#+build js
package main

// Elements Quiz's page: drawing, keys and taps. Rules are in ../game.

import "base:runtime"
import "core:fmt"
import "core:strconv"
import game "../game"
import "proto:gfx"

W :: 384
H :: 240

SLATE :: 0x18232b
SLATE_DARK :: 0x111a20
BENCH :: 0x3a2c22
LINE :: 0x2c3c46
WHITE :: 0xe8f0ee
DIM :: 0x8aa0a6
GLASS :: 0x9fe0d8
LIQUID :: 0x5ce0a0
YELLOW :: 0xf2d75c
GOOD :: 0x8fe08a
BAD :: 0xff7a6a
LEVEL_C := [game.Level]u32{.Easy = 0xf2d75c, .Difficult = 0x9fd0ff, .Impossible = 0xc8a0ff}

Screen :: enum {
	Title,
	Table,
	Playing,
	Over,
}

App :: struct {
	screen:   Screen,
	g:        game.Game,
	level:    game.Level,
	mode:     game.Mode,
	t:        f32,
	result_t: f32,
	best:     [game.Level][game.Mode]int,
	new_best: bool,
	sel:      int, // the element picked in the table
}

app: App

LEVEL_NAME := [game.Level]string{.Easy = "EASY", .Difficult = "DIFFICULT", .Impossible = "IMPOSSIBLE"}
MODE_NAME := [game.Mode]string {
	.Name_To_Symbol = "NAME -> SYMBOL",
	.Symbol_To_Name = "SYMBOL -> NAME",
	.Name_To_Number = "NAME -> NUMBER",
	.Number_To_Name = "NUMBER -> NAME",
}

ID_CHOICE :: 10 // + k
ID_LEVEL :: 20 // + level
ID_MODE :: 30 // + mode
ID_TABLE :: 40
ID_AGAIN :: 41
ID_MENU :: 42
ID_CELL :: 100 // + atomic number

main :: proc() {
	game.new_game(&app.g, 1, .Easy, .Name_To_Symbol)
	app.sel = 26
	buf: [32]u8
	for l in game.Level {
		for m in game.Mode {
			if v, ok := gfx.store_get(fmt.tprintf("best%d_%d", int(l), int(m)), buf[:]); ok {
				if n, nok := strconv.parse_int(v); nok && n >= 0 && n < 100000000 {app.best[l][m] = n}
			}
		}
	}
	if v, ok := gfx.store_get("level", buf[:]); ok {
		if n, nok := strconv.parse_int(v); nok && n >= 0 && n < len(game.Level) {app.level = game.Level(n)}
	}
}

set_level :: proc(l: game.Level) {
	app.level = l
	gfx.store_set("level", fmt.tprintf("%d", int(l)))
	gfx.tone(660, 40, .Square, 0.03)
}

start :: proc(mode: game.Mode) {
	app.mode = mode
	game.new_game(&app.g, u64(gfx.now_ms()) ~ u64(gfx.random() * 1e9), app.level, mode)
	app.screen = .Playing
	app.result_t = 0
	app.new_best = false
	gfx.tone(523, 80, .Sine, 0.06)
	gfx.tone(784, 80, .Sine, 0.06, 80)
	gfx.tone(1047, 160, .Sine, 0.05, 160)
}

@(export)
step :: proc(dt: f64) -> bool {
	d := f32(min(dt, 0.1))
	app.t += d
	if app.screen == .Playing {play(d)}
	draw()
	free_all(context.temp_allocator)
	return true
}

play :: proc(d: f32) {
	g := &app.g
	game.update(g, d)
	sounds()
	if g.answered {
		app.result_t += d
		right := g.picked >= 0 && g.choices[g.picked] == g.current
		wait: f32 = right ? 1.0 : 2.4
		if app.result_t >= wait {
			if g.over {
				finish()
			} else {
				game.next(g)
				app.result_t = 0
			}
		}
	} else if g.clock < 3 && int(g.clock * 10) != int((g.clock + d) * 10) && int(g.clock * 10) % 10 == 0 {
		gfx.tone(1400, 20, .Square, 0.02)
	}
}

