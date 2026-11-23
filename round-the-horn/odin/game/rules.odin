package horn

// 'Round the Horn: a clipper race from New York to San Francisco round Cape Horn, 1852. After
// "'Round the Horn" by George Blank (SoftSide, January 1979): one to three ships (the Challenge,
// the Flying Cloud and the Surprise) leave New York the same day; each week a captain sets a
// course, and winds, leeway and ocean currents set the ship along. No ship sails closer than two
// points (45 degrees) to the wind, the course is pushed off and comes back when the wind changes.
// Five climatic regions set the weather. Fewest days to the San Francisco square wins; the record is
// the Flying Cloud's 89 days 21 hours. Pure rules: no platform imports.
//
// Coordinates are the listing's: H is the map column (0..64, west to east) and V the row (0..16,
// north to south), both fractional. The map is the listing's block-graphic map: each cell is two
// by three dots.

COLS :: 64
ROWS :: 16
START_H :: 35.0
START_V :: 1.1
PORT_COL :: 17
PORT_ROW :: 2
STEPS_PER_WEEK :: 14 // half days
MAX_SHIPS :: 3
RECORD_HOURS :: 89 * 24 + 21
ICE_V :: 13.0 // polar ice south of 64 degrees S
MAX_TRACK :: 160

// Cape Horn: no passage north of 55 30 S until 72 W (Notice to Mariners).
HORN_H0 :: 32.0
HORN_H1 :: 35.5
HORN_V0 :: 11.0
HORN_V1 :: 12.04

SHIP_NAMES := [MAX_SHIPS]string{"CHALLENGE", "FLYING CLOUD", "SURPRISE"}
SHIP_INITIALS := [MAX_SHIPS]u8{'C', 'F', 'S'}

// Sixteen points of the compass, 0 = N, clockwise: the listing's DX, DY table.
DX := [16]f32{0, .4, .7, .9, 1, .9, .7, .4, 0, -.4, -.7, -.9, -1, -.9, -.7, -.4}
DY := [16]f32{-1, -.9, -.7, -.4, 0, .4, .7, .9, 1, .9, .7, .4, 0, -.4, -.7, -.9}
POINT_NAMES := [16]string {
	"N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
	"S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW",
}

Weather :: struct {
	pressure: f32, // inches
	trend:    f32,
	knots:    f32,
	dir:      int, // the point the wind blows from
}

Status :: enum u8 {
	Sailing,
	Arrived,
	Wrecked,
}

Event :: enum {
	None,
	Week_Over,
	Arrived,
	Wrecked,
}

Ship :: struct {
	h, v:       f32,
	want:       int, // the course the captain gave
	heading:    int, // the course sailed: pushed off the wind when need be
	half_days:  int,
	status:     Status,
	computer:   bool,
	wx:         Weather, // the weather the ship has this week
	steps_left: int,
	waypoint:   int, // the computer captain's next mark
}

Game :: struct {
	ships:   [MAX_SHIPS]Ship,
	n:       int,
	current: int,
	round:   int,
	regions: [5]Weather,
	rng:     u64,
	over:    bool,
	tracks:  [MAX_SHIPS][MAX_TRACK][2]f32,
	n_track: [MAX_SHIPS]int,
}

// ---- random numbers: xorshift64; rnd(n) is the listing's RND(n), 1..n ----

next :: proc(r: ^u64) -> u64 {
	x := r^
	x ~= x << 13
	x ~= x >> 7
	x ~= x << 17
	r^ = x
	return x
}

rnd :: proc(r: ^u64, n: int) -> int {
	return int(next(r) % u64(n)) + 1
}

frand :: proc(r: ^u64) -> f32 {
	return f32(next(r) >> 40) / f32(1 << 24)
}

// ---- the map ----

@(private)
Span :: struct {
	row, c0, c1: int,
	code:        u8,
}

// The listing's map POKEs: graphics character 128 + dots (1 top left, 2 top right, 4 middle left,
// 8 middle right, 16 bottom left, 32 bottom right). Later spans overwrite earlier ones. Row 5,
// column 28 is closed (the bottom dots, as the coast beside it): no canal at Panama in 1852.
@(private)
SPANS := [?]Span {
	{0, 16, 16, 162}, {0, 17, 33, 191}, {0, 34, 34, 151}, {0, 35, 37, 143}, {0, 38, 38, 142},
	{1, 17, 17, 139}, {1, 18, 32, 191}, {1, 33, 34, 159},
	{2, 18, 18, 162}, {2, 19, 32, 191}, {2, 33, 33, 157},
	{3, 19, 19, 131}, {3, 20, 21, 175}, {3, 22, 25, 191}, {3, 26, 31, 143}, {3, 28, 28, 135},
	{3, 32, 32, 175}, {3, 33, 33, 145},
	{4, 21, 21, 133}, {4, 22, 23, 143}, {4, 24, 26, 191}, {4, 33, 33, 130},
	{5, 26, 26, 139}, {5, 27, 27, 173}, {5, 28, 38, 176},
	{6, 28, 41, 191}, {6, 42, 42, 180}, {6, 43, 43, 144},
	{7, 28, 28, 138}, {7, 29, 43, 191},
	{8, 31, 40, 191}, {8, 41, 41, 143}, {8, 42, 42, 135},
	{9, 31, 36, 191}, {9, 37, 37, 131},
	{10, 31, 35, 191},
	{11, 31, 31, 131}, {11, 32, 33, 191}, {11, 34, 34, 181}, {11, 35, 35, 148},
}

