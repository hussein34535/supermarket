"""Inspect GLB/GLTF files: geometry, textures, rig, animations, extensions."""
import json
import os
import struct
import sys


def read_glb(path):
    with open(path, "rb") as f:
        data = f.read()
    magic, version, length = struct.unpack("<4sII", data[:12])
    assert magic == b"glTF", magic
    offset = 12
    js = None
    bins = []
    while offset < length:
        clen, ctype = struct.unpack("<II", data[offset:offset + 8])
        chunk = data[offset + 8: offset + 8 + clen]
        if ctype == 0x4E4F534A:
            js = json.loads(chunk.decode("utf-8"))
        elif ctype == 0x004E4942:
            bins.append(chunk)
        offset += 8 + clen
    return js, bins, len(data)


def read_gltf(path):
    with open(path, "rb") as f:
        js = json.load(f)
    return js, [], os.path.getsize(path)


def png_size(b):
    if b[:8] == b"\x89PNG\r\n\x1a\n":
        w, h = struct.unpack(">II", b[16:24])
        return w, h
    if b[:2] == b"\xff\xd8":
        i = 2
        while i < len(b) - 9:
            if b[i] != 0xFF:
                i += 1
                continue
            m = b[i + 1]
            if m in (0xC0, 0xC1, 0xC2):
                h, w = struct.unpack(">HH", b[i + 5:i + 9])
                return w, h
            seg = struct.unpack(">H", b[i + 2:i + 4])[0]
            i += 2 + seg
    return 0, 0


def human(n):
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024:
            return "%.1f%s" % (n, unit)
        n /= 1024.0
    return "%.1fTB" % n


def summarize(path):
    ext = os.path.splitext(path)[1].lower()
    js, bins, total = read_glb(path) if ext == ".glb" else read_gltf(path)
    bin_data = b"".join(bins)
    print("=" * 100)
    print("FILE:", os.path.basename(path), "|", human(total), "| generator:", js.get("asset", {}).get("generator", "?"))
    print("extensionsUsed:", js.get("extensionsUsed"))
    print("extensionsRequired:", js.get("extensionsRequired"))

    accessors = js.get("accessors", [])
    views = js.get("bufferViews", [])
    meshes = js.get("meshes", [])

    tris = 0
    verts = 0
    prims = 0
    for m in meshes:
        for p in m.get("primitives", []):
            prims += 1
            pos = p.get("attributes", {}).get("POSITION")
            if pos is not None:
                verts += accessors[pos].get("count", 0)
            idx = p.get("indices")
            if idx is not None:
                tris += accessors[idx].get("count", 0) // 3
    print("nodes: %d | meshes: %d | primitives: %d | verts: %s | tris: %s" % (
        len(js.get("nodes", [])), len(meshes), prims, format(verts, ","), format(tris, ",")))
    print("materials: %d | textures: %d | images: %d | animations: %d | skins: %d" % (
        len(js.get("materials", [])), len(js.get("textures", [])), len(js.get("images", [])),
        len(js.get("animations", [])), len(js.get("skins", []))))

    for i, sk in enumerate(js.get("skins", [])):
        print("   skin[%d] joints=%d name=%s" % (i, len(sk.get("joints", [])), sk.get("name", "")))

    for a in js.get("animations", []):
        dur = 0.0
        for s in a.get("samplers", []):
            acc = accessors[s["input"]]
            mx = acc.get("max")
            if mx:
                dur = max(dur, float(mx[0]))
        print("   anim: %-30s channels=%-4d %.2fs" % (a.get("name", "?"), len(a.get("channels", [])), dur))

    # images: embedded size & resolution
    img_bytes = 0
    for i, im in enumerate(js.get("images", [])):
        bv = im.get("bufferView")
        data = b""
        if bv is not None:
            v = views[bv]
            data = bin_data[v.get("byteOffset", 0): v.get("byteOffset", 0) + v["byteLength"]]
        elif im.get("uri", "").startswith("data:"):
            import base64
            data = base64.b64decode(im["uri"].split(",", 1)[1])
        img_bytes += len(data)
        w, h = png_size(data) if data else (0, 0)
        print("   image[%d] %-24s %-6s %5dx%-5d %s" % (
            i, (im.get("name") or "-")[:24], im.get("mimeType", "?").replace("image/", ""), w, h, human(len(data))))
    print("   -> images total: %s of %s" % (human(img_bytes), human(total)))

    node_names = [n.get("name", "?") for n in js.get("nodes", [])]
    print("nodes:", ", ".join(node_names[:30]) + (" ..." if len(node_names) > 30 else ""))
    for m in meshes[:15]:
        print("   mesh: %-30s prims=%d" % ((m.get("name") or "-")[:30], len(m.get("primitives", []))))

    # world-space bounds from POSITION accessors (node transforms mostly identity)
    bmin = [1e9] * 3
    bmax = [-1e9] * 3
    attrs = set()
    for m in meshes:
        for p in m.get("primitives", []):
            attrs.update(p.get("attributes", {}).keys())
            pa = p.get("attributes", {}).get("POSITION")
            if pa is None:
                continue
            acc = accessors[pa]
            if "min" in acc and "max" in acc:
                for i in range(3):
                    bmin[i] = min(bmin[i], acc["min"][i])
                    bmax[i] = max(bmax[i], acc["max"][i])
    if bmin[0] < 1e8:
        size = [bmax[i] - bmin[i] for i in range(3)]
        print("bounds min=(%.3f, %.3f, %.3f) max=(%.3f, %.3f, %.3f) size=(%.3f x %.3f x %.3f)" % (
            bmin[0], bmin[1], bmin[2], bmax[0], bmax[1], bmax[2], size[0], size[1], size[2]))
    print("attributes:", sorted(attrs))
    for mat in js.get("materials", [])[:10]:
        pbr = mat.get("pbrMetallicRoughness", {})
        print("   mat: %-26s baseColor=%s rough=%s metal=%s tex=%s" % (
            (mat.get("name") or "-")[:26],
            [round(x, 2) for x in pbr.get("baseColorFactor", [])][:4],
            pbr.get("roughnessFactor"), pbr.get("metallicFactor"),
            "Y" if "baseColorTexture" in pbr else "-"))


if __name__ == "__main__":
    for p in sys.argv[1:]:
        try:
            summarize(p)
        except Exception as e:  # noqa: BLE001
            print("FAILED", p, type(e).__name__, e)
