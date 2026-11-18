#+build js
package main

// Calculator's page: the tape, the display, the keypad and the keys. Rules are in ../game.

import "base:runtime"
import "core:fmt"
import "core:strconv"
import calc "../game"
import "proto:gfx"

W :: 512
H :: 288

CASE :: 0x2b2a27
CASE_LIT :: 0x3b3934
PAPER :: 0xf3edda
PAPER_LINE :: 0xd9d0b4
INK :: 0x2a2a3a
INK_RED :: 0xb8322a
LCD :: 0x9fb08a
LCD_DARK :: 0x8a9a76
LCD_INK :: 0x1f2a1c
KEY :: 0x4a4740
KEY_FN :: 0x6b4a2a
KEY_GO :: 0x2f5a3a
KEY_TEXT :: 0xf0ead8
DIM :: 0xa8a090

Pad_Key :: struct {
	label: string,
	ch:    u8, // what it types or presses
	col:   int,
	row:   int,
	kind:  int, // 0 digit, 1 function, 2 enter/clear
}

// ch: digits and '.', '-' type; letters press their function; '\r' Enter; 'C' clear; '\b' backspace.
PAD := [?]Pad_Key {
	{"7", '7', 0, 0, 0}, {"8", '8', 1, 0, 0}, {"9", '9', 2, 0, 0}, {"A +", 'A', 3, 0, 1},
	{"4", '4', 0, 1, 0}, {"5", '5', 1, 1, 0}, {"6", '6', 2, 1, 0}, {"S -", 'S', 3, 1, 1},
	{"1", '1', 0, 2, 0}, {"2", '2', 1, 2, 0}, {"3", '3', 2, 2, 0}, {"M X", 'M', 3, 2, 1},
	{"0", '0', 0, 3, 0}, {".", '.', 1, 3, 0}, {"-", '_', 2, 3, 0}, {"D /", 'D', 3, 3, 1},
	{"H MEM", 'H', 4, 0, 1}, {"N RCL", 'N', 4, 1, 0}, {"R 1/X", 'R', 4, 2, 1}, {"K +/-", 'K', 4, 3, 1},
	{"C CLR", 'C', 5, 0, 2}, {"<-", '\b', 5, 1, 2}, {"T TOT", 'T', 5, 2, 1}, {"ENTER", '\r', 5, 3, 2},
}

PAD_X :: 200
PAD_Y :: 136
PAD_W :: 46
PAD_H :: 30
PAD_GAP :: 5

App :: struct {
	c:       calc.Calc,
	t:       f32,
	pressed: int, // the pad key last pressed (lit briefly)
	press_t: f32,
	scroll:  int, // tape lines scrolled back from the newest
}

app: App

main :: proc() {
	calc.new_calc(&app.c)
	app.pressed = -1
	buf: [48]u8
	if v, ok := gfx.store_get("memory", buf[:]); ok {
		if x, xok := strconv.parse_f64(v); xok && x == x {app.c.memory = x}
	}
}

save_memory :: proc() {
	gfx.store_set("memory", calc.format(app.c.memory))
}

@(export)
step :: proc(dt: f64) -> bool {
	d := f32(min(dt, 0.1))
	app.t += d
	app.press_t = max(0, app.press_t - d)
	draw()
	free_all(context.temp_allocator)
	return true
}

// One key, from the keyboard or the pad.
act :: proc(ch: u8) {
	c := &app.c
	before_err := c.error
	mem := c.memory
	n := c.tape_len
	switch {
	case ch == '\r':
		calc.enter(c)
	case ch == 'C' || ch == 27:
		calc.clear_entry(c)
	case ch == '\b':
		calc.backspace(c)
	case (ch >= '0' && ch <= '9') || ch == '.' || ch == 'N':
		calc.type_char(c, ch)
	case ch == '_':
		calc.type_char(c, '-') // the pad's minus sign key
	case ch == '-':
		// A minus with nothing typed yet is a sign; otherwise it subtracts.
		if c.stage == .Initial && c.entry_len == 0 {
			calc.type_char(c, '-')
		} else {
			calc.press(c, .Subtract)
		}
	case:
		f := calc.func_for_key(ch)
		if f == .None {return}
		calc.press(c, f)
	}
	if c.error && !before_err {
		gfx.tone(140, 200, .Saw, 0.05)
	} else if c.tape_len != n || c.tape[max(0, c.tape_len - 1)].total {
		gfx.tone(1800, 10, .Square, 0.02)
		gfx.noise(30, 0.05, 10) // the printer
	} else {
		gfx.tone(2400, 8, .Square, 0.015)
	}
	if c.tape_len != n {app.scroll = 0}
	if c.memory != mem {save_memory()}
}

@(export)
on_key :: proc "c" (code: i32, down: i32) {
	context = runtime.default_context()
	if down == 0 {return}
	cd := int(code)
	switch cd {
	case gfx.KEY_ENTER:
		act('\r')
	case gfx.KEY_BACKSPACE, gfx.KEY_DELETE:
		act('\b')
	case gfx.KEY_ESCAPE:
		act('C')
	case gfx.KEY_UP:
		app.scroll = min(app.scroll + 1, max(0, app.c.tape_len - 1))
	case gfx.KEY_DOWN:
		app.scroll = max(0, app.scroll - 1)
	case:
		if cd > 0 && cd < 128 {
			ch := u8(cd)
			act(ch)
			for k, i in PAD {
				if k.ch == ch || (ch == '+' && k.ch == 'A') || (ch == '*' && k.ch == 'M') || (ch == '/' && k.ch == 'D') || (ch == '=' && k.ch == 'T') {
					light(i)
				}
			}
		}
	}
}

