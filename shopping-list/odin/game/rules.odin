package shopping

// Shopping List: a tool. Go up and down the aisles picking what you need (tap an item, or type its
// number as the listing had you do), then take the list to the store and tick things off. Items
// of yer own can be added (the cheese that wasn't on the list). After "Shopping List"
// (uncredited, SoftSide, November 1978), a memory jogger that showed numbered items from DATA
// lines and printed what you picked. The aisles and items here are new.
// Pure rules: no platform imports.

import "core:strconv"
import "core:strings"

Item :: struct {
	name:  string,
	aisle: int,
}

AISLES := [?]string {
	"PRODUCE",
	"BAKERY",
	"DAIRY",
	"CHEESE",
	"MEAT",
	"FISH",
	"FROZEN",
	"CANNED",
	"DRY GOODS",
	"BAKING",
	"BREAKFAST",
	"SNACKS",
	"DRINKS",
	"PETS",
	"HOUSEHOLD",
	"YER OWN",
}
OWN_AISLE :: len(AISLES) - 1

@(private)
item_names := [?][]string {
	{"APPLES", "BANANAS", "ORANGES", "LEMONS", "GRAPES", "PEARS", "BERRIES", "MELON", "TOMATOES", "LETTUCE", "CARROTS", "ONIONS", "POTATOES", "PEPPERS", "CELERY", "GARLIC", "MUSHROOMS", "AVOCADOS"},
	{"WHITE BREAD", "RYE BREAD", "WHEAT BREAD", "ROLLS", "BAGELS", "MUFFINS", "BUNS", "DOUGHNUTS", "PIE"},
	{"MILK", "BUTTER", "EGGS", "YOGURT", "CREAM", "SOUR CREAM", "MARGARINE", "BUTTERMILK"},
	{"AMERICAN", "CHEDDAR", "SWISS", "BLUE", "BRIE", "PARMESAN", "COTTAGE", "RICOTTA", "GRUYERE", "CREAM CHEESE"},
	{"HAMBURGER", "STEAK", "CHICKEN", "PORK CHOPS", "BACON", "HAM", "SAUSAGE", "HOT DOGS", "LAMB CHOPS", "POT ROAST", "TURKEY", "LIVER"},
	{"COD", "HADDOCK", "SALMON", "TUNA", "SHRIMP", "CLAMS", "SCALLOPS", "CRAB", "LOBSTER"},
	{"PEAS", "CORN", "SPINACH", "PIZZA", "ICE CREAM", "TV DINNERS", "JUICE", "FISH STICKS", "WAFFLES"},
	{"SOUP", "BAKED BEANS", "TOMATO PASTE", "TUNA FISH", "PEACHES", "CREAMED CORN", "GRAVY", "PASTA SAUCE", "PEANUT BUTTER", "JELLY"},
	{"RICE", "SPAGHETTI", "MACARONI", "NOODLES", "OATMEAL", "LENTILS", "DRIED BEANS", "RAISINS", "PRUNES"},
	{"FLOUR", "SUGAR", "BROWN SUGAR", "BAKING SODA", "BAKING POWDER", "YEAST", "VANILLA", "COCOA", "CHOC CHIPS", "SHORTENING", "OIL", "SALT", "PEPPER", "SPICES", "CAKE MIX", "HONEY", "MOLASSES"},
	{"CEREAL", "PANCAKE MIX", "SYRUP", "COFFEE", "TEA", "HOT COCOA", "JAM"},
	{"CHIPS", "PRETZELS", "CRACKERS", "COOKIES", "POPCORN", "NUTS", "CANDY", "MARSHMALLOWS"},
	{"SODA", "LEMONADE", "CIDER", "ORANGE JUICE", "GINGER ALE", "SELTZER"},
	{"CAT FOOD", "DOG FOOD", "DOG BISCUITS", "CATNIP", "KITTY LITTER", "BIRDSEED"},
	{"SOAP", "DISH SOAP", "DETERGENT", "PAPER TOWELS", "TISSUES", "TOILET PAPER", "FOIL", "WAX PAPER", "TRASH BAGS", "LIGHT BULBS", "BATTERIES", "TOOTHPICKS"},
}

