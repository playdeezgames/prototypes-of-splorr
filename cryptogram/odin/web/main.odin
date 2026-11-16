#+build js
package main

// Cryptogram's page: screens, drawing, keys and taps. Rules are in ../game.

import "base:runtime"
import "core:fmt"
import "core:strconv"
import game "../game"
import "proto:gfx"

W :: 512
H :: 304

BG :: 0x13161c
PANEL :: 0x1f2430
LINE :: 0x384052
TEXT :: 0xe9e4d4
DIM :: 0x7d8597
CODE :: 0x8fa3c8
SEL :: 0x3c5a8a
GOOD :: 0x6fd36a
BAD :: 0xf05a4a
GOLD :: 0xf0c75a

Screen :: enum {
	Title,
	Solve,
	Typing,
}

App :: struct {
	screen:     Screen,
	pz:         game.Puzzle,
	rng:        game.Rng,
	crypt:      int, // bank index, -1 for a typed-in crypt
	selected:   u8, // code letter, 0 for none
	clock:      f32,
	done:       bool,
	message:    string,
	msg_bad:    bool,
	msg_t:      f32,
	t:          f32,
	solved:     int, // all-time count
	best:       int, // best seconds without hints, 0 = none
	typed:      [game.MAX_TEXT]u8,
	typed_len:  int,
}

app: App

ID_KEY :: 100 // + letter index
ID_CELL :: 200 // + code letter index
ID_CLEAR :: 1
ID_HINT :: 2
ID_NEW :: 3
ID_MENU :: 4
ID_OWN :: 5
ID_SPACE :: 6
ID_DEL :: 7
ID_DONE :: 8
ID_ERASE :: 9

main :: proc() {
	app.rng = {u64(gfx.now_ms()) ~ 0x9E3779B97F4A7C15}
	app.crypt = -1
	buf: [32]u8
	if v, ok := gfx.store_get("solved", buf[:]); ok {
		if n, nok := strconv.parse_int(v); nok && n >= 0 {app.solved = n}
	}
	if v, ok := gfx.store_get("best", buf[:]); ok {
		if n, nok := strconv.parse_int(v); nok && n > 0 {app.best = n}
	}
}

say :: proc(msg: string, bad := false) {
	app.message = msg
	app.msg_bad = bad
	app.msg_t = 3
	if bad {gfx.tone(140, 160, .Saw, 0.05)}
}

deal :: proc() {
	n := len(game.BANK)
	i := game.rand_n(&app.rng, n)
	if i == app.crypt {i = (i + 1) % n}
	app.crypt = i
	game.from_plain(&app.pz, game.BANK[i].text, &app.rng)
	begin()
}

begin :: proc() {
	app.screen = .Solve
	app.clock = 0
	app.done = false
	app.selected = 0
	say("PICK A CODE LETTER, THEN THE LETTER IT STANDS FOR")
	app.msg_bad = false
	letters, n := game.order(&app.pz)
	if n > 0 {app.selected = letters[0]}
}

@(export)
step :: proc(dt: f64) -> bool {
	d := f32(min(dt, 0.25))
	app.t += d
	app.msg_t = max(0, app.msg_t - d)
	if app.screen == .Solve && !app.done {app.clock += d}
	draw()
	free_all(context.temp_allocator)
	return true
}

// ---- input ----

@(export)
on_key :: proc "c" (code: i32, down: i32) {
	context = runtime.default_context()
	if down == 0 {return}
	key(int(code))
}

@(export)
on_pointer :: proc "c" (x, y: f32, kind: i32) {
	context = runtime.default_context()
	if kind != 0 {return}
	id := gfx.hit(x, y)
	if id >= 0 {press(id)}
}

key :: proc(c: int) {
	switch app.screen {
	case .Title:
		if c == 'N' || c == gfx.KEY_ENTER || c == gfx.KEY_SPACE {deal()}
		if c == 'T' {
			app.screen = .Typing
			app.typed_len = 0
		}
	case .Typing:
		typing_key(c)
	case .Solve:
		solve_key(c)
	}
}

typing_key :: proc(c: int) {
	switch {
	case c == gfx.KEY_ESCAPE:
		app.screen = .Title
	case c == gfx.KEY_ENTER:
		has_letter := false
		for b in app.typed[:app.typed_len] {if game.is_letter(b) {has_letter = true}}
		if has_letter {
			game.from_cipher(&app.pz, string(app.typed[:app.typed_len]))
			app.crypt = -1
			begin()
		}
	case c == gfx.KEY_BACKSPACE || c == gfx.KEY_DELETE:
		if app.typed_len > 0 {app.typed_len -= 1}
	case c >= 32 && c < 127:
		if app.typed_len < 160 {
			app.typed[app.typed_len] = u8(c)
			app.typed_len += 1
		}
	}
}

