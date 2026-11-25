# SoftSide Vol. 1 No. 6 (March 1979): program listings

Source: https://www.atarimania.com/mags/pdf/SoftSide_Vol_1_No_06.pdf (downloaded November 25, 2026). The sixth issue.
TRS-80 Level II BASIC. `softside.txt` is the PDF's own OCR text layer (`pdftotext -layout`); the articles mostly read well (Tarot's is printed on a tint and barely reads), the listings' OCR is garbled, so read them from the page scans (`pdftoppm -r 110`).

PDF page numbers match the magazine's printed page numbers.

| Program | Author | Pages | Kind | Verdict |
|---|---|---|---|---|
| Dive Bomb | George Blank | pp. 30-31 | Two players at one keyboard: a dive bomber crosses the top of the screen (Z dives, A levels off, X drops the bomb) over a ship crossing the bottom, whose anti-aircraft gun (/) jams after three shots a pass; "SHIP SUNK" or "DIVE BOMBER GOES DOWN IN FLAMES"; written to fit 4K | Strong candidate (a tiny real-time duel; wants a computer side for one player) |
| Jig Saw | David Bohlke | pp. 46-48 | A 4x4 board covered by six pieces (shown with their shapes, any rotation); the computer picks one of about twenty hidden layouts and names a piece, you name a square (1-16) it covers; tries counted and rated (5-7 Genius ... over 21 Try Again) | Strong candidate (a deduction puzzle) |
| Tarot | Frank B. Rowlett, Jr. | pp. 8-14 | Asks a yes-or-no question, shuffles the 78-card Egyptian deck and deals the five-card "Yes or No" spread (past, present as the key card counted twice, future); upright means yes, reversed no; each card drawn as a framed card with its name and a meaning from DATA lines; a tie is "uncertain" | Candidate (a Toy; the card meanings are to be written new) |
| Fog Index ("Can You See Through This?") | George Blank | pp. 26-27 | Gunning's Fog Index: enter the word count and the count of words of three syllables or more for five sentences; prints the reading level by school grade with a scale (Atlantic Monthly 12, Time 10, Ladies' Home Journal and the Sermon on the Mount 8) | Candidate (a Tool; type or paste the text and count syllables automatically) |
| Metric/English Converter | Dr. Stephen W. Hebbler | pp. 17-19 | Menus for length, weight, volume and temperature; metric unit (milli/centi/-/kilo) and English unit (inches to miles, ounces and pounds, teaspoons to gallons); either direction; repeated conversions | Weak (a plain Tool; like Octal to Hex, only as a period piece) |
| Personal Finance Part I: Checkbook | Lance Micklus | pp. 32-44 | Outstanding-checks file kept on cassette (two-recorder), add and fix checks, cancel those returned by the bank, reconcile with the statement, estimate bills; a test-data generator; budget categories in DATA | Weak (a 1979 check register; Part II follows next issue) |

Not programs to build: the editorial "Outgoing Mail" (pp. 3-5), the Programming Hints (p. 15, the line-printer status at 14312; p. 34, pressing a cassette's corner), "A page from The BASIC Handbook" (p. 50, ASC), the "Simple Simon" revision notice (p. 20, moved to PROG/80); ads: New Arrivals (p. 6), Educator Assistant (p. 7), ST-80 (p. 16), BIZ-80 (pp. 22-25), Appointment Log (p. 28), ESP Tester and Sink 'Em (p. 29), Cribbage (p. 33), Adventure (p. 49), the Market Basket catalogue (pp. 51-61), Checkbook on tape (p. 61), back issues (p. 62). Next issue: Safari (named in the editorial).

## Dive Bomb
"Dear Gabby" letter as the article: the lovelorn reader has 1076 bytes. The plane enters at the right edge, top row, flying left one step a frame; Z sets it diving (one row a frame, down to a floor), A levels it; X drops the bomb once a pass when low enough: it falls straight down and sinks the ship if the ship is under it. The ship (a three-row hull and stack) steams left to right and wraps. / fires a shell up and back from the ship's gun, three per pass; a shell meeting a lit pixel downs the plane. A pass with no result brings the plane round again from the right. No score kept; a hit or a sinking restarts.

## Jig Saw
The screen shows a 4x4 grid numbered 1-16 on the left and the six piece shapes (1-6) on the right (lines 700-739 draw them from DATA). The DATA holds about twenty layouts as sixteen piece numbers (which piece covers each square); RND picks one. Each turn the computer names a piece still not found; you enter a square: if that piece covers it, "YOU GOT IT!!!" and the piece is drawn in place (every piece of that shape when a shape repeats), else "SORRY -- IT DOESN'T FIT THERE." Tries count up; a finished puzzle twinkles and offers another. The article suggests group play (each player takes pieces) or fewest tries.

## Tarot
The deck: 22 Major Arcana, 16 Court (Youth, Queen, King, Horseman in Scepters, Cups, Swords, Coins), 40 Minor (one to ten). The spread is dealt right to left: two past cards, the key present card (counts twice), two future cards; the answer is the majority of upright (yes) over reversed (no), uncertain on a tie (the article blames poor concentration). Court cards point at a person (Youth and King male upright, female reversed; the Queen the other way; the Horseman good or bad); some cards name an astrological temperament. Reference: "How to Read Tarot Cards" by Doris C. Doane and King Keyes. The meanings are DATA lines; write new ones rather than copy.

## Fog Index
Enter, for five sentences, the number of words and the number of words of three or more syllables; the program averages and prints INT of the index, then the grade scale. General test (five consecutive sentences) and Acid test (the five hardest). Blank's aside: the low-income credit instructions read at a master's level.

## Metric/English Converter
Choose length, weight, volume, temperature or end; for the first three, the metric unit then the English unit, then the direction, then values until a new choice. Factors in the listing (0.0254, 0.3048, 0.9144, 1609.34 m; 28.3495 g, 453.592 g; 4.93, 14.8, 29.5735, 236.6, 473.2, 946.4 ml, 3.785 l). Temperature in degrees F and C.

## Personal Finance Part I: Checkbook
"The Personal Check Balance Program", version 2.1, Level II 16K. Menu: end session, list outstanding checks, add new checks, fix checks with errors, enter checks received from the bank, reconcile, bill estimate. Data written to and read from cassette; a test-data generator (option 3). Advanced Personal Finance is sold on tape.
