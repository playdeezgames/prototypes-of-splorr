package elements

// Elements Quiz, gamified. After "Elements Quiz" by Roger W. Robitaille, Sr. (SoftSide, February
// 1979): the chemical elements by name, symbol, atomic number and atomic weight; three levels
// (Easy, Difficult, Impossible, each taking in the easier ones); four ways to be asked (the symbol
// for a name, the name for a symbol, the number for a name, the name for a number); a review chart;
// the missed ones asked again. New here, as with State Capital Quiz: four choices, a clock, three
// flasks (lives), streaks that multiply the score, and the table brought up to today's 118.
// Pure rules: no platform imports.

Element :: struct {
	name, symbol: string,
	weight:       string, // standard atomic weight, or [mass number] of the longest-lived isotope
}

// Index i is atomic number i + 1. American spellings, as in the magazine.
ELEMENTS := [118]Element {
	{"HYDROGEN", "H", "1.008"},
	{"HELIUM", "HE", "4.0026"},
	{"LITHIUM", "LI", "6.94"},
	{"BERYLLIUM", "BE", "9.0122"},
	{"BORON", "B", "10.81"},
	{"CARBON", "C", "12.011"},
	{"NITROGEN", "N", "14.007"},
	{"OXYGEN", "O", "15.999"},
	{"FLUORINE", "F", "18.998"},
	{"NEON", "NE", "20.180"},
	{"SODIUM", "NA", "22.990"},
	{"MAGNESIUM", "MG", "24.305"},
	{"ALUMINUM", "AL", "26.982"},
	{"SILICON", "SI", "28.085"},
	{"PHOSPHORUS", "P", "30.974"},
	{"SULFUR", "S", "32.06"},
	{"CHLORINE", "CL", "35.45"},
	{"ARGON", "AR", "39.95"},
	{"POTASSIUM", "K", "39.098"},
	{"CALCIUM", "CA", "40.078"},
	{"SCANDIUM", "SC", "44.956"},
	{"TITANIUM", "TI", "47.867"},
	{"VANADIUM", "V", "50.942"},
	{"CHROMIUM", "CR", "51.996"},
	{"MANGANESE", "MN", "54.938"},
	{"IRON", "FE", "55.845"},
	{"COBALT", "CO", "58.933"},
	{"NICKEL", "NI", "58.693"},
	{"COPPER", "CU", "63.546"},
	{"ZINC", "ZN", "65.38"},
	{"GALLIUM", "GA", "69.723"},
	{"GERMANIUM", "GE", "72.630"},
	{"ARSENIC", "AS", "74.922"},
	{"SELENIUM", "SE", "78.971"},
	{"BROMINE", "BR", "79.904"},
	{"KRYPTON", "KR", "83.798"},
	{"RUBIDIUM", "RB", "85.468"},
	{"STRONTIUM", "SR", "87.62"},
	{"YTTRIUM", "Y", "88.906"},
	{"ZIRCONIUM", "ZR", "91.224"},
	{"NIOBIUM", "NB", "92.906"},
	{"MOLYBDENUM", "MO", "95.95"},
	{"TECHNETIUM", "TC", "[97]"},
	{"RUTHENIUM", "RU", "101.07"},
	{"RHODIUM", "RH", "102.91"},
	{"PALLADIUM", "PD", "106.42"},
	{"SILVER", "AG", "107.87"},
	{"CADMIUM", "CD", "112.41"},
	{"INDIUM", "IN", "114.82"},
	{"TIN", "SN", "118.71"},
	{"ANTIMONY", "SB", "121.76"},
	{"TELLURIUM", "TE", "127.60"},
	{"IODINE", "I", "126.90"},
	{"XENON", "XE", "131.29"},
	{"CESIUM", "CS", "132.91"},
	{"BARIUM", "BA", "137.33"},
	{"LANTHANUM", "LA", "138.91"},
	{"CERIUM", "CE", "140.12"},
	{"PRASEODYMIUM", "PR", "140.91"},
	{"NEODYMIUM", "ND", "144.24"},
	{"PROMETHIUM", "PM", "[145]"},
	{"SAMARIUM", "SM", "150.36"},
	{"EUROPIUM", "EU", "151.96"},
	{"GADOLINIUM", "GD", "157.25"},
	{"TERBIUM", "TB", "158.93"},
	{"DYSPROSIUM", "DY", "162.50"},
	{"HOLMIUM", "HO", "164.93"},
	{"ERBIUM", "ER", "167.26"},
	{"THULIUM", "TM", "168.93"},
	{"YTTERBIUM", "YB", "173.05"},
	{"LUTETIUM", "LU", "174.97"},
	{"HAFNIUM", "HF", "178.49"},
	{"TANTALUM", "TA", "180.95"},
	{"TUNGSTEN", "W", "183.84"},
	{"RHENIUM", "RE", "186.21"},
	{"OSMIUM", "OS", "190.23"},
	{"IRIDIUM", "IR", "192.22"},
	{"PLATINUM", "PT", "195.08"},
	{"GOLD", "AU", "196.97"},
	{"MERCURY", "HG", "200.59"},
	{"THALLIUM", "TL", "204.38"},
	{"LEAD", "PB", "207.2"},
	{"BISMUTH", "BI", "208.98"},
	{"POLONIUM", "PO", "[209]"},
	{"ASTATINE", "AT", "[210]"},
	{"RADON", "RN", "[222]"},
	{"FRANCIUM", "FR", "[223]"},
	{"RADIUM", "RA", "[226]"},
	{"ACTINIUM", "AC", "[227]"},
	{"THORIUM", "TH", "232.04"},
	{"PROTACTINIUM", "PA", "231.04"},
	{"URANIUM", "U", "238.03"},
	{"NEPTUNIUM", "NP", "[237]"},
	{"PLUTONIUM", "PU", "[244]"},
	{"AMERICIUM", "AM", "[243]"},
	{"CURIUM", "CM", "[247]"},
	{"BERKELIUM", "BK", "[247]"},
	{"CALIFORNIUM", "CF", "[251]"},
	{"EINSTEINIUM", "ES", "[252]"},
	{"FERMIUM", "FM", "[257]"},
	{"MENDELEVIUM", "MD", "[258]"},
	{"NOBELIUM", "NO", "[259]"},
	{"LAWRENCIUM", "LR", "[266]"},
	{"RUTHERFORDIUM", "RF", "[267]"},
	{"DUBNIUM", "DB", "[268]"},
	{"SEABORGIUM", "SG", "[269]"},
	{"BOHRIUM", "BH", "[270]"},
	{"HASSIUM", "HS", "[269]"},
	{"MEITNERIUM", "MT", "[278]"},
	{"DARMSTADTIUM", "DS", "[281]"},
	{"ROENTGENIUM", "RG", "[282]"},
	{"COPERNICIUM", "CN", "[285]"},
	{"NIHONIUM", "NH", "[286]"},
	{"FLEROVIUM", "FL", "[289]"},
	{"MOSCOVIUM", "MC", "[290]"},
	{"LIVERMORIUM", "LV", "[293]"},
	{"TENNESSINE", "TS", "[294]"},
	{"OGANESSON", "OG", "[294]"},
}

