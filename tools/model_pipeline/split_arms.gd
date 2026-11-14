extends SceneTree

# Splits the two-arm MakeHuman mesh that ships inside the CC0 "FPS ARMS RIG 1"
# FBX into one mesh per side. The FBX has a single skinned mesh that carries both
# arms; the viewmodel needs an independent left and right arm, so the triangles
# are grouped by the dominant side of their skin weights. Vertex arrays stay
# untouched, which keeps the skin bind list valid, and only the index buffer is
# filtered. Run with:
#   godot --headless --path . --script tools/model_pipeline/split_arms.gd

const SRC := "res://assets/models/_fps_arms.fbx"
const OUT_L := "res://assets/models/arm_para_l.res"
const OUT_R := "res://assets/models/arm_para_r.res"


func _initialize() -> void:
	var packed := load(SRC) as PackedScene
	if packed == null:
		printerr("SPLIT: cannot load ", SRC)
		quit(1)
		return
	var root := packed.instantiate()
	var skel := _find_class(root, "Skeleton3D") as Skeleton3D
	var mi := _find_class(root, "MeshInstance3D") as MeshInstance3D
	if skel == null or mi == null or mi.mesh == null:
		printerr("SPLIT: missing skeleton or mesh")
		quit(1)
		return

	var skin := mi.skin
	if skin == null:
		printerr("SPLIT: mesh has no skin")
		quit(1)
		return
	var bone_side: Array[int] = []
	for i in skin.get_bind_count():
		var side := 0
		var n := skin.get_bind_name(i)
		if n.ends_with(".L"):
			side = -1
		elif n.ends_with(".R"):
			side = 1
		bone_side.append(side)

	var out := { -1: ArrayMesh.new(), 1: ArrayMesh.new() }
	for si in mi.mesh.get_surface_count():
		var arrays := mi.mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if idx.is_empty():
			printerr("SPLIT: surface ", si, " has no index buffer")
			continue
		var stride := bones.size() / verts.size() if verts.size() > 0 else 4
		var vside := PackedInt32Array()
		vside.resize(verts.size())
		for v in verts.size():
			var l := 0.0
			var r := 0.0
			for k in stride:
				var b := bones[v * stride + k]
				var w := weights[v * stride + k]
				if b < 0 or b >= bone_side.size():
					continue
				if bone_side[b] < 0:
					l += w
				elif bone_side[b] > 0:
					r += w
			vside[v] = -1 if l > r else 1

		var idx_l := PackedInt32Array()
		var idx_r := PackedInt32Array()
		for t in range(0, idx.size() - 2, 3):
			var a := idx[t]
			var b := idx[t + 1]
			var c := idx[t + 2]
			var score := vside[a] + vside[b] + vside[c]
			if score < 0:
				idx_l.append(a)
				idx_l.append(b)
				idx_l.append(c)
			else:
				idx_r.append(a)
				idx_r.append(b)
				idx_r.append(c)
		for side in [-1, 1]:
			var side_idx := idx_l if side < 0 else idx_r
			if side_idx.is_empty():
				continue
			var split := arrays.duplicate()
			split[Mesh.ARRAY_INDEX] = side_idx
			var am: ArrayMesh = out[side]
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, split)
			am.surface_set_material(am.get_surface_count() - 1, mi.mesh.surface_get_material(si))
			print("SPLIT surface ", si, " side=", side, " tris=", side_idx.size() / 3)
	ResourceSaver.save(out[-1], OUT_L)
	ResourceSaver.save(out[1], OUT_R)
	print("SPLIT saved ", OUT_L, " and ", OUT_R)
	root.free()
	quit()


func _find_class(n: Node, cn: String) -> Node:
	if n.get_class() == cn:
		return n
	for c in n.get_children():
		var r := _find_class(c, cn)
		if r != null:
			return r
	return null
