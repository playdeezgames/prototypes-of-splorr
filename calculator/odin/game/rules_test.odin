#+build !js
package calculator

import "core:strings"
import "core:testing"

@(private = "file")
keys :: proc(c: ^Calc, s: string) {
	for i in 0 ..< len(s) {
		ch := s[i]
		switch {
		case ch == '\n':
			enter(c)
		case ch == 'C':
			clear_entry(c)
		case (ch >= '0' && ch <= '9') || ch == '.' || ch == 'N':
			type_char(c, ch)
		case ch == '-' && (c.stage == .Initial || (c.stage == .Entry && c.entry_len == 0)):
			type_char(c, ch)
		case:
			press(c, func_for_key(ch))
		}
	}
}

@(test)
numbers_print_like_a_calculator :: proc(t: ^testing.T) {
	cases := [?]struct {
		v: f64,
		s: string,
	} {
		{0, "0"},
		{15, "15"},
		{-2.5, "-2.5"},
		{1.0 / 3, "0.3333333333"},
		{0.1 + 0.2, "0.3"},
		{1234567890, "1234567890"},
		{12345678901, "1.23456789E+10"},
		{0.000001, "0.000001"},
		{1e-7, "1E-07"},
		{100, "100"},
		{1e30, "1E+30"},
	}
	for c in cases {
		testing.expect_value(t, strings.clone(format(c.v), context.temp_allocator), c.s)
	}
}

@(test)
a_running_total :: proc(t: ^testing.T) {
	c: Calc
	new_calc(&c)
	keys(&c, "10\nA5\nM3\nS1\nD4\n")
	testing.expect_value(t, c.total, 11)
	testing.expect_value(t, c.stage, Stage.Function)
}

@(test)
one_key_functions :: proc(t: ^testing.T) {
	c: Calc
	new_calc(&c)
	keys(&c, "4\nR")
	testing.expect_value(t, c.total, 0.25)
	keys(&c, "K")
	testing.expect_value(t, c.total, -0.25)
}

@(test)
memory_and_recall_with_n :: proc(t: ^testing.T) {
	c: Calc
	new_calc(&c)
	keys(&c, "12\nH")
	testing.expect_value(t, c.memory, 12)
	keys(&c, "T") // total: a fresh calculation, memory kept
	testing.expect_value(t, c.stage, Stage.Initial)
	keys(&c, "2\nMN\n")
	testing.expect_value(t, c.total, 24)
}

@(test)
dividing_by_zero_is_refused :: proc(t: ^testing.T) {
	c: Calc
	new_calc(&c)
	keys(&c, "5\nD0\n")
	testing.expect(t, c.error)
	testing.expect_value(t, c.total, 5)
	testing.expect_value(t, c.stage, Stage.Entry) // fix the entry and try again
	keys(&c, "C2\n")
	testing.expect_value(t, c.total, 2.5)
}

@(test)
symbols_and_adding_machine_style :: proc(t: ^testing.T) {
	c: Calc
	new_calc(&c)
	keys(&c, "3\n4+2*") // a digit with no function adds it; a function finishes the entry
	testing.expect_value(t, c.total, 9) // 3 + 4 = 7, + 2 = 9, then * waits for its entry
	testing.expect_value(t, c.pending, Func.Multiply)
	keys(&c, "10=") // = is T: the total goes on the tape and a new calculation starts
	testing.expect_value(t, c.stage, Stage.Initial)
	testing.expect(t, c.tape[c.tape_len - 1].rule)
	testing.expect_value(t, strings.clone(line_text(&c.tape[c.tape_len - 2]), context.temp_allocator), "90 T")
}

@(test)
the_tape_keeps_the_newest_lines :: proc(t: ^testing.T) {
	c: Calc
	new_calc(&c)
	keys(&c, "0\n")
	for _ in 0 ..< 100 {keys(&c, "A1\n")}
	testing.expect_value(t, c.total, 100)
	testing.expect_value(t, c.tape_len, TAPE_LINES)
	last := &c.tape[c.tape_len - 1]
	testing.expect_value(t, strings.clone(line_text(last), context.temp_allocator), "100 =")
}

@(test)
negative_entries_and_one_point :: proc(t: ^testing.T) {
	c: Calc
	new_calc(&c)
	keys(&c, "-1.5.5\n") // the second point is refused: -1.55
	testing.expect_value(t, c.total, -1.55)
}
