#+build js
package main

// Ten Pin Bowling's page: the score sheet, the lane, the sweep and the throw. Rules are in ../game.

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:strconv"
import bw "../game"
import "proto:gfx"

W :: 384
H :: 240

BG :: 0x10141f
SHEET :: 0xf2ecd8
SHEET_LINE :: 0x8a8070
SHEET_INK :: 0x24202a
SHEET_HI :: 0xfff6b0
WOOD :: 0xc89a5a
WOOD_DARK :: 0xb08446
WOOD_LINE :: 0xa87a40
CHANNEL :: 0x3a3e4a
FOUL :: 0xd8443c
PIN :: 0xfaf6ea
PIN_NECK :: 0xd8443c
BALL :: 0x2a4ad0
BALL_LIT :: 0x6a8aff
TEXT :: 0xf3e6c4
DIM :: 0x9a8fb3
GOLD :: 0xf6c945
GREEN :: 0x6fd36a
RED :: 0xe8473c
BTN :: 0x283044

// The lane on screen: the foul line, the head pin row, and the inches-to-pixels scale across.
FOUL_X :: 44
HEAD_X :: 296
ROW_PX :: 14
LANE_Y :: 152
PX_PER_IN :: 2.4
ROLL_TIME :: 1.5
DECK_D :: bw.TO_HEAD_PIN + 4 * bw.ROW_GAP

Screen :: enum {
	Setup,
	Aim,
	Rolling,
	Result,
	Over,
}

App :: struct {
	screen:     Screen,
	g:          bw.Game,
	t:          f32, // time on this screen
	clock:      f32,
	n:          int,
	computer:   [bw.MAX_BOWLERS]bool,
	sel:        int, // setup: the highlighted seat
	sweep:      f32, // phase of the sweep, 0 to 1
	sweep_dir:  f32,
	release:    f32,
	throw:      bw.Throw,
	roll:       bw.Roll,
	standing:   bw.Pins, // before this ball
	cpu_target: f32,
	cpu_throw:  bw.Throw,
	cpu_ready:  bool,
	message:    string,
	msg_col:    u32,
	best:       int,
	new_best:   bool,
	sounded:    [10]bool,
}

app: App

ID_STRAIGHT :: 1
ID_LEFT :: 2
ID_RIGHT :: 3
ID_START :: 4
ID_COUNT :: 10 // + n
ID_SEAT :: 20 // + seat
ID_AGAIN :: 30
ID_MENU :: 31

main :: proc() {
	app.n = 1
	app.computer = {false, true, true, true}
	buf: [32]u8
	if v, ok := gfx.store_get("best", buf[:]); ok {
		if n, nok := strconv.parse_int(v); nok && n >= 0 && n <= 300 {app.best = n}
	}
}

seed :: proc() -> u64 {
	return u64(gfx.now_ms()) ~ u64(gfx.random() * 1e9)
}

start_game :: proc() {
	bw.new_game(&app.g, app.n, app.computer, seed())
	app.new_best = false
	begin_ball()
}

begin_ball :: proc() {
	app.screen = .Aim
	app.t = 0
	app.sweep = gfx.random() > 0.5 ? 0.25 : 0.75
	app.cpu_ready = false
	app.standing = app.g.standing
	if app.g.bowlers[app.g.current].computer {
		app.cpu_target, app.cpu_throw = bw.plan_throw(&app.g, app.g.standing, 2.2)
		app.cpu_ready = true
	}
}

// The sweep: a triangle wave from one side of the approach to the other and back, every 3 s.
sweep_x :: proc() -> f32 {
	p := app.sweep - math.floor(app.sweep)
	tri := p < 0.5 ? p * 4 - 1 : 3 - p * 4
	return tri * bw.RELEASE_LIMIT
}

throw_ball :: proc(t: bw.Throw) {
	if app.screen != .Aim {return}
	app.release = sweep_x()
	app.throw = t
	app.roll = bw.roll_ball(app.g.standing, app.release, t, bw.rand(&app.g) * 3)
	app.screen = .Rolling
	app.t = 0
	app.sounded = {}
	gfx.noise(80, 0.05)
}

