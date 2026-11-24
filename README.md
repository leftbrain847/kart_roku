# Kart for Roku

A kart racer for Roku TVs, written in BrightScript. Pick a track and a racer on the title screen, then race three bots over 3 laps. Five lanes, every lane its own track; where the road splits into 2 or 3 tracks, Left/Right jumps the gap. Item blocks (puck, banana, boost), light traffic, race position, lap timer and best lap per track.

**Tracks:** three worlds with hills, crests, textured roads and their own racers (Fernback Jungle, Girder Sky with a tube and a corkscrew, Pebble Cove), plus ten classic road themes. **Racers:** six 3D-rendered characters (Raptor Hatchling, Trike, Toaster Tank, Gear Snail, Hermit Conch, Jelly Jet), each drawn at three angles so they lean into turns.

**Download:** [kart_roku.zip](https://github.com/leftbrain847/kart_roku/releases/latest/download/kart_roku.zip) (latest release; sideload it, see below)

## Controls
| Remote | Title screen | Racing |
|---|---|---|
| Up / Down | choose track or racer row | Up throws your item forward, Down drops it behind |
| Left / Right | change the track or racer | change lane; across a split it's a jump to the other track |
| OK | start the race | use a boost |
| Play/Pause | start the race | pause menu: resume, traffic on/off, restart, tracks, exit |
| `*` (options) | | show or hide the FPS counter |
| Back | exit | exit |

Each lap has split zones (2 or 3 tracks) that rejoin. Bots stay in lanes too, switch to dodge hazards and grab blocks, and throw pucks at karts ahead. Jumping clears bananas.

## Run (on a Roku)
```
npm ci
npm run build          # -> dist/kart_roku.zip
npm run check          # security gate: allowed files only, no network APIs, no secrets
```
Then sideload: on the remote press Home ×3, Up ×2, Right, Left, Right, Left, Right to enable developer mode; open the Roku's IP in a browser on the same Wi-Fi, sign in as `rokudev`, upload `dist/kart_roku.zip`, Install.

Run it in the simulator instead: `npx brs-cli -n dist/kart_roku.zip` (add `-k autotest=1` for the scripted race plus a pass through each world's hills, tube and corkscrew).

## Test
```
npm test
```
Runs the brighterscript compiler checks, 100+ game-rule unit tests (including world courses: hills, tubes, corkscrew) and a 700-frame scripted race (countdown, items, pause menu, a jump across a split, 3 bots) followed by a render pass through all three worlds in the `brs-cli` simulator, builds the zip and runs it through the security gate. CI runs the same.

## Tune it
Every tunable is in `GameConfig()` in [`source/config.brs`](source/config.brs): lanes and jump feel, laps and countdown, speeds and boost, the default course, split zones, item odds, bots, traffic, camera, render bands, fog, the title-screen track list and the racer roster. Worlds (their courses with `rise` hills, `tube` and `roll` sections, split names, racers and landmarks) and road themes live in [`source/themes.brs`](source/themes.brs). `ValidateConfig` reports bad layouts at startup.

## Art
All art is generated, so it can be changed and rebuilt:
```
pip install pillow numpy
python3 scripts/art/make_art.py images/sprites        # items, roadside scenery, classic theme skies
python3 scripts/art/characters.py images/sprites      # 3D racers, 3 angles each (signed-distance shapes, ray marched)
python3 scripts/art/props.py images/sprites           # 3D props: dinosaur, girders, lighthouse, rock arch...
python3 scripts/art/worlds.py images/sprites          # world skies, parallax layers, cloud sea, road textures
```
The game loads each PNG once per race and pre-scales it into 30 sizes; frames only copy bitmaps.

## How it stays fast on a Streaming Stick HD (3840R)
- `roScreen` + Draw2D, double-buffered at 1280×720; no SceneGraph nodes in the frame loop.
- The road is ~115 depth samples; each is projected with curves and hills and drawn as a few rectangles (or one scaled texture row), clipped so crests hide what's behind them. Fog colors are pre-blended per sample.
- Sprites are pre-scaled once per race; a frame copies bitmaps and never scales them. The corkscrew draws the frame to an offscreen bitmap and rotates it once.
- Not yet measured on the stick: textured roads and the corkscrew rotation. Press `*` while racing to see the frame rate.
- System fonts only (`roFontRegistry.GetDefaultFont`).

Note: Roku requires SceneGraph for apps published to the Channel Store; `roScreen` is a legacy API. That's fine for sideloading, which is how this build ships.

## Layout
```
manifest, images/          Roku app metadata and icons
source/config.brs          all tunables
source/themes.brs          worlds, road themes, track and racer names
source/menu.brs            title screen
source/track.brs           course curves, hills, tubes, rolls, split zones, lanes (pure)
source/game.brs            rules: input, karts and bots, jumps, items, traffic, laps, race (pure)
source/sprites.brs         pre-scaled sprite bitmaps
source/render.brs          Draw2D renderer (hills, textures, tubes, corkscrew) and HUD
source/main.brs            screen, frame loop, saved best lap
scripts/                   build, zip, security gate, sprint snapshot; scripts/art: art generators
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
