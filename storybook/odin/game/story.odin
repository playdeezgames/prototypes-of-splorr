package storybook

// Storybook: a toy that tells a child a story with them in it. After "Storybook" by Otto Hansen
// (SoftSide, August 1979): it asks the child's name and age, friends, pet, favourite colour and
// lucky number, a wild animal they like and one they don't, then weaves them into an adventure
// (roads, trails, plains, caves, a desert of cactuses; shells, golden bricks, lollipops and
// gumdrops) that always ends happily at home, at a reading speed the grown-up picks. The words
// here are new. Pure rules: no platform imports.

Answers :: struct {
	name, friend1, friend2, pet, color, like, dislike: string,
	age, number: int,
	pronoun: Pronoun,
}

Pronoun :: enum {
	They,
	She,
	He,
}

Setting :: enum {
	Home,
	Road,
	Trail,
	Plains,
	Cave,
	Desert,
	Beach,
	Woods,
}

Vehicle :: enum {
	Feet,
	Skates,
	Balloon,
	Wagon,
	Carpet,
	Boat,
}

// What the picture on a page shows.
Scene :: struct {
	setting:  Setting,
	vehicle:  Vehicle,
	friends:  bool, // the child's two friends
	pet:      bool,
	like:     bool, // the animal they like
	dislike:  bool, // the one they don't
	treasure: bool,
	night:    bool,
}

MAX_PAGES :: 10
PAGE_TEXT :: 360

Page :: struct {
	text:  [PAGE_TEXT]u8,
	len:   int,
	scene: Scene,
}

Story :: struct {
	pages:    [MAX_PAGES]Page,
	count:    int,
	treasure: Treasure,
	setting:  Setting,
	vehicle:  Vehicle,
}

Treasure :: struct {
	one, many: string,
}

TREASURES := [?]Treasure {
	{"LOLLIPOP", "LOLLIPOPS"},
	{"GUMDROP", "GUMDROPS"},
	{"PEARLY SHELL", "PEARLY SHELLS"},
	{"GOLDEN BRICK", "GOLDEN BRICKS"},
	{"SHINY MARBLE", "SHINY MARBLES"},
	{"SPARKLY STONE", "SPARKLY STONES"},
	{"STRIPY CANDY CANE", "STRIPY CANDY CANES"},
}

OPENINGS := [?]string {
	"ONCE UPON A TIME,",
	"LONG, LONG AGO,",
	"NOT SO VERY LONG AGO,",
	"IN A TIME OF MAGIC AND WONDER,",
	"THEY SAY, IN QUIET WHISPERS, THAT",
	"WAY BACK, BEFORE ANYONE CAN REMEMBER,",
}

VEHICLE_PHRASES := [Vehicle]string {
	.Feet    = "ON FOOT, SINGING A MARCHING SONG",
	.Skates  = "ON A PAIR OF MAGIC ROLLER SKATES",
	.Balloon = "IN A BIG STRIPY HOT-AIR BALLOON",
	.Wagon   = "IN A RED WAGON THAT PULLED ITSELF",
	.Carpet  = "ON A FLYING CARPET WITH TASSELS",
	.Boat    = "IN A LITTLE BOAT WITH A PATCHED SAIL",
}

SETTING_PHRASES := [Setting]string {
	.Home   = "",
	.Road   = "DOWN A LONG AND RAMBLING ROAD",
	.Trail  = "ALONG A WINDING, TWISTY TRAIL",
	.Plains = "ACROSS THE ROLLING GRASSY PLAINS",
	.Cave   = "INTO A DEEP, DARK, ECHOING CAVE",
	.Desert = "THROUGH A DESERT FULL OF PRICKLY CACTUSES",
	.Beach  = "OVER THE WARM SAND OF A WIDE BEACH",
	.Woods  = "INTO THE WHISPERING WOODS",
}

Rng :: struct {
	s: u64,
}

rand_n :: proc(r: ^Rng, n: int) -> int {
	x := r.s
	x ~= x >> 12
	x ~= x << 25
	x ~= x >> 27
	r.s = x
	return int(u32((x * 0x2545F4914F6CDD1D) >> 32) % u32(n))
}

pick :: proc(r: ^Rng, options: []string) -> string {
	return options[rand_n(r, len(options))]
}

// ---- text building ----

Builder :: struct {
	page: ^Page,
}

put :: proc(b: Builder, s: string) {
	p := b.page
	for i in 0 ..< len(s) {
		if p.len < PAGE_TEXT {
			p.text[p.len] = s[i]
			p.len += 1
		}
	}
}

starts_with_vowel :: proc(s: string) -> bool {
	if len(s) == 0 {return false}
	switch s[0] {
	case 'A', 'E', 'I', 'O', 'U':
		return true
	}
	return false
}

article :: proc(s: string) -> string {return starts_with_vowel(s) ? "AN " : "A "}

