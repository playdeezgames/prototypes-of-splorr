package cribbage

// Cribbage: you against the computer, six-card two-handed cribbage to 121. After "Cribbage"
// (uncredited, SoftSide, October 1978): deal six, each throws two to the dealer's kitty (the
// crib), cut a starter (a Jack is two for the dealer, his heels), peg to 31 with GO, fifteens,
// pairs and runs, then count the non-dealer's hand, the dealer's hand and the kitty (fifteens,
// pairs, runs, flush, his nobs). Scores are checked the moment they are made, so the side
// that counts first wins a race past 120, as the listing's end-of-game logic says. The
// computer keeps the four cards worth most over every possible cut and plays the card that
// scores best now without handing over an easy fifteen or 31.
// Pure rules: no platform imports.

WIN :: 121
HAND :: 6
KEEP :: 4

YOU :: 0
CPU :: 1

Card :: distinct u8 // 0..51: suit = c / 13 (clubs, diamonds, hearts, spades), rank = c % 13 + 1

rank :: proc(c: Card) -> int {return int(c) % 13 + 1}
suit :: proc(c: Card) -> int {return int(c) / 13}
value :: proc(c: Card) -> int {return min(rank(c), 10)}
make_card :: proc(r, s: int) -> Card {return Card(s * 13 + r - 1)}

// ---- counting a hand ----

Count :: struct {
	fifteens: int, // points (2 each)
	pairs:    int,
	runs:     int,
	flush:    int,
	nobs:     int,
}

total :: proc(c: Count) -> int {
	return c.fifteens + c.pairs + c.runs + c.flush + c.nobs
}

count_hand :: proc(hand: [KEEP]Card, cut: Card, is_crib: bool) -> (c: Count) {
	all := [5]Card{hand[0], hand[1], hand[2], hand[3], cut}
	for mask in 1 ..< 32 {
		s := 0
		for i in 0 ..< 5 {if mask & (1 << uint(i)) != 0 {s += value(all[i])}}
		if s == 15 {c.fifteens += 2}
	}
	for i in 0 ..< 5 {
		for j in i + 1 ..< 5 {if rank(all[i]) == rank(all[j]) {c.pairs += 2}}
	}
	n: [15]int
	for x in all {n[rank(x)] += 1}
	r := 1
	for r <= 13 {
		if n[r] == 0 {
			r += 1
			continue
		}
		start := r
		mult := 1
		for r <= 13 && n[r] > 0 {
			mult *= n[r]
			r += 1
		}
		if r - start >= 3 {c.runs += (r - start) * mult}
	}
	s := suit(hand[0])
	if suit(hand[1]) == s && suit(hand[2]) == s && suit(hand[3]) == s {
		if suit(cut) == s {
			c.flush = 5
		} else if !is_crib {
			c.flush = 4
		}
	}
	for x in hand {
		if rank(x) == 11 && suit(x) == suit(cut) {c.nobs = 1}
	}
	return
}

// ---- pegging ----

Peg :: struct {
	fifteen:    bool,
	thirty_one: bool,
	pair:       int, // cards matched: 2 pair, 3 pair royal, 4 double pair royal
	run:        int, // run length (3 or more)
}

PAIR_POINTS := [5]int{0, 0, 2, 6, 12}

peg_points :: proc(p: Peg) -> int {
	n := PAIR_POINTS[p.pair] + p.run
	if p.fifteen {n += 2}
	if p.thirty_one {n += 2}
	return n
}

// What the last card played onto the pile scores.
score_pile :: proc(pile: []Card, count: int) -> (p: Peg) {
	p.fifteen = count == 15
	p.thirty_one = count == 31
	k := len(pile)
	if k >= 2 {
		m := 1
		for i := k - 2; i >= 0 && rank(pile[i]) == rank(pile[k - 1]); i -= 1 {m += 1}
		if m >= 2 {p.pair = m}
	}
	for n := k; n >= 3; n -= 1 {
		seen: [15]bool
		lo, hi := 14, 0
		ok := true
		for i in k - n ..< k {
			r := rank(pile[i])
			if seen[r] {
				ok = false
				break
			}
			seen[r] = true
			lo, hi = min(lo, r), max(hi, r)
		}
		if ok && hi - lo == n - 1 {
			p.run = n
			break
		}
	}
	return
}

