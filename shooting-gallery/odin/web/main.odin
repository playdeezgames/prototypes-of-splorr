#+build js
package main

// Shooting Gallery's page: drawing, keys and taps. Rules are in ../game.

import "base:runtime"
import "core:fmt"
import "core:strconv"
import game "../game"
import "proto:gfx"

W :: game.W
H :: game.H

BG :: 0x141a33
CURTAIN :: 0x5c1a2a
CURTAIN_DARK :: 0x3e101c
SHELF :: 0x7a4a24
SHELF_LIT :: 0xa8692f
TEXT :: 0xf3e6c4
DIM :: 0x9a8fb3
GOLD :: 0xf6c945
RED :: 0xe8473c
WHITE :: 0xfaf6ea
ORANGE :: 0xf08a24
BLUE :: 0x4aa3e8
GREEN :: 0x6fd36a

Screen :: enum {
	Title,
	Playing,
	Over,
}

Popup :: struct {
	x, y: f32,
	t:    f32,
	pts:  int,
}

App :: struct {
	screen:   Screen,
	g:        game.Game,
	held:     bit_set[Dir],
	best:     int,
	t:        f32,
	flash:    f32,
	popups:   [8]Popup,
	new_best: bool,
}

Dir :: enum {
	Left,
	Right,
	Up,
	Down,
}

app: App

ID_START :: 1
ID_MENU :: 2

// ---- sprites: '#' main colour, 'o' second, 'x' third, '.' clear ----

STAR := [?]string{"...#....", "..###...", "#######.", ".#####..", "..###...", ".##.##..", "#.....#."}

CLOWN := [?]string {
	".......xx.......",
	"......xxxx......",
	".....xxxxxx.....",
	"....xxxxxxxx....",
	"..oo########oo..",
	".ooo########ooo.",
	".oo##..##..##oo.",
	"..o##..##..##o..",
	"...####xx####...",
	"...###xxxx###...",
	"...####xx####...",
	"....##x##x##....",
	"....###xxx##....",
	".....######.....",
	"......####......",
	".......##.......",
}

PIPE := [?]string {"..#####.", ".#ooooo#", ".#ooooo#", "..#ooo#.", "...#o#..", "...#o#..", "...#o#..", "...#o#..", "...#o#..", "..#ooo#.", "..#####.", "........"}

DUCK := [?]string {
	"....###.......",
	"...#####......",
	"...##.##xx....",
	"...#####xxx...",
	"....###.......",
	".#..####......",
	"##########....",
	"###########...",
	"############..",
	".##########...",
	"..########....",
	"....oooo......",
}

ARROW := [?]string {".........o........", "#......oooo.......", "##################", "#......oooo.......", ".........o........"}

sprite :: proc(rows: []string, x, y: int, c1, c2, c3: u32) {
	for r, j in rows {
		for i in 0 ..< len(r) {
			c: u32
			switch r[i] {
			case '#':
				c = c1
			case 'o':
				c = c2
			case 'x':
				c = c3
			case:
				continue
			}
			gfx.rect(x + i, y + j, 1, 1, c)
		}
	}
}

main :: proc() {
	game.new_game(&app.g, 12345) // the rows run behind the title
	buf: [32]u8
	if v, ok := gfx.store_get("best", buf[:]); ok {
		if n, nok := strconv.parse_int(v); nok && n >= 0 && n < 1000000 {app.best = n}
	}
}

start :: proc() {
	game.new_game(&app.g, u64(gfx.now_ms()) ~ u64(gfx.random() * 1e9))
	app.screen = .Playing
	app.popups = {}
	app.new_best = false
	gfx.tone(392, 80, .Square, 0.05)
	gfx.tone(523, 120, .Square, 0.05, 90)
}

@(export)
step :: proc(dt: f64) -> bool {
	d := f32(min(dt, 0.1))
	app.t += d
	app.flash = max(0, app.flash - d)
	for &p in app.popups {if p.t > 0 {p.t -= d}}
	if app.screen == .Playing {
		dx, dy: f32
		if .Left in app.held {dx -= 1}
		if .Right in app.held {dx += 1}
		if .Up in app.held {dy -= 1}
		if .Down in app.held {dy += 1}
		if dx != 0 || dy != 0 {game.nudge(&app.g, dx, dy, d)}
		game.update(&app.g, d)
		sounds()
	} else if app.screen == .Title {
		game.update(&app.g, d) // the rows run behind the title
	}
	draw()
	free_all(context.temp_allocator)
	return true
}

