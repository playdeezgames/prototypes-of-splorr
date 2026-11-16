#+build js
package main

// Morse Code Tutor's page: screens, sound, drawing, keys and taps. Rules are in ../game.

import "base:runtime"
import "core:fmt"
import "core:strconv"
import game "../game"
import "proto:gfx"

W :: 512
H :: 288

BG :: 0x0f1416
PANEL :: 0x1b2427
LINE :: 0x34464b
TEXT :: 0xdfe9e4
DIM :: 0x7b8f8c
LAMP_ON :: 0xffc84a
LAMP_OFF :: 0x3a2f1a
GOOD :: 0x6fd36a
BAD :: 0xf05a4a
CYAN :: 0x63c7d6

TONE_HZ :: 700

Screen :: enum {
	Title,
	Copy, // the game, and buddy copying
	Send,
	Buddy_Entry,
	Over,
}

App :: struct {
	screen:     Screen,
	g:          game.Game,
	t:          f32,
	best:       int,
	best_level: int,
	new_best:   bool,
	chart:      bool, // show the code under each character
	wpm_index:  int, // the keyer and buddy speed: 5, 13, 20 (the original's three rates)
	// keyer
	queue:      [256]u8,
	q_len:      int,
	sent:       [40]u8, // last characters sent, for the display
	sent_len:   int,
	key_tx:     game.Transmission,
	key_timer:  f32,
	key_busy:   f32, // ms until the keyer is free
	key_char:   u8,
	// buddy
	message:    [160]u8,
	msg_len:    int,
}

app: App

WPMS := [3]f32{5, 13, 20}
WPM_NAMES := [3]string{"5 WPM NOVICE", "13 WPM GENERAL", "20 WPM ADVANCED"}

ID_COPY :: 1
ID_SEND :: 2
ID_BUDDY :: 3
ID_MENU :: 4
ID_REPLAY :: 5
ID_CHART :: 6
ID_SPEED :: 7
ID_DONE :: 8
ID_AGAIN :: 9
ID_SPACE :: 10
ID_DEL :: 11
ID_CHAR :: 100 // + character code

main :: proc() {
	app.chart = true
	app.wpm_index = 1
	buf: [32]u8
	if v, ok := gfx.store_get("best", buf[:]); ok {
		if n, nok := strconv.parse_int(v); nok && n >= 0 {app.best = n}
	}
	if v, ok := gfx.store_get("best-level", buf[:]); ok {
		if n, nok := strconv.parse_int(v); nok && n >= 0 {app.best_level = n}
	}
}

seed :: proc() -> u64 {return u64(gfx.now_ms()) ~ u64(gfx.random() * 1e9)}

play :: proc(tx: ^game.Transmission) {
	for i in 0 ..< tx.count {
		tn := tx.tones[i]
		gfx.tone(TONE_HZ, tn.length, .Sine, 0.12, tn.start)
	}
}

start_copy :: proc() {
	game.new_game(&app.g, seed())
	app.screen = .Copy
	app.new_best = false
}

start_buddy :: proc() {
	game.new_buddy(&app.g, string(app.message[:app.msg_len]), WPMS[app.wpm_index], seed())
	if app.g.script_len == 0 {return}
	app.screen = .Copy
}

@(export)
step :: proc(dt: f64) -> bool {
	d := f32(min(dt, 0.25))
	app.t += d
	switch app.screen {
	case .Copy:
		game.update(&app.g, d)
		events()
	case .Send:
		keyer(d)
	case .Title, .Buddy_Entry, .Over:
	}
	draw()
	free_all(context.temp_allocator)
	return true
}

events :: proc() {
	g := &app.g
	ev := g.events
	g.events = {}
	if .Send in ev {play(&g.tx)}
	if .Right in ev {gfx.tone(1047, 50, .Square, 0.035, 60)}
	if .Wrong in ev || .Timeout in ev {gfx.tone(160, 220, .Saw, 0.05, 40)}
	if .Level_Up in ev {
		notes := [?]f32{523, 659, 784}
		for f, i in notes {gfx.tone(f, 120, .Square, 0.05, f32(i) * 130)}
	}
	if .Over in ev {
		app.screen = .Over
		app.t = 0
		if !game.is_buddy(g) {
			if g.score > app.best {
				app.best = g.score
				app.new_best = true
				gfx.store_set("best", fmt.tprintf("%d", g.score))
			}
			if g.level > app.best_level {
				app.best_level = g.level
				gfx.store_set("best-level", fmt.tprintf("%d", g.level))
			}
		}
	}
}

