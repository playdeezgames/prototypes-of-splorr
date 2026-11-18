#+build !js
package pillbox

import "core:testing"

@(private = "file")
fly :: proc(g: ^Game) {
	for i := 0; i < 4000 && g.shell.state == .Flying; i += 1 {update(g, SIM_DT)}
}

@(test)
fields_have_a_mountain_between_level_pads :: proc(t: ^testing.T) {
	for seed in u64(1) ..< 40 {
		g: Game
		new_game(&g, seed, false)
		l, r := g.gunners[0], g.gunners[1]
		testing.expect(t, l.x < W / 3 && r.x > 2 * W / 3)
		testing.expect_value(t, g.ground[l.x], l.y)
		testing.expect_value(t, g.ground[r.x], r.y)
		peak := H
		for x in l.x ..< r.x {peak = min(peak, g.ground[x])}
		testing.expect(t, peak < min(l.y, r.y) - 10)
	}
}

@(test)
a_flat_shot_lands_short_of_the_mountain :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 3, false)
	g.turn = 0
	set_aim(&g, 0, VEL_MIN)
	testing.expect(t, fire(&g))
	fly(&g)
	testing.expect_value(t, g.shell.state, Shell_State.Landed)
	testing.expect_value(t, g.turn, 1) // the other side's turn now
	testing.expect_value(t, g.gunners[0].hits, 0)
}

@(test)
aim_is_clamped :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 3, false)
	set_aim(&g, 120, 5000)
	testing.expect_value(t, g.gunners[g.turn].angle, ANGLE_MAX)
	testing.expect_value(t, g.gunners[g.turn].velocity, VEL_MAX)
	set_aim(&g, -5, 0)
	testing.expect_value(t, g.gunners[g.turn].angle, ANGLE_MIN)
	testing.expect_value(t, g.gunners[g.turn].velocity, VEL_MIN)
}

// Every field has a firing solution, and the computer finds one by its third or so shot.
@(test)
the_computer_finds_the_range :: proc(t: ^testing.T) {
	for seed in u64(1) ..< 25 {
		g: Game
		new_game(&g, seed, true)
		hit := false
		for shot in 0 ..< 8 {
			g.turn = 1
			cpu_aim(&g)
			fire(&g)
			fly(&g)
			if g.shell.state == .Hit_Enemy {
				hit = true
				break
			}
			_ = shot
		}
		testing.expectf(t, hit, "seed %d: no hit in eight shots", seed)
	}
}

@(test)
five_hits_win_the_war :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 11, true)
	for g.winner < 0 {
		side := g.turn
		g.gunners[side].cpu = true
		cpu_aim(&g)
		fire(&g)
		fly(&g)
		if g.shell.state == .Hit_Enemy || g.shell.state == .Hit_Self {after_hit(&g)}
		testing.expect(t, g.gunners[0].hits <= HITS_TO_WIN && g.gunners[1].hits <= HITS_TO_WIN)
	}
	testing.expect_value(t, g.gunners[g.winner].hits, HITS_TO_WIN)
	testing.expect(t, !fire(&g)) // the war is over
}

@(test)
the_side_that_was_hit_fires_first_on_the_new_field :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 5, true)
	g.turn = 1
	for g.shell.state != .Hit_Enemy {
		g.turn = 1
		cpu_aim(&g)
		fire(&g)
		fly(&g)
	}
	after_hit(&g)
	testing.expect_value(t, g.turn, 0)
	testing.expect_value(t, g.gunners[1].hits, 1)
	testing.expect_value(t, g.shell.state, Shell_State.None)
}
