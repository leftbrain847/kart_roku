// The Grand Stacks: an enormous modern library. Walnut track with brass inlays and LED edges on a polished stone
// floor, 22 m shelf walls of neatly shelved books, rolling ladders, white columns, a coffered ceiling with
// skylights and light shafts. Left fork: a tunnel of book arches. Right fork: a ramp up to a glass mezzanine.
import { THREE, canvasTex, roadMesh, along } from './stage.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { ROAD_HALF, makeRoadField, rng, at, rightOf } from './track.js';

export const world = { name: 'library', leftRise: 0, rightRise: 8, bloom: { strength: 0.3, radius: 0.5, threshold: 0.97 } };

const CEIL = 44, SHELF_H = 22, LEVELS = 9, UNIT_W = 4.2, LEVEL_H = SHELF_H / LEVELS;
const PALETTE = ['#6b1d1d', '#8c2f22', '#1f3352', '#22405e', '#2c4a32', '#3b5e3a', '#7a5a35', '#9b7a4c', '#d8cdb4', '#efe6d0',
  '#4a2a3e', '#2a2a2e', '#b8860b', '#5c6b73', '#a0522d', '#e2d6bd', '#14324a', '#701c2c'];

function bookTex(seed) {
  return canvasTex(1024, 584, (g, w, h) => {
    const r = rng(seed);
    const grad = g.createLinearGradient(0, 0, 0, h);
    grad.addColorStop(0, '#1c120b'); grad.addColorStop(1, '#2b1d12');
    g.fillStyle = grad; g.fillRect(0, 0, w, h);
    let x = 6;
    while (x < w - 10) {
      const bw = 8 + Math.floor(r() * 16) + (r() < 0.08 ? 14 : 0);
      const bh = h * (0.68 + r() * 0.26);
      const col = PALETTE[Math.floor(r() * PALETTE.length)];
      const top = h - bh;
      g.fillStyle = col; g.fillRect(x, top, bw - 1, bh);
      const sh = g.createLinearGradient(x, 0, x + bw, 0);           // rounded spine shading
      sh.addColorStop(0, 'rgba(0,0,0,0.35)'); sh.addColorStop(0.35, 'rgba(255,255,255,0.10)'); sh.addColorStop(1, 'rgba(0,0,0,0.4)');
      g.fillStyle = sh; g.fillRect(x, top, bw - 1, bh);
      if (r() < 0.7) {                                               // gilt bands and a title label
        g.fillStyle = 'rgba(214,176,92,0.85)';
        g.fillRect(x + 1, top + bh * 0.08, bw - 3, 2); g.fillRect(x + 1, top + bh * 0.88, bw - 3, 2);
        if (bw > 11) { g.fillStyle = r() < 0.5 ? 'rgba(20,14,8,0.65)' : 'rgba(230,215,180,0.8)'; g.fillRect(x + 3, top + bh * 0.25, bw - 7, bh * 0.22); }
      }
      x += bw;
      if (r() < 0.04) x += 6 + r() * 14;                              // the odd gap
    }
    const top = g.createLinearGradient(0, 0, 0, h * 0.35);           // shadow under the shelf above
    top.addColorStop(0, 'rgba(0,0,0,0.75)'); top.addColorStop(1, 'rgba(0,0,0,0)');
    g.fillStyle = top; g.fillRect(0, 0, w, h * 0.35);
  });
}

function floorTex() {
  return canvasTex(1024, 1024, (g, w, h) => {
    const r = rng(21);
    for (let i = 0; i < 4; i++) for (let j = 0; j < 4; j++) {
      const l = 222 + r() * 14;
      g.fillStyle = `rgb(${l},${l - 4},${l - 12})`; g.fillRect(i * 256, j * 256, 256, 256);
      for (let k = 0; k < 6; k++) {                                   // faint veins
        g.strokeStyle = `rgba(150,140,125,${0.08 + r() * 0.12})`; g.lineWidth = 1 + r() * 2;
        g.beginPath(); let x = i * 256 + r() * 256, y = j * 256;
        g.moveTo(x, y);
        for (let s = 0; s < 8; s++) { x += (r() - 0.5) * 60; y += 32; g.lineTo(x, y); }
        g.stroke();
      }
      g.strokeStyle = 'rgba(120,110,95,0.6)'; g.lineWidth = 2; g.strokeRect(i * 256, j * 256, 256, 256);
    }
  });
}

