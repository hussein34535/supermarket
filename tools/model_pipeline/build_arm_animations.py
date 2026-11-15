import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector, Quaternion

ROOT = Path(__file__).resolve().parents[2]
SRC_FBX = ROOT / "assets" / "models" / "_fps_arms.fbx"
OUT_GLB = ROOT / "assets" / "models" / "fps_arms_animated.glb"

FINGERS = ["index", "middle", "ring", "pinky"]


def find_bone_name(arm_obj, base: str, side: str) -> str | None:
    s_upper = side.upper()
    candidates = [
        f"{base}.{s_upper}" if base == "hand" else f"f_{base}.{s_upper}",
        f"{base}.{s_upper}",
        f"{base}_{side.lower()}",
    ]
    if base.startswith("thumb"):
        candidates.insert(0, f"{base}.{s_upper}")
    for c in candidates:
        if c in arm_obj.data.bones:
            return c
    return None


def split_mesh_by_side(mesh_obj, arm_obj):
    """Split combined two-arm mesh into Arm_L and Arm_R using vertex group weights and smooth shading."""
    vgroups = {vg.index: vg.name for vg in mesh_obj.vertex_groups}
    created = []

    for side_tag, keep_suffix in [("Arm_L", ".L"), ("Arm_R", ".R")]:
        dup = mesh_obj.copy()
        dup.data = mesh_obj.data.copy()
        dup.name = side_tag
        bpy.context.collection.objects.link(dup)

        vert_keep = set()
        for v in dup.data.vertices:
            w_l, w_r = 0.0, 0.0
            for g in v.groups:
                name = vgroups.get(g.group, "")
                if name.endswith(".L") or name.endswith("_l"):
                    w_l += g.weight
                elif name.endswith(".R") or name.endswith("_r"):
                    w_r += g.weight
            if (keep_suffix == ".L" and w_l >= w_r) or (keep_suffix == ".R" and w_r > w_l):
                vert_keep.add(v.index)

        bm = bmesh.new()
        bm.from_mesh(dup.data)
        bm.verts.ensure_lookup_table()
        del_faces = [f for f in bm.faces if sum(1 for v in f.verts if v.index in vert_keep) < 2]
        bmesh.ops.delete(bm, geom=del_faces, context='FACES')
        for f in bm.faces:
            f.smooth = True
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(dup.data)
        bm.free()

        dup.parent = arm_obj
        created.append(dup)
        print(f"SPLIT {side_tag}: verts={len(dup.data.vertices)} polys={len(dup.data.polygons)}")

    bpy.data.objects.remove(mesh_obj, do_unlink=True)
    return created


def palm_normal_arm(arm_obj, side: str) -> Vector:
    b_idx = arm_obj.data.bones[find_bone_name(arm_obj, "index.01", side)]
    b_idx2 = arm_obj.data.bones[find_bone_name(arm_obj, "index.02", side)]
    b_pnk = arm_obj.data.bones[find_bone_name(arm_obj, "pinky.01", side)]

    hinge = (b_idx.head_local - b_pnk.head_local).normalized()
    fwd = (b_idx2.head_local - b_idx.head_local).normalized()
    fwd = (fwd - hinge * hinge.dot(fwd)).normalized()
    n = hinge.cross(fwd).normalized()
    if side.lower() == "r":
        n = -n
    return n


def curl_finger(arm_obj, side: str, finger: str, angles_deg: list[float]):
    palm = palm_normal_arm(arm_obj, side)
    b1_name = find_bone_name(arm_obj, f"{finger}.01", side)
    if not b1_name:
        return
    b1 = arm_obj.data.bones[b1_name]
    dir_arm = (b1.tail_local - b1.head_local)
    dir_arm = (dir_arm - palm * palm.dot(dir_arm)).normalized()
    if dir_arm.length < 1e-4:
        return

    hinge_arm = dir_arm.cross(palm).normalized()

    for j, deg in enumerate(angles_deg, start=1):
        bname = find_bone_name(arm_obj, f"{finger}.0{j}", side)
        if not bname:
            continue
        pb = arm_obj.pose.bones[bname]
        pb.rotation_mode = 'QUATERNION'
        rest_rot = pb.bone.matrix_local.to_3x3()
        hinge_local = (rest_rot.inverted() @ hinge_arm).normalized()
        pb.rotation_quaternion = Quaternion(hinge_local, math.radians(deg))
        pb.keyframe_insert(data_path="rotation_quaternion", frame=1)


