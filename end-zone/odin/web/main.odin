#+build js
package main

// End Zone's page: the field, the scoreboard, the play calls and the hand-over between players.
// Rules are in ../game.

import "base:runtime"
import "core:fmt"
import "core:strconv"
import "core:strings"
import ez "../game"
import "proto:gfx"

W :: 512
H :: 320

BG :: 0x10140f
GRASS :: 0x2f6b2f
GRASS_DARK :: 0x29602a
CHALK :: 0xe8f0e0
CHALK_DIM :: 0x6f9a6f
HOME_COL :: 0x3f6fd8
VIS_COL :: 0xd84a3a
BALL_COL :: 0x8a4a1e
SCRIMMAGE :: 0x6fb0ff
FIRST_DOWN :: 0xffd84a
BOARD :: 0x1c1e1a
BOARD_LINE :: 0x3a3e34
LAMP :: 0xffc23a
TEXT :: 0xe8ead8
DIM :: 0x8f948a
BTN :: 0x262a22
BTN_ON :: 0x3f5a2f

FX :: 16 // the field: end zones 40 px, a yard 4 px
FY :: 26
FH :: 60
YARD :: 4
GOAL_X :: FX + 10 * YARD

Mode :: enum {
	Two_Players,
	Versus_Computer, // you are HOME
}

Step :: enum {
	Title,
	Kickoff, // the kicking side picks deep or onside (or the computer kicks)
	Offence, // the offence calls a play in secret
	Hand_Over, // pass the keyboard to the defence
	Defence, // the defence picks an alignment (or punt return choice)
	Result,
	Over,
}

App :: struct {
	mode:      Mode,
	step:      Step,
	g:         ez.Game,
	call:      ez.Call,
	off_tempo: ez.Tempo,
	def_tempo: ez.Tempo,
	t:         f32, // time on this step
	anim:      f32,
	wins:      int, // against the computer
	losses:    int,
	ties:      int,
}

app: App

ID_TWO :: 1
ID_CPU :: 2
ID_DEEP :: 3
ID_ONSIDE :: 4
ID_READY :: 5
ID_NEXT :: 6
ID_AGAIN :: 7
ID_MENU :: 8
ID_TEMPO :: 20 // + tempo
ID_PLAY :: 40 // + play
ID_DEF :: 60 // + alignment
ID_PUNT :: 80 // + punt choice

main :: proc() {
	ez.new_game(&app.g, 3)
	buf: [32]u8
	if v, ok := gfx.store_get("record", buf[:]); ok {
		f := strings.fields(v, context.temp_allocator)
		if len(f) == 3 {
			app.wins, _ = strconv.parse_int(f[0])
			app.losses, _ = strconv.parse_int(f[1])
			app.ties, _ = strconv.parse_int(f[2])
		}
	}
}

human :: proc(team: int) -> bool {
	return app.mode == .Two_Players || team == ez.HOME
}

go :: proc(s: Step) {
	app.step = s
	app.t = 0
}

start :: proc(m: Mode) {
	app.mode = m
	ez.new_game(&app.g, u64(gfx.now_ms()) ~ u64(gfx.random() * 1e9))
	app.g.from_x = 50
	app.g.to_x = 50
	whistle()
	go(.Result) // shows the coin toss
}

whistle :: proc() {
	gfx.tone(2100, 90, .Sine, 0.05)
	gfx.tone(2300, 160, .Sine, 0.05, 110)
}

// What comes after a result: the next decision, by whoever makes it.
next :: proc() {
	g := &app.g
	app.off_tempo = .Normal
	app.def_tempo = .Normal
	switch g.phase {
	case .Over:
		record()
		go(.Over)
	case .Kickoff:
		go(.Kickoff)
	case .Scrimmage:
		if human(g.possession) {
			go(.Offence)
		} else {
			app.call.play, app.off_tempo = ez.cpu_offense(g)
			after_offence()
		}
	}
}

after_offence :: proc() {
	g := &app.g
	app.call.off_tempo = app.off_tempo
	def := ez.other(g.possession)
	if app.call.play == .Field_Goal {
		// The defense has nothing to choose against a kick.
		app.call.def_tempo = .Normal
		snap()
		return
	}
	if human(def) {
		go(app.mode == .Two_Players ? .Hand_Over : .Defence)
		return
	}
	app.call.defense, app.def_tempo = ez.cpu_defense(g)
	app.call.punt = ez.cpu_punt_choice(g)
	app.call.def_tempo = app.def_tempo
	snap()
}

