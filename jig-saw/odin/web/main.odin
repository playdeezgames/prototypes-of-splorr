#+build js
package main

// Jig Saw's page: drawing, keys and taps. Rules are in ../game.

import "base:runtime"
import "core:fmt"
import "core:strconv"
import game "../game"
import "proto:gfx"

W :: 384
H :: 240

BG :: 0x1c2430
PANEL :: 0x26303f
GRID :: 0x3a4658
TEXT :: 0xeee6d2
DIM :: 0x8a93a3
GOLD :: 0xf2c94c
RED :: 0xe05a47
MARK :: 0x5a6477

SHAPE_COL := [7]u32{0, 0xe8e2d0, 0x58b4e8, 0x6fcf72, 0xf2994a, 0xc77ddb, 0xeb5c7a}

Screen :: enum {
	Title,
	Playing,
	Over,
}

App :: struct {
	screen:   Screen,
	g:        game.Game,
	t:        f32,
	msg:      string,
	msg_t:    f32,
	typed:    int, // digits typed so far (0 = none)
	flash:    [game.SQUARES]f32,
	best:     int, // fewest tries solo, 0 = none
	new_best: bool,
	players:  int,
}

app: App

ID_ONE :: 100
ID_TWO :: 101
ID_AGAIN :: 102
ID_MENU :: 103

BX :: 20
BY :: 40
CS :: 40 // board square

main :: proc() {
	buf: [32]u8
	if v, ok := gfx.store_get("best", buf[:]); ok {
		if n, nok := strconv.parse_int(v); nok && n > 0 && n < 1000 {app.best = n}
	}
	app.players = 1
}

start :: proc(players: int) {
	app.players = players
	game.new_game(&app.g, u64(gfx.now_ms()) ~ u64(gfx.random() * 1e9), players)
	app.screen = .Playing
	app.flash = {}
	app.typed = 0
	app.new_best = false
	app.msg = ""
	gfx.tone(330, 70, .Triangle, 0.06)
	gfx.tone(494, 90, .Triangle, 0.06, 80)
}

@(export)
step :: proc(dt: f64) -> bool {
	d := f32(min(dt, 0.1))
	app.t += d
	app.msg_t = max(0, app.msg_t - d)
	for &f in app.flash {f = max(0, f - d)}
	draw()
	free_all(context.temp_allocator)
	return true
}

