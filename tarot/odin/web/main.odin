#+build js
package main

// Tarot's page: drawing, keys and taps. Rules are in ../game.

import "base:runtime"
import "core:fmt"
import game "../game"
import "proto:gfx"

W :: 384
H :: 240

BG :: 0x1e1430
PANEL :: 0x2c2044
TEXT :: 0xf0e6d0
DIM :: 0x9a8cb6
GOLD :: 0xf2c75c
FACE :: 0xf3e9cf
INK :: 0x2a1d3d
BACK :: 0x5b3b8c
BACK_LIT :: 0x8a68c4
RED :: 0xc8463c
MAJOR_EDGE :: 0xb8892c
COURT_EDGE :: 0x3d6fb0
MINOR_EDGE :: 0x5f8f4a

CW :: 64
CH :: 96
CY :: 34

Screen :: enum {
	Ask,
	Reading,
}

App :: struct {
	screen:   Screen,
	r:        game.Reading,
	question: [44]u8,
	qlen:     int,
	selected: int, // slot shown in the panel, -1 for the answer
	t:        f32,
	flip:     [game.SPREAD]f32, // turning animation
	count:    int, // readings this visit
}

app: App

ID_DEAL :: 1
ID_NEW :: 2
ID_ANSWER :: 3
ID_CARD :: 10

SCEPTER := [?]string{"...#...", "..###..", "...#...", "...#...", "...#...", "...#...", "..###.."}
CUP := [?]string{"#######", "#.....#", ".#...#.", "..###..", "...#...", "...#...", "..###.."}
COIN := [?]string{"..###..", ".#...#.", "#..#..#", "#.###.#", "#..#..#", ".#...#.", "..###.."}
SWORD := [?]string{"...#...", "...#...", "...#...", "...#...", "#######", "...#...", "..###.."}
STAR := [?]string{"...#...", "#..#..#", ".#.#.#.", "..###..", ".#.#.#.", "#..#..#", "...#..."}

pip_rows :: proc(s: game.Suit) -> []string {
	switch s {
	case .Scepters:
		return SCEPTER[:]
	case .Cups:
		return CUP[:]
	case .Coins:
		return COIN[:]
	case .Swords:
		return SWORD[:]
	}
	return STAR[:]
}

suit_col :: proc(s: game.Suit) -> u32 {
	switch s {
	case .Scepters:
		return 0x8a5a2b
	case .Cups:
		return 0x2f63a8
	case .Coins:
		return 0xb8892c
	case .Swords:
		return 0x5a5a6e
	}
	return INK
}

main :: proc() {
	app.selected = -1
}

question :: proc() -> string {
	return string(app.question[:app.qlen])
}

begin :: proc() {
	game.new_reading(&app.r, u64(gfx.now_ms()) ~ u64(gfx.random() * 1e9))
	app.screen = .Reading
	app.selected = -1
	app.flip = {}
	app.count += 1
	// a shuffle
	for i in 0 ..< 8 {gfx.noise(30, 0.05, f32(i) * 45)}
}

deal :: proc() {
	s := game.deal(&app.r)
	if s < 0 {return}
	app.flip[s] = 0.25
	app.selected = s
	gfx.noise(40, 0.06)
	gfx.tone(app.r.upright[s] ? 660 : 330, 120, .Sine, 0.05, 30)
	if app.r.answer != .Pending {
		app.selected = -1
		notes := app.r.answer == .Yes ? [3]f32{523, 659, 784} : (app.r.answer == .No ? [3]f32{392, 311, 262} : [3]f32{440, 466, 440})
		for f, i in notes {gfx.tone(f, 260, .Sine, 0.06, 400 + f32(i) * 220)}
	}
}

