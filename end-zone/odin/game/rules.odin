package endzone

// End Zone: football for two at one keyboard (or you against a computer coach). Each play the
// offence picks one of eleven plays in secret, the defence one of ten alignments, and the match-up
// decides the yardage, with sacks, interceptions, fumbles, penalties, punts, field goals and a
// game clock of four 15-minute quarters. After "End Zone" by Roger Robitaille (SoftSide, November
// 1978). The yardage tables here are new; the plays, alignments, time maneuvers, punt choices and
// penalties are the listing's. The computer coach is new.
// Pure rules: no platform imports. Field positions are yards from the offence's own goal line.

import "core:fmt"

HOME :: 0
VISITORS :: 1

QUARTER_SECS :: 15 * 60
TIMEOUTS :: 3

Play :: enum {
	Run_Weak,
	Run_Strong,
	Sweep,
	Delayed_Run,
	Middle,
	Short_Pass,
	Medium_Pass,
	Long_Pass,
	Punt,
	Field_Goal,
	Razzle_Dazzle,
}

Defense :: enum {
	Blitz,
	Prevent,
	Stacked,
	Balanced,
	Key_Short,
	Key_Medium,
	Key_Long,
	Key_Run,
	Key_Sweep,
	Goal_Line,
}

Punt_Choice :: enum {
	Return,
	Block,
	Fair_Catch,
}

Kick_Choice :: enum {
	Deep,
	Onside,
}

// Time maneuvers, called before the snap. The defence may not call a quick huddle.
Tempo :: enum {
	Normal,
	Quick_Huddle,
	Slow_Down,
	Time_Out,
}

PLAY_NAMES := [Play]string {
	.Run_Weak      = "RUN WEAK SIDE",
	.Run_Strong    = "RUN STRONG SIDE",
	.Sweep         = "SWEEP",
	.Delayed_Run   = "DELAYED RUN",
	.Middle        = "UP THE MIDDLE",
	.Short_Pass    = "SHORT PASS",
	.Medium_Pass   = "MEDIUM PASS",
	.Long_Pass     = "LONG PASS",
	.Punt          = "PUNT",
	.Field_Goal    = "FIELD GOAL",
	.Razzle_Dazzle = "RAZZLE DAZZLE",
}

DEFENSE_NAMES := [Defense]string {
	.Blitz      = "BLITZ",
	.Prevent    = "PREVENT",
	.Stacked    = "STACKED",
	.Balanced   = "BALANCED",
	.Key_Short  = "KEYED SHORT PASS",
	.Key_Medium = "KEYED MEDIUM PASS",
	.Key_Long   = "KEYED LONG PASS",
	.Key_Run    = "KEYED LONG RUN",
	.Key_Sweep  = "KEYED SWEEP",
	.Goal_Line  = "GOAL LINE",
}

Phase :: enum {
	Kickoff, // `kicker` kicks off (or a free kick after a safety)
	Scrimmage,
	Over,
}

Event :: enum {
	Touchdown,
	Field_Goal,
	Safety,
	Turnover,
	First_Down,
	Penalty,
	Big_Play,
	Loss,
	Two_Minute,
	Quarter_Over,
	Half_Time,
	Game_Over,
}

LOG :: 5
LINE :: 62

Call :: struct {
	play:       Play,
	defense:    Defense,
	punt:       Punt_Choice,
	off_tempo:  Tempo,
	def_tempo:  Tempo,
}

