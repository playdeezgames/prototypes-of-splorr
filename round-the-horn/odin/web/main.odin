#+build js
package main

// 'Round the Horn's page: the map of the Americas, the view off the bow, the ship's instruments.
// Rules are in ../game.

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:strconv"
import hn "../game"
import "proto:gfx"

W :: 384
H :: 240

BG :: 0x0e1424
SEA :: 0x1d3f6e
SEA_DEEP :: 0x16325a
LAND :: 0x6a8a3a
LAND_EDGE :: 0x4a6a2a
ICE :: 0xe8f0f8
TEXT :: 0xf2ead8
DIM :: 0x9aa4b8
GOLD :: 0xf6c945
RED :: 0xe8473c
BTN :: 0x26304a
PANEL :: 0x141c30

SHIP_COLOURS := [hn.MAX_SHIPS]u32{0xf06a50, 0xf6c945, 0x7ad0ff}

CELL_W :: 6 // map cell: two dots of 3
CELL_H :: 6 // three dots of 2
MAP_H :: hn.ROWS * CELL_H

STEP_HUMAN :: 0.22
STEP_COMPUTER :: 0.07

Phase :: enum {
	Setup,
	Course, // a captain to set the week's course
	Sailing,
	Land_Ho, // paused: land in sight
	Week_End,
	Arrived,
	Wrecked,
	Over,
}

Seat :: enum u8 {
	Person,
	Computer,
	Home, // stays in port
}

App :: struct {
	g:       hn.Game,
	phase:   Phase,
	t:       f32,
	clock:   f32,
	tick:    f32,
	seats:   [hn.MAX_SHIPS]Seat,
	seen:    [4]hn.Ground, // what was in sight, to call out new land
	who:     int, // the ship an Arrived/Wrecked notice is about
	best:    int, // hours: the best passage by a person, 0 if none
	new_best: bool,
	waves:   f32,
	message: string,
}

app: App

ID_SEAT :: 10
ID_START :: 20
ID_POINT :: 30 // + point 0..15
ID_PORT :: 50
ID_STBD :: 51
ID_SAIL :: 52
ID_GO_ON :: 53
ID_AGAIN :: 54

main :: proc() {
	app.seats = {.Person, .Computer, .Computer}
	buf: [32]u8
	if v, ok := gfx.store_get("best", buf[:]); ok {
		if n, ok2 := strconv.parse_int(v); ok2 {app.best = n}
	}
}

// ---- the flow ----

start_race :: proc() {
	n := 1
	computer: [hn.MAX_SHIPS]bool
	// Seats in order; a ship that stays home ends the list.
	for i in 0 ..< hn.MAX_SHIPS {
		if i > 0 && app.seats[i] == .Home {break}
		n = i + 1
		computer[i] = app.seats[i] == .Computer
	}
	hn.new_game(&app.g, n, computer, u64(gfx.now_ms()) ~ u64(gfx.random() * 1e9))
	app.new_best = false
	gfx.tone(392, 120, .Triangle, 0.06)
	gfx.tone(523, 220, .Triangle, 0.06, 130)
	begin()
}

// The current ship's week begins.
begin :: proc() {
	s := hn.begin_week(&app.g)
	app.seen = sighting_mask(s)
	app.t = 0
	app.tick = 0
	if s.computer {
		app.phase = .Sailing
		app.message = "COMPUTER AT THE HELM"
	} else {
		app.phase = .Course
		app.message = "SET COURSE, THEN SAIL"
	}
	gfx.tone(1568, 60, .Sine, 0.04)
	gfx.tone(1568, 60, .Sine, 0.04, 140)
}

sail :: proc() {
	if app.phase == .Course || app.phase == .Land_Ho {
		app.phase = .Sailing
		app.message = ""
		app.tick = 0
	}
}

go_on :: proc() {
	switch app.phase {
	case .Arrived, .Wrecked, .Week_End:
		hn.end_week(&app.g)
		if app.g.over {
			finish()
		} else {
			begin()
		}
	case .Over:
		app.phase = .Setup
	case .Setup:
		start_race()
	case .Course, .Land_Ho:
		sail()
	case .Sailing:
	}
}

finish :: proc() {
	app.phase = .Over
	app.t = 0
	for i in 0 ..< app.g.n {
		s := &app.g.ships[i]
		if s.computer || s.status != .Arrived {continue}
		h := hn.hours(s)
		if app.best == 0 || h < app.best {
			app.best = h
			app.new_best = true
			gfx.store_set("best", fmt.tprintf("%d", h))
		}
	}
}

