package calculator

// Calculator, a Tool: a desk calculator that carries a running total. After "Calculator"
// (uncredited, SoftSide, October 1978): an initial value, then one-key functions (A add,
// S subtract, M multiply, D divide, H store the total in memory, R reciprocal, K change sign,
// T total and start over), and an entry of N recalls the memory, as typing N at the original's
// INPUT prompt read the BASIC variable N. Every step is printed on a paper tape.
// Pure rules: no platform imports.

import "core:strconv"

Func :: enum {
	None,
	Add,
	Subtract,
	Multiply,
	Divide,
	Memory, // H: store the total
	Reciprocal,
	Sign,
	Total,
}

Stage :: enum {
	Initial, // "INITIAL VALUE?"
	Function, // "FUNCTION?"
	Entry, // "ENTRY?" after A, S, M or D
}

ENTRY_MAX :: 14
TAPE_LINES :: 64
LINE_MAX :: 32

Line :: struct {
	text:  [LINE_MAX]u8,
	len:   int,
	total: bool, // a total line (drawn brighter)
	rule:  bool, // a torn-off rule between calculations
}

Calc :: struct {
	stage:     Stage,
	total:     f64,
	memory:    f64,
	pending:   Func, // the function waiting for its entry
	entry:     [ENTRY_MAX]u8,
	entry_len: int,
	error:     bool, // the last step could not be done (divide by zero, a bad number)
	tape:      [TAPE_LINES]Line,
	tape_len:  int, // lines held (the oldest drop off)
}

new_calc :: proc(c: ^Calc) {
	mem := c.memory
	c^ = {}
	c.memory = mem
}

func_for_key :: proc(k: u8) -> Func {
	switch k {
	case 'A', '+':
		return .Add
	case 'S', '-':
		return .Subtract
	case 'M', '*', 'X':
		return .Multiply
	case 'D', '/':
		return .Divide
	case 'H':
		return .Memory
	case 'R':
		return .Reciprocal
	case 'K':
		return .Sign
	case 'T', '=':
		return .Total
	}
	return .None
}

FUNC_NAME := [Func]string {
	.None       = "",
	.Add        = "ADD",
	.Subtract   = "SUBTRACT",
	.Multiply   = "MULTIPLY",
	.Divide     = "DIVIDE",
	.Memory     = "MEMORY",
	.Reciprocal = "RECIPROCAL",
	.Sign       = "+/-",
	.Total      = "TOTAL",
}

FUNC_MARK := [Func]string {
	.None       = "",
	.Add        = "+",
	.Subtract   = "-",
	.Multiply   = "X",
	.Divide     = "/",
	.Memory     = "M",
	.Reciprocal = "1/X",
	.Sign       = "+/-",
	.Total      = "T",
}

// ---- typing an entry ----

type_char :: proc(c: ^Calc, ch: u8) -> bool {
	if c.stage == .Function {
		// A digit with no function picked first starts a fresh entry for ADD, adding-machine style.
		if (ch >= '0' && ch <= '9') || ch == '.' {
			c.pending = .Add
			c.stage = .Entry
		} else {
			return false
		}
	}
	if c.entry_len >= ENTRY_MAX {return false}
	switch {
	case ch >= '0' && ch <= '9':
	case ch == '.':
		for i in 0 ..< c.entry_len {if c.entry[i] == '.' {return false}}
	case ch == '-':
		if c.entry_len != 0 {return false}
	case ch == 'N':
		// Memory recall replaces whatever was typed.
		c.entry_len = 0
		s := format(c.memory)
		for i in 0 ..< min(len(s), ENTRY_MAX) {c.entry[i] = s[i]}
		c.entry_len = min(len(s), ENTRY_MAX)
		c.error = false
		return true
	case:
		return false
	}
	c.entry[c.entry_len] = ch
	c.entry_len += 1
	c.error = false
	return true
}

backspace :: proc(c: ^Calc) {
	if c.entry_len > 0 {c.entry_len -= 1}
}

entry_text :: proc(c: ^Calc) -> string {
	return string(c.entry[:c.entry_len])
}

// ---- functions ----

// Presses a function key (in the Function stage), or Enter (finishing an entry).
press :: proc(c: ^Calc, f: Func) {
	c.error = false
	switch c.stage {
	case .Initial:
		// A function key here works like Enter once a value is typed.
		enter(c)
		if c.stage == .Function && f != .None {press(c, f)}
	case .Function:
		switch f {
		case .None:
		case .Add, .Subtract, .Multiply, .Divide:
			c.pending = f
			c.stage = .Entry
			c.entry_len = 0
		case .Memory:
			c.memory = c.total
			log(c, FUNC_MARK[f], format(c.total), false)
		case .Reciprocal:
			if c.total == 0 {
				c.error = true
				return
			}
			c.total = 1 / c.total
			log(c, FUNC_MARK[f], format(c.total), true)
		case .Sign:
			c.total = -c.total
			log(c, FUNC_MARK[f], format(c.total), true)
		case .Total:
			log(c, "T", format(c.total), true)
			rule(c)
			mem := c.memory
			tape := c.tape
			n := c.tape_len
			new_calc(c)
			c.memory = mem
			c.tape = tape
			c.tape_len = n
		}
	case .Entry:
		// Another function before the entry is finished: finish it with Enter first.
		if c.entry_len > 0 {
			enter(c)
			if !c.error && f != .None {press(c, f)}
		} else if f >= .Add && f <= .Divide {
			c.pending = f // changed its mind
		}
	}
}

