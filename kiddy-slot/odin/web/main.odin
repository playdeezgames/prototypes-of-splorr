#+build js
package main

// Kiddy Slot's page: the machine, the reels, the lever. Rules are in ../game.

import "base:runtime"
import "core:fmt"
import sl "../game"
import "proto:gfx"

W :: 384
H :: 240

BG :: 0x20163a
CABINET :: 0xd8443c
CABINET_LIT :: 0xf06a50
CABINET_DARK :: 0x9a2a2a
CHROME :: 0xd0d4dc
WINDOW :: 0xfaf6ea
TEXT :: 0xfaf6ea
DIM :: 0xb0a8c8
GOLD :: 0xf6c945
INK :: 0x2a2030

Phase :: enum {
	Ready,
	Spinning,
	Won,
	Lost,
	Out,
}

App :: struct {
	m:        sl.Machine,
	phase:    Phase,
	t:        f32, // time in this phase
	clock:    f32,
	shown:    [3]sl.Picture, // what each window shows while spinning
	stopped:  [3]bool,
	lever:    f32, // 1 when pulled, eases back
	outcome:  sl.Outcome,
}

app: App

ID_SPIN :: 1

STOP_AT := [3]f32{0.9, 1.4, 1.9}

main :: proc() {
	sl.new_machine(&app.m, u64(gfx.now_ms()) ~ u64(gfx.random() * 1e9))
	app.shown = app.m.reels
	app.stopped = {true, true, true}
}

pull :: proc() {
	switch app.phase {
	case .Spinning:
		return
	case .Out:
		if app.t < 0.8 {return}
		sl.refill(&app.m)
		app.phase = .Ready
		app.t = 0
		gfx.tone(523, 90, .Square, 0.05)
		gfx.tone(784, 140, .Square, 0.05, 100)
		return
	case .Ready, .Won, .Lost:
	}
	app.outcome = sl.spin(&app.m)
	if app.outcome == .None {return}
	app.phase = .Spinning
	app.t = 0
	app.stopped = {}
	app.lever = 1
	gfx.noise(60, 0.05)
	gfx.tone(220, 80, .Triangle, 0.06)
}

@(export)
step :: proc(dt: f64) -> bool {
	d := f32(min(dt, 0.1))
	app.t += d
	app.clock += d
	app.lever = max(0, app.lever - d * 2.5)
	if app.phase == .Spinning {
		for i in 0 ..< 3 {
			if app.stopped[i] {continue}
			if app.t >= STOP_AT[i] {
				app.stopped[i] = true
				app.shown[i] = app.m.reels[i]
				gfx.tone(330 + f32(i) * 110, 50, .Square, 0.06)
				gfx.noise(30, 0.05)
			} else {
				// The strip runs by, a picture every 70 ms.
				k := int(app.t / 0.07) + i
				prev := app.shown[i]
				app.shown[i] = sl.Picture(k % len(sl.Picture))
				if app.shown[i] != prev {gfx.tone(900, 8, .Square, 0.015)}
			}
		}
		if app.stopped[2] {
			app.t = 0
			if app.outcome == .Win {
				app.phase = .Won
				notes := [?]f32{523, 659, 784, 1047, 784, 1047}
				for f, i in notes {gfx.tone(f, 110, .Square, 0.05, f32(i) * 120)}
			} else {
				app.phase = app.m.zzoopps > 0 ? .Lost : .Out
				gfx.tone(330, 140, .Triangle, 0.06, 60)
				gfx.tone(262, 220, .Triangle, 0.06, 210)
			}
		}
	}
	draw()
	free_all(context.temp_allocator)
	return true
}

// ---- input ----

@(export)
on_key :: proc "c" (code: i32, down: i32) {
	context = runtime.default_context()
	if down != 1 {return}
	c := int(code)
	if c == gfx.KEY_ENTER || c == gfx.KEY_SPACE {pull()}
}