finish :: proc() {
	g := &app.g
	if g.score > app.best[app.level][app.mode] {
		app.best[app.level][app.mode] = g.score
		app.new_best = true
		gfx.store_set(fmt.tprintf("best%d_%d", int(app.level), int(app.mode)), fmt.tprintf("%d", g.score))
	}
	app.screen = .Over
	app.t = 0
}

sounds :: proc() {
	g := &app.g
	ev := g.events
	g.events = {}
	if .Right in ev {
		f: f32 = 523 + f32(min(g.streak, 12)) * 30
		gfx.tone(f, 60, .Sine, 0.05)
		gfx.tone(f * 1.5, 120, .Sine, 0.05, 60)
		if g.streak > 0 && g.streak % game.STREAK_STEP == 0 {
			for k, i in ([?]f32{1, 1.25, 1.5, 2}) {gfx.tone(f * k, 80, .Triangle, 0.05, 200 + f32(i) * 80)}
		}
	}
	if .Wrong in ev || .Timeout in ev {
		// A flask cracks.
		gfx.noise(90, 0.08)
		gfx.tone(180, 220, .Saw, 0.04, 60)
	}
	if .Swept in ev {
		for f, i in ([?]f32{523, 659, 784, 1047, 784, 1047}) {gfx.tone(f, 120, .Square, 0.05, 500 + f32(i) * 120)}
	}
}

// ---- input ----

@(export)
on_key :: proc "c" (code: i32, down: i32) {
	context = runtime.default_context()
	if down != 1 {return}
	c := int(code)
	switch app.screen {
	case .Title:
		if c >= '1' && c <= '4' {start(game.Mode(c - '1'))}
		if c == 'E' {set_level(.Easy)}
		if c == 'D' {set_level(.Difficult)}
		if c == 'I' {set_level(.Impossible)}
		if c == gfx.KEY_LEFT && app.level > .Easy {set_level(game.Level(int(app.level) - 1))}
		if c == gfx.KEY_RIGHT && app.level < .Impossible {set_level(game.Level(int(app.level) + 1))}
		if c == 'T' {app.screen = .Table}
	case .Table:
		col, row := game.table_place(app.sel)
		switch c {
		case gfx.KEY_LEFT:
			col -= 1
		case gfx.KEY_RIGHT:
			col += 1
		case gfx.KEY_UP:
			row -= 1
		case gfx.KEY_DOWN:
			row += 1
		case gfx.KEY_ESCAPE, gfx.KEY_ENTER, 'T':
			app.screen = .Title
			return
		}
		if n := at_place(col, row); n > 0 {app.sel = n}
	case .Playing:
		if c >= '1' && c <= '4' {game.answer(&app.g, c - '1')}
		if c >= 'A' && c <= 'D' {game.answer(&app.g, c - 'A')}
		if c == gfx.KEY_ESCAPE {app.screen = .Title}
	case .Over:
		if app.t > 1 && (c == gfx.KEY_ENTER || c == gfx.KEY_SPACE) {start(app.mode)}
		if app.t > 1 && c == gfx.KEY_ESCAPE {app.screen = .Title}
	}
}

at_place :: proc(col, row: int) -> int {
	for n in 1 ..= len(game.ELEMENTS) {
		c, r := game.table_place(n)
		if c == col && r == row {return n}
	}
	return 0
}

@(export)
on_pointer :: proc "c" (x, y: f32, kind: i32) {
	context = runtime.default_context()
	if kind != 0 {return}
	id := gfx.hit(x, y)
	switch app.screen {
	case .Title:
		if id >= ID_LEVEL && id < ID_LEVEL + len(game.Level) {set_level(game.Level(id - ID_LEVEL))}
		if id >= ID_MODE && id < ID_MODE + len(game.Mode) {start(game.Mode(id - ID_MODE))}
		if id == ID_TABLE {app.screen = .Table}
	case .Table:
		if id > ID_CELL && id <= ID_CELL + len(game.ELEMENTS) {
			app.sel = id - ID_CELL
			gfx.tone(880, 25, .Sine, 0.03)
		}
		if id == ID_MENU {app.screen = .Title}
	case .Playing:
		if id >= ID_CHOICE && id < ID_CHOICE + game.CHOICES {game.answer(&app.g, id - ID_CHOICE)}
	case .Over:
		if app.t > 1 {
			if id == ID_AGAIN {start(app.mode)}
			if id == ID_MENU {app.screen = .Title}
		}
	}
}

