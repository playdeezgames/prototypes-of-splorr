package trolls

// Troll's Gold: a cave of six by six rooms. The gold is in the deepest room (bottom right), and
// so is the troll. Each turn a fresh set of doors stands open; you step through one (or stay
// put), then the troll comes a step closer through the same open doors (every third turn it stops
// to catch its breath instead, and you can see it coming). Take the gold and carry it back out the cave mouth
// (top left). After "Troll's Gold" by George Blank (SoftSide, November 1978).
// Pure rules: no platform imports. Rooms are numbered 0..35, row by row from the top left.

COLS :: 6
ROWS :: 6
ROOMS :: COLS * ROWS
H_DOORS :: ROWS * (COLS - 1) // between a room and the one to its right
DOORS :: H_DOORS + (ROWS - 1) * COLS // plus those between a room and the one below
OPEN_PER_TURN :: 24 // of the 60 doors, how many stand open each turn
REST_EVERY :: 3 // the troll is big and slow: every third turn it stops to catch its breath

ENTRANCE :: 0
GOLD_ROOM :: ROOMS - 1

Dir :: enum {
	Up,
	Down,
	Left,
	Right,
	Stay,
}

Event :: enum {
	Moved,
	Blocked,
	Gold,
	Troll_Moved,
	Troll_Rested,
	Eaten,
	Escaped,
}

Game :: struct {
	open:        [DOORS]bool,
	player:      int,
	troll:       int,
	gold:        bool, // the player is carrying it
	turns:       int,
	over:        bool,
	won:         bool,
	events:      bit_set[Event],
	troll_from:  int, // where the troll was before its last move (for the page)
	troll_steps: int,
	rng:         u64,
}

next_random :: proc(g: ^Game) -> f32 {
	// xorshift64*
	x := g.rng
	x ~= x >> 12
	x ~= x << 25
	x ~= x >> 27
	g.rng = x
	return f32((x * 0x2545F4914F6CDD1D) >> 40) / f32(1 << 24)
}

rand_int :: proc(g: ^Game, n: int) -> int {
	return min(n - 1, int(next_random(g) * f32(n)))
}

new_game :: proc(g: ^Game, seed: u64) {
	g^ = {}
	g.rng = seed | 1
	g.player = ENTRANCE
	g.troll = GOLD_ROOM
	g.troll_from = GOLD_ROOM
	shuffle_doors(g)
}

row_of :: proc(room: int) -> int {return room / COLS}
col_of :: proc(room: int) -> int {return room % COLS}

// The door between two rooms side by side or one above the other.
door_between :: proc(a, b: int) -> (door: int, ok: bool) {
	lo, hi := min(a, b), max(a, b)
	if lo < 0 || hi >= ROOMS {return}
	if hi - lo == 1 && row_of(lo) == row_of(hi) {
		return row_of(lo) * (COLS - 1) + col_of(lo), true
	}
	if hi - lo == COLS {
		return H_DOORS + lo, true
	}
	return
}

// The room a step away in a direction, if there is one (Stay is the room itself).
neighbour :: proc(room: int, d: Dir) -> (to: int, ok: bool) {
	r, c := row_of(room), col_of(room)
	switch d {
	case .Up:
		if r > 0 {return room - COLS, true}
	case .Down:
		if r < ROWS - 1 {return room + COLS, true}
	case .Left:
		if c > 0 {return room - 1, true}
	case .Right:
		if c < COLS - 1 {return room + 1, true}
	case .Stay:
		return room, true
	}
	return
}

// Whether a step from a room in a direction goes through an open door right now.
can_go :: proc(g: ^Game, room: int, d: Dir) -> (to: int, ok: bool) {
	to = neighbour(room, d) or_return
	if d == .Stay {return to, true}
	door, _ := door_between(room, to)
	return to, g.open[door]
}

// Shuts every door and opens a fresh OPEN_PER_TURN of them at random.
shuffle_doors :: proc(g: ^Game) {
	g.open = {}
	n := 0
	for n < OPEN_PER_TURN {
		d := rand_int(g, DOORS)
		if !g.open[d] {
			g.open[d] = true
			n += 1
		}
	}
}

// The player's move. A shut door costs nothing (Blocked, try another way). Returns whether a turn
// was taken; after one, the troll moves (troll_turn) and the doors change (shuffle_doors).
player_move :: proc(g: ^Game, d: Dir) -> bool {
	if g.over {return false}
	to, ok := can_go(g, g.player, d)
	if !ok {
		g.events += {.Blocked}
		return false
	}
	g.turns += 1
	g.player = to
	if d != .Stay {g.events += {.Moved}}
	if g.player == g.troll {
		eaten(g)
		return true
	}
	if g.player == GOLD_ROOM && !g.gold {
		g.gold = true
		g.events += {.Gold}
	}
	if g.player == ENTRANCE && g.gold {
		g.over = true
		g.won = true
		g.events += {.Escaped}
	}
	return true
}

eaten :: proc(g: ^Game) {
	g.over = true
	g.won = false
	g.events += {.Eaten}
}

// Whether the troll will sit out the coming turn to catch its breath (the page shows this).
troll_winded :: proc(g: ^Game) -> bool {
	return (g.turns + 1) % REST_EVERY == 0
}

// The troll's move: one step toward you through an open door, along the longer gap first (up or
// down toward yer row, or across toward yer column) and the other way if that door is shut. It
// eats you the moment it reaches yer room.
troll_turn :: proc(g: ^Game) {
	g.troll_from = g.troll
	g.troll_steps = 0
	if g.over {return}
	if g.turns % REST_EVERY == 0 {
		g.events += {.Troll_Rested}
		return
	}
	dr := row_of(g.player) - row_of(g.troll)
	dc := col_of(g.player) - col_of(g.troll)
	vert: Dir = dr < 0 ? .Up : .Down
	across: Dir = dc < 0 ? .Left : .Right
	tries: [2]Dir = {vert, across}
	if abs(dc) > abs(dr) {tries = {across, vert}}
	for d in tries {
		gap := (d == .Up || d == .Down) ? dr : dc
		if gap == 0 {continue}
		if to, ok := can_go(g, g.troll, d); ok {
			g.troll = to
			g.troll_steps = 1
			break
		}
	}
	if g.troll_steps > 0 {g.events += {.Troll_Moved}}
	if g.troll == g.player {eaten(g)}
}

// A whole turn: yer move, the troll's, then new doors. Returns false (nothing happens) when the
// way is shut.
take_turn :: proc(g: ^Game, d: Dir) -> bool {
	if !player_move(g, d) {return false}
	troll_turn(g)
	if !g.over {shuffle_doors(g)}
	return true
}
