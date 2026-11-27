#+build js
package main

// Rabbits and Foxes' page: drawing, keys and taps. The model is in ../game.

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:strconv"
import game "../game"
import "proto:gfx"

W :: 384
H :: 240

BG :: 0x18201a
PANEL :: 0x263226
LINE :: 0x3c4a3a
TEXT :: 0xeef0dc
DIM :: 0x8f9c88
GOLD :: 0xf2c94c
MEADOW :: 0x4f7a32
MEADOW_D :: 0x426a2a
RABBIT :: 0xf4f0e6
FOX :: 0xe8742f
GARDEN :: 0x6b4a2a

Screen :: enum {
	Setup,
	Run,
}

App :: struct {
	screen:  Screen,
	m:       game.Model,
	t:       f32,
	acc:     f32,
	running: bool,
	speed:   int, // index into SPEEDS
	start_r: int,
	start_f: int,
	ended_t: f32,
}

app: App

SPEEDS := [3]f32{5, 20, 60} // steps a second
SPEED_NAME := [3]string{"SLOW", "MEDIUM", "FAST"}

ID_R_MINUS :: 1
ID_R_PLUS :: 2
ID_F_MINUS :: 3
ID_F_PLUS :: 4
ID_START :: 5
ID_RUN :: 10
ID_SPEED :: 11
ID_ADD_R :: 12
ID_ADD_F :: 13
ID_RESET :: 14
ID_BALANCE :: 15

main :: proc() {
	app.start_r = 300
	app.start_f = 50
	app.speed = 1
	buf: [32]u8
	if v, ok := gfx.store_get("start", buf[:]); ok {
		r, f: int
		n := 0
		for i in 0 ..< len(v) {
			if v[i] == ',' {
				if a, aok := strconv.parse_int(v[:i]); aok {r = a; n += 1}
				if b, bok := strconv.parse_int(v[i + 1:]); bok {f = b; n += 1}
				break
			}
		}
		if n == 2 {app.start_r = clamp(r, 25, 400); app.start_f = clamp(f, 25, 400)}
	}
}

begin :: proc() {
	gfx.store_set("start", fmt.tprintf("%d,%d", app.start_r, app.start_f))
	game.reset(&app.m, app.start_r, app.start_f)
	app.screen = .Run
	app.running = true
	app.acc = 0
	app.ended_t = 0
	gfx.tone(523, 60, .Triangle, 0.05)
	gfx.tone(659, 80, .Triangle, 0.05, 60)
}

@(export)
step :: proc(dt: f64) -> bool {
	d := f32(min(dt, 0.1))
	app.t += d
	m := &app.m
	if app.screen == .Run && app.running && m.ending == .None {
		app.acc += d * SPEEDS[app.speed]
		for app.acc >= 1 && m.ending == .None {
			app.acc -= 1
			game.step(m)
		}
		if m.ending != .None {
			app.ended_t = app.t
			if m.ending == .No_Rabbits {
				gfx.tone(330, 200, .Sine, 0.06)
				gfx.tone(262, 300, .Sine, 0.06, 200)
			} else {
				gfx.tone(392, 120, .Triangle, 0.06)
				gfx.tone(523, 200, .Triangle, 0.06, 120)
			}
		}
	}
	draw()
	free_all(context.temp_allocator)
	return true
}

press :: proc(id: int) {
	m := &app.m
	switch app.screen {
	case .Setup:
		switch id {
		case ID_R_MINUS: app.start_r = max(25, app.start_r - 25)
		case ID_R_PLUS: app.start_r = min(400, app.start_r + 25)
		case ID_F_MINUS: app.start_f = max(25, app.start_f - 25)
		case ID_F_PLUS: app.start_f = min(400, app.start_f + 25)
		case ID_START: begin()
		case ID_BALANCE: app.start_r, app.start_f = 100, 200
		}
	case .Run:
		switch id {
		case ID_RUN: if m.ending == .None {app.running = !app.running}
		case ID_SPEED: app.speed = (app.speed + 1) % len(SPEEDS)
		case ID_ADD_R:
			game.add(m, 50, 0)
			gfx.tone(880, 40, .Square, 0.03)
		case ID_ADD_F:
			game.add(m, 0, 20)
			gfx.tone(220, 60, .Saw, 0.03)
		case ID_RESET: app.screen = .Setup
		}
	}
}

@(export)
on_key :: proc "c" (code: i32, down: i32) {
	context = runtime.default_context()
	if down != 1 {return}
	c := int(code)
	switch app.screen {
	case .Setup:
		switch c {
		case gfx.KEY_UP: press(ID_R_PLUS)
		case gfx.KEY_DOWN: press(ID_R_MINUS)
		case gfx.KEY_RIGHT: press(ID_F_PLUS)
		case gfx.KEY_LEFT: press(ID_F_MINUS)
		case 'B': press(ID_BALANCE)
		case gfx.KEY_ENTER, gfx.KEY_SPACE: press(ID_START)
		}
	case .Run:
		switch c {
		case gfx.KEY_SPACE, 'P': press(ID_RUN)
		case 'S': press(ID_SPEED)
		case 'R': press(ID_ADD_R)
		case 'F': press(ID_ADD_F)
		case gfx.KEY_ESCAPE, gfx.KEY_ENTER: if c == gfx.KEY_ESCAPE || app.m.ending != .None {press(ID_RESET)}
		}
	}
}

