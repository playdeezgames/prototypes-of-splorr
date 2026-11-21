#+build js
package main

// Shopping List's page: the aisles, the list on a notepad, and typing in an item of yer own.
// Rules are in ../game.

import "base:runtime"
import "core:fmt"
import sl "../game"
import "proto:gfx"

W :: 512
H :: 320

DESK :: 0x3a2a1e
DESK_DARK :: 0x2a1e15
PAD :: 0xf6e7a1
PAD_DARK :: 0xe8d68a
RULE :: 0x9ab8d8
MARGIN :: 0xd46a6a
INK :: 0x24263a
INK_SOFT :: 0x5a5a6a
PENCIL :: 0x8a8070
SIGN :: 0x2f5a3a
SIGN_LIT :: 0x4a8a5a
SIGN_TEXT :: 0xf0f0e0
TAG :: 0xd4492a
DIM :: 0xc8b89a
WHITE :: 0xffffff

View :: enum {
	Aisles,
	List,
}

App :: struct {
	l:         sl.List,
	view:      View,
	aisle:     int,
	number:    [3]u8, // a number being typed, the listing's way
	number_n:  int,
	typing:    bool, // an item of yer own
	text:      [sl.NAME_MAX]u8,
	text_n:    int,
	page:      int,
	sure:      f32, // "clear all" asked once; press again while this runs
	note:      [64]u8,
	note_n:    int,
	note_t:    f32,
	t:         f32,
}

app: App

ID_TAB_AISLES :: 1
ID_TAB_LIST :: 2
ID_OWN :: 3
ID_CLEAR_TICKED :: 4
ID_CLEAR_ALL :: 5
ID_PREV :: 6
ID_NEXT :: 7
ID_TYPE_OK :: 8
ID_TYPE_CANCEL :: 9
ID_LETTER :: 10 // + a key of the on-screen keyboard (KEYS)
ID_AISLE :: 100 // + aisle
ID_ADD :: 1000 // + item id
ID_MINUS :: 2000 // + item id
ID_TICK :: 3000 // + item id

main :: proc() {
	sl.init()
	buf: [8192]u8
	if v, ok := gfx.store_get("list", buf[:]); ok {sl.load(&app.l, v)}
	app.note_t = 10
}

save :: proc() {
	gfx.store_set("list", sl.save(&app.l))
}

say :: proc(s: string) {
	app.note_n = copy(app.note[:], s)
	app.note_t = 0
}

@(export)
step :: proc(dt: f64) -> bool {
	d := f32(min(dt, 0.1))
	app.t += d
	app.note_t += d
	app.sure = max(0, app.sure - d)
	draw()
	free_all(context.temp_allocator)
	return true
}

pick :: proc(id: int) {
	if sl.add(&app.l, id) {
		gfx.tone(880, 25, .Triangle, 0.05)
		say(fmt.tprintf("%s: %d ON THE LIST", sl.item_name(&app.l, id), app.l.qty[id]))
		save()
	} else {
		gfx.tone(160, 60, .Square, 0.04)
	}
}

unpick :: proc(id: int) {
	sl.remove(&app.l, id)
	gfx.tone(520, 25, .Triangle, 0.05)
	save()
}

enter_number :: proc() {
	if app.number_n == 0 {return}
	n := 0
	for i in 0 ..< app.number_n {n = n * 10 + int(app.number[i] - '0')}
	app.number_n = 0
	id, ok := sl.add_number(&app.l, n)
	if ok {
		app.aisle = sl.item_aisle(id)
		pick_sound_and_note(id)
		save()
	} else {
		gfx.tone(160, 80, .Square, 0.04)
		say(fmt.tprintf("NO ITEM %d", n))
	}
}

pick_sound_and_note :: proc(id: int) {
	gfx.tone(880, 25, .Triangle, 0.05)
	say(fmt.tprintf("%d %s: %d ON THE LIST", sl.item_number(id), sl.item_name(&app.l, id), app.l.qty[id]))
}

