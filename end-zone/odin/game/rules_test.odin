#+build !js
package endzone

import "core:log"
import "core:testing"

scrimmage :: proc(g: ^Game, team, ball: int) {
	g.phase = .Scrimmage
	g.possession = team
	g.ball = ball
	first_down(g)
	g.clock_running = false
}

@(test)
coin_toss_then_kickoff :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 5)
	testing.expect_value(t, g.phase, Phase.Kickoff)
	testing.expect_value(t, g.kicker, other(g.opening_receiver))
	kickoff(&g, .Deep)
	testing.expect(t, g.phase == .Scrimmage || g.phase == .Kickoff) // a return TD is possible
	testing.expect(t, g.clock < QUARTER_SECS)
}

@(test)
downs_and_first_downs :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 5)
	scrimmage(&g, HOME, 30)
	gain(&g, 4)
	testing.expect_value(t, g.down, 2)
	testing.expect_value(t, g.to_go, 6)
	gain(&g, 7)
	testing.expect_value(t, g.down, 1)
	testing.expect_value(t, g.to_go, 10)
	testing.expect_value(t, g.ball, 41)
	gain(&g, 0)
	gain(&g, 0)
	gain(&g, 0)
	gain(&g, 0) // fourth down fails
	testing.expect_value(t, g.possession, VISITORS)
	testing.expect_value(t, g.ball, 59)
	// Goal to go.
	scrimmage(&g, HOME, 95)
	testing.expect_value(t, g.to_go, 5)
}

@(test)
touchdowns_and_safeties :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 5)
	scrimmage(&g, VISITORS, 96)
	gain(&g, 6)
	testing.expect(t, g.score[VISITORS] == 6 || g.score[VISITORS] == 7)
	testing.expect_value(t, g.phase, Phase.Kickoff)
	testing.expect_value(t, g.kicker, VISITORS)
	scrimmage(&g, HOME, 3)
	gain(&g, -5)
	testing.expect_value(t, g.score[VISITORS] >= 8, true)
	testing.expect_value(t, g.kicker, HOME)
	testing.expect(t, g.free_kick)
}

@(test)
field_goal_odds_fall_with_distance :: proc(t: ^testing.T) {
	testing.expect(t, field_goal_pct(95) > field_goal_pct(75))
	testing.expect(t, field_goal_pct(75) > field_goal_pct(60))
	testing.expect(t, field_goal_pct(40) < 10)
	g: Game
	new_game(&g, 5)
	made := 0
	for i in 0 ..< 400 {
		scrimmage(&g, HOME, 90) // a 27-yarder
		g.score = {}
		snap(&g, {play = .Field_Goal})
		if g.score[HOME] == 3 {made += 1}
		g.quarter = 1
		g.clock = QUARTER_SECS
		_ = i
	}
	testing.expect(t, made > 320 && made < 395)
}

@(test)
time_maneuvers :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 5)
	scrimmage(&g, HOME, 30)
	g.clock_running = true
	g.clock = 600
	huddle(&g, .Normal, .Normal)
	normal := 600 - g.clock
	g.clock = 600
	huddle(&g, .Quick_Huddle, .Normal)
	quick := 600 - g.clock
	g.clock = 600
	huddle(&g, .Slow_Down, .Slow_Down)
	slow := 600 - g.clock
	testing.expect(t, quick < normal && normal < slow)
	g.clock = 600
	huddle(&g, .Normal, .Time_Out)
	testing.expect_value(t, g.clock, 600)
	testing.expect_value(t, g.timeouts[VISITORS], TIMEOUTS - 1)
	g.clock_running = true
	g.timeouts[HOME] = 0
	huddle(&g, .Time_Out, .Normal) // none left: the clock runs
	testing.expect(t, g.clock < 600)
}

@(test)
two_minute_warning_and_quarters :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 5)
	scrimmage(&g, HOME, 30)
	g.quarter = 4
	g.clock = 125
	g.clock_running = true
	run_clock(&g, 20)
	testing.expect(t, .Two_Minute in g.events)
	testing.expect(t, !g.clock_running)
	g.quarter = 2
	g.clock = 0
	end_of_play(&g)
	testing.expect_value(t, g.quarter, 3)
	testing.expect_value(t, g.phase, Phase.Kickoff)
	testing.expect_value(t, g.kicker, g.opening_receiver)
	testing.expect_value(t, g.timeouts, [2]int{TIMEOUTS, TIMEOUTS})
	g.quarter = 4
	g.clock = 0
	end_of_play(&g)
	testing.expect_value(t, g.phase, Phase.Over)
}

@(test)
keyed_defence_shuts_a_pass_down :: proc(t: ^testing.T) {
	yards :: proc(d: Defense) -> int {
		g: Game
		new_game(&g, 99)
		total := 0
		for _ in 0 ..< 3000 {
			scrimmage(&g, HOME, 30)
			g.quarter = 1
			g.clock = QUARTER_SECS
			before := g.ball
			snap(&g, {play = .Long_Pass, defense = d})
			if g.possession == HOME && g.phase == .Scrimmage {total += g.ball - before}
		}
		return total
	}
	testing.expect(t, yards(.Key_Long) < yards(.Stacked))
}

// Computer coaches on both sides play whole games: they end, and the scores look like football.
@(test)
whole_games :: proc(t: ^testing.T) {
	GAMES :: 300
	points, plays, max_plays := 0, 0, 0
	for seed in u64(1) ..= GAMES {
		g: Game
		new_game(&g, seed * 104729)
		for steps := 0; g.phase != .Over; steps += 1 {
			if steps > 2000 {
				testing.fail_now(t, "a game that never ends")
			}
			switch g.phase {
			case .Kickoff:
				kickoff(&g, cpu_kick_choice(&g))
			case .Scrimmage:
				snap(&g, cpu_call(&g))
			case .Over:
			}
			if g.phase == .Scrimmage {
				testing.expect(t, g.ball >= 1 && g.ball <= 99)
				testing.expect(t, g.down >= 1 && g.down <= 4)
				testing.expect(t, g.to_go >= 1 && g.ball + g.to_go <= 100)
			}
		}
		points += g.score[HOME] + g.score[VISITORS]
		plays += g.plays
		max_plays = max(max_plays, g.plays)
	}
	log.infof("computer vs computer: %.1f points and %.1f plays a game (most %d)", f32(points) / GAMES, f32(plays) / GAMES, max_plays)
	testing.expect(t, points / GAMES > 18 && points / GAMES < 70)
	testing.expect(t, plays / GAMES > 90 && plays / GAMES < 220)
}
