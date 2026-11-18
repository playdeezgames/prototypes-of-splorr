package capitals

// State Capital Quiz, gamified. After "State Capital Quiz" (uncredited, SoftSide, October 1978):
// a capital and three states to pick from, and a miss comes back later ("we will try that one
// again later"). New here, as with Morse Code Tutor: a clock on every question, three lives,
// streaks that multiply the score, a round that ends when all fifty are answered, and the
// other way round (a state and three capitals) as a second mode.
// Pure rules: no platform imports.

Place :: struct {
	state, capital: string,
}

PLACES := [50]Place {
	{"ALABAMA", "MONTGOMERY"},
	{"ALASKA", "JUNEAU"},
	{"ARIZONA", "PHOENIX"},
	{"ARKANSAS", "LITTLE ROCK"},
	{"CALIFORNIA", "SACRAMENTO"},
	{"COLORADO", "DENVER"},
	{"CONNECTICUT", "HARTFORD"},
	{"DELAWARE", "DOVER"},
	{"FLORIDA", "TALLAHASSEE"},
	{"GEORGIA", "ATLANTA"},
	{"HAWAII", "HONOLULU"},
	{"IDAHO", "BOISE"},
	{"ILLINOIS", "SPRINGFIELD"},
	{"INDIANA", "INDIANAPOLIS"},
	{"IOWA", "DES MOINES"},
	{"KANSAS", "TOPEKA"},
	{"KENTUCKY", "FRANKFORT"},
	{"LOUISIANA", "BATON ROUGE"},
	{"MAINE", "AUGUSTA"},
	{"MARYLAND", "ANNAPOLIS"},
	{"MASSACHUSETTS", "BOSTON"},
	{"MICHIGAN", "LANSING"},
	{"MINNESOTA", "ST. PAUL"},
	{"MISSISSIPPI", "JACKSON"},
	{"MISSOURI", "JEFFERSON CITY"},
	{"MONTANA", "HELENA"},
	{"NEBRASKA", "LINCOLN"},
	{"NEVADA", "CARSON CITY"},
	{"NEW HAMPSHIRE", "CONCORD"},
	{"NEW JERSEY", "TRENTON"},
	{"NEW MEXICO", "SANTA FE"},
	{"NEW YORK", "ALBANY"},
	{"NORTH CAROLINA", "RALEIGH"},
	{"NORTH DAKOTA", "BISMARCK"},
	{"OHIO", "COLUMBUS"},
	{"OKLAHOMA", "OKLAHOMA CITY"},
	{"OREGON", "SALEM"},
	{"PENNSYLVANIA", "HARRISBURG"},
	{"RHODE ISLAND", "PROVIDENCE"},
	{"SOUTH CAROLINA", "COLUMBIA"},
	{"SOUTH DAKOTA", "PIERRE"},
	{"TENNESSEE", "NASHVILLE"},
	{"TEXAS", "AUSTIN"},
	{"UTAH", "SALT LAKE CITY"},
	{"VERMONT", "MONTPELIER"},
	{"VIRGINIA", "RICHMOND"},
	{"WASHINGTON", "OLYMPIA"},
	{"WEST VIRGINIA", "CHARLESTON"},
	{"WISCONSIN", "MADISON"},
	{"WYOMING", "CHEYENNE"},
}

Mode :: enum {
	Capital_To_State, // the original: "... is the capital of what state?"
	State_To_Capital,
}

CHOICES :: 3
LIVES :: 3
TIME_LIMIT :: 8.0 // seconds a question
POINTS :: 100
TIME_BONUS :: 10 // per whole second left on the clock
STREAK_STEP :: 5 // every five in a row adds one to the multiplier
MAX_MULT :: 4
SWEEP_BONUS :: 500 // per life left when all fifty are done

Event :: enum {
	Right,
	Wrong,
	Timeout,
	Life_Lost,
	Round_Over,
	Swept,
}

