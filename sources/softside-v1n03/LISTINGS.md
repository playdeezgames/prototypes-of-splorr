# SoftSide Vol. 1 No. 3 (December 1978): program listings

Source: https://www.atarimania.com/mags/pdf/SoftSide_Vol_1_No_03.pdf (downloaded November 22, 2026). The third issue.
TRS-80 BASIC (Level II unless noted). `softside.txt` is the PDF's own OCR text layer (`pdftotext -layout`); the Santa Paravia listing is badly garbled (pp. 14-23, 41-48), but each of its routines has a readable ROUTINE / LINES / PURPOSE / PROCESS box, so read the boxes and the page scans when transcribing.

PDF page numbers match the magazine's printed page numbers.

| Program | Author | Pages | Kind | Verdict |
|---|---|---|---|---|
| Santa Paravia en Fiumaccio | Rev. George Blank | pp. 8-23, 41-48 | One to six players rule 15th-century Italian city-states; grain, land, taxes, justice, buildings; rise in title before you die | Strong candidate (largest build) |
| Biorhythms | Frank B. Rowlett, Jr., Blacksburg VA (April 21, 1978) | pp. 25-27 | Plots the three biorhythm curves for a month from a birth date | Only as a Toy |
| Mortgage Calculation | Russell Starkey | pp. 29-31 | Amortized loan schedule | Only as a Tool |
| Spelling Bee | Lance Micklus, Winooski VT | pp. 33-34 | Flash a word, then type it from memory | Only if gamified |
| Six Million Dollar [10K] Clock | Peter Ashley | pp. 37-39 | Ham radio clock: local time, GMT, elapsed time, station ID prompts | Weak (only as a Tool) |
| Chess Clock | uncredited | pp. 39-40 | Two-player tournament chess clock | Only as a Tool (small) |

Not programs to build: the editorial "The game of life" (pp. 4, 6); TRS-80 Programming Hints (p. 12: the doubled-L LLIST lockup; p. 40: disk lockups and dated backup names); the Bad Code solution (p. 13); ads for the Text Editor (p. 2), Breakaway (p. 24), 3-D Tic Tac Toe (p. 27), Cash Register (p. 28), Concentration (p. 32), Renumber (p. 35), X-Wing Fighter (p. 36), Personal Finance (p. 49), Statistics (p. 50), Time Bomb (p. 52) and the Market Basket catalogue (pp. 53-62); next issue (pp. 51, 64).

## Santa Paravia en Fiumaccio
One to six players take turns, a year each, as the ruler of a tiny Italian city-state, to be promoted through Sir, Baron, Count, Marquis, Duke, Grand Duke, Prince and King (with the female titles alongside). Crowned King or Queen wins; death comes at random (20 to 25 years in, pneumonia most often), and if everyone dies the first to reach the highest title wins. Four skill levels (Apprentice, Journeyman, Master, Grand Master) make titles harder to earn. Each year has four phases: harvest (weather from drought to excellent, rats eat a share of the reserves, land price from the harvest-to-demand ratio; buy and sell grain and land), grain release (20 to 80 percent of the reserves; plenty brings in-migration of serfs, too little kills them and slows the economy), taxes and justice (customs, sales and wealth tax rates, justice from very fair to outrageous; harsh justice drives serfs away), and public works (markets, woolen mills, palaces, cathedrals, and equipping soldiers; borrowing too much means bankruptcy: buildings and all but 6000 hectares seized). A graphic map shows the land wall, the plough horse (touching the wall means enough serfs to farm the land), castle or tower by soldiers per land, and the buildings. Other rulers can invade if your army is weak. The title is earned from markets, palaces, cathedrals, mills, treasury, land, merchants, nobles, soldiers, clergy and serfs, each worth at most ten points, divided by the skill level, less the justice level. The article has strategy notes (outrageous justice and high customs for early cash, buy land early, diversify late) and documents every routine with its line numbers.

## Biorhythms
Asks a name, birth date and a month to chart, then plots the physical (23-day), emotional (28-day) and intellectual (33-day) sine curves across the screen for that month, numbering the curves 1, 2 and 4 and summing them where curves cross; critical days (a curve crossing the axis) break the axis and show the value. The article says it is not fortune telling. Pseudoscience, so only as a Toy.

## Mortgage Calculation
Amount, interest rate, term and payments a year in; out comes the payment and a schedule, a screen at a time, with the interest and principal of each payment, the accumulated interest and principal, and the balance left. A utility.

## Spelling Bee
Asks the child's name, then ten words a session picked at random from DATA lines (short words: SNOWMAN, DANCE, MATCH, FENCE, PATCH, WHIP, SKILL, WATCH and so on): shows "WORD n IS ..." for a moment, clears the screen, asks "WHAT'S THE WORD", says "THAT'S RIGHT" or gives the correct spelling, and keeps a score. The article suggests changing the words as the speller improves. A new take could gamify it the way State Capital Quiz and Morse Code Tutor were.

## Six Million Dollar [10K] Clock
A clock for amateur radio operators: set local time (24-hour) and the GMT offset; shows local time and GMT in a graphics box, a running tally of on-the-air time, and flashes the call letters every ten minutes as a station identification reminder. Timing is by FOR-NEXT delay loops with a fine-tune line. Narrow; at most a Tool, perhaps folded in with the Chess Clock.

## Chess Clock
Two hours each for 40 moves; a key press ends a turn and switches the clock, showing completed turns and each side's time remaining in hours, minutes and seconds. Level I changes are in REM lines. A small Tool.
