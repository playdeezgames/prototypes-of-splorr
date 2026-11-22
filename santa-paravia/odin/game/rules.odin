package paravia

// Santa Paravia (working name), after "Santa Paravia en Fiumaccio" by Rev. George Blank
// (SoftSide, December 1978): one to six rulers of 15th-century Italian city-states take turns, a
// year each, to rise from Sir (or Lady) to King (or Queen) before death takes them. Each year:
// the harvest (weather, rats, grain and land prices; buy and sell), the grain released to the
// people (and the births, deaths, migration and flight that follow), rents, wages and invasions,
// taxes and justice (and the revenue, interest and bankruptcy), the map, the public works, and
// the new title. The formulas follow the listing (version 6.2), transcribed from the page scans.
// New here: computer rulers, so one person has rivals (and invaders) to measure up to.
// Pure rules: no platform imports.

MAX_PLAYERS :: 6
START_YEAR :: 1400
KING :: 8 // the top title

CITIES := [MAX_PLAYERS]string{"SANTA PARAVIA", "FIUMACCIO", "TORRICELLA", "MOLINETTO", "FONTANILE", "ROMAGNA"}

TITLES_M := [KING + 1]string{"", "SIR", "BARON", "COUNT", "MARQUIS", "DUKE", "GRAND DUKE", "PRINCE", "KING"}
TITLES_F := [KING + 1]string{"", "LADY", "BARONESS", "COUNTESS", "MARQUISE", "DUCHESS", "GRAND DUCHESS", "PRINCESS", "QUEEN"}

LEVELS := [5]string{"", "APPRENTICE", "JOURNEYMAN", "MASTER", "GRAND MASTER"}

JUSTICE := [5]string{"", "VERY FAIR", "MODERATE", "HARSH", "OUTRAGEOUS"}

WEATHER := [6]string{"", "DROUGHT. FAMINE THREATENS", "BAD WEATHER. POOR HARVEST", "NORMAL WEATHER. AVERAGE HARVEST", "GOOD WEATHER. FINE HARVEST", "EXCELLENT WEATHER. GREAT HARVEST"}

// Public works: the listing's menu, lines 6010-6050.
Work :: enum {
	Market,
	Mill,
	Palace,
	Cathedral,
	Soldiers,
}

WORK_COST := [Work]int {
	.Market    = 1000,
	.Mill      = 2000,
	.Palace    = 3000,
	.Cathedral = 5000,
	.Soldiers  = 500,
}

Cause :: enum {
	None,
	Old_Age,
	Pneumonia,
	Smallpox,
	Typhoid,
	Robbers,
	Food_Poisoning,
}

Player :: struct {
	name:        string,
	female:      bool,
	computer:    bool,
	city:        int,
	alive:       bool,
	death_year:  int, // O
	cause:       Cause,
	title:       int, // T: 1 Sir .. 8 King
	title_order: int, // when the title was reached (for ties at the end)
	// Resources (the listing's matrix variables).
	markets:     int, // A
	palaces:     int, // B
	cathedrals:  int, // C
	mills:       int, // D
	customs:     int, // G
	sales:       int, // H
	wealth:      int, // I
	justice:     int, // J
	treasury:    f64, // K
	land:        f64, // L
	merchants:   int, // M
	nobles:      int, // N
	soldiers:    int, // P
	clergy:      int, // Q
	grain:       f64, // R
	serfs:       f64, // S
	economy:     f64, // U
}

// What this year's harvest phase worked out (lines 2000-2240).
Harvest :: struct {
	weather:    int, // W, 1-5
	rats:       int, // percent of reserves eaten
	harvested:  f64, // H!
	demand:     f64, // D!
	grain_price: int, // G, florins for 1000 steres
	land_price: f64, // L, florins a hectare
}

// What happened between the grain release and the taxes (lines 4000-4990).
Report :: struct {
	born, died:      int,
	migrants:        int, // serfs moving to the city
	new_merchants:   int,
	new_nobles:      int,
	new_clergy:      int,
	fled:            int, // serfs fleeing harsh justice
	starving:        bool,
	market_rent:     int,
	mill_income:     int,
	soldiers_paid:   int,
	invaded:         bool,
	invader:         int, // player index, or -1 for Baron Peppone of Monterana
	land_lost:       int,
	soldiers_lost:   int,
}

