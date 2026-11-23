#+build !js
package bowling

import "core:testing"

@(test)
a_straight_ball_never_strikes :: proc(t: ^testing.T) {
	for step := -1500; step <= 1500; step += 1 {
		rel := f32(step) / 100
		r := roll_ball(ALL_PINS, rel, .Straight)
		testing.expect(t, r.down != ALL_PINS)
	}
}

@(test)
a_break_into_the_pocket_strikes :: proc(t: ^testing.T) {
	for th in ([2]Throw{.Break_Left, .Break_Right}) {
		strikes := 0
		for step := -1500; step <= 1500; step += 1 {
			r := roll_ball(ALL_PINS, f32(step) / 100, th)
			if r.down == ALL_PINS {strikes += 1}
		}
		// A window, not a single spot, and not most of the sweep either.
		testing.expect(t, strikes > 40)
		testing.expect(t, strikes < 600)
	}
}

@(test)
head_on_leaves_the_big_four :: proc(t: ^testing.T) {
	r := roll_ball(ALL_PINS, 0, .Straight)
	testing.expect(t, ALL_PINS - r.down == Pins{3, 5, 6, 9}) // 4, 6, 7, 10
}

@(test)
the_channel_takes_a_wild_ball :: proc(t: ^testing.T) {
	r := roll_ball(ALL_PINS, 15, .Break_Right)
	testing.expect(t, r.gutter)
	testing.expect_value(t, count(r.down), 0)
}

@(test)
the_seven_ten_converts_only_on_the_kick :: proc(t: ^testing.T) {
	split := Pins{6, 9}
	thin, full := 0, 0
	for step := 0; step <= 1500; step += 1 {
		rel := f32(step) / 100
		r := roll_ball(split, rel, .Straight)
		if 9 not_in r.down {continue}
		testing.expect(t, 6 not_in r.down) // no luck, no conversion
		lucky := roll_ball(split, rel, .Straight, 0.5)
		if abs(PIN_X[9] - r.ball_x[3]) >= THIN_HIT {
			thin += 1
			testing.expect(t, lucky.down == split && lucky.kickback)
		} else {
			full += 1
			testing.expect(t, lucky.down == Pins{9}) // a full hit just takes the one
		}
	}
	testing.expect(t, thin > 0 && full > 0)
}

@(test)
a_perfect_game_is_300 :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 1, {}, 1)
	for _ in 0 ..< 12 {record(&g, ALL_PINS)}
	testing.expect(t, g.over)
	testing.expect_value(t, total(&g.bowlers[0]), 300)
	m, n := frame_marks(&g.bowlers[0], 9)
	testing.expect_value(t, n, 3)
	testing.expect(t, m[0] == "X" && m[1] == "X" && m[2] == "X")
}

@(test)
spares_and_open_frames_score :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 1, {}, 1)
	// Every frame 9 then the last pin: a spare each time, and a 9 on the bonus ball.
	for _ in 0 ..< 10 {
		record(&g, Pins{0, 1, 2, 3, 4, 5, 6, 7, 8})
		record(&g, Pins{9})
	}
	record(&g, Pins{0, 1, 2, 3, 4, 5, 6, 7, 8})
	testing.expect(t, g.over)
	testing.expect_value(t, total(&g.bowlers[0]), 190)
	m, _ := frame_marks(&g.bowlers[0], 0)
	testing.expect(t, m[0] == "9" && m[1] == "/")

	h: Game
	new_game(&h, 1, {}, 1)
	for _ in 0 ..< 20 {record(&h, Pins{0, 1, 2})} // three, then nothing more of the same pins
	testing.expect(t, h.over)
	testing.expect_value(t, total(&h.bowlers[0]), 30)
}

@(test)
bowlers_take_turns_by_frame :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 2, {false, true, false, false}, 1)
	testing.expect_value(t, record(&g, ALL_PINS), Result.Next_Bowler) // a strike ends the frame
	testing.expect_value(t, g.current, 1)
	testing.expect_value(t, record(&g, Pins{0}), Result.Next_Ball)
	testing.expect_value(t, record(&g, Pins{1}), Result.Next_Bowler)
	testing.expect_value(t, g.current, 0)
	testing.expect_value(t, g.frame, 1)
}

@(test)
the_computer_bowls_a_fair_game :: proc(t: ^testing.T) {
	sum := 0
	games := 20
	for s in 0 ..< games {
		g: Game
		new_game(&g, 1, {true, false, false, false}, u64(s * 7 + 3))
		for !g.over {
			rel, th := plan_throw(&g, g.standing, 2.0)
			r := roll_ball(g.standing, rel, th, rand(&g) * 3)
			record(&g, r.down)
		}
		sum += total(&g.bowlers[0])
	}
	avg := sum / games
	testing.expectf(t, avg > 100 && avg < 260, "average %d", avg)
}
