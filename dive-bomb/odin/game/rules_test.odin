#+build !js
package divebomb

import "core:log"
import "core:testing"

@(test)
the_ship_steams_at_half_speed_and_wraps :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 1)
	for _ in 0 ..< 20 {tick(&g)}
	testing.expect_value(t, g.ship, 10)
	g.ship = SHIP_WRAP - 1
	g.ship_half = false
	tick(&g)
	testing.expect_value(t, g.ship, 0)
}

@(test)
the_plane_dives_to_row_forty_and_no_further :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 2)
	dive(&g)
	for _ in 0 ..< 50 {tick(&g)}
	testing.expect_value(t, g.py, PLANE_LOW)
	level(&g)
	tick(&g)
	testing.expect_value(t, g.py, PLANE_LOW)
}

@(test)
no_diving_past_the_left_margin :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 3)
	g.px = DIVE_MARGIN
	dive(&g)
	tick(&g)
	testing.expect_value(t, g.py, PLANE_TOP)
}

@(test)
one_bomb_a_pass_and_only_when_low :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 4)
	testing.expect(t, !drop(&g))
	g.py = BOMB_BELOW + 1
	testing.expect(t, drop(&g))
	for g.bomb.active {tick(&g)}
	testing.expect(t, !drop(&g))
}

@(test)
a_bomb_on_the_hull_sinks_the_ship :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 5)
	g.ship = 60
	g.px, g.py = 48, PLANE_LOW
	testing.expect(t, drop(&g))
	for _ in 0 ..< 10 {tick(&g); if g.pause > 0 {break}}
	testing.expect(t, .Sunk in g.events)
	testing.expect_value(t, g.score[.Bomber], 1)
	for g.pause > 0 {tick(&g)}
	testing.expect_value(t, g.ship, 0)
	testing.expect_value(t, g.px, WIDTH - 1)
}

@(test)
a_bomb_off_the_hull_splashes :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 6)
	g.ship = 30
	g.px, g.py = 80, PLANE_LOW
	drop(&g)
	for g.bomb.active {tick(&g)}
	testing.expect(t, .Splash in g.events)
	testing.expect_value(t, g.score[.Bomber], 0)
}

@(test)
the_gun_jams_after_three_shots :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 7)
	testing.expect(t, !fire(&g)) // the ship is not yet on screen
	g.ship = 40
	for _ in 0 ..< SHELLS {
		testing.expect(t, fire(&g))
		for g.shell.active {tick(&g)}
		g.px = WIDTH - 1 // keep the plane out of the way
	}
	testing.expect(t, !fire(&g))
	testing.expect(t, .Jam in g.events)
	new_pass(&g)
	testing.expect_value(t, g.shells, SHELLS)
}

@(test)
a_shell_on_the_plane_brings_it_down :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 8)
	g.ship = 40
	g.py = PLANE_LOW
	g.px = 100
	for !shot_would_hit(&g, 0) && g.px > 0 {tick(&g)}
	testing.expect(t, fire(&g))
	for _ in 0 ..< 30 {tick(&g); if g.pause > 0 {break}}
	testing.expect(t, .Downed in g.events)
	testing.expect_value(t, g.score[.Gunner], 1)
}

@(test)
an_empty_pass_comes_round_again :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 9)
	g.py = BOMB_BELOW + 1
	drop(&g)
	for _ in 0 ..< 200 {tick(&g); if .New_Pass in g.events {break}}
	testing.expect(t, .New_Pass in g.events)
	testing.expect(t, g.bomb_left)
	testing.expect_value(t, g.py, PLANE_TOP)
}

play :: proc(seed: u64, skill_b, skill_g: int) -> Side {
	g: Game
	new_game(&g, seed, true, true, skill_b, skill_g)
	for i := 0; !g.over && i < 200000; i += 1 {tick(&g)}
	return g.winner
}

@(test)
computer_matches_finish_and_both_sides_can_win :: proc(t: ^testing.T) {
	wins: [Side]int
	for seed in u64(1) ..< 40 {wins[play(seed, 1, 1)] += 1}
	log.infof("ace vs ace: bomber %d, gunner %d", wins[.Bomber], wins[.Gunner])
	testing.expect(t, wins[.Bomber] > 3 && wins[.Gunner] > 3)
	for seed in u64(1) ..< 40 {
		g: Game
		new_game(&g, seed, true, true, 0)
		for i := 0; !g.over && i < 200000; i += 1 {tick(&g)}
		testing.expect(t, g.over)
	}
}

@(test)
an_ace_gunner_downs_more_than_a_rookie :: proc(t: ^testing.T) {
	downs :: proc(skill: int) -> int {
		n := 0
		for seed in u64(1) ..< 40 {
			g: Game
			new_game(&g, seed, true, true, 0, skill)
			for i := 0; !g.over && i < 200000; i += 1 {tick(&g)}
			n += g.score[.Gunner]
		}
		return n
	}
	r, a := downs(0), downs(1)
	log.infof("downs against a rookie bomber: rookie gunner %d, ace gunner %d", r, a)
	testing.expect(t, a > r)
}
