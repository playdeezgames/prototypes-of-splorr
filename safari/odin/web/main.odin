#+build js
package main

// Safari's page: drawing, keys and taps. Rules are in ../game.

import "base:runtime"
import "core:fmt"
import "core:strconv"
import "core:strings"
import game "../game"
import "proto:gfx"

W :: 384
H :: 240

BG :: 0x1d1a14
PANEL :: 0x2e2a20
LINE :: 0x4a4434
TEXT :: 0xf0e6cc
DIM :: 0x9a8f76
GOLD :: 0xf2c14e
RED :: 0xe0603f
GREEN :: 0x8cc152
GRASS :: 0x6b7a2c
GRASS_D :: 0x56631f
SKY :: 0xe9b96a
PATH :: 0xd9c38a

ANIMAL_COL := [10]u32{0, 0xd9a441, 0xe07a2f, 0x9a9a9a, 0x8a6a4a, 0x7f8c8d, 0xc8925a, 0xe0b040, 0xe8c26a, 0x6c6058}

Screen :: enum {
	Title,
	Country, // the starting map
	Handover,
	Play,
	Over,
}

App :: struct {
	screen:     Screen,
	g:          game.Game,
	t:          f32,
	players:    int,
	level:      int,
	computer:   [game.MAX_PLAYERS]bool,
	// the outfit form
	o_scouts:   bit_set[game.Dir],
	o_cameras:  int,
	o_bearers:  int,
	// pacing
	film_t:     f32,
	ai_t:       f32,
	show_map:   bool, // the starting map over the play screen
	bump:       f32, // "no passage" flash
	best:       [4]int,
	new_best:   bool,
	from_title: bool,
}

app: App

ID_PL_MINUS :: 100
ID_PL_PLUS :: 101
ID_SEAT :: 110 // + seat
ID_LEVEL :: 120 // + level
ID_START :: 130
ID_BEGIN :: 131
ID_GO :: 132
ID_N :: 140 // + Move
ID_MAP :: 150
ID_CONTINUE :: 151
ID_SCOUT :: 160 // + Dir
ID_CAM_MINUS :: 170
ID_CAM_PLUS :: 171
ID_BEAR_MINUS :: 172
ID_BEAR_PLUS :: 173
ID_SET_OUT :: 174
ID_RETIRE :: 175
ID_SNAP :: 180
ID_AGAIN :: 190
ID_MENU :: 191
ID_CLOSE :: 192

main :: proc() {
	app.players = 1
	app.level = 1
	app.computer = {false, true, true, true, true, true}
	buf: [64]u8
	for l in 1 ..= 3 {
		if v, ok := gfx.store_get(fmt.tprintf("best%d", l), buf[:]); ok {
			if n, nok := strconv.parse_int(v); nok && n > 0 {app.best[l] = n}
		}
	}
	if v, ok := gfx.store_get("setup", buf[:]); ok && len(v) == 8 {
		app.players = clamp(int(v[0] - '0'), 1, 6)
		app.level = clamp(int(v[1] - '0'), 1, 3)
		for i in 0 ..< 6 {app.computer[i] = v[2 + i] == 'C'}
	}
}

save_setup :: proc() {
	b: [8]u8
	b[0] = u8('0' + app.players)
	b[1] = u8('0' + app.level)
	for i in 0 ..< 6 {b[2 + i] = app.computer[i] ? 'C' : 'H'}
	gfx.store_set("setup", string(b[:]))
}

humans :: proc() -> int {
	n := 0
	for i in 0 ..< app.players {if !app.computer[i] {n += 1}}
	return n
}

start :: proc() {
	save_setup()
	game.new_game(&app.g, u64(gfx.now_ms()) ~ u64(gfx.random() * 1e9), app.players, app.level, app.computer[:app.players])
	app.screen = .Country
	app.t = 0
	app.new_best = false
	gfx.tone(392, 90, .Triangle, 0.06)
	gfx.tone(523, 120, .Triangle, 0.06, 90)
}

name :: proc(i: int) -> string {
	return app.g.p[i].computer ? fmt.tprintf("BWANA %d (CPU)", i + 1) : fmt.tprintf("BWANA %d", i + 1)
}

me :: proc() -> ^game.Player {return game.cur(&app.g)}

// A new turn has begun: hand over, or set up the outfit form.
turn_begun :: proc() {
	app.t = 0
	app.ai_t = 0
	app.show_map = false
	pl := me()
	if app.g.phase == .Outfit {
		app.o_scouts = {}
		app.o_cameras = min(1, game.max_cameras(pl))
		app.o_bearers = clamp(8, 3, pl.bearers[1])
	}
	if !pl.computer && humans() > 1 && app.g.phase != .Report {
		app.screen = .Handover
	} else {
		app.screen = .Play
	}
}

advance :: proc() {
	g := &app.g
	game.next_turn(g)
	if g.phase == .Over {
		app.screen = .Over
		app.t = 0
		if g.players == 1 && !g.p[0].computer && g.p[0].points > app.best[g.level] {
			app.best[g.level] = g.p[0].points
			app.new_best = true
			gfx.store_set(fmt.tprintf("best%d", g.level), fmt.tprintf("%d", g.p[0].points))
		}
		notes := [?]f32{392, 494, 587, 784}
		for f, i in notes {gfx.tone(f, 160, .Triangle, 0.06, f32(i) * 130)}
		return
	}
	turn_begun()
}