finish_typing :: proc() {
	app.typing = false
	id, ok := sl.add_own(&app.l, string(app.text[:app.text_n]))
	app.text_n = 0
	if ok {
		gfx.tone(660, 40, .Triangle, 0.05)
		gfx.tone(990, 60, .Triangle, 0.05, 45)
		say(fmt.tprintf("%s: ADDED", sl.item_name(&app.l, id)))
		save()
	} else if app.l.own_n == sl.MAX_OWN {
		say("NO ROOM: TICK OFF SOME OF YER OWN FIRST")
	}
}

press :: proc(id: int) {
	switch {
	case id >= ID_TICK:
		sl.tick(&app.l, id - ID_TICK)
		gfx.tone(app.l.ticked[id - ID_TICK] ? 1046 : 600, 30, .Triangle, 0.05)
		save()
	case id >= ID_MINUS:
		unpick(id - ID_MINUS)
	case id >= ID_ADD:
		pick(id - ID_ADD)
	case id >= ID_AISLE:
		app.aisle = id - ID_AISLE
		gfx.tone(440, 20, .Triangle, 0.04)
	case id == ID_TAB_AISLES:
		app.view = .Aisles
	case id == ID_TAB_LIST:
		app.view = .List
		app.page = 0
	case id == ID_OWN:
		app.typing = true
		app.text_n = 0
	case id == ID_CLEAR_TICKED:
		_, ticked := sl.count(&app.l)
		sl.clear_ticked(&app.l)
		save()
		say(ticked > 0 ? "TICKED ITEMS TAKEN OFF THE LIST" : "NOTHING TICKED YET")
	case id == ID_CLEAR_ALL:
		if app.sure > 0 {
			sl.clear_all(&app.l)
			save()
			app.sure = 0
			say("A CLEAN SHEET")
			gfx.noise(200, 0.06)
		} else {
			app.sure = 3
			say("PRESS CLEAR ALL AGAIN TO START OVER")
		}
	case id == ID_PREV:
		app.page = max(0, app.page - 1)
	case id == ID_NEXT:
		app.page += 1
	case id == ID_TYPE_OK:
		finish_typing()
	case id >= ID_LETTER && id < ID_LETTER + len(KEYS):
		type_char(KEYS[id - ID_LETTER])
	case id == ID_TYPE_CANCEL:
		app.typing = false
	}
}

// The on-screen keyboard ('<' rubs out).
KEYS := "QWERTYUIOPASDFGHJKL'ZXCVBNM-.<1234567890& "

type_char :: proc(ch: u8) {
	if ch == '<' {
		if app.text_n > 0 {app.text_n -= 1}
		return
	}
	if !sl.valid_name_char(ch) || app.text_n >= sl.NAME_MAX {return}
	if ch == ' ' && (app.text_n == 0 || app.text[app.text_n - 1] == ' ') {return}
	app.text[app.text_n] = ch
	app.text_n += 1
	gfx.tone(1200, 12, .Square, 0.02)
}

// ---- input ----

@(export)
on_key :: proc "c" (code: i32, down: i32) {
	context = runtime.default_context()
	if down == 0 {return}
	c := int(code)
	if app.typing {
		switch c {
		case gfx.KEY_ENTER:
			finish_typing()
		case gfx.KEY_ESCAPE:
			app.typing = false
		case gfx.KEY_BACKSPACE, gfx.KEY_DELETE:
			type_char('<')
		case:
			if c < 128 {type_char(u8(c))}
		}
		return
	}
	if down != 1 && c != gfx.KEY_UP && c != gfx.KEY_DOWN {return}
	switch c {
	case gfx.KEY_TAB, gfx.KEY_SPACE:
		press(app.view == .Aisles ? ID_TAB_LIST : ID_TAB_AISLES)
	case '+', '=':
		press(ID_OWN)
	case gfx.KEY_ESCAPE:
		app.number_n = 0
		if app.view == .List {app.view = .Aisles}
	}
	switch app.view {
	case .Aisles:
		switch c {
		case gfx.KEY_UP:
			app.aisle = (app.aisle + len(sl.AISLES) - 1) % len(sl.AISLES)
		case gfx.KEY_DOWN:
			app.aisle = (app.aisle + 1) % len(sl.AISLES)
		case '0' ..= '9':
			if app.number_n < len(app.number) {
				app.number[app.number_n] = u8(c)
				app.number_n += 1
			}
		case gfx.KEY_BACKSPACE:
			if app.number_n > 0 {app.number_n -= 1}
		case gfx.KEY_ENTER:
			enter_number()
		}
	case .List:
		switch c {
		case gfx.KEY_LEFT, gfx.KEY_UP:
			press(ID_PREV)
		case gfx.KEY_RIGHT, gfx.KEY_DOWN:
			press(ID_NEXT)
		}
	}
}

