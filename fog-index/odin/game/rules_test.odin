#+build !js
package fogindex

import "core:log"
import "core:testing"

@(test)
syllables_of_common_words :: proc(t: ^testing.T) {
	Case :: struct {
		w: string,
		n: int,
	}
	cases := [?]Case {
		{"the", 1}, {"cat", 1}, {"make", 1}, {"jumped", 1}, {"boxes", 2}, {"wanted", 2},
		{"table", 2}, {"heaven", 2}, {"nation", 2}, {"lion", 2}, {"water", 2},
		{"liberty", 3}, {"merciful", 3}, {"computer", 3}, {"comforted", 3}, {"piano", 3},
		{"dedicated", 4}, {"persecuted", 4}, {"government", 3}, {"righteousness", 3},
		{"proposition", 4}, {"conceived", 2}, {"devotion", 3}, {"special", 2},
		{"unalienable", 5}, {"accordingly", 4}, {"magazine", 3}, {"Sermon", 2}, {"1979", 1},
	}
	wrong := 0
	for c in cases {
		got := syllables(c.w)
		if got != c.n {
			log.infof("%s: %d, not %d", c.w, got, c.n)
			wrong += 1
		}
	}
	// An estimate, as any syllable count by rule is; it must be right on nearly all of these.
	testing.expect(t, wrong <= 2)
	// The ones the index turns on (three or more) are never short words.
	for w in ([]string{"a", "I", "it", "is", "and", "with", "through", "strength"}) {
		testing.expect(t, !is_hard(w))
	}
}

@(test)
sentences_and_words_are_counted :: proc(t: ^testing.T) {
	a: Analysis
	analyse(&a, "The cat sat. Did it? Yes! It cost 3.5 dollars, said George B. Blank of Milford")
	testing.expect_value(t, a.count, 4)
	testing.expect_value(t, a.sentences[0].words, 3)
	testing.expect_value(t, a.sentences[1].words, 2)
	testing.expect_value(t, a.sentences[2].words, 1)
	testing.expect_value(t, a.sentences[3].words, 10) // 3.5 is one word; B. is an initial
	testing.expect_value(t, a.words, 16)
	analyse(&a, "")
	testing.expect_value(t, a.count, 0)
	testing.expect_value(t, gunning(&a), 0)
	analyse(&a, "   ...  !!  ")
	testing.expect_value(t, a.count, 0)
}

@(test)
the_listing_formula :: proc(t: ^testing.T) {
	// Five sentences of 20 words with 2 long words each: 0.4 * (110) / 5 = 8.8, printed 8.
	w := [5]int{20, 20, 20, 20, 20}
	h := [5]int{2, 2, 2, 2, 2}
	testing.expect_value(t, listing_index(w[:], h[:]), 8)
	w2 := [5]int{30, 25, 28, 32, 35}
	h2 := [5]int{6, 5, 7, 8, 9}
	testing.expect_value(t, listing_index(w2[:], h2[:]), 14) // 0.4 * 185 / 5 = 14.8
	testing.expect_value(t, listing_index(nil, nil), 0)
}

@(test)
the_acid_test_is_never_easier_than_the_general_test :: proc(t: ^testing.T) {
	a: Analysis
	for s in SAMPLES {
		analyse(&a, s.text)
		testing.expect(t, a.count >= TEST_SENTENCES)
		g, gn := general_test(&a)
		picks: [TEST_SENTENCES]int
		x, xn := acid_test(&a, &picks)
		testing.expect_value(t, gn, TEST_SENTENCES)
		testing.expect_value(t, xn, TEST_SENTENCES)
		testing.expect(t, x >= g)
		for p, i in picks {for q, j in picks {if i != j {testing.expect(t, p != q)}}}
		log.infof("%s: %d sentences, general %d, acid %d, Gunning %.1f", s.name, a.count, g, x, gunning(&a))
	}
}

@(test)
the_samples_rank_as_expected :: proc(t: ^testing.T) {
	// The Sermon on the Mount reads easiest, the Declaration hardest.
	a: Analysis
	idx: [len(SAMPLES)]f64
	for s, i in SAMPLES {
		analyse(&a, s.text)
		idx[i] = gunning(&a)
	}
	testing.expect(t, idx[0] < idx[1] && idx[1] < idx[2])
	testing.expect(t, idx[0] < 12)
	testing.expect(t, idx[2] > 17)
	for s in SAMPLES {testing.expect(t, len(s.name) <= 26)}
}

@(test)
grade_names_fit :: proc(t: ^testing.T) {
	for i in 0 ..= 30 {testing.expect(t, len(grade_name(i)) <= 22)}
	for l in LEVELS {testing.expect(t, len(l.name) + len(l.note) <= 44)}
}
