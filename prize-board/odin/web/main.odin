#+build js
package main

// Prize Board's page: drawing, keys and taps. Rules are in ../game.

import "base:runtime"
import "core:fmt"
import "core:strconv"
import game "../game"
import "proto:gfx"

W :: 384
H :: 240

STUDIO :: 0x14102a
PANEL :: 0x24305e
PANEL_LIT :: 0x3a4c8e
GONE :: 0x1b1838
GOLD :: 0xf2c84b
WHITE :: 0xf2f0e6
DIM :: 0x9a98b8
PINK :: 0xff6fa8
GOOD :: 0x8fe08a
BAD :: 0xff7a6a
CARD :: 0xfbf3dc
INK :: 0x2a2030

Screen :: enum {
	Title,
	Board,
	Round_End, // the number was found, or no pair is left
	Prizes, // what each player won this round
	Break, // "WE'LL BE BACK IN JUST A MOMENT"
	Over,
}

Level :: enum {
	Forgetful,
	Sharp,
	Elephant,
}
LEVEL_NAME := [Level]string{.Forgetful = "FORGETFUL", .Sharp = "SHARP", .Elephant = "ELEPHANT"}
LEVEL_RECALL := [Level]f32{.Forgetful = 0.35, .Sharp = 0.7, .Elephant = 0.95}

App :: struct {
	screen:  Screen,
	g:       game.Game,
	vs_cpu:  bool,
	level:   Level,
	t:       f32, // time on this screen
	wait:    f32, // time in this phase of the board
	entry:   [3]u8,
	n_entry: int,
	msg:     string,
	msg_buf: [64]u8,
	msg_c:   u32,
	commercial: int,
	// Records kept in the browser.
	wins:    [Level]int,
	losses:  [Level]int,
	best:    int, // biggest winnings by a person in one game
}

app: App

ID_LEVEL :: 10 // + level
ID_TWO :: 20
ID_SQUARE :: 100 // + square
ID_DIGIT :: 200 // + digit
ID_DEL :: 210
ID_OK :: 211
ID_NEXT :: 220

COMMERCIALS := [?]string {
	"SPARKLE-BRIGHT: THE TOOTHPASTE THAT WINKS BACK!",
	"CRUNCHY FLAKES: NOW WITH 20% MORE CRUNCH!",
	"ACE MOTORS: COME ON DOWN, WE'RE PRACTICALLY GIVING THEM AWAY!",
	"SOFTSIDE: YOUR BASIC SOFTWARE MAGAZINE!",
	"GLO-GUM: CHEW IT IN THE DARK!",
	"MAMMOTH STEREO: HEAR THE DRUMMER SWEAT!",
}

main :: proc() {
	game.new_game(&app.g, 1, false)
	buf: [32]u8
	load :: proc(key: string, buf: []u8) -> int {
		if v, ok := gfx.store_get(key, buf); ok {
			if n, nok := strconv.parse_int(v); nok && n >= 0 && n < 100000000 {return n}
		}
		return 0
	}
	for l in Level {
		app.wins[l] = load(fmt.tprintf("wins%d", int(l)), buf[:])
		app.losses[l] = load(fmt.tprintf("losses%d", int(l)), buf[:])
	}
	app.best = load("best", buf[:])
}

start :: proc(vs_cpu: bool, level: Level) {
	app.vs_cpu = vs_cpu
	app.level = level
	game.new_game(&app.g, u64(gfx.now_ms()) ~ u64(gfx.random() * 1e9), vs_cpu, LEVEL_RECALL[level])
	to_board()
	bell()
}

to_board :: proc() {
	app.screen = .Board
	app.wait = 0
	app.n_entry = 0
	app.msg = ""
}

player_name :: proc(p: int) -> string {
	if app.vs_cpu {return p == 0 ? "YOU" : "COMPUTER"}
	return p == 0 ? "PLAYER 1" : "PLAYER 2"
}

cpu_turn :: proc() -> bool {
	return app.g.players[app.g.turn].cpu
}

bell :: proc() {
	gfx.tone(659, 90, .Sine, 0.06)
	gfx.tone(880, 90, .Sine, 0.06, 90)
	gfx.tone(1319, 200, .Sine, 0.05, 180)
}

@(export)
step :: proc(dt: f64) -> bool {
	d := f32(min(dt, 0.1))
	app.t += d
	if app.screen == .Board {play(d)}
	draw()
	free_all(context.temp_allocator)
	return true
}

