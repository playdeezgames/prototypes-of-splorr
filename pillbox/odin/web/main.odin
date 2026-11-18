#+build js
package main

// Pillbox's page: drawing, keys and taps. Rules are in ../game.

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:strconv"
import game "../game"
import "proto:gfx"

W :: game.W
H :: game.H

SKY_TOP :: 0x1d2b4f
SKY_LOW :: 0x3d4f7a
GROUND :: 0x4a3b22
GROUND_LIT :: 0x6d5a32
GRASS :: 0x5f7a32
BOX :: 0x9a9a8a
BOX_DARK :: 0x5e5e52
TEXT :: 0xf1ead2
DIM :: 0x9aa3b8
GOLD :: 0xf4c542
RED :: 0xe8473c
GREEN :: 0x7bd36a
PANEL :: 0x141a2e
LEFT_C :: 0x7fc3f0
RIGHT_C :: 0xf08f6a

Screen :: enum {
	Title,
	Playing,
	Over,
}

Blast :: struct {
	x, y: f32,
	t:    f32,
	big:  bool,
}

App :: struct {
	screen:     Screen,
	g:          game.Game,
	one_player: bool,
	t:          f32,
	held:       int, // a held control (key or button), repeating
	held_t:     f32,
	cpu_wait:   f32, // the computer "thinks" before it fires
	hit_wait:   f32, // a hit is shown before the new field
	message:    string,
	msg_buf:    [64]u8,
	msg_t:      f32,
	blasts:     [6]Blast,
	won, lost:  int, // record against the computer
	flash:      f32,
}

app: App

ID_ONE :: 1
ID_TWO :: 2
ID_ANG_DOWN :: 3
ID_ANG_UP :: 4
ID_VEL_DOWN :: 5
ID_VEL_UP :: 6
ID_FIRE :: 7
ID_AGAIN :: 8
ID_MENU :: 9

main :: proc() {
	game.new_game(&app.g, 99, true)
	buf: [32]u8
	if v, ok := gfx.store_get("record", buf[:]); ok {
		w, l: int
		n := 0
		for part in split2(v) {
			if x, xok := strconv.parse_int(part); xok && x >= 0 && x < 100000 {
				if n == 0 {w = x} else {l = x}
			}
			n += 1
		}
		app.won, app.lost = w, l
	}
}

split2 :: proc(s: string) -> [2]string {
	for i in 0 ..< len(s) {
		if s[i] == ' ' {return {s[:i], s[i + 1:]}}
	}
	return {s, "0"}
}

start :: proc(one_player: bool) {
	app.one_player = one_player
	game.new_game(&app.g, u64(gfx.now_ms()) ~ u64(gfx.random() * 1e9), one_player)
	app.screen = .Playing
	app.blasts = {}
	app.hit_wait = 0
	app.cpu_wait = 1.0
	say(fmt.tprintf("%s FIRES FIRST", side_name(app.g.turn)))
	gfx.tone(330, 90, .Square, 0.05)
	gfx.tone(440, 140, .Square, 0.05, 100)
}

side_name :: proc(side: int) -> string {
	if app.one_player {return side == 0 ? "YOU" : "THE COMPUTER"}
	return side == 0 ? "LEFT GUNNER" : "RIGHT GUNNER"
}

say :: proc(s: string) {
	n := copy(app.msg_buf[:], s)
	app.message = string(app.msg_buf[:n])
	app.msg_t = 2.2
}

my_turn :: proc() -> bool {
	g := &app.g
	return app.screen == .Playing && g.winner < 0 && g.shell.state != .Flying && app.hit_wait <= 0 && !g.gunners[g.turn].cpu
}

@(export)
step :: proc(dt: f64) -> bool {
	d := f32(min(dt, 0.1))
	app.t += d
	app.msg_t = max(0, app.msg_t - d)
	app.flash = max(0, app.flash - d)
	for &b in app.blasts {if b.t > 0 {b.t -= d}}
	if app.screen == .Playing {play(d)}
	draw()
	free_all(context.temp_allocator)
	return true
}

play :: proc(d: f32) {
	g := &app.g
	if app.held != 0 && my_turn() {
		app.held_t -= d
		if app.held_t <= 0 {
			nudge(app.held)
			app.held_t = 0.05
		}
	}
	if g.shell.state == .Flying {game.update(g, d)}
	if app.hit_wait > 0 {
		app.hit_wait -= d
		if app.hit_wait <= 0 {
			if g.winner >= 0 {
				app.screen = .Over
				app.t = 0
			} else {
				game.after_hit(g)
				app.cpu_wait = 1.2
				say(fmt.tprintf("NEW GROUND. %s FIRES FIRST", side_name(g.turn)))
			}
		}
	} else if g.winner < 0 && g.shell.state != .Flying && g.gunners[g.turn].cpu {
		app.cpu_wait -= d
		if app.cpu_wait <= 0 {
			game.cpu_aim(g)
			game.fire(g)
		}
	}
	sounds()
}

