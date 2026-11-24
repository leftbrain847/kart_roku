"""Big 3D scenery props, rendered by sdf3d.py: a giant long-neck dinosaur, girder pillars and beacons for the sky
track, a lighthouse, beach umbrella and rock arch. Front views (seen from the road)."""
from __future__ import annotations

import math

import numpy as np

from sdf3d import Mat, blend, box, capsule, cone_cap, crop, cut, cyl_y, ellipsoid, render, sphere


def brachio():
    skin = Mat((110, 150, 90), spec=0.25, shine=12, rim=0.4)
    belly = Mat((190, 200, 140), spec=0.2)
    spots = Mat((80, 110, 70))
    body = blend(0.35, ellipsoid((0, 2.2, 0), (1.6, 1.1, 2.4)),
                 cone_cap((0, 2.8, 1.6), (0.2, 6.2, 3.4), 0.55, 0.28),
                 ellipsoid((0.3, 6.4, 3.8), (0.4, 0.32, 0.6)),
                 cone_cap((0, 2.0, -2.0), (-0.6, 1.0, -4.6), 0.6, 0.08))
    legs = [capsule((x, 0.2, z), (x, 2.0, z), 0.42) for x in (-1.0, 1.0) for z in (-1.4, 1.4)]
    parts = [(body, skin)] + [(l, skin) for l in legs]
    parts += [(ellipsoid((0, 1.6, 0.2), (1.2, 0.5, 1.8)), belly)]
    for i, (x, y, z) in enumerate(((-0.8, 3.0, 0.4), (0.7, 2.9, -0.6), (0.1, 3.2, -1.2), (0.9, 3.0, 1.0))):
        parts.append((sphere((x, y, z), 0.22), spots))
    parts.append((sphere((0.55, 6.55, 4.15), 0.07), Mat((20, 20, 20), spec=0.9, shine=60)))
    return parts


def fern():
    leaf = Mat((60, 150, 70), spec=0.3, rim=0.5)
    parts = []
    for i in range(9):
        a = i / 9 * math.tau
        parts.append((cone_cap((0, 0.2, 0), (1.1 * math.cos(a), 0.9 + 0.3 * (i % 2), 1.1 * math.sin(a) * 0.5), 0.18, 0.04), leaf))
    parts.append((sphere((0, 0.25, 0), 0.3), Mat((90, 70, 40))))
    return parts


def girder():
    """A riveted steel truss column hanging below the track (anchored at its top)."""
    steel = Mat((150, 156, 172), spec=0.9, shine=70, rim=0.5, metal=True)
    red = Mat((200, 60, 50), spec=0.6, shine=40)
    parts = []
    for x in (-0.35, 0.35):
        for z in (-0.35, 0.35):
            parts.append((box((x, 0, z), (0.07, 3.0, 0.07)), steel))
    for k in range(7):
        y = -2.8 + k * 0.9
        parts.append((box((0, y, -0.35), (0.42, 0.05, 0.05)), steel))
        parts.append((capsule((-0.35, y, -0.35), (0.35, y + 0.9, -0.35), 0.035), steel))
    parts.append((box((0, 3.0, 0), (0.5, 0.12, 0.5)), red))
    return parts


def beacon():
    pole = Mat((70, 74, 90), spec=0.8, shine=50, metal=True)
    lamp = Mat((255, 90, 60), spec=0.6, glow=1.4)
    return [(cyl_y((0, 1.0, 0), 0.06, 1.0), pole), (box((0, 2.05, 0), (0.18, 0.06, 0.18), 0.03), pole),
            (sphere((0, 2.25, 0), 0.16), lamp)]


def lighthouse():
    white = Mat((245, 245, 240), spec=0.4, rim=0.4)
    red = Mat((215, 50, 45), spec=0.4, rim=0.4)
    glass = Mat((255, 235, 150), spec=0.8, glow=1.0)
    dark = Mat((40, 44, 56), spec=0.5)
    parts = []
    for i in range(5):
        y = i * 0.9
        r = 0.75 - i * 0.07
        parts.append((cyl_y((0, y + 0.45, 0), r, 0.45), red if i % 2 else white))
    parts += [(cyl_y((0, 4.7, 0), 0.62, 0.06), dark), (cyl_y((0, 5.05, 0), 0.38, 0.3), glass),
              (cone_cap((0, 5.4, 0), (0, 5.9, 0), 0.45, 0.02), red)]
    return parts


def umbrella():
    canopy = [Mat((240, 70, 80), spec=0.4, rim=0.4), Mat((250, 250, 245), spec=0.4, rim=0.4)]
    parts = [(cyl_y((0, 1.0, 0), 0.04, 1.0), Mat((230, 230, 230), spec=0.6, metal=True))]
    for i in range(8):
        a0 = i / 8 * math.tau
        parts.append((cone_cap((0, 2.1, 0), (1.1 * math.cos(a0 + 0.2), 1.65, 1.1 * math.sin(a0 + 0.2)), 0.05, 0.38), canopy[i % 2]))
    return parts


def rockarch():
    rock = Mat((176, 150, 120), spec=0.2, shine=10, rim=0.3)
    dark = Mat((140, 116, 90), spec=0.15)
    arch = blend(0.5, ellipsoid((-2.2, 1.6, 0), (1.0, 1.8, 1.0)), ellipsoid((2.2, 1.6, 0), (1.0, 1.8, 1.0)),
                 ellipsoid((0, 3.3, 0), (3.0, 0.9, 1.0)))
    arch = cut(arch, ellipsoid((0, 0.8, 0), (1.6, 2.2, 2.0)))
    return [(arch, rock), (sphere((-1.3, 3.6, -0.6), 0.3), dark), (sphere((1.6, 3.2, -0.7), 0.25), dark)]


PROPS = {"brachio": (brachio, (620, 520), 10.5, (0, 3.4, 0.2), 4),
         "fern": (fern, (220, 160), 2.6, (0, 0.6, 0), 8),
         "girder": (girder, (120, 520), 6.6, (0, 0, 0), 4),
         "beacon": (beacon, (90, 230), 2.6, (0, 1.2, 0), 6),
         "lighthouse": (lighthouse, (180, 520), 6.6, (0, 3.0, 0), 4),
         "umbrella": (umbrella, (220, 200), 2.7, (0, 1.1, 0), 12),
         "rockarch": (rockarch, (560, 380), 7.0, (0, 2.0, 0), 4)}


YAW = {"brachio": 90}


def render_prop(name):
    fn, size, extent, center, pitch = PROPS[name]
    return crop(render(fn(), size=size, yaw_deg=YAW.get(name, 0), pitch_deg=pitch, zoom=2.6 / (extent * min(1.0, size[0] / size[1])),
                       center=center, shadow=True))


if __name__ == "__main__":
    import sys
    from pathlib import Path
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    for n in (sys.argv[2].split(",") if len(sys.argv) > 2 else PROPS):
        render_prop(n).save(out / f"{n}.png", optimize=True)
        print(n, flush=True)
