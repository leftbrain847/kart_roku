#!/usr/bin/env python3
"""Build the sprint day page for the video-track POC (one self-contained HTML file: preview clips and stills inline).
   python3 daypage.py <out.html> <jungle preview.mp4> <library preview.mp4> <poster.jpg> <still.jpg>..."""
import base64, html, sys
from pathlib import Path

out, jv, lv, poster, *stills = sys.argv[1:]
b64 = lambda p: base64.b64encode(Path(p).read_bytes()).decode()
CAPS = ['Fern Rush: the fork. Lanes 1-2 take the gorge, 4-5 the ruin ridge.', 'The Grand Stacks: the book tunnel fork.',
        'The Grand Stacks: 22 m shelf walls on the main hall.', 'Kart sprites: 24 rendered angles per kart, four karts.']
figs = '\n'.join(f'<figure class="screen"><img src="data:image/jpeg;base64,{b64(s)}" alt="{html.escape(c)}" loading="lazy"><figcaption>{html.escape(c)}</figcaption></figure>'
                 for s, c in zip(stills, CAPS))
page = f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Kart video tracks</title>
<meta name="description" content="A proof of concept: kart racing over pre-rendered video tracks on a Roku.">
<style>
:root {{ color-scheme: dark; --asphalt: #1c1f27; --asphalt-2: #262a34; --line: #3a3f4c; --paint: #f2f2f2; --muted: #b4b9c6; --kart: #e0322e; --hud: #ffd23f;
  --display: "Arial Narrow", system-ui, sans-serif; --body: system-ui, -apple-system, "Segoe UI", sans-serif; --mono: ui-monospace, Menlo, Consolas, monospace; }}
* {{ box-sizing: border-box; }}
html, body {{ background: var(--asphalt); color: var(--paint); }}
body {{ margin: 0; font: 16px/1.55 var(--body); padding: 28px max(16px, env(safe-area-inset-right, 0px)) 56px max(16px, env(safe-area-inset-left, 0px)); }}
main {{ max-width: 760px; margin: 0 auto; display: grid; gap: 30px; }}
h1, h2 {{ font-family: var(--display); margin: 0; line-height: 1.05; text-wrap: balance; }}
h1 {{ font-size: clamp(2.1rem, 8vw, 3.8rem); }} h1 span {{ color: var(--hud); }} h2 {{ font-size: 1.4rem; }}
p {{ margin: 0; max-width: 65ch; }} .lede {{ color: var(--muted); font-size: 1.05rem; }}
.eyebrow {{ font: 600 0.8rem/1 var(--mono); letter-spacing: 0.12em; text-transform: uppercase; color: var(--hud); }}
header, section {{ display: grid; gap: 12px; }}
.rumble {{ height: 10px; border-radius: 2px; background: repeating-linear-gradient(90deg, var(--kart) 0 28px, var(--paint) 28px 56px); }}
.screen {{ margin: 0; border-radius: 10px; overflow: hidden; background: #000; border: 1px solid var(--line); }}
.screen img, .screen video {{ display: block; width: 100%; aspect-ratio: 16 / 9; object-fit: cover; }}
.screen figcaption {{ padding: 8px 12px; font: 500 0.8rem/1.4 var(--mono); color: var(--muted); background: var(--asphalt-2); }}
.shots {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 14px; }}
ul {{ margin: 0; padding-left: 1.2em; display: grid; gap: 6px; max-width: 65ch; }}
code {{ font: 500 0.92em var(--mono); background: var(--asphalt-2); border: 1px solid var(--line); border-radius: 5px; padding: 1px 6px; }}
.small {{ color: var(--muted); font-size: 0.9rem; }}
</style></head>
<body><main>
<header><p class="eyebrow">Sprint day 2 · proof of concept</p><h1>Kart <span>video tracks</span></h1>
<p class="lede">The track is a pre-rendered video. Only the karts and HUD are drawn live on the Roku, so the scenery can be any quality. Pick a fork with your lane and the video follows you down it.</p></header>
<figure class="screen"><video id="tv" autoplay muted loop playsinline preload="auto" poster="data:image/jpeg;base64,{b64(poster)}"><source type="video/mp4" src="data:video/mp4;base64,{b64(jv)}"></video>
<figcaption>Fern Rush, one lap down the gorge fork: the karts are composited over the video with the same lane tables the Roku app uses (offline preview, not a TV capture).</figcaption></figure>
<div class="rumble" role="presentation"></div>
<section><h2>How it works</h2><ul>
<li>Each world is a shared straight plus one video per fork branch, rendered once from a camera riding the line across the five karts' mirrors at a steady speed.</li>
<li>Your lane picks the fork; the choice stays open until your kart reaches the split, a third of a second before the cut.</li>
<li>Boosts and spins show as your kart surging ahead of the camera or dropping behind it, so the video never changes speed.</li>
<li>Karts come from 24 rendered angles and sit on the road using a lane table exported with every video.</li>
<li>On the TV, <code>*</code> switches between three ways of jumping to the fork, and the HUD shows the stall each one causes, so we can pick the fastest.</li>
</ul></section>
<figure class="screen"><video autoplay muted loop playsinline preload="none"><source type="video/mp4" src="data:video/mp4;base64,{b64(lv)}"></video>
<figcaption>The Grand Stacks, a lap through the book tunnel with the lane zoom on.</figcaption></figure>
<section><h2>Stills</h2><div class="shots">{figs}</div></section>
<p class="small">Rendered with three.js in a headless browser for this prototype; the same pipeline can take Blender or Unreal renders. Videos stream from GitHub tonight and move to Cloudflare R2 next.</p>
</main></body></html>
'''
Path(out).write_text(page)
print(out, len(page))