turn :: proc(points: int) {
	if app.phase != .Course && app.phase != .Sailing && app.phase != .Land_Ho {return}
	s := hn.current_ship(&app.g)
	if s.computer {return}
	s.want = (s.want + points + 16) % 16
	gfx.tone(points > 0 ? 660 : 550, 30, .Square, 0.03)
}

set_course :: proc(p: int) {
	if app.phase != .Course && app.phase != .Sailing && app.phase != .Land_Ho {return}
	s := hn.current_ship(&app.g)
	if s.computer {return}
	s.want = p
	gfx.tone(600, 30, .Square, 0.03)
}

sighting_mask :: proc(s: ^hn.Ship) -> (m: [4]hn.Ground) {
	seen := hn.in_sight(s.h, s.v)
	for side in 0 ..< 4 {m[side] = seen[side].what}
	return
}

half_day :: proc() {
	g := &app.g
	s := hn.current_ship(g)
	e := hn.step(g)
	gfx.noise(40, 0.015)
	switch e {
	case .None:
		if !s.computer {
			now := sighting_mask(s)
			for side in 0 ..< 4 {
				if now[side] != .Sea && app.seen[side] == .Sea {
					app.phase = .Land_Ho
					app.message = now[side] == .Ice ? "ICE IN SIGHT!" : "LAND HO!"
					gfx.tone(880, 90, .Square, 0.05)
					gfx.tone(880, 90, .Square, 0.05, 160)
				}
			}
			app.seen = now
		}
	case .Week_Over:
		app.phase = .Week_End
		app.t = 0
		gfx.tone(1175, 80, .Sine, 0.04)
	case .Arrived:
		app.phase = .Arrived
		app.who = g.current
		app.t = 0
		notes := [?]f32{392, 494, 587, 784, 587, 784}
		for f, i in notes {gfx.tone(f, 140, .Triangle, 0.06, f32(i) * 150)}
	case .Wrecked:
		app.phase = .Wrecked
		app.who = g.current
		app.t = 0
		gfx.noise(500, 0.12)
		gfx.tone(110, 600, .Saw, 0.05, 80)
	}
}

@(export)
step :: proc(dt: f64) -> bool {
	d := f32(min(dt, 0.1))
	app.t += d
	app.clock += d
	if app.phase == .Sailing {
		s := hn.current_ship(&app.g)
		app.waves += d * (2 + s.wx.knots * 0.5)
		app.tick += d
		pace := f32(s.computer ? STEP_COMPUTER : STEP_HUMAN)
		for app.tick >= pace && app.phase == .Sailing {
			app.tick -= pace
			half_day()
		}
	} else if app.phase == .Week_End {
		s := hn.current_ship(&app.g)
		// Straight on to the next ship's week unless it is the same captain's.
		if app.t > (s.computer ? 0.5 : 0.9) {go_on()}
	} else {
		app.waves += d * 2
	}
	draw()
	free_all(context.temp_allocator)
	return true
}

// ---- input ----

@(export)
on_key :: proc "c" (code: i32, down: i32) {
	context = runtime.default_context()
	if down == 0 {return}
	c := int(code)
	if down == 2 && c != gfx.KEY_LEFT && c != gfx.KEY_RIGHT {return}
	switch c {
	case gfx.KEY_ENTER, gfx.KEY_SPACE:
		go_on()
	case gfx.KEY_LEFT, '/':
		turn(-1)
	case gfx.KEY_RIGHT, 'Z':
		turn(1)
	case '1' ..= '8':
		set_course((c - '1') * 2)
	case 'N':
		set_course(0)
	case 'E':
		set_course(4)
	case 'S':
		set_course(8)
	case 'W':
		set_course(12)
	}
}

