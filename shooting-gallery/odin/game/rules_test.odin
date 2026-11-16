#+build !js
package gallery

import "core:testing"

// Aims at the middle of the first fully visible live target in row i.
@(private = "file")
aim_at_row :: proc(g: ^Game, i: int) -> bool {
	def := ROWS[i]
	for s in 0 ..< g.rows[i].slots {
		x := slot_x(g, i, s)
		if g.rows[i].alive[s] && x >= 8 && x + f32(def.w) <= W - 8 {
			aim(g, x + f32(def.w) / 2, f32(def.y + def.h / 2))
			return true
		}
	}
	return false
}

@(test)
hitting_each_row_scores_its_points :: proc(t: ^testing.T) {
	for def, i in ROWS {
		g: Game
		new_game(&g, 7)
		testing.expect(t, aim_at_row(&g, i))
		testing.expect_value(t, fire(&g), POINTS[def.kind])
		testing.expect_value(t, g.score, POINTS[def.kind])
		testing.expect_value(t, g.shots, SHOTS - 1)
	}
}

@(test)
a_hit_leaves_a_gap :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 7)
	aim_at_row(&g, 0)
	testing.expect(t, fire(&g) > 0)
	testing.expect_value(t, fire(&g), 0) // same spot, same instant: the target is gone
	testing.expect(t, .Miss in g.events)
}

@(test)
an_empty_spot_costs_a_shot :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 7)
	aim(&g, 100, f32(ARROW_LANES[1]) - 10) // between rows
	testing.expect_value(t, fire(&g), 0)
	testing.expect_value(t, g.shots, SHOTS - 1)
}

@(test)
gaps_refill_when_the_row_wraps :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 7)
	for s in 0 ..< g.rows[0].slots {g.rows[0].alive[s] = false}
	// Long enough for every star slot to go round once.
	for _ in 0 ..< 600 {update(&g, 1.0 / 60)}
	alive := 0
	for s in 0 ..< g.rows[0].slots {if g.rows[0].alive[s] {alive += 1}}
	testing.expect_value(t, alive, g.rows[0].slots)
}

@(test)
twenty_shots_then_over :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 7)
	for _ in 0 ..< SHOTS {fire(&g)}
	testing.expect(t, g.over)
	testing.expect_value(t, fire(&g), 0)
	testing.expect_value(t, g.shots, 0)
}

@(test)
the_arrow_flies_and_pays_100 :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 99)
	seen := false
	for _ in 0 ..< 60 * 120 {
		update(&g, 1.0 / 60)
		if g.arrow.active && g.arrow.x > 100 {
			seen = true
			break
		}
	}
	testing.expect(t, seen)
	aim(&g, g.arrow.x + ARROW_W / 2, f32(ARROW_LANES[g.arrow.lane] + 2))
	testing.expect_value(t, fire(&g), 100)
	testing.expect(t, !g.arrow.active)
}

@(test)
sight_stays_in_the_gallery :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 1)
	aim(&g, -50, 999)
	testing.expect_value(t, g.sx, 4)
	testing.expect_value(t, g.sy, SIGHT_BOTTOM)
	nudge(&g, 0, -1, 10)
	testing.expect_value(t, g.sy, SIGHT_TOP)
}
