#+build !js
package storybook

import "core:strings"
import "core:testing"

@(private = "file")
answers :: proc() -> Answers {
	return {
		name = "ROBIN", friend1 = "SAM", friend2 = "ALEX", pet = "GOLDFISH", color = "PURPLE",
		like = "OWL", dislike = "WOLF", age = 5, number = 7, pronoun = .They,
	}
}

@(test)
every_story_is_filled_in :: proc(t: ^testing.T) {
	a := answers()
	for seed in 1 ..= 300 {
		r := Rng{u64(seed) * 7919}
		a.pronoun = Pronoun(seed % 3)
		a.number = seed % 2 == 0 ? 1 : 12
		st: Story
		tell(&st, &a, &r)
		testing.expect_value(t, st.count, 9)
		all := strings.builder_make(context.temp_allocator)
		for i in 0 ..< st.count {
			p := &st.pages[i]
			testing.expectf(t, p.len < PAGE_TEXT, "page %d may be cut off (%d chars)", i, p.len)
			s := page_text(p)
			testing.expect(t, !strings.contains(s, "{"))
			testing.expect(t, !strings.contains(s, "}"))
			strings.write_string(&all, s)
		}
		text := strings.to_string(all)
		testing.expect(t, strings.contains(text, "ROBIN"))
		testing.expect(t, strings.contains(text, "SAM"))
		testing.expect(t, strings.contains(text, "GOLDFISH"))
		testing.expect(t, strings.contains(text, "OWL"))
		testing.expect(t, strings.contains(text, "WOLF"))
		testing.expect(t, strings.has_suffix(text, "THE END."))
		if a.number == 1 {
			testing.expect(t, strings.contains(text, strings.concatenate({"1 PURPLE ", st.treasure.one}, context.temp_allocator)))
		} else {
			testing.expect(t, strings.contains(text, strings.concatenate({"12 PURPLE ", st.treasure.many}, context.temp_allocator)))
		}
		free_all(context.temp_allocator)
	}
}

@(test)
articles_follow_the_animal :: proc(t: ^testing.T) {
	testing.expect_value(t, article("OWL"), "AN ")
	testing.expect_value(t, article("WOLF"), "A ")
}

@(test)
answers_are_cleaned :: proc(t: ^testing.T) {
	buf: [16]u8
	testing.expect_value(t, clean(buf[:], "  robin {x} ", "YOU"), "ROBIN X")
	testing.expect_value(t, clean(buf[:], "   ", "YOU"), "YOU")
	testing.expect_value(t, len(clean(buf[:], "a very long name indeed yes", "YOU")), 16)
}

@(test)
the_same_seed_tells_the_same_story :: proc(t: ^testing.T) {
	a := answers()
	r1, r2 := Rng{42}, Rng{42}
	s1, s2: Story
	tell(&s1, &a, &r1)
	tell(&s2, &a, &r2)
	for i in 0 ..< s1.count {
		testing.expect_value(t, page_text(&s1.pages[i]), page_text(&s2.pages[i]))
	}
}