@(export)
on_pointer :: proc "c" (x, y: f32, kind: i32) {
	context = runtime.default_context()
	if kind == 0 {pull()}
}

// ---- pictures: 20 by 20, '#' outline, 'o' fill, 'x' detail ----

SUN := [20]string {
	".........#..........",
	"...#.....#.....#....",
	"....#....#....#.....",
	".....#.......#......",
	".......#####........",
	"......#ooooo#.......",
	"##...#ooooooo#...##.",
	"....#oo#ooo#oo#.....",
	"....#ooooooooo#.....",
	"....#ooooooooo#.....",
	"....#ox#ooo#xo#.....",
	"....#oox###xoo#.....",
	"##...#ooooooo#...##.",
	"......#ooooo#.......",
	".......#####........",
	".....#.......#......",
	"....#....#....#.....",
	"...#.....#.....#....",
	".........#..........",
	"....................",
}

SMILE := [20]string {
	"....................",
	"......########......",
	"....##oooooooo##....",
	"...#oooooooooooo#...",
	"..#oooooooooooooo#..",
	"..#ooo##oooo##ooo#..",
	".#oooo##oooo##oooo#.",
	".#oooooooooooooooo#.",
	".#oooooooooooooooo#.",
	".#oooooooooooooooo#.",
	".#oo#oooooooooo#oo#.",
	".#ooo#oooooooo#ooo#.",
	"..#ooo##oooo##ooo#..",
	"..#ooooo####ooooo#..",
	"...#oooooooooooo#...",
	"....##oooooooo##....",
	"......########......",
	"....................",
	"....................",
	"....................",
}

LOLLIPOP := [20]string {
	".......######.......",
	".....##oooooo##.....",
	"....#ooxxxxxxoo#....",
	"...#oxxooooooxxo#...",
	"...#oxoxxxxxxoxo#...",
	"...#oxoxooooxoxo#...",
	"...#oxoxoxxoxoxo#...",
	"...#oxoxoxooxoxo#...",
	"...#oxoxooooxxo#....",
	"....#oxoxxxxoo#.....",
	".....##oooooo##.....",
	".......######.......",
	".........##.........",
	".........##.........",
	".........##.........",
	".........##.........",
	".........##.........",
	".........##.........",
	".........##.........",
	"....................",
}

COLOURS := [sl.Picture][3]u32 {
	.Sun      = {0xd07a10, 0xffd23a, 0x8a3a10},
	.Smile    = {0x2a6ac0, 0x8ad0ff, 0x1a3a7a},
	.Lollipop = {0xb02a7a, 0xff8ac8, 0xfaf6ea},
}

picture :: proc(p: sl.Picture, x, y, scale: int) {
	rows: []string
	switch p {
	case .Sun:
		rows = SUN[:]
	case .Smile:
		rows = SMILE[:]
	case .Lollipop:
		rows = LOLLIPOP[:]
	}
	cs := COLOURS[p]
	for r, j in rows {
		for i in 0 ..< len(r) {
			c: u32
			switch r[i] {
			case '#':
				c = cs[0]
			case 'o':
				c = cs[1]
			case 'x':
				c = cs[2]
			case:
				continue
			}
			if p == .Lollipop && j >= 12 {c = 0xe8dcc0} // the stick
			gfx.rect(x + i * scale, y + j * scale, scale, scale, c)
		}
	}
}

// ---- drawing ----

