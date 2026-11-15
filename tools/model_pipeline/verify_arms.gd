extends SceneTree

const GLB_PATH := "res://assets/models/fps_arms_animated.glb"
const REQUIRED_ANIMS := ["idle_open", "carry_palm", "carry_box", "grip_grabber", "hold_bag"]


func _initialize() -> void:
	var packed := load(GLB_PATH) as PackedScene
	if packed == null:
		printerr("FAIL: Cannot load ", GLB_PATH)
		quit(1)
		return

	var root := packed.instantiate()
	var skel := _find_class(root, "Skeleton3D") as Skeleton3D
	var anim := _find_class(root, "AnimationPlayer") as AnimationPlayer
	if skel == null:
		printerr("FAIL: Missing Skeleton3D in ", GLB_PATH)
		quit(1)
		return
	if anim == null:
		printerr("FAIL: Missing AnimationPlayer in ", GLB_PATH)
		quit(1)
		return

	var has_l := root.find_child("Arm_L", true, false) != null
	var has_r := root.find_child("Arm_R", true, false) != null
	if not has_l or not has_r:
		printerr("FAIL: Missing Arm_L (", has_l, ") or Arm_R (", has_r, ")")
		quit(1)
		return

	var missing: Array[String] = []
	for a in REQUIRED_ANIMS:
		if not anim.has_animation(a):
			missing.append(a)
		else:
			anim.play(a)
			anim.advance(0.05)

	if not missing.is_empty():
		printerr("FAIL: Missing animations: ", missing)
		quit(1)
		return

	print("PASS: fps_arms_animated.glb verified. Bones=", skel.get_bone_count(), " Anims=", anim.get_animation_list())
	root.free()
	quit(0)


func _find_class(n: Node, cn: String) -> Node:
	if n.get_class() == cn:
		return n
	for c in n.get_children():
		var r := _find_class(c, cn)
		if r != null:
			return r
	return null
