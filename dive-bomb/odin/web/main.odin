#+build js
package main

// Dive Bomb's page: drawing, keys and taps. Rules are in ../game.

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:strconv"
import game "../game"
import "proto:gfx"

W :: 384
H :: 240
SX :: 3 // screen pixels per listing column
SY :: 4 // and per row
TOP :: 24

SKY_HI :: 0x1b2a4a
SKY_LO :: 0x3b5a86
SEA :: 0x1d4f6e
SEA_LIT :: 0x2f7aa0
HUD :: 0x0f1626
TEXT :: 0xf1ead8
DIM :: 0x8f9bb3
GOLD :: 0xf4c542
RED :: 0xe8503a
HULL :: 0x9aa3ad
HULL_DARK :: 0x5d6670
PLANE :: 0xd8d0b8
PLANE_DARK :: 0x8c8470
FLAK :: 0xffe08a
BTN :: 0x26324a

Screen :: enum {
	Title,
	Playing,
	Over,
}

Mode :: enum {
	Fly, // you fly the bomber, the computer mans the gun
	Gun, // you man the gun
	Two,
}

Spark :: struct {
	x, y, vx, vy, t: f32,
	col:             u32,
}

App :: struct {
	screen:  Screen,
	mode:    Mode,
	skill:   int,
	g:       game.Game,
	t:       f32,
	sparks:  [48]Spark,
	banner:  string,
	record:  [2][2][2]int, // [mode Fly/Gun][skill][won, lost]
	held_z:  bool,
}

app: App

ID_FLY :: 1
ID_GUN :: 2
ID_TWO :: 3
ID_SKILL :: 4
ID_DIVE :: 10
ID_LEVEL :: 11
ID_DROP :: 12
ID_FIRE :: 13
ID_AGAIN :: 20
ID_MENU :: 21

main :: proc() {
	buf: [64]u8
	for m in 0 ..< 2 {
		for s in 0 ..< 2 {
			for r in 0 ..< 2 {
				if v, ok := gfx.store_get(fmt.tprintf("rec%d_%d_%d", m, s, r), buf[:]); ok {
					if n, nok := strconv.parse_int(v); nok && n >= 0 {app.record[m][s][r] = n}
				}
			}
		}
	}
	game.new_game(&app.g, 7, true, true, 1) // the duel runs behind the title
}

start :: proc(m: Mode) {
	app.mode = m
	seed := u64(gfx.now_ms()) ~ u64(gfx.random() * 1e9)
	game.new_game(&app.g, seed, m == .Gun, m == .Fly, app.skill)
	app.screen = .Playing
	app.banner = ""
	gfx.tone(220, 90, .Square, 0.05)
	gfx.tone(330, 140, .Square, 0.05, 100)
}

@(export)
step :: proc(dt: f64) -> bool {
	d := f32(min(dt, 0.1))
	app.t += d
	for &s in app.sparks {
		if s.t > 0 {
			s.t -= d
			s.x += s.vx * d
			s.y += s.vy * d
			s.vy += 40 * d
		}
	}
	switch app.screen {
	case .Title:
		game.update(&app.g, d)
		app.g.events = {}
		if app.g.over {game.new_game(&app.g, u64(app.t * 1000) + 1, true, true, 1)}
	case .Playing:
		game.update(&app.g, d)
		sounds()
	case .Over:
	}
	draw()
	free_all(context.temp_allocator)
	return true
}

burst :: proc(x, y: f32, n: int, col: u32) {
	k := 0
	for &s in app.sparks {
		if s.t <= 0 {
			a := f32(gfx.random()) * 6.283
			sp := 20 + f32(gfx.random()) * 60
			s = {x, y, sp * cos32(a), sp * sin32(a) - 30, 0.6 + f32(gfx.random()) * 0.6, col}
			k += 1
			if k >= n {break}
		}
	}
}

cos32 :: proc(a: f32) -> f32 {return math.cos(a)}
sin32 :: proc(a: f32) -> f32 {return math.sin(a)}

