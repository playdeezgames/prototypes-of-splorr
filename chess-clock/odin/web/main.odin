#+build js
package main

// Chess Clock's page: two faces, tap yer own to end yer move. Rules are in ../game.

import "base:runtime"
import "core:fmt"
import "core:strconv"
import cc "../game"
import "proto:gfx"

W :: 384
H :: 240

CASE :: 0x2a1c12
CASE_LIT :: 0x4a3220
FACE_ON :: 0xf1e6c8
FACE_OFF :: 0x6e6450
INK :: 0x1a140e
INK_DIM :: 0x8a7a5a
BRASS :: 0xe0b050
RED :: 0xe0402e
GREEN :: 0x6fcf6a
KEY :: 0x3a2818
KEY_TEXT :: 0xf1e6c8

ID_WHITE :: 1
ID_BLACK :: 2
ID_PAUSE :: 3
ID_RESET :: 4
ID_PREV :: 5
ID_NEXT :: 6

App :: struct {
	c:      cc.Clock,
	t:      f32,
	flash:  f32,
}

app: App

main :: proc() {
	k := 0
	buf: [16]u8
	if v, ok := gfx.store_get("control", buf[:]); ok {
		if n, nok := strconv.parse_int(v); nok {k = n}
	}
	cc.reset(&app.c, k)
}

@(export)
step :: proc(dt: f64) -> bool {
	d := min(dt, 0.25)
	app.t += f32(d)
	app.flash = max(0, app.flash - f32(d))
	cc.tick(&app.c, d)
	sounds()
	draw()
	free_all(context.temp_allocator)
	return true
}

sounds :: proc() {
	ev := app.c.events
	app.c.events = {}
	if .Switched in ev {gfx.tone(1800, 18, .Square, 0.05)}
	if .Control_Made in ev {
		gfx.tone(880, 80, .Sine, 0.05, 30)
		gfx.tone(1320, 120, .Sine, 0.05, 110)
		app.flash = 2
	}
	if .Low_Time in ev {gfx.tone(1200, 60, .Square, 0.04)}
	if .Flag in ev {
		for i in 0 ..< 4 {gfx.tone(660, 180, .Square, 0.06, f32(i) * 260)}
	}
}

press :: proc(by: cc.Side) {
	cc.press(&app.c, by)
}

set_control :: proc(k: int) {
	if app.c.state == .Running {return}
	n := len(cc.CONTROLS)
	kk := ((k % n) + n) % n
	cc.reset(&app.c, kk)
	gfx.store_set("control", fmt.tprintf("%d", kk))
	gfx.tone(700, 20, .Square, 0.03)
}

click :: proc(id: int) {
	switch id {
	case ID_WHITE:
		press(.White)
	case ID_BLACK:
		press(.Black)
	case ID_PAUSE:
		cc.pause(&app.c)
		gfx.tone(500, 30, .Square, 0.03)
	case ID_RESET:
		if app.c.state != .Running {
			cc.reset(&app.c, app.c.control)
			gfx.tone(400, 40, .Square, 0.03)
		}
	case ID_PREV:
		set_control(app.c.control - 1)
	case ID_NEXT:
		set_control(app.c.control + 1)
	}
}

// ---- input ----

