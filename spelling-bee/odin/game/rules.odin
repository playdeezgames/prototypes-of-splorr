package spellingbee

// Spelling Bee, gamified. After "Spelling Bee" by Lance Micklus (SoftSide, December 1978): the
// word is shown ("WORD 3 IS MATCH."), the screen clears, and the speller types it from memory;
// right is "THAT'S RIGHT", wrong shows the spelling, and a session is ten words with the correct
// and wrong counted at the end. The listing's own words open the hive. New here, as with State
// Capital Quiz: a ladder of longer words and shorter looks, three bees (lives), streaks that
// multiply the score, a missed word coming back later; and the listing's ten-word session kept
// as Practice, with no lives and no clock.
// Pure rules: no platform imports.

// The listing's DATA lines 1020-1060.
LISTING_WORDS := [?]string {
	"SONG", "LAMP", "BEND", "DENT", "DUST", "DANCE", "MAP", "MATCH", "MAST", "FENCE",
	"FLING", "FUN", "PACK", "PATCH", "PAN", "WILT", "WIN", "WHIP", "SKILL", "SICK",
	"SILK", "CAMP", "CATCH", "CAN", "BARN", "WATCH", "WITH",
}

// More words for the ladder, a rung for each.
RUNGS := [?][]string {
	{"FROG", "SHIP", "DRUM", "KITE", "MILK", "NEST", "ROPE", "SNOW", "TREE", "WOLF", "BELL", "COIN", "GOLD", "JUMP", "LEAF", "MOON", "PINK", "RAIN", "SOCK", "YARD"},
	{"BRAVE", "CHAIR", "DREAM", "EARTH", "FLAME", "GRAPE", "HONEY", "JUICE", "LEMON", "MAGIC", "NIGHT", "OCEAN", "PIANO", "QUEEN", "RIVER", "STORM", "TIGER", "WHALE", "YOUNG", "ZEBRA"},
	{"BASKET", "CASTLE", "DRAGON", "FOREST", "GARDEN", "HAMMER", "ISLAND", "JUNGLE", "KITTEN", "LADDER", "MARKET", "NEEDLE", "ORANGE", "PENCIL", "RABBIT", "SILVER", "TURTLE", "VALLEY", "WINDOW", "YELLOW"},
	{"BALLOON", "CABBAGE", "DOLPHIN", "EXPLORE", "FEATHER", "GIRAFFE", "HARVEST", "JOURNEY", "KITCHEN", "LANTERN", "MACHINE", "NOTHING", "OCTOPUS", "PENGUIN", "QUARTER", "RAINBOW", "SHELTER", "THUNDER", "VILLAGE", "WEATHER"},
	{"ALPHABET", "BIRTHDAY", "CHOCOLATE", "DINOSAUR", "ELEPHANT", "FESTIVAL", "GRATEFUL", "HOSPITAL", "KANGAROO", "LIBRARY", "MOUNTAIN", "NEIGHBOR", "PAINTING", "QUESTION", "SANDWICH", "SQUIRREL", "TOMORROW", "UMBRELLA", "VACATION", "YESTERDAY"},
}

RUNG_COUNT :: len(RUNGS) + 1 // rung 0 is the listing's words
WORD_MAX :: 12
LIVES :: 3
UP_EVERY :: 5 // right answers to climb a rung
STREAK_STEP :: 5
MAX_MULT :: 4
PRACTICE_WORDS :: 10 // the listing's FOR GUESS=1 TO 10

Mode :: enum {
	Hive, // the game
	Practice, // the listing's session
}

Phase :: enum {
	Look, // the word is on the screen
	Spell, // the screen is clear; type it
	Result, // right or wrong shown
	Over,
}

Event :: enum {
	Right,
	Wrong,
	Rung_Up,
	Life_Lost,
	Over,
}

Game :: struct {
	mode:        Mode,
	phase:       Phase,
	rung:        int,
	word:        string,
	again:       [8]string, // missed words to ask again, oldest first
	again_n:     int,
	since_miss:  int, // words since the last re-ask was queued
	typed:       [WORD_MAX]u8,
	typed_n:     int,
	look:        f32, // seconds the word stays up
	timer:       f32,
	asked:       int, // words asked (the listing's GUESS)
	right:       int, // the listing's CW
	wrong:       int, // the listing's WW
	climb:       int, // right answers on this rung
	lives:       int,
	score:       int,
	streak:      int,
	best_streak: int,
	last_gain:   int,
	was_right:   bool,
	used:        [RUNG_COUNT][32]bool, // words already asked on each rung (cleared when all are)
	events:      bit_set[Event],
	rng:         u64,
}

next_random :: proc(g: ^Game) -> f32 {
	x := g.rng
	x ~= x >> 12
	x ~= x << 25
	x ~= x >> 27
	g.rng = x
	return f32((x * 0x2545F4914F6CDD1D) >> 40) / f32(1 << 24)
}

