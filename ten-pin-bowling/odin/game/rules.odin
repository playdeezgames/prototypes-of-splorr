package bowling

// Ten Pin Bowling. After "Ten Pin Bowling" by Frank B. Rowlett, Jr. (SoftSide, January 1979): the
// ball moves from side to side behind the foul line; wait until it is where you want it and throw
// it straight, or breaking left or right as it travels. As in real bowling a straight ball never
// strikes: it has to break into the pocket (a straight ball that would take the rack leaves a
// back corner pin). Skill decides the score; the one chance in it is the
// 7-10 split, which a correct throw converts one time in three. Ten frames, strikes and spares and
// the tenth frame's extra balls scored as usual. The listing played one or two bowlers; this take
// seats one to four, any of them the computer.
//
// The pin action is a new, deterministic model (the listing worked on screen characters): the
// ball's path is a straight line or a parabola; a pin within contact distance falls; a pin hit
// nearly full flies straight back, one hit at an angle flies off to the far side through the pin
// diagonally behind it (and on down that line), and one clipped thin skids sideways and takes
// nothing with it; every hit pushes the ball off line, a straight ball more than a breaking one.
// Pure rules: no platform imports. Lateral distances are inches from the middle of the lane.

LANE_HALF :: 20.75
BALL_LIMIT :: 17.0 // past this the ball drops in the channel
RELEASE_LIMIT :: 15.0 // the sweep behind the foul line
TO_HEAD_PIN :: 720.0 // sixty feet
ROW_GAP :: 10.39
CONTACT :: 6.7 // ball radius plus pin radius
FULL_HIT :: 1.5
THIN_HIT :: 4.5
HOOK :: 10.0 // how far a breaking ball has moved by the head pin
DEFLECT_STRAIGHT :: 4.0
DEFLECT_HOOK :: 1.2

FRAMES :: 10
MAX_BOWLERS :: 4
MAX_ROLLS :: 21

Throw :: enum {
	Straight,
	Break_Left,
	Break_Right,
}

PIN_X := [10]f32{0, -6, 6, -12, 0, 12, -18, -6, 6, 18}
PIN_ROW := [10]int{0, 1, 1, 2, 2, 2, 3, 3, 3, 3}

Pins :: bit_set[0 ..< 10] // pin n is bit n-1

ALL_PINS :: Pins{0, 1, 2, 3, 4, 5, 6, 7, 8, 9}

Fall :: struct {
	pin:   int,
	dir:   int, // -1 left, 0 straight back, 1 right
	order: int, // 0 for a pin the ball hit, more for each pin down a chain
	row:   int, // where along the deck the knock happened, for the page's timing
}

Roll :: struct {
	gutter:   bool,
	down:     Pins,
	falls:    [10]Fall,
	n_falls:  int,
	kickback: bool, // the 7-10 came good
	ball_x:   [5]f32, // the ball's line at the head pin row and each row after (and past the deck)
}

// Where the ball is, d inches from the foul line, before any pin pushes it.
path_x :: proc(release: f32, t: Throw, d: f32) -> f32 {
	k := d / TO_HEAD_PIN
	switch t {
	case .Straight:
		return release
	case .Break_Left:
		return release - HOOK * k * k
	case .Break_Right:
		return release + HOOK * k * k
	}
	return release
}

hook_sign :: proc(t: Throw) -> f32 {
	switch t {
	case .Break_Left:
		return -1
	case .Break_Right:
		return 1
	case .Straight:
	}
	return 0
}

@(private)
pin_at :: proc(row: int, x: f32) -> int {
	for i in 0 ..< 10 {
		if PIN_ROW[i] == row && abs(PIN_X[i] - x) < 0.5 {return i}
	}
	return -1
}

@(private)
add_fall :: proc(r: ^Roll, f: Fall) {
	r.down += {f.pin}
	r.falls[r.n_falls] = f
	r.n_falls += 1
}

// A pin knocked by another, carrying on down its line.
@(private)
chain :: proc(r: ^Roll, standing: Pins, from: int, dir: int, first_order: int) {
	order := first_order
	row := PIN_ROW[from]
	x := PIN_X[from]
	for {
		if dir == 0 {
			row += 2
		} else {
			row += 1
			x += 6 * f32(dir)
		}
		if row > 3 {return}
		p := pin_at(row, x)
		if p < 0 {
			if dir == 0 {return}
			continue // a gap: the flying pin carries on
		}
		if p in standing && p not_in r.down {
			add_fall(r, {p, dir, order, row})
		}
		order += 1
	}
}

