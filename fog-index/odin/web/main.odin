#+build js
package main

// Fog Index's page: type or paste text (long words light up as you go), try a sample, or count by
// hand as in 1979; then the General test, the Acid test and the listing's table. Rules are in ../game.

import "base:runtime"
import "core:fmt"
import fog "../game"
import "proto:gfx"

W :: 384
H :: 240

BG :: 0x182026
PAPER :: 0x0e1418
EDGE :: 0x34444e
INK :: 0xd8e2e8
DIM :: 0x7c8a94
FAINT :: 0x3c4a54
LONG :: 0xffc85a
ACCENT :: 0x8fd0ff
GOOD :: 0x8fe0a0
BTN :: 0x24323a

MAX_TEXT :: 6000
COLS :: 45
TX :: 10 // text area
TY :: 30
ROWS :: 16
LINE_H :: 10

Mode :: enum {
	Menu,
	Edit,
	Samples,
	Hand,
	Result,
}

ID_TYPE :: 1
ID_SAMPLES :: 2
ID_HAND :: 3
ID_MENU :: 4
ID_RATE :: 5
ID_CLEAR :: 6
ID_BACK :: 7
ID_NEXT :: 8
ID_DEL :: 9
ID_UP :: 10
ID_DOWN :: 11
ID_SAMPLE :: 100 // + sample
ID_DIGIT :: 200 // + digit
ID_CELL :: 300 // + cell (sentence*2 + column)

App :: struct {
	mode:        Mode,
	text:        [MAX_TEXT]u8,
	n:           int,
	scroll:      int, // lines up from the end
	clear_armed: f32,
	dirty:       bool,
	save_t:      f32,
	t:           f32,
	last_key:    f32,
	// counting by hand: words and long words for five sentences
	cells:       [fog.TEST_SENTENCES * 2]int,
	filled:      [fog.TEST_SENTENCES * 2]bool,
	cell:        int,
	// the last rating
	from_hand:   bool,
	a:           fog.Analysis,
	general:     int,
	general_n:   int,
	acid:        int,
	acid_n:      int,
	picks:       [fog.TEST_SENTENCES]int,
	whole:       f64,
}

app: App
store_buf: [MAX_TEXT + 16]u8

main :: proc() {
	if s, ok := gfx.store_get("text", store_buf[:]); ok {
		n := min(len(s), MAX_TEXT)
		copy(app.text[:], s[:n])
		app.n = n
	}
}

text_str :: proc() -> string {return string(app.text[:app.n])}

@(export)
step :: proc(dt: f64) -> bool {
	d := f32(min(dt, 0.1))
	app.t += d
	app.clear_armed = max(0, app.clear_armed - d)
	if app.dirty {
		app.save_t += d
		if app.save_t > 1 {
			gfx.store_set("text", text_str())
			app.dirty = false
		}
	}
	draw()
	free_all(context.temp_allocator)
	return true
}

changed :: proc() {
	app.dirty = true
	app.save_t = 0
	app.scroll = 0
}

insert :: proc(c: u8) {
	if app.n >= MAX_TEXT {return}
	if c == ' ' && (app.n == 0 || app.text[app.n - 1] == ' ') {return}
	app.text[app.n] = c
	app.n += 1
	changed()
	if app.t - app.last_key > 0.06 {gfx.tone(c == ' ' ? 900 : 1300, 8, .Square, 0.012)}
	app.last_key = app.t
}

load_sample :: proc(i: int) {
	s := fog.SAMPLES[i].text
	app.n = 0
	for k in 0 ..< min(len(s), MAX_TEXT) {
		c := s[k]
		app.text[app.n] = c >= 'a' && c <= 'z' ? c - 32 : c
		app.n += 1
	}
	changed()
	gfx.tone(660, 40, .Triangle, 0.05)
	gfx.tone(880, 60, .Triangle, 0.05, 50)
	rate_text()
}

rate_text :: proc() {
	fog.analyse(&app.a, text_str())
	if app.a.count == 0 {
		gfx.tone(140, 80, .Square, 0.04)
		return
	}
	app.from_hand = false
	app.general, app.general_n = fog.general_test(&app.a)
	app.acid, app.acid_n = fog.acid_test(&app.a, &app.picks)
	app.whole = fog.gunning(&app.a)
	app.mode = .Result
	chime()
}

