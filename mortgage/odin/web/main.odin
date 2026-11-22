#+build js
package main

// Mortgage's page: the loan on the left, edited in place, the schedule and a chart on the right.
// Rules are in ../game.

import "base:runtime"
import "core:fmt"
import "core:strconv"
import mg "../game"
import "proto:gfx"

W :: 640
H :: 360

PAPER :: 0xf2ecd8
PAPER_LINE :: 0xd8cfb0
GREEN_BAR :: 0xdfead0
INK :: 0x23303a
INK_DIM :: 0x7a8088
BLUE :: 0x2a5a9a
RED :: 0xb03a2e
DESK :: 0x3a4a52
DESK_LIT :: 0x52646e
KEY :: 0x2a363e
KEY_TEXT :: 0xf2ecd8
GOLD :: 0xe0b050
INTEREST_C :: 0xc8603a
PRINCIPAL_C :: 0x3a7ab0

Field :: enum {
	Amount,
	Rate,
	Per_Year,
	Years,
	Extra,
	Start,
}

FIELD_NAMES := [Field]string {
	.Amount   = "AMOUNT BORROWED",
	.Rate     = "INTEREST / YEAR %",
	.Per_Year = "PAYMENTS / YEAR",
	.Years    = "YEARS TO REPAY",
	.Extra    = "EXTRA EACH PAYMENT",
	.Start    = "FIRST PAYMENT",
}

PER_YEAR_CHOICES := [?]int{1, 2, 4, 12, 26, 52}
MONTHS := [?]string{"JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"}

ID_FIELD :: 10 // + field
ID_MINUS :: 20 // + field
ID_PLUS :: 30 // + field
ID_KEY :: 40 // + index into PAD
ID_VIEW :: 2
ID_UP :: 3
ID_DOWN :: 4
ID_TOP :: 5

PAD := "789456123.0<"

App :: struct {
	loan:     mg.Loan,
	sched:    mg.Schedule,
	editing:  bool,
	field:    Field,
	entry:    [12]u8,
	entry_n:  int,
	by_year:  bool,
	scroll:   int,
	t:        f32,
}

app: App

main :: proc() {
	app.loan = {amount = 200000, rate = 6, per_year = 12, years = 30, start_month = 1, start_year = 2027}
	buf: [128]u8
	if v, ok := gfx.store_get("loan", buf[:]); ok {load(v)}
	rebuild()
}

// Saved as "amount rate per_year years extra month year".
load :: proc(v: string) {
	vals: [7]f64
	n := 0
	start := 0
	for i in 0 ..= len(v) {
		if i == len(v) || v[i] == ' ' {
			if i > start && n < 7 {
				if f, ok := strconv.parse_f64(v[start:i]); ok {vals[n] = f}
				n += 1
			}
			start = i + 1
		}
	}
	if n != 7 {return}
	l := mg.Loan{vals[0], vals[1], int(vals[2]), int(vals[3]), vals[4], int(vals[5]), int(vals[6])}
	if mg.valid(l) && l.start_month >= 1 && l.start_month <= 12 {app.loan = l}
}

save :: proc() {
	l := app.loan
	gfx.store_set("loan", fmt.tprintf("%.2f %.4f %d %d %.2f %d %d", l.amount, l.rate, l.per_year, l.years, l.extra, l.start_month, l.start_year))
}

rebuild :: proc() {
	mg.build(app.loan, &app.sched)
	app.scroll = clamp(app.scroll, 0, max(0, rows_total() - ROWS))
	save()
}

rows_total :: proc() -> int {
	return app.by_year ? mg.year_count(app.loan, &app.sched) : app.sched.count
}

@(export)
step :: proc(dt: f64) -> bool {
	app.t += f32(min(dt, 0.1))
	draw()
	free_all(context.temp_allocator)
	return true
}

// ---- editing ----

begin_edit :: proc(f: Field) {
	if f == .Per_Year || f == .Start {return} // steppers only
	app.editing = true
	app.field = f
	app.entry_n = 0
}