play :: proc(d: f32) {
	g := &app.g
	app.wait += d
	sounds()
	#partial switch g.phase {
	case .First, .Second:
		if cpu_turn() && app.wait > 0.9 {
			game.pick(g, game.cpu_pick(g))
			app.wait = 0
		}
	case .Miss:
		if app.wait > 2.2 {advance()}
	case .Match:
		if app.wait > 1.8 {advance()}
	case .Guess:
		if cpu_turn() && app.wait > 1.2 {
			n := game.cpu_guess(g)
			set_msg(fmt.tprintf("COMPUTER GUESSES %d", n), DIM)
			game.guess(g, n)
			app.wait = 0
		}
	case .Guessed:
		if app.wait > 2.4 {advance()}
	case .Round_Won, .Round_Tied:
		if app.wait > 0.6 {
			app.screen = .Round_End
			app.t = 0
		}
	}
}

set_msg :: proc(s: string, c: u32) {
	n := copy(app.msg_buf[:], s)
	app.msg = string(app.msg_buf[:n])
	app.msg_c = c
}

// Moves a shown result on (also by a tap).
advance :: proc() {
	g := &app.g
	if g.phase == .Miss || g.phase == .Match || g.phase == .Guessed {
		game.cont(g)
		app.wait = 0
		app.n_entry = 0
		if g.phase != .Guessed {app.msg = ""}
	}
}

sounds :: proc() {
	g := &app.g
	ev := g.events
	g.events = {}
	if .Illegal in ev {gfx.tone(120, 140, .Square, 0.05)}
	if .Reveal in ev && .Match not_in ev && .Miss not_in ev {gfx.tone(880, 50, .Square, 0.03)}
	if .Match in ev {
		for f, i in ([?]f32{523, 659, 784, 1047}) {gfx.tone(f, 90, .Square, 0.045, f32(i) * 80)}
	}
	if .Miss in ev {
		gfx.tone(880, 50, .Square, 0.03)
		gfx.tone(220, 180, .Saw, 0.04, 120)
		gfx.tone(185, 260, .Saw, 0.04, 280)
	}
	if .Too_High in ev {
		set_msg(fmt.tprintf("%d IS TOO HIGH.", g.last_guess), BAD)
		gfx.tone(660, 90, .Triangle, 0.05)
		gfx.tone(440, 160, .Triangle, 0.05, 90)
	}
	if .Too_Low in ev {
		set_msg(fmt.tprintf("%d IS TOO LOW.", g.last_guess), BAD)
		gfx.tone(440, 90, .Triangle, 0.05)
		gfx.tone(660, 160, .Triangle, 0.05, 90)
	}
	if .Right in ev {
		for f, i in ([?]f32{523, 659, 784, 1047, 784, 1047, 1319}) {gfx.tone(f, 120, .Square, 0.05, f32(i) * 110)}
	}
	if .Tie in ev {
		gfx.tone(330, 200, .Triangle, 0.05)
		gfx.tone(294, 200, .Triangle, 0.05, 200)
		gfx.tone(262, 400, .Triangle, 0.05, 400)
	}
}

// ---- input ----

type_digit :: proc(c: u8) {
	if app.n_entry < 3 {
		app.entry[app.n_entry] = c
		app.n_entry += 1
		gfx.tone(1200, 15, .Square, 0.02)
	}
}

entry_value :: proc() -> int {
	if app.n_entry == 0 {return -1}
	n, _ := strconv.parse_int(string(app.entry[:app.n_entry]))
	return n
}

submit :: proc() {
	g := &app.g
	if cpu_turn() {return}
	n := entry_value()
	app.n_entry = 0
	if n < 0 {return}
	#partial switch g.phase {
	case .First, .Second:
		if !game.pick(g, n - 1) {app.msg, app.msg_c = "SORRY, I CAN'T SHOW YOU THAT.", BAD} else {app.msg = ""}
		app.wait = 0
	case .Guess:
		if !game.guess(g, n) {app.msg, app.msg_c = "A NUMBER FROM 1 TO 100, PLEASE.", BAD} else {app.wait = 0}
	}
}

choose_square :: proc(sq: int) {
	g := &app.g
	if cpu_turn() || (g.phase != .First && g.phase != .Second) {return}
	app.n_entry = 0
	if !game.pick(g, sq) {app.msg, app.msg_c = "SORRY, I CAN'T SHOW YOU THAT.", BAD} else {app.msg = ""}
	app.wait = 0
}

