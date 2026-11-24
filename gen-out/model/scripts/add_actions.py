"""Retarget animations from Quaternius' Universal Animation Library onto the model's Rig.

blender -b ashen_char_3outfits.blend -P add_actions.py -- <UAL1_Standard.glb> [out.blend]   (no out -> save in place)

Use the file WITHOUT root motion (UAL1_Standard.glb, not _RM): the 2D layers are rendered in place.

The UAL skeleton and Rig share bone names and hierarchy (UE style, 65 bones) but not their Blender rests: proportions
differ (Rig's legs are ~5 cm longer) and Blender's glTF importer gives some bones other rest orientations (spine_03
11 deg, neck 6 deg, thumbs, feet). Copying the keys would tilt those bones, so every frame is retargeted instead:
each bone gets the source bone's rotation-from-rest in armature space, positions follow Rig's own bone lengths,
and the pelvis translation is scaled by the pelvis-height ratio. Re-running replaces the actions.
"""
import bpy, sys
from mathutils import Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
GLB = argv[0]
OUT = argv[1] if len(argv) > 1 else bpy.data.filepath

WANT = ["Idle_Loop", "Walk_Loop", "Jog_Fwd_Loop", "Sprint_Loop", "Sword_Idle", "Sword_Attack",
        "Hit_Chest", "Hit_Head", "Death01", "Roll", "Punch_Cross", "Spell_Simple_Shoot"]
MOVERS = ("root", "pelvis")        # bones whose translation is animated

sc = bpy.context.scene
rig = bpy.data.objects["Rig"]
before_objs = set(bpy.data.objects)
before_acts = set(bpy.data.actions)
bpy.ops.import_scene.gltf(filepath=GLB)
new_objs = [o for o in bpy.data.objects if o not in before_objs]
src = next(o for o in new_objs if o.type == "ARMATURE")
imported = {a.name: a for a in bpy.data.actions if a not in before_acts}

missing = [b.name for b in rig.data.bones if b.name not in src.data.bones]
if missing:
    raise SystemExit(f"bones missing in UAL: {missing}")

order = []                          # parents before children
def visit(b):
    order.append(b.name)
    for c in b.children:
        visit(c)
for b in rig.data.bones:
    if b.parent is None:
        visit(b)

T_REST = {n: rig.data.bones[n].matrix_local.copy() for n in order}
S_REST = {n: src.data.bones[n].matrix_local.copy() for n in order}
H_RATIO = T_REST["pelvis"].translation.z / S_REST["pelvis"].translation.z


def assign(obj, act):
    if obj.animation_data is None:
        obj.animation_data_create()
    obj.animation_data.action = act
    if hasattr(obj.animation_data, "action_slot") and act.slots:
        obj.animation_data.action_slot = act.slots[0]


for pb in rig.pose.bones:
    pb.rotation_mode = "QUATERNION"

done = []
for name in WANT:
    s_act = next((a for n, a in imported.items() if n == name or n.startswith(name + ".")), None)
    if s_act is None:
        print("ACTION missing in UAL:", name)
        continue
    old = bpy.data.actions.get(name)
    if old is not None and old is not s_act:
        bpy.data.actions.remove(old)
    s_act.name = name + "__src"
    t_act = bpy.data.actions.new(name)
    t_act.use_fake_user = True
    assign(src, s_act)
    assign(rig, t_act)
    f0, f1 = (int(round(x)) for x in s_act.frame_range)
    for f in range(f0, f1 + 1):
        sc.frame_set(f)
        want = {}
        for n in order:
            sp = src.pose.bones[n].matrix                     # armature space
            rot = (sp.to_quaternion() @ S_REST[n].to_quaternion().inverted() @ T_REST[n].to_quaternion())
            parent = rig.data.bones[n].parent
            if n in MOVERS or parent is None:
                pos = T_REST[n].translation + (sp.translation - S_REST[n].translation) * H_RATIO
            else:
                pos = (want[parent.name] @ T_REST[parent.name].inverted() @ T_REST[n]).translation
            want[n] = Matrix.Translation(pos) @ rot.to_matrix().to_4x4()
        for n in order:
            pb = rig.pose.bones[n]
            parent = rig.data.bones[n].parent
            base = (want[parent.name] @ T_REST[parent.name].inverted() @ T_REST[n]) if parent else T_REST[n]
            basis = base.inverted() @ want[n]
            pb.rotation_quaternion = basis.to_quaternion()
            pb.keyframe_insert("rotation_quaternion", frame=f)
            if n in MOVERS or parent is None:
                pb.location = basis.translation
                pb.keyframe_insert("location", frame=f)
    done.append((name, f0, f1))
    print("ACTION", name, (f0, f1))

# clean up: imported objects and source actions
for o in new_objs:
    bpy.data.objects.remove(o, do_unlink=True)
for a in list(bpy.data.actions):
    if a.name not in WANT:
        bpy.data.actions.remove(a)
bpy.ops.outliner.orphans_purge(do_recursive=True)

act = bpy.data.actions["Sprint_Loop"]
assign(rig, act)
for pb in rig.pose.bones:
    pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0)
sc.frame_start, sc.frame_end = 0, int(act.frame_range[1])
sc.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath=OUT, relative_remap=True)
print("SAVED", OUT, sorted(a.name for a in bpy.data.actions), "pelvis ratio", round(H_RATIO, 3))
