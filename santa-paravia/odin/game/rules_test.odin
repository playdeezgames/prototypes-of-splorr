#+build !js
package paravia

import "core:fmt"
import "core:testing"

one :: proc(g: ^Game, seed: u64, computer := false) {
	s := [1]Setup{{"LORENZO", false, computer}}
	new_game(g, seed, s[:], 1)
}

@(test)
the_listings_starting_state :: proc(t: ^testing.T) {
	g: Game
	one(&g, 3)
	p := &g.players[0]
	testing.expect_value(t, p.land, 10000.0)
	testing.expect_value(t, p.serfs, 2000.0)
	testing.expect_value(t, p.treasury, 1000.0)
	testing.expect_value(t, p.title, 1)
	testing.expect(t, p.death_year >= 1421 && p.death_year <= 1455)
	testing.expect_value(t, g.skill, 6)
	testing.expect_value(t, g.year, 1400)
	testing.expect_value(t, title_name(p), "SIR")
	testing.expect_value(t, g.phase, Phase.Market)
	testing.expect(t, g.harvest.weather >= 1 && g.harvest.weather <= 5)
	testing.expect(t, g.harvest.rats >= 1 && g.harvest.rats <= 50)
}

@(test)
the_demand_formula :: proc(t: ^testing.T) {
	p := Player{nobles = 4, clergy = 5, merchants = 25, soldiers = 25, serfs = 2000}
	testing.expect_value(t, grain_demand(&p), 11600.0)
}

@(test)
trading :: proc(t: ^testing.T) {
	g: Game
	one(&g, 5)
	g.harvest.grain_price = 50
	g.harvest.land_price = 2
	p := &g.players[0]
	k := p.treasury
	testing.expect(t, buy_grain(&g, 2000))
	testing.expect_value(t, p.treasury, k - 100)
	testing.expect(t, !sell_grain(&g, int(p.grain) + 1)) // you don't have it
	testing.expect(t, !sell_land(&g, 5001)) // can't go under 5000 hectares
	testing.expect(t, sell_land(&g, 5000))
	testing.expect_value(t, p.land, 5000.0)
	testing.expect_value(t, max_land_sale(p), 0)
}

@(test)
release_limits_and_famine :: proc(t: ^testing.T) {
	g: Game
	one(&g, 9)
	done_market(&g)
	p := &g.players[0]
	p.grain = 10000
	testing.expect(t, !release_grain(&g, 1999)) // at least 20 percent
	testing.expect(t, !release_grain(&g, 8001)) // keep at least 20 percent
	serfs := p.serfs
	g.harvest.demand = 11600
	testing.expect(t, release_grain(&g, 2000))
	testing.expect(t, g.report.starving)
	testing.expect(t, g.report.died > 0)
	testing.expect(t, p.serfs < serfs + f64(g.report.born))
	testing.expect_value(t, g.phase, Phase.Report)
}

@(test)
taxes_follow_the_listing :: proc(t: ^testing.T) {
	p := Player{customs = 25, sales = 10, wealth = 5, justice = 2, title = 1, nobles = 4, clergy = 5, merchants = 25, economy = 1}
	rv := project_revenue(&p)
	// Y = 150 - 25 - 10 - 5 = 110.
	testing.expect_value(t, rv.justice, 100)
	testing.expect_value(t, rv.customs, 463 /* ((720 + 375 + 500) * 1.1 + 100) * 25% */)
	testing.expect_value(t, rv.sales, 137 /* (200 + 625 + 10) * 1.1 * 3 / 2 * 10% */)
	testing.expect_value(t, rv.wealth, 55 /* (1000 + 20 + 80 * 1.1) * 5% */)
	p.justice = 1
	testing.expect_value(t, project_revenue(&p).justice, -200) // very fair justice costs money
}

@(test)
debt_and_bankruptcy :: proc(t: ^testing.T) {
	g: Game
	one(&g, 4)
	p := &g.players[0]
	g.phase = .Taxes
	p.treasury = -20000
	p.markets = 3
	collect_taxes(&g)
	testing.expect_value(t, g.phase, Phase.Bankrupt)
	testing.expect_value(t, p.markets, 0)
	testing.expect_value(t, p.land, 6000.0)
	testing.expect_value(t, p.treasury, 100.0)
}

@(test)
weak_states_are_invaded :: proc(t: ^testing.T) {
	g: Game
	one(&g, 8)
	done_market(&g)
	p := &g.players[0]
	p.soldiers = 5 // 10000 hectares need ten
	release_grain(&g, release_min(p))
	testing.expect(t, g.report.invaded)
	testing.expect_value(t, g.report.invader, -1) // Baron Peppone of Monterana
	testing.expect(t, p.land >= 5000 - 1)
}

@(test)
works_and_titles :: proc(t: ^testing.T) {
	g: Game
	one(&g, 6)
	p := &g.players[0]
	g.phase = .Works
	testing.expect(t, buy_work(&g, .Market))
	testing.expect_value(t, p.merchants, 30)
	testing.expect_value(t, p.treasury, 0.0)
	testing.expect(t, buy_work(&g, .Soldiers))
	testing.expect_value(t, p.soldiers, 45)
	// Score: everything at the cap is 120; at Apprentice (6) less very fair justice (1) is 19.
	p^ = {alive = true, title = 1, justice = 1, markets = 10, palaces = 10, cathedrals = 10, mills = 10, treasury = 50000, land = 60000, merchants = 500, nobles = 50, soldiers = 500, clergy = 100, serfs = 20000, economy = 50, death_year = 1450}
	testing.expect_value(t, title_score(p), 120)
	testing.expect_value(t, deserved_title(&g, p), KING)
	done_works(&g)
	testing.expect_value(t, g.phase, Phase.Crowned)
	testing.expect_value(t, g.winner, 0)
}

@(test)
death_comes_on_its_year :: proc(t: ^testing.T) {
	g: Game
	one(&g, 2)
	g.players[0].death_year = 1400
	begin_turn(&g)
	testing.expect_value(t, g.phase, Phase.Obituary)
	testing.expect(t, !g.players[0].alive)
	continue_turn(&g)
	testing.expect_value(t, g.phase, Phase.Game_Over)
	testing.expect_value(t, g.winner, 0)
}

// Plays whole games with computer rulers, for balance: nothing breaks, and crowns are possible
// but not certain.
@(test)
computer_rulers_play_whole_games :: proc(t: ^testing.T) {
	crowned, games := 0, 60
	best_title := [KING + 1]int{}
	years := 0
	for seed in 1 ..= games {
		g := new(Game)
		defer free(g)
		s := [3]Setup{{"A", false, true}, {"B", true, true}, {"C", false, true}}
		new_game(g, u64(seed) * 7919, s[:], 1)
		for steps := 0; steps < 20000; steps += 1 {
			if g.phase == .Crowned || g.phase == .Game_Over {break}
			if g.phase == .Obituary || g.phase == .Promoted {continue_turn(g)} else {computer_phase(g)}
		}
		testing.expect(t, g.phase == .Crowned || g.phase == .Game_Over)
		if g.phase == .Crowned {crowned += 1}
		years += g.year - START_YEAR
		for i in 0 ..< g.count {
			p := &g.players[i]
			best_title[p.title] += 1
			testing.expect(t, p.serfs >= 0 && p.land >= 0, "no negative serfs or land")
		}
	}
	fmt.printfln("computer rulers: %d of %d games crowned a king or queen; titles %v; %.1f years a game", crowned, games, best_title, f64(years) / f64(games))
}
