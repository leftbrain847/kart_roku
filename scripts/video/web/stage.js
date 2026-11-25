// Shared rendering pieces: renderer, road ribbons, camera rig, lane table export.
import * as THREE from 'three';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
import { ROAD_HALF, CAM, at, rightOf, chain, worldPaths, SPEED, FPS } from './track.js';

export function makeRenderer(w, h, { alpha = false } = {}) {
  const r = new THREE.WebGLRenderer({ antialias: true, alpha, preserveDrawingBuffer: true });
  r.setPixelRatio(1);
  r.setSize(w, h);
  r.toneMapping = THREE.ACESFilmicToneMapping;
  r.outputColorSpace = THREE.SRGBColorSpace;
  r.shadowMap.enabled = true;
  r.shadowMap.type = THREE.PCFSoftShadowMap;
  document.body.appendChild(r.domElement);
  return r;
}

export function canvasTex(w, h, draw, { repeat = true, srgb = true } = {}) {
  const c = document.createElement('canvas');
  c.width = w; c.height = h;
  draw(c.getContext('2d'), w, h);
  const t = new THREE.CanvasTexture(c);
  if (repeat) t.wrapS = t.wrapT = THREE.RepeatWrapping;
  if (srgb) t.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = 8;
  return t;
}

// A road ribbon along a path. v runs along the road every `texLen` metres. Optional skirt walls down to `skirtTo`.
export function roadMesh(path, mat, { texLen = 12, half = ROAD_HALF, lift = 0.04, skirt = null, skirtMat = null } = {}) {
  const pos = [], uv = [], idx = [];
  const n = Math.floor(path.len);
  for (let i = 0; i <= n; i++) {
    const p = at(path, i), r = rightOf(p.h);
    pos.push(p.x - r.x * half, p.y + lift, p.z - r.z * half, p.x + r.x * half, p.y + lift, p.z + r.z * half);
    uv.push(0, i / texLen, 1, i / texLen);
    if (i < n) { const a = i * 2; idx.push(a, a + 1, a + 2, a + 1, a + 3, a + 2); }
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
  g.setIndex(idx);
  g.computeVertexNormals();
  const group = new THREE.Group();
  const road = new THREE.Mesh(g, mat);
  road.receiveShadow = true;
  group.add(road);
  if (skirt !== null) {
    for (const side of [-1, 1]) {
      const sp = [], si = [], su = [];
      for (let i = 0; i <= n; i++) {
        const p = at(path, i), r = rightOf(p.h);
        const x = p.x + r.x * half * side, z = p.z + r.z * half * side;
        sp.push(x, p.y + lift, z, x, Math.min(skirt, p.y), z);
        su.push(i / 8, 0, i / 8, Math.max(0.1, (p.y - skirt) / 8));
        if (i < n) { const a = i * 2; side > 0 ? si.push(a, a + 1, a + 2, a + 2, a + 1, a + 3) : si.push(a, a + 2, a + 1, a + 1, a + 2, a + 3); }
      }
      const sg = new THREE.BufferGeometry();
      sg.setAttribute('position', new THREE.Float32BufferAttribute(sp, 3));
      sg.setAttribute('uv', new THREE.Float32BufferAttribute(su, 2));
      sg.setIndex(si);
      sg.computeVertexNormals();
      const m = new THREE.Mesh(sg, skirtMat ?? mat);
      m.material.side = THREE.DoubleSide;
      m.receiveShadow = m.castShadow = true;
      group.add(m);
    }
  }
  return group;
}

// Places objects along a path: cb(pointAt(s), s) for s every `every` metres.
export function along(path, every, cb, start = 0) {
  for (let s = start; s < path.len; s += every) cb(at(path, s), s);
}

export function camPose(path, s) {
  const p = at(path, s), q = at(path, s + CAM.lookAhead);
  return {
    pos: new THREE.Vector3(p.x, p.y + CAM.height, p.z),
    look: new THREE.Vector3(q.x, q.y + CAM.lookHeight, q.z),
  };
}

export class Stage {
  constructor(w, h, world) {
    this.w = w; this.h = h;
    this.renderer = makeRenderer(w, h);
    this.scene = new THREE.Scene();
    this.camera = new THREE.PerspectiveCamera(CAM.fov, w / h, 0.3, 2500);
    this.paths = worldPaths(world);
    this.world = world;
    this.composer = new EffectComposer(this.renderer);
    this.composer.addPass(new RenderPass(this.scene, this.camera));
    if (world.bloom) this.composer.addPass(new UnrealBloomPass(new THREE.Vector2(w / 2, h / 2), world.bloom.strength, world.bloom.radius, world.bloom.threshold));
    this.composer.addPass(new OutputPass());
  }
  // The road the camera drives on for a segment, plus what follows it (for looking ahead past the cut).
  route(seg, cont) {
    const P = this.paths;
    if (seg === 'shared') return chain(P.shared, P[cont]);
    return chain(P[seg], P.shared, P[cont ?? 'left']);
  }
  segLen(seg) { return this.paths[seg].len; }
  frames(seg) { return Math.round(this.segLen(seg) / SPEED * FPS); }
  place(seg, cont, frame) {
    const route = this.route(seg, cont);
    const s = frame * this.segLen(seg) / this.frames(seg);
    const pose = camPose(route, s);
    this.camera.position.copy(pose.pos);
    this.camera.lookAt(pose.look);
    this.camera.updateMatrixWorld();
    return { route, s };
  }
  render() { this.composer.render(); }

  // Where the karts go: for rows at `rate` Hz, for each depth d (metres ahead of the kart line), the road centre on
  // screen (x, y), pixels per metre across the road, and the road's heading relative to the camera (degrees).
  laneTable(seg, cont, depths, rate = 15) {
    const n = this.frames(seg), rows = [];
    const v = new THREE.Vector3(), v2 = new THREE.Vector3(), fwd = new THREE.Vector3();
    for (let t = 0; t * FPS < n; t += 1 / rate) {
      const { route, s } = this.place(seg, cont, t * FPS);
      this.camera.getWorldDirection(fwd);
      const camYaw = Math.atan2(fwd.x, fwd.z);
      const row = [];
      for (const d of depths) {
        const p = at(route, s + CAM.back + d), r = rightOf(p.h);
        v.set(p.x, p.y, p.z).project(this.camera);
        v2.set(p.x + r.x, p.y, p.z + r.z).project(this.camera);
        const x = (v.x + 1) / 2 * this.w, y = (1 - v.y) / 2 * this.h;
        const ppm = Math.hypot((v2.x - v.x) / 2 * this.w, (v2.y - v.y) / 2 * this.h);
        let yaw = (p.h - camYaw) * 180 / Math.PI;
        yaw = ((yaw + 540) % 360) - 180;
        row.push(Math.round(x * 10) / 10, Math.round(y * 10) / 10, Math.round(ppm * 100) / 100, Math.round(yaw * 10) / 10);
      }
      rows.push(row);
    }
    return rows;
  }
}

export { THREE };