keyer :: proc(dt: f32) {
	app.key_timer += dt
	app.key_busy -= dt * 1000
	if app.key_busy > 0 || app.q_len == 0 {return}
	c := app.queue[0]
	copy(app.queue[:], app.queue[1:app.q_len])
	app.q_len -= 1
	wpm := WPMS[app.wpm_index]
	dit := game.dit_ms(wpm)
	if app.sent_len == len(app.sent) {
		copy(app.sent[:], app.sent[1:])
		app.sent_len -= 1
	}
	app.sent[app.sent_len] = c
	app.sent_len += 1
	app.key_char = c
	app.key_timer = 0
	if c == ' ' {
		app.key_tx = {}
		app.key_busy = 4 * dit // plus the 3 after the last character: a 7-dit word gap
		return
	}
	b := [1]u8{c}
	game.transmit(&app.key_tx, string(b[:]), wpm, wpm)
	play(&app.key_tx)
	app.key_busy = app.key_tx.total_ms + 3 * dit
}

// ---- input ----

@(export)
on_key :: proc "c" (code: i32, down: i32) {
	context = runtime.default_context()
	if down != 1 {return}
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
		switch c {
		case '1', gfx.KEY_ENTER, gfx.KEY_SPACE:
			start_copy()
		case '2':
			app.screen = .Send
			app.sent_len = 0
			app.q_len = 0
		case '3':
			app.screen = .Buddy_Entry
			app.msg_len = 0
		case gfx.KEY_TAB:
			app.wpm_index = (app.wpm_index + 1) % 3
		}
	case .Copy:
		switch c {
		case gfx.KEY_ESCAPE:
			app.screen = .Title
		case gfx.KEY_ENTER, gfx.KEY_SPACE:
			game.replay(&app.g)
		case gfx.KEY_TAB:
			app.chart = !app.chart
		case:
			if c < 128 {game.answer(&app.g, u8(c))}
		}
	case .Send:
		switch c {
		case gfx.KEY_ESCAPE:
			app.screen = .Title
		case gfx.KEY_TAB:
			app.wpm_index = (app.wpm_index + 1) % 3
		case gfx.KEY_BACKSPACE:
			if app.q_len > 0 {app.q_len -= 1}
		case:
			if c < 128 && (c == ' ' || len(game.code_for(u8(c))) > 0) && app.q_len < len(app.queue) {
				app.queue[app.q_len] = u8(c)
				app.q_len += 1
			}
		}
	case .Buddy_Entry:
		switch {
		case c == gfx.KEY_ESCAPE:
			app.screen = .Title
		case c == gfx.KEY_ENTER:
			start_buddy()
		case c == gfx.KEY_TAB:
			app.wpm_index = (app.wpm_index + 1) % 3
		case c == gfx.KEY_BACKSPACE:
			if app.msg_len > 0 {app.msg_len -= 1}
		case c < 128 && (c == ' ' || len(game.code_for(u8(c))) > 0):
			if app.msg_len < len(app.message) {
				app.message[app.msg_len] = u8(c)
				app.msg_len += 1
			}
		}
	case .Over:
		if app.t < 0.8 {return}
		if c == gfx.KEY_ENTER || c == gfx.KEY_SPACE {
			if game.is_buddy(&app.g) {app.screen = .Buddy_Entry} else {start_copy()}
		}
		if c == gfx.KEY_ESCAPE {app.screen = .Title}
	}
}

press :: proc(id: int) {
	switch {
	case id >= ID_CHAR && id < ID_CHAR + 128:
		key(id - ID_CHAR)
	case id == ID_COPY:
		key('1')
	case id == ID_SEND:
		key('2')
	case id == ID_BUDDY:
		key('3')
	case id == ID_MENU:
		app.screen = .Title
	case id == ID_REPLAY:
		game.replay(&app.g)
	case id == ID_CHART:
		app.chart = !app.chart
	case id == ID_SPEED:
		app.wpm_index = (app.wpm_index + 1) % 3
	case id == ID_DONE:
		key(gfx.KEY_ENTER)
	case id == ID_AGAIN:
		key(gfx.KEY_ENTER)
	case id == ID_SPACE:
		key(' ')
	case id == ID_DEL:
		key(gfx.KEY_BACKSPACE)
	}
}

// ---- drawing ----

draw :: proc() {
	gfx.clear(BG)
	gfx.begin_buttons()
	switch app.screen {
	case .Title:
		draw_title()
	case .Copy:
		draw_copy()
	case .Send:
		draw_send()
	case .Buddy_Entry:
		draw_buddy_entry()
	case .Over:
		draw_over()
	}
}