sounds :: proc() {
	g := &app.g
	ev := g.events
	g.events = {}
	if .Fired in ev {
		gfx.noise(160, 0.25)
		gfx.tone(90, 120, .Square, 0.06)
	}
	if .Landed in ev || .Lost in ev {
		if .Landed in ev {
			blast(g.shell.x, g.shell.y, false)
			gfx.noise(260, 0.18)
		}
		app.cpu_wait = 0.9
		if g.gunners[g.turn].cpu {say("THE COMPUTER IS AIMING...")} else if app.one_player {say("YOUR TURN")} else {say(fmt.tprintf("%s'S TURN", side_name(g.turn)))}
	}
	if .Hit in ev || .Hit_Self in ev {
		blast(g.shell.x, g.shell.y, true)
		gfx.noise(700, 0.35)
		for f, i in ([?]f32{196, 262, 330, 392}) {gfx.tone(f, 120, .Square, 0.05, 250 + f32(i) * 110)}
		app.flash = 0.25
		app.hit_wait = 2.2
		if .Hit_Self in ev {
			say(fmt.tprintf("%s SHELLED THEMSELVES!", side_name(g.turn)))
		} else {
			say(fmt.tprintf("DIRECT HIT BY %s!", side_name(g.turn)))
		}
	}
	if .War_Over in ev {
		if app.one_player {
			if g.winner == 0 {app.won += 1} else {app.lost += 1}
			gfx.store_set("record", fmt.tprintf("%d %d", app.won, app.lost))
		}
		app.hit_wait = 2.6
	}
}

blast :: proc(x, y: f32, big: bool) {
	for &b in app.blasts {
		if b.t <= 0 {
			b = {x, y, big ? 1.0 : 0.6, big}
			return
		}
	}
}

nudge :: proc(id: int) {
	g := &app.g
	gu := g.gunners[g.turn]
	switch id {
	case ID_ANG_DOWN:
		game.set_aim(g, gu.angle - 1, gu.velocity)
	case ID_ANG_UP:
		game.set_aim(g, gu.angle + 1, gu.velocity)
	case ID_VEL_DOWN:
		game.set_aim(g, gu.angle, gu.velocity - 10)
	case ID_VEL_UP:
		game.set_aim(g, gu.angle, gu.velocity + 10)
	}
}

press :: proc(id: int) {
	if id == ID_FIRE {
		if my_turn() {game.fire(&app.g)}
		return
	}
	if !my_turn() {return}
	nudge(id)
	gfx.tone(1200, 12, .Square, 0.02)
	app.held = id
	app.held_t = 0.35
}

// ---- input ----

key_id :: proc(c: int) -> int {
	switch c {
	case gfx.KEY_UP, 'W':
		return ID_ANG_UP
	case gfx.KEY_DOWN, 'S':
		return ID_ANG_DOWN
	case gfx.KEY_RIGHT, 'D':
		return ID_VEL_UP
	case gfx.KEY_LEFT, 'A':
		return ID_VEL_DOWN
	}
	return 0
}

@(export)
on_key :: proc "c" (code: i32, down: i32) {
	context = runtime.default_context()
	c := int(code)
	if id := key_id(c); id != 0 {
		if down == 0 {
			if app.held == id {app.held = 0}
		} else if down == 1 && app.screen == .Playing {
			press(id)
		}
		return
	}
	if down != 1 {return}
	switch app.screen {
	case .Title:
		if c == '1' || c == gfx.KEY_ENTER || c == gfx.KEY_SPACE {start(true)}
		if c == '2' {start(false)}
	case .Playing:
		if c == gfx.KEY_SPACE || c == gfx.KEY_ENTER || c == 'F' {press(ID_FIRE)}
		if c == gfx.KEY_ESCAPE {app.screen = .Title}
	case .Over:
		if app.t > 1 && (c == gfx.KEY_ENTER || c == gfx.KEY_SPACE) {start(app.one_player)}
		if app.t > 1 && c == gfx.KEY_ESCAPE {app.screen = .Title}
	}
}

@(export)
on_pointer :: proc "c" (x, y: f32, kind: i32) {
	context = runtime.default_context()
	if kind == 2 {
		app.held = 0
		return
	}
	if kind != 0 {return}
	id := gfx.hit(x, y)
	switch app.screen {
	case .Title:
		if id == ID_ONE {start(true)}
		if id == ID_TWO {start(false)}
	case .Playing:
		if id != -1 {press(id)}
	case .Over:
		if app.t > 1 {
			if id == ID_AGAIN {start(app.one_player)}
			if id == ID_MENU {app.screen = .Title}
		}
	}
}