@(export)
on_pointer :: proc "c" (x, y: f32, kind: i32) {
	context = runtime.default_context()
	if kind != 0 {return}
	id := gfx.hit(x, y)
	if id > 0 {press(id)}
}

// ---- drawing ----

draw :: proc() {
	gfx.clear(DESK)
	gfx.begin_buttons()
	draw_top()
	switch app.view {
	case .Aisles:
		draw_aisles()
	case .List:
		draw_list()
	}
	draw_bottom()
	if app.typing {draw_typing()}
}

draw_top :: proc() {
	gfx.rect(0, 0, W, 22, DESK_DARK)
	gfx.text(8, 7, "SHOPPING LIST", PAD)
	items, ticked := sl.count(&app.l)
	tab :: proc(x: int, label: string, id: int, on: bool) -> int {
		w := gfx.text_width(label) + 12
		gfx.rect(x, 3, w, 17, on ? PAD : DESK)
		gfx.text(x + 6, 8, label, on ? INK : DIM)
		gfx.zone(x, 3, w, 19, id)
		return w
	}
	list_label := items > 0 ? fmt.tprintf("MY LIST %d", items) : "MY LIST"
	if ticked > 0 {list_label = fmt.tprintf("MY LIST %d/%d", ticked, items)}
	lw := gfx.text_width(list_label) + 12
	x := W - 8 - lw
	tab(x, list_label, ID_TAB_LIST, app.view == .List)
	aw := gfx.text_width("AISLES") + 12
	tab(x - 4 - aw, "AISLES", ID_TAB_AISLES, app.view == .Aisles)
}

AX :: 8
AY :: 28
AH :: 16
IX :: 140
IY :: 28
COLW :: 182
ROWH :: 28

draw_aisles :: proc() {
	l := &app.l
	ids: [64]int
	for name, a in sl.AISLES {
		y := AY + a * AH
		on := a == app.aisle
		n := sl.aisle_items(l, a, ids[:])
		picked := 0
		for i in 0 ..< n {if l.qty[ids[i]] > 0 {picked += 1}}
		gfx.rect(AX, y, IX - AX - 8, AH - 2, on ? SIGN_LIT : SIGN)
		gfx.text(AX + 4, y + 3, fmt.tprintf("%2d %s", a + 1, name), on ? WHITE : SIGN_TEXT)
		if picked > 0 {
			gfx.rect(IX - 24, y + 2, 12, AH - 6, TAG)
			gfx.text(IX - 22, y + 3, picked > 9 ? "+" : fmt.tprintf("%d", picked), WHITE)
		}
		gfx.zone(AX, y, IX - AX - 8, AH, ID_AISLE + a)
	}
	// The shelf.
	sx, sy, sw, sh := IX, IY, W - IX - 8, 9 * ROWH + 6
	gfx.rect(sx, sy, sw, sh, 0x4a3828)
	n := sl.aisle_items(l, app.aisle, ids[:])
	for i in 0 ..< n {
		id := ids[i]
		x := sx + 4 + (i / 9) * COLW
		y := sy + 4 + (i % 9) * ROWH
		q := l.qty[id]
		bw := COLW - 6
		gfx.rect(x, y, bw, ROWH - 4, q > 0 ? PAD : PAD_DARK)
		label := sl.item_name(l, id)
		if id < sl.MAX_STOCK {
			gfx.text(x + 4, y + 4, fmt.tprintf("%3d", sl.item_number(id)), PENCIL)
		}
		gfx.text(x + 32, y + 4, label, INK)
		gfx.zone(x, y, bw - 26, ROWH - 4, ID_ADD + id)
		if q > 0 {
			gfx.text(x + 32, y + 14, fmt.tprintf("X%d", q), TAG)
			gfx.rect(x + bw - 22, y + 3, 18, ROWH - 10, TAG)
			gfx.text(x + bw - 17, y + 8, "-", WHITE)
			gfx.zone(x + bw - 24, y, 24, ROWH - 4, ID_MINUS + id)
		} else {
			gfx.text(x + bw - 16, y + 8, "+", PENCIL)
		}
	}
	if app.aisle == sl.OWN_AISLE {
		i := n
		x := sx + 4 + (i / 9) * COLW
		y := sy + 4 + (i % 9) * ROWH
		if i < 18 {
			gfx.rect(x, y, COLW - 6, ROWH - 4, SIGN_LIT)
			gfx.text(x + 8, y + 8, "+ ADD AN ITEM", WHITE)
			gfx.zone(x, y, COLW - 6, ROWH - 4, ID_OWN)
		}
		if n == 0 {
			gfx.text(sx + 8, sy + ROWH + 12, "ANYTHING THE AISLES DON'T HAVE.", PAD)
			gfx.text(sx + 8, sy + ROWH + 24, "(THE CHEESE FOR THE SOUFFLE?)", DIM)
		}
	}
}

