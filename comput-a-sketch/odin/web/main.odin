#+build js
package main

// Comput-A-Sketch's page: the pad, the key chart, keys, drags and taps. Rules are in ../game.

import "base:runtime"
import sk "../game"
import "proto:gfx"

W :: 384
H :: 240

BG :: 0x1a1d24
CASE :: 0x6b6f7a
CASE_LIT :: 0x8d919c
CASE_DARK :: 0x464a54
PAD :: 0xb9bcae
INK :: 0x2a2c30
TEXT :: 0xe8e6dc
DIM :: 0x9a9caa
GOLD :: 0xf0c050
BTN :: 0x2c303a

CELL :: 3
PAD_X :: 104
PAD_Y :: 14

ID_CLEAR :: 1
ID_PEN :: 2

App :: struct {
	pad:       sk.Pad,
	t:         f32,
	shake:     f32,
	dragging:  bool,
	tx, ty:    int,
	step_acc:  f32,
	pen_up:    bool, // for drags: move without drawing
	held:      bit_set[sk.Dir],
	held_acc:  f32,
	save_acc:  f32,
	saved_at:  int,
}

app: App

main :: proc() {
	sk.clear(&app.pad)
	buf: [sk.ENCODED_MAX + 16]u8
	if v, ok := gfx.store_get("pad", buf[:]); ok {_ = sk.decode(&app.pad, v)}
	app.saved_at = app.pad.moves
}

save :: proc() {
	buf: [sk.ENCODED_MAX]u8
	gfx.store_set("pad", sk.encode(&app.pad, buf[:]))
	app.saved_at = app.pad.moves
}

clear_pad :: proc() {
	sk.clear(&app.pad)
	app.shake = 0.45
	gfx.noise(90, 0.06)
	gfx.noise(90, 0.05, 120)
	gfx.noise(90, 0.04, 240)
	save()
}

tick_sound :: proc(drawing: bool) {
	gfx.tone(drawing ? 1800 : 900, 6, .Square, 0.012)
}

@(export)
step :: proc(dt: f64) -> bool {
	d := f32(min(dt, 0.1))
	app.t += d
	app.shake = max(0, app.shake - d)

	// Held arrow keys draw, about thirty steps a second.
	if app.held != {} {
		app.held_acc += d
		for app.held_acc >= 1.0 / 30 {
			app.held_acc -= 1.0 / 30
			dir, ok := held_dir()
			if ok {sk.draw(&app.pad, dir)}
		}
	}

	// A drag walks the stylus toward the finger in the eight directions, like the knobs would.
	if app.dragging {
		app.step_acc += d
		n := 0
		for app.step_acc >= 1.0 / 90 && n < 12 {
			app.step_acc -= 1.0 / 90
			n += 1
			dir, ok := sk.toward(&app.pad, app.tx, app.ty)
			if !ok {
				app.step_acc = 0
				break
			}
			if app.pen_up {sk.move(&app.pad, dir)} else {sk.draw(&app.pad, dir)}
		}
	}

	app.save_acc += d
	if app.save_acc > 1 {
		app.save_acc = 0
		if app.pad.moves != app.saved_at {save()}
	}
	draw()
	free_all(context.temp_allocator)
	return true
}

held_dir :: proc() -> (sk.Dir, bool) {
	h := app.held
	up, down, left, right := .Up in h, .Down in h, .Left in h, .Right in h
	switch {
	case up && left:
		return .Up_Left, true
	case up && right:
		return .Up_Right, true
	case down && left:
		return .Down_Left, true
	case down && right:
		return .Down_Right, true
	case up:
		return .Up, true
	case down:
		return .Down, true
	case left:
		return .Left, true
	case right:
		return .Right, true
	}
	return .Up, false
}

// ---- input ----

@(export)
on_key :: proc "c" (code: i32, down: i32) {
	context = runtime.default_context()
	c := int(code)
	arrow: sk.Dir
	is_arrow := true
	switch c {
	case gfx.KEY_LEFT:
		arrow = .Left
	case gfx.KEY_RIGHT:
		arrow = .Right
	case gfx.KEY_UP:
		arrow = .Up
	case gfx.KEY_DOWN:
		arrow = .Down
	case:
		is_arrow = false
	}
	if is_arrow {
		if down == 1 {
			app.held += {arrow}
			// The first step at once (a tap draws one dot), then a pause before the run.
			if dir, ok := held_dir(); ok {sk.draw(&app.pad, dir)}
			app.held_acc = -0.15
		} else if down == 0 {
			app.held -= {arrow}
		}
		return
	}
	if down == 0 {return}
	if c == 'C' && down == 1 {
		clear_pad()
		return
	}
	if c == gfx.KEY_SPACE && down == 1 {
		app.pen_up = !app.pen_up
		return
	}
	dir, drawing, ok := sk.key_dir(c)
	if !ok {return}
	if drawing {sk.draw(&app.pad, dir)} else {sk.move(&app.pad, dir)}
	tick_sound(drawing)
}

