#+build js
package main

// Santa Paravia's page: setting up, each phase of a ruler's year, the map, and the computer
// rulers' news. Rules are in ../game.

import "base:runtime"
import "core:fmt"
import "core:strconv"
import sp "../game"
import "proto:gfx"

W :: 512
H :: 320

VELLUM :: 0xefe2bf
VELLUM_DARK :: 0xd9c89a
INK :: 0x2a1a0e
INK_DIM :: 0x7a6040
RED :: 0x9a2a1a
GREEN :: 0x2a6a2a
BLUE :: 0x2a4a8a
GOLD :: 0xb08020
FRAME_C :: 0x5a3a1a
KEY :: 0x5a3a1a
KEY_TEXT :: 0xf5ead0
NIGHT :: 0x1a120c

Screen :: enum {
	Setup,
	Turn, // the human ruler's phases (the game's own phase says which)
	Pass, // hand the computer to the next ruler
	News, // what the computer rulers did
	Standings,
}

MALE_NAMES := [?]string{"LORENZO", "COSIMO", "GIOVANNI", "FRANCESCO", "LUDOVICO", "PIETRO", "MARCO", "ANTONIO"}
FEMALE_NAMES := [?]string{"CATERINA", "ISABELLA", "LUCREZIA", "BEATRICE", "BIANCA", "GIULIA", "FRANCESCA", "ELENA"}

Slot :: struct {
	computer: bool,
	female:   bool,
	name_k:   int,
}

NEWS_MAX :: 24

App :: struct {
	screen:     Screen,
	g:          sp.Game,
	slots:      [sp.MAX_PLAYERS]Slot,
	count:      int,
	level:      int,
	grain_amt:  int,
	land_amt:   int,
	release:    int,
	work_msg:   string,
	news:       [NEWS_MAX]string,
	news_n:     int,
	back:       Screen, // where Standings returns to
	t:          f32,
	msg:        string,
	msg_t:      f32,
}

app: App

main :: proc() {
	app.count = 2
	app.level = 1
	app.slots[0] = {false, false, 0}
	app.slots[1] = {true, true, 0}
	for i in 2 ..< sp.MAX_PLAYERS {app.slots[i] = {true, i % 2 == 1, i}}
	buf: [16]u8
	if v, ok := gfx.store_get("level", buf[:]); ok {
		if n, nok := strconv.parse_int(v); nok {app.level = clamp(n, 1, 4)}
	}
}

slot_name :: proc(s: Slot) -> string {
	return s.female ? FEMALE_NAMES[s.name_k % len(FEMALE_NAMES)] : MALE_NAMES[s.name_k % len(MALE_NAMES)]
}

humans :: proc() -> int {
	n := 0
	for i in 0 ..< app.g.count {if !app.g.players[i].computer {n += 1}}
	return n
}

start_game :: proc() {
	setups: [sp.MAX_PLAYERS]sp.Setup
	for i in 0 ..< app.count {
		s := app.slots[i]
		setups[i] = {slot_name(s), s.female, s.computer}
	}
	sp.new_game(&app.g, u64(gfx.now_ms()) ~ u64(gfx.random() * 1e9), setups[:app.count], app.level)
	gfx.store_set("level", fmt.tprintf("%d", app.level))
	app.news_n = 0
	fanfare()
	after_change()
}

fanfare :: proc() {
	for f, i in ([?]f32{392, 523, 659, 784}) {gfx.tone(f, 140, .Triangle, 0.05, f32(i) * 130)}
}

say :: proc(s: string) {
	app.msg = s
	app.msg_t = 2.5
}

add_news :: proc(s: string) {
	if app.news_n < NEWS_MAX {
		app.news[app.news_n] = s
		app.news_n += 1
	} else {
		for i in 1 ..< NEWS_MAX {app.news[i - 1] = app.news[i]}
		app.news[NEWS_MAX - 1] = s
	}
}

// After anything that may move play on: run computer rulers, then pick the screen.
after_change :: proc() {
	g := &app.g
	for g.phase != .Crowned && g.phase != .Game_Over && sp.cur(g).computer {
		run_computer()
	}
	if g.phase == .Crowned || g.phase == .Game_Over {
		app.screen = .Turn
		return
	}
	// A human's turn begins (Market, or an Obituary).
	set_amounts()
	if app.news_n > 0 {
		app.screen = .News
	} else if humans() > 1 {
		app.screen = .Pass
	} else {
		app.screen = .Turn
	}
}

set_amounts :: proc() {
	g := &app.g
	p := sp.cur(g)
	app.grain_amt = 1000
	app.land_amt = 100
	app.release = clamp(int(g.harvest.demand), sp.release_min(p), sp.release_max(p))
	app.work_msg = ""
}

// One computer ruler's year, told as news.
run_computer :: proc() {
	g := &app.g
	who := g.current
	p := &g.players[who]
	add_news(fmt.aprintf("%d %s %s OF %s", g.year, sp.title_name(p), p.name, sp.CITIES[p.city]))
	for steps := 0; steps < 200; steps += 1 {
		if g.current != who || g.phase == .Crowned || g.phase == .Game_Over {break}
		switch g.phase {
		case .Obituary:
			add_news(fmt.aprintf("  HAS DIED %s.", sp.CAUSE_TEXT[p.cause]))
			sp.continue_turn(g)
		case .Report:
			r := g.report
			if r.invaded {
				add_news(fmt.aprintf("  INVADED: %s HECTARES SEIZED.", num(f64(r.land_lost))))
			}
			if r.starving {add_news(fmt.aprintf("  FAMINE: %s SERFS DIED.", num(f64(r.died))))}
			sp.computer_phase(g)
		case .Bankrupt:
			add_news("  IS BANKRUPT.")
			sp.computer_phase(g)
		case .Promoted:
			add_news(fmt.aprintf("  IS NOW %s %s.", sp.title_name(p), p.name))
			sp.continue_turn(g)
		case .Crowned:
		case .Game_Over:
		case .Market, .Release, .Taxes, .Map, .Works:
			sp.computer_phase(g)
		}
	}
	if p.alive {
		add_news(fmt.aprintf("  %s SERFS, %s HECTARES, %s FLORINS.", num(p.serfs), num(p.land), num(p.treasury)))
	}
}

