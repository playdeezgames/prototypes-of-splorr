package gallery

// Shooting Gallery: a carnival gallery with twenty shots. After "Shooting Gallery" by Frank B.
// Rowlett, Jr. (SoftSide, August 1979): rows of stars (50), clowns (10), pipes (25) and ducks
// (15) scroll in alternating directions, a 100-point arrow flies across now and then, a hit
// target leaves a gap until its row wraps round, and a shot at an empty spot is still spent.
// Pure rules: no platform imports. Coordinates are the page's logical pixels.

W :: 384
H :: 240

SIGHT_TOP :: 24
SIGHT_BOTTOM :: 172
SIGHT_SPEED :: 130 // px per second with the keys
SHOTS :: 20

Kind :: enum {
	Star,
	Clown,
	Pipe,
	Duck,
	Arrow,
}

POINTS := [Kind]int {
	.Star  = 50,
	.Clown = 10,
	.Pipe  = 25,
	.Duck  = 15,
	.Arrow = 100,
}

Row_Def :: struct {
	kind:    Kind,
	y, h:    int,
	w:       int, // target width
	spacing: int, // distance from one target to the next
	speed:   f32, // px per second; negative scrolls left
}

ROWS := [4]Row_Def {
	{.Star, 44, 8, 8, 48, -42},
	{.Clown, 78, 16, 16, 64, 22},
	{.Pipe, 120, 12, 8, 48, -32},
	{.Duck, 148, 12, 14, 56, 36},
}

// The arrow's three lanes sit between the rows.
ARROW_LANES := [3]int{30, 62, 104}
ARROW_W :: 18
ARROW_H :: 5
ARROW_SPEED :: 170
ARROW_CHANCE :: 0.12 // per second while no arrow is flying

MAX_SLOTS :: 12

Row :: struct {
	offset: f32, // scroll position, kept in [0, ring)
	alive:  [MAX_SLOTS]bool,
	slots:  int,
}

Arrow :: struct {
	active: bool,
	x:      f32,
	lane:   int,
}

Event :: enum {
	Bang,
	Hit,
	Miss,
	Arrow_Appears,
	Arrow_Hit,
	Game_Over,
}

Game :: struct {
	rows:         [len(ROWS)]Row,
	arrow:        Arrow,
	sx, sy:       f32, // sight
	shots:        int,
	score:        int,
	over:         bool,
	clock:        f32,
	last_hit:     Kind,
	last_points:  int,
	events:       bit_set[Event],
	rng:          u64,
}

ring :: proc(def: Row_Def, row: Row) -> f32 {
	return f32(def.spacing * row.slots)
}

new_game :: proc(g: ^Game, seed: u64) {
	g^ = {}
	g.rng = seed | 1
	g.shots = SHOTS
	g.sx = W / 2
	g.sy = f32(ROWS[1].y + 8)
	for def, i in ROWS {
		r := &g.rows[i]
		r.slots = min(MAX_SLOTS, (W + def.spacing - 1) / def.spacing + 1)
		for s in 0 ..< r.slots {r.alive[s] = true}
		r.offset = f32(i * 13)
	}
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

// The left edge of slot s in row i, in screen pixels (may be off screen).
slot_x :: proc(g: ^Game, i, s: int) -> f32 {
	def := ROWS[i]
	r := g.rows[i]
	x := f32(s * def.spacing) + r.offset
	rl := ring(def, r)
	for x >= rl {x -= rl}
	return x - f32(def.spacing)
}

update :: proc(g: ^Game, dt: f32) {
	g.clock += dt
	if g.over {return}
	for def, i in ROWS {
		r := &g.rows[i]
		rl := ring(def, r^)
		before: [MAX_SLOTS]f32
		for s in 0 ..< r.slots {before[s] = slot_x(g, i, s)}
		r.offset += def.speed * dt
		for r.offset >= rl {r.offset -= rl}
		for r.offset < 0 {r.offset += rl}
		// A target that wrapped round re-enters as a fresh one.
		for s in 0 ..< r.slots {
			after := slot_x(g, i, s)
			if abs(after - before[s]) > rl / 2 {r.alive[s] = true}
		}
	}
	if g.arrow.active {
		g.arrow.x += ARROW_SPEED * dt
		if g.arrow.x > W {g.arrow.active = false}
	} else if next_random(g) < ARROW_CHANCE * dt {
		g.arrow = {true, -ARROW_W, int(next_random(g) * 3) % 3}
		g.events += {.Arrow_Appears}
	}
}

// Moves the sight by a direction (keys) for dt seconds.
nudge :: proc(g: ^Game, dx, dy: f32, dt: f32) {
	aim(g, g.sx + dx * SIGHT_SPEED * dt, g.sy + dy * SIGHT_SPEED * dt)
}

// Puts the sight at a point (pointer), kept inside the gallery.
aim :: proc(g: ^Game, x, y: f32) {
	g.sx = clamp(x, 4, W - 4)
	g.sy = clamp(y, SIGHT_TOP, SIGHT_BOTTOM)
}

// Spends a shot at the sight. Returns the points scored (0 for a miss).
fire :: proc(g: ^Game) -> int {
	if g.over || g.shots <= 0 {return 0}
	g.shots -= 1
	g.events += {.Bang}
	pts := 0
	x, y := g.sx, g.sy
	if g.arrow.active {
		ay := f32(ARROW_LANES[g.arrow.lane])
		if x >= g.arrow.x - 1 && x < g.arrow.x + ARROW_W + 1 && y >= ay - 2 && y < ay + ARROW_H + 2 {
			g.arrow.active = false
			pts = POINTS[.Arrow]
			g.last_hit = .Arrow
			g.events += {.Arrow_Hit}
		}
	}
	if pts == 0 {
		rows: for def, i in ROWS {
			if y < f32(def.y) || y >= f32(def.y + def.h) {continue}
			for s in 0 ..< g.rows[i].slots {
				sx := slot_x(g, i, s)
				if g.rows[i].alive[s] && x >= sx && x < sx + f32(def.w) {
					g.rows[i].alive[s] = false
					pts = POINTS[def.kind]
					g.last_hit = def.kind
					g.events += {.Hit}
					break rows
				}
			}
		}
	}
	if pts == 0 {g.events += {.Miss}}
	g.last_points = pts
	g.score += pts
	if g.shots == 0 {
		g.over = true
		g.events += {.Game_Over}
	}
	return pts
}