day_sounds :: proc() {
	g := &app.g
	for i in 0 ..< g.nmsg {
		#partial switch g.msgs[i].kind {
		case .Got_Picture:
			gfx.tone(659, 80, .Square, 0.05)
			gfx.tone(880, 140, .Square, 0.05, 90)
		case .Missed_Picture, .Too_Slow:
			gfx.tone(220, 180, .Saw, 0.04)
		case .Head_Hunters, .Scout_Lost, .Crewman_Lost, .Bearer_Lost, .Supplies_Lost, .Camera_Lost, .Disoriented, .Bearer_Starved, .Cameraman_Starved:
			gfx.tone(147, 220, .Saw, 0.05)
			gfx.tone(110, 260, .Saw, 0.05, 200)
		case .Home:
			gfx.tone(523, 90, .Triangle, 0.06)
			gfx.tone(784, 160, .Triangle, 0.06, 100)
		case .Map:
			gfx.tone(330, 300, .Sine, 0.06)
		}
	}
}

do_move :: proc(m: game.Move) {
	g := &app.g
	if g.phase != .Move {return}
	if !game.move(g, m) {
		app.bump = 0.6
		gfx.tone(98, 120, .Square, 0.05)
		return
	}
	gfx.noise(40, 0.05)
	gfx.noise(40, 0.05, 120)
	app.t = 0
	app.ai_t = 0
	app.film_t = 0
	if g.phase == .Report {day_sounds()}
	if g.phase == .Filming {gfx.tone(1200, 30, .Square, 0.04)}
}

set_out :: proc() {
	g := &app.g
	if game.outfit(g, app.o_scouts, app.o_cameras, app.o_bearers) {
		gfx.tone(440, 70, .Triangle, 0.06)
		gfx.tone(587, 90, .Triangle, 0.06, 70)
		app.t = 0
	}
}

snap :: proc() {
	g := &app.g
	if g.phase != .Filming {return}
	game.film_snap(g)
	gfx.noise(30, 0.12)
	day_sounds()
	app.t = 0
}

@(export)
step :: proc(dt: f64) -> bool {
	d := f32(min(dt, 0.1))
	app.t += d
	app.bump = max(0, app.bump - d)
	g := &app.g
	if app.screen == .Play {
		pl := me()
		if g.phase == .Filming {
			app.film_t += d
			for app.film_t >= game.FILM_TICK && g.phase == .Filming {
				app.film_t -= game.FILM_TICK
				if pl.computer {game.ai_film(g)}
				if g.phase == .Filming {game.film_tick(g)}
				if g.phase == .Report {day_sounds(); app.t = 0}
			}
		} else if pl.computer && !app.show_map {
			app.ai_t += d
			switch g.phase {
			case .Outfit:
				if app.ai_t > 0.9 {game.ai_outfit(g); app.ai_t = 0; app.t = 0}
			case .Move:
				if app.ai_t > 0.7 {
					before := g.phase
					game.ai_move(g)
					if g.phase != before {
						gfx.noise(40, 0.04)
						if g.phase == .Report {day_sounds()}
						app.film_t = 0
					}
					app.ai_t = 0
					app.t = 0
				}
			case .Report:
				if app.ai_t > 2.2 {advance()}
			case .Filming, .Over:
			}
		}
	}
	draw()
	free_all(context.temp_allocator)
	return true
}

// ---- input ----

key_move :: proc(c: int) -> (game.Move, bool) {
	switch c {
	case gfx.KEY_UP, 'N': return .North, true
	case gfx.KEY_RIGHT, 'E': return .East, true
	case gfx.KEY_DOWN: return .South, true
	case gfx.KEY_LEFT, 'W': return .West, true
	case 'S': return .Stay, true
	case 'L': return .Lost, true
	}
	return .Stay, false
}

@(export)
on_key :: proc "c" (code: i32, down: i32) {
	context = runtime.default_context()
	if down != 1 {return}
	c := int(code)
	g := &app.g
	switch app.screen {
	case .Title:
		switch c {
		case gfx.KEY_ENTER, gfx.KEY_SPACE: start()
		case '1' ..= '6': app.players = c - '0'
		case gfx.KEY_LEFT: app.players = max(1, app.players - 1)
		case gfx.KEY_RIGHT: app.players = min(6, app.players + 1)
		case 'B': app.level = 1
		case 'A': app.level = 2
		case 'X': app.level = 3
		}
	case .Country:
		if app.t > 0.4 && (c == gfx.KEY_ENTER || c == gfx.KEY_SPACE) {turn_begun()}
	case .Handover:
		if app.t > 0.3 && (c == gfx.KEY_ENTER || c == gfx.KEY_SPACE) {app.screen = .Play; app.t = 0}
	case .Play:
		if app.show_map {
			if c == gfx.KEY_ENTER || c == gfx.KEY_ESCAPE || c == gfx.KEY_SPACE || c == 'M' {app.show_map = false}
			return
		}
		pl := me()
		if c == 'M' && g.phase != .Filming {app.show_map = true; return}
		if pl.computer {
			if g.phase == .Report && (c == gfx.KEY_ENTER || c == gfx.KEY_SPACE) {advance()}
			return
		}
		switch g.phase {
		case .Outfit:
			switch c {
			case 'N': app.o_scouts ~= {.North}
			case 'E': app.o_scouts ~= {.East}
			case 'S': app.o_scouts ~= {.South}
			case 'W': app.o_scouts ~= {.West}
			case gfx.KEY_UP: app.o_cameras = min(app.o_cameras + 1, game.max_cameras(pl))
			case gfx.KEY_DOWN: app.o_cameras = max(app.o_cameras - 1, 0)
			case gfx.KEY_RIGHT: app.o_bearers = min(app.o_bearers + 1, pl.bearers[1])
			case gfx.KEY_LEFT: app.o_bearers = max(app.o_bearers - 1, 3)
			case gfx.KEY_ENTER: set_out()
			}
			for d in game.Dir {if pl.scouts[d] != .Base {app.o_scouts -= {d}}}
		case .Move:
			if m, ok := key_move(c); ok {do_move(m)}
		case .Filming:
			switch c {
			case gfx.KEY_UP: game.film_key(g, .Up)
			case gfx.KEY_DOWN: game.film_key(g, .Down)
			case gfx.KEY_LEFT: game.film_key(g, .Left)
			case gfx.KEY_RIGHT: game.film_key(g, .Right)
			case gfx.KEY_ENTER, gfx.KEY_SPACE: snap()
			}
		case .Report:
			if app.t > 0.3 && (c == gfx.KEY_ENTER || c == gfx.KEY_SPACE) {advance()}
		case .Over:
		}
	case .Over:
		if app.t > 0.8 {
			if c == gfx.KEY_ENTER || c == gfx.KEY_SPACE {start()}
			if c == gfx.KEY_ESCAPE {app.screen = .Title}
		}
	}
}

