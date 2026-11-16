#+build js
package gfx

// Drawing, sound and storage for the SoftSide prototypes; the page side is shared/web/shim.js.
// Coordinates are logical pixels of the game's fixed canvas. Text is Public Pixel: every glyph
// is 8 by 8 at size 1 (16 by 16 at size 2), so a string is len*8*size wide.

foreign import host "gfx"

@(default_calling_convention = "contextless")
foreign host {
	gfx_now_ms :: proc() -> f64 ---
	gfx_random :: proc() -> f64 ---
	gfx_clear :: proc(rgb: u32) ---
	gfx_rect :: proc(x, y, w, h: f32, rgb: u32) ---
	gfx_frame :: proc(x, y, w, h: f32, rgb: u32) ---
	gfx_text :: proc(x, y: f32, ptr: [^]u8, len: i32, rgb: u32, size: i32) ---
	gfx_tone :: proc(freq, ms: f32, wave: i32, gain: f32, delay_ms: f32) ---
	gfx_noise :: proc(ms: f32, gain: f32, delay_ms: f32) ---
	gfx_audio_time_ms :: proc() -> f64 ---
	gfx_store_set :: proc(kp: [^]u8, kl: i32, vp: [^]u8, vl: i32) ---
	gfx_store_get :: proc(kp: [^]u8, kl: i32, buf: [^]u8, cap: i32) -> i32 ---
}

Wave :: enum i32 {
	Square,
	Sine,
	Saw,
	Triangle,
}

CELL :: 8

now_ms :: proc() -> f64 {return gfx_now_ms()}
random :: proc() -> f64 {return gfx_random()}
clear :: proc(rgb: u32) {gfx_clear(rgb)}

rect :: proc(x, y, w, h: int, rgb: u32) {
	gfx_rect(f32(x), f32(y), f32(w), f32(h), rgb)
}

rectf :: proc(x, y, w, h: f32, rgb: u32) {
	gfx_rect(x, y, w, h, rgb)
}

frame :: proc(x, y, w, h: int, rgb: u32) {
	gfx_frame(f32(x), f32(y), f32(w), f32(h), rgb)
}

text :: proc(x, y: int, s: string, rgb: u32, size := 1) {
	if len(s) == 0 {return}
	str := s
	gfx_text(f32(x), f32(y), raw_data(str), i32(len(str)), rgb, i32(size))
}

text_width :: proc(s: string, size := 1) -> int {
	return len(s) * CELL * size
}

// Text centred on x.
text_c :: proc(cx, y: int, s: string, rgb: u32, size := 1) {
	text(cx - text_width(s, size) / 2, y, s, rgb, size)
}

tone :: proc(freq, ms: f32, wave := Wave.Square, gain: f32 = 0.08, delay_ms: f32 = 0) {
	gfx_tone(freq, ms, i32(wave), gain, delay_ms)
}

noise :: proc(ms: f32, gain: f32 = 0.1, delay_ms: f32 = 0) {
	gfx_noise(ms, gain, delay_ms)
}

audio_time_ms :: proc() -> f64 {return gfx_audio_time_ms()}

store_set :: proc(key, value: string) {
	k, v := key, value
	gfx_store_set(raw_data(k), i32(len(k)), raw_data(v), i32(len(v)))
}

// Returns the stored value in buf (ok false when missing or larger than buf).
store_get :: proc(key: string, buf: []u8) -> (value: string, ok: bool) {
	k := key
	n := gfx_store_get(raw_data(k), i32(len(k)), raw_data(buf), i32(len(buf)))
	if n < 0 || int(n) > len(buf) {return "", false}
	return string(buf[:n]), true
}

// ---- buttons: drawn each frame, tapped through hit ----

Button :: struct {
	x, y, w, h: int,
	id:         int,
}

MAX_BUTTONS :: 96

@(private)
buttons: [MAX_BUTTONS]Button
@(private)
button_count: int

// Call at the start of every frame's drawing.
begin_buttons :: proc() {
	button_count = 0
}

// Registers a tappable area (drawing is up to the caller).
zone :: proc(x, y, w, h: int, id: int) {
	if button_count < MAX_BUTTONS {
		buttons[button_count] = {x, y, w, h, id}
		button_count += 1
	}
}

// A framed text button; returns its width.
button :: proc(x, y: int, label: string, id: int, fg, bg: u32, size := 1) -> int {
	w := text_width(label, size) + 8 * size
	h := CELL * size + 6 * size
	rect(x, y, w, h, bg)
	frame(x, y, w, h, fg)
	text(x + 4 * size, y + 3 * size, label, fg, size)
	zone(x, y, w, h, id)
	return w
}

// The id of the last-drawn zone under (x, y), or -1.
hit :: proc(x, y: f32) -> int {
	for i := button_count - 1; i >= 0; i -= 1 {
		b := buttons[i]
		if x >= f32(b.x) && x < f32(b.x + b.w) && y >= f32(b.y) && y < f32(b.y + b.h) {
			return b.id
		}
	}
	return -1
}

// Key codes the shim sends (printable keys send their upper-case character).
KEY_BACKSPACE :: 8
KEY_TAB :: 9
KEY_ENTER :: 13
KEY_ESCAPE :: 27
KEY_SPACE :: 32
KEY_LEFT :: 256
KEY_UP :: 257
KEY_RIGHT :: 258
KEY_DOWN :: 259
KEY_DELETE :: 260