// ---- drawing ----

draw :: proc() {
	gfx.clear(SKY_TOP)
	gfx.begin_buttons()
	draw_field()
	switch app.screen {
	case .Title:
		draw_title()
	case .Playing:
		draw_hud()
	case .Over:
		draw_hud()
		draw_over()
	}
	if app.flash > 0 {
		gfx.frame(0, 0, W, H, 0xffffff)
		gfx.frame(1, 1, W - 2, H - 2, GOLD)
	}
}

draw_field :: proc() {
	g := &app.g
	// Sky in bands.
	for i in 0 ..< 8 {
		c := blend(SKY_TOP, SKY_LOW, f32(i) / 7)
		gfx.rect(0, 24 + i * 26, W, 26, c)
	}
	// Ground, column by column.
	for x in 0 ..< W {
		gy := g.ground[x]
		gfx.rect(x, gy, 1, H - gy, GROUND)
		gfx.rect(x, gy, 1, 2, GRASS)
		if (x * 7 + gy) % 11 == 0 {gfx.rect(x, gy + 6 + (x * 13) % 20, 1, 1, GROUND_LIT)}
	}
	for side in 0 ..< 2 {draw_box(side)}
	// The shell and its trail.
	sh := &g.shell
	if sh.state != .None {
		for i in 0 ..< sh.trail_len {
			if i % 3 != 0 {continue}
			p := sh.trail[i]
			if p[1] >= 0 {gfx.rect(int(p[0]), int(p[1]), 1, 1, 0xc8c0a0)}
		}
	}
	if sh.state == .Flying {
		if sh.y >= 0 {
			gfx.rect(int(sh.x) - 1, int(sh.y) - 1, 3, 3, TEXT)
		} else {
			// Above the top of the screen: a marker shows where it is.
			gfx.rect(int(sh.x) - 2, 25, 5, 1, GOLD)
			gfx.rect(int(sh.x) - 1, 26, 3, 1, GOLD)
			gfx.rect(int(sh.x), 27, 1, 1, GOLD)
		}
	}
	for b in app.blasts {
		if b.t <= 0 {continue}
		life: f32 = b.big ? 1.0 : 0.6
		k := 1 - b.t / life
		r := (b.big ? 18 : 8) * (0.3 + k)
		n := b.big ? 22 : 12
		for i in 0 ..< n {
			a := f32(i) * 6.2831853 / f32(n) + f32(i) * 0.37
			rr := r * (0.5 + 0.5 * f32((i * 7) % 5) / 4)
			x := int(b.x + rr * math.cos(a))
			y := int(b.y + rr * math.sin(a) * 0.7)
			c: u32 = k < 0.3 ? 0xffffff : (k < 0.6 ? GOLD : RED)
			gfx.rect(x, y, 2, 2, c)
		}
	}
}

draw_box :: proc(side: int) {
	g := &app.g
	gu := g.gunners[side]
	x0 := gu.x - game.BOX_W / 2
	y0 := gu.y - game.BOX_H
	hit_now := app.hit_wait > 0 && ((g.shell.state == .Hit_Enemy && side != g.turn) || (g.shell.state == .Hit_Self && side == g.turn))
	body: u32 = hit_now && int(app.t * 10) % 2 == 0 ? RED : BOX
	gfx.rect(x0, y0 + 2, game.BOX_W, game.BOX_H - 2, body)
	gfx.rect(x0 + 2, y0, game.BOX_W - 4, 2, body)
	gfx.rect(x0 + 3, y0 + 3, game.BOX_W - 6, 1, BOX_DARK) // the slit
	// The barrel at its angle.
	dir: f32 = side == 0 ? 1 : -1
	a := f32(gu.angle) * 3.14159265 / 180
	mx, my := game.muzzle(g, side)
	for i in 0 ..< 9 {
		gfx.rect(int(mx + dir * f32(i) * math.cos(a)), int(my - f32(i) * math.sin(a)), 1, 1, side == 0 ? LEFT_C : RIGHT_C)
	}
}

blend :: proc(a, b: u32, t: f32) -> u32 {
	ch :: proc(a, b: u32, s: u32, t: f32) -> u32 {
		x := f32((a >> s) & 0xff)
		y := f32((b >> s) & 0xff)
		return u32(x + (y - x) * t) << s
	}
	return ch(a, b, 16, t) | ch(a, b, 8, t) | ch(a, b, 0, t)
}

