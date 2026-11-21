#+build !js
package shopping

import "core:testing"

@(test)
the_shop_fits_the_page :: proc(t: ^testing.T) {
	init()
	testing.expect(t, stock_n > 100 && stock_n <= MAX_STOCK)
	l: List
	ids: [64]int
	for a in 0 ..< OWN_AISLE {
		n := aisle_items(&l, a, ids[:])
		testing.expect(t, n >= 1 && n <= 18) // two columns of nine
	}
	for i in 0 ..< stock_n {
		testing.expect(t, len(stock[i].name) <= NAME_MAX)
		for j in 0 ..< i {testing.expect(t, stock[i].name != stock[j].name)}
	}
}

@(test)
pick_by_tap_or_by_number :: proc(t: ^testing.T) {
	init()
	l: List
	testing.expect(t, add(&l, 0))
	testing.expect(t, add(&l, 0))
	testing.expect_value(t, l.qty[0], 2)
	id, ok := add_number(&l, 5)
	testing.expect(t, ok)
	testing.expect_value(t, id, 4)
	_, ok = add_number(&l, 0)
	testing.expect(t, !ok)
	_, ok = add_number(&l, stock_n + 1)
	testing.expect(t, !ok)
	for _ in 0 ..< 20 {add(&l, 7)}
	testing.expect_value(t, l.qty[7], MAX_QTY)
	remove(&l, 0)
	remove(&l, 0)
	remove(&l, 0)
	testing.expect_value(t, l.qty[0], 0)
	items, _ := count(&l)
	testing.expect_value(t, items, 2)
}

@(test)
tick_off_in_the_store :: proc(t: ^testing.T) {
	init()
	l: List
	add(&l, 3)
	add(&l, 9)
	tick(&l, 3)
	tick(&l, 11) // not on the list: nothing to tick
	testing.expect(t, !l.ticked[11])
	items, ticked := count(&l)
	testing.expect_value(t, items, 2)
	testing.expect_value(t, ticked, 1)
	clear_ticked(&l)
	items, ticked = count(&l)
	testing.expect_value(t, items, 1)
	testing.expect_value(t, ticked, 0)
	testing.expect_value(t, l.qty[9], 1)
}

@(test)
items_of_yer_own :: proc(t: ^testing.T) {
	init()
	l: List
	id, ok := add_own(&l, "  gruyere for the souffle, quick!")
	// Upper-cased, cut to fit, a stock name maps to the stock item.
	testing.expect(t, ok)
	testing.expect_value(t, item_name(&l, id), "GRUYERE FOR T")
	id2, _ := add_own(&l, "Gruyere")
	testing.expect(t, id2 < MAX_STOCK)
	testing.expect_value(t, item_aisle(id), OWN_AISLE)
	id3, _ := add_own(&l, "gruyere for t")
	testing.expect_value(t, id3, id)
	testing.expect_value(t, l.qty[id], 2)
	_, ok = add_own(&l, "  ,,, ")
	testing.expect(t, !ok)
	// Full up: unused ones make room.
	for i in 0 ..< MAX_OWN + 3 {
		buf := [2]u8{u8('A' + i), 'X'}
		nid, nok := add_own(&l, string(buf[:]))
		if nok && i % 2 == 0 {remove(&l, nid)}
	}
	testing.expect(t, l.own_n <= MAX_OWN)
	testing.expect_value(t, l.qty[id], 2) // the cheese is still on the list
}

@(test)
saved_and_loaded :: proc(t: ^testing.T) {
	init()
	l: List
	add(&l, 2)
	add(&l, 2)
	add(&l, 40)
	tick(&l, 40)
	own, _ := add_own(&l, "Jarlsberg")
	tick(&l, own)
	s := save(&l)
	m: List
	load(&m, s)
	testing.expect_value(t, m.qty[2], 2)
	testing.expect_value(t, m.qty[40], 1)
	testing.expect(t, m.ticked[40])
	testing.expect_value(t, m.own_n, 1)
	testing.expect_value(t, item_name(&m, MAX_STOCK), "JARLSBERG")
	testing.expect(t, m.ticked[MAX_STOCK])
	load(&m, "rubbish\nS9999 2 0\nS3 x 1\nO\n")
	items, _ := count(&m)
	testing.expect_value(t, items, 0)
}