light :: proc(i: int) {
	app.pressed = i
	app.press_t = 0.12
}

@(export)
on_pointer :: proc "c" (x, y: f32, kind: i32) {
	context = runtime.default_context()
	if kind != 0 {return}
	id := gfx.hit(x, y)
	if id >= 100 && id < 100 + len(PAD) {
		i := id - 100
		light(i)
		act(PAD[i].ch)
	} else if id == 200 {
		app.scroll = min(app.scroll + 4, max(0, app.c.tape_len - 1))
	} else if id == 201 {
		app.scroll = max(0, app.scroll - 4)
	}
}

// ---- drawing ----

draw :: proc() {
	gfx.clear(CASE)
	gfx.begin_buttons()
	draw_tape()
	draw_display()
	draw_pad()
	gfx.text(PAD_X, H - 12, "AFTER 'CALCULATOR', SOFTSIDE 1978", DIM)
}

TAPE_X :: 14
TAPE_W :: 168
TAPE_TOP :: 14
TAPE_BOTTOM :: H - 14

draw_tape :: proc() {
	c := &app.c
	gfx.rect(TAPE_X - 4, TAPE_TOP - 4, TAPE_W + 8, TAPE_BOTTOM - TAPE_TOP + 8, CASE_LIT)
	gfx.rect(TAPE_X, TAPE_TOP, TAPE_W, TAPE_BOTTOM - TAPE_TOP, PAPER)
	// The newest line at the bottom, by the print head.
	line_h := 11
	y := TAPE_BOTTOM - 16
	i := c.tape_len - 1 - app.scroll
	for ; i >= 0 && y > TAPE_TOP; i -= 1 {
		l := &c.tape[i]
		if l.rule {
			for x := TAPE_X + 4; x < TAPE_X + TAPE_W - 4; x += 4 {gfx.rect(x, y + 4, 2, 1, PAPER_LINE)}
		} else {
			s := calc.line_text(l)
			ink: u32 = INK
			if len(s) > 0 && s[0] == '-' {ink = INK_RED} // negatives in red, as on a two-colour ribbon
			gfx.text(TAPE_X + TAPE_W - 6 - gfx.text_width(s), y, s, ink)
		}
		y -= line_h
	}
	// The print head.
	gfx.rect(TAPE_X - 4, TAPE_BOTTOM - 4, TAPE_W + 8, 6, 0x5a5650)
	if app.scroll > 0 {gfx.text(TAPE_X + 4, TAPE_BOTTOM - 14, fmt.tprintf("^%d", app.scroll), INK_RED)}
	gfx.zone(TAPE_X, TAPE_TOP, TAPE_W, (TAPE_BOTTOM - TAPE_TOP) / 2, 200)
	gfx.zone(TAPE_X, TAPE_TOP + (TAPE_BOTTOM - TAPE_TOP) / 2, TAPE_W, (TAPE_BOTTOM - TAPE_TOP) / 2, 201)
}

draw_display :: proc() {
	c := &app.c
	x, y := PAD_X, 14
	w := W - PAD_X - 14
	gfx.rect(x, y, w, 110, LCD)
	gfx.frame(x, y, w, 110, LCD_DARK)
	prompt: string
	switch c.stage {
	case .Initial:
		prompt = "INITIAL VALUE?"
	case .Function:
		prompt = "FUNCTION?"
	case .Entry:
		prompt = fmt.tprintf("ENTRY? (%s)", calc.FUNC_NAME[c.pending])
	}
	gfx.text(x + 8, y + 8, prompt, LCD_INK)
	if c.error {gfx.text(x + w - 8 - gfx.text_width("ERROR"), y + 8, "ERROR", INK_RED)}
	// The entry being typed, big, with a cursor.
	e := calc.entry_text(c)
	cursor := int(app.t * 2) % 2 == 0 && c.stage != .Function ? "_" : ""
	gfx.text(x + 8, y + 26, fmt.tprintf("%s%s", e, cursor), LCD_INK, 2)
	gfx.rect(x + 8, y + 48, w - 16, 1, LCD_DARK)
	gfx.text(x + 8, y + 58, "TOTAL", LCD_INK)
	ts := c.stage == .Initial ? "-" : calc.format(c.total)
	gfx.text(x + w - 8 - gfx.text_width(ts, 2), y + 54, ts, LCD_INK, 2)
	gfx.text(x + 8, y + 80, "MEMORY", LCD_INK)
	ms := calc.format(c.memory)
	gfx.text(x + w - 8 - gfx.text_width(ms), y + 80, ms, LCD_INK)
	gfx.text(x + 8, y + 96, "A TOOL. KEYS: DIGITS ASMD HNRKT", LCD_DARK - 0x202020)
}

draw_pad :: proc() {
	for k, i in PAD {
		x := PAD_X + k.col * (PAD_W + PAD_GAP)
		y := PAD_Y + k.row * (PAD_H + PAD_GAP)
		bg: u32 = KEY
		if k.kind == 1 {bg = KEY_FN}
		if k.kind == 2 {bg = KEY_GO}
		lit := app.pressed == i && app.press_t > 0
		dy := lit ? 1 : 0
		gfx.rect(x, y + 2, PAD_W, PAD_H, 0x1a1916)
		gfx.rect(x, y + dy, PAD_W, PAD_H - 1, lit ? KEY_TEXT : bg)
		gfx.rect(x, y + dy, PAD_W, 1, lit ? KEY_TEXT : bg + 0x181818)
		gfx.text_c(x + PAD_W / 2, y + dy + PAD_H / 2 - 5, k.label, lit ? bg : KEY_TEXT)
		gfx.zone(x, y, PAD_W, PAD_H, 100 + i)
	}
}