Game :: struct {
	score:            [2]int,
	quarter:          int,
	clock:            int, // seconds left in the quarter
	clock_running:    bool,
	possession:       int,
	ball:             int,
	down:             int,
	to_go:            int,
	timeouts:         [2]int,
	phase:            Phase,
	kicker:           int,
	free_kick:        bool,
	opening_receiver: int,
	warned:           bool,
	plays:            int,
	// What the last play said, newest last.
	log:              [LOG][LINE]u8,
	log_len:          [LOG]int,
	log_n:            int,
	events:           bit_set[Event],
	// Where the ball went on the last play, on the fixed field (0 HOME's goal line, 100 VISITORS').
	from_x, to_x:     int,
	rng:              u64,
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

// A whole number from lo to hi inclusive.
rand_range :: proc(g: ^Game, lo, hi: int) -> int {
	return lo + min(hi - lo, int(next_random(g) * f32(hi - lo + 1)))
}

chance :: proc(g: ^Game, pct: int) -> bool {
	return next_random(g) * 100 < f32(pct)
}

// Bunched toward the middle: the sum of two rolls.
spread :: proc(g: ^Game, half: int) -> int {
	return rand_range(g, -half, half) / 2 + rand_range(g, -half, half) / 2
}

other :: proc(t: int) -> int {return 1 - t}

new_game :: proc(g: ^Game, seed: u64) {
	g^ = {}
	g.rng = seed | 1
	g.quarter = 1
	g.clock = QUARTER_SECS
	g.timeouts = {TIMEOUTS, TIMEOUTS}
	g.opening_receiver = rand_range(g, 0, 1)
	g.kicker = other(g.opening_receiver)
	g.possession = g.kicker
	g.phase = .Kickoff
	say(g, "COIN TOSS: %s WILL RECEIVE.", team_name(g.opening_receiver))
}

team_name :: proc(t: int) -> string {return t == HOME ? "HOME" : "VISITORS"}

say :: proc(g: ^Game, format: string, args: ..any) {
	if g.log_n == LOG {
		for i in 1 ..< LOG {
			g.log[i - 1] = g.log[i]
			g.log_len[i - 1] = g.log_len[i]
		}
		g.log_n -= 1
	}
	s := fmt.bprintf(g.log[g.log_n][:], format, ..args)
	g.log_len[g.log_n] = len(s)
	g.log_n += 1
}

log_line :: proc(g: ^Game, i: int) -> string {
	return string(g.log[i][:g.log_len[i]])
}

clear_log :: proc(g: ^Game) {
	g.log_n = 0
}

// The fixed-field position of a spot measured from a team's own goal line.
field_x :: proc(team, yards: int) -> int {
	return team == HOME ? yards : 100 - yards
}

// "HOME 35", "VISITORS 20", or "MIDFIELD".
spot_name :: proc(g: ^Game, buf: []u8) -> string {
	if g.ball == 50 {return "MIDFIELD"}
	if g.ball < 50 {return fmt.bprintf(buf, "%s %d", team_name(g.possession), g.ball)}
	return fmt.bprintf(buf, "%s %d", team_name(other(g.possession)), 100 - g.ball)
}

// ---- the clock ----

// Time off the clock; the two-minute warning stops it once in the fourth quarter.
run_clock :: proc(g: ^Game, secs: int) {
	before := g.clock
	g.clock = max(0, g.clock - secs)
	if g.quarter == 4 && !g.warned && before > 120 && g.clock <= 120 && g.clock > 0 {
		g.warned = true
		g.clock_running = false
		g.events += {.Two_Minute}
		say(g, "TWO MINUTE WARNING.")
	}
}

// Between plays: the huddle runs the clock unless it is stopped, a time out is called, or the
// offence hurries. The snap always comes before the quarter runs out.
huddle :: proc(g: ^Game, off, def: Tempo) {
	def_team := other(g.possession)
	if off == .Time_Out && g.timeouts[g.possession] > 0 {
		g.timeouts[g.possession] -= 1
		say(g, "TIME OUT, %s. %d LEFT.", team_name(g.possession), g.timeouts[g.possession])
		g.clock_running = false
	} else if def == .Time_Out && g.timeouts[def_team] > 0 {
		g.timeouts[def_team] -= 1
		say(g, "TIME OUT, %s. %d LEFT.", team_name(def_team), g.timeouts[def_team])
		g.clock_running = false
	}
	if !g.clock_running {return}
	secs := 26
	#partial switch off {
	case .Quick_Huddle:
		secs = 10
	case .Slow_Down:
		secs = 38
	}
	if def == .Slow_Down {secs += 6}
	run_clock(g, min(secs, max(0, g.clock - 1)))
}