def pose_thumb(arm_obj, side: str, abduct_deg: float, flex_deg: list[float]):
    """Abduct thumb out of palm plane on joint 01, then curl joints 01-03 toward palm."""
    palm = palm_normal_arm(arm_obj, side)
    t1_name = find_bone_name(arm_obj, "thumb.01", side)
    if not t1_name:
        return
    t1 = arm_obj.data.bones[t1_name]
    dir_arm = (t1.tail_local - t1.head_local).normalized()
    hinge_arm = dir_arm.cross(palm).normalized()

    for j, deg in enumerate(flex_deg, start=1):
        bname = find_bone_name(arm_obj, f"thumb.0{j}", side)
        if not bname:
            continue
        pb = arm_obj.pose.bones[bname]
        pb.rotation_mode = 'QUATERNION'
        rest_rot = pb.bone.matrix_local.to_3x3()
        hinge_local = (rest_rot.inverted() @ hinge_arm).normalized()
        q = Quaternion(hinge_local, math.radians(deg))
        if j == 1 and abs(abduct_deg) > 0.01:
            palm_local = (rest_rot.inverted() @ palm).normalized()
            sign = 1.0 if side.lower() == "l" else -1.0
            q = Quaternion(palm_local, math.radians(abduct_deg * sign)) @ q
        pb.rotation_quaternion = q
        pb.keyframe_insert(data_path="rotation_quaternion", frame=1)


def reset_pose(arm_obj):
    for pb in arm_obj.pose.bones:
        pb.rotation_mode = 'QUATERNION'
        pb.rotation_quaternion = Quaternion((1, 0, 0, 0))


def create_pose_action(arm_obj, name: str, pose_fn):
    action = bpy.data.actions.new(name=name)
    arm_obj.animation_data_create()
    arm_obj.animation_data.action = action
    reset_pose(arm_obj)
    pose_fn(arm_obj)

    track = arm_obj.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 1, action)
    arm_obj.animation_data.action = None
    print(f"ANIMATION CREATED: {name}")


def pose_idle_open(arm_obj):
    for f in FINGERS:
        curl_finger(arm_obj, "l", f, [6.0, 5.0, 3.0])
    pose_thumb(arm_obj, "l", -8.0, [-8.0, -5.0, -2.0])


def pose_carry_palm(arm_obj):
    curl_finger(arm_obj, "l", "index", [18.0, 26.0, 18.0])
    curl_finger(arm_obj, "l", "middle", [20.0, 28.0, 20.0])
    curl_finger(arm_obj, "l", "ring", [20.0, 28.0, 20.0])
    curl_finger(arm_obj, "l", "pinky", [18.0, 24.0, 16.0])
    pose_thumb(arm_obj, "l", 18.0, [14.0, 18.0, 12.0])


def pose_carry_box(arm_obj):
    for f in FINGERS:
        curl_finger(arm_obj, "l", f, [12.0, 18.0, 12.0])
    pose_thumb(arm_obj, "l", 22.0, [10.0, 14.0, 10.0])


def pose_grip_grabber(arm_obj):
    for f in FINGERS:
        curl_finger(arm_obj, "l", f, [58.0, 68.0, 42.0])
    pose_thumb(arm_obj, "l", 20.0, [25.0, 32.0, 20.0])


def pose_hold_bag(arm_obj):
    for f in FINGERS:
        curl_finger(arm_obj, "r", f, [62.0, 72.0, 45.0])
    pose_thumb(arm_obj, "r", 20.0, [28.0, 34.0, 22.0])


def main():
    if not SRC_FBX.exists():
        raise FileNotFoundError(f"Missing source FBX: {SRC_FBX}")

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(SRC_FBX))

    arm_obj = next((o for o in bpy.data.objects if o.type == 'ARMATURE'), None)
    mesh_obj = next((o for o in bpy.data.objects if o.type == 'MESH'), None)
    if not arm_obj or not mesh_obj:
        raise RuntimeError("Missing Armature or Mesh in _fps_arms.fbx")

    split_mesh_by_side(mesh_obj, arm_obj)

    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode='POSE')

    for anim_name, fn in [
        ("idle_open", pose_idle_open),
        ("carry_palm", pose_carry_palm),
        ("carry_box", pose_carry_box),
        ("grip_grabber", pose_grip_grabber),
        ("hold_bag", pose_hold_bag),
    ]:
        create_pose_action(arm_obj, anim_name, fn)

    bpy.ops.object.mode_set(mode='OBJECT')

    bpy.ops.export_scene.gltf(
        filepath=str(OUT_GLB),
        export_format='GLB',
        export_animations=True,
        export_nla_strips=True,
        export_def_bones=True,
    )
    if not OUT_GLB.exists() or OUT_GLB.stat().st_size == 0:
        raise RuntimeError(f"Export failed or produced empty file: {OUT_GLB}")
    print(f"SUCCESS: Exported {OUT_GLB} ({OUT_GLB.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