try :: proc(sq: int) {
	g := &app.g
	before := g.placed
	if !game.try_square(g, sq) {return}
	ev := g.events
	g.events = {}
	if .Fit in ev {
		for i in 0 ..< game.SQUARES {if g.placed[i] && !before[i] {app.flash[i] = 0.6}}
		app.msg = "YOU GOT IT!"
		app.msg_t = 1.4
		gfx.tone(523, 70, .Square, 0.05)
		gfx.tone(659, 70, .Square, 0.05, 70)
		gfx.tone(784, 120, .Square, 0.05, 140)
	} else if .Miss in ev {
		app.msg = "SORRY --|IT DOESN'T FIT THERE."
		app.msg_t = 1.4
		gfx.tone(196, 140, .Saw, 0.04)
	}
	if .Done in ev {
		app.screen = .Over
		app.t = 0
		if g.players == 1 && (app.best == 0 || g.tries < app.best) {
			app.best = g.tries
			app.new_best = true
			gfx.store_set("best", fmt.tprintf("%d", g.tries))
		}
		notes := [?]f32{523, 659, 784, 1047}
		for f, i in notes {gfx.tone(f, 140, .Triangle, 0.06, 250 + f32(i) * 120)}
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
		if c == '1' || c == gfx.KEY_ENTER || c == gfx.KEY_SPACE {start(1)}
		if c == '2' {start(2)}
	case .Playing:
		switch {
		case c >= '0' && c <= '9':
			v := app.typed * 10 + (c - '0')
			if v > 16 {v = c - '0'}
			app.typed = v
			if app.typed >= 2 {try(app.typed - 1); app.typed = 0} // only a 1 may be the start of 10-16
		case c == gfx.KEY_ENTER:
			if app.typed >= 1 && app.typed <= 16 {try(app.typed - 1)}
			app.typed = 0
		case c == gfx.KEY_BACKSPACE:
			app.typed /= 10
		case c == gfx.KEY_ESCAPE:
			app.screen = .Title
		}
	case .Over:
		if app.t > 0.8 {
			if c == gfx.KEY_ENTER || c == gfx.KEY_SPACE {start(app.players)}
			if c == gfx.KEY_ESCAPE {app.screen = .Title}
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
		if id == ID_ONE {start(1)}
		if id == ID_TWO {start(2)}
	case .Playing:
		if id >= 0 && id < game.SQUARES {app.typed = 0; try(id)}
		if id == ID_MENU {app.screen = .Title}
	case .Over:
		if app.t > 0.8 {
			if id == ID_AGAIN {start(app.players)}
			if id == ID_MENU {app.screen = .Title}
		}
	}
}

// ---- drawing ----

draw :: proc() {
	gfx.begin_buttons()
	gfx.clear(BG)
	switch app.screen {
	case .Title:
		draw_title()
	case .Playing, .Over:
		draw_board()
		draw_side()
	}
}

draw_shape :: proc(s, x, y, cell: int, col: u32) {
	for c in game.SHAPE_CELLS[s] {
		gfx.rect(x + c.x * cell, y + c.y * cell, cell - 1, cell - 1, col)
	}
}

draw_title :: proc() {
	gfx.text_c(W / 2, 22, "JIG SAW", GOLD, 3)
	gfx.text_c(W / 2, 54, "SIX PIECES HIDE ON A 4 BY 4 BOARD.", TEXT)
	gfx.text_c(W / 2, 66, "I NAME A PIECE: YOU NAME A SQUARE", TEXT)
	gfx.text_c(W / 2, 78, "IT COVERS. PIECES MAY BE TURNED", TEXT)
	gfx.text_c(W / 2, 90, "OR FLIPPED ANY WAY.", TEXT)
	// the key, as in the listing
	x := 52
	for s in 1 ..= game.SHAPES {
		gfx.text(x, 110, fmt.tprintf("%d", s), DIM)
		draw_shape(s, x + 10, 110, 8, SHAPE_COL[s])
		x += 48
	}
	gfx.button(96, 148, "1 PLAYER", ID_ONE, TEXT, PANEL, 1)
	gfx.button(208, 148, "2 PLAYERS", ID_TWO, TEXT, PANEL, 1)
	if app.best > 0 {gfx.text_c(W / 2, 178, fmt.tprintf("FEWEST TRIES: %d", app.best), GOLD)}
	gfx.text_c(W / 2, 200, "AFTER \"JIG SAW\" BY DAVID BOHLKE", DIM)
	gfx.text_c(W / 2, 212, "(SOFTSIDE, MARCH 1979)", DIM)
}

draw_board :: proc() {
	g := &app.g
	gfx.rect(BX - 4, BY - 4, CS * 4 + 8, CS * 4 + 8, GRID)
	for i in 0 ..< game.SQUARES {
		x := BX + (i % 4) * CS
		y := BY + (i / 4) * CS
		if g.placed[i] {
			s := int(g.shape[i])
			col := SHAPE_COL[s]
			if app.flash[i] > 0 && int(app.flash[i] * 10) % 2 == 0 {col = 0xffffff}
			gfx.rect(x, y, CS, CS, col)
			// join a piece's squares: draw borders only where the neighbour differs
			edge := u32(0x10151d)
			if i % 4 == 0 || g.shape[i - 1] != g.shape[i] || !g.placed[i - 1] {gfx.rect(x, y, 2, CS, edge)}
			if i % 4 == 3 || g.shape[i + 1] != g.shape[i] || !g.placed[i + 1] {gfx.rect(x + CS - 2, y, 2, CS, edge)}
			if i < 4 || g.shape[i - 4] != g.shape[i] || !g.placed[i - 4] {gfx.rect(x, y, CS, 2, edge)}
			if i >= 12 || g.shape[i + 4] != g.shape[i] || !g.placed[i + 4] {gfx.rect(x, y + CS - 2, CS, 2, edge)}
			if s == 1 {gfx.rect(x, y, CS, 2, edge); gfx.rect(x, y + CS - 2, CS, 2, edge); gfx.rect(x, y, 2, CS, edge); gfx.rect(x + CS - 2, y, 2, CS, edge)}
		} else {
			gfx.rect(x + 1, y + 1, CS - 2, CS - 2, PANEL)
			col := u32(TEXT)
			if g.tried[i] {
				col = MARK
				gfx.text_c(x + CS / 2, y + CS / 2 - 4, "X", MARK, 2)
			} else {
				gfx.text_c(x + CS / 2, y + CS / 2 - 4, fmt.tprintf("%d", i + 1), col, 1)
			}
			if app.screen == .Playing {gfx.zone(x, y, CS, CS, i)}
		}
	}
	if app.screen == .Over {
		for k in 0 ..< 10 {
			px := BX + int((app.t * 53 + f32(k) * 37)) % (CS * 4)
			py := BY + int((app.t * 31 + f32(k) * 71)) % (CS * 4)
			gfx.rect(px, py, 2, 2, 0xffffff)
		}
	}
}

draw_side :: proc() {
	g := &app.g
	sx := 200
	gfx.text(sx, 12, "JIG SAW", GOLD, 2)
	if g.players == 2 {
		for p in 0 ..< 2 {
			col := p == g.turn && app.screen == .Playing ? u32(GOLD) : u32(DIM)
			gfx.text(sx + p * 92, 36, fmt.tprintf("P%d %2d SQ", p + 1, g.score[p]), col)
		}
	} else {
		gfx.text(sx, 36, fmt.tprintf("TRIES %d", g.tries), TEXT)
		if app.best > 0 {gfx.text(sx + 96, 36, fmt.tprintf("BEST %d", app.best), DIM)}
	}
	if app.screen == .Playing {
		who := g.players == 2 ? fmt.tprintf("PLAYER %d:", g.turn + 1) : "WHERE WOULD YOU"
		gfx.text(sx, 56, who, TEXT)
		gfx.text(sx, 68, fmt.tprintf("PLACE PIECE #%d?", g.named), TEXT)
		gfx.rect(sx, 82, 72, 72, PANEL)
		cells := game.SHAPE_CELLS[g.named]
		mw, mh := 0, 0
		for c in cells {mw = max(mw, c.x + 1); mh = max(mh, c.y + 1)}
		cell := 18
		draw_shape(g.named, sx + 36 - mw * cell / 2, 82 + 36 - mh * cell / 2, cell, SHAPE_COL[g.named])
		gfx.text(sx + 82, 86, "TAP A", DIM)
		gfx.text(sx + 82, 98, "SQUARE OR", DIM)
		gfx.text(sx + 82, 110, "TYPE 1-16", DIM)
		if app.typed > 0 {gfx.text(sx + 82, 128, fmt.tprintf("%d_", app.typed), GOLD, 2)}
		if app.msg_t > 0 {
			col := app.msg[0] == 'Y' ? u32(GOLD) : u32(RED)
			y := 160
			rest := app.msg
			for len(rest) > 0 {
				line := rest
				for ch, i in rest {if ch == '|' {line = rest[:i]; break}}
				gfx.text(sx, y, line, col)
				rest = len(line) < len(rest) ? rest[len(line) + 1:] : ""
				y += 11
			}
		}
		// the key
		x := sx
		for s in 1 ..= game.SHAPES {
			gfx.text(x, 188, fmt.tprintf("%d", s), DIM)
			draw_shape(s, x + 9, 188, 5, SHAPE_COL[s])
			x += 30
		}
		gfx.button(sx, 214, "MENU", ID_MENU, DIM, PANEL)
	} else {
		if g.players == 2 {
			w := g.score[0] == g.score[1] ? "A TIE!" : fmt.tprintf("PLAYER %d WINS!", g.score[0] > g.score[1] ? 1 : 2)
			gfx.text(sx, 64, w, GOLD, 1)
			gfx.text(sx, 80, fmt.tprintf("IN %d TRIES IN ALL", g.tries), TEXT)
		} else {
			r := game.rating(g.tries)
			gfx.text(sx, 60, fmt.tprintf("DONE IN %d TRIES", g.tries), TEXT)
			gfx.text(sx, 76, r.title, GOLD, 2)
			gfx.text(sx, 100, r.line, TEXT)
			gfx.text(sx, 116, fmt.tprintf("%d PIECES: %d IS PERFECT", game.pieces(g), game.pieces(g)), DIM)
			if app.new_best {gfx.text(sx, 132, "YOUR FEWEST YET!", GOLD)}
		}
		if app.t > 0.8 {
			gfx.button(sx, 160, "ANOTHER PUZZLE", ID_AGAIN, TEXT, PANEL)
			gfx.button(sx, 186, "MENU", ID_MENU, DIM, PANEL)
		}
	}
}