char_str :: proc(c: u8) -> string {
	b := new([1]u8, context.temp_allocator)
	b[0] = c
	return string(b[:])
}

// Dots and dashes drawn as marks.
draw_code :: proc(x, y: int, code: string, rgb: u32, scale := 1) {
	cx := x
	for i in 0 ..< len(code) {
		if code[i] == '.' {
			gfx.rect(cx, y, 2 * scale, 2 * scale, rgb)
			cx += 4 * scale
		} else {
			gfx.rect(cx, y, 6 * scale, 2 * scale, rgb)
			cx += 8 * scale
		}
	}
}

code_width :: proc(code: string, scale := 1) -> int {
	w := 0
	for i in 0 ..< len(code) {w += (code[i] == '.' ? 4 : 8) * scale}
	return max(0, w - 2 * scale)
}

lamp :: proc(cx, cy: int, on: bool) {
	gfx.rect(cx - 30, cy - 30, 60, 60, LINE)
	gfx.rect(cx - 26, cy - 26, 52, 52, on ? LAMP_ON : LAMP_OFF)
	if on {gfx.rect(cx - 18, cy - 20, 12, 6, 0xfff2c8)}
}

draw_title :: proc() {
	gfx.text_c(W / 2, 22, "MORSE CODE", CYAN, 3)
	gfx.text_c(W / 2, 50, "TUTOR", CYAN, 3)
	draw_code(W / 2 - code_width("-- --- .-. ... .", 1) / 2, 78, "-- --- .-. ... .", LAMP_ON)
	y := 100
	gfx.button(64, y, "1 COPY -- THE GAME", ID_COPY, LAMP_ON, PANEL)
	gfx.text(232, y + 4, "HEAR A CHARACTER, TYPE IT. 3 LIVES.", DIM)
	gfx.button(64, y + 26, "2 SEND -- A KEYER", ID_SEND, TEXT, PANEL)
	gfx.text(232, y + 30, "TYPE, AND HEAR IT IN CODE.", DIM)
	gfx.button(64, y + 52, "3 BUDDY", ID_BUDDY, TEXT, PANEL)
	gfx.text(232, y + 56, "A FRIEND TYPES A MESSAGE; YOU COPY.", DIM)
	gfx.button(64, y + 82, fmt.tprintf("TAB SPEED: %s", WPM_NAMES[app.wpm_index]), ID_SPEED, DIM, PANEL)
	gfx.text(64, y + 102, "(FOR SEND AND BUDDY; THE GAME SETS ITS OWN PACE)", DIM)
	gfx.text_c(W / 2, 228, fmt.tprintf("BEST SCORE %d   BEST LEVEL %d", app.best, app.best_level), DIM)
	gfx.text_c(W / 2, 252, "TURN YOUR SOUND ON. THE LAMP SHOWS THE CODE TOO.", TEXT)
	gfx.text_c(W / 2, 272, "AFTER DONALD E. SMITH'S TUTOR, SOFTSIDE, AUGUST 1979", DIM)
}

