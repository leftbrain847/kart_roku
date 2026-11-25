// Track layout shared by every world: one shared straight, then a Y fork into two 5-lane loops that both
// come back to the start of the straight ("theta" shape). Units are metres. Each segment is a list of
// pieces { len, turn (radians, + = left), rise (metres, eased) }.
export const LANE_W = 3.6;
export const LANES = 5;
export const ROAD_HALF = LANE_W * LANES / 2 + 1.2;   // road half-width incl. shoulder

export const CAM = {
  back: 12,        // camera is this far behind the kart line (the line through the karts' mirrors)
  height: 3.8,     // camera height above the road
  lookAhead: 22,   // looks at the road this far ahead of the camera...
  lookHeight: 0.8, // ...this high above it
  fov: 55,         // vertical field of view (degrees)
};

export const SPEED = 32;   // camera speed, m/s (steady; karts surge ahead or drop back from it)
export const FPS = 30;

const R = 36, STRAIGHT = 128;
export function layout(world) {
  const dip = world.leftRise ?? -6, climb = world.rightRise ?? 6;
  const half = STRAIGHT / 2, arc = Math.PI * R;
  return {
    shared: [{ len: STRAIGHT }],
    left: [{ len: arc, turn: Math.PI }, { len: half, rise: dip }, { len: half, rise: -dip }, { len: arc, turn: Math.PI }],
    right: [{ len: arc, turn: -Math.PI }, { len: half, rise: climb }, { len: half, rise: -climb }, { len: arc, turn: -Math.PI }],
  };
}

const STEP = 0.25;
// Integrates pieces into samples every STEP metres: { x, y, z, h (heading), len }.
export function buildPath(pieces, start = { x: 0, y: 0, z: 0, h: 0 }) {
  const pts = [];
  let { x, y, z, h } = start;
  pts.push({ x, y, z, h });
  for (const p of pieces) {
    const n = Math.max(1, Math.round(p.len / STEP));
    const ds = p.len / n, dh = (p.turn ?? 0) / n, y0 = y;
    for (let i = 1; i <= n; i++) {
      const hm = h + dh / 2;                 // midpoint heading: exact on arcs up to rounding
      x += Math.sin(hm) * ds; z += Math.cos(hm) * ds; h += dh;
      const t = i / n;
      y = y0 + (p.rise ?? 0) * (t * t * (3 - 2 * t));
      pts.push({ x, y, z, h });
    }
  }
  return { pts, len: (pts.length - 1) * STEP };
}

// Several paths joined end to end (for looking ahead past a segment's end).
export function chain(...paths) {
  const pts = [];
  for (const p of paths) pts.push(...(pts.length ? p.pts.slice(1) : p.pts));
  return { pts, len: (pts.length - 1) * STEP };
}

export function at(path, s) {
  const f = Math.min(Math.max(s / STEP, 0), path.pts.length - 1.0001);
  const i = Math.floor(f), t = f - i, a = path.pts[i], b = path.pts[i + 1];
  return { x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t, z: a.z + (b.z - a.z) * t, h: a.h + (b.h - a.h) * t };
}
// Right-hand vector for heading h (forward = (sin h, 0, cos h)).
export const rightOf = (h) => ({ x: -Math.cos(h), z: Math.sin(h) });

export function worldPaths(world) {
  const L = layout(world);
  const shared = buildPath(L.shared);
  const end = shared.pts[shared.pts.length - 1];
  return {
    shared,
    left: buildPath(L.left, end),
    right: buildPath(L.right, end),
  };
}

// Distance from (x, z) to the nearest road sample of any path, and that sample's height. Grid-accelerated.
export function makeRoadField(paths, cell = 8) {
  const grid = new Map();
  for (const p of paths) for (let i = 0; i < p.pts.length; i += 4) {
    const q = p.pts[i];
    const k = `${Math.floor(q.x / cell)},${Math.floor(q.z / cell)}`;
    if (!grid.has(k)) grid.set(k, []);
    grid.get(k).push(q);
  }
  return (x, z, reach = 6) => {
    let best = Infinity, by = 0;
    const cx = Math.floor(x / cell), cz = Math.floor(z / cell);
    for (let r = 0; r <= reach; r++) {
      for (let i = -r; i <= r; i++) for (let j = -r; j <= r; j++) {
        if (Math.max(Math.abs(i), Math.abs(j)) !== r) continue;
        const list = grid.get(`${cx + i},${cz + j}`);
        if (!list) continue;
        for (const q of list) {
          const d = Math.hypot(q.x - x, q.z - z);
          if (d < best) { best = d; by = q.y; }
        }
      }
      if (best < (r - 1) * cell) break;
    }
    return { d: best, y: by };
  };
}

// Deterministic random numbers.
export function rng(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s + 0x6d2b79f5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// Smooth value noise in 2D, deterministic.
export function noise2(seed) {
  const r = rng(seed), P = new Float32Array(256 * 256);
  for (let i = 0; i < P.length; i++) P[i] = r();
  const v = (x, y) => P[((y & 255) << 8) | (x & 255)];
  return (x, y) => {
    const xi = Math.floor(x), yi = Math.floor(y), xf = x - xi, yf = y - yi;
    const u = xf * xf * (3 - 2 * xf), w = yf * yf * (3 - 2 * yf);
    const a = v(xi, yi), b = v(xi + 1, yi), c = v(xi, yi + 1), d = v(xi + 1, yi + 1);
    return a + (b - a) * u + (c - a) * w + (a - b - c + d) * u * w;
  };
}
export function fbm(n, x, y, oct = 5) {
  let s = 0, a = 0.5, f = 1;
  for (let i = 0; i < oct; i++) { s += a * n(x * f, y * f); f *= 2.03; a *= 0.5; }
  return s;
}
