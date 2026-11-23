#+build !js
package slot

import "core:testing"

@(test)
a_visit_starts_with_ten :: proc(t: ^testing.T) {
	m: Machine
	new_machine(&m, 3)
	testing.expect_value(t, m.zzoopps, START)
}

@(test)
a_match_pays_five_and_a_miss_costs_one :: proc(t: ^testing.T) {
	m: Machine
	new_machine(&m, 99)
	wins, losses := 0, 0
	for _ in 0 ..< 400 {
		refill(&m)
		before := m.zzoopps
		switch spin(&m) {
		case .Win:
			wins += 1
			testing.expect(t, m.reels[0] == m.reels[1] && m.reels[1] == m.reels[2])
			testing.expect_value(t, m.zzoopps, before + WIN)
		case .Lose:
			losses += 1
			testing.expect(t, !(m.reels[0] == m.reels[1] && m.reels[1] == m.reels[2]))
			testing.expect_value(t, m.zzoopps, before - COST)
		case .None:
			testing.fail(t)
		}
	}
	// Three pictures a reel: about one spin in nine matches.
	testing.expect(t, wins > 20 && wins < 80)
	testing.expect(t, losses > 300)
}

@(test)
no_spin_when_out_then_play_again :: proc(t: ^testing.T) {
	m: Machine
	new_machine(&m, 5)
	m.zzoopps = 0
	testing.expect_value(t, spin(&m), Outcome.None)
	refill(&m)
	testing.expect_value(t, m.zzoopps, START)
}

@(test)
every_picture_comes_up :: proc(t: ^testing.T) {
	m: Machine
	new_machine(&m, 11)
	seen: bit_set[Picture]
	for _ in 0 ..< 50 {
		refill(&m)
		spin(&m)
		for r in m.reels {seen += {r}}
	}
	testing.expect(t, seen == {.Sun, .Smile, .Lollipop})
}