draw_copy :: proc() {
	g := &app.g
	buddy := game.is_buddy(g)
	gfx.text(12, 8, buddy ? "BUDDY COPY" : "MORSE CODE TUTOR", CYAN)
	if buddy {
		gfx.text(140, 8, fmt.tprintf("CHARACTER %d OF %d", min(g.script_at + 1, g.script_len), g.script_len), DIM)
		gfx.text(W - 12 - gfx.text_width("RIGHT 000"), 8, fmt.tprintf("RIGHT %3d", game.buddy_right(g)), TEXT)
	} else {
		info := game.level_info(g.level)
		gfx.text(160, 8, fmt.tprintf("LEVEL %d  %.0f WPM", g.level, info.char_wpm), DIM)
		gfx.text(W - 12 - gfx.text_width("SCORE 00000"), 8, fmt.tprintf("SCORE %5d", g.score), TEXT)
		for i in 0 ..< game.LIVES {
			c: u32 = i < g.lives ? BAD : LINE
			x := 12 + i * 14
			gfx.rect(x, 22, 4, 4, c)
			gfx.rect(x + 6, 22, 4, 4, c)
			gfx.rect(x, 24, 10, 4, c)
			gfx.rect(x + 2, 28, 6, 2, c)
		}
		if g.streak >= 5 {gfx.text(60, 22, fmt.tprintf("STREAK %d  x%d", g.streak, 1 + min(g.streak / 5, 3)), LAMP_ON)}
		// Progress through the level.
		for i in 0 ..< game.PER_LEVEL {
			gfx.rect(W - 12 - (game.PER_LEVEL - i) * 10, 22, 8, 6, i < g.right ? GOOD : PANEL)
		}
	}

	cx, cy := W / 2, 80
	on := g.phase == .Sending && game.keyed(&g.tx, g.timer * 1000)
	lamp(cx, cy, on)

	#partial switch g.phase {
	case .Ready:
		gfx.text_c(cx, 124, "LISTEN...", DIM)
	case .Sending:
		gfx.text_c(cx, 124, "LISTEN...", TEXT)
	case .Waiting:
		gfx.text_c(cx, 124, "WHAT WAS IT?", TEXT)
		frac := 1 - g.timer / game.reply_seconds(g)
		gfx.rect(cx - 80, 138, 160, 4, PANEL)
		gfx.rect(cx - 80, 138, int(160 * clamp(frac, 0, 1)), 4, frac < 0.3 ? BAD : LAMP_ON)
		if !g.replayed {gfx.text_c(cx, 148, "SPACE HEARS IT AGAIN (NO SPEED BONUS)", DIM)}
	case .Result:
		code := game.code_for(g.current)
		if g.answered == g.current {
			gfx.text_c(cx, 120, fmt.tprintf("RIGHT!  +%d", g.gained), GOOD, 2)
		} else if g.answered == 0 {
			gfx.text_c(cx, 120, "TOO SLOW", BAD, 2)
		} else {
			gfx.text_c(cx, 120, fmt.tprintf("NOT %c", rune(g.answered)), BAD, 2)
		}
		gfx.text_c(cx - 24, 142, fmt.tprintf("IT WAS %c", rune(g.current)), TEXT)
		draw_code(cx + 16, 145, code, LAMP_ON)
	case .Level_Up:
		gfx.text_c(cx, 120, fmt.tprintf("LEVEL %d", g.level), LAMP_ON, 2)
		chars := game.level_chars(g.level)
		if len(chars) >= 2 {
			a, b := chars[len(chars) - 2], chars[len(chars) - 1]
			gfx.text(cx - 80, 144, fmt.tprintf("NEW: %c", rune(a)), TEXT)
			draw_code(cx - 24, 147, game.code_for(a), LAMP_ON)
			gfx.text(cx + 24, 144, fmt.tprintf("%c", rune(b)), TEXT)
			draw_code(cx + 40, 147, game.code_for(b), LAMP_ON)
		}
	}

	// The characters in play: a chart and a keyboard for taps.
	chars: string
	if buddy {
		chars = "ETANIMSOURDKGWHVFLBYPCXQZJ1234567890.,?/="
	} else {
		chars = game.level_chars(g.level)
	}
	draw_char_keys(chars, 170)
	x := 12
	x += gfx.button(x, H - 20, "SPACE REPLAY", ID_REPLAY, TEXT, PANEL) + 6
	x += gfx.button(x, H - 20, app.chart ? "TAB HIDE CODES" : "TAB SHOW CODES", ID_CHART, TEXT, PANEL) + 6
	gfx.button(x, H - 20, "ESC MENU", ID_MENU, DIM, PANEL)
}

draw_char_keys :: proc(chars: string, top: int) {
	per_row := 14
	kw := 34
	kh := app.chart ? 24 : 18
	rows := (len(chars) + per_row - 1) / per_row
	for i in 0 ..< len(chars) {
		c := chars[i]
		row := i / per_row
		col := i % per_row
		in_row := row == rows - 1 ? len(chars) - row * per_row : per_row
		x := W / 2 - in_row * kw / 2 + col * kw
		y := top + row * (kh + 4)
		gfx.rect(x + 1, y, kw - 3, kh, PANEL)
		gfx.frame(x + 1, y, kw - 3, kh, LINE)
		gfx.text(x + 13, y + 4, char_str(c), TEXT)
		if app.chart {
			code := game.code_for(c)
			draw_code(x + kw / 2 - code_width(code) / 2, y + 16, code, LAMP_ON)
		}
		gfx.zone(x, y, kw, kh + 2, ID_CHAR + int(c))
	}
}