// After a play: the quarter (or the game) may be over.
end_of_play :: proc(g: ^Game) {
	g.plays += 1
	if g.clock > 0 {return}
	switch g.quarter {
	case 1, 3:
		g.events += {.Quarter_Over}
		say(g, "END OF THE %s QUARTER.", g.quarter == 1 ? "FIRST" : "THIRD")
		g.quarter += 1
		g.clock = QUARTER_SECS
		g.clock_running = false
	case 2:
		g.events += {.Half_Time}
		say(g, "HALF TIME. SECOND HALF BEGINS.")
		g.quarter = 3
		g.clock = QUARTER_SECS
		g.clock_running = false
		g.timeouts = {TIMEOUTS, TIMEOUTS}
		g.phase = .Kickoff
		g.free_kick = false
		g.kicker = g.opening_receiver
		g.possession = g.kicker
	case:
		g.events += {.Game_Over}
		g.phase = .Over
		g.clock_running = false
		switch {
		case g.score[HOME] > g.score[VISITORS]:
			say(g, "FINAL: HOME WINS, %d TO %d.", g.score[HOME], g.score[VISITORS])
		case g.score[VISITORS] > g.score[HOME]:
			say(g, "FINAL: VISITORS WIN, %d TO %d.", g.score[VISITORS], g.score[HOME])
		case:
			say(g, "FINAL: A TIE, %d ALL.", g.score[HOME])
		}
	}
}

// ---- possession and scores ----

first_down :: proc(g: ^Game) {
	g.down = 1
	g.to_go = min(10, 100 - g.ball)
}

// The other side takes over with the ball at `yards` from their own goal line.
change_possession :: proc(g: ^Game, yards: int) {
	g.possession = other(g.possession)
	g.ball = clamp(yards, 1, 99)
	first_down(g)
	g.clock_running = false
	g.phase = .Scrimmage
}

touchdown :: proc(g: ^Game, team: int) {
	g.score[team] += 6
	g.events += {.Touchdown}
	say(g, "TOUCHDOWN, %s!", team_name(team))
	if chance(g, 94) {
		g.score[team] += 1
		say(g, "EXTRA POINT GOOD.")
	} else {
		say(g, "EXTRA POINT NO GOOD.")
	}
	kickoff_next(g, team)
}

kickoff_next :: proc(g: ^Game, kicker: int) {
	g.phase = .Kickoff
	g.kicker = kicker
	g.possession = kicker
	g.free_kick = false
	g.clock_running = false
}

safety :: proc(g: ^Game) {
	def_team := other(g.possession)
	g.score[def_team] += 2
	g.events += {.Safety}
	say(g, "SAFETY! TWO POINTS, %s.", team_name(def_team))
	kickoff_next(g, g.possession)
	g.free_kick = true
}

// Moves the ball for the offence and settles downs, scores and turnovers on downs.
gain :: proc(g: ^Game, yards: int) {
	g.ball += yards
	g.to_x = field_x(g.possession, clamp(g.ball, 0, 100))
	if g.ball >= 100 {
		touchdown(g, g.possession)
		return
	}
	if g.ball <= 0 {
		safety(g)
		return
	}
	g.to_go -= yards
	if g.to_go <= 0 {
		first_down(g)
		g.events += {.First_Down}
		say(g, "FIRST DOWN.")
		return
	}
	g.down += 1
	if g.down > 4 {
		say(g, "TURNOVER ON DOWNS.")
		g.events += {.Turnover}
		change_possession(g, 100 - g.ball)
	}
}

// ---- kickoffs ----

