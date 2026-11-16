#!/usr/bin/env python3
"""Draws the 630 by 500 itch.io cover: the title in Public Pixel (CC0) over four of the
screenshots in assets/screenshots/. Run after tools/make_shots.sh."""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "assets", "cover.png")
SHOTS = os.path.join(ROOT, "assets", "screenshots")
FONT = os.path.join(ROOT, "shared", "web", "PublicPixel.ttf")
W, H = 630, 500
BG, GOLD, INK, DIM = (18, 17, 15), (240, 177, 58), (232, 217, 168), (143, 138, 110)

img = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(img)


def centred(y, text, size, fill):
    f = ImageFont.truetype(FONT, size)
    d.text(((W - d.textlength(text, font=f)) // 2, y), text, font=f, fill=fill)


centred(20, "SOFTSIDE", 44, GOLD)
centred(74, "PROTOTYPES", 28, INK)
centred(114, "FIVE TYPE-INS FROM AUGUST 1979", 14, DIM)

# Four screenshots, two by two, each 250 wide.
tiles = ["01-melt-down", "02-shooting-gallery", "04-morse-code-tutor", "05-storybook"]
tw, gap, top = 250, 24, 146
for i, name in enumerate(tiles):
    s = Image.open(os.path.join(SHOTS, name + ".png")).convert("RGB")
    th = round(s.height * tw / s.width)
    s = s.resize((tw, th), Image.NEAREST if s.width % tw == 0 else Image.LANCZOS)
    x = (W - 2 * tw - gap) // 2 + (i % 2) * (tw + gap)
    y = top + (i // 2) * 166 + (160 - th) // 2
    d.rectangle([x - 2, y - 2, x + tw + 1, y + th + 1], fill=DIM)
    img.paste(s, (x, y))
centred(H - 22, "THEGRUMPYGAMEDEV", 12, DIM)
img.save(OUT)
print("wrote", os.path.relpath(OUT, ROOT), img.size)