solve_key :: proc(c: int) {
	pz := &app.pz
	if app.done {
		if c == gfx.KEY_ENTER || c == gfx.KEY_SPACE || c == 'N' || c == '?' {deal()}
		if c == gfx.KEY_ESCAPE {app.screen = .Title}
		return
	}
	switch {
	case c >= 'A' && c <= 'Z':
		if app.selected == 0 {
			select(u8(c))
		} else {
			put(u8(c))
		}
	case c == gfx.KEY_SPACE || c == gfx.KEY_BACKSPACE || c == gfx.KEY_DELETE:
		if app.selected != 0 {game.clear_guess(pz, app.selected)}
	case c == gfx.KEY_LEFT || c == gfx.KEY_RIGHT || c == gfx.KEY_TAB:
		move_selection(c == gfx.KEY_LEFT ? -1 : 1)
	case c == gfx.KEY_ESCAPE:
		if app.selected != 0 {app.selected = 0} else {app.screen = .Title}
	case c == '/':
		game.clear_all(pz)
		say("ALL SUBSTITUTIONS CLEARED")
	case c == '?':
		deal()
	case c == '1':
		give_hint()
	}
}

select :: proc(code: u8) {
	if int(code - 'A') not_in app.pz.present {
		say(fmt.tprintf("\"%c\" NOT IN CRYPT", rune(code)), true)
		return
	}
	app.selected = code
	gfx.tone(500, 20, .Square, 0.03)
}

put :: proc(letter: u8) {
	pz := &app.pz
	switch game.assign(pz, app.selected, letter) {
	case .Ok:
		gfx.tone(660, 30, .Square, 0.04)
		move_to_next_blank()
		check_solved()
	case .Already_In_Use:
		holder, _ := game.holder(pz, letter)
		say(fmt.tprintf("\"%c\" ALREADY IN USE (FOR \"%c\")", rune(letter), rune(holder)), true)
	case .Not_In_Crypt:
		say(fmt.tprintf("\"%c\" NOT IN CRYPT", rune(app.selected)), true)
	case .Not_A_Letter, .Solved_Already:
	}
}

move_selection :: proc(dir: int) {
	letters, n := game.order(&app.pz)
	if n == 0 {return}
	at := -1
	for i in 0 ..< n {if letters[i] == app.selected {at = i}}
	if at < 0 {
		app.selected = letters[0]
		return
	}
	app.selected = letters[(at + dir + n) % n]
}

// After a guess, hop to the next code letter that has none (in reading order).
move_to_next_blank :: proc() {
	letters, n := game.order(&app.pz)
	at := 0
	for i in 0 ..< n {if letters[i] == app.selected {at = i}}
	for k in 1 ..= n {
		c := letters[(at + k) % n]
		if app.pz.guess[c - 'A'] == 0 {
			app.selected = c
			return
		}
	}
}

give_hint :: proc() {
	if !app.pz.has_answer {
		say("NO ANSWER KNOWN FOR A CRYPT YOU TYPED IN", true)
		return
	}
	code := game.hint(&app.pz, &app.rng)
	if code != 0 {
		app.selected = code
		say(fmt.tprintf("HINT: \"%c\" IS \"%c\"", rune(code), rune(app.pz.guess[code - 'A'])))
		gfx.tone(880, 60, .Sine, 0.05)
		check_solved()
	}
}

check_solved :: proc() {
	if !game.solved(&app.pz) {return}
	app.done = true
	app.selected = 0
	app.solved += 1
	gfx.store_set("solved", fmt.tprintf("%d", app.solved))
	secs := int(app.clock + 0.5)
	if app.pz.hints == 0 && (app.best == 0 || secs < app.best) {
		app.best = secs
		gfx.store_set("best", fmt.tprintf("%d", secs))
	}
	notes := [?]f32{523, 659, 784, 1047, 784, 1047}
	for f, i in notes {gfx.tone(f, 110, .Square, 0.05, f32(i) * 110)}
}

