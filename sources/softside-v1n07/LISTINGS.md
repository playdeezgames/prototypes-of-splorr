# SoftSide Vol. 1 No. 7 (April 1979): program listings

Source: https://www.atarimania.com/mags/pdf/SoftSide_Vol_1_No_07.pdf (downloaded November 27, 2026). The seventh issue.
TRS-80 Level II BASIC. `softside.txt` is the PDF's own OCR text layer (`pdftotext -layout`); the articles read well, the listings' OCR is garbled, so read them from the page scans (`pdftoppm -r 110`).

The PDF has 44 pages, not the whole issue: printed pages 15-20, 27-28, 33-36 and 57 on are missing. PDF pages 1-14 are printed pages 1-14; after that, PDF page 15 is printed 21, PDF 21 is printed 29, PDF 25 is printed 37, and PDF 44 is printed 56.

| Program | Author | Pages | Kind | Verdict |
|---|---|---|---|---|
| Safari | David J. Bohlke | pp. 36-50 (article pp. 37-40, listing pp. 42-50) | One to several Bwanas, each with a base camp on a 13x13 map of 169 regions; outfit a party (four scouts, one per direction, who "look ahead"; cameras with three reels each and two cameramen apiece; bearers carrying 100 lb of supplies); a day's move N, S, E or W; scouts' report as paths (six blocks an animal, four nothing, three no scout, solid a base camp, none no passage); in an animal's region, steer a camera lens over it with the arrows and press ENTER; 80, 50, 30 points for the first three to film a region, less for time spent aiming, plus 10 a day's journey from camp; disasters (snake bite, exhaustion, fever, stampede ...) on 30-45% of regions by level; lost: L sends a scout for a map, at his life; supplies run out and the party starves; ends when no one can outfit a party | Strong candidate (the issue's big game; exploration plus a little aiming; wants computer Bwanas for one player) |
| Rabbits and Foxes | Russell Starkey (from an idea in a 1973 magazine) | pp. 24-26 | Lotka-Volterra predator-prey model: enter rabbits and foxes (25-400), one or two bar graphs (POKEd blocks) redrawn each step with current, min and max counts; runs until one side drops to 1 | Candidate as a Toy (a live chart; sliders for the encounter factor and step, maybe a garden to defend) |
| Spring Flowers | David A. Eide | p. 31 | Ten lines: plots the four-petal rose r = 35 sin 2t with SET | Weak (a Toy at most; could grow into a rose-curve doodler with petal count and colours) |
| Series Circuits | Philip Brown | pp. 54-56 | Two resistors, a start and end voltage and a step; draws the circuit in block graphics and tables total voltage, the drop across each resistor (E1, E2) and the current | Weak (a Tool; Ohm's law for two resistors) |
| Don't It Make My Brown Eyes Blue | James Garon | p. 17 (only lines 910-950 survive, on p. 21) | Plays the 1977 Crystal Gayle song (by its title; the article is on the missing pages) | Not to build: the scan lacks the article and almost all the listing, and the tune is a copyrighted song |
| Personal Finance Part II: Checkfinder | Lance Micklus | pp. 8-14 | Merges Checkbook's CANCELLED CHECKS tapes into a CHECK FILE (up to 900 checks in 16K, blocking factor 8), bubble-sorts it, and finds a check or a group (by number, date, payee, amount, budget category) with totals; budget names in DATA | Weak (follows Part I, also weak) |

Not programs to build: the editorial "Outgoing Mail" (pp. 4-5, on the TRS-80), the STARTREK III 3.3A fix notice (p. 29), the Programming Hints (p. 21: INKEY$ with a prompt, line feeds in REMs; p. 38: a SHIFT at the start of a line gives a syntax error), "A page from The BASIC Handbook" (p. 32, INKEY$), "Take A Part: Safari" (p. 51, the arrow keys via CHR$ 91-94 and INKEY$, lines 450-454 and 510 of Safari); ads: diskettes (p. 6), a renumber utility (p. 7), 3-D Tic Tac Toe (p. 14), Simple Simon (p. 22), Z80 Instruction Handbook (p. 23), amateur radio (p. 30), Sink 'Um! by Rev. George Blank (p. 29, sold on tape, no listing), New Arrivals (p. 41), BIZ-80 Inventory System II (pp. 52-53).

## Safari
Difficulty Beginner, Average or Expert sets the share of regions with a disaster or hardship (30 to 45%). Players' names; the map of the whole country shows how many animals are in all the regions and every base camp (you do not know which is yours unless alone). At base: four scouts, six cameramen, twenty bearers, three cameras, 5000 lb of supplies; choose how many of each go. A survey of the party (scouts, cameramen and cameras, bearers, supplies, points, days) in the upper right; the scouts' report map in the upper left. Filming: the camera lens and the animal; arrow keys move the lens, ENTER shoots. Points: 80 for the first to film a region, 50 the second, 30 the third, none after; less the time spent positioning; plus 10 for each day's journey from base. Your turn ends when base cannot equip a new party (two cameramen, one camera, three bearers, 200 lb) or the last camera is lost. The game ends when every player has lost all cameras or cannot outfit a party; the most points wins, even if eliminated early. Disaster messages in the listing include "BY SNAKE BITE", "BY EXHAUSTION", "TO FEVER", "IN STAMPEDE"; day messages "NO EXCITEMENT TODAY", "A WEARY DAY"; the listing (lines 1-7176) is complete on pp. 42-50.

## Rabbits and Foxes
Rabbits D = D + B*(2D - A*D*C); foxes C = C + B*(A*D*C - C), with B = .02 (step) and A = .01 (encounter factor). Prints rabbits and foxes with their min and max, every fifth step, as bars POKEd into video memory at 15360 and 16000 (one or two bars wide). Stops when either count is 1.

## Spring Flowers
FOR I = 0 TO 6.28319 STEP 1.74533E-02: R = 35*SIN(2*I): X = R*COS(I)+64: Y = R*SIN(I)+47: SET(X, 47-Y/2). "GRAPHIC DISPLAY OF A FOUR LEAF ROSE", then "PROGRAM TERMINATED".

## Series Circuits
Resistors R1 and R2 (each over 0), initial and final voltage, an increment of at least 1. Draws two resistors in a loop, then columns TOTAL VOLTAGE, E1 = R1/(R1+R2)*E, E2 = R2/(R1+R2)*E, AMPERAGE = E/(R1+R2), a screenful at a time.

## Personal Finance Part II: Checkfinder
"Check Finder", version 2.1, 16K Level II. Reads one or more CANCELLED CHECKS tapes into memory, sorts them, writes a CHECK FILE tape, and locates checks with totals; a blinking star while busy; budget category names (Child care, Hobbies, Household, Groceries, Rent, Auto, Insurance, Taxes, Doctor ...) in DATA.
