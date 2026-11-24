"""A tiny offline 3D renderer for sprites: signed-distance-field shapes, ray marched with numpy, lit with a key
light, sky fill, rim light, specular highlights and ambient occlusion, then outlined. Sprites are rendered from
several camera angles so a kart can lean and turn on screen. Runs at build time only; the game copies the PNGs.
"""
from __future__ import annotations

import numpy as np
from PIL import Image, ImageFilter

# ---------- shapes: each returns distance for points p (N,3) ----------


def sphere(c, r):
    c = np.array(c, float)
    return lambda p: np.linalg.norm(p - c, axis=1) - r


def ellipsoid(c, r):
    c, r = np.array(c, float), np.array(r, float)

    def f(p):
        q = (p - c) / r
        k0 = np.linalg.norm(q, axis=1)
        k1 = np.linalg.norm(q / r, axis=1)
        return k0 * (k0 - 1.0) / np.maximum(k1, 1e-6)
    return f


def box(c, b, r=0.0):
    c, b = np.array(c, float), np.array(b, float) - r

    def f(p):
        q = np.abs(p - c) - b
        return np.linalg.norm(np.maximum(q, 0), axis=1) + np.minimum(q.max(axis=1), 0) - r
    return f


def capsule(a, b, r):
    a, b = np.array(a, float), np.array(b, float)
    ba = b - a
    bb = ba @ ba

    def f(p):
        pa = p - a
        h = np.clip(pa @ ba / bb, 0, 1)
        return np.linalg.norm(pa - h[:, None] * ba, axis=1) - r
    return f


def cone_cap(a, b, ra, rb):
    """Rounded cone between points a (radius ra) and b (radius rb), approximated as a tapered capsule."""
    a, b = np.array(a, float), np.array(b, float)
    ba = b - a
    bb = ba @ ba

    def f(p):
        pa = p - a
        h = np.clip(pa @ ba / bb, 0, 1)
        return np.linalg.norm(pa - h[:, None] * ba, axis=1) - (ra + (rb - ra) * h)
    return f


def torus_x(c, R, r):
    """A wheel: torus whose axle runs along x."""
    c = np.array(c, float)

    def f(p):
        q = p - c
        d = np.sqrt(q[:, 1] ** 2 + q[:, 2] ** 2) - R
        return np.sqrt(d ** 2 + q[:, 0] ** 2) - r
    return f


def cyl_x(c, R, h):
    """Disc / hub along x."""
    c = np.array(c, float)

    def f(p):
        q = p - c
        d = np.stack([np.sqrt(q[:, 1] ** 2 + q[:, 2] ** 2) - R, np.abs(q[:, 0]) - h], axis=1)
        return np.minimum(d.max(axis=1), 0) + np.linalg.norm(np.maximum(d, 0), axis=1)
    return f


def cyl_y(c, R, h):
    c = np.array(c, float)

    def f(p):
        q = p - c
        d = np.stack([np.sqrt(q[:, 0] ** 2 + q[:, 2] ** 2) - R, np.abs(q[:, 1]) - h], axis=1)
        return np.minimum(d.max(axis=1), 0) + np.linalg.norm(np.maximum(d, 0), axis=1)
    return f


def smin(a, b, k):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
    return b + (a - b) * h - k * h * (1 - h)


def blend(k, *fs):
    def f(p):
        d = fs[0](p)
        for g in fs[1:]:
            d = smin(d, g(p), k)
        return d
    return f


def cut(f, g):
    """f minus g."""
    return lambda p: np.maximum(f(p), -g(p))


def twist_y(f, rate):
    def g(p):
        a = p[:, 1] * rate
        c, s = np.cos(a), np.sin(a)
        q = p.copy()
        q[:, 0] = c * p[:, 0] - s * p[:, 2]
        q[:, 2] = s * p[:, 0] + c * p[:, 2]
        return f(q)
    return g


# ---------- scene: list of (sdf, material) ----------
class Mat:
    def __init__(self, color, spec=0.3, shine=24, rim=0.35, glow=0.0, metal=False):
        self.color = np.array(color, float) / 255.0
        self.spec, self.shine, self.rim, self.glow, self.metal = spec, shine, rim, glow, metal