@(export)
on_pointer :: proc "c" (x, y: f32, kind: i32) {
	context = runtime.default_context()
	if kind != 0 {return}
	id := gfx.hit(x, y)
	switch {
	case id >= ID_SEAT && id < ID_SEAT + hn.MAX_SHIPS:
		i := id - ID_SEAT
		k := (int(app.seats[i]) + 1) % (i == 0 ? 2 : 3)
		app.seats[i] = Seat(k)
		gfx.tone(500, 30, .Square, 0.03)
	case id == ID_START || id == ID_GO_ON || id == ID_AGAIN || id == ID_SAIL:
		go_on()
	case id >= ID_POINT && id < ID_POINT + 16:
		set_course(id - ID_POINT)
	case id == ID_PORT:
		turn(-1)
	case id == ID_STBD:
		turn(1)
	case id < 0:
		if app.phase == .Arrived || app.phase == .Wrecked || app.phase == .Over {go_on()}
	}
}

// ---- drawing ----

draw :: proc() {
	gfx.clear(BG)
	gfx.begin_buttons()
	if app.phase == .Setup {
		draw_setup()
		return
	}
	draw_map()
	draw_bow()
	draw_panel()
	#partial switch app.phase {
	case .Arrived:
		draw_arrived()
	case .Wrecked:
		draw_wrecked()
	case .Over:
		draw_over()
	}
}

draw_map :: proc() {
	// Runs of dots of one ground, row by row.
	for py in 0 ..< hn.ROWS * 3 {
		y := py * 2
		run := 0
		kind := hn.Ground.Sea
		for px in 0 ..= hn.COLS * 2 {
			g := hn.Ground.Sea
			if px < hn.COLS * 2 {g = hn.ground((f32(px) + 0.5) / 2, (f32(py) + 0.5) / 3)}
			if px == hn.COLS * 2 || g != kind {
				if run > 0 {
					c: u32 = (py / 3) % 2 == 0 ? SEA : SEA_DEEP
					if kind == .Land {c = LAND} else if kind == .Ice {c = ICE}
					gfx.rect((px - run) * 3, y, run * 3, 2, c)
				}
				run = 0
				kind = g
			}
			run += 1
		}
	}
	// New York and San Francisco.
	gfx.frame(hn.PORT_COL * CELL_W, hn.PORT_ROW * CELL_H, CELL_W, CELL_H, GOLD)
	gfx.text(hn.PORT_COL * CELL_W - 10, hn.PORT_ROW * CELL_H - 1, "S", GOLD)
	gfx.text(35 * CELL_W + 4, 4, "N", GOLD)
	// Wakes, then the ships.
	g := &app.g
	for i in 0 ..< g.n {
		for k in 0 ..< g.n_track[i] {
			p := g.tracks[i][k]
			gfx.rect(int(p[0] * CELL_W), int(p[1] * CELL_H), 1, 1, SHIP_COLOURS[i])
		}
	}
	for i in 0 ..< g.n {
		s := &g.ships[i]
		x, y := int(s.h * CELL_W), int(s.v * CELL_H)
		if i == g.current && app.phase != .Over {
			if int(app.clock * 3) % 3 != 0 {gfx.text(x - 3, y - 4, "!", TEXT)}
		} else {
			initials := [hn.MAX_SHIPS]string{"C", "F", "S"}
			label := s.status == .Wrecked ? "+" : initials[i]
			gfx.text(x - 3, y - 4, label, SHIP_COLOURS[i])
		}
	}
	gfx.rect(0, MAP_H, W, 2, 0x2a3450)
}

