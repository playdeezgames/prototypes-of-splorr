#+build !js
package safari

import "core:testing"

count_code :: proc(g: ^Game, v: int) -> int {
	n := 0
	for row in g.cell {for x in row {if x == v {n += 1}}}
	return n
}

@(test)
country_is_laid_out_as_in_the_listing :: proc(t: ^testing.T) {
	for seed in 1 ..= 40 {
		g: Game
		level := 1 + seed % 3
		new_game(&g, u64(seed) * 7919, 6, level)
		dl := 2 * level
		testing.expect_value(t, count_code(&g, HEAD_HUNTERS), 1 + dl)
		testing.expect_value(t, count_code(&g, CREWMAN_LOST), 5 + dl)
		testing.expect_value(t, count_code(&g, CAMERA_LOST), 5 + dl)
		testing.expect_value(t, count_code(&g, SCOUT_LOST), 6 + dl)
		testing.expect_value(t, count_code(&g, DISORIENTED), 6 + dl)
		testing.expect_value(t, count_code(&g, BEARER_LOST), 12 + dl)
		testing.expect_value(t, count_code(&g, SUPPLIES_LOST), 12 + dl)
		for b in 0 ..< 6 {
			pl := &g.p[b]
			testing.expect_value(t, g.cell[pl.br][pl.bc], 100 + b)
			testing.expect(t, pl.br >= 1 && pl.br <= 10 && pl.bc >= 1 && pl.bc <= 10)
			for o in 0 ..< 6 {
				if o == b {continue}
				q := &g.p[o]
				testing.expect(t, abs(q.br - pl.br) + abs(q.bc - pl.bc) > 1, "camps side by side")
			}
			testing.expect_value(t, pl.men[1], 6)
			testing.expect_value(t, pl.bearers[1], 20)
			testing.expect_value(t, pl.cameras[1], 3)
			testing.expect_value(t, pl.supplies[1], 5000)
		}
		// animals dealt in turn, 1-9
		for row in g.start {for v in row {if is_animal(v) {testing.expect(t, v % 10 == 0 && v / 10 >= 1 && v / 10 <= 9)}}}
	}
}

@(test)
outfitting_follows_the_listing :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 99, 1, 1)
	testing.expect_value(t, g.phase, Phase.Outfit)
	testing.expect(t, !outfit(&g, {}, 4, 10), "four cameras from three")
	testing.expect(t, !outfit(&g, {}, 1, 2), "fewer than three bearers")
	testing.expect(t, !outfit(&g, {}, 1, 21), "more bearers than the camp has")
	testing.expect(t, outfit(&g, {.North, .West}, 2, 12))
	pl := cur(&g)
	testing.expect_value(t, pl.men[0], 4)
	testing.expect_value(t, pl.men[1], 2)
	testing.expect_value(t, pl.cameras[0], 2)
	testing.expect_value(t, pl.film, 6)
	testing.expect_value(t, pl.supplies[0], 1200)
	testing.expect_value(t, pl.supplies[1], 3800)
	testing.expect_value(t, party_scouts(pl), 2)
	testing.expect_value(t, daily_food(2, 4, 12), 10 + 24 + 20 + 36)
	testing.expect_value(t, g.phase, Phase.Move)
}

@(test)
scouts_report_what_lies_next_door :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 5, 1, 1)
	pl := cur(&g)
	g.cell = {}
	pl.r, pl.c = 0, 5
	pl.scouts = {.North = .Party, .East = .Party, .South = .Base, .West = .Party}
	g.cell[0][6] = 30
	g.cell[0][4] = 101
	testing.expect_value(t, report(&g, pl, .North), Report.Edge)
	testing.expect_value(t, report(&g, pl, .East), Report.Animal)
	testing.expect_value(t, report(&g, pl, .South), Report.No_Scout)
	testing.expect_value(t, report(&g, pl, .West), Report.Base_Camp)
	g.cell[0][6] = SUPPLIES_LOST
	testing.expect_value(t, report(&g, pl, .East), Report.Nothing)
}

