package prizeboard

// Prize Board (a working name). After "Concentration" by Lance Micklus (SoftSide, February 1979),
// after the TV game show. From the listing: a board of 32 numbered squares hiding fifteen pairs of
// prizes and two wild cards; name two squares, and a pair (or a wild card with anything) wins the
// prize and a guess at the secret number 1 to 100 (too high or too low); after a guess the same
// player goes again; a miss passes the turn. When no pair can be made the round is a tie and
// nobody keeps its prizes; guessing the number wins the round, and only the winner keeps the
// round's prizes. Three rounds; the greater value wins; a tie plays a rubber round.
// New here: a computer contestant with a memory that slips, at three levels. The prize list is
// written new.
// Pure rules: no platform imports.

Prize :: struct {
	name:  string, // at most 10 letters: it is shown in a board square
	value: int,
}

WILD :: 0

PRIZES := [?]Prize {
	{"WILD CARD", 0},
	{"NEW CAR", 5200},
	{"SPORTS CAR", 8900},
	{"CAMPER VAN", 9400},
	{"MOTORCYCLE", 2100},
	{"SAILBOAT", 3800},
	{"CANOE", 290},
	{"TEN-SPEED", 180},
	{"MINIBIKE", 350},
	{"COLOR TV", 620},
	{"STEREO", 780},
	{"8-TRACK", 90},
	{"CB RADIO", 150},
	{"PINBALL", 900},
	{"JUKEBOX", 1400},
	{"COMPUTER", 1100},
	{"CALCULATOR", 30},
	{"CAMERA", 160},
	{"WRISTWATCH", 140},
	{"GOLD RING", 450},
	{"FUR COAT", 2400},
	{"WATERBED", 600},
	{"RECLINER", 330},
	{"PIANO", 2900},
	{"GUITAR", 260},
	{"DRUM KIT", 700},
	{"POOL TABLE", 1300},
	{"HOT TUB", 3100},
	{"BARBECUE", 120},
	{"LAWN MOWER", 210},
	{"SNOWBLOWER", 480},
	{"FRIDGE", 640},
	{"DISHWASHER", 380},
	{"MICROWAVE", 450},
	{"BLENDER", 35},
	{"TOASTER", 22},
	{"CROCK-POT", 25},
	{"FONDUE SET", 18},
	{"LAVA LAMP", 30},
	{"MOOD RING", 12},
	{"PET ROCK", 4},
	{"YO-YO", 1},
	{"KAZOO", 1},
	{"TACKS", 2},
	{"PARIS TRIP", 1900},
	{"SKI TRIP", 900},
	{"CRUISE", 2500},
	{"$1000 CASH", 1000},
	{"$1 CASH", 1},
	{"A HAM", 18},
}

SQUARES :: 32
PAIRS :: 15 // and two wild cards
ROUNDS :: 3
MAX_WON :: 17 // prizes one player can win in a round

Square :: struct {
	prize: int,
	gone:  bool, // matched and off the board
}

Player :: struct {
	cpu:        bool,
	won:        [MAX_WON]int, // prize indexes won this round
	n_won:      int,
	round_value: int,
	total:      int, // kept from rounds won
	rounds_won: int,
}

Phase :: enum {
	First, // pick the first square
	Second, // pick the second
	Miss, // both shown, no pair: the page shows them, then cont()
	Match, // a pair: the page shows it, then cont() to the guess
	Guess, // guess the secret number
	Guessed, // too high or too low: the page shows it, then cont()
	Round_Won,
	Round_Tied,
	Over,
}

Event :: enum {
	Reveal,
	Illegal,
	Match,
	Miss,
	Wild,
	Too_High,
	Too_Low,
	Right,
	Tie,
	Game_Over,
}

// What the computer remembers of the board and of the guesses.
Memory :: struct {
	known: [SQUARES]bool,
	lo, hi: int, // the secret number lies in lo..hi as far as it recalls
}