def render(parts, size=(320, 260), yaw_deg=0.0, pitch_deg=18.0, zoom=1.0, center=(0, 0.55, 0), ss=2,
           outline=(18, 14, 22), sky=(0.55, 0.62, 0.8), ground=(0.35, 0.3, 0.25), shadow=True):
    """Orthographic camera behind the object (looking toward +z), rotated by yaw/pitch. Returns an RGBA image."""
    W, H = size[0] * ss, size[1] * ss
    yaw, pitch = np.radians(yaw_deg), np.radians(pitch_deg)
    # camera basis
    fwd = np.array([np.sin(yaw) * np.cos(pitch), -np.sin(pitch), np.cos(yaw) * np.cos(pitch)])
    right = np.array([np.cos(yaw), 0, -np.sin(yaw)])
    up = np.cross(fwd, right)
    up /= np.linalg.norm(up)
    scale = 2.6 / zoom / W
    xs = (np.arange(W) - W / 2) * scale
    ys = (H / 2 - np.arange(H)) * scale
    gx, gy = np.meshgrid(xs, ys)
    origin = np.array(center, float) - fwd * 6
    ro = origin + gx.reshape(-1, 1) * right + gy.reshape(-1, 1) * up
    rd = np.broadcast_to(fwd, ro.shape)

    def scene(p):
        ds = np.stack([s(p) for s, _ in parts], axis=1)
        return ds.min(axis=1), ds.argmin(axis=1)

    n = ro.shape[0]
    t = np.zeros(n)
    hit = np.zeros(n, bool)
    alive = np.ones(n, bool)
    for _ in range(110):
        idx = np.nonzero(alive)[0]
        if idx.size == 0:
            break
        p = ro[idx] + rd[idx] * t[idx, None]
        d, _ = scene(p)
        t[idx] += d * 0.9
        done = d < 1e-3
        hit[idx[done]] = True
        gone = t[idx] > 14
        alive[idx[done | gone]] = False
    img = np.zeros((n, 4))
    hi = np.nonzero(hit)[0]
    if hi.size:
        p = ro[hi] + rd[hi] * t[hi, None]
        _, mid = scene(p)
        e = 1.5e-3
        nrm = np.zeros_like(p)
        for k in range(3):
            o = np.zeros(3)
            o[k] = e
            nrm[:, k] = scene(p + o)[0] - scene(p - o)[0]
        nrm /= np.linalg.norm(nrm, axis=1, keepdims=True) + 1e-9
        key = np.array([-0.55, 0.75, -0.45])
        key /= np.linalg.norm(key)
        diff = np.clip(nrm @ key, 0, 1)
        # soft shadow toward the key light
        sh = np.ones(len(p))
        if shadow:
            st = np.full(len(p), 0.03)
            for _ in range(24):
                d, _ = scene(p + key * st[:, None])
                sh = np.minimum(sh, np.clip(10 * d / st, 0, 1))
                st += np.clip(d, 0.02, 0.2)
            sh = np.clip(sh, 0.25, 1)
        # ambient occlusion
        ao = np.ones(len(p))
        for i in range(1, 6):
            hstep = 0.035 * i
            d, _ = scene(p + nrm * hstep)
            ao -= (hstep - d) * (0.9 / i)
        ao = np.clip(ao, 0.3, 1)
        view = -fwd
        half = key + view
        half /= np.linalg.norm(half)
        skyamt = np.clip(0.5 + 0.5 * nrm[:, 1], 0, 1)
        rimv = np.clip(1 - np.abs(nrm @ view), 0, 1) ** 3
        col = np.zeros((len(p), 3))
        for i, (_, m) in enumerate(parts):
            sel = mid == i
            if not sel.any():
                continue
            base = m.color
            amb = (np.array(sky) * skyamt[sel, None] + np.array(ground) * (1 - skyamt[sel, None])) * 0.55
            lit = base * (amb + 0.95 * diff[sel, None] * sh[sel, None]) * ao[sel, None]
            s = m.spec * np.clip(nrm[sel] @ half, 0, 1) ** m.shine * sh[sel]
            if m.metal:
                refl = np.clip(nrm[sel, 1], -1, 1)
                env = np.where(refl[:, None] > 0, np.array([0.75, 0.8, 0.95]), np.array([0.3, 0.27, 0.25]))
                lit = lit * 0.55 + base * env * 0.6 * ao[sel, None]
            lit = lit + s[:, None] + m.rim * rimv[sel, None] * np.array([0.9, 0.95, 1.0])
            lit = lit + base * m.glow
            col[sel] = lit
        img[hi, :3] = np.clip(col, 0, 1)
        img[hi, 3] = 1
    rgba = (img.reshape(H, W, 4) * 255).astype(np.uint8)
    im = Image.fromarray(rgba, "RGBA")
    # outline + contact shadow, then downsample
    a = im.split()[3]
    grown = a.filter(ImageFilter.MaxFilter(2 * ss + 1))
    line = Image.new("RGBA", im.size, outline + (0,))
    line.putalpha(grown)
    out = Image.alpha_composite(line, im)
    return out.resize(size, Image.LANCZOS)


def crop(im, pad=4):
    bb = im.split()[3].getbbox()
    if not bb:
        return im
    x0, y0, x1, y1 = bb
    return im.crop((max(0, x0 - pad), max(0, y0 - pad), min(im.width, x1 + pad), min(im.height, y1 + pad)))