rate_hand :: proc() {
	w, h: [fog.TEST_SENTENCES]int
	for k in 0 ..< fog.TEST_SENTENCES {
		if !app.filled[k * 2] || app.cells[k * 2] == 0 {
			app.cell = k * 2
			gfx.tone(140, 80, .Square, 0.04)
			return
		}
		w[k] = app.cells[k * 2]
		h[k] = min(app.cells[k * 2 + 1], w[k])
	}
	app.from_hand = true
	app.general = fog.listing_index(w[:], h[:])
	app.general_n = fog.TEST_SENTENCES
	app.mode = .Result
	chime()
}

chime :: proc() {
	gfx.tone(523, 70, .Triangle, 0.05)
	gfx.tone(659, 70, .Triangle, 0.05, 80)
	gfx.tone(784, 120, .Triangle, 0.05, 160)
}

hand_digit :: proc(dg: int) {
	c := app.cell
	if !app.filled[c] {app.cells[c] = 0}
	if app.cells[c] >= 100 {gfx.tone(140, 60, .Square, 0.04); return}
	app.cells[c] = app.cells[c] * 10 + dg
	app.filled[c] = true
	gfx.tone(1000, 15, .Square, 0.03)
}

hand_del :: proc() {
	c := app.cell
	app.cells[c] /= 10
	if app.cells[c] == 0 {app.filled[c] = false}
	gfx.tone(700, 15, .Square, 0.03)
}

hand_next :: proc() {
	if app.cell + 1 < len(app.cells) {
		app.cell += 1
		gfx.tone(800, 15, .Square, 0.03)
	} else {
		rate_hand()
	}
}

go :: proc(m: Mode) {
	app.mode = m
	app.clear_armed = 0
	if m == .Hand {app.cell = 0}
	gfx.tone(600, 25, .Square, 0.03)
}

click :: proc(id: int) {
	switch {
	case id >= ID_CELL:
		app.cell = id - ID_CELL
		gfx.tone(800, 15, .Square, 0.03)
	case id >= ID_DIGIT:
		hand_digit(id - ID_DIGIT)
	case id >= ID_SAMPLE:
		load_sample(id - ID_SAMPLE)
	case id == ID_TYPE:
		go(.Edit)
	case id == ID_SAMPLES:
		go(.Samples)
	case id == ID_HAND:
		go(.Hand)
	case id == ID_MENU:
		go(.Menu)
	case id == ID_RATE:
		if app.mode == .Hand {rate_hand()} else {rate_text()}
	case id == ID_CLEAR:
		if app.clear_armed > 0 {
			app.n = 0
			app.clear_armed = 0
			changed()
			gfx.noise(120, 0.05)
		} else {
			app.clear_armed = 2.5
			gfx.tone(300, 40, .Square, 0.04)
		}
	case id == ID_BACK:
		go(app.from_hand ? .Hand : .Edit)
	case id == ID_NEXT:
		hand_next()
	case id == ID_DEL:
		hand_del()
	case id == ID_UP:
		app.scroll += 3
	case id == ID_DOWN:
		app.scroll = max(0, app.scroll - 3)
	}
}

// ---- input ----

@(export)
on_key :: proc "c" (code: i32, down: i32) {
	context = runtime.default_context()
	if down == 0 {return}
	c := int(code)
	switch app.mode {
	case .Menu:
		switch c {
		case '1', gfx.KEY_ENTER, 'T':
			if down == 1 {click(ID_TYPE)}
		case '2', 'S':
			if down == 1 {click(ID_SAMPLES)}
		case '3', 'H':
			if down == 1 {click(ID_HAND)}
		}
	case .Edit:
		switch c {
		case 32 ..= 126:
			insert(u8(c))
		case gfx.KEY_BACKSPACE, gfx.KEY_DELETE:
			if app.n > 0 {app.n -= 1; changed()}
		case gfx.KEY_ENTER:
			if down == 1 {rate_text()}
		case gfx.KEY_ESCAPE:
			if down == 1 {click(ID_MENU)}
		case gfx.KEY_UP:
			app.scroll += 1
		case gfx.KEY_DOWN:
			app.scroll = max(0, app.scroll - 1)
		}
	case .Samples:
		switch c {
		case '1' ..= '9':
			i := c - '1'
			if down == 1 && i < len(fog.SAMPLES) {click(ID_SAMPLE + i)}
		case gfx.KEY_ESCAPE, 'M':
			if down == 1 {click(ID_MENU)}
		}
	case .Hand:
		switch c {
		case '0' ..= '9':
			if down == 1 {hand_digit(c - '0')}
		case gfx.KEY_BACKSPACE, gfx.KEY_DELETE:
			hand_del()
		case gfx.KEY_ENTER, gfx.KEY_TAB, gfx.KEY_SPACE:
			if down == 1 {hand_next()}
		case gfx.KEY_RIGHT:
			app.cell = min(app.cell + 1, len(app.cells) - 1)
		case gfx.KEY_LEFT:
			app.cell = max(app.cell - 1, 0)
		case gfx.KEY_DOWN:
			app.cell = min(app.cell + 2, len(app.cells) - 1)
		case gfx.KEY_UP:
			app.cell = max(app.cell - 2, 0)
		case gfx.KEY_ESCAPE:
			if down == 1 {click(ID_MENU)}
		case 'R':
			if down == 1 {rate_hand()}
		}
	case .Result:
		switch c {
		case gfx.KEY_ENTER, 'E', gfx.KEY_BACKSPACE:
			if down == 1 {click(ID_BACK)}
		case gfx.KEY_ESCAPE, 'M':
			if down == 1 {click(ID_MENU)}
		}
	}
}