sounds :: proc() {
	g := &app.g
	ev := g.events
	g.events = {}
	if .Bang in ev {
		gfx.noise(110, 0.22)
		app.flash = 0.06
	}
	if .Hit in ev || .Arrow_Hit in ev {
		f: f32 = 440 + f32(g.last_points) * 8
		gfx.tone(f, 60, .Square, 0.05, 40)
		gfx.tone(f * 1.5, 80, .Square, 0.05, 100)
		for &p in app.popups {
			if p.t <= 0 {
				p = {g.sx, g.sy - 6, 0.8, g.last_points}
				break
			}
		}
	}
	if .Arrow_Appears in ev {
		gfx.tone(1200, 400, .Sine, 0.04)
		gfx.tone(900, 300, .Sine, 0.03, 380)
	}
	if .Game_Over in ev {
		if g.score > app.best {
			app.best = g.score
			app.new_best = true
			gfx.store_set("best", fmt.tprintf("%d", g.score))
		}
		notes := [?]f32{523, 392, 330, 262}
		for f, i in notes {gfx.tone(f, 160, .Triangle, 0.07, 300 + f32(i) * 170)}
	}
	if g.over && app.screen == .Playing {
		app.screen = .Over
		app.t = 0
	}
}

// ---- input ----

@(export)
on_key :: proc "c" (code: i32, down: i32) {
	context = runtime.default_context()
	c := int(code)
	dir, is_dir := key_dir(c)
	if is_dir {
		if down != 0 {app.held += {dir}} else {app.held -= {dir}}
		return
	}
	if down != 1 {return}
	switch app.screen {
	case .Title:
		if c == gfx.KEY_ENTER || c == gfx.KEY_SPACE {start()}
	case .Playing:
		if c == gfx.KEY_SPACE || c == gfx.KEY_ENTER || c == 'Z' || c == 'X' {game.fire(&app.g)}
	case .Over:
		if app.t > 1 && (c == gfx.KEY_ENTER || c == gfx.KEY_SPACE) {start()}
		if app.t > 1 && c == gfx.KEY_ESCAPE {app.screen = .Title}
	}
}

key_dir :: proc(c: int) -> (Dir, bool) {
	switch c {
	case gfx.KEY_LEFT, 'A':
		return .Left, true
	case gfx.KEY_RIGHT, 'D':
		return .Right, true
	case gfx.KEY_UP, 'W':
		return .Up, true
	case gfx.KEY_DOWN, 'S':
		return .Down, true
	}
	return .Left, false
}

@(export)
on_pointer :: proc "c" (x, y: f32, kind: i32) {
	context = runtime.default_context()
	switch app.screen {
	case .Title:
		if kind == 0 {start()}
	case .Playing:
		game.aim(&app.g, x, y)
		if kind == 0 {game.fire(&app.g)}
	case .Over:
		if kind == 0 && app.t > 1 {
			id := gfx.hit(x, y)
			if id == ID_MENU {app.screen = .Title} else {start()}
		}
	}
}

// ---- drawing ----

draw :: proc() {
	gfx.clear(BG)
	gfx.begin_buttons()
	draw_booth()
	switch app.screen {
	case .Title:
		draw_title()
	case .Playing:
		draw_sight()
		draw_hud()
	case .Over:
		draw_hud()
		draw_over()
	}
	if app.flash > 0 {
		gfx.frame(0, 0, W, H, WHITE)
		gfx.frame(1, 1, W - 2, H - 2, GOLD)
	}
}

draw_booth :: proc() {
	g := &app.g
	// Curtain with folds, and lights along the top.
	gfx.rect(0, 0, W, 22, CURTAIN)
	for x := 0; x < W; x += 16 {gfx.rect(x + 12, 0, 4, 22, CURTAIN_DARK)}
	for x := 8; x < W; x += 24 {
		on := (x / 24 + int(app.t * 3)) % 2 == 0
		gfx.rect(x, 18, 4, 4, on ? GOLD : 0x6b5a2a)
	}
	gfx.rect(0, 22, W, 2, SHELF)

	for def, i in game.ROWS {
		for s in 0 ..< g.rows[i].slots {
			if !g.rows[i].alive[s] {continue}
			x := int(game.slot_x(g, i, s))
			switch def.kind {
			case .Star:
				sprite(STAR[:], x, def.y, GOLD, GOLD, GOLD)
			case .Clown:
				sprite(CLOWN[:], x, def.y, WHITE, ORANGE, RED)
			case .Pipe:
				sprite(PIPE[:], x, def.y, 0x9c9486, WHITE, WHITE)
			case .Duck:
				sprite(DUCK[:], x, def.y, GOLD, ORANGE, ORANGE)
			case .Arrow:
			}
		}
		// The shelf each row rides on.
		gfx.rect(0, def.y + def.h + 1, W, 3, SHELF)
		gfx.rect(0, def.y + def.h + 1, W, 1, SHELF_LIT)
	}
	if g.arrow.active {
		sprite(ARROW[:], int(g.arrow.x), game.ARROW_LANES[g.arrow.lane], 0xd8c8a0, RED, RED)
	}
	// Counter.
	gfx.rect(0, 178, W, H - 178, 0x2a1a10)
	gfx.rect(0, 178, W, 3, SHELF_LIT)

	for p in app.popups {
		if p.t <= 0 {continue}
		rise := int((0.8 - p.t) * 30)
		gfx.text_c(int(p.x), int(p.y) - rise, fmt.tprintf("+%d", p.pts), p.pts >= 100 ? RED : GOLD)
	}
}

