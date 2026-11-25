"""World art for the three showcase worlds: sky paintings, parallax ridges, the cloud sea under the sky track and
tiling road textures (rows are drawn one per road band, scaled to the road's width)."""
from __future__ import annotations

import math
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SS = 3


def grad(w, h, stops):
    """Vertical gradient through (t, (r,g,b)) stops."""
    arr = np.zeros((h, w, 4), np.uint8)
    ts = np.linspace(0, 1, h)
    for c in range(3):
        arr[:, :, c] = np.interp(ts, [s[0] for s in stops], [s[1][c] for s in stops])[:, None]
    arr[:, :, 3] = 255
    return Image.fromarray(arr, "RGBA")


def glow(img, cx, cy, r, color, alpha=120, blur=30):
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(lay).ellipse([cx - r, cy - r, cx + r, cy + r], fill=color + (alpha,))
    return Image.alpha_composite(img, lay.filter(ImageFilter.GaussianBlur(blur)))


def big(w, h):
    return Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))


def shrink(img, w, h):
    return img.resize((w, h), Image.LANCZOS)


def tile_wrap(img, w, overlap=300):
    """Make a strip tile horizontally by copying its left edge onto its right edge."""
    s = img.width // w
    left = img.crop((0, 0, overlap * s, img.height))
    img.paste(left, (img.width - overlap * s, 0), left)
    return img


# ---------- jungle ----------
def jungle():
    out = {}
    sky = grad(1280, 250, [(0, (64, 150, 170)), (0.6, (170, 210, 170)), (1, (236, 232, 180))])
    sky = glow(sky, 980, 120, 90, (255, 245, 200), 150, 40)
    out["sky_jungle.png"] = sky
    w, h = 2048, 150
    im = big(w, h)
    d = ImageDraw.Draw(im)
    S = SS
    # volcano with a smoke plume, distant long-neck dinosaur silhouettes
    d.polygon([(300 * S, h * S), (560 * S, 30 * S), (640 * S, 30 * S), (900 * S, h * S)], fill=(84, 110, 100, 255))
    d.polygon([(560 * S, 30 * S), (640 * S, 30 * S), (620 * S, 46 * S), (580 * S, 46 * S)], fill=(255, 120, 60, 255))
    for i in range(8):
        r = 18 + i * 9
        d.ellipse([(600 - r + i * 14) * S, (20 - i * 14 - r * 0.6) * S, (600 + r + i * 14) * S, (20 - i * 14 + r * 0.6) * S], fill=(200, 200, 190, 150))
    for x0, sc in ((1300, 1.0), (1500, 0.7)):
        d.ellipse([(x0 - 40 * sc) * S, (h - 50 * sc) * S, (x0 + 40 * sc) * S, (h - 10 * sc) * S], fill=(70, 100, 90, 255))
        d.line([(x0 + 30 * sc) * S, (h - 40 * sc) * S, (x0 + 70 * sc) * S, (h - 120 * sc) * S, (x0 + 90 * sc) * S, (h - 125 * sc) * S], fill=(70, 100, 90, 255), width=int(10 * sc * S))
        d.line([(x0 - 35 * sc) * S, (h - 30 * sc) * S, (x0 - 90 * sc) * S, (h - 20 * sc) * S], fill=(70, 100, 90, 255), width=int(8 * sc * S))
    rnd = random.Random(3)
    for i in range(40):
        x = rnd.randint(0, w)
        r = rnd.randint(30, 70)
        d.ellipse([(x - r) * S, (h - r * 0.8) * S, (x + r) * S, (h + r) * S], fill=(60, 120, 80, 255))
    out["far_jungle.png"] = shrink(tile_wrap(im, w), w, h)
    w, h = 2048, 90
    im = big(w, h)
    d = ImageDraw.Draw(im)
    rnd = random.Random(4)
    for i in range(70):
        x = rnd.randint(0, w)
        r = rnd.randint(24, 52)
        y = h - rnd.randint(10, 60)
        d.ellipse([(x - r) * S, (y - r) * S, (x + r) * S, (y + r) * S], fill=(30, 90, 50, 255))
        d.ellipse([(x - r * 0.6) * S, (y - r * 0.9) * S, (x + r * 0.3) * S, (y - r * 0.2) * S], fill=(60, 130, 70, 255))
    d.rectangle([0, (h - 20) * S, w * S, h * S], fill=(30, 90, 50, 255))
    out["near_jungle.png"] = shrink(tile_wrap(im, w), w, h)
    # dirt road with stones and tyre ruts
    tw, th = 1024, 128
    arr = np.zeros((th, tw, 3))
    rng = np.random.default_rng(5)
    base = np.array([150, 96, 62], float)
    arr[:] = base
    arr += rng.normal(0, 9, (th, tw, 1))
    for x0 in (256, 768):
        arr[:, x0 - 50:x0 + 50] *= 0.88
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).convert("RGBA")
    d = ImageDraw.Draw(img)
    for _ in range(700):
        x, y = rng.integers(0, tw), rng.integers(0, th)
        r = int(rng.integers(3, 9))
        g = int(rng.integers(150, 200))
        d.ellipse([x - r, y - r * 0.6, x + r, y + r * 0.6], fill=(g, g - 20, g - 40, 255))
    out["road_jungle.png"] = img
    return out