draw_send :: proc() {
	gfx.text(12, 8, "SEND -- A KEYER", CYAN)
	gfx.text(W - 12 - gfx.text_width(WPM_NAMES[app.wpm_index]), 8, WPM_NAMES[app.wpm_index], DIM)
	gfx.text(12, 22, "TYPE ANYTHING; IT GOES OUT IN CODE. TAB CHANGES SPEED.", DIM)
	on := game.keyed(&app.key_tx, app.key_timer * 1000)
	lamp(W / 2, 76, on)
	// The line sent so far, newest at the right, each with its code.
	s := string(app.sent[:app.sent_len])
	x0 := W / 2 - len(s) * 12 / 2
	for i in 0 ..< len(s) {
		c := s[i]
		x := x0 + i * 12
		last := i == len(s) - 1
		gfx.text(x + 2, 120, char_str(c), last ? LAMP_ON : TEXT)
	}
	if app.sent_len > 0 && app.key_char != ' ' {
		code := game.code_for(app.key_char)
		draw_code(W / 2 - code_width(code, 3) / 2, 140, code, LAMP_ON, 3)
	}
	if app.q_len > 0 {gfx.text_c(W / 2, 154, fmt.tprintf("%d WAITING", app.q_len), DIM)}
	draw_char_keys("ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890.,?/=", 168)
	x := 12
	x += gfx.button(x, H - 20, "SPACE", ID_CHAR + ' ', TEXT, PANEL) + 6
	x += gfx.button(x, H - 20, "TAB SPEED", ID_SPEED, TEXT, PANEL) + 6
	gfx.button(x, H - 20, "ESC MENU", ID_MENU, DIM, PANEL)
}

draw_buddy_entry :: proc() {
	gfx.text(12, 8, "BUDDY -- ENTER A MESSAGE", CYAN)
	gfx.text(12, 24, "HAVE A FRIEND TYPE A ONE-LINE MESSAGE (NO PEEKING!),", DIM)
	gfx.text(12, 36, "THEN PRESS ENTER. YOU COPY IT ONE CHARACTER AT A TIME.", DIM)
	stars := make([]u8, app.msg_len, context.temp_allocator)
	for i in 0 ..< app.msg_len {stars[i] = app.message[i] == ' ' ? ' ' : '*'}
	gfx.text(24, 64, string(stars), LAMP_ON)
	if int(app.t * 2) % 2 == 0 {gfx.rect(24 + app.msg_len * 8, 64, 7, 8, TEXT)}
	gfx.text(24, 80, fmt.tprintf("%d/%d", app.msg_len, len(app.message)), DIM)
	gfx.button(24, 100, fmt.tprintf("TAB SPEED: %s", WPM_NAMES[app.wpm_index]), ID_SPEED, DIM, PANEL)
	draw_char_keys("ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890.,?/=", 140)
	x := 12
	x += gfx.button(x, H - 20, "SPACE", ID_SPACE, TEXT, PANEL) + 6
	x += gfx.button(x, H - 20, "DELETE", ID_DEL, TEXT, PANEL) + 6
	x += gfx.button(x, H - 20, "ENTER START", ID_DONE, LAMP_ON, PANEL) + 6
	gfx.button(x, H - 20, "ESC MENU", ID_MENU, DIM, PANEL)
}

draw_over :: proc() {
	g := &app.g
	if game.is_buddy(g) {
		gfx.text_c(W / 2, 40, "MESSAGE COPIED", CYAN, 2)
		gfx.text_c(W / 2, 70, fmt.tprintf("%d OF %d RIGHT", game.buddy_right(g), g.script_len), TEXT)
		x0 := W / 2 - g.script_len * 10 / 2
		for i in 0 ..< g.script_len {
			gfx.text(x0 + i * 10, 96, char_str(g.script[i]), g.marks[i] ? GOOD : BAD)
		}
	} else {
		gfx.text_c(W / 2, 36, "OUT OF LIVES", BAD, 2)
		gfx.text_c(W / 2, 66, fmt.tprintf("SCORE %d", g.score), TEXT, 2)
		gfx.text_c(W / 2, 92, fmt.tprintf("REACHED LEVEL %d  --  BEST STREAK %d", g.level, g.best_streak), DIM)
		gfx.text_c(W / 2, 106, fmt.tprintf("CHARACTERS LEARNED: %s", game.level_chars(g.level)), DIM)
		if app.new_best {gfx.text_c(W / 2, 122, "NEW BEST!", GOOD)}
	}
	if app.t > 0.8 {
		gfx.button(W / 2 - 110, 150, "ENTER AGAIN", ID_AGAIN, LAMP_ON, PANEL)
		gfx.button(W / 2 + 20, 150, "ESC MENU", ID_MENU, DIM, PANEL)
	}
}