next_screen :: proc() {
	g := &app.g
	switch app.screen {
	case .Round_End:
		app.screen = .Prizes
	case .Prizes:
		game.next_round(g)
		if g.phase == .Over {
			finish()
		} else {
			app.screen = .Break
			app.commercial = int(gfx.random() * f64(len(COMMERCIALS))) % len(COMMERCIALS)
		}
	case .Break:
		to_board()
	case .Title, .Board, .Over:
	}
	app.t = 0
}

finish :: proc() {
	g := &app.g
	app.screen = .Over
	app.t = 0
	if app.vs_cpu {
		if g.winner == 0 {app.wins[app.level] += 1} else {app.losses[app.level] += 1}
		gfx.store_set(fmt.tprintf("wins%d", int(app.level)), fmt.tprintf("%d", app.wins[app.level]))
		gfx.store_set(fmt.tprintf("losses%d", int(app.level)), fmt.tprintf("%d", app.losses[app.level]))
	}
	for p in 0 ..< 2 {
		if g.players[p].cpu {continue}
		if g.players[p].total > app.best {
			app.best = g.players[p].total
			gfx.store_set("best", fmt.tprintf("%d", app.best))
		}
	}
	bell()
}

@(export)
on_key :: proc "c" (code: i32, down: i32) {
	context = runtime.default_context()
	if down != 1 {return}
	c := int(code)
	switch app.screen {
	case .Title:
		if c == '1' {start(true, .Forgetful)}
		if c == '2' {start(true, .Sharp)}
		if c == '3' {start(true, .Elephant)}
		if c == '4' {start(false, .Sharp)}
	case .Board:
		g := &app.g
		if c == gfx.KEY_ESCAPE {app.screen = .Title; return}
		if g.phase == .Miss || g.phase == .Match || g.phase == .Guessed {
			if c == gfx.KEY_ENTER || c == gfx.KEY_SPACE {advance()}
			return
		}
		if c >= '0' && c <= '9' {type_digit(u8(c))}
		if c == gfx.KEY_BACKSPACE && app.n_entry > 0 {app.n_entry -= 1}
		if c == gfx.KEY_ENTER {submit()}
	case .Round_End, .Prizes, .Break:
		if app.t > 0.6 && (c == gfx.KEY_ENTER || c == gfx.KEY_SPACE) {next_screen()}
		if c == gfx.KEY_ESCAPE {app.screen = .Title}
	case .Over:
		if app.t > 1 && (c == gfx.KEY_ENTER || c == gfx.KEY_SPACE || c == gfx.KEY_ESCAPE) {app.screen = .Title}
	}
}

@(export)
on_pointer :: proc "c" (x, y: f32, kind: i32) {
	context = runtime.default_context()
	if kind != 0 {return}
	id := gfx.hit(x, y)
	switch app.screen {
	case .Title:
		if id >= ID_LEVEL && id < ID_LEVEL + len(Level) {start(true, Level(id - ID_LEVEL))}
		if id == ID_TWO {start(false, .Sharp)}
	case .Board:
		g := &app.g
		if g.phase == .Miss || g.phase == .Match || g.phase == .Guessed {
			advance()
			return
		}
		if id >= ID_SQUARE && id < ID_SQUARE + game.SQUARES {choose_square(id - ID_SQUARE)}
		if id >= ID_DIGIT && id < ID_DIGIT + 10 {type_digit(u8('0' + id - ID_DIGIT))}
		if id == ID_DEL && app.n_entry > 0 {app.n_entry -= 1}
		if id == ID_OK {submit()}
	case .Round_End, .Prizes, .Break:
		if app.t > 0.6 {next_screen()}
	case .Over:
		if app.t > 1 {app.screen = .Title}
	}
}

// ---- drawing ----

draw :: proc() {
	gfx.clear(STUDIO)
	gfx.begin_buttons()
	// Studio lights along the top and bottom.
	for i in 0 ..< 24 {
		on := (int(app.t * 4) + i) % 3 == 0
		gfx.rect(4 + i * 16, 0, 6, 2, on ? GOLD : 0x4a3a20)
		gfx.rect(4 + i * 16, H - 2, 6, 2, on ? GOLD : 0x4a3a20)
	}
	switch app.screen {
	case .Title:
		draw_title()
	case .Board:
		draw_board()
	case .Round_End:
		draw_round_end()
	case .Prizes:
		draw_prizes()
	case .Break:
		draw_break()
	case .Over:
		draw_over()
	}
}