kickoff :: proc(g: ^Game, choice: Kick_Choice) {
	if g.phase != .Kickoff {return}
	clear_log(g)
	g.events = {}
	k := g.kicker
	r := other(k)
	from := g.free_kick ? 20 : 35
	free := g.free_kick
	g.free_kick = false
	g.from_x = field_x(k, from)
	run_clock(g, choice == .Onside ? 4 : rand_range(g, 5, 9))
	defer end_of_play(g)
	if choice == .Onside {
		land := from + rand_range(g, 10, 13)
		if chance(g, 22) {
			say(g, "%s TRIES AN ONSIDE KICK... AND RECOVERS!", team_name(k))
			g.events += {.Big_Play}
			g.possession = r // change_possession flips it back to the kicker
			change_possession(g, land)
		} else {
			say(g, "ONSIDE KICK. %s RECOVERS.", team_name(r))
			g.possession = k
			change_possession(g, 100 - land)
		}
		g.to_x = field_x(g.possession, g.ball)
		return
	}
	dist := free ? rand_range(g, 42, 58) : rand_range(g, 54, 72)
	land := 100 - from - dist // from the receiver's goal line; under 0 is in the end zone
	g.possession = k
	if land < -3 {
		say(g, "KICKOFF %d YARDS INTO THE END ZONE. TOUCHBACK.", -land)
		change_possession(g, 20)
		g.to_x = field_x(g.possession, 20)
		return
	}
	ret := 18 + spread(g, 14)
	if chance(g, 4) {ret += rand_range(g, 25, 80)}
	caught := max(land, 0)
	say(g, "KICKOFF TO THE %d. RETURNED %d YARDS.", caught, ret)
	if chance(g, 2) {
		say(g, "FUMBLE! %s RECOVERS.", team_name(k))
		g.events += {.Turnover}
		spot := caught + ret / 2 // from the receiver's goal line
		g.possession = r // change_possession flips it to the kicking team
		change_possession(g, 100 - spot)
		g.to_x = field_x(g.possession, g.ball)
		return
	}
	at := caught + ret
	g.possession = r
	g.to_x = field_x(r, min(at, 100))
	if at >= 100 {
		g.events += {.Big_Play}
		g.ball = 100
		touchdown(g, r)
		return
	}
	g.possession = k
	change_possession(g, at)
	if ret >= 35 {g.events += {.Big_Play}}
}

// ---- plays from scrimmage ----

// Yards a run averages, and what each alignment does to it.
RUN_BASE := [5]int{3, 4, 4, 3, 3}
RUN_MOD := [5][10]int { // indexed by int(Defense)
	// blitz prev stack bal ks km kl krun ksweep goal
	{0, 3, -3, 0, 2, 3, 4, -3, 1, -2}, // weak side
	{0, 3, -3, 0, 2, 3, 4, -3, 1, -2}, // strong side
	{2, 3, -1, 0, 2, 3, 3, 1, -5, 1}, // sweep
	{4, 4, -2, 0, 1, 2, 3, -3, 1, -2}, // delayed
	{-2, 2, -3, 0, 2, 2, 3, -2, 1, -1}, // middle
}

// Passes: completion %, yards, interception %.
PASS_COMP := [3]int{68, 54, 36}
PASS_YARDS := [3]int{7, 14, 30}
PASS_INT := [3]int{2, 4, 6}
COMP_MOD := [3][10]int { // indexed by int(Defense)
	{5, 10, 5, 0, -25, 5, 5, 5, 0, -5},
	{-10, -5, 10, 0, 5, -25, 0, 10, 5, 10},
	{-15, -25, 10, 0, 5, 0, -25, 10, 5, 15},
}

snap :: proc(g: ^Game, c: Call) {
	if g.phase != .Scrimmage {return}
	clear_log(g)
	g.events = {}
	huddle(g, c.off_tempo, c.def_tempo)
	g.from_x = field_x(g.possession, g.ball)
	g.to_x = g.from_x
	defer end_of_play(g)
	g.clock_running = true
	#partial switch c.play {
	case .Punt:
		punt(g, c.punt)
		return
	case .Field_Goal:
		field_goal(g)
		return
	}
	say(g, "%s: %s VS. %s.", team_name(g.possession), PLAY_NAMES[c.play], DEFENSE_NAMES[c.defense])
	if chance(g, 7) {
		penalty(g)
		return
	}
	switch c.play {
	case .Run_Weak, .Run_Strong, .Sweep, .Delayed_Run, .Middle:
		run(g, c.play, c.defense)
	case .Short_Pass, .Medium_Pass, .Long_Pass:
		pass(g, c.play, c.defense)
	case .Razzle_Dazzle:
		razzle(g, c.defense)
	case .Punt, .Field_Goal:
	}
}