@(export)
step :: proc(dt: f64) -> bool {
	d := f32(min(dt, 0.1))
	app.t += d
	for &f in app.flip {f = max(0, f - d)}
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
	switch app.screen {
	case .Ask:
		switch {
		case c == gfx.KEY_ENTER:
			begin()
		case c == gfx.KEY_BACKSPACE:
			if app.qlen > 0 {app.qlen -= 1}
		case c == gfx.KEY_ESCAPE:
			app.qlen = 0
		case (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == ' ' || c == '?' || c == '\'' || c == ',' || c == '.' || c == '!' || c == '-':
			if app.qlen < len(app.question) && !(c == ' ' && app.qlen == 0) {
				app.question[app.qlen] = u8(c)
				app.qlen += 1
			}
		}
	case .Reading:
		if down != 1 {return}
		switch c {
		case gfx.KEY_ENTER, gfx.KEY_SPACE:
			if app.r.answer == .Pending {deal()} else {new_question()}
		case gfx.KEY_LEFT:
			move_sel(-1)
		case gfx.KEY_RIGHT:
			move_sel(1)
		case gfx.KEY_ESCAPE:
			new_question()
		}
	}
}

new_question :: proc() {
	app.screen = .Ask
	app.qlen = 0
}

move_sel :: proc(d: int) {
	s := app.selected
	for _ in 0 ..< game.SPREAD {
		s = s < 0 ? (d > 0 ? 0 : game.SPREAD - 1) : s + d
		if s < 0 || s >= game.SPREAD {app.selected = -1; return}
		if game.is_dealt(&app.r, s) {app.selected = s; return}
	}
}

@(export)
on_pointer :: proc "c" (x, y: f32, kind: i32) {
	context = runtime.default_context()
	if kind != 0 {return}
	id := gfx.hit(x, y)
	switch app.screen {
	case .Ask:
		if id == ID_DEAL {begin()}
	case .Reading:
		switch {
		case id == ID_DEAL:
			deal()
		case id == ID_NEW:
			new_question()
		case id == ID_ANSWER:
			app.selected = -1
		case id >= ID_CARD && id < ID_CARD + game.SPREAD:
			app.selected = id - ID_CARD
		}
	}
}

// ---- drawing ----

draw :: proc() {
	gfx.begin_buttons()
	gfx.clear(BG)
	switch app.screen {
	case .Ask:
		draw_ask()
	case .Reading:
		draw_reading()
	}
}

draw_ask :: proc() {
	gfx.text_c(W / 2, 20, "TAROT", GOLD, 3)
	gfx.text_c(W / 2, 52, "THE \"YES AND NO\" SPREAD", DIM)
	// a fan of backs
	for i in 0 ..< 7 {
		draw_back(W / 2 - 84 + i * 20, 66 + abs(i - 3) * 3, 40, 60)
	}
	gfx.text_c(W / 2, 140, "ASK A QUESTION THAT CAN BE ANSWERED", TEXT)
	gfx.text_c(W / 2, 151, "BY \"YES\" OR \"NO\". TYPE IT, OR JUST THINK IT.", TEXT)
	gfx.rect(16, 165, W - 32, 16, PANEL)
	q := question()
	cursor := int(app.t * 2) % 2 == 0 ? "_" : " "
	gfx.text(20, 169, fmt.tprintf("%s%s", q, app.qlen < len(app.question) ? cursor : ""), GOLD)
	gfx.button(W / 2 - 68, 188, "SHUFFLE AND DEAL", ID_DEAL, TEXT, PANEL)
	gfx.text_c(W / 2, 214, "AFTER \"TAROT\" BY FRANK B. ROWLETT, JR.", DIM)
	gfx.text_c(W / 2, 225, "(SOFTSIDE, MARCH 1979)  FOR FUN ONLY", DIM)
}

slot_x :: proc(s: int) -> int {return 16 + s * 72}

draw_reading :: proc() {
	r := &app.r
	q := app.qlen > 0 ? fmt.tprintf("\"%s\"", question()) : "YOUR QUESTION, THOUGHT NOT SPOKEN"
	gfx.text_c(W / 2, 6, q, DIM)
	gfx.text_c(slot_x(0) + CW + 4, 22, "FUTURE", TEXT)
	gfx.text_c(slot_x(2) + CW / 2, 22, "PRESENT", GOLD)
	gfx.text_c(slot_x(3) + CW + 4, 22, "PAST", TEXT)
	for s in 0 ..< game.SPREAD {
		x := slot_x(s)
		if game.is_dealt(r, s) {
			f := app.flip[s]
			if f > 0.125 {
				w := int(f32(CW) * (f - 0.125) / 0.125)
				draw_back(x + (CW - w) / 2, CY, max(w, 2), CH)
			} else if f > 0 {
				w := int(f32(CW) * (0.125 - f) / 0.125)
				gfx.rect(x + (CW - w) / 2, CY, max(w, 2), CH, FACE)
			} else {
				draw_face(r.cards[s], r.upright[s], x, CY)
			}
			if s == app.selected {gfx.frame(x - 2, CY - 2, CW + 4, CH + 4, GOLD)}
			gfx.zone(x, CY, CW, CH, ID_CARD + s)
		} else {
			gfx.frame(x, CY, CW, CH, 0x4a3a66)
			gfx.text_c(x + CW / 2, CY + CH / 2 - 4, fmt.tprintf("(%d)", game.SPREAD - s), 0x4a3a66)
			if s == game.next_slot(r) {
				draw_back(x, CY, CW, CH)
				if int(app.t * 2) % 2 == 0 {gfx.frame(x - 2, CY - 2, CW + 4, CH + 4, BACK_LIT)}
				gfx.zone(x, CY, CW, CH, ID_DEAL)
			}
		}
	}
	// the panel
	py := CY + CH + 8
	gfx.rect(8, py, W - 16, H - py - 4, PANEL)
	if app.selected >= 0 {
		s := app.selected
		nb, mb: [64]u8
		id := r.cards[s]
		place := game.SLOT_PLACE[s]
		gfx.text(16, py + 6, fmt.tprintf("%s: %s", place, game.card_name(id, nb[:])), GOLD)
		gfx.text(16, py + 20, game.card_meaning(id, r.upright[s], mb[:]), TEXT)
		say := r.upright[s] ? "RIGHT SIDE UP: YES" : "UPSIDE DOWN: NO"
		if s == game.KEY_SLOT {say = fmt.tprintf("%s (THE KEY CARD COUNTS TWICE)", say)}
		gfx.text(16, py + 34, say, r.upright[s] ? 0x9ad07a : 0xe08a7a)
	} else if r.answer == .Pending {
		gfx.text(16, py + 6, "TAP THE DECK, OR PRESS ENTER, FOR A CARD.", TEXT)
		gfx.text(16, py + 20, "RIGHT SIDE UP SAYS YES, UPSIDE DOWN NO;", DIM)
		gfx.text(16, py + 32, "THE PRESENT IS THE KEY AND COUNTS TWICE.", DIM)
	}
	if r.answer != .Pending {
		ay := py + 50
		word: string
		switch r.answer {
		case .Yes:
			word = "YES"
		case .No:
			word = "NO"
		case .Uncertain, .Pending:
			word = "UNCERTAIN"
		}
		if app.selected < 0 {
			gfx.text(16, py + 6, "THE ANSWER IS", TEXT)
			gfx.text(16, py + 20, word, GOLD, 2)
			gfx.text(16, py + 40, fmt.tprintf("%d YES, %d NO", r.yes, r.no), DIM)
			if r.answer == .Uncertain {gfx.text(130, py + 40, "CONCENTRATE, AND ASK AGAIN", DIM)}
		} else {
			gfx.text(16, ay, fmt.tprintf("THE ANSWER: %s (%d YES, %d NO)", word, r.yes, r.no), DIM)
			gfx.button(W - 16 - 56, ay + 14, "ANSWER", ID_ANSWER, DIM, PANEL)
		}
		gfx.button(16, H - 22, "NEW QUESTION", ID_NEW, TEXT, BG)
		gfx.text(130, H - 18, "TAP A CARD TO READ IT", DIM)
	}
}

draw_back :: proc(x, y, w, h: int) {
	gfx.rect(x, y, w, h, BACK)
	gfx.frame(x, y, w, h, BACK_LIT)
	if w < 12 {return}
	for yy := y + 6; yy < y + h - 6; yy += 8 {
		for xx := x + 6 + ((yy - y) / 8 % 2) * 4; xx < x + w - 6; xx += 8 {
			gfx.rect(xx, yy, 2, 2, BACK_LIT)
		}
	}
}

// Art drawn inside a card, mirrored top to bottom when the card is upside down.
Face :: struct {
	x, y: int,
	up:   bool,
}

put :: proc(f: Face, x, y, w, h: int, col: u32) {
	yy := f.up ? y : CH - y - h
	gfx.rect(f.x + x, f.y + yy, w, h, col)
}

sprite :: proc(f: Face, rows: []string, x, y, px: int, col: u32) {
	for row, j in rows {
		for i in 0 ..< len(row) {
			if row[i] == '#' {put(f, x + i * px, y + j * px, px, px, col)} // put mirrors it upside down
		}
	}
}

draw_face :: proc(id: int, upright: bool, x, y: int) {
	c := game.card(id)
	edge: u32 = c.kind == .Major ? MAJOR_EDGE : (c.kind == .Court ? COURT_EDGE : MINOR_EDGE)
	gfx.rect(x, y, CW, CH, FACE)
	gfx.frame(x, y, CW, CH, edge)
	gfx.frame(x + 2, y + 2, CW - 4, CH - 4, edge)
	f := Face{x, y, upright}
	// the listing's bar: at the foot when right side up, at the head when upside down
	put(f, 6, CH - 9, CW - 12, 4, edge)
	switch c.kind {
	case .Major:
		sprite(f, STAR[:], CW / 2 - 7, 12, 2, edge)
		n := game.ROMAN[c.number]
		size := len(n) <= 3 ? 2 : 1
		gfx.text_c(x + CW / 2, y + 44, n, INK, size)
		put(f, 12, 68, CW - 24, 1, edge)
	case .Court:
		letters := [game.Rank]string{.Youth = "Y", .Queen = "Q", .King = "K", .Horseman = "H"}
		gfx.text_c(x + CW / 2, y + 20, letters[c.rank], INK, 3)
		sprite(f, pip_rows(c.suit), CW / 2 - 7, 58, 2, suit_col(c.suit))
	case .Minor:
		n := c.number
		rows := (n + 1) / 2
		for k in 0 ..< n {
			col_i := k % 2
			row_i := k / 2
			px := n == 1 ? CW / 2 - 7 : (col_i == 0 ? 14 : CW - 28)
			if n % 2 == 1 && k == n - 1 && n > 1 {px = CW / 2 - 7}
			top := 8 + (78 - rows * 15) / 2
			sprite(f, pip_rows(c.suit), px, top + row_i * 15, 2, suit_col(c.suit))
		}
	}
}