// The view off the bow: sky, sea, land in sight ahead, the bowsprit and the fore topmast staysail.
draw_bow :: proc() {
	x0, y0, bw, bh := 4, MAP_H + 6, 192, H - MAP_H - 10
	s := hn.current_ship(&app.g)
	w := s.wx
	storm := w.knots > 30 || (w.pressure < 28.5 && w.trend < 0)
	horizon := y0 + 46
	gfx.rect(x0, y0, bw, horizon - y0, storm ? 0x4a5468 : 0x7ab0e0)
	gfx.rect(x0, horizon, bw, y0 + bh - horizon, storm ? 0x23405a : 0x2a5a90)
	cx := x0 + bw / 2

	// Land and ice off the bow: the sightings due N, E, S, W that lie within three points.
	seen := hn.in_sight(s.h, s.v)
	for side in 0 ..< 4 {
		if seen[side].what == .Sea {continue}
		rel := (side * 4 - s.heading + 24) % 16 - 8 // -8..7 points off the bow
		if rel < -3 || rel > 3 {continue}
		near := 2.5 - seen[side].cells // 0.5 .. 2
		lw := int(30 + near * 30)
		lh := int(3 + near * 5)
		lx := cx + rel * 26 - lw / 2
		c: u32 = seen[side].what == .Ice ? ICE : 0x4a6a3a
		gfx.rect(max(lx, x0), horizon - lh, min(lw, x0 + bw - max(lx, x0)), lh, c)
		gfx.rect(max(lx + lw / 4, x0), horizon - lh - 3, lw / 2, 3, c)
	}

	// Waves rolling towards the ship.
	for row in 0 ..< 7 {
		f := math.mod(f32(row) + app.waves * 0.25, 7) / 7
		yy := horizon + 2 + int(f * f * f32(y0 + bh - horizon - 4))
		span := 6 + int(f * 30)
		for k in 0 ..< 6 {
			xx := x0 + int(math.mod(f32(k * 37 + row * 61) + app.waves * 3, f32(bw)))
			gfx.rect(xx, yy, min(span / 3, x0 + bw - xx), 1 + int(f * 2), storm ? 0xc0d0e0 : 0x8ac0f0)
		}
	}

	// The bow and bowsprit.
	base := y0 + bh
	for k in 0 ..< 34 {
		half := 6 + k * 2
		gfx.rect(cx - half, base - 34 + k, half * 2, 1, k == 0 ? 0xa06a3a : 0x6a4020)
	}
	gfx.rect(cx - 1, horizon + 8, 3, base - 34 - horizon - 8, 0x8a5a2a)
	// The staysail on the side away from the wind: bigger off the wind.
	pos := hn.point_of_sail(s.heading, w.dir)
	top := [hn.Point_Of_Sail]int{.Close_Hauled = 36, .Reach = 22, .Running = 10}
	width := [hn.Point_Of_Sail]int{.Close_Hauled = 26, .Reach = 44, .Running = 62}
	side := hn.port_tack(s.heading, w.dir) ? 1 : -1
	y_top := y0 + top[pos]
	y_foot := base - 40
	for y in y_top ..< y_foot {
		f := f32(y - y_top) / f32(y_foot - y_top)
		sw := int(f * f32(width[pos]))
		belly := int(math.sin(f * math.PI) * 4)
		if side > 0 {
			gfx.rect(cx + 2, y, sw + belly, 1, 0xf4efe0)
		} else {
			gfx.rect(cx - 1 - sw - belly, y, sw + belly, 1, 0xf4efe0)
		}
	}
	gfx.frame(x0, y0, bw, bh, 0x2a3450)
}

days_text :: proc(s: ^hn.Ship) -> string {
	return fmt.tprintf("DAY %d, %d HOURS", s.half_days / 2, (s.half_days % 2) * 12)
}

lat_text :: proc(s: ^hn.Ship) -> string {
	la := hn.latitude(s.v)
	lo := hn.longitude(s.h)
	lad, lam := int(abs(la)), int(math.mod(abs(la), 1) * 60)
	lod, lom := int(abs(lo)), int(math.mod(abs(lo), 1) * 60)
	return fmt.tprintf("%02d %02d %s  %03d %02d %s", lad, lam, la >= 0 ? "N" : "S", lod, lom, lo >= 0 ? "W" : "E")
}

