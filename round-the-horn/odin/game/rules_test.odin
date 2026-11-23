#+build !js
package horn

import "core:fmt"
import "core:testing"

@(test)
the_map_has_the_ports_and_the_passage :: proc(t: ^testing.T) {
	testing.expect(t, ground(START_H, START_V) == .Sea) // New York
	testing.expect(t, ground(17.5, 2.5) == .Sea) // San Francisco
	testing.expect(t, at_port(17.5, 2.5))
	testing.expect(t, ground(35, 7.5) == .Land) // Brazil
	testing.expect(t, ground(25, 1.5) == .Land) // the plains
	testing.expect(t, ground(34, 11.8) == .Land) // Cape Horn
	testing.expect(t, ground(34, 12.5) == .Sea) // the passage south of it
	testing.expect(t, ground(34, 13.2) == .Ice)
	testing.expect(t, ground(-1, 5) == .Land) // off the map
	testing.expect(t, ground(28.5, 5.9) == .Land) // no canal at Panama
}

@(test)
every_waypoint_is_at_sea :: proc(t: ^testing.T) {
	for p in WAYPOINTS {testing.expectf(t, !is_land(p[0], p[1]), "%v", p)}
}

@(test)
never_closer_than_two_points :: proc(t: ^testing.T) {
	for wind in 0 ..< 16 {
		for want in 0 ..< 16 {
			h := fix_heading(want, wind)
			testing.expect(t, off_wind(h, wind) >= 2)
			if off_wind(want, wind) >= 2 {testing.expect_value(t, h, want)}
		}
	}
	testing.expect_value(t, fix_heading(0, 0), 2) // head to wind: pushed off to NE
	testing.expect_value(t, fix_heading(15, 0), 14) // NNW into a north wind: NW
	testing.expect(t, port_tack(4, 0)) // east in a north wind: wind over the port side
	testing.expect(t, !port_tack(12, 0))
	testing.expect_value(t, point_of_sail(8, 0), Point_Of_Sail.Running)
	testing.expect_value(t, point_of_sail(4, 0), Point_Of_Sail.Reach)
	testing.expect_value(t, point_of_sail(2, 0), Point_Of_Sail.Close_Hauled)
}

@(test)
latitude_and_longitude :: proc(t: ^testing.T) {
	testing.expect(t, abs(latitude(START_V) - 40.18) < 0.01)
	testing.expect(t, abs(longitude(START_H) - 69) < 0.01)
	testing.expect(t, latitude(12.03) < -55)
}

@(test)
a_running_ship_makes_way :: proc(t: ^testing.T) {
	s := Ship{h = 45, v = 3.5, want = 8, wx = {pressure = 29.5, knots = 16, dir = 0}}
	r: u64 = 7
	step_ship(&s, &r)
	testing.expect(t, s.v > 3.5 + 0.15) // south before a north wind
	testing.expect_value(t, s.half_days, 1)
}

@(test)
a_lee_shore_wrecks :: proc(t: ^testing.T) {
	s := Ship{h = 44.2, v = 7.5, want = 12, wx = {pressure = 29.5, knots = 20, dir = 4}}
	r: u64 = 9
	e: Event
	for _ in 0 ..< 10 {
		e = step_ship(&s, &r)
		if e != .None {break}
	}
	testing.expect_value(t, e, Event.Wrecked)
}

@(test)
weeks_go_round_the_ships :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 2, {}, 5)
	begin_week(&g)
	for step(&g) == .None {}
	end_week(&g)
	testing.expect_value(t, g.current, 1)
	testing.expect_value(t, g.round, 0)
	begin_week(&g)
	for step(&g) == .None {}
	end_week(&g)
	testing.expect_value(t, g.current, 0)
	testing.expect_value(t, g.round, 1)
	testing.expect_value(t, g.ships[0].half_days, STEPS_PER_WEEK)
}

@(test)
the_computer_captains_make_the_passage :: proc(t: ^testing.T) {
	arrived, total_days := 0, 0
	races := 8
	for seed in 0 ..< races {
		g: Game
		new_game(&g, 3, {true, true, true}, u64(seed * 31 + 7))
		for weeks := 0; !g.over && weeks < 3 * 60; weeks += 1 {
			begin_week(&g)
			for {
				e := step(&g)
				if e != .None {break}
			}
			end_week(&g)
		}
		testing.expect(t, g.over)
		for i in 0 ..< g.n {
			s := &g.ships[i]
			if s.status == .Arrived {
				arrived += 1
				total_days += s.half_days / 2
			} else {
				fmt.printfln("seed %d ship %d %v at %.2f,%.2f after %d days", seed, i, s.status, s.h, s.v, s.half_days / 2)
			}
		}
	}
	testing.expectf(t, arrived >= races * 3 - 1, "%d of %d arrived", arrived, races * 3)
	avg := total_days / max(arrived, 1)
	fmt.printfln("computer captains: %d of %d arrived, %d days on average", arrived, races * 3, avg)
	testing.expectf(t, avg > 70 && avg < 200, "average %d days", avg)
}
