// Build the viewmodel hands from the CC0 Innerscene "Posable anatomical hand".
//
// The source is a single hand cropped from the MakeHuman body: the skin sits in the
// standard MakeHuman UV block and the sixteen bone names already match the ones this
// project poses with (hand_r, index_01_r ... thumb_03_r).
//
// The crop left the whole rig under a node whose matrix has a negative determinant.
// That is harmless for a static prop and poison for a viewmodel: the vertices are
// stored mirrored against the joints, so a product placed from the bone positions
// lands on the far side of the rendered palm. This script drops that scale, which
// flips the skin into the same space as the bones, and rebuilds whatever the flip
// invalidates:
//
//   * the rig node becomes a pure rotation (or identity), so no node in the file has
//     a negative determinant and Godot's Skeleton3D space is the space the hand is
//     drawn in,
//   * the right hand keeps the original inverse bind matrices - they already encode
//     the old mirror, which is exactly what puts the skin back on the joints,
//   * the left hand is a true mirror: every joint local is conjugated by the mirror
//     (M * L * M) and every inverse bind matrix is pre-multiplied by it, which keeps
//     the determinants positive and leaves positive-X flexion folding toward the
//     palm on both hands,
//   * the rig gets a presentation rotation that leaves the fingers along -Z with the
//     palm up, only so the asset opens in a readable pose.
//
// Usage: node build_hands.js <source.glb> <out_right.glb> <out_left.glb>

const fs = require('fs');
const { NodeIO } = require('@gltf-transform/core');
const { ALL_EXTENSIONS } = require('@gltf-transform/extensions');

const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
const [srcPath, outRight, outLeft] = process.argv.slice(2);
if (!srcPath || !outRight || !outLeft) {
  console.error('usage: node build_hands.js <source.glb> <out_right.glb> <out_left.glb>');
  process.exit(1);
}

const IDENT = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];
const MIRROR = [-1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];

// ---------------------------------------------------------------- 4x4 helpers
// Column-major, matching the glTF accessor layout.
function mul(a, b) {
  const out = new Array(16).fill(0);
  for (let c = 0; c < 4; c++) {
    for (let r = 0; r < 4; r++) {
      let sum = 0;
      for (let k = 0; k < 4; k++) sum += a[k * 4 + r] * b[c * 4 + k];
      out[c * 4 + r] = sum;
    }
  }
  return out;
}

function det3(m) {
  return m[0] * (m[5] * m[10] - m[6] * m[9])
    - m[4] * (m[1] * m[10] - m[2] * m[9])
    + m[8] * (m[1] * m[6] - m[2] * m[5]);
}

function invert(m) {
  const a = m;
  const s0 = a[0] * a[5] - a[4] * a[1];
  const s1 = a[0] * a[6] - a[4] * a[2];
  const s2 = a[0] * a[7] - a[4] * a[3];
  const s3 = a[1] * a[6] - a[5] * a[2];
  const s4 = a[1] * a[7] - a[5] * a[3];
  const s5 = a[2] * a[7] - a[6] * a[3];
  const c5 = a[10] * a[15] - a[14] * a[11];
  const c4 = a[9] * a[15] - a[13] * a[11];
  const c3 = a[9] * a[14] - a[13] * a[10];
  const c2 = a[8] * a[15] - a[12] * a[11];
  const c1 = a[8] * a[14] - a[12] * a[10];
  const c0 = a[8] * a[13] - a[12] * a[9];
  const det = s0 * c5 - s1 * c4 + s2 * c3 + s3 * c2 - s4 * c1 + s5 * c0;
  if (Math.abs(det) < 1e-12) throw new Error('singular matrix');
  const d = 1 / det;
  const out = new Array(16).fill(0);
  out[0] = (a[5] * c5 - a[6] * c4 + a[7] * c3) * d;
  out[4] = (-a[4] * c5 + a[6] * c2 - a[7] * c1) * d;
  out[8] = (a[4] * c4 - a[5] * c2 + a[7] * c0) * d;
  out[12] = (-a[4] * c3 + a[5] * c1 - a[6] * c0) * d;
  out[1] = (-a[1] * c5 + a[2] * c4 - a[3] * c3) * d;
  out[5] = (a[0] * c5 - a[2] * c2 + a[3] * c1) * d;
  out[9] = (-a[0] * c4 + a[1] * c2 - a[3] * c0) * d;
  out[13] = (a[0] * c3 - a[1] * c1 + a[2] * c0) * d;
  out[2] = (a[1] * s5 - a[2] * s4 + a[3] * s3) * d;
  out[6] = (-a[0] * s5 + a[2] * s2 - a[3] * s1) * d;
  out[10] = (a[0] * s4 - a[1] * s2 + a[3] * s0) * d;
  out[14] = (-a[0] * s3 + a[1] * s1 - a[2] * s0) * d;
  out[3] = (-a[1] * a[10] * a[15] + a[1] * a[14] * a[11] + a[9] * a[2] * a[15]
    - a[9] * a[14] * a[3] - a[13] * a[2] * a[11] + a[13] * a[3] * a[10]) * d;
  out[7] = (a[0] * a[10] * a[15] - a[0] * a[14] * a[11] - a[8] * a[2] * a[15]
    + a[8] * a[14] * a[3] + a[12] * a[2] * a[11] - a[12] * a[3] * a[10]) * d;
  out[11] = (-a[0] * a[6] * a[15] + a[0] * a[14] * a[7] + a[8] * a[1] * a[15]
    - a[8] * a[14] * a[3] - a[12] * a[1] * a[7] + a[12] * a[3] * a[6]) * d;
  out[15] = (a[0] * a[6] * a[11] - a[0] * a[10] * a[7] - a[8] * a[1] * a[11]
    + a[8] * a[10] * a[3] + a[12] * a[1] * a[7] - a[12] * a[3] * a[6]) * d;
  return out;
}

