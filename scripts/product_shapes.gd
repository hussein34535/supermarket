class_name ProductShapes
extends RefCounted

const ROT := PI * 0.5
const FLAT_CATALOG_PRODUCTS: Array[String] = [
	"tomato_tray", "carrots", "zucchini", "pepsi_cans", "red_onions", "tuna_cans", "tuna_pack"
]

static var _mat_cache: Dictionary = {}
static var _shop_mat_cache: Dictionary = {}
static var _declared_dims: Dictionary = {}
static var _sign_font: Font


static func sign_font() -> Font:
	if _sign_font == null:
		_sign_font = load("res://assets/fonts/Cairo.ttf")
	return _sign_font


static func build(parent: Node3D, dept: int, dept_color: Color, rng: RandomNumberGenerator, s: float = 1.0) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	match dept:
		0: _fruit(parent, dept_color, rng, s, out)
		1: _dairy(parent, dept_color, rng, s, out)
		2: _drinks(parent, dept_color, rng, s, out)
		3: _snacks(parent, dept_color, rng, s, out)
		4: _cleaning(parent, dept_color, rng, s, out)
		_: _frozen(parent, dept_color, rng, s, out)
	return out


static func highlight_material(color: Color) -> StandardMaterial3D:
	return _mat(color.lightened(0.45), 0.0, 0.4, 2.5)


# Catalog models are authored with their long axis pointing along X or Z. Most
# products are upright, but shallow trays, packs and multipacks must stay flat.
# Their generated catalog height is the explicit orientation hint; using the
# longest raw axis for every model turns those products on their sides.
static func is_flat_product(model_name: String) -> bool:
	return model_name in FLAT_CATALOG_PRODUCTS


static func upright_model(inst: Node3D, model_name: String = "") -> Vector3:
	var parent := inst.get_parent() as Node3D
	if parent == null:
		return Vector3.ZERO
	var bounds := _model_bounds_in_parent(inst, parent)
	if bounds.size.length_squared() < 0.000001:
		return Vector3.ZERO
	_choose_up_axis(inst, bounds.size, model_name)
	bounds = _model_bounds_in_parent(inst, parent)
	inst.position -= Vector3(
		bounds.position.x + bounds.size.x * 0.5,
		bounds.position.y,
		bounds.position.z + bounds.size.z * 0.5)
	return bounds.size


# The catalog records the height/w/d every model is meant to end up with, so the
# up axis is picked by matching those numbers. The old rule stood the longest
# axis upright, which put wide multipacks and flat cheese boxes on their ends.
static func _choose_up_axis(inst: Node3D, size: Vector3, model_name: String) -> void:
	var declared := declared_dims(model_name)
	if declared == Vector3.ZERO:
		if size.z > size.x and size.z > size.y:
			inst.rotation.x = PI * 0.5
		elif size.x > size.y:
			inst.rotation.z = -PI * 0.5
		return
	var candidates: Array[Vector3] = [
		Vector3.ZERO,
		Vector3(PI * 0.5, 0.0, 0.0),
		Vector3(-PI * 0.5, 0.0, 0.0),
		Vector3(0.0, 0.0, PI * 0.5),
		Vector3(0.0, 0.0, -PI * 0.5),
	]
	var best := INF
	var best_rot := Vector3.ZERO
	for rot in candidates:
		var score := _axis_score(_rotated_size(size, rot), declared)
		if score < best - 0.0001:
			best = score
			best_rot = rot
	inst.rotation = Vector3(best_rot.x, inst.rotation.y, best_rot.z)


# Declared size of a catalog model as (height, width, depth); zero when the name
# is not in the catalog.
static func declared_dims(model_name: String) -> Vector3:
	if _declared_dims.is_empty():
		for dept in ModelCatalog.DECKS.keys():
			for hero in ModelCatalog.DECKS[dept]:
				_declared_dims[String(hero["name"])] = Vector3(
					float(hero["height"]), float(hero["w"]), float(hero["d"]))
	return _declared_dims.get(model_name, Vector3.ZERO)


static func _rotated_size(size: Vector3, rot: Vector3) -> Vector3:
	if not is_zero_approx(rot.x):
		return Vector3(size.x, size.z, size.y)
	if not is_zero_approx(rot.z):
		return Vector3(size.y, size.x, size.z)
	return size


static func _axis_score(size: Vector3, declared: Vector3) -> float:
	var err_y := absf(size.y - declared.x) / maxf(declared.x, 0.001)
	var straight := absf(size.x - declared.y) + absf(size.z - declared.z)
	var swapped := absf(size.x - declared.z) + absf(size.z - declared.y)
	var err_xz := minf(straight, swapped) / maxf(declared.y + declared.z, 0.001)
	return err_y + err_xz


