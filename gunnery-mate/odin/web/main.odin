#+build js
package main

// Gunnery Mate's page: drawing, keys and taps. Rules are in ../game.

import "base:runtime"
import "core:fmt"
import "core:strconv"
import game "../game"
import "proto:gfx"

W :: 384
H :: 240
FX :: 8 // the play grid's top-left
FY :: 32
CELL :: 8

BG :: 0x07080f
HULL :: 0x161a26
HULL_LINE :: 0x232a3c
TEXT :: 0xe6ecf5
DIM :: 0x7d879c
GREEN :: 0x6fe08a
GREEN_DIM :: 0x2c5a38
RED :: 0xff5a4a
AMBER :: 0xffbf40
CYAN :: 0x6fd0f0
WHITE :: 0xffffff

Screen :: enum {
	Title,
	Playing,
	Over,
}

App :: struct {
	screen:   Screen,
	g:        game.Game,
	t:        f32,
	flash:    f32,
	best:     int,
	new_best: bool,
	stars:    [60][3]int,
}

app: App

ID_AGAIN :: 1
ID_MENU :: 2

main :: proc() {
	game.new_game(&app.g, 31)
	r: u64 = 0x9e3779b97f4a7c15
	for &s in app.stars {
		r = r * 6364136223846793005 + 1442695040888963407
		s = {int(r >> 33) % W, FY + int(r >> 45) % (game.ROWS * CELL), int(r >> 20) % 3}
	}
	buf: [32]u8
	if v, ok := gfx.store_get("best", buf[:]); ok {
		if n, nok := strconv.parse_int(v); nok && n >= 0 && n < 1000 {app.best = n}
	}
}

start :: proc() {
	game.new_game(&app.g, u64(gfx.now_ms()) ~ u64(gfx.random() * 1e9))
	app.screen = .Playing
	app.new_best = false
	gfx.tone(220, 120, .Saw, 0.04)
	gfx.tone(330, 160, .Saw, 0.04, 130)
}

@(export)
step :: proc(dt: f64) -> bool {
	d := f32(min(dt, 0.1))
	app.t += d
	app.flash = max(0, app.flash - d)
	if app.screen == .Playing || app.screen == .Title {game.update(&app.g, d)}
	if app.screen == .Playing {sounds()}
	draw()
	free_all(context.temp_allocator)
	return true
}

sounds :: proc() {
	g := &app.g
	ev := g.events
	g.events = {}
	if .Bang in ev {
		gfx.noise(90, 0.16)
		gfx.tone(880, 60, .Square, 0.04)
		app.flash = 0.08
	}
	if .Kill in ev {
		gfx.noise(400, 0.3, 60)
		gfx.tone(660, 80, .Square, 0.05, 80)
		gfx.tone(990, 120, .Square, 0.05, 170)
	}
	if .Miss in ev {gfx.tone(160, 120, .Saw, 0.04, 40)}
	if .Moved in ev && card(game.locked(g)) > 0 {gfx.tone(1320, 30, .Sine, 0.03)}
	if .Over in ev {
		if g.kills > app.best {
			app.best = g.kills
			app.new_best = true
			gfx.store_set("best", fmt.tprintf("%d", g.kills))
		}
		notes := [?]f32{392, 330, 262, 196}
		if game.rank(g.kills) >= .Good {notes = {262, 330, 392, 523}}
		for f, i in notes {gfx.tone(f, 160, .Triangle, 0.07, 300 + f32(i) * 170)}
		app.screen = .Over
		app.t = 0
	}
}

// ---- input ----

@(export)
on_key :: proc "c" (code: i32, down: i32) {
	context = runtime.default_context()
	if down != 1 {return}
	c := int(code)
	switch app.screen {
	case .Title:
		if c == gfx.KEY_ENTER || c == gfx.KEY_SPACE {start()}
	case .Playing:
		if c == gfx.KEY_ESCAPE {
			app.screen = .Title
		} else {
			game.fire(&app.g) // any key fires, as CLEAR did
		}
	case .Over:
		if app.t > 1 && (c == gfx.KEY_ENTER || c == gfx.KEY_SPACE) {start()}
		if app.t > 1 && c == gfx.KEY_ESCAPE {app.screen = .Title}
	}
}

@(export)
on_pointer :: proc "c" (x, y: f32, kind: i32) {
	context = runtime.default_context()
	if kind != 0 {return}
	switch app.screen {
	case .Title:
		start()
	case .Playing:
		game.fire(&app.g)
	case .Over:
		if app.t > 1 {
			if gfx.hit(x, y) == ID_MENU {app.screen = .Title} else {start()}
		}
	}
}

// ---- drawing ----

draw :: proc() {
	gfx.clear(BG)
	gfx.begin_buttons()
	draw_field()
	draw_hud()
	switch app.screen {
	case .Title:
		draw_title()
	case .Playing:
	case .Over:
		draw_over()
	}
}

cell_x :: proc(c: game.Cell) -> int {return FX + c.x * CELL}
cell_y :: proc(c: game.Cell) -> int {return FY + c.y * CELL}

RAIDER_ART := [3][8]string {
	{"..#....#..", ".##....##.", "###.oo.###", "#########.", "###.oo.###", ".##....##.", "..#....#..", ".........."},
	{"##......##", "##..oo..##", "##########", "##.oooo.##", "##########", "##..oo..##", "##......##", ".........."},
	{"....##....", "....##....", "#..####..#", "##########", "#..#oo#..#", "...####...", "....##....", ".........."},
}

draw_raider :: proc(kind: int, x, y: int, c: u32) {
	for row, j in RAIDER_ART[kind] {
		for i in 0 ..< len(row) {
			switch row[i] {
			case '#':
				gfx.rect(x + i * 2 + 2, y + j, 2, 1, c)
			case 'o':
				gfx.rect(x + i * 2 + 2, y + j, 2, 1, AMBER)
			}
		}
	}
}

