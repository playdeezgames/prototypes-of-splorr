#+build !js
package cribbage

import "core:testing"

C :: 0
D :: 1
Hh :: 2
S :: 3

@(private = "file")
h :: proc(a, b, c, d: Card) -> [KEEP]Card {return {a, b, c, d}}

@(test)
the_best_hand_is_twenty_nine :: proc(t: ^testing.T) {
	// Three fives and the Jack of the cut's suit, with the fourth five cut.
	hand := h(make_card(5, C), make_card(5, D), make_card(5, Hh), make_card(11, S))
	c := count_hand(hand, make_card(5, S), false)
	testing.expect_value(t, c.fifteens, 16)
	testing.expect_value(t, c.pairs, 12)
	testing.expect_value(t, c.nobs, 1)
	testing.expect_value(t, total(c), 29)
}

@(test)
double_runs_and_fifteens :: proc(t: ^testing.T) {
	// 7 8 8 9 with a 6 cut: a double run of four (8), a pair (2), fifteens 7+8 twice and 6+9 (6).
	hand := h(make_card(7, C), make_card(8, D), make_card(8, Hh), make_card(9, S))
	c := count_hand(hand, make_card(6, C), false)
	testing.expect_value(t, c.runs, 8) // 6-7-8-9 twice: two runs of four
	testing.expect_value(t, c.pairs, 2)
	testing.expect_value(t, c.fifteens, 6)
	testing.expect_value(t, total(c), 16)
}

@(test)
flushes_in_hand_and_kitty :: proc(t: ^testing.T) {
	hand := h(make_card(2, Hh), make_card(4, Hh), make_card(8, Hh), make_card(12, Hh))
	testing.expect_value(t, count_hand(hand, make_card(13, C), false).flush, 4)
	testing.expect_value(t, count_hand(hand, make_card(13, Hh), false).flush, 5)
	testing.expect_value(t, count_hand(hand, make_card(13, C), true).flush, 0) // a kitty needs all five
	testing.expect_value(t, count_hand(hand, make_card(13, Hh), true).flush, 5)
}

@(test)
nineteen_is_nothing :: proc(t: ^testing.T) {
	hand := h(make_card(2, C), make_card(4, D), make_card(6, Hh), make_card(12, S))
	testing.expect_value(t, total(count_hand(hand, make_card(13, C), false)), 0)
}

@(test)
pegging_scores :: proc(t: ^testing.T) {
	five, ten := make_card(5, C), make_card(10, D)
	p := score_pile([]Card{five, ten}, 15)
	testing.expect(t, p.fifteen)
	testing.expect_value(t, peg_points(p), 2)
	// A pair royal.
	trips := []Card{make_card(4, C), make_card(4, D), make_card(4, Hh)}
	testing.expect_value(t, score_pile(trips, 12).pair, 3)
	testing.expect_value(t, peg_points(score_pile(trips, 12)), 6)
	// A run out of order: 3, 5, 4.
	run := []Card{make_card(3, C), make_card(5, D), make_card(4, Hh)}
	testing.expect_value(t, score_pile(run, 12).run, 3)
	// Not a run once a card breaks it: 3, 5, 5, 4.
	broken := []Card{make_card(3, C), make_card(5, D), make_card(5, S), make_card(4, Hh)}
	testing.expect_value(t, score_pile(broken, 17).run, 0)
	// 31.
	testing.expect(t, score_pile([]Card{make_card(10, C), make_card(10, D), make_card(10, S), make_card(1, C)}, 31).thirty_one)
}

@(test)
the_computer_keeps_the_good_cards :: proc(t: ^testing.T) {
	// 5 5 J Q plus 2 and 9: it should keep the fives and the faces.
	six := [HAND]Card{make_card(2, C), make_card(5, D), make_card(5, Hh), make_card(9, S), make_card(11, C), make_card(12, D)}
	a, b := choose_throw(six, false)
	testing.expect(t, (a == 0 && b == 3) || (a == 3 && b == 0))
}

// Plays whole games with the computer's own choices on both sides.
@(test)
whole_games_reach_121 :: proc(t: ^testing.T) {
	for seed in u64(1) ..< 60 {
		g: Game
		new_game(&g, seed)
		steps := 0
		for g.phase != .Over && steps < 20000 {
			steps += 1
			switch g.phase {
			case .Discard:
				a, b := choose_throw(g.hands[YOU], g.dealer == YOU)
				testing.expect(t, discard(&g, a, b))
			case .Peg:
				if your_play(&g) {
					// You play like the computer would.
					best := -1
					for i in 0 ..< KEEP {if legal(&g, YOU, i) {best = i}}
					testing.expect(t, play(&g, best))
				} else {
					testing.expect(t, advance(&g))
				}
				testing.expect(t, g.count <= 31)
			case .Show:
				show_next(&g)
			case .Over:
			}
		}
		testing.expect_value(t, g.phase, Phase.Over)
		testing.expect_value(t, g.scores[g.winner], WIN)
		testing.expect(t, g.scores[1 - g.winner] < WIN)
	}
}

@(test)
pegging_a_hand_through :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 77)
	g.dealer = CPU
	deal(&g)
	discard(&g, 0, 1)
	testing.expect_value(t, g.turn, YOU) // the non-dealer leads
	before := g.scores
	plays := 0
	for g.phase == .Peg {
		if your_play(&g) {
			for i in 0 ..< KEEP {
				if legal(&g, YOU, i) {
					play(&g, i)
					break
				}
			}
		} else {
			advance(&g)
		}
		plays += 1
		testing.expect(t, plays < 100)
	}
	testing.expect_value(t, g.played_n, 8)
	testing.expect(t, g.scores[0] + g.scores[1] > before[0] + before[1]) // the last card at least
	if g.phase == .Show {
		show_next(&g)
		show_next(&g)
		show_next(&g)
		if g.phase == .Show {
			show_next(&g)
			testing.expect_value(t, g.dealer, YOU) // the deal passes
			testing.expect_value(t, g.phase, Phase.Discard)
		}
	}
}