Revenue :: struct {
	customs, sales, wealth, justice: int,
}

Phase :: enum {
	Obituary, // the current player has just died
	Market, // buy and sell grain and land
	Release, // how much grain for the people
	Report, // what came of it
	Taxes, // set taxes and justice
	Bankrupt, // creditors have seized the assets
	Map,
	Works, // public works
	Promoted, // a new title
	Crowned, // a King or Queen: the game is over
	Game_Over, // everyone has died
}

Game :: struct {
	players:     [MAX_PLAYERS]Player,
	count:       int,
	level:       int, // 1-4
	skill:       int, // U(0) = level + 5
	year:        int,
	current:     int,
	phase:       Phase,
	harvest:     Harvest,
	report:      Report,
	revenue:     Revenue,
	old_title:   int,
	winner:      int, // -1 none
	order:       int, // counts titles reached, for ties
	rng:         u64,
}

Setup :: struct {
	name:     string,
	female:   bool,
	computer: bool,
}

// ---- randomness: the listing's RND(n), 1 to n ----

next_random :: proc(g: ^Game) -> f64 {
	x := g.rng
	x ~= x >> 12
	x ~= x << 25
	x ~= x >> 27
	g.rng = x
	return f64((x * 0x2545F4914F6CDD1D) >> 11) / f64(u64(1) << 53)
}

rnd :: proc(g: ^Game, n: int) -> int {
	if n <= 0 {return 0}
	return 1 + min(n - 1, int(next_random(g) * f64(n)))
}

// ---- setting up (lines 300-580) ----

new_game :: proc(g: ^Game, seed: u64, setups: []Setup, level: int) {
	g^ = {}
	g.rng = seed | 1
	g.count = clamp(len(setups), 1, MAX_PLAYERS)
	g.level = clamp(level, 1, 4)
	g.skill = g.level + 5
	g.year = START_YEAR
	g.winner = -1
	for i in 0 ..< g.count {
		p := &g.players[i]
		p^ = {
			name       = setups[i].name,
			female     = setups[i].female,
			computer   = setups[i].computer,
			city       = i,
			alive      = true,
			customs    = 25,
			sales      = 10,
			wealth     = 5,
			justice    = 2,
			death_year = 1420 + rnd(g, 35),
			treasury   = 1000,
			land       = 10000,
			grain      = 5000,
			title      = 1,
			economy    = 1,
			nobles     = 4,
			soldiers   = 25,
			clergy     = 5,
			merchants  = 25,
			serfs      = 2000,
		}
	}
	g.current = 0
	begin_turn(g)
}

title_name :: proc(p: ^Player) -> string {
	t := clamp(p.title, 1, KING)
	return p.female ? TITLES_F[t] : TITLES_M[t]
}

title_of :: proc(p: ^Player, t: int) -> string {
	k := clamp(t, 1, KING)
	return p.female ? TITLES_F[k] : TITLES_M[k]
}

cur :: proc(g: ^Game) -> ^Player {
	return &g.players[g.current]
}

// ---- the control loop (lines 600-990) ----

// Starts the current player's year: death, or the harvest.
begin_turn :: proc(g: ^Game) {
	p := cur(g)
	if g.year == p.death_year {
		die(g, p)
		g.phase = .Obituary
		return
	}
	agriculture(g, p)
	g.phase = .Market
}

// Lines 1100-1180: the obituary's cause of death.
die :: proc(g: ^Game, p: ^Player) {
	p.alive = false
	v := rnd(g, 8)
	switch {
	case g.year > 1450:
		p.cause = .Old_Age
	case v < 4:
		p.cause = .Pneumonia
	case v == 4:
		p.cause = .Typhoid
	case v == 5:
		p.cause = .Smallpox
	case v == 6:
		p.cause = .Robbers
	case:
		p.cause = .Food_Poisoning
	}
}

CAUSE_TEXT := [Cause]string {
	.None           = "",
	.Old_Age        = "OF OLD AGE AFTER A LONG REIGN",
	.Pneumonia      = "OF PNEUMONIA AFTER A COLD WINTER IN A DRAFTY CASTLE",
	.Smallpox       = "IN A SMALLPOX EPIDEMIC",
	.Typhoid        = "OF TYPHOID AFTER DRINKING CONTAMINATED WATER",
	.Robbers        = "AFTER BEING ATTACKED BY ROBBERS WHILE TRAVELING",
	.Food_Poisoning = "OF FOOD POISONING",
}