finish_ball :: proc() {
	down := app.roll.down & app.standing
	n := bw.count(down)
	first_ball := app.g.ball == 0 || (app.g.frame == bw.FRAMES - 1 && app.standing == bw.ALL_PINS)
	switch {
	case app.roll.gutter:
		app.message, app.msg_col = "GUTTER BALL", DIM
	case first_ball && n == 10:
		app.message, app.msg_col = "S T R I K E !", GOLD
	case !first_ball && down == app.standing:
		app.message, app.msg_col = app.roll.kickback ? "THE 7-10! A SPARE!" : "S P A R E !", GREEN
	case first_ball && app.standing - down == bw.Pins{6, 9}:
		app.message, app.msg_col = "THE 7-10 SPLIT", RED
	case n == 0:
		app.message, app.msg_col = "MISSED THEM ALL", DIM
	case:
		app.message, app.msg_col = fmt.aprintf("%d PIN%s", n, n == 1 ? "" : "S"), TEXT
	}
	res := bw.record(&app.g, down)
	app.screen = .Result
	app.t = 0
	if res == .Game_Over {
		top := 0
		for i in 0 ..< app.g.n_bowlers {
			b := &app.g.bowlers[i]
			if !b.computer {top = max(top, bw.total(b))}
		}
		if top > app.best {
			app.best = top
			app.new_best = true
			gfx.store_set("best", fmt.tprintf("%d", top))
		}
	}
}

@(export)
step :: proc(dt: f64) -> bool {
	d := f32(min(dt, 0.1))
	app.t += d
	app.clock += d
	switch app.screen {
	case .Setup, .Over:
	case .Aim:
		prev := sweep_x()
		app.sweep += d / 3
		if app.cpu_ready && app.t > 0.8 {
			now := sweep_x()
			lo, hi := min(prev, now), max(prev, now)
			if app.cpu_target >= lo - 0.01 && app.cpu_target <= hi + 0.01 {throw_ball(app.cpu_throw)}
		}
	case .Rolling:
		pin_sounds()
		if app.t >= ROLL_TIME + 0.7 {finish_ball()}
	case .Result:
		limit: f32 = app.g.bowlers[prev_bowler()].computer ? 1.6 : 2.2
		if app.t > limit {next_after_result()}
	}
	draw()
	free_all(context.temp_allocator)
	return true
}

prev_bowler :: proc() -> int {
	// Whose ball the result belongs to (record has already moved on).
	if app.g.ball > 0 {return app.g.current}
	p := app.g.current - 1
	if p < 0 {p = app.g.n_bowlers - 1}
	return p
}

next_after_result :: proc() {
	if app.g.over {
		app.screen = .Over
		app.t = 0
		notes := [?]f32{392, 523, 659, 784}
		for f, i in notes {gfx.tone(f, 140, .Square, 0.05, f32(i) * 150)}
	} else {
		begin_ball()
	}
}

ball_d :: proc() -> f32 {
	return min(app.t / ROLL_TIME, 1.05) * DECK_D
}

// When the ball reaches pin row r (0 at the head pin), in seconds from the throw.
row_time :: proc(row: int) -> f32 {
	return ROLL_TIME * (bw.TO_HEAD_PIN + f32(row) * bw.ROW_GAP) / DECK_D
}

pin_sounds :: proc() {
	for f in app.roll.falls[:app.roll.n_falls] {
		if app.sounded[f.pin] {continue}
		if app.t >= row_time(f.row) + f32(f.order) * 0.06 {
			app.sounded[f.pin] = true
			gfx.noise(40, 0.08)
			gfx.tone(700 + f32(f.pin) * 40, 30, .Square, 0.03)
		}
	}
}

// ---- input ----

@(export)
on_key :: proc "c" (code: i32, down: i32) {
	context = runtime.default_context()
	if down != 1 {return}
	c := int(code)
	switch app.screen {
	case .Setup:
		switch c {
		case '1' ..= '4':
			app.n = c - '0'
			app.sel = min(app.sel, app.n - 1)
		case gfx.KEY_UP, gfx.KEY_LEFT:
			app.sel = (app.sel + app.n - 1) % app.n
		case gfx.KEY_DOWN, gfx.KEY_RIGHT, gfx.KEY_TAB:
			app.sel = (app.sel + 1) % app.n
		case gfx.KEY_SPACE, 'C':
			app.computer[app.sel] = !app.computer[app.sel]
		case gfx.KEY_ENTER:
			start_game()
		}
	case .Aim:
		if app.g.bowlers[app.g.current].computer {return}
		switch c {
		case gfx.KEY_RIGHT, 'D':
			throw_ball(.Straight)
		case gfx.KEY_UP, 'W':
			throw_ball(.Break_Left)
		case gfx.KEY_DOWN, 'S':
			throw_ball(.Break_Right)
		}
	case .Rolling:
	case .Result:
		if (c == gfx.KEY_SPACE || c == gfx.KEY_ENTER) && app.t > 0.4 {next_after_result()}
	case .Over:
		if app.t > 1 {
			if c == gfx.KEY_ENTER || c == gfx.KEY_SPACE {start_game()}
			if c == gfx.KEY_ESCAPE {app.screen = .Setup}
		}
	}
}

