#!/usr/bin/env python3
"""Draws the original app icon (barometer dial over a wave). No third-party marks."""
import math, sys
from PIL import Image, ImageDraw, ImageFilter
S = 1024
SS = 4  # supersample
W = S * SS
img = Image.new("RGB", (W, W))
px = img.load()
top, bot = (14, 52, 86), (5, 20, 38)
d = ImageDraw.Draw(img)
for y in range(W):
    t = y / W
    d.line([(0, y), (W, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
glow = Image.new("RGB", (W, W), (0, 0, 0))
ImageDraw.Draw(glow).ellipse([-W*0.2, -W*0.35, W*0.8, W*0.55], fill=(60, 150, 220))
glow = glow.filter(ImageFilter.GaussianBlur(W * 0.12))
img = Image.blend(img, Image.composite(glow, img, glow.convert("L")), 0.55)
d = ImageDraw.Draw(img)
cx, cy, r = W * 0.5, W * 0.6, W * 0.3
lw = int(W * 0.055)
d.arc([cx - r, cy - r, cx + r, cy + r], 180, 360, fill=(255, 255, 255), width=lw)
for k in range(9):  # tick marks
    a = math.pi + k * math.pi / 8
    r1, r2 = r * 0.78, r * 0.9
    d.line([(cx + r1*math.cos(a), cy + r1*math.sin(a)), (cx + r2*math.cos(a), cy + r2*math.sin(a))], fill=(200, 230, 255), width=int(W*0.014))
ang = math.radians(-55)
nx, ny = cx + r * 0.72 * math.cos(ang), cy + r * 0.72 * math.sin(ang)
d.line([(cx, cy), (nx, ny)], fill=(255, 196, 107), width=lw)
d.ellipse([nx - lw/2, ny - lw/2, nx + lw/2, ny + lw/2], fill=(255, 196, 107))
d.ellipse([cx - lw*0.9, cy - lw*0.9, cx + lw*0.9, cy + lw*0.9], fill=(255, 255, 255))
pts = []
y0 = W * 0.8
for i in range(0, 801):
    x = W * 0.1 + i / 800 * W * 0.8
    pts.append((x, y0 - math.sin((x - W*0.1) / (W*0.8) * 4 * math.pi) * W * 0.035))
rr = W * 0.025
for p in pts:  # stamp a round brush along the curve for a clean, even stroke
    d.ellipse([p[0]-rr, p[1]-rr, p[0]+rr, p[1]+rr], fill=(155, 216, 255))
img = img.resize((S, S), Image.LANCZOS)
img.save(sys.argv[1], "PNG")
print("icon written", img.size, img.mode)
