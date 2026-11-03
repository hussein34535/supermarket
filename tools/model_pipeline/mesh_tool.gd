extends SceneTree

# Offline asset helper for the supermarket project.
# Usage (headless):
#   godot --headless --path . --script res://tools/model_pipeline/mesh_tool.gd -- inspect <mesh_or_scene>
#   godot --headless --path . --script res://tools/model_pipeline/mesh_tool.gd -- split <glb> <out_left.res> <out_right.res> [axis]
#
# `split` cuts a single-mesh arms scene into the left and right arm resources the
# viewmodel expects, keeping bones/weights so the skeleton still deforms it.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("no command")
		quit()
		return
	match args[0]:
		"inspect":
			_inspect(args[1])
		"split":
			var axis := 0
			if args.size() > 4:
				axis = int(args[4])
			_split(args[1], args[2], args[3], axis)
		"split_all":
			_split_all(args[1], args[2])
		_:
			print("unknown command: ", args[0])
	quit()


func _get_mesh(path: String) -> ArrayMesh:
	if path.ends_with(".res") or path.ends_with(".tres"):
		return load(path) as ArrayMesh
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var inst := ps.instantiate()
	for node in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh is ArrayMesh:
			return mi.mesh
	return null


func _describe(m: ArrayMesh, label: String) -> void:
	if m == null:
		print(label, ": NULL")
		return
	print(label, ": surfaces=", m.get_surface_count(), " aabb=", m.get_aabb())
	for s in m.get_surface_count():
		var arrays := m.surface_get_arrays(s)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx = arrays[Mesh.ARRAY_INDEX]
		var bones = arrays[Mesh.ARRAY_BONES]
		var weights = arrays[Mesh.ARRAY_WEIGHTS]
		print("  surface ", s, " verts=", v.size(), " indices=", (idx.size() if idx != null else 0),
			" bones=", (bones.size() if bones != null else 0),
			" weights=", (weights.size() if weights != null else 0),
			" format=", m.surface_get_format(s), " prim=", m.surface_get_primitive_type(s))


func _inspect(path: String) -> void:
	var m := _get_mesh(path)
	_describe(m, path)


func _split(glb: String, out_left: String, out_right: String, axis: int) -> void:
	var m := _get_mesh(glb)
	if m == null:
		printerr("could not load mesh from ", glb)
		return
	var arrays := m.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices = arrays[Mesh.ARRAY_INDEX]
	var tri_count := 0
	var order := PackedInt32Array()
	if indices == null:
		order.resize(verts.size())
		for i in verts.size():
			order[i] = i
		tri_count = verts.size() / 3
	else:
		order = indices
		tri_count = indices.size() / 3

	var left_tris := PackedInt32Array()
	var right_tris := PackedInt32Array()
	for t in tri_count:
		var a := order[t * 3]
		var b := order[t * 3 + 1]
		var c := order[t * 3 + 2]
		var centroid := (verts[a] + verts[b] + verts[c]) / 3.0
		var coord := centroid[axis]
		if coord < 0.0:
			left_tris.append_array([a, b, c])
		else:
			right_tris.append_array([a, b, c])

	print("triangles: total=", tri_count, " left=", left_tris.size() / 3, " right=", right_tris.size() / 3)
	_save_submesh(m, arrays, left_tris, out_left)
	_save_submesh(m, arrays, right_tris, out_right)


# Rebuilds a compacted ArrayMesh containing only the requested triangles.
func _save_submesh(src_mesh: ArrayMesh, arrays: Array, tris: PackedInt32Array, out_path: String) -> void:
	var remap := {}
	var new_verts := PackedVector3Array()
	for i in tris:
		if not remap.has(i):
			remap[i] = new_verts.size()
			new_verts.append(arrays[Mesh.ARRAY_VERTEX][i])

	var out_arrays := []
	out_arrays.resize(Mesh.ARRAY_MAX)
	out_arrays[Mesh.ARRAY_VERTEX] = new_verts

	for key in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
		var src_attr = arrays[key]
		if src_attr == null or src_attr.size() == 0:
			continue
		var per_vertex := 1
		if key == Mesh.ARRAY_TANGENT or key == Mesh.ARRAY_COLOR:
			per_vertex = 4
		var dst = src_attr.duplicate()
		dst.resize(new_verts.size() * per_vertex)
		for i in tris:
			if not remap.has(i):
				continue
			var ni: int = remap[i]
			for k in per_vertex:
				dst[ni * per_vertex + k] = src_attr[i * per_vertex + k]
		out_arrays[key] = dst

	var bones = arrays[Mesh.ARRAY_BONES]
	var weights = arrays[Mesh.ARRAY_WEIGHTS]
	if bones != null and bones.size() > 0:
		# bones/weights are flat with 4 entries per vertex.
		var dst_bones := PackedInt32Array()
		var dst_weights := PackedFloat32Array()
		dst_bones.resize(new_verts.size() * 4)
		dst_weights.resize(new_verts.size() * 4)
		for i in tris:
			if not remap.has(i):
				continue
			var ni: int = remap[i]
			for k in 4:
				dst_bones[ni * 4 + k] = bones[i * 4 + k]
				dst_weights[ni * 4 + k] = weights[i * 4 + k]
		out_arrays[Mesh.ARRAY_BONES] = dst_bones
		out_arrays[Mesh.ARRAY_WEIGHTS] = dst_weights

	var new_indices := PackedInt32Array()
	new_indices.resize(tris.size())
	for i in tris.size():
		new_indices[i] = remap[tris[i]]
	out_arrays[Mesh.ARRAY_INDEX] = new_indices

	var out_mesh := ArrayMesh.new()
	out_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out_arrays)
	var err := ResourceSaver.save(out_mesh, out_path)
	print("saved ", out_path, " verts=", new_verts.size(), " tris=", tris.size() / 3, " err=", err)


func _pack_like(src, dst: Array):
	match src.get_class():
		"PackedVector2Array":
			return PackedVector2Array(dst)
		"PackedVector3Array":
			return PackedVector3Array(dst)
		"PackedColorArray":
			return PackedColorArray(dst)
		"PackedFloat32Array":
			return PackedFloat32Array(dst)
		_:
			return dst


func _split_all(glb: String, prefix: String) -> void:
	# Splits every surface separately (used when the scene contains one mesh per part).
	var m := _get_mesh(glb)
	if m == null:
		printerr("could not load ", glb)
		return
	for s in m.get_surface_count():
		var single := ArrayMesh.new()
		single.add_surface_from_arrays(m.surface_get_primitive_type(s), m.surface_get_arrays(s))
		ResourceSaver.save(single, "%s_%d.res" % [prefix, s])
	print("split_all surfaces=", m.get_surface_count())