Level :: enum {
	Easy,
	Difficult,
	Impossible,
}

// The level an element first comes in at (by atomic number).
EASY := [?]int{1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 22, 24, 25, 26, 27, 28, 29, 30, 47, 50, 53, 78, 79, 80, 82, 92}

level_of :: proc(number: int) -> Level {
	for n in EASY {if n == number {return .Easy}}
	if number <= 56 || (number >= 72 && number <= 88) || number == 90 || number == 94 {return .Difficult}
	return .Impossible
}

// How many elements a level asks (each takes in the easier ones).
level_size :: proc(l: Level) -> int {
	n := 0
	for i in 1 ..= len(ELEMENTS) {if level_of(i) <= l {n += 1}}
	return n
}

Mode :: enum {
	Name_To_Symbol,
	Symbol_To_Name,
	Name_To_Number,
	Number_To_Name,
}

CHOICES :: 4
LIVES :: 3
TIME_LIMIT :: 10.0
TIME_BONUS :: 10
STREAK_STEP :: 5
MAX_MULT :: 4
SWEEP_BONUS :: 500
LEVEL_POINTS := [Level]int{.Easy = 100, .Difficult = 150, .Impossible = 200}

Event :: enum {
	Right,
	Wrong,
	Timeout,
	Round_Over,
	Swept,
}

Game :: struct {
	level:       Level,
	mode:        Mode,
	deck:        [len(ELEMENTS)]int, // atomic numbers still to be answered, front first
	deck_len:    int,
	total:       int, // how many the level asks
	current:     int, // the atomic number asked about
	choices:     [CHOICES]int, // atomic numbers shown
	answered:    bool,
	picked:      int,
	clock:       f32,
	lives:       int,
	score:       int,
	streak:      int,
	best_streak: int,
	right:       int,
	missed:      [len(ELEMENTS) + 1]bool, // by atomic number: missed at least once
	over:        bool,
	last_gain:   int,
	events:      bit_set[Event],
	rng:         u64,
}

