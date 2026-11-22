package biorhythms

// Biorhythms: a toy. After "Biorhythms Charting Program" by Frank B. Rowlett, Jr. (SoftSide,
// December 1978): from a birth date, plot the physical (23-day), emotional (28-day) and
// intellectual (33-day) sine curves for a month. The curves are numbered 1, 2 and 4; a critical
// day is where a curve crosses the axis, shown with the curve's number, or the sum where two or
// three cross on the same day (3, 5, 6 or 7). As the article said, it is not fortune telling.
// New here: any month at a tap, a marker for today, and a readout for the day under the finger.
// Pure rules: no platform imports.

import "core:math"

Rhythm :: enum {
	Physical,
	Emotional,
	Intellectual,
}

PERIOD := [Rhythm]int {
	.Physical     = 23,
	.Emotional    = 28,
	.Intellectual = 33,
}

// The listing's numbers for each curve, summed where curves cross together.
NUMBER := [Rhythm]int {
	.Physical     = 1,
	.Emotional    = 2,
	.Intellectual = 4,
}

Date :: struct {
	year, month, day: int,
}

is_leap :: proc(y: int) -> bool {
	return (y % 4 == 0 && y % 100 != 0) || y % 400 == 0
}

days_in_month :: proc(y, m: int) -> int {
	switch m {
	case 2:
		return is_leap(y) ? 29 : 28
	case 4, 6, 9, 11:
		return 30
	}
	return 31
}

valid :: proc(d: Date) -> bool {
	return d.year >= 1800 && d.year <= 2200 && d.month >= 1 && d.month <= 12 && d.day >= 1 &&
		d.day <= days_in_month(d.year, d.month)
}

// Days since 1970-01-01 (Howard Hinnant's days_from_civil).
day_number :: proc(d: Date) -> int {
	y := d.month <= 2 ? d.year - 1 : d.year
	era := (y >= 0 ? y : y - 399) / 400
	yoe := y - era * 400
	mp := d.month > 2 ? d.month - 3 : d.month + 9
	doy := (153 * mp + 2) / 5 + d.day - 1
	doe := yoe * 365 + yoe / 4 - yoe / 100 + doy
	return era * 146097 + doe - 719468
}

// Day of the week, 0 Sunday.
weekday :: proc(d: Date) -> int {
	return ((day_number(d) + 4) % 7 + 7) % 7
}

// Days lived on the given date (0 on the birthday itself).
age_days :: proc(birth, on: Date) -> int {
	return day_number(on) - day_number(birth)
}

// The curve's height, -1 to 1, at the start of a day of life.
value :: proc(r: Rhythm, days: int) -> f64 {
	p := f64(PERIOD[r])
	return math.sin(2 * math.PI * f64(days) / p)
}

// A curve is critical on a day when it crosses the axis during that day (or sits on it).
critical :: proc(r: Rhythm, days: int) -> bool {
	if days < 0 {return false}
	p := PERIOD[r]
	// Crossings fall at every half period, k*p/2; the day [d, d+1) holds one when a multiple
	// of p lies in [2d, 2d+2).
	return (days * 2) % p == 0 || (days * 2 + 1) % p == 0
}

// The listing's sum on a day: 0 when nothing crosses.
critical_sum :: proc(days: int) -> int {
	s := 0
	for r in Rhythm {if critical(r, days) {s += NUMBER[r]}}
	return s
}

// Where each rhythm is in its cycle, as the readout tells it.
Phase :: enum {
	High,
	Low,
	Critical,
}

phase :: proc(r: Rhythm, days: int) -> Phase {
	if critical(r, days) {return .Critical}
	return value(r, days) > 0 ? .High : .Low
}

// Percent, -100 to 100, for the readout.
percent :: proc(r: Rhythm, days: int) -> int {
	return int(math.round(value(r, days) * 100))
}

add_months :: proc(y, m, n: int) -> (int, int) {
	k := y * 12 + (m - 1) + n
	return k / 12, k % 12 + 1
}

// The date for a day number (days since 1970-01-01).
from_day_number :: proc(n: int) -> Date {
	z := n + 719468
	era := (z >= 0 ? z : z - 146096) / 146097
	doe := z - era * 146097
	yoe := (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
	y := yoe + era * 400
	doy := doe - (365 * yoe + yoe / 4 - yoe / 100)
	mp := (5 * doy + 2) / 153
	d := doy - (153 * mp + 2) / 5 + 1
	m := mp < 10 ? mp + 3 : mp - 9
	if m <= 2 {y += 1}
	return {y, m, d}
}
