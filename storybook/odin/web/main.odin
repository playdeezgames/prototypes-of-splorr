#+build js
package main

// Storybook's page: questions, the reading screen and its pictures. Story rules are in ../game.

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:strconv"
import game "../game"
import "proto:gfx"

W :: 512
H :: 288

BG :: 0xfaf3e3
INK :: 0x3a2e28
SOFT :: 0x8a7a6a
ACCENT :: 0xd9534f
KEYBG :: 0xefe3c8
KEYLINE :: 0xb8a684

Screen :: enum {
	Title,
	Question,
	Speed,
	Reading,
}

Kind :: enum {
	Text,
	Number,
	Choice,
}

Question :: struct {
	prompt: string,
	kind:   Kind,
}

QUESTIONS := [?]Question {
	{"WHAT IS YOUR FIRST NAME?", .Text},
	{"HOW OLD ARE YOU?", .Number},
	{"WHAT IS YOUR BEST FRIEND'S NAME?", .Text},
	{"WHO ELSE DO YOU LIKE TO PLAY WITH?", .Text},
	{"WHAT IS YOUR FAVOURITE COLOUR?", .Text},
	{"WHAT IS YOUR LUCKY NUMBER? (1 TO 49)", .Number},
	{"WHAT KIND OF PET DO YOU LIKE BEST?", .Text},
	{"WHAT IS YOUR FAVOURITE WILD ANIMAL?", .Text},
	{"WHICH WILD ANIMAL DON'T YOU LIKE?", .Text},
	{"SHOULD THE STORY SAY SHE, HE OR THEY?", .Choice},
}

FALLBACKS := [?]string{"YOU", "6", "PIP", "JO", "BLUE", "7", "DOG", "BEAR", "CROCODILE", ""}

SPEEDS := [4]string{"A FAST READER", "AN AVERAGE READER", "A SLOW READER", "A VERY SLOW READER"}
CPS := [4]f32{45, 28, 16, 10} // letters per second as the text appears
HOLD := [4]f32{4, 7, 11, 16} // seconds a finished page stays before turning by itself

App :: struct {
	screen:   Screen,
	q:        int,
	typed:    [len(QUESTIONS)][16]u8,
	typed_n:  [len(QUESTIONS)]int,
	clean:    [len(QUESTIONS)][16]u8,
	answers:  game.Answers,
	speed:    int,
	story:    game.Story,
	rng:      game.Rng,
	page:     int,
	shown:    f32, // letters revealed
	hold:     f32,
	auto:     bool,
	t:        f32,
}

app: App

ID_KEY :: 100 // + character
ID_SPACE :: 1
ID_DEL :: 2
ID_NEXT :: 3
ID_BACK :: 4
ID_SPEED :: 10 // + 0..3
ID_CHOICE :: 20 // + pronoun
ID_TURN :: 30
ID_AGAIN :: 31
ID_NEW :: 32
ID_AUTO :: 33
ID_START :: 34

main :: proc() {
	app.rng = {u64(gfx.now_ms()) ~ 0x2545F4914F6CDD1D}
	app.auto = true
	app.speed = 1
}

@(export)
step :: proc(dt: f64) -> bool {
	d := f32(min(dt, 0.25))
	app.t += d
	if app.screen == .Reading {
		p := &app.story.pages[app.page]
		if app.shown < f32(p.len) {
			before := int(app.shown)
			app.shown += CPS[app.speed] * d
			// A soft tick now and then as the words appear.
			if int(app.shown) / 6 != before / 6 {gfx.tone(1400, 8, .Sine, 0.015)}
		} else if app.auto && app.page < app.story.count - 1 {
			app.hold += d
			if app.hold >= HOLD[app.speed] {turn()}
		}
	}
	draw()
	free_all(context.temp_allocator)
	return true
}

// ---- story control ----

begin_questions :: proc() {
	app.screen = .Question
	app.q = 0
}