parse_entry :: proc(c: ^Calc) -> (f64, bool) {
	s := entry_text(c)
	if s == "" || s == "-" || s == "." || s == "-." {return 0, false}
	return strconv.parse_f64(s)
}

// Enter: finishes the initial value or an entry.
enter :: proc(c: ^Calc) {
	switch c.stage {
	case .Initial:
		v, ok := parse_entry(c)
		if !ok {
			if c.entry_len == 0 {v, ok = 0, true} else {
				c.error = true
				return
			}
		}
		c.total = v
		log(c, "", format(v), false)
		c.entry_len = 0
		c.stage = .Function
	case .Entry:
		v, ok := parse_entry(c)
		if !ok {
			c.error = c.entry_len > 0
			return
		}
		r := c.total
		switch c.pending {
		case .Add:
			r += v
		case .Subtract:
			r -= v
		case .Multiply:
			r *= v
		case .Divide:
			if v == 0 {
				c.error = true
				return
			}
			r /= v
		case .None, .Memory, .Reciprocal, .Sign, .Total:
		}
		if r != r || r > 1e38 || r < -1e38 {
			c.error = true // overflow, as the TRS-80's single precision would have
			return
		}
		log(c, FUNC_MARK[c.pending], format(v), false)
		c.total = r
		log(c, "=", format(r), true)
		c.entry_len = 0
		c.pending = .None
		c.stage = .Function
	case .Function:
		press(c, .Total)
	}
}

// Clear: drops the entry, or with nothing typed starts the calculation over.
clear_entry :: proc(c: ^Calc) {
	if c.entry_len > 0 {
		c.entry_len = 0
		return
	}
	if c.stage == .Entry {
		c.stage = .Function
		c.pending = .None
		return
	}
	if c.stage == .Function {
		rule(c)
		mem := c.memory
		tape := c.tape
		n := c.tape_len
		new_calc(c)
		c.memory = mem
		c.tape = tape
		c.tape_len = n
	}
}

// ---- the tape ----

log :: proc(c: ^Calc, mark, value: string, is_total: bool) {
	l: Line
	l.total = is_total
	// Right-aligned like an adding machine's tape: the value, then the mark.
	n := 0
	for i in 0 ..< min(len(value), LINE_MAX - 5) {
		l.text[n] = value[i]
		n += 1
	}
	l.text[n] = ' '
	n += 1
	for i in 0 ..< min(len(mark), 3) {
		l.text[n] = mark[i]
		n += 1
	}
	l.len = n
	push_line(c, l)
}

rule :: proc(c: ^Calc) {
	if c.tape_len > 0 && c.tape[c.tape_len - 1].rule {return}
	l: Line
	l.rule = true
	push_line(c, l)
}

push_line :: proc(c: ^Calc, l: Line) {
	if c.tape_len == TAPE_LINES {
		for i in 1 ..< TAPE_LINES {c.tape[i - 1] = c.tape[i]}
		c.tape_len -= 1
	}
	c.tape[c.tape_len] = l
	c.tape_len += 1
}

line_text :: proc(l: ^Line) -> string {
	return string(l.text[:l.len])
}

// ---- numbers ----

@(private)
fmt_buf: [48]u8

// Up to ten significant digits, plain when it fits, else 1.234E+12 (the TRS-80's style).
format :: proc(v: f64) -> string {
	if v == 0 {return "0"}
	if v != v {return "ERROR"}
	tmp: [48]u8
	s := strconv.write_float(tmp[:], v, 'e', 9, 64) // "+d.ddddddddde+XX"
	neg := s[0] == '-'
	digits: [10]u8
	nd := 0
	i := 1
	for ; i < len(s) && s[i] != 'e'; i += 1 {
		if s[i] != '.' && nd < 10 {
			digits[nd] = s[i]
			nd += 1
		}
	}
	exp, _ := strconv.parse_int(s[i + 1:])
	for nd > 1 && digits[nd - 1] == '0' {nd -= 1}
	out := fmt_buf[:]
	n := 0
	put :: proc(out: []u8, n: ^int, c: u8) {
		out[n^] = c
		n^ += 1
	}
	if neg {put(out, &n, '-')}
	if exp >= -6 && exp < 10 {
		if exp < 0 {
			put(out, &n, '0')
			put(out, &n, '.')
			for _ in 0 ..< -exp - 1 {put(out, &n, '0')}
			for k in 0 ..< nd {put(out, &n, digits[k])}
		} else {
			for k in 0 ..= exp {put(out, &n, k < nd ? digits[k] : '0')}
			if nd > exp + 1 {
				put(out, &n, '.')
				for k in exp + 1 ..< nd {put(out, &n, digits[k])}
			}
		}
	} else {
		put(out, &n, digits[0])
		if nd > 1 {
			put(out, &n, '.')
			for k in 1 ..< nd {put(out, &n, digits[k])}
		}
		put(out, &n, 'E')
		put(out, &n, exp < 0 ? '-' : '+')
		e := abs(exp)
		if e >= 100 {put(out, &n, u8('0' + e / 100))}
		put(out, &n, u8('0' + (e / 10) % 10))
		put(out, &n, u8('0' + e % 10))
	}
	return string(out[:n])
}