Line :: struct {
	header: int, // an aisle, or -1 for an item
	id:     int,
}

LINES_PER_COL :: 20
LINE_H :: 12

draw_list :: proc() {
	l := &app.l
	// The pad.
	px, py, pw, ph := 8, 28, W - 16, LINES_PER_COL * LINE_H + 14
	gfx.rect(px + 3, py + 3, pw, ph, DESK_DARK)
	gfx.rect(px, py, pw, ph, PAD)
	for i in 0 ..< LINES_PER_COL {gfx.rect(px, py + 12 + i * LINE_H + LINE_H - 1, pw, 1, RULE)}
	gfx.rect(px + 22, py, 1, ph, MARGIN)
	gfx.rect(px + pw / 2 + 14, py, 1, ph, MARGIN)

	lines: [sl.MAX_ITEMS + 32]Line
	nl := 0
	ids: [64]int
	for a in 0 ..< len(sl.AISLES) {
		n := sl.aisle_items(l, a, ids[:])
		first := true
		for i in 0 ..< n {
			if l.qty[ids[i]] == 0 {continue}
			if first {
				// Keep a header off the bottom of a column.
				if (nl + 1) % LINES_PER_COL == 0 {
					lines[nl] = {-2, 0}
					nl += 1
				}
				lines[nl] = {a, 0}
				nl += 1
				first = false
			}
			lines[nl] = {-1, ids[i]}
			nl += 1
		}
	}
	if nl == 0 {
		gfx.text(px + 32, py + 16, "NOTHING ON THE LIST YET.", INK)
		gfx.text(px + 32, py + 16 + LINE_H * 2, "PICK THINGS IN THE AISLES (TAB),", INK_SOFT)
		gfx.text(px + 32, py + 16 + LINE_H * 3, "THEN TICK THEM OFF HERE IN THE STORE.", INK_SOFT)
		gfx.text(px + 32, py + 16 + LINE_H * 5, "AND DON'T FORGET THE CHEESE.", MARGIN)
		return
	}
	per_page := LINES_PER_COL * 2
	pages := (nl + per_page - 1) / per_page
	app.page = min(app.page, pages - 1)
	for k in 0 ..< per_page {
		i := app.page * per_page + k
		if i >= nl {break}
		ln := lines[i]
		col := k / LINES_PER_COL
		x := px + 28 + col * (pw / 2 + 14 - 6)
		y := py + 14 + (k % LINES_PER_COL) * LINE_H
		switch ln.header {
		case -2:
		case -1:
			id := ln.id
			done := l.ticked[id]
			gfx.frame(x, y, 9, 9, INK_SOFT)
			if done {
				gfx.rect(x + 2, y + 2, 5, 5, TAG)
			}
			s := fmt.tprintf("%d %s", l.qty[id], sl.item_name(l, id))
			gfx.text(x + 14, y + 1, s, done ? PENCIL : INK)
			if done {gfx.rect(x + 14, y + 4, gfx.text_width(s), 1, TAG)}
			gfx.zone(x - 4, y - 1, pw / 2 - 30, LINE_H, ID_TICK + id)
		case:
			gfx.text(x - 4, y + 1, sl.AISLES[ln.header], MARGIN)
		}
	}
	if pages > 1 {
		gfx.text(px + pw - 80, py + ph - 10, fmt.tprintf("PAGE %d/%d", app.page + 1, pages), INK_SOFT)
	}
}

