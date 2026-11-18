#+build !js
package gunnery

import "core:testing"

@(test)
batteries_are_spread_out_and_raiders_start_clear :: proc(t: ^testing.T) {
	for seed in u64(1) ..< 30 {
		g: Game
		new_game(&g, seed)
		for a, i in g.batteries {
			testing.expect(t, a.x >= 2 && a.x <= COLS - 3 && a.y >= 1 && a.y <= ROWS - 2)
			for b, j in g.batteries {
				if i != j {testing.expect(t, !(abs(a.x - b.x) <= 3 && abs(a.y - b.y) <= 1))}
			}
		}
		testing.expect_value(t, card(locked(&g)), 0)
	}
}

@(test)
raiders_step_one_cell_and_stay_on_the_grid :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 9)
	for _ in 0 ..< 2000 {
		before := g.raiders
		move_raiders(&g)
		for r, i in g.raiders {
			testing.expect(t, valid(r))
			testing.expect(t, abs(r.x - before[i].x) <= 1 && abs(r.y - before[i].y) <= 1)
		}
	}
}

@(test)
a_lined_up_raider_is_destroyed :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 4)
	g.raiders[1] = g.batteries[3]
	testing.expect_value(t, fire(&g), 1)
	testing.expect_value(t, g.kills, 1)
	testing.expect_value(t, g.shots, SHOTS - 1)
	testing.expect(t, g.raiders[1] != g.batteries[3])
	testing.expect_value(t, fire(&g), 0) // nothing lined up now: a wasted shot
	testing.expect(t, .Miss in g.events)
}

@(test)
two_at_once_count_twice :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 4)
	g.raiders[0] = g.batteries[0]
	g.raiders[2] = g.batteries[5]
	testing.expect_value(t, fire(&g), 2)
}

@(test)
twenty_one_shots_then_a_rank :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 2)
	for _ in 0 ..< SHOTS {fire(&g)}
	testing.expect(t, g.over)
	testing.expect_value(t, fire(&g), 0)
	testing.expect_value(t, rank(4), Rank.School)
	testing.expect_value(t, rank(5), Rank.Demoted)
	testing.expect_value(t, rank(10), Rank.Good)
	testing.expect_value(t, rank(11), Rank.Promoted)
}

@(test)
raiders_speed_up_with_kills :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 2)
	a := step_time(&g)
	g.kills = 6
	testing.expect(t, step_time(&g) < a)
	g.kills = 100
	testing.expect_value(t, step_time(&g), f32(STEP_MIN))
}
