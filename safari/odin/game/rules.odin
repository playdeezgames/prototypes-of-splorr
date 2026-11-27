package safari

// Safari. After "Safari" by David J. Bohlke (SoftSide, April 1979). From the listing: one to six
// Bwanas, each with a base camp on a 13 by 13 country of 169 regions (no two camps side by side);
// about one region in five holds one of nine animals; disasters wait in empty regions (1+2L, then
// pairs of 5+2L, 6+2L and 12+2L, for level L 1-3). At base: four scouts (one for each direction),
// six cameramen, twenty bearers, three cameras and 5000 lb of supplies; a party takes some scouts,
// cameras (three reels each, two cameramen apiece) and at least three bearers (100 lb each). A
// day's journey is one region N, E, S or W; S stays, L sends a scout for a map at his life. The
// scouts report each way as a path: six blocks an animal, four nothing, three no scout there, a
// solid path a base camp, none the edge of the country. In an animal's region, steer the camera
// frame over the animal and snap: 80, 50 or 30 contract points for the first, second and third
// to film there, plus 10 for each region from base, counting down while you aim. A day eats
// 10 + 6 a cameraman + 10 a scout + 3 a bearer pounds; under 100 lb the bearers, then the
// cameramen, starve; eight hungry days and a scout brings a map anyway. A Bwana is out when base
// cannot outfit a party (two cameramen, a camera, three bearers, 200 lb) or no cameras or
// cameramen are left; when all are out, the most points wins.
// New here: computer Bwanas for any seat, and a Bwana may retire at base (so a game can end
// without starving the camp out). Pure rules: no platform imports.

SIZE :: 13
MAX_PLAYERS :: 6

ANIMALS := [10]string{"", "LION", "CHARGING TIGER", "BULL ELEPHANT", "BABOON", "RHINO", "FLEETING IMPALA", "LEOPARD", "GIRAFFE", "MUDDY HIPPO"}

// The listing's causes (lines 691-699).
CAUSES := [10]string{"", "IN QUICKSAND.", "TO WILD ANIMALS.", "BY SNAKE BITE.", "BY EXHAUSTION.", "TO FEVER.", "IN STAMPEDE.", "IN BRUSH FIRE.", "IN FLASH FLOOD.", "TO WARRING NATIVES."}

// The listing's quiet days (lines 3501-3509).
QUIPS := [10]string{"", "NO EXCITEMENT TODAY.", "A WEARY DAY.", "NO ACTION TODAY.", "BETTER LUCK TOMORROW.", "MAYBE YOU'LL FIND SOMETHING TOMORROW.", "IS IT REALLY WORTH IT?", "NO LUCK AGAIN.", "THOSE SCOUTS ARE LOUSY.", "I WONDER HOW THE OTHERS ARE DOING."}

Dir :: enum {
	North,
	East,
	South,
	West,
}

DIR_NAME := [Dir]string {
	.North = "NORTH",
	.East  = "EAST",
	.South = "SOUTH",
	.West  = "WEST",
}

DR := [Dir]int {
	.North = -1,
	.East  = 0,
	.South = 1,
	.West  = 0,
}
DC := [Dir]int {
	.North = 0,
	.East  = 1,
	.South = 0,
	.West  = -1,
}

Scout :: enum u8 {
	Base,
	Party,
	Dead,
}

// What a scout reports (the path's look).
Report :: enum u8 {
	Edge, // no path: no passage
	Base_Camp, // a solid path
	Animal, // six blocks
	Nothing, // four blocks
	No_Scout, // three blocks
}

// The cell codes, as in the listing: 0 empty, 1-7 a disaster, 10*animal + times filmed, 100+b a base.
HEAD_HUNTERS :: 1
SCOUT_LOST :: 2
CREWMAN_LOST :: 3
BEARER_LOST :: 4
SUPPLIES_LOST :: 5
CAMERA_LOST :: 6
DISORIENTED :: 7