function worldMatrix(node) {
  let m = node.getMatrix();
  let parent = node.getParentNode();
  while (parent) {
    m = mul(parent.getMatrix(), m);
    parent = parent.getParentNode();
  }
  return m;
}

function transpose(m) {
  return [
    m[0], m[4], m[8], m[12],
    m[1], m[5], m[9], m[13],
    m[2], m[6], m[10], m[14],
    m[3], m[7], m[11], m[15],
  ];
}

function rotX(rad) {
  const c = Math.cos(rad);
  const s = Math.sin(rad);
  return [1, 0, 0, 0, 0, c, s, 0, 0, -s, c, 0, 0, 0, 0, 1];
}

function conj(m) {
  return mul(mul(MIRROR, m), MIRROR);
}

// ---------------------------------------------------------------- vector helpers
const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
const cross = (a, b) => [
  a[1] * b[2] - a[2] * b[1],
  a[2] * b[0] - a[0] * b[2],
  a[0] * b[1] - a[1] * b[0],
];
const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
function norm(v) {
  const l = Math.hypot(v[0], v[1], v[2]);
  return l < 1e-9 ? [0, 0, 0] : [v[0] / l, v[1] / l, v[2] / l];
}

// Chain of a joint measured from the first non-joint ancestor, which is the rig.
// `spin` optionally composes an extra local rotation onto one bone without touching
// the document.
function jointChain(node, jointSet, spinNode, spin) {
  const chain = [];
  let p = node;
  while (p && jointSet.has(p)) {
    chain.unshift(p);
    p = p.getParentNode();
  }
  let m = IDENT;
  for (const j of chain) {
    let local = j.getMatrix();
    if (j === spinNode) local = mul(local, spin);
    m = mul(m, local);
  }
  return m;
}

const originOf = (m) => [m[12], m[13], m[14]];

function jointNamed(joints, name) {
  const j = joints.find((n) => n.getName() === name);
  if (!j) throw new Error('joint not found: ' + name);
  return j;
}

// Which way the fingers fold. Positive rotation about a bone-local X is flexion on
// this rig, so the direction the middle phalanx sweeps is the palm side. Measuring
// it beats guessing from a cross product whose sign depends on the export.
function palmSide(joints, jointSet, side) {
  const i2 = jointNamed(joints, 'index_02_' + side);
  const i3 = jointNamed(joints, 'index_03_' + side);
  const rest = originOf(jointChain(i3, jointSet));
  const bent = originOf(jointChain(i3, jointSet, i2, rotX(0.25)));
  return norm(sub(bent, rest));
}

function anatomy(joints, jointSet, side) {
  const knuckle = originOf(jointChain(jointNamed(joints, 'index_01_' + side), jointSet));
  const tip = originOf(jointChain(jointNamed(joints, 'index_02_' + side), jointSet));
  const wrist = originOf(jointChain(jointNamed(joints, 'hand_' + side), jointSet));
  const thumb = originOf(jointChain(jointNamed(joints, 'thumb_03_' + side), jointSet));
  const pinky = originOf(jointChain(jointNamed(joints, 'pinky_01_' + side), jointSet));
  const fwd = norm(sub(tip, knuckle));
  let palm = palmSide(joints, jointSet, side);
  palm = norm(sub(palm, [fwd[0] * dot(palm, fwd), fwd[1] * dot(palm, fwd), fwd[2] * dot(palm, fwd)]));
  const across = norm(cross(fwd, palm));
  const thumbSide = dot(norm(sub(thumb, wrist)), across);
  return {
    fwd,
    palm,
    across,
    thumbSide,
    span: Math.hypot(...sub(knuckle, wrist)),
    width: Math.hypot(...sub(knuckle, pinky)),
  };
}