snap :: proc() {
	ez.snap(&app.g, app.call)
	app.anim = 0
	sounds()
	go(.Result)
}

kick :: proc(c: ez.Kick_Choice) {
	ez.kickoff(&app.g, c)
	app.anim = 0
	gfx.noise(60, 0.12)
	gfx.tone(180, 60, .Square, 0.05)
	sounds()
	go(.Result)
}

sounds :: proc() {
	ev := app.g.events
	if .Touchdown in ev {
		for f, i in ([?]f32{392, 523, 659, 784, 659, 784}) {gfx.tone(f, 120, .Square, 0.05, 300 + f32(i) * 110)}
	} else if .Field_Goal in ev {
		for f, i in ([?]f32{523, 659, 784}) {gfx.tone(f, 120, .Triangle, 0.06, 300 + f32(i) * 110)}
	} else if .Safety in ev {
		gfx.tone(330, 200, .Square, 0.05, 300)
		gfx.tone(330, 200, .Square, 0.05, 560)
	} else if .Turnover in ev {
		gfx.tone(220, 140, .Saw, 0.05, 300)
		gfx.tone(165, 200, .Saw, 0.05, 450)
	} else if .Big_Play in ev {
		gfx.noise(700, 0.08, 200)
	} else if .First_Down in ev {
		gfx.tone(880, 70, .Triangle, 0.05, 300)
	}
	if .Penalty in ev {gfx.tone(1900, 300, .Sine, 0.04, 100)}
	if .Two_Minute in ev || .Quarter_Over in ev || .Half_Time in ev || .Game_Over in ev {
		gfx.tone(220, 500, .Square, 0.05, 700) // the horn
	}
	gfx.noise(80, 0.1) // the snap, the crunch
}

record :: proc() {
	if app.mode != .Versus_Computer {return}
	g := &app.g
	switch {
	case g.score[ez.HOME] > g.score[ez.VISITORS]:
		app.wins += 1
	case g.score[ez.HOME] < g.score[ez.VISITORS]:
		app.losses += 1
	case:
		app.ties += 1
	}
	gfx.store_set("record", fmt.tprintf("%d %d %d", app.wins, app.losses, app.ties))
}

press :: proc(id: int) {
	g := &app.g
	switch app.step {
	case .Title:
		if id == ID_TWO {start(.Two_Players)}
		if id == ID_CPU {start(.Versus_Computer)}
	case .Kickoff:
		if human(g.kicker) {
			if id == ID_DEEP {kick(.Deep)}
			if id == ID_ONSIDE {kick(.Onside)}
		} else if id == ID_NEXT || id == ID_DEEP {
			kick(ez.cpu_kick_choice(g))
		}
	case .Offence:
		switch {
		case id >= ID_PLAY && id < ID_PLAY + len(ez.Play):
			app.call.play = ez.Play(id - ID_PLAY)
			gfx.tone(660, 30, .Square, 0.04)
			after_offence()
		case id >= ID_TEMPO && id < ID_TEMPO + len(ez.Tempo):
			tm := ez.Tempo(id - ID_TEMPO)
			if tm == .Time_Out && g.timeouts[g.possession] == 0 {break}
			app.off_tempo = tm
			gfx.tone(500, 20, .Square, 0.03)
		}
	case .Hand_Over:
		if id == ID_READY {go(.Defence)}
	case .Defence:
		def := ez.other(g.possession)
		switch {
		case app.call.play == .Punt && id >= ID_PUNT && id < ID_PUNT + len(ez.Punt_Choice):
			app.call.punt = ez.Punt_Choice(id - ID_PUNT)
			app.call.def_tempo = app.def_tempo
			snap()
		case app.call.play != .Punt && id >= ID_DEF && id < ID_DEF + len(ez.Defense):
			app.call.defense = ez.Defense(id - ID_DEF)
			app.call.def_tempo = app.def_tempo
			snap()
		case id >= ID_TEMPO && id < ID_TEMPO + len(ez.Tempo):
			tm := ez.Tempo(id - ID_TEMPO)
			if tm == .Quick_Huddle {break}
			if tm == .Time_Out && g.timeouts[def] == 0 {break}
			app.def_tempo = tm
			gfx.tone(500, 20, .Square, 0.03)
		}
	case .Result:
		if id == ID_NEXT && app.t > 0.3 {next()}
	case .Over:
		if id == ID_AGAIN {start(app.mode)}
		if id == ID_MENU {go(.Title)}
	}
}

