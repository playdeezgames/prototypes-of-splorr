package hamclock

// Ham Shack Clock: a tool (working name). After "Six Million Dollar [10K] Clock" by Peter Ashley
// (SoftSide, December 1978), a clock for amateur radio operators: local time and Greenwich Mean
// Time in a box, a tally of on-the-air time, and the call letters flashed for 30 seconds every ten
// minutes as a reminder to identify the station. The original was set by hand and kept time with
// FOR-NEXT loops; this one reads the computer's clock. New here: an ON AIR switch so the tally
// and the ID reminder run only while transmitting, an IDENTIFIED button that restarts the ten
// minutes, the call sign sounded in Morse, and a running total kept between sessions.
// Pure rules: no platform imports.

ID_EVERY_S :: 600.0 // ten minutes
FLASH_S :: 30.0
CALL_MAX :: 10

Event :: enum {
	Id_Due, // the reminder has just come up
}

Shack :: struct {
	call:      [CALL_MAX]u8,
	call_n:    int,
	on_air:    bool,
	session_s: f64, // on the air since the switch went on
	total_s:   f64, // every session, kept between visits
	since_id:  f64, // on-air seconds since the last identification
	flash:     f64, // seconds the call sign has left to flash
	ids:       int, // reminders this session
	events:    bit_set[Event],
}

// Call signs are letters, digits and a slash (portable or a prefix): W1AW, VE3/G4ABC.
valid_call_char :: proc(ch: u8) -> bool {
	return (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9') || ch == '/'
}

type_call :: proc(s: ^Shack, ch: u8) -> bool {
	if !valid_call_char(ch) || s.call_n >= CALL_MAX {return false}
	s.call[s.call_n] = ch
	s.call_n += 1
	return true
}

rub_out :: proc(s: ^Shack) {
	if s.call_n > 0 {s.call_n -= 1}
}

set_call :: proc(s: ^Shack, call: string) {
	s.call_n = 0
	for i in 0 ..< len(call) {
		ch := call[i]
		if ch >= 'a' && ch <= 'z' {ch -= 32}
		type_call(s, ch)
	}
}

call_sign :: proc(s: ^Shack) -> string {
	return string(s.call[:s.call_n])
}

// Going on the air starts a session (and the ten minutes); going off ends it.
switch_air :: proc(s: ^Shack) {
	s.on_air = !s.on_air
	if s.on_air {
		s.session_s = 0
		s.since_id = 0
		s.ids = 0
	}
	s.flash = 0
}

// The station has been identified: the ten minutes start again and the flashing stops.
identified :: proc(s: ^Shack) {
	s.since_id = 0
	s.flash = 0
}

tick :: proc(s: ^Shack, dt: f64) {
	if s.flash > 0 {s.flash = max(0, s.flash - dt)}
	if !s.on_air {return}
	s.session_s += dt
	s.total_s += dt
	s.since_id += dt
	if s.since_id >= ID_EVERY_S {
		s.since_id -= ID_EVERY_S
		s.flash = FLASH_S
		s.ids += 1
		s.events += {.Id_Due}
	}
}

// Seconds until the next reminder (while on the air).
id_in :: proc(s: ^Shack) -> f64 {
	return ID_EVERY_S - s.since_id
}

// Time of day from milliseconds since 1970 (UTC) and a minute offset.
Clock_Time :: struct {
	h, m, s: int,
}

time_of_day :: proc(unix_ms: f64, offset_min: int) -> Clock_Time {
	secs := i64(unix_ms / 1000) + i64(offset_min) * 60
	day := ((secs % 86400) + 86400) % 86400
	return {int(day / 3600), int(day / 60 % 60), int(day % 60)}
}

// Day of the week (0 Sunday) and the date, from milliseconds since 1970 and a minute offset.
Date :: struct {
	year, month, day, weekday: int,
}

date_of :: proc(unix_ms: f64, offset_min: int) -> Date {
	secs := i64(unix_ms / 1000) + i64(offset_min) * 60
	days := secs / 86400
	if secs < 0 && secs % 86400 != 0 {days -= 1}
	wd := int(((days + 4) % 7 + 7) % 7) // 1970-01-01 was a Thursday
	// Civil from days (Howard Hinnant's algorithm).
	z := days + 719468
	era := (z >= 0 ? z : z - 146096) / 146097
	doe := z - era * 146097
	yoe := (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
	y := yoe + era * 400
	doy := doe - (365 * yoe + yoe / 4 - yoe / 100)
	mp := (5 * doy + 2) / 153
	d := doy - (153 * mp + 2) / 5 + 1
	m := mp < 10 ? mp + 3 : mp - 9
	if m <= 2 {y += 1}
	return {int(y), int(m), int(d), wd}
}

// Morse for the call sign's characters: dots and dashes as '.' and '-'.
morse :: proc(ch: u8) -> string {
	switch ch {
	case 'A': return ".-"
	case 'B': return "-..."
	case 'C': return "-.-."
	case 'D': return "-.."
	case 'E': return "."
	case 'F': return "..-."
	case 'G': return "--."
	case 'H': return "...."
	case 'I': return ".."
	case 'J': return ".---"
	case 'K': return "-.-"
	case 'L': return ".-.."
	case 'M': return "--"
	case 'N': return "-."
	case 'O': return "---"
	case 'P': return ".--."
	case 'Q': return "--.-"
	case 'R': return ".-."
	case 'S': return "..."
	case 'T': return "-"
	case 'U': return "..-"
	case 'V': return "...-"
	case 'W': return ".--"
	case 'X': return "-..-"
	case 'Y': return "-.--"
	case 'Z': return "--.."
	case '0': return "-----"
	case '1': return ".----"
	case '2': return "..---"
	case '3': return "...--"
	case '4': return "....-"
	case '5': return "....."
	case '6': return "-...."
	case '7': return "--..."
	case '8': return "---.."
	case '9': return "----."
	case '/': return "-..-."
	}
	return ""
}

// Hours, minutes and seconds of a duration.
hms :: proc(secs: f64) -> (h, m, s: int) {
	t := int(max(secs, 0))
	return t / 3600, t / 60 % 60, t % 60
}