invader_name :: proc(k: int) -> string {
	if k < 0 {return "BARON PEPPONE OF MONTERANA"}
	q := &app.g.players[k]
	return fmt.tprintf("%s %s OF %s", sp.title_name(q), q.name, sp.CITIES[q.city])
}

@(export)
step :: proc(dt: f64) -> bool {
	d := f32(min(dt, 0.1))
	app.t += d
	app.msg_t = max(0, app.msg_t - d)
	draw()
	free_all(context.temp_allocator)
	return true
}

// ---- buttons ----

ID_COUNT_DOWN :: 1
ID_COUNT_UP :: 2
ID_LEVEL :: 3
ID_START :: 4
ID_CONTINUE :: 5
ID_STANDINGS :: 6
ID_NEW_GAME :: 7
ID_SLOT_KIND :: 10 // + slot
ID_SLOT_SEX :: 20 // + slot
ID_SLOT_NAME :: 30 // + slot
ID_GRAIN_STEP :: 40 // + 0..5 (-10000 -1000 -100 +100 +1000 +10000)
ID_LAND_STEP :: 50 // + 0..5
ID_BUY_GRAIN :: 60
ID_SELL_GRAIN :: 61
ID_BUY_LAND :: 62
ID_SELL_LAND :: 63
ID_REL_STEP :: 70 // + 0..5
ID_REL_MIN :: 76
ID_REL_DEMAND :: 77
ID_REL_PLENTY :: 78
ID_REL_MAX :: 79
ID_TAX_DOWN :: 80 // + tax 0..3
ID_TAX_UP :: 84 // + tax 0..3
ID_WORK :: 90 // + work

STEPS := [6]int{-10000, -1000, -100, 100, 1000, 10000}
STEP_LABELS := [6]string{"-10K", "-1K", "-100", "+100", "+1K", "+10K"}

click :: proc(id: int) {
	g := &app.g
	switch app.screen {
	case .Setup:
		click_setup(id)
		return
	case .Pass, .News:
		if id == ID_CONTINUE {
			if app.screen == .News && humans() > 1 {
				app.news_n = 0
				app.screen = .Pass
			} else {
				app.news_n = 0
				app.screen = .Turn
			}
			gfx.tone(660, 30, .Triangle, 0.04)
		}
		return
	case .Standings:
		if id == ID_CONTINUE || id == ID_STANDINGS {app.screen = app.back}
		return
	case .Turn:
	}
	if id == ID_STANDINGS {
		app.back = app.screen
		app.screen = .Standings
		return
	}
	p := sp.cur(g)
	switch g.phase {
	case .Market:
		switch {
		case id >= ID_GRAIN_STEP && id < ID_GRAIN_STEP + 6:
			app.grain_amt = clamp(app.grain_amt + STEPS[id - ID_GRAIN_STEP], 0, 999999)
			tick()
		case id >= ID_LAND_STEP && id < ID_LAND_STEP + 6:
			app.land_amt = clamp(app.land_amt + STEPS[id - ID_LAND_STEP], 0, 999999)
			tick()
		case id == ID_BUY_GRAIN:
			trade(sp.buy_grain(g, app.grain_amt), "BOUGHT", "")
		case id == ID_SELL_GRAIN:
			trade(sp.sell_grain(g, app.grain_amt), "SOLD", "YOU DON'T HAVE IT")
		case id == ID_BUY_LAND:
			trade(sp.buy_land(g, app.land_amt), "BOUGHT", "")
		case id == ID_SELL_LAND:
			trade(sp.sell_land(g, app.land_amt), "SOLD", "YOU CAN'T SELL THAT MUCH")
		case id == ID_CONTINUE:
			sp.done_market(g)
			app.release = clamp(app.release, sp.release_min(p), sp.release_max(p))
			tick()
		}
	case .Release:
		lo, hi := sp.release_min(p), sp.release_max(p)
		switch {
		case id >= ID_REL_STEP && id < ID_REL_STEP + 6:
			app.release = clamp(app.release + STEPS[id - ID_REL_STEP], lo, hi)
			tick()
		case id == ID_REL_MIN:
			app.release = lo
		case id == ID_REL_DEMAND:
			app.release = clamp(int(g.harvest.demand + 1), lo, hi)
		case id == ID_REL_PLENTY:
			app.release = clamp(int(g.harvest.demand * 1.3 + 1), lo, hi)
		case id == ID_REL_MAX:
			app.release = hi
		case id == ID_CONTINUE:
			if sp.release_grain(g, app.release) {
				if g.report.invaded {
					gfx.noise(400, 0.08)
				} else if g.report.starving {
					gfx.tone(160, 400, .Saw, 0.04)
				} else {
					gfx.tone(523, 80, .Triangle, 0.04)
				}
			}
		}
	case .Report:
		if id == ID_CONTINUE {
			sp.done_report(g)
			tick()
		}
	case .Taxes:
		switch {
		case id >= ID_TAX_UP && id < ID_TAX_UP + 4:
			nudge_tax(p, id - ID_TAX_UP, 1)
		case id >= ID_TAX_DOWN && id < ID_TAX_DOWN + 4:
			nudge_tax(p, id - ID_TAX_DOWN, -1)
		case id == ID_CONTINUE:
			sp.collect_taxes(g)
			if g.phase == .Bankrupt {
				gfx.tone(120, 600, .Saw, 0.05)
			} else {
				coins()
			}
		}
	case .Bankrupt:
		if id == ID_CONTINUE {sp.done_bankrupt(g)}
	case .Map:
		if id == ID_CONTINUE {sp.done_map(g)}
	case .Works:
		switch {
		case id >= ID_WORK && id < ID_WORK + len(sp.Work):
			w := sp.Work(id - ID_WORK)
			if sp.buy_work(g, w) {
				coins()
				app.work_msg = fmt.aprintf("BOUGHT: %s", WORK_NAMES[w])
			} else {
				app.work_msg = "NOT ENOUGH SERFS TO ARM"
			}
		case id == ID_CONTINUE:
			sp.done_works(g)
			switch g.phase {
			case .Promoted:
				fanfare()
			case .Crowned:
				fanfare()
				for f, i in ([?]f32{784, 1047, 784, 1047, 1319}) {gfx.tone(f, 160, .Square, 0.04, 600 + f32(i) * 160)}
			case .Market, .Release, .Report, .Taxes, .Bankrupt, .Map, .Works, .Obituary, .Game_Over:
				after_change()
			}
		}
	case .Promoted:
		if id == ID_CONTINUE {
			sp.continue_turn(g)
			after_change()
		}
	case .Obituary:
		if id == ID_CONTINUE {
			sp.continue_turn(g)
			after_change()
		}
	case .Crowned, .Game_Over:
		if id == ID_NEW_GAME {app.screen = .Setup}
	}
}