// Rolls one ball at the standing pins. kick is a number in [0, 3): the 7-10 converts when it is
// below 1 (the page passes a random one; tests pass what they need).
roll_ball :: proc(standing: Pins, release: f32, t: Throw, kick: f32 = 3) -> Roll {
	r: Roll
	rel := clamp(release, -RELEASE_LIMIT, RELEASE_LIMIT)
	// Into the channel before the pins?
	if abs(path_x(rel, t, TO_HEAD_PIN)) > BALL_LIMIT {
		r.gutter = true
		for i in 0 ..< 5 {r.ball_x[i] = path_x(rel, t, TO_HEAD_PIN + f32(i) * ROW_GAP)}
		return r
	}
	k: f32 = t == .Straight ? DEFLECT_STRAIGHT : DEFLECT_HOOK
	push: f32 = 0
	split := standing == Pins{6, 9}
	for row in 0 ..< 4 {
		d := TO_HEAD_PIN + f32(row) * ROW_GAP
		bx := path_x(rel, t, d) + push
		r.ball_x[row] = bx
		row_push: f32 = 0
		for i in 0 ..< 10 {
			if PIN_ROW[i] != row || i not_in standing || i in r.down {continue}
			o := PIN_X[i] - bx
			if abs(o) >= CONTACT {continue}
			dir := 0
			if abs(o) >= FULL_HIT {dir = o > 0 ? 1 : -1}
			add_fall(&r, {i, dir, 0, row})
			if abs(o) < THIN_HIT {chain(&r, standing, i, dir, 1)}
			row_push -= k * o / CONTACT
			// The 7-10: clip one thin and it may come back off the kickback and take the other.
			if split && kick < 1 && abs(o) >= THIN_HIT {
				other := i == 6 ? 9 : 6
				if other not_in r.down {
					add_fall(&r, {other, PIN_X[other] > PIN_X[i] ? 1 : -1, 1, row})
					r.kickback = true
				}
			}
		}
		push += row_push
	}
	r.ball_x[4] = path_x(rel, t, TO_HEAD_PIN + 4 * ROW_GAP) + push
	// The listing's rule, kept outright: a straight ball does not strike. A full rack all down
	// to a straight ball leaves the back corner pin on the ball's side standing (the 5 head on).
	if t == .Straight && standing == ALL_PINS && r.down == ALL_PINS {
		keep := 4
		if r.ball_x[0] > 0.25 {keep = 9} else if r.ball_x[0] < -0.25 {keep = 6}
		r.down -= {keep}
		for j in 0 ..< r.n_falls {
			if r.falls[j].pin == keep {
				r.falls[j] = r.falls[r.n_falls - 1]
				r.n_falls -= 1
				break
			}
		}
	}
	return r
}

count :: proc(p: Pins) -> int {
	n := 0
	for i in 0 ..< 10 {if i in p {n += 1}}
	return n
}

// ---- the game ----

Bowler :: struct {
	rolls:    [MAX_ROLLS]int,
	n_rolls:  int,
	computer: bool,
}

Game :: struct {
	bowlers:   [MAX_BOWLERS]Bowler,
	n_bowlers: int,
	current:   int,
	frame:     int, // 0 to 9
	ball:      int, // ball in this frame, 0 to 2
	standing:  Pins,
	over:      bool,
	rng:       u64,
}

new_game :: proc(g: ^Game, n: int, computer: [MAX_BOWLERS]bool, seed: u64) {
	g^ = {}
	g.n_bowlers = clamp(n, 1, MAX_BOWLERS)
	for i in 0 ..< g.n_bowlers {g.bowlers[i].computer = computer[i]}
	g.standing = ALL_PINS
	g.rng = seed | 1
}

rand :: proc(g: ^Game) -> f32 {
	x := g.rng
	x ~= x << 13
	x ~= x >> 7
	x ~= x << 17
	g.rng = x
	return f32(x >> 40) / f32(1 << 24)
}

Result :: enum {
	Next_Ball, // same bowler, same frame
	Next_Bowler,
	Game_Over,
}