next_random :: proc(g: ^Game) -> f32 {
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

element :: proc(number: int) -> Element {return ELEMENTS[number - 1]}

new_game :: proc(g: ^Game, seed: u64, level: Level, mode: Mode) {
	g^ = {}
	g.rng = seed | 1
	g.level = level
	g.mode = mode
	g.lives = LIVES
	for i in 1 ..= len(ELEMENTS) {
		if level_of(i) <= level {
			g.deck[g.deck_len] = i
			g.deck_len += 1
		}
	}
	g.total = g.deck_len
	for i := g.deck_len - 1; i > 0; i -= 1 {
		j := rand_int(g, i + 1)
		g.deck[i], g.deck[j] = g.deck[j], g.deck[i]
	}
	ask(g)
}

multiplier :: proc(streak: int) -> int {
	return min(MAX_MULT, 1 + streak / STREAK_STEP)
}

// A wrong answer worth thinking about: for a number, one close by; for a symbol or a name, one
// that starts with the same letter when there is one in the level.
@(private)
decoy :: proc(g: ^Game) -> int {
	cur := g.current
	if g.mode == .Name_To_Number {
		limit := level_size(.Impossible)
		d := 1 + rand_int(g, 6)
		c := next_random(g) < 0.5 ? cur - d : cur + d
		if c < 1 || c > limit {c = cur + (cur - c)}
		return clamp(c, 1, limit)
	}
	look := g.mode == .Name_To_Symbol ? element(cur).symbol[0] : (g.mode == .Symbol_To_Name ? element(cur).symbol[0] : element(cur).name[0])
	if next_random(g) < 0.7 {
		for _ in 0 ..< 40 {
			c := 1 + rand_int(g, len(ELEMENTS))
			if level_of(c) > g.level {continue}
			e := element(c)
			key := g.mode == .Name_To_Symbol ? e.symbol[0] : e.name[0]
			if key == look {return c}
		}
	}
	for {
		c := 1 + rand_int(g, len(ELEMENTS))
		if level_of(c) <= g.level {return c}
	}
}

ask :: proc(g: ^Game) {
	g.current = g.deck[0]
	g.choices[0] = g.current
	for k in 1 ..< CHOICES {
		for {
			c := decoy(g)
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
}

// The clue, as the page shows it, and the words of a choice.
clue :: proc(g: ^Game, buf: []u8) -> string {
	e := element(g.current)
	switch g.mode {
	case .Name_To_Symbol, .Name_To_Number:
		return e.name
	case .Symbol_To_Name:
		return e.symbol
	case .Number_To_Name:
		return itoa(buf, g.current)
	}
	return ""
}

choice_text :: proc(g: ^Game, k: int, buf: []u8) -> string {
	e := element(g.choices[k])
	switch g.mode {
	case .Name_To_Symbol:
		return e.symbol
	case .Name_To_Number:
		return itoa(buf, g.choices[k])
	case .Symbol_To_Name, .Number_To_Name:
		return e.name
	}
	return ""
}

itoa :: proc(buf: []u8, n: int) -> string {
	i := len(buf)
	v := n
	if v == 0 {i -= 1; buf[i] = '0'}
	for v > 0 && i > 0 {
		i -= 1
		buf[i] = u8('0' + v % 10)
		v /= 10
	}
	return string(buf[i:])
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
		g.last_gain = LEVEL_POINTS[g.level] * multiplier(g.streak) + int(g.clock) * TIME_BONUS
		g.score += g.last_gain
		if !g.missed[g.current] {g.right += 1}
		g.events += {.Right}
		for i in 1 ..< g.deck_len {g.deck[i - 1] = g.deck[i]}
		g.deck_len -= 1
	} else {
		g.events += k < 0 ? {.Timeout} : {.Wrong}
		g.missed[g.current] = true
		g.streak = 0
		g.lives -= 1
		// "Re-quiz the ones missed": back into the deck a few places on.
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

next :: proc(g: ^Game) {
	if g.over || !g.answered {return}
	ask(g)
}

// Where an element sits in the periodic table: column 0-17 and row 0-8 (rows 7 and 8 are the
// lanthanides and actinides, drawn apart below the table).
table_place :: proc(n: int) -> (col, row: int) {
	switch {
	case n == 1:
		return 0, 0
	case n == 2:
		return 17, 0
	case n <= 4:
		return n - 3, 1
	case n <= 10:
		return n - 5 + 12, 1
	case n <= 12:
		return n - 11, 2
	case n <= 18:
		return n - 13 + 12, 2
	case n <= 36:
		return n - 19, 3
	case n <= 54:
		return n - 37, 4
	case n <= 56:
		return n - 55, 5
	case n <= 71:
		return n - 57 + 2, 7
	case n <= 86:
		return n - 72 + 3, 5
	case n <= 88:
		return n - 87, 6
	case n <= 103:
		return n - 89 + 2, 8
	}
	return n - 104 + 3, 6
}
