package divebomb

// Dive Bomb. After "Dive Bomb" by Rev. George Blank (SoftSide, March 1979). From the listing, on
// its 128 by 48 screen: a dive bomber enters at the top right and flies left; it dives one row a
// step (only while still past the left margin, down to row 40) and levels off on command, and may
// drop one bomb a pass, only when low (below row 38); the bomb falls straight and sinks the ship
// if the hull is under it. The ship steams left to right at half the plane's speed along the
// bottom and wraps round. Its anti-aircraft gun fires a shell up and forward on a 45-degree line
// from just behind its bow, three shots a pass ("a surplus model from the last war"), only while
// the ship is well on screen; a shell that meets the plane brings it down. A pass with no result
// brings the plane round again with a fresh bomb and the gun reloaded. A sinking or a downing
// restarts the ship from the left.
// New here: the shell and bomb fly visibly instead of at once; a match to five; a computer bomber
// or gunner, at two levels, so one person can play either side.
// Pure rules: no platform imports.

WIDTH :: 128
HEIGHT :: 48
TICK :: f32(1.0 / 30.0) // one plane step

PLANE_TOP :: 7
PLANE_LOW :: 40
DIVE_MARGIN :: 10
BOMB_BELOW :: 38
SHIP_WRAP :: 157
SHIP_LEN :: 24
SHELLS :: 3
SHELL_RANGE :: 40
SHELL_SPEED :: 3 // diagonal steps a tick
WIN_POINTS :: 5
NOTICE_ACE :: f32(0.12)
NOTICE_ROOKIE :: f32(0.04)
DIVE_GAP_ACE :: 56
PAUSE :: f32(1.6)

Side :: enum {
	Bomber,
	Gunner,
}

Event :: enum {
	Dive,
	Level,
	Drop,
	Fire,
	Jam, // the gun is out of shells this pass
	Sunk,
	Downed,
	New_Pass,
	Splash, // a bomb missed
	Match_Over,
}

Shell :: struct {
	active: bool,
	x0:     int, // where the shell left the gun
	k:      int, // diagonal steps flown
}

Bomb :: struct {
	active: bool,
	x, y:   int,
}