Game :: struct {
	board:     [SQUARES]Square,
	players:   [2]Player,
	turn:      int, // 0 or 1
	round:     int, // 1-based; past ROUNDS on a rubber round
	secret:    int,
	phase:     Phase,
	first, second: int, // squares shown this turn (-1 none)
	prize:     int, // the prize just won (-1 for two wild cards)
	last_guess: int,
	guesses:   int,
	winner:    int, // of the round, then of the game (-1 a tie)
	recall:    f32, // the computer's chance to remember what it sees
	mem:       Memory,
	events:    bit_set[Event],
	rng:       u64,
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

// recall 0 for two people; otherwise the second player is the computer.
new_game :: proc(g: ^Game, seed: u64, vs_cpu: bool, recall: f32 = 0.7) {
	g^ = {}
	g.rng = seed | 1
	g.players[1].cpu = vs_cpu
	g.recall = recall
	g.round = 0
	start_round(g)
}

start_round :: proc(g: ^Game) {
	g.round += 1
	for &p in g.players {
		p.n_won = 0
		p.round_value = 0
	}
	// Two wild cards and fifteen different prizes, each twice, shuffled.
	n := 0
	g.board[0] = {WILD, false}
	g.board[1] = {WILD, false}
	n = 2
	for n < SQUARES {
		pz := 1 + rand_int(g, len(PRIZES) - 1)
		dup := false
		for i in 0 ..< n {if g.board[i].prize == pz {dup = true}}
		if dup {continue}
		g.board[n] = {pz, false}
		g.board[n + 1] = {pz, false}
		n += 2
	}
	for i := SQUARES - 1; i > 0; i -= 1 {
		j := rand_int(g, i + 1)
		g.board[i], g.board[j] = g.board[j], g.board[i]
	}
	g.secret = 1 + rand_int(g, 100)
	g.mem = {lo = 1, hi = 100}
	g.guesses = 0
	g.winner = -1
	g.turn = (g.round - 1) % 2 // the rounds take turns going first
	begin_turn(g)
}

@(private)
begin_turn :: proc(g: ^Game) {
	g.phase = .First
	g.first, g.second = -1, -1
	g.prize = -1
}

// Picks a square for the phase (First or Second). False for an illegal pick ("SORRY, I CAN'T
// SHOW YOU THAT."): off the board, already won, or the first square again.
pick :: proc(g: ^Game, sq: int) -> bool {
	if g.phase != .First && g.phase != .Second {return false}
	if sq < 0 || sq >= SQUARES || g.board[sq].gone || sq == g.first {
		g.events += {.Illegal}
		return false
	}
	g.events += {.Reveal}
	see(g, sq)
	if g.phase == .First {
		g.first = sq
		g.phase = .Second
		return true
	}
	g.second = sq
	a, b := g.board[g.first].prize, g.board[sq].prize
	if a == b || a == WILD || b == WILD {
		g.phase = .Match
		g.events += {.Match}
		if a == WILD || b == WILD {g.events += {.Wild}}
		g.prize = a == WILD ? b : a
		if g.prize == WILD {g.prize = -1} // two wild cards: no prize, but a guess
	} else {
		g.phase = .Miss
		g.events += {.Miss}
	}
	return true
}

// The computer sees every square shown, and may keep it.
@(private)
see :: proc(g: ^Game, sq: int) {
	if g.players[1].cpu && next_random(g) < g.recall {g.mem.known[sq] = true}
}

// After the page has shown a Miss, a Match or a Guessed result.
cont :: proc(g: ^Game) {
	#partial switch g.phase {
	case .Miss:
		g.turn = 1 - g.turn
		begin_turn(g)
		check_possible(g)
	case .Match:
		g.board[g.first].gone = true
		g.board[g.second].gone = true
		g.mem.known[g.first] = false
		g.mem.known[g.second] = false
		p := &g.players[g.turn]
		if g.prize > 0 && p.n_won < MAX_WON {
			p.won[p.n_won] = g.prize
			p.n_won += 1
			p.round_value += PRIZES[g.prize].value
		}
		g.phase = .Guess
	case .Guessed:
		// "BUT YOU STILL GET ANOTHER TURN."
		begin_turn(g)
		check_possible(g)
	}
}

// "MAKE SURE THERE IS AT LEAST 1 MATCH POSSIBLE", else the round is a tie and nobody keeps it.
check_possible :: proc(g: ^Game) {
	if !match_possible(g) {
		g.phase = .Round_Tied
		g.winner = -1
		g.events += {.Tie}
		end_round(g)
	}
}

match_possible :: proc(g: ^Game) -> bool {
	counts: [len(PRIZES)]int
	for s in g.board {if !s.gone {counts[s.prize] += 1}}
	for c, pz in counts {
		if pz == WILD {
			if c >= 2 {return true}
		} else if c > 0 && c + counts[WILD] >= 2 {return true}
	}
	return false
}