finish_questions :: proc() {
	a := &app.answers
	get :: proc(i: int) -> string {
		return game.clean(app.clean[i][:], string(app.typed[i][:app.typed_n[i]]), FALLBACKS[i])
	}
	a.name = get(0)
	a.friend1 = get(2)
	a.friend2 = get(3)
	a.color = get(4)
	a.pet = get(6)
	a.like = get(7)
	a.dislike = get(8)
	age, ok := strconv.parse_int(get(1))
	a.age = ok ? clamp(age, 1, 120) : 6
	n, nok := strconv.parse_int(get(5))
	a.number = nok ? clamp(n, 1, 49) : 7
	app.screen = .Speed
}

tell :: proc() {
	game.tell(&app.story, &app.answers, &app.rng)
	app.page = 0
	app.shown = 0
	app.hold = 0
	app.screen = .Reading
	notes := [?]f32{523, 587, 659, 784}
	for f, i in notes {gfx.tone(f, 140, .Triangle, 0.05, f32(i) * 150)}
}

turn :: proc() {
	p := &app.story.pages[app.page]
	if app.shown < f32(p.len) {
		app.shown = f32(p.len) // first tap shows the whole page
		return
	}
	if app.page < app.story.count - 1 {
		app.page += 1
		app.shown = 0
		app.hold = 0
		gfx.tone(660, 40, .Triangle, 0.04)
		gfx.tone(880, 60, .Triangle, 0.04, 50)
	}
}

// ---- input ----

@(export)
on_key :: proc "c" (code: i32, down: i32) {
	context = runtime.default_context()
	if down != 1 {return}
	key(int(code))
}

@(export)
on_pointer :: proc "c" (x, y: f32, kind: i32) {
	context = runtime.default_context()
	if kind != 0 {return}
	id := gfx.hit(x, y)
	if id >= 0 {
		press(id)
	} else if app.screen == .Reading {
		turn()
	} else if app.screen == .Title {
		begin_questions()
	}
}

key :: proc(c: int) {
	switch app.screen {
	case .Title:
		begin_questions()
	case .Question:
		question_key(c)
	case .Speed:
		if c >= '1' && c <= '4' {
			app.speed = c - '1'
			tell()
		}
		if c == gfx.KEY_ESCAPE {app.q = len(QUESTIONS) - 1; app.screen = .Question}
	case .Reading:
		last := app.page == app.story.count - 1
		switch {
		case c == gfx.KEY_SPACE || c == gfx.KEY_ENTER || c == gfx.KEY_RIGHT:
			if last && app.shown >= f32(app.story.pages[app.page].len) {tell()} else {turn()}
		case c == gfx.KEY_LEFT:
			if app.page > 0 {
				app.page -= 1
				app.shown = f32(app.story.pages[app.page].len)
				app.hold = 0
			}
		case c == 'A':
			app.auto = !app.auto
		case c == 'N' || c == gfx.KEY_ESCAPE:
			begin_questions()
		case c == 'Y':
			if last {tell()}
		}
	}
}

question_key :: proc(c: int) {
	q := QUESTIONS[app.q]
	i := app.q
	switch {
	case c == gfx.KEY_ENTER:
		next_question()
	case c == gfx.KEY_ESCAPE:
		if app.q > 0 {app.q -= 1} else {app.screen = .Title}
	case q.kind == .Choice:
		switch c {
		case '1', 'S':
			choose(.She)
		case '2', 'H':
			choose(.He)
		case '3', 'T':
			choose(.They)
		}
	case c == gfx.KEY_BACKSPACE || c == gfx.KEY_DELETE:
		if app.typed_n[i] > 0 {app.typed_n[i] -= 1}
	case c >= 32 && c < 127:
		if q.kind == .Number && (c < '0' || c > '9') {return}
		if app.typed_n[i] < 16 {
			app.typed[i][app.typed_n[i]] = u8(c)
			app.typed_n[i] += 1
		}
	}
}

