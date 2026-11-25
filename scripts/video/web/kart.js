// Original kart model, rendered to transparent sprites at 24 angles for the Roku overlay.
import * as THREE from 'three';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';

export const VARIANTS = {
  red: { body: 0xd8261c, trim: 0xf2f2f2, suit: 0x1b1b1f, helmet: 0xffcc1a },
  teal: { body: 0x0fa3a3, trim: 0x111318, suit: 0xf0f0f0, helmet: 0xff4f8b },
  gold: { body: 0xf2a91a, trim: 0x2a2a30, suit: 0x2050c8, helmet: 0xf4f4f4 },
  violet: { body: 0x7b3fe4, trim: 0xf2f2f2, suit: 0x2b2b2b, helmet: 0x39d98a },
};

function kart(v) {
  const g = new THREE.Group();
  const paint = new THREE.MeshPhysicalMaterial({ color: v.body, metalness: 0.35, roughness: 0.28, clearcoat: 1, clearcoatRoughness: 0.08 });
  const trim = new THREE.MeshStandardMaterial({ color: v.trim, metalness: 0.2, roughness: 0.4 });
  const carbon = new THREE.MeshStandardMaterial({ color: 0x1a1a1d, metalness: 0.4, roughness: 0.45 });
  const chrome = new THREE.MeshStandardMaterial({ color: 0xdddddd, metalness: 1, roughness: 0.15 });
  const rubber = new THREE.MeshStandardMaterial({ color: 0x141414, roughness: 0.9 });
  const suit = new THREE.MeshStandardMaterial({ color: v.suit, roughness: 0.7 });
  const helmet = new THREE.MeshPhysicalMaterial({ color: v.helmet, metalness: 0.2, roughness: 0.2, clearcoat: 1 });
  const visor = new THREE.MeshStandardMaterial({ color: 0x101820, metalness: 0.9, roughness: 0.05 });
  const add = (geo, mat, x, y, z, rx = 0, ry = 0, rz = 0) => { const m = new THREE.Mesh(geo, mat); m.position.set(x, y, z); m.rotation.set(rx, ry, rz); g.add(m); return m; };

  add(new RoundedBoxGeometry(1.15, 0.28, 2.6, 4, 0.12), carbon, 0, 0.28, 0);           // floor pan
  add(new RoundedBoxGeometry(0.95, 0.42, 1.5, 5, 0.2), paint, 0, 0.55, 0.45);          // tub
  const nose = add(new THREE.ConeGeometry(0.42, 1.0, 16), paint, 0, 0.5, 1.55, Math.PI / 2);
  nose.scale.set(1.3, 1, 0.7);
  add(new RoundedBoxGeometry(1.7, 0.08, 0.42, 3, 0.03), trim, 0, 0.32, 1.95);         // front wing
  for (const s of [-1, 1]) {
    add(new RoundedBoxGeometry(0.3, 0.32, 1.4, 4, 0.12), paint, s * 0.75, 0.42, 0.1);  // side pods
    add(new RoundedBoxGeometry(0.06, 0.3, 0.5, 2, 0.02), trim, s * 0.86, 0.36, 1.95);  // wing end plates
  }
  add(new RoundedBoxGeometry(0.8, 0.5, 0.75, 4, 0.12), carbon, 0, 0.62, -0.75);        // engine
  for (const s of [-1, 1]) add(new THREE.CylinderGeometry(0.09, 0.11, 0.55, 12), chrome, s * 0.22, 0.78, -1.25, Math.PI / 2 - 0.35);
  add(new RoundedBoxGeometry(1.55, 0.07, 0.45, 3, 0.03), paint, 0, 1.22, -1.2);       // rear wing
  for (const s of [-1, 1]) add(new THREE.BoxGeometry(0.06, 0.5, 0.1), carbon, s * 0.3, 0.95, -1.15);
  add(new THREE.BoxGeometry(1.6, 0.05, 0.08), trim, 0, 1.27, -1.42);                   // wing lip
  // Driver
  add(new THREE.SphereGeometry(0.34, 18, 14), suit, 0, 0.92, -0.15).scale.set(1, 1.1, 0.9);
  add(new THREE.SphereGeometry(0.27, 24, 18), helmet, 0, 1.35, -0.12);
  const vz = add(new THREE.SphereGeometry(0.2, 18, 12, -Math.PI * 0.4, Math.PI * 0.8, Math.PI * 0.35, Math.PI * 0.3), visor, 0, 1.35, -0.06);
  vz.rotation.y = 0;
  add(new THREE.TorusGeometry(0.16, 0.03, 8, 20), carbon, 0, 0.95, 0.35, -0.6);       // steering wheel
  // Wheels: fat slicks at the back
  const wheel = (x, z, r, w) => {
    const t = add(new THREE.CylinderGeometry(r, r, w, 28), rubber, x, r, z, 0, 0, Math.PI / 2);
    add(new THREE.CylinderGeometry(r * 0.62, r * 0.62, w + 0.02, 20), chrome, x, r, z, 0, 0, Math.PI / 2);
    add(new THREE.TorusGeometry(r * 0.95, 0.03, 6, 28), rubber, x + Math.sign(x) * w / 2, r, z, 0, Math.PI / 2);
    return t;
  };
  for (const s of [-1, 1]) { wheel(s * 0.95, 1.2, 0.3, 0.32); wheel(s * 1.0, -1.05, 0.38, 0.48); }
  g.traverse((o) => { o.castShadow = true; });
  return g;
}