draw_panel :: proc() {
	g := &app.g
	s := hn.current_ship(g)
	w := s.wx
	x := 202
	y := MAP_H + 6
	gfx.rect(x - 4, y, W - x, H - y - 4, PANEL)
	gfx.text(x, y + 2, hn.SHIP_NAMES[g.current], SHIP_COLOURS[g.current])
	gfx.text(x + 120, y + 2, fmt.tprintf("WEEK %d", g.round + 1), DIM)
	gfx.text(x, y + 12, days_text(s), TEXT)
	gfx.text(x, y + 22, lat_text(s), TEXT)
	gfx.text(x, y + 32, fmt.tprintf("WIND %s %d KNOTS", hn.POINT_NAMES[w.dir], int(w.knots)), TEXT)
	pos_names := [hn.Point_Of_Sail]string{.Close_Hauled = "CLOSE HAULED", .Reach = "ON A REACH", .Running = "RUNNING"}
	head := app.phase == .Course ? hn.fix_heading(s.want, w.dir) : s.heading
	gfx.text(x, y + 42, fmt.tprintf("COURSE %s %s", hn.POINT_NAMES[head], hn.port_tack(head, w.dir) ? "PORT" : "STARB'D"), GOLD)
	gfx.text(x, y + 52, pos_names[hn.point_of_sail(head, w.dir)], DIM)
	if head != s.want {gfx.text(x + 104, y + 52, fmt.tprintf("(%s)", hn.POINT_NAMES[s.want]), DIM)}
	gfx.text(x, y + 62, hn.REGION_NAMES[hn.region(s.v)], DIM)

	// The compass: eight courses and a SAIL button, then a point to port or starboard.
	by := y + 74
	labels := [9]string{"NW", "N", "NE", "W", "", "E", "SW", "S", "SE"}
	points := [9]int{14, 0, 2, 12, -1, 4, 10, 8, 6}
	human := !s.computer && (app.phase == .Course || app.phase == .Sailing || app.phase == .Land_Ho)
	for k in 0 ..< 9 {
		bx := x + (k % 3) * 34
		yy := by + (k / 3) * 17
		if points[k] < 0 {
			ready := app.phase == .Course || app.phase == .Land_Ho
			gfx.rect(bx, yy, 32, 15, ready ? GOLD : BTN)
			gfx.text_c(bx + 16, yy + 4, "SAIL", ready ? BG : DIM)
			if ready {gfx.zone(bx, yy, 32, 15, ID_SAIL)}
			continue
		}
		on := s.want == points[k]
		gfx.rect(bx, yy, 32, 15, on ? 0x3a4a6a : BTN)
		gfx.frame(bx, yy, 32, 15, on ? GOLD : 0x3a4460)
		gfx.text_c(bx + 16, yy + 4, labels[k], human ? TEXT : DIM)
		if human {gfx.zone(bx, yy, 32, 15, ID_POINT + points[k])}
	}
	rx := x + 108
	gfx.rect(rx, by, 66, 15, BTN)
	gfx.text(rx + 4, by + 4, "< PORT", human ? TEXT : DIM)
	gfx.rect(rx, by + 17, 66, 15, BTN)
	gfx.text(rx + 4, by + 21, "STBD >", human ? TEXT : DIM)
	if human {
		gfx.zone(rx, by, 66, 15, ID_PORT)
		gfx.zone(rx, by + 17, 66, 15, ID_STBD)
	}
	gfx.text(rx + 4, by + 38, fmt.tprintf("%.2f IN", w.pressure), w.trend < 0 ? RED : DIM)

	// What is in sight, and the word of the moment.
	seen := hn.in_sight(s.h, s.v)
	sides := [4]string{"N", "E", "S", "W"}
	line := ""
	for side in 0 ..< 4 {
		if seen[side].what == .Sea {continue}
		line = fmt.tprintf("%s%s ", line, sides[side])
	}
	my := H - 14
	if app.message != "" {
		blink := app.phase != .Land_Ho || int(app.clock * 3) % 2 == 0
		if blink {gfx.text(x, my, app.message, app.phase == .Land_Ho ? RED : GOLD)}
	} else if line != "" {
		gfx.text(x, my, fmt.tprintf("IN SIGHT: %s", line), RED)
	} else if app.phase == .Sailing {
		gfx.text(x, my, "UNDER SAIL", DIM)
	}
}

overlay :: proc(h: int) -> int {
	y := (H - h) / 2
	gfx.rect(16, y, W - 32, h, PANEL)
	gfx.frame(16, y, W - 32, h, GOLD)
	return y
}

passage :: proc(s: ^hn.Ship) -> string {
	return fmt.tprintf("%d DAYS %d HOURS", s.half_days / 2, (s.half_days % 2) * 12)
}

draw_arrived :: proc() {
	s := &app.g.ships[app.who]
	y := overlay(92)
	gfx.text_c(W / 2, y + 10, fmt.tprintf("THE CLIPPER %s", hn.SHIP_NAMES[app.who]), SHIP_COLOURS[app.who])
	gfx.text_c(W / 2, y + 24, "HAS JUST ARRIVED IN SAN FRANCISCO", TEXT)
	gfx.text_c(W / 2, y + 36, fmt.tprintf("AFTER %s,", passage(s)), GOLD)
	gfx.text_c(W / 2, y + 48, "UNLOADING CHOICE EASTERN MERCHANDISE", TEXT)
	if hn.hours(s) < hn.RECORD_HOURS {gfx.text_c(W / 2, y + 62, "A NEW RECORD PASSAGE!", GOLD)}
	if app.t > 0.6 {gfx.text_c(W / 2, y + 76, "PRESS ENTER OR TAP", DIM)}
}

