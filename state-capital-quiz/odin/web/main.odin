#+build js
package main

// State Capital Quiz's page: drawing, keys and taps. Rules are in ../game.

import "base:runtime"
import "core:fmt"
import "core:strconv"
import game "../game"
import "proto:gfx"

W :: 384
H :: 240

BOARD :: 0x1f3a2c
BOARD_DARK :: 0x183024
FRAME :: 0x8a5a2e
FRAME_LIT :: 0xb07a44
CHALK :: 0xeef0e6
CHALK_DIM :: 0x9fb3a4
YELLOW :: 0xf2d75c
GOOD :: 0x8fe08a
BAD :: 0xff7a6a
APPLE :: 0xe0443a

Screen :: enum {
	Title,
	Playing,
	Over,
}

App :: struct {
	screen:   Screen,
	g:        game.Game,
	mode:     game.Mode,
	t:        f32,
	result_t: f32, // how long the current result has shown
	best:     [game.Mode]int,
	new_best: bool,
}

app: App

ID_CHOICE :: 10 // + k
ID_MODE :: 20 // + mode
ID_AGAIN :: 30
ID_MENU :: 31

main :: proc() {
	game.new_game(&app.g, 1, .Capital_To_State)
	buf: [32]u8
	for m in game.Mode {
		if v, ok := gfx.store_get(fmt.tprintf("best%d", int(m)), buf[:]); ok {
			if n, nok := strconv.parse_int(v); nok && n >= 0 && n < 10000000 {app.best[m] = n}
		}
	}
}

start :: proc(mode: game.Mode) {
	app.mode = mode
	game.new_game(&app.g, u64(gfx.now_ms()) ~ u64(gfx.random() * 1e9), mode)
	app.screen = .Playing
	app.result_t = 0
	app.new_best = false
	bell()
}

bell :: proc() {
	gfx.tone(784, 90, .Sine, 0.06)
	gfx.tone(1047, 160, .Sine, 0.05, 90)
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
		wait: f32 = right ? 0.9 : 2.0
		if app.result_t >= wait {
			if g.over {
				finish()
			} else {
				game.next(g)
				app.result_t = 0
			}
		}
	} else if g.clock < 3 && int(g.clock * 10) != int((g.clock + d) * 10) && int(g.clock * 10) % 10 == 0 {
		gfx.tone(1400, 20, .Square, 0.02) // the last seconds tick
	}
}

finish :: proc() {
	g := &app.g
	if g.score > app.best[app.mode] {
		app.best[app.mode] = g.score
		app.new_best = true
		gfx.store_set(fmt.tprintf("best%d", int(app.mode)), fmt.tprintf("%d", g.score))
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
		gfx.tone(f, 70, .Square, 0.04)
		gfx.tone(f * 1.25, 110, .Square, 0.04, 70)
		if g.streak > 0 && g.streak % game.STREAK_STEP == 0 && game.multiplier(g.streak) <= game.MAX_MULT {
			for k, i in ([?]f32{1, 1.25, 1.5, 2}) {gfx.tone(f * k, 80, .Triangle, 0.05, 200 + f32(i) * 80)}
		}
	}
	if .Wrong in ev || .Timeout in ev {
		gfx.tone(196, 160, .Saw, 0.05)
		gfx.tone(147, 260, .Saw, 0.05, 150)
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
		if c == '1' || c == gfx.KEY_ENTER || c == gfx.KEY_SPACE {start(.Capital_To_State)}
		if c == '2' {start(.State_To_Capital)}
	case .Playing:
		if c >= '1' && c <= '3' {game.answer(&app.g, c - '1')}
		if c == 'A' || c == 'B' || c == 'C' {game.answer(&app.g, c - 'A')}
		if c == gfx.KEY_ESCAPE {app.screen = .Title}
	case .Over:
		if app.t > 1 && (c == gfx.KEY_ENTER || c == gfx.KEY_SPACE) {start(app.mode)}
		if app.t > 1 && c == gfx.KEY_ESCAPE {app.screen = .Title}
	}
}