choose :: proc(p: game.Pronoun) {
	app.answers.pronoun = p
	next_question()
}

next_question :: proc() {
	gfx.tone(740, 30, .Triangle, 0.04)
	if app.q < len(QUESTIONS) - 1 {
		app.q += 1
	} else {
		finish_questions()
	}
}

press :: proc(id: int) {
	switch {
	case id >= ID_KEY && id < ID_KEY + 128:
		key(id - ID_KEY)
	case id == ID_SPACE:
		key(' ')
	case id == ID_DEL:
		key(gfx.KEY_BACKSPACE)
	case id == ID_NEXT:
		key(gfx.KEY_ENTER)
	case id == ID_BACK:
		key(gfx.KEY_ESCAPE)
	case id >= ID_SPEED && id < ID_SPEED + 4:
		key('1' + id - ID_SPEED)
	case id >= ID_CHOICE && id < ID_CHOICE + 3:
		choose(game.Pronoun(id - ID_CHOICE))
	case id == ID_TURN:
		turn()
	case id == ID_AGAIN:
		tell()
	case id == ID_NEW:
		begin_questions()
	case id == ID_AUTO:
		app.auto = !app.auto
	case id == ID_START:
		begin_questions()
	}
}

// ---- drawing ----

draw :: proc() {
	gfx.clear(BG)
	gfx.begin_buttons()
	switch app.screen {
	case .Title:
		draw_title()
	case .Question:
		draw_question()
	case .Speed:
		draw_speed()
	case .Reading:
		draw_reading()
	}
}

draw_title :: proc() {
	gfx.text_c(W / 2, 26, "STORYBOOK", ACCENT, 4)
	gfx.text_c(W / 2, 64, "A TOY: STORIES WITH YOU IN THEM", INK)
	scene := game.Scene{setting = .Woods, friends = true, pet = true, like = true}
	draw_picture(96, 80, scene)
	lines := [?]string {
		"ANSWER A FEW QUESTIONS, AND THE STORYTELLER WILL MAKE UP",
		"AN ADVENTURE STARRING YOU AND YOUR FRIENDS. GROWN-UPS,",
		"READ ALONG! TAP OR PRESS SPACE TO TURN THE PAGE.",
	}
	for l, i in lines {gfx.text_c(W / 2, 222 + i * 11, l, SOFT)}
	if int(app.t * 2) % 2 == 0 {gfx.text_c(W / 2, 258, "TAP OR PRESS ANY KEY TO BEGIN", ACCENT)}
	gfx.text_c(W / 2, 276, "AFTER OTTO HANSEN'S STORYBOOK, SOFTSIDE, AUGUST 1979", SOFT)
	gfx.zone(0, 0, W, H, ID_START)
}

draw_question :: proc() {
	q := QUESTIONS[app.q]
	gfx.text(16, 10, fmt.tprintf("QUESTION %d OF %d", app.q + 1, len(QUESTIONS)), SOFT)
	gfx.text_c(W / 2, 40, q.prompt, INK)
	if q.kind == .Choice {
		labels := [3]string{"1 SHE", "2 HE", "3 THEY"}
		ids := [3]game.Pronoun{.She, .He, .They}
		for l, i in labels {
			gfx.button(W / 2 - 132 + i * 92, 80, l, ID_CHOICE + int(ids[i]), INK, KEYBG, 2)
		}
		gfx.text_c(W / 2, 130, "(HOW THE STORY TALKS ABOUT YOU)", SOFT)
	} else {
		s := string(app.typed[app.q][:app.typed_n[app.q]])
		w := 16 * 16 + 16
		gfx.rect(W / 2 - w / 2, 66, w, 30, 0xffffff)
		gfx.frame(W / 2 - w / 2, 66, w, 30, KEYLINE)
		gfx.text(W / 2 - w / 2 + 8, 73, s, INK, 2)
		if int(app.t * 2) % 2 == 0 {gfx.rect(W / 2 - w / 2 + 8 + len(s) * 16, 73, 14, 16, ACCENT)}
		draw_keyboard(q.kind == .Number)
	}
	x := 16
	x += gfx.button(x, H - 22, "ESC BACK", ID_BACK, SOFT, KEYBG) + 6
	if q.kind != .Choice {
		x += gfx.button(x, H - 22, "SPACE", ID_SPACE, INK, KEYBG) + 6
		x += gfx.button(x, H - 22, "DELETE", ID_DEL, INK, KEYBG) + 6
		gfx.button(x, H - 22, "ENTER NEXT", ID_NEXT, ACCENT, KEYBG)
	}
}

