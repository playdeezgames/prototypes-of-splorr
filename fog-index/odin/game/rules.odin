package fogindex

// Fog Index, after "Can You See Through This?" by Rev. George Blank (SoftSide, March 1979).
// The listing asks, for five sentences, the number of words and the number of words of three
// syllables or more, and prints INT(0.4 * (all the words + all the long words) / 5): the reading
// level by school grade. Here the counting is done for you from typed or pasted text; the
// General test takes the first five sentences, the Acid test the five hardest, as the article
// describes. Gunning's own formula over the whole text is given beside them.

MAX_SENTENCES :: 400
TEST_SENTENCES :: 5

Sentence :: struct {
	start, end: int, // byte range in the text
	words:      int,
	hard:       int, // words of three syllables or more
}

Analysis :: struct {
	sentences: [MAX_SENTENCES]Sentence,
	count:     int,
	words:     int,
	hard:      int,
}

is_letter :: proc(c: u8) -> bool {
	return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')
}

is_word_char :: proc(c: u8) -> bool {
	return is_letter(c) || (c >= '0' && c <= '9') || c == '\''
}

lower :: proc(c: u8) -> u8 {
	return c >= 'A' && c <= 'Z' ? c + 32 : c
}

is_vowel :: proc(c: u8) -> bool {
	switch c {
	case 'a', 'e', 'i', 'o', 'u', 'y':
		return true
	}
	return false
}

// An estimate of a word's syllables: groups of vowels, less a silent final e, and (as Gunning
// says) the -es and -ed endings don't add one. Numbers count as one syllable.
syllables :: proc(word: string) -> int {
	buf: [48]u8
	n := 0
	for i in 0 ..< len(word) {
		c := lower(word[i])
		if is_letter(c) && n < len(buf) {buf[n] = c; n += 1}
	}
	if n == 0 {return 1}
	if n <= 3 {return 1}
	w := buf[:n]
	// Endings that add no syllable: -es (but not -ses, -zes, -ces, -ges, -xes, -shes, -ches),
	// -ed (but not -ted, -ded), and a silent final -e (but not -le after a consonant).
	if n > 4 && w[n - 2] == 'e' && w[n - 1] == 's' {
		p := w[n - 3]
		keep := p == 's' || p == 'z' || p == 'c' || p == 'g' || p == 'x' || (p == 'h' && (w[n - 4] == 's' || w[n - 4] == 'c'))
		if !keep {w = w[:n - 2]}
	} else if n > 4 && w[n - 2] == 'e' && w[n - 1] == 'd' {
		p := w[n - 3]
		if p != 't' && p != 'd' {w = w[:n - 2]}
	} else if w[n - 1] == 'e' {
		le := n >= 3 && w[n - 2] == 'l' && !is_vowel(w[n - 3])
		if !le {w = w[:n - 1]}
	}
	count := 0
	prev := false
	for c, i in w {
		v := is_vowel(c) && !(c == 'y' && i == 0)
		if v && !prev {count += 1}
		prev = v
	}
	// Vowel pairs that are two syllables: li-on, ra-ti-o, pi-an-o, vi-de-o, po-et, di-et.
	for i in 0 ..< len(w) - 1 {
		a, b := w[i], w[i + 1]
		if (a == 'i' && (b == 'a' || b == 'o')) || (a == 'e' && b == 'o') || (a == 'o' && b == 'e' && i + 2 < len(w)) || (a == 'i' && b == 'e' && i + 2 < len(w) && w[i + 2] == 't') {
			count += 1
		}
	}
	// -tion, -sion, -cial, -tial, -cious, -tious are one syllable, not two.
	for i in 1 ..< max(1, len(w) - 1) {
		if i + 1 < len(w) && (w[i - 1] == 't' || w[i - 1] == 's' || w[i - 1] == 'c') && w[i] == 'i' && (w[i + 1] == 'o' || w[i + 1] == 'a') {
			count -= 1
		}
	}
	return max(1, count)
}

is_hard :: proc(word: string) -> bool {return syllables(word) >= 3}