async function build(sourcePath, outPath, wantRight) {
  const doc = await io.read(sourcePath);
  const root = doc.getRoot();
  const skin = root.listSkins()[0];
  const joints = skin.listJoints();
  const jointSet = new Set(joints);

  const jointRoot = joints.find((j) => !jointSet.has(j.getParentNode()));
  let rig = jointRoot;
  while (rig.getParentNode()) rig = rig.getParentNode();
  const meshNode = root
    .listNodes()
    .find((n) => n.getMesh() && n.getSkin() === skin);
  if (!meshNode) throw new Error('skinned mesh node not found');

  const sourceIbm = Array.from(skin.getInverseBindMatrices().getArray());
  const rigDet = det3(worldMatrix(meshNode));
  if (rigDet > 0) throw new Error('expected a mirrored rig, got det ' + rigDet);

  // The old inverse bind matrices already carry the mirror the rig applies, so
  // dropping the rig matrix is all it takes to put the skin back on the bones.
  const sourceIsLeft = anatomy(joints, jointSet, 'r').thumbSide > 0;
  // The source is a left hand; each output is mirrored only when it has to be.
  const mirror = sourceIsLeft === wantRight;
  if (mirror) {
    for (const j of joints) j.setMatrix(conj(j.getMatrix()));
  }
  const shape = anatomy(joints, jointSet, 'r');
  if (shape.thumbSide > 0 === wantRight) throw new Error('hand came out the wrong way round');

  // Fingers along -Z with the palm up, so the asset opens the same way every run.
  const src = [
    shape.fwd[0], shape.fwd[1], shape.fwd[2], 0,
    shape.palm[0], shape.palm[1], shape.palm[2], 0,
    shape.across[0], shape.across[1], shape.across[2], 0,
    0, 0, 0, 1,
  ];
  const dst = [
    0, 0, -1, 0,
    0, 1, 0, 0,
    1, 0, 0, 0,
    0, 0, 0, 1,
  ];
  rig.setMatrix(mul(dst, transpose(src)));
  meshNode.setMatrix(IDENT);

  if (mirror) {
    const ibm = new Float32Array(joints.length * 16);
    for (let i = 0; i < joints.length; i++) {
      const m = mul(MIRROR, sourceIbm.slice(i * 16, i * 16 + 16));
      for (let k = 0; k < 16; k++) ibm[i * 16 + k] = m[k];
    }
    skin.getInverseBindMatrices().setArray(ibm);
  }

  const side = wantRight ? 'r' : 'l';
  for (const j of joints) {
    j.setName(j.getName().replace(/_[rl]$/, '_' + side));
  }

  await io.write(outPath, doc);

  // ---------------------------------------------------------------- sanity check
  const check = await io.read(outPath);
  const cskin = check.getRoot().listSkins()[0];
  const cjoints = cskin.listJoints();
  const cset = new Set(cjoints);
  const cibm = cskin.getInverseBindMatrices().getArray();
  const cmesh = check.getRoot().listNodes().find((n) => n.getMesh() && n.getSkin() === cskin);
  const meshWorld = worldMatrix(cmesh);
  // Every joint has to produce the same skin matrix, otherwise the hand shears
  // apart at rest. Its value is the transform the stored vertices need to land on
  // the skeleton, so it should be the mirror the old rig used to carry.
  let worst = 0;
  let mirrored = 0;
  let detMin = 1e9;
  let skinAtRest = null;
  cjoints.forEach((j, i) => {
    const w = worldMatrix(j);
    const ibm = Array.from(cibm.slice(i * 16, i * 16 + 16));
    const prod = mul(mul(invert(meshWorld), w), ibm);
    if (!skinAtRest) skinAtRest = prod;
    for (let r = 0; r < 4; r++) {
      for (let c = 0; c < 4; c++) {
        worst = Math.max(worst, Math.abs(prod[c * 4 + r] - skinAtRest[c * 4 + r]));
      }
    }
    detMin = Math.min(detMin, det3(w));
    if (det3(w) < 0) mirrored++;
  });
  const a = anatomy(cjoints, cset, side);
  console.log(
    outPath,
    '| ' + (wantRight ? 'right' : 'left'),
    '| skin error', worst.toExponential(1),
    '| mirrored nodes', mirrored,
    '| min det', detMin.toFixed(3),
    '| wrist->knuckle', a.span.toFixed(4),
    '| knuckles', a.width.toFixed(4),
    '| fingers', a.fwd.map((v) => +v.toFixed(2)).join(','),
    '| palm', a.palm.map((v) => +v.toFixed(2)).join(','),
  );
}

(async () => {
  // The right hand is written over the source, so both builds read from a private
  // copy and the second one is never fed an already-processed file.
  const source = srcPath + '.orig';
  fs.copyFileSync(srcPath, source);
  try {
    await build(source, outRight, true);
    await build(source, outLeft, false);
  } finally {
    fs.rmSync(source, { force: true });
  }
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