Msg_Kind :: enum u8 {
	Quip, // a = quip
	Home, // made it to base
	Other_Base,
	No_Film, // a = animal
	No_Crew, // a = animal
	Too_Late, // a = animal
	Got_Picture, // a = animal, n = points
	Missed_Picture,
	Too_Slow,
	Head_Hunters,
	Weary,
	Scout_Lost, // a = cause
	Crewman_Lost, // a = cause
	Bearer_Lost, // a = cause
	Supplies_Lost, // n = pounds, a = cause
	Camera_Lost, // a = cause
	Disoriented,
	Bearer_Starved,
	Cameraman_Starved,
	Map, // a: 0 scout, 1 scout from base, 2 cameraman, 3 cameraman from base, 4 from a high peak; n = 1 when forced
	Stayed,
	Out_No_Cameras,
	Out_No_Outfit,
	Retired,
}

Msg :: struct {
	kind: Msg_Kind,
	a, n: int,
}

Phase :: enum u8 {
	Outfit, // at base: choose the party
	Move, // choose a direction
	Filming,
	Report, // the end-of-day survey; next_turn to go on
	Over,
}

// The camera, in TRS-80 screen characters (64 by 16), as in lines 7150-7720.
Film :: struct {
	p1, p2: int, // the frame's top-left (1-40, 1-7)
	a1, a2: int, // the animal (0-50, 2-13)
	pp:     int, // points left, counting down
	animal: int,
	done:   bool,
	hit:    bool,
}

Player :: struct {
	computer:     bool,
	r, c:         int,
	br, bc:       int,
	scouts:       [Dir]Scout,
	men:          [2]int, // cameramen: [0] party, [1] base
	bearers:      [2]int,
	cameras:      [2]int,
	supplies:     [2]int,
	film:         int, // reels in the party
	points:       int,
	days:         int,
	hungry:       int, // days begun under 100 lb (the listing's X)
	out:          bool,
	retired:      bool,
	shown_map:    bool, // a map was just made (the page shows it)
	// the computer's notebook
	ai_known:     bool, // knows where it is
	ai_kr, ai_kc: int,
	ai_danger:    [SIZE][SIZE]bool,
	ai_done:      [SIZE][SIZE]bool, // no more points to be had here
	ai_target:    [2]int,
	ai_home:      bool,
}

Game :: struct {
	players:  int,
	level:    int,
	cell:     [SIZE][SIZE]int,
	start:    [SIZE][SIZE]int, // the map shown at the start (animals and camps)
	p:        [MAX_PLAYERS]Player,
	turn:     int,
	phase:    Phase,
	msgs:     [8]Msg,
	nmsg:     int,
	film:     Film,
	at_base:  bool, // the day ended at the player's own base
	rng:      u64,
}

next_random :: proc(g: ^Game) -> f32 {
	x := g.rng
	x ~= x << 13
	x ~= x >> 7
	x ~= x << 17
	g.rng = x
	return f32(x >> 40) / f32(1 << 24)
}

// RND(n): 1..n, as in TRS-80 BASIC.
rnd :: proc(g: ^Game, n: int) -> int {
	return 1 + min(n - 1, int(next_random(g) * f32(n)))
}

say :: proc(g: ^Game, kind: Msg_Kind, a := 0, n := 0) {
	if g.nmsg < len(g.msgs) {
		g.msgs[g.nmsg] = {kind, a, n}
		g.nmsg += 1
	}
}

is_animal :: proc(v: int) -> bool {return v >= 10 && v < 100}
animal_of :: proc(v: int) -> int {return v / 10}
is_base :: proc(v: int) -> bool {return v >= 100}

// GOSUB 190: a random empty region.
random_empty :: proc(g: ^Game) -> (r, c: int) {
	for {
		r = rnd(g, SIZE) - 1
		c = rnd(g, SIZE) - 1
		if g.cell[r][c] == 0 {return}
	}
}