// ---- drawing ----

draw :: proc() {
	gfx.clear(BENCH)
	gfx.begin_buttons()
	gfx.rect(4, 4, W - 8, H - 8, SLATE)
	gfx.frame(4, 4, W - 8, H - 8, LINE)
	switch app.screen {
	case .Title:
		draw_title()
	case .Table:
		draw_table()
	case .Playing:
		draw_question()
	case .Over:
		draw_over()
	}
}

draw_flask :: proc(x, y: int, full: bool) {
	gfx.rect(x + 3, y, 3, 4, GLASS) // the neck
	gfx.rect(x + 2, y, 5, 1, GLASS)
	gfx.rect(x + 1, y + 4, 7, 2, GLASS)
	gfx.rect(x, y + 6, 9, 4, GLASS)
	if full {
		gfx.rect(x + 2, y + 5, 5, 1, LIQUID)
		gfx.rect(x + 1, y + 6, 7, 3, LIQUID)
	} else {
		gfx.rect(x + 1, y + 6, 7, 3, SLATE_DARK)
		gfx.rect(x + 3, y + 7, 1, 2, BAD) // cracked
		gfx.rect(x + 4, y + 6, 1, 1, BAD)
	}
}

// A little element tile, as in a classroom chart.
draw_tile :: proc(x, y, n: int, size: int, c: u32) {
	e := game.element(n)
	w := 40 * size
	gfx.rect(x, y, w, w, SLATE_DARK)
	gfx.frame(x, y, w, w, c)
	gfx.text(x + 3, y + 3, fmt.tprintf("%d", n), DIM)
	gfx.text_c(x + w / 2, y + w / 2 - 4 * size, e.symbol, c, size + 1)
}

draw_title :: proc() {
	gfx.text_c(W / 2, 14, "ELEMENTS", GLASS, 3)
	gfx.text_c(W / 2, 40, "QUIZ", LIQUID, 2)
	// A few tiles for show.
	draw_tile(22, 14, 79, 1, LEVEL_C[.Easy])
	draw_tile(W - 62, 14, 26, 1, LEVEL_C[.Easy])
	gfx.text_c(W / 2, 64, "THE SYMBOL, THE NAME, THE NUMBER.", DIM)
	gfx.text_c(W / 2, 75, "BEAT THE CLOCK. A MISS COMES BACK", DIM)
	gfx.text_c(W / 2, 86, "LATER BUT CRACKS A FLASK. THREE FLASKS.", DIM)
	// Level.
	x := 36
	for l in game.Level {
		label := fmt.tprintf("%s %d", LEVEL_NAME[l], game.level_size(l))
		on := l == app.level
		x += gfx.button(x, 102, label, ID_LEVEL + int(l), on ? SLATE : LEVEL_C[l], on ? LEVEL_C[l] : SLATE_DARK) + 8
	}
	// Mode: starts the round.
	for m in game.Mode {
		bx := m == .Name_To_Symbol || m == .Name_To_Number ? 30 : 202
		by := 126 + (int(m) / 2) * 34
		gfx.button(bx, by, fmt.tprintf("%d: %s", int(m) + 1, MODE_NAME[m]), ID_MODE + int(m), WHITE, SLATE_DARK)
		gfx.text(bx, by + 17, fmt.tprintf("BEST %d", app.best[app.level][m]), DIM)
	}
	gfx.button(W / 2 - 44, 196, "T: THE TABLE", ID_TABLE, GLASS, SLATE_DARK)
	gfx.text_c(W / 2, 220, "AFTER ROGER W. ROBITAILLE, SR., SOFTSIDE 1979", DIM)
}

