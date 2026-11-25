#!/usr/bin/env python3
"""Crop the raw kart renders to one shared box (so every angle has the same size and ground anchor),
shrink them, and save palette PNGs for the Roku overlay. Writes <out>/kart_<variant>_<angle>.png and karts.json.
   python3 sprites.py <raw dir> <out dir> [scale]"""
import json, sys
from pathlib import Path
from PIL import Image

raw, out = Path(sys.argv[1]), Path(sys.argv[2])
scale = float(sys.argv[3]) if len(sys.argv) > 3 else 0.75
meta = json.loads((raw / 'karts.json').read_text())
out.mkdir(parents=True, exist_ok=True)
box = None
files = [(v, a) for v in meta['variants'] for a in meta['angles']]
for v, a in files:
    bb = Image.open(raw / f'{v}_{a}.png').getchannel('A').point(lambda x: 255 if x > 8 else 0).getbbox()
    box = bb if box is None else (min(box[0], bb[0]), min(box[1], bb[1]), max(box[2], bb[2]), max(box[3], bb[3]))
# keep the ground anchor horizontally centred in the box
ax, ay = meta['anchor']
half = max(ax - box[0], box[2] - ax)
box = (int(ax - half), box[1], int(ax + half) + 1, box[3])
w, h = round((box[2] - box[0]) * scale), round((box[3] - box[1]) * scale)
total = 0
for v, a in files:
    im = Image.open(raw / f'{v}_{a}.png').crop(box).resize((w, h), Image.LANCZOS)
    p = out / f'kart_{v}_{a}.png'
    im.quantize(colors=96, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).save(p, optimize=True)
    total += p.stat().st_size
info = {'w': w, 'h': h, 'anchorX': w / 2, 'anchorY': round((ay - box[1]) * scale, 1), 'pxPerM': round(meta['pxPerM'] * scale, 2),
        'angles': meta['angles'], 'variants': meta['variants']}
(out / 'karts.json').write_text(json.dumps(info))
print(info, 'total bytes', total)