new_game :: proc(g: ^Game, seed: u64, players: int, level: int, computer: []bool = nil) {
	g^ = {}
	g.rng = seed | 1
	for _ in 0 ..< 4 {next_random(g)}
	g.players = clamp(players, 1, MAX_PLAYERS)
	g.level = clamp(level, 1, 3)
	// base camps (lines 50-56): rows and columns 1-10, nothing beside them
	for b in 0 ..< g.players {
		for {
			r := rnd(g, 10)
			c := rnd(g, 10)
			if g.cell[r][c] != 0 || g.cell[r + 1][c] != 0 || g.cell[r - 1][c] != 0 || g.cell[r][c + 1] != 0 || g.cell[r][c - 1] != 0 {continue}
			g.cell[r][c] = 100 + b
			pl := &g.p[b]
			pl.r, pl.c, pl.br, pl.bc = r, c, r, c
			break
		}
	}
	// animals (lines 60-125): one region in five, the kinds dealt in turn
	kind := 0
	for r in 0 ..< SIZE {
		for c in 0 ..< SIZE {
			if g.cell[r][c] != 0 {continue}
			if rnd(g, 5) == 1 {
				kind += 1
				if kind == 10 {kind = 1}
				g.cell[r][c] = 10 * kind
			}
		}
	}
	g.start = g.cell
	// disasters (lines 135-155)
	dl := g.level * 2
	for _ in 0 ..< 1 + dl {r, c := random_empty(g); g.cell[r][c] = HEAD_HUNTERS}
	for _ in 0 ..< 5 + dl {
		r, c := random_empty(g); g.cell[r][c] = CREWMAN_LOST
		r, c = random_empty(g); g.cell[r][c] = CAMERA_LOST
	}
	for _ in 0 ..< 6 + dl {
		r, c := random_empty(g); g.cell[r][c] = SCOUT_LOST
		r, c = random_empty(g); g.cell[r][c] = DISORIENTED
	}
	for _ in 0 ..< 12 + dl {
		r, c := random_empty(g); g.cell[r][c] = BEARER_LOST
		r, c = random_empty(g); g.cell[r][c] = SUPPLIES_LOST
	}
	// the camps (lines 160-165)
	for b in 0 ..< g.players {
		pl := &g.p[b]
		pl.men[1] = 6
		pl.bearers[1] = 20
		pl.cameras[1] = 3
		pl.supplies[1] = 5000
		pl.computer = computer != nil && b < len(computer) && computer[b]
		pl.ai_known = true
		pl.ai_kr, pl.ai_kc = pl.r, pl.c
	}
	g.turn = 0
	begin_turn(g)
}

cur :: proc(g: ^Game) -> ^Player {return &g.p[g.turn]}

at_own_base :: proc(g: ^Game, pl: ^Player) -> bool {
	return pl.r == pl.br && pl.c == pl.bc
}

// GOSUB 950: the party comes home.
merge_party :: proc(pl: ^Player) {
	for &s in pl.scouts {if s != .Dead {s = .Base}}
	pl.men[1] += pl.men[0]
	pl.bearers[1] += pl.bearers[0]
	pl.cameras[1] += pl.cameras[0]
	pl.supplies[1] += pl.supplies[0]
	pl.men[0], pl.bearers[0], pl.cameras[0], pl.supplies[0], pl.film = 0, 0, 0, 0, 0
}

party_scouts :: proc(pl: ^Player) -> int {
	n := 0
	for s in pl.scouts {if s == .Party {n += 1}}
	return n
}

// The listing's minimum at base (line 800; three bearers, as the article and line 865 say).
can_outfit :: proc(pl: ^Player) -> bool {
	return pl.men[1] >= 2 && pl.bearers[1] >= 3 && pl.cameras[1] >= 1 && pl.supplies[1] >= 200
}