@(export)
on_pointer :: proc "c" (x, y: f32, kind: i32) {
	context = runtime.default_context()
	if kind != 0 {return}
	id := gfx.hit(x, y)
	if id >= 0 {press(id)}
}

// ---- drawing ----

draw :: proc() {
	gfx.begin_buttons()
	gfx.clear(BG)
	switch app.screen {
	case .Setup: draw_setup()
	case .Run: draw_run()
	}
}

draw_setup :: proc() {
	gfx.text_c(W / 2, 10, "RABBITS VS THE FOXES", GOLD, 2)
	gfx.text_c(W / 2, 34, "A SIMPLE ECOLOGICAL MODEL OF INTERACTING", TEXT)
	gfx.text_c(W / 2, 44, "POPULATIONS: RABBITS WITH AN INFINITE FOOD", TEXT)
	gfx.text_c(W / 2, 54, "SUPPLY, AND FOXES THAT PREY ON THEM.", TEXT)
	gfx.text(40, 72, "(RABBITS) D = D + B*(2D - A*D*C)", DIM)
	gfx.text(40, 82, "(FOXES)   C = C + B*(A*D*C - C)", DIM)
	gfx.text(40, 94, "B IS THE STEP SIZE, .02; A IS THE", DIM)
	gfx.text(40, 104, "ENCOUNTER FACTOR, .01.", DIM)
	gfx.text(60, 128, "RABBITS", RABBIT)
	gfx.button(140, 124, "-", ID_R_MINUS, TEXT, PANEL)
	gfx.text(164, 128, fmt.tprintf("%3d", app.start_r), GOLD)
	gfx.button(196, 124, "+", ID_R_PLUS, TEXT, PANEL)
	gfx.text(60, 150, "FOXES", FOX)
	gfx.button(140, 146, "-", ID_F_MINUS, TEXT, PANEL)
	gfx.text(164, 150, fmt.tprintf("%3d", app.start_f), GOLD)
	gfx.button(196, 146, "+", ID_F_PLUS, TEXT, PANEL)
	gfx.text(232, 128, "(25 - 400)", DIM)
	gfx.button(232, 146, "BALANCE", ID_BALANCE, DIM, PANEL)
	gfx.button(W / 2 - 48, 174, "RELEASE", ID_START, BG, GOLD, 2)
	gfx.text_c(W / 2, 214, "AFTER \"RABBITS AND FOXES\" BY RUSSELL STARKEY", DIM)
	gfx.text_c(W / 2, 226, "(SOFTSIDE, APRIL 1979). A TOY.", DIM)
}

hash :: proc(i: int) -> u32 {
	x := u32(i) * 2654435761 + 0x9e3779b9
	x ~= x >> 15
	x *= 0x85ebca6b
	x ~= x >> 13
	return x
}

MX :: 4
MY :: 18
MW :: 180
MH :: 110

draw_meadow :: proc() {
	m := &app.m
	gfx.rect(MX, MY, MW, MH, MEADOW)
	for i in 0 ..< 60 {
		h := hash(i + 1000)
		gfx.rect(MX + int(h % u32(MW - 3)), MY + int((h >> 12) % u32(MH - 1)), 3, 1, MEADOW_D)
	}
	// the gardens the foxes protect
	gfx.rect(MX + 6, MY + MH - 16, 40, 12, GARDEN)
	for k in 0 ..< 6 {gfx.rect(MX + 9 + k * 6, MY + MH - 13, 2, 6, 0x7fc24a)}
	t := app.t
	// one dot for every two animals, up to 400 of each
	nr := min(game.rabbit_count(m) / 2, 400)
	nf := min(game.fox_count(m) / 2, 400)
	for i in 0 ..< nr {
		h := hash(i)
		x := f32(h % u32(MW - 4)) + 2 * math.sin(t * 3 + f32(h % 97))
		y := f32((h >> 10) % u32(MH - 4)) + 1.5 * math.cos(t * 2.5 + f32(h % 89))
		gfx.rect(MX + int(clamp(x, 0, f32(MW - 3))), MY + int(clamp(y, 0, f32(MH - 3))), 2, 2, RABBIT)
	}
	for i in 0 ..< nf {
		h := hash(i + 5000)
		x := f32(h % u32(MW - 5)) + 4 * math.sin(t * 1.3 + f32(h % 83))
		y := f32((h >> 10) % u32(MH - 4)) + 3 * math.cos(t * 1.1 + f32(h % 79))
		gfx.rect(MX + int(clamp(x, 0, f32(MW - 4))), MY + int(clamp(y, 0, f32(MH - 3))), 3, 2, FOX)
	}
	gfx.frame(MX, MY, MW, MH, LINE)
}