draw_hud :: proc() {
	g := &app.g
	gfx.rect(0, 0, W, 24, PANEL)
	gfx.rect(0, 23, W, 1, 0x2e3a5e)
	for side in 0 ..< 2 {
		c: u32 = side == 0 ? LEFT_C : RIGHT_C
		name := side_name(side)
		x := side == 0 ? 6 : W - 6 - gfx.text_width(name)
		gfx.text(x, 3, name, g.turn == side && g.winner < 0 ? c : DIM)
		for i in 0 ..< game.HITS_TO_WIN {
			px := side == 0 ? 6 + i * 10 : W - 14 - i * 10
			on := i < g.gunners[side].hits
			gfx.rect(px, 14, 8, 6, on ? c : 0x2a3350)
		}
	}
	if app.one_player {gfx.text_c(W / 2, 3, fmt.tprintf("RECORD %d-%d", app.won, app.lost), DIM)}
	if app.msg_t > 0 {gfx.text_c(W / 2, 30, app.message, GOLD)}

	// The controls, for whoever is on.
	gu := g.gunners[g.turn]
	c: u32 = g.turn == 0 ? LEFT_C : RIGHT_C
	if g.winner >= 0 {return}
	y := H - 20
	gfx.rect(0, y - 4, W, 24, PANEL)
	if my_turn() {
		x := 6
		x += gfx.button(x, y, "-", ID_ANG_DOWN, TEXT, 0x26304f) + 2
		gfx.text(x + 2, y + 3, fmt.tprintf("ANGLE %2d", gu.angle), c)
		x += 70
		x += gfx.button(x, y, "+", ID_ANG_UP, TEXT, 0x26304f) + 10
		x += gfx.button(x, y, "-", ID_VEL_DOWN, TEXT, 0x26304f) + 2
		gfx.text(x + 2, y + 3, fmt.tprintf("VELOCITY %4d", gu.velocity), c)
		x += 110
		x += gfx.button(x, y, "+", ID_VEL_UP, TEXT, 0x26304f) + 10
		gfx.button(W - 46, y, "FIRE", ID_FIRE, GOLD, 0x4a2020)
	} else {
		gfx.text(6, y + 3, fmt.tprintf("ANGLE %2d  VELOCITY %4d", gu.angle, gu.velocity), DIM)
	}
}

draw_title :: proc() {
	gfx.rect(24, 34, W - 48, 150, PANEL)
	gfx.frame(24, 34, W - 48, 150, GOLD)
	gfx.text_c(W / 2, 44, "PILLBOX", GOLD, 3)
	lines := [?]string {
		"TWO GUNNERS, ONE MOUNTAIN.",
		"FIRST TO FIVE HITS WINS THE WAR.",
		"UP/DOWN: BARREL ANGLE",
		"LEFT/RIGHT: MUZZLE VELOCITY",
		"SPACE FIRES. OR TAP THE BUTTONS.",
	}
	for l, i in lines {gfx.text_c(W / 2, 76 + i * 11, l, TEXT)}
	gfx.button(W / 2 - 160, 136, "1: VS THE COMPUTER", ID_ONE, GOLD, 0x26304f)
	gfx.button(W / 2 + 8, 136, "2: TWO GUNNERS", ID_TWO, TEXT, 0x26304f)
	gfx.text_c(W / 2, 162, fmt.tprintf("RECORD VS THE COMPUTER %d-%d", app.won, app.lost), DIM)
	gfx.text_c(W / 2, 172, "AFTER GENE PERKINS, SOFTSIDE 1978", DIM)
}

draw_over :: proc() {
	g := &app.g
	gfx.rect(56, 60, W - 112, 100, PANEL)
	gfx.frame(56, 60, W - 112, 100, GOLD)
	gfx.text_c(W / 2, 70, "THE WAR IS OVER", GOLD, 2)
	verdict: string
	if app.one_player {
		verdict = g.winner == 0 ? "YOU WIN!" : "THE COMPUTER WINS"
	} else {
		verdict = fmt.tprintf("%s WINS!", side_name(g.winner))
	}
	gfx.text_c(W / 2, 96, verdict, g.winner == 0 ? LEFT_C : RIGHT_C)
	gfx.text_c(W / 2, 110, fmt.tprintf("%d HITS TO %d", g.gunners[g.winner].hits, g.gunners[1 - g.winner].hits), TEXT)
	if app.t > 1 {
		gfx.button(W / 2 - 92, 132, "PLAY AGAIN", ID_AGAIN, TEXT, 0x26304f)
		gfx.button(W / 2 + 20, 132, "TITLE", ID_MENU, DIM, 0x26304f)
	}
}