MAX_STOCK :: 200
MAX_OWN :: 18
NAME_MAX :: 13 // what fits in an item's column
MAX_QTY :: 9
MAX_ITEMS :: MAX_STOCK + MAX_OWN

// The shop's own items, numbered from 1 in aisle order (built by init).
stock: [MAX_STOCK]Item
stock_n: int

init :: proc() {
	stock_n = 0
	for names, a in item_names {
		for n in names {
			stock[stock_n] = {n, a}
			stock_n += 1
		}
	}
}

Own :: struct {
	name: [NAME_MAX]u8,
	len:  int,
}

List :: struct {
	qty:    [MAX_ITEMS]int, // index: a stock item, or MAX_STOCK + an own item
	ticked: [MAX_ITEMS]bool,
	own:    [MAX_OWN]Own,
	own_n:  int,
}

// Every item id in an aisle, in order.
aisle_items :: proc(l: ^List, aisle: int, out: []int) -> int {
	n := 0
	if aisle == OWN_AISLE {
		for i in 0 ..< l.own_n {
			if n < len(out) {out[n] = MAX_STOCK + i;n += 1}
		}
		return n
	}
	for i in 0 ..< stock_n {
		if stock[i].aisle == aisle && n < len(out) {
			out[n] = i
			n += 1
		}
	}
	return n
}

is_item :: proc(l: ^List, id: int) -> bool {
	return (id >= 0 && id < stock_n) || (id >= MAX_STOCK && id < MAX_STOCK + l.own_n)
}

item_name :: proc(l: ^List, id: int) -> string {
	if id >= MAX_STOCK {
		o := &l.own[id - MAX_STOCK]
		return string(o.name[:o.len])
	}
	return stock[id].name
}

item_aisle :: proc(id: int) -> int {
	return id >= MAX_STOCK ? OWN_AISLE : stock[id].aisle
}

// The number shown beside a stock item (1 up), as in the listing.
item_number :: proc(id: int) -> int {return id + 1}

add :: proc(l: ^List, id: int) -> bool {
	if !is_item(l, id) || l.qty[id] >= MAX_QTY {return false}
	l.qty[id] += 1
	l.ticked[id] = false
	return true
}

remove :: proc(l: ^List, id: int) {
	if !is_item(l, id) || l.qty[id] == 0 {return}
	l.qty[id] -= 1
	if l.qty[id] == 0 {l.ticked[id] = false}
}

// Picks an item by its number (the listing's way); false when there is no such item.
add_number :: proc(l: ^List, number: int) -> (id: int, ok: bool) {
	id = number - 1
	if id < 0 || id >= stock_n {return -1, false}
	return id, add(l, id)
}

tick :: proc(l: ^List, id: int) {
	if is_item(l, id) && l.qty[id] > 0 {l.ticked[id] = !l.ticked[id]}
}

// Takes the ticked items off the list (what's in the cart).
clear_ticked :: proc(l: ^List) {
	for i in 0 ..< MAX_ITEMS {
		if l.ticked[i] {
			l.qty[i] = 0
			l.ticked[i] = false
		}
	}
	drop_unused_own(l)
}

clear_all :: proc(l: ^List) {
	l^ = {}
}

// Own items not on the list any more are forgotten, so there's room for new ones.
drop_unused_own :: proc(l: ^List) {
	w := 0
	for r in 0 ..< l.own_n {
		id := MAX_STOCK + r
		if l.qty[id] > 0 {
			nid := MAX_STOCK + w
			l.own[w] = l.own[r]
			l.qty[nid] = l.qty[id]
			l.ticked[nid] = l.ticked[id]
			w += 1
		}
	}
	for r in w ..< l.own_n {
		l.qty[MAX_STOCK + r] = 0
		l.ticked[MAX_STOCK + r] = false
		l.own[r] = {}
	}
	l.own_n = w
}

