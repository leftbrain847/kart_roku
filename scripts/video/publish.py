#!/usr/bin/env python3
"""Make the streamable copies of a rendered world: re-encode the segments small enough to keep in the repo (or
upload to R2), join them into all.mp4 for the seek method, and copy the lane table (with the new sizes) into the app.
   python3 publish.py <rendered world dir> <media/world out dir> <video_poc/data/world.json> [crf]"""
import json, subprocess, sys
from pathlib import Path

src, out, data = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
crf = sys.argv[4] if len(sys.argv) > 4 else '29'
out.mkdir(parents=True, exist_ok=True)
lanes = json.loads((src / 'lanes.json').read_text())
for seg in ['shared', 'left', 'right']:
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', str(src / f'{seg}.mp4'), '-c:v', 'libx264', '-preset', 'slower', '-crf', crf,
                    '-pix_fmt', 'yuv420p', '-profile:v', 'high', '-level', '4.1', '-g', '15', '-keyint_min', '15', '-sc_threshold', '0',
                    '-map_metadata', '-1', '-movflags', '+faststart', '-an', str(out / f'{seg}.mp4')], check=True)
    lanes['segs'][seg]['bytes'] = (out / f'{seg}.mp4').stat().st_size
lst = out / 'list.txt'
lst.write_text(''.join(f"file '{s}.mp4'\n" for s in ['shared', 'left', 'right']))
subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', str(lst), '-c', 'copy', '-map_metadata', '-1',
                '-movflags', '+faststart', str(out / 'all.mp4')], check=True)
lst.unlink()
data.write_text(json.dumps(lanes, separators=(',', ':')))
print({s: lanes['segs'][s] for s in lanes['segs']}, 'all', (out / 'all.mp4').stat().st_size)
