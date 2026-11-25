package tarot

// Tarot. After "Tarot" by Frank B. Rowlett, Jr. (SoftSide, March 1979). From the listing: the
// 78-card "Egyptian" deck (22 Major Arcana under the names the listing prints, from The Magus to
// The Materialist; 16 Court Arcana, Youth, Queen, King and Horseman in Scepters, Cups, Coins and
// Swords; 40 Minor Arcana, one to ten in each suit) and the five-card "Yes or No" spread, dealt
// one at a time from right to left: the first two cards are the past, the centre card the
// present (the key card, which counts twice), the last two the future. A card right side up says
// yes, upside down no; more yeses than noes answers yes, a tie is uncertain. A Youth or King
// right side up is a man and upside down a woman, a Queen the other way round, each of a
// temperament by suit and rank (the listing's zodiac table); a Horseman is thoughts, good or bad.
// The meanings are written new.
// Pure rules: no platform imports.

CARDS :: 78
MAJORS :: 22
SPREAD :: 5

Kind :: enum {
	Major,
	Court,
	Minor,
}

Suit :: enum {
	Scepters,
	Cups,
	Coins,
	Swords,
}

Rank :: enum {
	Youth,
	Queen,
	King,
	Horseman,
}

SUIT_NAMES := [Suit]string{.Scepters = "SCEPTERS", .Cups = "CUPS", .Coins = "COINS", .Swords = "SWORDS"}
RANK_NAMES := [Rank]string{.Youth = "YOUTH", .Queen = "QUEEN", .King = "KING", .Horseman = "HORSEMAN"}
NUMBER_NAMES := [11]string{"", "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN", "EIGHT", "NINE", "TEN"}
ROMAN := [23]string{"", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX", "XXI", "XXII"}

// The listing's names for the Major Arcana.
MAJOR_NAMES := [MAJORS + 1]string {
	"",
	"THE MAGUS",
	"VEILED ISIS",
	"ISIS UNVEILED",
	"THE SOVEREIGN",
	"THE HIEROPHANT",
	"THE TWO PATHS",
	"THE CONQUEROR",
	"THE BALANCE",
	"THE SAGE",
	"THE WHEEL",
	"THE ENCHANTRESS",
	"THE MARTYR",
	"THE REAPER",
	"THE ALCHEMIST",
	"THE BLACK MAGICIAN",
	"LIGHTNING",
	"STAR",
	"MOON",
	"SUN",
	"SARCOPHAGUS",
	"ADEPT",
	"MATERIALIST",
}

Meaning :: struct {
	up, down: string,
}

// Written new: what each Major Arcanum says right side up and upside down.
MAJOR_MEANINGS := [MAJORS + 1]Meaning {
	{},
	{"A STRONG WILL GETS THE THING STARTED", "SKILL WASTED ON TRICKS"},
	{"SOMETHING HIDDEN IS LEARNED IN TIME", "A SECRET KEPT TOO LONG"},
	{"PLENTY, AND A PLAN THAT BEARS FRUIT", "A HARVEST PUT OFF"},
	{"FIRM GROUND AND THE AUTHORITY TO ACT", "A RULER WHO WILL NOT LISTEN"},
	{"GOOD COUNSEL FROM AN OLD HAND", "ADVICE THAT DOES NOT FIT"},
	{"A CHOICE MADE WITH AN OPEN HEART", "TORN BETWEEN TWO ROADS"},
	{"VICTORY FOR WHOEVER KEEPS GOING", "A CHARGE THAT RUNS OUT OF ROAD"},
	{"A FAIR SETTLEMENT, EVENLY WEIGHED", "THE SCALES TIP THE WRONG WAY"},
	{"PATIENCE AND A LAMP IN THE DARK", "TOO LONG ALONE WITH IT"},
	{"THE WHEEL TURNS UP: LUCK IS COMING", "THE WHEEL TURNS DOWN FOR NOW"},
	{"QUIET STRENGTH TAMES THE TROUBLE", "FORCE WHERE A KIND WORD WOULD DO"},
	{"A SACRIFICE THAT PAYS OFF LATER", "GIVING UP MORE THAN IT IS WORTH"},
	{"AN ENDING THAT CLEARS THE GROUND", "HOLDING ON TO WHAT IS FINISHED"},
	{"THE RIGHT MIXTURE: WAIT AND BLEND", "IMPATIENCE SPOILS THE BATCH"},
	{"A TEMPTATION SEEN FOR WHAT IT IS", "CAUGHT IN A BAD BARGAIN"},
	{"A SHOCK THAT BREAKS A FALSE IDEA", "SUDDEN UPSET, NOTHING LEARNED"},
	{"HOPE, AND A NIGHT THAT IS ENDING", "A WISH THAT IS ONLY A WISH"},
	{"TRUST YOUR DREAMS, CHECK YOUR MAPS", "FOG, WORRY AND WRONG TURNINGS"},
	{"JOY, HEALTH AND A CLEAR DAY", "A CLOUDY SPELL, SOON OVER"},
	{"AN OLD MATTER COMES BACK TO LIFE", "A CALL LEFT UNANSWERED"},
	{"MASTERY: THE JOB DONE WHOLE", "ALMOST, BUT NOT QUITE"},
	{"THE WORLD IN HAND, IF YOU KEEP IT", "THINGS THAT OWN THEIR OWNER"},
}

// The listing's temperaments: the twelve signs dealt round the suits, Kings first.
SIGNS := [12]string{"ARIES", "TAURUS", "GEMINI", "CANCER", "LEO", "VIRGO", "LIBRA", "SCORPIO", "SAGITTARIUS", "CAPRICORN", "AQUARIUS", "PISCES"}

sign_of :: proc(suit: Suit, rank: Rank) -> string {
	row := 0
	switch rank {
	case .King:
		row = 0
	case .Queen:
		row = 1
	case .Youth:
		row = 2
	case .Horseman:
		return ""
	}
	// the listing's suit numbers are Scepters 1, Cups 2, Coins 3, Swords 4
	return SIGNS[row * 4 + int(suit)]
}

// Written new: the Horsemen's thoughts.
HORSEMEN := [Suit]Meaning {
	.Scepters = {"THOUGHTS THAT GET BUSINESS DONE", "THOUGHTS THAT WORK AGAINST IT"},
	.Cups = {"THOUGHTS OF LOVE AND WELCOME", "THOUGHTS THAT COOL A FRIENDSHIP"},
	.Coins = {"THOUGHTS THAT ADD TO YOUR PURSE", "THOUGHTS OF AN UNFAIR GAIN"},
	.Swords = {"HONEST THOUGHTS, PLAINLY SAID", "DECEIT DRESSED AS ADVICE"},
}

// Written new: the Minor Arcana, one to ten in each suit.
MINORS := [Suit][11]Meaning {
	.Scepters = {
		{},
		{"A NEW VENTURE TAKES ROOT", "A START THAT STALLS"},
		{"A PARTNER WITH THE SAME AIM", "TWO PLANS PULLING APART"},
		{"WORK SENT OUT COMES BACK WELL", "A SHIPMENT DELAYED"},
		{"A JOB FINISHED AND CELEBRATED", "THE PARTY BEFORE THE WORK"},
		{"HEALTHY RIVALRY SHARPENS YOU", "SQUABBLES OVER NOTHING"},
		{"PRAISE AND A STEP UP", "CREDIT GIVEN TO ANOTHER"},
		{"HOLD YOUR GROUND AND YOU WIN", "OUTNUMBERED THIS TIME"},
		{"NEWS AND MOVEMENT, QUICKLY", "HASTE THAT MAKES WASTE"},
		{"STRENGTH HELD IN RESERVE", "TIRED OF STANDING GUARD"},
		{"A HEAVY LOAD, CARRIED HOME", "TAKING ON TOO MUCH"},
	},
	.Cups = {
		{},
		{"A FULL HEART AND A WARM HOME", "AN EMPTY CUP, FOR A WHILE"},
		{"A MEETING OF MINDS", "A QUARREL BETWEEN FRIENDS"},
		{"GOOD COMPANY AND A TOAST", "TOO MUCH OF A GOOD THING"},
		{"CONTENT, IF A LITTLE BORED", "MISSING WHAT IS OFFERED"},
		{"A LOSS, BUT NOT EVERYTHING", "REGRET OVER SPILT MILK"},
		{"AN OLD FRIEND, A HAPPY MEMORY", "LIVING TOO MUCH IN THE PAST"},
		{"MANY CHOICES: PICK ONE", "CASTLES IN THE AIR"},
		{"LEAVING SOMETHING FOR BETTER", "DRIFTING AWAY FOR NO REASON"},
		{"THE WISH IS GRANTED", "A WISH GRANTED TOO LITERALLY"},
		{"A HAPPY HOUSEHOLD", "A FAMILY AT ODDS"},
	},
	.Coins = {
		{},
		{"MONEY ARRIVES", "A DEAL THAT FALLS THROUGH"},
		{"JUGGLING BILLS, AND MANAGING", "A CHECK THAT BOUNCES"},
		{"PAID WELL FOR GOOD WORK", "SLOPPY WORK, SMALL PAY"},
		{"SAVINGS GROW", "TIGHT FISTS, NARROW LIFE"},
		{"HELP COMES IN HARD TIMES", "OUT IN THE COLD"},
		{"A GIFT GIVEN OR RECEIVED", "A LOAN WITH STRINGS"},
		{"PATIENCE BEFORE THE HARVEST", "WORK THAT DOES NOT PAY"},
		{"A SKILL LEARNED BRINGS INCOME", "CUTTING CORNERS"},
		{"COMFORT EARNED BY YOURSELF", "LIVING BEYOND YOUR MEANS"},
		{"WEALTH THAT LASTS", "A FAMILY SQUABBLE OVER MONEY"},
	},
	.Swords = {
		{},
		{"A CLEAR DECISION CUTS THROUGH", "A SHARP WORD REGRETTED"},
		{"A TRUCE, FOR NOW", "STALEMATE AND STUBBORNNESS"},
		{"A HURT THAT HEALS CLEAN", "AN OLD WOUND REOPENED"},
		{"REST BEFORE THE NEXT TRY", "RESTLESS AND WORN OUT"},
		{"WINNING THE POINT", "WINNING THE POINT, LOSING A FRIEND"},
		{"TROUBLE LEFT BEHIND", "TROUBLE PACKED IN THE BAGS"},
		{"A CLEVER WAY ROUND", "A PLAN TOO CLEVER BY HALF"},
		{"A KNOT THAT CAN BE UNTIED", "TIED UP BY YOUR OWN WORRIES"},
		{"A BAD NIGHT, A BETTER MORNING", "SLEEPLESS OVER NOTHING"},
		{"THE WORST IS OVER", "A SETBACK, NOT THE END"},
	},
}

// ---- cards: 0-21 Major (I-XXII), 22-37 Court, 38-77 Minor ----

Card :: struct {
	kind:   Kind,
	number: int, // Major I-XXII, Minor 1-10
	suit:   Suit,
	rank:   Rank,
}

card :: proc(id: int) -> Card {
	switch {
	case id < MAJORS:
		return {kind = .Major, number = id + 1}
	case id < MAJORS + 16:
		k := id - MAJORS
		return {kind = .Court, suit = Suit(k / 4), rank = Rank(k % 4)}
	}
	k := id - MAJORS - 16
	return {kind = .Minor, suit = Suit(k / 10), number = k % 10 + 1}
}

// The name as the card's label shows it (short enough for the reading panel).
card_name :: proc(id: int, buf: []u8) -> string {
	c := card(id)
	switch c.kind {
	case .Major:
		return join(buf, MAJOR_NAMES[c.number], " (", ROMAN[c.number], ")")
	case .Court:
		return join(buf, RANK_NAMES[c.rank], " OF ", SUIT_NAMES[c.suit])
	case .Minor:
		return join(buf, NUMBER_NAMES[c.number], " OF ", SUIT_NAMES[c.suit])
	}
	return ""
}

// What the card says, right side up or upside down.
card_meaning :: proc(id: int, upright: bool, buf: []u8) -> string {
	c := card(id)
	switch c.kind {
	case .Major:
		m := MAJOR_MEANINGS[c.number]
		return upright ? m.up : m.down
	case .Minor:
		m := MINORS[c.suit][c.number]
		return upright ? m.up : m.down
	case .Court:
		if c.rank == .Horseman {
			m := HORSEMEN[c.suit]
			return upright ? m.up : m.down
		}
		male := upright
		if c.rank == .Queen {male = !upright}
		who: string
		if c.rank == .Youth {who = male ? "A YOUNG MAN" : "A YOUNG WOMAN"} else {who = male ? "A MAN" : "A WOMAN"}
		s := sign_of(c.suit, c.rank)
		an := s[0] == 'A' ? " OF AN " : " OF A "
		return join(buf, who, an, s, " TEMPERAMENT")
	}
	return ""
}

join :: proc(buf: []u8, parts: ..string) -> string {
	n := 0
	for p in parts {
		for i in 0 ..< len(p) {
			if n < len(buf) {buf[n] = p[i]; n += 1}
		}
	}
	return string(buf[:n])
}

// ---- the reading ----

Answer :: enum {
	Pending,
	Yes,
	No,
	Uncertain,
}

// Spread slots left to right: 0-1 future, 2 present (the key), 3-4 past. Dealing runs 4 to 0.
SLOT_PLACE := [SPREAD]string{"FUTURE", "FUTURE", "PRESENT", "PAST", "PAST"}
KEY_SLOT :: 2

Reading :: struct {
	deck:    [CARDS]int,
	cards:   [SPREAD]int,
	upright: [SPREAD]bool,
	dealt:   int, // how many are face up
	yes, no: int,
	answer:  Answer,
	rng:     u64,
}

next_random :: proc(r: ^Reading) -> f32 {
	x := r.rng
	x ~= x << 13
	x ~= x >> 7
	x ~= x << 17
	r.rng = x
	return f32(x >> 40) / f32(1 << 24)
}

rand_int :: proc(r: ^Reading, n: int) -> int {
	return min(n - 1, int(next_random(r) * f32(n)))
}

new_reading :: proc(r: ^Reading, seed: u64) {
	r^ = {}
	r.rng = seed | 1
	for _ in 0 ..< 4 {next_random(r)}
	for i in 0 ..< CARDS {r.deck[i] = i}
	for i := CARDS - 1; i > 0; i -= 1 {
		j := rand_int(r, i + 1)
		r.deck[i], r.deck[j] = r.deck[j], r.deck[i]
	}
	for i in 0 ..< SPREAD {
		r.cards[i] = r.deck[i]
		r.upright[i] = next_random(r) < 0.5
	}
}

// The slot the next card goes to (right to left), or -1 when all are down.
next_slot :: proc(r: ^Reading) -> int {
	if r.dealt >= SPREAD {return -1}
	return SPREAD - 1 - r.dealt
}

is_dealt :: proc(r: ^Reading, slot: int) -> bool {
	return slot > SPREAD - 1 - r.dealt
}

// Turns the next card; returns its slot, or -1.
deal :: proc(r: ^Reading) -> int {
	s := next_slot(r)
	if s < 0 {return -1}
	r.dealt += 1
	if r.dealt == SPREAD {tally(r)}
	return s
}

tally :: proc(r: ^Reading) {
	r.yes, r.no = 0, 0
	for i in 0 ..< SPREAD {
		votes := i == KEY_SLOT ? 2 : 1
		if r.upright[i] {r.yes += votes} else {r.no += votes}
	}
	switch {
	case r.yes > r.no:
		r.answer = .Yes
	case r.no > r.yes:
		r.answer = .No
	case:
		r.answer = .Uncertain
	}
}