tick :: proc() {gfx.tone(900, 12, .Square, 0.02)}

coins :: proc() {
	for i in 0 ..< 3 {gfx.tone(1568 + f32(i) * 200, 40, .Square, 0.03, f32(i) * 50)}
}

trade :: proc(ok: bool, done, refused: string) {
	if ok {
		coins()
		say(done)
	} else if refused != "" {
		gfx.tone(140, 160, .Saw, 0.04)
		say(refused)
	}
}

nudge_tax :: proc(p: ^sp.Player, k, dir: int) {
	switch k {
	case 0:
		sp.set_customs(p, p.customs + dir)
	case 1:
		sp.set_sales(p, p.sales + dir)
	case 2:
		sp.set_wealth(p, p.wealth + dir)
	case 3:
		sp.set_justice(p, p.justice + dir)
	}
	tick()
}

click_setup :: proc(id: int) {
	switch {
	case id == ID_COUNT_DOWN:
		app.count = max(1, app.count - 1)
	case id == ID_COUNT_UP:
		app.count = min(sp.MAX_PLAYERS, app.count + 1)
	case id == ID_LEVEL:
		app.level = app.level % 4 + 1
	case id == ID_START:
		start_game()
		return
	case id >= ID_SLOT_NAME && id < ID_SLOT_NAME + sp.MAX_PLAYERS:
		app.slots[id - ID_SLOT_NAME].name_k += 1
	case id >= ID_SLOT_SEX && id < ID_SLOT_SEX + sp.MAX_PLAYERS:
		s := &app.slots[id - ID_SLOT_SEX]
		s.female = !s.female
	case id >= ID_SLOT_KIND && id < ID_SLOT_KIND + sp.MAX_PLAYERS:
		s := &app.slots[id - ID_SLOT_KIND]
		s.computer = !s.computer
	}
	tick()
}

// ---- input ----

@(export)
on_key :: proc "c" (code: i32, down: i32) {
	context = runtime.default_context()
	if down != 1 {return}
	c := int(code)
	g := &app.g
	if c == gfx.KEY_ENTER || c == gfx.KEY_SPACE {
		switch app.screen {
		case .Setup:
			click(ID_START)
		case .Turn:
			if g.phase == .Crowned || g.phase == .Game_Over {click(ID_NEW_GAME)} else {click(ID_CONTINUE)}
		case .Pass, .News, .Standings:
			click(ID_CONTINUE)
		}
		return
	}
	if c == 'S' && app.screen == .Turn {click(ID_STANDINGS)}
	if c == gfx.KEY_ESCAPE && app.screen == .Standings {click(ID_CONTINUE)}
	if app.screen == .Turn && g.phase == .Works && c >= '1' && c <= '5' {click(ID_WORK + c - '1')}
	if app.screen == .Turn && g.phase == .Release {
		if c == gfx.KEY_UP || c == gfx.KEY_RIGHT {click(ID_REL_STEP + 4)}
		if c == gfx.KEY_DOWN || c == gfx.KEY_LEFT {click(ID_REL_STEP + 1)}
	}
}

@(export)
on_pointer :: proc "c" (x, y: f32, kind: i32) {
	context = runtime.default_context()
	if kind != 0 {return}
	id := gfx.hit(x, y)
	if id > 0 {click(id)}
}

// ---- drawing helpers ----

WORK_NAMES := [sp.Work]string {
	.Market    = "MARKETPLACE",
	.Mill      = "WOOLEN MILL",
	.Palace    = "PALACE (PARTIAL)",
	.Cathedral = "CATHEDRAL (PARTIAL)",
	.Soldiers  = "A PLATOON OF SOLDIERS",
}

num :: proc(v: f64) -> string {
	n := i64(v)
	neg := n < 0
	if neg {n = -n}
	tmp: [32]u8
	k := 0
	digits := 0
	for {
		if digits > 0 && digits % 3 == 0 {tmp[k] = ','; k += 1}
		tmp[k] = u8('0' + n % 10)
		k += 1
		digits += 1
		n /= 10
		if n == 0 {break}
	}
	if neg {tmp[k] = '-'; k += 1}
	out := make([]u8, k, context.temp_allocator)
	for i in 0 ..< k {out[i] = tmp[k - 1 - i]}
	return string(out)
}

btn :: proc(x, y: int, label: string, id: int, size := 1) -> int {
	return gfx.button(x, y, label, id, KEY_TEXT, KEY, size)
}

rtext :: proc(right, y: int, s: string, c: u32) {
	gfx.text(right - gfx.text_width(s), y, s, c)
}

ruler_line :: proc(p: ^sp.Player) -> string {
	return fmt.tprintf("%s %s OF %s", sp.title_name(p), p.name, sp.CITIES[p.city])
}

header :: proc() {
	g := &app.g
	p := sp.cur(g)
	gfx.rect(0, 0, W, 20, FRAME_C)
	gfx.text(8, 6, fmt.tprintf("%d", g.year), GOLD)
	gfx.text(48, 6, ruler_line(p), KEY_TEXT)
	rtext(W - 8, 6, fmt.tprintf("%s FL", num(p.treasury)), p.treasury < 0 ? 0xff8a6a : GOLD)
}

continue_button :: proc(label: string) {
	w := gfx.text_width(label, 2) + 16
	btn(W - 8 - w, H - 30, label, ID_CONTINUE, 2)
}

standings_button :: proc() {
	btn(8, H - 26, "STANDINGS", ID_STANDINGS)
}

// ---- drawing ----

