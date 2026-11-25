#+build !js
package elements

import "core:testing"

@(test)
the_table_is_whole_and_symbols_are_unique :: proc(t: ^testing.T) {
	for a, i in ELEMENTS {
		testing.expect(t, len(a.name) > 0 && len(a.name) <= 13)
		testing.expect(t, len(a.symbol) >= 1 && len(a.symbol) <= 2)
		testing.expect(t, len(a.weight) > 0 && len(a.weight) <= 7)
		for b, j in ELEMENTS {
			if i != j {
				testing.expect(t, a.symbol != b.symbol)
				testing.expect(t, a.name != b.name)
			}
		}
	}
	testing.expect_value(t, element(26).symbol, "FE")
	testing.expect_value(t, element(79).name, "GOLD")
	testing.expect_value(t, element(118).symbol, "OG")
}

@(test)
levels_take_in_the_easier_ones :: proc(t: ^testing.T) {
	testing.expect_value(t, level_size(.Easy), len(EASY))
	testing.expect(t, level_size(.Difficult) > level_size(.Easy))
	testing.expect_value(t, level_size(.Impossible), 118)
}

@(test)
every_table_place_is_used_once :: proc(t: ^testing.T) {
	used: [18 * 9]bool
	for n in 1 ..= 118 {
		c, r := table_place(n)
		testing.expect(t, c >= 0 && c < 18 && r >= 0 && r < 9)
		testing.expect(t, !used[r * 18 + c])
		used[r * 18 + c] = true
	}
	c, r := table_place(26) // iron: group 8, period 4
	testing.expect(t, c == 7 && r == 3)
	c, r = table_place(80) // mercury: group 12, period 6
	testing.expect(t, c == 11 && r == 5)
}

@(test)
every_question_has_one_right_choice_and_no_repeats :: proc(t: ^testing.T) {
	for m in Mode {
		for l in Level {
			for seed in u64(1) ..< 60 {
				g: Game
				new_game(&g, seed, l, m)
				n := 0
				for c, k in g.choices {
					if c == g.current {n += 1}
					if m != .Name_To_Number {testing.expect(t, level_of(c) <= l)}
					for d, j in g.choices {if j != k {testing.expect(t, c != d)}}
				}
				testing.expect_value(t, n, 1)
			}
		}
	}
}

@(test)
a_clean_round_answers_the_whole_level :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 5, .Difficult, .Symbol_To_Name)
	seen: [119]bool
	for !g.over {
		seen[g.current] = true
		testing.expect(t, answer(&g, correct_choice(&g)))
		next(&g)
	}
	n := 0
	for s in seen {if s {n += 1}}
	testing.expect_value(t, n, level_size(.Difficult))
	testing.expect_value(t, g.right, level_size(.Difficult))
	testing.expect(t, .Swept in g.events)
}

@(test)
a_miss_costs_a_flask_and_comes_back :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 8, .Easy, .Name_To_Number)
	cur := g.current
	wrong := (correct_choice(&g) + 1) % CHOICES
	answer(&g, wrong)
	testing.expect_value(t, g.lives, LIVES - 1)
	testing.expect(t, .Wrong in g.events)
	back := false
	for i in 0 ..< g.deck_len {if g.deck[i] == cur {back = true}}
	testing.expect(t, back)
	next(&g)
	testing.expect(t, g.current != cur)
}

@(test)
the_clock_runs_out :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 9, .Impossible, .Number_To_Name)
	update(&g, TIME_LIMIT + 1)
	testing.expect(t, g.answered)
	testing.expect(t, .Timeout in g.events)
	testing.expect_value(t, g.lives, LIVES - 1)
}

@(test)
three_misses_end_the_round :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 10, .Easy, .Name_To_Symbol)
	for _ in 0 ..< LIVES {
		answer(&g, (correct_choice(&g) + 1) % CHOICES)
		next(&g)
	}
	testing.expect(t, g.over)
	testing.expect(t, .Swept not_in g.events)
}