rand_int :: proc(g: ^Game, n: int) -> int {
	return min(n - 1, int(next_random(g) * f32(n)))
}

rung_words :: proc(r: int) -> []string {
	if r == 0 {return LISTING_WORDS[:]}
	return RUNGS[r - 1]
}

// How long the word is shown: two and a half seconds at the bottom, a second at the top.
look_time :: proc(g: ^Game) -> f32 {
	if g.mode == .Practice {return 2.5}
	return max(1.0, 2.5 - f32(g.rung) * 0.25 - f32(g.climb) * 0.03)
}

multiplier :: proc(streak: int) -> int {
	return min(MAX_MULT, 1 + streak / STREAK_STEP)
}

new_game :: proc(g: ^Game, seed: u64, mode: Mode) {
	g^ = {}
	g.rng = seed | 1
	g.mode = mode
	g.lives = LIVES
	ask(g)
}

pick_word :: proc(g: ^Game) -> string {
	words := rung_words(g.rung)
	left := 0
	for i in 0 ..< len(words) {if !g.used[g.rung][i] {left += 1}}
	if left == 0 {
		g.used[g.rung] = {}
		left = len(words)
	}
	k := rand_int(g, left)
	for i in 0 ..< len(words) {
		if g.used[g.rung][i] {continue}
		if k == 0 {
			g.used[g.rung][i] = true
			return words[i]
		}
		k -= 1
	}
	return words[0]
}

ask :: proc(g: ^Game) {
	// A missed word comes back after a few others.
	if g.again_n > 0 && g.since_miss >= 3 {
		g.word = g.again[0]
		for i in 1 ..< g.again_n {g.again[i - 1] = g.again[i]}
		g.again_n -= 1
		g.since_miss = 0
	} else {
		g.word = pick_word(g)
		g.since_miss += 1
	}
	g.typed_n = 0
	g.look = look_time(g)
	g.timer = g.look
	g.phase = .Look
	g.asked += 1
}

// The page calls this every frame.
update :: proc(g: ^Game, dt: f32) {
	if g.phase == .Look {
		g.timer -= dt
		if g.timer <= 0 {g.phase = .Spell}
	}
}

// Skips the rest of the look (the speller is ready).
ready :: proc(g: ^Game) {
	if g.phase == .Look {g.phase = .Spell}
}

type_letter :: proc(g: ^Game, ch: u8) -> bool {
	c := ch
	if c >= 'a' && c <= 'z' {c -= 32}
	if c < 'A' || c > 'Z' {return false}
	if g.phase == .Look {g.phase = .Spell} // typing ends the look
	if g.phase != .Spell || g.typed_n >= WORD_MAX {return false}
	g.typed[g.typed_n] = c
	g.typed_n += 1
	return true
}

rub_out :: proc(g: ^Game) {
	if g.phase == .Spell && g.typed_n > 0 {g.typed_n -= 1}
}

typed :: proc(g: ^Game) -> string {
	return string(g.typed[:g.typed_n])
}

// The listing's line 620: IF A$=W$(N) ... THAT'S RIGHT.
submit :: proc(g: ^Game) -> bool {
	if g.phase != .Spell || g.typed_n == 0 {return false}
	g.phase = .Result
	g.last_gain = 0
	g.was_right = typed(g) == g.word
	if g.was_right {
		g.right += 1
		g.streak += 1
		g.best_streak = max(g.best_streak, g.streak)
		g.events += {.Right}
		if g.mode == .Hive {
			g.last_gain = 10 * len(g.word) * (g.rung + 1) * multiplier(g.streak)
			g.score += g.last_gain
			g.climb += 1
			if g.climb >= UP_EVERY && g.rung < RUNG_COUNT - 1 {
				g.rung += 1
				g.climb = 0
				g.events += {.Rung_Up}
			}
		}
	} else {
		g.wrong += 1
		g.streak = 0
		g.events += {.Wrong}
		if g.mode == .Hive {
			g.lives -= 1
			g.events += {.Life_Lost}
			if g.again_n < len(g.again) {
				g.again[g.again_n] = g.word
				g.again_n += 1
				if g.again_n == 1 {g.since_miss = 0}
			}
		}
	}
	if (g.mode == .Hive && g.lives <= 0) || (g.mode == .Practice && g.asked >= PRACTICE_WORDS) {
		g.events += {.Over}
	}
	return true
}

// After the result: the next word, or the end.
next :: proc(g: ^Game) {
	if g.phase != .Result {return}
	if (g.mode == .Hive && g.lives <= 0) || (g.mode == .Practice && g.asked >= PRACTICE_WORDS) {
		g.phase = .Over
		return
	}
	ask(g)
}
