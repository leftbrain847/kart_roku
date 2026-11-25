// The video-track POC (video_poc/): lint, logic unit tests, package + security gate, and the media contract
// (every video the app streams is in media/, and the lane tables match the videos).
import { test } from 'node:test';
import assert from 'node:assert';
import { execFileSync } from 'node:child_process';
import { readFileSync, existsSync, statSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { ROOT, loadConfig, build, collect } from '../scripts/build.mjs';
import { checkZip } from '../scripts/check-package.mjs';
import { makeZip } from '../scripts/zip.mjs';

const CFG = loadConfig('scripts/video_poc.config.json');
const bin = (name) => join(ROOT, 'node_modules', '.bin', name);
const run = (cmd, args) => execFileSync(cmd, args, { cwd: ROOT, encoding: 'utf8', timeout: 240_000, stdio: ['ignore', 'pipe', 'pipe'] });
const logic = readFileSync(join(ROOT, 'video_poc/source/logic.brs'), 'utf8');
const baseUrl = logic.match(/baseUrl: "([^"]+)"/)[1];
const worlds = [...logic.matchAll(/\{ id: "(\w+)", title:/g)].map((m) => m[1]);
const SEGS = ['shared', 'left', 'right'];

test('POC BrightScript passes the brighterscript compiler checks', () => {
  const out = run(bin('bsc'), ['--project', 'video_poc/bsconfig.json', '--stagingDir', join(mkdtempSync(join(tmpdir(), 'bsc-')), 'stage')]);
  assert.doesNotMatch(out, /error BS\d+/, out);
});

test('POC logic: unit tests in the simulator', () => {
  const out = run(bin('brs-cli'), ['-n', 'tests/video_poc_test.brs', 'video_poc/source/logic.brs']);
  const m = out.match(/RESULT pass=(\d+) fail=(\d+)/);
  assert.ok(m, out);
  assert.equal(m[2], '0', out);
  assert.ok(Number(m[1]) >= 35, out);
});

test('POC zip builds and passes its security gate', () => {
  const zip = readFileSync(build(ROOT, CFG));
  const { problems, files } = checkZip(zip, CFG);
  assert.deepEqual(problems, []);
  for (const f of ['manifest', 'source/main.brs', 'components/RaceScene.xml', 'images/karts/karts.json', ...worlds.map((w) => `data/${w}.json`)]) assert.ok(files.includes(f), f);
  assert.ok(files.filter((f) => f.startsWith('images/karts/kart_')).length >= 40, 'kart sprites at many angles');
});

test('POC gate: only the allowlisted media host, no HTTP client, no plain http', () => {
  const good = collect(ROOT, CFG);
  const bad = (extra) => checkZip(makeZip([...good, ...extra]), CFG).problems.join('\n');
  assert.match(bad([{ name: 'source/x.brs', data: Buffer.from('u = "https://evil.example.com/a.mp4"') }]), /not on the allowlist/);
  assert.match(bad([{ name: 'components/x.xml', data: Buffer.from('<x uri="https://evil.example.com/a"/>') }]), /not on the allowlist/);
  assert.match(bad([{ name: 'source/x.brs', data: Buffer.from('x = CreateObject("roUrlTransfer")') }]), /roUrlTransfer/);
  assert.match(bad([{ name: 'source/x.brs', data: Buffer.from('u = "http://raw.githubusercontent.com/x"') }]), /http:\/\//);
  assert.match(bad([{ name: 'source/k.brs', data: Buffer.from('k = "ghp_' + 'a'.repeat(36) + '"') }]), /secret/);
  const P = 'https://raw.githubusercontent.com/leftbrain847/kart_roku/main/media/';
  for (const sneaky of [P + '../../../../otheruser/repo/main/x.mp4', P + '%2e%2e/%2e%2e/x.mp4', 'HTTPS://evil.example.com/a.mp4',
    'HTTP://evil.example.com/a', 'rtmp://evil.example.com/live', P.replace('https://', 'https://user@'), P + 'a\\..\\b']) {
    assert.ok(bad([{ name: 'source/x.brs', data: Buffer.from(`u = "${sneaky}"`) }]).length > 0, `rejects ${sneaky}`);
  }
  assert.match(bad([{ name: 'source/x.brs', data: Buffer.from('u = "https:" + "//evil.example.com"') }]), /split URL scheme/);
  assert.match(bad([{ name: 'data/x.json', data: Buffer.from('{"u":"https://evil.example.com/a.mp4"}') }]), /not on the allowlist/);
  assert.match(bad([{ name: 'source/x.brs', data: Buffer.from('x = CreateObject("rourltransfer")') }]), /roUrlTransfer/);
  assert.ok(CFG.allowedUrls.some((p) => baseUrl.startsWith(p)), 'baseUrl is on the allowlist');
});

test('every video the POC streams is in media/, and lane tables match the videos', () => {
  assert.deepEqual(worlds, ['jungle', 'library']);
  const prefix = 'https://raw.githubusercontent.com/leftbrain847/kart_roku/main/';
  assert.ok(baseUrl.startsWith(prefix), 'media served from this repo (change this test when moving to R2)');
  const dir = baseUrl.slice(prefix.length);
  for (const w of worlds) {
    const lanes = JSON.parse(readFileSync(join(ROOT, 'video_poc/data', `${w}.json`), 'utf8'));
    let total = 0;
    for (const seg of [...SEGS, 'all']) {
      const p = join(ROOT, dir, w, `${seg}.mp4`);
      assert.ok(existsSync(p), p);
      const size = statSync(p).size;
      assert.ok(size < 25e6, `${p} is ${size} bytes; keep repo media small (R2 for big files)`);
      if (seg !== 'all') {
        total += size;
        assert.equal(lanes.segs[seg].bytes, size, `${w}/${seg}.mp4 changed since its lane table was made`);
      }
    }
    assert.equal(statSync(join(ROOT, dir, w, 'all.mp4')).size > total * 0.95, true, 'all.mp4 is the three segments back to back');
    for (const [key, seg] of [['shared_left', 'shared'], ['shared_right', 'shared'], ['left', 'left'], ['right', 'right']]) {
      const rows = lanes.tables[key];
      assert.ok(Math.abs(rows.length - lanes.segs[seg].dur * lanes.rate) <= 1, `${w} ${key}: one row per 1/${lanes.rate} s`);
      for (const row of rows) assert.equal(row.length, lanes.depths.length * 4);
    }
    // On the straight, the kart line is low and central and all five lanes fit on screen.
    const row = lanes.tables.shared_left[5], at0 = lanes.depths.indexOf(0) * 4;
    const [x, y, ppm] = row.slice(at0, at0 + 3);
    assert.ok(x > 560 && x < 720 && y > 380 && y < 640, `${w}: kart line at ${x},${y}`);
    assert.ok(x - ppm * 2 * lanes.laneW > 0 && x + ppm * 2 * lanes.laneW < 1280, `${w}: five lanes fit`);
    const far = lanes.depths.length * 4 - 4;
    assert.ok(row[far + 1] < y && row[far + 2] < ppm, `${w}: further ahead is higher and smaller`);
  }
});