TX :: 3
TY :: 44
TS :: 21
TROW :: 14

cell_xy :: proc(n: int) -> (int, int) {
	c, r := game.table_place(n)
	y := TY + r * TROW
	if r >= 7 {y += 6}
	return TX + c * TS, y
}

draw_table :: proc() {
	e := game.element(app.sel)
	lv := game.level_of(app.sel)
	gfx.text(10, 10, fmt.tprintf("%d", app.sel), DIM)
	gfx.text(40, 8, e.symbol, LEVEL_C[lv], 2)
	gfx.text(80, 8, e.name, WHITE)
	gfx.text(80, 18, fmt.tprintf("ATOMIC WEIGHT %s", e.weight), DIM)
	gfx.text(W - 10 - gfx.text_width(LEVEL_NAME[lv]), 8, LEVEL_NAME[lv], LEVEL_C[lv])
	gfx.text(10, 30, "TAP AN ELEMENT, OR USE THE ARROWS.", DIM)
	for n in 1 ..= len(game.ELEMENTS) {
		x, y := cell_xy(n)
		l := game.level_of(n)
		sel := n == app.sel
		gfx.rect(x, y, TS - 1, TROW - 1, sel ? LEVEL_C[l] : SLATE_DARK)
		gfx.text(x + (TS - 1 - gfx.text_width(game.element(n).symbol)) / 2, y + 3, game.element(n).symbol, sel ? SLATE_DARK : LEVEL_C[l])
		gfx.zone(x, y, TS - 1, TROW - 1, ID_CELL + n)
	}
	// The f-block's place in the table.
	x5, y5 := cell_xy(57)
	_ = x5
	gfx.text(TX + 2 * TS + 4, TY + 5 * TROW + 3, "*", DIM)
	gfx.text(TX + 2 * TS + 4, TY + 6 * TROW + 3, "**", DIM)
	gfx.text(TX + 4, y5 + 3, "*", DIM)
	gfx.text(TX + 4, y5 + TROW + 3, "**", DIM)
	ly := TY + 9 * TROW + 12
	x := 10
	for l in game.Level {
		gfx.rect(x, ly, 8, 8, LEVEL_C[l])
		gfx.text(x + 12, ly, LEVEL_NAME[l], LEVEL_C[l])
		x += gfx.text_width(LEVEL_NAME[l]) + 28
	}
	gfx.button(W - 70, ly - 3, "BACK", ID_MENU, WHITE, SLATE_DARK)
}

question_words :: proc(m: game.Mode) -> string {
	switch m {
	case .Name_To_Symbol:
		return "WHAT IS ITS CHEMICAL SYMBOL?"
	case .Symbol_To_Name:
		return "IS THE SYMBOL FOR WHAT ELEMENT?"
	case .Name_To_Number:
		return "WHAT IS ITS ATOMIC NUMBER?"
	case .Number_To_Name:
		return "IS THE ATOMIC NUMBER OF WHAT ELEMENT?"
	}
	return ""
}

