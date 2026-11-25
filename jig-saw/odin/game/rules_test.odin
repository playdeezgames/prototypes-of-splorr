#+build !js
package jigsaw

import "core:testing"

// The cells normalised to the top-left corner, sorted, as a bit mask on a 4x4 grid.
mask_of :: proc(cells: []Cell) -> u16 {
	mx, my := 99, 99
	for c in cells {mx = min(mx, c.x); my = min(my, c.y)}
	m: u16
	for c in cells {m |= 1 << u16((c.y - my) * 4 + (c.x - mx))}
	return m
}

// Every turn and flip of a shape.
same_shape :: proc(a: []Cell, shape: int) -> bool {
	want := mask_of(a)
	base := SHAPE_CELLS[shape]
	for flip in 0 ..< 2 {
		for rot in 0 ..< 4 {
			cs: [4]Cell
			for c, i in base {
				p := c
				if flip == 1 {p.x = -p.x}
				for _ in 0 ..< rot {p = {-p.y, p.x}}
				cs[i] = p
			}
			if mask_of(cs[:len(base)]) == want {return true}
		}
	}
	return false
}

@(test)
every_layout_is_made_of_whole_pieces :: proc(t: ^testing.T) {
	for l, li in LAYOUTS {
		for s in 2 ..= SHAPES {
			cells: [16]Cell
			n := 0
			for v, i in l {if int(v) == s {cells[n] = {i % 4, i / 4}; n += 1}}
			if n == 0 {continue}
			ok := n == len(SHAPE_CELLS[s]) && same_shape(cells[:n], s)
			testing.expectf(t, ok, "layout %d shape %d", li, s)
		}
		for v in l {testing.expect(t, v >= 1 && v <= 6)}
	}
}

@(test)
no_two_layouts_are_the_same :: proc(t: ^testing.T) {
	for a, i in LAYOUTS {for b, j in LAYOUTS {if i < j {testing.expect(t, a != b)}}}
}

@(test)
a_right_square_places_the_whole_piece :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 3, 1, 0) // 5,5,6,6 / 5,6,6,3 / 5,4,2,3 / 4,4,2,3
	for g.named != 6 {g.placed = {}; name_next(&g)}
	testing.expect(t, try_square(&g, 5))
	testing.expect(t, .Fit in g.events)
	testing.expect(t, g.placed[2] && g.placed[3] && g.placed[5] && g.placed[6])
	testing.expect(t, !g.placed[0])
	testing.expect_value(t, g.tries, 1)
}

@(test)
a_wrong_square_is_marked_and_cannot_be_tried_twice :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 4, 1, 0)
	for g.named != 2 {name_next(&g)}
	testing.expect(t, try_square(&g, 0))
	testing.expect(t, .Miss in g.events)
	testing.expect(t, g.tried[0])
	testing.expect(t, !try_square(&g, 0))
	testing.expect_value(t, g.tries, 1)
	testing.expect(t, !try_square(&g, 16))
}

@(test)
a_single_square_goes_in_alone :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 5, 1, 20) // 1,5,5,1 / 3,1,5,2 / 3,4,5,2 / 3,4,4,1
	for g.named != 1 {name_next(&g)}
	testing.expect(t, try_square(&g, 3))
	n := 0
	for p in g.placed {if p {n += 1}}
	testing.expect_value(t, n, 1)
}

// Always names a right square: the fewest tries.
@(test)
a_perfect_game_takes_one_try_a_piece :: proc(t: ^testing.T) {
	for l in 0 ..< len(LAYOUTS) {
		g: Game
		new_game(&g, u64(l + 9), 1, l)
		want := pieces(&g)
		for !g.done {
			for i in 0 ..< SQUARES {
				if !g.placed[i] && int(g.shape[i]) == g.named {try_square(&g, i); break}
			}
		}
		testing.expect_value(t, g.tries, want)
		testing.expect(t, want >= 5)
		testing.expect_value(t, rating(g.tries).title, want <= 7 ? "GENIUS" : "EXPERT")
	}
}

@(test)
two_players_take_turns_and_score_squares :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 6, 2, 0)
	first := g.turn
	wrong := 0
	for int(g.shape[wrong]) == g.named {wrong += 1}
	try_square(&g, wrong)
	testing.expect(t, g.turn != first)
	for i in 0 ..< SQUARES {if int(g.shape[i]) == g.named {try_square(&g, i); break}}
	testing.expect(t, g.score[1 - first] >= 2)
	testing.expect_value(t, g.score[first], 0)
	for !g.done {
		for i in 0 ..< SQUARES {if !g.placed[i] && !g.tried[i] {try_square(&g, i); break}}
	}
	testing.expect_value(t, g.score[0] + g.score[1], SQUARES)
}

@(test)
ratings_follow_the_article :: proc(t: ^testing.T) {
	testing.expect_value(t, rating(5).title, "GENIUS")
	testing.expect_value(t, rating(8).title, "EXPERT")
	testing.expect_value(t, rating(15).title, "GOOD")
	testing.expect_value(t, rating(20).title, "FAIR")
	testing.expect_value(t, rating(21).title, "TRY AGAIN")
}

@(test)
rating_lines_fit_beside_the_board :: proc(t: ^testing.T) {
	for r in RATINGS {testing.expect(t, len(r.line) <= 23)}
}