// Expands a template: {N} name, {F1} {F2} friends, {P} pet, {C} colour, {L} liked animal,
// {D} disliked one, {AL} {AD} the same with "A"/"AN", {T} {TM} {TR} they/them/their,
// {X} the lucky number of treasures ("7 RED GUMDROPS"), {AGE}.
expand :: proc(b: Builder, tpl: string, a: ^Answers, st: ^Story) {
	i := 0
	for i < len(tpl) {
		if tpl[i] != '{' {
			put(b, tpl[i:i + 1])
			i += 1
			continue
		}
		j := i + 1
		for j < len(tpl) && tpl[j] != '}' {j += 1}
		tok := tpl[i + 1:j]
		i = j + 1
		switch tok {
		case "N":
			put(b, a.name)
		case "F1":
			put(b, a.friend1)
		case "F2":
			put(b, a.friend2)
		case "P":
			put(b, a.pet)
		case "C":
			put(b, a.color)
		case "L":
			put(b, a.like)
		case "D":
			put(b, a.dislike)
		case "AL":
			put(b, article(a.like))
			put(b, a.like)
		case "AD":
			put(b, article(a.dislike))
			put(b, a.dislike)
		case "T":
			put(b, PRONOUNS[a.pronoun][0])
		case "TM":
			put(b, PRONOUNS[a.pronoun][1])
		case "TR":
			put(b, PRONOUNS[a.pronoun][2])
		case "AGE":
			put_int(b, a.age)
		case "X":
			put_int(b, a.number)
			put(b, " ")
			put(b, a.color)
			put(b, " ")
			put(b, a.number == 1 ? st.treasure.one : st.treasure.many)
		}
	}
}

PRONOUNS := [Pronoun][3]string {
	.They = {"THEY", "THEM", "THEIR"},
	.She  = {"SHE", "HER", "HER"},
	.He   = {"HE", "HIM", "HIS"},
}

put_int :: proc(b: Builder, n: int) {
	buf: [12]u8
	i := len(buf)
	v := n
	if v <= 0 {
		put(b, "0")
		return
	}
	for v > 0 && i > 0 {
		i -= 1
		buf[i] = u8('0' + v % 10)
		v /= 10
	}
	put(b, string(buf[i:]))
}

new_page :: proc(st: ^Story, scene: Scene) -> Builder {
	p := &st.pages[st.count]
	p^ = {}
	p.scene = scene
	st.count += 1
	return {p}
}

page_text :: proc(p: ^Page) -> string {return string(p.text[:p.len])}

// ---- the story ----