type_key :: proc(ch: u8) {
	if !app.editing {return}
	switch ch {
	case '<':
		if app.entry_n > 0 {app.entry_n -= 1}
	case '.':
		if app.field == .Years {return}
		for i in 0 ..< app.entry_n {if app.entry[i] == '.' {return}}
		if app.entry_n < len(app.entry) {app.entry[app.entry_n] = '.'; app.entry_n += 1}
	case '0' ..= '9':
		if app.entry_n < len(app.entry) {app.entry[app.entry_n] = ch; app.entry_n += 1}
	}
	gfx.tone(1100, 12, .Square, 0.02)
}

finish_edit :: proc() {
	if !app.editing {return}
	app.editing = false
	if app.entry_n == 0 {return}
	v, ok := strconv.parse_f64(string(app.entry[:app.entry_n]))
	if !ok {return}
	l := app.loan
	switch app.field {
	case .Amount:
		l.amount = v
	case .Rate:
		l.rate = v
	case .Years:
		l.years = int(v)
	case .Extra:
		l.extra = v
	case .Per_Year, .Start:
	}
	if mg.valid(l) {
		app.loan = l
		gfx.tone(880, 40, .Square, 0.03)
	} else {
		gfx.tone(140, 160, .Saw, 0.04) // the listing asked again; we keep the old number
	}
	rebuild()
}

step_field :: proc(f: Field, dir: int) {
	l := app.loan
	switch f {
	case .Amount:
		l.amount = max(1000, l.amount + f64(dir) * 1000)
	case .Rate:
		l.rate = clamp(l.rate + f64(dir) * 0.125, 0, 100)
	case .Per_Year:
		k := 0
		for c, i in PER_YEAR_CHOICES {if c == l.per_year {k = i}}
		k = clamp(k + dir, 0, len(PER_YEAR_CHOICES) - 1)
		l.per_year = PER_YEAR_CHOICES[k]
	case .Years:
		l.years = clamp(l.years + dir, 1, 50)
	case .Extra:
		l.extra = max(0, l.extra + f64(dir) * 50)
	case .Start:
		m := l.start_year * 12 + l.start_month - 1 + dir
		l.start_year = m / 12
		l.start_month = m % 12 + 1
	}
	if mg.valid(l) {
		app.loan = l
		rebuild()
		gfx.tone(dir > 0 ? 900 : 700, 15, .Square, 0.03)
	}
}

click :: proc(id: int) {
	switch {
	case id >= ID_KEY:
		type_key(PAD[id - ID_KEY])
	case id >= ID_PLUS:
		finish_edit()
		step_field(Field(id - ID_PLUS), 1)
	case id >= ID_MINUS:
		finish_edit()
		step_field(Field(id - ID_MINUS), -1)
	case id >= ID_FIELD:
		f := Field(id - ID_FIELD)
		if app.editing && app.field == f {finish_edit()} else {
			finish_edit()
			begin_edit(f)
		}
	case id == ID_VIEW:
		app.by_year = !app.by_year
		app.scroll = 0
		gfx.tone(800, 20, .Square, 0.03)
	case id == ID_UP:
		app.scroll = max(0, app.scroll - ROWS)
	case id == ID_DOWN:
		app.scroll = clamp(app.scroll + ROWS, 0, max(0, rows_total() - ROWS))
	case id == ID_TOP:
		app.scroll = 0
	}
}

// ---- input ----