static func _model_bounds_in_parent(inst: Node3D, parent: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	var meshes: Array[Node] = inst.find_children("*", "MeshInstance3D", true, false)
	if inst is MeshInstance3D:
		meshes.append(inst)
	for node in meshes:
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var relative := Transform3D.IDENTITY
		var current := mi as Node3D
		while current != null and current != parent:
			relative = current.transform * relative
			current = current.get_parent() as Node3D
		if current != parent:
			continue
		var box: AABB = relative * mi.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


# The sculpted models ship with glossy, often fully metallic PBR materials
# tuned for a studio HDRI. Under the store's omni lights those read almost
# black, so flatten the metal response on a copy while keeping the albedo,
# normal and roughness maps that make the labels readable.
static func shop_material(mi: MeshInstance3D) -> void:
	if mi == null or mi.mesh == null:
		return
	var mesh: Mesh = mi.mesh
	var mesh_override: Material = mi.material_override
	for surface_index: int in range(mesh.get_surface_count()):
		var mat: Material = mi.get_surface_override_material(surface_index)
		if mat == null:
			mat = mesh.surface_get_material(surface_index)
		if mat == null and mesh_override is StandardMaterial3D:
			mat = mesh_override
		if mat is StandardMaterial3D:
			mi.set_surface_override_material(surface_index, _shop_material_copy(mat as StandardMaterial3D))
	# A StandardMaterial3D whole-mesh override masks the per-surface adaptations.
	# Drop it after adapting the underlying slots; leave other override types alone.
	if mesh_override is StandardMaterial3D:
		mi.material_override = null


static func _shop_material_copy(source: StandardMaterial3D) -> StandardMaterial3D:
	var cache_key: int = source.get_instance_id()
	if _shop_mat_cache.has(cache_key):
		var cached: Array = _shop_mat_cache[cache_key]
		if cached[0] == source:
			return cached[1] as StandardMaterial3D
	var copy := source.duplicate() as StandardMaterial3D
	copy.metallic = 0.0
	copy.metallic_specular = 0.45
	copy.roughness = clampf(copy.roughness + 0.2, 0.45, 1.0)
	copy.albedo_color = copy.albedo_color.lightened(0.1)
	copy.vertex_color_use_as_albedo = false
	# Keep source refs alive so instance IDs cannot be recycled into stale cache hits.
	_shop_mat_cache[cache_key] = [source, copy]
	# Mark adapted copies too, so calling this again on the same instance is idempotent.
	_shop_mat_cache[copy.get_instance_id()] = [copy, copy]
	return copy


static func _mat(c: Color, metallic: float = 0.0, rough: float = 0.55, emission: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [c.to_html(), metallic, rough, emission]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = rough
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emission
	_mat_cache[key] = m
	return m


static func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	# Hundreds of thumbnail-sized goods on the floor are not worth a shadow pass.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _box(w: float, h: float, d: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(w, h, d)
	return b


static func _cyl(top: float, bottom: float, h: float, seg: int = 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


static func _sph(r: float, seg: int = 12, rings: int = 8) -> SphereMesh:
	var sp := SphereMesh.new()
	sp.radius = r
	sp.height = r * 2.0
	sp.radial_segments = seg
	sp.rings = rings
	return sp


static func _fruit(parent: Node3D, dc: Color, rng: RandomNumberGenerator, s: float, out: Array[MeshInstance3D]) -> void:
	var variant := rng.randi_range(0, 2)
	if variant == 0:
		var cols: Array[Color] = [
			Color(0.85, 0.16, 0.14), Color(0.95, 0.78, 0.12), Color(0.45, 0.76, 0.22)
		]
		var col: Color = cols[rng.randi_range(0, 2)]
		var r := 0.095 * s
		out.append(_add(parent, _sph(r), _mat(col, 0.0, 0.32), Vector3(0, r, 0)))
		out.append(_add(parent, _cyl(0.008 * s, 0.011 * s, 0.05 * s, 6), _mat(Color(0.36, 0.22, 0.09), 0.0, 0.9), Vector3(0, 2.0 * r + 0.02 * s, 0)))
		var leaf := _add(parent, _sph(0.032 * s, 8, 4), _mat(Color(0.28, 0.66, 0.2), 0.0, 0.45), Vector3(0.035 * s, 2.0 * r + 0.04 * s, 0))
		leaf.scale = Vector3(1.5, 0.2, 0.85)
		leaf.rotation.z = -0.45
		out.append(leaf)
	elif variant == 1:
		var col2 := Color(1.0, 0.58, 0.08) if rng.randf() < 0.5 else Color(0.35, 0.68, 0.25)
		var r2 := 0.11 * s
		out.append(_add(parent, _sph(r2), _mat(col2, 0.0, 0.38), Vector3(0, r2, 0)))
		out.append(_add(parent, _cyl(0.012 * s, 0.02 * s, 0.012 * s, 6), _mat(Color(0.28, 0.55, 0.16), 0.0, 0.7), Vector3(0, 2.0 * r2 + 0.004 * s, 0)))
	else:
		var cap := CapsuleMesh.new()
		cap.radius = 0.055 * s
		cap.height = 0.2 * s
		cap.radial_segments = 10
		cap.rings = 4
		out.append(_add(parent, cap, _mat(Color(1.0, 0.85, 0.18), 0.0, 0.4), Vector3(0, 0.055 * s, 0), Vector3(0, rng.randf_range(0.0, TAU), ROT)))


static func _dairy(parent: Node3D, dc: Color, rng: RandomNumberGenerator, s: float, out: Array[MeshInstance3D]) -> void:
	var variant := rng.randi_range(0, 2)
	if variant == 0:
		var w := 0.13 * s
		var h := 0.26 * s
		var d := 0.09 * s
		out.append(_add(parent, _box(w, h, d), _mat(Color(0.97, 0.97, 0.99), 0.0, 0.5), Vector3(0, h * 0.5, 0)))
		var roof := PrismMesh.new()
		roof.size = Vector3(w * 1.01, 0.045 * s, d * 1.01)
		out.append(_add(parent, roof, _mat(Color(0.94, 0.94, 0.97), 0.0, 0.5), Vector3(0, h + 0.0225 * s, 0)))
		out.append(_add(parent, _box(w + 0.004 * s, 0.06 * s, d + 0.004 * s), _mat(dc, 0.0, 0.5), Vector3(0, h * 0.5, 0)))
		out.append(_add(parent, _cyl(0.02 * s, 0.02 * s, 0.03 * s, 8), _mat(dc.darkened(0.15), 0.1, 0.35), Vector3(w * 0.24, h + 0.05 * s, 0)))
	elif variant == 1:
		var cup_h := 0.12 * s
		out.append(_add(parent, _cyl(0.068 * s, 0.052 * s, cup_h), _mat(Color(0.98, 0.98, 1.0), 0.0, 0.5), Vector3(0, cup_h * 0.5, 0)))
		out.append(_add(parent, _cyl(0.07 * s, 0.07 * s, 0.014 * s, 12), _mat(dc, 0.15, 0.3), Vector3(0, cup_h + 0.007 * s, 0)))
	else:
		out.append(_add(parent, _box(0.15 * s, 0.07 * s, 0.09 * s), _mat(Color(1.0, 0.92, 0.6), 0.0, 0.5), Vector3(0, 0.035 * s, 0)))
		out.append(_add(parent, _box(0.152 * s, 0.028 * s, 0.092 * s), _mat(dc, 0.0, 0.45), Vector3(0, 0.035 * s, 0)))


static func _drinks(parent: Node3D, dc: Color, rng: RandomNumberGenerator, s: float, out: Array[MeshInstance3D]) -> void:
	var variant := rng.randi_range(0, 2)
	if variant == 0:
		var h := 0.16 * s
		out.append(_add(parent, _cyl(0.052 * s, 0.052 * s, h, 14), _mat(Color(0.8, 0.82, 0.85), 0.7, 0.3), Vector3(0, h * 0.5, 0)))
		out.append(_add(parent, _cyl(0.054 * s, 0.054 * s, 0.07 * s, 14), _mat(dc, 0.2, 0.35), Vector3(0, h * 0.5, 0)))
		out.append(_add(parent, _cyl(0.053 * s, 0.053 * s, 0.004 * s, 14), _mat(Color(0.7, 0.72, 0.75), 0.8, 0.25), Vector3(0, h - 0.002 * s, 0)))
		out.append(_add(parent, _box(0.018 * s, 0.003 * s, 0.009 * s), _mat(Color(0.8, 0.82, 0.85), 0.8, 0.25), Vector3(0.01 * s, h + 0.004 * s, 0)))
	elif variant == 1:
		var bh := 0.18 * s
		out.append(_add(parent, _cyl(0.058 * s, 0.062 * s, bh, 14), _mat(dc, 0.0, 0.3), Vector3(0, bh * 0.5, 0)))
		out.append(_add(parent, _cyl(0.063 * s, 0.063 * s, 0.055 * s, 14), _mat(Color(0.97, 0.97, 0.95), 0.0, 0.45), Vector3(0, bh * 0.48, 0)))
		out.append(_add(parent, _cyl(0.064 * s, 0.064 * s, 0.012 * s, 14), _mat(dc.darkened(0.1), 0.1, 0.35), Vector3(0, bh * 0.48, 0)))
		out.append(_add(parent, _cyl(0.022 * s, 0.05 * s, 0.05 * s, 10), _mat(dc.darkened(0.05), 0.0, 0.35), Vector3(0, bh + 0.025 * s, 0)))
		out.append(_add(parent, _cyl(0.024 * s, 0.024 * s, 0.03 * s, 10), _mat(Color(0.95, 0.95, 0.95), 0.1, 0.4), Vector3(0, bh + 0.065 * s, 0)))
	else:
		var w := 0.11 * s
		var h2 := 0.21 * s
		var d := 0.08 * s
		out.append(_add(parent, _box(w, h2, d), _mat(dc, 0.0, 0.5), Vector3(0, h2 * 0.5, 0)))
		out.append(_add(parent, _box(w + 0.003 * s, 0.05 * s, d + 0.003 * s), _mat(Color(1, 1, 1), 0.0, 0.5), Vector3(0, h2 * 0.7, 0)))
		out.append(_add(parent, _cyl(0.005 * s, 0.005 * s, 0.09 * s, 6), _mat(Color(0.92, 0.92, 0.94), 0.1, 0.4), Vector3(0.035 * s, h2 + 0.035 * s, 0.01 * s), Vector3(0, 0, 0.3)))


static func _snacks(parent: Node3D, dc: Color, rng: RandomNumberGenerator, s: float, out: Array[MeshInstance3D]) -> void:
	var variant := rng.randi_range(0, 2)
	if variant == 0:
		var w := 0.18 * s
		var h := 0.25 * s
		var d := 0.07 * s
		out.append(_add(parent, _box(w, h, d), _mat(dc, 0.05, 0.7), Vector3(0, h * 0.5, 0)))
		out.append(_add(parent, _box(w * 0.9, 0.03 * s, d * 1.05), _mat(dc.darkened(0.2), 0.25, 0.6), Vector3(0, h, 0)))
		out.append(_add(parent, _box(w * 0.7, 0.12 * s, 0.004 * s), _mat(Color(1, 1, 1), 0.0, 0.5), Vector3(0, h * 0.55, d * 0.5 + 0.002 * s)))
	elif variant == 1:
		out.append(_add(parent, _box(0.14 * s, 0.055 * s, 0.035 * s), _mat(dc, 0.0, 0.6), Vector3(0, 0.0275 * s, 0)))
		out.append(_add(parent, _box(0.1 * s, 0.02 * s, 0.037 * s), _mat(Color(1, 1, 0.9), 0.0, 0.5), Vector3(0, 0.0275 * s, 0)))
	else:
		var w2 := 0.15 * s
		var h2 := 0.28 * s
		out.append(_add(parent, _box(w2, h2, 0.06 * s), _mat(dc, 0.0, 0.55), Vector3(0, h2 * 0.5, 0)))
		out.append(_add(parent, _box(w2 * 0.75, 0.14 * s, 0.004 * s), _mat(Color(1, 1, 1), 0.0, 0.5), Vector3(0, h2 * 0.6, 0.032 * s)))


static func _cleaning(parent: Node3D, dc: Color, rng: RandomNumberGenerator, s: float, out: Array[MeshInstance3D]) -> void:
	var variant := rng.randi_range(0, 2)
	if variant == 0:
		var h := 0.19 * s
		out.append(_add(parent, _cyl(0.055 * s, 0.06 * s, h, 12), _mat(dc, 0.0, 0.35), Vector3(0, h * 0.5, 0)))
		out.append(_add(parent, _cyl(0.018 * s, 0.03 * s, 0.05 * s, 8), _mat(dc.darkened(0.1), 0.0, 0.4), Vector3(0, h + 0.025 * s, 0)))
		out.append(_add(parent, _box(0.05 * s, 0.025 * s, 0.07 * s), _mat(Color(0.95, 0.95, 0.95), 0.0, 0.45), Vector3(0.045 * s, h + 0.02 * s, 0.02 * s)))
		out.append(_add(parent, _cyl(0.008 * s, 0.008 * s, 0.03 * s, 6), _mat(Color(0.9, 0.9, 0.9), 0.0, 0.5), Vector3(0.07 * s, h + 0.02 * s, 0.045 * s), Vector3(ROT, 0, 0)))
		out.append(_add(parent, _box(0.065 * s, 0.075 * s, 0.006 * s), _mat(Color(0.97, 0.97, 0.96), 0.0, 0.5), Vector3(0, h * 0.5, 0.057 * s)))
		out.append(_add(parent, _box(0.065 * s, 0.018 * s, 0.008 * s), _mat(dc.darkened(0.1), 0.0, 0.4), Vector3(0, h * 0.34, 0.058 * s)))
	elif variant == 1:
		var h2 := 0.17 * s
		var body_col := Color(0.96, 0.97, 1.0) if rng.randf() < 0.5 else dc.lightened(0.2)
		out.append(_add(parent, _cyl(0.062 * s, 0.066 * s, h2, 12), _mat(body_col, 0.0, 0.35), Vector3(0, h2 * 0.5, 0)))
		out.append(_add(parent, _cyl(0.012 * s, 0.012 * s, 0.05 * s, 6), _mat(Color(0.85, 0.87, 0.9), 0.2, 0.4), Vector3(0, h2 + 0.025 * s, 0)))
		out.append(_add(parent, _box(0.05 * s, 0.018 * s, 0.025 * s), _mat(Color(0.85, 0.87, 0.9), 0.2, 0.4), Vector3(0.02 * s, h2 + 0.05 * s, 0)))
	else:
		var w := 0.15 * s
		var h3 := 0.24 * s
		out.append(_add(parent, _box(w, h3, 0.1 * s), _mat(dc, 0.0, 0.4), Vector3(0, h3 * 0.5, 0)))
		out.append(_add(parent, _cyl(0.032 * s, 0.032 * s, 0.04 * s, 10), _mat(dc.darkened(0.2), 0.1, 0.35), Vector3(0, h3 + 0.02 * s, 0)))
		out.append(_add(parent, _box(w + 0.003 * s, 0.06 * s, 0.102 * s), _mat(Color(1, 1, 1), 0.0, 0.5), Vector3(0, h3 * 0.55, 0)))
		out.append(_add(parent, _box(0.085 * s, 0.095 * s, 0.004 * s), _mat(Color(0.97, 0.97, 0.96), 0.0, 0.5), Vector3(0, h3 * 0.5, 0.052 * s)))
		out.append(_add(parent, _box(0.085 * s, 0.022 * s, 0.005 * s), _mat(dc.darkened(0.1), 0.0, 0.4), Vector3(0, h3 * 0.35, 0.053 * s)))


static func _frozen(parent: Node3D, dc: Color, rng: RandomNumberGenerator, s: float, out: Array[MeshInstance3D]) -> void:
	var variant := rng.randi_range(0, 2)
	if variant == 0:
		var h := 0.12 * s
		out.append(_add(parent, _cyl(0.075 * s, 0.07 * s, h, 12), _mat(Color(0.92, 0.97, 1.0), 0.0, 0.3), Vector3(0, h * 0.5, 0)))
		out.append(_add(parent, _cyl(0.077 * s, 0.077 * s, 0.02 * s, 12), _mat(dc, 0.2, 0.3), Vector3(0, h + 0.01 * s, 0)))
		out.append(_add(parent, _cyl(0.0775 * s, 0.0775 * s, 0.055 * s, 12), _mat(Color(0.97, 0.98, 1.0), 0.0, 0.4), Vector3(0, h * 0.45, 0)))
		out.append(_add(parent, _cyl(0.0785 * s, 0.0785 * s, 0.012 * s, 12), _mat(dc, 0.1, 0.35), Vector3(0, h * 0.45, 0)))
	elif variant == 1:
		var w := 0.17 * s
		var h2 := 0.2 * s
		out.append(_add(parent, _box(w, h2, 0.08 * s), _mat(dc, 0.05, 0.35), Vector3(0, h2 * 0.5, 0)))
		out.append(_add(parent, _box(w * 0.6, 0.1 * s, 0.004 * s), _mat(Color(0.95, 0.98, 1.0), 0.0, 0.3, 0.4), Vector3(0, h2 * 0.55, 0.042 * s)))
	else:
		out.append(_add(parent, _cyl(0.006 * s, 0.045 * s, 0.13 * s, 10), _mat(Color(0.85, 0.66, 0.38), 0.0, 0.6), Vector3(0, 0.065 * s, 0)))
		var r := 0.06 * s
		out.append(_add(parent, _sph(r), _mat(dc.lightened(0.3), 0.0, 0.3), Vector3(0, 0.13 * s + r * 0.6, 0)))
		out.append(_add(parent, _sph(0.023 * s, 8, 5), _mat(Color(0.75, 0.08, 0.1), 0.0, 0.35), Vector3(0, 0.13 * s + r * 1.4, 0)))
