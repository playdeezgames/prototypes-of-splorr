#+build !js
package meltdown

import "core:fmt"
import "core:testing"

@(test)
disasters_match_the_listing :: proc(t: ^testing.T) {
	testing.expect_value(t, len(DISASTERS), 16)
	testing.expect_value(t, DISASTERS[0].name, "WATER LEVEL LOW!")
	testing.expect_value(t, DISASTERS[15].start[Meter.Water_Pressure], 1)
	testing.expect_value(t, DISASTERS[9].start[Meter.Coolant], 1)
	for d in DISASTERS {
		for v in d.drift {testing.expect(t, v >= -1 && v <= 1)}
	}
}

@(test)
plant_moves_every_three_seconds :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 0, 1)
	update(&g, 5.9)
	testing.expect_value(t, g.ticks, 0)
	update(&g, 0.2)
	testing.expect_value(t, g.ticks, 1)
	update(&g, 6)
	testing.expect_value(t, g.ticks, 3)
}

@(test)
hot_core_melts_down :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 0, 1)
	g.m[.Core_Temp] = 8.9
	g.m[.Control_Rods] = 1
	update(&g, TICK_SECONDS + GRACE_SECONDS)
	testing.expect_value(t, g.state, State.Lost)
}

@(test)
coolant_cannot_exceed_reserve :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 9, 1) // emergency core cooling failure: reserve 1
	testing.expect(t, !command(&g, .Coolant, 3))
	testing.expect(t, .Refused in g.events)
	testing.expect(t, command(&g, .Coolant, 1))
}

@(test)
scram_drops_every_rod :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 0, 1)
	before := g.m[.Core_Temp]
	command(&g, .Scram, 0)
	testing.expect_value(t, g.m[.Control_Rods], 9)
	testing.expect(t, g.m[.Core_Temp] < before)
}

@(test)
stable_plant_wins_after_six_seconds :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 0, 5)
	for &v in g.m {v = 5}
	g.m[.Radiation] = 1
	g.m[.Coolant] = 5
	g.drift = {}
	check(&g)
	testing.expect_value(t, g.state, State.Running) // too soon
	g.clock = MIN_SECONDS
	check(&g)
	testing.expect_value(t, g.state, State.Won)
}

// ---- a lookahead bot: proves every disaster can be brought under control ----

@(private = "file")
cost :: proc(g: ^Game) -> f32 {
	if g.state == .Lost {return 1e9}
	if g.state == .Won {return -1e9}
	s := SKILLS[g.skill]
	total: f32 = 0
	for k in Meter {
		v := g.m[k]
		switch k {
		case .Radiation:
			total += max(0, v - s.rad_max + 0.3) * 2
		case .Coolant:
			total += max(0, s.cool_min + 0.5 - v) * 2
		case .Water_Level, .Core_Temp, .Room_Temp, .Water_Pressure, .Critical_Mass, .Control_Rods, .Turbine_Speed:
			d := abs(v - 5)
			total += d * d
		}
	}
	total += max(0, g.m[.Core_Temp] - 7) * 20
	total += max(0, g.m[.Water_Pressure] - 7.5) * 10
	return total
}

@(private = "file")
Choice :: struct {
	c: Command,
	n: int,
}

@(private = "file")
rollout :: proc(g: Game, ch: Choice, horizon: int) -> f32 {
	h := g
	if ch.c != .None {command(&h, ch.c, ch.n)}
	best := cost(&h)
	for _ in 0 ..< horizon {
		update(&h, TICK_SECONDS)
		best = min(best, cost(&h))
		if h.state != .Running {break}
	}
	return best + cost(&h) * 0.5
}

bot_play :: proc(disaster, skill: int, act: bool, limit_s: f32) -> (State, f32) {
	g: Game
	new_game(&g, disaster, skill)
	choices: [dynamic]Choice
	defer delete(choices)
	append(&choices, Choice{.None, 0})
	append(&choices, Choice{.Scram, 0})
	for c in Command {
		lo, hi, signed := amount_range(c)
		if hi == 0 {continue}
		for n in lo ..= hi {
			append(&choices, Choice{c, n})
			if signed {append(&choices, Choice{c, -n})}
		}
	}
	for g.state == .Running && g.clock < limit_s {
		if act {
			best := choices[0]
			best_cost := rollout(g, best, 3)
			for ch in choices[1:] {
				c := rollout(g, ch, 3)
				if c < best_cost {best, best_cost = ch, c}
			}
			if best.c != .None {command(&g, best.c, best.n)}
		}
		// A player needs a moment per command: about 2.5 s.
		update(&g, 2.5)
	}
	return g.state, g.clock
}

@(test)
every_disaster_can_be_won :: proc(t: ^testing.T) {
	for skill in 1 ..= 5 {
		for d in 0 ..< len(DISASTERS) {
			state, secs := bot_play(d, skill, true, 600)
			if state != .Won {
				testing.expectf(t, false, "skill %d, %s: %v after %.0f s", skill, DISASTERS[d].name, state, secs)
			}
		}
	}
}

@(test)
idling_never_wins :: proc(t: ^testing.T) {
	lost := 0
	for d in 0 ..< len(DISASTERS) {
		state, _ := bot_play(d, 1, false, 600)
		testing.expectf(t, state != .Won, "%s won with no commands", DISASTERS[d].name)
		if state == .Lost {lost += 1}
	}
	// Most disasters should melt down if left alone.
	testing.expectf(t, lost >= 10, "only %d of 16 melted down when left alone", lost)
	fmt.printfln("idle: %d of 16 melt down", lost)
}