@(export)
on_pointer :: proc "c" (x, y: f32, kind: i32) {
	context = runtime.default_context()
	if kind != 0 {return}
	id := gfx.hit(x, y)
	g := &app.g
	switch app.screen {
	case .Title:
		switch {
		case id == ID_PL_MINUS: app.players = max(1, app.players - 1)
		case id == ID_PL_PLUS: app.players = min(6, app.players + 1)
		case id >= ID_SEAT && id < ID_SEAT + 6: app.computer[id - ID_SEAT] = !app.computer[id - ID_SEAT]
		case id >= ID_LEVEL + 1 && id <= ID_LEVEL + 3: app.level = id - ID_LEVEL
		case id == ID_START: start()
		}
	case .Country:
		if app.t > 0.4 && id == ID_BEGIN {turn_begun()}
	case .Handover:
		if app.t > 0.3 {app.screen = .Play; app.t = 0}
	case .Play:
		if app.show_map {
			app.show_map = false
			return
		}
		if id == ID_MAP {app.show_map = true; return}
		pl := me()
		if pl.computer {
			if g.phase == .Report && id == ID_CONTINUE {advance()}
			return
		}
		switch g.phase {
		case .Outfit:
			switch {
			case id >= ID_SCOUT && id < ID_SCOUT + 4:
				d := game.Dir(id - ID_SCOUT)
				if pl.scouts[d] == .Base {app.o_scouts ~= {d}}
			case id == ID_CAM_MINUS: app.o_cameras = max(app.o_cameras - 1, 0)
			case id == ID_CAM_PLUS: app.o_cameras = min(app.o_cameras + 1, game.max_cameras(pl))
			case id == ID_BEAR_MINUS: app.o_bearers = max(app.o_bearers - 1, 3)
			case id == ID_BEAR_PLUS: app.o_bearers = min(app.o_bearers + 1, pl.bearers[1])
			case id == ID_SET_OUT: set_out()
			case id == ID_RETIRE: game.retire(g); app.t = 0
			}
		case .Move:
			if id >= ID_N && id < ID_N + 6 {do_move(game.Move(id - ID_N))}
		case .Filming:
			if id == ID_SNAP {snap(); return}
			// a tap moves the frame a step toward it
			f := &g.film
			cx, cy := game.frame_centre(f)
			tx := int(x) / CW
			ty := int(y) / CH
			if abs(tx - cx) * CH >= abs(ty - cy) * CW {
				if tx > cx + 1 {game.film_key(g, .Right)} else if tx < cx - 1 {game.film_key(g, .Left)}
			} else {
				if ty > cy {game.film_key(g, .Down)} else if ty < cy {game.film_key(g, .Up)}
			}
		case .Report:
			if app.t > 0.3 && id == ID_CONTINUE {advance()}
		case .Over:
		}
	case .Over:
		if app.t > 0.8 {
			if id == ID_AGAIN {start()}
			if id == ID_MENU {app.screen = .Title}
		}
	}
}

// ---- drawing ----

draw :: proc() {
	gfx.begin_buttons()
	gfx.clear(BG)
	switch app.screen {
	case .Title: draw_title()
	case .Country: draw_country(true)
	case .Handover: draw_handover()
	case .Play:
		if app.show_map {
			draw_country(false)
		} else if app.g.phase == .Filming {
			draw_film()
		} else if app.g.phase == .Outfit {
			draw_outfit()
		} else {
			draw_day()
		}
	case .Over: draw_over()
	}
}

LEVEL_NAME := [4]string{"", "BEGINNER", "AVERAGE", "EXPERT"}

draw_title :: proc() {
	gfx.text_c(W / 2, 14, "S A F A R I", GOLD, 3)
	gfx.text_c(W / 2, 44, "FILM WILD ANIMALS FOR A MOVIE CONTRACT.", TEXT)
	gfx.text_c(W / 2, 56, "OUTFIT A PARTY, TRUST YOUR SCOUTS,", DIM)
	gfx.text_c(W / 2, 66, "AND REMEMBER THE WAY BACK TO CAMP.", DIM)
	gfx.text(40, 86, "BWANAS", TEXT)
	gfx.button(104, 82, "-", ID_PL_MINUS, TEXT, PANEL)
	gfx.text(126, 86, fmt.tprintf("%d", app.players), GOLD)
	gfx.button(140, 82, "+", ID_PL_PLUS, TEXT, PANEL)
	for i in 0 ..< 6 {
		x := 40 + (i % 3) * 104
		y := 104 + (i / 3) * 20
		if i < app.players {
			lab := app.computer[i] ? fmt.tprintf("%d COMPUTER", i + 1) : fmt.tprintf("%d PERSON  ", i + 1)
			gfx.button(x, y, lab, ID_SEAT + i, app.computer[i] ? DIM : TEXT, PANEL)
		} else {
			gfx.text(x + 4, y + 3, fmt.tprintf("%d -", i + 1), LINE)
		}
	}
	gfx.text(40, 152, "LEVEL", TEXT)
	x := 96
	for l in 1 ..= 3 {
		col := l == app.level ? u32(GOLD) : u32(DIM)
		x += gfx.button(x, 148, LEVEL_NAME[l], ID_LEVEL + l, col, PANEL) + 6
	}
	gfx.button(W / 2 - 40, 174, "START", ID_START, BG, GOLD, 2)
	if app.best[app.level] > 0 {gfx.text_c(W / 2, 200, fmt.tprintf("BEST ALONE (%s): %d", LEVEL_NAME[app.level], app.best[app.level]), GOLD)}
	gfx.text_c(W / 2, 214, "AFTER \"SAFARI\" BY DAVID J. BOHLKE", DIM)
	gfx.text_c(W / 2, 226, "(SOFTSIDE, APRIL 1979)", DIM)
}