@(private)
land_dots: [ROWS][COLS]u8
@(private)
map_ready: bool

@(private)
ensure_map :: proc() {
	if map_ready {return}
	for s in SPANS {
		for c in s.c0 ..= s.c1 {land_dots[s.row][c] = s.code - 128}
	}
	map_ready = true
}

// The dots of one map cell, for drawing (bit 0 top left .. bit 5 bottom right).
cell_dots :: proc(col, row: int) -> u8 {
	ensure_map()
	if col < 0 || col >= COLS || row < 0 || row >= ROWS {return 0}
	return land_dots[row][col]
}

Ground :: enum u8 {
	Sea,
	Land,
	Ice,
}

ground :: proc(h, v: f32) -> Ground {
	if h < 0 || v < 0 || h >= COLS || v >= ROWS {return .Land} // off the map
	if v >= ICE_V {return .Ice}
	if h >= HORN_H0 && h < HORN_H1 && v >= HORN_V0 && v < HORN_V1 {return .Land}
	px := int(h * 2)
	py := int(v * 3)
	bit := u8(1) << u8((py % 3) * 2 + px % 2)
	return cell_dots(px / 2, py / 3) & bit != 0 ? .Land : .Sea
}

is_land :: proc(h, v: f32) -> bool {
	return ground(h, v) != .Sea
}

at_port :: proc(h, v: f32) -> bool {
	return h >= 0 && v >= 0 && int(h) == PORT_COL && int(v) == PORT_ROW
}

// Land is checked only due N, E, S and W, within two cells (Notice 6). The nearest sighting each
// way; .Sea when none.
Sighting :: struct {
	what:  Ground,
	cells: f32,
}

in_sight :: proc(h, v: f32) -> (seen: [4]Sighting) {
	for side in 0 ..< 4 {
		p := side * 4 // N, E, S, W
		for k := f32(0.5); k <= 2.0; k += 0.5 {
			g := ground(h + DX[p] * k, v + DY[p] * k)
			if g != .Sea {
				seen[side] = {g, k}
				break
			}
		}
	}
	return
}

// ---- where the ship is ----

latitude :: proc(v: f32) -> f32 {
	// Degrees, north positive.
	return v <= 6 ? (6 - v) * 8.2 : -(v - 6) * 9.2
}

longitude :: proc(h: f32) -> f32 {
	// Degrees, west positive.
	return 174 - 3 * h
}

// The five climatic regions, by row: Horse Latitudes, Northeast Trades, Doldrums, Southeast Trades,
// Roaring Forties.
REGION_NAMES := [5]string{"HORSE LATITUDES", "NORTHEAST TRADES", "DOLDRUMS", "SOUTHEAST TRADES", "ROARING FORTIES"}

region :: proc(v: f32) -> int {
	switch {
	case v <= 2.5:
		return 0
	case v <= 5:
		return 1
	case v <= 6.3:
		return 2
	case v <= 9:
		return 3
	}
	return 4
}

// Ocean currents in the region: east and south positive.
current_at :: proc(h, v: f32) -> (ch, cv: f32) {
	switch region(v) {
	case 0:
		if v < 2 && h > 30 && h < 45 {ch, cv = 1.9, -.2} // the Gulf Stream
		if h > 45 {ch, cv = -.4, .8}
		if h > 14 && h < 18 {cv = 1}
	case 1:
		if v > 3.6 {ch = -1.2}
		if h > 15 && h < 20 {cv = .7}
		if h > 32 && h < 37 {cv = -1}
	case 2:
		if h > 45 {ch = 1.3}
	case 3:
		if v < 7 {ch = -2.1}
		if h > 32 && h < 42 {cv = 1.5}
		if h > 48 {cv = -2}
		if h > 24 && h < 31 {cv = -1.8}
	case 4:
		if v > 10.8 {ch = 2.2}
		if h > 27 && h < 37 {cv = -1.8}
		if h > 37 && h < 41 {cv = 1.4}
	}
	return
}