function roadTex() {
  return canvasTex(512, 1024, (g, w, h) => {
    const r = rng(33);
    g.fillStyle = '#3b2516'; g.fillRect(0, 0, w, h);
    for (let x = 16; x < w - 16; x += 48) {                          // long walnut planks along the road
      let y = -r() * 300;
      while (y < h) {
        const len = 220 + r() * 260, l = r() * 0.3;
        g.fillStyle = `rgb(${70 + l * 90},${40 + l * 50},${22 + l * 26})`; g.fillRect(x, y, 46, len - 3);
        for (let k = 0; k < 5; k++) { g.fillStyle = `rgba(25,12,5,${0.15 + r() * 0.2})`; g.fillRect(x + r() * 46, y, 1 + r() * 2, len - 3); }
        y += len;
      }
    }
    const edge = 18;
    g.fillStyle = '#f4ead2'; g.fillRect(0, 0, 6, h); g.fillRect(w - 6, 0, 6, h);   // LED edge (bright, blooms)
    g.fillStyle = '#c9a34a'; g.fillRect(8, 0, 4, h); g.fillRect(w - 12, 0, 4, h);  // brass
    for (let k = 1; k < 5; k++) {
      const x = edge + (w - 2 * edge) * k / 5;
      g.fillStyle = '#d4af55';
      for (let y = 0; y < h; y += 128) g.fillRect(x - 3, y, 6, 80);
    }
  });
}

