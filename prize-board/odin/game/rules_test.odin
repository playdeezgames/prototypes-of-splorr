#+build !js
package prizeboard

import "core:log"
import "core:testing"

@(test)
prize_names_fit_a_square :: proc(t: ^testing.T) {
	for p in PRIZES {testing.expect(t, len(p.name) <= 10)}
}

@(test)
the_board_has_fifteen_pairs_and_two_wild_cards :: proc(t: ^testing.T) {
	for seed in u64(1) ..< 100 {
		g: Game
		new_game(&g, seed, false)
		counts: [len(PRIZES)]int
		for s in g.board {counts[s.prize] += 1}
		testing.expect_value(t, counts[WILD], 2)
		pairs := 0
		for c, pz in counts {
			if pz == WILD {continue}
			testing.expect(t, c == 0 || c == 2)
			if c == 2 {pairs += 1}
		}
		testing.expect_value(t, pairs, PAIRS)
		testing.expect(t, g.secret >= 1 && g.secret <= 100)
	}
}

find :: proc(g: ^Game, prize: int, not: int = -1) -> int {
	for s, i in g.board {if i != not && !s.gone && s.prize == prize {return i}}
	return -1
}

@(test)
illegal_picks_are_refused :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 3, false)
	testing.expect(t, !pick(&g, -1))
	testing.expect(t, !pick(&g, 32))
	testing.expect(t, pick(&g, 5))
	testing.expect(t, !pick(&g, 5)) // the same square twice
	testing.expect_value(t, g.phase, Phase.Second)
}

@(test)
a_miss_passes_the_turn :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 4, false)
	a := 0
	for g.board[a].prize == WILD {a += 1}
	b := 0
	for b == a || g.board[b].prize == WILD || g.board[b].prize == g.board[a].prize {b += 1}
	who := g.turn
	pick(&g, a)
	pick(&g, b)
	testing.expect_value(t, g.phase, Phase.Miss)
	cont(&g)
	testing.expect_value(t, g.turn, 1 - who)
	testing.expect(t, !g.board[a].gone)
}

@(test)
a_pair_wins_the_prize_and_a_guess_then_the_same_player_goes_again :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 5, false)
	a := 0
	for g.board[a].prize == WILD {a += 1}
	pz := g.board[a].prize
	b := find(&g, pz, a)
	who := g.turn
	pick(&g, a)
	pick(&g, b)
	testing.expect_value(t, g.phase, Phase.Match)
	testing.expect_value(t, g.prize, pz)
	cont(&g)
	testing.expect_value(t, g.phase, Phase.Guess)
	testing.expect(t, g.board[a].gone && g.board[b].gone)
	testing.expect_value(t, g.players[who].round_value, PRIZES[pz].value)
	wrong := g.secret == 100 ? 1 : 100
	testing.expect(t, guess(&g, wrong))
	testing.expect(t, (.Too_High in g.events) != (.Too_Low in g.events))
	cont(&g)
	testing.expect_value(t, g.phase, Phase.First)
	testing.expect_value(t, g.turn, who)
}

@(test)
a_wild_card_matches_anything :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 6, false)
	w := find(&g, WILD)
	a := 0
	for g.board[a].prize == WILD {a += 1}
	pick(&g, w)
	pick(&g, a)
	testing.expect_value(t, g.phase, Phase.Match)
	testing.expect_value(t, g.prize, g.board[a].prize)
	testing.expect(t, .Wild in g.events)
}

@(test)
two_wild_cards_win_a_guess_but_no_prize :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 7, false)
	w1 := find(&g, WILD)
	w2 := find(&g, WILD, w1)
	pick(&g, w1)
	pick(&g, w2)
	testing.expect_value(t, g.phase, Phase.Match)
	cont(&g)
	testing.expect_value(t, g.phase, Phase.Guess)
	testing.expect_value(t, g.players[g.turn].n_won, 0)
}

