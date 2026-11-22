#+build !js
package spellingbee

import "core:testing"

spell :: proc(g: ^Game, s: string) {
	for i in 0 ..< len(s) {type_letter(g, s[i])}
	submit(g)
}

@(test)
the_listings_words_come_first :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 7, .Hive)
	testing.expect_value(t, g.phase, Phase.Look)
	found := false
	for w in LISTING_WORDS {if w == g.word {found = true}}
	testing.expect(t, found)
	update(&g, 3)
	testing.expect_value(t, g.phase, Phase.Spell)
}

@(test)
right_and_wrong :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 7, .Hive)
	ready(&g)
	spell(&g, g.word)
	testing.expect(t, g.was_right)
	testing.expect(t, g.score > 0)
	next(&g)
	ready(&g)
	missed := g.word
	spell(&g, "XQZ")
	testing.expect(t, !g.was_right)
	testing.expect_value(t, g.lives, LIVES - 1)
	testing.expect_value(t, g.streak, 0)
	// It comes back within a few words.
	back := false
	for _ in 0 ..< 6 {
		next(&g)
		if g.word == missed {back = true}
		ready(&g)
		spell(&g, g.word)
	}
	testing.expect(t, back)
}

@(test)
lower_case_counts :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 3, .Hive)
	buf: [16]u8
	for i in 0 ..< len(g.word) {buf[i] = g.word[i] + 32}
	spell(&g, string(buf[:len(g.word)]))
	testing.expect(t, g.was_right)
}

@(test)
climbing_the_ladder :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 11, .Hive)
	first_look := g.look
	for _ in 0 ..< UP_EVERY {
		spell(&g, g.word)
		next(&g)
	}
	testing.expect_value(t, g.rung, 1)
	testing.expect(t, g.look < first_look)
	testing.expect_value(t, len(g.word), 4) // after the listing's words come four letters
	for _ in 0 ..< 200 {
		spell(&g, g.word)
		next(&g)
	}
	testing.expect_value(t, g.rung, RUNG_COUNT - 1)
	testing.expect_value(t, look_time(&g), 1.0)
}

@(test)
three_bees_and_out :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 5, .Hive)
	for _ in 0 ..< LIVES {
		spell(&g, "WRONG")
		next(&g)
	}
	testing.expect_value(t, g.phase, Phase.Over)
}

@(test)
practice_is_ten_words :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 9, .Practice)
	for i in 0 ..< PRACTICE_WORDS {
		if i % 2 == 0 {spell(&g, g.word)} else {spell(&g, "NOPE")}
		next(&g)
	}
	testing.expect_value(t, g.phase, Phase.Over)
	testing.expect_value(t, g.right, 5)
	testing.expect_value(t, g.wrong, 5)
	testing.expect_value(t, g.lives, LIVES) // no lives lost in practice
}
