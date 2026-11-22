#+build js
package main

// Spelling Bee's page: look, then spell from memory. Rules are in ../game.

import "base:runtime"
import "core:fmt"
import "core:strconv"
import sb "../game"
import "proto:gfx"

W :: 512
H :: 288

COMB :: 0x2a2010
COMB_LINE :: 0x4a3818
HONEY :: 0xf4b830
HONEY_DIM :: 0x8a6420
WAX :: 0xfff0c8
INK :: 0x1a1208
GOOD :: 0x8fe08a
BAD :: 0xff7060
KEY :: 0x3a2c14

Screen :: enum {
	Title,
	Playing,
	Over,
}

ID_HIVE :: 1
ID_PRACTICE :: 2
ID_AGAIN :: 3
ID_MENU :: 4
ID_ENTER :: 5
ID_DEL :: 6
ID_READY :: 7
ID_NEXT :: 8
ID_LETTER :: 100 // + letter index in ROWS order

KEY_ROWS := [?]string{"QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"}

App :: struct {
	screen:   Screen,
	g:        sb.Game,
	mode:     sb.Mode,
	t:        f32,
	result_t: f32,
	best:     int,
	new_best: bool,
	flash:    f32, // a rung-up banner
}

app: App

main :: proc() {
	sb.new_game(&app.g, 1, .Hive)
	buf: [32]u8
	if v, ok := gfx.store_get("best", buf[:]); ok {
		if n, nok := strconv.parse_int(v); nok && n >= 0 {app.best = n}
	}
}

start :: proc(mode: sb.Mode) {
	app.mode = mode
	sb.new_game(&app.g, u64(gfx.now_ms()) ~ u64(gfx.random() * 1e9), mode)
	app.screen = .Playing
	app.result_t = 0
	app.new_best = false
	gfx.tone(660, 80, .Triangle, 0.05)
	gfx.tone(880, 120, .Triangle, 0.05, 80)
}

@(export)
step :: proc(dt: f64) -> bool {
	d := f32(min(dt, 0.1))
	app.t += d
	app.flash = max(0, app.flash - d)
	if app.screen == .Playing {
		g := &app.g
		sb.update(g, d)
		sounds()
		if g.phase == .Result {
			app.result_t += d
			if g.was_right && app.result_t > 1.0 {advance()}
		}
	}
	draw()
	free_all(context.temp_allocator)
	return true
}

advance :: proc() {
	g := &app.g
	sb.next(g)
	app.result_t = 0
	if g.phase == .Over {
		if app.mode == .Hive && g.score > app.best {
			app.best = g.score
			app.new_best = true
			gfx.store_set("best", fmt.tprintf("%d", g.score))
		}
		app.screen = .Over
		app.t = 0
	}
}

sounds :: proc() {
	g := &app.g
	ev := g.events
	g.events = {}
	if .Right in ev {
		f: f32 = 523 + f32(min(g.streak, 12)) * 25
		gfx.tone(f, 70, .Triangle, 0.05)
		gfx.tone(f * 1.5, 120, .Triangle, 0.05, 70)
	}
	if .Wrong in ev {
		// A buzz, as a bee would.
		gfx.tone(110, 300, .Saw, 0.05)
		gfx.tone(104, 300, .Saw, 0.04)
	}
	if .Rung_Up in ev {
		for f, i in ([?]f32{523, 659, 784, 1047}) {gfx.tone(f, 90, .Square, 0.04, 200 + f32(i) * 90)}
		app.flash = 1.6
	}
}

press_letter :: proc(ch: u8) {
	if sb.type_letter(&app.g, ch) {gfx.tone(1000 + f32(ch - 'A') * 20, 15, .Square, 0.02)}
}

click :: proc(id: int) {
	g := &app.g
	switch app.screen {
	case .Title:
		if id == ID_HIVE {start(.Hive)}
		if id == ID_PRACTICE {start(.Practice)}
	case .Playing:
		switch {
		case id >= ID_LETTER:
			k := id - ID_LETTER
			for row in KEY_ROWS {
				if k < len(row) {
					press_letter(row[k])
					break
				}
				k -= len(row)
			}
		case id == ID_DEL:
			sb.rub_out(g)
		case id == ID_ENTER:
			if g.phase == .Result {advance()} else {sb.submit(g)}
		case id == ID_READY:
			sb.ready(g)
		case id == ID_NEXT:
			advance()
		}
	case .Over:
		if app.t > 0.8 {
			if id == ID_AGAIN {start(app.mode)}
			if id == ID_MENU {app.screen = .Title}
		}
	}
}

// ---- input ----

