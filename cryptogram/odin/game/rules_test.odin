#+build !js
package cryptogram

import "core:testing"

@(test)
no_letter_stands_for_itself :: proc(t: ^testing.T) {
	r := Rng{12345}
	for _ in 0 ..< 200 {
		k := derangement(&r)
		seen: bit_set[0 ..< 26]
		for c, i in k {
			testing.expect(t, c != 'A' + u8(i))
			seen += {int(c - 'A')}
		}
		testing.expect_value(t, card(seen), 26)
	}
}

@(test)
punctuation_and_spaces_survive :: proc(t: ^testing.T) {
	r := Rng{7}
	pz: Puzzle
	from_plain(&pz, "DON'T PANIC, OK?", &r)
	s := text(&pz)
	testing.expect_value(t, len(s), len("DON'T PANIC, OK?"))
	testing.expect_value(t, s[3], '\'')
	testing.expect_value(t, s[5], ' ')
	testing.expect_value(t, s[11], ',')
	testing.expect_value(t, s[15], '?')
}

// Plays the right answer into the board.
@(private = "file")
solve :: proc(pz: ^Puzzle) {
	for i in 0 ..< 26 {
		if i in pz.present {assign(pz, 'A' + u8(i), pz.answer[i])}
	}
}

@(test)
every_bank_crypt_can_be_solved :: proc(t: ^testing.T) {
	r := Rng{99}
	for c in BANK {
		testing.expect(t, len(c.text) <= MAX_TEXT)
		pz: Puzzle
		from_plain(&pz, c.text, &r)
		testing.expect(t, !solved(&pz))
		solve(&pz)
		testing.expectf(t, solved(&pz), "not solved: %s", c.text)
	}
}

@(test)
refusals_match_the_original :: proc(t: ^testing.T) {
	pz: Puzzle
	from_cipher(&pz, "XYZ XY")
	testing.expect_value(t, assign(&pz, 'Q', 'A'), Result.Not_In_Crypt)
	testing.expect_value(t, assign(&pz, 'X', 'T'), Result.Ok)
	testing.expect_value(t, assign(&pz, 'Y', 'T'), Result.Already_In_Use)
	testing.expect_value(t, assign(&pz, 'X', 'H'), Result.Ok) // changing your mind is fine
	testing.expect_value(t, assign(&pz, 'Y', 'T'), Result.Ok)
	testing.expect_value(t, assign(&pz, 'Y', '3'), Result.Not_A_Letter)
	clear_all(&pz)
	testing.expect_value(t, pz.guess['X' - 'A'], 0)
	testing.expect(t, !solved(&pz)) // typed-in crypts have no answer
}

@(test)
hints_finish_a_puzzle :: proc(t: ^testing.T) {
	r := Rng{3}
	pz: Puzzle
	from_plain(&pz, BANK[0].text, &r)
	// A wrong guess that holds a true letter must be moved off by the hint.
	for i in 0 ..< 26 {
		if i in pz.present {
			assign(&pz, 'A' + u8(i), 'Z' - u8(i % 5))
			break
		}
	}
	n := 0
	for !solved(&pz) && n < 30 {
		testing.expect(t, hint(&pz, &r) != 0)
		n += 1
	}
	testing.expect(t, solved(&pz))
	testing.expect_value(t, pz.hints, n)
	testing.expect_value(t, hint(&pz, &r), 0)
}

@(test)
order_follows_first_appearance :: proc(t: ^testing.T) {
	pz: Puzzle
	from_cipher(&pz, "BAB CAB")
	l, n := order(&pz)
	testing.expect_value(t, n, 3)
	testing.expect_value(t, string(l[:n]), "BAC")
}
