#!/usr/bin/env python3
"""Offline preview of the POC: composites the kart sprites over a world's rendered video, using the same lane-table
math as video_poc/source/logic.brs (TableSample, KartPlace, AngleIndex). Used to check the overlay lines up with
the road before testing on a TV, and to make the demo clip.
   python3 preview.py <media/world dir> <lanes.json> <sprites dir> <out.mp4> [left|right] [zoom]"""
import json, math, subprocess, sys
from PIL import Image

media, lanes_p, spr_dir, out = sys.argv[1:5]
branch = sys.argv[5] if len(sys.argv) > 5 else 'left'
zoom = float(sys.argv[6]) if len(sys.argv) > 6 else 1.0
L = json.load(open(lanes_p))
S = json.load(open(f'{spr_dir}/karts.json'))
W, H, FPS, FOCAL, LANE_W = 1280, 720, 30, 691.5, 3.6
sprites = {}


def sprite(v, a):
    k = (v, a)
    if k not in sprites:
        sprites[k] = Image.open(f'{spr_dir}/kart_{v}_{a}.png').convert('RGBA')
    return sprites[k]


def depth_sample(row, d):
    D = L['depths']
    if d <= D[0]:
        j, k, u = 0, 0, 0.0
    elif d >= D[-1]:
        j = k = len(D) - 1; u = 0.0
    else:
        j = 0
        while j < len(D) - 2 and D[j + 1] < d:
            j += 1
        k, u = j + 1, (d - D[j]) / (D[j + 1] - D[j])
    return [row[j * 4 + i] + (row[k * 4 + i] - row[j * 4 + i]) * u for i in range(4)]


def table_sample(rows, t, d):
    f = min(max(t * L['rate'], 0), len(rows) - 1)
    i = min(int(f), len(rows) - 2); ft = f - i
    a, b = depth_sample(rows[i], d), depth_sample(rows[i + 1], d)
    return [a[n] + (b[n] - a[n]) * ft for n in range(4)]


def place(s, lane, steer=0.0, spin=0.0):
    x, y, ppm, yaw = s
    x = x + ppm * (lane - 2) * LANE_W
    k = ppm / S['pxPerM']
    bearing = math.degrees(math.atan((x - 640) / FOCAL))
    ang = round((bearing - yaw + steer + spin) / 15) % 24
    return x, y, k, ang


# A scripted lap: you weave lanes and boost; three bots hold lanes and drift ahead and back.
def script(t):
    side = 0 if branch == 'left' else 4
    keys = [(0, 2), (1.0, 2), (1.6, side), (6.0, side), (6.6, 2), (9.0, 2), (9.3, 3), (12.0, 3), (12.3, 1)]
    lane, steer = keys[-1][1], 0.0
    for (t0, l0), (t1, l1) in zip(keys, keys[1:]):
        if t0 <= t < t1:
            lane = l0 + (l1 - l0) * (t - t0) / (t1 - t0)
            steer = 14.0 * (1 if l1 > l0 else -1 if l1 < l0 else 0)
            break
    boost = 2.5 < t < 4.1 or 10.5 < t < 12.1
    d = -2.5
    for (t0, t1) in [(2.5, 4.1), (10.5, 12.1)]:
        if t > t0:
            up = min(t, t1) - t0
            d += 10 * (1 - math.exp(-1.6 * up)) * (math.exp(-1.6 * (t - t1)) if t > t1 else 1)
    karts = [dict(v='red', lane=lane, d=d, steer=steer)]
    for v, ln, base, ph in [('teal', 1, 6, 0.0), ('gold', 3, 11, 2.0), ('violet', 4, 3, 4.0)]:
        karts.append(dict(v=v, lane=ln, d=-2.5 + base + 5 * math.sin(t * 0.4 + ph), steer=0.0))
    return karts, boost


segs = [('shared', f'shared_{branch}'), (branch, branch)]
enc = subprocess.Popen(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-',
                        '-c:v', 'libx264', '-preset', 'slow', '-crf', '22', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', out], stdin=subprocess.PIPE)
T = 0.0
focus = 640.0
for seg, key in segs:
    rows = L['tables'][key]
    dec = subprocess.Popen(['ffmpeg', '-loglevel', 'error', '-i', f'{media}/{seg}.mp4', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'], stdout=subprocess.PIPE)
    n = 0
    while True:
        raw = dec.stdout.read(W * H * 3)
        if len(raw) < W * H * 3:
            break
        t = n / FPS
        frame = Image.frombytes('RGB', (W, H), raw).convert('RGBA')
        karts, boost = script(T + t)
        placed = []
        for k in karts:
            if seg != 'shared' and k['v'] == 'gold':
                continue                                   # gold took the other fork
            x, y, sc, ang = place(table_sample(rows, t, k['d']), k['lane'], k['steer'])
            placed.append((k['d'], k['v'], x, y, sc, ang))
            if k['v'] == 'red':
                px = x
        for d, v, x, y, sc, ang in sorted(placed, reverse=True):
            im = sprite(v, S['angles'][ang])
            w, h = max(1, round(im.width * sc)), max(1, round(im.height * sc))
            frame.alpha_composite(im.resize((w, h), Image.LANCZOS), (round(x - S['anchorX'] * sc), round(y - S['anchorY'] * sc)))
        if zoom > 1:
            focus += (px - focus) * 6 / FPS
            tx = min(0, max(W - W * zoom, 640 - focus * zoom)); ty = min(0, max(H - H * zoom, 470 - 470 * zoom))
            frame = frame.resize((round(W * zoom), round(H * zoom)), Image.BILINEAR).crop((round(-tx), round(-ty), round(-tx) + W, round(-ty) + H))
        enc.stdin.write(frame.convert('RGB').tobytes())
        n += 1
    T += n / FPS
enc.stdin.close(); enc.wait()
print('preview', out, round(T, 2), 's')
