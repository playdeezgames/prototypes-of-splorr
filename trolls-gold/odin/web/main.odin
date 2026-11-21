#+build js
package main

// Troll's Gold's page: the cave, keys and taps. Rules are in ../game.

import "base:runtime"
import "core:fmt"
import "core:strconv"
import game "../game"
import "proto:gfx"

W :: 384
H :: 240
X0 :: 14 // the cave's top-left (outer wall)
Y0 :: 32
RW :: 32 // a room, wall included
RH :: 29
WALL :: 2
PX :: X0 + game.COLS * RW + WALL + 10 // the side panel

BG :: 0x0e0c0a
ROCK :: 0x8a7050
ROCK_LIT :: 0xa88a62
FLOOR :: 0x15110d
FLOOR_LIT :: 0x2b241b
PANEL :: 0x18140f
PANEL_LINE :: 0x3a3024
TEXT :: 0xe8d9a8
DIM :: 0x8f8a6e
GOLD :: 0xffcc33
GOLD_DARK :: 0xb07a12
TROLL :: 0x7fbf4a
TROLL_DARK :: 0x3f6a22
HERO :: 0xeae2d2
RED :: 0xff5a4a
EXIT :: 0x9fd0ff

Screen :: enum {
	Title,
	Playing,
	Over,
}

// What the page is waiting on between yer move and yer next.
Phase :: enum {
	Input,
	Troll, // the troll moves when the timer runs out
	Doors, // then the doors change
}

App :: struct {
	screen:   Screen,
	phase:    Phase,
	timer:    f32,
	g:        game.Game,
	t:        f32,
	moved_t:  f32, // time since the troll last moved (slides it between rooms)
	bump:     f32, // a shut door was tried
	bump_dir: game.Dir,
	wins:     int,
	losses:   int,
	fastest:  int,
	new_best: bool,
}

app: App

ID_AGAIN :: 1
ID_MENU :: 2

main :: proc() {
	game.new_game(&app.g, 17)
	app.moved_t = 10
	app.wins = load_int("wins")
	app.losses = load_int("losses")
	app.fastest = load_int("fastest")
}

load_int :: proc(key: string) -> int {
	buf: [32]u8
	if v, ok := gfx.store_get(key, buf[:]); ok {
		if n, nok := strconv.parse_int(v); nok && n >= 0 && n < 1_000_000 {return n}
	}
	return 0
}

start :: proc() {
	game.new_game(&app.g, u64(gfx.now_ms()) ~ u64(gfx.random() * 1e9))
	app.screen = .Playing
	app.phase = .Input
	app.new_best = false
	app.moved_t = 10
	creak(0)
}

@(export)
step :: proc(dt: f64) -> bool {
	d := f32(min(dt, 0.1))
	app.t += d
	app.moved_t += d
	app.bump = max(0, app.bump - d)
	if app.screen == .Playing && app.phase != .Input {
		app.timer -= d
		if app.timer <= 0 {
			switch app.phase {
			case .Troll:
				game.troll_turn(&app.g)
				app.moved_t = 0
				sounds()
				if app.screen == .Playing {
					app.phase = .Doors
					app.timer = 0.22
				}
			case .Doors:
				game.shuffle_doors(&app.g)
				creak(0)
				app.phase = .Input
			case .Input:
			}
		}
	}
	draw()
	free_all(context.temp_allocator)
	return true
}

creak :: proc(delay: f32) {
	gfx.tone(96, 70, .Saw, 0.03, delay)
	gfx.tone(118, 90, .Saw, 0.025, delay + 60)
}

sounds :: proc() {
	g := &app.g
	ev := g.events
	g.events = {}
	if .Blocked in ev {gfx.tone(70, 90, .Square, 0.05)}
	if .Moved in ev {gfx.tone(330, 30, .Triangle, 0.05)}
	if .Gold in ev {
		for f, i in ([?]f32{523, 659, 784, 1047}) {gfx.tone(f, 90, .Square, 0.04, f32(i) * 80)}
	}
	if .Troll_Moved in ev {
		gfx.tone(62, 140, .Square, 0.07)
		gfx.noise(60, 0.08)
	}
	if .Troll_Rested in ev {
		gfx.noise(220, 0.03)
		gfx.noise(220, 0.03, 300)
	}
	if .Eaten in ev {
		gfx.noise(500, 0.25)
		for f, i in ([?]f32{220, 185, 147, 110}) {gfx.tone(f, 200, .Saw, 0.06, 200 + f32(i) * 190)}
		finish()
	}
	if .Escaped in ev {
		for f, i in ([?]f32{392, 523, 659, 784, 1047}) {gfx.tone(f, 140, .Triangle, 0.07, f32(i) * 120)}
		finish()
	}
}