draw_title :: proc() {
	gfx.text_c(W / 2, 14, "PRIZE", GOLD, 3)
	gfx.text_c(W / 2, 40, "BOARD", PINK, 3)
	lines := [?]string {
		"32 SQUARES HIDE 15 PAIRS OF PRIZES",
		"AND 2 WILD CARDS. NAME TWO SQUARES.",
		"A PAIR WINS THE PRIZE AND A GUESS AT",
		"MY SECRET NUMBER, 1 TO 100. GUESS IT",
		"AND YOU KEEP THE ROUND'S PRIZES.",
		"THREE ROUNDS. CONCENTRATE!",
	}
	for l, i in lines {gfx.text_c(W / 2, 74 + i * 10, l, DIM)}
	y := 140
	x := 12
	for l in Level {
		label := fmt.tprintf("%d: VS %s", int(l) + 1, LEVEL_NAME[l])
		w := gfx.button(x, y, label, ID_LEVEL + int(l), l == .Sharp ? GOLD : WHITE, PANEL)
		gfx.text(x, y + 18, fmt.tprintf("%d-%d", app.wins[l], app.losses[l]), DIM)
		x += w + 8
	}
	gfx.button(W / 2 - 60, 178, "4: TWO PLAYERS", ID_TWO, WHITE, PANEL)
	if app.best > 0 {gfx.text_c(W / 2, 200, fmt.tprintf("BIGGEST WINNINGS $%d", app.best), GOLD)}
	gfx.text_c(W / 2, 216, "AFTER 'CONCENTRATION' BY LANCE MICKLUS, 1979", DIM)
}

BX :: 5
BY :: 26
CW :: 92
CH :: 16
GAP :: 2

square_xy :: proc(sq: int) -> (int, int) {
	return BX + (sq % 4) * (CW + GAP), BY + (sq / 4) * (CH + GAP)
}