// ---- sailing ----

// Never closer than two points to the wind: the course is pushed off on the side it was given.
fix_heading :: proc(want, wind: int) -> int {
	d := (want - wind + 16) % 16
	if d < 2 {return (wind + 2) % 16}
	if d > 14 {return (wind + 14) % 16}
	return want
}

// Points between the heading and where the wind blows from: 0 (in irons) to 8 (dead before it).
off_wind :: proc(heading, wind: int) -> int {
	d := (heading - wind + 16) % 16
	return min(d, 16 - d)
}

// The wind over the port side.
port_tack :: proc(heading, wind: int) -> bool {
	d := (heading - wind + 16) % 16
	return d >= 1 && d <= 8
}

Point_Of_Sail :: enum u8 {
	Close_Hauled,
	Reach,
	Running,
}

point_of_sail :: proc(heading, wind: int) -> Point_Of_Sail {
	t := off_wind(heading, wind)
	if t <= 3 {return .Close_Hauled}
	if t <= 5 {return .Reach}
	return .Running
}

SAIL_FACTOR := [Point_Of_Sail]f32 {
	.Close_Hauled = .6,
	.Reach        = 1.0,
	.Running      = 1.2,
}

// One half day: the week's weather wanders, the ship sails, leeway and the current set it along.
step_ship :: proc(s: ^Ship, r: ^u64) -> Event {
	if s.status != .Sailing {return .None}
	w := &s.wx
	w.pressure += w.trend
	w.knots = max(0, w.knots + f32(rnd(r, 3) - 2))
	w.dir = (w.dir + rnd(r, 3) - 2 + 16) % 16
	if w.pressure < 28 && w.trend < -0.09 {
		w.knots += f32(rnd(r, 5)) // a storm
		if rnd(r, 12) > 10 {w.trend = -w.trend}
	}
	s.heading = fix_heading(s.want, w.dir)
	m := SAIL_FACTOR[point_of_sail(s.heading, w.dir)] * w.knots / 8
	lee := (w.dir + 8) % 16
	ch, cv := current_at(s.h, s.v)
	dh := DX[s.heading] * m / 6 + DX[lee] * w.knots / 600 + ch / 30
	dv := DY[s.heading] * m / 10 + DY[lee] * w.knots / 1000 + cv / 50
	s.half_days += 1
	h0, v0 := s.h, s.v
	for i in 1 ..= 4 {
		s.h = h0 + dh * f32(i) / 4
		s.v = v0 + dv * f32(i) / 4
		if is_land(s.h, s.v) {
			s.status = .Wrecked
			return .Wrecked
		}
		if at_port(s.h, s.v) {
			s.status = .Arrived
			return .Arrived
		}
	}
	return .None
}

hours :: proc(s: ^Ship) -> int {
	return s.half_days * 12
}

// ---- the race ----

new_game :: proc(g: ^Game, n: int, computer: [MAX_SHIPS]bool, seed: u64) {
	g^ = {}
	g.rng = seed | 1
	g.n = clamp(n, 1, MAX_SHIPS)
	for i in 0 ..< g.n {
		s := &g.ships[i]
		s.h, s.v = START_H, START_V
		s.want = 6 // SE, out of the Sound
		s.heading = 6
		s.computer = computer[i]
		push_track(g, i)
	}
	for &w in g.regions {w.pressure = 29 + frand(&g.rng)}
	new_weather(g)
}

// The weather of each region for a round (the listing's W1 pressure, W2 trend, W3 speed, W4
// direction).
new_weather :: proc(g: ^Game) {
	r := &g.rng
	a := rnd(r, 3)
	for &w, i in g.regions {
		trend, knots, dir: int
		switch i {
		case 0:
			trend = rnd(r, 6) - 1
			if w.pressure > 30 {trend = -trend}
			knots = rnd(r, 7) * rnd(r, a + 1) + rnd(r, 15) - 1
			dir = rnd(r, 16) - 1
		case 1:
			trend = rnd(r, 6) - 1
			if w.pressure > 29.5 {trend = -trend}
			knots = rnd(r, 5) * rnd(r, a + 1)
			if knots < 10 {knots += rnd(r, 15)}
			dir = 2 + rnd(r, 8) - rnd(r, 8)
		case 2:
			trend = rnd(r, 3) - 1
			if w.pressure > 29 {trend = -trend}
			knots = rnd(r, 3) * a + rnd(r, 3) - 1
			dir = rnd(r, 16) - 1
		case 3:
			trend = rnd(r, 6) - 1
			if w.pressure > 30 {trend = -trend}
			knots = rnd(r, 6) * a
			if knots < 10 {knots += rnd(r, 21) - 1}
			dir = 6 + rnd(r, 8) - rnd(r, 8)
			if dir < 0 {dir = 15}
		case 4:
			trend = rnd(r, 3) + 2
			if w.pressure > 29.7 {trend = -trend}
			knots = (3 + rnd(r, 7)) * a
			dir = 11 + rnd(r, 8) - rnd(r, 8)
			if dir > 15 {dir -= 16}
		}
		w.trend = f32(trend)
		w.knots = f32(knots)
		w.dir = (dir % 16 + 16) % 16
		w.pressure += w.trend / 7
	}
}

