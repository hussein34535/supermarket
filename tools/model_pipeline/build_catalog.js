// Clean The Supermarket — catalog builder.
//
// Optimises every model from the 3D drop into assets/models/catalog/<category>/.
// Pipeline per asset: weld -> simplify (triangle budget) -> per-map texture
// resize -> WebP, with normal + metallicRoughness maps stored losslessly.
//
// Why lossless for those two: lossy WebP on the metal/rough map breaks specular
// highlights on smooth metal (visible as a diagonal crease on the scale tray),
// and normals are cheap enough to keep exact at 1K.
//
// Usage: node build_catalog.js [--only=produce] [--force]
const fs = require('fs');
const path = require('path');
const { NodeIO, getBounds } = require('@gltf-transform/core');
const { ALL_EXTENSIONS } = require('@gltf-transform/extensions');
const { weld, simplify, prune, dedup, textureCompress } = require('@gltf-transform/functions');
const { MeshoptSimplifier } = require('meshoptimizer');
const sharp = require('sharp');

const ROOT = path.resolve(__dirname, '..', '..');
const CATALOG = JSON.parse(fs.readFileSync(path.join(__dirname, 'catalog.json'), 'utf8'));
const OUT_ROOT = path.join(ROOT, CATALOG.out);
const only = (process.argv.find(a => a.startsWith('--only=')) || '').split('=')[1] || '';
const force = process.argv.includes('--force');

const args = process.argv.slice(2);
const opt = { base: 1024, normal: 1024, mr: 512, quality: 90 };
for (const a of args) {
  const m = a.match(/^--(base|normal|mr|quality)=(\d+)$/);
  if (m) opt[m[1]] = parseInt(m[2], 10);
}

const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);

const BUILT_JSON = path.join(__dirname, 'catalog_built.json');
const prevBuilt = new Map();
if (fs.existsSync(BUILT_JSON)) {
  for (const r of JSON.parse(fs.readFileSync(BUILT_JSON, 'utf8'))) {
    prevBuilt.set(r.category + '/' + r.name, r);
  }
}

// How the catalog is exposed to the game. Products get shrunk to the target
// height of their department so a bag of crisps and a milk carton read at a
// similar size on the floor; the two legacy props are folded into the decks so
// nothing in assets/models goes unused.
const TARGET_HEIGHT = {
  produce: 0.24, dairy: 0.26, drinks: 0.28, snacks: 0.24,
  pantry: 0.26, cleaning: 0.30, frozen: 0.24,
};
const EXTRAS = [
  { category: 'produce', name: 'tomato_tray', height: 0.287, path: 'res://assets/models/props/tomato_tray.glb' },
  { category: 'cleaning', name: 'cleaner_bottle', height: 1.040, path: 'res://assets/models/props/cleaner_bottle.glb' },
];
const DEPT_CATEGORIES = {
  0: ['produce'],
  1: ['dairy'],
  2: ['drinks'],
  3: ['snacks', 'pantry'],
  4: ['cleaning'],
  5: ['frozen'],
};
const DEPT_NAMES = ['فواكه', 'ألبان', 'مشروبات', 'سناكس', 'منظفات', 'مجمدات'];
const DEPT_CHANCE = [0.10, 0.10, 0.10, 0.12, 0.16, 0.16];
const CATEGORY_ORDER = ['produce', 'dairy', 'drinks', 'snacks', 'pantry', 'cleaning', 'frozen', 'equipment'];

function countTris(doc) {
  let tris = 0;
  for (const mesh of doc.getRoot().listMeshes()) {
    for (const prim of mesh.listPrimitives()) {
      const idx = prim.getIndices();
      const pos = prim.getAttribute('POSITION');
      if (idx) tris += idx.getCount() / 3;
      else if (pos) tris += pos.getCount() / 3;
    }
  }
  return Math.round(tris);
}

function slotMap(root) {
  const slots = new Map();
  const tag = (tex, name) => {
    if (!tex) return;
    if (!slots.has(tex)) slots.set(tex, new Set());
    slots.get(tex).add(name);
  };
  for (const mat of root.listMaterials()) {
    tag(mat.getBaseColorTexture(), 'base');
    tag(mat.getNormalTexture(), 'normal');
    tag(mat.getMetallicRoughnessTexture(), 'mr');
    tag(mat.getEmissiveTexture(), 'emissive');
    tag(mat.getOcclusionTexture(), 'mr');
  }
  return slots;
}