draw_keyboard :: proc(digits: bool) {
	chars := digits ? "1234567890" : "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	per_row := 13
	kw := 34
	for i in 0 ..< len(chars) {
		row := i / per_row
		col := i % per_row
		in_row := min(per_row, len(chars) - row * per_row)
		x := W / 2 - in_row * kw / 2 + col * kw
		y := 120 + row * 32
		gfx.rect(x + 1, y, kw - 3, 28, KEYBG)
		gfx.frame(x + 1, y, kw - 3, 28, KEYLINE)
		b := [1]u8{chars[i]}
		gfx.text(x + 9, y + 6, string(b[:]), INK, 2)
		gfx.zone(x, y, kw, 30, ID_KEY + int(chars[i]))
	}
}

draw_speed :: proc() {
	gfx.text_c(W / 2, 30, "WHO IS READING?", INK, 2)
	gfx.text_c(W / 2, 54, "THE WORDS APPEAR AT YOUR PACE.", SOFT)
	for s, i in SPEEDS {
		gfx.button(W / 2 - 110, 80 + i * 34, fmt.tprintf("%d %s", i + 1, s), ID_SPEED + i, i == app.speed ? ACCENT : INK, KEYBG, 1)
	}
	gfx.text_c(W / 2, 230, "PAGES TURN BY THEMSELVES, OR TAP TO TURN THEM.", SOFT)
	gfx.button(16, H - 22, "ESC BACK", ID_BACK, SOFT, KEYBG)
}

draw_reading :: proc() {
	p := &app.story.pages[app.page]
	draw_picture(96, 6, p.scene)
	text := game.page_text(p)
	shown := min(int(app.shown), len(text))
	starts, ends, n := wrap(text, 60)
	for li in 0 ..< n {
		a, b := starts[li], ends[li]
		if a >= shown {break}
		gfx.text(16, 150 + li * 12, text[a:min(b, shown)], INK)
	}
	last := app.page == app.story.count - 1
	gfx.text(16, H - 18, fmt.tprintf("PAGE %d OF %d", app.page + 1, app.story.count), SOFT)
	if last && shown >= len(text) {
		gfx.text_c(W / 2, 196, "WOULD YOU LIKE ANOTHER STORY?", ACCENT)
		gfx.button(W / 2 - 150, 214, "Y ANOTHER STORY", ID_AGAIN, INK, KEYBG)
		gfx.button(W / 2 + 20, 214, "N NEW STORYTELLER", ID_NEW, INK, KEYBG)
	} else {
		x := W - 16
		w := gfx.text_width("SPACE NEXT >") + 8
		gfx.button(x - w, H - 22, "SPACE NEXT >", ID_TURN, ACCENT, KEYBG)
		label := app.auto ? "A AUTO: ON" : "A AUTO: OFF"
		w2 := gfx.text_width(label) + 8
		gfx.button(x - w - 6 - w2, H - 22, label, ID_AUTO, SOFT, KEYBG)
	}
}

