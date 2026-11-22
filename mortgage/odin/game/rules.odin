package mortgage

// Mortgage: a tool. After "Mortgage Calculation" by Russell Starkey (SoftSide, December 1978):
// the amount borrowed, the interest a year, payments a year and years to repay, then a schedule
// of every payment with its interest and principal, the interest and principal to date and the
// balance left, shown by period or by year from a starting month. New here: the numbers are
// edited in place and the schedule follows at once, totals, a chart of interest against principal,
// and an extra payment each period to see how much sooner the loan is paid.
// Pure rules: no platform imports.

import "core:math"

MAX_ROWS :: 52 * 50 // weekly for fifty years

Loan :: struct {
	amount:      f64, // PV
	rate:        f64, // percent a year (I)
	per_year:    int, // N
	years:       int, // Y
	extra:       f64, // paid on top of every payment (new)
	start_month: int, // 1-12
	start_year:  int,
}

Row :: struct {
	n:            int, // payment number, 1 first
	payment:      f64,
	interest:     f64,
	principal:    f64,
	interest_sum: f64,
	principal_sum: f64,
	balance:      f64,
}

Schedule :: struct {
	rows:     [MAX_ROWS]Row,
	count:    int,
	payment:  f64, // the regular payment, before any extra
	total:    f64, // everything paid
	interest: f64, // all the interest
	ok:       bool,
}

valid :: proc(l: Loan) -> bool {
	return l.amount >= 1 && l.rate >= 0 && l.rate <= 100 && l.per_year >= 1 && l.per_year <= 52 &&
		l.years >= 1 && l.years * l.per_year <= MAX_ROWS && l.extra >= 0
}

cents :: proc(x: f64) -> f64 {
	return math.round(x * 100) / 100
}

// The listing's line 600: PMT = PV * IA / (1 - (1 + IA) ^ -(N * Y)), IA the rate a period.
payment :: proc(l: Loan) -> f64 {
	n := f64(l.per_year * l.years)
	ia := l.rate / 100 / f64(l.per_year)
	if ia == 0 {return cents(l.amount / n)}
	return cents(l.amount * ia / (1 - math.pow(1 + ia, -n)))
}

build :: proc(l: Loan, s: ^Schedule) {
	s.count = 0
	s.total = 0
	s.interest = 0
	s.ok = valid(l)
	if !s.ok {return}
	s.payment = payment(l)
	ia := l.rate / 100 / f64(l.per_year)
	bal := l.amount
	isum, psum: f64
	last := l.per_year * l.years
	for k in 1 ..= last {
		if bal <= 0.004 {break}
		it := cents(bal * ia)
		pay := s.payment + l.extra
		// The last payment (or one the extra makes the last) clears what is left.
		if k == last || pay >= bal + it {pay = cents(bal + it)}
		pr := cents(pay - it)
		bal = cents(bal - pr)
		isum += it
		psum += pr
		s.rows[s.count] = {k, pay, it, pr, cents(isum), cents(psum), bal}
		s.count += 1
		s.total += pay
		s.interest += it
	}
	s.total = cents(s.total)
	s.interest = cents(s.interest)
}

// The month (1-12) and year a payment falls in, payments spread evenly over the year.
when_paid :: proc(l: Loan, n: int) -> (month, year: int) {
	months := (n - 1) * 12 / l.per_year
	m := l.start_month - 1 + months
	return m % 12 + 1, l.start_year + m / 12
}

// One line a year (by the loan's years, not the calendar): the sums of that year's payments.
Year_Row :: struct {
	year:      int, // 1 first
	paid:      f64,
	interest:  f64,
	principal: f64,
	balance:   f64,
}

year_row :: proc(l: Loan, s: ^Schedule, y: int) -> (r: Year_Row, ok: bool) {
	first := (y - 1) * l.per_year
	if first >= s.count {return {}, false}
	r.year = y
	for i in first ..< min(s.count, first + l.per_year) {
		r.paid += s.rows[i].payment
		r.interest += s.rows[i].interest
		r.principal += s.rows[i].principal
		r.balance = s.rows[i].balance
	}
	r.paid = cents(r.paid)
	r.interest = cents(r.interest)
	r.principal = cents(r.principal)
	return r, true
}

year_count :: proc(l: Loan, s: ^Schedule) -> int {
	if s.count == 0 {return 0}
	return (s.count + l.per_year - 1) / l.per_year
}

// Money with thousands separators and cents: 1,234,567.89.
money :: proc(buf: []u8, x: f64) -> string {
	v := i64(math.round(abs(x) * 100))
	whole := v / 100
	c := v % 100
	tmp: [32]u8
	n := 0
	tmp[n] = u8('0' + c % 10); n += 1
	tmp[n] = u8('0' + c / 10); n += 1
	tmp[n] = '.'; n += 1
	digits := 0
	for {
		if digits > 0 && digits % 3 == 0 {tmp[n] = ','; n += 1}
		tmp[n] = u8('0' + whole % 10)
		n += 1
		digits += 1
		whole /= 10
		if whole == 0 {break}
	}
	if x < 0 && v != 0 {tmp[n] = '-'; n += 1}
	out := 0
	for i := n - 1; i >= 0 && out < len(buf); i -= 1 {
		buf[out] = tmp[i]
		out += 1
	}
	return string(buf[:out])
}