async function build(entry) {
  const src = path.join(CATALOG.source, entry.file);
  const dstDir = path.join(OUT_ROOT, entry.category);
  const dst = path.join(dstDir, entry.name + '.glb');
  fs.mkdirSync(dstDir, { recursive: true });
  if (!force && fs.existsSync(dst)) {
    const prev = prevBuilt.get(entry.category + '/' + entry.name);
    return {
      ...entry, path: dst, skipped: true,
      height: prev ? prev.height : 0,
      trisOut: prev ? prev.tris : 0,
      bytes: fs.statSync(dst).size,
    };
  }

  const t0 = Date.now();
  const doc = await io.read(src);
  const root = doc.getRoot();
  const trisIn = countTris(doc);

  // --- geometry -------------------------------------------------------------
  await doc.transform(weld(), dedup());
  const trisAfterWeld = countTris(doc);
  const ratio = Math.max(0.02, Math.min(1, entry.target_tris / trisAfterWeld));
  if (ratio < 0.995) {
    await doc.transform(simplify({
      simplifier: MeshoptSimplifier,
      ratio,
      error: entry.category === 'equipment' ? 0.001 : 0.002,
      lockBorder: false,
    }));
  }
  await doc.transform(prune());

  // --- textures -------------------------------------------------------------
  const slots = slotMap(root);
  const keep = new Map(); // texture -> resized source buffer, for lossless re-encode
  for (const tex of root.listTextures()) {
    const s = slots.get(tex) || new Set(['base']);
    let target = opt.base;
    if (s.has('normal')) target = opt.normal;
    else if (s.has('mr')) target = opt.mr;
    let buf = tex.getImage();
    if (!buf) continue;
    const meta = await sharp(buf).metadata();
    if (Math.max(meta.width || 0, meta.height || 0) > target) {
      buf = await sharp(buf)
        .resize({ width: target, height: target, fit: 'fill', kernel: 'lanczos3' })
        .toBuffer();
      tex.setImage(buf);
    }
    if (s.has('normal') || s.has('mr')) keep.set(tex, Buffer.from(buf));
  }
  await doc.transform(textureCompress({ encoder: sharp, targetFormat: 'webp', quality: opt.quality }));
  for (const [tex, buf] of keep) {
    tex.setImage(await sharp(buf).webp({ lossless: true, effort: 6 }).toBuffer());
  }

  // --- normalise pivot: centred on X/Z, base at y = 0 -----------------------
  const scene = root.listScenes()[0];
  const bounds = getBounds(scene);
  const cx = (bounds.min[0] + bounds.max[0]) / 2;
  const cz = (bounds.min[2] + bounds.max[2]) / 2;
  const minY = bounds.min[1];
  for (const node of scene.listChildren()) {
    const t = node.getTranslation();
    node.setTranslation([t[0] - cx, t[1] - minY, t[2] - cz]);
  }
  const height = bounds.max[1] - bounds.min[1];

  await io.write(dst, doc);
  const bytes = fs.statSync(dst).size;

  return {
    ...entry, path: dst, skipped: false,
    trisIn, trisOut: countTris(doc), height, bytes,
    ms: Date.now() - t0,
  };
}

