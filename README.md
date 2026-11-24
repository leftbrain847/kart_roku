# Kart for Roku

A fake-3D lane racer for Roku TVs, written in BrightScript: five lanes, tap Left/Right to change lane, auto-accelerate, route forks, item blocks (shell, banana, boost), light traffic, lap timer and best lap. First build of the Kart game.

**Download:** [kart_roku.zip](https://github.com/leftbrain847/kart_roku/releases/latest/download/kart_roku.zip) (latest release; sideload it, see below)

## Controls
| Remote | Action |
|---|---|
| Left / Right | change lane (one tap = one lane) |
| Up | throw shell or banana forward |
| Down | drop it behind |
| OK | use a boost |
| Play/Pause | pause menu: resume, traffic on/off, restart, exit |
| Back | exit |

Your lane when you reach a fork picks the route (e.g. lanes 1–2 left, 3–5 right); you can only steer within that route until the routes rejoin.

## Run (on a Roku)
```
npm ci
npm run build          # -> dist/kart_roku.zip
npm run check          # security gate: allowed files only, no network APIs, no secrets
```
Then sideload: on the remote press Home ×3, Up ×2, Right, Left, Right, Left, Right to enable developer mode; open the Roku's IP in a browser on the same Wi-Fi, sign in as `rokudev`, upload `dist/kart_roku.zip`, Install.

Run it in the simulator instead: `npx brs-cli -n dist/kart_roku.zip` (add `-k autotest=1` for the scripted 20-second race).

## Test
```
npm test
```
Runs the brighterscript compiler checks, 50+ game-rule unit tests and a 600-frame scripted race in the `brs-cli` simulator, builds the zip and runs it through the security gate. CI runs the same.

## Tune it
Every tunable is in `GameConfig()` in [`source/config.brs`](source/config.brs): lane count, speeds and boost, track length, fork layout (`forks`), `forkSpeedMode` (`"carry"` default, or `"perRoute"` to use each route's `speedMult`), item block spacing and odds, traffic density and speeds, camera and render band sizes, colors. `ValidateConfig` reports bad layouts at startup.

## How it stays fast on a Streaming Stick HD (3840R)
- `roScreen` + Draw2D, double-buffered at 1280×720; no SceneGraph nodes in the frame loop.
- The road is ~115 horizontal bands of `DrawRect`; each band's depth and scale is computed once at startup.
- Sprites are drawn from rectangles into bitmaps once at startup, at 30 pre-scaled sizes; a frame only copies bitmaps (`DrawObject`), never scales them, and does no per-pixel work.
- System fonts only (`roFontRegistry.GetDefaultFont`).

Note: Roku requires SceneGraph for apps published to the Channel Store; `roScreen` is a legacy API. That's fine for sideloading, which is how this build ships.

## Layout
```
manifest, images/          Roku app metadata and icons
source/config.brs          all tunables
source/track.brs           forks, lanes, road geometry (pure)
source/game.brs            rules: input, speed, items, traffic, laps (pure)
source/sprites.brs         pre-scaled sprite bitmaps
source/render.brs          Draw2D renderer and HUD
source/main.brs            screen, frame loop, saved best lap
scripts/                   build, zip, security gate, sprint snapshot
tests/                     unit tests (BrightScript) and end-to-end tests (node:test)
sprint/kart.html           the day page for the sprint site
```

## Deployed
- Release: https://github.com/leftbrain847/kart_roku/releases/latest (built by `.github/workflows/release.yml` after tests and the security gate pass; bump `build_version` in `manifest` to publish a new one)
- Day snapshot: `2026-11-24 - Kart Roku` (frozen; never edited)

## Ship a sprint day
```
node scripts/snapshot.mjs sprint/kart.html --public
```
Commit `snapshots/` to `main` (via PR). The index's nightly refresh logs the day automatically; public pages still have to pass its UAT and secret scan.