press :: proc(id: int) {
	switch {
	case id >= ID_KEY && id < ID_KEY + 26:
		letter := u8('A' + id - ID_KEY)
		if app.screen == .Typing {
			typing_key(int(letter))
		} else if app.selected == 0 {
			say("PICK A CODE LETTER IN THE CRYPT FIRST", true)
		} else {
			put(letter)
		}
	case id >= ID_CELL && id < ID_CELL + 26:
		if !app.done {select(u8('A' + id - ID_CELL))}
	case id == ID_CLEAR:
		key('/')
	case id == ID_HINT:
		key('1')
	case id == ID_NEW:
		if app.screen == .Title {deal()} else {key('?')}
	case id == ID_MENU:
		app.screen = .Title
	case id == ID_OWN:
		key('T')
	case id == ID_SPACE:
		typing_key(' ')
	case id == ID_DEL:
		typing_key(gfx.KEY_BACKSPACE)
	case id == ID_DONE:
		typing_key(gfx.KEY_ENTER)
	case id == ID_ERASE:
		if app.selected != 0 && !app.done {game.clear_guess(&app.pz, app.selected)}
	}
}

// ---- drawing ----

draw :: proc() {
	gfx.clear(BG)
	gfx.begin_buttons()
	switch app.screen {
	case .Title:
		draw_title()
	case .Solve:
		draw_solve()
	case .Typing:
		draw_typing()
	}
}

char :: proc(x, y: int, c: u8, rgb: u32, size := 1) {
	b := [1]u8{c}
	gfx.text(x, y, string(b[:]), rgb, size)
}

draw_title :: proc() {
	gfx.text_c(W / 2, 30, "CRYPTOGRAM", GOLD, 4)
	lines := [?]string {
		"EACH CRYPT IS A SAYING IN A SIMPLE CODE: EVERY LETTER",
		"STANDS FOR ANOTHER. TYPE THE LETTER YOU THINK THE",
		"HIGHLIGHTED CODE LETTER STANDS FOR. TAP A CODE LETTER,",
		"USE THE ARROWS, OR ESC THEN A LETTER TO PICK ANOTHER.",
		"",
		"  /  CLEARS ALL GUESSES     ?  DEALS ANOTHER CRYPT",
		"  1  GIVES A HINT           ESC  BACK TO THIS PAGE",
	}
	for l, i in lines {gfx.text(40, 80 + i * 12, l, i >= 5 ? CODE : DIM)}
	gfx.button(W / 2 - 150, 186, "N NEW CRYPT", ID_NEW, GOLD, PANEL, 1)
	gfx.button(W / 2 + 10, 186, "T TYPE YOUR OWN", ID_OWN, TEXT, PANEL, 1)
	stats := fmt.tprintf("SOLVED %d", app.solved)
	if app.best > 0 {stats = fmt.tprintf("SOLVED %d   BEST (NO HINTS) %d:%02d", app.solved, app.best / 60, app.best % 60)}
	gfx.text_c(W / 2, 220, stats, DIM)
	gfx.text_c(W / 2, 270, "AFTER \"CRYPTOGRAM\" BY RIK PIERCE, SOFTSIDE, AUGUST 1979", DIM)
	gfx.text_c(W / 2, 282, "A SOFTSIDE PROTOTYPE BY THEGRUMPYGAMEDEV", DIM)
}

CELL_W :: 12
LINE_H :: 30
MAX_COLS :: 40

// Splits the crypt into lines at spaces, at most MAX_COLS wide.
wrap :: proc(s: string) -> (starts: [12]int, ends: [12]int, n: int) {
	i := 0
	for i < len(s) && n < 12 {
		for i < len(s) && s[i] == ' ' {i += 1}
		if i >= len(s) {break}
		end := min(i + MAX_COLS, len(s))
		if end < len(s) {
			cut := end
			for cut > i && s[cut] != ' ' {cut -= 1}
			if cut > i {end = cut}
		}
		starts[n], ends[n] = i, end
		n += 1
		i = end
	}
	return
}

