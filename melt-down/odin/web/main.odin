#+build js
package main

// Melt Down's page: screens, drawing, keys and taps. Rules are in ../game.

import "base:runtime"
import "core:fmt"
import "core:strconv"
import game "../game"
import "proto:gfx"

W :: 576
H :: 320

// Palette: a dark control room with amber text.
BG :: 0x10140f
PANEL :: 0x1a2118
LINE :: 0x3d4a37
TEXT :: 0xe8d9a8
DIM :: 0x8f8a6e
GOOD :: 0x6fd36a
BAD :: 0xf05a4a
WARN :: 0xf0b13a
BAND :: 0x24402a

Screen :: enum {
	Title,
	Playing,
	Help,
	Over,
}

Stage :: enum {
	Idle,
	Sign, // waiting for + or -
	Amount, // waiting for a digit
	Confirm, // scram: Y or N
}

App :: struct {
	screen:     Screen,
	g:          game.Game,
	skill:      int,
	stage:      Stage,
	pending:    game.Command,
	sign:       int,
	best:       [6]int, // best seconds per level, 0 = none
	over_t:     f32, // seconds on the Over screen
	blink:      f32,
	help_from:  Screen,
}

app: App

// Button ids: 1..5 levels, 100+ commands, 200+ digits, others below.
ID_PLUS :: 300
ID_MINUS :: 301
ID_CANCEL :: 302
ID_YES :: 303
ID_HELP :: 304
ID_BACK :: 305
ID_AGAIN :: 306
ID_MENU :: 307

KEYS := [game.Command]u8 {
	.None    = 0,
	.Valve   = 'V',
	.Rods    = 'C',
	.Coolant = 'E',
	.Fuel    = 'P',
	.Scram   = 'S',
	.Flood   = 'O',
	.Turbine = 'T',
}

LABELS := [game.Command]string {
	.None    = "",
	.Valve   = "V VALVE",
	.Rods    = "C RODS",
	.Coolant = "E COOL",
	.Fuel    = "P FUEL",
	.Scram   = "S SCRAM",
	.Flood   = "O WATER",
	.Turbine = "T TURB",
}

main :: proc() {
	app.skill = 1
	load_best()
}

load_best :: proc() {
	buf: [32]u8
	for lv in 1 ..= 5 {
		key := fmt.tprintf("best-%d", lv)
		if v, ok := gfx.store_get(key, buf[:]); ok {
			if n, nok := strconv.parse_int(v); nok && n > 0 && n < 100000 {
				app.best[lv] = n
			}
		}
	}
}

start :: proc(skill: int) {
	app.skill = skill
	d := int(gfx.random() * f64(len(game.DISASTERS)))
	game.new_game(&app.g, clamp(d, 0, len(game.DISASTERS) - 1), skill)
	app.stage = .Idle
	app.pending = .None
	app.screen = .Playing
	gfx.tone(330, 120, .Square, 0.06)
	gfx.tone(440, 160, .Square, 0.06, 140)
}

@(export)
step :: proc(dt: f64) -> bool {
	d := f32(min(dt, 0.25))
	app.blink += d
	if app.screen == .Playing {
		game.update(&app.g, d)
		sounds()
		if app.g.state != .Running {
			finish()
		}
	} else if app.screen == .Over {
		app.over_t += d
	}
	draw()
	free_all(context.temp_allocator)
	return true
}

finish :: proc() {
	app.screen = .Over
	app.over_t = 0
	app.stage = .Idle
	if app.g.state == .Won {
		secs := int(app.g.clock + 0.5)
		if app.best[app.skill] == 0 || secs < app.best[app.skill] {
			app.best[app.skill] = secs
			gfx.store_set(fmt.tprintf("best-%d", app.skill), fmt.tprintf("%d", secs))
		}
	}
}