run :: proc(g: ^Game, p: Play, d: Defense) {
	i := int(p) - int(Play.Run_Weak)
	mod := RUN_MOD[i][int(d)]
	y := RUN_BASE[i] + mod + spread(g, 5)
	run_clock(g, rand_range(g, 5, 7))
	if d == .Blitz && p != .Delayed_Run && chance(g, 15) {
		y = -rand_range(g, 1, 5)
		say(g, "THE BLITZ GETS THROUGH. TACKLED FOR A LOSS.")
	} else if chance(g, 4 + 2 * max(0, mod)) {
		y += rand_range(g, 10, 45)
		g.events += {.Big_Play}
		say(g, "HE'S THROUGH THE LINE, PAST THE LINEBACKERS...")
	}
	if p == .Sweep && chance(g, 30) {
		g.clock_running = false // out of bounds
	}
	if chance(g, 2) {
		fumble(g, y)
		return
	}
	report_gain(g, y)
	gain(g, y)
}

pass :: proc(g: ^Game, p: Play, d: Defense) {
	i := int(p) - int(Play.Short_Pass)
	sack := 4 + (d == .Blitz ? 14 : 0) - (d == .Prevent ? 3 : 0) + i
	keyed := (i == 0 && d == .Key_Short) || (i == 1 && d == .Key_Medium) || (i == 2 && d == .Key_Long)
	pick := PASS_INT[i] + (keyed ? 6 : 0)
	comp := PASS_COMP[i] + COMP_MOD[i][int(d)]
	run_clock(g, rand_range(g, 5, 9))
	if chance(g, sack) {
		y := -rand_range(g, 4, 10)
		say(g, "SACKED! LOSS OF %d.", -y)
		g.events += {.Loss}
		if chance(g, 8) {
			fumble(g, y)
			return
		}
		gain(g, y)
		return
	}
	if chance(g, pick) {
		air := clamp(PASS_YARDS[i] + spread(g, 6), 1, 60)
		at := g.ball + air
		say(g, "INTERCEPTED!")
		g.events += {.Turnover}
		g.to_x = field_x(g.possession, min(at, 100))
		if at >= 100 {
			say(g, "IN THE END ZONE. TOUCHBACK.")
			change_possession(g, 20)
			return
		}
		ret := rand_range(g, 0, 20)
		if chance(g, 4) {ret += rand_range(g, 20, 100)}
		thief := other(g.possession)
		spot := 100 - at + ret
		if spot >= 100 {
			g.to_x = field_x(thief, 100)
			g.possession = thief
			touchdown(g, thief)
			return
		}
		say(g, "RETURNED %d YARDS.", ret)
		change_possession(g, spot)
		g.to_x = field_x(g.possession, g.ball)
		return
	}
	if !chance(g, comp) {
		say(g, "INCOMPLETE.")
		g.clock_running = false
		gain(g, 0)
		return
	}
	y := PASS_YARDS[i] + spread(g, 4 + i * 4)
	y = max(y, 0)
	if chance(g, 8) {
		y += rand_range(g, 10, 40)
		g.events += {.Big_Play}
		say(g, "CAUGHT, AND HE BREAKS A TACKLE...")
	} else {
		say(g, "COMPLETE.")
	}
	if chance(g, 2) {
		fumble(g, y)
		return
	}
	report_gain(g, y)
	gain(g, y)
}