@(export)
on_pointer :: proc "c" (x, y: f32, kind: i32) {
	context = runtime.default_context()
	if kind != 0 {return}
	id := gfx.hit(x, y)
	switch app.screen {
	case .Setup:
		switch {
		case id == ID_START:
			start_game()
		case id > ID_COUNT && id <= ID_COUNT + 4:
			app.n = id - ID_COUNT
			app.sel = min(app.sel, app.n - 1)
		case id >= ID_SEAT && id < ID_SEAT + 4:
			app.sel = id - ID_SEAT
			app.computer[app.sel] = !app.computer[app.sel]
		}
	case .Aim:
		if app.g.bowlers[app.g.current].computer {return}
		switch id {
		case ID_STRAIGHT:
			throw_ball(.Straight)
		case ID_LEFT:
			throw_ball(.Break_Left)
		case ID_RIGHT:
			throw_ball(.Break_Right)
		}
	case .Rolling:
	case .Result:
		if app.t > 0.4 {next_after_result()}
	case .Over:
		if app.t > 1 {
			if id == ID_MENU {app.screen = .Setup} else if id == ID_AGAIN {start_game()}
		}
	}
}

// ---- drawing ----

draw :: proc() {
	gfx.clear(BG)
	gfx.begin_buttons()
	if app.screen == .Setup {
		draw_lane(bw.ALL_PINS, false)
		draw_setup()
		return
	}
	draw_sheet()
	switch app.screen {
	case .Setup:
	case .Aim:
		draw_lane(app.g.standing, false)
		draw_sweep()
		draw_controls()
	case .Rolling:
		draw_lane(app.standing, true)
	case .Result:
		draw_lane(app.standing, true)
		gfx.text_c(W / 2, 220, app.message, app.msg_col, app.msg_col == GOLD || app.msg_col == GREEN ? 2 : 1)
	case .Over:
		draw_lane(bw.Pins{}, false)
		draw_over()
	}
}

name_of :: proc(i: int) -> string {
	if app.g.bowlers[i].computer {return fmt.tprintf("CPU %d", i + 1)}
	if app.g.n_bowlers == 1 {return "YOU"}
	return fmt.tprintf("BOWLER%d", i + 1)
}

draw_sheet :: proc() {
	g := &app.g
	row_h := 18
	top := 4
	x0 := 2
	name_w := 58
	fw := 29
	gfx.rect(x0, top, W - 4, row_h * g.n_bowlers + 1, SHEET)
	for i in 0 ..< g.n_bowlers {
		b := &g.bowlers[i]
		y := top + i * row_h
		up := i == g.current && !g.over && (app.screen == .Aim || app.screen == .Rolling)
		if up {gfx.rect(x0, y, name_w, row_h, SHEET_HI)}
		gfx.text(x0 + 3, y + 5, name_of(i), SHEET_INK)
		scores := bw.frame_scores(b)
		for f in 0 ..< bw.FRAMES {
			fx := x0 + name_w + f * fw
			if up && f == g.frame {gfx.rect(fx, y, fw, row_h, SHEET_HI)}
			gfx.frame(fx, y, fw + 1, row_h + 1, SHEET_LINE)
			marks, n := bw.frame_marks(b, f)
			// The little boxes for the balls, top right of each frame.
			boxes := f == bw.FRAMES - 1 ? 3 : 2
			for k in 0 ..< boxes {
				bx := fx + fw - (boxes - k) * 9
				gfx.frame(bx, y, 10, 9, SHEET_LINE)
				if k < n {
					c: u32 = marks[k] == "X" ? RED : SHEET_INK
					gfx.text(bx + 1, y + 1, marks[k], c)
				}
			}
			if scores[f] >= 0 {
				s := fmt.tprintf("%d", scores[f])
				gfx.text(fx + fw - 2 - gfx.text_width(s), y + 10, s, SHEET_INK)
			}
		}
		gfx.frame(x0, y, name_w + 1, row_h + 1, SHEET_LINE)
		tot := fmt.tprintf("%d", bw.total(b))
		gfx.text(W - 4 - gfx.text_width(tot), y + 5, tot, SHEET_INK)
	}
}