export function setupKarts(w, h) {
  const r = new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true });
  r.setPixelRatio(1); r.setSize(w, h);
  r.setClearColor(0x000000, 0);
  r.toneMapping = THREE.ACESFilmicToneMapping; r.toneMappingExposure = 1.0;
  r.outputColorSpace = THREE.SRGBColorSpace;
  r.shadowMap.enabled = true;
  document.body.appendChild(r.domElement);
  const scene = new THREE.Scene();
  const pm = new THREE.PMREMGenerator(r);
  scene.environment = pm.fromScene(new RoomEnvironment(), 0.04).texture;
  scene.add(new THREE.HemisphereLight(0xffffff, 0x404040, 1.2));
  const sun = new THREE.DirectionalLight(0xfff2dd, 2.6);
  sun.position.set(-3, 8, 2); sun.castShadow = true;
  sun.shadow.mapSize.set(1024, 1024);
  Object.assign(sun.shadow.camera, { left: -3, right: 3, top: 3, bottom: -3 });
  scene.add(sun);
  // Contact shadow: a soft dark blob that stays in the sprite (sits on any road)
  const blob = document.createElement('canvas'); blob.width = blob.height = 128;
  const bg = blob.getContext('2d'); const gr = bg.createRadialGradient(64, 64, 8, 64, 64, 64);
  gr.addColorStop(0, 'rgba(0,0,0,0.6)'); gr.addColorStop(1, 'rgba(0,0,0,0)'); bg.fillStyle = gr; bg.fillRect(0, 0, 128, 128);
  const shadowTex = new THREE.CanvasTexture(blob);
  const shadow = new THREE.Mesh(new THREE.PlaneGeometry(2.6, 3.6), new THREE.MeshBasicMaterial({ map: shadowTex, transparent: true, depthWrite: false }));
  shadow.rotation.x = -Math.PI / 2; shadow.position.y = 0.01;
  scene.add(shadow);
  // Same view angle as the race camera: 3.8 m up, 12 m back; narrow lens so every sprite has the same perspective.
  const cam = new THREE.PerspectiveCamera(18, w / h, 1, 100);
  const dist = 16, elev = Math.atan2(3.8, 12);
  cam.position.set(0, dist * Math.sin(elev) + 0.5, -dist * Math.cos(elev));
  cam.lookAt(0, 0.6, 0);
  const karts = {};
  for (const [k, v] of Object.entries(VARIANTS)) { karts[k] = kart(v); scene.add(karts[k]); karts[k].visible = false; }
  cam.updateMatrixWorld();
  const proj = (x, y, z) => { const p = new THREE.Vector3(x, y, z).project(cam); return [(p.x + 1) / 2 * w, (1 - p.y) / 2 * h]; };
  const [ax, ay] = proj(0, 0, 0), [bx] = proj(-1, 0, 0);
  return {
    anchor: [ax, ay], pxPerM: Math.abs(bx - ax),
    render(variant, deg) {
      for (const k in karts) karts[k].visible = k === variant;
      // deg > 0: kart points to the right of the screen (we see its left side). Camera right is -x here.
      karts[variant].rotation.y = -deg * Math.PI / 180;
      r.render(scene, cam);
      return r.domElement.toDataURL('image/png');
    },
  };
}
