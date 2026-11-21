#+build js
package main

// Octal to Hex's page: the display, the bits, the keypad and the tape. Rules are in ../game.

import "base:runtime"
import "core:fmt"
import oh "../game"
import "proto:gfx"

W :: 384
H :: 240

BG :: 0x0b0f0b
GLASS :: 0x102014
GLASS_LINE :: 0x2c5a34
PHOS :: 0x7cf08a
PHOS_DIM :: 0x3c8a48
PHOS_FAINT :: 0x1e4426
AMBER :: 0xffbf40
RED :: 0xff6a5a
KEY :: 0x24302a
KEY_FN :: 0x3a3424
KEY_GO :: 0x2c5a34
KEY_TEXT :: 0xe6f0e0
DIM :: 0x8a9a8a

// Tap targets.
ID_DIGIT :: 100 // + digit
ID_BIT :: 200 // + bit
ID_CLEAR :: 1
ID_BACK :: 2
ID_ENTER :: 3
ID_DOWN :: 4
ID_UP :: 5

App :: struct {
	c:       oh.Conv,
	t:       f32,
	pressed: int,
	press_t: f32,
}

app: App

main :: proc() {
	app.press_t = 10
	oh.set_value(&app.c, 0o35) // the listing's example
}

@(export)
step :: proc(dt: f64) -> bool {
	d := f32(min(dt, 0.1))
	app.t += d
	app.press_t += d
	draw()
	free_all(context.temp_allocator)
	return true
}

click :: proc(id: int) {
	app.pressed = id
	app.press_t = 0
	c := &app.c
	switch {
	case id >= ID_BIT:
		oh.toggle_bit(c, uint(id - ID_BIT))
		gfx.tone(1200, 20, .Square, 0.03)
	case id >= ID_DIGIT:
		if oh.type_digit(c, u8('0' + id - ID_DIGIT)) {
			gfx.tone(900, 18, .Square, 0.03)
		} else {
			gfx.tone(120, 60, .Square, 0.04)
		}
	case id == ID_CLEAR:
		oh.clear(c)
		gfx.tone(500, 30, .Square, 0.03)
	case id == ID_BACK:
		oh.backspace(c)
		gfx.tone(700, 20, .Square, 0.03)
	case id == ID_ENTER:
		if oh.enter(c) {
			gfx.tone(660, 40, .Square, 0.03)
			gfx.tone(990, 60, .Square, 0.03, 45)
		} else if c.error {
			gfx.tone(140, 160, .Saw, 0.05)
		}
	case id == ID_DOWN:
		oh.nudge(c, -1)
		gfx.tone(600, 15, .Square, 0.03)
	case id == ID_UP:
		oh.nudge(c, 1)
		gfx.tone(800, 15, .Square, 0.03)
	}
}

// ---- input ----

@(export)
on_key :: proc "c" (code: i32, down: i32) {
	context = runtime.default_context()
	if down == 0 {return}
	c := int(code)
	switch c {
	case '0' ..= '7':
		if down == 1 {click(ID_DIGIT + c - '0')}
	case '8', '9':
		if down == 1 {click(ID_DIGIT + c - '0')} // refused, with a buzz
	case gfx.KEY_BACKSPACE, gfx.KEY_DELETE:
		click(ID_BACK)
	case gfx.KEY_ESCAPE, 'C':
		if down == 1 {click(ID_CLEAR)}
	case gfx.KEY_ENTER, '=', ',':
		if down == 1 {click(ID_ENTER)}
	case gfx.KEY_UP, gfx.KEY_RIGHT, '+':
		click(ID_UP)
	case gfx.KEY_DOWN, gfx.KEY_LEFT, '-':
		click(ID_DOWN)
	}
}

@(export)
on_pointer :: proc "c" (x, y: f32, kind: i32) {
	context = runtime.default_context()
	if kind != 0 {return}
	id := gfx.hit(x, y)
	if id > 0 {click(id)}
}

// ---- drawing ----

draw :: proc() {
	gfx.clear(BG)
	gfx.begin_buttons()
	gfx.text(8, 6, "OCTAL TO HEX", PHOS)
	gfx.text(W - 8 - gfx.text_width("A TOOL"), 6, "A TOOL", PHOS_DIM)
	draw_display()
	draw_pad()
	draw_tape()
}

DX :: 8
DY :: 20
DW :: 232
DH :: 132

draw_display :: proc() {
	c := &app.c
	gfx.rect(DX, DY, DW, DH, GLASS)
	gfx.frame(DX, DY, DW, DH, GLASS_LINE)
	v, ok := oh.value(c)

	// What's typed, with a cursor.
	gfx.text(DX + 8, DY + 8, "OCTAL", PHOS_DIM)
	typed := string(c.digits[:c.n])
	gfx.text(DX + 56, DY + 4, typed, ok || c.n == 0 ? PHOS : RED, 2)
	if c.n < oh.MAX_DIGITS && int(app.t * 2) % 2 == 0 {
		gfx.rect(DX + 56 + c.n * 16, DY + 18, 14, 2, PHOS)
	}

	gfx.text(DX + 8, DY + 36, "HEX", PHOS_DIM)
	if ok {
		h := oh.hex_digits(v)
		gfx.text(DX + 56, DY + 28, string(h[:]), AMBER, 3)
		gfx.text(DX + 8, DY + 60, fmt.tprintf("DEC %3d", v), PHOS)
	} else if c.n > 0 {
		gfx.text(DX + 56, DY + 34, "** ERROR **", RED)
		gfx.text(DX + 8, DY + 60, "NOT A BYTE: OVER 377", RED)
	} else {
		gfx.text(DX + 56, DY + 34, "TYPE 0-7", PHOS_FAINT)
	}

	// The bits, tappable, highest first.
	gfx.text(DX + 8, DY + 80, "BITS", PHOS_DIM)
	for i in 0 ..< 8 {
		bit := uint(7 - i)
		x := DX + 8 + i * 22
		y := DY + 92
		on := ok && (v >> bit) & 1 == 1
		gfx.rect(x, y, 20, 18, on ? PHOS_DIM : 0x0c180f)
		gfx.frame(x, y, 20, 18, GLASS_LINE)
		gfx.text(x + 6, y + 5, on ? "1" : "0", on ? KEY_TEXT : PHOS_FAINT)
		gfx.text(x + 6, y + 21, fmt.tprintf("%d", bit), PHOS_FAINT)
		gfx.zone(x, y, 20, 18, ID_BIT + int(bit))
	}
	gfx.text(DX + 8 + 8 * 22 + 2, DY + 97, "TAP", PHOS_FAINT)

	draw_char(DX + DW - 48, DY + 8, v, ok)
}

