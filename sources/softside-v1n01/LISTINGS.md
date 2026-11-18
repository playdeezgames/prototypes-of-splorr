# SoftSide Vol. 1 No. 1 (October 1978): program listings

Source: https://www.atarimania.com/mags/pdf/SoftSide_Vol_1_No_01.pdf (downloaded November 18, 2026). The first issue.
TRS-80 BASIC (Level II unless noted). `softside.txt` is the PDF's own OCR text layer (`pdftotext -layout`); it is very noisy in this issue (the Cribbage commentary is close to unreadable), so check the page scans when transcribing.

PDF page numbers match the magazine's printed page numbers.

| Program | Author | Pages | Kind | Verdict |
|---|---|---|---|---|
| Cribbage | uncredited (SoftSide / TRS-80 Software Exchange) | pp. 8-27 | Two-handed six-card cribbage, you vs. the computer | Strong candidate (largest build) |
| State Capital Quiz | uncredited | pp. 28-31 | Name the state for a capital, three choices | Only if gamified |
| Death Star | uncredited | pp. 33-36 | One-key timing shooter | Strong candidate (needs its own fiction) |
| Calculator | uncredited | p. 39 | Four-function calculator with memory | Skip |
| Pillbox | Gene Perkins | pp. 40-43 | Two-player artillery duel over a mountain | Strong candidate |

Not listings: the TRS-80 Programming Hints (pp. 37, 44) are one-liners (a press-ENTER prompt, a POKE for a READ bug, three ways to draw a line); everything else (Star Trek III, Inventory, Statistics, Concentration, Breakaway, the Market Basket catalogue on pp. 49-55) is an ad.

## Cribbage
You against the computer, to 121, no board on screen (the article's point is that the computer is the board). Deal six each, both throw two to the kitty, cut a card (a cut Jack is two for the dealer, "his heels"). Pegging to 31 with GO, pairs, fifteens, 31 and runs in play order. Then the show: fifteens, pairs, runs (double and quadruple runs), flush (four, five with the cut), and one for his nobs. The kitty belongs to the dealer and alternates. End of game: if both pass 120 in the show, the side without the kitty counts first and wins. The computer keeps the best four of its six by scoring every four-card keep plus a weighted chance that the cut fills a run; in pegging it rates each legal card and plays the best. The article closes with a challenge to readers to write a better pegging algorithm. Instructions are in DATA/PRINT lines 9000-9100.

## State Capital Quiz
Shows a capital and three states; type the number of the right one. A miss gets "we will try that one again later". All fifty states and capitals are in subroutines at lines 1000-1495. A drill.

## Death Star
Thirteen remote batteries (`+`) are scattered on screen and three enemy fighters (`<O>`, `]-[`, `-!-`) jitter one cell at a time in any of eight directions. Tap the CLEAR key (any key, Level II) when a fighter's centre sits on a battery to destroy it. Twenty-one shots; the rating at the end: under 5 kills, back to gunnery school; under 8, demoted; under 11, good shooting; otherwise a promotion. The trick in the article is using CLEAR as an interrupt by testing `POINT(0,0)`. The names and story text are *Star Wars* (Death Star, the Emperor, a galaxy far, far away), so a new take needs its own setting and names.

## Calculator
Enter an initial value, then one-key functions: add, subtract, multiply, divide, memory store and recall, reciprocal, sign change, total. Not a game and not much of a toy.

## Pillbox
Two gunners take turns. The ground is drawn new each game: two pillboxes on either side of a random mountain. Enter a barrel angle (0-90) and a muzzle velocity (100-2000); the shell flies a ballistic arc (the program computes sine and cosine by series) and is plotted point by point. Hitting the mountain or overshooting is the usual first shot. First to five hits wins the war. Level I or II, 4K. Two players only; there is no computer gunner.