@(export)
on_key :: proc "c" (code: i32, down: i32) {
	context = runtime.default_context()
	if down == 0 {return}
	c := int(code)
	if app.editing {
		switch c {
		case gfx.KEY_ENTER, gfx.KEY_TAB:
			f := app.field
			finish_edit()
			if c == gfx.KEY_TAB {begin_edit(next_typed(f))}
		case gfx.KEY_ESCAPE:
			app.editing = false
		case gfx.KEY_BACKSPACE, gfx.KEY_DELETE:
			type_key('<')
		case '0' ..= '9', '.':
			type_key(u8(c))
		}
		return
	}
	switch c {
	case gfx.KEY_UP:
		app.scroll = max(0, app.scroll - 1)
	case gfx.KEY_DOWN:
		app.scroll = clamp(app.scroll + 1, 0, max(0, rows_total() - ROWS))
	case gfx.KEY_LEFT:
		click(ID_UP)
	case gfx.KEY_RIGHT, gfx.KEY_SPACE:
		click(ID_DOWN)
	case 'V', 'Y', 'P':
		click(ID_VIEW)
	case gfx.KEY_TAB, gfx.KEY_ENTER:
		begin_edit(.Amount)
	case 'A':
		begin_edit(.Amount)
	case 'I', 'R':
		begin_edit(.Rate)
	case 'E':
		begin_edit(.Extra)
	}
}

next_typed :: proc(f: Field) -> Field {
	switch f {
	case .Amount: return .Rate
	case .Rate: return .Years
	case .Years: return .Extra
	case .Extra, .Per_Year, .Start: return .Amount
	}
	return .Amount
}

@(export)
on_pointer :: proc "c" (x, y: f32, kind: i32) {
	context = runtime.default_context()
	if kind != 0 {return}
	id := gfx.hit(x, y)
	if id > 0 {click(id)} else if app.editing {finish_edit()}
}

// ---- drawing ----

LX :: 8
LW :: 208
RX :: 224
RW :: W - RX - 8
ROWS :: 18

field_value :: proc(f: Field) -> string {
	l := app.loan
	buf := make([]u8, 32, context.temp_allocator)
	switch f {
	case .Amount:
		return mg.money(buf, l.amount)
	case .Rate:
		return fmt.tprintf("%.3f", l.rate)
	case .Per_Year:
		name := ""
		switch l.per_year {
		case 1: name = " YEARLY"
		case 2: name = " HALF-YEARLY"
		case 4: name = " QUARTERLY"
		case 12: name = " MONTHLY"
		case 26: name = " FORTNIGHTLY"
		case 52: name = " WEEKLY"
		}
		return fmt.tprintf("%d%s", l.per_year, name)
	case .Years:
		return fmt.tprintf("%d", l.years)
	case .Extra:
		return mg.money(buf, l.extra)
	case .Start:
		return fmt.tprintf("%s %d", MONTHS[l.start_month - 1], l.start_year)
	}
	return ""
}

draw :: proc() {
	gfx.clear(DESK)
	gfx.begin_buttons()
	gfx.text(LX, 8, "MORTGAGE", GOLD, 2)
	gfx.text(LX + 136, 13, "A TOOL", 0xa8b4bc)
	draw_fields()
	if app.editing {draw_pad()} else {draw_totals()}
	draw_schedule()
	draw_chart()
}

draw_fields :: proc() {
	y := 30
	for f in Field {
		editing := app.editing && app.field == f
		gfx.text(LX, y, FIELD_NAMES[f], 0xa8b4bc)
		bx, by, bw, bh := LX, y + 10, LW - 40, 16
		gfx.rect(bx, by, bw, bh, editing ? 0xffffff : PAPER)
		gfx.frame(bx, by, bw, bh, editing ? GOLD : DESK_LIT)
		v := editing ? string(app.entry[:app.entry_n]) : field_value(f)
		gfx.text(bx + 4, by + 4, v, editing ? BLUE : INK)
		if editing && int(app.t * 2) % 2 == 0 {gfx.rect(bx + 4 + len(v) * 8, by + 12, 7, 1, BLUE)}
		gfx.zone(bx, by, bw, bh, ID_FIELD + int(f))
		small_key(LX + LW - 38, by, "-", ID_MINUS + int(f))
		small_key(LX + LW - 18, by, "+", ID_PLUS + int(f))
		y += 30
	}
}

small_key :: proc(x, y: int, label: string, id: int) {
	gfx.rect(x, y, 18, 16, KEY)
	gfx.frame(x, y, 18, 16, DESK_LIT)
	gfx.text_c(x + 9, y + 4, label, KEY_TEXT)
	gfx.zone(x, y, 18, 16, id)
}