// ---- the game ----

Phase :: enum {
	Discard, // you pick two for the kitty
	Peg,
	Show, // the counts, one by one
	Over,
}

Note_Kind :: enum {
	Peg, // a scoring play
	Go,
	Last_Card,
	His_Heels,
	Hand,
	Crib,
}

// The latest thing that scored (or a GO), for the page to show.
Note :: struct {
	who:    int,
	kind:   Note_Kind,
	points: int,
	peg:    Peg,
	count:  Count,
}

Event :: enum {
	Dealt,
	Cut,
	Played,
	Scored,
	Said_Go,
	Reset, // the count went back to 0
	Pegging_Done,
	Counted,
	Game_Over,
}

Game :: struct {
	phase:      Phase,
	dealer:     int,
	scores:     [2]int,
	backs:      [2]int, // where each back peg sits (the score before the last one)
	winner:     int,
	deck:       [52]Card,
	hands:      [2][HAND]Card,
	hand_len:   [2]int,
	cpu_throw:  [2]int, // indexes in the computer's six it will throw
	kept:       [2][KEEP]Card, // the four each keeps, for the show
	played:     [2][KEEP]bool,
	crib:       [KEEP]Card,
	cut:        Card,
	count:      int,
	pile:       [8]Card, // cards since the count was last reset
	pile_len:   int,
	played_all: [8]Card, // every card pegged this hand, in order, and who played it
	played_by:  [8]int,
	played_n:   int,
	turn:       int,
	said_go:    [2]bool,
	last:       int, // who played the last card
	show_step:  int, // 0 non-dealer, 1 dealer, 2 kitty; 3 done
	note:       Note,
	notes:      int, // how many notes so far (the page watches for a new one)
	events:     bit_set[Event],
	games:      int,
	rng:        u64,
}

next_random :: proc(g: ^Game) -> f32 {
	// xorshift64*
	x := g.rng
	x ~= x >> 12
	x ~= x << 25
	x ~= x >> 27
	g.rng = x
	return f32((x * 0x2545F4914F6CDD1D) >> 40) / f32(1 << 24)
}

rand_int :: proc(g: ^Game, n: int) -> int {
	return min(n - 1, int(next_random(g) * f32(n)))
}

new_game :: proc(g: ^Game, seed: u64) {
	g^ = {}
	g.rng = seed | 1
	g.winner = -1
	g.dealer = rand_int(g, 2)
	deal(g)
}

deal :: proc(g: ^Game) {
	for i in 0 ..< 52 {g.deck[i] = Card(i)}
	for i := 51; i > 0; i -= 1 {
		j := rand_int(g, i + 1)
		g.deck[i], g.deck[j] = g.deck[j], g.deck[i]
	}
	for p in 0 ..< 2 {
		for i in 0 ..< HAND {g.hands[p][i] = g.deck[p * HAND + i]}
		g.hand_len[p] = HAND
		sort_hand(g.hands[p][:])
		g.played[p] = {}
	}
	g.cut = g.deck[2 * HAND]
	g.count = 0
	g.pile_len = 0
	g.played_n = 0
	g.said_go = {}
	g.show_step = 0
	g.phase = .Discard
	a, b := choose_throw(g.hands[CPU], g.dealer == CPU)
	g.cpu_throw = {a, b}
	g.events += {.Dealt}
}

// Low to high by rank, then suit (how a hand is held).
sort_hand :: proc(h: []Card) {
	for i in 1 ..< len(h) {
		for j := i; j > 0 && key(h[j]) < key(h[j - 1]); j -= 1 {h[j], h[j - 1] = h[j - 1], h[j]}
	}
	key :: proc(c: Card) -> int {return rank(c) * 4 + suit(c)}
}