// Splits the text into sentences (ended by . ! ? or the end of the text) and counts each one's
// words and long words. A full stop inside a number (3.5) or after a single capital (initials,
// as in "George B. Blank") doesn't end a sentence.
analyse :: proc(a: ^Analysis, text: string) {
	a^ = {}
	cur := Sentence{start = -1}
	i := 0
	for i < len(text) {
		c := text[i]
		if is_word_char(c) {
			j := i
			for j < len(text) && (is_word_char(text[j]) || joins(text, j, i)) {j += 1}
			word := text[i:j]
			if cur.start < 0 {cur.start = i}
			// A hyphenated word (battle-field) is one word.
			cur.words += 1
			if is_hard(word) {cur.hard += 1}
			cur.end = j
			i = j
			continue
		}
		if c == '.' || c == '!' || c == '?' {
			ends := true
			if c == '.' && i > 0 && i + 1 < len(text) && text[i - 1] >= '0' && text[i - 1] <= '9' && text[i + 1] >= '0' && text[i + 1] <= '9' {ends = false}
			if c == '.' && i >= 1 && text[i - 1] >= 'A' && text[i - 1] <= 'Z' && (i == 1 || !is_word_char(text[i - 2])) && cur.words > 1 {ends = false}
			if ends && cur.words > 0 {
				cur.end = i + 1
				for cur.end < len(text) && (text[cur.end] == '"' || text[cur.end] == '\'' || text[cur.end] == ')') {cur.end += 1}
				push(a, cur)
				cur = Sentence{start = -1}
			}
		}
		i += 1
	}
	if cur.words > 0 {push(a, cur)}
}

// A hyphen between letters (battle-field) or a point or comma between digits (3.5, 1,000)
// keeps a word together.
@(private)
joins :: proc(text: string, j, start: int) -> bool {
	if j <= start || j + 1 >= len(text) {return false}
	c, p, n := text[j], text[j - 1], text[j + 1]
	if c == '-' {return is_letter(p) && is_letter(n)}
	if c == '.' || c == ',' {return p >= '0' && p <= '9' && n >= '0' && n <= '9'}
	return false
}

@(private)
push :: proc(a: ^Analysis, s: Sentence) {
	a.words += s.words
	a.hard += s.hard
	if a.count < MAX_SENTENCES {
		a.sentences[a.count] = s
		a.count += 1
	}
}

// The listing's sum: 0.4 times the average of words plus long words per sentence, whole grades.
listing_index :: proc(words, hard: []int) -> int {
	n := min(len(words), len(hard))
	if n == 0 {return 0}
	total := 0
	for k in 0 ..< n {total += words[k] + hard[k]}
	return int(0.4 * f64(total) / f64(n))
}

// Gunning's formula: 0.4 * (words per sentence + the percentage of long words).
gunning :: proc(a: ^Analysis) -> f64 {
	if a.count == 0 || a.words == 0 {return 0}
	return 0.4 * (f64(a.words) / f64(a.count) + 100 * f64(a.hard) / f64(a.words))
}

// The General test: the first five sentences.
general_test :: proc(a: ^Analysis) -> (index: int, n: int) {
	n = min(a.count, TEST_SENTENCES)
	w, h: [TEST_SENTENCES]int
	for k in 0 ..< n {w[k] = a.sentences[k].words; h[k] = a.sentences[k].hard}
	return listing_index(w[:n], h[:n]), n
}

// The Acid test: the five hardest sentences (most words plus long words). The chosen sentence
// numbers are returned in picks.
acid_test :: proc(a: ^Analysis, picks: ^[TEST_SENTENCES]int) -> (index: int, n: int) {
	n = min(a.count, TEST_SENTENCES)
	used: [MAX_SENTENCES]bool
	w, h: [TEST_SENTENCES]int
	for k in 0 ..< n {
		best := -1
		for s, i in a.sentences[:a.count] {
			if used[i] {continue}
			if best < 0 || s.words + s.hard > a.sentences[best].words + a.sentences[best].hard {best = i}
		}
		used[best] = true
		picks[k] = best
		w[k] = a.sentences[best].words
		h[k] = a.sentences[best].hard
	}
	return listing_index(w[:n], h[:n]), n
}

// The listing's table of typical values.
Level :: struct {
	grade: int,
	name:  string,
	note:  string,
}