lane_y :: proc(lateral: f32) -> f32 {
	return LANE_Y + lateral * PX_PER_IN
}

d_to_x :: proc(d: f32) -> f32 {
	if d <= bw.TO_HEAD_PIN {return FOUL_X + (HEAD_X - FOUL_X) * d / bw.TO_HEAD_PIN}
	return HEAD_X + (d - bw.TO_HEAD_PIN) / bw.ROW_GAP * ROW_PX
}

draw_lane :: proc(standing: bw.Pins, rolling: bool) {
	half := 50
	top := LANE_Y - half
	ch := 8
	// Channels, the lane boards and the approach.
	gfx.rect(0, top - ch, W, half * 2 + ch * 2, CHANNEL)
	gfx.rect(0, top, W, half * 2, WOOD)
	for k := 0; k < half * 2; k += 6 {gfx.rect(0, top + k, W, 1, WOOD_LINE)}
	gfx.rect(0, top, FOUL_X - 2, half * 2, WOOD_DARK)
	gfx.rect(FOUL_X - 2, top, 2, half * 2, FOUL)
	// The aiming arrows, fifteen feet out.
	ax := int(d_to_x(180))
	for k in -2 ..= 2 {
		y := int(lane_y(f32(k) * 5))
		gfx.rect(ax, y - 1, 6, 3, WOOD_LINE)
		gfx.rect(ax + 6, y, 3, 1, WOOD_LINE)
	}
	gfx.rect(HEAD_X + 4 * ROW_PX + 10, top - ch, W, half * 2 + ch * 2, 0x1a1e28) // the pit

	// Pins: standing ones, and the ones going over.
	for i in 0 ..< 10 {
		if i not_in standing {continue}
		px := d_to_x(bw.TO_HEAD_PIN + f32(bw.PIN_ROW[i]) * bw.ROW_GAP)
		py := lane_y(bw.PIN_X[i])
		fallen := false
		dx, dy: f32
		if rolling {
			for f in app.roll.falls[:app.roll.n_falls] {
				if f.pin != i {continue}
				t0 := row_time(f.row) + f32(f.order) * 0.06
				if app.t >= t0 {
					fallen = true
					k := min((app.t - t0) / 0.35, 1)
					dy = f32(f.dir) * 10 * k
					dx = (f.dir == 0 ? 14 : 8) * k
					if k >= 1 {dx = -999}
				}
			}
		}
		if dx < -100 {continue}
		x, y := int(px + dx), int(py + dy)
		if fallen {
			gfx.rect(x - 3, y - 1, 7, 3, PIN)
			gfx.rect(x + 1, y - 1, 2, 3, PIN_NECK)
		} else {
			gfx.rect(x - 2, y - 2, 5, 5, PIN)
			gfx.rect(x - 1, y - 1, 3, 3, 0xe8e2d0)
			gfx.rect(x, y - 2, 1, 5, PIN_NECK)
		}
	}

	if rolling {
		d := ball_d()
		lat := ball_lateral(d)
		if app.roll.gutter && abs(lat) > bw.BALL_LIMIT {lat = (lat > 0 ? 1 : -1) * (bw.LANE_HALF + 2)}
		draw_ball(int(d_to_x(d)), int(lane_y(lat)))
	}
}

// The ball across the lane at distance d: its path to the head pin, then the rows' pushed line.
ball_lateral :: proc(d: f32) -> f32 {
	r := &app.roll
	if d <= bw.TO_HEAD_PIN {
		if r.gutter {
			// Into the channel where it leaves the lane.
			lat := bw.path_x(app.release, app.throw, d)
			return lat
		}
		return bw.path_x(app.release, app.throw, d)
	}
	k := (d - bw.TO_HEAD_PIN) / bw.ROW_GAP
	i := clamp(int(k), 0, 3)
	f := k - f32(i)
	return r.ball_x[i] + (r.ball_x[i + 1] - r.ball_x[i]) * min(f, 1)
}