@(private)
add :: proc(g: ^Game, who, points: int, n: Note) -> bool {
	g.note = n
	g.note.who = who
	g.note.points = points
	g.notes += 1
	if points > 0 {
		g.backs[who] = g.scores[who]
		g.scores[who] = min(WIN, g.scores[who] + points)
		g.events += {.Scored}
	}
	if g.scores[who] >= WIN && g.phase != .Over {
		g.phase = .Over
		g.winner = who
		g.games += 1
		g.events += {.Game_Over}
		return true
	}
	return false
}

// Your two cards for the kitty (indexes into yer six). The computer's go in with them,
// the starter is turned, and pegging begins with the non-dealer.
discard :: proc(g: ^Game, a, b: int) -> bool {
	if g.phase != .Discard || a == b || a < 0 || b < 0 || a >= HAND || b >= HAND {return false}
	// The kitty: yours first, then the computer's.
	g.crib[0], g.crib[1] = g.hands[YOU][a], g.hands[YOU][b]
	g.crib[2], g.crib[3] = g.hands[CPU][g.cpu_throw[0]], g.hands[CPU][g.cpu_throw[1]]
	keep(g, YOU, a, b)
	keep(g, CPU, g.cpu_throw[0], g.cpu_throw[1])
	g.phase = .Peg
	g.turn = 1 - g.dealer
	g.events += {.Cut}
	if rank(g.cut) == 11 {
		add(g, g.dealer, 2, {kind = .His_Heels})
	}
	return true
}

@(private)
keep :: proc(g: ^Game, p, a, b: int) {
	k := 0
	for i in 0 ..< HAND {
		if i != a && i != b {
			g.kept[p][k] = g.hands[p][i]
			k += 1
		}
	}
	g.hand_len[p] = KEEP
	g.played[p] = {}
}

can_play :: proc(g: ^Game, p: int) -> bool {
	for i in 0 ..< KEEP {
		if !g.played[p][i] && g.count + value(g.kept[p][i]) <= 31 {return true}
	}
	return false
}

legal :: proc(g: ^Game, p, i: int) -> bool {
	return i >= 0 && i < KEEP && !g.played[p][i] && g.count + value(g.kept[p][i]) <= 31
}

cards_left :: proc(g: ^Game, p: int) -> int {
	n := 0
	for i in 0 ..< KEEP {if !g.played[p][i] {n += 1}}
	return n
}

// Is the game waiting on you to play a card?
your_play :: proc(g: ^Game) -> bool {
	return g.phase == .Peg && g.turn == YOU && can_play(g, YOU)
}

// You play card i of yer four.
play :: proc(g: ^Game, i: int) -> bool {
	if !your_play(g) || !legal(g, YOU, i) {return false}
	put(g, YOU, i)
	return true
}

@(private)
put :: proc(g: ^Game, p, i: int) {
	c := g.kept[p][i]
	g.played[p][i] = true
	g.count += value(c)
	g.pile[g.pile_len] = c
	g.pile_len += 1
	g.played_all[g.played_n] = c
	g.played_by[g.played_n] = p
	g.played_n += 1
	g.last = p
	g.events += {.Played}
	pg := score_pile(g.pile[:g.pile_len], g.count)
	if pts := peg_points(pg); pts > 0 {
		if add(g, p, pts, {kind = .Peg, peg = pg}) {return}
	}
	if g.count == 31 {reset(g)}
	g.turn = 1 - p
	if cards_left(g, YOU) == 0 && cards_left(g, CPU) == 0 {finish_pegging(g)}
}

@(private)
reset :: proc(g: ^Game) {
	g.count = 0
	g.pile_len = 0
	g.said_go = {}
	g.events += {.Reset}
}

@(private)
finish_pegging :: proc(g: ^Game) {
	if g.count > 0 {
		if add(g, g.last, 1, {kind = .Last_Card}) {return}
	}
	reset(g)
	g.phase = .Show
	g.show_step = 0
	g.events += {.Pegging_Done}
}