// What the byte is on a TRS-80's screen.
draw_char :: proc(x, y, v: int, ok: bool) {
	gfx.text(x - 4, y, "CHAR", PHOS_DIM)
	bx, by, bw, bh := x - 4, y + 12, 44, 48
	gfx.rect(bx, by, bw, bh, 0x050805)
	gfx.frame(bx, by, bw, bh, GLASS_LINE)
	if !ok {return}
	switch oh.char_kind(v) {
	case .Control:
		gfx.text_c(bx + bw / 2, by + 20, "CTRL", PHOS_DIM)
	case .Text:
		s := [1]u8{u8(v)}
		if v == 32 {
			gfx.text_c(bx + bw / 2, by + 20, "SPACE", PHOS_DIM)
		} else if v == 127 {
			gfx.text_c(bx + bw / 2, by + 20, "DEL", PHOS_DIM)
		} else {
			gfx.text_c(bx + bw / 2, by + 12, string(s[:]), PHOS, 3)
		}
	case .Block:
		cells := oh.block_cells(v)
		for i in 0 ..< 6 {
			cx := bx + 8 + (i % 2) * 14
			cy := by + 6 + (i / 2) * 12
			lit := (cells >> uint(i)) & 1 == 1
			gfx.rect(cx, cy, 14, 12, lit ? PHOS : 0x0c180f)
		}
	case .Space_Comp:
		gfx.text_c(bx + bw / 2, by + 14, fmt.tprintf("%d", v - 192), PHOS, 2)
		gfx.text_c(bx + bw / 2, by + 34, "SPACES", PHOS_DIM)
	}
	label := ""
	switch oh.char_kind(v) {
	case .Control:
		label = "CONTROL"
	case .Text:
		label = "ASCII"
	case .Block:
		label = "GRAPHIC"
	case .Space_Comp:
		label = "LEVEL II"
	}
	gfx.text_c(bx + bw / 2, by + bh + 4, label, PHOS_FAINT)
}

PADX :: 248
PADY :: 20
KW :: 30
KH :: 24
KG :: 3

pad_key :: proc(col, row: int, label: string, id: int, bg: u32, span := 1) {
	x := PADX + col * (KW + KG)
	y := PADY + row * (KH + KG)
	w := KW * span + KG * (span - 1)
	lit := app.pressed == id && app.press_t < 0.12
	gfx.rect(x, y, w, KH, lit ? PHOS_DIM : bg)
	gfx.frame(x, y, w, KH, lit ? PHOS : GLASS_LINE)
	gfx.text_c(x + w / 2, y + 8, label, KEY_TEXT)
	gfx.zone(x, y, w, KH, id)
}

draw_pad :: proc() {
	for d in 0 ..< 8 {
		// 4 5 6 7 on top, 0 1 2 3 below, as octal reads.
		col := d % 4
		row := d < 4 ? 1 : 0
		s := [1]u8{u8('0' + d)}
		pad_key(col, row, string(s[:]), ID_DIGIT + d, KEY)
	}
	pad_key(0, 2, "CLR", ID_CLEAR, KEY_FN, 2)
	pad_key(2, 2, "<-", ID_BACK, KEY_FN, 2)
	pad_key(0, 3, "-1", ID_DOWN, KEY_FN)
	pad_key(1, 3, "+1", ID_UP, KEY_FN)
	pad_key(2, 3, "ENTER", ID_ENTER, KEY_GO, 2)
	gfx.text(PADX, PADY + 4 * (KH + KG) + 2, "KEYS 0-7, ENTER,", DIM)
	gfx.text(PADX, PADY + 4 * (KH + KG) + 12, "ARROWS, BACKSPACE", DIM)
}

TY :: 160

draw_tape :: proc() {
	c := &app.c
	gfx.rect(DX, TY, W - 16, H - TY - 6, 0x0a140c)
	gfx.frame(DX, TY, W - 16, H - TY - 6, GLASS_LINE)
	gfx.text(DX + 6, TY + 5, "TAPE", PHOS_DIM)
	COLS :: 5
	ROWS :: 6
	if c.tape_n == 0 {
		gfx.text(DX + 48, TY + 5, "ENTER PUTS A CONVERSION HERE", PHOS_FAINT)
		return
	}
	// Newest first, down the columns.
	shown := min(c.tape_n, COLS * ROWS)
	for i in 0 ..< shown {
		v := c.tape[c.tape_n - 1 - i]
		o := oh.oct_digits(v)
		h := oh.hex_digits(v)
		x := DX + 6 + (i / ROWS) * 72
		y := TY + 18 + (i % ROWS) * 10
		gfx.text(x, y, fmt.tprintf("%s=%s", string(o[:]), string(h[:])), i == 0 ? AMBER : PHOS_DIM)
	}
}
