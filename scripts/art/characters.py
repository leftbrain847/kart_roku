"""Kart's racers as 3D models (signed-distance shapes), rendered by sdf3d.py from behind at several angles.
Coordinates: x right, y up, z forward (the kart drives toward +z, the camera sits behind it). Ground is y = 0.
"""
from __future__ import annotations

import math

from sdf3d import (Mat, blend, box, capsule, cone_cap, crop, cut, cyl_x, cyl_y, ellipsoid, render, sphere,
                   torus_x, twist_y)

TIRE = Mat((34, 34, 40), spec=0.25, shine=10, rim=0.15)
HUB = Mat((200, 200, 210), spec=0.8, shine=60, metal=True)


def wheels(xs=0.58, zf=0.42, zb=-0.42, y=0.2, R=0.16, r=0.08, tire=TIRE, hub=HUB):
    out = []
    for x in (-xs, xs):
        for z in (zf, zb):
            out.append((torus_x((x, y, z), R, r), tire))
            out.append((cyl_x((x, y, z), R * 0.75, 0.03), hub))
    return out


def hatchling():
    """A baby raptor driving the speckled eggshell it just hatched from."""
    shell = Mat((214, 190, 150), spec=0.5, shine=40, rim=0.3)
    spots = Mat((120, 84, 50), spec=0.2)
    skin = Mat((240, 120, 50), spec=0.35, shine=20, rim=0.45)
    belly = Mat((250, 220, 170), spec=0.2)
    spike = Mat((40, 170, 170), spec=0.4, shine=30)
    eye = Mat((255, 255, 255), spec=0.9, shine=80)
    pupil = Mat((20, 20, 20), spec=0.9, shine=80)
    egg = ellipsoid((0, 0.5, 0), (0.62, 0.45, 0.8))
    egg = cut(egg, ellipsoid((0, 0.55, 0), (0.54, 0.4, 0.72)))
    rim = box((0, 1.05, 0), (1, 0.32, 1))
    for i in range(7):
        a = i / 7 * math.tau
        rim_s = sphere((0.6 * math.cos(a), 0.78, 0.78 * math.sin(a)), 0.13)
        rim = (lambda f, g: (lambda p: __import__("numpy").minimum(f(p), g(p))))(rim, rim_s)
    egg = cut(egg, rim)
    head = blend(0.12, sphere((0, 1.08, 0.12), 0.34), ellipsoid((0, 1.02, 0.42), (0.22, 0.18, 0.26)),
                 capsule((0, 0.62, 0.1), (0, 0.95, 0.1), 0.24))
    parts = [
        (egg, shell),
        (sphere((-0.35, 0.42, -0.62), 0.09), spots), (sphere((0.4, 0.5, -0.55), 0.07), spots),
        (sphere((0.1, 0.3, -0.74), 0.06), spots),
        (head, skin),
        (ellipsoid((0, 0.7, -0.08), (0.2, 0.18, 0.1)), belly),
        (capsule((0, 0.62, -0.2), (0.25, 0.35, -0.95), 0.12), skin),
        (sphere((0.3, 0.38, -1.02), 0.1), skin),
        (cone_cap((0, 1.36, 0.0), (0, 1.52, -0.02), 0.07, 0.01), spike),
        (cone_cap((0, 1.26, -0.2), (0, 1.38, -0.3), 0.06, 0.01), spike),
        (cone_cap((0, 1.06, -0.32), (0, 1.12, -0.46), 0.05, 0.01), spike),
        (sphere((-0.27, 1.2, 0.2), 0.12), eye), (sphere((0.27, 1.2, 0.2), 0.12), eye),
        (sphere((-0.32, 1.22, 0.24), 0.06), pupil), (sphere((0.32, 1.22, 0.24), 0.06), pupil),
        (capsule((-0.2, 0.82, 0.1), (-0.3, 0.75, 0.35), 0.06), skin),
        (capsule((0.2, 0.82, 0.1), (0.3, 0.75, 0.35), 0.06), skin),
    ] + wheels(xs=0.6, y=0.18, R=0.15, r=0.075, tire=Mat((230, 220, 200), spec=0.3), hub=Mat((140, 110, 80)))
    return parts