sounds :: proc() {
	g := &app.g
	ev := g.events
	g.events = {}
	if .Dive in ev {gfx.tone(660, 300, .Saw, 0.025); gfx.tone(440, 300, .Saw, 0.025, 280)}
	if .Drop in ev {gfx.tone(900, 220, .Sine, 0.04); gfx.tone(500, 200, .Sine, 0.04, 200)}
	if .Fire in ev {gfx.noise(70, 0.15)}
	if .Jam in ev {gfx.tone(120, 60, .Square, 0.05); gfx.tone(110, 60, .Square, 0.05, 80)}
	if .Splash in ev {gfx.noise(160, 0.06); burst(f32(g.bomb.x * SX), f32(TOP + 46 * SY), 8, SEA_LIT)}
	if .Sunk in ev {
		gfx.noise(600, 0.25)
		gfx.tone(80, 500, .Saw, 0.06, 100)
		burst(f32((g.ship - 12) * SX), f32(TOP + 45 * SY), 30, RED)
		app.banner = "SHIP SUNK"
	}
	if .Downed in ev {
		gfx.noise(400, 0.22)
		gfx.tone(500, 600, .Saw, 0.04)
		gfx.tone(250, 500, .Saw, 0.04, 300)
		burst(f32(g.px * SX + 6), f32(TOP + g.py * SY), 30, FLAK)
		app.banner = "BOMBER GOES DOWN IN FLAMES"
	}
	if .Match_Over in ev {
		app.screen = .Over
		app.t = 0
		if app.mode != .Two {
			m := app.mode == .Fly ? 0 : 1
			mine := app.mode == .Fly ? game.Side.Bomber : game.Side.Gunner
			r := g.winner == mine ? 0 : 1
			app.record[m][app.skill][r] += 1
			gfx.store_set(fmt.tprintf("rec%d_%d_%d", m, app.skill, r), fmt.tprintf("%d", app.record[m][app.skill][r]))
		}
	}
	if g.pause <= 0 && !g.over {app.banner = ""} // banners last as long as the pause after a hit
}

// ---- input ----

human :: proc(s: game.Side) -> bool {
	return !app.g.cpu[s]
}

act :: proc(id: int) {
	g := &app.g
	switch id {
	case ID_DIVE:
		if human(.Bomber) {game.dive(g)}
	case ID_LEVEL:
		if human(.Bomber) {game.level(g)}
	case ID_DROP:
		if human(.Bomber) {game.drop(g)}
	case ID_FIRE:
		if human(.Gunner) {game.fire(g)}
	}
}

@(export)
on_key :: proc "c" (code: i32, down: i32) {
	context = runtime.default_context()
	if down != 1 {return}
	c := int(code)
	switch app.screen {
	case .Title:
		switch c {
		case '1':
			start(.Fly)
		case '2':
			start(.Gun)
		case '3':
			start(.Two)
		case 'S':
			app.skill = 1 - app.skill
		}
	case .Playing:
		switch c {
		case 'Z':
			act(ID_DIVE)
		case 'A':
			act(ID_LEVEL)
		case 'X':
			act(ID_DROP)
		case '/', '?', gfx.KEY_SPACE, gfx.KEY_ENTER:
			// one player at the gun also fires with space or Enter; a lone bomber drops with them
			if c == '/' || c == '?' || human(.Gunner) {act(ID_FIRE)} else {act(ID_DROP)}
		case gfx.KEY_DOWN:
			if app.mode == .Fly {act(ID_DIVE)}
		case gfx.KEY_UP:
			if app.mode == .Fly {act(ID_LEVEL)}
		case gfx.KEY_ESCAPE:
			app.screen = .Title
			game.new_game(&app.g, 7, true, true, 1)
		}
	case .Over:
		if app.t > 1 {
			if c == gfx.KEY_ENTER || c == gfx.KEY_SPACE {start(app.mode)}
			if c == gfx.KEY_ESCAPE {app.screen = .Title; game.new_game(&app.g, 7, true, true, 1)}
		}
	}
}

@(export)
on_pointer :: proc "c" (x, y: f32, kind: i32) {
	context = runtime.default_context()
	if kind != 0 {return}
	id := gfx.hit(x, y)
	switch app.screen {
	case .Title:
		switch id {
		case ID_FLY:
			start(.Fly)
		case ID_GUN:
			start(.Gun)
		case ID_TWO:
			start(.Two)
		case ID_SKILL:
			app.skill = 1 - app.skill
		}
	case .Playing:
		if id == ID_MENU {app.screen = .Title; game.new_game(&app.g, 7, true, true, 1)} else {act(id)}
	case .Over:
		if app.t > 1 {
			if id == ID_AGAIN {start(app.mode)}
			if id == ID_MENU {app.screen = .Title; game.new_game(&app.g, 7, true, true, 1)}
		}
	}
}

// ---- drawing ----

draw :: proc() {
	gfx.begin_buttons()
	draw_world()
	switch app.screen {
	case .Title:
		draw_title()
	case .Playing:
		draw_hud()
		draw_controls()
	case .Over:
		draw_hud()
		draw_over()
	}
}