// The starting map (lines 30-90), or the same again during play.
draw_country :: proc(at_start: bool) {
	g := &app.g
	gfx.text_c(W / 2, 6, "S A F A R I   M A P", GOLD)
	cs := 12
	ox := W / 2 - cs * game.SIZE / 2
	oy := 20
	gfx.rect(ox - 3, oy - 3, cs * game.SIZE + 6, cs * game.SIZE + 6, GRASS_D)
	animals := 0
	for r in 0 ..< game.SIZE {
		for c in 0 ..< game.SIZE {
			x := ox + c * cs
			y := oy + r * cs
			gfx.rect(x, y, cs - 1, cs - 1, GRASS)
			v := g.start[r][c]
			switch {
			case game.is_base(v):
				gfx.text(x + 2, y + 2, "B", TEXT)
				animals += 1
			case game.is_animal(v):
				gfx.text(x + 2, y + 2, "A", GOLD)
				animals += 1
			case:
				gfx.text(x + 2, y + 2, "+", GRASS_D)
			}
		}
	}
	gfx.text(ox, oy + cs * game.SIZE + 8, "B = BASE   A = ANIMALS", TEXT)
	gfx.text(ox + cs * game.SIZE - 24, oy + cs * game.SIZE + 8, fmt.tprintf("%3d", animals), DIM)
	if g.players > 1 {
		gfx.text(8, 204, "WHICH CAMP IS WHOSE?", DIM)
		gfx.text(8, 214, "YOU'LL HAVE TO FIND OUT.", DIM)
	} else {
		gfx.text(8, 204, "B IS YOUR CAMP. DISASTERS", DIM)
		gfx.text(8, 214, "DON'T SHOW ON ANY MAP.", DIM)
	}
	if at_start {
		if app.t > 0.4 {gfx.button(W - 80, 206, "BEGIN", ID_BEGIN, BG, GOLD)}
	} else {
		gfx.button(W - 80, 206, "CLOSE", ID_CLOSE, TEXT, PANEL)
	}
}

draw_handover :: proc() {
	gfx.text_c(W / 2, 80, fmt.tprintf("%s'S TURN", name(app.g.turn)), GOLD, 2)
	gfx.text_c(W / 2, 112, "THE OTHERS LOOK AWAY WHILE", DIM)
	gfx.text_c(W / 2, 124, "YOU READ YOUR SCOUTS.", DIM)
	gfx.text_c(W / 2, 160, "TAP OR PRESS ENTER", TEXT)
}

// ---- figures ----

person :: proc(x, y: int, col: u32) {
	gfx.rect(x + 1, y, 3, 3, col)
	gfx.rect(x, y + 3, 5, 3, col)
	gfx.rect(x, y + 6, 2, 3, col)
	gfx.rect(x + 3, y + 6, 2, 3, col)
}

scout_fig :: proc(x, y: int, col: u32) {
	gfx.rect(x - 1, y, 7, 1, GOLD) // hat brim
	person(x, y + 1, col)
}

camera_fig :: proc(x, y: int, col: u32) {
	person(x, y, col)
	gfx.rect(x + 5, y + 3, 3, 3, 0x30302a)
}

bearer_fig :: proc(x, y: int, col: u32) {
	gfx.rect(x, y, 5, 2, 0xb08a52) // the load
	person(x, y + 2, col)
}

// Draws the party (or the camp): returns the y below it.
draw_party :: proc(x, y: int, l: int) {
	pl := me()
	gfx.text(x, y, "SCOUTS", DIM)
	sx := x + 56
	for s, d in pl.scouts {
		want := l == 0 ? game.Scout.Party : game.Scout.Base
		if s == want {
			scout_fig(sx, y - 2, TEXT)
			gfx.text(sx - 1, y + 9, game.DIR_NAME[d][:1], DIM)
			sx += 14
		}
	}
	if sx == x + 56 {gfx.text(sx, y, "NONE", LINE)}
	men := pl.men[l]
	gfx.text(x, y + 22, fmt.tprintf("CAMERAMEN %d", men), DIM)
	for i in 0 ..< men {camera_fig(x + 104 + (i % 8) * 11, y + 20, TEXT)}
	b := pl.bearers[l]
	gfx.text(x, y + 38, fmt.tprintf("BEARERS %d", b), DIM)
	for i in 0 ..< min(b, 40) {bearer_fig(x + 92 + (i % 20) * 6, y + 34 + (i / 20) * 12, TEXT)}
}