draw_wrecked :: proc() {
	y := overlay(84)
	if int(app.clock * 4) % 2 == 0 {gfx.text_c(W / 2, y + 10, "SOS ... SOS ... SOS", RED)}
	gfx.text_c(W / 2, y + 24, "S H I P W R E C K !", RED, 1)
	gfx.text_c(W / 2, y + 38, fmt.tprintf("THE CLIPPER %s WAS LOST AT SEA", hn.SHIP_NAMES[app.who]), TEXT)
	gfx.text_c(W / 2, y + 50, "WITH ALL HANDS", TEXT)
	if app.t > 0.6 {gfx.text_c(W / 2, y + 68, "PRESS ENTER OR TAP", DIM)}
}

draw_over :: proc() {
	g := &app.g
	y := overlay(140)
	gfx.text_c(W / 2, y + 8, "THE RACE IS OVER", GOLD)
	win := hn.winner(g)
	for i in 0 ..< g.n {
		s := &g.ships[i]
		yy := y + 26 + i * 12
		gfx.text(40, yy, hn.SHIP_NAMES[i], SHIP_COLOURS[i])
		gfx.text(150, yy, s.status == .Arrived ? passage(s) : "LOST AT SEA", s.status == .Arrived ? TEXT : RED)
		if i == win {gfx.text(310, yy, "WINS", GOLD)}
	}
	ry := y + 70
	gfx.text_c(W / 2, ry, "THE RECORD: FLYING CLOUD, 89 DAYS 21 HOURS", DIM)
	if app.best > 0 {
		gfx.text_c(W / 2, ry + 12, fmt.tprintf("YOUR BEST: %d DAYS %d HOURS", app.best / 24, app.best % 24), app.new_best ? GOLD : DIM)
	}
	if app.new_best {gfx.text_c(W / 2, ry + 24, "A NEW BEST PASSAGE!", GOLD)}
	if app.t > 0.6 {gfx.button(W / 2 - 52, y + 116, "RACE AGAIN", ID_AGAIN, TEXT, BTN)}
}

draw_setup :: proc() {
	// A strip of sea with a clipper hull-down on the horizon.
	gfx.rect(0, 0, W, 70, 0x2a5a90)
	gfx.rect(0, 0, W, 44, 0x7ab0e0)
	sx := int(math.mod(app.clock * 12, W + 60)) - 30
	gfx.rect(sx - 14, 40, 28, 4, 0x4a3020)
	for k in 0 ..< 3 {
		mx := sx - 9 + k * 9
		gfx.rect(mx, 18, 1, 22, 0x4a3020)
		for r in 0 ..< 3 {gfx.rect(mx - 3 + r, 20 + r * 6, 7 - r * 2 + 2, 5, 0xf4efe0)}
	}
	for k in 0 ..< 12 {
		wx := int(math.mod(f32(k * 41) + app.clock * 20, W))
		gfx.rect(wx, 50 + (k % 4) * 5, 10, 1, 0x8ac0f0)
	}
	gfx.text_c(W / 2, 80, "C L I P P E R", GOLD, 2)
	gfx.text_c(W / 2, 100, "A RACE AROUND THE HORN TO CALIFORNIA IN 1852", TEXT)
	gfx.text_c(W / 2, 114, "NEW YORK TO SAN FRANCISCO IN THE FEWEST DAYS", DIM)
	seat_names := [Seat]string{.Person = "CAPTAIN  ", .Computer = "COMPUTER ", .Home = "IN PORT  "}
	for i in 0 ..< hn.MAX_SHIPS {
		yy := 132 + i * 18
		gfx.text(90, yy + 3, hn.SHIP_NAMES[i], SHIP_COLOURS[i])
		gfx.button(210, yy, seat_names[app.seats[i]], ID_SEAT + i, app.seats[i] == .Home ? DIM : TEXT, BTN)
	}
	gfx.button(W / 2 - 60, 190, "SET SAIL!", ID_START, BG, GOLD, 2)
	rec := "THE RECORD: FLYING CLOUD, 89 DAYS 21 HOURS"
	if app.best > 0 {rec = fmt.tprintf("%s  YOURS: %d D %d H", "RECORD 89 D 21 H.", app.best / 24, app.best % 24)}
	gfx.text_c(W / 2, 222, rec, DIM)
}