draw :: proc() {
	gfx.clear(VELLUM)
	gfx.begin_buttons()
	switch app.screen {
	case .Setup:
		draw_setup()
	case .Pass:
		draw_pass()
	case .News:
		draw_news()
	case .Standings:
		draw_standings()
	case .Turn:
		draw_turn()
	}
	if app.msg_t > 0 {
		gfx.rect(W / 2 - 110, H - 56, 220, 18, INK)
		gfx.text_c(W / 2, H - 51, app.msg, VELLUM)
	}
}

draw_setup :: proc() {
	gfx.text_c(W / 2, 12, "SANTA PARAVIA", RED, 3)
	gfx.text_c(W / 2, 40, "AND FIUMACCIO", INK_DIM, 2)
	lines := [?]string {
		"YOU ARE THE RULER OF A 15TH CENTURY ITALIAN CITY-STATE.",
		"RULE WELL AND YOU WILL RISE IN TITLE. THE FIRST TO BE",
		"CROWNED KING OR QUEEN WINS; BUT LIFE THEN WAS BRIEF.",
	}
	for l, i in lines {gfx.text_c(W / 2, 62 + i * 10, l, INK)}

	y := 100
	gfx.text(16, y + 4, "RULERS", INK_DIM)
	btn(80, y, "-", ID_COUNT_DOWN)
	gfx.text(102, y + 4, fmt.tprintf("%d", app.count), INK)
	btn(116, y, "+", ID_COUNT_UP)
	gfx.text(160, y + 4, "LEVEL", INK_DIM)
	btn(208, y, fmt.tprintf("%d %s", app.level, sp.LEVELS[app.level]), ID_LEVEL)

	for i in 0 ..< app.count {
		s := app.slots[i]
		ry := 124 + i * 22
		gfx.text(16, ry + 4, sp.CITIES[i], INK)
		btn(140, ry, s.computer ? "COMPUTER" : "PERSON  ", ID_SLOT_KIND + i)
		btn(224, ry, s.female ? "WOMAN" : "MAN  ", ID_SLOT_SEX + i)
		btn(280, ry, slot_name(s), ID_SLOT_NAME + i)
		t := s.female ? sp.TITLES_F[1] : sp.TITLES_M[1]
		gfx.text(370, ry + 4, fmt.tprintf("%s %s", t, slot_name(s)), INK_DIM)
	}
	gfx.text(16, H - 22, "TAP A NAME FOR ANOTHER", INK_DIM)
	btn(W - 8 - 112, H - 30, "BEGIN", ID_START, 2)
}

draw_pass :: proc() {
	g := &app.g
	p := sp.cur(g)
	gfx.clear(NIGHT)
	gfx.text_c(W / 2, 90, fmt.tprintf("THE YEAR %d", g.year), GOLD, 2)
	gfx.text_c(W / 2, 130, ruler_line(p), VELLUM)
	gfx.text_c(W / 2, 150, "YOUR TURN. THE OTHERS LOOK AWAY.", VELLUM_DARK)
	continue_button("READY")
}

draw_news :: proc() {
	gfx.text_c(W / 2, 10, "NEWS FROM THE OTHER STATES", RED, 2)
	for i in 0 ..< app.news_n {
		line := app.news[i]
		head := len(line) > 0 && line[0] != ' '
		gfx.text(12, 34 + i * 10, line, head ? RED : INK)
	}
	continue_button("ON")
}

draw_standings :: proc() {
	g := &app.g
	gfx.text_c(W / 2, 8, "STANDINGS", RED, 2)
	// The listing's comparison table (lines 1000-1060).
	cols := [?]string{"NOBLES", "SOLDIERS", "CLERGY", "MERCHANTS", "SERFS", "LAND", "TREASURY"}
	xs := [?]int{64, 136, 192, 278, 336, 402, 500}
	y := 34
	for c, i in cols {rtext(xs[i], y, c, INK_DIM)}
	for k in 0 ..< g.count {
		p := &g.players[k]
		ry := y + 14 + k * 34
		c: u32 = p.alive ? INK : INK_DIM
		head := ruler_line(p)
		if !p.alive {head = fmt.tprintf("%s (DIED %d)", head, p.death_year)}
		gfx.text(8, ry, head, k == g.current ? RED : c)
		vals := [?]f64{f64(p.nobles), f64(p.soldiers), f64(p.clergy), f64(p.merchants), p.serfs, p.land, p.treasury}
		for v, i in vals {rtext(xs[i], ry + 11, num(v), c)}
		gfx.text(8, ry + 22, fmt.tprintf("MARKETS %d  MILLS %d  PALACE %d  CATHEDRAL %d", p.markets, p.mills, p.palaces, p.cathedrals), INK_DIM)
	}
	continue_button("BACK")
}

draw_turn :: proc() {
	g := &app.g
	switch g.phase {
	case .Market:
		draw_market()
	case .Release:
		draw_release()
	case .Report:
		draw_report()
	case .Taxes:
		draw_taxes()
	case .Bankrupt:
		draw_bankrupt()
	case .Map:
		draw_map_screen()
	case .Works:
		draw_works()
	case .Promoted:
		draw_promoted()
	case .Obituary:
		draw_obituary()
	case .Crowned, .Game_Over:
		draw_end()
	}
}