wrap :: proc(s: string, cols: int) -> (starts: [16]int, ends: [16]int, n: int) {
	i := 0
	for i < len(s) && n < 16 {
		for i < len(s) && s[i] == ' ' {i += 1}
		if i >= len(s) {break}
		end := min(i + cols, len(s))
		if end < len(s) {
			cut := end
			for cut > i && s[cut] != ' ' {cut -= 1}
			if cut > i {end = cut}
		}
		starts[n], ends[n] = i, end
		n += 1
		i = end
	}
	return
}

// ---- pictures (320 by 136) ----

PW :: 320
PH :: 136

color_of :: proc(name: string) -> (u32, bool) {
	switch name {
	case "RED": return 0xe23b3b, true
	case "BLUE": return 0x3b6fe2, true
	case "GREEN": return 0x3bb54a, true
	case "YELLOW": return 0xf5d21f, true
	case "ORANGE": return 0xf58a1f, true
	case "PURPLE", "VIOLET": return 0x8e44c9, true
	case "PINK": return 0xf279b8, true
	case "BLACK": return 0x202020, true
	case "WHITE": return 0xfafafa, true
	case "BROWN": return 0x8b5a2b, true
	case "GOLD": return 0xe5b80b, true
	case "SILVER", "GREY", "GRAY": return 0xb8b8c0, true
	case "TURQUOISE", "TEAL": return 0x1fb5a8, true
	}
	return 0, false
}

fav :: proc(i: int) -> u32 {
	if c, ok := color_of(app.answers.color); ok {return c}
	rainbow := [6]u32{0xe23b3b, 0xf58a1f, 0xf5d21f, 0x3bb54a, 0x3b6fe2, 0x8e44c9}
	return rainbow[(i + int(app.t * 4)) % 6]
}