draw :: proc() {
	gfx.clear(BG)
	gfx.begin_buttons()
	// Lights round the top.
	for i in 0 ..< 24 {
		on := (i + int(app.clock * (app.phase == .Won ? 12 : 3))) % 3 == 0
		gfx.rect(8 + i * 15, 6, 6, 6, on ? GOLD : 0x5a4a2a)
	}
	gfx.text_c(W / 2 - 16, 20, "KIDDY SLOT", GOLD, 2)

	// The cabinet and its three windows.
	cx, cy, cw, ch := 20, 44, 296, 120
	gfx.rect(cx, cy, cw, ch, CABINET)
	gfx.rect(cx, cy, cw, 3, CABINET_LIT)
	gfx.rect(cx, cy + ch - 3, cw, 3, CABINET_DARK)
	for i in 0 ..< 3 {
		wx := cx + 12 + i * 94
		gfx.rect(wx - 2, cy + 14, 82, 92, CHROME)
		gfx.rect(wx, cy + 16, 78, 88, WINDOW)
		jig := 0
		if !app.stopped[i] {jig = int(app.t * 300) % 12 - 6}
		picture(app.shown[i], wx + 9, cy + 20 + jig, 3)
		if !app.stopped[i] {
			// Blur bands while the reel runs.
			gfx.rect(wx, cy + 16, 78, 6, 0xe0dccf)
			gfx.rect(wx, cy + 98, 78, 6, 0xe0dccf)
		}
	}

	// The lever at the side.
	lx := cx + cw + 22
	gfx.rect(lx - 4, cy + 50, 16, 40, CHROME)
	top := cy + 4 + int(app.lever * 46)
	gfx.rect(lx + 2, top + 10, 4, cy + 56 - top, 0x8a8e98)
	gfx.rect(lx - 4, top, 16, 14, 0xe8473c)
	gfx.frame(lx - 4, top, 16, 14, 0x9a2a2a)

	draw_zzoopps()
	draw_message()
}

draw_zzoopps :: proc() {
	m := &app.m
	gfx.text(20, 174, fmt.tprintf("YOU NOW HAVE %d ZZOOPPS", m.zzoopps), TEXT)
	// One round token for each, up to a row of twenty.
	n := min(m.zzoopps, 20)
	for i in 0 ..< n {
		x := 22 + i * 14
		gfx.rect(x, 188, 10, 10, GOLD)
		gfx.frame(x, 188, 10, 10, 0xa07a20)
		gfx.rect(x + 4, 191, 2, 4, 0xa07a20)
	}
	if m.zzoopps > 20 {gfx.text(22 + 20 * 14, 189, "+", GOLD)}
}

draw_message :: proc() {
	y := 210
	switch app.phase {
	case .Ready:
		if app.m.spins == 0 {
			gfx.text_c(W / 2, y - 2, "THREE ALIKE WIN FIVE ZZOOPPS.", DIM)
			gfx.text_c(W / 2, y + 10, "EACH SPIN COSTS ONE. GOOD LUCK!", DIM)
		}
		if int(app.clock * 2) % 2 == 0 {gfx.text_c(W / 2, y + 22, "PRESS ENTER OR TAP TO SPIN", GOLD)}
	case .Spinning:
		gfx.text_c(W / 2, y + 4, "ROUND AND ROUND...", DIM)
	case .Won:
		if app.t < 1.6 {
			if int(app.t * 6) % 2 == 0 {gfx.text_c(W / 2, y, "Y O U   W I N", GOLD, 2)}
		} else {
			gfx.text_c(W / 2, y, "H U R R A Y !", GOLD, 2)
			gfx.text_c(W / 2, y + 22, "PRESS ENTER OR TAP TO SPIN", DIM)
		}
	case .Lost:
		gfx.text_c(W / 2, y, "S O R R Y - THEY DON'T ALL MATCH", TEXT)
		gfx.text_c(W / 2, y + 22, "PRESS ENTER OR TAP TO SPIN", DIM)
	case .Out:
		gfx.text_c(W / 2, y - 4, "YOU ARE ALL OUT OF ZZOOPPS,", TEXT)
		gfx.text_c(W / 2, y + 8, "BUT JUST PRESS ENTER (OR TAP)", TEXT)
		gfx.text_c(W / 2, y + 20, "AND YOU CAN PLAY AGAIN!", GOLD)
	}
}