draw_market :: proc() {
	g := &app.g
	p := sp.cur(g)
	h := &g.harvest
	header()
	gfx.text(12, 28, "HARVEST TIME", RED, 2)
	gfx.text(12, 50, fmt.tprintf("RATS ATE %d%% OF YOUR GRAIN RESERVES.", h.rats), INK)
	gfx.text(12, 62, fmt.tprintf("%s (%s STERES)", sp.WEATHER[h.weather], num(h.harvested)), INK)
	// The steward's table (lines 2350-2380).
	heads1 := [?]string{"GRAIN", "GRAIN", "PRICE OF", "PRICE OF", "TREASURY"}
	heads2 := [?]string{"RESERVE", "DEMAND", "GRAIN/1000", "LAND / HA", ""}
	vals := [?]string {
		fmt.tprintf("%s ST", num(p.grain)),
		fmt.tprintf("%s ST", num(h.demand)),
		fmt.tprintf("%d FL", h.grain_price),
		fmt.tprintf("%.1f FL", h.land_price),
		fmt.tprintf("%s FL", num(p.treasury)),
	}
	gfx.rect(8, 76, W - 16, 44, VELLUM_DARK)
	for hd, i in heads1 {
		x := 12 + i * 100
		gfx.text(x, 80, hd, INK_DIM)
		gfx.text(x, 90, heads2[i], INK_DIM)
		gfx.text(x, 106, vals[i], i == 4 && p.treasury < 0 ? RED : INK)
	}
	gfx.text(12, 126, fmt.tprintf("YOU HOLD %s HECTARES.", num(p.land)), INK)
	short := h.demand - p.grain
	if short > 0 {
		gfx.text(220, 126, fmt.tprintf("RESERVES ARE %s ST SHORT OF DEMAND.", num(short)), RED)
	}

	// Grain.
	y := 144
	gfx.text(12, y + 4, "GRAIN", INK)
	stepper_row(64, y, ID_GRAIN_STEP)
	gfx.rect(64 + 3 * 42, y, 72, 16, 0xffffff)
	gfx.text(64 + 3 * 42 + 4, y + 4, num(f64(app.grain_amt)), INK)
	btn(64 + 6 * 42 + 80, y, "BUY", ID_BUY_GRAIN)
	btn(64 + 6 * 42 + 116, y, "SELL", ID_SELL_GRAIN)
	gfx.text(64, y + 20, fmt.tprintf("%s STERES FOR %s FLORINS", num(f64(app.grain_amt)), num(f64(app.grain_amt * h.grain_price) / 1000)), INK_DIM)

	// Land.
	y = 188
	gfx.text(12, y + 4, "LAND", INK)
	stepper_row(64, y, ID_LAND_STEP)
	gfx.rect(64 + 3 * 42, y, 72, 16, 0xffffff)
	gfx.text(64 + 3 * 42 + 4, y + 4, num(f64(app.land_amt)), INK)
	btn(64 + 6 * 42 + 80, y, "BUY", ID_BUY_LAND)
	btn(64 + 6 * 42 + 116, y, "SELL", ID_SELL_LAND)
	gfx.text(64, y + 20, fmt.tprintf("%s HECTARES FOR %s FLORINS (KEEP 5,000)", num(f64(app.land_amt)), num(f64(app.land_amt) * h.land_price)), INK_DIM)

	gfx.text(12, 234, "BUYING ON CREDIT IS ALLOWED. DEBT COSTS 50% INTEREST,", INK_DIM)
	gfx.text(12, 244, "AND TOO MUCH OF IT MEANS BANKRUPTCY.", INK_DIM)
	standings_button()
	continue_button("FEED THE PEOPLE")
}

// Three steps down, the box (drawn by the caller), three steps up.
stepper_row :: proc(x, y, id0: int) {
	for i in 0 ..< 3 {small_btn(x + i * 42, y, STEP_LABELS[i], id0 + i)}
	for i in 3 ..< 6 {small_btn(x + 3 * 42 + 76 + (i - 3) * 42, y, STEP_LABELS[i], id0 + i)}
}

small_btn :: proc(x, y: int, label: string, id: int) {
	gfx.rect(x, y, 40, 16, KEY)
	gfx.text_c(x + 20, y + 4, label, KEY_TEXT)
	gfx.zone(x, y, 40, 16, id)
}

draw_release :: proc() {
	g := &app.g
	p := sp.cur(g)
	h := &g.harvest
	header()
	gfx.text(12, 28, "THE PEOPLE MUST EAT", RED, 2)
	gfx.text(12, 52, "HOW MUCH GRAIN WILL YOU RELEASE FOR CONSUMPTION?", INK)
	gfx.text(12, 70, fmt.tprintf("RESERVES %s ST.  DEMAND %s ST.", num(p.grain), num(h.demand)), INK)
	gfx.text(12, 82, fmt.tprintf("YOU MUST RELEASE AT LEAST %s AND KEEP AT LEAST 20%%.", num(f64(sp.release_min(p)))), INK_DIM)

	y := 104
	stepper_row(64, y, ID_REL_STEP)
	gfx.rect(64 + 3 * 42, y, 72, 16, 0xffffff)
	gfx.text(64 + 3 * 42 + 4, y + 4, num(f64(app.release)), INK)
	btn(64, y + 24, "LEAST", ID_REL_MIN)
	btn(120, y + 24, "THE DEMAND", ID_REL_DEMAND)
	btn(216, y + 24, "PLENTY (+30%)", ID_REL_PLENTY)
	btn(336, y + 24, "MOST", ID_REL_MAX)

	// A bar: the release against the demand.
	bx, by, bw := 64, 162, 380
	full := max(f64(sp.release_max(p)), h.demand * 1.4)
	gfx.rect(bx, by, bw, 12, VELLUM_DARK)
	rel_w := int(f64(app.release) / full * f64(bw))
	ratio := f64(app.release) / max(h.demand, 1)
	col: u32 = ratio < 1 ? RED : ratio >= 1.3 ? GREEN : GOLD
	gfx.rect(bx, by, rel_w, 12, col)
	dx := bx + int(h.demand / full * f64(bw))
	gfx.rect(dx, by - 4, 2, 20, INK)
	gfx.text(dx - 24, by + 18, "DEMAND", INK_DIM)
	msg := ""
	switch {
	case ratio < 1:
		msg = "TOO LITTLE: SOME WILL STARVE, AND THE DEATH RATE WILL BE HIGH."
	case ratio >= 1.3:
		msg = "A LARGE SURPLUS: SERFS WILL COME TO SERVE YOU."
	case:
		msg = "ENOUGH TO FEED EVERYONE."
	}
	gfx.text(12, 200, msg, col == GOLD ? INK : col)
	gfx.text(12, 214, fmt.tprintf("THE REST, %s ST, STAYS IN RESERVE (AND SEED FOR NEXT YEAR).", num(p.grain - f64(app.release))), INK_DIM)
	standings_button()
	continue_button("RELEASE")
}