draw_picture :: proc(x0, y0: int, s: game.Scene) {
	sky: u32 = s.night ? 0x1d2556 : 0x8fd3f4
	if s.setting == .Cave {sky = 0x3b2a20}
	gfx.rect(x0, y0, PW, PH, sky)
	ground_y := y0 + 96
	if s.night {
		for i in 0 ..< 14 {
			sx := x0 + (i * 53) % PW
			sy := y0 + 6 + (i * 29) % 60
			if (i + int(app.t * 2)) % 5 != 0 {gfx.rect(sx, sy, 2, 2, 0xfff6c0)}
		}
		gfx.rect(x0 + PW - 50, y0 + 12, 16, 16, 0xfff2b0)
		gfx.rect(x0 + PW - 44, y0 + 10, 14, 14, sky)
	} else if s.setting != .Cave {
		gfx.rect(x0 + PW - 46, y0 + 10, 18, 18, 0xffd84a)
	}

	switch s.setting {
	case .Home:
		gfx.rect(x0, ground_y, PW, PH - 96, 0x7cc864)
		hx := x0 + 30
		gfx.rect(hx, y0 + 50, 70, 46, 0xe9d3a8)
		for i in 0 ..< 20 {gfx.rect(hx - 6 + i * 2, y0 + 50 - i, 82 - i * 4, 2, 0xb5533c)}
		gfx.rect(hx + 52, y0 + 22, 8, 22, 0x8b5a2b) // a crooked chimney
		gfx.rect(hx + 56, y0 + 16, 8, 8, 0x8b5a2b)
		gfx.rect(hx + 28, y0 + 70, 14, 26, fav(0))
		gfx.rect(hx + 8, y0 + 60, 12, 10, s.night ? 0xffe27a : 0xbfe6ff)
		gfx.rect(hx + 50, y0 + 60, 12, 10, s.night ? 0xffe27a : 0xbfe6ff)
	case .Road:
		gfx.rect(x0, ground_y, PW, PH - 96, 0x7cc864)
		gfx.rect(x0, ground_y + 12, PW, 16, 0x9a9a9a)
		for i := 0; i < PW; i += 24 {gfx.rect(x0 + i + int(app.t * 20) % 24, ground_y + 19, 10, 2, 0xffffff)}
	case .Trail:
		gfx.rect(x0, ground_y, PW, PH - 96, 0x6dbb55)
		for i := 0; i < PW; i += 6 {
			yy := ground_y + 16 + int(6 * math.sin(f32(i) / 30))
			gfx.rect(x0 + i, yy, 5, 4, 0xc49a5c)
		}
		tree(x0 + 30, ground_y)
		tree(x0 + 270, ground_y)
	case .Plains:
		gfx.rect(x0, ground_y - 10, PW, PH - 86, 0x9ad66a)
		for i := 0; i < PW; i += 4 {
			hh := int(10 * math.sin(f32(i) / 40))
			gfx.rect(x0 + i, ground_y - 14 - hh, 4, 14 + hh, 0x8ccb5c)
		}
	case .Cave:
		gfx.rect(x0, ground_y, PW, PH - 96, 0x5a4434)
		for i in 0 ..< 8 {gfx.rect(x0 + 20 + i * 40, y0, 6, 10 + (i * 7) % 14, 0x6e5644)}
		gfx.rect(x0 + 260, y0 + 40, 30, 56, 0x1a120c)
	case .Desert:
		gfx.rect(x0, ground_y, PW, PH - 96, 0xecd08a)
		cactus(x0 + 40, ground_y)
		cactus(x0 + 250, ground_y)
		cactus(x0 + 290, ground_y + 6)
	case .Beach:
		gfx.rect(x0, ground_y, PW, PH - 96, 0xf2dea0)
		wave := int(app.t * 2) % 2
		gfx.rect(x0, ground_y - 8, PW, 10, 0x3fa7d6)
		for i := 0; i < PW; i += 16 {gfx.rect(x0 + i + wave * 8, ground_y - 8, 8, 2, 0xffffff)}
	case .Woods:
		gfx.rect(x0, ground_y, PW, PH - 96, 0x4f9a43)
		for i in 0 ..< 6 {tree(x0 + 14 + i * 56, ground_y - (i % 2) * 4)}
	}

	// The party walks along, bobbing.
	px := x0 + 110 + int(6 * math.sin(app.t * 0.8))
	bob := int(app.t * 4) % 2
	gy := ground_y + 10
	if s.vehicle != .Feet {draw_vehicle(px - 8, gy, s.vehicle)}
	person(px, gy - bob, fav(1), 0xf2c8a0)
	if s.friends {
		person(px + 16, gy - (1 - bob), 0x3bb5a8, 0xc68c5a)
		person(px + 32, gy - bob, 0xf2a73b, 0x8d5a3a)
	}
	if s.pet {critter(px - 18, gy + 6, 6, 0xa0703a, false)}
	if s.like {
		critter(px + 64, gy - 4, 14, 0xb07a40, false)
		label(px + 64 + 7, gy - 18, app.answers.like)
	}
	if s.dislike {
		critter(x0 + 240, gy - 8, 18, 0x6a4b8a, true)
		label(x0 + 249, gy - 24, app.answers.dislike)
	}
	if s.treasure {
		for i in 0 ..< min(app.answers.number, 12) {
			tx := px + 50 + (i % 6) * 7
			ty := gy + 8 - (i / 6) * 6
			gfx.rect(tx, ty, 5, 5, fav(i))
			gfx.rect(tx + 1, ty + 1, 1, 1, 0xffffff)
		}
	}
	gfx.frame(x0, y0, PW, PH, INK)
}

label :: proc(cx, y: int, s: string) {
	w := gfx.text_width(s)
	gfx.rect(cx - w / 2 - 2, y - 1, w + 4, 10, 0xfffaf0)
	gfx.text(cx - w / 2, y, s, INK)
}

