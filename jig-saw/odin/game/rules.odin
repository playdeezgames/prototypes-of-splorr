package jigsaw

// Jig Saw. After "Jig Saw" by David Bohlke (SoftSide, March 1979). From the listing: a 4x4 board
// covered by pieces of six shapes (1 a single square, 2 a domino, 3 a straight three, 4 a bent
// three, 5 an L of four, 6 an S of four), turned or flipped any way, in one of the listing's 28
// layouts. The computer names a piece still to place; you name a square (1-16) you think it
// covers. Any square of that piece counts, and the whole piece goes in (a single square goes in
// alone); otherwise "SORRY -- IT DOESN'T FIT THERE." Tries are counted and rated (5-7 Genius ...
// over 21 Try Again). New here: a two-player game on one board (a found piece scores its squares,
// a miss passes the turn), and the squares already tried for the named piece are marked.
// Pure rules: no platform imports.

SQUARES :: 16
SHAPES :: 6

// The listing's layouts (DATA lines 10-76): which shape covers each square, row by row.
LAYOUTS := [28][SQUARES]u8 {
	{5, 5, 6, 6, 5, 6, 6, 3, 5, 4, 2, 3, 4, 4, 2, 3},
	{6, 3, 3, 3, 6, 6, 2, 2, 5, 6, 4, 4, 5, 5, 5, 4},
	{3, 2, 4, 4, 3, 2, 4, 5, 3, 6, 6, 5, 6, 6, 5, 5},
	{4, 5, 5, 5, 4, 4, 6, 5, 2, 2, 6, 6, 3, 3, 3, 6},
	{4, 4, 6, 5, 4, 6, 6, 5, 2, 6, 5, 5, 2, 3, 3, 3},
	{5, 5, 5, 3, 6, 6, 5, 3, 4, 6, 6, 3, 4, 4, 2, 2},
	{3, 3, 3, 2, 5, 5, 6, 2, 5, 6, 6, 4, 5, 6, 4, 4},
	{2, 2, 4, 4, 3, 6, 6, 4, 3, 5, 6, 6, 3, 5, 5, 5},
	{1, 6, 6, 3, 6, 6, 5, 3, 4, 4, 5, 3, 4, 1, 5, 5},
	{3, 3, 3, 5, 6, 5, 5, 5, 6, 6, 4, 1, 1, 6, 4, 4},
	{5, 5, 1, 4, 3, 5, 4, 4, 3, 5, 6, 6, 3, 6, 6, 1},
	{4, 4, 6, 1, 1, 4, 6, 6, 5, 5, 5, 6, 5, 3, 3, 3},
	{5, 5, 6, 1, 1, 5, 6, 6, 4, 5, 1, 6, 4, 4, 2, 2},
	{1, 6, 6, 2, 6, 6, 1, 2, 5, 5, 5, 4, 5, 1, 4, 4},
	{2, 2, 4, 4, 6, 1, 5, 4, 6, 6, 5, 1, 1, 6, 5, 5},
	{4, 4, 1, 5, 4, 5, 5, 5, 2, 1, 6, 6, 2, 6, 6, 1},
	{5, 5, 6, 1, 5, 2, 6, 6, 5, 2, 1, 6, 1, 3, 3, 3},
	{1, 6, 6, 3, 6, 6, 1, 3, 5, 2, 2, 3, 5, 5, 5, 1},
	{3, 3, 3, 1, 6, 1, 2, 5, 6, 6, 2, 5, 1, 6, 5, 5},
	{1, 5, 5, 5, 3, 2, 2, 5, 3, 1, 6, 6, 3, 6, 6, 1},
	{1, 5, 5, 1, 3, 1, 5, 2, 3, 4, 5, 2, 3, 4, 4, 1},
	{1, 2, 2, 1, 5, 5, 5, 4, 5, 1, 4, 4, 1, 3, 3, 3},
	{1, 4, 4, 3, 2, 5, 4, 3, 2, 5, 1, 3, 1, 5, 5, 1},
	{3, 3, 3, 1, 4, 4, 1, 5, 4, 5, 5, 5, 1, 2, 2, 1},
	{1, 6, 4, 4, 6, 6, 1, 4, 6, 1, 2, 2, 3, 3, 3, 1},
	{4, 4, 2, 1, 4, 1, 2, 3, 6, 6, 1, 3, 1, 6, 6, 3},
	{1, 3, 3, 3, 2, 2, 1, 6, 4, 1, 6, 6, 4, 4, 6, 1},
	{3, 6, 6, 1, 3, 1, 6, 6, 3, 2, 1, 4, 1, 2, 4, 4},
}