// The scout report (lines 700-730, 960-993): paths drawn from the party each way.
draw_report :: proc(cx, cy: int) {
	g := &app.g
	pl := me()
	gfx.text(4, 20, "SCOUTS'", GOLD)
	gfx.text(4, 30, "REPORT", GOLD)
	for d in game.Dir {
		rep := game.report(g, pl, d)
		q := 0
		switch rep {
		case .Edge: q = 0
		case .Base_Camp: q = 1
		case .Animal: q = 2
		case .Nothing: q = 3
		case .No_Scout: q = 4
		}
		lx, ly := cx + game.DC[d] * 50, cy + game.DR[d] * 41
		gfx.text(lx - 4, ly - 4, game.DIR_NAME[d][:1], q == 0 ? LINE : DIM)
		if q == 0 {continue}
		col := u32(PATH)
		if rep == .Animal {col = GOLD}
		for k := 0; k < 11; k += q {
			wig := int((u32(pl.days * 31 + int(d) * 7 + k * 13) * 2654435761) >> 30) - 1 // -1..2
			dist := 9 + k * 3
			bx := cx + game.DC[d] * dist + (game.DC[d] == 0 ? wig : 0) - 2
			by := cy + game.DR[d] * dist + (game.DR[d] == 0 ? wig : 0) - 2
			gfx.rect(bx, by, 3, 3, col)
		}
	}
	// the party in the middle
	at_base := game.at_own_base(g, pl)
	gfx.rect(cx - 6, cy - 6, 12, 12, at_base ? GOLD : GRASS)
	gfx.text(cx - 4, cy - 4, at_base ? "B" : "S", BG)
	// the key: a sample of each path
	keys := [4]struct {q: int, lab: string} {{2, "ANIMAL"}, {1, "CAMP"}, {4, "NO SCOUT"}, {3, "NOTHING"}}
	for k, i in keys {
		kx := cx - 72 + (i % 2) * 80
		ky := cy + 50 + (i / 2) * 10
		for j := 0; j < 11; j += k.q {gfx.rect(kx + j, ky + 2, 1, 3, k.q == 2 ? u32(GOLD) : u32(PATH))}
		gfx.text(kx + 14, ky, k.lab, DIM)
	}
}

// The map a scout gave his life for (lines 3070-3110).
draw_map :: proc() {
	pl := me()
	cs := 8
	ox, oy := 4, 32
	for r in 0 ..< game.SIZE {
		for c in 0 ..< game.SIZE {
			x := ox + c * cs
			y := oy + r * cs
			col := u32(GRASS_D)
			if r == pl.br && c == pl.bc {col = GOLD}
			if r == pl.r && c == pl.c {col = RED}
			gfx.rect(x, y, cs - 1, cs - 1, col)
		}
	}
	gfx.text(114, 44, "B", GOLD)
	gfx.text(124, 44, "BASE", DIM)
	gfx.text(114, 58, "S", RED)
	gfx.text(124, 58, "YOU", DIM)
}

msg_text :: proc(m: game.Msg) -> (a, b: string) {
	an := game.ANIMALS[clamp(m.a, 0, 9)]
	cause := game.CAUSES[clamp(m.a, 0, 9)]
	switch m.kind {
	case .Quip: return game.QUIPS[clamp(m.a, 0, 9)], ""
	case .Home: return "YOU MADE IT TO YOUR BASE CAMP!", ""
	case .Other_Base: return "YOU'RE AT A BASE CAMP, BUT IT IS NOT YOURS! SUPPLIES ARE GUARDED, SO DON'T GET ANY FUNNY IDEAS.", ""
	case .No_Film: return fmt.tprintf("THERE'S A %s!", an), "TOO BAD YOU HAVE NO FILM LEFT."
	case .No_Crew: return fmt.tprintf("THERE'S A %s!", an), "TOO BAD YOU'RE SHORT ON CAMERAMEN!"
	case .Too_Late: return fmt.tprintf("THERE'S A %s!", an), "TOO BAD YOU'RE TOO LATE TO GET ANY CONTRACT POINTS."
	case .Got_Picture: return fmt.tprintf("YOU GOT SOME GOOD PICTURES OF A %s.", an), fmt.tprintf("THEY ARE WORTH %d CONTRACT POINTS.", m.n)
	case .Missed_Picture: return "SORRY, BUT YOU MISSED THE PICTURE.", ""
	case .Too_Slow: return "YOU'RE TOO SLOW WITH THE CAMERA!", ""
	case .Head_Hunters: return "DISASTER!!! MOST OF YOUR PARTY CAPTURED BY HEAD HUNTERS.", "YOU'LL HAVE A TOUGH TIME SURVIVING."
	case .Weary: return "A WEARY DAY.", ""
	case .Scout_Lost: return fmt.tprintf("SCOUT LOST %s", cause), ""
	case .Crewman_Lost: return fmt.tprintf("CAMERA CREWMAN AND FILM LOST %s", cause), ""
	case .Bearer_Lost: return fmt.tprintf("BEARER LOST %s", cause), ""
	case .Supplies_Lost: return fmt.tprintf("%d POUNDS OF SUPPLIES LOST %s", m.n, cause), ""
	case .Camera_Lost: return fmt.tprintf("CAMERA DESTROYED %s", cause), ""
	case .Disoriented: return "YOUR SCOUTS ARE COMPLETELY DISORIENTATED...", "YOU PROBABLY WON'T FIND YOUR WAY BACK TO BASE."
	case .Bearer_Starved: return "ONE BEARER STARVED.", ""
	case .Cameraman_Starved: return "ONE CAMERAMAN STARVED.", ""
	case .Map:
		pre := m.n == 1 ? "YOU ACT AS IF YOU ARE LOST, SO... " : ""
		who := [4]string{"SCOUT", "SCOUT FROM BASE", "CAMERAMAN", "CAMERAMAN FROM BASE"}
		if m.a == 4 {return fmt.tprintf("%sFROM A HIGH PEAK, YOU'VE MADE THIS MAP TO YOUR BASE CAMP.", pre), ""}
		return fmt.tprintf("%sYOUR %s GAVE HIS LIFE TO GET THIS MAP!", pre, who[clamp(m.a, 0, 3)]), ""
	case .Stayed: return "YOU STAY WHERE YOU ARE TODAY.", ""
	case .Out_No_Cameras: return "YOU HAVE NO CAMERAS (OR CAMERAMEN) TO TAKE PICTURES.", "YOU CAN NO LONGER PLAY."
	case .Out_No_Outfit: return "YOU DO NOT HAVE ENOUGH MINIMAL EQUIPMENT TO GO ON SAFARI.", "YOU CAN NO LONGER PLAY."
	case .Retired: return fmt.tprintf("YOU RETIRE FROM SAFARI WITH %d CONTRACT POINTS.", me().points), ""
	}
	return "", ""
}