// Moves to the next living player, a new year after the last; ends the game when all are dead.
next_player :: proc(g: ^Game) {
	any_alive := false
	for i in 0 ..< g.count {if g.players[i].alive {any_alive = true}}
	if !any_alive {
		end_game(g)
		return
	}
	for {
		g.current += 1
		if g.current >= g.count {
			g.current = 0
			g.year += 1
		}
		if g.players[g.current].alive {break}
	}
	begin_turn(g)
}

// Lines 11000: everyone is dead; the highest title wins, the first to reach it on a tie.
end_game :: proc(g: ^Game) {
	g.phase = .Game_Over
	best := -1
	for i in 0 ..< g.count {
		p := &g.players[i]
		if best < 0 || p.title > g.players[best].title || (p.title == g.players[best].title && p.title_order < g.players[best].title_order) {
			best = i
		}
	}
	g.winner = best
}

// ---- agriculture (lines 2000-2240) ----

agriculture :: proc(g: ^Game, p: ^Player) {
	h := &g.harvest
	h.weather = (rnd(g, 5) + rnd(g, 6)) / 2
	h.rats = rnd(g, 50)
	p.grain = (p.grain * 100 - p.grain * f64(h.rats)) / 100
	// The harvest is limited by the land, the serfs not at the mills, and the seed grain.
	x := p.land
	y := (p.serfs - f64(p.mills) * 100) * 5
	if y < 0 {y = 0}
	if y < x {x = y}
	y = p.grain * 2
	if y < x {x = y}
	h.harvested = f64(int(x * (f64(h.weather) - 0.5)))
	p.grain += h.harvested
	h.demand = grain_demand(p)
	// Land price.
	lp := f64(3 * h.weather + rnd(g, 6) + rnd(g, 6) + 10) / 10
	ratio: f64 = 2
	if h.harvested >= 1 {ratio = min(2, h.demand / h.harvested)}
	if ratio < 0.8 {ratio = 0.8}
	lp *= ratio
	h.land_price = f64(int(lp * 10)) / 10
	// Grain price.
	z := 6 - h.weather
	h.grain_price = int(f64(z * 3 + rnd(g, 5) + rnd(g, 5)) / 5 * ratio * 20)
}

// Line 2170. The listing counts cathedrals at 40 steres; the clergy are surely meant (the
// cathedrals are buildings, and the clergy otherwise eat nothing), so this counts the clergy.
grain_demand :: proc(p: ^Player) -> f64 {
	return f64(p.nobles * 100 + p.clergy * 40 + p.merchants * 30 + p.soldiers * 10) + p.serfs * 5
}

// ---- harvest time: buying and selling (lines 2600-2880) ----

// The listing let a ruler buy on credit: the treasury may go below zero (interest follows).
buy_grain :: proc(g: ^Game, n: int) -> bool {
	if g.phase != .Market || n <= 0 {return false}
	p := cur(g)
	p.treasury -= f64(n * g.harvest.grain_price) / 1000
	p.grain += f64(n)
	return true
}

sell_grain :: proc(g: ^Game, n: int) -> bool {
	p := cur(g)
	if g.phase != .Market || n <= 0 || f64(n) > p.grain {return false} // "YOU DONT HAVE IT"
	p.treasury += f64(n * g.harvest.grain_price) / 1000
	p.grain -= f64(n)
	return true
}

buy_land :: proc(g: ^Game, n: int) -> bool {
	if g.phase != .Market || n <= 0 {return false}
	p := cur(g)
	p.land += f64(n)
	p.treasury -= f64(n) * g.harvest.land_price
	return true
}

// Line 2860: "YOU CANT SELL THAT MUCH" below 5000 hectares.
sell_land :: proc(g: ^Game, n: int) -> bool {
	p := cur(g)
	if g.phase != .Market || n <= 0 || f64(n) > p.land - 5000 {return false}
	p.land -= f64(n)
	p.treasury += f64(n) * g.harvest.land_price
	return true
}

max_land_sale :: proc(p: ^Player) -> int {
	return max(0, int(p.land - 5000))
}

