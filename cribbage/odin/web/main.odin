#+build js
package main

// Cribbage's page: the board, the cards, keys and taps. Rules are in ../game.

import "base:runtime"
import "core:fmt"
import "core:strconv"
import cb "../game"
import "proto:gfx"

W :: 512
H :: 320

FELT :: 0x1f5a3a
FELT_DARK :: 0x174a2f
WOOD :: 0x8a5a2e
WOOD_DARK :: 0x5e3b1c
HOLE :: 0x3e2410
CARD :: 0xf7f3e8
CARD_EDGE :: 0x8a8a7a
BACK :: 0x2a4c9a
BACK_LIT :: 0x4a6cc0
INK :: 0x1c1c24
RED :: 0xc8302a
TEXT :: 0xf3efdc
DIM :: 0x9ebfa8
GOLD :: 0xf2c84a
YOU_C :: 0x6fd0f0
CPU_C :: 0xf08f5a
SEL :: 0xf2c84a

CW :: 36 // card size
CH :: 50
SCW :: 26 // small card (the computer's, face down)
SCH :: 36

Screen :: enum {
	Title,
	Playing,
	Over,
}

App :: struct {
	screen:     Screen,
	g:          cb.Game,
	t:          f32,
	wait:       f32, // before the next automatic step
	selected:   [cb.HAND]bool,
	seen_notes: int,
	msg:        [96]u8,
	msg_len:    int,
	msg_who:    int,
	msg_t:      f32,
	won, lost:  int,
}

app: App

ID_CARD :: 10 // + index
ID_THROW :: 30
ID_NEXT :: 31
ID_START :: 32
ID_MENU :: 33

main :: proc() {
	cb.new_game(&app.g, 5)
	buf: [32]u8
	if v, ok := gfx.store_get("record", buf[:]); ok {
		for i in 0 ..< len(v) {
			if v[i] == ' ' {
				a, aok := strconv.parse_int(v[:i])
				b, bok := strconv.parse_int(v[i + 1:])
				if aok && bok && a >= 0 && b >= 0 {app.won, app.lost = a, b}
			}
		}
	}
}

start :: proc() {
	cb.new_game(&app.g, u64(gfx.now_ms()) ~ u64(gfx.random() * 1e9))
	app.screen = .Playing
	app.selected = {}
	app.seen_notes = app.g.notes
	app.wait = 0.6
	app.msg_len = 0
	shuffle_sound()
}

shuffle_sound :: proc() {
	for i in 0 ..< 6 {gfx.noise(25, 0.08, f32(i) * 45)}
}

say :: proc(who: int, s: string) {
	app.msg_len = copy(app.msg[:], s)
	app.msg_who = who
	app.msg_t = 0
}

who_name :: proc(who: int) -> string {return who == cb.YOU ? "YOU" : "THE COMPUTER"}

@(export)
step :: proc(dt: f64) -> bool {
	d := f32(min(dt, 0.1))
	app.t += d
	app.msg_t += d
	if app.screen == .Playing {play(d)}
	draw()
	free_all(context.temp_allocator)
	return true
}

play :: proc(d: f32) {
	g := &app.g
	if g.phase == .Peg && !cb.your_play(g) {
		app.wait -= d
		if app.wait <= 0 {
			cb.advance(g)
			app.wait = 0.75
		}
	}
	notes()
	sounds()
	if g.phase == .Over && app.screen == .Playing {
		app.wait -= d
		if app.wait <= -1.5 {
			if g.winner == cb.YOU {app.won += 1} else {app.lost += 1}
			gfx.store_set("record", fmt.tprintf("%d %d", app.won, app.lost))
			app.screen = .Over
			app.t = 0
		}
	}
}

