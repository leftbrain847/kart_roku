#!/usr/bin/env python3
"""Draws Kart's art as PNGs: karts (10 styles x body colors), items, roadside scenery and sky panoramas for each
road theme. Shapes are drawn 4x oversized and shrunk (anti-aliasing), lit with gradients, outlined and given soft
shadows, so the sprites read as 3D. The game loads each PNG once at startup and pre-scales it; frames only copy.

    python3 scripts/art/make_art.py OUT_DIR [--only kart:classic,theme:meadow]

Deterministic: the same inputs give byte-identical PNGs.
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

SS = 4  # supersampling factor


# ---------- helpers ----------
def rgb(h: int) -> tuple:
    return ((h >> 16) & 255, (h >> 8) & 255, h & 255)


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def shade(c, f):
    """f < 1 darkens, f > 1 lightens toward white."""
    if f <= 1:
        return tuple(int(v * f) for v in c)
    return mix(c, (255, 255, 255), min(1, f - 1))


class Canvas:
    """An RGBA canvas in sprite pixels; every coordinate is scaled by SS internally."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))

    def _xy(self, pts):
        return [(x * SS, y * SS) for x, y in pts]

    def layer(self):
        return Image.new("RGBA", self.img.size, (0, 0, 0, 0))

    def paste(self, lay):
        self.img = Image.alpha_composite(self.img, lay)

    def poly_grad(self, pts, top, bottom, alpha=255, axis="y", spec=0.0):
        """Polygon filled with a linear gradient (top->bottom or left->right) and an optional highlight band."""
        mask = Image.new("L", self.img.size, 0)
        ImageDraw.Draw(mask).polygon(self._xy(pts), fill=alpha)
        grad = Image.new("RGBA", self.img.size)
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        lo, hi = (min(ys), max(ys)) if axis == "y" else (min(xs), max(xs))
        span = max(1e-6, hi - lo)
        gd = ImageDraw.Draw(grad)
        n = self.img.size[1] if axis == "y" else self.img.size[0]
        for i in range(int(lo * SS), int(hi * SS) + 1):
            t = min(1, max(0, (i / SS - lo) / span))
            c = mix(top, bottom, t)
            if spec and 0.12 < t < 0.3:
                c = mix(c, (255, 255, 255), spec * (1 - abs(t - 0.21) / 0.09))
            if axis == "y":
                gd.line([(0, i), (self.img.size[0], i)], fill=c + (255,))
            else:
                gd.line([(i, 0), (i, self.img.size[1])], fill=c + (255,))
        lay = self.layer()
        lay.paste(grad, (0, 0), mask)
        self.paste(lay)

    def rect(self, x, y, w, h, top, bottom=None, alpha=255, spec=0.0, r=0):
        bottom = bottom or top
        if r:
            self.round_rect(x, y, w, h, r, top, bottom, alpha, spec)
        else:
            self.poly_grad([(x, y), (x + w, y), (x + w, y + h), (x, y + h)], top, bottom, alpha, spec=spec)

    def round_rect(self, x, y, w, h, r, top, bottom, alpha=255, spec=0.0):
        mask = Image.new("L", self.img.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle([x * SS, y * SS, (x + w) * SS, (y + h) * SS], radius=r * SS, fill=alpha)
        self._fill_mask(mask, y, y + h, top, bottom, spec)

    def ellipse(self, x, y, w, h, top, bottom=None, alpha=255, spec=0.0):
        mask = Image.new("L", self.img.size, 0)
        ImageDraw.Draw(mask).ellipse([x * SS, y * SS, (x + w) * SS, (y + h) * SS], fill=alpha)
        self._fill_mask(mask, y, y + h, top, bottom or top, spec)

    def _fill_mask(self, mask, y0, y1, top, bottom, spec):
        grad = Image.new("RGBA", self.img.size)
        gd = ImageDraw.Draw(grad)
        span = max(1e-6, y1 - y0)
        for i in range(max(0, int(y0 * SS)), min(self.img.size[1], int(y1 * SS) + 1)):
            t = min(1, max(0, (i / SS - y0) / span))
            c = mix(top, bottom, t)
            if spec and 0.1 < t < 0.32:
                c = mix(c, (255, 255, 255), spec * (1 - abs(t - 0.21) / 0.11))
            gd.line([(0, i), (self.img.size[0], i)], fill=c + (255,))
        lay = self.layer()
        lay.paste(grad, (0, 0), mask)
        self.paste(lay)

    def glow(self, x, y, w, h, color, alpha=160, blur=3):
        lay = self.layer()
        ImageDraw.Draw(lay).ellipse([x * SS, y * SS, (x + w) * SS, (y + h) * SS], fill=color + (alpha,))
        self.paste(lay.filter(ImageFilter.GaussianBlur(blur * SS)))

    def finish(self, outline=(20, 16, 24), shadow=True, thickness=1.2):
        """Dark outline around the silhouette and a soft ground shadow, then shrink to sprite size."""
        a = self.img.split()[3]
        grown = a.filter(ImageFilter.MaxFilter(int(thickness * SS) * 2 + 1))
        line = Image.new("RGBA", self.img.size, outline + (0,))
        line.putalpha(grown)
        out = Image.alpha_composite(line, self.img)
        if shadow:
            sh = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
            bw = self.w * SS
            ImageDraw.Draw(sh).ellipse([bw * 0.04, self.img.size[1] - 7 * SS, bw * 0.96, self.img.size[1] - 0.5 * SS], fill=(0, 0, 0, 110))
            sh = sh.filter(ImageFilter.GaussianBlur(2 * SS))
            out = Image.alpha_composite(sh, out)
        return out.resize((self.w, self.h), Image.LANCZOS)


def wheel(c, x, y, w, h, tread=True):
    c.round_rect(x, y, w, h, min(w, h) * 0.28, (58, 58, 64), (18, 18, 22))
    if tread:
        for k in range(1, 5):
            c.rect(x + 1, y + h * k / 5, w - 2, max(1, h * 0.05), (28, 28, 32), alpha=200)
    c.rect(x + w * 0.15, y + 1, w * 0.12, h - 2, (110, 110, 120), alpha=120)


def helmet(c, x, y, w, color, visor=(34, 44, 90)):
    c.ellipse(x, y, w, w * 0.92, shade(color, 1.35), shade(color, 0.6), spec=0.55)
    c.round_rect(x + w * 0.12, y + w * 0.36, w * 0.76, w * 0.22, w * 0.1, visor, shade(visor, 0.5))


# ---------- karts (rear view, slight top-down) ----------
def kart(style: str, body: int) -> Image.Image:
    B = rgb(body)
    hi, lo = shade(B, 1.35), shade(B, 0.55)
    W, H = 240, 170
    c = Canvas(W, H)
    if style == "classic":
        wheel(c, 6, 92, 50, 70); wheel(c, 184, 92, 50, 70)
        c.round_rect(30, 78, 180, 66, 14, hi, lo, spec=0.4)
        c.rect(36, 132, 168, 14, shade(B, 0.45))
        c.round_rect(64, 64, 112, 28, 10, shade(B, 1.15), shade(B, 0.7))
        helmet(c, 84, 8, 72, (255, 210, 63))
        c.rect(104, 112, 32, 12, (240, 240, 240), (190, 190, 190))
        c.round_rect(50, 96, 24, 10, 4, (255, 70, 60), (170, 20, 20)); c.round_rect(166, 96, 24, 10, 4, (255, 70, 60), (170, 20, 20))
    elif style == "f1":
        W, H = 260, 150; c = Canvas(W, H)
        wheel(c, 2, 62, 60, 84); wheel(c, 198, 62, 60, 84)
        c.rect(60, 18, 10, 60, (30, 30, 36)); c.rect(190, 18, 10, 60, (30, 30, 36))
        c.round_rect(10, 4, 240, 26, 6, hi, lo, spec=0.6)
        c.rect(70, 10, 120, 6, (245, 245, 245))
        c.poly_grad([(82, 60), (178, 60), (196, 140), (64, 140)], hi, lo, spec=0.35)
        helmet(c, 101, 34, 58, (245, 245, 245), (20, 30, 70))
        c.rect(118, 124, 24, 12, (255, 60, 60), (150, 10, 10)); c.glow(112, 118, 36, 22, (255, 60, 60), 120, 4)
    elif style == "monster":
        W, H = 260, 230; c = Canvas(W, H)
        wheel(c, 0, 104, 84, 122); wheel(c, 176, 104, 84, 122)
        c.rect(84, 150, 92, 18, (90, 90, 96), (50, 50, 56))
        c.round_rect(18, 62, 224, 82, 16, hi, lo, spec=0.45)
        c.round_rect(58, 8, 144, 64, 14, shade(B, 1.2), shade(B, 0.8))
        c.round_rect(70, 16, 120, 42, 8, (170, 220, 245), (90, 140, 180), spec=0.5)
        helmet(c, 110, 24, 40, (40, 40, 50), (70, 80, 110))
        c.round_rect(22, 132, 216, 16, 6, (225, 228, 235), (130, 134, 145), spec=0.6)
        c.round_rect(30, 78, 28, 16, 4, (255, 70, 60), (170, 20, 20)); c.round_rect(202, 78, 28, 16, 4, (255, 70, 60), (170, 20, 20))
    elif style == "bubble":
        W, H = 210, 190; c = Canvas(W, H)
        wheel(c, 16, 136, 40, 50); wheel(c, 154, 136, 40, 50)
        c.ellipse(10, 10, 190, 160, hi, lo, spec=0.5)
        c.ellipse(46, 26, 118, 86, (190, 230, 250), (110, 160, 200), spec=0.5)
        c.ellipse(82, 44, 46, 50, (90, 62, 46), (50, 34, 26))
        c.round_rect(80, 40, 50, 16, 8, (255, 120, 170), (200, 70, 120))
        c.round_rect(30, 112, 26, 14, 6, (255, 70, 60), (170, 20, 20)); c.round_rect(154, 112, 26, 14, 6, (255, 70, 60), (170, 20, 20))
        c.round_rect(84, 132, 42, 16, 4, (245, 245, 245), (200, 200, 200))
    elif style == "hover":
        W, H = 250, 150; c = Canvas(W, H)
        c.glow(30, 118, 190, 30, (64, 224, 255), 220, 5)
        c.poly_grad([(6, 70), (244, 70), (226, 122), (24, 122)], hi, lo, spec=0.5)
        c.poly_grad([(48, 40), (202, 40), (226, 72), (24, 72)], shade(B, 1.2), shade(B, 0.85))
        c.ellipse(82, 6, 86, 58, (40, 56, 100), (14, 20, 40), spec=0.7)
        c.round_rect(96, 26, 58, 10, 5, (64, 224, 255), (30, 150, 200))
        for x in (30, 186):
            c.glow(x - 6, 80, 46, 40, (255, 150, 40), 200, 3)
            c.ellipse(x, 86, 34, 26, (255, 230, 120), (255, 120, 30))
    elif style == "frog":
        W, H = 230, 200; c = Canvas(W, H)
        wheel(c, 4, 120, 50, 74); wheel(c, 176, 120, 50, 74)
        c.round_rect(30, 112, 170, 66, 14, hi, lo, spec=0.4)
        c.ellipse(52, 34, 126, 98, (120, 210, 70), (50, 140, 30), spec=0.35)
        for ex in (46, 124):
            c.ellipse(ex, 6, 60, 54, (255, 255, 255), (205, 205, 205), spec=0.4)
            c.ellipse(ex + 20, 18, 22, 26, (20, 20, 20))
            c.ellipse(ex + 24, 21, 7, 7, (255, 255, 255))
        c.round_rect(90, 88, 50, 10, 5, (225, 50, 46), (150, 20, 20))
    elif style == "robot":
        W, H = 230, 210; c = Canvas(W, H)
        wheel(c, 4, 132, 50, 74); wheel(c, 176, 132, 50, 74)
        c.round_rect(22, 118, 186, 70, 10, (225, 230, 238), (120, 126, 140), spec=0.6)
        c.rect(22, 118, 186, 12, hi, B)
        for bx in (34, 186):
            c.ellipse(bx, 140, 10, 10, (150, 150, 160), (80, 80, 90))
        c.round_rect(66, 30, 98, 92, 12, (210, 216, 226), (110, 116, 130), spec=0.55)
        c.rect(60, 64, 8, 30, (64, 224, 255)); c.rect(162, 64, 8, 30, (64, 224, 255))
        c.glow(52, 60, 26, 40, (64, 224, 255), 150, 3); c.glow(152, 60, 26, 40, (64, 224, 255), 150, 3)
        c.rect(112, 4, 6, 28, (90, 90, 100)); c.ellipse(106, 0, 18, 14, hi, B, spec=0.6)
        c.round_rect(84, 150, 62, 16, 6, (64, 224, 255), (30, 150, 200))
    elif style == "buggy":
        W, H = 250, 210; c = Canvas(W, H)
        wheel(c, 0, 116, 62, 90); wheel(c, 188, 116, 62, 90)
        c.round_rect(40, 114, 170, 48, 10, hi, lo, spec=0.4)
        helmet(c, 92, 34, 66, B)
        for x0 in (40, 198):
            c.rect(x0, 8, 12, 118, (40, 40, 46), (20, 20, 24))
        c.rect(40, 4, 170, 12, (50, 50, 56), (20, 20, 24))
        c.ellipse(90, 120, 70, 70, (40, 40, 44), (14, 14, 16))
        c.ellipse(108, 138, 34, 34, (170, 170, 178), (100, 100, 108), spec=0.5)
    elif style == "muscle":
        W, H = 270, 170; c = Canvas(W, H)
        wheel(c, 12, 126, 46, 42); wheel(c, 212, 126, 46, 42)
        c.round_rect(4, 62, 262, 84, 16, hi, lo, spec=0.45)
        c.poly_grad([(52, 16), (218, 16), (240, 66), (30, 66)], shade(B, 1.15), shade(B, 0.85))
        c.poly_grad([(64, 24), (206, 24), (224, 60), (46, 60)], (60, 74, 104), (24, 30, 46), spec=0.4)
        c.rect(104, 16, 22, 130, (245, 245, 245), alpha=235); c.rect(144, 16, 22, 130, (245, 245, 245), alpha=235)
        c.round_rect(14, 84, 242, 18, 6, (255, 60, 50), (150, 10, 10)); c.glow(10, 76, 250, 34, (255, 60, 50), 90, 4)
        c.rect(6, 54, 258, 10, shade(B, 0.7), shade(B, 0.5))
        c.round_rect(70, 140, 22, 14, 6, (220, 224, 232), (120, 124, 132)); c.round_rect(178, 140, 22, 14, 6, (220, 224, 232), (120, 124, 132))
    elif style == "soapbox":
        W, H = 230, 200; c = Canvas(W, H)
        for x0 in (6, 174):
            c.ellipse(x0, 132, 50, 64, (140, 140, 148), (80, 80, 88))
            c.ellipse(x0 + 14, 150, 22, 28, (200, 200, 208), (130, 130, 140))
        c.round_rect(28, 110, 174, 68, 6, (190, 136, 82), (120, 80, 42), spec=0.3)
        for y0 in (128, 148, 166):
            c.rect(28, y0, 174, 2, (95, 62, 30))
        c.ellipse(92, 124, 46, 46, (245, 245, 245), (200, 200, 200)); c.ellipse(104, 134, 22, 26, B, lo)
        c.ellipse(70, 32, 90, 90, (245, 200, 160), (200, 150, 110))
        c.round_rect(66, 22, 98, 36, 14, hi, lo, spec=0.4); c.round_rect(140, 40, 40, 12, 6, B, lo)
        c.rect(66, 58, 98, 10, (60, 60, 66))
    return c.finish()


# ---------- items and scenery ----------
def item(name):
    if name == "block":   # item crate: wooden box with a glowing star stencil
        c = Canvas(128, 128)
        c.glow(4, 4, 120, 120, (120, 220, 255), 120, 6)
        c.round_rect(8, 8, 112, 112, 8, (205, 150, 90), (130, 85, 45), spec=0.35)
        for y0 in (40, 76):
            c.rect(8, y0, 112, 4, (100, 62, 30))
        c.rect(8, 8, 112, 10, (230, 180, 110), (180, 125, 70))
        star = [(64 + 34 * math.cos(math.radians(-90 + k * 36)) * (1 if k % 2 == 0 else 0.45),
                 66 + 34 * math.sin(math.radians(-90 + k * 36)) * (1 if k % 2 == 0 else 0.45)) for k in range(10)]
        c.glow(26, 28, 76, 76, (120, 230, 255), 200, 4)
        c.poly_grad(star, (230, 252, 255), (90, 200, 255))
        return c.finish(shadow=False)
    if name == "shell":   # spiked steel puck that skims along the lane
        c = Canvas(120, 84)
        c.ellipse(4, 40, 112, 40, (60, 64, 76), (24, 26, 32))
        c.ellipse(10, 18, 100, 50, (190, 210, 230), (80, 96, 120), spec=0.7)
        for k in range(7):
            x = 14 + k * 15
            c.poly_grad([(x, 30), (x + 6, 8), (x + 12, 30)], (240, 244, 250), (130, 140, 160))
        c.ellipse(46, 32, 28, 16, (64, 224, 255), (20, 140, 200))
        return c.finish()
    if name == "banana":
        c = Canvas(110, 84)
        lay = c.layer()
        d = ImageDraw.Draw(lay)
        d.arc([8 * SS, -40 * SS, 102 * SS, 70 * SS], 20, 160, fill=(255, 224, 74, 255), width=22 * SS)
        c.paste(lay)
        c.rect(88, 14, 8, 16, (110, 75, 30))
        return c.finish()
    if name == "boost":   # nitro canister with a lightning bolt
        c = Canvas(90, 140)
        c.glow(6, 20, 78, 110, (255, 170, 40), 120, 6)
        c.round_rect(14, 22, 62, 112, 18, (255, 170, 60), (200, 80, 20), spec=0.6)
        c.round_rect(30, 6, 30, 22, 6, (200, 204, 214), (110, 114, 124), spec=0.5)
        c.poly_grad([(52, 34), (30, 80), (46, 80), (36, 122), (64, 70), (48, 70), (58, 34)], (255, 255, 220), (255, 220, 80))
        return c.finish()
    if name == "car":
        c = Canvas(260, 200)
        wheel(c, 12, 150, 50, 48); wheel(c, 198, 150, 50, 48)
        c.round_rect(6, 80, 248, 92, 20, (70, 130, 235), (20, 60, 150), spec=0.5)
        c.poly_grad([(46, 20), (214, 20), (236, 86), (24, 86)], (60, 110, 210), (30, 70, 160))
        c.poly_grad([(60, 30), (200, 30), (218, 80), (42, 80)], (190, 225, 250), (100, 150, 190), spec=0.5)
        c.round_rect(14, 104, 50, 18, 6, (255, 80, 70), (170, 20, 20)); c.round_rect(196, 104, 50, 18, 6, (255, 80, 70), (170, 20, 20))
        c.round_rect(90, 132, 80, 22, 4, (235, 235, 235), (180, 180, 180))
        return c.finish()
    raise ValueError(name)


def scenery(name):
    if name == "tree":
        c = Canvas(200, 320)
        c.rect(88, 220, 24, 100, (120, 80, 40), (70, 45, 20))
        for (x, y, w, h, l) in ((10, 120, 180, 130, 0.9), (30, 60, 140, 110, 1.0), (55, 10, 90, 80, 1.1)):
            c.ellipse(x, y, w, h, shade((60, 160, 70), l + 0.2), shade((30, 100, 45), l), spec=0.25)
        return c.finish()
    if name == "pine":
        c = Canvas(180, 340)
        c.rect(80, 290, 20, 50, (100, 66, 34), (60, 40, 20))
        for i, (y, w) in enumerate(((210, 170), (140, 132), (74, 96), (14, 60))):
            c.poly_grad([(90, y), (90 + w / 2, y + 90), (90 - w / 2, y + 90)], (50, 130, 90), (20, 70, 50))
            c.poly_grad([(90, y), (90 + w / 4, y + 34), (90 - w / 4, y + 34)], (250, 252, 255), (210, 225, 240))
        return c.finish()
    if name == "cactus":
        c = Canvas(150, 300)
        g1, g2 = (110, 190, 100), (40, 110, 55)
        c.round_rect(56, 10, 38, 290, 18, g1, g2, spec=0.2)
        c.round_rect(14, 90, 26, 100, 12, g1, g2); c.round_rect(14, 166, 60, 24, 12, g1, g2)
        c.round_rect(110, 50, 26, 90, 12, g1, g2); c.round_rect(80, 120, 56, 24, 12, g1, g2)
        c.rect(66, 10, 6, 290, (170, 230, 160), alpha=140)
        return c.finish()
    if name == "rock":
        c = Canvas(240, 150)
        c.poly_grad([(10, 150), (30, 60), (90, 20), (170, 30), (225, 80), (235, 150)], (200, 130, 90), (110, 65, 40), spec=0.2)
        c.poly_grad([(90, 20), (170, 30), (150, 70), (100, 64)], (230, 170, 120), (190, 130, 90))
        return c.finish()
    if name == "lamp":
        c = Canvas(110, 420)
        c.glow(0, 20, 80, 70, (255, 230, 150), 160, 6)
        c.rect(70, 40, 14, 380, (90, 96, 110), (40, 44, 54))
        c.rect(20, 34, 64, 10, (90, 96, 110), (50, 54, 64))
        c.round_rect(10, 40, 40, 16, 6, (255, 245, 200), (255, 210, 120))
        return c.finish(shadow=False)
    if name == "building":
        c = Canvas(300, 420)
        c.rect(0, 20, 300, 400, (60, 66, 96), (28, 30, 48))
        c.rect(0, 10, 300, 14, (90, 96, 130))
        rnd = random.Random(7)
        for row in range(9):
            for col in range(5):
                lit = rnd.random() < 0.55
                col_c = (255, 214, 107) if lit else (70, 76, 110)
                c.rect(20 + col * 56, 44 + row * 40, 34, 22, col_c, shade(col_c, 0.8))
        return c.finish(shadow=False)
    if name == "palm":
        c = Canvas(260, 400)
        lay = c.layer()
        d = ImageDraw.Draw(lay)
        for i in range(10):
            y = 380 - i * 32
            x = 126 + math.sin(i / 3) * 10
            d.ellipse([(x - 13) * SS, y * SS, (x + 13) * SS, (y + 34) * SS], fill=(150, 110, 60, 255) if i % 2 else (125, 90, 48, 255))
        c.paste(lay)
        for ang in (-150, -115, -70, -35, 0, 35, 70, 115, 150, 180):
            a = math.radians(ang - 90)
            ex, ey = 130 + math.cos(a) * 120, 70 + math.sin(a) * 60 + 30
            c.poly_grad([(130, 66), (ex, ey), (ex + 8, ey + 22), (136, 80)], (80, 190, 90), (30, 120, 50))
        return c.finish()
    if name == "pylon":
        c = Canvas(100, 400)
        c.glow(10, 0, 80, 400, (255, 62, 200), 110, 6)
        c.rect(36, 10, 28, 390, (40, 20, 70), (20, 10, 40))
        c.rect(40, 10, 6, 390, (255, 80, 210)); c.rect(54, 10, 6, 390, (62, 232, 255))
        c.round_rect(20, 0, 60, 16, 6, (255, 120, 220), (200, 40, 160))
        return c.finish(shadow=False)
    if name == "lavarock":
        c = Canvas(240, 170)
        c.glow(40, 100, 160, 60, (255, 100, 30), 140, 6)
        c.poly_grad([(6, 170), (30, 70), (100, 20), (180, 40), (234, 110), (230, 170)], (70, 50, 54), (24, 18, 22))
        for pts in (((80, 110), (150, 100), (156, 108), (84, 120)), ((150, 60), (158, 58), (170, 140), (160, 142))):
            c.poly_grad(list(pts), (255, 200, 80), (255, 90, 20))
        return c.finish()
    if name == "autumn":
        c = Canvas(220, 320)
        c.rect(98, 220, 24, 100, (110, 74, 40), (70, 45, 22))
        for (x, y, w, h, col) in ((10, 120, 200, 130, (220, 110, 40)), (34, 56, 150, 120, (240, 150, 50)), (70, 10, 90, 80, (250, 195, 70))):
            c.ellipse(x, y, w, h, shade(col, 1.15), shade(col, 0.7), spec=0.3)
        return c.finish()
    if name == "fence":
        c = Canvas(260, 110)
        for x in (8, 120, 232):
            c.rect(x, 4, 20, 106, (245, 240, 228), (190, 182, 166))
        c.rect(0, 26, 260, 16, (245, 240, 228), (205, 198, 182)); c.rect(0, 66, 260, 16, (245, 240, 228), (205, 198, 182))
        return c.finish()
    if name == "crystal":
        c = Canvas(160, 300)
        c.glow(10, 60, 140, 240, (150, 120, 255), 120, 8)
        for (x, top, w, col) in ((50, 10, 60, (150, 120, 255)), (10, 110, 46, (110, 80, 230)), (104, 80, 46, (120, 90, 240))):
            c.poly_grad([(x + w / 2, top), (x + w, top + 50), (x + w, 300), (x, 300), (x, top + 50)], shade(col, 1.35), shade(col, 0.6), axis="x")
        return c.finish()
    raise ValueError(name)


# ---------- skies ----------
THEMES = {
    "meadow":  {"sky": (0x3A86D6, 0xA9DBF5), "far": (0x7FB27A, "hills"), "near": (0x3E7D4B, "hills"), "sun": None},
    "desert":  {"sky": (0x3F8FD0, 0xF7D9A8), "far": (0xC9875A, "mesas"), "near": (0xA45E3A, "mesas"), "sun": (0xFFF2C0, 0.78, 0.25)},
    "city":    {"sky": (0x0B0F2A, 0x3A2A5A), "far": (0x1A1D3A, "skyline"), "near": (0x101226, "skyline"), "sun": (0xF4F1D8, 0.2, 0.25), "stars": 60},
    "snow":    {"sky": (0x8FB2D8, 0xE8F1FA), "far": (0xB7C6D9, "peaks"), "near": (0xE9F0F7, "peaks"), "sun": None},
    "beach":   {"sky": (0x2F9BE0, 0xBFEBFF), "far": (0x2F7FB0, "sea"), "near": (0x6FB36A, "island"), "sun": (0xFFFBE0, 0.8, 0.3)},
    "synth":   {"sky": (0x14062E, 0xFF5A9A), "far": (0x5B1E8A, "peaks"), "near": (0x2A0E4A, "grid"), "sun": (0xFFB13D, 0.5, 0.55), "stars": 40},
    "volcano": {"sky": (0x2A0A0A, 0xD2461E), "far": (0x3A1A1A, "volcano"), "near": (0x1E1010, "mesas"), "sun": None},
    "forest":  {"sky": (0x5D93C4, 0xD9E8D0), "far": (0x2E5A3E, "treeline"), "near": (0x1C3F2A, "treeline"), "sun": None},
    "autumn":  {"sky": (0x6E9FD0, 0xF5D9B0), "far": (0xC9844A, "hills"), "near": (0x9A5A2A, "hills"), "sun": (0xFFE8B0, 0.25, 0.3)},
    "space":   {"sky": (0x02030A, 0x14183A), "far": (0x4A4E62, "craters"), "near": (0x2A2D3A, "craters"), "sun": None, "stars": 160, "planet": True},
}


def ridge(kind, w, h, color, seed):
    """One parallax layer: a 2048 px wide strip whose shapes tile seamlessly."""
    rnd = random.Random(seed)
    c = Canvas(w, h)
    col = rgb(color)
    lay = c.layer()
    d = ImageDraw.Draw(lay)
    S = SS
    if kind == "hills":
        for i in range(-1, 9):
            x = i * 260 + rnd.randint(-40, 40)
            ww = rnd.randint(300, 460)
            hh = rnd.randint(int(h * 0.45), h)
            d.ellipse([x * S, (h - hh) * S, (x + ww) * S, (h + hh) * S], fill=col + (255,))
    elif kind == "mesas":
        for i in range(-1, 8):
            x = i * 300 + rnd.randint(-30, 30)
            ww = rnd.randint(140, 260)
            hh = rnd.randint(int(h * 0.4), h - 4)
            d.polygon([(x * S, h * S), ((x + 20) * S, (h - hh) * S), ((x + ww - 20) * S, (h - hh) * S), ((x + ww) * S, h * S)], fill=col + (255,))
            d.rectangle([(x + 20) * S, (h - hh) * S, (x + ww - 20) * S, (h - hh + 6) * S], fill=shade(col, 1.3) + (255,))
    elif kind == "skyline":
        x = 0
        while x < w:
            bw = rnd.randint(40, 110)
            bh = rnd.randint(int(h * 0.3), h)
            d.rectangle([x * S, (h - bh) * S, (x + bw) * S, h * S], fill=col + (255,))
            for wy in range(h - bh + 8, h - 6, 14):
                for wx in range(x + 6, x + bw - 8, 12):
                    if rnd.random() < 0.3:
                        d.rectangle([wx * S, wy * S, (wx + 5) * S, (wy + 6) * S], fill=(255, 214, 120, 255))
            x += bw + rnd.randint(0, 10)
    elif kind == "peaks":
        for i in range(-1, 10):
            x = i * 230 + rnd.randint(-40, 40)
            ww = rnd.randint(220, 380)
            hh = rnd.randint(int(h * 0.5), h)
            top = (x + ww / 2, h - hh)
            d.polygon([(x * S, h * S), (top[0] * S, top[1] * S), ((x + ww) * S, h * S)], fill=col + (255,))
            cap = 0.25
            d.polygon([(top[0] * S, top[1] * S), ((top[0] - ww * cap / 2) * S, (top[1] + hh * cap) * S), ((top[0] + ww * cap / 2) * S, (top[1] + hh * cap) * S)], fill=shade(col, 1.6) + (255,))
    elif kind == "sea":
        d.rectangle([0, (h - 30) * S, w * S, h * S], fill=col + (255,))
        for i in range(60):
            x = rnd.randint(0, w)
            y = rnd.randint(h - 28, h - 4)
            d.rectangle([x * S, y * S, (x + rnd.randint(10, 40)) * S, (y + 1) * S], fill=(220, 240, 255, 200))
    elif kind == "island":
        for x0 in (200, 1100, 1700):
            d.ellipse([x0 * S, (h - 50) * S, (x0 + 260) * S, (h + 40) * S], fill=col + (255,))
    elif kind == "grid":
        for i in range(-1, 9):
            x = i * 260 + rnd.randint(-30, 30)
            ww = rnd.randint(260, 380)
            hh = rnd.randint(int(h * 0.4), h)
            d.polygon([(x * S, h * S), ((x + ww / 2) * S, (h - hh) * S), ((x + ww) * S, h * S)], fill=col + (255,))
            d.line([(x * S, h * S), ((x + ww / 2) * S, (h - hh) * S), ((x + ww) * S, h * S)], fill=(255, 80, 210, 255), width=2 * S)
    elif kind == "volcano":
        for x0, ww, hh in ((300, 620, h), (1250, 500, int(h * 0.8))):
            d.polygon([(x0 * S, h * S), ((x0 + ww * 0.42) * S, (h - hh) * S), ((x0 + ww * 0.58) * S, (h - hh) * S), ((x0 + ww) * S, h * S)], fill=col + (255,))
            d.polygon([((x0 + ww * 0.44) * S, (h - hh) * S), ((x0 + ww * 0.56) * S, (h - hh) * S), ((x0 + ww * 0.6) * S, (h - hh + 40) * S), ((x0 + ww * 0.5) * S, (h - hh + 70) * S)], fill=(255, 110, 30, 255))
    elif kind == "treeline":
        x = 0
        while x < w:
            tw = rnd.randint(18, 36)
            th = rnd.randint(int(h * 0.4), h)
            d.polygon([(x * S, h * S), ((x + tw / 2) * S, (h - th) * S), ((x + tw) * S, h * S)], fill=col + (255,))
            x += rnd.randint(8, 20)
    elif kind == "craters":
        for i in range(-1, 9):
            x = i * 250 + rnd.randint(-30, 30)
            ww = rnd.randint(260, 420)
            hh = rnd.randint(int(h * 0.3), int(h * 0.8))
            d.ellipse([x * S, (h - hh) * S, (x + ww) * S, (h + hh) * S], fill=col + (255,))
            d.ellipse([(x + ww * 0.3) * S, (h - hh * 0.7) * S, (x + ww * 0.5) * S, (h - hh * 0.55) * S], fill=shade(col, 0.7) + (255,))
    c.paste(lay)
    # wrap: copy the left 300px onto the right edge so the strip tiles
    img = c.img
    img.paste(img.crop((0, 0, 300 * S, h * S)), ((w - 300) * S, 0), img.crop((0, 0, 300 * S, h * S)))
    return img.resize((w, h), Image.LANCZOS)


def sky(theme, w=1280, h=250):
    t = THEMES[theme]
    top, bottom = rgb(t["sky"][0]), rgb(t["sky"][1])
    img = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        d.line([(0, y), (w, y)], fill=mix(top, bottom, (y / (h - 1)) ** 1.4) + (255,))
    rnd = random.Random(theme)
    for _ in range(t.get("stars", 0)):
        x, y = rnd.randint(0, w), rnd.randint(0, int(h * 0.7))
        a = rnd.randint(120, 255)
        d.rectangle([x, y, x + (1 if rnd.random() < 0.8 else 2), y + 1], fill=(255, 255, 255, a))
    if t.get("planet"):
        pl = Image.new("RGBA", (w * 2, h * 2), (0, 0, 0, 0))
        pd = ImageDraw.Draw(pl)
        pd.ellipse([1500, 60, 1780, 340], fill=(90, 140, 230, 255))
        pd.ellipse([1560, 120, 1700, 200], fill=(120, 200, 120, 255))
        pd.ellipse([1520, 60, 1800, 340], fill=(0, 0, 0, 120))
        img = Image.alpha_composite(img, pl.resize((w, h), Image.LANCZOS))
    if t.get("sun"):
        col, fx, fy = t["sun"]
        cx, cy, r = int(w * fx), int(h * fy), 46
        glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        ImageDraw.Draw(glow).ellipse([cx - r * 2.2, cy - r * 2.2, cx + r * 2.2, cy + r * 2.2], fill=rgb(col) + (90,))
        img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(28)))
        sun = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
        sd = ImageDraw.Draw(sun)
        sd.ellipse([(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS], fill=rgb(col) + (255,))
        if theme == "synth":
            for k in range(6):
                yy = cy + 6 + k * 7
                sd.rectangle([(cx - r) * SS, yy * SS, (cx + r) * SS, (yy + 1 + k * 0.6) * SS], fill=(0, 0, 0, 0))
        img = Image.alpha_composite(img, sun.resize((w, h), Image.LANCZOS))
    return img


def theme_art(theme):
    t = THEMES[theme]
    return {
        f"sky_{theme}.png": sky(theme),
        f"far_{theme}.png": ridge(t["far"][1], 2048, 120, t["far"][0], theme + "far"),
        f"near_{theme}.png": ridge(t["near"][1], 2048, 70, t["near"][0], theme + "near"),
    }


KART_STYLES = ["classic", "f1", "monster", "bubble", "hover", "frog", "robot", "buggy", "muscle", "soapbox"]
BODIES = [0xE0322E, 0x2FB14A, 0x8E44D9, 0xFF8C1A]   # you, then the bots
SCENERY = ["tree", "pine", "cactus", "rock", "lamp", "building", "palm", "pylon", "lavarock", "autumn", "fence", "crystal"]
ITEMS = ["block", "shell", "banana", "boost", "car"]


def main():
    out = Path(sys.argv[1])
    only = set()
    if "--only" in sys.argv:
        only = set(sys.argv[sys.argv.index("--only") + 1].split(","))
    want = lambda kind, name: not only or f"{kind}:{name}" in only or f"{kind}:*" in only
    out.mkdir(parents=True, exist_ok=True)
    for style in KART_STYLES:
        if want("kart", style):
            for i, b in enumerate(BODIES):
                kart(style, b).save(out / f"kart_{style}_{i}.png", optimize=True)
    for n in ITEMS:
        if want("item", n):
            item(n).save(out / f"{n}.png", optimize=True)
    for n in SCENERY:
        if want("scenery", n):
            scenery(n).save(out / f"{n}.png", optimize=True)
    for th in THEMES:
        if want("theme", th):
            for fn, img in theme_art(th).items():
                img.save(out / fn, optimize=True)


if __name__ == "__main__":
    main()