sounds :: proc() {
	ev := app.g.events
	app.g.events = {}
	if .Tick in ev {
		if app.g.m[.Core_Temp] >= 7 {
			gfx.tone(880, 90, .Square, 0.07)
			gfx.tone(880, 90, .Square, 0.07, 160)
		} else {
			gfx.tone(200, 35, .Square, 0.05)
		}
	}
	if .Command in ev {gfx.tone(660, 40, .Square, 0.05)}
	if .Refused in ev {gfx.tone(110, 250, .Saw, 0.07)}
	if .Burst in ev {
		gfx.noise(700, 0.25)
		gfx.tone(90, 500, .Saw, 0.08)
	}
	if .Won in ev {
		notes := [?]f32{523, 659, 784, 1047}
		for f, i in notes {gfx.tone(f, 140, .Square, 0.06, f32(i) * 150)}
	}
	if .Lost in ev {
		for i in 0 ..< 6 {
			gfx.tone(i % 2 == 0 ? 880 : 660, 220, .Saw, 0.07, f32(i) * 240)
		}
		gfx.noise(1500, 0.2, 1450)
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
	if id >= 0 {press(id)}
}

key :: proc(code: int) {
	switch app.screen {
	case .Title:
		if code >= '1' && code <= '5' {start(code - '0')}
		if code == gfx.KEY_ENTER || code == gfx.KEY_SPACE {start(app.skill)}
		if code == 'I' {
			app.help_from = .Title
			app.screen = .Help
		}
	case .Help:
		app.screen = app.help_from
	case .Over:
		if app.over_t < 0.8 {return}
		if code == gfx.KEY_ENTER || code == gfx.KEY_SPACE || code == 'Y' {start(app.skill)}
		if code == gfx.KEY_ESCAPE || code == 'N' {app.screen = .Title}
	case .Playing:
		playing_key(code)
	}
}

playing_key :: proc(code: int) {
	switch app.stage {
	case .Idle:
		if code == 'I' {
			app.help_from = .Playing
			app.screen = .Help
			return
		}
		for k, c in KEYS {
			if k != 0 && int(k) == code {choose(c)}
		}
	case .Sign:
		if code == '+' || code == '=' {
			app.sign = 1
			app.stage = .Amount
		} else if code == '-' || code == '_' {
			app.sign = -1
			app.stage = .Amount
		} else if code == gfx.KEY_ESCAPE {
			cancel()
		}
	case .Amount:
		lo, hi, _ := game.amount_range(app.pending)
		if code >= '0' && code <= '9' {
			n := code - '0'
			if n < lo || n > hi {
				gfx.tone(110, 120, .Saw, 0.06)
				return
			}
			game.command(&app.g, app.pending, n * app.sign)
			cancel()
		} else if code == gfx.KEY_ESCAPE {
			cancel()
		}
	case .Confirm:
		if code == 'Y' {
			game.command(&app.g, .Scram, 0)
		}
		cancel()
	}
}

choose :: proc(c: game.Command) {
	app.pending = c
	app.sign = 1
	if c == .Scram {
		app.stage = .Confirm
		return
	}
	_, _, signed := game.amount_range(c)
	app.stage = signed ? .Sign : .Amount
	gfx.tone(520, 25, .Square, 0.04)
}

cancel :: proc() {
	app.stage = .Idle
	app.pending = .None
}

press :: proc(id: int) {
	switch {
	case id >= 1 && id <= 5:
		key('0' + id)
	case id >= 100 && id < 100 + len(game.Command):
		if app.stage == .Idle {choose(game.Command(id - 100))}
	case id >= 200 && id <= 209:
		key('0' + id - 200)
	case id == ID_PLUS:
		key('+')
	case id == ID_MINUS:
		key('-')
	case id == ID_CANCEL:
		key(gfx.KEY_ESCAPE)
	case id == ID_YES:
		key('Y')
	case id == ID_HELP:
		key('I')
	case id == ID_BACK:
		key(gfx.KEY_ESCAPE)
	case id == ID_AGAIN:
		key(gfx.KEY_ENTER)
	case id == ID_MENU:
		key(gfx.KEY_ESCAPE)
	}
}

// ---- drawing ----

draw :: proc() {
	gfx.clear(BG)
	gfx.begin_buttons()
	switch app.screen {
	case .Title:
		draw_title()
	case .Playing:
		draw_plant()
	case .Help:
		draw_help()
	case .Over:
		draw_over()
	}
}

draw_title :: proc() {
	gfx.text_c(W / 2, 28, "MELT DOWN", WARN, 4)
	gfx.text_c(W / 2, 70, "A NUCLEAR REACTOR TEST", TEXT)
	lines := [?]string {
		"YOU ARE THE OPERATOR OF A NUCLEAR POWER PLANT. A DISASTER",
		"HAS STRUCK. BRING EVERY METER BACK TO 5 -- RADIATION LOW,",
		"EMERGENCY CORE COOLING HIGH -- BEFORE THE CORE REACHES 9.",
		"EVERY 3 SECONDS THE PLANT MOVES. EVERY COMMAND HELPS ONE",
		"THING AND HURTS ANOTHER. PRESS I FOR THE COMMAND LIST.",
	}
	for l, i in lines {gfx.text(24, 96 + i * 12, l, DIM)}
	gfx.text_c(W / 2, 170, "CHOOSE A LEVEL (1-5)", TEXT)
	x := 24
	for lv in 1 ..= 5 {
		label := fmt.tprintf("%d %s", lv, game.SKILL_NAMES[lv])
		w := gfx.button(x, 186, label, lv, lv == app.skill ? WARN : TEXT, PANEL)
		best := app.best[lv] > 0 ? fmt.tprintf("BEST %ds", app.best[lv]) : "--"
		gfx.text(x + 4, 206, best, DIM)
		x += w + 8
	}
	gfx.button(24, 236, "I COMMANDS", ID_HELP, TEXT, PANEL)
	gfx.text(24, 284, "AFTER \"MELT DOWN\" BY MICHAEL WINTER, SOFTSIDE, AUGUST 1979", DIM)
	gfx.text(24, 296, "A SOFTSIDE PROTOTYPE BY THEGRUMPYGAMEDEV", DIM)
}

HELP_ROWS := [?][3]string {
	{"O WATER", "COOLS THE CORE", "RAISES WATER PRESSURE"},
	{"V VALVE", "LOWERS WATER PRESSURE", "RAISES CORE TEMP"},
	{"S SCRAM", "LOWERS CORE TEMP", "STOPS THE TURBINE"},
	{"C + RODS", "SPEEDS UP THE TURBINE", "RAISES CORE TEMP"},
	{"C - RODS", "LOWERS CORE TEMP", "SLOWS THE TURBINE"},
	{"E COOL", "LOWERS CORE TEMP", "USES EMR CORE COOLING"},
	{"P + FUEL", "RAISES CRITICAL MASS", "SLOWS THE TURBINE"},
	{"P - FUEL", "LOWERS CRITICAL MASS", "RAISES CORE TEMP"},
	{"T + TURB", "SPEEDS UP THE TURBINE", "RAISES CORE TEMP"},
	{"T - TURB", "SLOWS THE TURBINE", "RAISES WATER PRESSURE"},
}

draw_help :: proc() {
	gfx.text(16, 12, "COMMANDS", WARN, 2)
	gfx.text(16, 40, "COMMAND", DIM)
	gfx.text(112, 40, "ADVANTAGE", DIM)
	gfx.text(320, 40, "DISADVANTAGE", DIM)
	for r, i in HELP_ROWS {
		y := 56 + i * 14
		gfx.text(16, y, r[0], TEXT)
		gfx.text(112, y, r[1], GOOD)
		gfx.text(320, y, r[2], BAD)
	}
	notes := [?]string {
		"V 2-8 OPENS THE MAIN DUMP VALVE. O 1-9 FLOODS THE CORE.",
		"C +/- 1-9 MOVES THE RODS. P +/- 1-9: EACH UNIT IS HALF A POINT.",
		"E 1-9 SPENDS COOLANT YOU HAVE. T 1-9 SETS THE TURBINE (10-90%).",
		"S ASKS YOU TO CONFIRM. WATER PRESSURE AT 9 BURSTS THE PIPES.",
		"EVERYTHING AFFECTS EVERYTHING ELSE. ESC CANCELS A COMMAND.",
	}
	for n, i in notes {gfx.text(16, 208 + i * 12, n, DIM)}
	gfx.button(16, 284, "ANY KEY TO RETURN", ID_BACK, TEXT, PANEL)
}

BOX_W :: 184
BOX_H :: 62

draw_plant :: proc() {
	g := &app.g
	gfx.text(8, 6, "MELT DOWN", WARN)
	gfx.text(96, 6, fmt.tprintf("LEVEL %d %s", app.skill, game.SKILL_NAMES[app.skill]), DIM)
	gfx.text(W - 8 - gfx.text_width("TIME 0000"), 6, fmt.tprintf("TIME %4d", int(g.clock)), TEXT)

	for k, i in game.Meter {
		col := int(i) % 3
		row := int(i) / 3
		draw_meter(8 + col * (BOX_W + 8), 20 + row * (BOX_H + 6), k)
	}

	y := 20 + 3 * (BOX_H + 6) + 2
	gfx.text(8, y, "THE EVENT IS -", DIM)
	gfx.text(128, y, game.DISASTERS[g.disaster].name, BAD)
	gfx.text(8, y + 12, g.message, g.burst_ticks > 0 ? BAD : TEXT)
	// Time to the next plant check.
	frac := 1 - g.until_tick / game.TICK_SECONDS
	gfx.text(8, y + 24, "NEXT CHECK", DIM)
	gfx.rect(96, y + 25, 120, 6, PANEL)
	gfx.rect(96, y + 25, int(120 * clamp(frac, 0, 1)), 6, g.m[.Core_Temp] >= 7 ? BAD : WARN)
	draw_prompt(232, y + 24)

	draw_command_row(H - 22)
}

draw_meter :: proc(x, y: int, k: game.Meter) {
	g := &app.g
	v := g.m[k]
	ok := game.in_band(g, k)
	gfx.rect(x, y, BOX_W, BOX_H, PANEL)
	gfx.frame(x, y, BOX_W, BOX_H, LINE)
	gfx.text(x + 6, y + 5, game.METER_NAMES[k], TEXT)
	gfx.text(x + BOX_W - 6 - gfx.text_width("0.0"), y + 5, fmt.tprintf("%.1f", v), ok ? GOOD : BAD)

	// Scale 1..9 across, with the safe band shaded.
	tx := x + 12
	tw := BOX_W - 24
	ty := y + 26
	pos :: proc(tx, tw: int, v: f32) -> int {return tx + int((v - 1) / 8 * f32(tw))}
	s := game.SKILLS[app.skill]
	lo, hi: f32
	#partial switch k {
	case .Radiation:
		lo, hi = 1, s.rad_max
	case .Coolant:
		lo, hi = s.cool_min, 9
	case:
		lo, hi = 5 - s.band, 5 + s.band
	}
	b0 := pos(tx, tw, max(lo, 1))
	b1 := pos(tx, tw, min(hi, 9))
	gfx.rect(b0, ty - 4, max(b1 - b0, 2), 14, BAND)
	gfx.rect(tx, ty + 2, tw, 2, LINE)
	for n in 1 ..= 9 {
		px := pos(tx, tw, f32(n))
		gfx.rect(px, ty, 1, 6, LINE)
		gfx.text(px - 3, ty + 14, fmt.tprintf("%d", n), DIM)
	}
	mx := pos(tx, tw, clamp(v, 1, 9))
	c: u32 = ok ? GOOD : BAD
	if k == .Core_Temp && v >= 7 && int(app.blink * 4) % 2 == 0 {c = WARN}
	gfx.rect(mx - 2, ty - 6, 5, 14, c)
}

