#+build !js
package mortgage

import "core:testing"

home :: proc() -> Loan {
	return {amount = 200000, rate = 6, per_year = 12, years = 30, start_month = 1, start_year = 2027}
}

@(test)
the_payment_formula :: proc(t: ^testing.T) {
	testing.expect_value(t, payment(home()), 1199.10)
	l := home()
	l.rate = 0
	testing.expect_value(t, payment(l), 555.56)
}

@(test)
the_schedule_clears_the_loan :: proc(t: ^testing.T) {
	s := new(Schedule)
	defer free(s)
	build(home(), s)
	testing.expect(t, s.ok)
	testing.expect_value(t, s.count, 360)
	first := s.rows[0]
	testing.expect_value(t, first.interest, 1000.00)
	testing.expect_value(t, first.principal, 199.10)
	testing.expect_value(t, first.balance, 199800.90)
	testing.expect_value(t, s.rows[359].balance, 0.0)
	testing.expect(t, abs(s.rows[359].principal_sum - 200000) < 0.01)
	testing.expect(t, abs(s.interest - 231676) < 5)
}

@(test)
an_extra_payment_ends_it_sooner :: proc(t: ^testing.T) {
	s := new(Schedule)
	defer free(s)
	l := home()
	l.extra = 200
	build(l, s)
	testing.expect(t, s.count < 300)
	testing.expect_value(t, s.rows[s.count - 1].balance, 0.0)
	testing.expect(t, s.interest < 180000)
}

@(test)
years_and_dates :: proc(t: ^testing.T) {
	s := new(Schedule)
	defer free(s)
	l := home()
	l.start_month = 11
	build(l, s)
	testing.expect_value(t, year_count(l, s), 30)
	y1, ok := year_row(l, s, 1)
	testing.expect(t, ok)
	testing.expect_value(t, y1.paid, 1199.10 * 12)
	m, y := when_paid(l, 3)
	testing.expect_value(t, m, 1)
	testing.expect_value(t, y, 2028)
	l.per_year = 26
	m, y = when_paid(l, 27)
	testing.expect_value(t, m, 11)
	testing.expect_value(t, y, 2028)
}

@(test)
bad_loans :: proc(t: ^testing.T) {
	l := home()
	l.rate = 101 // the listing asked again over 100
	testing.expect(t, !valid(l))
	l = home()
	l.amount = 0
	testing.expect(t, !valid(l))
}

@(test)
money_reads_well :: proc(t: ^testing.T) {
	buf: [32]u8
	testing.expect_value(t, money(buf[:], 1234567.891), "1,234,567.89")
	testing.expect_value(t, money(buf[:], 0.5), "0.50")
	testing.expect_value(t, money(buf[:], 999), "999.00")
}