function writeGDScript(summary) {
  const byCat = new Map();
  for (const r of summary) {
    if (r.error || !r.bytes) continue;
    const t = TARGET_HEIGHT[r.category];
    if (!t) continue;
    if (!byCat.has(r.category)) byCat.set(r.category, []);
    byCat.get(r.category).push({
      name: r.name,
      path: r.path,
      scale: r.height > 0 ? +(t / r.height).toFixed(3) : 1,
      height: t,
    });
  }
  for (const e of EXTRAS) {
    const t = TARGET_HEIGHT[e.category];
    byCat.get(e.category)?.push({
      name: e.name, path: e.path, scale: +(t / e.height).toFixed(3), height: t,
    });
  }
  for (const list of byCat.values()) list.sort((a, b) => a.name.localeCompare(b.name));

  const lines = [];
  lines.push('class_name ModelCatalog');
  lines.push('extends RefCounted');
  lines.push('');
  lines.push('# GENERATED by tools/model_pipeline/build_catalog.js — do not edit by hand.');
  lines.push('#');
  lines.push('# One deck per gameplay department. Product.pick() draws from a shuffled');
  lines.push('# deck that only reshuffles once it is empty, so every sculpt is used');
  lines.push('# before any repeat. scale shrinks each model to the department target');
  lines.push('# height; height is the matching collider / pivot height.');
  lines.push('');
  lines.push(`const CHANCE: Array[float] = [${DEPT_CHANCE.map(v => v.toFixed(2)).join(', ')}]`);
  lines.push('');
  lines.push('const DECKS: Dictionary = {');
  for (const [dept, cats] of Object.entries(DEPT_CATEGORIES)) {
    const list = cats.flatMap(c => byCat.get(c) || []);
    lines.push(`\t${dept}: [  # ${DEPT_NAMES[dept]}`);
    for (const m of list) {
      lines.push(`\t\t{"name": "${m.name}", "path": "${m.path}", "scale": ${m.scale.toFixed(3)}, "height": ${m.height.toFixed(2)}},`);
    }
    lines.push('\t],');
  }
  lines.push('}');
  lines.push('');
  lines.push('const EQUIPMENT: Dictionary = {');
  for (const r of summary) {
    if (r.category !== 'equipment' || r.error) continue;
    lines.push(`\t"${r.name}": {"path": "${r.path}"},`);
  }
  lines.push('}');
  lines.push('');
  lines.push('static var _pools: Dictionary = {}');
  lines.push('static var _given: Dictionary = {}');
  lines.push('static var _scenes: Dictionary = {}');
  lines.push('');
  lines.push('');
  lines.push('# Draws the next sculpt for a floor product. The first deck-size draws of');
  lines.push('# every department are guaranteed, so a full run shows each model at least');
  lines.push('# once even when the deck is larger than the expected hero count.');
  lines.push('static func take(dept: int, rng: RandomNumberGenerator) -> Dictionary:');
  lines.push('\tif not DECKS.has(dept):');
  lines.push('\t\treturn {}');
  lines.push('\tvar given: int = _given.get(dept, 0)');
  lines.push('\tvar deck_size: int = (DECKS[dept] as Array).size()');
  lines.push('\tif given >= deck_size and rng.randf() >= CHANCE[dept]:');
  lines.push('\t\treturn {}');
  lines.push('\t_given[dept] = given + 1');
  lines.push('\treturn pick(dept)');
  lines.push('');
  lines.push('');
  lines.push('# Next sculpt for this department, cycling through a freshly shuffled deck');
  lines.push('# each time it runs out.');
  lines.push('static func pick(dept: int) -> Dictionary:');
  lines.push('\tif not DECKS.has(dept):');
  lines.push('\t\treturn {}');
  lines.push('\tvar pool: Array = _pools.get(dept, [])');
  lines.push('\tif pool.is_empty():');
  lines.push('\t\tpool = (DECKS[dept] as Array).duplicate()');
  lines.push('\t\tpool.shuffle()');
  lines.push('\t\t_pools[dept] = pool');
  lines.push('\treturn pool.pop_back()');
  lines.push('');
  lines.push('');
  lines.push('static func scene(path: String) -> PackedScene:');
  lines.push('\tif not _scenes.has(path):');
  lines.push('\t\tvar packed := load(path) as PackedScene');
  lines.push('\t\t_scenes[path] = packed');
  lines.push('\treturn _scenes[path]');
  lines.push('');
  lines.push('');
  lines.push('static func equipment(name: String) -> PackedScene:');
  lines.push('\tif not EQUIPMENT.has(name):');
  lines.push('\t\treturn null');
  lines.push('\treturn scene(String(EQUIPMENT[name]["path"]))');
  lines.push('');

  const out = path.join(ROOT, 'scripts', 'model_catalog.gd');
  fs.writeFileSync(out, lines.join('\n'));
  console.log(`wrote ${path.relative(ROOT, out)} (${Object.values(DEPT_CATEGORIES).flat().length} decks)`);
}

(async () => {
  await MeshoptSimplifier.ready;
  const entries = CATALOG.entries.filter(e => !only || e.category === only);
  const results = [];
  let i = 0;
  for (const entry of entries) {
    i++;
    const tag = `${String(i).padStart(2)}/${entries.length} ${entry.category}/${entry.name}`;
    try {
      const r = await build(entry);
      const mb = (r.bytes / 1048576).toFixed(2);
      if (r.skipped) {
        console.log(`${tag}  (cached)`);
      } else {
        console.log(`${tag}  ${r.trisIn} -> ${r.trisOut} tris  ${mb} MB  h=${r.height.toFixed(2)}  ${r.ms}ms`);
      }
      results.push(r);
    } catch (e) {
      console.error(`${tag}  FAILED: ${e.message}`);
      results.push({ ...entry, error: String(e.message) });
    }
  }

  const summary = results.map(r => ({
    category: r.category,
    name: r.name,
    path: 'res://' + path.relative(ROOT, r.path).replace(/\\/g, '/'),
    height: +(r.height || 0).toFixed(3),
    tris: r.trisOut || 0,
    bytes: r.bytes || 0,
    error: r.error || null,
  }));

  // Keep entries from earlier partial runs so a `--only=` rebuild never drops
  // models from the generated script.
  const merged = new Map(prevBuilt);
  for (const r of summary) {
    if (!r.error) merged.set(r.category + '/' + r.name, r);
  }
  const all = [...merged.values()].sort((a, b) =>
    (CATEGORY_ORDER.indexOf(a.category) - CATEGORY_ORDER.indexOf(b.category)) ||
    a.name.localeCompare(b.name));
  fs.writeFileSync(BUILT_JSON, JSON.stringify(all, null, 1));
  const total = all.reduce((s, r) => s + (r.bytes || 0), 0);
  console.log(`\nDONE ${all.length} models, ${(total / 1048576).toFixed(1)} MB`);
  const errs = summary.filter(r => r.error);
  if (errs.length) console.log(`FAILED: ${errs.map(e => e.category + '/' + e.name).join(', ')}`);
  writeGDScript(all);
})();