// Lines 200-250: the start of a Bwana's day.
begin_turn :: proc(g: ^Game) {
	g.nmsg = 0
	g.at_base = false
	pl := cur(g)
	pl.shown_map = false
	pl.days += 1
	if pl.supplies[0] < 100 {pl.hungry += 1} else {pl.hungry = 0}
	home := at_own_base(g, pl)
	if home {merge_party(pl)}
	if pl.men[0] + pl.men[1] < 2 || pl.cameras[0] + pl.cameras[1] < 1 {
		pl.out = true
		say(g, .Out_No_Cameras)
		g.phase = .Report
		return
	}
	if home {
		if !can_outfit(pl) {
			pl.out = true
			say(g, .Out_No_Outfit)
			g.phase = .Report
			return
		}
		g.phase = .Outfit
		return
	}
	g.phase = .Move
}

// The most cameras the base can send (two cameramen each).
max_cameras :: proc(pl: ^Player) -> int {return min(pl.cameras[1], pl.men[1] / 2)}

// Lines 805-875. Returns false when the choice is not possible.
outfit :: proc(g: ^Game, scouts: bit_set[Dir], cameras, bearers: int) -> bool {
	if g.phase != .Outfit {return false}
	pl := cur(g)
	if cameras < 0 || cameras > max_cameras(pl) {return false}
	if bearers < 3 || bearers > pl.bearers[1] {return false}
	for d in scouts {if pl.scouts[d] != .Base {return false}}
	for d in scouts {pl.scouts[d] = .Party}
	pl.cameras[1] -= cameras
	pl.cameras[0] = cameras
	pl.men[1] -= 2 * cameras
	pl.men[0] = 2 * cameras
	pl.film = 3 * cameras
	pl.bearers[1] -= bearers
	pl.bearers[0] = bearers
	if 100 * bearers > pl.supplies[1] {
		pl.supplies[0] = pl.supplies[1]
		pl.supplies[1] = 0
	} else {
		pl.supplies[1] -= 100 * bearers
		pl.supplies[0] = 100 * bearers
	}
	g.phase = .Move
	return true
}

// Pounds a party eats in a day (line 655).
daily_food :: proc(scouts, men, bearers: int) -> int {
	return 10 + 6 * men + 10 * scouts + 3 * bearers
}

// Retire at base (new): out of the game, keeping the points.
retire :: proc(g: ^Game) -> bool {
	if g.phase != .Outfit {return false}
	pl := cur(g)
	pl.out = true
	pl.retired = true
	g.nmsg = 0
	say(g, .Retired)
	g.phase = .Report
	return true
}

// Lines 700-730: what the scouts see.
report :: proc(g: ^Game, pl: ^Player, d: Dir) -> Report {
	r, c := pl.r + DR[d], pl.c + DC[d]
	if r < 0 || r >= SIZE || c < 0 || c >= SIZE {return .Edge}
	if pl.scouts[d] != .Party {return .No_Scout}
	v := g.cell[r][c]
	if is_base(v) {return .Base_Camp}
	if is_animal(v) {return .Animal}
	return .Nothing
}

Move :: enum {
	North,
	East,
	South,
	West,
	Stay,
	Lost,
}

// Lines 505-640. Returns false for a move off the map (ask again).
move :: proc(g: ^Game, m: Move) -> bool {
	if g.phase != .Move {return false}
	pl := cur(g)
	if pl.hungry > 7 {
		make_map(g, pl, true)
		end_day(g)
		return true
	}
	switch m {
	case .Stay:
		say(g, .Stayed)
		end_day(g)
		return true
	case .Lost:
		make_map(g, pl, false)
		end_day(g)
		return true
	case .North, .East, .South, .West:
	}
	d := Dir(int(m))
	r, c := pl.r + DR[d], pl.c + DC[d]
	if r < 0 || r >= SIZE || c < 0 || c >= SIZE {return false}
	pl.r, pl.c = r, c
	pl.ai_kr += DR[d]
	pl.ai_kc += DC[d]
	v := g.cell[r][c]
	switch {
	case v == 0:
		say(g, .Quip, rnd(g, 9))
	case v == 100 + g.turn:
		say(g, .Home)
	case is_base(v):
		say(g, .Other_Base)
	case is_animal(v):
		a := animal_of(v)
		if pl.film < 1 {
			say(g, .No_Film, a)
		} else if pl.men[0] < 2 {
			say(g, .No_Crew, a)
		} else if v % 10 > 2 {
			say(g, .Too_Late, a)
			pl.ai_done[r][c] = true
		} else {
			begin_film(g, pl, r, c)
			return true
		}
	case:
		disaster(g, pl, v)
	}
	end_day(g)
	return true
}