def triceracart():
    """A triceratops whose four feet are wheels."""
    hide = Mat((214, 120, 64), spec=0.25, shine=14, rim=0.35)
    frill = Mat((240, 170, 70), spec=0.3, rim=0.35)
    dots = Mat((120, 60, 140), spec=0.3)
    horn = Mat((250, 242, 220), spec=0.6, shine=40)
    body = blend(0.2, ellipsoid((0, 0.62, 0), (0.55, 0.38, 0.75)), ellipsoid((0, 0.72, 0.6), (0.32, 0.28, 0.3)))
    parts = [
        (body, hide),
        (ellipsoid((0, 0.98, 0.62), (0.6, 0.42, 0.07)), frill),
        (sphere((-0.3, 1.1, 0.56), 0.07), dots), (sphere((0.3, 1.1, 0.56), 0.07), dots), (sphere((0, 1.3, 0.56), 0.08), dots),
        (cone_cap((-0.22, 1.0, 0.8), (-0.5, 1.15, 1.25), 0.07, 0.01), horn),
        (cone_cap((0.22, 1.0, 0.8), (0.5, 1.15, 1.25), 0.07, 0.01), horn),
        (cone_cap((0, 0.6, -0.6), (0, 0.45, -1.15), 0.18, 0.03), hide),
        (box((0, 0.95, 0.05), (0.18, 0.04, 0.18), 0.03), Mat((90, 60, 40))),
    ] + wheels(xs=0.52, zf=0.45, zb=-0.45, y=0.2, R=0.17, r=0.08)
    return parts


def toaster():
    """A chrome toaster on tank treads, two slices of toast up top."""
    chrome = Mat((210, 214, 224), spec=1.0, shine=90, rim=0.5, metal=True)
    toast = Mat((214, 160, 90), spec=0.15, shine=8)
    crust = Mat((140, 84, 40), spec=0.1)
    tread = Mat((40, 40, 46), spec=0.3, shine=12)
    red = Mat((230, 50, 40), spec=0.7, shine=50)
    led = Mat((80, 230, 255), spec=0.6, glow=0.9)
    parts = [
        (box((0, 0.72, 0), (0.46, 0.38, 0.55), 0.14), chrome),
        (box((-0.17, 1.12, 0.0), (0.1, 0.2, 0.36), 0.04), crust),
        (box((-0.17, 1.13, 0.0), (0.08, 0.19, 0.33), 0.03), toast),
        (box((0.17, 1.18, 0.05), (0.1, 0.22, 0.36), 0.04), crust),
        (box((0.17, 1.19, 0.05), (0.08, 0.21, 0.33), 0.03), toast),
        (capsule((0.5, 0.85, -0.1), (0.62, 0.95, -0.1), 0.04), chrome),
        (sphere((0.64, 0.97, -0.1), 0.07), red),
        (sphere((-0.18, 0.78, -0.56), 0.07), led), (sphere((0.18, 0.78, -0.56), 0.07), led),
        (box((0, 0.55, -0.56), (0.14, 0.03, 0.02), 0.015), led),
        (box((-0.58, 0.2, 0), (0.13, 0.19, 0.62), 0.12), tread),
        (box((0.58, 0.2, 0), (0.13, 0.19, 0.62), 0.12), tread),
    ]
    for x in (-0.58, 0.58):
        for z in (-0.4, 0, 0.4):
            parts.append((cyl_x((x, 0.2, z), 0.12, 0.14), HUB))
    return parts


def gearsnail():
    """A snail with a brass gear shell and a jet engine."""
    slug = Mat((150, 190, 140), spec=0.6, shine=40, rim=0.5)
    brass = Mat((220, 170, 70), spec=0.9, shine=70, rim=0.45, metal=True)
    dark = Mat((60, 50, 40), spec=0.4)
    flame = Mat((255, 150, 50), spec=0.2, glow=1.2)
    eye = Mat((20, 20, 24), spec=0.9, shine=80)
    shell = twist_y(blend(0.04, ellipsoid((0, 0.95, -0.05), (0.42, 0.5, 0.5)),
                          *[box((0.42 * math.cos(a), 0.95, 0.42 * math.sin(a)), (0.08, 0.42, 0.08), 0.03)
                            for a in [i * math.tau / 10 for i in range(10)]]), 0.0)
    parts = [
        (blend(0.15, capsule((0, 0.28, -0.7), (0, 0.32, 0.75), 0.24), sphere((0, 0.5, 0.75), 0.26)), slug),
        (shell, brass),
        (cyl_x((0, 0.95, -0.05), 0.2, 0.46), dark),
        (cyl_x((0, 0.95, -0.05), 0.12, 0.47), brass),
        (capsule((-0.12, 0.7, 0.85), (-0.2, 1.2, 0.95), 0.04), slug), (capsule((0.12, 0.7, 0.85), (0.2, 1.2, 0.95), 0.04), slug),
        (sphere((-0.2, 1.24, 0.95), 0.08), eye), (sphere((0.2, 1.24, 0.95), 0.08), eye),
        (cyl_y((0, 0.45, -0.85), 0.17, 0.02), brass),
        (blend(0.05, capsule((0, 0.42, -0.72), (0, 0.42, -1.0), 0.16)), Mat((90, 90, 100), spec=0.8, metal=True)),
        (ellipsoid((0, 0.42, -1.12), (0.12, 0.12, 0.16)), flame),
    ] + wheels(xs=0.34, zf=0.45, zb=-0.4, y=0.13, R=0.11, r=0.05)
    return parts