done_market :: proc(g: ^Game) {
	if g.phase == .Market {g.phase = .Release}
}

// ---- population (lines 4000-4530) ----

release_min :: proc(p: ^Player) -> int {return int(p.grain / 5 + 0.999)}
release_max :: proc(p: ^Player) -> int {return int(p.grain - p.grain / 5)}

release_grain :: proc(g: ^Game, amount: int) -> bool {
	p := cur(g)
	if g.phase != .Release || amount < release_min(p) || amount > release_max(p) {return false}
	r := &g.report
	r^ = {}
	r.invader = -1
	rel := f64(amount)
	p.grain -= rel
	d := g.harvest.demand
	if rel < d - 1 {
		// Lines 4500-4520: a shortage.
		x := int((d - rel) / d * 100 - 9)
		x = clamp(x, 0, 65)
		r.starving = true
		r.born = births(g, p, 3)
		r.died = deaths(g, p, x + 8)
	} else {
		r.born = births(g, p, 7)
		r.died = deaths(g, p, 3)
		if p.customs + p.sales < 35 {
			k := rnd(g, 4)
			p.merchants += k
			r.new_merchants += k
		}
		if p.wealth < rnd(g, 20) {
			n := rnd(g, 2) - 1
			c := rnd(g, 3) - 1
			p.nobles += n
			p.clergy += c
			r.new_nobles += n
			r.new_clergy += c
		}
		if rel >= d * 1.3 {
			// Lines 4200-4280: a large surplus draws people to the city.
			zi := int(p.serfs / 1000)
			z := (rel - d) / d * 10
			z = z * f64(zi) * f64(rnd(g, 25)) + f64(rnd(g, 40))
			if z > 32000 {z = 32000}
			m := rnd(g, int(z))
			p.serfs += f64(m)
			r.migrants = m
			k := min(50, rnd(g, m / 5))
			p.merchants += k
			r.new_merchants += k
			p.nobles += 1
			p.clergy += 2
			r.new_nobles += 1
			r.new_clergy += 2
		}
	}
	// Lines 4300-4340: harsh justice drives serfs away.
	if p.justice >= 3 {
		j := int(p.serfs / 100 * f64((p.justice - 2) * (p.justice - 2)))
		f := rnd(g, j)
		p.serfs -= f64(f)
		r.fled = f
	}
	// Lines 4900-4930: rents, mills, wages.
	r.market_rent = p.markets * 75
	p.treasury += f64(r.market_rent)
	p.serfs = f64(int(p.serfs))
	if p.mills > 0 {
		r.mill_income = p.mills * (55 + rnd(g, 250))
		p.treasury += f64(r.mill_income)
	}
	r.soldiers_paid = p.soldiers * 3
	p.treasury -= f64(r.soldiers_paid)
	// Lines 4940-4970: invasion of a weak state.
	if p.land / 1000 > f64(p.soldiers) {
		invade(g, p)
	} else if !(p.land / 500 < f64(p.soldiers)) {
		for i in 0 ..< g.count {
			if i == g.current || !g.players[i].alive {continue}
			if f64(g.players[i].soldiers) > f64(p.soldiers) * 2.4 {
				invade(g, p)
				break
			}
		}
	}
	g.phase = .Report
	return true
}

// Lines 1500-1510: births and deaths, a random percent of the serfs up to n.
births :: proc(g: ^Game, p: ^Player, n: int) -> int {
	z := int(f64(rnd(g, n)) * p.serfs / 100)
	p.serfs += f64(z)
	return z
}

deaths :: proc(g: ^Game, p: ^Player, n: int) -> int {
	z := int(f64(rnd(g, n)) * p.serfs / 100)
	p.serfs -= f64(z)
	return z
}

