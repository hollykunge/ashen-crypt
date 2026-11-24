"""Assemble one Quaternius character (shared armature + all outfit parts + head) with a run action.

blender -b --factory-startup -P build_scene.py -- <out.blend> <action_name>
"""
import bpy, sys, os, math

argv = sys.argv[sys.argv.index("--") + 1:]
OUT_BLEND, ACTION = argv[0], argv[1]

Q = r"D:\quaternius"
UBC = Q + r"\UBC_Standard\Universal Base Characters[Standard]"
PARTS = Q + r"\Outfits_Fantasy_Standard\Modular Character Outfits - Fantasy[Standard]\Exports\glTF (Godot-Unreal)\Modular Parts"
UAL = Q + r"\UAL_Standard\Universal Animation Library[Standard]\Unreal-Godot\UAL1_Standard.glb"
HAIR = UBC + r"\Hairstyles\Rigged to Head Bone\glTF (Godot -Unreal)"

bpy.ops.wm.read_factory_settings(use_empty=True)


def imp(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def drop(objs):
    for o in objs:
        bpy.data.objects.remove(o, do_unlink=True)


def adopt(objs, arm, collection):
    """Rebind imported meshes to the master armature; delete their own armature/helpers."""
    keep = []
    for o in objs:
        if o.type == "MESH" and o.name.startswith("Icosphere"):
            continue
        if o.type == "MESH":
            mw = o.matrix_world.copy()
            o.parent = arm
            o.matrix_world = mw
            for m in o.modifiers:
                if m.type == "ARMATURE":
                    m.object = arm
            for c in o.users_collection:
                c.objects.unlink(o)
            collection.objects.link(o)
            keep.append(o)
    drop([o for o in objs if o not in keep and o is not arm])
    return keep


# ---- master armature: from Male_Peasant parts (Regular male proportions)
master_objs = imp(PARTS + r"\Male_Peasant_Body.gltf")
arm = next(o for o in master_objs if o.type == "ARMATURE")
arm.name = "Rig"
col_parts = bpy.data.collections.new("Parts")
bpy.context.scene.collection.children.link(col_parts)
adopt(master_objs, arm, col_parts)

part_files = ["Male_Peasant_Arms", "Male_Peasant_Feet", "Male_Peasant_Legs",
              "Male_Ranger_Acc_Pauldron", "Male_Ranger_Arms", "Male_Ranger_Body", "Male_Ranger_Feet_Boots",
              "Male_Ranger_Head_Hood", "Male_Ranger_Legs"]
for f in part_files:
    adopt(imp(PARTS + "\\" + f + ".gltf"), arm, col_parts)

# ---- head from the Superhero body: keep only vertices above the neck
head_objs = imp(UBC + r"\Base Characters\Godot - UE\Superhero_Male_FullBody.gltf")
heads = adopt(head_objs, arm, col_parts)
neck_z = (arm.matrix_world @ arm.data.bones["neck_01"].head_local).z
for o in heads:
    if o.name.startswith("SuperHero"):
        o.name = "Head_Skin"
        bpy.context.view_layer.objects.active = o
        me = o.data
        import bmesh
        bm = bmesh.new()
        bm.from_mesh(me)
        # keep vertices mostly driven by the head/neck bones
        keep_groups = {o.vertex_groups[n].index for n in ("Head", "neck_01", "neck_02") if n in o.vertex_groups}
        dl = bm.verts.layers.deform.active
        bad = []
        for v in bm.verts:
            w = v[dl]
            tot = sum(w.values()) or 1.0
            if sum(val for gi, val in w.items() if gi in keep_groups) / tot < 0.5:
                bad.append(v)
        bmesh.ops.delete(bm, geom=bad, context="VERTS")
        bm.to_mesh(me)
        bm.free()
    elif o.name.startswith("Eyes"):
        o.name = "Head_Eyes"
    elif o.name.startswith("Eyebrows"):
        o.name = "Head_Eyebrows"
for f in ("Hair_SimpleParted", "Hair_Beard"):
    for o in adopt(imp(HAIR + "\\" + f + ".gltf"), arm, col_parts):
        o.name = "Head_" + f

# ---- animation from the Universal Animation Library (no root motion version)
anim_objs = imp(UAL)
src_arm = next(o for o in anim_objs if o.type == "ARMATURE")
act = bpy.data.actions[ACTION]
act.use_fake_user = True
drop(anim_objs)
arm.animation_data_create()
arm.animation_data.action = act
if hasattr(act, "slots") and len(act.slots):
    arm.animation_data.action_slot = act.slots[0]
    print("SLOT", act.slots[0].identifier)
f0, f1 = (int(round(v)) for v in act.frame_range)
sc = bpy.context.scene
sc.frame_start, sc.frame_end = f0, f1
print("ACTION", ACTION, "frames", f0, f1, "fps", sc.render.fps)

# drop other imported actions to keep the file small
for a in list(bpy.data.actions):
    if a is not act:
        bpy.data.actions.remove(a)

print("PARTS", sorted(o.name for o in col_parts.objects))
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
