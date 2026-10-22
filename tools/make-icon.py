#!/usr/bin/env python3
"""Generate the pixel-art notification icon for the claudeSessions plugin.

Draws a 32x32 sprite (orange-gold hair, star hairpin, orange/white coat) and
upscales it x8 with NEAREST so it stays crisp pixel art.

    python3 -I make-icon.py            # writes ../claude-pixel.png
"""
from __future__ import annotations

import pathlib
import sys

from PIL import Image, ImageDraw

S = 32
OUT = pathlib.Path(__file__).resolve().parent.parent / "claude-pixel.png"

K = (42, 30, 20, 255)      # outline
H = (224, 164, 88, 255)    # hair
HL = (255, 215, 154, 255)  # hair highlight
HD = (176, 118, 47, 255)   # hair shadow
SK = (251, 227, 207, 255)  # skin
SS = (235, 197, 166, 255)  # skin shadow
EY = (59, 36, 23, 255)     # eye
IR = (200, 131, 46, 255)   # iris
MO = (168, 92, 74, 255)    # mouth
BL = (240, 169, 140, 255)  # blush
W = (247, 241, 230, 255)   # coat
WS = (217, 207, 192, 255)  # coat shadow
O = (217, 122, 74, 255)    # orange accent
V = (58, 46, 32, 255)      # vest
P = (255, 233, 176, 255)   # pin / star


def build() -> Image.Image:
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # ── hair silhouette (outline then fill) ────────────────────
    d.ellipse([7, 2, 24, 23], fill=K)
    d.ellipse([8, 3, 23, 22], fill=H)

    # long side locks
    d.rectangle([8, 11, 9, 24], fill=HD)
    d.rectangle([21, 11, 22, 24], fill=HD)

    # ── face ───────────────────────────────────────────────────
    d.ellipse([10, 7, 21, 20], fill=K)
    d.ellipse([11, 8, 20, 19], fill=SK)

    # fringe over the forehead
    d.polygon([(10, 10), (21, 10), (21, 7), (19, 6), (12, 6), (10, 8)], fill=H)
    d.point([(13, 7), (14, 7), (15, 7)], fill=HL)
    d.point([(18, 8), (19, 8)], fill=HL)
    # a couple of loose strands
    d.line([(11, 8), (12, 12)], fill=HD)
    d.line([(20, 8), (19, 12)], fill=HD)

    # ── features ───────────────────────────────────────────────
    d.rectangle([13, 12, 14, 13], fill=EY)
    d.rectangle([17, 12, 18, 13], fill=EY)
    d.point([(14, 12), (18, 12)], fill=IR)
    d.point([(12, 14), (19, 14)], fill=BL)
    d.rectangle([15, 15, 16, 15], fill=MO)

    # ── neck ───────────────────────────────────────────────────
    d.rectangle([15, 18, 16, 21], fill=SS)
    d.rectangle([14, 20, 17, 21], fill=K)

    # ── coat (outline, then white) ─────────────────────────────
    d.polygon([(5, 31), (5, 25), (10, 21), (15, 19), (16, 19),
               (21, 21), (26, 25), (26, 31)], fill=K)
    d.polygon([(6, 31), (6, 26), (11, 22), (15, 20), (16, 20),
               (20, 22), (25, 26), (25, 31)], fill=W)

    # coat shadow in the lower corners
    d.rectangle([6, 29, 8, 31], fill=WS)
    d.rectangle([23, 29, 25, 31], fill=WS)

    # orange trim / lapels
    d.polygon([(11, 22), (15, 21), (14, 27), (12, 27)], fill=O)
    d.polygon([(20, 22), (16, 21), (17, 27), (19, 27)], fill=O)

    # vest
    d.rectangle([14, 24, 17, 31], fill=V)

    # ── star hairpin (four-point) + brooch ─────────────────────
    sx, sy = 22, 7
    d.point([(sx, sy - 2), (sx, sy + 2), (sx - 2, sy), (sx + 2, sy),
             (sx, sy)], fill=P)
    d.point([(sx - 1, sy - 1), (sx + 1, sy - 1),
             (sx - 1, sy + 1), (sx + 1, sy + 1)], fill=P)

    d.point([(15, 24), (17, 24), (16, 23), (16, 25), (16, 24)], fill=P)

    return img


def main() -> int:
    img = build()
    big = img.resize((S * 8, S * 8), Image.Resampling.NEAREST)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    big.save(OUT)
    print(f"wrote {OUT} ({big.width}x{big.height})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