draw_board :: proc() {
	g := &app.g
	// Header: the round, each player's banked total and this round's prizes.
	round := g.round > game.ROUNDS ? "RUBBER ROUND" : fmt.tprintf("ROUND %d OF %d", g.round, game.ROUNDS)
	gfx.text_c(W / 2, 5, round, GOLD)
	for p in 0 ..< 2 {
		pl := &g.players[p]
		c: u32 = p == g.turn ? WHITE : DIM
		s := fmt.tprintf("%s $%d", player_name(p), pl.total)
		r := fmt.tprintf("+$%d AT STAKE", pl.round_value)
		if p == 0 {
			gfx.text(6, 5, s, c)
			gfx.text(6, 15, r, DIM)
			if p == g.turn {gfx.rect(0, 5, 3, 8, PINK)}
		} else {
			gfx.text(W - 6 - gfx.text_width(s), 5, s, c)
			gfx.text(W - 6 - gfx.text_width(r), 15, r, DIM)
			if p == g.turn {gfx.rect(W - 3, 5, 3, 8, PINK)}
		}
	}
	human := !cpu_turn()
	picking := g.phase == .First || g.phase == .Second
	for sq in 0 ..< game.SQUARES {
		x, y := square_xy(sq)
		s := g.board[sq]
		shown := sq == g.first || sq == g.second
		if s.gone && !shown {
			gfx.rect(x, y, CW, CH, GONE)
			continue
		}
		if shown {
			wild := s.prize == game.WILD
			gfx.rect(x, y, CW, CH, wild ? PINK : CARD)
			gfx.text_c(x + CW / 2, y + 4, game.PRIZES[s.prize].name, INK)
		} else {
			gfx.rect(x, y, CW, CH, PANEL)
			gfx.frame(x, y, CW, CH, PANEL_LIT)
			gfx.text_c(x + CW / 2, y + 4, fmt.tprintf(">> %d <<", sq + 1), GOLD)
			if human && picking {gfx.zone(x, y, CW, CH, ID_SQUARE + sq)}
		}
	}

	// The panel under the board.
	py := BY + 8 * (CH + GAP) + 2
	who := player_name(g.turn)
	line1, line2: string
	c1: u32 = WHITE
	switch g.phase {
	case .First:
		line1 = fmt.tprintf("%s: YOUR FIRST SQUARE?", who)
	case .Second:
		pz := game.PRIZES[g.board[g.first].prize]
		line1 = pz.value > 0 ? fmt.tprintf("THE %s, WORTH $%d", pz.name, pz.value) : "A WILD CARD!"
		line2 = fmt.tprintf("%s: YOUR SECOND SQUARE?", who)
	case .Miss:
		line1, c1 = "NO MATCH.", BAD
		line2 = "TAP TO GO ON"
	case .Match:
		if g.prize < 0 {
			line1, c1 = "TWO WILD CARDS! NO PRIZE, BUT A GUESS.", GOLD
		} else {
			pz := game.PRIZES[g.prize]
			line1, c1 = fmt.tprintf("A MATCH! THE %s, WORTH $%d", pz.name, pz.value), GOOD
		}
	case .Guess:
		line1 = fmt.tprintf("%s: WHAT'S MY SECRET NUMBER (1-100)?", who)
	case .Guessed:
		line1, c1 = app.msg, app.msg_c
		line2 = "BUT YOU STILL GET ANOTHER TURN."
	case .Round_Won, .Round_Tied, .Over:
	}
	if g.phase == .Guessed && cpu_turn() {line2 = "BUT IT STILL GETS ANOTHER TURN."}
	gfx.text_c(W / 2, py + 2, line1, c1)
	if line2 != "" {gfx.text_c(W / 2, py + 12, line2, DIM)}
	if (picking || g.phase == .Guess) && app.msg != "" && app.msg_c == BAD && g.phase != .Guessed {
		gfx.text_c(W / 2, py + 12, app.msg, BAD)
	}
	if g.phase == .Guess && cpu_turn() && app.wait > 0.4 {gfx.text_c(W / 2, py + 12, "HMM...", DIM)}

	// A keypad for people: square numbers or the guess.
	if human && (picking || g.phase == .Guess) {
		ky := py + 26
		entry := app.n_entry > 0 ? string(app.entry[:app.n_entry]) : ""
		gfx.rect(6, ky, 38, 16, CARD)
		gfx.text(10, ky + 4, entry, INK)
		if int(app.t * 2) % 2 == 0 {gfx.rect(10 + app.n_entry * 8, ky + 12, 7, 1, INK)}
		x := 50
		for dgt in 0 ..< 10 {
			gfx.rect(x, ky, 22, 16, PANEL)
			gfx.frame(x, ky, 22, 16, PANEL_LIT)
			gfx.text(x + 7, ky + 4, fmt.tprintf("%d", (dgt + 1) % 10), WHITE)
			gfx.zone(x, ky, 22, 16, ID_DIGIT + (dgt + 1) % 10)
			x += 24
		}
		gfx.button(x + 2, ky + 1, "DEL", ID_DEL, DIM, PANEL)
		gfx.button(x + 36, ky + 1, "OK", ID_OK, GOLD, PANEL)
	}
}

draw_round_end :: proc() {
	g := &app.g
	if g.phase == .Round_Won {
		gfx.text_c(W / 2, 40, "THAT'S CORRECT,", WHITE, 2)
		gfx.text_c(W / 2, 62, fmt.tprintf("%s!", player_name(g.winner)), GOLD, 2)
		gfx.text_c(W / 2, 96, fmt.tprintf("MY NUMBER WAS %d.", g.secret), WHITE)
		gfx.text_c(W / 2, 110, fmt.tprintf("FOUND ON GUESS %d OF THE ROUND.", g.guesses), DIM)
	} else {
		gfx.text_c(W / 2, 50, "TIE GAME, NO WINNER.", WHITE, 2)
		gfx.text_c(W / 2, 84, "NO PAIR CAN BE MADE ANY MORE.", DIM)
		gfx.text_c(W / 2, 96, fmt.tprintf("MY NUMBER WAS %d.", g.secret), DIM)
		gfx.text_c(W / 2, 108, "NOBODY KEEPS THIS ROUND'S PRIZES.", DIM)
	}
	if app.t > 0.6 {gfx.button(W / 2 - 60, 160, "SEE THE PRIZES", ID_NEXT, GOLD, PANEL)}
}