draw_sight :: proc() {
	g := &app.g
	x, y := int(g.sx), int(g.sy)
	c: u32 = int(app.t * 6) % 2 == 0 ? WHITE : RED
	gfx.rect(x - 5, y, 4, 1, c)
	gfx.rect(x + 2, y, 4, 1, c)
	gfx.rect(x, y - 5, 1, 4, c)
	gfx.rect(x, y + 2, 1, 4, c)
	gfx.rect(x, y, 1, 1, c)
}

draw_hud :: proc() {
	g := &app.g
	// Shots as little bullets.
	gfx.text(8, 188, "SHOTS", DIM)
	for i in 0 ..< game.SHOTS {
		c: u32 = i < g.shots ? GOLD : 0x4a3a20
		gfx.rect(56 + i * 7, 188, 4, 8, c)
		gfx.rect(56 + i * 7, 188, 4, 2, i < g.shots ? 0xc08a30 : 0x4a3a20)
	}
	gfx.text(W - 8 - gfx.text_width("SCORE 0000"), 188, fmt.tprintf("SCORE %4d", g.score), TEXT)
	gfx.text(8, 204, "STARS 50  PIPES 25  DUCKS 15  CLOWNS 10", DIM)
	gfx.text(8, 216, "ARROW 100", RED)
	gfx.text(W - 8 - gfx.text_width("BEST 0000"), 216, fmt.tprintf("BEST %4d", app.best), DIM)
}

draw_title :: proc() {
	gfx.rect(12, 54, W - 24, 118, 0x0e1224)
	gfx.frame(12, 54, W - 24, 118, GOLD)
	gfx.text_c(W / 2, 64, "SHOOTING", GOLD, 3)
	gfx.text_c(W / 2, 92, "GALLERY", GOLD, 3)
	lines := [?]string {
		"20 SHOTS. HIT THE TARGETS AS THEY GO BY.",
		"ARROWS OR WASD MOVE THE SIGHT, SPACE FIRES.",
		"OR POINT AND CLICK (OR TAP) TO SHOOT.",
		"A MISS STILL COSTS A SHOT!",
	}
	for l, i in lines {gfx.text_c(W / 2, 122 + i * 10, l, TEXT)}
	if int(app.t * 2) % 2 == 0 {gfx.text_c(W / 2, 192, "PRESS SPACE OR TAP TO BEGIN", GOLD)}
	gfx.text_c(W / 2, 212, fmt.tprintf("BEST %d", app.best), DIM)
	gfx.text_c(W / 2, 228, "AFTER FRANK B. ROWLETT, JR., SOFTSIDE 1979", DIM)
}

draw_over :: proc() {
	g := &app.g
	gfx.rect(56, 50, W - 112, 116, 0x0e1224)
	gfx.frame(56, 50, W - 112, 116, GOLD)
	gfx.text_c(W / 2, 60, "GAME OVER", RED, 2)
	gfx.text_c(W / 2, 86, fmt.tprintf("SCORE %d", g.score), TEXT, 2)
	verdict := "KEEP PRACTISING"
	switch {
	case g.score >= 700:
		verdict = "FASTEST GUN IN TOWN!"
	case g.score >= 450:
		verdict = "A CRACK SHOT"
	case g.score >= 250:
		verdict = "A STEADY HAND"
	}
	gfx.text_c(W / 2, 110, verdict, GOLD)
	if app.new_best {gfx.text_c(W / 2, 122, "NEW BEST!", GREEN)}
	if app.t > 1 {
		gfx.button(W / 2 - 92, 138, "PLAY AGAIN", ID_START, TEXT, 0x2a2340)
		gfx.button(W / 2 + 20, 138, "TITLE", ID_MENU, DIM, 0x2a2340)
	}
}