draw_prompt :: proc(x, y: int) {
	q: string
	switch app.stage {
	case .Idle:
		if int(app.blink * 2) % 2 == 0 {q = "COMMAND? _"} else {q = "COMMAND?"}
	case .Sign:
		q = app.pending == .Rods ? "RAISE (+) OR LOWER (-) THE RODS?" : "ADD (+) OR REMOVE (-) FUEL?"
	case .Amount:
		lo, hi, _ := game.amount_range(app.pending)
		what: string
		#partial switch app.pending {
		case .Valve:
			what = "OPEN THE MAIN VALVE HOW FAR"
		case .Rods:
			what = app.sign > 0 ? "RAISE THE RODS HOW FAR" : "LOWER THE RODS HOW FAR"
		case .Fuel:
			what = app.sign > 0 ? "FUEL UNITS TO ADD" : "FUEL UNITS TO REMOVE"
		case .Coolant:
			what = "COOLANT TO RELEASE"
		case .Flood:
			what = "WATER INTO THE CORE"
		case .Turbine:
			what = "TURBINE SPEED"
		}
		q = fmt.tprintf("%s (%d-%d)?", what, lo, hi)
	case .Confirm:
		q = "VERIFY REACTOR SCRAM (Y/N)?"
	}
	gfx.text(x, y, q, WARN)
}