// A guess at the secret number.
guess :: proc(g: ^Game, n: int) -> bool {
	if g.phase != .Guess || n < 1 || n > 100 {return false}
	g.last_guess = n
	g.guesses += 1
	// The computer hears every guess and may keep what it learns.
	if g.players[1].cpu && (g.turn == 1 || next_random(g) < g.recall) {
		if n > g.secret {g.mem.hi = min(g.mem.hi, n - 1)}
		if n < g.secret {g.mem.lo = max(g.mem.lo, n + 1)}
	}
	if n == g.secret {
		g.events += {.Right}
		g.winner = g.turn
		g.phase = .Round_Won
		end_round(g)
	} else {
		g.events += n > g.secret ? {.Too_High} : {.Too_Low}
		g.phase = .Guessed
	}
	return true
}

@(private)
end_round :: proc(g: ^Game) {
	if g.winner >= 0 {
		w := &g.players[g.winner]
		w.total += w.round_value
		w.rounds_won += 1
	}
}

// The value a player has banked so far (rounds won).
standing :: proc(g: ^Game, p: int) -> int {return g.players[p].total}

// After the page has shown the round's end and the prizes: the next round, or the end.
// "IF THEY TIE, WE PLAY A RUBBER MATCH."
next_round :: proc(g: ^Game) {
	if g.phase != .Round_Won && g.phase != .Round_Tied {return}
	if g.round >= ROUNDS && g.players[0].total != g.players[1].total {
		g.phase = .Over
		g.winner = g.players[0].total > g.players[1].total ? 0 : 1
		g.events += {.Game_Over}
		return
	}
	// A rubber round decides it even when its prizes come to nothing (two wild cards).
	if rubber(g) && g.winner >= 0 {
		g.phase = .Over
		g.events += {.Game_Over}
		return
	}
	start_round(g)
}

rubber :: proc(g: ^Game) -> bool {return g.round > ROUNDS}

// ---- the computer contestant ----

// The square the computer picks now.
cpu_pick :: proc(g: ^Game) -> int {
	if g.phase == .First {
		// A pair it knows of (or a wild card it knows with a prize it knows), best prize first.
		best, a, b := -1, -1, -1
		for i in 0 ..< SQUARES {
			if g.board[i].gone || !g.mem.known[i] {continue}
			for j in i + 1 ..< SQUARES {
				if g.board[j].gone || !g.mem.known[j] {continue}
				pi, pj := g.board[i].prize, g.board[j].prize
				if pi == pj || pi == WILD || pj == WILD {
					v := PRIZES[pi == WILD ? pj : pi].value
					if v > best {best, a, b = v, i, j}
				}
			}
		}
		if a >= 0 {
			_ = b
			// Open with the prize square, keep the wild card for the second.
			return g.board[a].prize == WILD ? b : a
		}
		return unknown_square(g, -1)
	}
	// Second: the partner it remembers, else a wild card it remembers, else a fresh square.
	fp := g.board[g.first].prize
	for i in 0 ..< SQUARES {
		if i == g.first || g.board[i].gone || !g.mem.known[i] {continue}
		if fp == WILD || g.board[i].prize == fp {return i}
	}
	for i in 0 ..< SQUARES {
		if i == g.first || g.board[i].gone || !g.mem.known[i] {continue}
		if g.board[i].prize == WILD {return i}
	}
	return unknown_square(g, g.first)
}

// A square it does not remember (any square left if it remembers them all).
@(private)
unknown_square :: proc(g: ^Game, not: int) -> int {
	cand: [SQUARES]int
	n := 0
	for i in 0 ..< SQUARES {
		if i != not && !g.board[i].gone && !g.mem.known[i] {cand[n] = i; n += 1}
	}
	if n == 0 {
		for i in 0 ..< SQUARES {
			if i != not && !g.board[i].gone {cand[n] = i; n += 1}
		}
	}
	if n == 0 {return -1}
	return cand[rand_int(g, n)]
}

// The number the computer guesses: halfway through what it recalls, a little off when it is
// forgetful.
cpu_guess :: proc(g: ^Game) -> int {
	lo, hi := g.mem.lo, g.mem.hi
	if lo > hi {lo, hi = 1, 100}
	mid := (lo + hi) / 2
	slop := int(f32(hi - lo) * (1 - g.recall) * 0.5)
	if slop > 0 {mid += rand_int(g, 2 * slop + 1) - slop}
	return clamp(mid, lo, hi)
}
