#+build !js
package chessclock

import "core:testing"

@(test)
two_hours_each_and_white_starts :: proc(t: ^testing.T) {
	c: Clock
	reset(&c, 0)
	testing.expect_value(t, c.left[.White], 7200.0)
	testing.expect_value(t, c.left[.Black], 7200.0)
	testing.expect(t, press(&c, .Black))
	testing.expect_value(t, c.state, State.Running)
	testing.expect_value(t, c.to_move, Side.White)
	tick(&c, 5)
	testing.expect_value(t, c.left[.White], 7195.0)
	testing.expect_value(t, c.left[.Black], 7200.0)
}

@(test)
only_the_side_to_move_can_press :: proc(t: ^testing.T) {
	c: Clock
	reset(&c, 0)
	press(&c, .Black)
	testing.expect(t, !press(&c, .Black))
	testing.expect(t, press(&c, .White))
	testing.expect_value(t, c.to_move, Side.Black)
	testing.expect(t, press(&c, .Black))
	testing.expect_value(t, turns(&c), 1)
}

@(test)
forty_moves_earn_the_next_hour :: proc(t: ^testing.T) {
	c: Clock
	reset(&c, 0)
	press(&c, .Black)
	for _ in 0 ..< 39 {
		press(&c, .White)
		press(&c, .Black)
	}
	testing.expect_value(t, moves_to_control(&c, .White), 1)
	before := c.left[.White]
	press(&c, .White)
	testing.expect(t, .Control_Made in c.events)
	testing.expect_value(t, c.left[.White], before + 3600)
	testing.expect_value(t, moves_to_control(&c, .White), 20)
	testing.expect_value(t, moves_to_control(&c, .Black), 1)
}

@(test)
increment_after_every_move :: proc(t: ^testing.T) {
	c: Clock
	reset(&c, 3) // blitz 5 + 3
	press(&c, .Black)
	tick(&c, 10)
	press(&c, .White)
	testing.expect_value(t, c.left[.White], 300.0 - 10 + 3)
	testing.expect_value(t, moves_to_control(&c, .White), -1)
}

@(test)
the_flag_falls :: proc(t: ^testing.T) {
	c: Clock
	reset(&c, 5) // bullet, one minute
	press(&c, .White)
	tick(&c, 50.5)
	testing.expect(t, .Low_Time in c.events)
	tick(&c, 10)
	testing.expect_value(t, c.state, State.Flagged)
	testing.expect_value(t, c.flagged, Side.White)
	testing.expect_value(t, c.left[.White], 0.0)
	testing.expect(t, !press(&c, .White))
}

@(test)
pause_stops_the_clock :: proc(t: ^testing.T) {
	c: Clock
	reset(&c, 2)
	press(&c, .Black)
	pause(&c)
	tick(&c, 30)
	testing.expect_value(t, c.left[.White], 900.0)
	pause(&c)
	tick(&c, 1)
	testing.expect_value(t, c.left[.White], 899.0)
}

@(test)
time_reads_out :: proc(t: ^testing.T) {
	h, m, s, _ := split(7200)
	testing.expect_value(t, h, 2)
	testing.expect_value(t, m, 0)
	testing.expect_value(t, s, 0)
	h, m, s, _ = split(7199.2)
	testing.expect_value(t, h, 2) // shows 2:00:00 until the second is gone
	_, _, s2, tn := split(9.37)
	testing.expect_value(t, s2, 9)
	testing.expect_value(t, tn, 3)
}
