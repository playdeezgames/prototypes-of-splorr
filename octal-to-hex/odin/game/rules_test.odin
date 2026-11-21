#+build !js
package octhex

import "core:testing"

type :: proc(c: ^Conv, s: string) {
	for i in 0 ..< len(s) {type_digit(c, s[i])}
}

@(test)
the_listings_example :: proc(t: ^testing.T) {
	c: Conv
	type(&c, "035")
	v, ok := value(&c)
	testing.expect(t, ok)
	testing.expect_value(t, v, 29)
	testing.expect_value(t, hex_digits(v), [2]u8{'1', 'D'})
	testing.expect(t, enter(&c))
	testing.expect_value(t, c.tape_n, 1)
	testing.expect_value(t, c.tape[0], 29)
}

@(test)
only_octal_digits_and_only_three :: proc(t: ^testing.T) {
	c: Conv
	testing.expect(t, !type_digit(&c, '8'))
	testing.expect(t, !type_digit(&c, 'A'))
	type(&c, "1234")
	testing.expect_value(t, c.n, 3)
	v, _ := value(&c)
	testing.expect_value(t, v, 0o123)
}

@(test)
over_377_is_an_error :: proc(t: ^testing.T) {
	c: Conv
	type(&c, "377")
	v, ok := value(&c)
	testing.expect(t, ok && v == 255)
	clear(&c)
	type(&c, "400")
	_, ok = value(&c)
	testing.expect(t, !ok)
	testing.expect(t, !enter(&c))
	testing.expect(t, c.error)
	testing.expect_value(t, c.tape_n, 0)
	backspace(&c)
	testing.expect(t, !c.error)
	clear(&c)
	testing.expect(t, !enter(&c)) // nothing typed: no error either
	testing.expect(t, !c.error)
}

@(test)
bits_and_nudges :: proc(t: ^testing.T) {
	c: Conv
	toggle_bit(&c, 7)
	v, _ := value(&c)
	testing.expect_value(t, v, 128)
	testing.expect_value(t, oct_digits(v), [3]u8{'2', '0', '0'})
	toggle_bit(&c, 0)
	v, _ = value(&c)
	testing.expect_value(t, v, 129)
	nudge(&c, -2)
	v, _ = value(&c)
	testing.expect_value(t, v, 127)
	set_value(&c, 255)
	nudge(&c, 1)
	v, _ = value(&c)
	testing.expect_value(t, v, 0)
	clear(&c)
	nudge(&c, 1)
	v, _ = value(&c)
	testing.expect_value(t, v, 0)
}

@(test)
characters :: proc(t: ^testing.T) {
	testing.expect_value(t, char_kind(13), Char_Kind.Control)
	testing.expect_value(t, char_kind(65), Char_Kind.Text)
	testing.expect_value(t, char_kind(128), Char_Kind.Block)
	testing.expect_value(t, char_kind(191), Char_Kind.Block)
	testing.expect_value(t, char_kind(192), Char_Kind.Space_Comp)
	testing.expect_value(t, block_cells(191), u8(63))
	testing.expect_value(t, block_cells(129), u8(1))
}

@(test)
the_tape_keeps_the_newest :: proc(t: ^testing.T) {
	c: Conv
	for i in 0 ..< TAPE + 5 {
		set_value(&c, i)
		enter(&c)
	}
	testing.expect_value(t, c.tape_n, TAPE)
	testing.expect_value(t, c.tape[TAPE - 1], TAPE + 4)
	testing.expect_value(t, c.tape[0], 5)
}