@(export)
on_pointer :: proc "c" (x, y: f32, kind: i32) {
	context = runtime.default_context()
	if kind != 0 {return}
	id := gfx.hit(x, y)
	if id > 0 {click(id)}
}

// ---- drawing ----

draw :: proc() {
	gfx.clear(BG)
	gfx.begin_buttons()
	switch app.mode {
	case .Menu:
		draw_menu()
	case .Edit:
		draw_edit()
	case .Samples:
		draw_samples()
	case .Hand:
		draw_hand()
	case .Result:
		draw_result()
	}
}

// Drifting fog bands behind the title.
draw_fog :: proc(y0, h: int) {
	for k in 0 ..< 6 {
		y := y0 + k * h / 6
		off := int(app.t * f32(6 + k * 3)) % 96
		for x := -96 + off; x < W; x += 96 {
			gfx.rect(x, y, 60 + k * 4, 3, k % 2 == 0 ? 0x1f2a31 : 0x22303a)
		}
	}
}

draw_menu :: proc() {
	draw_fog(10, 60)
	gfx.text_c(W / 2, 24, "FOG INDEX", INK, 3)
	gfx.text_c(W / 2, 54, "CAN YOU SEE THROUGH THIS?", ACCENT)
	gfx.text_c(W / 2, 80, "HOW HARD IS YOUR WRITING TO READ?", DIM)
	gfx.text_c(W / 2, 92, "THE INDEX IS ABOUT THE SCHOOL GRADE", DIM)
	gfx.text_c(W / 2, 104, "A READER NEEDS TO FOLLOW IT.", DIM)
	labels := [3]string{"1 TYPE OR PASTE TEXT", "2 TRY A SAMPLE", "3 COUNT BY HAND (1979)"}
	ids := [3]int{ID_TYPE, ID_SAMPLES, ID_HAND}
	for l, i in labels {
		w := gfx.text_width(l) + 8
		gfx.button(W / 2 - w / 2, 124 + i * 22, l, ids[i], INK, BTN)
	}
	gfx.text_c(W / 2, 200, "AFTER \"FOG INDEX\" BY REV. GEORGE BLANK", DIM)
	gfx.text_c(W / 2, 212, "(SOFTSIDE, MARCH 1979)", DIM)
}

Line :: struct {
	start, end: int,
}

wrap :: proc(s: string) -> [dynamic]Line {
	lines := make([dynamic]Line, context.temp_allocator)
	i := 0
	for i < len(s) {
		for i < len(s) && s[i] == ' ' {i += 1}
		if i >= len(s) {break}
		end := min(i + COLS, len(s))
		if end < len(s) && s[end] != ' ' {
			k := end
			for k > i && s[k] != ' ' {k -= 1}
			if k > i {end = k}
		}
		append(&lines, Line{i, end})
		i = end
	}
	return lines
}

draw_words :: proc(s: string, x0, y: int) {
	i := 0
	for i < len(s) {
		if s[i] == ' ' {i += 1; continue}
		j := i
		for j < len(s) && s[j] != ' ' {j += 1}
		word := s[i:j]
		gfx.text(x0 + i * gfx.CELL, y, word, fog.is_hard(word) ? LONG : INK)
		i = j
	}
}

