#+build !js
package trolls

import "core:log"
import "core:testing"

@(test)
doors_join_neighbours_only :: proc(t: ^testing.T) {
	seen: [DOORS]bool
	for a in 0 ..< ROOMS {
		for d in Dir {
			if d == .Stay {continue}
			b, ok := neighbour(a, d)
			if !ok {continue}
			door, dok := door_between(a, b)
			testing.expect(t, dok)
			testing.expect(t, door >= 0 && door < DOORS)
			back, _ := door_between(b, a)
			testing.expect_value(t, back, door)
			seen[door] = true
		}
	}
	for s in seen {testing.expect(t, s)}
	_, ok := door_between(5, 6) // end of one row, start of the next: not neighbours
	testing.expect(t, !ok)
	_, ok = neighbour(5, .Right)
	testing.expect(t, !ok)
	_, ok = neighbour(0, .Up)
	testing.expect(t, !ok)
}

@(test)
a_fresh_set_of_doors_each_turn :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 7)
	n := 0
	for o in g.open {if o {n += 1}}
	testing.expect_value(t, n, OPEN_PER_TURN)
	before := g.open
	shuffle_doors(&g)
	testing.expect(t, before != g.open)
}

@(test)
a_shut_door_costs_nothing :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 3)
	g.open = {}
	testing.expect(t, !take_turn(&g, .Right))
	testing.expect(t, .Blocked in g.events)
	testing.expect_value(t, g.turns, 0)
	testing.expect_value(t, g.player, ENTRANCE)
	testing.expect(t, take_turn(&g, .Stay))
	testing.expect_value(t, g.turns, 1)
}

@(test)
the_troll_steps_toward_you_through_open_doors :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 3)
	g.turns = 1 // not a resting turn
	g.open = {}
	g.player = 0
	g.troll = 14 // row 2, column 2
	troll_turn(&g)
	testing.expect_value(t, g.troll, 14) // every door shut: it waits
	up, _ := door_between(14, 8)
	left, _ := door_between(8, 7)
	g.open[up] = true
	g.open[left] = true
	troll_turn(&g)
	testing.expect_value(t, g.troll, 8) // one step: up toward yer row (the gaps are equal)
	testing.expect_value(t, g.troll_steps, 1)
	g.open = {}
	g.open[left] = true
	g.troll = 8
	g.player = 6
	troll_turn(&g)
	testing.expect_value(t, g.troll, 7) // same row now: across
	g.troll = 13 // the longer gap is across, but that door is shut: it tries the other way
	g.player = 1
	g.open = {}
	up2, _ := door_between(13, 7)
	g.open[up2] = true
	troll_turn(&g)
	testing.expect_value(t, g.troll, 7)
	testing.expect(t, !g.over)
}

@(test)
the_troll_rests_every_third_turn :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 3)
	g.player = 8
	g.troll = 14
	up, _ := door_between(14, 8)
	g.open = {}
	g.open[up] = true
	g.turns = REST_EVERY - 1
	testing.expect(t, troll_winded(&g))
	g.turns += 1
	troll_turn(&g)
	testing.expect(t, .Troll_Rested in g.events)
	testing.expect_value(t, g.troll, 14)
	testing.expect(t, !g.over)
	testing.expect(t, !troll_winded(&g))
}

@(test)
the_troll_eats_you :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 3)
	g.turns = 1
	g.open = {}
	g.player = 8
	g.troll = 14
	up, _ := door_between(14, 8)
	g.open[up] = true
	troll_turn(&g)
	testing.expect(t, g.over && !g.won)
	testing.expect(t, .Eaten in g.events)

	// Walking into the troll's room is just as bad.
	new_game(&g, 3)
	g.open = {}
	g.player = 34
	right, _ := door_between(34, 35)
	g.open[right] = true
	take_turn(&g, .Right)
	testing.expect(t, g.over && !g.won)
}

@(test)
take_the_gold_and_get_out :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 3)
	g.troll = 20
	g.player = 34
	g.open = {}
	right, _ := door_between(34, 35)
	g.open[right] = true
	testing.expect(t, player_move(&g, .Right))
	testing.expect(t, g.gold)
	testing.expect(t, .Gold in g.events)
	testing.expect(t, !g.over)
	g.player = 1
	left, _ := door_between(1, 0)
	g.open[left] = true
	testing.expect(t, player_move(&g, .Left))
	testing.expect(t, g.over && g.won)
	// Reaching the cave mouth without the gold is not a win.
	new_game(&g, 3)
	g.player = 1
	g.open[left] = true
	player_move(&g, .Left)
	testing.expect(t, !g.over)
}

// A careful player: never steps where the troll can reach this turn, heads for the gold and then
// the way out. Keeps the door count honest: the cave should be beatable, but not every time.
@(test)
a_careful_player_wins_some :: proc(t: ^testing.T) {
	wins, eaten_n, stuck := 0, 0, 0
	GAMES :: 2000
	for seed in u64(1) ..= GAMES {
		g: Game
		new_game(&g, seed * 7919)
		for !g.over && g.turns < 300 {
			target := g.gold ? ENTRANCE : GOLD_ROOM
			best := Dir.Stay
			best_score := max(int)
			for d in Dir {
				if _, ok := can_go(&g, g.player, d); !ok {continue}
				h := g
				player_move(&h, d)
				troll_turn(&h)
				score := 0
				if h.over && !h.won {score = 1000}
				if h.won {score = -1000}
				p := h.player
				score += 10 * (abs(row_of(p) - row_of(target)) + abs(col_of(p) - col_of(target)))
				near := abs(row_of(p) - row_of(h.troll)) + abs(col_of(p) - col_of(h.troll))
				if near == 1 {score += 25} else if near == 2 {score += 8}
				score -= near
				if score < best_score {
					best_score = score
					best = d
				}
			}
			take_turn(&g, best)
		}
		if g.won {wins += 1} else if g.over {eaten_n += 1} else {stuck += 1}
	}
	log.infof("careful player: %d won, %d eaten, %d out of time, of %d", wins, eaten_n, stuck, GAMES)
	testing.expect(t, wins > GAMES / 3)
	testing.expect(t, wins < GAMES * 19 / 20)
}
