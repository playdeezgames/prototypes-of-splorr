# SoftSide Vol. 1 No. 5 (February 1979): program listings

Source: https://www.atarimania.com/mags/pdf/SoftSide_Vol_1_No_05.pdf (downloaded November 25, 2026). The fifth issue.
TRS-80 Level II BASIC. `softside.txt` is the PDF's own OCR text layer (`pdftotext -layout`); the articles read well but every listing's OCR is garbled, so read the listings from the page scans (`pdftoppm -r 110`).

PDF page numbers match the magazine's printed page numbers.

| Program | Author | Pages | Kind | Verdict |
|---|---|---|---|---|
| Concentration | Lance Micklus | pp. 37-43 | After the TV game show: two players, a board of 32 numbered squares hiding prizes in pairs (prize names and values in DATA lines); find a pair to win the prize and a guess at the computer's secret number (1 to 100, told high or low); guessing it ends the game, and the prize lists are shown | Strong candidate (memory game; the TV show's name wants a working name) |
| Elements Quiz | Roger W. Robitaille, Sr. | pp. 47-52 | A drill on the chemical elements: name, symbol, atomic number and atomic weight; three difficulty levels; four quiz directions (symbol from name, name from symbol, number from name, name from number); a review chart; missed questions asked again | Candidate, gamified like State Capital Quiz (the table needs bringing up to today's 118 elements and names) |
| 1040 Tax Program | George Clisham | pp. 10-24 | Walks through the 1978 Form 1040 line by line (filing status, exemptions, wages, interest, dividends, Schedule A deductions with the medical percentages, credits, energy credit, income averaging, the tax table look-up), warns of audit-bait figures, then prints the lines to copy onto the form | Weak (a 1978 tax form; only as a Toy or a period piece) |
| Cribbage Update | Roger W. Robitaille, Sr. | pp. 55-58 | Line changes to the Vol. 1 No. 1 Cribbage listing: display clean-up, an ace-suit bug (13/13 read as diamonds), pairs vs runs detection during pegging | Not a new program (our Cribbage is a fresh build; check it scores aces' suits and pegging runs right) |

Not programs to build: the editorial "Just to Let You Know" (pp. 4-6); "Writing Good Computer Games, Part II: Mechanics" by George Blank (pp. 27-36, an essay using 'Round the Horn as its example); the Programming Hint for disk users (p. 53, grounding disk drives against radio noise); ads for Adventure (p. 2), New Arrivals (p. 7), disk software (pp. 8-9), BASIC Handbook (p. 25), TRS-80 FORTRAN (p. 26), diskettes (pp. 12, 30), Omega VI (p. 44), Appointment Log (p. 45), 8080-to-Z80 conversion (p. 46), Batter Up, Zone Hockey, End Zone and Ten Pin (p. 57), a ham radio package (p. 59), the Market Basket catalogue (pp. 60-70) and Santa Paravia (p. 71); next issue (p. 72: Tarot, Jigsaw).

## Concentration
After the long-running TV game show (the original title is the show's name, so a working name is needed). The board is 32 numbered blocks, each hiding a prize, every prize twice. On a turn a player names two squares; a match wins the prize (value shown) and a guess at the secret number 1-100, answered too high or too low; a miss covers them again. Every reveal and every guess helps the other player. When a square has no possible match left the program says so; if none are possible, a tie. Guessing the number wins; "HIT ENTER TO SEE YOUR PRIZES" lists each player's prizes and totals. The listing ends with "What else... a commercial!" Prize names and values are DATA lines (CREDIT CARD..., a disc..., trips, cars), to be written new.

## Elements Quiz
An introductory marquee scrolls the data; pick Easy, Difficult, Impossible or Done (each level includes the easier ones; the article gives the lines to isolate levels). Optional review: a paged chart of element, symbol, atomic number, atomic weight. Pick one of four directions (symbol given the name, name given the symbol, atomic number given the name, name given the atomic number). Questions come shuffled; "C O R R E C T" or the correct answer; at the end a score and percentage, then a retry of only the missed ones, or a second round. The article pitches it as a reusable quiz engine (swap the DATA for history dates, geologic periods). The 1979 data (about 104 elements, some weights in parentheses) is out of date: use today's table.

## 1040 Tax Program
"SoftSide presents: 1040". Y/N questions and figures one line at a time in the order of the 1978 Form 1040, both sides, plus Schedules A, B and G (income averaging) and Form 5695 (residential energy credit); medical deductions checked against the percentages of gross income; asks for the tax from the X, Y, Z tables; offers income averaging; then lists the figures keyed to the form's line numbers (a sample form on p. 16). Joke at the end about a TRS-80 deduction and a new address in a cell block. Not useful as a tool today; as a Toy it would be a 1978 tax-day curio.

## Cribbage Update
Fixes to the first issue's Cribbage: lines 1301 and 1504-1506, 2600 and 3036-3038 tidy the display; 1340, 2500 and 2635 fix suit detection (values 1-13 are clubs, and INT(13/13) read the ace as a diamond, so offset by -1); 2302, 2303 and 2689 separate run detection from pairs during pegging (mode Q=3). Nothing to build; a reminder to check our own flush and run scoring.
