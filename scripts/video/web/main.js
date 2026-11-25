// Page API driven by render.mjs: setup a world, place the camera on a segment frame, render, export lane tables.
import { Stage } from './stage.js';
import { FPS } from './track.js';
const worlds = { jungle: () => import('./jungle.js'), library: () => import('./library.js') };
let stage = null;
window.API = {
  async setup(name, w, h) {
    const mod = await worlds[name]();
    stage = new Stage(w, h, mod.world);
    mod.build(stage);
    return { shared: stage.frames('shared'), left: stage.frames('left'), right: stage.frames('right'),
      lens: { shared: stage.segLen('shared'), left: stage.segLen('left'), right: stage.segLen('right') } };
  },
  // seg time origin: shared starts at 0; branches start where shared ends, so animations stay continuous within a lap.
  frame(seg, cont, i, quality = 0.92) {
    stage.place(seg, cont, i);
    const t0 = seg === 'shared' ? 0 : stage.frames('shared');
    stage.update?.((t0 + i) / FPS);
    stage.render();
    return stage.renderer.domElement.toDataURL('image/jpeg', quality);
  },
  table(seg, cont, depths, rate) { return stage.laneTable(seg, cont, depths, rate); },
};
window.READY = true;
import { setupKarts } from './kart.js';
let karts = null;
window.API.setupKarts = (w, h) => { karts = setupKarts(w, h); return { anchor: karts.anchor, pxPerM: karts.pxPerM }; };
window.API.kart = (variant, deg) => karts.render(variant, deg);
