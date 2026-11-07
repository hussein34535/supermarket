const fs = require('fs');
const path = require('path');
const { NodeIO } = require('@gltf-transform/core');
const { ALL_EXTENSIONS } = require('@gltf-transform/extensions');
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
const root = path.resolve(__dirname, '..', '..', 'assets', 'models', 'catalog');
const rows = [];
(async () => {
  for (const cat of fs.readdirSync(root)) {
    const dir = path.join(root, cat);
    if (!fs.statSync(dir).isDirectory()) continue;
    for (const f of fs.readdirSync(dir)) {
      if (!f.endsWith('.glb')) continue;
      const p = path.join(dir, f);
      const doc = await io.read(p);
      const r = doc.getRoot();
      const prims = r.listMeshes().reduce((s, m) => s + m.listPrimitives().length, 0);
      rows.push({ cat, name: f, meshes: r.listMeshes().length, prims, mats: r.listMaterials().length, tex: r.listTextures().length });
    }
  }
  const counts = {};
  for (const x of rows) counts[x.prims] = (counts[x.prims] || 0) + 1;
  console.log('prims distribution', counts);
  console.log('meshes>1', rows.filter(x => x.meshes > 1).length, 'mats>1', rows.filter(x => x.mats > 1).length);
  for (const x of rows.filter(x => x.meshes > 1 || x.mats > 1)) console.log(x.cat, x.name, 'meshes', x.meshes, 'prims', x.prims, 'mats', x.mats, 'tex', x.tex);
})();
