// Fern Rush: an original prehistoric jungle. Red-earth road, giant buttress trees, fern carpets, mossy rocks,
// a volcano, a gorge with a waterfall on the left fork, a ridge of stone ruins on the right fork, long-necked
// dinosaurs grazing on the plain and flyers overhead.
import { THREE, Stage, canvasTex, roadMesh, along } from './stage.js';
import { Sky } from 'three/addons/objects/Sky.js';
import { ROAD_HALF, makeRoadField, rng, noise2, fbm, at, rightOf } from './track.js';

export const world = { name: 'jungle', leftRise: -6, rightRise: 7, bloom: { strength: 0.18, radius: 0.4, threshold: 0.98 } };

function roadTex() {
  return canvasTex(512, 1024, (g, w, h) => {
    const r = rng(7);
    g.fillStyle = '#8a4b2c'; g.fillRect(0, 0, w, h);
    for (let i = 0; i < 26000; i++) {               // packed earth grain
      const v = r();
      g.fillStyle = v < 0.5 ? `rgba(60,28,14,${0.1 + r() * 0.25})` : `rgba(190,120,80,${0.08 + r() * 0.2})`;
      const s = 1 + r() * 3;
      g.fillRect(r() * w, r() * h, s, s);
    }
    for (let i = 0; i < 40; i++) {                   // tyre ruts
      g.strokeStyle = `rgba(50,22,10,${0.05 + r() * 0.08})`;
      g.lineWidth = 6 + r() * 14;
      const x = r() * w;
      g.beginPath(); g.moveTo(x, 0); g.lineTo(x + (r() - 0.5) * 30, h); g.stroke();
    }
    const edge = 22;                                 // stone kerbs
    for (const x0 of [0, w - edge]) {
      for (let y = 0; y < h; y += 32) {
        const l = 140 + r() * 50;
        g.fillStyle = `rgb(${l},${l - 8},${l - 25})`;
        g.fillRect(x0 + 1, y + 1, edge - 2, 30);
        g.fillStyle = 'rgba(40,70,20,0.5)';
        g.fillRect(x0 + 1, y + 26, edge - 2, 5);
      }
    }
    g.fillStyle = 'rgba(255,236,190,0.85)';         // lane lines: crushed shell
    for (let k = 1; k < 5; k++) {
      const x = edge + (w - 2 * edge) * k / 5;
      for (let y = 0; y < h; y += 128) g.fillRect(x - 4, y, 8, 70);
    }
  });
}

function leafTex() {
  return canvasTex(256, 256, (g, w, h) => {
    g.clearRect(0, 0, w, h);
    const r = rng(11);
    g.translate(w / 2, h);
    for (let k = 0; k < 9; k++) {                    // a fern frond fan
      g.save();
      g.rotate((k - 4) * 0.28 + (r() - 0.5) * 0.1);
      const L = h * (0.75 + r() * 0.25);
      g.strokeStyle = '#2d5a1b'; g.lineWidth = 3;
      g.beginPath(); g.moveTo(0, 0); g.lineTo(0, -L); g.stroke();
      for (let y = 10; y < L; y += 7) {
        const ll = (1 - y / L) * 34 + 6, c = 80 + r() * 60;
        g.fillStyle = `rgb(${c * 0.45},${c},${c * 0.3})`;
        for (const s of [-1, 1]) {
          g.beginPath(); g.moveTo(0, -y); g.quadraticCurveTo(s * ll * 0.6, -y - 8, s * ll, -y - 2); g.quadraticCurveTo(s * ll * 0.5, -y + 2, 0, -y + 4); g.fill();
        }
      }
      g.restore();
    }
  }, { repeat: false });
}