// Word-wrapped lines; returns the y below.
wrap :: proc(x, y: int, s: string, width: int, col: u32) -> int {
	yy := y
	rest := s
	per := width / 8
	for len(rest) > 0 {
		n := len(rest)
		if n > per {
			n = per
			for i := per; i > 0; i -= 1 {if rest[i] == ' ' {n = i; break}}
		}
		gfx.text(x, yy, strings.trim_space(rest[:n]), col)
		rest = strings.trim_left_space(rest[n:])
		yy += 10
	}
	return yy
}

survey :: proc(x, y: int) {
	pl := me()
	l := game.at_own_base(&app.g, pl) ? 1 : 0 // at base, the camp's stock
	draw_party(x, y, l)
	yy := y + 64
	if l == 0 {
		daily := game.daily_food(game.party_scouts(pl), pl.men[0], pl.bearers[0])
		gfx.text(x, yy, fmt.tprintf("SUPPLIES %d LB", pl.supplies[0]), pl.supplies[0] < 100 ? RED : TEXT)
		gfx.text(x + 128, yy, fmt.tprintf("-%d A DAY", daily), DIM)
		gfx.text(x, yy + 12, fmt.tprintf("CAMERAS %d  FILM %d", pl.cameras[0], pl.film), TEXT)
	} else {
		gfx.text(x, yy, fmt.tprintf("SUPPLIES %d LB IN CAMP", pl.supplies[1]), TEXT)
		gfx.text(x, yy + 12, fmt.tprintf("CAMERAS %d", pl.cameras[1]), TEXT)
	}
	gfx.text(x, yy + 24, fmt.tprintf("CONTRACT POINTS %d", pl.points), GOLD)
}

draw_day :: proc() {
	g := &app.g
	pl := me()
	at_base := game.at_own_base(g, pl)
	gfx.text(4, 4, fmt.tprintf("%s'S SAFARI", name(g.turn)), GOLD)
	gfx.text(W - 4 - gfx.text_width(fmt.tprintf("DAY %d", pl.days)), 4, fmt.tprintf("DAY %d", pl.days), DIM)
	gfx.rect(0, 14, W, 1, LINE)
	// left: the scouts, or the map
	if g.phase == .Report && pl.shown_map {
		gfx.text(4, 20, "MAP TO BASE CAMP", GOLD)
		draw_map()
	} else {
		draw_report(76, 70)
	}
	// right: the survey
	gfx.text(160, 20, at_base ? "BASE CAMP" : "SAFARI CAMP", TEXT)
	if g.phase == .Report && !pl.out {gfx.text(260, 20, at_base ? "BASE SURVEY" : "END OF DAY", DIM)}
	survey(160, 38)
	gfx.rect(0, 140, W, 1, LINE)
	// messages
	y := 146
	mw := 296
	if g.phase == .Report {
		for i in 0 ..< g.nmsg {
			a, b := msg_text(g.msgs[i])
			col := u32(TEXT)
			#partial switch g.msgs[i].kind {
			case .Got_Picture, .Home: col = GOLD
			case .Head_Hunters, .Scout_Lost, .Crewman_Lost, .Bearer_Lost, .Supplies_Lost, .Camera_Lost, .Disoriented, .Bearer_Starved, .Cameraman_Starved, .Out_No_Cameras, .Out_No_Outfit, .Missed_Picture, .Too_Slow: col = RED
			}
			y = wrap(4, y, a, W - 8, col)
			if b != "" {y = wrap(4, y, b, W - 8, col)}
		}
		if pl.computer {
			gfx.button(W - 92, 216, "CONTINUE", ID_CONTINUE, DIM, PANEL)
		} else if app.t > 0.3 {
			gfx.button(W - 92, 216, "CONTINUE", ID_CONTINUE, BG, GOLD)
		}
		gfx.button(4, 216, "MAP", ID_MAP, DIM, PANEL)
		return
	}
	// choosing a way
	if pl.computer {
		gfx.text(4, y, "THE COMPUTER CONSULTS ITS SCOUTS...", DIM)
		return
	}
	gfx.text(4, y, "WHICH WAY?", TEXT)
	if pl.hungry > 7 {
		y = wrap(4, y + 12, "YOUR BEARERS ARE STARVING. THE SCOUTS WILL BRING A MAP WHETHER YOU WANT ONE OR NOT.", mw, RED)
	} else if app.bump > 0 {
		gfx.text(4, y + 12, "NO PASSAGE THAT WAY.", RED)
	} else {
		gfx.text(4, y + 12, "ARROWS OR TAP; S STAYS, L FOR LOST", DIM)
		gfx.text(4, y + 24, "(A SCOUT BRINGS A MAP, AT HIS LIFE).", DIM)
	}
	bx := 4
	bx += gfx.button(bx, 216, "STAY", ID_N + int(game.Move.Stay), TEXT, PANEL) + 6
	bx += gfx.button(bx, 216, "LOST", ID_N + int(game.Move.Lost), TEXT, PANEL) + 6
	gfx.button(bx, 216, "MAP", ID_MAP, DIM, PANEL)
	// the cross
	cx, cy := 340, 190
	s := 22
	arrows := [4]string{"N", "E", "S", "W"}
	for d in game.Dir {
		x := cx + game.DC[d] * (s + 2) - s / 2
		yy := cy + game.DR[d] * (s + 2) - s / 2
		gfx.rect(x, yy, s, s, PANEL)
		gfx.frame(x, yy, s, s, TEXT)
		gfx.text(x + 7, yy + 7, arrows[int(d)], TEXT)
		gfx.zone(x, yy, s, s, ID_N + int(d))
	}
}

