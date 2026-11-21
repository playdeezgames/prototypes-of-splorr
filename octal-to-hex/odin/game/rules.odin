package octhex

// Octal to Hex: a tool. Type up to three octal digits and see the byte in hex, decimal and
// binary, and the TRS-80 character it stands for. After "Octal to Hex Conversion Program" by
// Lance Micklus (SoftSide, November 1978), which took three octal digits, checked they made a byte
// (no more than 377) and printed the hex value; anything else was "** ERROR **".
// Pure rules: no platform imports.

MAX_DIGITS :: 3
TAPE :: 64

Conv :: struct {
	digits: [MAX_DIGITS]u8, // '0'..'7'
	n:      int,
	error:  bool, // the last Enter was not a byte
	tape:   [TAPE]int, // values entered, oldest first
	tape_n: int,
}

type_digit :: proc(c: ^Conv, ch: u8) -> bool {
	if ch < '0' || ch > '7' || c.n >= MAX_DIGITS {return false}
	c.digits[c.n] = ch
	c.n += 1
	c.error = false
	return true
}

backspace :: proc(c: ^Conv) {
	if c.n > 0 {c.n -= 1}
	c.error = false
}

clear :: proc(c: ^Conv) {
	c.n = 0
	c.error = false
}

// The value typed so far (ok false when nothing is typed or it is over 377 octal).
value :: proc(c: ^Conv) -> (v: int, ok: bool) {
	if c.n == 0 {return 0, false}
	for i in 0 ..< c.n {v = v * 8 + int(c.digits[i] - '0')}
	return v, v <= 255
}

// Replaces the entry with a byte, written as three octal digits.
set_value :: proc(c: ^Conv, v: int) {
	b := ((v % 256) + 256) % 256
	c.digits = {u8('0' + b / 64), u8('0' + (b / 8) % 8), u8('0' + b % 8)}
	c.n = 3
	c.error = false
}

// Flips one bit (0 the lowest) of the entry; an empty or bad entry counts as zero.
toggle_bit :: proc(c: ^Conv, bit: uint) {
	v, ok := value(c)
	if !ok {v = 0}
	set_value(c, v ~ (1 << bit))
}

// Steps the byte up or down by one, wrapping round.
nudge :: proc(c: ^Conv, by: int) {
	v, ok := value(c)
	if !ok {v = by > 0 ? -1 : 0}
	set_value(c, v + by)
}

// Converts: a byte goes on the tape; anything else is an error, as in the listing.
enter :: proc(c: ^Conv) -> bool {
	v, ok := value(c)
	if !ok {
		c.error = c.n > 0
		return false
	}
	if c.tape_n == TAPE {
		copy(c.tape[:], c.tape[1:])
		c.tape_n -= 1
	}
	c.tape[c.tape_n] = v
	c.tape_n += 1
	return true
}

HEX := "0123456789ABCDEF"

hex_digits :: proc(v: int) -> [2]u8 {
	return {HEX[(v >> 4) & 15], HEX[v & 15]}
}

oct_digits :: proc(v: int) -> [3]u8 {
	return {u8('0' + (v >> 6) & 3), u8('0' + (v >> 3) & 7), u8('0' + v & 7)}
}

Char_Kind :: enum {
	Control, // 0-31: no picture
	Text, // 32-127: the ASCII character (127 is drawn as a block on the screen of a TRS-80, but kept simple)
	Block, // 128-191: a 2 by 3 block graphic
	Space_Comp, // 192-255: Level II's space-compression codes (0 to 63 spaces)
}

char_kind :: proc(v: int) -> Char_Kind {
	switch {
	case v < 32:
		return .Control
	case v < 128:
		return .Text
	case v < 192:
		return .Block
	}
	return .Space_Comp
}

// Which of the six cells of a block graphic are lit: bit 0 top left, 1 top right, 2 middle left,
// 3 middle right, 4 bottom left, 5 bottom right.
block_cells :: proc(v: int) -> u8 {
	return u8((v - 128) & 63)
}