// Records a ball that knocked down `down` of the standing pins and moves the game on.
record :: proc(g: ^Game, down: Pins) -> Result {
	b := &g.bowlers[g.current]
	knocked := down & g.standing
	b.rolls[b.n_rolls] = count(knocked)
	b.n_rolls += 1
	g.standing -= knocked
	done := false
	if g.frame < FRAMES - 1 {
		done = g.standing == {} || g.ball == 1
	} else {
		// The tenth: a strike or a spare earns the extra balls, with the pins set up again.
		first := b.rolls[b.n_rolls - 1 - g.ball]
		switch g.ball {
		case 0:
			if g.standing == {} {g.standing = ALL_PINS}
		case 1:
			second := b.rolls[b.n_rolls - 1]
			if first + second < 10 && first < 10 {
				done = true
			} else if g.standing == {} {
				g.standing = ALL_PINS
			}
		case 2:
			done = true
		}
	}
	if !done {
		g.ball += 1
		return .Next_Ball
	}
	g.ball = 0
	g.standing = ALL_PINS
	g.current += 1
	if g.current >= g.n_bowlers {
		g.current = 0
		g.frame += 1
		if g.frame >= FRAMES {
			g.over = true
			return .Game_Over
		}
	}
	return .Next_Bowler
}

// The running total after each frame, -1 where it cannot be scored yet.
frame_scores :: proc(b: ^Bowler) -> [FRAMES]int {
	out: [FRAMES]int
	for &v in out {v = -1}
	r := b.rolls[:b.n_rolls]
	i, total := 0, 0
	for f in 0 ..< FRAMES {
		if i >= len(r) {break}
		if r[i] == 10 && f < FRAMES - 1 {
			if i + 2 >= len(r) {break}
			total += 10 + r[i + 1] + r[i + 2]
			i += 1
		} else if f < FRAMES - 1 {
			if i + 1 >= len(r) {break}
			if r[i] + r[i + 1] == 10 {
				if i + 2 >= len(r) {break}
				total += 10 + r[i + 2]
			} else {
				total += r[i] + r[i + 1]
			}
			i += 2
		} else {
			// The tenth: two balls, or three after a strike or spare.
			if i + 1 >= len(r) {break}
			if r[i] == 10 || r[i] + r[i + 1] == 10 {
				if i + 2 >= len(r) {break}
				total += r[i] + r[i + 1] + r[i + 2]
			} else {
				total += r[i] + r[i + 1]
			}
		}
		out[f] = total
	}
	return out
}

total :: proc(b: ^Bowler) -> int {
	s := frame_scores(b)
	best := 0
	for v in s {if v >= 0 {best = v}}
	return best
}

// The marks for frame f: up to three short strings ("X", "/", "-", "7"), "" where none.
frame_marks :: proc(b: ^Bowler, f: int) -> (marks: [3]string, n: int) {
	digits := [11]string{"-", "1", "2", "3", "4", "5", "6", "7", "8", "9", "X"}
	r := b.rolls[:b.n_rolls]
	// Find where frame f starts.
	i := 0
	for k in 0 ..< f {
		if i >= len(r) {return}
		if r[i] == 10 && k < FRAMES - 1 {i += 1} else {i += 2}
	}
	if i >= len(r) {return}
	if f < FRAMES - 1 {
		if r[i] == 10 {
			marks[0] = "X"
			return marks, 1
		}
		marks[0] = digits[r[i]]
		n = 1
		if i + 1 < len(r) {
			marks[1] = r[i] + r[i + 1] == 10 ? "/" : digits[r[i + 1]]
			n = 2
		}
		return
	}
	// The tenth.
	pins_up := 10
	for k in 0 ..< 3 {
		if i + k >= len(r) {break}
		v := r[i + k]
		if v == pins_up && pins_up < 10 {
			marks[k] = "/"
		} else {
			marks[k] = digits[v]
		}
		pins_up -= v
		if pins_up == 0 {pins_up = 10}
		n = k + 1
	}
	return
}

// ---- the computer bowler ----

// The throw that knocks down the most of `standing`, preferring a straight ball on ties, and
// the release a little off it (spread is the computer's unsteadiness in inches).
plan_throw :: proc(g: ^Game, standing: Pins, spread: f32) -> (release: f32, t: Throw) {
	best := -1
	best_rel: f32 = 0
	best_t := Throw.Straight
	for th in Throw {
		for step := -150; step <= 150; step += 1 {
			rel := f32(step) / 10
			// Score a release by the worst of its near neighbours, so the plan has some room.
			worst := 99
			for dd in ([3]f32{-0.6, 0, 0.6}) {
				r := roll_ball(standing, rel + dd, th)
				worst = min(worst, count(r.down & standing))
			}
			if worst > best || (worst == best && th == .Straight && best_t != .Straight) {
				best, best_rel, best_t = worst, rel, th
			}
		}
	}
	noise := (rand(g) + rand(g) + rand(g) - 1.5) * spread
	return clamp(best_rel + noise, -RELEASE_LIMIT, RELEASE_LIMIT), best_t
}
