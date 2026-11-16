# SoftSide Vol. 1 No. 11 (August 1979): program listings

Source: https://www.atarimania.com/mags/pdf/SoftSide_Vol_1_No_11.pdf (downloaded November 15, 2026).
TRS-80 Level II BASIC. `softside.txt` is the PDF's own OCR text layer (`pdftotext -layout`); it is noisy (0/O, 1/l, 8/0 swaps), so check the page scans when transcribing.

PDF page numbers match the magazine's printed page numbers.

| Program | Author | Article | Listing | Kind |
|---|---|---|---|---|
| Melt Down | Michael Winter | pp. 9-11 | pp. 12-25 | Real-time nuclear plant control sim |
| Shooting Gallery | Frank B. Rowlett, Jr. | p. 27 | pp. 28-31 | Carnival shooting gallery (arcade) |
| Storybook | Otto Hansen | p. 37 | pp. 38-48 | Mad-libs story generator for small children |
| Morse Code Tutor | Donald E. Smith | — | pp. 53-55 | Morse code trainer (3 modes) |
| Cryptogram | Rik Pierce | — | pp. 58-63 | Substitution-cipher puzzle with a bank of crypts |

Not listings: the VAL excerpt from *The BASIC Handbook* (p. 33) is two four-line test programs; Taipan (p. 35) and End Zone (p. 67) are ads.

## Melt Down
You run a reactor during one of 16 disasters (from DATA at lines 1620-1770: water level low, high critical mass, pump power failure, very high turbine speed, and so on). Meters run 1-9 and every one affects the others. Commands (keys) raise or lower the control rods, release coolant, flood the core (`O`), set turbine speed (`T`) and more. Every three seconds of the real-time clock the plant ticks, each meter drifts the way the event pushes it, and win or loss is checked. Win: every meter near 5 (skill 1 accepts 3.5-7.5; skill 5 needs exactly 5) and emergency core cooling level high. Loss: core temperature reaches 9. If water pressure reaches 9 the pipes burst and core cooling is briefly lost.

## Shooting Gallery
Rows of targets scroll across the screen in alternate directions: stars (50), pipes (25), ducks (15), clowns (10), plus a flying arrow. Move a sight with the arrow keys and fire with space. You get 20 shots; hitting a scoring row with nothing in it still costs the shot.

## Storybook
It asks for the child's name, age, friends, pet, favourite wild animal, colour and lucky number, then strings randomly chosen phrases into an adventure with semigraphic pictures. Reading speed is adjustable. A toy rather than a game.

## Morse Code Tutor
Mode 1 sends what you type, at 5/13/20 WPM. Mode 2 sends random characters for you to copy within a response time. Mode 3 sends a line someone else typed. A drill rather than a game.

## Cryptogram
Type a cryptogram or choose a number from the built-in bank of crypts. Press a cipher letter, then the plain letter to put in its place. `/` clears every guess, shift-N goes to the next crypt and `?` restarts.
