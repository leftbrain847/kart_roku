#!/usr/bin/env node
// Offline renderer for the video-track POC.
//   node render.mjs world <jungle|library> <outDir> [--w 1280 --h 720 --crf 24 --frames N]
//       -> shared.mp4, left.mp4, right.mp4, all.mp4 (shared|left|right back to back) and lanes.json
//   node render.mjs karts <outDir>   -> raw kart sprite PNGs + karts.json (then run sprites.py to crop/compress)
import { createRequire } from 'node:module';
import { spawn, execFileSync } from 'node:child_process';
import { writeFileSync, mkdirSync, statSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { serve } from './serve.mjs';
const { chromium } = createRequire(import.meta.url)('playwright');

const [mode, a1, a2, ...rest] = process.argv.slice(2);
const opt = (k, d) => { const i = rest.indexOf(`--${k}`); return i >= 0 ? Number(rest[i + 1]) : d; };
const W = opt('w', 1280), H = opt('h', 720), CRF = opt('crf', 24), MAXF = opt('frames', Infinity);
export const DEPTHS = [-6, -4, -2, 0, 2, 4, 7, 10, 14, 19, 25];
const RATE = 15;

const srv = await serve();
const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await browser.newPage({ viewport: { width: W, height: H } });
page.on('pageerror', (e) => console.log('pageerror:', e.message));
await page.goto(`http://127.0.0.1:${srv.address().port}/`);
await page.waitForFunction(() => window.READY);

function encoder(file, fps) {
  const ff = spawn('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', String(fps), '-i', '-',
    '-c:v', 'libx264', '-preset', 'slow', '-crf', String(CRF), '-pix_fmt', 'yuv420p', '-profile:v', 'high', '-level', '4.1',
    '-g', '15', '-keyint_min', '15', '-sc_threshold', '0', '-movflags', '+faststart', '-an', file], { stdio: ['pipe', 'inherit', 'inherit'] });
  const done = new Promise((ok, bad) => ff.on('close', (c) => (c ? bad(new Error(`ffmpeg ${c}`)) : ok())));
  return { write: (buf) => new Promise((ok) => (ff.stdin.write(buf) ? ok() : ff.stdin.once('drain', ok))), end: () => { ff.stdin.end(); return done; } };
}

if (mode === 'world') {
  const out = resolve(a2); mkdirSync(out, { recursive: true });
  const info = await page.evaluate(([n, w, h]) => API.setup(n, w, h), [a1, W, H]);
  console.log(a1, JSON.stringify(info));
  const segs = {};
  for (const seg of ['shared', 'left', 'right']) {
    const n = Math.min(info[seg], MAXF), enc = encoder(join(out, `${seg}.mp4`), 30);
    const t0 = Date.now();
    for (let i = 0; i < n; i++) {
      const url = await page.evaluate(([s, k]) => API.frame(s, 'left', k), [seg, i]);
      await enc.write(Buffer.from(url.slice(url.indexOf(',') + 1), 'base64'));
      if (i % 30 === 0) console.log(`${a1} ${seg} ${i}/${n} ${((Date.now() - t0) / (i + 1)).toFixed(0)} ms/frame`);
    }
    await enc.end();
    segs[seg] = { frames: n, dur: n / 30, bytes: statSync(join(out, `${seg}.mp4`)).size };
  }
  writeFileSync(join(out, 'list.txt'), ['shared', 'left', 'right'].map((s) => `file '${s}.mp4'`).join('\n') + '\n');
  execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', join(out, 'list.txt'), '-c', 'copy', '-movflags', '+faststart', join(out, 'all.mp4')]);
  await writeTables(out, a1, segs);
  console.log('done', JSON.stringify(segs));
} else if (mode === 'tables') {
  const out = resolve(a2);
  const info = await page.evaluate(([n, w, h]) => API.setup(n, w, h), [a1, W, H]);
  const segs = Object.fromEntries(['shared', 'left', 'right'].map((s) => [s, { frames: info[s], dur: info[s] / 30, bytes: statSync(join(out, `${s}.mp4`)).size }]));
  await writeTables(out, a1, segs);
  console.log('tables done');
}
async function writeTables(out, name, segs) {
  const tables = {};
  for (const [k, seg, cont] of [['shared_left', 'shared', 'left'], ['shared_right', 'shared', 'right'], ['left', 'left', 'left'], ['right', 'right', 'left']])
    tables[k] = await page.evaluate(([s, c, d, r]) => API.table(s, c, d, r), [seg, cont, DEPTHS, RATE]);
  const lanes = { world: name, w: W, h: H, fps: 30, rate: RATE, depths: DEPTHS, laneW: 3.6, segs, tables };
  writeFileSync(join(out, 'lanes.json'), JSON.stringify(lanes));
}
if (mode === 'karts') {
  const out = resolve(a1); mkdirSync(out, { recursive: true });
  const meta = await page.evaluate(() => API.setupKarts(400, 300));
  const angles = Array.from({ length: 24 }, (_, i) => i * 15);
  for (const v of ['red', 'teal', 'gold', 'violet']) for (const a of angles) {
    const url = await page.evaluate(([vv, aa]) => API.kart(vv, aa), [v, a]);
    writeFileSync(join(out, `${v}_${a}.png`), Buffer.from(url.slice(url.indexOf(',') + 1), 'base64'));
  }
  writeFileSync(join(out, 'karts.json'), JSON.stringify({ ...meta, w: 400, h: 300, angles, variants: ['red', 'teal', 'gold', 'violet'] }));
  console.log('karts', JSON.stringify(meta));
}
await browser.close(); srv.close();