draw_solve :: proc() {
	pz := &app.pz
	title := app.crypt >= 0 ? fmt.tprintf("CRYPT #%d", app.crypt + 1) : "YOUR CRYPT"
	gfx.text(16, 8, "CRYPTOGRAM", GOLD)
	gfx.text(112, 8, title, DIM)
	secs := int(app.clock)
	right := fmt.tprintf("HINTS %d  TIME %d:%02d", pz.hints, secs / 60, secs % 60)
	gfx.text(W - 16 - gfx.text_width(right), 8, right, TEXT)

	s := game.text(pz)
	starts, ends, n := wrap(s)
	top := 28 + max(0, (6 - n) * LINE_H / 2)
	for li in 0 ..< n {
		line := s[starts[li]:ends[li]]
		x0 := W / 2 - len(line) * CELL_W / 2
		y := top + li * LINE_H
		for k in 0 ..< len(line) {
			c := line[k]
			x := x0 + k * CELL_W
			if !game.is_letter(c) {
				char(x + 2, y + 2, c, TEXT)
				continue
			}
			idx := c - 'A'
			if c == app.selected {gfx.rect(x, y - 1, CELL_W - 1, 25, SEL)}
			g := pz.guess[idx]
			col: u32 = app.done ? GOOD : TEXT
			if g != 0 {char(x + 2, y + 2, g, col)}
			gfx.rect(x + 1, y + 11, CELL_W - 3, 1, LINE)
			char(x + 2, y + 14, c, CODE)
			gfx.zone(x, y - 1, CELL_W, 25, ID_CELL + int(idx))
		}
	}

	if app.done {
		src := app.crypt >= 0 ? game.BANK[app.crypt].source : ""
		gfx.text_c(W / 2, 210, fmt.tprintf("SOLVED!  -- %s", src), GOOD)
		gfx.text_c(W / 2, 224, fmt.tprintf("%d:%02d WITH %d HINT%s", secs / 60, secs % 60, pz.hints, pz.hints == 1 ? "" : "S"), DIM)
		gfx.button(W / 2 - 110, 250, "N NEXT CRYPT", ID_NEW, GOLD, PANEL)
		gfx.button(W / 2 + 20, 250, "ESC MENU", ID_MENU, DIM, PANEL)
		return
	}

	if app.msg_t > 0 {gfx.text_c(W / 2, 206, app.message, app.msg_bad ? BAD : DIM)}
	draw_keyboard(220)
	x := 16
	y := 280
	x += gfx.button(x, y, "/ CLEAR ALL", ID_CLEAR, TEXT, PANEL) + 6
	if pz.has_answer {x += gfx.button(x, y, "1 HINT", ID_HINT, TEXT, PANEL) + 6}
	x += gfx.button(x, y, "SPACE ERASE", ID_ERASE, TEXT, PANEL) + 6
	x += gfx.button(x, y, "? NEW CRYPT", ID_NEW, TEXT, PANEL) + 6
	gfx.button(x, y, "ESC MENU", ID_MENU, DIM, PANEL)
}

// The 26 letters; a letter in use shows which code letter has it.
draw_keyboard :: proc(y: int) {
	pz := &app.pz
	kw :: 36
	for i in 0 ..< 26 {
		row := i / 13
		col := i % 13
		x := W / 2 - 13 * kw / 2 + col * kw
		ky := y + row * 28
		letter := u8('A' + i)
		holder, used := game.holder(pz, letter)
		if app.screen == .Typing {used = false}
		gfx.rect(x + 1, ky, kw - 3, 24, used ? BG : PANEL)
		gfx.frame(x + 1, ky, kw - 3, 24, used ? LINE : CODE)
		char(x + 12, ky + 4, letter, used ? DIM : TEXT)
		if used {char(x + 12, ky + 14, holder, CODE)}
		gfx.zone(x, ky, kw, 26, ID_KEY + i)
	}
}

draw_typing :: proc() {
	gfx.text(16, 8, "TYPE IN YOUR OWN CRYPTOGRAM", GOLD)
	gfx.text(16, 22, "LETTERS, SPACES AND PUNCTUATION. ENTER WHEN DONE, ESC TO GO BACK.", DIM)
	s := string(app.typed[:app.typed_len])
	starts, ends, n := wrap(s)
	for li in 0 ..< n {
		gfx.text(24, 48 + li * 14, s[starts[li]:ends[li]], CODE)
	}
	cx, cy := 24, 48
	if n > 0 {
		cx = 24 + (ends[n - 1] - starts[n - 1]) * 8
		cy = 48 + (n - 1) * 14
		if ends[n - 1] < len(s) {cx += 8}
	}
	if int(app.t * 2) % 2 == 0 {gfx.rect(cx, cy, 7, 8, TEXT)}
	gfx.text(24, 190, fmt.tprintf("%d/160", app.typed_len), DIM)
	draw_keyboard(220)
	x := 16
	x += gfx.button(x, 280, "SPACE", ID_SPACE, TEXT, PANEL) + 6
	x += gfx.button(x, 280, "DELETE", ID_DEL, TEXT, PANEL) + 6
	x += gfx.button(x, 280, "ENTER  SOLVE IT", ID_DONE, GOLD, PANEL) + 6
	gfx.button(x, 280, "ESC MENU", ID_MENU, DIM, PANEL)
}
