#!/usr/bin/env python3
"""Shrink the art so the sideload zip stays under Roku's install limit (old Roku docs: 2 MB zipped; we cap at
1.9 MB in scripts/package.config.json). Opaque backgrounds (sky_, road_, below_) become JPEG; every other sprite
becomes a 256-color palette PNG with transparency. Run after the generators:

    python3 scripts/art/optimize.py images/sprites
"""
import io
import sys
from pathlib import Path

from PIL import Image

JPEG_PREFIXES = ("sky_", "road_", "below_")


def main():
    folder = Path(sys.argv[1])
    before = after = 0
    for p in sorted(folder.glob("*.png")):
        data_in = p.read_bytes()
        before += len(data_in)
        im = Image.open(p)
        if p.stem.startswith(JPEG_PREFIXES):
            buf = io.BytesIO()
            im.convert("RGB").save(buf, "JPEG", quality=86, optimize=True)
            out = p.with_suffix(".jpg")
            out.write_bytes(buf.getvalue())
            p.unlink()
            after += out.stat().st_size
            continue
        if im.mode == "P":
            after += len(data_in)
            continue
        q = im.convert("RGBA").quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
        buf = io.BytesIO()
        q.save(buf, "PNG", optimize=True)
        if buf.tell() < len(data_in):
            p.write_bytes(buf.getvalue())
        after += p.stat().st_size
    print(f"art: {before} -> {after} bytes")


if __name__ == "__main__":
    main()
