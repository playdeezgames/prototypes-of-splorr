#+build !js
package hamclock

import "core:testing"

@(test)
reminder_every_ten_minutes_on_the_air :: proc(t: ^testing.T) {
	s: Shack
	tick(&s, 700)
	testing.expect_value(t, s.flash, 0.0) // off the air: nothing
	testing.expect_value(t, s.total_s, 0.0)
	switch_air(&s)
	tick(&s, 599)
	testing.expect(t, .Id_Due not_in s.events)
	tick(&s, 1)
	testing.expect(t, .Id_Due in s.events)
	testing.expect_value(t, s.flash, FLASH_S)
	tick(&s, 31)
	testing.expect_value(t, s.flash, 0.0) // thirty seconds of flashing
	testing.expect_value(t, s.ids, 1)
}

@(test)
identifying_restarts_the_ten_minutes :: proc(t: ^testing.T) {
	s: Shack
	switch_air(&s)
	tick(&s, 400)
	identified(&s)
	testing.expect_value(t, id_in(&s), 600.0)
	tick(&s, 400)
	testing.expect_value(t, s.ids, 0)
}

@(test)
the_tally_keeps_the_total :: proc(t: ^testing.T) {
	s: Shack
	switch_air(&s)
	tick(&s, 90)
	switch_air(&s)
	tick(&s, 50)
	switch_air(&s)
	tick(&s, 30)
	testing.expect_value(t, s.session_s, 30.0)
	testing.expect_value(t, s.total_s, 120.0)
}

@(test)
call_signs :: proc(t: ^testing.T) {
	s: Shack
	set_call(&s, "VE3/G4ABC")
	testing.expect_value(t, call_sign(&s), "VE3/G4ABC")
	testing.expect(t, !type_call(&s, '-'))
	set_call(&s, "w1aw") // stored lower case reads back in capitals
	testing.expect_value(t, call_sign(&s), "W1AW")
	testing.expect(t, !type_call(&s, 'w'))
	testing.expect_value(t, morse('W'), ".--")
	testing.expect_value(t, morse('/'), "-..-.")
}

@(test)
local_and_greenwich :: proc(t: ^testing.T) {
	// 2026-11-22 15:04:05 UTC
	ms := f64(1795359845) * 1000
	g := time_of_day(ms, 0)
	testing.expect_value(t, g, Clock_Time{15, 4, 5})
	l := time_of_day(ms, -300) // five hours west
	testing.expect_value(t, l, Clock_Time{10, 4, 5})
	e := time_of_day(ms, 600)
	testing.expect_value(t, e, Clock_Time{1, 4, 5})
	d := date_of(ms, 0)
	testing.expect_value(t, d, Date{2026, 11, 22, 0})
	testing.expect_value(t, date_of(ms, 600).day, 23)
}