LEVELS := [?]Level {
	{17, "COLLEGE GRADUATE", "NO POPULAR MAGAZINE"},
	{12, "HIGH SCHOOL SENIOR", "ATLANTIC MONTHLY"},
	{10, "HIGH SCHOOL SOPHOMORE", "TIME MAGAZINE"},
	{8, "EIGHTH GRADE", "LADIES HOME JOURNAL"},
}

// What the index means in words (grade 13 to 16 is college; 17 and up a graduate).
grade_name :: proc(index: int) -> string {
	switch {
	case index <= 0:
		return "NO TEXT YET"
	case index <= 6:
		return "EASY READING"
	case index == 7:
		return "SEVENTH GRADE"
	case index == 8:
		return "EIGHTH GRADE"
	case index == 9:
		return "HIGH SCHOOL FRESHMAN"
	case index == 10:
		return "HIGH SCHOOL SOPHOMORE"
	case index == 11:
		return "HIGH SCHOOL JUNIOR"
	case index == 12:
		return "HIGH SCHOOL SENIOR"
	case index <= 16:
		return "COLLEGE"
	}
	return "COLLEGE GRADUATE"
}

// Public-domain passages to try.
Sample :: struct {
	name: string,
	text: string,
}

SAMPLES := [?]Sample {
	{
		"THE BEATITUDES (KJV)",
		"Blessed are the poor in spirit: for theirs is the kingdom of heaven. Blessed are they that mourn: for they shall be comforted. Blessed are the meek: for they shall inherit the earth. Blessed are they which do hunger and thirst after righteousness: for they shall be filled. Blessed are the merciful: for they shall obtain mercy. Blessed are the pure in heart: for they shall see God. Blessed are the peacemakers: for they shall be called the children of God. Blessed are they which are persecuted for righteousness' sake: for theirs is the kingdom of heaven.",
	},
	{
		"THE GETTYSBURG ADDRESS",
		"Four score and seven years ago our fathers brought forth on this continent, a new nation, conceived in Liberty, and dedicated to the proposition that all men are created equal. Now we are engaged in a great civil war, testing whether that nation, or any nation so conceived and so dedicated, can long endure. We are met on a great battle-field of that war. We have come to dedicate a portion of that field, as a final resting place for those who here gave their lives that that nation might live. It is altogether fitting and proper that we should do this. But, in a larger sense, we can not dedicate -- we can not consecrate -- we can not hallow -- this ground. The brave men, living and dead, who struggled here, have consecrated it, far above our poor power to add or detract. The world will little note, nor long remember what we say here, but it can never forget what they did here. It is for us the living, rather, to be dedicated here to the unfinished work which they who fought here have thus far so nobly advanced. It is rather for us to be here dedicated to the great task remaining before us -- that from these honored dead we take increased devotion to that cause for which they gave the last full measure of devotion -- that we here highly resolve that these dead shall not have died in vain -- that this nation, under God, shall have a new birth of freedom -- and that government of the people, by the people, for the people, shall not perish from the earth.",
	},
	{
		"THE DECLARATION (1776)",
		"We hold these truths to be self-evident, that all men are created equal, that they are endowed by their Creator with certain unalienable Rights, that among these are Life, Liberty and the pursuit of Happiness. That to secure these rights, Governments are instituted among Men, deriving their just powers from the consent of the governed, that whenever any Form of Government becomes destructive of these ends, it is the Right of the People to alter or to abolish it, and to institute new Government, laying its foundation on such principles and organizing its powers in such form, as to them shall seem most likely to effect their Safety and Happiness. Prudence, indeed, will dictate that Governments long established should not be changed for light and transient causes; and accordingly all experience hath shewn, that mankind are more disposed to suffer, while evils are sufferable, than to right themselves by abolishing the forms to which they are accustomed. But when a long train of abuses and usurpations, pursuing invariably the same Object evinces a design to reduce them under absolute Despotism, it is their right, it is their duty, to throw off such Government, and to provide new Guards for their future security. Such has been the patient sufferance of these Colonies; and such is now the necessity which constrains them to alter their former Systems of Government.",
	},
}