@(export)
on_pointer :: proc "c" (x, y: f32, kind: i32) {
	context = runtime.default_context()
	cx := int((x - PAD_X) / CELL)
	cy := int((y - PAD_Y) / CELL)
	on_pad := x >= PAD_X && y >= PAD_Y && cx < sk.PAD_W && cy < sk.PAD_H
	switch kind {
	case 0:
		if on_pad {
			app.dragging = true
			app.tx, app.ty = cx, cy
			app.step_acc = 0
			return
		}
		switch gfx.hit(x, y) {
		case ID_CLEAR:
			clear_pad()
		case ID_PEN:
			app.pen_up = !app.pen_up
		}
	case 1:
		if app.dragging {
			app.tx = clamp(cx, 0, sk.PAD_W - 1)
			app.ty = clamp(cy, 0, sk.PAD_H - 1)
		}
	case 2:
		app.dragging = false
	}
}

// ---- drawing ----

draw :: proc() {
	gfx.clear(BG)
	gfx.begin_buttons()
	draw_chart()
	draw_pad()
}

draw_chart :: proc() {
	gfx.text(6, 8, "DRAW KEYS", GOLD)
	keys := [?]string{"R-->", "L<--", "U-^", "D-DWN", "Z-^&<--", "S-->&DWN", "M-->&^", "K-DWN&<--", "C-CLEAR"}
	for k, i in keys {gfx.text(6, 22 + i * 10, k, TEXT)}
	gfx.text(6, 116, "*******", DIM)
	gfx.text(6, 128, "SHIFT POINT", GOLD)
	moves := [?]string{"Q<--", "P-->", "O-^", "N-DWN"}
	for k, i in moves {gfx.text(6, 142 + i * 10, k, TEXT)}
	gfx.text(6, 186, "ARROWS DRAW", DIM)
	gfx.text(6, 196, "OR DRAG", DIM)
	gfx.button(4, 210, "CLEAR", ID_CLEAR, TEXT, BTN)
	gfx.button(52, 210, app.pen_up ? "MOVE" : "DRAW", ID_PEN, app.pen_up ? DIM : GOLD, BTN)
}

draw_pad :: proc() {
	jx, jy := 0, 0
	if app.shake > 0 {
		k := int(app.t * 40) % 4
		JX := [4]int{-3, 2, 3, -2}
		JY := [4]int{1, -2, 2, -1}
		jx = JX[k]
		jy = JY[k]
	}
	px, py := PAD_X + jx, PAD_Y + jy
	pw, ph := sk.PAD_W * CELL, sk.PAD_H * CELL
	// The case, with a lip, and its two knobs below.
	gfx.rect(px - 8, py - 10, pw + 16, ph + 20, CASE)
	gfx.rect(px - 8, py - 10, pw + 16, 2, CASE_LIT)
	gfx.rect(px - 8, py + ph + 8, pw + 16, 2, CASE_DARK)
	gfx.text_c(px + pw / 2, py - 9, "COMPUT-A-SKETCH", TEXT)
	gfx.rect(px - 1, py - 1, pw + 2, ph + 2, CASE_DARK)
	gfx.rect(px, py, pw, ph, PAD)
	knob_spin := f32(app.pad.x) * 0.4
	draw_knob(px + 10, py + ph + 5, knob_spin)
	draw_knob(px + pw - 10, py + ph + 5, f32(app.pad.y) * 0.4)

	fade := app.shake > 0
	for row in 0 ..< sk.PAD_H {
		for col in 0 ..< sk.PAD_W {
			if app.pad.dots[row][col] {
				gfx.rect(px + col * CELL, py + row * CELL, CELL, CELL, fade ? 0x8a8c80 : INK)
			}
		}
	}
	// The floating stylus blinks so it can be found on a busy sketch.
	if int(app.t * 4) % 2 == 0 {
		sx, sy := px + app.pad.x * CELL, py + app.pad.y * CELL
		c: u32 = app.pen_up ? 0x6a6c70 : 0x000000
		gfx.frame(sx - 1, sy - 1, CELL + 2, CELL + 2, c)
	}
}

draw_knob :: proc(cx, cy: int, spin: f32) {
	gfx.rect(cx - 5, cy - 5, 10, 10, 0xd8d6cc)
	gfx.frame(cx - 5, cy - 5, 10, 10, 0x8a887e)
	k := int(spin) % 4
	OFF := [4][2]int{{0, -3}, {3, 0}, {0, 3}, {-3, 0}}
	off := OFF[k]
	gfx.rect(cx + off[0] - 1, cy + off[1] - 1, 2, 2, 0x5a5850)
}