// One step of pegging that is not yer choice: the computer plays, someone says GO, or the
// count goes back to 0. Returns false when it is waiting on you (or pegging is over).
advance :: proc(g: ^Game) -> bool {
	if g.phase != .Peg || your_play(g) {return false}
	p := g.turn
	if can_play(g, p) {
		// It must be the computer's play.
		put(g, p, choose_play(g))
		return true
	}
	other := 1 - p
	if can_play(g, other) {
		if !g.said_go[p] {
			g.said_go[p] = true
			g.note = {who = p, kind = .Go}
			g.notes += 1
			g.events += {.Said_Go}
		}
		g.turn = other
		return true
	}
	// Neither can play: one for the last card, and the count starts again.
	if add(g, g.last, 1, {kind = .Go}) {return true}
	reset(g)
	g.turn = 1 - g.last
	return true
}

// The counts, in order: non-dealer's hand, dealer's hand, the kitty. Each call counts one.
show_next :: proc(g: ^Game) -> bool {
	if g.phase != .Show {return false}
	switch g.show_step {
	case 0, 1:
		who := g.show_step == 0 ? 1 - g.dealer : g.dealer
		c := count_hand(g.kept[who], g.cut, false)
		g.show_step += 1
		g.events += {.Counted}
		add(g, who, total(c), {kind = .Hand, count = c})
	case 2:
		c := count_hand(g.crib, g.cut, true)
		g.show_step += 1
		g.events += {.Counted}
		add(g, g.dealer, total(c), {kind = .Crib, count = c})
	case:
		// All counted: the deal passes.
		g.dealer = 1 - g.dealer
		deal(g)
	}
	return true
}

// ---- the computer ----

// Which two of six to throw: the keep worth most on average over every cut it cannot see,
// counting the two thrown as a gift to its own kitty or to yers.
choose_throw :: proc(six: [HAND]Card, own_crib: bool) -> (int, int) {
	best: f64 = -1e9
	ba, bb := 0, 1
	for a in 0 ..< HAND {
		for b in a + 1 ..< HAND {
			kept: [KEEP]Card
			k := 0
			for i in 0 ..< HAND {
				if i != a && i != b {
					kept[k] = six[i]
					k += 1
				}
			}
			sum := 0
			n := 0
			for c in 0 ..< 52 {
				cut := Card(c)
				seen := false
				for x in six {if x == cut {seen = true}}
				if seen {continue}
				sum += total(count_hand(kept, cut, false))
				n += 1
			}
			ev := f64(sum) / f64(n)
			gift := throw_value(six[a], six[b])
			ev += own_crib ? gift : -gift
			if ev > best {
				best = ev
				ba, bb = a, b
			}
		}
	}
	return ba, bb
}

// A rough worth of two cards in a kitty: what they make together, and the cards that combine well.
throw_value :: proc(a, b: Card) -> f64 {
	v := 0.0
	if rank(a) == rank(b) {v += 2}
	if value(a) + value(b) == 15 {v += 2}
	if abs(rank(a) - rank(b)) == 1 {v += 1}
	if abs(rank(a) - rank(b)) == 2 {v += 0.5}
	if rank(a) == 5 {v += 1}
	if rank(b) == 5 {v += 1}
	return v
}

// Which of its cards to play: what it scores now, less what it hands over.
choose_play :: proc(g: ^Game) -> int {
	best: f64 = -1e9
	bi := -1
	for i in 0 ..< KEEP {
		if !legal(g, CPU, i) {continue}
		c := g.kept[CPU][i]
		cnt := g.count + value(c)
		pile := g.pile
		pile[g.pile_len] = c
		gain := f64(peg_points(score_pile(pile[:g.pile_len + 1], cnt))) * 10
		// Counts that let a ten-card make 15 or 31.
		if cnt == 5 || cnt == 21 {gain -= 4}
		// Room for a card that makes 15 or 31 from here.
		if cnt < 15 && 15 - cnt <= 9 && cnt != 5 {gain -= 1}
		// Leading: something under 5 is safest.
		if g.count == 0 && value(c) < 5 {gain += 1.5}
		// Otherwise hold the low cards for the end of the count.
		gain += f64(value(c)) * 0.1
		if gain > best {
			best = gain
			bi = i
		}
	}
	return bi
}
