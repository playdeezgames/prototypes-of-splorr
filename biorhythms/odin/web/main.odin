#+build js
package main

// Biorhythms' page: a birth date, a month, three curves. Rules are in ../game.

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:strconv"
import bio "../game"
import "proto:gfx"

W :: 512
H :: 320

SCREEN :: 0x0a0e1a
GRID :: 0x18203a
AXIS :: 0x5a6a9a
TEXT :: 0xd8e0f0
TEXT_DIM :: 0x7080a8
KEY :: 0x222c4a
KEY_LINE :: 0x3a4a7a
TODAY_C :: 0x2a3456
GOLD :: 0xf0c050

CURVE := [bio.Rhythm]u32 {
	.Physical     = 0xff6a5a,
	.Emotional    = 0x5ad890,
	.Intellectual = 0x6aa8ff,
}

NAMES := [bio.Rhythm]string {
	.Physical     = "PHYSICAL",
	.Emotional    = "EMOTIONAL",
	.Intellectual = "INTELLECTUAL",
}

MONTHS := [?]string{"JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"}
DAYS := [?]string{"SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"}

ID_BIRTH :: 10 // + part*4 + {0: -, 1: +, 2: --, 3: ++}
ID_PREV :: 2
ID_NEXT :: 3
ID_TODAY :: 4

App :: struct {
	birth:    bio.Date,
	year:     int,
	month:    int,
	today:    bio.Date,
	selected: int, // day of the chart month under the finger, 0 none
	t:        f32,
}

app: App

main :: proc() {
	app.today = today()
	app.year, app.month = app.today.year, app.today.month
	app.birth = {1978, 12, 1} // the issue's month, until yer own is set
	buf: [32]u8
	if v, ok := gfx.store_get("birth", buf[:]); ok && len(v) == 8 {
		y, _ := strconv.parse_int(v[0:4])
		m, _ := strconv.parse_int(v[4:6])
		d, _ := strconv.parse_int(v[6:8])
		b := bio.Date{y, m, d}
		if bio.valid(b) {app.birth = b}
	}
	app.selected = app.today.day
}

today :: proc() -> bio.Date {
	ms := gfx.now_ms() + f64(gfx.tz_offset_min()) * 60000
	return bio.from_day_number(int(math.floor(ms / 86400000)))
}

save :: proc() {
	b := app.birth
	gfx.store_set("birth", fmt.tprintf("%04d%02d%02d", b.year, b.month, b.day))
}

@(export)
step :: proc(dt: f64) -> bool {
	app.t += f32(min(dt, 0.1))
	draw()
	free_all(context.temp_allocator)
	return true
}

// part 0 day, 1 month, 2 year; big steps are a month of days, a year of months, ten years.
nudge_birth :: proc(part, dir: int) {
	b := app.birth
	switch part {
	case 0:
		n := bio.day_number(b) + dir
		b = bio.from_day_number(n)
	case 1:
		b.year, b.month = bio.add_months(b.year, b.month, dir)
		b.day = min(b.day, bio.days_in_month(b.year, b.month))
	case 2:
		b.year += dir
		b.day = min(b.day, bio.days_in_month(b.year, b.month))
	}
	if bio.valid(b) && bio.day_number(b) <= bio.day_number(app.today) {
		app.birth = b
		save()
		gfx.tone(dir > 0 ? 900 : 700, 15, .Sine, 0.04)
	}
}

change_month :: proc(dir: int) {
	app.year, app.month = bio.add_months(app.year, app.month, dir)
	app.selected = 0
	if app.year == app.today.year && app.month == app.today.month {app.selected = app.today.day}
	gfx.tone(dir > 0 ? 660 : 520, 25, .Sine, 0.04)
}

click :: proc(id: int) {
	switch {
	case id >= ID_BIRTH:
		k := id - ID_BIRTH
		part := k / 4
		steps := [4]int{-1, 1, -10, 10}
		s := steps[k % 4]
		if abs(s) == 10 && part == 0 {s = s > 0 ? 30 : -30}
		if abs(s) == 10 && part == 1 {s = s > 0 ? 12 : -12}
		nudge_birth(part, s)
	case id == ID_PREV:
		change_month(-1)
	case id == ID_NEXT:
		change_month(1)
	case id == ID_TODAY:
		app.today = today()
		app.year, app.month = app.today.year, app.today.month
		app.selected = app.today.day
	}
}

