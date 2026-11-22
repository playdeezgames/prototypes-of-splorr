package chessclock

// Chess Clock: a tool. After "Chess Clock" (uncredited, SoftSide, December 1978): a tournament
// clock giving each player two hours to complete 40 moves; a key press ends a turn and starts the
// other side's clock, with completed turns and both times shown. New here: other time controls
// (with an increment for the faster ones), a second period after the 40th move, pause, and a flag
// when a side runs out.
// Pure rules: no platform imports.

Side :: enum {
	White,
	Black,
}

Control :: struct {
	name:      string,
	main_s:    int, // seconds each at the start
	moves:     int, // moves to make in the main time (0: the whole game)
	extra_s:   int, // added to each side's clock when it makes its last move of a period
	extra_mvs: int, // moves in each later period (0: the rest of the game)
	inc_s:     int, // added after every move
}

CONTROLS := [?]Control {
	{"TOURNAMENT 2H / 40", 2 * 3600, 40, 3600, 20, 0}, // the listing's two hours for 40 moves, then an hour for 20
	{"RAPID 25 + 10", 25 * 60, 0, 0, 0, 10},
	{"RAPID 15", 15 * 60, 0, 0, 0, 0},
	{"BLITZ 5 + 3", 5 * 60, 0, 0, 0, 3},
	{"BLITZ 3 + 2", 3 * 60, 0, 0, 0, 2},
	{"BULLET 1", 60, 0, 0, 0, 0},
}

State :: enum {
	Ready, // set, nobody's clock running; the first press starts White's clock
	Running,
	Paused,
	Flagged, // one side's time ran out
}

Clock :: struct {
	control:  int,
	left:     [Side]f64, // seconds left
	moves:    [Side]int, // moves completed
	to_move:  Side,
	state:    State,
	flagged:  Side,
	periods:  [Side]int, // time controls made
	events:   bit_set[Event],
}

Event :: enum {
	Switched,
	Control_Made, // a side made its moves in time and got the next period
	Flag,
	Low_Time, // a running clock crossed ten seconds left
}

reset :: proc(c: ^Clock, control: int) {
	k := clamp(control, 0, len(CONTROLS) - 1)
	c^ = {}
	c.control = k
	for s in Side {c.left[s] = f64(CONTROLS[k].main_s)}
	c.to_move = .White
	c.state = .Ready
}

// The player whose clock is running presses their side to end their move. In Ready, either
// press starts White's clock (Black presses to start the game, as on a real clock; White
// pressing also starts it, for one person setting it going).
press :: proc(c: ^Clock, by: Side) -> bool {
	switch c.state {
	case .Ready:
		c.to_move = .White
		c.state = .Running
		c.events += {.Switched}
		return true
	case .Paused:
		c.state = .Running
		return by == c.to_move ? end_move(c) : true
	case .Running:
		if by != c.to_move {return false}
		return end_move(c)
	case .Flagged:
		return false
	}
	return false
}

@(private)
end_move :: proc(c: ^Clock) -> bool {
	s := c.to_move
	ctl := CONTROLS[c.control]
	c.moves[s] += 1
	c.left[s] += f64(ctl.inc_s)
	if ctl.moves > 0 && c.moves[s] == period_end(ctl, c.periods[s]) {
		c.left[s] += f64(ctl.extra_s)
		c.periods[s] += 1
		c.events += {.Control_Made}
	}
	c.to_move = s == .White ? .Black : .White
	c.events += {.Switched}
	return true
}

// The move number that ends period p (0 the first) for a control with a move count.
period_end :: proc(ctl: Control, p: int) -> int {
	if p == 0 {return ctl.moves}
	if ctl.extra_mvs == 0 {return max(int)}
	return ctl.moves + p * ctl.extra_mvs
}

// Moves still to make in the current period, or -1 when the period is the rest of the game.
moves_to_control :: proc(c: ^Clock, s: Side) -> int {
	ctl := CONTROLS[c.control]
	if ctl.moves == 0 {return -1}
	end := period_end(ctl, c.periods[s])
	if end == max(int) {return -1}
	return end - c.moves[s]
}

pause :: proc(c: ^Clock) {
	if c.state == .Running {c.state = .Paused} else if c.state == .Paused {c.state = .Running}
}

tick :: proc(c: ^Clock, dt: f64) {
	if c.state != .Running {return}
	s := c.to_move
	before := c.left[s]
	c.left[s] -= dt
	if before > 10 && c.left[s] <= 10 {c.events += {.Low_Time}}
	if c.left[s] <= 0 {
		c.left[s] = 0
		c.state = .Flagged
		c.flagged = s
		c.events += {.Flag}
	}
}

// Completed turns as the listing counted them: one for each move by Black.
turns :: proc(c: ^Clock) -> int {
	return c.moves[.Black]
}

// Hours, minutes, seconds (rounded up while running, so 0:00:00 is the flag) and tenths.
split :: proc(secs: f64) -> (h, m, s, tenths: int) {
	t := max(secs, 0)
	whole := int(t)
	if f64(whole) < t && t >= 20 {whole += 1} // show the second as it counts down
	h = whole / 3600
	m = (whole / 60) % 60
	s = whole % 60
	tenths = int((t - f64(int(t))) * 10)
	return
}