export function build(stage) {
  const { scene } = stage, P = stage.paths, all = [P.shared, P.left, P.right];
  const field = makeRoadField(all);
  const R = rng(77);
  stage.renderer.toneMappingExposure = 0.68;

  const pmrem = new THREE.PMREMGenerator(stage.renderer);
  scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
  scene.environmentIntensity = 0.55;
  scene.background = new THREE.Color(0xb9a98e);
  scene.fog = new THREE.FogExp2(0xb9a98e, 0.0042);

  scene.add(new THREE.HemisphereLight(0xfff4e0, 0x6b5a45, 1.0));
  const sunL = new THREE.DirectionalLight(0xfff1d6, 3.4);
  sunL.castShadow = true;
  sunL.shadow.mapSize.set(2048, 2048);
  Object.assign(sunL.shadow.camera, { left: -80, right: 80, top: 80, bottom: -80, near: 1, far: 300 });
  sunL.shadow.bias = -0.0006;
  scene.add(sunL, sunL.target);
  const sunDir = new THREE.Vector3(0.35, 1, 0.25).normalize();

  // Floor
  const ft = floorTex(); ft.repeat.set(90, 90);
  const floor = new THREE.Mesh(new THREE.PlaneGeometry(1000, 1000), new THREE.MeshStandardMaterial({ map: ft, roughness: 0.42, metalness: 0.0 }));
  floor.rotation.x = -Math.PI / 2; floor.position.set(0, -0.01, 60);
  floor.receiveShadow = true;
  scene.add(floor);

  // Track (ramp sides are white panels)
  const roadMat = new THREE.MeshStandardMaterial({ map: roadTex(), roughness: 0.35, metalness: 0.05, emissive: 0xffffff, emissiveIntensity: 0.0 });
  const panel = new THREE.MeshStandardMaterial({ color: 0xf1ede6, roughness: 0.5 });
  for (const p of all) scene.add(roadMesh(p, roadMat, { texLen: 10, skirt: 0, skirtMat: panel }));

  // Shelf walls along every road (where they don't block another road)
  const units = [];
  for (const path of all) {
    along(path, UNIT_W, (p) => {
      const r = rightOf(p.h);
      for (const side of [-1, 1]) {
        const off = ROAD_HALF + 5.5;
        const x = p.x + r.x * off * side, z = p.z + r.z * off * side;
        const f = field(x, z, 4);
        if (f.d < ROAD_HALF + 4.5) continue;
        if (units.some((u) => Math.hypot(u.x - x, u.z - z) < UNIT_W * 0.9)) continue;
        units.push({ x, z, rot: p.h + (side > 0 ? Math.PI / 2 : -Math.PI / 2), y: 0 });
      }
    });
  }
  const m4 = new THREE.Matrix4(), q = new THREE.Quaternion(), e = new THREE.Euler(), vs = new THREE.Vector3(), vp = new THREE.Vector3();
  const wood = new THREE.MeshStandardMaterial({ color: 0x6b4426, roughness: 0.45 });
  const postG = new THREE.BoxGeometry(0.28, SHELF_H, 0.9); postG.translate(0, SHELF_H / 2, 0);
  const boardG = new THREE.BoxGeometry(UNIT_W, 0.12, 0.9);
  const posts = new THREE.InstancedMesh(postG, wood, units.length);
  const boards = new THREE.InstancedMesh(boardG, wood, units.length * (LEVELS + 1));
  const tex = [bookTex(1), bookTex(2), bookTex(3), bookTex(4)];
  tex.forEach((t) => t.repeat.set(1, LEVELS));
  const panelG = new THREE.PlaneGeometry(UNIT_W, SHELF_H); panelG.translate(0, SHELF_H / 2, 0);
  const groups = tex.map(() => []);
  units.forEach((u, i) => {
    q.setFromEuler(e.set(0, u.rot, 0));
    const right = new THREE.Vector3(1, 0, 0).applyQuaternion(q), back = new THREE.Vector3(0, 0, -1).applyQuaternion(q);
    m4.compose(vp.set(u.x + right.x * UNIT_W / 2, 0, u.z + right.z * UNIT_W / 2), q, vs.set(1, 1, 1));
    posts.setMatrixAt(i, m4);
    for (let k = 0; k <= LEVELS; k++) {
      m4.compose(vp.set(u.x, k * LEVEL_H + 0.06, u.z), q, vs.set(1, 1, 1));
      boards.setMatrixAt(i * (LEVELS + 1) + k, m4);
    }
    groups[Math.floor(R() * tex.length)].push({ x: u.x + back.x * 0.3, z: u.z + back.z * 0.3, q: q.clone() });
  });
  posts.castShadow = boards.castShadow = true; posts.receiveShadow = boards.receiveShadow = true;
  scene.add(posts, boards);
  groups.forEach((list, k) => {
    const im = new THREE.InstancedMesh(panelG, new THREE.MeshStandardMaterial({ map: tex[k], roughness: 0.8, side: THREE.DoubleSide }), list.length);
    list.forEach((b, i) => { m4.compose(vp.set(b.x, 0, b.z), b.q, vs.set(1, 1, 1)); im.setMatrixAt(i, m4); });
    im.receiveShadow = true;
    scene.add(im);
  });

  // Rolling ladders: brass rails, a few per wall
  const brass = new THREE.MeshStandardMaterial({ color: 0xc9a046, metalness: 0.9, roughness: 0.25 });
  const ladderG = new THREE.Group();
  for (const sx of [-0.35, 0.35]) { const rail = new THREE.Mesh(new THREE.CylinderGeometry(0.05, 0.05, 14, 6), brass); rail.position.set(sx, 7, 0); ladderG.add(rail); }
  for (let k = 0; k < 28; k++) { const rung = new THREE.Mesh(new THREE.CylinderGeometry(0.03, 0.03, 0.7, 6), brass); rung.rotation.z = Math.PI / 2; rung.position.set(0, 0.5 + k * 0.48, 0); ladderG.add(rung); }
  units.forEach((u) => {
    if (R() > 0.07) return;
    const l = ladderG.clone();
    l.position.set(u.x, 0, u.z);
    l.rotation.set(0, u.rot, 0);
    l.rotateX(-0.18);
    l.translateZ(1.4);
    l.traverse((o) => { o.castShadow = true; });
    scene.add(l);
  });

  // White columns and the coffered ceiling with skylights
  const colMat = new THREE.MeshStandardMaterial({ color: 0xf4f1ea, roughness: 0.35 });
  const colG = new THREE.CylinderGeometry(1.6, 1.8, CEIL, 24);
  for (let k = 0; k < 400; k++) {
    const x = (R() - 0.5) * 420, z = (R() - 0.5) * 420 + 60;
    const f = field(x, z, 6);
    if (f.d < ROAD_HALF + 2 || f.d > ROAD_HALF + 4.5) continue;
    if (R() < 0.6) continue;
    const c = new THREE.Mesh(colG, colMat);
    c.position.set(x, CEIL / 2, z); c.castShadow = true;
    scene.add(c);
  }
  const ceilTex = canvasTex(512, 512, (g, w, h) => {
    g.fillStyle = '#e9e2d4'; g.fillRect(0, 0, w, h);
    g.fillStyle = '#cfc5b2'; g.fillRect(24, 24, w - 48, h - 48);
    g.fillStyle = '#fffaf0'; g.fillRect(70, 70, w - 140, h - 140);
  });
  ceilTex.repeat.set(60, 60);
  const ceil = new THREE.Mesh(new THREE.PlaneGeometry(1000, 1000), new THREE.MeshStandardMaterial({ map: ceilTex, emissiveMap: ceilTex, emissive: 0xfff3dc, emissiveIntensity: 0.35, roughness: 0.8 }));
  ceil.rotation.x = Math.PI / 2; ceil.position.set(0, CEIL, 60);
  scene.add(ceil);

  // Chandeliers: rings of glowing globes in rows over the tracks
  const glow = new THREE.MeshStandardMaterial({ color: 0xffffff, emissive: 0xffd9a0, emissiveIntensity: 2.2 });
  const globeG = new THREE.SphereGeometry(0.45, 12, 8);
  const globes = [];
  for (const path of all) along(path, 26, (p) => {
    for (let k = 0; k < 10; k++) {
      const a = k / 10 * Math.PI * 2;
      globes.push([p.x + Math.cos(a) * 3.2, p.y + 17 + (k % 2) * 0.8, p.z + Math.sin(a) * 3.2]);
    }
  }, 8);
  const gl = new THREE.InstancedMesh(globeG, glow, globes.length);
  globes.forEach((g3, i) => { m4.compose(vp.set(...g3), q.identity(), vs.set(1, 1, 1)); gl.setMatrixAt(i, m4); });
  scene.add(gl);
  const cordMat = new THREE.MeshStandardMaterial({ color: 0x222222 });
  for (const path of all) along(path, 26, (p) => {
    const cord = new THREE.Mesh(new THREE.CylinderGeometry(0.04, 0.04, CEIL - p.y - 17, 4), cordMat);
    cord.position.set(p.x, (CEIL + p.y + 17) / 2, p.z); scene.add(cord);
    const ring = new THREE.Mesh(new THREE.TorusGeometry(3.2, 0.08, 6, 40), brass);
    ring.rotation.x = Math.PI / 2; ring.position.set(p.x, p.y + 17.4, p.z); scene.add(ring);
  }, 8);

  // Light shafts from the skylights (soft additive slabs)
  const shaftTex = canvasTex(64, 256, (g, w, h) => {
    const gr = g.createLinearGradient(0, 0, 0, h);
    gr.addColorStop(0, 'rgba(255,244,220,0.5)'); gr.addColorStop(1, 'rgba(255,244,220,0)');
    g.fillStyle = gr; g.fillRect(0, 0, w, h);
  }, { repeat: false });
  const shaftMat = new THREE.MeshBasicMaterial({ map: shaftTex, transparent: true, opacity: 0.35, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide, fog: false });
  shaftMat.opacity = 0.14;
  for (const path of all) along(path, 37, (p) => {
    const s = new THREE.Mesh(new THREE.PlaneGeometry(7, CEIL), shaftMat);
    s.position.set(p.x + 6, CEIL / 2, p.z); s.rotation.set(0, p.h + 0.6, 0.32);
    scene.add(s);
  }, 20);

  // Left fork: a tunnel of book arches (books stacked into half rings)
  const archTex = bookTex(9); archTex.repeat.set(10, 1);
  const archMat = new THREE.MeshStandardMaterial({ map: archTex, roughness: 0.8 });
  const archG = new THREE.TorusGeometry(ROAD_HALF + 1.2, 1.3, 10, 40, Math.PI);
  const arc = Math.PI * 36;
  along(P.left, 3.2, (p, s) => {
    if (s < arc + 6 || s > arc + 122) return;
    const a = new THREE.Mesh(archG, archMat);
    a.position.set(p.x, p.y, p.z); a.rotation.y = p.h;
    a.castShadow = a.receiveShadow = true;
    scene.add(a);
  });
  const lampMat = new THREE.MeshStandardMaterial({ color: 0xffffff, emissive: 0xffc070, emissiveIntensity: 3 });
  along(P.left, 9.6, (p, s) => {
    if (s < arc + 8 || s > arc + 120) return;
    const r = rightOf(p.h);
    for (const side of [-1, 1]) {
      const l = new THREE.Mesh(new THREE.SphereGeometry(0.35, 10, 8), lampMat);
      l.position.set(p.x + r.x * (ROAD_HALF - 0.4) * side, p.y + 6.5, p.z + r.z * (ROAD_HALF - 0.4) * side);
      scene.add(l);
    }
  });

  // Right fork: glass balustrades and brass rails along the ramp up to the mezzanine
  const glass = new THREE.MeshPhysicalMaterial({ color: 0xdfeee9, transmission: 0, transparent: true, opacity: 0.22, roughness: 0.05, metalness: 0, side: THREE.DoubleSide });
  for (const side of [-1, 1]) {
    const gp = [], gi = [], rp = [];
    const n = Math.floor(P.right.len);
    for (let i = 0; i <= n; i++) {
      const p = at(P.right, i), r = rightOf(p.h);
      const x = p.x + r.x * (ROAD_HALF - 0.1) * side, z = p.z + r.z * (ROAD_HALF - 0.1) * side;
      gp.push(x, p.y, z, x, p.y + 1.2, z);
      rp.push(new THREE.Vector3(x, p.y + 1.25, z));
      if (i < n) { const a = i * 2; gi.push(a, a + 1, a + 2, a + 1, a + 3, a + 2); }
    }
    const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(gp, 3)); g.setIndex(gi); g.computeVertexNormals();
    scene.add(new THREE.Mesh(g, glass));
    scene.add(new THREE.Mesh(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(rp.filter((_, i) => i % 4 === 0)), 400, 0.06, 6), brass));
  }

  // Reading tables with green lamps, and globes on stands, in the open floor between tracks
  const tableMat = new THREE.MeshStandardMaterial({ color: 0x4a2c18, roughness: 0.4 });
  const lampShade = new THREE.MeshStandardMaterial({ color: 0x1f6b3a, emissive: 0x2a8a4a, emissiveIntensity: 0.6, roughness: 0.3 });
  const globeMat = new THREE.MeshStandardMaterial({ color: 0x3b6e8f, roughness: 0.5, metalness: 0.1 });
  for (let k = 0; k < 900; k++) {
    const x = (R() - 0.5) * 300, z = (R() - 0.5) * 300 + 60;
    const f = field(x, z, 6);
    if (f.d < ROAD_HALF + 2 || f.d > ROAD_HALF + 4.4) continue;
    if (R() < 0.75) continue;
    const g = new THREE.Group();
    if (R() < 0.7) {
      const top = new THREE.Mesh(new THREE.BoxGeometry(3, 0.12, 1.4), tableMat); top.position.y = 0.8; g.add(top);
      for (const [a, b] of [[-1.3, -0.55], [1.3, -0.55], [-1.3, 0.55], [1.3, 0.55]]) { const leg = new THREE.Mesh(new THREE.BoxGeometry(0.1, 0.8, 0.1), tableMat); leg.position.set(a, 0.4, b); g.add(leg); }
      const shade = new THREE.Mesh(new THREE.CylinderGeometry(0.12, 0.3, 0.25, 12, 1, true), lampShade); shade.position.set(0, 1.25, 0); g.add(shade);
    } else {
      const ball = new THREE.Mesh(new THREE.SphereGeometry(0.7, 20, 14), globeMat); ball.position.y = 1.5; g.add(ball);
      const stand = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.4, 0.9, 10), brass); stand.position.y = 0.45; g.add(stand);
    }
    g.position.set(x, 0, z); g.rotation.y = R() * 6;
    g.traverse((o) => { o.castShadow = true; });
    scene.add(g);
  }

  // Dust motes drifting in the light
  const dustTex = canvasTex(32, 32, (g, w) => { const gr = g.createRadialGradient(16, 16, 0, 16, 16, 16); gr.addColorStop(0, 'rgba(255,240,210,1)'); gr.addColorStop(1, 'rgba(255,240,210,0)'); g.fillStyle = gr; g.fillRect(0, 0, w, w); }, { repeat: false });
  const dn = 2500, dp = new Float32Array(dn * 3);
  const dustBase = [];
  for (let i = 0; i < dn; i++) {
    const path = all[i % 3], p = at(path, R() * path.len), r = rightOf(p.h), off = (R() - 0.5) * 30;
    dustBase.push([p.x + r.x * off, p.y + 1 + R() * 20, p.z + r.z * off, R() * 6]);
  }
  const dg = new THREE.BufferGeometry(); dg.setAttribute('position', new THREE.BufferAttribute(dp, 3));
  const dust = new THREE.Points(dg, new THREE.PointsMaterial({ map: dustTex, size: 0.12, transparent: true, opacity: 0.7, depthWrite: false, blending: THREE.AdditiveBlending }));
  scene.add(dust);

  stage.update = (t) => {
    const cam = stage.camera.position;
    sunL.position.set(cam.x + sunDir.x * 120, cam.y + sunDir.y * 120, cam.z + sunDir.z * 120);
    sunL.target.position.set(cam.x, 0, cam.z + 20);
    sunL.target.updateMatrixWorld();
    dustBase.forEach((d, i) => { dp[i * 3] = d[0] + Math.sin(t * 0.3 + d[3]) * 0.6; dp[i * 3 + 1] = d[1] + Math.sin(t * 0.2 + d[3] * 2) * 0.5; dp[i * 3 + 2] = d[2] + Math.cos(t * 0.25 + d[3]) * 0.6; });
    dg.attributes.position.needsUpdate = true;
  };
}
