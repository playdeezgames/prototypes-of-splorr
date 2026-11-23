package sketch

// Comput-A-Sketch: a sketching toy. After "Comput-A-Sketch" by Albert C. Blackwell, Jr. (SoftSide,
// January 1979): a bordered pad, a stylus that starts in the middle, eight draw keys that move it
// and leave a line (R right, L left, U up, D down, Z up-left, M up-right, K down-left, S
// down-right), four keys that move it without drawing and erase what they cross (Q left, P right,
// O up, N down), the border that keeps it in, and C to clear. Pure rules: no platform imports.

PAD_W :: 92
PAD_H :: 72

Dir :: enum {
	Right,
	Left,
	Up,
	Down,
	Up_Left,
	Up_Right,
	Down_Left,
	Down_Right,
}

DX := [Dir]int {
	.Right      = 1,
	.Left       = -1,
	.Up         = 0,
	.Down       = 0,
	.Up_Left    = -1,
	.Up_Right   = 1,
	.Down_Left  = -1,
	.Down_Right = 1,
}

DY := [Dir]int {
	.Right      = 0,
	.Left       = 0,
	.Up         = -1,
	.Down       = 1,
	.Up_Left    = -1,
	.Up_Right   = -1,
	.Down_Left  = 1,
	.Down_Right = 1,
}

Pad :: struct {
	dots:  [PAD_H][PAD_W]bool,
	x, y:  int,
	moves: int, // changes since the last save, for the page
}

clear :: proc(p: ^Pad) {
	p.dots = {}
	home(p)
	p.moves += 1
}

// The stylus back to the middle, as the listing's X=75:Y=25.
home :: proc(p: ^Pad) {
	p.x = PAD_W / 2
	p.y = PAD_H / 2
}

@(private)
keep_in :: proc(p: ^Pad) {
	p.x = clamp(p.x, 0, PAD_W - 1)
	p.y = clamp(p.y, 0, PAD_H - 1)
}

// A draw key: move one step, then leave a dot.
draw :: proc(p: ^Pad, d: Dir) {
	p.x += DX[d]
	p.y += DY[d]
	keep_in(p)
	p.dots[p.y][p.x] = true
	p.moves += 1
}

// A move key: lift what is under the stylus, then step (the listing's RESET then move).
move :: proc(p: ^Pad, d: Dir) {
	p.dots[p.y][p.x] = false
	p.x += DX[d]
	p.y += DY[d]
	keep_in(p)
	p.moves += 1
}

// The listing's keys; ok false for any other.
key_dir :: proc(c: int) -> (d: Dir, drawing: bool, ok: bool) {
	switch c {
	case 'R':
		return .Right, true, true
	case 'L':
		return .Left, true, true
	case 'U':
		return .Up, true, true
	case 'D':
		return .Down, true, true
	case 'Z':
		return .Up_Left, true, true
	case 'M':
		return .Up_Right, true, true
	case 'K':
		return .Down_Left, true, true
	case 'S':
		return .Down_Right, true, true
	case 'Q':
		return .Left, false, true
	case 'P':
		return .Right, false, true
	case 'O':
		return .Up, false, true
	case 'N':
		return .Down, false, true
	}
	return .Right, false, false
}

// The direction of one step from the stylus toward (tx, ty), or false when already there.
toward :: proc(p: ^Pad, tx, ty: int) -> (Dir, bool) {
	sx := sign(tx - p.x)
	sy := sign(ty - p.y)
	for d in Dir {
		if DX[d] == sx && DY[d] == sy {return d, true}
	}
	return .Right, false
}

@(private)
sign :: proc(v: int) -> int {
	if v > 0 {return 1}
	if v < 0 {return -1}
	return 0
}

// ---- saving: the stylus and the dots as text ----

HEX := "0123456789abcdef"

// Writes "x,y," then the dots, four to a hex digit, row by row, into buf.
encode :: proc(p: ^Pad, buf: []u8) -> string {
	n := 0
	put_int :: proc(buf: []u8, n: ^int, v: int) {
		if v >= 10 {put_int(buf, n, v / 10)}
		buf[n^] = u8('0' + v % 10)
		n^ += 1
	}
	put_int(buf, &n, p.x)
	buf[n] = ','
	n += 1
	put_int(buf, &n, p.y)
	buf[n] = ','
	n += 1
	for row in 0 ..< PAD_H {
		for col := 0; col < PAD_W; col += 4 {
			v := 0
			for b in 0 ..< 4 {
				if col + b < PAD_W && p.dots[row][col + b] {v |= 1 << uint(b)}
			}
			buf[n] = HEX[v]
			n += 1
		}
	}
	return string(buf[:n])
}

ENCODED_MAX :: 12 + PAD_H * ((PAD_W + 3) / 4)

decode :: proc(p: ^Pad, s: string) -> bool {
	i := 0
	read_int :: proc(s: string, i: ^int) -> (int, bool) {
		v, digits := 0, 0
		for i^ < len(s) && s[i^] >= '0' && s[i^] <= '9' {
			v = v * 10 + int(s[i^] - '0')
			i^ += 1
			digits += 1
		}
		if digits == 0 || i^ >= len(s) || s[i^] != ',' {return 0, false}
		i^ += 1
		return v, true
	}
	x, ok1 := read_int(s, &i)
	y, ok2 := read_int(s, &i)
	if !ok1 || !ok2 {return false}
	per_row := (PAD_W + 3) / 4
	if len(s) - i != PAD_H * per_row {return false}
	q: Pad
	for row in 0 ..< PAD_H {
		for k in 0 ..< per_row {
			ch := s[i]
			i += 1
			v: int
			switch ch {
			case '0' ..= '9':
				v = int(ch - '0')
			case 'a' ..= 'f':
				v = int(ch - 'a') + 10
			case:
				return false
			}
			for b in 0 ..< 4 {
				col := k * 4 + b
				if col < PAD_W && v & (1 << uint(b)) != 0 {q.dots[row][col] = true}
			}
		}
	}
	q.x, q.y = x, y
	keep_in(&q)
	p^ = q
	return true
}