// Turns the rules' latest note into the message line.
notes :: proc() {
	g := &app.g
	if g.notes == app.seen_notes {return}
	app.seen_notes = g.notes
	n := g.note
	name := who_name(n.who)
	switch n.kind {
	case .Peg:
		say(n.who, fmt.tprintf("%s: %s", name, peg_words(n.peg)))
		app.wait = max(app.wait, 1.1)
	case .Go:
		if n.points > 0 {say(n.who, fmt.tprintf("GO. ONE FOR %s", name))} else {say(n.who, fmt.tprintf("%s: GO", name))}
		app.wait = max(app.wait, 1.0)
	case .Last_Card:
		say(n.who, fmt.tprintf("LAST CARD. ONE FOR %s", name))
	case .His_Heels:
		say(n.who, fmt.tprintf("A JACK! HIS HEELS: TWO FOR %s", name))
		app.wait = max(app.wait, 1.4)
	case .Hand:
		say(n.who, n.who == cb.YOU ? fmt.tprintf("YOU COUNT %d", n.points) : fmt.tprintf("THE COMPUTER COUNTS %d", n.points))
	case .Crib:
		say(n.who, fmt.tprintf("THE KITTY: %d FOR %s", n.points, name))
	}
}

peg_words :: proc(p: cb.Peg) -> string {
	parts: [4]string
	k := 0
	if p.fifteen {parts[k] = "FIFTEEN FOR 2"; k += 1}
	if p.thirty_one {parts[k] = "31 FOR 2"; k += 1}
	switch p.pair {
	case 2:
		parts[k] = "A PAIR FOR 2"; k += 1
	case 3:
		parts[k] = "PAIR ROYAL FOR 6"; k += 1
	case 4:
		parts[k] = "DOUBLE PAIR ROYAL, 12"; k += 1
	}
	if p.run >= 3 {parts[k] = fmt.tprintf("A RUN OF %d", p.run); k += 1}
	s := parts[0]
	for i in 1 ..< k {s = fmt.tprintf("%s, %s", s, parts[i])}
	return s
}

sounds :: proc() {
	g := &app.g
	ev := g.events
	g.events = {}
	if .Dealt in ev {shuffle_sound()}
	if .Played in ev {gfx.noise(35, 0.12)}
	if .Scored in ev {
		gfx.tone(880, 50, .Square, 0.04, 60)
		gfx.tone(1175, 70, .Square, 0.04, 120)
	}
	if .Said_Go in ev {gfx.tone(330, 120, .Triangle, 0.06)}
	if .Game_Over in ev {
		notes_up := [?]f32{523, 659, 784, 1047}
		notes_dn := [?]f32{392, 330, 262, 196}
		ns := g.winner == cb.YOU ? notes_up : notes_dn
		for f, i in ns {gfx.tone(f, 170, .Triangle, 0.07, 300 + f32(i) * 170)}
		app.wait = 0
	}
}

// ---- input ----

toggle :: proc(i: int) {
	if i < 0 || i >= cb.HAND {return}
	if app.selected[i] {
		app.selected[i] = false
	} else {
		n := 0
		for s in app.selected {if s {n += 1}}
		if n >= 2 {return}
		app.selected[i] = true
	}
	gfx.tone(1400, 15, .Square, 0.03)
}

throw :: proc() {
	a, b := -1, -1
	for s, i in app.selected {
		if !s {continue}
		if a < 0 {a = i} else {b = i}
	}
	if b < 0 {return}
	if cb.discard(&app.g, a, b) {
		app.selected = {}
		app.wait = 1.0
	}
}

// Yer playable cards in the order drawn (unplayed ones only), so 1-4 pick by position.
your_cards :: proc(out: ^[cb.KEEP]int) -> int {
	g := &app.g
	n := 0
	for i in 0 ..< cb.KEEP {
		if !g.played[cb.YOU][i] {
			out[n] = i
			n += 1
		}
	}
	return n
}

play_slot :: proc(slot: int) {
	idx: [cb.KEEP]int
	n := your_cards(&idx)
	if slot < 0 || slot >= n {return}
	if !cb.play(&app.g, idx[slot]) {
		gfx.tone(150, 120, .Saw, 0.04) // over 31
	} else {
		app.wait = 0.8
	}
}