// Each shape as the key shows it: cells (column, row).
Cell :: [2]int
SHAPE_CELLS := [SHAPES + 1][]Cell {
	{},
	{{0, 0}},
	{{0, 0}, {1, 0}},
	{{0, 0}, {1, 0}, {2, 0}},
	{{0, 0}, {0, 1}, {1, 1}},
	{{0, 0}, {0, 1}, {0, 2}, {1, 2}},
	{{0, 0}, {0, 1}, {1, 1}, {1, 2}},
}

Rating :: struct {
	most:  int,
	title: string,
	line:  string, // at most 23 letters
}

// The article's scale (the jokes are rewritten).
RATINGS := [?]Rating {
	{7, "GENIUS", "THE ECONOMY NEEDS YOU"},
	{10, "EXPERT", "FOUR PUZZLES AT ONCE"},
	{15, "GOOD", "WALK, CHEW GUM, THINK"},
	{20, "FAIR", "ONE THING AT A TIME"},
	{9999, "TRY AGAIN", "EINSTEIN TALKED LATE"},
}

rating :: proc(tries: int) -> Rating {
	for r in RATINGS {if tries <= r.most {return r}}
	return RATINGS[len(RATINGS) - 1]
}

Event :: enum {
	Fit,
	Miss,
	Done,
}

Game :: struct {
	layout:  int,
	shape:   [SQUARES]u8, // shape covering each square
	placed:  [SQUARES]bool,
	tried:   [SQUARES]bool, // squares tried for the piece now named
	named:   int, // the shape asked for (1-6), 0 when done
	tries:   int,
	players: int, // 1 or 2
	turn:    int,
	score:   [2]int, // squares placed, in a two-player game
	tries_p: [2]int,
	last:    int, // the square last tried, -1 before any
	done:    bool,
	events:  bit_set[Event],
	rng:     u64,
}

next_random :: proc(g: ^Game) -> f32 {
	x := g.rng
	x ~= x << 13
	x ~= x >> 7
	x ~= x << 17
	g.rng = x
	return f32(x >> 40) / f32(1 << 24)
}

rand_int :: proc(g: ^Game, n: int) -> int {
	return min(n - 1, int(next_random(g) * f32(n)))
}

new_game :: proc(g: ^Game, seed: u64, players := 1, layout := -1) {
	g^ = {}
	g.rng = seed | 1
	for _ in 0 ..< 4 {next_random(g)}
	g.players = clamp(players, 1, 2)
	g.layout = layout >= 0 ? layout % len(LAYOUTS) : rand_int(g, len(LAYOUTS))
	g.shape = LAYOUTS[g.layout]
	g.last = -1
	name_next(g)
}

// The listing picks a random square still open and names its shape.
name_next :: proc(g: ^Game) {
	g.tried = {}
	open: [SQUARES]int
	n := 0
	for i in 0 ..< SQUARES {if !g.placed[i] {open[n] = i; n += 1}}
	if n == 0 {
		g.named = 0
		g.done = true
		g.events += {.Done}
		return
	}
	g.named = int(g.shape[open[rand_int(g, n)]])
}

// Squares 0-15. Returns false for a square already placed or tried for this piece.
try_square :: proc(g: ^Game, sq: int) -> bool {
	if g.done || sq < 0 || sq >= SQUARES || g.placed[sq] || g.tried[sq] {return false}
	g.tries += 1
	g.tries_p[g.turn] += 1
	g.last = sq
	if int(g.shape[sq]) != g.named {
		g.tried[sq] = true
		g.events += {.Miss}
		if g.players == 2 {g.turn = 1 - g.turn}
		return true
	}
	got := 0
	if g.named == 1 {
		g.placed[sq] = true
		got = 1
	} else {
		for i in 0 ..< SQUARES {
			if int(g.shape[i]) == g.named && !g.placed[i] {g.placed[i] = true; got += 1}
		}
	}
	g.score[g.turn] += got
	g.events += {.Fit}
	name_next(g)
	return true
}

// The fewest tries a layout can take: one per piece.
pieces :: proc(g: ^Game) -> int {
	n := 0
	seen: [SHAPES + 1]bool
	for s in g.shape {
		if s == 1 {n += 1} else if !seen[s] {seen[s] = true; n += 1}
	}
	return n
}