function barkTex() {
  return canvasTex(256, 512, (g, w, h) => {
    const r = rng(5);
    g.fillStyle = '#5a4630'; g.fillRect(0, 0, w, h);
    for (let i = 0; i < 260; i++) {
      g.strokeStyle = `rgba(${30 + r() * 40},${25 + r() * 30},${15 + r() * 20},0.6)`;
      g.lineWidth = 2 + r() * 6;
      const x = r() * w;
      g.beginPath(); g.moveTo(x, 0); g.bezierCurveTo(x + 10, h / 3, x - 10, h * 2 / 3, x + (r() - 0.5) * 20, h); g.stroke();
    }
    for (let i = 0; i < 90; i++) { g.fillStyle = `rgba(70,110,40,${r() * 0.5})`; g.fillRect(r() * w, r() * h, 10 + r() * 30, 6 + r() * 20); }
  });
}

export function build(stage) {
  const { scene } = stage, P = stage.paths, all = [P.shared, P.left, P.right];
  const field = makeRoadField(all);
  const R = rng(42), N = noise2(3);

  // Sky, sun, haze
  const sky = new Sky();
  sky.scale.setScalar(4000);
  const sun = new THREE.Vector3().setFromSphericalCoords(1, THREE.MathUtils.degToRad(62), THREE.MathUtils.degToRad(200));
  Object.assign(sky.material.uniforms, {});
  sky.material.uniforms.sunPosition.value.copy(sun);
  sky.material.uniforms.turbidity.value = 10;
  sky.material.uniforms.rayleigh.value = 1.6;
  sky.material.uniforms.mieCoefficient.value = 0.006;
  sky.material.uniforms.mieDirectionalG.value = 0.85;
  scene.add(sky);
  scene.fog = new THREE.FogExp2(0xbfd6c4, 0.0032);
  stage.renderer.toneMappingExposure = 0.85;

  const hemi = new THREE.HemisphereLight(0xdcefff, 0x5a6b34, 1.5);
  scene.add(hemi);
  const sunL = new THREE.DirectionalLight(0xfff0d0, 3.2);
  sunL.castShadow = true;
  sunL.shadow.mapSize.set(2048, 2048);
  Object.assign(sunL.shadow.camera, { left: -70, right: 70, top: 70, bottom: -70, near: 1, far: 400 });
  sunL.shadow.bias = -0.0005;
  scene.add(sunL, sunL.target);

  // Ground: rolling jungle floor that meets the road; hills and cliffs further out.
  const size = 900, seg = 300;
  const gg = new THREE.PlaneGeometry(size, size, seg, seg);
  gg.rotateX(-Math.PI / 2);
  const gp = gg.attributes.position, colors = [];
  const cx = 0, cz = 60;
  for (let i = 0; i < gp.count; i++) {
    const x = gp.getX(i) + cx, z = gp.getZ(i) + cz;
    const f = field(x, z, 10);
    const away = THREE.MathUtils.smoothstep(f.d, ROAD_HALF + 2, ROAD_HALF + 40);
    let hgt = fbm(N, x / 60, z / 60) * 26 - 9;
    hgt += Math.max(0, fbm(N, x / 180 + 9, z / 180) - 0.45) * 220 * THREE.MathUtils.smoothstep(Math.hypot(x, z - 60), 180, 420);
    hgt += fbm(N, x / 7, z / 7, 3) * 1.6;
    const y = f.y - 0.25 + (hgt) * away + (f.y < -1 ? Math.abs(f.y) * 2.2 * THREE.MathUtils.smoothstep(f.d, ROAD_HALF, ROAD_HALF + 10) : 0);
    gp.setY(i, y);
    const m = fbm(N, x / 20 + 4, z / 20, 3);
    const near = 1 - THREE.MathUtils.smoothstep(f.d, ROAD_HALF, ROAD_HALF + 4);
    const c = new THREE.Color().setRGB(0.16 + m * 0.14, 0.34 + m * 0.2, 0.06 + m * 0.05);
    c.lerp(new THREE.Color(0.34, 0.2, 0.1), near * 0.8);
    if (y > 45) c.lerp(new THREE.Color(0.35, 0.33, 0.3), THREE.MathUtils.smoothstep(y, 45, 80));
    colors.push(c.r, c.g, c.b);
  }
  gg.computeVertexNormals();
  const gn = gg.attributes.normal, rockC = new THREE.Color(0.17, 0.14, 0.11), tmpC = new THREE.Color();
  for (let i = 0; i < gp.count; i++) {                    // steep ground shows rock strata instead of grass
    const steep = THREE.MathUtils.smoothstep(1 - gn.getY(i), 0.12, 0.35);
    if (steep <= 0) continue;
    const band = 0.85 + 0.3 * Math.sin(gp.getY(i) * 1.7 + N(gp.getX(i) / 9, gp.getZ(i) / 9) * 4);
    tmpC.setRGB(colors[i * 3], colors[i * 3 + 1], colors[i * 3 + 2]).lerp(rockC.clone().multiplyScalar(band), steep);
    colors[i * 3] = tmpC.r; colors[i * 3 + 1] = tmpC.g; colors[i * 3 + 2] = tmpC.b;
  }
  gg.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
  const ground = new THREE.Mesh(gg, new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.95 }));
  ground.position.set(cx, 0, cz);
  ground.receiveShadow = true;
  scene.add(ground);
  const groundY = (x, z) => {
    const f = field(x, z, 10);
    const away = THREE.MathUtils.smoothstep(f.d, ROAD_HALF + 2, ROAD_HALF + 40);
    return f.y - 0.25 + (fbm(N, x / 60, z / 60) * 26 - 9) * away;
  };

  // Road
  const rt = roadTex();
  const roadMat = new THREE.MeshStandardMaterial({ map: rt, roughness: 0.9 });
  const rockMat = new THREE.MeshStandardMaterial({ color: 0x6e6559, roughness: 0.95, flatShading: true });
  for (const p of all) scene.add(roadMesh(p, roadMat, { texLen: 14, skirt: -12, skirtMat: rockMat }));

  // Giant trees: buttress trunks + clustered canopies (instanced)
  const bark = barkTex();
  const trunkG = new THREE.CylinderGeometry(0.7, 2.2, 1, 9, 6, true);
  trunkG.translate(0, 0.5, 0);
  const tp = trunkG.attributes.position;
  for (let i = 0; i < tp.count; i++) {                  // flare and buttress ridges near the base
    const y = tp.getY(i), a = Math.atan2(tp.getZ(i), tp.getX(i));
    const k = 1 + Math.pow(1 - y, 4) * (0.8 + 0.6 * Math.max(0, Math.cos(a * 5)));
    tp.setX(i, tp.getX(i) * k); tp.setZ(i, tp.getZ(i) * k);
  }
  trunkG.computeVertexNormals();
  const canopyG = new THREE.IcosahedronGeometry(1, 2);
  const cp = canopyG.attributes.position;
  for (let i = 0; i < cp.count; i++) { const v = new THREE.Vector3().fromBufferAttribute(cp, i); v.multiplyScalar(0.8 + N(v.x * 3 + 5, v.z * 3 + v.y * 2) * 0.45); cp.setXYZ(i, v.x, v.y * 0.6, v.z); }
  canopyG.computeVertexNormals();
  const trees = [];
  for (let k = 0; k < 2600 && trees.length < 420; k++) {
    const x = (R() - 0.5) * 760, z = (R() - 0.5) * 760 + 60;
    const f = field(x, z, 10);
    if (f.d < ROAD_HALF + 12 || f.d > 220) continue;
    if (f.d < 40 && R() < 0.55) continue;
    trees.push({ x, z, y: groundY(x, z), h: 26 + R() * 30, s: 0.8 + R() * 0.7 });
  }
  const trunks = new THREE.InstancedMesh(trunkG, new THREE.MeshStandardMaterial({ map: bark, roughness: 0.95 }), trees.length);
  const canopies = new THREE.InstancedMesh(canopyG, new THREE.MeshStandardMaterial({ color: 0x3f7a2a, roughness: 0.85 }), trees.length * 4);
  const m4 = new THREE.Matrix4(), q = new THREE.Quaternion(), e = new THREE.Euler(), vs = new THREE.Vector3(), vp = new THREE.Vector3();
  trees.forEach((t, i) => {
    m4.compose(vp.set(t.x, t.y - 0.5, t.z), q.setFromEuler(e.set(0, R() * 6, 0)), vs.set(t.s, t.h, t.s));
    trunks.setMatrixAt(i, m4);
    for (let j = 0; j < 4; j++) {
      const r = (5 + R() * 6) * t.s, a = R() * 6.28, off = j === 0 ? 0 : 4 + R() * 4;
      m4.compose(vp.set(t.x + Math.cos(a) * off, t.y + t.h - 2 + R() * 4 - j, t.z + Math.sin(a) * off), q.setFromEuler(e.set(0, R() * 6, 0)), vs.set(r * 1.3, r, r * 1.3));
      canopies.setMatrixAt(i * 4 + j, m4);
      canopies.setColorAt(i * 4 + j, new THREE.Color().setHSL(0.26 + R() * 0.06, 0.55, 0.18 + R() * 0.12));
    }
  });
  trunks.castShadow = trunks.receiveShadow = canopies.castShadow = canopies.receiveShadow = true;
  scene.add(trunks, canopies);

  // Ferns: crossed alpha cards, thousands of them
  const fernG = new THREE.PlaneGeometry(1, 1);
  fernG.translate(0, 0.5, 0);
  const fernG2 = fernG.clone().rotateY(Math.PI / 2);
  const fernMat = new THREE.MeshStandardMaterial({ map: leafTex(), alphaTest: 0.45, side: THREE.DoubleSide, roughness: 0.8 });
  const ferns = [];
  for (let k = 0; k < 60000 && ferns.length < 9000; k++) {
    const x = (R() - 0.5) * 520, z = (R() - 0.5) * 520 + 60;
    const f = field(x, z, 6);
    if (f.d < ROAD_HALF + 0.6 || f.d > 70) continue;
    ferns.push({ x, z, y: groundY(x, z), s: 1.2 + R() * 2.6 * Math.min(1, (f.d - ROAD_HALF) / 6 + 0.3) });
  }
  for (const geo of [fernG, fernG2]) {
    const im = new THREE.InstancedMesh(geo, fernMat, ferns.length);
    ferns.forEach((f, i) => {
      m4.compose(vp.set(f.x, f.y - 0.1, f.z), q.setFromEuler(e.set(0, R() * 6.28, 0)), vs.set(f.s * 1.6, f.s, f.s * 1.6));
      im.setMatrixAt(i, m4);
      im.setColorAt(i, new THREE.Color().setHSL(0.24 + R() * 0.08, 0.5, 0.45 + R() * 0.3));
    });
    im.castShadow = true; im.receiveShadow = true;
    scene.add(im);
  }

  // Mossy boulders
  const rockG = new THREE.DodecahedronGeometry(1, 1);
  const rp = rockG.attributes.position;
  for (let i = 0; i < rp.count; i++) { const v = new THREE.Vector3().fromBufferAttribute(rp, i); v.multiplyScalar(0.75 + N(v.x * 2 + 1, v.y * 2 + v.z) * 0.5); rp.setXYZ(i, v.x, v.y, v.z); }
  rockG.computeVertexNormals();
  const rocks = new THREE.InstancedMesh(rockG, new THREE.MeshStandardMaterial({ color: 0x777064, roughness: 0.9, flatShading: true }), 260);
  for (let i = 0; i < 260; i++) {
    let x, z, f;
    do { x = (R() - 0.5) * 500; z = (R() - 0.5) * 500 + 60; f = field(x, z, 8); } while (f.d < ROAD_HALF + 1.5 || f.d > 80);
    const s = 0.8 + R() * R() * 6;
    m4.compose(vp.set(x, groundY(x, z) + s * 0.2, z), q.setFromEuler(e.set(R(), R() * 6, R())), vs.set(s * 1.3, s, s));
    rocks.setMatrixAt(i, m4);
    rocks.setColorAt(i, new THREE.Color().setHSL(0.15 + R() * 0.1, 0.15, 0.3 + R() * 0.15));
  }
  rocks.castShadow = rocks.receiveShadow = true;
  scene.add(rocks);

  // Volcano with a smoke plume
  const vg = new THREE.ConeGeometry(160, 230, 64, 24, true);
  const vpz = vg.attributes.position;
  for (let i = 0; i < vpz.count; i++) {
    const x = vpz.getX(i), y = vpz.getY(i), z = vpz.getZ(i), a = Math.atan2(z, x);
    const k = 1 + (fbm(N, a * 3 + 20, y / 40) - 0.5) * 0.35;
    vpz.setX(i, x * k); vpz.setZ(i, z * k);
    if (y > 100) { vpz.setX(i, x * k * 1.25); vpz.setZ(i, z * k * 1.25); }
  }
  vg.computeVertexNormals();
  const volcano = new THREE.Mesh(vg, new THREE.MeshStandardMaterial({ color: 0x4a4038, roughness: 1, flatShading: true }));
  volcano.position.set(-150, 70, 620);
  scene.add(volcano);
  const lava = new THREE.Mesh(new THREE.CircleGeometry(38, 24), new THREE.MeshBasicMaterial({ color: 0xff6a1a }));
  lava.rotation.x = -Math.PI / 2; lava.position.set(-150, 182, 620);
  scene.add(lava);
  const smokeTex = canvasTex(128, 128, (g, w) => {
    const gr = g.createRadialGradient(w / 2, w / 2, 4, w / 2, w / 2, w / 2);
    gr.addColorStop(0, 'rgba(255,255,255,0.9)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = gr; g.fillRect(0, 0, w, w);
  }, { repeat: false });
  const puffs = [];
  for (let i = 0; i < 26; i++) {
    const sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: smokeTex, color: 0x8c8880, transparent: true, opacity: 0.55, depthWrite: false, fog: true }));
    scene.add(sp); puffs.push({ sp, o: i / 26, r: R() });
  }

  // Gorge waterfall on the left fork's back straight
  const waterTex = canvasTex(128, 512, (g, w, h) => {
    const r = rng(9);
    g.fillStyle = '#9fc9d6'; g.fillRect(0, 0, w, h);
    for (let i = 0; i < 900; i++) { g.fillStyle = `rgba(255,255,255,${r() * 0.7})`; g.fillRect(r() * w, r() * h, 1 + r() * 3, 10 + r() * 60); }
  });
  waterTex.repeat.set(3, 1);
  const falls = [];
  const lp = at(P.left, Math.PI * 36 + 50), lr = rightOf(lp.h);
  for (const side of [-1, 1]) {
    const cliffX = lp.x + lr.x * side * 30, cliffZ = lp.z + lr.z * side * 30;
    const cliff = new THREE.Mesh(new THREE.BoxGeometry(14, 48, 70, 4, 12, 16), rockMat);
    const cpos = cliff.geometry.attributes.position;
    for (let i = 0; i < cpos.count; i++) cpos.setX(i, cpos.getX(i) + (N(cpos.getY(i) / 5, cpos.getZ(i) / 5) - 0.5) * 6);
    cliff.geometry.computeVertexNormals();
    cliff.position.set(cliffX, lp.y + 10, cliffZ);
    cliff.rotation.y = lp.h;
    cliff.castShadow = cliff.receiveShadow = true;
    scene.add(cliff);
    if (side === 1) {
      const wf = new THREE.Mesh(new THREE.PlaneGeometry(16, 40), new THREE.MeshStandardMaterial({ map: waterTex, transparent: true, opacity: 0.92, roughness: 0.2, emissive: 0x334a55 }));
      wf.position.set(lp.x + lr.x * 22.5, lp.y + 14, lp.z + lr.z * 22.5);
      wf.rotation.y = lp.h - Math.PI / 2;
      scene.add(wf); falls.push(wf);
      const mist = new THREE.Sprite(new THREE.SpriteMaterial({ map: smokeTex, color: 0xffffff, transparent: true, opacity: 0.5, depthWrite: false }));
      mist.scale.set(26, 14, 1); mist.position.set(lp.x + lr.x * 18, lp.y - 2, lp.z + lr.z * 18);
      scene.add(mist);
    }
  }

  // Ruins on the right fork's climb: stone arches spanning the road, broken columns
  const stone = new THREE.MeshStandardMaterial({ color: 0x9b917c, roughness: 0.9, flatShading: true });
  const moss = new THREE.MeshStandardMaterial({ color: 0x4d6b2c, roughness: 1 });
  along(P.right, 34, (p, s) => {
    if (s < 100 || s > 240) return;
    const r = rightOf(p.h), g = new THREE.Group();
    const half = ROAD_HALF + 1.5;
    for (const side of [-1, 1]) {
      const col = new THREE.Mesh(new THREE.BoxGeometry(2.2, 13, 2.2), stone);
      col.position.set(r.x * half * side, 6.5, r.z * half * side);
      col.rotation.y = p.h;
      col.castShadow = true;
      g.add(col);
    }
    const lintel = new THREE.Mesh(new THREE.BoxGeometry(half * 2 + 3, 2.4, 2.6), stone);
    lintel.position.y = 13.6; lintel.rotation.y = p.h; lintel.castShadow = true;
    g.add(lintel);
    const mossTop = new THREE.Mesh(new THREE.BoxGeometry(half * 2 + 3.2, 0.5, 2.8), moss);
    mossTop.position.y = 15; mossTop.rotation.y = p.h;
    g.add(mossTop);
    g.position.set(p.x, p.y, p.z);
    scene.add(g);
  }, 0);
  for (let i = 0; i < 40; i++) {
    const s = 90 + R() * 180, p = at(P.right, s), r = rightOf(p.h), side = R() < 0.5 ? -1 : 1, off = ROAD_HALF + 4 + R() * 14;
    const h = 3 + R() * 9;
    const col = new THREE.Mesh(new THREE.CylinderGeometry(1, 1.1, h, 10), stone);
    const x = p.x + r.x * off * side, z = p.z + r.z * off * side;
    col.position.set(x, groundY(x, z) + h / 2 - 0.5, z);
    col.rotation.set((R() - 0.5) * 0.2, 0, (R() - 0.5) * 0.2);
    col.castShadow = true;
    scene.add(col);
  }

  // Long-necked grazers on the plain and flyers in the sky (original designs)
  const skin = new THREE.MeshStandardMaterial({ color: 0x6f6a58, roughness: 0.85 });
  function grazer(scale) {
    const g = new THREE.Group();
    const body = new THREE.Mesh(new THREE.SphereGeometry(1, 20, 14), skin);
    body.scale.set(2.2, 1.5, 4.2); body.position.y = 4.6; g.add(body);
    const neckPts = [new THREE.Vector3(0, 5, 3), new THREE.Vector3(0, 8.5, 6), new THREE.Vector3(0, 12.5, 7.2), new THREE.Vector3(0, 14.5, 8.8)];
    const neck = new THREE.Mesh(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(neckPts), 20, 0.75, 10), skin);
    const head = new THREE.Mesh(new THREE.SphereGeometry(0.9, 12, 10), skin);
    head.scale.set(0.8, 0.7, 1.4); head.position.copy(neckPts[3]).add(new THREE.Vector3(0, 0, 0.6));
    const neckG = new THREE.Group(); neckG.add(neck, head); g.add(neckG);
    const tail = new THREE.Mesh(new THREE.TubeGeometry(new THREE.CatmullRomCurve3([new THREE.Vector3(0, 5, -3.5), new THREE.Vector3(0, 4, -7), new THREE.Vector3(0.5, 2.5, -11), new THREE.Vector3(1.5, 1.5, -14)]), 20, 0.6, 8), skin);
    g.add(tail);
    const legs = [];
    for (const [lx, lz] of [[1.2, 2.2], [-1.2, 2.2], [1.2, -2.2], [-1.2, -2.2]]) {
      const leg = new THREE.Mesh(new THREE.CylinderGeometry(0.55, 0.65, 4.4, 10), skin);
      leg.geometry.translate(0, -2.2, 0);
      leg.position.set(lx, 4.4, lz); g.add(leg); legs.push(leg);
    }
    g.traverse((o) => { o.castShadow = true; });
    g.scale.setScalar(scale);
    return { g, neckG, legs };
  }
  const herd = [];
  for (const [x, z, h, sc] of [[-150, 150, 1.2, 1.4], [-175, 200, 1.6, 1.1], [-120, 230, 0.9, 1.25], [160, 40, -1.2, 1.3], [140, -20, -0.8, 1.0], [200, 230, 2.4, 1.5]]) {
    const d = grazer(sc);
    d.g.position.set(x, groundY(x, z) - 0.3, z);
    d.g.rotation.y = h;
    scene.add(d.g); herd.push({ ...d, x, z, h, ph: R() * 6 });
  }
  const wingMat = new THREE.MeshStandardMaterial({ color: 0x5b3a2a, side: THREE.DoubleSide, roughness: 0.8 });
  const flyers = [];
  for (let i = 0; i < 5; i++) {
    const g = new THREE.Group();
    const body = new THREE.Mesh(new THREE.ConeGeometry(0.4, 3, 8), wingMat); body.rotation.x = Math.PI / 2; g.add(body);
    const wl = new THREE.Mesh(new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(0, 0, 1), new THREE.Vector3(0, 0, -1), new THREE.Vector3(5, 0, -0.5)]), wingMat);
    const wr = wl.clone(); wr.scale.x = -1;
    g.add(wl, wr); g.scale.setScalar(1.4);
    scene.add(g); flyers.push({ g, wl, wr, c: new THREE.Vector3(-60 + i * 30, 55 + i * 6, 120 + i * 40), r: 40 + i * 12, ph: i });
  }

  stage.update = (t) => {
    const cam = stage.camera.position;
    sunL.position.set(cam.x + sun.x * 150, cam.y + sun.y * 150, cam.z + sun.z * 150);
    sunL.target.position.set(cam.x, cam.y - 4, cam.z + 0);
    sunL.target.updateMatrixWorld();
    puffs.forEach((p) => {
      const k = (p.o + t * 0.03) % 1;
      p.sp.position.set(-150 + k * 90 + p.r * 20, 190 + k * 160, 620 - k * 30);
      const s = 30 + k * 120; p.sp.scale.set(s, s, 1);
      p.sp.material.opacity = 0.6 * (1 - k);
    });
    waterTex.offset.y = t * 1.4;
    herd.forEach((d) => {
      d.neckG.rotation.x = Math.sin(t * 0.5 + d.ph) * 0.12;
      d.neckG.rotation.y = Math.sin(t * 0.3 + d.ph) * 0.2;
      d.legs.forEach((l, i) => { l.rotation.x = Math.sin(t * 1.2 + d.ph + i * Math.PI / 2) * 0.12; });
    });
    flyers.forEach((f) => {
      const a = t * 0.25 + f.ph;
      f.g.position.set(f.c.x + Math.cos(a) * f.r, f.c.y + Math.sin(t + f.ph) * 3, f.c.z + Math.sin(a) * f.r);
      f.g.rotation.y = -a;
      const flap = Math.sin(t * 5 + f.ph) * 0.6;
      f.wl.rotation.z = flap; f.wr.rotation.z = -flap;
    });
  };
}