current_ship :: proc(g: ^Game) -> ^Ship {
	return &g.ships[g.current]
}

// The start of a ship's week: it takes the weather of its region.
begin_week :: proc(g: ^Game) -> ^Ship {
	s := current_ship(g)
	s.wx = g.regions[region(s.v)]
	s.wx.trend /= 50
	s.steps_left = STEPS_PER_WEEK
	return s
}

// A half day of the current ship's week. The computer captain looks ahead before each one.
step :: proc(g: ^Game) -> Event {
	s := current_ship(g)
	if s.status != .Sailing || s.steps_left <= 0 {return .Week_Over}
	if s.computer {s.want = plan(s, g.rng)}
	e := step_ship(s, &g.rng)
	s.steps_left -= 1
	if s.steps_left % 2 == 0 || e != .None {push_track(g, g.current)}
	if e == .None && s.steps_left == 0 {return .Week_Over}
	return e
}

// The next ship still at sea; a new round (and new weather) when the order comes round.
end_week :: proc(g: ^Game) {
	current_ship(g).steps_left = 0
	for k in 1 ..= g.n {
		i := (g.current + k) % g.n
		if g.ships[i].status != .Sailing {continue}
		if i <= g.current {
			g.round += 1
			new_weather(g)
		}
		g.current = i
		return
	}
	g.over = true
}

push_track :: proc(g: ^Game, i: int) {
	s := &g.ships[i]
	n := g.n_track[i]
	if n == MAX_TRACK {
		// Full: keep every other point.
		for k in 0 ..< MAX_TRACK / 2 {g.tracks[i][k] = g.tracks[i][k * 2]}
		n = MAX_TRACK / 2
	}
	g.tracks[i][n] = {s.h, s.v}
	g.n_track[i] = n + 1
}

// The ship that has done best: arrived soonest, else none.
winner :: proc(g: ^Game) -> int {
	best, at := -1, 0
	for i in 0 ..< g.n {
		s := &g.ships[i]
		if s.status != .Arrived {continue}
		if best < 0 || s.half_days < at {best, at = i, s.half_days}
	}
	return best
}

// ---- the computer captain ----

// Marks down the coast of the Americas, round the Horn and up to San Francisco.
WAYPOINTS := [?][2]f32 {
	{40, 3.5}, {46, 6.5}, {45, 9}, {38, 12.52}, {28.5, 12.52}, {29, 9}, {26.5, 6},
	{22, 5.5}, {19, 4}, {17.5, 2.5},
}

LOOK_AHEAD :: 10

@(private)
dist :: proc(h, v: f32, p: [2]f32) -> f32 {
	dh, dv := h - p[0], v - p[1]
	return dh * dh + dv * dv
}

land_near :: proc(h, v, r: f32) -> bool {
	for p := 0; p < 16; p += 2 {
		if is_land(h + DX[p] * r, v + DY[p] * r) {return true}
	}
	return false
}

// Try each course for a few half days of the coming weather and keep the one that makes most
// towards the next mark without running ashore.
plan :: proc(s: ^Ship, rng: u64) -> int {
	for s.waypoint < len(WAYPOINTS) - 1 && dist(s.h, s.v, WAYPOINTS[s.waypoint]) < 1.5 * 1.5 {
		s.waypoint += 1
	}
	mark := WAYPOINTS[s.waypoint]
	best, best_score := s.want, f32(-1e30)
	for want in 0 ..< 16 {
		c := s^
		c.want = want
		r := rng
		score: f32
		ended := false
		for k in 0 ..< LOOK_AHEAD {
			e := step_ship(&c, &r)
			if e == .Wrecked {
				score = -1e9 + f32(k)
				ended = true
				break
			}
			if e == .Arrived {
				score = 1e9 - f32(k)
				ended = true
				break
			}
		}
		if !ended {
			score = -dist(c.h, c.v, mark)
			if land_near(c.h, c.v, 0.3) {score -= 8}
		}
		if want == s.want {score += 0.001}
		if score > best_score {best, best_score = want, score}
	}
	return best
}