draw_world :: proc() {
	g := &app.g
	gfx.clear(HUD)
	// sky in bands
	for i in 0 ..< 8 {
		t := f32(i) / 7
		r := u32(f32(0x1b) + (f32(0x3b) - f32(0x1b)) * t)
		gg := u32(f32(0x2a) + (f32(0x5a) - f32(0x2a)) * t)
		b := u32(f32(0x4a) + (f32(0x86) - f32(0x4a)) * t)
		gfx.rect(0, TOP + i * 23, W, 24, r << 16 | gg << 8 | b)
	}
	// the floor the plane can dive to
	for x := 0; x < W; x += 12 {gfx.rect(x, TOP + (game.PLANE_LOW + 1) * SY, 4, 1, 0x4a6a96)}
	// the sea
	sea_y := TOP + 46 * SY
	gfx.rect(0, sea_y, W, 2 * SY, SEA)
	for x := 0; x < W; x += 16 {
		o := int(app.t * 12) % 16
		gfx.rect((x + o) % W, sea_y + 2, 6, 1, SEA_LIT)
	}
	draw_ship()
	if g.pause <= 0 || app.g.last != .Gunner {draw_plane()}
	// the shell's tracer
	if g.shell.active {
		for k in max(0, g.shell.k - 4) ..= g.shell.k {
			x, y := game.shell_point(g.shell, k)
			col := k == g.shell.k ? u32(FLAK) : u32(0xc08a3a)
			gfx.rect(x * SX, TOP + y * SY, SX, SY - 1, col)
		}
	}
	if g.bomb.active {
		gfx.rect(g.bomb.x * SX, TOP + g.bomb.y * SY, SX, SY + 2, 0x202020)
		gfx.rect(g.bomb.x * SX, TOP + g.bomb.y * SY, SX, 2, 0x606060)
	}
	for s in app.sparks {
		if s.t > 0 {gfx.rectf(s.x, s.y, 2, 2, s.col)}
	}
}

draw_ship :: proc() {
	g := &app.g
	if g.pause > 0 && g.last == .Bomber {
		// sinking: the hull slides under
		d := int((game.PAUSE - g.pause) * 8)
		y := TOP + 46 * SY + d
		x0 := (g.ship - (game.SHIP_LEN - 1)) * SX
		gfx.rect(x0, y, game.SHIP_LEN * SX, max(0, 2 * SY - d), HULL_DARK)
		return
	}
	x0 := (g.ship - (game.SHIP_LEN - 1)) * SX
	y := TOP + 46 * SY
	w := game.SHIP_LEN * SX
	gfx.rect(x0 + 3, y, w - 3, SY, HULL)
	gfx.rect(x0 + 6, y + SY, w - 9, SY - 1, HULL_DARK)
	gfx.rect(x0 + w - 3, y, 3, 2, HULL) // bow
	// the listing's superstructure point at ship-20, and a funnel and gun
	gfx.rect((g.ship - 20) * SX, y - SY, SX, SY, HULL)
	gfx.rect((g.ship - 20) * SX, y - 2 * SY, 2, SY, HULL_DARK)
	gfx.rect((g.ship - 14) * SX, y - 6, 9, 6, HULL)
	gfx.rect((g.ship - 13) * SX, y - 10, 5, 4, HULL_DARK)
	gx := (g.ship - 6) * SX
	gfx.rect(gx, y - 4, 6, 4, HULL)
	gfx.rect(gx + 4, y - 7, 2, 3, HULL_DARK)
	gfx.rect(gx + 6, y - 9, 2, 2, HULL_DARK)
	// shells left
	for i in 0 ..< g.shells {gfx.rect(x0 + 6 + i * 4, y + 2, 2, 2, GOLD)}
}

draw_plane :: proc() {
	g := &app.g
	if g.px < -6 || g.px > game.WIDTH {return}
	x := g.px * SX
	y := TOP + g.py * SY
	nose_down := g.diving && g.py < game.PLANE_LOW && g.px > game.DIVE_MARGIN
	// body along the listing's five points, fin at the fifth
	gfx.rect(x, y, 15, 3, PLANE)
	gfx.rect(x + 12, y - SY, 3, SY, PLANE_DARK) // tail fin (px+4, py-1)
	gfx.rect(x + 4, y - 1, 6, 1, PLANE_DARK) // wing
	gfx.rect(x + 3, y + 3, 7, 1, PLANE_DARK)
	if nose_down {gfx.rect(x - 2, y + 2, 3, 3, PLANE)} else {gfx.rect(x - 2, y + 1, 2, 1, PLANE_DARK)}
	if g.bomb_left {gfx.rect(x + 6, y + 3, 3, 2, 0x303030)}
	// propeller
	if int(app.t * 20) % 2 == 0 {gfx.rect(x - 3, y - 2, 1, 7, DIM)}
}

