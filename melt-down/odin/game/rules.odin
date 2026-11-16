package meltdown

// Melt Down: keep a failing reactor from melting down. After "Melt Down" by Michael Winter
// (SoftSide, August 1979). The meters, the sixteen disasters (starting readings and drift
// directions, from the listing's DATA lines 1620-1770), the commands and their trade-offs, the
// three-second plant check and the skill bands follow the original; how the meters push each
// other is a new, simpler model (see DESIGN.md). Pure rules: no platform imports.

Meter :: enum {
	Water_Level,
	Core_Temp,
	Room_Temp,
	Water_Pressure,
	Critical_Mass,
	Control_Rods, // 9 = fully inserted, 1 = fully withdrawn
	Turbine_Speed,
	Radiation,
	Coolant, // emergency core cooling reserve
}

METER_NAMES := [Meter]string {
	.Water_Level    = "WATER LEVEL",
	.Core_Temp      = "CORE TEMP",
	.Room_Temp      = "ROOM TEMP",
	.Water_Pressure = "WATER PRESSURE",
	.Critical_Mass  = "CRITICAL MASS",
	.Control_Rods   = "CONTROL RODS",
	.Turbine_Speed  = "TURBINE SPEED",
	.Radiation      = "RADIATION",
	.Coolant        = "EMR CORE COOLING",
}

Disaster :: struct {
	name:  string,
	start: [9]f32, // in Meter order
	drift: [9]f32,
}

// Straight from the listing: name, nine starting readings, nine drift directions.
DISASTERS := [16]Disaster {
	{"WATER LEVEL LOW!", {3, 7, 6, 4, 5, 5, 4, 2, 4}, {-1, 1, 1, -1, 0, 0, -1, -1, -1}},
	{"WATER PRESSURE LOW!", {4, 7, 6, 3, 5, 5, 3, 2, 4}, {-1, 1, 1, -1, 0, 0, -1, 1, -1}},
	{"LOW CRITICAL MASS!", {5, 7, 6, 5, 3, 5, 6, 3, 5}, {0, 1, 1, 0, -1, 0, 1, 1, 0}},
	{"HIGH CRITICAL MASS!", {5, 3, 4, 5, 7, 5, 4, 1, 5}, {0, -1, -1, 0, 1, 0, -1, 0, 0}},
	{"WATER PRESSURE HIGH!", {6, 5, 5, 7, 4, 5, 7, 1, 6}, {1, 0, 0, 1, 0, 0, 1, 0, 1}},
	{"WATER LEVEL VERY LOW!!", {2, 8, 7, 3, 5, 5, 3, 4, 3}, {-1, 1, 1, -1, 0, 0, -1, 1, -1}},
	{"WATER PRESSURE VERY LOW!!", {3, 8, 7, 3, 5, 5, 2, 4, 4}, {-1, 1, 1, -1, 0, 0, -1, 1, -1}},
	{"VERY HIGH CRITICAL MASS!!", {5, 2, 3, 5, 8, 5, 3, 1, 5}, {0, -1, -1, 0, 1, 0, -1, 0, 0}},
	{"VERY LOW CRITICAL MASS!!", {5, 8, 7, 5, 2, 5, 7, 4, 5}, {0, 1, 1, 0, -1, 0, 1, 1, 0}},
	{"EMR. CORE COOLING FAILURE", {3, 7, 6, 4, 5, 5, 4, 2, 1}, {-1, 1, 1, -1, 0, 0, -1, 1, -1}},
	{"PUMP POWER FAILURE", {4, 7, 6, 2, 5, 5, 1, 2, 4}, {-1, 1, 1, -1, 0, 0, -1, -1, -1}},
	{"VERY HIGH RADIATION LEVEL!!", {3, 7, 6, 4, 5, 5, 6, 5, 4}, {-1, 1, 1, -1, 0, 0, 1, 1, -1}},
	{"VERY HIGH RADIATION LEVEL!!", {2, 8, 7, 3, 5, 5, 7, 6, 3}, {-1, 1, 1, -1, 0, 0, 1, 1, -1}},
	{"HIGH TURBINE SPEED!", {6, 4, 4, 7, 5, 5, 7, 1, 6}, {1, 0, 0, 1, 0, 0, 1, 0, 1}},
	{"VERY HIGH TURBINE SPEED!!", {6, 4, 4, 8, 5, 5, 8, 1, 6}, {1, 0, 0, 1, 0, 0, 1, 0, 1}},
	{"WATER PUMP FAILURE!", {4, 7, 6, 1, 5, 5, 1, 3, 4}, {-1, 1, 1, 0, 0, 0, 0, 1, -1}},
}

TICK_SECONDS :: 3.0
GRACE_SECONDS :: 3.0
// How hard a disaster's drift pushes on each check, and how fast the fault fades out.
DRIFT_STEP :: 0.25
DRIFT_FADE :: 0.82
// Seconds that must pass before the plant can count as stable (the original's TM > 5).
MIN_SECONDS :: 6.0