@(export)
on_pointer :: proc "c" (x, y: f32, kind: i32) {
	context = runtime.default_context()
	if kind != 0 {return}
	id := gfx.hit(x, y)
	switch app.screen {
	case .Title:
		if id == ID_MODE + 0 {start(.Capital_To_State)}
		if id == ID_MODE + 1 {start(.State_To_Capital)}
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
	gfx.clear(FRAME)
	gfx.begin_buttons()
	gfx.rect(6, 6, W - 12, H - 12, BOARD)
	gfx.frame(6, 6, W - 12, H - 12, FRAME_LIT)
	// Old chalk smudges.
	for i in 0 ..< 9 {
		gfx.rect(20 + (i * 97) % 320, 120 + (i * 53) % 90, 12 + (i * 11) % 20, 2, BOARD_DARK)
	}
	gfx.rect(6, H - 12, W - 12, 6, FRAME_LIT) // the chalk ledge
	gfx.rect(60, H - 15, 14, 3, CHALK)
	gfx.rect(300, H - 15, 9, 3, YELLOW)
	switch app.screen {
	case .Title:
		draw_title()
	case .Playing:
		draw_question()
	case .Over:
		draw_over()
	}
}

draw_title :: proc() {
	gfx.text_c(W / 2, 26, "STATE", CHALK, 3)
	gfx.text_c(W / 2, 52, "CAPITAL QUIZ", CHALK, 2)
	lines := [?]string {
		"FIFTY STATES. THREE CHOICES EACH.",
		"BEAT THE CLOCK, KEEP A STREAK GOING.",
		"MISS ONE AND IT COMES BACK LATER,",
		"BUT IT COSTS AN APPLE. THREE APPLES.",
	}
	for l, i in lines {gfx.text_c(W / 2, 82 + i * 11, l, CHALK_DIM)}
	gfx.button(W / 2 - 168, 136, "1: CAPITAL -> STATE", ID_MODE + 0, YELLOW, BOARD_DARK)
	gfx.button(W / 2 + 8, 136, "2: STATE -> CAPITAL", ID_MODE + 1, CHALK, BOARD_DARK)
	gfx.text(W / 2 - 168, 156, fmt.tprintf("BEST %d", app.best[.Capital_To_State]), CHALK_DIM)
	gfx.text(W / 2 + 8, 156, fmt.tprintf("BEST %d", app.best[.State_To_Capital]), CHALK_DIM)
	gfx.text_c(W / 2, 184, "KEYS 1 2 3 OR TAP TO ANSWER", CHALK_DIM)
	gfx.text_c(W / 2, 206, "AFTER 'STATE CAPITAL QUIZ', SOFTSIDE 1978", CHALK_DIM)
}

draw_apple :: proc(x, y: int, on: bool) {
	c: u32 = on ? APPLE : 0x3a4a3e
	gfx.rect(x + 1, y + 2, 6, 5, c)
	gfx.rect(x, y + 3, 8, 3, c)
	gfx.rect(x + 2, y + 7, 4, 1, c)
	gfx.rect(x + 4, y, 1, 2, on ? 0x6a4a20 : 0x3a4a3e)
	gfx.rect(x + 5, y, 2, 1, on ? GOOD : 0x3a4a3e)
}

draw_question :: proc() {
	g := &app.g
	// Top line: score, streak, apples, how many left.
	gfx.text(14, 14, fmt.tprintf("SCORE %d", g.score), CHALK)
	mult := game.multiplier(g.streak)
	gfx.text(14, 25, fmt.tprintf("STREAK %d", g.streak), CHALK_DIM)
	if mult > 1 {gfx.text(14 + gfx.text_width("STREAK 00 "), 25, fmt.tprintf("X%d", mult), YELLOW)}
	for i in 0 ..< game.LIVES {draw_apple(W - 46 + i * 11, 13, i < g.lives)}
	gfx.text(W - 14 - gfx.text_width(fmt.tprintf("%d LEFT", g.deck_len)), 25, fmt.tprintf("%d LEFT", g.deck_len), CHALK_DIM)

	// The clock as a chalk line that shortens.
	full := W - 28
	left := int(f32(full) * g.clock / game.TIME_LIMIT)
	gfx.rect(14, 38, full, 2, BOARD_DARK)
	gfx.rect(14, 38, left, 2, g.clock < 3 ? BAD : CHALK)

	p := game.prompt(g)
	q := app.mode == .Capital_To_State ? "IS THE CAPITAL OF WHAT STATE?" : "WHAT IS ITS CAPITAL?"
	gfx.text_c(W / 2, 58, p, YELLOW, 2)
	gfx.text_c(W / 2, 82, q, CHALK)

	right_k := game.correct_choice(g)
	for k in 0 ..< game.CHOICES {
		y := 104 + k * 30
		bw := 260
		x := (W - bw) / 2
		fg: u32 = CHALK
		bg: u32 = BOARD_DARK
		if g.answered {
			if k == right_k {fg, bg = BOARD, GOOD} else if k == g.picked {fg, bg = BOARD, BAD} else {fg = CHALK_DIM}
		}
		gfx.rect(x, y, bw, 22, bg)
		gfx.frame(x, y, bw, 22, fg)
		gfx.text(x + 8, y + 7, fmt.tprintf("%d", k + 1), fg)
		gfx.text(x + 28, y + 7, game.choice_text(g, k), fg)
		if !g.answered {gfx.zone(x, y, bw, 22, ID_CHOICE + k)}
	}
	if g.answered {
		msg: string
		c: u32 = GOOD
		switch {
		case g.picked >= 0 && k_is_right(g):
			msg = fmt.tprintf("C O R R E C T !   +%d", g.last_gain)
		case g.picked < 0:
			msg, c = "TIME'S UP. WE WILL TRY THAT ONE AGAIN LATER.", BAD
		case:
			msg, c = "NO. WE WILL TRY THAT ONE AGAIN LATER.", BAD
		}
		gfx.text_c(W / 2, 200, msg, c)
	}
}

k_is_right :: proc(g: ^game.Game) -> bool {
	return g.choices[g.picked] == g.current
}

draw_over :: proc() {
	g := &app.g
	swept := g.deck_len == 0
	gfx.text_c(W / 2, 26, swept ? "ALL FIFTY!" : "OUT OF APPLES", swept ? YELLOW : CHALK, 2)
	gfx.text_c(W / 2, 56, fmt.tprintf("SCORE %d", g.score), CHALK, 2)
	gfx.text_c(W / 2, 84, fmt.tprintf("%d OF 50 ANSWERED", 50 - g.deck_len), CHALK_DIM)
	gfx.text_c(W / 2, 96, fmt.tprintf("LONGEST STREAK %d", g.best_streak), CHALK_DIM)
	if swept {gfx.text_c(W / 2, 108, fmt.tprintf("APPLES LEFT %d  +%d", g.lives, g.lives * game.SWEEP_BONUS), GOOD)}
	verdict := "KEEP STUDYING THAT MAP"
	switch {
	case swept && g.lives == game.LIVES:
		verdict = "A PERFECT PAPER. GOLD STAR!"
	case swept:
		verdict = "TOP OF THE CLASS"
	case 50 - g.deck_len >= 30:
		verdict = "A GOOD SHOWING"
	}
	gfx.text_c(W / 2, 126, verdict, YELLOW)
	if app.new_best {gfx.text_c(W / 2, 140, "NEW BEST!", GOOD)}
	if app.t > 1 {
		gfx.button(W / 2 - 92, 162, "PLAY AGAIN", ID_AGAIN, CHALK, BOARD_DARK)
		gfx.button(W / 2 + 20, 162, "TITLE", ID_MENU, CHALK_DIM, BOARD_DARK)
	}
}
