package pillbox

import "core:math"

// Pillbox: two gun emplacements either side of a mountain take turns shelling each other; the
// first to five hits wins the war. After "Pillbox" by Gene Perkins (SoftSide, October 1978): the
// ground is new every battle, each gunner sets a barrel angle (0 to 90 degrees) and a muzzle
// velocity (100 to 2000), and the shell flies a plain ballistic arc with no wind. New here: a
// computer gunner who brackets its target, for one player.
// Pure rules: no platform imports. Coordinates are the page's logical pixels, y down.

W :: 384
H :: 240

GROUND_TOP :: 40 // highest a peak may reach
GROUND_FLOOR :: 228 // the bottom of the play field
BOX_W :: 12
BOX_H :: 6
HITS_TO_WIN :: 5

ANGLE_MIN :: 0
ANGLE_MAX :: 90
VEL_MIN :: 100
VEL_MAX :: 2000

SPEED_PER_VEL :: 0.18 // px per second per unit of muzzle velocity
GRAVITY :: 250 // px per second squared
SIM_DT :: 1.0 / 240.0

Shell_State :: enum {
	None,
	Flying,
	Landed, // hit the ground
	Lost, // left the field at the side
	Hit_Enemy,
	Hit_Self,
}

Gunner :: struct {
	x:        int, // centre of the pillbox
	y:        int, // top of the ground under it
	angle:    int,
	velocity: int,
	hits:     int, // hits scored on the other side
	cpu:      bool,
}

Shell :: struct {
	state:      Shell_State,
	x, y:       f32,
	vx, vy:     f32,
	t:          f32,
	cleared:    bool, // has left its own pillbox (only then can it fall back on it)
	trail:      [512][2]i16,
	trail_len:  int,
}

Event :: enum {
	Fired,
	Landed,
	Lost,
	Hit,
	Hit_Self,
	New_Field,
	War_Over,
}