draw_edit :: proc() {
	gfx.text(TX, 8, "TYPE OR PASTE YOUR TEXT", ACCENT)
	fog.analyse(&app.a, text_str())
	gfx.text(TX, 18, fmt.tprintf("%d SENTENCES  %d WORDS  ", app.a.count, app.a.words), DIM)
	lx := TX + gfx.text_width(fmt.tprintf("%d SENTENCES  %d WORDS  ", app.a.count, app.a.words))
	gfx.text(lx, 18, fmt.tprintf("%d LONG", app.a.hard), LONG)
	gfx.rect(TX - 4, TY - 4, COLS * gfx.CELL + 8, ROWS * LINE_H + 6, PAPER)
	gfx.frame(TX - 4, TY - 4, COLS * gfx.CELL + 8, ROWS * LINE_H + 6, EDGE)
	s := text_str()
	lines := wrap(s)
	first := max(0, len(lines) - ROWS - app.scroll)
	app.scroll = max(0, min(app.scroll, len(lines) - ROWS))
	if app.n == 0 {
		gfx.text(TX, TY + LINE_H, "TYPE HERE, OR PASTE (CTRL+V, OR THE", FAINT)
		gfx.text(TX, TY + LINE_H * 2, "\"PASTE TEXT\" LINK BELOW). WORDS OF", FAINT)
		gfx.text(TX, TY + LINE_H * 3, "THREE SYLLABLES OR MORE LIGHT UP.", FAINT)
		gfx.text(TX, TY + LINE_H * 5, "THEN PRESS ENTER OR \"RATE IT\".", FAINT)
	}
	cx, cy := TX, TY
	for li in first ..< min(len(lines), first + ROWS) {
		l := lines[li]
		y := TY + (li - first) * LINE_H
		draw_words(s[l.start:l.end], TX, y)
		cx, cy = TX + (l.end - l.start) * gfx.CELL, y
	}
	if len(lines) > 0 && app.n > 0 && s[app.n - 1] == ' ' {cx += gfx.CELL}
	if len(lines) > 0 && cx >= TX + COLS * gfx.CELL {cx, cy = TX, cy + LINE_H}
	if app.scroll == 0 && int(app.t * 2) % 2 == 0 && cy < TY + ROWS * LINE_H {gfx.rect(cx, cy, 7, 8, ACCENT)}
	if len(lines) > ROWS {
		gfx.button(W - 16, TY - 4, "^", ID_UP, DIM, BTN)
		gfx.button(W - 16, TY + ROWS * LINE_H - 14, "v", ID_DOWN, DIM, BTN)
	}
	by := 202
	x := TX - 4
	x += gfx.button(x, by, "RATE IT", ID_RATE, app.a.count > 0 ? GOOD : DIM, BTN) + 6
	x += gfx.button(x, by, app.clear_armed > 0 ? "SURE? CLEAR" : "CLEAR", ID_CLEAR, app.clear_armed > 0 ? LONG : INK, BTN) + 6
	gfx.button(x, by, "MENU", ID_MENU, INK, BTN)
	gfx.text(TX, 224, "ENTER RATES IT, ESC IS THE MENU", FAINT)
}

draw_samples :: proc() {
	draw_fog(8, 30)
	gfx.text_c(W / 2, 12, "TRY A SAMPLE", ACCENT, 2)
	gfx.text_c(W / 2, 40, "PUBLIC-DOMAIN PASSAGES, EASY TO HARD", DIM)
	for s, i in fog.SAMPLES {
		gfx.button(40, 64 + i * 30, fmt.tprintf("%d %s", i + 1, s.name), ID_SAMPLE + i, INK, BTN)
	}
	gfx.text(40, 160, "THE ARTICLE: THE SERMON ON THE MOUNT", FAINT)
	gfx.text(40, 170, "READS AT THE EIGHTH GRADE.", FAINT)
	gfx.text(40, 180, "A SAMPLE REPLACES YOUR TEXT.", FAINT)
	gfx.button(40, 202, "MENU", ID_MENU, INK, BTN)
}