draw_command_row :: proc(y: int) {
	x := 8
	switch app.stage {
	case .Idle:
		for c in game.Command {
			if c == .None {continue}
			x += gfx.button(x, y, LABELS[c], 100 + int(c), TEXT, PANEL) + 4
		}
		gfx.button(x, y, "I HELP", ID_HELP, DIM, PANEL)
	case .Sign:
		x += gfx.button(x, y, "+ RAISE/ADD", ID_PLUS, TEXT, PANEL) + 4
		x += gfx.button(x, y, "- LOWER/REMOVE", ID_MINUS, TEXT, PANEL) + 4
		gfx.button(x, y, "ESC", ID_CANCEL, DIM, PANEL)
	case .Amount:
		lo, hi, _ := game.amount_range(app.pending)
		for n in lo ..= hi {
			x += gfx.button(x, y, fmt.tprintf(" %d ", n), 200 + n, TEXT, PANEL) + 4
		}
		gfx.button(x, y, "ESC", ID_CANCEL, DIM, PANEL)
	case .Confirm:
		x += gfx.button(x, y, "Y SCRAM", ID_YES, BAD, PANEL) + 4
		gfx.button(x, y, "N CANCEL", ID_CANCEL, DIM, PANEL)
	}
}

draw_over :: proc() {
	g := &app.g
	t := app.over_t
	if g.state == .Lost {
		if t < 2.4 {
			if int(t * 4) % 2 == 0 {
				gfx.clear(0x3a0c08)
				gfx.text_c(W / 2, H / 2 - 16, "DANGER - DANGER - DANGER", BAD, 2)
			}
			return
		}
		gfx.text_c(W / 2, 40, "MELTDOWN", BAD, 4)
		lines := [?]string {
			"THE CORE TEMPERATURE PASSED THE POINT OF NO RETURN.",
			"THE CONTAINMENT LOG HAS STARTED. EVACUATE EVERYONE",
			"WITHIN 250 MILES -- NOW.",
			"",
			"AND YOU ARE FIRED.",
		}
		for l, i in lines {gfx.text_c(W / 2, 100 + i * 14, l, TEXT)}
		gfx.text_c(W / 2, 186, fmt.tprintf("THE EVENT WAS: %s", game.DISASTERS[g.disaster].name), DIM)
	} else {
		head := fmt.tprintf("EVENT OVER -- EVENT DURATION: %d SECONDS", int(g.clock + 0.5))
		shown := min(len(head), int(t * 30))
		gfx.text_c(W / 2, 40, head[:shown], GOOD)
		if t > 1.6 {
			gfx.text_c(W / 2, 70, "UNDER CONTROL", GOOD, 3)
			lines := [?]string {
				"YOU HAVE DONE IT!! THE REACTOR IS STABLE.",
				"THE REGULATORS WILL HEAR ABOUT THIS -- IN A GOOD WAY.",
			}
			for l, i in lines {gfx.text_c(W / 2, 120 + i * 14, l, TEXT)}
			best := app.best[app.skill]
			gfx.text_c(W / 2, 166, fmt.tprintf("LEVEL %d %s -- BEST %d SECONDS", app.skill, game.SKILL_NAMES[app.skill], best), DIM)
		}
	}
	if t > 0.8 {
		gfx.text_c(W / 2, 220, "PLAY AGAIN?", TEXT)
		gfx.button(W / 2 - 120, 240, "Y AGAIN", ID_AGAIN, TEXT, PANEL)
		gfx.button(W / 2 + 20, 240, "N MENU", ID_MENU, DIM, PANEL)
	}
}