draw_outfit :: proc() {
	g := &app.g
	pl := me()
	gfx.text(4, 4, fmt.tprintf("%s: BASE CAMP", name(g.turn)), GOLD)
	gfx.text(W - 4 - gfx.text_width(fmt.tprintf("DAY %d", pl.days)), 4, fmt.tprintf("DAY %d", pl.days), DIM)
	gfx.rect(0, 14, W, 1, LINE)
	gfx.text(4, 20, "PREPARE FOR NEW SAFARI...", TEXT)
	gfx.text(4, 32, fmt.tprintf("IN CAMP: %d MEN %d BEARERS %d CAMERAS %d LB", pl.men[1], pl.bearers[1], pl.cameras[1], pl.supplies[1]), DIM)
	gfx.text(4, 42, fmt.tprintf("CONTRACT POINTS %d", pl.points), GOLD)
	comp := pl.computer
	// scouts
	gfx.text(4, 62, "SCOUTS", TEXT)
	x := 88
	for d in game.Dir {
		s := pl.scouts[d]
		lab := game.DIR_NAME[d]
		if s == .Dead {
			gfx.text(x + 4, 62, "  --  ", LINE)
		} else {
			on := d in app.o_scouts
			gfx.button(x, 58, lab, ID_SCOUT + int(d), on ? BG : TEXT, on ? GOLD : PANEL)
		}
		x += 56
	}
	// cameras
	gfx.text(4, 88, "CAMERAS", TEXT)
	if !comp {gfx.button(88, 84, "-", ID_CAM_MINUS, TEXT, PANEL)}
	gfx.text(110, 88, fmt.tprintf("%d", app.o_cameras), GOLD)
	if !comp {gfx.button(124, 84, "+", ID_CAM_PLUS, TEXT, PANEL)}
	gfx.text(152, 88, fmt.tprintf("%d CAMERAMEN, %d REELS OF FILM", 2 * app.o_cameras, 3 * app.o_cameras), DIM)
	// bearers
	gfx.text(4, 112, "BEARERS", TEXT)
	if !comp {gfx.button(88, 108, "-", ID_BEAR_MINUS, TEXT, PANEL)}
	gfx.text(106, 112, fmt.tprintf("%2d", app.o_bearers), GOLD)
	if !comp {gfx.button(124, 108, "+", ID_BEAR_PLUS, TEXT, PANEL)}
	carry := min(100 * app.o_bearers, pl.supplies[1])
	gfx.text(152, 112, fmt.tprintf("%d LB OF SUPPLIES", carry), DIM)
	daily := game.daily_food(card(app.o_scouts), 2 * app.o_cameras, app.o_bearers)
	days := max(0, (carry - 100) / daily)
	gfx.text(4, 136, fmt.tprintf("THE PARTY EATS %d LB A DAY:", daily), TEXT)
	gfx.text(4, 148, fmt.tprintf("ABOUT %d DAYS BEFORE ANYONE GOES HUNGRY.", days), days < 4 ? RED : TEXT)
	gfx.text(4, 166, "SCOUTS SEE ONE REGION AHEAD; A CAMERA NEEDS", DIM)
	gfx.text(4, 176, "TWO CAMERAMEN; EACH BEARER CARRIES 100 LB.", DIM)
	if comp {
		gfx.text(4, 220, "THE COMPUTER IS PACKING...", DIM)
		return
	}
	gfx.text(4, 196, "KEYS: N E S W SCOUTS, UP/DOWN CAMERAS,", LINE)
	gfx.text(4, 206, "LEFT/RIGHT BEARERS, ENTER SETS OUT", LINE)
	bx := W - 4
	bx -= gfx.text_width("SET OUT") + 8
	gfx.button(bx, 218, "SET OUT", ID_SET_OUT, BG, GOLD)
	bx -= gfx.text_width("RETIRE") + 8 + 8
	gfx.button(bx, 218, "RETIRE", ID_RETIRE, DIM, PANEL)
	bx -= gfx.text_width("MAP") + 8 + 8
	gfx.button(bx, 218, "MAP", ID_MAP, DIM, PANEL)
}

// ---- the camera: TRS-80 characters, 64 by 16, at 6 by 15 pixels ----

CW :: 6
CH :: 15

// Nine animals, 12 by 7 cells of 2 pixels (drawn new; the listing's are TRS-80 block graphics).
SPRITES := [10][7]string {
	{},
	{ // lion
		"..###.......",
		".#####......",
		"##.#########",
		".##########.",
		"..#########.",
		"..#.#...#.#.",
		"..#.#...#.#.",
	},
	{ // tiger
		"............",
		"##..........",
		"###########.",
		".#.#.#.#.###",
		".##########.",
		".#.#....#.#.",
		".#.#....#.#.",
	},
	{ // elephant
		".....####...",
		"..########..",
		".#########.#",
		"##########.#",
		"##########.#",
		".##.##.##..#",
		".##.##.##...",
	},
	{ // baboon
		"........##..",
		".......####.",
		"..######.#..",
		".########...",
		"##.######...",
		"#..#.....#..",
		"..#.......#.",
	},
	{ // rhino
		"#...........",
		"##.#........",
		"###########.",
		"############",
		".##########.",
		".##.....##..",
		".##.....##..",
	},
	{ // impala
		"#.#.........",
		".##.........",
		".###........",
		"..#######...",
		"...######...",
		"...#....#...",
		"..#......#..",
	},
	{ // leopard
		"............",
		"##..........",
		"##########..",
		".#.#.#.#.###",
		".#########.#",
		".#.#...#.#.#",
		".#.#...#.#..",
	},
	{ // giraffe
		"##..........",
		".##.........",
		"..#.........",
		"..##........",
		"...######...",
		"...#.#.#....",
		"...#....#...",
	},
	{ // hippo
		"............",
		"............",
		"..########..",
		"############",
		"############",
		".##.....##..",
		"............",
	},
}

