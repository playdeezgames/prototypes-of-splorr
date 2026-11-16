package morse

// Morse Code Tutor, made into a game. After "Morse Code Tutor" by Donald E. Smith (SoftSide,
// August 1979), whose three modes were: send what you type, copy random characters within a
// response time, and copy a buddy's message. Here the copying mode is a game with levels: the
// characters come in a pair at a time (Koch order), the code gets faster and the time to answer
// shorter, three lives, and streaks multiply the score. Pure rules: no platform imports.

// International Morse code for the characters the tutor uses.
code_for :: proc(c: u8) -> string {
	switch c {
	case 'A': return ".-"
	case 'B': return "-..."
	case 'C': return "-.-."
	case 'D': return "-.."
	case 'E': return "."
	case 'F': return "..-."
	case 'G': return "--."
	case 'H': return "...."
	case 'I': return ".."
	case 'J': return ".---"
	case 'K': return "-.-"
	case 'L': return ".-.."
	case 'M': return "--"
	case 'N': return "-."
	case 'O': return "---"
	case 'P': return ".--."
	case 'Q': return "--.-"
	case 'R': return ".-."
	case 'S': return "..."
	case 'T': return "-"
	case 'U': return "..-"
	case 'V': return "...-"
	case 'W': return ".--"
	case 'X': return "-..-"
	case 'Y': return "-.--"
	case 'Z': return "--.."
	case '0': return "-----"
	case '1': return ".----"
	case '2': return "..---"
	case '3': return "...--"
	case '4': return "....-"
	case '5': return "....."
	case '6': return "-...."
	case '7': return "--..."
	case '8': return "---.."
	case '9': return "----."
	case '.': return ".-.-.-"
	case ',': return "--..--"
	case '?': return "..--.."
	case '/': return "-..-."
	case '=': return "-...-"
	}
	return ""
}

// The order characters are introduced (Koch's), two per level.
KOCH := "ETANIMSOURDKGWHVFLBYPCXQZJ5.,?/=123467890"

// Characters in play at a level (1-based): two at level 1, two more each level after.
level_chars :: proc(level: int) -> string {
	return KOCH[:clamp(2 * level, 2, len(KOCH))]
}

// ---- timing ----

// One dit in milliseconds at a character speed in words per minute (PARIS = 50 dits).
dit_ms :: proc(wpm: f32) -> f32 {return 1200 / wpm}

Tone :: struct {
	start, length: f32, // ms from the start of the transmission
}

MAX_TONES :: 512

Transmission :: struct {
	tones:    [MAX_TONES]Tone,
	count:    int,
	total_ms: f32,
}

// Lays out a text as tones. Characters go at char_wpm; the gaps between characters and words
// are stretched to word_wpm when that is slower (Farnsworth timing, like the original's
// separate character and word rates).
transmit :: proc(tx: ^Transmission, text: string, char_wpm, word_wpm: f32) {
	tx^ = {}
	d := dit_ms(char_wpm)
	// Farnsworth: extra time spread over the 19 dits of spacing in PARIS.
	fd := d
	if word_wpm < char_wpm {
		fd = ((60000 / word_wpm) - 31 * d) / 19
	}
	t: f32 = 0
	for i in 0 ..< len(text) {
		c := text[i]
		if c == ' ' {
			t += 7 * fd
			continue
		}
		code := code_for(c)
		for j in 0 ..< len(code) {
			l := code[j] == '.' ? d : 3 * d
			if tx.count < MAX_TONES {
				tx.tones[tx.count] = {t, l}
				tx.count += 1
			}
			t += l
			if j < len(code) - 1 {t += d}
		}
		if i < len(text) - 1 && text[i + 1] != ' ' {t += 3 * fd}
	}
	tx.total_ms = t
}

// Whether the key is down at a moment of the transmission (for the lamp).
keyed :: proc(tx: ^Transmission, ms: f32) -> bool {
	for i in 0 ..< tx.count {
		tn := tx.tones[i]
		if ms >= tn.start && ms < tn.start + tn.length {return true}
		if tn.start > ms {break}
	}
	return false
}

// ---- the copy game ----

Phase :: enum {
	Ready, // a beat before the next character
	Sending,
	Waiting, // sent; the answer clock is running
	Result, // showing right or wrong
	Level_Up,
	Over,
}

Level :: struct {
	char_wpm: f32,
	word_wpm: f32,
	reply_s:  f32, // time to answer after the character ends
}

level_info :: proc(level: int) -> Level {
	l := f32(min(level, 20) - 1)
	return {char_wpm = 12 + l * 0.8, word_wpm = 12 + l * 0.8, reply_s = max(1.4, 4.0 - l * 0.15)}
}

PER_LEVEL :: 8 // right answers to clear a level
LIVES :: 3
READY_S :: 0.7
RESULT_S :: 1.1
LEVEL_UP_S :: 2.2

Event :: enum {
	Send, // a new character went out (the page plays tx)
	Right,
	Wrong,
	Timeout,
	Level_Up,
	Over,
}

Game :: struct {
	level:     int,
	lives:     int,
	score:     int,
	streak:    int,
	best_streak: int,
	right:     int, // right answers this level
	phase:     Phase,
	timer:     f32, // seconds in the current phase
	current:   u8,
	answered:  u8, // what the player typed (0 for a timeout)
	gained:    int,
	replayed:  bool,
	tx:        Transmission,
	events:    bit_set[Event],
	rng:       u64,
	// Buddy mode: copy a fixed message instead (no lives, no levels).
	script:    [160]u8,
	script_len: int,
	script_at: int,
	script_wpm: f32,
	marks:     [160]bool, // buddy mode: which characters were copied right
}