// Lines 8100-8280.
invade :: proc(g: ^Game, p: ^Player) {
	r := &g.report
	best := -1
	for i in 0 ..< g.count {
		a := &g.players[i]
		if i == g.current || !a.alive {continue}
		if a.soldiers < p.soldiers {continue}
		if f64(a.soldiers) < 1.2 * (a.land / 1000) {continue}
		if best < 0 || a.soldiers > g.players[best].soldiers {best = i}
	}
	seized: f64
	if best < 0 {
		seized = f64(rnd(g, 9000) + 1000) // Baron Peppone of Monterana
	} else {
		a := &g.players[best]
		seized = f64(a.soldiers) * 1000 - a.land / 3
	}
	if seized > p.land - 5000 {seized = (p.land - 5000) / 2}
	seized = max(0, f64(int(seized)))
	if best >= 0 {g.players[best].land += seized}
	p.land -= seized
	z := rnd(g, 40)
	if z > p.soldiers - 15 {z = max(0, p.soldiers - 15)}
	p.soldiers -= z
	r.invaded = true
	r.invader = best
	r.land_lost = int(seized)
	r.soldiers_lost = z
}

done_report :: proc(g: ^Game) {
	if g.phase == .Report {g.phase = .Taxes}
}

// ---- taxes and justice (lines 2400-2590, 3000-3220) ----

// What the current rates would bring in.
project_revenue :: proc(p: ^Player) -> Revenue {
	rv: Revenue
	rv.justice = (p.justice * 300 - 500) * p.title
	y := f64(150 - p.customs - p.sales - p.wealth)
	if y < 1 {y = 1}
	c := (f64(p.nobles * 180 + p.clergy * 75 + p.merchants * 20)) * (y / 100) + p.economy * 100
	s := (f64(p.nobles * 50 + p.merchants * 25) + p.economy * 10) * (y / 100) * f64(5 - p.justice) / 2
	w := f64(p.nobles * 250) + p.economy * 20 + f64(10 * p.justice * p.nobles) * (y / 100)
	rv.customs = int(c * f64(p.customs) / 100)
	rv.sales = int(s * f64(p.sales) / 100)
	rv.wealth = int(w * f64(p.wealth) / 100)
	return rv
}

revenue_total :: proc(rv: Revenue) -> int {
	return rv.customs + rv.sales + rv.wealth + rv.justice
}

// The listing's limits: customs 0-100, sales 0-50, wealth 0-25, justice 1-4.
set_customs :: proc(p: ^Player, v: int) {p.customs = clamp(v, 0, 100)}
set_sales :: proc(p: ^Player, v: int) {p.sales = clamp(v, 0, 50)}
set_wealth :: proc(p: ^Player, v: int) {p.wealth = clamp(v, 0, 25)}
set_justice :: proc(p: ^Player, v: int) {p.justice = clamp(v, 1, 4)}

// Lines 3200-3220: credit the revenue, charge interest on a debt, test for bankruptcy.
collect_taxes :: proc(g: ^Game) {
	if g.phase != .Taxes {return}
	p := cur(g)
	g.revenue = project_revenue(p)
	p.treasury += f64(revenue_total(g.revenue))
	if p.treasury < 0 {p.treasury *= 1.5}
	if p.treasury < -10000 * f64(p.title) {
		// Lines 8000-8040.
		p.markets = 0
		p.palaces = 0
		p.cathedrals = 0
		p.mills = 0
		p.land = 6000
		p.economy = 1
		p.treasury = 100
		g.phase = .Bankrupt
		return
	}
	g.phase = .Map
}

done_bankrupt :: proc(g: ^Game) {
	if g.phase == .Bankrupt {g.phase = .Map}
}

done_map :: proc(g: ^Game) {
	if g.phase == .Map {g.phase = .Works}
}

// ---- public works (lines 6000-6550) ----

// As in the listing, works can be bought on credit.
buy_work :: proc(g: ^Game, w: Work) -> bool {
	if g.phase != .Works {return false}
	p := cur(g)
	switch w {
	case .Market:
		p.markets += 1
		p.merchants += 5
		p.economy += 0.1
	case .Mill:
		p.mills += 1
		p.economy += 0.25
	case .Palace:
		p.palaces += 1
		p.nobles += rnd(g, 2)
		p.economy += 0.5
	case .Cathedral:
		p.cathedrals += 1
		p.clergy += rnd(g, 6)
		p.economy += 1
	case .Soldiers:
		if p.serfs < 20 {return false}
		p.soldiers += 20
		p.serfs -= 20
	}
	p.treasury -= f64(WORK_COST[w])
	return true
}

// ---- the new title (lines 7000-7190) ----