Command :: enum {
	None,
	Valve, // V: open the main dump valve 2-8
	Rods, // C: raise (+) or lower (-) the control rods 1-9
	Coolant, // E: release emergency core coolant 1-9 (no more than the reserve)
	Fuel, // P: add (+) or remove (-) fuel units 1-9
	Scram, // S: drop every rod (asks to confirm)
	Flood, // O: flood the core with plain water 1-9
	Turbine, // T: set turbine speed 1-9 (10% to 90%)
}

State :: enum {
	Running,
	Won,
	Lost,
}

Skill :: struct {
	band:    f32, // how far from 5 a meter may read
	rad_max: f32, // radiation at or below
	cool_min: f32, // emergency cooling at or above
}

// Level 1 accepts 3 to 7 (the original: 3.5 to 7.5); level 5 wants 4.5 to 5.5 (the original
// wanted exactly 5, which this smoother model makes close to impossible).
SKILLS := [6]Skill {
	{},
	{2.0, 4.0, 1.0},
	{1.5, 3.5, 1.5},
	{1.0, 3.0, 2.0},
	{0.75, 2.5, 2.5},
	{0.5, 2.0, 3.0},
}

SKILL_NAMES := [6]string{"", "NOVICE", "EASY", "HARD", "VERY HARD", "EXPERT"}

Game :: struct {
	m:           [Meter]f32,
	drift:       [Meter]f32,
	disaster:    int,
	skill:       int,
	clock:       f32, // seconds since the disaster began
	until_tick:  f32,
	ticks:       int,
	burst_ticks: int, // checks left without core cooling after the pipes burst
	state:       State,
	message:     string, // last thing the plant said (a constant string)
	events:      bit_set[Event],
}

// Things the page may want to sound; cleared by the caller after reading.
Event :: enum {
	Tick,
	Command,
	Burst,
	Refused,
	Won,
	Lost,
}

new_game :: proc(g: ^Game, disaster: int, skill: int) {
	d := DISASTERS[disaster]
	g^ = {}
	g.disaster = disaster
	g.skill = clamp(skill, 1, 5)
	g.m = transmute([Meter]f32)d.start
	g.drift = transmute([Meter]f32)d.drift
	// One check of grace while the player reads the board ("stand by to take command").
	g.until_tick = TICK_SECONDS + GRACE_SECONDS
	g.message = "AN EVENT HAS OCCURRED -- STAND BY TO TAKE COMMAND"
}

// Advances the clock; every three seconds the plant moves and is checked.
update :: proc(g: ^Game, dt: f32) {
	if g.state != .Running {return}
	g.clock += dt
	g.until_tick -= dt
	for g.until_tick <= 0 && g.state == .Running {
		g.until_tick += TICK_SECONDS
		tick(g)
	}
}

clamp_meters :: proc(g: ^Game) {
	for &v, k in g.m {
		lo: f32 = k == .Coolant ? 0 : 1
		v = clamp(v, lo, 9)
	}
}

// One plant check: the fault pushes, the meters push each other, then win or lose.
tick :: proc(g: ^Game) {
	g.ticks += 1
	g.events += {.Tick}
	for k in Meter {
		g.m[k] += g.drift[k] * DRIFT_STEP
		g.drift[k] *= DRIFT_FADE
	}

	w := g.m[.Water_Level]
	c := g.m[.Core_Temp]
	// Fission heat from fuel and from withdrawn rods; water carries it away.
	heat := 0.12 * (g.m[.Critical_Mass] - 5) + 0.15 * (5 - g.m[.Control_Rods])
	cooling := 0.12 * (w - 5)
	if g.burst_ticks > 0 {
		g.burst_ticks -= 1
		cooling = -0.4
	}
	g.m[.Core_Temp] += heat - cooling
	// Boil-off: a hot core drinks its water.
	g.m[.Water_Level] -= 0.03 * (c - 3)
	// Steam builds pressure; the turbine spends it and spins with it.
	g.m[.Water_Pressure] += 0.15 * (c - 5) - 0.12 * (g.m[.Turbine_Speed] - 5) + 0.05 * (w - 5)
	g.m[.Turbine_Speed] += 0.08 * (g.m[.Water_Pressure] - 5)
	// The room follows the core; radiation follows heat and fuel.
	g.m[.Room_Temp] += 0.5 * (g.m[.Core_Temp] - g.m[.Room_Temp])
	rad_target := 1 + 0.8 * max(0, g.m[.Core_Temp] - 4) + 0.4 * max(0, g.m[.Critical_Mass] - 5)
	g.m[.Radiation] += 0.4 * (rad_target - g.m[.Radiation])

	if g.m[.Water_Pressure] >= 9 {
		g.m[.Water_Pressure] = 4
		g.m[.Water_Level] -= 2
		g.burst_ticks = 2
		g.message = "WATER PRESSURE AT 9 -- THE PIPES HAVE BURST!"
		g.events += {.Burst}
	}
	clamp_meters(g)
	check(g)
}

in_band :: proc(g: ^Game, k: Meter) -> bool {
	s := SKILLS[g.skill]
	v := g.m[k]
	#partial switch k {
	case .Radiation:
		return v <= s.rad_max
	case .Coolant:
		return v >= s.cool_min
	}
	return abs(v - 5) <= s.band + 0.001
}