@(test)
filming_scores_by_order_and_distance :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 1234, 2, 1)
	outfit(&g, {}, 1, 10)
	pl := cur(&g)
	g.cell = {}
	pl.br, pl.bc = 2, 2
	pl.r, pl.c = 2, 4
	g.cell[2][5] = 41 // a baboon, filmed once already
	testing.expect(t, move(&g, .East))
	testing.expect_value(t, g.phase, Phase.Filming)
	testing.expect_value(t, g.film.pp, 50 + 3 * 10)
	testing.expect_value(t, g.cell[2][5], 42)
	testing.expect_value(t, pl.film, 2)
	// put the frame on the animal and snap at once
	g.film.p1, g.film.p2 = 20, 5
	g.film.a1, g.film.a2 = 31, 9
	film_snap(&g)
	testing.expect(t, g.film.hit)
	testing.expect_value(t, pl.points, 80)
	testing.expect_value(t, g.phase, Phase.Report)
	// a fourth visitor is too late
	next_turn(&g)
	testing.expect_value(t, g.turn, 1)
}

@(test)
too_late_after_three :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 77, 1, 1)
	outfit(&g, {}, 1, 10)
	pl := cur(&g)
	g.cell = {}
	pl.br, pl.bc = 6, 6
	pl.r, pl.c = 6, 6
	g.cell[6][7] = 13
	move(&g, .East)
	testing.expect_value(t, g.phase, Phase.Report)
	testing.expect_value(t, g.msgs[0].kind, Msg_Kind.Too_Late)
	testing.expect_value(t, pl.film, 3)
}

@(test)
a_day_eats_and_the_hungry_starve :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 31, 1, 1)
	outfit(&g, {.East}, 1, 3)
	pl := cur(&g)
	g.cell = {}
	pl.br, pl.bc = 0, 0
	pl.r, pl.c = 5, 5
	pl.supplies[0] = 130
	move(&g, .Stay)
	// 10 + 12 + 10 + 9 = 41: 89 left, under 100, so a bearer starves
	testing.expect_value(t, pl.supplies[0], 89)
	testing.expect_value(t, pl.bearers[0], 2)
	testing.expect_value(t, g.msgs[1].kind, Msg_Kind.Bearer_Starved)
}

@(test)
a_map_costs_a_life :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 8, 1, 1)
	outfit(&g, {.South}, 1, 5)
	pl := cur(&g)
	pl.r, pl.c = 12, 12
	move(&g, .Lost)
	testing.expect_value(t, pl.scouts[.South], Scout.Dead)
	testing.expect_value(t, g.msgs[0].kind, Msg_Kind.Map)
	testing.expect_value(t, g.msgs[0].a, 0)
	testing.expect(t, pl.shown_map)
}

@(test)
head_hunters_take_the_party :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 3, 1, 1)
	outfit(&g, {.North}, 2, 10)
	pl := cur(&g)
	g.cell = {}
	pl.br, pl.bc = 1, 1
	pl.r, pl.c = 7, 7
	g.cell[7][8] = HEAD_HUNTERS
	move(&g, .East)
	testing.expect_value(t, pl.men[0], 0)
	testing.expect_value(t, pl.film, 0)
	testing.expect_value(t, pl.scouts[.North], Scout.Dead)
	testing.expect_value(t, pl.cameras[1], 1)
}

@(test)
computer_bwanas_finish_games :: proc(t: ^testing.T) {
	total, games, zero := 0, 0, 0
	for seed in 1 ..= 60 {
		g: Game
		comp := []bool{true, true, true, true}
		n := 1 + seed % 4
		new_game(&g, u64(seed) * 104729, n, 1 + seed % 3, comp)
		steps := 0
		for g.phase != .Over && steps < 200000 {ai_act(&g); steps += 1}
		testing.expect(t, g.phase == .Over, "game did not end")
		for i in 0 ..< n {
			total += g.p[i].points
			games += 1
			if g.p[i].points == 0 {zero += 1}
		}
	}
	avg := total / games
	testing.expectf(t, avg > 150, "computer Bwanas average only %d points", avg)
	testing.expectf(t, zero * 4 < games, "%d of %d computer Bwanas scored nothing", zero, games)
}