pick_party_scout_to_lose :: proc(pl: ^Player) -> bool {
	for &s in pl.scouts {if s == .Party {s = .Dead; return true}}
	return false
}

// Lines 600-637.
disaster :: proc(g: ^Game, pl: ^Player, v: int) {
	pl.ai_danger[pl.r][pl.c] = true
	switch v {
	case HEAD_HUNTERS:
		if pl.men[0] < 2 && pl.bearers[0] < 2 {return}
		say(g, .Head_Hunters)
		for &s in pl.scouts {if s == .Party {s = .Dead}}
		pl.men[0], pl.bearers[0], pl.cameras[0], pl.supplies[0], pl.film = 0, 0, 0, 0, 0
	case SCOUT_LOST:
		cause := rnd(g, 9)
		if pick_party_scout_to_lose(pl) {say(g, .Scout_Lost, cause)} else {say(g, .Weary)}
	case CREWMAN_LOST:
		if pl.men[0] < 1 {return}
		pl.men[0] -= 1
		pl.film = max(0, pl.film - 3)
		say(g, .Crewman_Lost, rnd(g, 4) + 5)
	case BEARER_LOST:
		if pl.bearers[0] < 2 {return}
		pl.bearers[0] -= 1
		say(g, .Bearer_Lost, rnd(g, 9))
	case SUPPLIES_LOST:
		cause := rnd(g, 4) + 5
		if pl.supplies[0] < 10 {return}
		ls := 50 + rnd(g, 100)
		pl.supplies[0] = max(0, pl.supplies[0] - ls)
		say(g, .Supplies_Lost, cause, ls)
	case CAMERA_LOST:
		if pl.cameras[0] < 1 {return}
		pl.cameras[0] -= 1
		pl.film = max(0, pl.film - 3)
		say(g, .Camera_Lost, rnd(g, 4) + 5)
	case DISORIENTED:
		say(g, .Disoriented)
		r, c := random_empty(g)
		pl.r, pl.c = r, c
		pl.ai_known = false
	}
}

// Lines 3000-3120: a map to base, at a man's life (if there is one to give).
make_map :: proc(g: ^Game, pl: ^Player, forced: bool) {
	f := forced ? 1 : 0
	pl.hungry = 0
	pl.shown_map = true
	pl.ai_known = true
	pl.ai_kr, pl.ai_kc = pl.r, pl.c
	for &s in pl.scouts {if s == .Party {s = .Dead; say(g, .Map, 0, f); return}}
	for &s in pl.scouts {if s == .Base {s = .Dead; say(g, .Map, 1, f); return}}
	if pl.men[0] > 0 {pl.men[0] -= 1; say(g, .Map, 2, f); return}
	if pl.men[1] > 0 {pl.men[1] -= 1; say(g, .Map, 3, f); return}
	say(g, .Map, 4, f)
}

// Lines 650-685: the end of the day.
end_day :: proc(g: ^Game) {
	pl := cur(g)
	pl.supplies[0] -= daily_food(party_scouts(pl), pl.men[0], pl.bearers[0])
	if pl.supplies[0] < 0 {pl.supplies[0] = 0}
	if at_own_base(g, pl) {
		merge_party(pl)
		pl.hungry = 0
		g.at_base = true
	} else if pl.supplies[0] < 100 && pl.bearers[0] > 1 {
		pl.bearers[0] -= 1
		say(g, .Bearer_Starved)
	} else if pl.supplies[0] < 100 && pl.bearers[0] < 2 && pl.men[0] > 0 {
		pl.men[0] -= 1
		say(g, .Cameraman_Starved)
	}
	g.phase = .Report
}

