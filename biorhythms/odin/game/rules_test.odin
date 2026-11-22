#+build !js
package biorhythms

import "core:testing"

@(test)
day_numbers_and_weekdays :: proc(t: ^testing.T) {
	testing.expect_value(t, day_number({1970, 1, 1}), 0)
	testing.expect_value(t, day_number({2026, 11, 22}), 20779)
	testing.expect_value(t, weekday({2026, 11, 22}), 0) // a Sunday
	testing.expect_value(t, weekday({1978, 12, 1}), 5) // the issue's month began on a Friday
	testing.expect_value(t, age_days({2000, 2, 28}, {2000, 3, 1}), 2) // a leap year
	testing.expect_value(t, days_in_month(1900, 2), 28)
	testing.expect_value(t, days_in_month(2000, 2), 29)
}

@(test)
the_birthday_is_triple_critical :: proc(t: ^testing.T) {
	testing.expect_value(t, critical_sum(0), 7)
	testing.expect_value(t, critical_sum(1), 0)
}

@(test)
crossings_every_half_period :: proc(t: ^testing.T) {
	// 23 days: crossings at 11.5, 23, 34.5, 46 fall in days 11, 23, 34, 46.
	for d in 1 ..< 50 {
		want := d == 11 || d == 23 || d == 34 || d == 46
		testing.expectf(t, critical(.Physical, d) == want, "physical day %d", d)
	}
	// 28 days: every 14.
	testing.expect(t, critical(.Emotional, 14))
	testing.expect(t, critical(.Emotional, 28))
	testing.expect(t, !critical(.Emotional, 13))
	// 23 and 28 together at 644 days (both periods divide it).
	testing.expect_value(t, critical_sum(644), 3)
}

@(test)
highs_and_lows :: proc(t: ^testing.T) {
	testing.expect_value(t, phase(.Emotional, 7), Phase.High) // the top of the curve
	testing.expect_value(t, percent(.Emotional, 7), 100)
	testing.expect_value(t, phase(.Emotional, 21), Phase.Low)
	testing.expect_value(t, percent(.Emotional, 21), -100)
}

@(test)
dates_check :: proc(t: ^testing.T) {
	testing.expect(t, valid({1978, 12, 31}))
	testing.expect(t, !valid({1978, 2, 29}))
	y, m := add_months(2026, 12, 1)
	testing.expect_value(t, y, 2027)
	testing.expect_value(t, m, 1)
	y, m = add_months(2027, 1, -1)
	testing.expect_value(t, y, 2026)
	testing.expect_value(t, m, 12)
}

@(test)
day_numbers_round_trip :: proc(t: ^testing.T) {
	for n in ([?]int{-1, 0, 59, 10957, 20779, -25567}) {
		testing.expect_value(t, day_number(from_day_number(n)), n)
	}
	testing.expect_value(t, from_day_number(20779), Date{2026, 11, 22})
}