finish :: proc() {
	g := &app.g
	if g.won {
		app.wins += 1
		if app.fastest == 0 || g.turns < app.fastest {
			app.fastest = g.turns
			app.new_best = true
			gfx.store_set("fastest", fmt.tprintf("%d", g.turns))
		}
		gfx.store_set("wins", fmt.tprintf("%d", app.wins))
	} else {
		app.losses += 1
		gfx.store_set("losses", fmt.tprintf("%d", app.losses))
	}
	app.screen = .Over
	app.phase = .Input
	app.t = 0
}

try_move :: proc(d: game.Dir) {
	if app.screen != .Playing || app.phase != .Input {return}
	if game.player_move(&app.g, d) {
		sounds()
		if app.screen == .Playing {
			app.phase = .Troll
			app.timer = 0.28
		}
	} else {
		app.bump = 0.25
		app.bump_dir = d
		sounds()
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
		switch c {
		case gfx.KEY_UP, 'U', 'W':
			try_move(.Up)
		case gfx.KEY_DOWN, 'D', 'S':
			try_move(.Down)
		case gfx.KEY_RIGHT, 'R', 'I':
			try_move(.Right)
		case gfx.KEY_LEFT, 'L', 'O', 'A':
			try_move(.Left)
		case gfx.KEY_SPACE, gfx.KEY_ENTER, '.', 'Z':
			try_move(.Stay)
		case gfx.KEY_ESCAPE:
			app.screen = .Title
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
		// A tap on yer own room stays; on a room next to it, goes there.
		c := int(x - X0) / RW
		r := int(y - Y0) / RH
		if x < X0 || y < Y0 || c >= game.COLS || r >= game.ROWS {
			if gfx.hit(x, y) == ID_MENU {app.screen = .Title}
			return
		}
		room := r * game.COLS + c
		p := app.g.player
		switch room {
		case p:
			try_move(.Stay)
		case p - game.COLS:
			try_move(.Up)
		case p + game.COLS:
			try_move(.Down)
		case p - 1:
			if game.row_of(room) == game.row_of(p) {try_move(.Left)}
		case p + 1:
			if game.row_of(room) == game.row_of(p) {try_move(.Right)}
		}
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
	draw_cave()
	draw_panel()
	switch app.screen {
	case .Title:
		draw_title()
	case .Playing:
	case .Over:
		draw_over()
	}
}

room_x :: proc(room: int) -> int {return X0 + game.col_of(room) * RW + WALL}
room_y :: proc(room: int) -> int {return Y0 + game.row_of(room) * RH + WALL}
IW :: RW - WALL // a room's floor
IH :: RH - WALL

draw_cave :: proc() {
	g := &app.g
	gfx.rect(X0 - 2, Y0 - 2, game.COLS * RW + WALL + 4, game.ROWS * RH + WALL + 4, ROCK_LIT)
	gfx.rect(X0, Y0, game.COLS * RW + WALL, game.ROWS * RH + WALL, ROCK)
	for room in 0 ..< game.ROOMS {
		c: u32 = room == g.player && app.screen == .Playing ? FLOOR_LIT : FLOOR
		gfx.rect(room_x(room), room_y(room), IW, IH, c)
	}
	// The open doors this turn: gaps in the walls.
	for room in 0 ..< game.ROOMS {
		if game.col_of(room) < game.COLS - 1 {
			d, _ := game.door_between(room, room + 1)
			if g.open[d] {
				lit := room == g.player || room + 1 == g.player
				gfx.rect(room_x(room) + IW, room_y(room) + IH / 2 - 5, WALL, 10, lit ? FLOOR_LIT : FLOOR)
			}
		}
		if game.row_of(room) < game.ROWS - 1 {
			d, _ := game.door_between(room, room + game.COLS)
			if g.open[d] {
				lit := room == g.player || room + game.COLS == g.player
				gfx.rect(room_x(room) + IW / 2 - 6, room_y(room) + IH, 12, WALL, lit ? FLOOR_LIT : FLOOR)
			}
		}
	}
	// The cave mouth, on the left of the first room.
	gfx.rect(X0 - 2, room_y(0) + IH / 2 - 6, WALL + 2, 12, FLOOR)
	gfx.text(1, room_y(0) + IH / 2 - 4, "<", EXIT)
	if app.screen == .Playing && app.phase == .Input {draw_exits()}
	if !g.gold {draw_hoard(room_x(game.GOLD_ROOM) + 1, room_y(game.GOLD_ROOM) + 2)}
	draw_troll()
	if !(app.screen == .Over && !g.won) {draw_hero()}
}

// Little arrows in the open doorways of yer room.
draw_exits :: proc() {
	g := &app.g
	p := g.player
	px, py := room_x(p), room_y(p)
	blink := int(app.t * 3) % 2 == 0
	col: u32 = blink ? GOLD : GOLD_DARK
	if _, ok := game.can_go(g, p, .Up); ok {gfx.rect(px + IW / 2 - 1, py, 2, 2, col)}
	if _, ok := game.can_go(g, p, .Down); ok {gfx.rect(px + IW / 2 - 1, py + IH - 2, 2, 2, col)}
	if _, ok := game.can_go(g, p, .Left); ok {gfx.rect(px, py + IH / 2 - 1, 2, 2, col)}
	if _, ok := game.can_go(g, p, .Right); ok {gfx.rect(px + IW - 2, py + IH / 2 - 1, 2, 2, col)}
	if app.bump > 0 {
		// The wall you walked into flashes.
		c: u32 = RED
		switch app.bump_dir {
		case .Up:
			gfx.rect(px, py - WALL, IW, WALL, c)
		case .Down:
			gfx.rect(px, py + IH, IW, WALL, c)
		case .Left:
			gfx.rect(px - WALL, py, WALL, IH, c)
		case .Right:
			gfx.rect(px + IW, py, WALL, IH, c)
		case .Stay:
		}
	}
}

HERO_ART := [?]string{"..#..", ".###.", "#.#.#", "..#..", ".#.#.", ".#.#."}
TROLL_ART := [?]string {
	"..#....#..",
	".########.",
	".#o####o#.",
	"##########",
	"#.#VVVV#.#",
	"#.######.#",
	"#.######.#",
	"..##..##..",
	".###..###.",
}
HOARD_ART := [?]string{"....o....", "...ooo...", "..ooooo..", ".ooo.ooo.", "ooooooooo"}

art :: proc(rows: []string, x, y, px: int, body, extra: u32) {
	for row, j in rows {
		for i in 0 ..< len(row) {
			switch row[i] {
			case '#':
				gfx.rect(x + i * px, y + j * px, px, px, body)
			case 'o', 'V':
				gfx.rect(x + i * px, y + j * px, px, px, extra)
			}
		}
	}
}

draw_hoard :: proc(x, y: int) {
	art(HOARD_ART[:], x, y, 1, GOLD, int(app.t * 4) % 3 == 0 ? 0xfff2a8 : GOLD)
}

draw_hero :: proc() {
	g := &app.g
	x := room_x(g.player) + IW / 2 - 5
	y := room_y(g.player) + IH / 2 - 6
	art(HERO_ART[:], x, y, 2, HERO, HERO)
	if g.gold {gfx.rect(x + 8, y + 4, 3, 3, GOLD)}
}

draw_troll :: proc() {
	g := &app.g
	k := min(1, app.moved_t / 0.18)
	ax, ay := f32(room_x(g.troll_from)), f32(room_y(g.troll_from))
	bx, by := f32(room_x(g.troll)), f32(room_y(g.troll))
	x := int(ax + (bx - ax) * k) + IW / 2 - 10
	y := int(ay + (by - ay) * k) + IH - 20
	eyes: u32 = RED
	if app.screen == .Playing && game.troll_winded(g) {eyes = int(app.t * 2) % 2 == 0 ? 0x5a2a20 : RED}
	art(TROLL_ART[:], x, y, 2, TROLL, eyes)
	// Its teeth are white.
	for i in 0 ..< 4 {gfx.rect(x + 6 + i * 2, y + 8, 1, 2, 0xffffff)}
}

draw_panel :: proc() {
	g := &app.g
	gfx.rect(0, 0, W, 24, PANEL)
	gfx.rect(0, 23, W, 1, PANEL_LINE)
	gfx.text(X0, 8, "TROLL'S GOLD", GOLD)
	gfx.text(W - 8 - gfx.text_width("TURN 000"), 8, fmt.tprintf("TURN %3d", g.turns), DIM)
	x := PX
	y := Y0 + 2
	if app.screen == .Playing {
		if g.gold {
			gfx.text(x, y, "YOU HAVE THE GOLD.", GOLD)
			gfx.text(x, y + 11, "GET OUT! (TOP LEFT)", TEXT)
		} else {
			gfx.text(x, y, "THE GOLD IS IN THE", TEXT)
			gfx.text(x, y + 11, "DEEPEST ROOM.", TEXT)
		}
		if game.troll_winded(g) {
			gfx.text(x, y + 30, "THE TROLL IS", TROLL)
			gfx.text(x, y + 41, "PUFFING: IT WILL", TROLL)
			gfx.text(x, y + 52, "REST NEXT TURN.", TROLL)
		} else {
			gfx.text(x, y + 30, "THE TROLL IS", TROLL)
			gfx.text(x, y + 41, "COMING FOR YOU.", TROLL)
		}
		gfx.text(x, y + 76, "ARROWS: GO", DIM)
		gfx.text(x, y + 87, "SPACE: STAY", DIM)
		gfx.text(x, y + 98, "OR TAP A ROOM", DIM)
	}
	gfx.rect(x - 4, Y0 + 124, W - x - 4, 1, PANEL_LINE)
	gfx.text(x, Y0 + 132, fmt.tprintf("ESCAPES %d", app.wins), TEXT)
	gfx.text(x, Y0 + 143, fmt.tprintf("EATEN   %d", app.losses), TEXT)
	if app.fastest > 0 {
		gfx.text(x, Y0 + 154, fmt.tprintf("FASTEST %d TURNS", app.fastest), DIM)
	}
	if app.screen == .Playing {
		gfx.text(x, H - 14, "ESC: TITLE", DIM)
	}
}

panel_box :: proc(y, h: int, edge: u32) {
	gfx.rect(24, y, W - 48, h, PANEL)
	gfx.frame(24, y, W - 48, h, edge)
}

draw_title :: proc() {
	panel_box(44, 160, GOLD)
	gfx.text_c(W / 2, 54, "TROLL'S", GOLD, 3)
	gfx.text_c(W / 2, 80, "GOLD", GOLD, 3)
	lines := [?]string {
		"A TROLL SITS ON A HOARD OF GOLD",
		"IN THE DEEPEST ROOM OF HIS CAVE.",
		"EVERY TURN, DIFFERENT DOORS OPEN.",
		"TAKE THE GOLD AND GET BACK OUT.",
		"EVERY THIRD TURN HE CATCHES HIS",
		"BREATH. USE IT.",
	}
	for l, i in lines {gfx.text_c(W / 2, 110 + i * 11, l, TEXT)}
	if int(app.t * 2) % 2 == 0 {gfx.text_c(W / 2, 182, "PRESS SPACE OR TAP TO ENTER", GOLD)}
	gfx.text_c(W / 2, H - 14, "AFTER GEORGE BLANK, SOFTSIDE 1978", DIM)
}

draw_over :: proc() {
	g := &app.g
	panel_box(56, 132, g.won ? GOLD : RED)
	lines: [4]string
	if g.won {
		gfx.text_c(W / 2, 66, "YOU GOT OUT!", GOLD, 2)
		lines = {
			"YOU ARE VERY RICH.",
			fmt.tprintf("%d TURNS IN THE CAVE.", g.turns),
			"",
			"P.S. THE TROLL WONDERS IF YOU",
		}
		gfx.text_c(W / 2, 134, "COULD LEND HIM A FEW THOUSAND.", DIM)
	} else {
		gfx.text_c(W / 2, 66, "EATEN!", RED, 2)
		lines = {
			"THE SIGN AT THE CAVE MOUTH SAID",
			"PLEASE DON'T FEED THE TROLL.",
			"",
			"SOME PEOPLE NEVER LEARN.",
		}
	}
	for l, i in lines {
		c: u32 = i == 3 && g.won ? DIM : TEXT
		if len(l) > 0 {gfx.text_c(W / 2, 90 + i * 11, l, c)}
	}
	if app.new_best {gfx.text_c(W / 2, 146, "YER FASTEST YET!", GOLD)}
	if app.t > 1 {
		gfx.button(W / 2 - 92, 160, "PLAY AGAIN", ID_AGAIN, TEXT, 0x2a2219)
		gfx.button(W / 2 + 20, 160, "TITLE", ID_MENU, DIM, 0x2a2219)
	}
}