draw_report :: proc() {
	g := &app.g
	r := &g.report
	header()
	gfx.text(12, 28, "THE STATE OF THE STATE", RED, 2)
	y := 52
	line :: proc(y: ^int, s: string, c: u32 = INK) {
		gfx.text(12, y^, s, c)
		y^ += 13
	}
	if r.starving {line(&y, "THERE WAS NOT ENOUGH GRAIN. PEOPLE STARVED.", RED)}
	line(&y, fmt.tprintf("%s SERFS BORN THIS YEAR.", num(f64(r.born))))
	line(&y, fmt.tprintf("%s SERFS DIE THIS YEAR.", num(f64(r.died))), r.starving ? RED : INK)
	if r.migrants > 0 {line(&y, fmt.tprintf("%s SERFS MOVE TO THE CITY.", num(f64(r.migrants))), GREEN)}
	if r.new_merchants > 0 {line(&y, fmt.tprintf("%d MERCHANTS ARRIVE.", r.new_merchants), GREEN)}
	if r.new_nobles > 0 {line(&y, fmt.tprintf("%d NOBLES JOIN YOUR COURT.", r.new_nobles), GREEN)}
	if r.new_clergy > 0 {line(&y, fmt.tprintf("%d CLERGY COME TO YOUR CHURCHES.", r.new_clergy), GREEN)}
	if r.fled > 0 {line(&y, fmt.tprintf("%s SERFS FLEE HARSH JUSTICE.", num(f64(r.fled))), RED)}
	if r.market_rent > 0 {line(&y, fmt.tprintf("YOUR MARKETS EARNED %s FLORINS RENT.", num(f64(r.market_rent))))}
	if r.mill_income > 0 {line(&y, fmt.tprintf("YOUR WOOLEN MILLS EARNED %s FLORINS.", num(f64(r.mill_income))))}
	line(&y, fmt.tprintf("YOU PAID YOUR SOLDIERS %s FLORINS.", num(f64(r.soldiers_paid))))
	if r.invaded {
		y += 4
		line(&y, fmt.tprintf("%s INVADES", invader_name(r.invader)), RED)
		line(&y, fmt.tprintf("AND SEIZES %s HECTARES OF LAND!", num(f64(r.land_lost))), RED)
		line(&y, fmt.tprintf("YOU LOSE %d SOLDIERS IN BATTLE.", r.soldiers_lost), RED)
	}
	standings_button()
	continue_button("TO THE TAXES")
}

draw_taxes :: proc() {
	g := &app.g
	p := sp.cur(g)
	header()
	gfx.text(12, 28, "TAXES AND JUSTICE", RED, 2)
	rv := sp.project_revenue(p)
	names := [4]string{"CUSTOMS DUTY", "SALES TAX", "WEALTH TAX", "JUSTICE"}
	limits := [4]string{"0-100%", "0-50%", "0-25%", ""}
	vals := [4]string{fmt.tprintf("%d%%", p.customs), fmt.tprintf("%d%%", p.sales), fmt.tprintf("%d%%", p.wealth), sp.JUSTICE[p.justice]}
	brings := [4]int{rv.customs, rv.sales, rv.wealth, rv.justice}
	for k in 0 ..< 4 {
		y := 56 + k * 30
		gfx.text(12, y + 4, names[k], INK)
		gfx.text(12, y + 14, limits[k], INK_DIM)
		small_btn(130, y, "-", ID_TAX_DOWN + k)
		gfx.rect(172, y, 104, 16, 0xffffff)
		gfx.text(176, y + 4, vals[k], INK)
		small_btn(278, y, "+", ID_TAX_UP + k)
		rtext(440, y + 4, fmt.tprintf("%s FL", num(f64(brings[k]))), brings[k] < 0 ? RED : INK)
	}
	gfx.rect(12, 178, 428, 1, INK_DIM)
	gfx.text(12, 184, "STATE REVENUES", INK)
	rtext(440, 184, fmt.tprintf("%s GOLD FLORINS", num(f64(sp.revenue_total(rv)))), INK)
	gfx.text(12, 206, "HIGH TAXES RAISE MONEY, BUT SLOW DOWN ECONOMIC GROWTH.", INK_DIM)
	gfx.text(12, 218, "FAIR JUSTICE COSTS MONEY BUT IS MARVELOUS FOR THE ECONOMY;", INK_DIM)
	gfx.text(12, 230, "HARSH JUSTICE DRIVES SERFS AWAY.", INK_DIM)
	gfx.text(12, 242, "LOW CUSTOMS AND SALES TAXES BRING MERCHANTS.", INK_DIM)
	standings_button()
	continue_button("COLLECT")
}

draw_bankrupt :: proc() {
	g := &app.g
	header()
	gfx.text_c(W / 2, 90, fmt.tprintf("%s IS BANKRUPT", ruler_line(sp.cur(g))), RED)
	gfx.text_c(W / 2, 110, "CREDITORS HAVE SEIZED MUCH OF YOUR ASSETS:", INK)
	gfx.text_c(W / 2, 124, "EVERY BUILDING, AND ALL BUT 6,000 HECTARES.", INK)
	continue_button("ALAS")
}

draw_map_screen :: proc() {
	header()
	draw_map(sp.cur(&app.g), 8, 24)
	continue_button("PUBLIC WORKS")
	standings_button()
}

draw_works :: proc() {
	g := &app.g
	p := sp.cur(g)
	header()
	gfx.text(12, 28, "STATE PURCHASES", RED, 2)
	counts := [sp.Work]int{.Market = p.markets, .Mill = p.mills, .Palace = p.palaces, .Cathedral = p.cathedrals, .Soldiers = p.soldiers}
	for w in sp.Work {
		y := 54 + int(w) * 26
		btn(12, y, fmt.tprintf("%d", int(w) + 1), ID_WORK + int(w))
		gfx.text(36, y + 4, WORK_NAMES[w], INK)
		rtext(330, y + 4, fmt.tprintf("%s FLORINS", num(f64(sp.WORK_COST[w]))), INK)
		have := w == .Soldiers ? fmt.tprintf("%d SOLDIERS", counts[w]) : fmt.tprintf("HAVE %d", counts[w])
		gfx.text(350, y + 4, have, INK_DIM)
		gfx.zone(36, y, 300, 16, ID_WORK + int(w))
	}
	gfx.text(12, 190, fmt.tprintf("YOU HAVE %s GOLD FLORINS.", num(p.treasury)), p.treasury < 0 ? RED : INK)
	gfx.text(12, 204, "MARKETS BRING MERCHANTS, PALACES NOBLES, CATHEDRALS CLERGY.", INK_DIM)
	gfx.text(12, 216, "SOLDIERS ARE ARMED SERFS. THE TOWER ON THE MAP SHOWS IF", INK_DIM)
	gfx.text(12, 228, "YOU HAVE ENOUGH FOR YOUR LAND.", INK_DIM)
	if app.work_msg != "" {gfx.text(12, 246, app.work_msg, GREEN)}
	standings_button()
	continue_button("END THE YEAR")
}

