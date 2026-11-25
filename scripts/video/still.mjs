// Render a few stills to check a world: node still.mjs <world> <outdir> [seg:frame ...]
import { createRequire } from 'node:module';
const { chromium } = createRequire(import.meta.url)('playwright');
import { writeFileSync, mkdirSync } from 'node:fs';
import { serve } from './serve.mjs';
const [world = 'jungle', out = 'stills', ...shots] = process.argv.slice(2);
mkdirSync(out, { recursive: true });
const srv = await serve();
const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
page.on('console', (m) => console.log('page:', m.text()));
page.on('pageerror', (e) => console.log('pageerror:', e.message));
await page.goto(`http://127.0.0.1:${srv.address().port}/`);
await page.waitForFunction(() => window.READY);
let t = Date.now();
const info = await page.evaluate(([w]) => API.setup(w, 1280, 720), [world]);
console.log('setup', Date.now() - t, 'ms', JSON.stringify(info));
for (const s of shots.length ? shots : ['shared:0', 'shared:100', 'left:150', 'right:200']) {
  const [seg, f, cont] = s.split(':');
  t = Date.now();
  const url = await page.evaluate(([a, b, c]) => API.frame(a, c || 'left', Number(b)), [seg, f, cont]);
  writeFileSync(`${out}/${world}_${seg}_${f}.jpg`, Buffer.from(url.split(',')[1], 'base64'));
  console.log(s, Date.now() - t, 'ms');
}
await browser.close(); srv.close();
