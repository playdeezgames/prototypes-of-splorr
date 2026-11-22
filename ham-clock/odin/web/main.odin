#+build js
package main

// Ham Shack Clock's page: local time and GMT, the on-air tally and the station ID reminder.
// Rules are in ../game.

import "base:runtime"
import "core:fmt"
import "core:strconv"
import hc "../game"
import "proto:gfx"

W :: 384
H :: 240

PANEL :: 0x1c1f22
PANEL_LIT :: 0x2c3136
BEZEL :: 0x8a949c
NIXIE :: 0xffa040
NIXIE_DIM :: 0x4a2c14
GLASS :: 0x0c0806
LABEL :: 0xc8d0d6
LABEL_DIM :: 0x7a848c
RED :: 0xff3a2a
RED_DIM :: 0x5a1a14
GREEN :: 0x7ce07a
KEY :: 0x30363c

ID_AIR :: 1
ID_IDENT :: 2
ID_CALL :: 3
ID_DONE :: 4
ID_MORSE :: 5
ID_KEY :: 100 // + index into KEYS

KEYS := "1234567890QWERTYUIOPASDFGHJKL/ZXCVBNM<"

App :: struct {
	s:        hc.Shack,
	t:        f32,
	typing:   bool,
	save_t:   f32,
	morse_on: bool,
}

app: App

main :: proc() {
	buf: [64]u8
	if v, ok := gfx.store_get("call", buf[:]); ok {hc.set_call(&app.s, v)}
	if v, ok := gfx.store_get("total", buf[:]); ok {
		if n, nok := strconv.parse_f64(v); nok && n >= 0 {app.s.total_s = n}
	}
	app.morse_on = true
	if v, ok := gfx.store_get("morse", buf[:]); ok {app.morse_on = v != "0"}
	if app.s.call_n == 0 {app.typing = true}
}

save :: proc() {
	gfx.store_set("call", hc.call_sign(&app.s))
	gfx.store_set("total", fmt.tprintf("%.0f", app.s.total_s))
	gfx.store_set("morse", app.morse_on ? "1" : "0")
}

@(export)
step :: proc(dt: f64) -> bool {
	d := min(dt, 0.5)
	app.t += f32(d)
	hc.tick(&app.s, d)
	if .Id_Due in app.s.events {
		app.s.events = {}
		reminder()
	}
	app.save_t += f32(d)
	if app.save_t > 10 && app.s.on_air {
		app.save_t = 0
		save()
	}
	draw()
	free_all(context.temp_allocator)
	return true
}

reminder :: proc() {
	gfx.tone(1000, 120, .Sine, 0.06)
	gfx.tone(1000, 120, .Sine, 0.06, 240)
	if app.morse_on {send_call(600)}
}

// The call sign in Morse at about 18 words a minute.
send_call :: proc(delay: f32) {
	DOT :: f32(66)
	at := delay
	call := hc.call_sign(&app.s)
	for i in 0 ..< len(call) {
		code := hc.morse(call[i])
		for j in 0 ..< len(code) {
			ms := code[j] == '.' ? DOT : DOT * 3
			gfx.tone(700, ms, .Sine, 0.05, at)
			at += ms + DOT
		}
		at += DOT * 2
	}
}

click :: proc(id: int) {
	s := &app.s
	switch {
	case id >= ID_KEY:
		ch := KEYS[id - ID_KEY]
		if ch == '<' {hc.rub_out(s)} else {hc.type_call(s, ch)}
		gfx.tone(1200, 12, .Square, 0.02)
	case id == ID_AIR:
		hc.switch_air(s)
		gfx.tone(s.on_air ? 880 : 440, 60, .Square, 0.04)
		save()
	case id == ID_IDENT:
		if s.on_air {
			hc.identified(s)
			gfx.tone(1320, 40, .Sine, 0.04)
		}
	case id == ID_CALL:
		app.typing = true
	case id == ID_DONE:
		app.typing = false
		save()
	case id == ID_MORSE:
		app.morse_on = !app.morse_on
		if app.morse_on {send_call(0)}
		save()
	}
}

// ---- input ----

@(export)
on_key :: proc "c" (code: i32, down: i32) {
	context = runtime.default_context()
	if down == 0 {return}
	c := int(code)
	if app.typing {
		switch c {
		case gfx.KEY_ENTER, gfx.KEY_ESCAPE:
			click(ID_DONE)
		case gfx.KEY_BACKSPACE, gfx.KEY_DELETE:
			hc.rub_out(&app.s)
		case:
			if c < 128 && hc.type_call(&app.s, u8(c)) {gfx.tone(1200, 12, .Square, 0.02)}
		}
		return
	}
	if down != 1 {return}
	switch c {
	case gfx.KEY_SPACE, 'A':
		click(ID_AIR)
	case 'I', gfx.KEY_ENTER:
		click(ID_IDENT)
	case 'C':
		click(ID_CALL)
	case 'M':
		click(ID_MORSE)
	}
}

@(export)
on_pointer :: proc "c" (x, y: f32, kind: i32) {
	context = runtime.default_context()
	if kind != 0 {return}
	id := gfx.hit(x, y)
	if id > 0 {click(id)}
}

// ---- drawing ----

MONTHS := [?]string{"JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"}
DAYS := [?]string{"SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"}