// ---- the camera (lines 7150-7820) ----

FILM_TICK :: 1.0 / 6.0 // seconds a step of the listing's loop

begin_film :: proc(g: ^Game, pl: ^Player, r, c: int) {
	v := g.cell[r][c]
	f := &g.film
	f^ = {}
	f.p1 = rnd(g, 40)
	f.p2 = rnd(g, 7)
	f.a1 = rnd(g, 50)
	f.a2 = rnd(g, 13)
	f.animal = animal_of(v)
	switch v % 10 {
	case 0: f.pp = 80
	case 1: f.pp = 50
	case: f.pp = 30
	}
	f.pp += (abs(pl.r - pl.br) + abs(pl.c - pl.bc)) * 10
	g.cell[r][c] += 1
	pl.film -= 1
	if pl.computer || v % 10 + 1 > 2 {pl.ai_done[r][c] = true} // the computer films a region once
	g.phase = .Filming
}

Frame_Move :: enum {
	Up,
	Down,
	Left,
	Right,
}

// One key press (lines 7320-7350).
film_key :: proc(g: ^Game, m: Frame_Move) {
	if g.phase != .Filming {return}
	f := &g.film
	switch m {
	case .Up: f.p2 = max(1, f.p2 - 1)
	case .Down: f.p2 = min(7, f.p2 + 1)
	case .Left:
		f.p1 = f.p1 - 3 - rnd(g, 2)
		if f.p1 < 0 {f.p1 = 1}
	case .Right:
		f.p1 = f.p1 + 3 + rnd(g, 2)
		if f.p1 > 40 {f.p1 = 40}
	}
}

// One pass of the loop: the animal wanders and the points drop (lines 7400-7450).
film_tick :: proc(g: ^Game) {
	if g.phase != .Filming {return}
	f := &g.film
	f.a1 += (rnd(g, 3) - 2) * 3
	if f.a1 < 0 {f.a1 = 2} else if f.a1 > 50 {f.a1 = 50}
	f.a2 += rnd(g, 3) - 2
	if f.a2 < 2 {f.a2 = 2} else if f.a2 > 13 {f.a2 = 13}
	f.pp -= 1
	if f.pp < 1 {film_end(g, false)}
}

// The frame's centre (line 7715).
frame_centre :: proc(f: ^Film) -> (x, y: int) {return f.p1 + 11, f.p2 + 4}

in_frame :: proc(f: ^Film) -> bool {
	x, y := frame_centre(f)
	return abs(x - f.a1) < 11 && abs(y - f.a2) < 4
}

// ENTER (lines 7700-7800).
film_snap :: proc(g: ^Game) {
	if g.phase != .Filming {return}
	film_end(g, true)
}

film_end :: proc(g: ^Game, snapped: bool) {
	f := &g.film
	pl := cur(g)
	f.done = true
	if !snapped || f.pp < 1 {
		f.pp = 0
		say(g, .Too_Slow)
	} else if in_frame(f) {
		f.hit = true
		pl.points += f.pp
		say(g, .Got_Picture, f.animal, f.pp)
	} else {
		say(g, .Missed_Picture)
	}
	end_day(g)
}

// After the report: the next Bwana still in the game, or the end.
next_turn :: proc(g: ^Game) {
	if g.phase != .Report {return}
	for _ in 0 ..< g.players {
		g.turn = (g.turn + 1) % g.players
		if !g.p[g.turn].out {
			begin_turn(g)
			return
		}
	}
	g.phase = .Over
}

all_out :: proc(g: ^Game) -> bool {
	for i in 0 ..< g.players {if !g.p[i].out {return false}}
	return true
}

// Index of the winner (the first of any tie).
leader :: proc(g: ^Game) -> int {
	best := 0
	for i in 1 ..< g.players {if g.p[i].points > g.p[best].points {best = i}}
	return best
}