rand_u32 :: proc(g: ^Game) -> u32 {
	x := g.rng
	x ~= x >> 12
	x ~= x << 25
	x ~= x >> 27
	g.rng = x
	return u32((x * 0x2545F4914F6CDD1D) >> 32)
}

new_game :: proc(g: ^Game, seed: u64) {
	g^ = {}
	g.rng = seed | 1
	g.level = 1
	g.lives = LIVES
	g.phase = .Ready
}

// Buddy mode: a message to copy, sent at one speed. Spaces are skipped.
new_buddy :: proc(g: ^Game, message: string, wpm: f32, seed: u64) {
	new_game(g, seed)
	for i in 0 ..< min(len(message), len(g.script)) {
		c := message[i]
		if c >= 'a' && c <= 'z' {c -= 32}
		if len(code_for(c)) > 0 {
			g.script[g.script_len] = c
			g.script_len += 1
		}
	}
	g.script_wpm = wpm
}

is_buddy :: proc(g: ^Game) -> bool {return g.script_len > 0}

// Picks the next character: half the time one of the two newest, so new ones get practice.
pick :: proc(g: ^Game) -> u8 {
	chars := level_chars(g.level)
	letters: [64]u8
	n := 0
	for i in 0 ..< len(chars) {
		letters[n] = chars[i]
		n += 1
	}
	if n > 2 && rand_u32(g) % 2 == 0 {
		return letters[n - 2 + int(rand_u32(g) % 2)]
	}
	c := letters[rand_u32(g) % u32(n)]
	if c == g.current && n > 1 {c = letters[rand_u32(g) % u32(n)]}
	return c
}

send_current :: proc(g: ^Game) {
	b := [1]u8{g.current}
	if is_buddy(g) {
		transmit(&g.tx, string(b[:]), g.script_wpm, g.script_wpm)
	} else {
		info := level_info(g.level)
		transmit(&g.tx, string(b[:]), info.char_wpm, info.word_wpm)
	}
	g.phase = .Sending
	g.timer = 0
	g.events += {.Send}
}

reply_seconds :: proc(g: ^Game) -> f32 {
	return is_buddy(g) ? 4.0 : level_info(g.level).reply_s
}

update :: proc(g: ^Game, dt: f32) {
	g.timer += dt
	switch g.phase {
	case .Ready:
		if g.timer >= READY_S {
			if is_buddy(g) {
				if g.script_at >= g.script_len {
					g.phase = .Over
					g.events += {.Over}
					return
				}
				g.current = g.script[g.script_at]
			} else {
				g.current = pick(g)
			}
			g.replayed = false
			send_current(g)
		}
	case .Sending:
		if g.timer * 1000 >= g.tx.total_ms {
			g.phase = .Waiting
			g.timer = 0
		}
	case .Waiting:
		if g.timer >= reply_seconds(g) {
			g.answered = 0
			miss(g, .Timeout)
		}
	case .Result:
		if g.timer >= RESULT_S {
			if g.lives <= 0 {
				g.phase = .Over
				g.events += {.Over}
			} else if !is_buddy(g) && g.right >= PER_LEVEL {
				g.phase = .Level_Up
				g.timer = 0
				g.level += 1
				g.right = 0
				g.events += {.Level_Up}
			} else {
				g.phase = .Ready
				g.timer = 0
			}
		}
	case .Level_Up:
		if g.timer >= LEVEL_UP_S {
			g.phase = .Ready
			g.timer = 0
		}
	case .Over:
	}
}

// The player's answer. Accepted while the character is being sent or after.
answer :: proc(g: ^Game, c: u8) {
	if g.phase != .Sending && g.phase != .Waiting {return}
	ch := c
	if ch >= 'a' && ch <= 'z' {ch -= 32}
	if len(code_for(ch)) == 0 {return}
	g.answered = ch
	if ch != g.current {
		miss(g, .Wrong)
		return
	}
	// Faster answers earn more; a replay forfeits the speed bonus.
	frac: f32 = 1
	if g.phase == .Waiting {frac = 1 - g.timer / reply_seconds(g)}
	if g.replayed {frac = 0}
	g.streak += 1
	g.best_streak = max(g.best_streak, g.streak)
	mult := 1 + min(g.streak / 5, 3)
	g.gained = (10 * g.level + int(frac * 10)) * mult
	g.score += g.gained
	g.right += 1
	if is_buddy(g) {
		g.marks[g.script_at] = true
		g.script_at += 1
	}
	g.events += {.Right}
	g.phase = .Result
	g.timer = 0
}

miss :: proc(g: ^Game, why: Event) {
	g.streak = 0
	g.gained = 0
	if is_buddy(g) {
		g.script_at += 1
	} else {
		g.lives -= 1
	}
	g.events += {why}
	g.phase = .Result
	g.timer = 0
}

// Sends the current character again (once per character; costs the speed bonus).
replay :: proc(g: ^Game) -> bool {
	if g.phase != .Waiting || g.replayed {return false}
	g.replayed = true
	send_current(g)
	return true
}

buddy_right :: proc(g: ^Game) -> int {
	n := 0
	for i in 0 ..< g.script_len {if g.marks[i] {n += 1}}
	return n
}