razzle :: proc(g: ^Game, d: Defense) {
	run_clock(g, rand_range(g, 6, 10))
	big := 35 + (d == .Blitz ? 10 : 0) - (d == .Prevent || d == .Balanced ? 10 : 0)
	r := rand_range(g, 1, 100)
	y: int
	switch {
	case r <= 10:
		say(g, "THE LATERAL GOES ASTRAY...")
		fumble(g, -rand_range(g, 3, 8))
		return
	case r <= 10 + big:
		y = rand_range(g, 18, 55)
		g.events += {.Big_Play}
		say(g, "A HANDOFF, A LATERAL, A PASS... IT WORKS!")
	case r <= 10 + big + 25:
		y = rand_range(g, 0, 8)
		say(g, "A LOT OF RUNNING ABOUT.")
	case:
		y = -rand_range(g, 4, 14)
		say(g, "THE DEFENSE ISN'T FOOLED.")
	}
	report_gain(g, y)
	gain(g, y)
}

report_gain :: proc(g: ^Game, y: int) {
	switch {
	case y > 0:
		say(g, "GAIN OF %d.", y)
	case y < 0:
		say(g, "LOSS OF %d.", -y)
		g.events += {.Loss}
	case:
		say(g, "NO GAIN.")
	}
}

// A fumble at the end of a gain of y: the defence recovers a little over half the time.
fumble :: proc(g: ^Game, y: int) {
	spot := g.ball + y
	if spot >= 100 {spot = 99}
	say(g, "FUMBLE!")
	if spot <= 0 {
		say(g, "RECOVERED IN THE END ZONE.")
		gain(g, y)
		return
	}
	if chance(g, 55) {
		say(g, "%s RECOVERS.", team_name(other(g.possession)))
		g.events += {.Turnover}
		g.to_x = field_x(g.possession, spot)
		change_possession(g, 100 - spot)
		return
	}
	say(g, "%s FALLS ON IT.", team_name(g.possession))
	gain(g, y)
}

Foul :: struct {
	name:      string,
	yards:     int,
	offence:   bool,
	auto:      bool, // an automatic first down
	pre_snap:  bool,
}

FOULS := [?]Foul {
	{"OFFSIDE", 5, true, false, true},
	{"ILLEGAL FORMATION", 5, true, false, true},
	{"FALSE START", 5, true, false, true},
	{"HOLDING", 10, true, false, false},
	{"OFFSIDE", 5, false, false, true},
	{"ENCROACHMENT", 5, false, false, true},
	{"HOLDING", 5, false, true, false},
	{"PERSONAL FOUL", 15, false, true, false},
}

penalty :: proc(g: ^Game) {
	f := FOULS[rand_range(g, 0, len(FOULS) - 1)]
	g.events += {.Penalty}
	side := f.offence ? g.possession : other(g.possession)
	if f.pre_snap {g.clock_running = false} else {run_clock(g, rand_range(g, 4, 7))}
	if f.offence {
		y := min(f.yards, g.ball / 2) // half the distance to the goal
		say(g, "FLAG! %s, %s. %d YARDS. REPLAY THE DOWN.", f.name, team_name(side), y)
		g.ball -= y
		g.to_go += y
	} else {
		y := min(f.yards, (100 - g.ball) / 2)
		g.ball += y
		g.to_go -= y
		if f.auto || g.to_go <= 0 {
			first_down(g)
			g.events += {.First_Down}
			say(g, "FLAG! %s, %s. %d YARDS, FIRST DOWN.", f.name, team_name(side), y)
		} else {
			say(g, "FLAG! %s, %s. %d YARDS.", f.name, team_name(side), y)
		}
	}
	g.to_x = field_x(g.possession, g.ball)
}

// ---- kicking from scrimmage ----

