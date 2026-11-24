#!/usr/bin/env node
// Security gate for the sideload zip. The release workflow publishes the zip only if this passes.
// Checks: only allowed files, manifest at the root with required keys, no network or store APIs in code,
// no secret-looking strings anywhere, size limit.
//   node scripts/check-package.mjs [dist/kart_roku.zip]
import { readFileSync } from 'node:fs';
import { extname, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { readZip } from './zip.mjs';
import { ROOT, CONFIG } from './build.mjs';

function regex(src) {
  // Allow a leading (?i) for case-insensitive patterns in the JSON config.
  return src.startsWith('(?i)') ? new RegExp(src.slice(4), 'i') : new RegExp(src);
}

export function checkZip(buf, cfg = CONFIG) {
  const problems = [];
  if (buf.length > cfg.maxBytes) problems.push(`zip is ${buf.length} bytes, over ${cfg.maxBytes}`);
  const entries = readZip(buf);
  const names = entries.map((e) => e.name);
  if (!names.includes('manifest')) problems.push('manifest missing from zip root');
  if (!names.some((n) => /^source\/main\.brs$/.test(n))) problems.push('source/main.brs missing');
  const secrets = cfg.secretPatterns.map(regex);
  for (const { name, data } of entries) {
    if (name.includes('..') || name.startsWith('/')) problems.push(`${name}: unsafe path`);
    const top = name.split('/')[0];
    if (!cfg.include.includes(top)) problems.push(`${name}: not in an allowed folder`);
    if (name !== 'manifest' && !cfg.allowedExtensions.includes(extname(name))) problems.push(`${name}: file type not allowed`);
    if (name.split('/').some((part) => part.startsWith('.'))) problems.push(`${name}: hidden file`);
    const text = data.toString('latin1');
    for (const re of secrets) if (re.test(text)) problems.push(`${name}: looks like a secret (${re.source})`);
    if (name === 'manifest' || name.endsWith('.brs')) {
      for (const word of cfg.forbiddenCode) if (text.includes(word)) problems.push(`${name}: uses ${word} (the game makes no network calls)`);
    }
    if (name === 'manifest') {
      const keys = new Set(text.split(/\r?\n/).map((l) => l.split('=')[0].trim()).filter(Boolean));
      for (const k of cfg.manifestRequired) if (!keys.has(k)) problems.push(`manifest: missing ${k}`);
    }
  }
  return { problems, files: names };
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  const path = process.argv[2] ?? join(ROOT, CONFIG.outDir, CONFIG.zipName);
  const { problems, files } = checkZip(readFileSync(path));
  if (problems.length) {
    console.error(`package check FAILED for ${path}:\n- ${problems.join('\n- ')}`);
    process.exit(1);
  }
  console.log(`package check passed: ${files.length} files, no network APIs, no secrets`);
}