draw_bottom :: proc() {
	y := H - 22
	gfx.rect(0, y, W, 22, DESK_DARK)
	if app.note_t < 3 && app.note_n > 0 {
		gfx.text(8, y + 8, string(app.note[:app.note_n]), PAD)
		return
	}
	switch app.view {
	case .Aisles:
		if app.number_n > 0 {
			gfx.text(8, y + 8, fmt.tprintf("ITEM NUMBER %s_  (ENTER ADDS IT)", string(app.number[:app.number_n])), PAD)
		} else {
			gfx.text(8, y + 8, "TAP TO ADD, OR TYPE A NUMBER. TAB: MY LIST", DIM)
		}
	case .List:
		x := 8
		x += gfx.button(x, y + 3, "CLEAR TICKED", ID_CLEAR_TICKED, PAD, DESK) + 6
		x += gfx.button(x, y + 3, app.sure > 0 ? "SURE? CLEAR ALL" : "CLEAR ALL", ID_CLEAR_ALL, app.sure > 0 ? TAG : PAD, DESK) + 6
		x += gfx.button(x, y + 3, "+ OWN ITEM", ID_OWN, PAD, DESK) + 6
		gfx.button(W - 8 - 2 * 28 - 4, y + 3, "<", ID_PREV, PAD, DESK)
		gfx.button(W - 8 - 28, y + 3, ">", ID_NEXT, PAD, DESK)
	}
}

draw_typing :: proc() {
	bx, by, bw, bh := 72, 34, W - 144, 252
	gfx.rect(bx + 3, by + 3, bw, bh, DESK_DARK)
	gfx.rect(bx, by, bw, bh, PAD)
	gfx.frame(bx, by, bw, bh, INK)
	gfx.text_c(W / 2, by + 10, "WHAT ELSE DO YOU NEED?", INK)
	fx := W / 2 - sl.NAME_MAX * 8 - 6
	gfx.rect(fx, by + 28, sl.NAME_MAX * 16 + 12, 24, WHITE)
	gfx.frame(fx, by + 28, sl.NAME_MAX * 16 + 12, 24, INK_SOFT)
	gfx.text(fx + 6, by + 32, string(app.text[:app.text_n]), INK, 2)
	if app.text_n < sl.NAME_MAX && int(app.t * 2) % 2 == 0 {
		gfx.rect(fx + 6 + app.text_n * 16, by + 48, 14, 2, INK)
	}
	// Four rows of ten keys, then the space bar.
	KW :: 30
	KH :: 26
	kx := W / 2 - (10 * KW + 9 * 2) / 2
	for i in 0 ..< len(KEYS) - 1 {
		x := kx + (i % 10) * (KW + 2)
		y := by + 62 + (i / 10) * (KH + 2)
		gfx.rect(x, y, KW, KH, PAD_DARK)
		gfx.frame(x, y, KW, KH, INK_SOFT)
		k := KEYS[i:i + 1]
		gfx.text_c(x + KW / 2, y + 9, k == "<" ? "DEL" : k, INK)
		gfx.zone(x, y, KW, KH, ID_LETTER + i)
	}
	sy := by + 62 + 4 * (KH + 2)
	gfx.rect(kx + 3 * (KW + 2), sy, 4 * (KW + 2) - 2, KH, PAD_DARK)
	gfx.frame(kx + 3 * (KW + 2), sy, 4 * (KW + 2) - 2, KH, INK_SOFT)
	gfx.text_c(kx + 5 * (KW + 2) - 1, sy + 9, "SPACE", INK_SOFT)
	gfx.zone(kx + 3 * (KW + 2), sy, 4 * (KW + 2) - 2, KH, ID_LETTER + len(KEYS) - 1)
	gfx.button(W / 2 - 84, by + bh - 26, "ADD IT", ID_TYPE_OK, WHITE, SIGN)
	gfx.button(W / 2 + 14, by + bh - 26, "CANCEL", ID_TYPE_CANCEL, INK, PAD_DARK)
}