draw_prizes :: proc() {
	g := &app.g
	gfx.text_c(W / 2, 8, "THIS ROUND'S PRIZES", GOLD)
	for p in 0 ..< 2 {
		pl := &g.players[p]
		x := p == 0 ? 8 : W / 2 + 4
		keep := g.winner == p
		gfx.text(x, 22, player_name(p), keep ? WHITE : DIM)
		if pl.n_won == 0 {
			gfx.text(x, 36, "NO PRIZES.", DIM)
		}
		for i in 0 ..< pl.n_won {
			pz := game.PRIZES[pl.won[i]]
			y := 34 + i * 10
			if y > 186 {break}
			gfx.text(x, y, pz.name, keep ? WHITE : DIM)
			v := fmt.tprintf("$%d", pz.value)
			gfx.text(x + 176 - gfx.text_width(v), y, v, keep ? GOLD : DIM)
		}
		tot := fmt.tprintf("TOTAL $%d", pl.round_value)
		gfx.text(x, 196, tot, keep ? GOLD : DIM)
		gfx.text(x, 207, keep ? (pl.n_won > 0 ? "KEEPS THEM!" : "WINS THE ROUND!") : (pl.n_won > 0 ? "LOSES THEM." : ""), keep ? GOOD : BAD)
	}
	gfx.rect(W / 2 - 1, 22, 1, 196, PANEL)
	if app.t > 0.6 {gfx.text_c(W / 2, 224, "TAP TO GO ON", DIM)}
}

draw_break :: proc() {
	g := &app.g
	if game.rubber(g) {
		gfx.text_c(W / 2, 30, "TIE GAME, SO WE PLAY", WHITE)
		gfx.text_c(W / 2, 42, "A RUBBER MATCH.", WHITE)
	}
	gfx.text_c(W / 2, 64, "WE'LL BE BACK IN JUST A MOMENT", WHITE)
	gfx.text_c(W / 2, 76, game.rubber(g) ? "WITH THE RUBBER ROUND." : fmt.tprintf("WITH ROUND %d.", g.round), WHITE)
	gfx.text_c(W / 2, 100, "(INSERT COMMERCIAL HERE)", DIM)
	// The commercial.
	gfx.rect(30, 120, W - 60, 60, CARD)
	gfx.frame(32, 122, W - 64, 56, PINK)
	ad := COMMERCIALS[app.commercial]
	if len(ad) > 38 {
		cut := 38
		for cut > 0 && ad[cut] != ' ' {cut -= 1}
		gfx.text_c(W / 2, 138, ad[:cut], INK)
		gfx.text_c(W / 2, 150, ad[cut + 1:], INK)
	} else {
		gfx.text_c(W / 2, 144, ad, INK)
	}
	for p in 0 ..< 2 {
		gfx.text_c(p == 0 ? W / 4 : 3 * W / 4, 196, fmt.tprintf("%s $%d", player_name(p), g.players[p].total), GOLD)
	}
	if app.t > 0.6 {gfx.text_c(W / 2, 214, "TAP TO GO ON", DIM)}
}

draw_over :: proc() {
	g := &app.g
	w := g.winner
	gfx.text_c(W / 2, 30, player_name(w), GOLD, 2)
	gfx.text_c(W / 2, 52, app.vs_cpu && w == 0 ? "WIN THE GAME!!!" : "WINS THE GAME!!!", WHITE, 2)
	for p in 0 ..< 2 {
		pl := &g.players[p]
		gfx.text_c(p == 0 ? W / 4 : 3 * W / 4, 92, player_name(p), p == w ? WHITE : DIM)
		gfx.text_c(p == 0 ? W / 4 : 3 * W / 4, 104, fmt.tprintf("$%d", pl.total), p == w ? GOLD : DIM)
		gfx.text_c(p == 0 ? W / 4 : 3 * W / 4, 116, fmt.tprintf("%d ROUND%s WON", pl.rounds_won, pl.rounds_won == 1 ? "" : "S"), DIM)
	}
	gfx.text_c(W / 2, 146, "CONGRATULATIONS. HOPE YOU HAD FUN PLAYING.", WHITE)
	if app.vs_cpu {
		gfx.text_c(W / 2, 162, fmt.tprintf("VS %s: %d WON, %d LOST", LEVEL_NAME[app.level], app.wins[app.level], app.losses[app.level]), DIM)
	}
	gfx.text_c(W / 2, 190, "C O N C E N T R A T E !", PINK)
	if app.t > 1 {gfx.text_c(W / 2, 212, "TAP FOR THE TITLE", DIM)}
}
