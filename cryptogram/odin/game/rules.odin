package cryptogram

// Cryptogram: solve a letter-substitution code. After "Cryptogram" by Rik Pierce (SoftSide, August
// 1979): pick a code letter, then the letter it stands for; "/" clears every guess, "?" picks
// another crypt; a letter not in the crypt, or one already given to another code letter, is
// refused. The original only displayed guesses; here crypts come from a bank of public-domain
// proverbs under a fresh random key, so the game knows when you have it. You can still type in
// your own crypt (no answer known, just the solving board). Pure rules: no platform imports.

MAX_TEXT :: 200

Result :: enum {
	Ok,
	Not_A_Letter,
	Not_In_Crypt,
	Already_In_Use,
	Solved_Already,
}

Puzzle :: struct {
	text:       [MAX_TEXT]u8, // the crypt as shown (code letters, spaces, punctuation)
	len:        int,
	answer:     [26]u8, // code letter -> true letter ('A'..'Z'), 0 when unknown
	has_answer: bool,
	guess:      [26]u8, // code letter -> the player's letter, 0 when none
	present:    bit_set[0 ..< 26],
	hints:      int,
	moves:      int,
}

Rng :: struct {
	s: u64,
}

rand_u32 :: proc(r: ^Rng) -> u32 {
	x := r.s
	x ~= x >> 12
	x ~= x << 25
	x ~= x >> 27
	r.s = x
	return u32((x * 0x2545F4914F6CDD1D) >> 32)
}

rand_n :: proc(r: ^Rng, n: int) -> int {
	return int(rand_u32(r) % u32(n))
}

is_letter :: proc(c: u8) -> bool {return c >= 'A' && c <= 'Z'}

upper :: proc(c: u8) -> u8 {return c >= 'a' && c <= 'z' ? c - 32 : c}

// A random key where no letter stands for itself.
derangement :: proc(r: ^Rng) -> (key: [26]u8) {
	for {
		p: [26]u8
		for i in 0 ..< 26 {p[i] = u8(i)}
		for i := 25; i > 0; i -= 1 {
			j := rand_n(r, i + 1)
			p[i], p[j] = p[j], p[i]
		}
		ok := true
		for i in 0 ..< 26 {if p[i] == u8(i) {ok = false}}
		if ok {
			for i in 0 ..< 26 {key[i] = 'A' + p[i]}
			return
		}
	}
}

// Enciphers a plain text under a fresh key.
from_plain :: proc(pz: ^Puzzle, plain: string, r: ^Rng) {
	pz^ = {}
	key := derangement(r) // true letter -> code letter
	for i in 0 ..< min(len(plain), MAX_TEXT) {
		c := upper(plain[i])
		if is_letter(c) {
			code := key[c - 'A']
			pz.text[pz.len] = code
			pz.answer[code - 'A'] = c
			pz.present += {int(code - 'A')}
		} else {
			pz.text[pz.len] = c
		}
		pz.len += 1
	}
	pz.has_answer = true
}

// A crypt the player typed in: no answer known.
from_cipher :: proc(pz: ^Puzzle, cipher: string) {
	pz^ = {}
	for i in 0 ..< min(len(cipher), MAX_TEXT) {
		c := upper(cipher[i])
		pz.text[pz.len] = c
		if is_letter(c) {pz.present += {int(c - 'A')}}
		pz.len += 1
	}
}

text :: proc(pz: ^Puzzle) -> string {
	return string(pz.text[:pz.len])
}

assign :: proc(pz: ^Puzzle, code_in, letter_in: u8) -> Result {
	code, letter := upper(code_in), upper(letter_in)
	if !is_letter(code) || !is_letter(letter) {return .Not_A_Letter}
	if solved(pz) {return .Solved_Already}
	if int(code - 'A') not_in pz.present {return .Not_In_Crypt}
	for g, i in pz.guess {
		if g == letter && i != int(code - 'A') {return .Already_In_Use}
	}
	pz.guess[code - 'A'] = letter
	pz.moves += 1
	return .Ok
}

clear_guess :: proc(pz: ^Puzzle, code: u8) {
	c := upper(code)
	if is_letter(c) {pz.guess[c - 'A'] = 0}
}

clear_all :: proc(pz: ^Puzzle) {
	pz.guess = {}
}

// Which code letter, if any, already has this letter.
holder :: proc(pz: ^Puzzle, letter: u8) -> (code: u8, ok: bool) {
	l := upper(letter)
	for g, i in pz.guess {
		if g == l && g != 0 {return 'A' + u8(i), true}
	}
	return 0, false
}

solved :: proc(pz: ^Puzzle) -> bool {
	if !pz.has_answer || pz.present == {} {return false}
	for i in 0 ..< 26 {
		if i in pz.present && pz.guess[i] != pz.answer[i] {return false}
	}
	return true
}

// Fills in one code letter that is blank or wrong (freeing its true letter if another code
// letter holds it). Returns the code letter, or 0 when there is nothing to give.
hint :: proc(pz: ^Puzzle, r: ^Rng) -> u8 {
	if !pz.has_answer || solved(pz) {return 0}
	wrong: [26]u8
	n := 0
	for i in 0 ..< 26 {
		if i in pz.present && pz.guess[i] != pz.answer[i] {
			wrong[n] = u8(i)
			n += 1
		}
	}
	if n == 0 {return 0}
	i := wrong[rand_n(r, n)]
	truth := pz.answer[i]
	for &g in pz.guess {if g == truth {g = 0}}
	pz.guess[i] = truth
	pz.hints += 1
	return 'A' + i
}

// Code letters in the order they first appear (for moving the selection with the arrows).
order :: proc(pz: ^Puzzle) -> (letters: [26]u8, n: int) {
	seen: bit_set[0 ..< 26]
	for c in pz.text[:pz.len] {
		if is_letter(c) && int(c - 'A') not_in seen {
			seen += {int(c - 'A')}
			letters[n] = c
			n += 1
		}
	}
	return
}
