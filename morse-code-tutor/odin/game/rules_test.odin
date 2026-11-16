#+build !js
package morse

import "core:testing"

@(test)
koch_covers_every_character_once :: proc(t: ^testing.T) {
	seen: bit_set[0 ..< 128]
	for i in 0 ..< len(KOCH) {
		c := KOCH[i]
		testing.expectf(t, len(code_for(c)) > 0, "no code for %c", rune(c))
		testing.expect(t, int(c) not_in seen)
		seen += {int(c)}
	}
	testing.expect_value(t, len(KOCH), 41)
	testing.expect_value(t, level_chars(1), "ET")
	testing.expect_value(t, level_chars(3), "ETANIM")
	testing.expect_value(t, len(level_chars(99)), 41)
}

@(test)
codes_are_standard :: proc(t: ^testing.T) {
	testing.expect_value(t, code_for('S'), "...")
	testing.expect_value(t, code_for('O'), "---")
	testing.expect_value(t, code_for('?'), "..--..")
	testing.expect_value(t, code_for('0'), "-----")
	testing.expect_value(t, code_for('#'), "")
}

@(test)
paris_takes_one_minute_over_wpm :: proc(t: ^testing.T) {
	// PARIS plus a word gap is 50 dits: at 20 WPM, 3 seconds.
	tx: Transmission
	transmit(&tx, "PARIS ", 20, 20)
	dit := dit_ms(20)
	testing.expect_value(t, dit, 60)
	// PARIS alone is 43 dits (no trailing gap), the 7-dit gap is added by the space.
	testing.expect(t, abs(tx.total_ms - 50 * dit) < 0.01)
	testing.expect(t, keyed(&tx, 1))
	testing.expect(t, !keyed(&tx, dit + 1)) // the gap after P's first dit
}

@(test)
farnsworth_stretches_only_the_gaps :: proc(t: ^testing.T) {
	a, b: Transmission
	transmit(&a, "EE", 20, 20)
	transmit(&b, "EE", 20, 10)
	testing.expect(t, b.total_ms > a.total_ms)
	testing.expect_value(t, b.tones[0].length, a.tones[0].length)
}

@(private = "file")
run_until :: proc(g: ^Game, phase: Phase) {
	for _ in 0 ..< 10000 {
		if g.phase == phase {return}
		update(g, 0.02)
	}
}

@(test)
right_answers_score_and_level_up :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 42)
	for i in 0 ..< PER_LEVEL {
		run_until(&g, .Waiting)
		answer(&g, g.current)
		testing.expect(t, .Right in g.events)
		g.events = {}
		_ = i
	}
	testing.expect(t, g.score > 0)
	testing.expect_value(t, g.streak, PER_LEVEL)
	run_until(&g, .Level_Up)
	testing.expect_value(t, g.level, 2)
	testing.expect_value(t, g.lives, LIVES)
}

@(test)
three_misses_end_it :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 42)
	run_until(&g, .Waiting)
	answer(&g, g.current == 'E' ? 'T' : 'E') // wrong
	testing.expect_value(t, g.lives, LIVES - 1)
	run_until(&g, .Waiting)
	run_until(&g, .Result) // timeout
	testing.expect_value(t, g.lives, LIVES - 2)
	run_until(&g, .Waiting)
	answer(&g, '5')
	testing.expect_value(t, g.lives, 0)
	run_until(&g, .Over)
	testing.expect_value(t, g.phase, Phase.Over)
}

@(test)
early_answers_count_and_replay_costs_the_bonus :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 7)
	run_until(&g, .Sending)
	answer(&g, g.current)
	fast := g.gained
	testing.expect_value(t, fast, 20) // 10 x level 1 + full bonus
	run_until(&g, .Waiting)
	testing.expect(t, replay(&g))
	testing.expect(t, !replay(&g)) // only once (it is Sending again anyway)
	run_until(&g, .Waiting)
	answer(&g, g.current)
	testing.expect_value(t, g.gained, 10)
}

@(test)
buddy_mode_copies_the_message :: proc(t: ^testing.T) {
	g: Game
	new_buddy(&g, "Hi there!", 13, 5) // '!' and spaces are dropped
	testing.expect_value(t, g.script_len, 7)
	for i in 0 ..< g.script_len {
		run_until(&g, .Waiting)
		answer(&g, i == 2 ? 'Q' : g.current)
	}
	run_until(&g, .Over)
	testing.expect_value(t, buddy_right(&g), 6)
	testing.expect_value(t, g.lives, LIVES)
}