tree :: proc(x, ground: int) {
	gfx.rect(x + 8, ground - 18, 6, 18, 0x7a5230)
	gfx.rect(x, ground - 40, 22, 24, 0x2f7a35)
	gfx.rect(x + 4, ground - 48, 14, 10, 0x2f7a35)
}

cactus :: proc(x, ground: int) {
	gfx.rect(x + 6, ground - 30, 8, 30, 0x3f8f4a)
	gfx.rect(x, ground - 22, 4, 10, 0x3f8f4a)
	gfx.rect(x, ground - 14, 8, 4, 0x3f8f4a)
	gfx.rect(x + 16, ground - 26, 4, 12, 0x3f8f4a)
	gfx.rect(x + 12, ground - 16, 8, 4, 0x3f8f4a)
}

person :: proc(x, y: int, shirt, skin: u32) {
	gfx.rect(x + 2, y - 22, 6, 6, skin)
	gfx.rect(x + 1, y - 24, 8, 3, INK)
	gfx.rect(x + 1, y - 16, 8, 9, shirt)
	gfx.rect(x + 2, y - 7, 2, 7, INK)
	gfx.rect(x + 6, y - 7, 2, 7, INK)
}

// A four-legged animal of any size (the page can't know what a "wombat" looks like).
critter :: proc(x, y, size: int, fur: u32, cross: bool) {
	body_w := size * 3 / 2
	body_h := size * 2 / 3
	gfx.rect(x, y - body_h - 3, body_w, body_h, fur)
	head := size * 2 / 3
	gfx.rect(x + body_w - 2, y - body_h - head / 2 - 4, head, head, fur)
	leg := max(2, size / 5)
	gfx.rect(x + 1, y - 3, leg, 3, fur)
	gfx.rect(x + body_w - leg - 1, y - 3, leg, 3, fur)
	gfx.rect(x + body_w + head / 2 - 1, y - body_h - head / 2 - 1, 2, 2, cross ? 0xff4040 : INK)
	if cross {gfx.rect(x + body_w + head / 2 - 3, y - body_h - head / 2 - 3, 5, 1, INK)}
	gfx.rect(x - 3, y - body_h - 2, 3, 2, fur)
}

draw_vehicle :: proc(x, y: int, v: game.Vehicle) {
	switch v {
	case .Feet:
	case .Skates:
		for i in 0 ..< 3 {
			gfx.rect(x + 8 + i * 16, y, 10, 2, 0xd94040)
			gfx.rect(x + 9 + i * 16, y + 2, 2, 2, INK)
			gfx.rect(x + 15 + i * 16, y + 2, 2, 2, INK)
		}
	case .Balloon:
		gfx.rect(x + 6, y - 2, 46, 6, 0x8b5a2b)
		gfx.rect(x + 14, y - 80, 30, 34, 0xe23b3b)
		gfx.rect(x + 20, y - 80, 6, 34, 0xf5d21f)
		gfx.rect(x + 32, y - 80, 6, 34, 0xf5d21f)
		gfx.rect(x + 10, y - 46, 1, 44, INK)
		gfx.rect(x + 48, y - 46, 1, 44, INK)
	case .Wagon:
		gfx.rect(x + 4, y - 6, 52, 8, 0xd93a3a)
		gfx.rect(x + 8, y + 2, 6, 6, INK)
		gfx.rect(x + 44, y + 2, 6, 6, INK)
	case .Carpet:
		gfx.rect(x + 2, y + 1, 56, 4, 0x8e44c9)
		for i := 0; i < 56; i += 6 {gfx.rect(x + 2 + i, y + 5, 2, 3, 0xf5d21f)}
	case .Boat:
		gfx.rect(x - 10, y + 2, 80, 6, 0x3fa7d6)
		gfx.rect(x + 2, y - 4, 58, 8, 0x8b5a2b)
		gfx.rect(x + 50, y - 44, 2, 40, INK)
		gfx.rect(x + 52, y - 42, 16, 26, 0xf4ecd8)
	}
}