next :: proc() {
	g := &app.g
	if g.phase == .Show {
		cb.show_next(g)
		if g.phase == .Discard {app.msg_len = 0}
	}
}

@(export)
on_key :: proc "c" (code: i32, down: i32) {
	context = runtime.default_context()
	if down != 1 {return}
	c := int(code)
	g := &app.g
	switch app.screen {
	case .Title:
		if c == gfx.KEY_ENTER || c == gfx.KEY_SPACE {start()}
	case .Playing:
		if c == gfx.KEY_ESCAPE {
			app.screen = .Title
			return
		}
		switch g.phase {
		case .Discard:
			if c >= '1' && c <= '6' {toggle(c - '1')}
			if c == gfx.KEY_ENTER || c == gfx.KEY_SPACE {throw()}
		case .Peg:
			if c >= '1' && c <= '4' {play_slot(c - '1')}
		case .Show:
			if c == gfx.KEY_ENTER || c == gfx.KEY_SPACE {next()}
		case .Over:
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
	id := gfx.hit(x, y)
	g := &app.g
	switch app.screen {
	case .Title:
		start()
	case .Playing:
		switch {
		case id >= ID_CARD && id < ID_CARD + cb.HAND:
			if g.phase == .Discard {toggle(id - ID_CARD)}
			if g.phase == .Peg {play_slot(id - ID_CARD)}
		case id == ID_THROW:
			throw()
		case id == ID_NEXT:
			next()
		}
	case .Over:
		if app.t > 1 {
			if id == ID_MENU {app.screen = .Title} else if id == ID_START {start()}
		}
	}
}

// ---- drawing ----

draw :: proc() {
	gfx.clear(FELT)
	gfx.begin_buttons()
	switch app.screen {
	case .Title:
		draw_board()
		draw_title()
	case .Playing:
		draw_board()
		draw_table()
	case .Over:
		draw_board()
		draw_over()
	}
}

// ---- the cribbage board: 120 holes a side and a game hole, pegs front and back ----

BOARD_Y :: 4
HOLE_X0 :: 52

hole_x :: proc(s: int) -> int {
	// s from 1 to 121; groups of five
	if s >= 121 {return HOLE_X0 + 120 * 3 + 24 * 2 + 4}
	i := s - 1
	return HOLE_X0 + i * 3 + (i / 5) * 2
}

draw_board :: proc() {
	g := &app.g
	gfx.rect(4, BOARD_Y, W - 8, 30, WOOD)
	gfx.frame(4, BOARD_Y, W - 8, 30, WOOD_DARK)
	for side in 0 ..< 2 {
		y := BOARD_Y + 7 + side * 12
		c: u32 = side == cb.YOU ? YOU_C : CPU_C
		gfx.text(10, y - 2, side == cb.YOU ? "YOU" : "CPU", c)
		for s in 1 ..= 121 {
			gfx.rect(hole_x(s), y, 2, 2, s % 5 == 0 ? WOOD_DARK : HOLE)
		}
		// Pegs: the back peg shows the score before the last one.
		for pegs in 0 ..< 2 {
			sc := pegs == 0 ? g.scores[side] : g.backs[side]
			x := sc == 0 ? 42 + pegs * 4 : hole_x(sc)
			gfx.rect(x - 1, y - 1, 4, 4, pegs == 0 ? c : (c & 0xfefefe) >> 1)
		}
		sc := fmt.tprintf("%d", g.scores[side])
		gfx.text(W - 10 - gfx.text_width(sc), y - 2, sc, c)
	}
}

// ---- cards ----

SUIT_ART := [4][7]string {
	{"..###..", "..###..", "#######", "#######", "#.#.#.#", "...#...", "..###.."}, // clubs
	{"...#...", "..###..", ".#####.", "#######", ".#####.", "..###..", "...#..."}, // diamonds
	{".##.##.", "#######", "#######", ".#####.", "..###..", "...#...", "......."}, // hearts
	{"...#...", "..###..", ".#####.", "#######", "#######", "..#.#..", "..###.."}, // spades
}

RANK_TEXT := [14]string{"", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"}

draw_suit :: proc(s, x, y: int, c: u32) {
	for row, j in SUIT_ART[s] {
		for i in 0 ..< len(row) {if row[i] == '#' {gfx.rect(x + i, y + j, 1, 1, c)}}
	}
}

draw_card :: proc(card: cb.Card, x, y: int, dim := false, lift := false) {
	yy := lift ? y - 8 : y
	gfx.rect(x + 1, yy + 2, CW, CH, 0x10301e)
	gfx.rect(x, yy, CW, CH, dim ? 0xb8b4a8 : CARD)
	gfx.frame(x, yy, CW, CH, CARD_EDGE)
	s := cb.suit(card)
	ink: u32 = (s == 1 || s == 2) ? RED : INK
	r := RANK_TEXT[cb.rank(card)]
	gfx.text(x + 3, yy + 3, r, ink)
	draw_suit(s, x + 3, yy + 13, ink)
	// A big pip in the middle.
	for row, j in SUIT_ART[s] {
		for i in 0 ..< len(row) {if row[i] == '#' {gfx.rect(x + 11 + i * 2, yy + 22 + j * 2, 2, 2, ink)}}
	}
}

draw_back :: proc(x, y, w, h: int) {
	gfx.rect(x, y, w, h, BACK)
	gfx.frame(x, y, w, h, CARD)
	for j := y + 3; j < y + h - 3; j += 4 {
		for i := x + 3 + (j / 4) % 2 * 2; i < x + w - 3; i += 4 {gfx.rect(i, j, 2, 2, BACK_LIT)}
	}
}

// ---- the table ----

draw_table :: proc() {
	g := &app.g
	// The computer's hand, face down (or face up while it is counted).
	cpu_n := g.phase == .Discard ? cb.HAND : cb.cards_left(g, cb.CPU)
	showing_cpu := g.phase == .Show && g.show_step >= 1 && last_counted() == cb.CPU && g.note.kind == .Hand
	if g.phase == .Show && !showing_cpu {cpu_n = 0}
	for i in 0 ..< cpu_n {draw_back(W / 2 - cpu_n * 15 + i * 30, 42, SCW, SCH)}
	gfx.text(10, 46, g.dealer == cb.CPU ? "THE COMPUTER DEALS" : "YOU DEAL", DIM)

	// The starter, turned up once both have thrown, on the deck; the kitty beside the dealer.
	deck_x := W - 60
	draw_back(deck_x + 3, 92, CW, CH)
	if g.phase != .Discard {draw_card(g.cut, deck_x, 89)}
	gfx.text(deck_x - 4, 145, "STARTER", DIM)
	if g.phase == .Peg || (g.phase == .Show && g.show_step < 3) {
		// The kitty, face down beside the dealer until it is counted.
		kx, ky := W / 2 + 120, 42
		if g.dealer == cb.YOU {kx, ky = W - 60, 200}
		for i in 0 ..< 4 {draw_back(kx + i * 2, ky - i * 2, SCW, SCH)}
		gfx.text(kx - 2, ky + SCH + 2, "KITTY", DIM)
	}

	switch g.phase {
	case .Discard:
		draw_discard()
	case .Peg:
		draw_peg()
	case .Show:
		draw_show()
	case .Over:
		draw_peg()
	}
	draw_message()
}

last_counted :: proc() -> int {
	return app.g.note.who
}

draw_discard :: proc() {
	g := &app.g
	whose := g.dealer == cb.YOU ? "YOUR KITTY" : "THE COMPUTER'S KITTY"
	gfx.text_c(W / 2 - 30, 112, fmt.tprintf("THROW TWO CARDS TO %s", whose), TEXT)
	gfx.text_c(W / 2 - 30, 126, "TAP TWO, OR KEYS 1-6, THEN THROW", DIM)
	for i in 0 ..< cb.HAND {
		x := W / 2 - 3 * 44 + i * 44
		draw_card(g.hands[cb.YOU][i], x, 200, false, app.selected[i])
		gfx.zone(x, 192, CW, CH + 8, ID_CARD + i)
		gfx.text(x + CW / 2 - 4, 256, fmt.tprintf("%d", i + 1), DIM)
	}
	n := 0
	for s in app.selected {if s {n += 1}}
	if n == 2 {gfx.button(W / 2 - 64, 154, "THROW TO KITTY", ID_THROW, GOLD, FELT_DARK)}
}

draw_peg :: proc() {
	g := &app.g
	// The pile since the count was last reset, fanned out.
	start := g.played_n - g.pile_len
	for k in 0 ..< g.pile_len {
		i := start + k
		x := 60 + k * 26
		y := 94 + (g.played_by[i] == cb.CPU ? -4 : 4)
		draw_card(g.played_all[i], x, y)
	}
	// Cards pegged earlier this hand, small, to keep track.
	for i in 0 ..< start {
		c := g.played_all[i]
		x := 20 + i * 18
		s := cb.suit(c)
		ink: u32 = (s == 1 || s == 2) ? RED : INK
		gfx.rect(x, 160, 16, 20, 0xb8b4a8)
		gfx.text(x + 1, 162, RANK_TEXT[cb.rank(c)], ink)
		draw_suit(s, x + 4, 171, ink)
	}
	gfx.text(300, 100, "COUNT", DIM)
	gfx.text(300, 112, fmt.tprintf("%d", g.count), GOLD, 3)

	idx: [cb.KEEP]int
	n := your_cards(&idx)
	yours := cb.your_play(g)
	for k in 0 ..< n {
		i := idx[k]
		x := W / 2 - n * 22 + k * 44
		ok := cb.legal(g, cb.YOU, i)
		draw_card(g.kept[cb.YOU][i], x, 200, yours && !ok, false)
		if yours {
			gfx.zone(x, 200, CW, CH, ID_CARD + k)
			gfx.text(x + CW / 2 - 4, 256, fmt.tprintf("%d", k + 1), ok ? TEXT : DIM)
		}
	}
	if yours {
		gfx.text_c(W / 2, 186, "YOUR PLAY", YOU_C)
	} else if g.phase == .Peg && g.turn == cb.CPU && cb.can_play(g, cb.CPU) {
		gfx.text_c(W / 2, 186, "THE COMPUTER IS THINKING", CPU_C)
	}
}

draw_show :: proc() {
	g := &app.g
	if g.show_step == 0 {
		gfx.text_c(W / 2 - 30, 110, "PEGGING DONE. TIME TO COUNT.", TEXT)
		gfx.button(W / 2 - 80, 150, "COUNT THE HANDS", ID_NEXT, GOLD, FELT_DARK)
		draw_kept(cb.YOU, 200)
		return
	}
	n := g.note
	cards: [cb.KEEP]cb.Card
	title: string
	if n.kind == .Crib {
		cards = g.crib
		title = g.dealer == cb.YOU ? "YOUR KITTY" : "THE COMPUTER'S KITTY"
	} else {
		cards = g.kept[n.who]
		title = n.who == cb.YOU ? "YOUR HAND" : "THE COMPUTER'S HAND"
	}
	gfx.text(40, 74, title, n.who == cb.YOU ? YOU_C : CPU_C)
	for i in 0 ..< cb.KEEP {draw_card(cards[i], 40 + i * 42, 88)}
	draw_card(g.cut, 40 + 4 * 42 + 10, 88)
	c := n.count
	lines: [5]string
	k := 0
	if c.fifteens > 0 {lines[k] = fmt.tprintf("FIFTEENS  %2d", c.fifteens); k += 1}
	if c.pairs > 0 {lines[k] = fmt.tprintf("PAIRS     %2d", c.pairs); k += 1}
	if c.runs > 0 {lines[k] = fmt.tprintf("RUNS      %2d", c.runs); k += 1}
	if c.flush > 0 {lines[k] = fmt.tprintf("FLUSH     %2d", c.flush); k += 1}
	if c.nobs > 0 {lines[k] = fmt.tprintf("HIS NOBS  %2d", c.nobs); k += 1}
	y := 150
	if k == 0 {
		gfx.text(40, y, "NINETEEN (NOTHING)", DIM)
		y += 11
	}
	for i in 0 ..< k {
		gfx.text(40, y, lines[i], TEXT)
		y += 11
	}
	gfx.text(40, y + 2, fmt.tprintf("TOTAL     %2d", cb.total(c)), GOLD)
	if g.phase == .Show {
		label := g.show_step >= 3 ? "NEXT DEAL" : "NEXT COUNT"
		gfx.button(300, 160, label, ID_NEXT, GOLD, FELT_DARK)
	}
}

draw_kept :: proc(p, y: int) {
	g := &app.g
	for i in 0 ..< cb.KEEP {
		draw_card(g.kept[p][i], W / 2 - 2 * 44 + i * 44, y)
	}
}

draw_message :: proc() {
	if app.msg_len == 0 {return}
	s := string(app.msg[:app.msg_len])
	c: u32 = app.msg_who == cb.YOU ? YOU_C : CPU_C
	gfx.rect(0, H - 30, W, 22, FELT_DARK)
	gfx.text_c(W / 2, H - 23, s, app.msg_t < 0.3 && int(app.msg_t * 20) % 2 == 0 ? TEXT : c)
}

draw_title :: proc() {
	gfx.rect(56, 60, W - 112, 200, FELT_DARK)
	gfx.frame(56, 60, W - 112, 200, GOLD)
	gfx.text_c(W / 2, 72, "CRIBBAGE", GOLD, 3)
	gfx.text_c(W / 2, 100, "YOU VS THE COMPUTER, TO 121", TEXT)
	lines := [?]string {
		"THROW TWO TO THE KITTY, PEG TO 31,",
		"THEN COUNT FIFTEENS, PAIRS, RUNS,",
		"FLUSHES AND HIS NOBS.",
		"",
		"TAP OR KEYS 1-6 TO PICK CARDS.",
		"SPACE OR ENTER TO GO ON.",
	}
	for l, i in lines {gfx.text_c(W / 2, 122 + i * 11, l, DIM)}
	if int(app.t * 2) % 2 == 0 {gfx.text_c(W / 2, 200, "PRESS SPACE OR TAP TO DEAL", GOLD)}
	gfx.text_c(W / 2, 222, fmt.tprintf("RECORD %d-%d", app.won, app.lost), DIM)
	gfx.text_c(W / 2, 240, "AFTER 'CRIBBAGE', SOFTSIDE 1978", DIM)
}

draw_over :: proc() {
	g := &app.g
	gfx.rect(76, 70, W - 152, 170, FELT_DARK)
	gfx.frame(76, 70, W - 152, 170, GOLD)
	gfx.text_c(W / 2, 84, g.winner == cb.YOU ? "YOU WIN!" : "THE COMPUTER WINS", g.winner == cb.YOU ? YOU_C : CPU_C, 2)
	gfx.text_c(W / 2, 112, fmt.tprintf("%d TO %d", g.scores[g.winner], g.scores[1 - g.winner]), TEXT, 2)
	loser := g.scores[1 - g.winner]
	verdict := ""
	switch {
	case loser <= 60:
		verdict = "A DOUBLE SKUNK!"
	case loser <= 90:
		verdict = "A SKUNK!"
	case loser >= 116:
		verdict = "BY A PEG OR TWO"
	}
	gfx.text_c(W / 2, 140, verdict, GOLD)
	gfx.text_c(W / 2, 156, fmt.tprintf("RECORD %d-%d", app.won, app.lost), DIM)
	if app.t > 1 {
		gfx.button(W / 2 - 92, 190, "PLAY AGAIN", ID_START, TEXT, FELT)
		gfx.button(W / 2 + 20, 190, "TITLE", ID_MENU, DIM, FELT)
	}
}