draw_hand :: proc() {
	gfx.text(TX, 8, "COUNT BY HAND, THE 1979 WAY", ACCENT)
	gfx.text(TX, 22, "PICK FIVE SENTENCES. FOR EACH, COUNT THE", DIM)
	gfx.text(TX, 32, "WORDS AND THE WORDS OF 3+ SYLLABLES.", DIM)
	gfx.text(TX + 120, 48, "WORDS", INK)
	gfx.text(TX + 200, 48, "3+ SYLL.", LONG)
	for k in 0 ..< fog.TEST_SENTENCES {
		y := 60 + k * 18
		gfx.text(TX, y + 4, fmt.tprintf("SENTENCE %d", k + 1), INK)
		for col in 0 ..< 2 {
			c := k * 2 + col
			x := TX + 116 + col * 80
			sel := c == app.cell
			gfx.rect(x, y, 56, 15, sel ? 0x2c4452 : PAPER)
			gfx.frame(x, y, 56, 15, sel ? ACCENT : EDGE)
			if app.filled[c] {
				gfx.text(x + 52 - gfx.text_width(fmt.tprintf("%d", app.cells[c])), y + 4, fmt.tprintf("%d", app.cells[c]), col == 0 ? INK : LONG)
			}
			if sel && int(app.t * 2) % 2 == 0 {gfx.rect(x + 53, y + 3, 1, 9, ACCENT)}
			gfx.zone(x, y, 56, 15, ID_CELL + c)
		}
	}
	// keypad
	kx := TX - 4
	for dg in 0 ..< 10 {
		lbl := fmt.tprintf("%d", (dg + 1) % 10)
		gfx.button(kx + dg * 26, 154, lbl, ID_DIGIT + (dg + 1) % 10, INK, BTN, 1)
	}
	gfx.button(kx + 10 * 26, 154, "DEL", ID_DEL, INK, BTN)
	gfx.button(kx + 10 * 26 + 36, 154, "NEXT", ID_NEXT, INK, BTN)
	by := 202
	x := TX - 4
	x += gfx.button(x, by, "RATE IT", ID_RATE, GOOD, BTN) + 6
	gfx.button(x, by, "MENU", ID_MENU, INK, BTN)
	gfx.text(TX, 180, "THE LISTING'S SUM: 0.4 X (WORDS + LONG", FAINT)
	gfx.text(TX, 190, "WORDS) PER SENTENCE.", FAINT)
}

draw_result :: proc() {
	gfx.text(TX, 8, "THE FOG INDEX", ACCENT)
	y := 22
	if app.from_hand {
		big(y, "YOUR FIVE SENTENCES", app.general)
		y += 44
	} else {
		big(y, app.general_n == fog.TEST_SENTENCES ? "GENERAL TEST: THE FIRST FIVE SENTENCES" : fmt.tprintf("GENERAL TEST: %d SENTENCES (FIVE IS BEST)", app.general_n), app.general)
		y += 40
		big(y, app.acid_n == fog.TEST_SENTENCES ? "ACID TEST: THE FIVE HARDEST SENTENCES" : "ACID TEST: THE HARDEST SENTENCES", app.acid)
		y += 38
		gfx.text(TX, y, fmt.tprintf("WHOLE TEXT BY GUNNING'S FORMULA: %.1f", app.whole), DIM)
		y += 10
		gfx.text(TX, y, fmt.tprintf("%d SENTENCES, %d WORDS, %d LONG", app.a.count, app.a.words, app.a.hard), FAINT)
		y += 14
	}
	gfx.text(TX, y, "TYPICAL VALUES", INK)
	y += 11
	near := 0
	for l, i in fog.LEVELS {
		if abs(l.grade - app.general) < abs(fog.LEVELS[near].grade - app.general) {near = i}
	}
	for l, i in fog.LEVELS {
		col: u32 = i == near ? LONG : DIM
		if i == near {gfx.text(TX - 2, y, ">", LONG)}
		gfx.text(TX + 8, y, fmt.tprintf("%2d %s - %s", l.grade, l.name, l.note), col)
		y += 10
	}
	gfx.text(TX, y + 2, "ABOUT THE SAME AS THE SCHOOL GRADE LEVEL.", FAINT)
	by := 214
	x := TX - 4
	x += gfx.button(x, by, app.from_hand ? "COUNT AGAIN" : "EDIT TEXT", ID_BACK, INK, BTN) + 6
	gfx.button(x, by, "MENU", ID_MENU, INK, BTN)
}

big :: proc(y: int, label: string, index: int) {
	gfx.text(TX, y, label, DIM)
	gfx.text(TX, y + 12, fmt.tprintf("%d", index), index <= 8 ? GOOD : (index <= 12 ? INK : LONG), 3)
	gfx.text(TX + 64, y + 20, fog.grade_name(index), INK)
}