draw :: proc() {
	s := &app.s
	gfx.clear(PANEL)
	gfx.begin_buttons()
	gfx.text(8, 8, "HAM SHACK CLOCK", LABEL)
	gfx.text(W - 8 - gfx.text_width("A TOOL"), 8, "A TOOL", LABEL_DIM)

	now := gfx.now_ms()
	off := gfx.tz_offset_min()
	draw_clock(8, 24, "LOCAL", hc.time_of_day(now, off), hc.date_of(now, off))
	draw_clock(W / 2 + 4, 24, "GMT", hc.time_of_day(now, 0), hc.date_of(now, 0))

	if app.typing {
		draw_keyboard()
		return
	}

	// The call sign, and the reminder flashing it as the listing did.
	cy := 96
	gfx.rect(8, cy, W - 16, 40, GLASS)
	gfx.frame(8, cy, W - 16, 40, BEZEL)
	call := hc.call_sign(s)
	if s.flash > 0 {
		on := int(app.t * 3) % 2 == 0
		gfx.text_c(W / 2, cy + 4, "IDENTIFY YOUR STATION", on ? RED : RED_DIM)
		gfx.text_c(W / 2, cy + 16, call, on ? NIXIE : NIXIE_DIM, 3)
	} else {
		gfx.text(14, cy + 4, "CALL", LABEL_DIM)
		gfx.text_c(W / 2, cy + 16, call, NIXIE, 2)
		gfx.text(W - 14 - gfx.text_width("C: EDIT"), cy + 4, "C: EDIT", LABEL_DIM)
	}
	gfx.zone(8, cy, W - 16, 40, ID_CALL)

	// The switch and the tallies.
	y := 144
	air_bg: u32 = s.on_air ? RED : RED_DIM
	gfx.rect(8, y, 120, 40, air_bg)
	gfx.frame(8, y, 120, 40, s.on_air ? NIXIE : BEZEL)
	gfx.text_c(68, y + 8, "ON AIR", s.on_air ? 0xffffff : LABEL_DIM, 2)
	gfx.text_c(68, y + 28, s.on_air ? "TAP TO GO OFF" : "TAP TO TRANSMIT", s.on_air ? 0xffe0d0 : LABEL_DIM)
	gfx.zone(8, y, 120, 40, ID_AIR)

	sh, sm, ss := hc.hms(s.session_s)
	th, tm, ts := hc.hms(s.total_s)
	gfx.text(140, y + 2, "ON-AIR TIME", LABEL_DIM)
	gfx.text(140, y + 14, fmt.tprintf("%d:%02d:%02d", sh, sm, ss), s.on_air ? NIXIE : LABEL)
	gfx.text(140, y + 28, fmt.tprintf("TOTAL %d:%02d:%02d", th, tm, ts), LABEL_DIM)

	if s.on_air {
		_, im, is := hc.hms(hc.id_in(s))
		gfx.text(262, y + 2, "ID DUE IN", LABEL_DIM)
		gfx.text(262, y + 14, fmt.tprintf("%d:%02d", im, is), im == 0 ? RED : LABEL)
		gfx.button(262, y + 26, "IDENTIFIED", ID_IDENT, GREEN, KEY)
	} else {
		gfx.text(262, y + 2, "ID EVERY", LABEL_DIM)
		gfx.text(262, y + 14, "10 MINUTES", LABEL)
	}

	gfx.button(8, H - 22, app.morse_on ? "MORSE ID: ON" : "MORSE ID: OFF", ID_MORSE, app.morse_on ? LABEL : LABEL_DIM, KEY)
	gfx.text(W - 8 - gfx.text_width("SPACE: AIR  I: IDENTIFIED"), H - 18, "SPACE: AIR  I: IDENTIFIED", LABEL_DIM)
}

draw_clock :: proc(x, y: int, label: string, t: hc.Clock_Time, d: hc.Date) {
	w := W / 2 - 12
	gfx.rect(x, y, w, 64, PANEL_LIT)
	gfx.frame(x, y, w, 64, BEZEL)
	gfx.text(x + 6, y + 5, label, LABEL)
	gfx.text(x + w - 6 - gfx.text_width(DAYS[d.weekday]), y + 5, DAYS[d.weekday], LABEL_DIM)
	gfx.rect(x + 6, y + 16, w - 12, 30, GLASS)
	digits := fmt.tprintf("%02d:%02d:%02d", t.h, t.m, t.s)
	gfx.text_c(x + w / 2 + 1, y + 20, "88:88:88", NIXIE_DIM, 2) // the unlit segments behind
	gfx.text_c(x + w / 2 + 1, y + 20, digits, NIXIE, 2)
	gfx.text_c(x + w / 2, y + 51, fmt.tprintf("%d %s %d", d.day, MONTHS[clamp(d.month - 1, 0, 11)], d.year), LABEL_DIM)
}

draw_keyboard :: proc() {
	s := &app.s
	y := 96
	gfx.text(8, y, "YOUR CALL SIGN", LABEL)
	gfx.rect(8, y + 10, W - 16, 22, GLASS)
	gfx.frame(8, y + 10, W - 16, 22, BEZEL)
	call := hc.call_sign(s)
	gfx.text(16, y + 13, call, NIXIE, 2)
	if int(app.t * 2) % 2 == 0 {gfx.rect(16 + len(call) * 16, y + 28, 14, 2, NIXIE)}
	KW :: 34
	KH :: 18
	rows := [?]int{10, 10, 9, 9}
	k := 0
	for n, r in rows {
		x0 := 8 + (10 - n) * KW / 2
		for i in 0 ..< n {
			ch := KEYS[k]
			x := x0 + i * (KW + 2)
			ky := y + 38 + r * (KH + 2)
			gfx.rect(x, ky, KW, KH, KEY)
			gfx.frame(x, ky, KW, KH, BEZEL)
			label := ch == '<' ? "DEL" : string([]u8{ch})
			gfx.text_c(x + KW / 2, ky + 5, label, LABEL)
			gfx.zone(x, ky, KW, KH, ID_KEY + k)
			k += 1
		}
	}
	gfx.button(W - 8 - 56, y - 4, "DONE", ID_DONE, GREEN, KEY)
}