draw_ball :: proc(x, y: int) {
	gfx.rect(x - 4, y - 3, 9, 7, BALL)
	gfx.rect(x - 3, y - 4, 7, 9, BALL)
	gfx.rect(x - 2, y - 2, 2, 2, BALL_LIT)
}

draw_sweep :: proc() {
	lat := sweep_x()
	draw_ball(FOUL_X - 14, int(lane_y(lat)))
	b := &app.g.bowlers[app.g.current]
	who := name_of(app.g.current)
	msg := b.computer ? fmt.tprintf("%s IS LINING UP...", who) : fmt.tprintf("%s: FRAME %d, BALL %d", who, app.g.frame + 1, app.g.ball + 1)
	gfx.text_c(W / 2, 84, msg, b.computer ? DIM : TEXT)
}

draw_controls :: proc() {
	if app.g.bowlers[app.g.current].computer {return}
	y := 214
	gfx.button(8, y, "^ BREAK LEFT", ID_LEFT, TEXT, BTN)
	gfx.button(132, y, "> STRAIGHT", ID_STRAIGHT, GOLD, BTN)
	gfx.button(240, y, "v BREAK RIGHT", ID_RIGHT, TEXT, BTN)
}

draw_setup :: proc() {
	gfx.rect(20, 14, W - 40, 210, 0x161b2a)
	gfx.frame(20, 14, W - 40, 210, GOLD)
	gfx.text_c(W / 2, 24, "TEN PIN BOWLING", GOLD, 2)
	gfx.text_c(W / 2, 46, "TEN FRAMES. WAIT TILL THE BALL IS WHERE", TEXT)
	gfx.text_c(W / 2, 56, "YOU WANT IT, THEN THROW IT STRAIGHT (>)", TEXT)
	gfx.text_c(W / 2, 66, "OR BREAKING LEFT (^) OR RIGHT (v).", TEXT)
	gfx.text_c(W / 2, 76, "A STRAIGHT BALL NEVER STRIKES.", GOLD)
	gfx.text(36, 94, "BOWLERS", DIM)
	for n in 1 ..= 4 {
		label := fmt.tprintf("%d", n)
		gfx.button(104 + (n - 1) * 28, 90, label, ID_COUNT + n, n == app.n ? BG : TEXT, n == app.n ? GOLD : BTN)
	}
	for i in 0 ..< app.n {
		y := 114 + i * 18
		gfx.text(36, y + 3, fmt.tprintf("BOWLER %d", i + 1), i == app.sel ? GOLD : DIM)
		gfx.button(120, y, app.computer[i] ? "COMPUTER" : "PERSON  ", ID_SEAT + i, app.computer[i] ? DIM : TEXT, BTN)
	}
	gfx.button(W / 2 - 40, 192, "BOWL!", ID_START, BG, GOLD, 2)
	gfx.text_c(W / 2, 212, fmt.tprintf("BEST GAME %d   1-4, SPACE, ENTER", app.best), DIM)
	gfx.text_c(W / 2, 230, "AFTER FRANK B. ROWLETT, JR., SOFTSIDE 1979", DIM)
}

draw_over :: proc() {
	g := &app.g
	best_i, best := 0, -1
	for i in 0 ..< g.n_bowlers {
		s := bw.total(&g.bowlers[i])
		if s > best {best_i, best = i, s}
	}
	gfx.rect(60, 96, W - 120, 110, 0x161b2a)
	gfx.frame(60, 96, W - 120, 110, GOLD)
	if g.n_bowlers == 1 {
		gfx.text_c(W / 2, 106, fmt.tprintf("YOU BOWLED %d", best), GOLD, 2)
	} else {
		gfx.text_c(W / 2, 106, fmt.tprintf("%s WINS", name_of(best_i)), GOLD, 2)
		gfx.text_c(W / 2, 128, fmt.tprintf("WITH %d", best), TEXT)
	}
	if app.new_best {gfx.text_c(W / 2, 144, "A NEW BEST GAME!", GREEN)} else {gfx.text_c(W / 2, 144, fmt.tprintf("BEST GAME %d", app.best), DIM)}
	if app.t > 1 {
		gfx.button(W / 2 - 100, 170, "BOWL AGAIN", ID_AGAIN, TEXT, BTN)
		gfx.button(W / 2 + 12, 170, "BOWLERS", ID_MENU, DIM, BTN)
	}
}
