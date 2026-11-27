package safari

// The computer Bwana (new). It knows what any player is shown: the starting map of animals and
// camps, its scouts' reports, and what has happened to its own party. It keeps its place by
// counting its steps, loses it when disoriented (and then buys a map), remembers where disasters
// struck, and films each region once.

INF :: 1 << 20

// Steps from (r, c) to every region, keeping off regions where it met a disaster (unless the
// region is the goal itself).
distances :: proc(pl: ^Player, r, c: int) -> (d: [SIZE][SIZE]int) {
	for &row in d {for &v in row {v = INF}}
	qr, qc: [SIZE * SIZE]int
	head, tail := 0, 0
	d[r][c] = 0
	qr[tail], qc[tail] = r, c
	tail += 1
	for head < tail {
		cr, cc := qr[head], qc[head]
		head += 1
		for dir in Dir {
			nr, nc := cr + DR[dir], cc + DC[dir]
			if nr < 0 || nr >= SIZE || nc < 0 || nc >= SIZE || d[nr][nc] != INF {continue}
			d[nr][nc] = d[cr][cc] + 1
			if pl.ai_danger[nr][nc] {continue} // reachable, but not through
			qr[tail], qc[tail] = nr, nc
			tail += 1
		}
	}
	return
}

// The first step from (r, c) along a shortest safe way to (tr, tc).
step_toward :: proc(pl: ^Player, r, c, tr, tc: int) -> (Move, bool) {
	d := distances(pl, tr, tc) // from the target back
	best := INF
	mv := Move.Stay
	for dir in Dir {
		nr, nc := r + DR[dir], c + DC[dir]
		if nr < 0 || nr >= SIZE || nc < 0 || nc >= SIZE {continue}
		v := d[nr][nc]
		if pl.ai_danger[nr][nc] && !(nr == tr && nc == tc) {v += 6}
		if v < best {best = v; mv = Move(int(dir))}
	}
	return mv, best < INF
}

ai_value :: proc(g: ^Game, pl: ^Player, r, c: int) -> int {
	return 80 + 10 * (abs(r - pl.br) + abs(c - pl.bc))
}

// The best region to film from (r, c), given food for `days` more days; ok false if none.
ai_pick :: proc(g: ^Game, pl: ^Player, r, c: int, days: int) -> (tr, tc: int, ok: bool) {
	from := distances(pl, r, c)
	home := distances(pl, pl.br, pl.bc)
	best := -1
	for rr in 0 ..< SIZE {
		for cc in 0 ..< SIZE {
			if !is_animal(g.start[rr][cc]) || pl.ai_done[rr][cc] {continue}
			if from[rr][cc] >= INF || home[rr][cc] >= INF {continue}
			trip := from[rr][cc] + home[rr][cc]
			if trip > days {continue}
			score := ai_value(g, pl, rr, cc) * 10 / (from[rr][cc] + 2)
			if score > best {best = score; tr, tc = rr, cc; ok = true}
		}
	}
	return
}

// Days of food a party of this size has, keeping 100 lb in hand so no one starves.
food_days :: proc(pl: ^Player) -> int {
	daily := daily_food(party_scouts(pl), pl.men[0], pl.bearers[0])
	return max(0, (pl.supplies[0] - 100) / daily)
}

ai_outfit :: proc(g: ^Game) {
	pl := cur(g)
	cams := min(max_cameras(pl), 2)
	scouts: bit_set[Dir]
	// one scout, for a map if lost; the one facing the way it will go
	tr, tc, ok := ai_pick(g, pl, pl.br, pl.bc, 40)
	if !ok || cams < 1 {
		retire(g)
		return
	}
	first, _ := step_toward(pl, pl.br, pl.bc, tr, tc)
	want := Dir.North
	if first <= .West {want = Dir(int(first))}
	if pl.scouts[want] == .Base {
		scouts += {want}
	} else {
		for s, d in pl.scouts {if s == .Base {scouts += {d}; break}}
	}
	ns := card(scouts)
	dist := abs(tr - pl.br) + abs(tc - pl.bc)
	days := 2 * dist + 4 + 2 * cams
	fixed := daily_food(ns, 2 * cams, 0)
	bearers := pl.bearers[1]
	den := 100 - 3 * days
	if den > 10 {
		need := (days * fixed + 150 + den - 1) / den
		bearers = clamp(need, 3, pl.bearers[1])
	}
	bearers = clamp(bearers, 3, max(3, min(pl.bearers[1], (pl.supplies[1] + 99) / 100)))
	bearers = min(bearers, pl.bearers[1])
	pl.ai_target = {tr, tc}
	pl.ai_home = false
	if !outfit(g, scouts, cams, bearers) {
		// fall back to the least the camp can send
		if !outfit(g, {}, 1, 3) {retire(g)}
	}
}

ai_move :: proc(g: ^Game) {
	pl := cur(g)
	if !pl.ai_known || pl.hungry > 7 {
		move(g, .Lost)
		return
	}
	r, c := pl.ai_kr, pl.ai_kc
	home := distances(pl, pl.br, pl.bc)
	daily := daily_food(party_scouts(pl), pl.men[0], pl.bearers[0])
	to_home := home[r][c]
	can_film := pl.film > 0 && pl.men[0] >= 2 && pl.cameras[0] > 0
	if !can_film || pl.supplies[0] - (to_home + 1) * daily < 100 {pl.ai_home = true}
	if !pl.ai_home {
		// an animal the scouts can see is worth a look
		for d in Dir {
			nr, nc := r + DR[d], c + DC[d]
			if report(g, pl, d) == .Animal && !pl.ai_done[nr][nc] && !pl.ai_danger[nr][nc] {
				if move(g, Move(int(d))) {return}
			}
		}
		tr, tc, ok := ai_pick(g, pl, r, c, food_days(pl))
		if !ok {
			pl.ai_home = true
		} else {
			pl.ai_target = {tr, tc}
			mv, _ := step_toward(pl, r, c, tr, tc)
			if move(g, mv) {return}
		}
	}
	mv, ok := step_toward(pl, r, c, pl.br, pl.bc)
	if !ok || !move(g, mv) {move(g, .Lost)}
}

// One reaction of the computer's camera hand: a frame move, a snap, or nothing. It judges the
// animal's place by eye (off by a few characters), so now and then it snaps a miss.
ai_film :: proc(g: ^Game) {
	if g.phase != .Filming {return}
	f := &g.film
	if next_random(g) < 0.35 {return} // hands not always on the keys
	x, y := frame_centre(f)
	dx := f.a1 - x + rnd(g, 19) - 10
	dy := f.a2 - y + rnd(g, 5) - 3
	if abs(dx) < 8 && abs(dy) < 3 {
		if next_random(g) < 0.5 {film_snap(g)}
		return
	}
	if abs(dy) >= 2 && (abs(dx) < 6 || next_random(g) < 0.4) {
		film_key(g, dy < 0 ? .Up : .Down)
	} else if abs(dx) >= 4 {
		film_key(g, dx < 0 ? .Left : .Right)
	}
}

// Plays one whole step for a computer Bwana (tests and the page's auto-play).
ai_act :: proc(g: ^Game) {
	switch g.phase {
	case .Outfit: ai_outfit(g)
	case .Move: ai_move(g)
	case .Filming:
		ai_film(g)
		film_tick(g)
	case .Report: next_turn(g)
	case .Over:
	}
}
