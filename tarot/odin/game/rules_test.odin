#+build !js
package tarot

import "core:testing"

@(test)
the_deck_has_seventy_eight_different_cards :: proc(t: ^testing.T) {
	majors, courts, minors := 0, 0, 0
	for i in 0 ..< CARDS {
		switch card(i).kind {
		case .Major:
			majors += 1
		case .Court:
			courts += 1
		case .Minor:
			minors += 1
		}
		a, b: [64]u8
		for j in 0 ..< CARDS {if i != j {testing.expect(t, card_name(i, a[:]) != card_name(j, b[:]))}}
	}
	testing.expect_value(t, majors, 22)
	testing.expect_value(t, courts, 16)
	testing.expect_value(t, minors, 40)
}

@(test)
every_card_has_two_meanings_that_fit_the_panel :: proc(t: ^testing.T) {
	for i in 0 ..< CARDS {
		a, b, n: [64]u8
		up := card_meaning(i, true, a[:])
		down := card_meaning(i, false, b[:])
		testing.expectf(t, len(up) > 0 && len(down) > 0 && up != down, "card %d", i)
		testing.expectf(t, len(up) <= 46 && len(down) <= 46, "card %d: %s / %s", i, up, down)
		testing.expect(t, len(card_name(i, n[:])) <= 46)
	}
}

@(test)
court_cards_follow_the_listing :: proc(t: ^testing.T) {
	buf: [64]u8
	king_scepters := MAJORS + int(Suit.Scepters) * 4 + int(Rank.King)
	testing.expect_value(t, card_meaning(king_scepters, true, buf[:]), "A MAN OF AN ARIES TEMPERAMENT")
	queen_swords := MAJORS + int(Suit.Swords) * 4 + int(Rank.Queen)
	testing.expect_value(t, card_meaning(queen_swords, true, buf[:]), "A WOMAN OF A SCORPIO TEMPERAMENT")
	testing.expect_value(t, card_meaning(queen_swords, false, buf[:]), "A MAN OF A SCORPIO TEMPERAMENT")
	youth_coins := MAJORS + int(Suit.Coins) * 4 + int(Rank.Youth)
	testing.expect_value(t, card_meaning(youth_coins, false, buf[:]), "A YOUNG WOMAN OF AN AQUARIUS TEMPERAMENT")
}

@(test)
cards_are_dealt_right_to_left_and_none_repeats :: proc(t: ^testing.T) {
	for seed in u64(1) ..< 200 {
		r: Reading
		new_reading(&r, seed)
		for i in 0 ..< SPREAD {for j in 0 ..< SPREAD {if i != j {testing.expect(t, r.cards[i] != r.cards[j])}}}
		testing.expect_value(t, deal(&r), 4)
		testing.expect(t, is_dealt(&r, 4) && !is_dealt(&r, 3))
		testing.expect_value(t, deal(&r), 3)
		deal(&r); deal(&r)
		testing.expect_value(t, r.answer, Answer.Pending)
		testing.expect_value(t, deal(&r), 0)
		testing.expect(t, r.answer != .Pending)
		testing.expect_value(t, deal(&r), -1)
		testing.expect_value(t, r.yes + r.no, 6)
	}
}

@(test)
the_key_card_counts_twice :: proc(t: ^testing.T) {
	r: Reading
	new_reading(&r, 1)
	r.upright = {true, true, false, false, false} // 2 yes, 4 no
	tally(&r)
	testing.expect_value(t, r.answer, Answer.No)
	r.upright = {true, false, true, false, false} // 3 and 3
	tally(&r)
	testing.expect_value(t, r.answer, Answer.Uncertain)
	r.upright = {true, true, true, false, false}
	tally(&r)
	testing.expect_value(t, r.answer, Answer.Yes)
}

@(test)
both_answers_come_up :: proc(t: ^testing.T) {
	seen: [Answer]int
	for seed in u64(1) ..< 300 {
		r: Reading
		new_reading(&r, seed)
		tally(&r)
		seen[r.answer] += 1
	}
	testing.expect(t, seen[.Yes] > 60 && seen[.No] > 60 && seen[.Uncertain] > 30)
}
