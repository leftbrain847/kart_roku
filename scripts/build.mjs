#!/usr/bin/env node
// Build the Roku sideload zip: dist/kart_roku.zip with manifest, source/ and images/ at the zip root.
//   node scripts/build.mjs
import { readFileSync, readdirSync, statSync, mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { makeZip } from './zip.mjs';

export const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
export const CONFIG = JSON.parse(readFileSync(join(ROOT, 'scripts', 'package.config.json'), 'utf8'));

function walk(abs) {
  if (statSync(abs).isFile()) return [abs];
  return readdirSync(abs).sort().flatMap((n) => walk(join(abs, n)));
}

export function collect(root = ROOT, cfg = CONFIG) {
  return cfg.include.flatMap((p) => walk(join(root, p))).map((abs) => ({
    name: relative(root, abs).split(sep).join('/'),
    data: readFileSync(abs),
  }));
}

export function build(root = ROOT, cfg = CONFIG) {
  const zip = makeZip(collect(root, cfg));
  mkdirSync(join(root, cfg.outDir), { recursive: true });
  const out = join(root, cfg.outDir, cfg.zipName);
  writeFileSync(out, zip);
  return out;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  const out = build();
  console.log(`built ${relative(ROOT, out)} (${statSync(out).size} bytes)`);
}