draw_question :: proc() {
	g := &app.g
	gfx.text(12, 10, fmt.tprintf("SCORE %d", g.score), WHITE)
	mult := game.multiplier(g.streak)
	gfx.text(12, 21, fmt.tprintf("STREAK %d", g.streak), DIM)
	if mult > 1 {gfx.text(12 + gfx.text_width("STREAK 00 "), 21, fmt.tprintf("X%d", mult), YELLOW)}
	for i in 0 ..< game.LIVES {draw_flask(W - 46 + i * 12, 9, i < g.lives)}
	left := fmt.tprintf("%d LEFT", g.deck_len)
	gfx.text(W - 12 - gfx.text_width(left), 23, left, DIM)
	gfx.text_c(W / 2, 10, LEVEL_NAME[g.level], LEVEL_C[g.level])

	full := W - 24
	gfx.rect(12, 34, full, 2, SLATE_DARK)
	gfx.rect(12, 34, int(f32(full) * g.clock / game.TIME_LIMIT), 2, g.clock < 3 ? BAD : LIQUID)

	buf: [8]u8
	clue := game.clue(g, buf[:])
	size := len(clue) <= 3 ? 3 : 2
	gfx.text_c(W / 2, size == 3 ? 46 : 50, clue, YELLOW, size)
	gfx.text_c(W / 2, 76, question_words(g.mode), WHITE)

	right_k := game.correct_choice(g)
	for k in 0 ..< game.CHOICES {
		y := 90 + k * 26
		bw := 240
		x := (W - bw) / 2
		fg: u32 = WHITE
		bg: u32 = SLATE_DARK
		if g.answered {
			if k == right_k {fg, bg = SLATE, GOOD} else if k == g.picked {fg, bg = SLATE, BAD} else {fg = DIM}
		}
		gfx.rect(x, y, bw, 20, bg)
		gfx.frame(x, y, bw, 20, fg)
		gfx.text(x + 8, y + 6, fmt.tprintf("%d", k + 1), fg)
		cbuf: [8]u8
		gfx.text(x + 28, y + 6, game.choice_text(g, k, cbuf[:]), fg)
		if !g.answered {gfx.zone(x, y, bw, 20, ID_CHOICE + k)}
	}
	if g.answered {
		e := game.element(g.current)
		card := fmt.tprintf("%d  %s  %s  %s", g.current, e.symbol, e.name, e.weight)
		if g.picked >= 0 && g.choices[g.picked] == g.current {
			gfx.text_c(W / 2, 200, fmt.tprintf("C O R R E C T !   +%d", g.last_gain), GOOD)
		} else {
			gfx.text_c(W / 2, 200, g.picked < 0 ? "TIME'S UP. IT COMES BACK LATER." : "NO. IT COMES BACK LATER.", BAD)
		}
		gfx.text_c(W / 2, 214, card, DIM)
	}
}

draw_over :: proc() {
	g := &app.g
	swept := g.deck_len == 0
	gfx.text_c(W / 2, 14, swept ? "THE WHOLE TABLE!" : "OUT OF FLASKS", swept ? YELLOW : WHITE, 2)
	gfx.text_c(W / 2, 40, fmt.tprintf("SCORE %d", g.score), WHITE, 2)
	done := g.total - g.deck_len
	gfx.text_c(W / 2, 64, fmt.tprintf("%d OF %d ANSWERED, %d RIGHT FIRST TIME", done, g.total, g.right), DIM)
	gfx.text_c(W / 2, 75, fmt.tprintf("THAT'S %d%%.  LONGEST STREAK %d", g.right * 100 / g.total, g.best_streak), DIM)
	if swept {gfx.text_c(W / 2, 86, fmt.tprintf("FLASKS LEFT %d  +%d", g.lives, g.lives * game.SWEEP_BONUS), GOOD)}
	if app.new_best {gfx.text_c(W / 2, 97, "NEW BEST!", GOOD)}
	// The ones missed, to study.
	gfx.text(16, 112, "TO STUDY:", WHITE)
	x, y := 16, 124
	any := false
	for n in 1 ..= len(game.ELEMENTS) {
		if !g.missed[n] {continue}
		any = true
		e := game.element(n)
		s := fmt.tprintf("%s %s", e.symbol, e.name)
		if x + gfx.text_width(s) > W - 16 {
			x = 16
			y += 10
		}
		if y > 168 {break}
		gfx.text(x, y, s, LEVEL_C[game.level_of(n)])
		x += gfx.text_width(s) + 12
	}
	if !any {gfx.text(16, 124, "NOTHING. YOU GOT THE LEAD OUT!", GOOD)}
	if app.t > 1 {
		gfx.button(W / 2 - 92, 190, "PLAY AGAIN", ID_AGAIN, WHITE, SLATE_DARK)
		gfx.button(W / 2 + 20, 190, "TITLE", ID_MENU, DIM, SLATE_DARK)
	}
}