// ---- input ----

@(export)
on_key :: proc "c" (code: i32, down: i32) {
	context = runtime.default_context()
	if down == 0 {return}
	n := bio.days_in_month(app.year, app.month)
	switch int(code) {
	case gfx.KEY_LEFT:
		if app.selected > 1 {app.selected -= 1} else {
			change_month(-1)
			app.selected = bio.days_in_month(app.year, app.month)
		}
	case gfx.KEY_RIGHT:
		if app.selected < n && app.selected > 0 {app.selected += 1} else {
			change_month(1)
			app.selected = 1
		}
	case gfx.KEY_UP, 'P':
		change_month(-1)
	case gfx.KEY_DOWN, 'N':
		change_month(1)
	case 'T':
		click(ID_TODAY)
	}
}

@(export)
on_pointer :: proc "c" (x, y: f32, kind: i32) {
	context = runtime.default_context()
	if y >= f32(CY) && y < f32(CY + CH) && x >= f32(CX) && x < f32(CX + CW) {
		n := bio.days_in_month(app.year, app.month)
		app.selected = clamp(int((x - f32(CX)) / f32(CW) * f32(n)) + 1, 1, n)
	}
	if kind != 0 {return}
	id := gfx.hit(x, y)
	if id > 0 {click(id)}
}

// ---- drawing ----

CX :: 16
CY :: 76
CW :: W - 32
CH :: 168

draw :: proc() {
	gfx.clear(SCREEN)
	gfx.begin_buttons()
	gfx.text(8, 8, "BIORHYTHMS", GOLD, 2)
	gfx.text(W - 8 - gfx.text_width("A TOY"), 8, "A TOY", TEXT_DIM)
	draw_birth()
	draw_month_bar()
	draw_chart()
	draw_readout()
	gfx.text_c(W / 2, H - 12, "JUST FOR FUN: AS THE 1978 ARTICLE SAID, NOT FORTUNE TELLING.", TEXT_DIM)
}

stepper :: proc(x, y: int, label, value: string, part: int, big: bool) -> int {
	gfx.text(x, y, label, TEXT_DIM)
	bx := x
	by := y + 10
	cx := bx
	if big {cx += small(cx, by, "<<", ID_BIRTH + part * 4 + 2)}
	cx += small(cx, by, "-", ID_BIRTH + part * 4 + 0)
	vw := gfx.text_width(value) + 8
	gfx.rect(cx, by, vw, 16, GRID)
	gfx.text(cx + 4, by + 4, value, TEXT)
	cx += vw + 2
	cx += small(cx, by, "+", ID_BIRTH + part * 4 + 1)
	if big {cx += small(cx, by, ">>", ID_BIRTH + part * 4 + 3)}
	return cx - x
}

small :: proc(x, y: int, label: string, id: int) -> int {
	w := gfx.text_width(label) + 8
	gfx.rect(x, y, w, 16, KEY)
	gfx.frame(x, y, w, 16, KEY_LINE)
	gfx.text(x + 4, y + 4, label, TEXT)
	gfx.zone(x, y, w, 16, id)
	return w + 2
}

draw_birth :: proc() {
	b := app.birth
	x := 8
	y := 28
	x += stepper(x, y, "BORN: DAY", fmt.tprintf("%2d", b.day), 0, true) + 8
	x += stepper(x, y, "MONTH", MONTHS[b.month - 1][:3], 1, true) + 8
	x += stepper(x, y, "YEAR", fmt.tprintf("%d", b.year), 2, true) + 8
	lived := bio.age_days(b, app.today)
	gfx.text(x, y, "DAYS LIVED", TEXT_DIM)
	gfx.text(x, y + 14, fmt.tprintf("%d", lived), GOLD)
}

draw_month_bar :: proc() {
	y := 58
	gfx.button(CX, y - 2, "<", ID_PREV, TEXT, KEY)
	title := fmt.tprintf("%s %d", MONTHS[app.month - 1], app.year)
	gfx.text_c(W / 2, y + 2, title, TEXT)
	gfx.button(CX + CW - 16, y - 2, ">", ID_NEXT, TEXT, KEY)
	gfx.button(CX + CW - 76, y - 2, "TODAY", ID_TODAY, TEXT_DIM, KEY)
}