draw_hud :: proc() {
	g := &app.g
	gfx.rect(0, 0, W, TOP, HUD)
	b := app.mode == .Gun ? "CPU BOMBER" : (app.mode == .Two ? "BOMBER" : "YOU: BOMBER")
	gun := app.mode == .Fly ? "CPU GUN" : (app.mode == .Two ? "GUN" : "YOU: GUN")
	gfx.text(6, 8, fmt.tprintf("%s %d", b, g.score[.Bomber]), PLANE)
	s := fmt.tprintf("%d %s", g.score[.Gunner], gun)
	gfx.text(W - 6 - gfx.text_width(s), 8, s, HULL)
	gfx.text_c(W / 2, 8, fmt.tprintf("TO %d", game.WIN_POINTS), DIM)
	if app.banner != "" {
		gfx.rect(W / 2 - gfx.text_width(app.banner) / 2 - 6, 70, gfx.text_width(app.banner) + 12, 16, HUD)
		gfx.text_c(W / 2, 74, app.banner, app.banner == "SHIP SUNK" ? RED : GOLD)
	}
}

draw_controls :: proc() {
	g := &app.g
	y := H - 22
	gfx.rect(0, y - 2, W, 24, HUD)
	if human(.Bomber) {
		x := 4
		x += gfx.button(x, y, "Z DIVE", ID_DIVE, g.diving ? GOLD : TEXT, BTN) + 4
		x += gfx.button(x, y, "A LEVEL", ID_LEVEL, TEXT, BTN) + 4
		gfx.button(x, y, "X BOMB", ID_DROP, game.can_drop(g) ? GOLD : DIM, BTN)
	}
	if human(.Gunner) {
		label := fmt.tprintf("/ FIRE (%d)", g.shells)
		bw := gfx.text_width(label) + 8
		gfx.button(W - 4 - bw, y, label, ID_FIRE, game.can_fire(g) ? GOLD : DIM, BTN)
	}
	mx := app.mode == .Gun ? 4 : (app.mode == .Fly ? W - 4 - 48 : W / 2 - 24)
	gfx.button(mx, y, "MENU", ID_MENU, DIM, BTN)
}

draw_title :: proc() {
	gfx.rect(0, 0, W, TOP, HUD)
	gfx.text_c(W / 2, 30, "DIVE BOMB!", GOLD, 3)
	gfx.text_c(W / 2, 62, "Z DIVE  A LEVEL OFF  X DROP THE BOMB", TEXT)
	gfx.text_c(W / 2, 74, "/ FIRES THE GUN: IT JAMS AFTER THREE", TEXT)
	gfx.button(40, 92, "1 FLY THE BOMBER", ID_FLY, TEXT, BTN)
	gfx.button(208, 92, "2 MAN THE GUN", ID_GUN, TEXT, BTN)
	gfx.button(40, 114, "3 TWO PLAYERS", ID_TWO, TEXT, BTN)
	gfx.button(208, 114, app.skill == 1 ? "S: CPU IS ACE" : "S: CPU IS ROOKIE", ID_SKILL, GOLD, BTN)
	r := app.record
	gfx.text(40, 138, fmt.tprintf("BOMBER %d-%d", r[0][app.skill][0], r[0][app.skill][1]), DIM)
	gfx.text(208, 138, fmt.tprintf("GUNNER %d-%d", r[1][app.skill][0], r[1][app.skill][1]), DIM)
	gfx.text_c(W / 2, 160, "AFTER \"DIVE BOMB\" BY REV. GEORGE BLANK", DIM)
	gfx.text_c(W / 2, 172, "(SOFTSIDE, MARCH 1979)", DIM)
}

draw_over :: proc() {
	g := &app.g
	gfx.rect(64, 90, W - 128, 70, HUD)
	gfx.frame(64, 90, W - 128, 70, DIM)
	w: string
	if app.mode == .Two {
		w = g.winner == .Bomber ? "THE BOMBER WINS" : "THE GUN WINS"
	} else {
		mine := app.mode == .Fly ? game.Side.Bomber : game.Side.Gunner
		w = g.winner == mine ? "YOU WIN!" : "THE COMPUTER WINS"
	}
	gfx.text_c(W / 2, 98, w, GOLD, 1)
	gfx.text_c(W / 2, 112, fmt.tprintf("BOMBER %d  GUN %d", g.score[.Bomber], g.score[.Gunner]), TEXT)
	if app.t > 1 {
		gfx.button(92, 132, "AGAIN", ID_AGAIN, TEXT, BTN)
		gfx.button(W - 92 - 48, 132, "MENU", ID_MENU, DIM, BTN)
	}
}