def hermit():
    """A hermit crab driving its own conch shell."""
    conch = Mat((250, 190, 190), spec=0.7, shine=50, rim=0.55)
    lip = Mat((255, 230, 210), spec=0.6, shine=40)
    crab = Mat((230, 70, 50), spec=0.5, shine=30, rim=0.4)
    eye = Mat((20, 20, 20), spec=0.9, shine=80)
    disc = Mat((235, 228, 205), spec=0.3)
    spiral = twist_y(blend(0.06, cone_cap((0, 0.55, -0.35), (0, 1.25, 0.55), 0.5, 0.06),
                           *[cone_cap((0.45 * math.cos(a), 0.55 + i * 0.08, -0.3 + i * 0.1), (0.38 * math.cos(a + 1), 0.6 + i * 0.08, -0.25 + i * 0.1), 0.07, 0.07)
                             for i, a in enumerate([k * 1.3 for k in range(7)])]), 1.4)
    parts = [
        (spiral, conch),
        (ellipsoid((0, 0.55, -0.62), (0.4, 0.34, 0.08)), lip),
        (sphere((0, 0.56, -0.58), 0.24), crab),
        (capsule((-0.1, 0.72, -0.62), (-0.16, 0.98, -0.66), 0.03), crab), (capsule((0.1, 0.72, -0.62), (0.16, 0.98, -0.66), 0.03), crab),
        (sphere((-0.16, 1.0, -0.66), 0.06), eye), (sphere((0.16, 1.0, -0.66), 0.06), eye),
        (ellipsoid((-0.62, 0.55, -0.35), (0.2, 0.14, 0.22)), crab), (ellipsoid((0.62, 0.55, -0.35), (0.2, 0.14, 0.22)), crab),
        (capsule((-0.25, 0.5, -0.55), (-0.55, 0.52, -0.38), 0.06), crab), (capsule((0.25, 0.5, -0.55), (0.55, 0.52, -0.38), 0.06), crab),
        (ellipsoid((-0.75, 0.62, -0.3), (0.08, 0.1, 0.16)), crab), (ellipsoid((0.75, 0.62, -0.3), (0.08, 0.1, 0.16)), crab),
    ]
    for x in (-0.5, 0.5):
        for z in (0.35, -0.2):
            parts.append((cyl_x((x, 0.17, z), 0.17, 0.04), disc))
            parts.append((cyl_x((x, 0.17, z), 0.06, 0.05), Mat((200, 180, 150))))
    return parts


def jelly():
    """A hovering jellyfish with a glowing bell and trailing tentacles."""
    bell = Mat((255, 130, 190), spec=0.9, shine=60, rim=0.9, glow=0.25)
    inner = Mat((255, 210, 120), spec=0.5, glow=0.6)
    tent = Mat((200, 120, 230), spec=0.6, shine=40, rim=0.6, glow=0.2)
    dome = cut(ellipsoid((0, 0.95, 0), (0.6, 0.48, 0.6)), box((0, 0.5, 0), (1, 0.42, 1)))
    parts = [(dome, bell), (sphere((0, 1.0, 0), 0.25), inner)]
    for i in range(8):
        a = i / 8 * math.tau
        x, z = 0.42 * math.cos(a), 0.42 * math.sin(a)
        parts.append((cone_cap((x, 0.92, z), (x * 1.2 + 0.05 * math.sin(i), 0.15, z * 1.1 - 0.25), 0.07, 0.025), tent))
    return parts


CHARACTERS = {"hatchling": hatchling, "triceracart": triceracart, "toaster": toaster, "gearsnail": gearsnail,
              "hermit": hermit, "jelly": jelly}
ANGLES = {"c": 0, "l": -24, "r": 24}   # camera yaw: centre, leaning left, leaning right


def render_character(name, angle="c", size=(300, 260)):
    parts = CHARACTERS[name]()
    return crop(render(parts, size=size, yaw_deg=ANGLES[angle], pitch_deg=16, zoom=1.05, center=(0, 0.62, 0)))


if __name__ == "__main__":
    import sys
    import time
    from pathlib import Path
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    names = sys.argv[2].split(",") if len(sys.argv) > 2 else list(CHARACTERS)
    for n in names:
        for a in ANGLES:
            t = time.time()
            render_character(n, a).save(out / f"racer_{n}_{a}.png", optimize=True)
            print(n, a, f"{time.time() - t:.1f}s", flush=True)