# ---------- sky track ----------
def skytrack():
    out = {}
    sky = grad(1280, 250, [(0, (22, 16, 60)), (0.55, (150, 70, 140)), (1, (255, 170, 110))])
    rnd = random.Random(8)
    d = ImageDraw.Draw(sky)
    for _ in range(80):
        x, y = rnd.randint(0, 1280), rnd.randint(0, 120)
        d.point((x, y), fill=(255, 255, 255, rnd.randint(120, 255)))
    sky = glow(sky, 400, 236, 120, (255, 200, 120), 170, 50)
    out["sky_skytrack.png"] = sky
    # far: floating girder towers and a distant loop silhouette
    w, h = 2048, 160
    im = big(w, h)
    d = ImageDraw.Draw(im)
    S = SS
    col = (70, 50, 100, 255)
    for x0 in (150, 700, 1250, 1750):
        tw = rnd.randint(30, 60)
        th = rnd.randint(70, 150)
        d.rectangle([x0 * S, (h - th) * S, (x0 + tw) * S, h * S], fill=col)
        for yy in range(h - th, h, 16):
            d.line([x0 * S, yy * S, (x0 + tw) * S, (yy + 16) * S], fill=(110, 80, 140, 255), width=2 * S)
        d.ellipse([(x0 + tw / 2 - 6) * S, (h - th - 12) * S, (x0 + tw / 2 + 6) * S, (h - th) * S], fill=(255, 90, 60, 255))
    cx, cy, r = 980, 70, 55
    d.ellipse([(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S], outline=col, width=12 * S)
    d.line([(cx - 260) * S, (cy + r) * S, (cx + 260) * S, (cy + r) * S], fill=col, width=12 * S)
    out["far_skytrack.png"] = shrink(tile_wrap(im, w), w, h)
    im = big(w, 60)
    out["near_skytrack.png"] = shrink(im, w, 60)
    # the cloud sea below the track
    below = grad(1280, 470, [(0, (255, 190, 140)), (0.25, (220, 140, 160)), (1, (60, 40, 90))])
    lay = Image.new("RGBA", below.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(lay)
    for row in range(14):
        y = 8 + row * row * 2.6
        r = 20 + row * 9
        for k in range(int(1280 / r) + 2):
            x = k * r * 1.6 + (row % 2) * r * 0.8
            shade = int(255 - row * 6)
            ld.ellipse([x - r, y - r * 0.45, x + r, y + r * 0.45], fill=(shade, int(shade * 0.82), int(shade * 0.86), 150))
    below = Image.alpha_composite(below, lay.filter(ImageFilter.GaussianBlur(3)))
    out["below_skytrack.png"] = below
    # diamond plate steel with rivet rows and a centre seam
    tw, th = 1024, 128
    img = Image.new("RGBA", (tw, th), (112, 118, 132, 255))
    d = ImageDraw.Draw(img)
    for y in range(0, th, 16):
        for x in range(0, tw, 32):
            ox = 16 if (y // 16) % 2 else 0
            d.line([x + ox, y + 4, x + ox + 12, y + 10], fill=(170, 176, 190, 255), width=4)
            d.line([x + ox, y + 7, x + ox + 12, y + 13], fill=(70, 74, 86, 255), width=2)
    for y in (0, 64):
        d.rectangle([0, y, tw, y + 3], fill=(60, 64, 76, 255))
        for x in range(8, tw, 32):
            d.ellipse([x - 4, y + 7, x + 4, y + 15], fill=(200, 204, 214, 255))
    out["road_skytrack.png"] = img
    return out


# ---------- pebble beach ----------
def pebble():
    out = {}
    sky = grad(1280, 250, [(0, (40, 140, 220)), (0.7, (150, 215, 245)), (1, (230, 245, 250))])
    sky = glow(sky, 260, 70, 60, (255, 255, 230), 200, 30)
    d = ImageDraw.Draw(sky)
    rnd = random.Random(11)
    for _ in range(6):
        x, y = rnd.randint(0, 1280), rnd.randint(20, 140)
        for k in range(5):
            d.ellipse([x + k * 24 - 30, y - 14 + (k % 2) * 6, x + k * 24 + 30, y + 14], fill=(255, 255, 255, 200))
    out["sky_pebble.png"] = sky.filter(ImageFilter.GaussianBlur(0.6))
    w, h = 2048, 120
    im = big(w, h)
    d = ImageDraw.Draw(im)
    S = SS
    d.rectangle([0, (h - 40) * S, w * S, h * S], fill=(30, 120, 180, 255))
    for i in range(140):
        x = rnd.randint(0, w)
        y = rnd.randint(h - 38, h - 2)
        d.rectangle([x * S, y * S, (x + rnd.randint(8, 30)) * S, (y + 1) * S], fill=(230, 245, 255, 220))
    for x0, ww, hh in ((80, 380, 90), (1400, 520, 110)):
        d.polygon([(x0 * S, (h - 40) * S), ((x0 + 60) * S, (h - hh) * S), ((x0 + ww - 120) * S, (h - hh - 10) * S), ((x0 + ww) * S, (h - 40) * S)], fill=(176, 150, 120, 255))
        d.polygon([((x0 + 60) * S, (h - hh) * S), ((x0 + ww - 120) * S, (h - hh - 10) * S), ((x0 + ww - 150) * S, (h - hh + 6) * S), ((x0 + 70) * S, (h - hh + 10) * S)], fill=(90, 160, 80, 255))
    out["far_pebble.png"] = shrink(tile_wrap(im, w), w, h)
    out["near_pebble.png"] = shrink(big(w, 40), w, 40)
    # pebble mosaic road
    tw, th = 1024, 128
    img = Image.new("RGBA", (tw, th), (196, 186, 168, 255))
    d = ImageDraw.Draw(img)
    rng = np.random.default_rng(12)
    for _ in range(3200):
        x, y = rng.integers(0, tw), rng.integers(0, th)
        rx, ry = int(rng.integers(5, 12)), int(rng.integers(3, 6))
        g = int(rng.integers(160, 235))
        tint = rng.integers(-15, 15)
        d.ellipse([x - rx, y - ry, x + rx, y + ry], fill=(g, g - 6 + int(tint), g - 14, 255), outline=(90, 84, 76, 255))
    out["road_pebble.png"] = img
    return out


# ---------- whirligig woods ----------
def whirligig():
    out = {}
    sky = grad(1280, 250, [(0, (150, 120, 220)), (0.55, (250, 190, 220)), (1, (255, 236, 200))])
    S = SS
    im = big(1280, 250)
    d = ImageDraw.Draw(im)
    rnd = random.Random(21)
    # mountains hanging upside down from the top of the sky, snowcaps at their tips
    for x0, ww, hh, col in ((60, 260, 120, (170, 140, 230)), (420, 200, 90, (190, 150, 235)), (900, 300, 140, (160, 130, 220)), (1150, 180, 80, (185, 150, 230))):
        tip = (x0 + ww / 2, hh)
        d.polygon([(x0 * S, 0), ((x0 + ww) * S, 0), (tip[0] * S, tip[1] * S)], fill=col + (255,))
        d.polygon([((tip[0] - ww * 0.12) * S, (hh * 0.78) * S), ((tip[0] + ww * 0.12) * S, (hh * 0.78) * S), (tip[0] * S, tip[1] * S)], fill=(255, 250, 255, 255))
    # floating islands with grass tops and waterfalls
    for cx, cy, w in ((300, 150, 120), (720, 110, 90), (1060, 170, 70)):
        d.polygon([((cx - w) * S, cy * S), ((cx + w) * S, cy * S), (cx * S, (cy + w * 0.8) * S)], fill=(160, 120, 170, 255))
        d.ellipse([(cx - w) * S, (cy - 12) * S, (cx + w) * S, (cy + 10) * S], fill=(140, 220, 170, 255))
        d.rectangle([(cx + w * 0.4) * S, cy * S, (cx + w * 0.4 + 6) * S, (cy + 70) * S], fill=(200, 235, 255, 200))
    # a spiral sun
    for k in range(5):
        r = 40 - k * 7
        d.ellipse([(560 - r) * S, (60 - r) * S, (560 + r) * S, (60 + r) * S], fill=((255, 240, 160) if k % 2 == 0 else (255, 200, 120)) + (255,))
    sky = Image.alpha_composite(sky, shrink(im, 1280, 250))
    out["sky_whirligig.png"] = sky
    w, h = 2048, 140
    im = big(w, h)
    d = ImageDraw.Draw(im)
    cols = [(250, 170, 210), (170, 230, 210), (200, 180, 250), (255, 220, 170)]
    for i in range(-1, 11):
        x = i * 200 + rnd.randint(-30, 30)
        ww = rnd.randint(220, 320)
        hh = rnd.randint(60, h)
        col = cols[i % 4]
        d.ellipse([x * S, (h - hh) * S, (x + ww) * S, (h + hh) * S], fill=col + (255,))
        for k in range(1, 4):
            d.arc([(x + ww * 0.1 * k) * S, (h - hh + hh * 0.15 * k) * S, (x + ww - ww * 0.1 * k) * S, (h + hh) * S], 200, 340, fill=(255, 255, 255, 160), width=3 * S)
    out["far_whirligig.png"] = shrink(tile_wrap(im, w), w, h)
    im = big(w, 70)
    d = ImageDraw.Draw(im)
    for i in range(60):
        x = rnd.randint(0, w)
        r = rnd.randint(14, 28)
        y = 70 - r - rnd.randint(0, 12)
        d.line([x * S, y * S, x * S, 70 * S], fill=(250, 250, 250, 255), width=3 * S)
        d.ellipse([(x - r) * S, (y - r) * S, (x + r) * S, (y + r) * S], fill=cols[i % 4] + (255,))
        d.arc([(x - r * 0.6) * S, (y - r * 0.6) * S, (x + r * 0.6) * S, (y + r * 0.6) * S], 0, 300, fill=(255, 255, 255, 255), width=3 * S)
    out["near_whirligig.png"] = shrink(tile_wrap(im, w), w, 70)
    # candy swirl road: diagonal pastel stripes with sprinkles
    tw, th = 1024, 128
    img = Image.new("RGBA", (tw, th), (250, 236, 246, 255))
    d = ImageDraw.Draw(img)
    for k in range(-th, tw + th, 64):
        d.polygon([(k, 0), (k + 32, 0), (k + 32 + th // 2, th), (k + th // 2, th)], fill=(255, 205, 228, 255))
    rng = np.random.default_rng(22)
    sprinkle = [(240, 80, 140), (80, 180, 240), (255, 210, 60), (120, 210, 140)]
    for _ in range(500):
        x, y = rng.integers(0, tw), rng.integers(0, th)
        c = sprinkle[int(rng.integers(0, 4))]
        d.line([x, y, x + 6, y + 2], fill=c + (255,), width=3)
    out["road_whirligig.png"] = img
    return out


def main():
    import sys
    from pathlib import Path
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    for fn in (jungle, skytrack, pebble, whirligig):
        for name, img in fn().items():
            img.save(out / name, optimize=True)
            print(name)


if __name__ == "__main__":
    main()