Game :: struct {
	ship:      int, // A: the bow's column; the hull is ship-23 .. ship on rows 46-47
	ship_half: bool,
	px, py:    int, // C, D: the plane's nose
	diving:    bool,
	bomb_left: bool, // T
	shells:    int, // F
	shell:     Shell,
	bomb:      Bomb,
	score:     [Side]int,
	cpu:       [Side]bool,
	skill:     [Side]int, // 0 rookie, 1 ace
	pause:     f32, // after a hit, before the next round
	last:      Side, // who scored last
	over:      bool,
	winner:    Side,
	acc:       f32,
	ticks:     int,
	events:    bit_set[Event],
	// the computer bomber's plan for this pass
	dive_gap:  int,
	rng:       u64,
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

new_game :: proc(g: ^Game, seed: u64, cpu_bomber := false, cpu_gunner := false, skill := 0, gunner_skill := -1) {
	g^ = {}
	g.rng = seed | 1
	for _ in 0 ..< 4 {next_random(g)}
	g.cpu = {.Bomber = cpu_bomber, .Gunner = cpu_gunner}
	g.skill = {.Bomber = clamp(skill, 0, 1), .Gunner = clamp(gunner_skill < 0 ? skill : gunner_skill, 0, 1)}
	new_round(g)
}

new_round :: proc(g: ^Game) {
	g.ship = 0
	g.ship_half = false
	new_pass(g)
}

new_pass :: proc(g: ^Game) {
	g.px = WIDTH - 1
	g.py = PLANE_TOP
	g.diving = false
	g.bomb_left = true
	g.shells = SHELLS
	g.shell = {}
	g.bomb = {}
	plan_pass(g)
}

// ---- controls (the listing's Z, A, X and /) ----

dive :: proc(g: ^Game) {
	if g.pause > 0 || g.over {return}
	if !g.diving {g.events += {.Dive}}
	g.diving = true
}

level :: proc(g: ^Game) {
	if g.pause > 0 || g.over {return}
	if g.diving {g.events += {.Level}}
	g.diving = false
}

can_drop :: proc(g: ^Game) -> bool {
	return g.bomb_left && g.py > BOMB_BELOW && g.px >= 0 && !g.bomb.active
}

drop :: proc(g: ^Game) -> bool {
	if g.pause > 0 || g.over || !can_drop(g) {return false}
	g.bomb_left = false
	g.bomb = {true, g.px, g.py + 1}
	g.events += {.Drop}
	return true
}

can_fire :: proc(g: ^Game) -> bool {
	return g.shells > 0 && g.ship > 10 && g.ship < 90 && !g.shell.active
}

fire :: proc(g: ^Game) -> bool {
	if g.pause > 0 || g.over {return false}
	if g.shells <= 0 && !g.shell.active {g.events += {.Jam}; return false}
	if !can_fire(g) {return false}
	g.shells -= 1
	g.shell = {true, g.ship - 5, 0}
	g.events += {.Fire}
	return true
}

// ---- geometry ----

shell_point :: proc(s: Shell, k: int) -> (x, y: int) {
	return s.x0 + k, 45 - k
}

// The plane's lit points in the listing: its nose row (nose to four behind) and the tail fin.
plane_covers :: proc(px, py, x, y: int) -> bool {
	if y == py && x >= px && x <= px + 4 {return true}
	return x == px + 4 && y == py - 1
}

on_hull :: proc(g: ^Game, x: int) -> bool {
	return x >= g.ship - (SHIP_LEN - 1) && x <= g.ship
}

// ---- time ----

update :: proc(g: ^Game, dt: f32) {
	if g.over {return}
	g.acc += dt
	for g.acc >= TICK {
		g.acc -= TICK
		tick(g)
		if g.over {break}
	}
}

score :: proc(g: ^Game, s: Side) {
	g.score[s] += 1
	g.last = s
	g.events += {s == .Bomber ? .Sunk : .Downed}
	g.pause = PAUSE
	g.shell = {}
	g.bomb = {}
	if g.score[s] >= WIN_POINTS {
		g.over = true
		g.winner = s
		g.events += {.Match_Over}
	}
}

tick :: proc(g: ^Game) {
	g.ticks += 1
	if g.pause > 0 {
		g.pause -= TICK
		if g.pause <= 0 {g.pause = 0; new_round(g)}
		return
	}
	if g.cpu[.Bomber] {cpu_bomber(g)}
	if g.cpu[.Gunner] {cpu_gunner(g)}

	// the ship: one column every other plane step
	g.ship_half = !g.ship_half
	if g.ship_half {
		g.ship += 1
		if g.ship >= SHIP_WRAP {g.ship = 0}
	}
	// the plane
	if g.diving && g.px > DIVE_MARGIN && g.py < PLANE_LOW {g.py += 1}
	g.px -= 1
	// the shell
	if g.shell.active {
		for _ in 0 ..< SHELL_SPEED {
			g.shell.k += 1
			x, y := shell_point(g.shell, g.shell.k)
			if plane_covers(g.px, g.py, x, y) {score(g, .Gunner); return}
			if g.shell.k >= SHELL_RANGE {g.shell.active = false; break}
		}
	}
	// the bomb
	if g.bomb.active {
		g.bomb.y += 1
		if g.bomb.y >= 46 {
			if on_hull(g, g.bomb.x) {score(g, .Bomber); return}
			g.bomb.active = false
			g.events += {.Splash}
		}
	}
	if g.px < -1 && !g.bomb.active && !g.shell.active {
		new_pass(g)
		g.events += {.New_Pass}
	}
}

// ---- the computer's sides ----

// Would a shell fired now hit the plane, if it holds its course?
shot_would_hit :: proc(g: ^Game, slack: int) -> bool {
	if !can_fire(g) {return false}
	s := Shell{true, g.ship - 5, 0}
	px, py := g.px, g.py
	for _ in 0 ..< 20 {
		if g.diving && px > DIVE_MARGIN && py < PLANE_LOW {py += 1}
		px -= 1
		for _ in 0 ..< SHELL_SPEED {
			s.k += 1
			x, y := shell_point(s, s.k)
			for dx in -slack ..= slack {if plane_covers(px, py, x + dx, y) {return true}}
			if s.k >= SHELL_RANGE {return false}
		}
	}
	return false
}

cpu_gunner :: proc(g: ^Game) {
	if !can_fire(g) {return}
	notice: f32 = g.skill[.Gunner] == 1 ? NOTICE_ACE : NOTICE_ROOKIE
	if shot_would_hit(g, 0) {
		if next_random(g) < notice {fire(g)}
	} else if g.skill[.Gunner] == 0 && shot_would_hit(g, 3) && next_random(g) < 0.08 {
		fire(g) // a rookie snaps off a near miss now and then
	}
}

plan_pass :: proc(g: ^Game) {
	// The plane needs 33 steps to come down; the gap to the ship closes one and a half a step.
	g.dive_gap = g.skill[.Bomber] == 1 ? DIVE_GAP_ACE + rand_int(g, 8) : 40 + rand_int(g, 40)
}

// The gun's line is x + y = ship + 40. A diving plane keeps x + y fixed, so near the line it
// slides along it while the ship closes slowly; flying level it crosses three times as fast. An
// ace dives early, levels off to cross the line quickly, then dives on; a rookie just dives.
cpu_bomber :: proc(g: ^Game) {
	mid := g.ship - SHIP_LEN / 2
	can_dive := g.py < PLANE_LOW && g.bomb_left && g.px > DIVE_MARGIN + 4
	if g.skill[.Bomber] == 1 {
		off := g.px + g.py + 2 - (g.ship + 40)
		armed := g.shells > 0 && g.ship > 6 && g.ship < 92
		if armed && off >= 0 && off <= 8 {
			level(g)
		} else if can_dive && g.px - mid <= g.dive_gap {
			dive(g)
		}
	} else if !g.diving && can_dive && g.px - mid <= g.dive_gap {
		dive(g)
	}
	if can_drop(g) {
		// the bomb falls about six steps; the ship moves three columns meanwhile
		ahead := g.ship + 3
		lo, hi := ahead - (SHIP_LEN - 1) + 2, ahead - 2
		if g.skill[.Bomber] == 0 {lo -= 3; hi += 3}
		if g.px >= lo && g.px <= hi && next_random(g) < (g.skill[.Bomber] == 1 ? 0.9 : 0.35) {drop(g)}
	}
}
