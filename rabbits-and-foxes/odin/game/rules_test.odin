#+build !js
package rabbits

import "core:testing"

@(test)
the_balance_holds :: proc(t: ^testing.T) {
	m: Model
	reset(&m, 100, 200)
	for _ in 0 ..< 5000 {step(&m)}
	testing.expect_value(t, m.ending, Ending.None)
	testing.expect_value(t, rabbit_count(&m), 100)
	testing.expect_value(t, fox_count(&m), 200)
}

@(test)
one_step_as_in_the_listing :: proc(t: ^testing.T) {
	m: Model
	reset(&m, 300, 50)
	step(&m)
	// E = .01*300*50 = 150; C = 50 + .02*(150-50) = 52; D = 300 + .02*(600-150) = 309
	testing.expect(t, abs(m.foxes - 52) < 1e-9)
	testing.expect(t, abs(m.rabbits - 309) < 1e-9)
}

@(test)
swings_grow_until_one_side_dies :: proc(t: ^testing.T) {
	for start in ([][2]int{{300, 50}, {25, 400}, {400, 400}, {150, 150}}) {
		m: Model
		reset(&m, start[0], start[1])
		for m.ending == .None && m.steps < 200000 {step(&m)}
		testing.expectf(t, m.ending != .None, "%v never ended", start)
		testing.expect(t, m.max_r > start[0] || m.max_f > start[1])
		testing.expect(t, m.min_r <= 1 || m.min_f <= 1)
	}
}

@(test)
inputs_are_kept_in_the_listing_range :: proc(t: ^testing.T) {
	m: Model
	reset(&m, 5, 900)
	testing.expect_value(t, m.start_r, 25)
	testing.expect_value(t, m.start_f, 400)
	testing.expect_value(t, samples(&m), 1)
}
