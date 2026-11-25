"""blender -b outfits_rigged.blend -P anim_check.py -- <out_dir> <combos.json>"""
import bpy, sys, os, json, math
from mathutils import Vector, Matrix
a = sys.argv[sys.argv.index("--")+1:]; OUT, CMB = a; os.makedirs(OUT, exist_ok=True); combos = json.load(open(CMB))
sc = bpy.context.scene; rig = bpy.data.objects["Rig"]
sc.render.engine = "BLENDER_WORKBENCH"; sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "TEXTURE"
sc.display.shading.show_backface_culling = False
sc.render.film_transparent = False; sc.render.resolution_x = int(os.environ.get("RW", 300)); sc.render.resolution_y = int(os.environ.get("RH", 360)); sc.world = sc.world or bpy.data.worlds.new("W"); sc.world.color = (0.86, 0.84, 0.8)
cam = bpy.data.objects.new("CheckCam", bpy.data.cameras.new("CheckCam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.type = "ORTHO"; cam.data.ortho_scale = float(os.environ.get("OS", 2.3))
yaw = float(os.environ.get("YAW", 35)); d = Vector((math.sin(math.radians(yaw)), -math.cos(math.radians(yaw)), 0))
cam.location = d * 6 + Vector((0, 0, float(os.environ.get("CZ", 0.95)))); cam.rotation_euler = (math.radians(90), 0, math.radians(yaw))
TAG = {"peasant": "peasant3", "leather-2": "leather2", "chain-2": "chain2"}
FOREARM_ONLY = {"chain2"}
meshes = {o.name: o for o in bpy.data.objects if o.type == "MESH"}
def visible(cfg):
    show = {"body__base_body", "peasant3__body_head"}
    for slot, s in cfg.items():
        if s == "none": continue
        t = TAG[s]
        if t == "peasant3":
            if slot == "helmet": show.add("peasant3__hair_topknot")
            elif slot.startswith("arm_"): show |= {f"peasant3__body_{slot}", f"peasant3__bracer_{slot[-1]}"}
            else: show.add(f"peasant3__{slot}")
        else:
            show.add(f"{t}__{slot}")
            if slot.startswith("arm_") and t in FOREARM_ONLY and TAG[cfg.get("top", "peasant")] != t:
                show.add(f"peasant3__body_{slot}")
    return show
SHOTS = json.loads(os.environ["SHOTS"]) if "SHOTS" in os.environ else [("rest", None, 0), ("Idle_Loop", "Idle_Loop", 30), ("Walk_Loop", "Walk_Loop", 8), ("Walk_Loop", "Walk_Loop", 24),
         ("Sword_Attack", "Sword_Attack", 18), ("Punch_Cross", "Punch_Cross", 12), ("Roll", "Roll", 14)]
def assign(act):
    rig.animation_data_create(); rig.animation_data.action = act
    if act is not None and hasattr(rig.animation_data, "action_slot") and act.slots: rig.animation_data.action_slot = act.slots[0]
rows = []
for cname, cfg in combos.items():
    vis = visible(cfg); missing = [n for n in vis if n not in meshes]
    if missing: print("MISSING", cname, missing)
    for n, o in meshes.items(): o.hide_render = n not in vis
    row = []
    for label, an, f in SHOTS:
        if an is None:
            assign(None)
            for pb in rig.pose.bones: pb.matrix_basis = Matrix()
        else: assign(bpy.data.actions[an])
        sc.frame_set(f)
        p = os.path.join(OUT, f"{cname}_{len(row)}.png"); sc.render.filepath = p; bpy.ops.render.render(write_still=True)
        row.append([f"{label} {f}" if an else "T rest", p])
    rows.append([cname, row])
json.dump(rows, open(os.path.join(OUT, "rows.json"), "w")); print("DONE")
