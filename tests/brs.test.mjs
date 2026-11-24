// End to end: lint the BrightScript, run the game-rule unit tests and a scripted race in the brs-cli
// simulator, build the sideload zip and pass it through the security gate.
import { test } from 'node:test';
import assert from 'node:assert';
import { execFileSync } from 'node:child_process';
import { readFileSync, mkdtempSync, writeFileSync, mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { ROOT, CONFIG, build, collect } from '../scripts/build.mjs';
import { checkZip } from '../scripts/check-package.mjs';
import { makeZip, readZip } from '../scripts/zip.mjs';

const bin = (name) => join(ROOT, 'node_modules', '.bin', name);
const run = (cmd, args) => execFileSync(cmd, args, { cwd: ROOT, encoding: 'utf8', timeout: 240_000, stdio: ['ignore', 'pipe', 'pipe'] });

test('BrightScript passes the brighterscript compiler checks', () => {
  const out = run(bin('bsc'), ['--project', 'bsconfig.json', '--stagingDir', join(mkdtempSync(join(tmpdir(), 'bsc-')), 'stage')]);
  assert.doesNotMatch(out, /error BS\d+/, out);
});

test('game rules: unit tests in the simulator', () => {
  const out = run(bin('brs-cli'), ['-n', 'tests/logic_test.brs', 'source/config.brs', 'source/track.brs', 'source/game.brs']);
  const m = out.match(/RESULT pass=(\d+) fail=(\d+)/);
  assert.ok(m, out);
  assert.equal(m[2], '0', out);
  assert.ok(Number(m[1]) >= 50, out);
});

test('the built zip runs a scripted race end to end', () => {
  const zip = build();
  const out = run(bin('brs-cli'), ['-n', '-k', 'autotest=1', zip]);
  assert.match(out, /AUTOTEST OK/, out);
  const line = out.match(/AUTOTEST frames=(\d+) dist=(\d+) items=(\d+) boosts=\d+ routes=(\S*) traffic=(\w+)/);
  assert.ok(line, out);
  assert.equal(line[1], '600');
  assert.ok(Number(line[2]) > 500, 'kart auto-accelerated down the track');
  assert.ok(Number(line[3]) >= 1, 'picked up an item block');
  assert.equal(line[4], 'CANYON', 'left lanes took the left route at the first fork');
  assert.equal(line[5], 'off', 'pause menu toggled traffic off');
});

test('the zip passes the security gate', () => {
  const zip = readFileSync(build());
  const { problems, files } = checkZip(zip);
  assert.deepEqual(problems, []);
  assert.ok(files.includes('manifest') && files.includes('source/main.brs'));
  assert.ok(files.every((f) => !f.startsWith('tests/') && !f.startsWith('node_modules/')));
});

test('the security gate rejects secrets, network code and stray files', () => {
  const good = collect();
  const bad = (extra) => checkZip(makeZip([...good, ...extra])).problems.join('\n');
  assert.match(bad([{ name: 'source/net.brs', data: Buffer.from('x = CreateObject("roUrlTransfer")') }]), /roUrlTransfer/);
  assert.match(bad([{ name: 'source/k.brs', data: Buffer.from('k = "ghp_' + 'a'.repeat(36) + '"') }]), /secret/);
  assert.match(bad([{ name: 'source/k.brs', data: Buffer.from('apiKey = "abcdefgh12345"') }]), /secret/);
  assert.match(bad([{ name: '.env', data: Buffer.from('X=1') }]), /not in an allowed folder/);
  assert.match(bad([{ name: 'source/run.sh', data: Buffer.from('echo') }]), /file type not allowed/);
  assert.match(checkZip(makeZip(good.filter((e) => e.name !== 'manifest'))).problems.join('\n'), /manifest missing/);
});

test('zip round-trips and builds are byte-identical', () => {
  const entries = [{ name: 'a.txt', data: Buffer.from('hello') }, { name: 'd/b.bin', data: Buffer.alloc(1000, 7) }];
  const back = readZip(makeZip(entries));
  assert.deepEqual(back.map((e) => [e.name, e.data.toString('hex')]), entries.map((e) => [e.name, e.data.toString('hex')]));
  assert.ok(readFileSync(build()).equals(readFileSync(build())));
});

test('manifest version and package config agree', () => {
  const manifest = readFileSync(join(ROOT, 'manifest'), 'utf8');
  for (const k of CONFIG.manifestRequired) assert.match(manifest, new RegExp(`^${k}=\\S`, 'm'));
  assert.equal(CONFIG.zipName, 'kart_roku.zip');
});