draw_promoted :: proc() {
	g := &app.g
	p := sp.cur(g)
	header()
	gfx.text_c(W / 2, 80, "BY ORDER OF THE COURT", INK_DIM)
	gfx.text_c(W / 2, 100, fmt.tprintf("%s OF %s", p.name, sp.CITIES[p.city]), INK)
	gfx.text_c(W / 2, 116, "IS NOW", INK_DIM)
	gfx.text_c(W / 2, 134, sp.title_name(p), RED, 3)
	gfx.text_c(W / 2, 176, fmt.tprintf("(WAS %s)", sp.title_of(p, g.old_title)), INK_DIM)
	continue_button("HUZZAH")
}

draw_obituary :: proc() {
	g := &app.g
	p := sp.cur(g)
	gfx.clear(NIGHT)
	gfx.text_c(W / 2, 60, "VERY SAD NEWS", VELLUM_DARK, 2)
	gfx.text_c(W / 2, 100, fmt.tprintf("%s HAS JUST DIED", ruler_line(p)), VELLUM)
	gfx.text_c(W / 2, 116, sp.CAUSE_TEXT[p.cause], VELLUM)
	gfx.text_c(W / 2, 140, fmt.tprintf("IN THE YEAR %d.", g.year), VELLUM_DARK)
	continue_button("REST IN PEACE")
	standings_button()
}

draw_end :: proc() {
	g := &app.g
	if g.phase == .Crowned {
		p := &g.players[g.winner]
		gfx.text_c(W / 2, 20, "GAME OVER", INK_DIM, 2)
		gfx.text_c(W / 2, 46, fmt.tprintf("H.R.H. %s %s", sp.title_name(p), p.name), RED, 2)
		gfx.text_c(W / 2, 68, fmt.tprintf("OF %s WINS IN %d", sp.CITIES[p.city], g.year), INK)
		draw_map(p, 8, 84, true)
	} else {
		gfx.text_c(W / 2, 20, "GAME OVER", INK_DIM, 2)
		if g.winner >= 0 {
			p := &g.players[g.winner]
			gfx.text_c(W / 2, 50, "ALL THE RULERS HAVE DIED.", INK)
			gfx.text_c(W / 2, 66, fmt.tprintf("THE HIGHEST TITLE: %s %s OF %s.", sp.title_name(p), p.name, sp.CITIES[p.city]), RED)
		}
		for k in 0 ..< g.count {
			q := &g.players[k]
			gfx.text(40, 100 + k * 14, fmt.tprintf("%s, DIED %d", ruler_line(q), q.death_year), INK)
		}
	}
	btn(W - 8 - 128, H - 30, "NEW GAME", ID_NEW_GAME, 2)
}

// ---- the map (lines 5000-5530, drawn anew) ----

// A chunky picture like the TRS-80's block graphics: a 128 by 48 grid of cells.
CELLW :: 4
CELLH :: 4

MAP_SKY :: 0xa8c8e8
MAP_FIELD :: 0x9ab85a
MAP_FURROW :: 0x7a9a42
MAP_OUTSIDE :: 0xc8b878
MAP_WALL :: 0x6a5a4a
MAP_STONE :: 0xd8d0c0
MAP_ROOF :: 0xa83a2a
MAP_WOOD :: 0x7a4a2a

cell :: proc(ox, oy, cx, cy, w, h: int, c: u32) {
	gfx.rect(ox + cx * CELLW, oy + cy * CELLH, w * CELLW, h * CELLH, c)
}