valid_name_char :: proc(c: u8) -> bool {
	return (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == ' ' || c == '-' || c == '\'' || c == '.' || c == '&'
}

// Adds an item of yer own to the list (or one more of it, if it's already there).
add_own :: proc(l: ^List, raw: string) -> (id: int, ok: bool) {
	buf: [NAME_MAX]u8
	n := 0
	for i in 0 ..< len(raw) {
		c := raw[i]
		if c >= 'a' && c <= 'z' {c -= 32}
		if c == ' ' && (n == 0 || buf[n - 1] == ' ') {continue} // no leading or doubled spaces
		if valid_name_char(c) && n < NAME_MAX {
			buf[n] = c
			n += 1
		}
	}
	name := strings.trim_space(string(buf[:n]))
	if len(name) == 0 {return -1, false}
	for i in 0 ..< l.own_n {
		if item_name(l, MAX_STOCK + i) == name {
			id = MAX_STOCK + i
			return id, add(l, id)
		}
	}
	for i in 0 ..< stock_n {
		if stock[i].name == name {return i, add(l, i)}
	}
	if l.own_n == MAX_OWN {drop_unused_own(l)}
	if l.own_n == MAX_OWN {return -1, false}
	o := &l.own[l.own_n]
	o^ = {}
	copy(o.name[:], name)
	o.len = len(name)
	id = MAX_STOCK + l.own_n
	l.own_n += 1
	return id, add(l, id)
}

// Items on the list and how many are ticked.
count :: proc(l: ^List) -> (items, ticked: int) {
	for i in 0 ..< MAX_ITEMS {
		if l.qty[i] > 0 {
			items += 1
			if l.ticked[i] {ticked += 1}
		}
	}
	return
}

// ---- saving: one line per item on the list, "S<number> <qty> <ticked>" or "O<qty> <ticked> <name>" ----

save :: proc(l: ^List, allocator := context.temp_allocator) -> string {
	b := strings.builder_make(allocator)
	for i in 0 ..< stock_n {
		if l.qty[i] > 0 {
			strings.write_string(&b, "S")
			strings.write_int(&b, item_number(i))
			strings.write_string(&b, " ")
			strings.write_int(&b, l.qty[i])
			strings.write_string(&b, l.ticked[i] ? " 1\n" : " 0\n")
		}
	}
	for i in 0 ..< l.own_n {
		id := MAX_STOCK + i
		if l.qty[id] > 0 {
			strings.write_string(&b, "O")
			strings.write_int(&b, l.qty[id])
			strings.write_string(&b, l.ticked[id] ? " 1 " : " 0 ")
			strings.write_string(&b, item_name(l, id))
			strings.write_string(&b, "\n")
		}
	}
	return strings.to_string(b)
}

load :: proc(l: ^List, s: string) {
	l^ = {}
	rest := s
	for line in strings.split_lines_iterator(&rest) {
		if len(line) < 2 {continue}
		switch line[0] {
		case 'S':
			parts := strings.fields(line[1:], context.temp_allocator)
			if len(parts) != 3 {continue}
			num, ok1 := strconv.parse_int(parts[0])
			q, ok2 := strconv.parse_int(parts[1])
			if !ok1 || !ok2 {continue}
			id := num - 1
			if id < 0 || id >= stock_n || q < 1 {continue}
			l.qty[id] = min(q, MAX_QTY)
			l.ticked[id] = parts[2] == "1"
		case 'O':
			sp := strings.index_byte(line, ' ')
			if sp < 0 || sp + 3 > len(line) {continue}
			q, ok := strconv.parse_int(line[1:sp])
			if !ok || q < 1 {continue}
			t := line[sp + 1] == '1'
			id, added := add_own(l, line[sp + 3:])
			if !added {continue}
			l.qty[id] = min(q, MAX_QTY)
			l.ticked[id] = t
		}
	}
}
