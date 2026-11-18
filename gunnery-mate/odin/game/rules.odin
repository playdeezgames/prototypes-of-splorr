package gunnery

// Gunnery Mate: you work the remote batteries of a battle station. Raiders jitter about the
// screen one cell at a time; when a raider's centre sits on one of yer batteries, fire. After
// "Death Star" (uncredited, SoftSide, October 1978): ten batteries, three raiders that each step
// at random in any of eight directions (or stay put), twenty-one shots, and a rank at the end
// (under 5 kills, under 8, under 11, or better). The original's film setting is not used.
// Pure rules: no platform imports. Positions are cells of the play grid.

COLS :: 46
ROWS :: 22
BATTERIES :: 10
RAIDERS :: 3
SHOTS :: 21

STEP_START :: 0.26 // seconds between raider moves
STEP_PER_KILL :: 0.008
STEP_MIN :: 0.15

Cell :: [2]int

Event :: enum {
	Bang,
	Kill,
	Miss,
	Moved,
	Over,
}

Rank :: enum {
	School, // under 5
	Demoted, // under 8
	Good, // under 11
	Promoted,
}

Game :: struct {
	batteries: [BATTERIES]Cell,
	raiders:   [RAIDERS]Cell,
	killed_at: [RAIDERS]f32, // clock time a raider was last destroyed (for the page's flash)
	shots:     int,
	kills:     int,
	clock:     f32,
	timer:     f32,
	over:      bool,
	events:    bit_set[Event],
	last_kills: int, // raiders destroyed by the last shot
	rng:       u64,
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
	g.shots = SHOTS
	for i in 0 ..< BATTERIES {
		for {
			c := Cell{2 + rand_int(g, COLS - 4), 1 + rand_int(g, ROWS - 2)}
			ok := true
			for j in 0 ..< i {
				b := g.batteries[j]
				if abs(b.x - c.x) <= 3 && abs(b.y - c.y) <= 1 {ok = false}
			}
			if ok {
				g.batteries[i] = c
				break
			}
		}
	}
	for i in 0 ..< RAIDERS {
		g.raiders[i] = spawn(g)
		g.killed_at[i] = -10
	}
}

// A raider enters somewhere not on a battery.
spawn :: proc(g: ^Game) -> Cell {
	for {
		c := Cell{1 + rand_int(g, COLS - 2), rand_int(g, ROWS)}
		if !on_battery(g, c) {return c}
	}
}

on_battery :: proc(g: ^Game, c: Cell) -> bool {
	for b in g.batteries {if b == c {return true}}
	return false
}

// A raider's centre may go anywhere its three-cell body still fits.
valid :: proc(c: Cell) -> bool {
	return c.x >= 1 && c.x <= COLS - 2 && c.y >= 0 && c.y < ROWS
}

step_time :: proc(g: ^Game) -> f32 {
	return max(STEP_MIN, STEP_START - STEP_PER_KILL * f32(g.kills))
}

update :: proc(g: ^Game, dt: f32) {
	g.clock += dt
	if g.over {return}
	g.timer += dt
	for g.timer >= step_time(g) {
		g.timer -= step_time(g)
		move_raiders(g)
	}
}

move_raiders :: proc(g: ^Game) {
	for &r in g.raiders {
		// One of nine moves, re-rolled until it stays on the grid (as the listing does).
		for {
			n := Cell{r.x + rand_int(g, 3) - 1, r.y + rand_int(g, 3) - 1}
			if valid(n) {
				r = n
				break
			}
		}
	}
	g.events += {.Moved}
}

// Which raiders are lined up on a battery right now.
locked :: proc(g: ^Game) -> (set: bit_set[0 ..< RAIDERS]) {
	for r, i in g.raiders {if on_battery(g, r) {set += {i}}}
	return
}

// Fires the batteries: every raider whose centre is on a battery is destroyed and a new one
// enters. Returns the number destroyed.
fire :: proc(g: ^Game) -> int {
	if g.over || g.shots <= 0 {return 0}
	g.shots -= 1
	g.events += {.Bang}
	n := 0
	for i in locked(g) {
		g.raiders[i] = spawn(g)
		g.killed_at[i] = g.clock
		n += 1
	}
	g.kills += n
	g.last_kills = n
	g.events += n > 0 ? {.Kill} : {.Miss}
	if g.shots == 0 {
		g.over = true
		g.events += {.Over}
	}
	return n
}

rank :: proc(kills: int) -> Rank {
	switch {
	case kills < 5:
		return .School
	case kills < 8:
		return .Demoted
	case kills < 11:
		return .Good
	}
	return .Promoted
}