@(test)
only_the_round_winner_keeps_its_prizes :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 8, false)
	// Player to move wins a pair, guesses wrong, misses; the other wins a pair and the number.
	first := g.turn
	a := 0
	for g.board[a].prize == WILD {a += 1}
	pick(&g, a); pick(&g, find(&g, g.board[a].prize, a)); cont(&g)
	guess(&g, g.secret == 100 ? 1 : 100); cont(&g)
	x := 0
	for g.board[x].gone || g.board[x].prize == WILD {x += 1}
	y := 0
	for y == x || g.board[y].gone || g.board[y].prize == WILD || g.board[y].prize == g.board[x].prize {y += 1}
	pick(&g, x); pick(&g, y); cont(&g)
	second := g.turn
	testing.expect(t, second != first)
	b := 0
	for g.board[b].gone || g.board[b].prize == WILD {b += 1}
	pick(&g, b); pick(&g, find(&g, g.board[b].prize, b)); cont(&g)
	guess(&g, g.secret)
	testing.expect_value(t, g.phase, Phase.Round_Won)
	testing.expect_value(t, g.winner, second)
	testing.expect_value(t, g.players[first].total, 0)
	testing.expect_value(t, g.players[second].total, g.players[second].round_value)
	next_round(&g)
	testing.expect_value(t, g.round, 2)
}

@(test)
no_possible_pair_ties_the_round :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 9, false)
	// Take every square off but two different prizes.
	keep1 := 0
	for g.board[keep1].prize == WILD {keep1 += 1}
	keep2 := 0
	for keep2 == keep1 || g.board[keep2].prize == WILD || g.board[keep2].prize == g.board[keep1].prize {keep2 += 1}
	for &s, i in g.board {if i != keep1 && i != keep2 {s.gone = true}}
	testing.expect(t, !match_possible(&g))
	pick(&g, keep1); pick(&g, keep2); cont(&g)
	testing.expect_value(t, g.phase, Phase.Round_Tied)
	testing.expect_value(t, g.players[0].total + g.players[1].total, 0)
}

// Plays whole games with the computer on both seats' moves.
play_out :: proc(g: ^Game) {
	for steps := 0; g.phase != .Over && steps < 20000; steps += 1 {
		#partial switch g.phase {
		case .First, .Second:
			pick(g, cpu_pick(g))
		case .Miss, .Match, .Guessed:
			cont(g)
		case .Guess:
			guess(g, cpu_guess(g))
		case .Round_Won, .Round_Tied:
			next_round(g)
		}
	}
}

@(test)
games_end_with_a_winner :: proc(t: ^testing.T) {
	for seed in u64(1) ..< 60 {
		g: Game
		new_game(&g, seed, true, 0.7)
		play_out(&g)
		testing.expect_value(t, g.phase, Phase.Over)
		testing.expect(t, g.round >= ROUNDS)
		testing.expect(t, g.players[g.winner].total >= g.players[1 - g.winner].total)
	}
}

@(test)
a_sharper_memory_misses_less :: proc(t: ^testing.T) {
	// The computer clears boards alone (it keeps the turn after a miss); count the misses.
	misses :: proc(recall: f32) -> int {
		m := 0
		for seed in u64(1) ..< 100 {
			g: Game
			new_game(&g, seed, true, recall)
			g.turn = 1
			for steps := 0; steps < 5000 && g.phase != .Round_Tied && g.phase != .Round_Won; steps += 1 {
				#partial switch g.phase {
				case .First, .Second:
					pick(&g, cpu_pick(&g))
				case .Miss:
					m += 1
					cont(&g)
					g.turn = 1
				case .Match:
					cont(&g)
				case .Guess:
					guess(&g, g.secret == 100 ? 1 : 100) // never the number: clear the board
				case .Guessed:
					cont(&g)
				}
			}
		}
		return m
	}
	hi, lo := misses(0.95), misses(0.1)
	log.infof("misses over 99 boards: recall 0.95 %d, recall 0.1 %d", hi, lo)
	testing.expect(t, hi * 3 < lo * 2)
}

@(test)
a_tie_after_three_rounds_plays_a_rubber_round :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 11, false)
	for _ in 0 ..< ROUNDS {
		g.phase = .Round_Tied
		next_round(&g)
	}
	testing.expect(t, rubber(&g))
	testing.expect_value(t, g.phase, Phase.First)
	g.phase = .Guess
	who := g.turn
	guess(&g, g.secret)
	next_round(&g)
	testing.expect_value(t, g.phase, Phase.Over)
	testing.expect_value(t, g.winner, who)
}
