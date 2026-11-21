# SoftSide Vol. 1 No. 2 (November 1978): program listings

Source: https://www.atarimania.com/mags/pdf/SoftSide_Vol_1_No_02.pdf (downloaded November 20, 2026). The second issue.
TRS-80 BASIC (Level II unless noted). `softside.txt` is the PDF's own OCR text layer (`pdftotext -layout`); it is unreadable for the Troll's Gold and End Zone listings (pp. 17-24, 36-44), so read the page scans when transcribing.

PDF page numbers match the magazine's printed page numbers.

| Program | Author | Pages | Kind | Verdict |
|---|---|---|---|---|
| Troll's Gold | George Blank, Leechburg PA (July 17, 1978) | pp. 17-24 | Cave of 36 rooms, shifting doors, a troll; get the gold and get out | Strong candidate |
| End Zone | Roger Robitaille (1977) | pp. 33-44 | Two-player football: hidden offensive play vs. defensive alignment | Strong candidate (largest build) |
| Shopping List | uncredited | pp. 27-29 | Pick items from a DATA list, print the selections | Only as a Tool |
| Octal to Hex | Lance Micklus, Winooski VT (July 1978) | p. 61 | Three octal digits to a hex byte | Only as a Tool (small) |

Not programs to build: the Level I to Level II conversion article (pp. 10-12); TRS-80 Programming Hints (p. 14: a table of the 2x3 block graphics characters and a "Bad Code" find-the-bug puzzle; p. 62: a variable-dump subroutine); the corrections on p. 15 (Level II lines for issue 1's Calculator and Project Death Star, which our versions do not need); ads for Renumber (p. 26), Star Trek III (pp. 45-46), Time Bomb (p. 58), Concentration (p. 59) and the Market Basket catalogue (pp. 49-55); the survey (p. 60).

## Troll's Gold
The screen is a 6x6 grid of rooms (room 1 top left, room 36 bottom right, where the gold is). Each turn a new set of doors opens at random (`RND(80)` picks door slots; lines 2600-2790), the rest are shut, and the walls are redrawn. You type UP, DOWN, RIGHT (or IN), LEFT (or OUT) or STAY and can only move through an open door. Reach room 36 to take the gold, then carry it back to room 1 to win ("YOU ARE VERY RICH!", then the troll asks for a loan). The troll moves each turn toward you, one room at a time, also only through open doors (up/down when you are in another row, in/out when in the same row; lines 3300-3890). If it reaches your room: "PLEASE DON'T FEED THE TROLL ... THE TROLL JUST ATE YOU FOR DINNER!". The joke of the original is the sign at the cave mouth. Small and complete; the luck of the doors is the whole game, so a new take could add a little reading ahead (show next turn's doors, or a lantern).

## End Zone
Hot-seat football for two, four 15-minute quarters with a two-minute warning. Coin toss, kickoff, then each play: both sides may call a time maneuver (offence: time out, quick huddle, slow down; defence: slow down, time out), the offence secretly picks one of eleven plays (run weak side, run strong side, sweep, delayed run, up the middle, short/medium/long pass, punt, field goal, razzle dazzle), then the defence picks one of ten alignments (blitz, prevent, stacked, balanced, keyed short/medium/long pass, keyed long run, keyed sweep, goal line). Yardage depends on the match-up, with sacks, interceptions, fumbles and recoveries, penalties (offside, encroachment, illegal formation, false start, holding, personal foul), punts with cover/block/fair catch, field goals and extra points. A field across the top of the screen with down, distance, ball position and clock below. The article tells the offence to send the defence for coffee while choosing. A new take could add a computer coach so one person can play.

## Shopping List
A list of numbered items from DATA lines (the magazine prints a long grocery list by aisle: pet food, fruit, breads, baking, cheese, seafood, frozen, canned, fish, pork, variety meats, dried foods, lamb, beverages); type a number to select it, 0 when done, and the program prints the selections. A memory jogger, not a game. The article's skit (the cheese for the soufflé, "Lucky Duffy") is the most fun in it.

## Octal to Hex
Enter three octal digits separated by commas; the program checks they make a byte (0-377 octal) and prints the hex value, using DATA lines as the digit table. A utility.