draw_animal :: proc(a, x, y: int) {
	col := ANIMAL_COL[a]
	for row, ry in SPRITES[a] {
		for ch, rx in row {
			if ch == '#' {gfx.rect(x + rx * 2, y + ry * 2, 2, 2, col)}
		}
	}
}

draw_film :: proc() {
	g := &app.g
	f := &g.film
	// the veldt
	gfx.rect(0, 0, W, 26, SKY)
	gfx.rect(0, 26, W, H - 26, GRASS)
	for i in 0 ..< 40 {
		h := u32(i + 1) * 2654435761
		gx := int(h >> 8) % W
		gy := 30 + int(h >> 20) % (H - 36)
		gfx.rect(gx, gy, 3, 1, GRASS_D)
	}
	gfx.rect(40, 16, 30, 7, 0x4f5a20) // acacias on the horizon
	gfx.rect(54, 22, 3, 5, 0x5a4024)
	gfx.rect(300, 14, 40, 8, 0x4f5a20)
	gfx.rect(318, 21, 3, 6, 0x5a4024)
	// the animal: its spot (a1, a2) is the centre of a 24 by 14 picture
	ax := f.a1 * CW + CW / 2
	ay := f.a2 * CH + CH / 2
	draw_animal(f.animal, ax - 12, ay - 7)
	// the frame: 23 characters by 9 rows from (p1, p2)
	fx := f.p1 * CW
	fy := f.p2 * CH
	fw := 23 * CW
	fh := 9 * CH
	gfx.frame(fx, fy, fw, fh, 0x101010)
	gfx.frame(fx + 1, fy + 1, fw - 2, fh - 2, 0xffffff)
	gfx.frame(fx + 2, fy + 2, fw - 4, fh - 4, 0x101010)
	cx, cy := game.frame_centre(f)
	gfx.rect(cx * CW, cy * CH + CH / 2 - 1, CW, 2, 0xffffff)
	gfx.rect(cx * CW + CW / 2 - 1, cy * CH + 3, 2, CH - 6, 0xffffff)
	// the top line (lines 7300-7310)
	gfx.rect(0, 0, W, 12, 0x000000)
	gfx.text(2, 2, fmt.tprintf("%s: %s", name(g.turn), game.ANIMALS[f.animal]), TEXT)
	pp := fmt.tprintf("%d", f.pp)
	gfx.text(W - 4 - gfx.text_width(pp), 2, pp, GOLD)
	if !me().computer {
		gfx.rect(0, H - 14, W, 14, 0x000000)
		gfx.text(2, H - 11, "ARROWS OR TAP MOVE THE FRAME", DIM)
		gfx.button(W - 92, H - 30, "SNAP!", ID_SNAP, BG, GOLD, 2)
	} else {
		gfx.rect(0, H - 14, W, 14, 0x000000)
		gfx.text(2, H - 11, "THE COMPUTER AIMS ITS CAMERA...", DIM)
	}
}

draw_over :: proc() {
	g := &app.g
	gfx.text_c(W / 2, 12, "THE GAME IS OVER", GOLD, 2)
	gfx.text_c(W / 2, 36, "NO ONE HAS THE CAMERA EQUIPMENT NEEDED", DIM)
	gfx.text_c(W / 2, 46, "TO SCORE POINTS.", DIM)
	gfx.text(80, 66, "FINAL STANDINGS:", TEXT)
	order: [game.MAX_PLAYERS]int
	for i in 0 ..< g.players {order[i] = i}
	for i in 0 ..< g.players {
		for j in i + 1 ..< g.players {
			if g.p[order[j]].points > g.p[order[i]].points {order[i], order[j] = order[j], order[i]}
		}
	}
	for k in 0 ..< g.players {
		i := order[k]
		col := k == 0 ? u32(GOLD) : u32(TEXT)
		gfx.text(80, 82 + k * 12, name(i), col)
		gfx.text(240, 82 + k * 12, fmt.tprintf("%5d", g.p[i].points), col)
		gfx.text(290, 82 + k * 12, fmt.tprintf("%d DAYS", g.p[i].days), DIM)
	}
	y := 90 + g.players * 12
	if g.players > 1 {
		gfx.text_c(W / 2, y, fmt.tprintf("%s GETS THE BIG MOVIE CONTRACT!", name(order[0])), GOLD)
	} else {
		gfx.text_c(W / 2, y, fmt.tprintf("%s LEVEL", LEVEL_NAME[g.level]), DIM)
		if app.new_best {gfx.text_c(W / 2, y + 12, "YOUR BEST YET!", GOLD)} else if app.best[g.level] > 0 {gfx.text_c(W / 2, y + 12, fmt.tprintf("BEST: %d", app.best[g.level]), DIM)}
	}
	if app.t > 0.8 {
		gfx.button(W / 2 - 100, 206, "ANOTHER GAME", ID_AGAIN, BG, GOLD)
		gfx.button(W / 2 + 20, 206, "MENU", ID_MENU, DIM, PANEL)
	}
}