draw_map :: proc(p: ^sp.Player, ox, oy: int, small := false) {
	rows := small ? 36 : 48
	// Outside the walls.
	cell(ox, oy, 0, 0, 124, rows, MAP_OUTSIDE)
	if small {return_map_small(p, ox, oy); return}
	// The wall's corner moves up and left as the land grows (as the listing's did).
	k := int(p.land / 1000)
	wx, wy: int
	switch {
	case k < 10:
		wx, wy = 80, 27
	case k < 30:
		wx, wy = 80, 27 - (k - 10)
	case k < 50:
		wx, wy = 60, 27 - (k - 30) / 2
	case k < 70:
		wx, wy = 40, 17 - (k - 50) / 3
	case k < 90:
		wx, wy = 20, 11 - (k - 70) / 4
	case k < 110:
		wx, wy = 6, 6 - (k - 90) / 10
	case:
		wx, wy = 2, 3
	}
	// Trees in the countryside outside the wall.
	for i in 0 ..< 24 {
		tx := (i * 37 + 11) % 118 + 2
		ty := (i * 23 + 5) % 40 + 4
		if tx + 3 >= wx && ty + 4 >= wy {continue}
		cell(ox, oy, tx, ty, 3, 2, 0x5a8a3a)
		cell(ox, oy, tx + 1, ty + 2, 1, 2, MAP_WOOD)
	}
	// The fields inside, with furrows.
	cell(ox, oy, wx, wy, 124 - wx, 48 - wy, MAP_FIELD)
	for r := wy + 2; r < 48; r += 3 {cell(ox, oy, wx + 1, r, 123 - wx, 1, MAP_FURROW)}
	cell(ox, oy, wx, wy, 124 - wx, 1, MAP_WALL)
	cell(ox, oy, wx, wy, 1, 48 - wy, MAP_WALL)
	for x := wx; x < 124; x += 2 {cell(ox, oy, x, wy - 1, 1, 1, MAP_WALL)} // crenels

	// The guard tower in the corner: its size shows the defences.
	land_k := p.land / 1000
	tx, ty := wx + 1, wy
	if f64(p.soldiers - 5) >= land_k {
		cell(ox, oy, tx, ty - 6, 6, 6, MAP_STONE)
		for i in 0 ..< 3 {cell(ox, oy, tx + i * 2, ty - 7, 1, 1, MAP_STONE)}
		cell(ox, oy, tx + 2, ty - 4, 2, 2, NIGHT)
	} else if f64(p.soldiers) / 2 >= land_k {
		cell(ox, oy, tx, ty - 3, 3, 3, MAP_STONE)
		cell(ox, oy, tx + 1, ty - 4, 1, 1, MAP_STONE)
	}

	// The ploughman and horse: up at the wall when there are serfs enough to farm it all.
	z := (p.serfs - f64(p.mills) * 100) * 5 / max(p.land, 1) * 10 + 1
	z = clamp(z, 1, 10)
	py := 46 - int(z / 10 * f64(46 - wy - 2))
	px := 104
	cell(ox, oy, px, py, 6, 2, MAP_WOOD) // the horse
	cell(ox, oy, px + 5, py - 1, 2, 2, MAP_WOOD)
	cell(ox, oy, px, py + 2, 1, 1, MAP_WOOD)
	cell(ox, oy, px + 5, py + 2, 1, 1, MAP_WOOD)
	cell(ox, oy, px - 3, py + 1, 2, 1, INK) // the plough
	cell(ox, oy, px - 5, py - 2, 1, 3, 0xe0c090) // the man
	cell(ox, oy, px - 5, py - 3, 1, 1, 0xf0d0b0)

	// The cathedral, built in stages (C+1, at most 7).
	stage := min(p.cathedrals + 1, 7)
	cx, cy := 92, 30
	if stage >= 2 {cell(ox, oy, cx, cy, 10, 8, MAP_STONE)}
	if stage >= 3 {cell(ox, oy, cx + 10, cy + 2, 4, 6, MAP_STONE)}
	if stage >= 4 {cell(ox, oy, cx + 2, cy - 4, 4, 4, MAP_STONE)}
	if stage >= 5 {cell(ox, oy, cx + 3, cy - 8, 2, 4, MAP_STONE)}
	if stage >= 6 {cell(ox, oy, cx + 3, cy - 10, 2, 2, GOLD)}
	if stage >= 7 {
		cell(ox, oy, cx + 4, cy + 3, 2, 5, NIGHT) // the great door
		cell(ox, oy, cx + 11, cy + 4, 2, 2, 0x4a6aa8) // a rose window
	}

	// The palace: wider with every part, a roof when it is whole.
	pw := min(p.palaces * 2, 18)
	if pw > 0 {
		cell(ox, oy, 70 - pw / 2, 32, pw, 6, MAP_STONE)
		for x := 70 - pw / 2 + 1; x < 70 + pw / 2 - 1; x += 3 {cell(ox, oy, x, 34, 1, 2, NIGHT)}
		if p.palaces >= 9 {cell(ox, oy, 70 - pw / 2 - 1, 30, pw + 2, 2, MAP_ROOF)}
	}

	// Markets along the bottom left, woolen mills along the bottom right.
	space := max(0, 100 - wx)
	nm := min(p.markets, space / 4)
	for i in 0 ..< nm {
		x := wx + 2 + i * 4
		cell(ox, oy, x, 42, 3, 2, MAP_ROOF)
		cell(ox, oy, x, 44, 1, 2, MAP_WOOD)
		cell(ox, oy, x + 2, 44, 1, 2, MAP_WOOD)
	}
	nd := min(p.mills, 6)
	for i in 0 ..< nd {
		x := 122 - (i + 1) * 4
		cell(ox, oy, x, 44, 3, 3, MAP_WOOD)
		cell(ox, oy, x + 1, 42, 1, 2, MAP_STONE)
	}

	// The legend, as the listing's instructions told it.
	ly := oy + 48 * CELLH + 4
	gfx.text(ox, ly, fmt.tprintf("THE WALL GROWS WITH YOUR LAND: %s HECTARES.", num(p.land)), INK)
	tower := "NO TOWER: TOO FEW SOLDIERS. EQUIP MORE!"
	if f64(p.soldiers - 5) >= land_k {tower = "A STRONG TOWER: YOUR DEFENCES ARE ADEQUATE."} else if f64(p.soldiers) / 2 >= land_k {tower = "A SMALL TOWER: YOUR DEFENCES ARE THIN."}
	gfx.text(ox, ly + 11, tower, INK)
	plough := z >= 10 ? "THE PLOUGHMAN REACHES THE WALL: ALL YOUR LAND IS IN USE." : "THE PLOUGHMAN IS SHORT OF THE WALL: YOU NEED MORE SERFS."
	gfx.text(ox, ly + 22, plough, INK)
}

// The end screen's smaller picture: just the buildings and the title.
return_map_small :: proc(p: ^sp.Player, ox, oy: int) {
	cell(ox, oy, 0, 24, 124, 12, MAP_FIELD)
	stage := min(p.cathedrals + 1, 7)
	if stage >= 2 {cell(ox, oy, 80, 16, 10, 8, MAP_STONE)}
	if stage >= 5 {cell(ox, oy, 83, 8, 2, 8, MAP_STONE)}
	pw := min(p.palaces * 2, 18)
	if pw > 0 {
		cell(ox, oy, 40 - pw / 2, 18, pw, 6, MAP_STONE)
		if p.palaces >= 9 {cell(ox, oy, 40 - pw / 2 - 1, 16, pw + 2, 2, MAP_ROOF)}
	}
	// A crown above it all.
	cell(ox, oy, 58, 4, 8, 3, GOLD)
	for i in 0 ..< 3 {cell(ox, oy, 58 + i * 3, 2, 2, 2, GOLD)}
	gfx.text(ox, oy + 36 * CELLH + 6, fmt.tprintf("MARKETS %d  MILLS %d  PALACE %d  CATHEDRAL %d  SERFS %s  LAND %s", p.markets, p.mills, p.palaces, p.cathedrals, num(p.serfs), num(p.land)), INK)
}