// The listing's bars (lines 7000-7140): a full row of blocks against the bigger starting count x3.
bar :: proc(x, y, w: int, v, limit: int, col: u32) {
	gfx.rect(x, y, w, 6, PANEL)
	f := limit > 0 ? min(1, f32(v) / f32(limit)) : 0
	gfx.rect(x, y, int(f * f32(w)), 6, col)
}

draw_run :: proc() {
	m := &app.m
	gfx.text(4, 4, "RABBITS VS THE FOXES", GOLD)
	st := fmt.tprintf("STEP %d", m.steps)
	gfx.text(W - 4 - gfx.text_width(st), 4, st, DIM)
	draw_meadow()
	// the numbers, every fifth step as in the listing
	x := 194
	r, f := game.rabbit_count(m), game.fox_count(m)
	if m.ending == .None && m.steps % game.SHOW_EVERY != 0 {
		// keep the shown numbers to the listing's every fifth step
		lr, lf := game.sample(m, game.samples(m) - 1)
		r, f = int(lr), int(lf)
	}
	limit := 3 * max(m.start_r, m.start_f)
	gfx.text(x, 20, fmt.tprintf("RABBITS %4d", r), RABBIT)
	gfx.text(x, 30, fmt.tprintf("MIN %d  MAX %d", m.min_r, m.max_r), DIM)
	bar(x, 40, W - 4 - x, r, limit, RABBIT)
	gfx.text(x, 56, fmt.tprintf("FOXES   %4d", f), FOX)
	gfx.text(x, 66, fmt.tprintf("MIN %d  MAX %d", m.min_f, m.max_f), DIM)
	bar(x, 76, W - 4 - x, f, limit, FOX)
	switch m.ending {
	case .No_Rabbits:
		gfx.text(x, 92, "THE RABBITS ARE GONE,", GOLD)
		gfx.text(x, 102, "AND THE FOXES WILL", GOLD)
		gfx.text(x, 112, "FOLLOW.", GOLD)
	case .No_Foxes:
		gfx.text(x, 92, "THE FOXES ARE GONE.", GOLD)
		gfx.text(x, 102, "NOW, ABOUT THOSE", GOLD)
		gfx.text(x, 112, "GARDENS...", GOLD)
	case .None:
		gfx.text(x, 92, fmt.tprintf("STARTED %d AND %d", m.start_r, m.start_f), DIM)
		gfx.text(x, 102, "BALANCE: 100 RABBITS,", DIM)
		gfx.text(x, 112, "200 FOXES", DIM)
	}
	draw_chart(4, 134, W - 8, 74)
	// buttons
	bx := 4
	run := m.ending != .None ? "ENDED" : app.running ? "PAUSE" : "RUN"
	bx += gfx.button(bx, 218, run, ID_RUN, m.ending != .None ? DIM : TEXT, PANEL) + 6
	bx += gfx.button(bx, 218, SPEED_NAME[app.speed], ID_SPEED, TEXT, PANEL) + 6
	bx += gfx.button(bx, 218, "+50 RABBITS", ID_ADD_R, m.ending != .None ? DIM : RABBIT, PANEL) + 6
	bx += gfx.button(bx, 218, "+20 FOXES", ID_ADD_F, m.ending != .None ? DIM : FOX, PANEL) + 6
	gfx.button(bx, 218, "NEW", ID_RESET, m.ending != .None ? BG : TEXT, m.ending != .None ? GOLD : PANEL)
}

draw_chart :: proc(x, y, w, h: int) {
	m := &app.m
	gfx.rect(x, y, w, h, PANEL)
	n := game.samples(m)
	top: f32 = 100
	for i in 0 ..< n {
		r, f := game.sample(m, i)
		top = max(top, r, f)
	}
	top = f32(int(top / 100) + 1) * 100
	// grid lines every 100 (or 200)
	stepv: f32 = top > 800 ? 200 : 100
	for v := stepv; v < top; v += stepv {
		gy := y + h - 1 - int(v / top * f32(h - 2))
		gfx.rect(x, gy, w, 1, LINE)
	}
	gfx.text(x + 2, y + 2, fmt.tprintf("%d", int(top)), DIM)
	// the newest samples at the right, two pixels each, joined up
	PX :: 2
	first := max(0, n - w / PX)
	py_r, py_f := -1, -1
	for i in first ..< n {
		r, f := game.sample(m, i)
		px := x + (i - first) * PX
		ry := y + h - 2 - int(r / top * f32(h - 3))
		fy := y + h - 2 - int(f / top * f32(h - 3))
		if py_f < 0 {py_r, py_f = ry, fy}
		gfx.rect(px, min(fy, py_f), PX, abs(fy - py_f) + 2, FOX)
		gfx.rect(px, min(ry, py_r), PX, abs(ry - py_r) + 2, RABBIT)
		py_r, py_f = ry, fy
	}
}