punt :: proc(g: ^Game, choice: Punt_Choice) {
	say(g, "%s PUNTS.", team_name(g.possession))
	run_clock(g, rand_range(g, 8, 12))
	if choice == .Block && chance(g, 18) {
		say(g, "BLOCKED!")
		g.events += {.Turnover, .Big_Play}
		spot := g.ball - rand_range(g, 3, 9)
		if spot <= 0 {
			thief := other(g.possession)
			say(g, "RECOVERED IN THE END ZONE.")
			g.to_x = field_x(g.possession, 0)
			g.possession = thief
			touchdown(g, thief)
			return
		}
		g.to_x = field_x(g.possession, spot)
		change_possession(g, 100 - spot)
		return
	}
	if choice == .Block && chance(g, 7) {
		say(g, "ROUGHING THE KICKER! 15 YARDS AND A FIRST DOWN.")
		g.events += {.Penalty}
		g.ball = min(99, g.ball + 15)
		first_down(g)
		g.to_x = field_x(g.possession, g.ball)
		return
	}
	dist := 42 + spread(g, 14)
	land := g.ball + dist
	if land >= 100 {
		say(g, "%d YARDS, INTO THE END ZONE. TOUCHBACK.", dist)
		g.to_x = field_x(g.possession, 100)
		change_possession(g, 20)
		return
	}
	catcher := 100 - land // from the receiving team's goal line
	switch choice {
	case .Fair_Catch:
		say(g, "%d YARDS. FAIR CATCH AT THE %d.", dist, catcher)
	case .Block:
		roll := rand_range(g, 3, 12) // nobody back to field it
		say(g, "%d YARDS AND NOBODY BACK. IT ROLLS %d MORE.", dist, roll)
		catcher = max(1, catcher - roll)
	case .Return:
		if chance(g, 3) {
			say(g, "%d YARDS. MUFFED! THE KICKING TEAM RECOVERS.", dist)
			g.events += {.Turnover}
			g.to_x = field_x(g.possession, land)
			g.ball = land
			first_down(g)
			g.clock_running = false
			return
		}
		ret := 7 + spread(g, 8)
		if chance(g, 3) {ret += rand_range(g, 30, 90)}
		say(g, "%d YARDS. RETURNED %d.", dist, ret)
		catcher += max(0, ret)
		if catcher >= 100 {
			r := other(g.possession)
			g.to_x = field_x(r, 100)
			g.possession = r
			touchdown(g, r)
			return
		}
	}
	change_possession(g, catcher)
	g.to_x = field_x(g.possession, g.ball)
}

// The chance of a field goal from this far (the kick is from 7 yards behind the line, and the
// goal posts stand on the end line, 10 yards deeper).
field_goal_pct :: proc(ball: int) -> int {
	d := 100 - ball + 17
	switch {
	case d <= 20:
		return 97
	case d <= 30:
		return 90
	case d <= 40:
		return 76
	case d <= 50:
		return 52
	case d <= 55:
		return 32
	case d <= 60:
		return 14
	}
	return 3
}

field_goal :: proc(g: ^Game) {
	d := 100 - g.ball + 17
	run_clock(g, rand_range(g, 4, 6))
	g.clock_running = false
	if chance(g, 3) {
		say(g, "%d-YARD FIELD GOAL ATTEMPT... BLOCKED!", d)
		g.events += {.Turnover}
		change_possession(g, 100 - (g.ball - 7))
		return
	}
	if chance(g, field_goal_pct(g.ball)) {
		say(g, "%d-YARD FIELD GOAL ATTEMPT... IT'S GOOD!", d)
		g.score[g.possession] += 3
		g.events += {.Field_Goal}
		g.to_x = field_x(g.possession, 100)
		kickoff_next(g, g.possession)
		return
	}
	say(g, "%d-YARD FIELD GOAL ATTEMPT... NO GOOD.", d)
	g.events += {.Turnover}
	change_possession(g, max(20, 100 - (g.ball - 7)))
}

// ---- the computer coach ----

behind_late :: proc(g: ^Game, team: int) -> bool {
	return g.quarter == 4 && g.clock < 300 && g.score[team] < g.score[other(team)]
}

ahead_late :: proc(g: ^Game, team: int) -> bool {
	return g.quarter == 4 && g.clock < 360 && g.score[team] > g.score[other(team)]
}

