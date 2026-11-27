package rabbits

// Rabbits and Foxes. After "Rabbits and Foxes" by Russell Starkey (SoftSide, April 1979), a Toy.
// From the listing: rabbits with an infinite food supply and foxes that prey on them,
//   rabbits D = D + B * (2D - A*D*C)
//   foxes   C = C + B * (A*D*C - C)
// with step size B = .02 and encounter factor A = .01; the starting numbers 25-400; the counts with
// their least and most shown every fifth step; it stops when either is down to one. (The balance
// is 100 rabbits and 200 foxes; started anywhere else, the swings grow until one side dies out.)
// New here: rabbits or foxes released mid-run, and a history for a chart. Pure rules.

A :: 0.01
B :: 0.02
HISTORY :: 512
SHOW_EVERY :: 5 // the listing prints every fifth step

Ending :: enum u8 {
	None,
	No_Rabbits,
	No_Foxes,
}

Model :: struct {
	rabbits, foxes:     f64, // the listing's D and C
	start_r, start_f:   int,
	steps:              int,
	min_r, max_r:       int,
	min_f, max_f:       int,
	hist_r, hist_f:     [HISTORY]f32, // every SHOW_EVERY steps
	hist_n:             int, // samples kept (wraps)
	ending:             Ending,
}

reset :: proc(m: ^Model, rabbits, foxes: int) {
	m^ = {}
	m.start_r = clamp(rabbits, 25, 400)
	m.start_f = clamp(foxes, 25, 400)
	m.rabbits = f64(m.start_r)
	m.foxes = f64(m.start_f)
	m.min_r, m.max_r = m.start_r, m.start_r
	m.min_f, m.max_f = m.start_f, m.start_f
	record(m)
}

rabbit_count :: proc(m: ^Model) -> int {return int(m.rabbits)}
fox_count :: proc(m: ^Model) -> int {return int(m.foxes)}

record :: proc(m: ^Model) {
	i := m.hist_n % HISTORY
	m.hist_r[i] = f32(m.rabbits)
	m.hist_f[i] = f32(m.foxes)
	m.hist_n += 1
}

// One step of lines 150-180 (the listing reads the old D in the foxes' line through E).
step :: proc(m: ^Model) {
	if m.ending != .None {return}
	e := A * m.rabbits * m.foxes
	m.foxes = m.foxes + B * (e - m.foxes)
	m.rabbits = m.rabbits + B * (2 * m.rabbits - e)
	if m.rabbits < 0 {m.rabbits = 0}
	if m.foxes < 0 {m.foxes = 0}
	m.steps += 1
	r, f := rabbit_count(m), fox_count(m)
	m.min_r = min(m.min_r, r)
	m.max_r = max(m.max_r, r)
	m.min_f = min(m.min_f, f)
	m.max_f = max(m.max_f, f)
	if m.steps % SHOW_EVERY == 0 {record(m)}
	if r <= 1 {m.ending = .No_Rabbits; record(m)} else if f <= 1 {m.ending = .No_Foxes; record(m)}
}

// Released into the meadow (new).
add :: proc(m: ^Model, rabbits, foxes: int) {
	if m.ending != .None {return}
	m.rabbits += f64(rabbits)
	m.foxes += f64(foxes)
	m.max_r = max(m.max_r, rabbit_count(m))
	m.max_f = max(m.max_f, fox_count(m))
}

// The i-th kept sample, oldest first.
sample :: proc(m: ^Model, i: int) -> (r, f: f32) {
	n := min(m.hist_n, HISTORY)
	first := m.hist_n - n
	j := (first + i) % HISTORY
	return m.hist_r[j], m.hist_f[j]
}

samples :: proc(m: ^Model) -> int {return min(m.hist_n, HISTORY)}