draw_totals :: proc() {
	s := &app.sched
	y := 214
	gfx.rect(LX, y, LW, H - y - 8, PAPER)
	gfx.frame(LX, y, LW, H - y - 8, PAPER_LINE)
	if !s.ok {
		gfx.text(LX + 6, y + 8, "NOT A LOAN I CAN WORK OUT", RED)
		return
	}
	buf: [32]u8
	gfx.text(LX + 6, y + 6, "PAYMENT", INK_DIM)
	gfx.text(LX + 6, y + 16, mg.money(buf[:], s.payment), INK, 2)
	if app.loan.extra > 0 {
		gfx.text(LX + 6, y + 36, fmt.tprintf("+ %s EXTRA", mg.money(buf[:], app.loan.extra)), BLUE)
	}
	gfx.text(LX + 6, y + 50, "TOTAL PAID", INK_DIM)
	gfx.text(LX + 100, y + 50, mg.money(buf[:], s.total), INK)
	gfx.text(LX + 6, y + 62, "INTEREST", INK_DIM)
	gfx.text(LX + 100, y + 62, mg.money(buf[:], s.interest), INTEREST_C)
	m, yr := mg.when_paid(app.loan, s.count)
	gfx.text(LX + 6, y + 74, "PAID OFF", INK_DIM)
	gfx.text(LX + 100, y + 74, fmt.tprintf("%s %d", MONTHS[m - 1], yr), INK)
	gfx.text(LX + 6, y + 86, fmt.tprintf("%d PAYMENTS", s.count), INK_DIM)
	if app.loan.extra > 0 {
		saved := app.loan.per_year * app.loan.years - s.count
		gfx.text(LX + 6, y + 98, fmt.tprintf("%d SOONER", saved), BLUE)
	}
	gfx.text(LX + 6, y + 120, "TAP A NUMBER TO TYPE IT", INK_DIM)
}

draw_pad :: proc() {
	y := 214
	KW :: 64
	KH :: 24
	for i in 0 ..< len(PAD) {
		x := LX + (i % 3) * (KW + 8)
		ky := y + (i / 3) * (KH + 4)
		ch := PAD[i]
		gfx.rect(x, ky, KW, KH, KEY)
		gfx.frame(x, ky, KW, KH, DESK_LIT)
		label := ch == '<' ? "DEL" : string([]u8{ch})
		gfx.text_c(x + KW / 2, ky + 8, label, KEY_TEXT)
		gfx.zone(x, ky, KW, KH, ID_KEY + i)
	}
	gfx.text(LX, H - 14, "ENTER OR TAP THE BOX: DONE", 0xa8b4bc)
}

col_r :: proc(right, y: int, s: string, c: u32) {
	gfx.text(right - gfx.text_width(s), y, s, c)
}