@(export)
step :: proc(dt: f64) -> bool {
	d := f32(min(dt, 0.1))
	app.t += d
	app.anim += d
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
	if c == gfx.KEY_ESCAPE {
		go(.Title)
		return
	}
	enter := c == gfx.KEY_ENTER || c == gfx.KEY_SPACE
	switch app.step {
	case .Title:
		if c == '1' {press(ID_TWO)}
		if c == '2' {press(ID_CPU)}
	case .Kickoff:
		if c == 'D' || c == '1' || (enter && !human(app.g.kicker)) {press(ID_DEEP)}
		if c == 'O' || c == '2' {press(ID_ONSIDE)}
	case .Offence:
		if c >= 'A' && c < 'A' + len(ez.Play) {press(ID_PLAY + c - 'A')}
		if c >= '1' && c <= '4' {press(ID_TEMPO + c - '1')}
	case .Hand_Over:
		if enter {press(ID_READY)}
	case .Defence:
		if app.call.play == .Punt {
			if c >= 'A' && c < 'A' + len(ez.Punt_Choice) {press(ID_PUNT + c - 'A')}
		} else if c >= 'A' && c < 'A' + len(ez.Defense) {
			press(ID_DEF + c - 'A')
		}
		if c >= '1' && c <= '4' {press(ID_TEMPO + c - '1')}
	case .Result:
		if enter {press(ID_NEXT)}
	case .Over:
		if enter && app.t > 1 {press(ID_AGAIN)}
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
	gfx.clear(BG)
	gfx.begin_buttons()
	if app.step == .Title {
		draw_title()
		return
	}
	draw_field()
	draw_board()
	switch app.step {
	case .Title:
	case .Kickoff:
		draw_kickoff()
	case .Offence:
		draw_offence()
	case .Hand_Over:
		draw_hand_over()
	case .Defence:
		draw_defence()
	case .Result:
		draw_result()
	case .Over:
		draw_over()
	}
}

yard_x :: proc(fixed: int) -> int {return GOAL_X + fixed * YARD}

draw_field :: proc() {
	g := &app.g
	gfx.rect(FX, FY, 120 * YARD, FH, GRASS)
	for i in 0 ..< 10 {
		if i % 2 == 1 {gfx.rect(yard_x(i * 10), FY, 10 * YARD, FH, GRASS_DARK)}
	}
	gfx.rect(FX, FY, 10 * YARD, FH, HOME_COL)
	gfx.rect(yard_x(100), FY, 10 * YARD, FH, VIS_COL)
	gfx.text_c(FX + 20, FY + FH / 2 - 4, "HOME", CHALK)
	gfx.text_c(yard_x(100) + 20, FY + FH / 2 - 4, "VIS", CHALK)
	for yd := 0; yd <= 100; yd += 5 {
		x := yard_x(yd)
		major := yd % 10 == 0
		gfx.rect(x, FY, 1, FH, major ? CHALK : CHALK_DIM)
		if major && yd > 0 && yd < 100 {
			n := yd <= 50 ? yd : 100 - yd
			gfx.text_c(x + 1, FY + 3, fmt.tprintf("%d", n), CHALK)
		}
	}
	gfx.frame(FX, FY, 120 * YARD, FH, CHALK)
	// The ball, the line of scrimmage and the line to make.
	ball := ez.field_x(g.possession, clamp(g.ball, 0, 100))
	if g.phase == .Scrimmage && app.step != .Result {
		gfx.rect(yard_x(ball), FY + 1, 1, FH - 2, SCRIMMAGE)
		fd := ez.field_x(g.possession, clamp(g.ball + g.to_go, 0, 100))
		gfx.rect(yard_x(fd), FY + 1, 1, FH - 2, FIRST_DOWN)
	}
	bx := yard_x(ball)
	if app.step == .Result {
		k := min(1, app.anim / 0.7)
		bx = yard_x(g.from_x) + int(f32(yard_x(g.to_x) - yard_x(g.from_x)) * k)
	}
	if g.phase == .Kickoff && app.step != .Result {bx = yard_x(ez.field_x(g.kicker, g.free_kick ? 20 : 35))}
	by := FY + FH / 2 + 8
	gfx.rect(bx - 6, by - 2, 13, 5, 0x1a1a10)
	gfx.rect(bx - 4, by - 4, 9, 9, 0x1a1a10)
	gfx.rect(bx - 5, by - 1, 11, 3, BALL_COL)
	gfx.rect(bx - 3, by - 3, 7, 7, BALL_COL)
	gfx.rect(bx - 2, by, 5, 1, CHALK)
	for i in 0 ..< 3 {gfx.rect(bx - 2 + i * 2, by - 1, 1, 3, CHALK)}
	// Who's going which way.
	if g.phase == .Scrimmage {
		arrow := g.possession == ez.HOME ? ">" : "<"
		gfx.text_c(bx + (g.possession == ez.HOME ? 12 : -12), by - 3, arrow, g.possession == ez.HOME ? HOME_COL : VIS_COL)
	}
}

ordinal :: proc(n: int) -> string {
	switch n {
	case 1:
		return "1ST"
	case 2:
		return "2ND"
	case 3:
		return "3RD"
	}
	return "4TH"
}

clock_text :: proc(secs: int) -> string {
	return fmt.tprintf("%d:%02d", secs / 60, secs % 60)
}

BY :: FY + FH + 6

draw_board :: proc() {
	g := &app.g
	gfx.rect(FX, BY, 120 * YARD, 40, BOARD)
	gfx.frame(FX, BY, 120 * YARD, 40, BOARD_LINE)
	gfx.text(FX + 8, BY + 6, "HOME", HOME_COL)
	gfx.text(FX + 48, BY + 2, fmt.tprintf("%2d", g.score[ez.HOME]), LAMP, 2)
	gfx.text(FX + 92, BY + 6, "VISITORS", VIS_COL)
	gfx.text(FX + 164, BY + 2, fmt.tprintf("%2d", g.score[ez.VISITORS]), LAMP, 2)
	qtr := g.phase == .Over ? "FINAL" : fmt.tprintf("QTR %d", g.quarter)
	gfx.text(FX + 220, BY + 6, qtr, DIM)
	gfx.text(FX + 276, BY + 2, clock_text(g.clock), LAMP, 2)
	gfx.text(FX + 368, BY + 6, fmt.tprintf("T.O. %d-%d", g.timeouts[ez.HOME], g.timeouts[ez.VISITORS]), DIM)
	line: string
	buf: [32]u8
	switch g.phase {
	case .Scrimmage:
		dist := g.ball + g.to_go >= 100 ? "GOAL" : fmt.tprintf("%d", g.to_go)
		line = fmt.tprintf("%s BALL, %s & %s ON THE %s", ez.team_name(g.possession), ordinal(g.down), dist, ez.spot_name(g, buf[:]))
	case .Kickoff:
		line = fmt.tprintf("%s %s", ez.team_name(g.kicker), g.free_kick ? "FREE KICK FROM THE 20" : "TO KICK OFF")
	case .Over:
		line = "THE GAME IS OVER"
	}
	gfx.text(FX + 8, BY + 26, line, TEXT)
}

LY :: BY + 46 // the play-by-play
AY :: LY + 64 // the area for calls

draw_log :: proc(y: int) {
	g := &app.g
	for i in 0 ..< g.log_n {
		c: u32 = i == g.log_n - 1 ? TEXT : DIM
		gfx.text(FX + 4, y + i * 11, ez.log_line(g, i), c)
	}
}

choice :: proc(x, y, w: int, key, label: string, id: int, on := false, enabled := true) {
	h := 15
	bg: u32 = on ? BTN_ON : BTN
	gfx.rect(x, y, w, h, bg)
	gfx.frame(x, y, w, h, on ? LAMP : BOARD_LINE)
	fg: u32 = enabled ? TEXT : 0x50544c
	gfx.text(x + 4, y + 4, key, enabled ? LAMP : 0x50544c)
	gfx.text(x + 4 + gfx.text_width(key) + 6, y + 4, label, fg)
	if enabled {gfx.zone(x, y, w, h, id)}
}

TEMPO_NAMES := [ez.Tempo]string {
	.Normal       = "NORMAL",
	.Quick_Huddle = "QUICK HUDDLE",
	.Slow_Down    = "SLOW DOWN",
	.Time_Out     = "TIME OUT",
}

draw_tempos :: proc(y: int, team: int, offence: bool, current: ez.Tempo) {
	g := &app.g
	x := FX
	gfx.text(x, y + 4, "TIME:", DIM)
	x += 48
	for tm in ez.Tempo {
		if !offence && tm == .Quick_Huddle {continue}
		label := TEMPO_NAMES[tm]
		ok := true
		if tm == .Time_Out {
			label = fmt.tprintf("TIME OUT %d", g.timeouts[team])
			ok = g.timeouts[team] > 0
		}
		w := gfx.text_width(label) + 24
		key := fmt.tprintf("%d", int(tm) + 1)
		choice(x, y, w, key, label, ID_TEMPO + int(tm), current == tm, ok)
		x += w + 4
	}
}

draw_offence :: proc() {
	g := &app.g
	y := LY
	gfx.text(FX, y, fmt.tprintf("%s, CALL YER PLAY.", ez.team_name(g.possession)), g.possession == ez.HOME ? HOME_COL : VIS_COL)
	if app.mode == .Two_Players {
		gfx.text(FX + 220, y, fmt.tprintf("(%s, LOOK AWAY!)", ez.team_name(ez.other(g.possession))), DIM)
	}
	y += 14
	for p, i in ez.Play {
		col := i < 6 ? 0 : 1
		row := i < 6 ? i : i - 6
		key := fmt.tprintf("%c", 'A' + i)
		label := ez.PLAY_NAMES[p]
		if p == .Field_Goal {label = fmt.tprintf("FIELD GOAL (%d%%)", ez.field_goal_pct(g.ball))}
		choice(FX + col * 242, y + row * 17, 236, key, label, ID_PLAY + i)
	}
	draw_tempos(H - 20, g.possession, true, app.off_tempo)
}

draw_hand_over :: proc() {
	g := &app.g
	def := ez.other(g.possession)
	gfx.rect(FX + 60, LY + 10, 120 * YARD - 120, 120, BOARD)
	gfx.frame(FX + 60, LY + 10, 120 * YARD - 120, 120, LAMP)
	gfx.text_c(W / 2, LY + 26, "THE PLAY IS CALLED.", TEXT, 2)
	gfx.text_c(W / 2, LY + 56, fmt.tprintf("HAND OVER TO %s.", ez.team_name(def)), def == ez.HOME ? HOME_COL : VIS_COL)
	gfx.text_c(W / 2, LY + 70, fmt.tprintf("(%s, NO PEEKING AT THEIR PICK.)", ez.team_name(g.possession)), DIM)
	gfx.button(W / 2 - 44, LY + 92, "DEFENSE READY", ID_READY, TEXT, BTN)
}

PUNT_NAMES := [ez.Punt_Choice]string {
	.Return     = "COVER THE RETURN",
	.Block      = "TRY TO BLOCK IT",
	.Fair_Catch = "FAIR CATCH",
}

draw_defence :: proc() {
	g := &app.g
	def := ez.other(g.possession)
	y := LY
	col: u32 = def == ez.HOME ? HOME_COL : VIS_COL
	if app.call.play == .Punt {
		gfx.text(FX, y, fmt.tprintf("%s LINE UP TO PUNT. %s, WHAT'LL IT BE?", ez.team_name(g.possession), ez.team_name(def)), col)
		for pc, i in ez.Punt_Choice {
			choice(FX, y + 16 + i * 17, 236, fmt.tprintf("%c", 'A' + i), PUNT_NAMES[pc], ID_PUNT + i)
		}
	} else {
		gfx.text(FX, y, fmt.tprintf("%s, SET YER DEFENSE.", ez.team_name(def)), col)
		if !human(g.possession) {gfx.text(FX + 220, y, "(THE COMPUTER HAS CALLED ITS PLAY)", DIM)}
		y += 14
		for d, i in ez.Defense {
			c := i < 5 ? 0 : 1
			row := i < 5 ? i : i - 5
			choice(FX + c * 242, y + row * 17, 236, fmt.tprintf("%c", 'A' + i), ez.DEFENSE_NAMES[d], ID_DEF + i)
		}
	}
	draw_tempos(H - 20, def, false, app.def_tempo)
}

draw_kickoff :: proc() {
	g := &app.g
	draw_log(LY)
	k := g.kicker
	if human(k) {
		gfx.text(FX, AY + 6, fmt.tprintf("%s, HOW WILL YOU KICK?", ez.team_name(k)), k == ez.HOME ? HOME_COL : VIS_COL)
		choice(FX, AY + 22, 200, "D", "DEEP KICK", ID_DEEP)
		choice(FX + 210, AY + 22, 200, "O", "ONSIDE KICK", ID_ONSIDE)
	} else {
		gfx.text(FX, AY + 6, fmt.tprintf("%s WILL KICK OFF.", ez.team_name(k)), VIS_COL)
		gfx.button(FX, AY + 22, "KICK IT (SPACE)", ID_NEXT, TEXT, BTN)
	}
}

draw_result :: proc() {
	draw_log(LY)
	if app.t > 0.3 {
		gfx.button(W - 16 - gfx.text_width("NEXT (SPACE)") - 8, H - 24, "NEXT (SPACE)", ID_NEXT, TEXT, BTN)
	}
}

draw_over :: proc() {
	g := &app.g
	draw_log(LY)
	h, v := g.score[ez.HOME], g.score[ez.VISITORS]
	msg := h == v ? "A TIE." : (h > v ? "HOME WINS!" : "VISITORS WIN!")
	if app.mode == .Versus_Computer {
		msg = h == v ? "A TIE WITH THE COMPUTER." : (h > v ? "YOU BEAT THE COMPUTER!" : "THE COMPUTER WINS.")
		gfx.text(FX, H - 44, fmt.tprintf("YER RECORD: %d WON, %d LOST, %d TIED", app.wins, app.losses, app.ties), DIM)
	}
	gfx.text(FX, AY + 4, msg, LAMP, 2)
	if app.t > 1 {
		gfx.button(W - 200, H - 24, "PLAY AGAIN", ID_AGAIN, TEXT, BTN)
		gfx.button(W - 92, H - 24, "TITLE", ID_MENU, DIM, BTN)
	}
}

// The title in big round letters, as the listing printed it in O's.
BIG := [5]string {
	"OOOOO O   O OOOO      OOOOO  OOO  O   O OOOOO",
	"O     OO  O O   O        O  O   O OO  O O    ",
	"OOOO  O O O O   O       O   O   O O O O OOOO ",
	"O     O  OO O   O      O    O   O O  OO O    ",
	"OOOOO O   O OOOO      OOOOO  OOO  O   O OOOOO",
}

draw_title :: proc() {
	cell := 10
	ox := W / 2 - len(BIG[0]) * cell / 2
	for row, j in BIG {
		for i in 0 ..< len(row) {
			if row[i] == 'O' {
				x := ox + i * cell
				y := 40 + j * cell
				lit := (i + j + int(app.t * 6)) % 11 == 0
				c: u32 = lit ? 0xffffff : LAMP
				gfx.rect(x + 2, y + 1, 5, 7, c)
				gfx.rect(x + 1, y + 2, 7, 5, c)
				gfx.rect(x + 3, y + 3, 3, 3, BG)
			}
		}
	}
	lines := [?]string {
		"FOUR 15-MINUTE QUARTERS OF FOOTBALL.",
		"THE OFFENSE CALLS ONE OF ELEVEN PLAYS IN SECRET,",
		"THE DEFENSE ONE OF TEN ALIGNMENTS. THE MATCH-UP",
		"DECIDES THE YARDAGE. WATCH THE CLOCK.",
		"",
		"TWO PLAYERS: SEND YER OPPONENT FOR COFFEE",
		"WHILE YOU PICK.",
	}
	for l, i in lines {gfx.text_c(W / 2, 108 + i * 12, l, i >= 5 ? DIM : TEXT)}
	gfx.button(W / 2 - 170, 204, "1  TWO PLAYERS", ID_TWO, TEXT, BTN)
	gfx.button(W / 2 + 10, 204, "2  YOU VS. COMPUTER", ID_CPU, TEXT, BTN)
	if app.wins + app.losses + app.ties > 0 {
		gfx.text_c(W / 2, 236, fmt.tprintf("AGAINST THE COMPUTER: %d-%d-%d", app.wins, app.losses, app.ties), DIM)
	}
	gfx.text_c(W / 2, 260, "KEYS: LETTERS PICK, 1-4 TIME MANEUVERS, SPACE GOES ON", DIM)
	gfx.text_c(W / 2, H - 18, "AFTER ROGER ROBITAILLE, SOFTSIDE 1978", DIM)
}