// Everything is past tense, so "THEY RAN" and "SHE RAN" read the same.
tell :: proc(st: ^Story, a: ^Answers, r: ^Rng) {
	st^ = {}
	st.treasure = TREASURES[rand_n(r, len(TREASURES))]
	st.setting = Setting(1 + rand_n(r, len(Setting) - 1))
	st.vehicle = Vehicle(rand_n(r, len(Vehicle)))
	s := st.setting
	v := st.vehicle
	everyone := Scene{setting = s, vehicle = v, friends = true, pet = true}

	b := new_page(st, {setting = .Home, pet = true})
	put(b, pick(r, OPENINGS[:]))
	expand(b, pick(r, []string {
			" IN A HOUSE WITH A CROOKED CHIMNEY, THERE LIVED {N}, WHO WAS {AGE} YEARS OLD, AND A PET {P} WHO WAS NEVER FAR AWAY.",
			" AT THE END OF A STREET LINED WITH APPLE TREES, THERE LIVED {N}, AGED {AGE}, WITH A VERY GOOD PET {P}.",
			" IN A COSY LITTLE HOUSE WITH A {C} DOOR, THERE LIVED {N}, WHO WAS {AGE}, AND {TR} PET {P}.",
		}), a, st)

	b = new_page(st, {setting = .Home, friends = true, pet = true})
	expand(b, pick(r, []string {
			"ONE SUNNY MORNING {N}'S BEST FRIEND {F1} CAME KNOCKING, WITH {F2} RIGHT BEHIND. \"LET'S GO ON AN ADVENTURE!\" THEY SAID. SO {N} PACKED A SANDWICH, AND THE {P} JUMPED FOR JOY.",
			"ONE DAY A LETTER CAME FLUTTERING THROUGH THE WINDOW. IT SAID: \"A TREASURE IS WAITING FOR {N}!\" {N} RAN TO TELL {F1} AND {F2}, AND OFF THEY ALL WENT TO FIND IT, WITH THE {P} TOO.",
			"ONE MORNING {N} FOUND A MAP UNDER THE BED. AN X WAS MARKED ON IT IN {C} CRAYON. {N} CALLED {F1} AND {F2}, WHISTLED FOR THE {P}, AND THE ADVENTURE BEGAN.",
		}), a, st)

	b = new_page(st, everyone)
	expand(b, "THEY SET OFF ", a, st)
	put(b, VEHICLE_PHRASES[v])
	put(b, ", ")
	put(b, SETTING_PHRASES[s])
	put(b, ". ")
	expand(b, pick(r, []string {
			"{F2} COUNTED EVERY BIRD THEY SAW, AND {F1} TOLD SILLY JOKES ALL THE WAY.",
			"THE {P} RAN AHEAD AND THEN RAN BACK, AS IF TO SAY \"HURRY UP!\"",
			"{N} HELD THE MAP UPSIDE DOWN FOR A WHILE, BUT NOBODY MINDED A BIT.",
		}), a, st)

	b = new_page(st, {setting = s, vehicle = v, friends = true, pet = true, like = true})
	expand(b, pick(r, []string {
			"SOON THEY MET {AL}, WHO WAS VERY FRIENDLY. \"WHERE ARE YOU GOING?\" ASKED THE {L}. \"TO FIND A TREASURE,\" SAID {N}. \"THEN I WILL SHOW YOU THE WAY,\" SAID THE {L}.",
			"BEHIND A BIG ROCK SAT {AL}, HUMMING A TUNE. THE {L} LIKED {N} AT ONCE, AND OFFERED TO COME ALONG AND KEEP EVERYONE COMPANY.",
			"{AL} POPPED OUT TO SAY HELLO! THE {P} AND THE {L} SNIFFED NOSES, AND THEN THEY WERE THE BEST OF FRIENDS.",
		}), a, st)

	b = new_page(st, {setting = s, vehicle = v, friends = true, pet = true, like = true, dislike = true})
	expand(b, pick(r, []string {
			"BUT THEN, OH NO! {AD} STOOD RIGHT IN THE WAY, GRUMBLING AND GROWLING. {F1} HID BEHIND {N}. EVEN THE {P} SHIVERED.",
			"ALL AT ONCE THE SKY WENT GREY, AND OUT STOMPED {AD}, AS CROSS AS COULD BE. \"NOBODY PASSES HERE!\" IT ROARED.",
			"SUDDENLY THERE WAS A RUMBLE, AND {AD} CAME SLIDING DOWN THE HILL, BLOCKING THE PATH.",
		}), a, st)

	b = new_page(st, {setting = s, vehicle = v, friends = true, pet = true, like = true})
	expand(b, pick(r, []string {
			"{N} WAS SCARED TOO, BUT {T} HAD AN IDEA. {N} SANG THE SILLIEST SONG {T} KNEW, AND {F2} JOINED IN, AND THE {D} LAUGHED SO HARD IT ROLLED AWAY OVER THE HILL.",
			"THE {L} WHISPERED A SECRET IN {N}'S EAR. {N} SHARED {TR} SANDWICH WITH THE {D}, WHICH HAD ONLY BEEN GRUMPY BECAUSE IT WAS HUNGRY. IT SAID THANK YOU AND WANDERED OFF HAPPY.",
			"{N} STOOD UP TALL AND SAID, \"WE ARE NOT AFRAID OF YOU!\" {F1} AND {F2} SAID IT TOO, AND THE {P} MADE ITS LOUDEST NOISE. THE {D} WAS SO SURPRISED THAT IT RAN AWAY.",
		}), a, st)

	b = new_page(st, {setting = s, vehicle = v, friends = true, pet = true, treasure = true})
	expand(b, pick(r, []string {
			"AND THERE, JUST WHERE THE MAP SAID, WAS A WOODEN CHEST. INSIDE THEY FOUND {X}! THEY COUNTED THEM TWICE TO BE SURE.",
			"AT LAST THEY CAME TO A GLITTERING HOLLOW, AND IT WAS FULL OF {X}. \"HOORAY!\" SHOUTED {F1}.",
			"THE {P} STARTED DIGGING, AND DIGGING, AND UP CAME {X}, SHINING IN THE SUN.",
		}), a, st)

	b = new_page(st, {setting = .Home, friends = true, pet = true, treasure = true, night = true})
	expand(b, pick(r, []string {
			"THEY CARRIED THE TREASURE ALL THE WAY HOME, SAFE AND SOUND. {N} GAVE SOME TO {F1}, SOME TO {F2}, AND A SPECIAL ONE TO THE {P}. THEN EVERYONE HAD A BIG SUPPER AND WENT TO BED SMILING.",
			"BY SUPPERTIME THEY WERE HOME AGAIN, TIRED AND HAPPY, WITH POCKETS FULL OF TREASURE. {N} PUT ONE ON THE WINDOWSILL TO REMEMBER THE DAY BY.",
			"HOME THEY CAME AS THE STARS CAME OUT. {F1} AND {F2} WAVED GOODNIGHT, THE {P} CURLED UP AT THE FOOT OF THE BED, AND {N} FELL ASLEEP DREAMING OF THE NEXT ADVENTURE.",
		}), a, st)

	b = new_page(st, {setting = .Home, pet = true, night = true})
	put(b, "THE END.")
}

// Upper-cases a typed answer and trims it; falls back when empty.
clean :: proc(buf: []u8, typed: string, fallback: string) -> string {
	n := 0
	start := 0
	for start < len(typed) && typed[start] == ' ' {start += 1}
	for i in start ..< len(typed) {
		if n >= len(buf) {break}
		c := typed[i]
		if c >= 'a' && c <= 'z' {c -= 32}
		if c == '{' || c == '}' {continue}
		buf[n] = c
		n += 1
	}
	for n > 0 && buf[n - 1] == ' ' {n -= 1}
	if n == 0 {return fallback}
	return string(buf[:n])
}