draw_schedule :: proc() {
	s := &app.sched
	l := app.loan
	top := 8
	gfx.rect(RX, top, RW, 222, PAPER)
	// Green-bar paper.
	for r in 0 ..< ROWS {
		if r % 2 == 0 {gfx.rect(RX, top + 26 + r * 10, RW, 10, GREEN_BAR)}
	}
	gfx.frame(RX, top, RW, 222, PAPER_LINE)
	gfx.button(RX + 4, top + 3, app.by_year ? "BY YEAR" : "BY PAYMENT", ID_VIEW, BLUE, PAPER)
	gfx.button(RX + RW - 84, top + 3, "^", ID_UP, INK, PAPER)
	gfx.button(RX + RW - 62, top + 3, "v", ID_DOWN, INK, PAPER)
	gfx.button(RX + RW - 40, top + 3, "TOP", ID_TOP, INK, PAPER)
	if !s.ok {return}
	total := rows_total()
	gfx.text(RX + 110, top + 6, fmt.tprintf("%d-%d OF %d", app.scroll + 1, min(total, app.scroll + ROWS), total), INK_DIM)
	hy := top + 18
	buf: [32]u8
	c1, c2, c3, c4 := RX + 150, RX + 236, RX + 316, RX + RW - 6
	if app.by_year {
		gfx.text(RX + 6, hy, "YEAR", INK_DIM)
		col_r(c1, hy, "PAID", INK_DIM)
		col_r(c2, hy, "INTEREST", INK_DIM)
		col_r(c3, hy, "PRINCIPAL", INK_DIM)
		col_r(c4, hy, "BALANCE", INK_DIM)
		for r in 0 ..< ROWS {
			yr, ok := mg.year_row(l, s, app.scroll + r + 1)
			if !ok {break}
			y := top + 27 + r * 10
			_, cal := mg.when_paid(l, (yr.year - 1) * l.per_year + 1)
			gfx.text(RX + 6, y, fmt.tprintf("%2d %d", yr.year, cal), INK)
			col_r(c1, y, mg.money(buf[:], yr.paid), INK)
			col_r(c2, y, mg.money(buf[:], yr.interest), INTEREST_C)
			col_r(c3, y, mg.money(buf[:], yr.principal), PRINCIPAL_C)
			col_r(c4, y, mg.money(buf[:], yr.balance), INK)
		}
	} else {
		gfx.text(RX + 6, hy, "NO. DATE", INK_DIM)
		col_r(c1, hy, "PAYMENT", INK_DIM)
		col_r(c2, hy, "INTEREST", INK_DIM)
		col_r(c3, hy, "PRINCIPAL", INK_DIM)
		col_r(c4, hy, "BALANCE", INK_DIM)
		for r in 0 ..< ROWS {
			i := app.scroll + r
			if i >= s.count {break}
			row := s.rows[i]
			y := top + 27 + r * 10
			m, yr := mg.when_paid(l, row.n)
			gfx.text(RX + 6, y, fmt.tprintf("%3d %s%02d", row.n, MONTHS[m - 1], yr % 100), INK)
			col_r(c1, y, mg.money(buf[:], row.payment), INK)
			col_r(c2, y, mg.money(buf[:], row.interest), INTEREST_C)
			col_r(c3, y, mg.money(buf[:], row.principal), PRINCIPAL_C)
			col_r(c4, y, mg.money(buf[:], row.balance), INK)
		}
		// The listing's running sums, for the last row shown.
		last := min(s.count, app.scroll + ROWS) - 1
		if last >= 0 {
			row := s.rows[last]
			b2: [32]u8
			gfx.text(RX + 6, top + 210, fmt.tprintf("TO NO. %d: INTEREST %s  PRINCIPAL %s", row.n, mg.money(buf[:], row.interest_sum), mg.money(b2[:], row.principal_sum)), INK_DIM)
		}
	}
}

// Each year's payments split into interest and principal.
draw_chart :: proc() {
	s := &app.sched
	l := app.loan
	top := 238
	ch := H - top - 8
	gfx.rect(RX, top, RW, ch, PAPER)
	gfx.frame(RX, top, RW, ch, PAPER_LINE)
	gfx.rect(RX + 6, top + 6, 8, 8, INTEREST_C)
	gfx.text(RX + 18, top + 6, "INTEREST", INK_DIM)
	gfx.rect(RX + 92, top + 6, 8, 8, PRINCIPAL_C)
	gfx.text(RX + 104, top + 6, "PRINCIPAL, EACH YEAR", INK_DIM)
	if !s.ok {return}
	n := mg.year_count(l, s)
	if n == 0 {return}
	peak := 0.0
	for y in 1 ..= n {
		r, _ := mg.year_row(l, s, y)
		peak = max(peak, r.paid)
	}
	area_h := ch - 26
	base := top + ch - 6
	bw := max(1, (RW - 12) / n)
	for y in 1 ..= n {
		r, _ := mg.year_row(l, s, y)
		x := RX + 6 + (y - 1) * bw
		ih := int(r.interest / peak * f64(area_h))
		ph := int(r.principal / peak * f64(area_h))
		w := max(1, bw - 1)
		gfx.rect(x, base - ih, w, ih, INTEREST_C)
		gfx.rect(x, base - ih - ph, w, ph, PRINCIPAL_C)
	}
}
