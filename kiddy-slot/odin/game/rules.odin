package slot

// Kiddy Slot: a children's three-reel slot machine. After "Kiddy Slot" by David Boike (SoftSide,
// January 1979): ten ZZOOPPS to start, three reels that each show one of three pictures, three
// alike win five ZZOOPPS, otherwise the spin costs one, and when they run out you start again with
// ten. Pure rules: no platform imports.

START :: 10
WIN :: 5
COST :: 1

Picture :: enum u8 {
	Sun,
	Smile,
	Lollipop,
}

Outcome :: enum {
	None,
	Win,
	Lose,
}

Machine :: struct {
	zzoopps: int,
	reels:   [3]Picture,
	spins:   int,
	wins:    int,
	most:    int, // the most ZZOOPPS held this visit
	rng:     u64,
}

new_machine :: proc(m: ^Machine, seed: u64) {
	m^ = {}
	m.rng = seed | 1
	m.zzoopps = START
	m.most = START
	m.reels = {.Sun, .Smile, .Lollipop}
}

@(private)
next :: proc(m: ^Machine) -> u64 {
	x := m.rng
	x ~= x << 13
	x ~= x >> 7
	x ~= x << 17
	m.rng = x
	return x
}

roll :: proc(m: ^Machine, n: int) -> int {
	return int(next(m) % u64(n))
}

can_spin :: proc(m: ^Machine) -> bool {
	return m.zzoopps > 0
}

// One pull: the listing pays five on a match and takes one on a miss.
spin :: proc(m: ^Machine) -> Outcome {
	if !can_spin(m) {return .None}
	for &r in m.reels {r = Picture(roll(m, len(Picture)))}
	m.spins += 1
	if m.reels[0] == m.reels[1] && m.reels[1] == m.reels[2] {
		m.zzoopps += WIN
		m.wins += 1
		m.most = max(m.most, m.zzoopps)
		return .Win
	}
	m.zzoopps -= COST
	return .Lose
}

// Out of ZZOOPPS: "JUST PRESS ENTER AND YOU CAN PLAY AGAIN!"
refill :: proc(m: ^Machine) {
	if m.zzoopps <= 0 {m.zzoopps = START}
}