draw_chart :: proc() {
	n := bio.days_in_month(app.year, app.month)
	first := bio.age_days(app.birth, {app.year, app.month, 1})
	gfx.rect(CX, CY, CW, CH, SCREEN)
	gfx.frame(CX, CY, CW, CH, GRID)
	mid := CY + CH / 2
	amp := f64(CH / 2 - 14)
	colw := f64(CW) / f64(n)
	// Today and the selected day.
	for d in 1 ..= n {
		x := CX + int(f64(d - 1) * colw)
		w := int(f64(d) * colw) - int(f64(d - 1) * colw)
		if app.year == app.today.year && app.month == app.today.month && d == app.today.day {
			gfx.rect(x, CY + 1, w, CH - 2, TODAY_C)
		}
		if d == app.selected {gfx.frame(x, CY + 1, w, CH - 2, AXIS)}
		if bio.weekday({app.year, app.month, d}) == 0 {gfx.rect(x, CY + CH - 3, w, 2, GRID)}
	}
	// The axis, broken on critical days with the listing's numbers.
	for d in 1 ..= n {
		x := CX + int(f64(d - 1) * colw)
		w := int(f64(d) * colw) - int(f64(d - 1) * colw)
		days := first + d - 1
		sum := bio.critical_sum(days)
		if sum == 0 || days < 0 {
			gfx.rect(x, mid, w, 1, AXIS)
		} else {
			gfx.text_c(x + w / 2, mid - 3, fmt.tprintf("%d", sum), GOLD)
		}
	}
	// The curves, a pixel at a time across the month (each day's value at its middle).
	if first + n > 0 {
		for r in bio.Rhythm {
			p := f64(bio.PERIOD[r])
			prev_y := -1
			for px in 0 ..< CW {
				t := f64(first) + f64(px) / colw - 0.5
				if t < -0.5 {
					prev_y = -1
					continue
				}
				v := math.sin(2 * math.PI * t / p)
				y := mid - int(math.round(v * amp))
				if prev_y >= 0 {
					lo, hi := min(y, prev_y), max(y, prev_y)
					gfx.rect(CX + px, lo, 1, hi - lo + 1, CURVE[r])
				}
				prev_y = y
			}
		}
	}
	// Day numbers under the chart.
	for d in 1 ..= n {
		if d == 1 || d % 5 == 0 || d == n {
			x := CX + int((f64(d) - 0.5) * colw)
			gfx.text_c(x, CY + CH + 3, fmt.tprintf("%d", d), TEXT_DIM)
		}
	}
	gfx.text(CX + 3, CY + 3, "HIGH", TEXT_DIM)
	gfx.text(CX + 3, CY + CH - 11, "LOW", TEXT_DIM)
}

draw_readout :: proc() {
	y := CY + CH + 16
	if app.selected <= 0 {
		gfx.text(CX, y, "TOUCH THE CHART TO READ A DAY. ARROWS MOVE DAY BY DAY.", TEXT_DIM)
		return
	}
	d := bio.Date{app.year, app.month, app.selected}
	days := bio.age_days(app.birth, d)
	head := fmt.tprintf("%s %d %s", DAYS[bio.weekday(d)], d.day, MONTHS[d.month - 1][:3])
	gfx.text(CX, y, head, TEXT)
	if days < 0 {
		gfx.text(CX + 120, y, "BEFORE YOU WERE BORN", TEXT_DIM)
		return
	}
	sum := bio.critical_sum(days)
	if sum > 0 {
		kind := "CRITICAL DAY"
		if sum == 3 || sum == 5 || sum == 6 {kind = "DOUBLE CRITICAL"}
		if sum == 7 {kind = "TRIPLE CRITICAL"}
		gfx.text(CX + 120, y, fmt.tprintf("%s (%d)", kind, sum), GOLD)
	}
	x := CX
	for r in bio.Rhythm {
		ph := bio.phase(r, days)
		state := ph == .Critical ? "CRITICAL" : ph == .High ? "HIGH" : "LOW"
		gfx.rect(x, y + 13, 8, 8, CURVE[r])
		gfx.text(x + 12, y + 13, fmt.tprintf("%d %s", bio.NUMBER[r], NAMES[r]), CURVE[r])
		gfx.text(x + 12, y + 23, fmt.tprintf("%+d%% %s", bio.percent(r, days), state), TEXT)
		x += 160
	}
}