stable :: proc(g: ^Game) -> bool {
	for k in Meter {
		if !in_band(g, k) {return false}
	}
	return true
}

check :: proc(g: ^Game) {
	if g.state != .Running {return}
	if g.m[.Core_Temp] >= 9 {
		g.state = .Lost
		g.message = "THE CORE TEMPERATURE HAS REACHED 9 -- MELTDOWN"
		g.events += {.Lost}
		return
	}
	if g.clock >= MIN_SECONDS && stable(g) {
		g.state = .Won
		g.message = "THE REACTOR IS UNDER CONTROL!"
		g.events += {.Won}
	}
}

// The range of amounts a command takes, and whether it asks for a sign first.
amount_range :: proc(c: Command) -> (lo, hi: int, signed: bool) {
	#partial switch c {
	case .Valve:
		return 2, 8, false
	case .Rods, .Fuel:
		return 1, 9, true
	case .Coolant, .Flood, .Turbine:
		return 1, 9, false
	}
	return 0, 0, false
}

// Runs a command. amount is signed for Rods and Fuel; Scram ignores it. Returns false (and a
// message) when the plant refuses it.
command :: proc(g: ^Game, c: Command, amount: int) -> bool {
	if g.state != .Running {return false}
	n := f32(abs(amount))
	sign: f32 = amount < 0 ? -1 : 1
	switch c {
	case .None:
		return false
	case .Valve:
		// Lowers water pressure; raises core temperature.
		g.m[.Water_Level] -= n * 0.35
		g.m[.Water_Pressure] -= n * 0.5
		g.m[.Core_Temp] += n * 0.2
		g.m[.Turbine_Speed] -= n * 0.15
		g.message = "MAIN DUMP VALVE OPENED"
	case .Rods:
		// Raising them speeds the turbine and heats the core; lowering does the opposite.
		g.m[.Control_Rods] -= sign * n * 0.5
		g.m[.Core_Temp] += sign * n * 0.25
		g.m[.Turbine_Speed] += sign * n * 0.25
		g.m[.Water_Pressure] += sign * n * 0.15
		g.message = sign > 0 ? "CONTROL RODS RAISED" : "CONTROL RODS LOWERED"
	case .Coolant:
		// Cools the core; spends the emergency reserve.
		if n > g.m[.Coolant] {
			g.message = "YOU DON'T HAVE ENOUGH COOLANT"
			g.events += {.Refused}
			return false
		}
		g.m[.Coolant] -= n
		g.m[.Core_Temp] -= n * 0.5
		g.m[.Water_Level] += n * 0.25
		g.m[.Room_Temp] -= n * 0.2
		g.message = "EMERGENCY COOLANT RELEASED"
	case .Fuel:
		// Each unit moves critical mass by a half. Adding slows the turbine; pulling fuel
		// heats the core for a moment.
		if sign > 0 && g.m[.Critical_Mass] + n * 0.5 > 9 {
			g.message = "YOU CAN'T ENTER THAT MUCH"
			g.events += {.Refused}
			return false
		}
		g.m[.Critical_Mass] += sign * n * 0.5
		if sign > 0 {
			g.m[.Turbine_Speed] -= n * 0.15
			g.message = "FUEL ADDED"
		} else {
			g.m[.Core_Temp] += n * 0.1
			g.message = "FUEL REMOVED"
		}
	case .Scram:
		// Every rod in: cools the core, stops the turbine.
		g.m[.Control_Rods] = 9
		g.m[.Core_Temp] -= 2
		g.m[.Turbine_Speed] -= 3
		g.m[.Water_Pressure] += 1
		g.m[.Coolant] += 0.5
		g.message = "REACTOR SCRAM -- ALL RODS IN"
	case .Flood:
		// Cools the core; raises water pressure; tops up the emergency reserve a little.
		g.m[.Water_Level] += n * 0.4
		g.m[.Core_Temp] -= n * 0.3
		g.m[.Water_Pressure] += n * 0.35
		g.m[.Coolant] += n * 0.15
		g.message = "PLAIN WATER VALVE OPENED"
	case .Turbine:
		// Speeding up heats the core and spends pressure; slowing down raises pressure.
		target := clamp(n, 1, 9)
		delta := target - g.m[.Turbine_Speed]
		g.m[.Turbine_Speed] = target
		if delta > 0 {
			g.m[.Core_Temp] += delta * 0.2
			g.m[.Water_Pressure] -= delta * 0.3
		} else {
			g.m[.Water_Pressure] -= delta * 0.4
		}
		g.message = "TURBINE SPEED SET"
	}
	g.events += {.Command}
	clamp_meters(g)
	// The original also checks the plant whenever a key is pressed.
	if g.m[.Water_Pressure] >= 9 {
		g.m[.Water_Pressure] = 4
		g.m[.Water_Level] -= 2
		g.burst_ticks = 2
		g.message = "WATER PRESSURE AT 9 -- THE PIPES HAVE BURST!"
		g.events += {.Burst}
		clamp_meters(g)
	}
	check(g)
	return true
}