@(export)
on_key :: proc "c" (code: i32, down: i32) {
	context = runtime.default_context()
	if down != 1 {return}
	switch int(code) {
	case 'A', 'Z', 'Q', gfx.KEY_LEFT, gfx.KEY_TAB:
		press(.White)
	case 'L', 'M', gfx.KEY_RIGHT, gfx.KEY_ENTER:
		press(.Black)
	case gfx.KEY_SPACE:
		if app.c.state == .Ready {press(.Black)} else {press(app.c.to_move)}
	case 'P', gfx.KEY_ESCAPE:
		click(ID_PAUSE)
	case 'R':
		click(ID_RESET)
	case gfx.KEY_UP:
		click(ID_PREV)
	case gfx.KEY_DOWN:
		click(ID_NEXT)
	case '1' ..= '6':
		set_control(int(code) - '1')
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

FY :: 30
FH :: 150

draw :: proc() {
	c := &app.c
	gfx.clear(CASE)
	gfx.begin_buttons()
	gfx.text(8, 8, "CHESS CLOCK", BRASS)
	gfx.text(W - 8 - gfx.text_width("A TOOL"), 8, "A TOOL", INK_DIM)
	gfx.text_c(W / 2, 8, cc.CONTROLS[c.control].name, FACE_OFF)
	draw_face(.White, 8, FY)
	draw_face(.Black, W / 2 + 4, FY)

	// Turns, as the listing counted them, between the faces.
	gfx.text_c(W / 2, FY + FH + 6, fmt.tprintf("COMPLETE TURNS %d", cc.turns(c)), FACE_ON)

	y := H - 30
	can_set := c.state != .Running
	gfx.button(8, y, "<", ID_PREV, can_set ? KEY_TEXT : INK_DIM, KEY, 2)
	gfx.button(44, y, ">", ID_NEXT, can_set ? KEY_TEXT : INK_DIM, KEY, 2)
	label := c.state == .Paused ? "GO ON" : "PAUSE"
	gfx.button(W / 2 - 44, y, label, ID_PAUSE, c.state == .Running || c.state == .Paused ? KEY_TEXT : INK_DIM, KEY, 2)
	gfx.button(W - 8 - 88, y, "RESET", ID_RESET, can_set ? KEY_TEXT : INK_DIM, KEY, 2)

	msg := ""
	switch c.state {
	case .Ready:
		msg = "TAP EITHER FACE TO START WHITE'S CLOCK"
	case .Paused:
		msg = "PAUSED"
	case .Flagged:
		msg = fmt.tprintf("%s'S FLAG HAS FALLEN", c.flagged == .White ? "WHITE" : "BLACK")
	case .Running:
		msg = app.flash > 0 ? "TIME CONTROL MADE: NEXT PERIOD ADDED" : "A/Z/LEFT: WHITE   L/M/RIGHT: BLACK   SPACE"
	}
	gfx.text_c(W / 2, FY + FH + 18, msg, c.state == .Flagged ? RED : INK_DIM)
}

draw_face :: proc(s: cc.Side, x, y: int) {
	c := &app.c
	w := W / 2 - 12
	running := c.state == .Running && c.to_move == s
	flagged := c.state == .Flagged && c.flagged == s
	up := c.state != .Ready && c.to_move == s
	face: u32 = up ? FACE_ON : FACE_OFF
	gfx.rect(x, y, w, FH, CASE_LIT)
	gfx.frame(x, y, w, FH, BRASS)
	// The plunger: up on the side whose clock runs.
	pw := 48
	px := x + w / 2 - pw / 2
	if up {
		gfx.rect(px, y - 8, pw, 8, BRASS)
	} else {
		gfx.rect(px, y - 3, pw, 3, INK_DIM)
	}
	gfx.rect(x + 6, y + 6, w - 12, FH - 12, face)
	name := s == .White ? "WHITE" : "BLACK"
	gfx.text_c(x + w / 2, y + 14, name, INK)

	h, m, sec, tn := cc.split(c.left[s])
	digits: string
	if c.left[s] < 20 && c.left[s] > 0 {
		digits = fmt.tprintf("%d:%02d.%d", m, sec, tn)
	} else {
		digits = fmt.tprintf("%d:%02d:%02d", h, m, sec)
	}
	col: u32 = INK
	if flagged {col = RED} else if c.left[s] < 20 && running && int(app.t * 4) % 2 == 0 {col = RED}
	gfx.text_c(x + w / 2, y + 50, digits, col, 2)

	gfx.text_c(x + w / 2, y + 84, fmt.tprintf("MOVES %d", c.moves[s]), INK)
	left := cc.moves_to_control(c, s)
	if left > 0 {
		gfx.text_c(x + w / 2, y + 98, fmt.tprintf("%d TO TIME CONTROL", left), INK_DIM)
	} else if cc.CONTROLS[c.control].inc_s > 0 {
		gfx.text_c(x + w / 2, y + 98, fmt.tprintf("+%dS A MOVE", cc.CONTROLS[c.control].inc_s), INK_DIM)
	}
	if flagged {
		// The little red flag hanging.
		gfx.rect(x + w - 30, y + 116, 2, 16, INK)
		gfx.rect(x + w - 28, y + 120, 10, 7, RED)
		gfx.text_c(x + w / 2, y + 122, "FLAG", RED)
	} else if running {
		gfx.text_c(x + w / 2, y + 122, "TAP HERE", GREEN)
	}
	gfx.zone(x, y - 8, w, FH + 8, s == .White ? ID_WHITE : ID_BLACK)
}