@(export)
on_key :: proc "c" (code: i32, down: i32) {
	context = runtime.default_context()
	if down == 0 {return}
	c := int(code)
	switch app.screen {
	case .Title:
		if down != 1 {return}
		if c == '1' || c == gfx.KEY_ENTER || c == gfx.KEY_SPACE {start(.Hive)}
		if c == '2' {start(.Practice)}
	case .Playing:
		g := &app.g
		switch {
		case c >= 'A' && c <= 'Z':
			if down == 1 {press_letter(u8(c))}
		case c == gfx.KEY_BACKSPACE || c == gfx.KEY_DELETE:
			sb.rub_out(g)
		case c == gfx.KEY_ENTER:
			if down != 1 {return}
			switch g.phase {
			case .Look:
				sb.ready(g)
			case .Spell:
				sb.submit(g)
			case .Result:
				advance()
			case .Over:
			}
		case c == gfx.KEY_SPACE:
			if down == 1 && g.phase == .Look {sb.ready(g)}
		case c == gfx.KEY_ESCAPE:
			app.screen = .Title
		}
	case .Over:
		if down != 1 || app.t < 0.8 {return}
		if c == gfx.KEY_ENTER || c == gfx.KEY_SPACE {start(app.mode)}
		if c == gfx.KEY_ESCAPE {app.screen = .Title}
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
	gfx.clear(COMB)
	gfx.begin_buttons()
	draw_comb()
	switch app.screen {
	case .Title:
		draw_title()
	case .Playing:
		draw_play()
	case .Over:
		draw_over()
	}
}

// A faint honeycomb behind everything.
draw_comb :: proc() {
	for row in 0 ..< 12 {
		for col in 0 ..< 18 {
			x := col * 30 + (row % 2) * 15 - 8
			y := row * 26 - 6
			gfx.rect(x + 7, y, 14, 1, COMB_LINE)
			gfx.rect(x + 7, y + 22, 14, 1, COMB_LINE)
			gfx.rect(x, y + 7, 1, 9, COMB_LINE)
			gfx.rect(x + 27, y + 7, 1, 9, COMB_LINE)
		}
	}
}

draw_bee :: proc(x, y: int, alive: bool) {
	body: u32 = alive ? HONEY : 0x4a3a20
	stripe: u32 = alive ? INK : 0x2a2010
	gfx.rect(x + 2, y + 3, 10, 6, body)
	gfx.rect(x + 5, y + 3, 2, 6, stripe)
	gfx.rect(x + 9, y + 3, 1, 6, stripe)
	gfx.rect(x + 3, y, 4, 3, alive ? 0xe0f0ff : 0x3a3020) // wings
	gfx.rect(x + 7, y, 4, 3, alive ? 0xe0f0ff : 0x3a3020)
	gfx.rect(x + 12, y + 5, 2, 2, stripe)
}

draw_title :: proc() {
	gfx.text_c(W / 2, 30, "SPELLING", HONEY, 3)
	gfx.text_c(W / 2, 58, "BEE", HONEY, 3)
	draw_bee(W / 2 + 40, 60, true)
	lines := [?]string {
		"A WORD FLASHES UP. THEN IT'S GONE.",
		"TYPE IT FROM MEMORY.",
		"FIVE RIGHT AND YOU CLIMB TO LONGER WORDS",
		"AND SHORTER LOOKS. MISS ONE AND IT COMES",
		"BACK LATER, BUT IT COSTS A BEE. THREE BEES.",
	}
	for l, i in lines {gfx.text_c(W / 2, 96 + i * 12, l, WAX)}
	gfx.button(W / 2 - 180, 170, "1: THE HIVE", ID_HIVE, HONEY, KEY, 2)
	gfx.button(W / 2 + 16, 170, "2: PRACTICE", ID_PRACTICE, WAX, KEY, 2)
	gfx.text(W / 2 - 180, 198, fmt.tprintf("BEST %d", app.best), HONEY_DIM)
	gfx.text(W / 2 + 16, 198, "TEN WORDS, NO BEES", HONEY_DIM)
	gfx.text_c(W / 2, 236, "AFTER 'SPELLING BEE' BY LANCE MICKLUS,", HONEY_DIM)
	gfx.text_c(W / 2, 248, "SOFTSIDE, DECEMBER 1978", HONEY_DIM)
}

draw_play :: proc() {
	g := &app.g
	// Top line.
	if app.mode == .Hive {
		gfx.text(12, 10, fmt.tprintf("SCORE %d", g.score), WAX)
		mult := sb.multiplier(g.streak)
		gfx.text(12, 22, fmt.tprintf("STREAK %d", g.streak), HONEY_DIM)
		if mult > 1 {gfx.text(12 + gfx.text_width("STREAK 00 "), 22, fmt.tprintf("X%d", mult), HONEY)}
		for i in 0 ..< sb.LIVES {draw_bee(W - 60 + i * 16, 10, i < g.lives)}
		gfx.text(W - 12 - gfx.text_width(fmt.tprintf("RUNG %d", g.rung + 1)), 24, fmt.tprintf("RUNG %d", g.rung + 1), HONEY_DIM)
	} else {
		gfx.text(12, 10, fmt.tprintf("PRACTICE  WORD %d OF %d", g.asked, sb.PRACTICE_WORDS), WAX)
		gfx.text(12, 22, fmt.tprintf("CORRECT %d  WRONG %d", g.right, g.wrong), HONEY_DIM)
	}
	if app.flash > 0 {gfx.text_c(W / 2, 22, "LONGER WORDS!", HONEY)}

	// The card.
	cx, cy, cw, ch := 56, 40, W - 112, 96
	gfx.rect(cx, cy, cw, ch, WAX)
	gfx.frame(cx, cy, cw, ch, HONEY)
	switch g.phase {
	case .Look:
		gfx.text_c(W / 2, cy + 10, fmt.tprintf("WORD %d IS", g.asked), HONEY_DIM)
		size := len(g.word) > 8 ? 3 : 4
		gfx.text_c(W / 2, cy + 32, g.word, INK, size)
		// The look running out.
		full := cw - 16
		left := int(f32(full) * g.timer / g.look)
		gfx.rect(cx + 8, cy + ch - 10, full, 3, 0xe8d8a8)
		gfx.rect(cx + 8, cy + ch - 10, left, 3, HONEY)
		gfx.zone(cx, cy, cw, ch, ID_READY)
	case .Spell:
		gfx.text_c(W / 2, cy + 10, "WHAT'S THE WORD?", HONEY_DIM)
		s := sb.typed(g)
		gfx.text_c(W / 2, cy + 36, s, INK, 3)
		if int(app.t * 2) % 2 == 0 {
			gfx.rect(W / 2 + gfx.text_width(s, 3) / 2 + 2, cy + 58, 20, 3, INK)
		}
	case .Result:
		if g.was_right {
			gfx.text_c(W / 2, cy + 16, "THAT'S RIGHT!", 0x2a7a2a, 2)
			gfx.text_c(W / 2, cy + 44, g.word, INK, 3)
			if g.last_gain > 0 {gfx.text_c(W / 2, cy + 76, fmt.tprintf("+%d", g.last_gain), HONEY_DIM)}
		} else {
			gfx.text_c(W / 2, cy + 8, fmt.tprintf("SORRY. YOU TYPED %s", sb.typed(g)), 0xa02a20)
			gfx.text_c(W / 2, cy + 24, "THE WORD IS", HONEY_DIM)
			gfx.text_c(W / 2, cy + 40, g.word, INK, 3)
			gfx.text_c(W / 2, cy + 74, app.mode == .Hive ? "IT WILL COME BACK. PRESS ENTER." : "PRESS ENTER TO CONTINUE.", HONEY_DIM)
			gfx.zone(cx, cy, cw, ch, ID_NEXT)
		}
	case .Over:
	}
	draw_keys()
}

draw_keys :: proc() {
	KW :: 36
	KH :: 26
	y0 := 148
	k := 0
	for row, r in KEY_ROWS {
		x0 := (W - len(row) * (KW + 4)) / 2 + r * 6
		for i in 0 ..< len(row) {
			x := x0 + i * (KW + 4)
			y := y0 + r * (KH + 4)
			gfx.rect(x, y, KW, KH, KEY)
			gfx.frame(x, y, KW, KH, HONEY_DIM)
			gfx.text_c(x + KW / 2, y + 9, string([]u8{row[i]}), WAX)
			gfx.zone(x, y, KW, KH, ID_LETTER + k)
			k += 1
		}
	}
	y := y0 + 2 * (KH + 4)
	gfx.button(12, y + 2, "DEL", ID_DEL, WAX, KEY, 2)
	gfx.button(W - 12 - 92, y + 2, "ENTER", ID_ENTER, HONEY, KEY, 2)
}

draw_over :: proc() {
	g := &app.g
	if app.mode == .Hive {
		gfx.text_c(W / 2, 34, "THE BEES ARE GONE", HONEY, 2)
		gfx.text_c(W / 2, 66, fmt.tprintf("SCORE %d", g.score), WAX, 2)
		gfx.text_c(W / 2, 96, fmt.tprintf("CORRECT %d  WRONG %d", g.right, g.wrong), WAX)
		gfx.text_c(W / 2, 110, fmt.tprintf("REACHED RUNG %d  LONGEST STREAK %d", g.rung + 1, g.best_streak), HONEY_DIM)
		verdict := "KEEP BUZZING"
		switch {
		case g.rung >= sb.RUNG_COUNT - 1:
			verdict = "QUEEN OF THE HIVE"
		case g.rung >= 4:
			verdict = "A CHAMPION SPELLER"
		case g.rung >= 2:
			verdict = "A BUSY BEE"
		}
		gfx.text_c(W / 2, 132, verdict, HONEY)
		if app.new_best {gfx.text_c(W / 2, 148, "NEW BEST!", GOOD)}
	} else {
		// The listing's line 840.
		gfx.text_c(W / 2, 50, "PRACTICE DONE", HONEY, 2)
		gfx.text_c(W / 2, 90, fmt.tprintf("CORRECT: %d   WRONG: %d", g.right, g.wrong), WAX, 2)
		gfx.text_c(W / 2, 124, g.wrong == 0 ? "EVERY ONE RIGHT!" : "PLAY AGAIN?", HONEY_DIM)
	}
	if app.t > 0.8 {
		gfx.button(W / 2 - 120, 180, "PLAY AGAIN", ID_AGAIN, HONEY, KEY, 2)
		gfx.button(W / 2 + 56, 180, "TITLE", ID_MENU, WAX, KEY, 2)
	}
}