pick_weighted :: proc(g: ^Game, w: []int) -> int {
	total := 0
	for x in w {total += x}
	r := rand_range(g, 1, max(1, total))
	for x, i in w {
		r -= x
		if r <= 0 {return i}
	}
	return len(w) - 1
}

cpu_tempo :: proc(g: ^Game, team: int, offence: bool) -> Tempo {
	late := (g.quarter == 2 || g.quarter == 4) && g.clock <= 120
	if behind_late(g, team) || (late && offence && g.quarter == 2) {
		if g.clock_running && g.timeouts[team] > 0 && late {return .Time_Out}
		return offence ? .Quick_Huddle : .Normal
	}
	if ahead_late(g, team) {return .Slow_Down}
	return .Normal
}

cpu_offense :: proc(g: ^Game) -> (Play, Tempo) {
	team := g.possession
	tempo := cpu_tempo(g, team, true)
	desperate := behind_late(g, team)
	if g.down == 4 {
		fg := field_goal_pct(g.ball)
		need_td := desperate && g.score[other(team)] - g.score[team] > 3
		switch {
		case fg >= 50 && !need_td:
			return .Field_Goal, tempo
		case desperate || (g.to_go <= 1 && g.ball >= 45) || (g.to_go <= 2 && g.ball >= 65 && fg < 50):
		// go for it
		case:
			return .Punt, tempo
		}
	}
	// Last seconds of a half in range: kick it.
	if (g.quarter == 2 || g.quarter == 4) && g.clock < 20 && field_goal_pct(g.ball) >= 40 &&
	   !(desperate && g.score[other(team)] - g.score[team] > 3) {
		return .Field_Goal, tempo
	}
	w: [11]int
	switch {
	case g.to_go <= 2:
		w = {14, 14, 6, 6, 30, 14, 4, 2, 0, 0, 1}
	case g.to_go >= 10 && g.down >= 2:
		w = {4, 4, 6, 6, 2, 22, 30, 18, 0, 0, 3}
	case desperate:
		w = {2, 2, 4, 2, 0, 24, 30, 30, 0, 0, 6}
	case ahead_late(g, team):
		w = {18, 18, 12, 12, 24, 8, 4, 1, 0, 0, 0}
	case:
		w = {12, 12, 10, 8, 12, 18, 14, 8, 0, 0, 2}
	}
	return Play(pick_weighted(g, w[:])), tempo
}

cpu_defense :: proc(g: ^Game) -> (Defense, Tempo) {
	team := other(g.possession)
	tempo := cpu_tempo(g, team, false)
	w: [10]int
	switch {
	case g.ball >= 92:
		w = {6, 0, 14, 8, 6, 4, 2, 10, 6, 40}
	case behind_late(g, g.possession) && g.clock < 120:
		w = {8, 36, 2, 8, 8, 18, 18, 0, 2, 0}
	case g.to_go <= 2:
		w = {16, 0, 30, 10, 8, 2, 2, 20, 8, 4}
	case g.to_go >= 10:
		w = {14, 18, 2, 12, 12, 20, 14, 2, 4, 2}
	case:
		w = {10, 6, 10, 20, 12, 12, 8, 10, 10, 2}
	}
	return Defense(pick_weighted(g, w[:])), tempo
}

cpu_punt_choice :: proc(g: ^Game) -> Punt_Choice {
	if g.ball >= 55 {return .Fair_Catch} // deep in our own end: make it safe
	if chance(g, 15) {return .Block}
	return .Return
}

cpu_kick_choice :: proc(g: ^Game) -> Kick_Choice {
	k := g.kicker
	if g.quarter == 4 && g.clock < 180 && g.score[k] < g.score[other(k)] {return .Onside}
	return .Deep
}

// A whole call from the computer coaches on both sides (for tests and demos).
cpu_call :: proc(g: ^Game) -> Call {
	c: Call
	c.play, c.off_tempo = cpu_offense(g)
	c.defense, c.def_tempo = cpu_defense(g)
	c.punt = cpu_punt_choice(g)
	return c
}