title_score :: proc(p: ^Player) -> int {
	part :: proc(a: f64) -> int {return int(min(a, 10))}
	z := 0
	z += part(f64(p.markets))
	z += part(f64(p.palaces))
	z += part(f64(p.cathedrals))
	z += part(f64(p.mills))
	z += part(p.treasury / 5000)
	z += part(p.land / 6000)
	z += part(f64(p.merchants) / 50)
	z += part(f64(p.nobles) / 5)
	z += part(f64(p.soldiers) / 50)
	z += part(f64(p.clergy) / 10)
	z += part(p.serfs / 2000)
	z += part(p.economy / 5)
	return z
}

// The title the score deserves (line 7130), never above King.
deserved_title :: proc(g: ^Game, p: ^Player) -> int {
	a := f64(title_score(p)) / f64(g.skill) - f64(p.justice)
	return min(KING, int(a))
}

// Ends the public works: the title, and then the next player.
done_works :: proc(g: ^Game) {
	if g.phase != .Works {return}
	p := cur(g)
	g.old_title = p.title
	// Line 7140: two years before death, a title of honour.
	if g.year + 2 == p.death_year {p.title += 1}
	a := deserved_title(g, p)
	if a > p.title {p.title = a}
	p.title = min(p.title, KING)
	if p.title > g.old_title {
		g.order += 1
		p.title_order = g.order
	}
	if p.title >= KING {
		g.winner = g.current
		g.phase = .Crowned
		return
	}
	if p.title > g.old_title {
		g.phase = .Promoted
		return
	}
	next_player(g)
}

// The page calls this after the obituary or the promotion.
continue_turn :: proc(g: ^Game) {
	switch g.phase {
	case .Obituary, .Promoted:
		next_player(g)
	case .Market, .Release, .Report, .Taxes, .Bankrupt, .Map, .Works, .Crowned, .Game_Over:
	}
}

// ---- computer rulers (new) ----

// Plays the computer ruler's whole phase. A plain, sensible steward: keep a year's grain,
// feed the people well, keep enough soldiers, moderate taxes, then build with spare money.
computer_phase :: proc(g: ^Game) {
	p := cur(g)
	h := &g.harvest
	switch g.phase {
	case .Market:
		need := h.demand * 1.6
		if p.grain < need && h.grain_price > 0 {
			afford := int((p.treasury - 300) * 1000 / f64(h.grain_price))
			n := min(int(need - p.grain), afford)
			if n > 0 {buy_grain(g, n)}
		} else if p.grain > h.demand * 3 {
			sell_grain(g, int(p.grain - h.demand * 2.5))
		}
		if h.land_price <= 2.2 && p.treasury > 3000 {
			n := int((p.treasury - 2000) / 2 / h.land_price)
			if n > 0 {buy_land(g, n)}
		} else if h.land_price >= 4 && p.land > 20000 {
			sell_land(g, int((p.land - 15000) / 4))
		}
		done_market(g)
	case .Release:
		want := int(h.demand * 1.3)
		if f64(release_max(p)) < h.demand * 1.3 {want = int(h.demand)}
		want = clamp(want, release_min(p), release_max(p))
		release_grain(g, want)
	case .Report:
		done_report(g)
	case .Taxes:
		set_customs(p, 30)
		set_sales(p, 10)
		set_wealth(p, 10)
		set_justice(p, g.year < 1405 ? 3 : 2)
		collect_taxes(g)
	case .Bankrupt:
		done_bankrupt(g)
	case .Map:
		done_map(g)
	case .Works:
		for _ in 0 ..< 20 {
			if p.land / 700 > f64(p.soldiers) && p.treasury > 800 {
				buy_work(g, .Soldiers)
			} else if p.treasury > 9000 && p.cathedrals < 10 {
				buy_work(g, .Cathedral)
			} else if p.treasury > 6000 && p.palaces < 10 {
				buy_work(g, .Palace)
			} else if p.treasury > 3500 && p.mills < 10 {
				buy_work(g, .Mill)
			} else if p.treasury > 2000 && p.markets < 10 {
				buy_work(g, .Market)
			} else {
				break
			}
		}
		done_works(g)
	case .Obituary, .Promoted, .Crowned, .Game_Over:
	}
}

living :: proc(g: ^Game) -> int {
	n := 0
	for i in 0 ..< g.count {if g.players[i].alive {n += 1}}
	return n
}