draw_field :: proc() {
	g := &app.g
	// Space, seen through the station's gun deck.
	for s in app.stars {
		tw := (int(app.t * 2) + s[0]) % 7 == 0
		c: u32 = s[2] == 0 ? 0x3a4258 : (s[2] == 1 ? 0x6a7590 : 0xb8c4dd)
		if tw {c = 0x2a3045}
		gfx.rect(s[0], s[1], 1, 1, c)
	}
	gfx.frame(FX - 2, FY - 2, game.COLS * CELL + 4, game.ROWS * CELL + 4, HULL_LINE)
	lock := game.locked(g)
	// Batteries: a plus, lit when a raider's centre is on it.
	for b in g.batteries {
		x, y := cell_x(b), cell_y(b)
		lit := false
		for r, i in g.raiders {if i in lock && r == b {lit = true}}
		c: u32 = lit ? (int(app.t * 16) % 2 == 0 ? RED : WHITE) : GREEN
		gfx.rect(x + 3, y + 1, 2, 6, c)
		gfx.rect(x + 1, y + 3, 6, 2, c)
		if lit {gfx.frame(x - 1, y - 1, CELL + 2, CELL + 2, RED)}
	}
	// Raiders, three cells wide around their centre.
	for r, i in g.raiders {
		gone := g.clock - g.killed_at[i]
		if gone < 0.5 {
			// Where the last one blew up, the new one warps in.
			k := gone / 0.5
			gfx.rect(cell_x(r) - CELL, cell_y(r) + 3, int(3 * CELL * k), 1, CYAN)
			continue
		}
		draw_raider(i, cell_x(r) - CELL, cell_y(r), i in lock ? WHITE : 0xa8b4c8)
	}
	if app.flash > 0 {
		gfx.frame(FX - 2, FY - 2, game.COLS * CELL + 4, game.ROWS * CELL + 4, AMBER)
	}
}

draw_hud :: proc() {
	g := &app.g
	gfx.rect(0, 0, W, 26, HULL)
	gfx.rect(0, 25, W, 1, HULL_LINE)
	gfx.text(8, 4, "GUNNERY MATE", GREEN)
	gfx.text(8, 15, fmt.tprintf("KILLS %2d", g.kills), TEXT)
	gfx.text(W - 8 - gfx.text_width("BEST 00"), 15, fmt.tprintf("BEST %2d", app.best), DIM)
	gfx.text(W - 8 - gfx.text_width("SHOTS"), 4, "SHOTS", DIM)
	// Shots as little shells.
	for i in 0 ..< game.SHOTS {
		x := 120 + i * 6
		on := i < g.shots
		gfx.rect(x, 6, 3, 6, on ? AMBER : 0x3a2e14)
		gfx.rect(x, 6, 3, 1, on ? WHITE : 0x3a2e14)
	}
	gfx.rect(0, H - 26, W, 26, HULL)
	gfx.rect(0, H - 26, W, 1, HULL_LINE)
	if app.screen == .Playing {
		gfx.text_c(W / 2, H - 18, "FIRE WHEN A RAIDER'S CENTRE IS ON A BATTERY", DIM)
	}
}

draw_title :: proc() {
	gfx.rect(28, 50, W - 56, 140, HULL)
	gfx.frame(28, 50, W - 56, 140, GREEN)
	gfx.text_c(W / 2, 60, "GUNNERY", GREEN, 3)
	gfx.text_c(W / 2, 86, "MATE", GREEN, 3)
	lines := [?]string {
		"YOU WORK THE OVERLORD'S BATTERIES.",
		"RAIDERS DRIFT OVER THE GUN DECK.",
		"WHEN ONE IS CENTRED ON A + , FIRE!",
		"ANY KEY OR A TAP FIRES. 21 SHOTS.",
	}
	for l, i in lines {gfx.text_c(W / 2, 118 + i * 11, l, TEXT)}
	if int(app.t * 2) % 2 == 0 {gfx.text_c(W / 2, 172, "PRESS SPACE OR TAP TO BEGIN", AMBER)}
	gfx.text_c(W / 2, H - 18, "AFTER 'DEATH STAR', SOFTSIDE 1978", DIM)
}

draw_over :: proc() {
	g := &app.g
	gfx.rect(40, 60, W - 80, 116, HULL)
	gfx.frame(40, 60, W - 80, 116, GREEN)
	gfx.text_c(W / 2, 70, "SHOTS EXPENDED", AMBER, 2)
	gfx.text_c(W / 2, 94, fmt.tprintf("%d RAIDERS DESTROYED", g.kills), TEXT)
	a, b: string
	switch game.rank(g.kills) {
	case .School:
		a, b = "YOU ARE BEING SENT BACK", "TO GUNNERY SCHOOL."
	case .Demoted:
		a, b = "THE OVERLORD HAS DEMOTED YOU", "TO GUNNERY MATE THIRD CLASS."
	case .Good:
		a, b = "GOOD SHOOTING.", "THE OVERLORD IS VERY PLEASED."
	case .Promoted:
		a, b = "TERRIFIC!", "A PROMOTION AND A BONUS ARE ON THE WAY."
	}
	gfx.text_c(W / 2, 110, a, GREEN)
	gfx.text_c(W / 2, 121, b, GREEN)
	if app.new_best {gfx.text_c(W / 2, 134, "NEW BEST!", AMBER)}
	if app.t > 1 {
		gfx.button(W / 2 - 92, 148, "PLAY AGAIN", ID_AGAIN, TEXT, 0x22283a)
		gfx.button(W / 2 + 20, 148, "TITLE", ID_MENU, DIM, 0x22283a)
	}
}