Game :: struct {
	ground:   [W]int, // y of the ground surface in each column
	gunners:  [2]Gunner,
	turn:     int,
	shell:    Shell,
	shots:    int, // fired this field, both sides
	winner:   int, // -1 until someone has five hits
	events:   bit_set[Event],
	rng:      u64,
	// shots the computer has taken at this field, per side (its aim tightens with each)
	cpu_shots: [2]int,
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

new_game :: proc(g: ^Game, seed: u64, cpu_right: bool) {
	g^ = {}
	g.rng = seed | 1
	g.winner = -1
	g.gunners[1].cpu = cpu_right
	for &gu in g.gunners {
		gu.angle = 45
		gu.velocity = 1000
	}
	new_field(g)
	g.turn = rand_int(g, 2)
}

// Draws a new battlefield: two pillboxes on level ground, a mountain between them
// (as in the listing: each box somewhere in its third, the peak somewhere in the middle).
new_field :: proc(g: ^Game) {
	lx := 24 + rand_int(g, 90)
	rx := W - 24 - rand_int(g, 90)
	ly := 150 + rand_int(g, 70)
	ry := 150 + rand_int(g, 70)
	px := W / 2 - 40 + rand_int(g, 80)
	py := GROUND_TOP + rand_int(g, 80)
	py = min(py, min(ly, ry) - 20)
	for x in 0 ..< W {
		y: f32
		switch {
		case x <= lx + BOX_W:
			y = f32(ly)
		case x >= rx - BOX_W:
			y = f32(ry)
		case x <= px:
			y = lerp_s(f32(ly), f32(py), f32(x - lx - BOX_W) / f32(px - lx - BOX_W))
		case:
			y = lerp_s(f32(py), f32(ry), f32(x - px) / f32(rx - BOX_W - px))
		}
		g.ground[x] = int(y)
	}
	// A little roughness on the slopes, never on the pads.
	for x in lx + BOX_W + 2 ..< rx - BOX_W - 2 {
		if abs(x - px) > 3 {g.ground[x] += rand_int(g, 3) - 1}
	}
	g.gunners[0].x, g.gunners[0].y = lx, ly
	g.gunners[1].x, g.gunners[1].y = rx, ry
	g.shell = {}
	g.shots = 0
	g.cpu_shots = {}
	g.events += {.New_Field}
}

// A slope that eases in and out, so the mountain looks like one.
lerp_s :: proc(a, b, t: f32) -> f32 {
	u := clamp(t, 0, 1)
	u = u * u * (3 - 2 * u)
	return a + (b - a) * u
}

set_aim :: proc(g: ^Game, angle, velocity: int) {
	gu := &g.gunners[g.turn]
	gu.angle = clamp(angle, ANGLE_MIN, ANGLE_MAX)
	gu.velocity = clamp(velocity, VEL_MIN, VEL_MAX)
}

// The muzzle: just above the pillbox's roof.
muzzle :: proc(g: ^Game, side: int) -> (f32, f32) {
	gu := g.gunners[side]
	return f32(gu.x), f32(gu.y - BOX_H - 1)
}

fire :: proc(g: ^Game) -> bool {
	if g.winner >= 0 || g.shell.state == .Flying {return false}
	gu := g.gunners[g.turn]
	dir: f32 = g.turn == 0 ? 1 : -1
	a := f32(gu.angle) * 3.14159265 / 180
	s := f32(gu.velocity) * SPEED_PER_VEL
	x, y := muzzle(g, g.turn)
	g.shell = {}
	g.shell.state = .Flying
	g.shell.x, g.shell.y = x, y
	g.shell.vx = dir * s * math.cos(a)
	g.shell.vy = -s * math.sin(a)
	g.shots += 1
	g.events += {.Fired}
	return true
}

in_box :: proc(g: ^Game, side: int, x, y: f32) -> bool {
	gu := g.gunners[side]
	return x >= f32(gu.x - BOX_W / 2 - 1) && x <= f32(gu.x + BOX_W / 2 + 1) && y >= f32(gu.y - BOX_H - 1) && y <= f32(gu.y)
}

// Advances a flying shell by dt seconds of game time.
update :: proc(g: ^Game, dt: f32) {
	sh := &g.shell
	if sh.state != .Flying {return}
	left := dt
	for left > 0 && sh.state == .Flying {
		step := min(left, SIM_DT)
		left -= step
		sh.t += step
		sh.vy += GRAVITY * step
		sh.x += sh.vx * step
		sh.y += sh.vy * step
		if sh.trail_len < len(sh.trail) {
			p := [2]i16{i16(sh.x), i16(sh.y)}
			if sh.trail_len == 0 || sh.trail[sh.trail_len - 1] != p {
				sh.trail[sh.trail_len] = p
				sh.trail_len += 1
			}
		}
		resolve(g)
	}
}

@(private)
resolve :: proc(g: ^Game) {
	sh := &g.shell
	enemy := 1 - g.turn
	// Leaving the field at the bottom or the sides.
	if sh.x < 0 || sh.x >= W || sh.y > GROUND_FLOOR + 8 {
		sh.state = .Lost
		g.events += {.Lost}
		end_turn(g)
		return
	}
	// A shell grazing a pillbox counts before the ground under it.
	if sh.t > 0.05 && in_box(g, enemy, sh.x, sh.y) {
		sh.state = .Hit_Enemy
		g.gunners[g.turn].hits += 1
		g.events += {.Hit}
		if g.gunners[g.turn].hits >= HITS_TO_WIN {
			g.winner = g.turn
			g.events += {.War_Over}
		}
		return
	}
	if !sh.cleared {
		sh.cleared = !in_box(g, g.turn, sh.x, sh.y)
	} else if in_box(g, g.turn, sh.x, sh.y) {
		// Shelling yerself scores for the other side.
		sh.state = .Hit_Self
		g.gunners[enemy].hits += 1
		g.events += {.Hit_Self}
		if g.gunners[enemy].hits >= HITS_TO_WIN {
			g.winner = enemy
			g.events += {.War_Over}
		}
		return
	}
	if sh.y >= 0 && int(sh.y) >= g.ground[int(sh.x)] {
		sh.state = .Landed
		g.events += {.Landed}
		end_turn(g)
	}
}

@(private)
end_turn :: proc(g: ^Game) {
	g.turn = 1 - g.turn
}

// After a hit the page shows it, then calls this: a new field, and the side that was hit fires first.
after_hit :: proc(g: ^Game) {
	if g.winner >= 0 {return}
	hit_side := g.shell.state == .Hit_Enemy ? 1 - g.turn : g.turn
	new_field(g)
	g.turn = hit_side
}

// ---- the computer gunner ----

// Where a shot would come down, simulated without touching the game (x of the impact,
// and whether it struck the enemy's box).
predict :: proc(g: ^Game, side, angle, velocity: int) -> (x: f32, hit: bool) {
	sim: Game
	sim.ground = g.ground
	sim.gunners = g.gunners
	sim.turn = side
	sim.winner = -1
	sim.gunners[side].angle = angle
	sim.gunners[side].velocity = velocity
	sim.gunners[0].hits, sim.gunners[1].hits = 0, 0
	fire(&sim)
	sim.shell.trail_len = len(sim.shell.trail) // no trail needed
	for i := 0; i < 4000 && sim.shell.state == .Flying; i += 1 {update(&sim, SIM_DT)}
	return sim.shell.x, sim.shell.state == .Hit_Enemy
}

// Picks the computer's aim: a firing solution that clears the mountain, spoilt by an error
// that shrinks with every shot it takes at this field (it brackets, like a real gunner).
cpu_aim :: proc(g: ^Game) {
	side := g.turn
	// Every hitting (angle, velocity) on a coarse grid; it picks one at random.
	sols: [512][2]int
	n_sols := 0
	for a := 20; a <= 80; a += 5 {
		for v := VEL_MIN; v <= VEL_MAX; v += 10 {
			if _, hit := predict(g, side, a, v); hit && n_sols < len(sols) {
				sols[n_sols] = {a, v}
				n_sols += 1
			}
		}
	}
	best_a, best_v := 45 + rand_int(g, 30), 700 + rand_int(g, 900)
	if n_sols > 0 {
		pick := sols[rand_int(g, n_sols)]
		best_a, best_v = pick[0], pick[1]
	}
	n := g.cpu_shots[side]
	spread := f32(240) / f32(1 + n * n) // velocity error, shrinking fast
	err := (next_random(g) * 2 - 1) * spread
	if n == 0 {err = (next_random(g) < 0.5 ? -1 : 1) * (spread * 0.5 + next_random(g) * spread * 0.5)}
	g.cpu_shots[side] += 1
	set_aim(g, best_a, best_v + int(err))
}
