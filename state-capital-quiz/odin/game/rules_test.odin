#+build !js
package capitals

import "core:testing"

@(test)
every_question_has_one_right_choice_and_no_repeats :: proc(t: ^testing.T) {
	for seed in u64(1) ..< 200 {
		g: Game
		new_game(&g, seed, .Capital_To_State)
		n := 0
		for c, k in g.choices {
			if c == g.current {n += 1}
			for d, j in g.choices {if j != k {testing.expect(t, c != d)}}
		}
		testing.expect_value(t, n, 1)
	}
}

@(test)
a_clean_round_answers_all_fifty :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 5, .State_To_Capital)
	seen: [50]bool
	for !g.over {
		seen[g.current] = true
		testing.expect(t, answer(&g, correct_choice(&g)))
		next(&g)
	}
	for s in seen {testing.expect(t, s)}
	testing.expect_value(t, g.right, 50)
	testing.expect_value(t, g.lives, LIVES)
	testing.expect(t, .Swept in g.events)
	testing.expect(t, g.score >= 50 * POINTS + LIVES * SWEEP_BONUS)
}

@(test)
a_miss_costs_a_life_and_comes_back :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 8, .Capital_To_State)
	missed := g.current
	wrong := (correct_choice(&g) + 1) % CHOICES
	answer(&g, wrong)
	testing.expect_value(t, g.lives, LIVES - 1)
	testing.expect_value(t, g.streak, 0)
	testing.expect_value(t, g.deck_len, 50)
	found := false
	for i in 1 ..< 10 {if g.deck[i] == missed {found = true}}
	testing.expect(t, found)
	testing.expect(t, g.deck[0] != missed)
}

@(test)
the_clock_runs_out :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 8, .Capital_To_State)
	update(&g, TIME_LIMIT + 1)
	testing.expect(t, g.answered)
	testing.expect_value(t, g.picked, -1)
	testing.expect(t, .Timeout in g.events)
	testing.expect_value(t, g.lives, LIVES - 1)
}

@(test)
three_misses_end_the_round :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 3, .Capital_To_State)
	for _ in 0 ..< LIVES {
		answer(&g, (correct_choice(&g) + 1) % CHOICES)
		next(&g)
	}
	testing.expect(t, g.over)
	testing.expect(t, !answer(&g, 0))
}

@(test)
streaks_multiply :: proc(t: ^testing.T) {
	testing.expect_value(t, multiplier(1), 1)
	testing.expect_value(t, multiplier(5), 2)
	testing.expect_value(t, multiplier(10), 3)
	testing.expect_value(t, multiplier(99), MAX_MULT)
	g: Game
	new_game(&g, 3, .Capital_To_State)
	answer(&g, correct_choice(&g))
	testing.expect_value(t, g.last_gain, POINTS + int(TIME_LIMIT) * TIME_BONUS)
}