Game :: struct {
	mode:      Mode,
	deck:      [64]int, // place indexes still to be answered, front first
	deck_len:  int,
	current:   int, // the place asked about
	choices:   [CHOICES]int, // place indexes shown, one of them current
	answered:  bool, // the current question is settled (the page shows the result)
	picked:    int, // the choice picked (-1 for a timeout)
	clock:     f32, // time left on this question
	lives:     int,
	score:     int,
	streak:    int,
	best_streak: int,
	right:     int, // first-time right answers
	asked:     int,
	over:      bool,
	last_gain: int,
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

new_game :: proc(g: ^Game, seed: u64, mode: Mode) {
	g^ = {}
	g.rng = seed | 1
	g.mode = mode
	g.lives = LIVES
	g.deck_len = len(PLACES)
	for i in 0 ..< len(PLACES) {g.deck[i] = i}
	for i := g.deck_len - 1; i > 0; i -= 1 {
		j := rand_int(g, i + 1)
		g.deck[i], g.deck[j] = g.deck[j], g.deck[i]
	}
	ask(g)
}

multiplier :: proc(streak: int) -> int {
	return min(MAX_MULT, 1 + streak / STREAK_STEP)
}

// Puts the question at the front of the deck up, with two other places as the wrong choices.
ask :: proc(g: ^Game) {
	g.current = g.deck[0]
	g.choices[0] = g.current
	for k in 1 ..< CHOICES {
		for {
			c := rand_int(g, len(PLACES))
			dup := false
			for j in 0 ..< k {if g.choices[j] == c {dup = true}}
			if !dup {
				g.choices[k] = c
				break
			}
		}
	}
	for i := CHOICES - 1; i > 0; i -= 1 {
		j := rand_int(g, i + 1)
		g.choices[i], g.choices[j] = g.choices[j], g.choices[i]
	}
	g.answered = false
	g.picked = -1
	g.clock = TIME_LIMIT
	g.asked += 1
}

// The words of the question and of each choice, for the current mode.
prompt :: proc(g: ^Game) -> string {
	p := PLACES[g.current]
	return g.mode == .Capital_To_State ? p.capital : p.state
}

choice_text :: proc(g: ^Game, k: int) -> string {
	p := PLACES[g.choices[k]]
	return g.mode == .Capital_To_State ? p.state : p.capital
}

correct_choice :: proc(g: ^Game) -> int {
	for c, k in g.choices {if c == g.current {return k}}
	return 0
}

update :: proc(g: ^Game, dt: f32) {
	if g.over || g.answered {return}
	g.clock -= dt
	if g.clock <= 0 {
		g.clock = 0
		settle(g, -1)
	}
}

answer :: proc(g: ^Game, k: int) -> bool {
	if g.over || g.answered || k < 0 || k >= CHOICES {return false}
	settle(g, k)
	return true
}

@(private)
settle :: proc(g: ^Game, k: int) {
	g.answered = true
	g.picked = k
	g.last_gain = 0
	if k >= 0 && g.choices[k] == g.current {
		g.streak += 1
		g.best_streak = max(g.best_streak, g.streak)
		g.last_gain = POINTS * multiplier(g.streak) + int(g.clock) * TIME_BONUS
		g.score += g.last_gain
		g.right += 1
		g.events += {.Right}
		// Answered: out of the deck for good.
		for i in 1 ..< g.deck_len {g.deck[i - 1] = g.deck[i]}
		g.deck_len -= 1
	} else {
		g.events += k < 0 ? {.Timeout} : {.Wrong}
		g.streak = 0
		g.lives -= 1
		g.events += {.Life_Lost}
		// "We will try that one again later": back into the deck a few places on.
		cur := g.deck[0]
		for i in 1 ..< g.deck_len {g.deck[i - 1] = g.deck[i]}
		at := min(g.deck_len - 1, 4 + rand_int(g, 5))
		for i := g.deck_len - 1; i > at; i -= 1 {g.deck[i] = g.deck[i - 1]}
		g.deck[at] = cur
	}
	if g.deck_len == 0 {
		g.over = true
		g.score += g.lives * SWEEP_BONUS
		g.events += {.Swept, .Round_Over}
	} else if g.lives <= 0 {
		g.over = true
		g.events += {.Round_Over}
	}
}

// After the page has shown the result: the next question.
next :: proc(g: ^Game) {
	if g.over || !g.answered {return}
	ask(g)
}
