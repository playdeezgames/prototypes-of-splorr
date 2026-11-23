#+build !js
package sketch

import "core:testing"

@(test)
draw_keys_leave_a_line :: proc(t: ^testing.T) {
	p: Pad
	clear(&p)
	x0, y0 := p.x, p.y
	for _ in 0 ..< 3 {draw(&p, .Right)}
	testing.expect(t, p.dots[y0][x0 + 1] && p.dots[y0][x0 + 2] && p.dots[y0][x0 + 3])
	testing.expect(t, !p.dots[y0][x0]) // the first step moves before it marks
	draw(&p, .Down_Left)
	testing.expect(t, p.dots[y0 + 1][x0 + 2])
}

@(test)
move_keys_erase_and_do_not_draw :: proc(t: ^testing.T) {
	p: Pad
	clear(&p)
	x0, y0 := p.x, p.y
	for _ in 0 ..< 3 {draw(&p, .Right)}
	for _ in 0 ..< 3 {move(&p, .Left)} // back over the line
	testing.expect(t, !p.dots[y0][x0 + 3] && !p.dots[y0][x0 + 2] && !p.dots[y0][x0 + 1])
	move(&p, .Up)
	testing.expect(t, !p.dots[y0 - 1][x0])
}

@(test)
the_border_keeps_the_stylus_in :: proc(t: ^testing.T) {
	p: Pad
	clear(&p)
	for _ in 0 ..< 200 {draw(&p, .Up_Left)}
	testing.expect_value(t, p.x, 0)
	testing.expect_value(t, p.y, 0)
	for _ in 0 ..< 200 {draw(&p, .Down_Right)}
	testing.expect_value(t, p.x, PAD_W - 1)
	testing.expect_value(t, p.y, PAD_H - 1)
}

@(test)
the_listings_keys :: proc(t: ^testing.T) {
	d, drawing, ok := key_dir('M')
	testing.expect(t, ok && drawing && d == .Up_Right)
	d, drawing, ok = key_dir('N')
	testing.expect(t, ok && !drawing && d == .Down)
	_, _, ok = key_dir('C')
	testing.expect(t, !ok) // C clears; the page handles it
}

@(test)
a_sketch_survives_saving :: proc(t: ^testing.T) {
	p: Pad
	clear(&p)
	for _ in 0 ..< 10 {draw(&p, .Up_Right)}
	for _ in 0 ..< 7 {draw(&p, .Down)}
	buf: [ENCODED_MAX]u8
	s := encode(&p, buf[:])
	q: Pad
	testing.expect(t, decode(&q, s))
	testing.expect(t, q.dots == p.dots)
	testing.expect_value(t, q.x, p.x)
	testing.expect_value(t, q.y, p.y)
	testing.expect(t, !decode(&q, "1,2,zz"))
}

@(test)
toward_steps_diagonally :: proc(t: ^testing.T) {
	p: Pad
	home(&p)
	d, ok := toward(&p, p.x + 5, p.y - 2)
	testing.expect(t, ok && d == .Up_Right)
	_, ok = toward(&p, p.x, p.y)
	testing.expect(t, !ok)
}
