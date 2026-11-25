"""blender -b -P mix.py -- <parts_dir> <out_dir> <combos.json>
combos: {name: {slot: source}} with source in peasant|leather-2|chain-2|none. Body (base_body + body_head) always on;
peasant body_arm shown when arm slot source is peasant; hair_topknot hidden when a helmet is worn."""
import bpy, sys, os, json, math
from mathutils import Vector
a = sys.argv[sys.argv.index("--")+1:]; PD, OUT, CMB = a[:3]; BODY = a[3] if len(a) > 3 else None; os.makedirs(OUT, exist_ok=True); combos = json.load(open(CMB))
bpy.ops.wm.read_factory_settings(use_empty=True)
src = {"peasant": os.path.join(PD, "slots/_all_slots.glb"), "leather-2": os.path.join(PD, "leather-2/slots_aligned/_all_slots.glb"),
       "chain-2": os.path.join(PD, "chain-2/slots_aligned/_all_slots.glb"), "body": BODY or os.path.join(PD, "base_body/base_body.glb")}
FOREARM_ONLY = {"chain-2"}   # sets whose arm slot is bracer+hand; the upper sleeve lives in their top
M = {}
for tag, p in src.items():
    before = set(bpy.context.scene.objects); bpy.ops.import_scene.gltf(filepath=p)
    new = [o for o in bpy.context.scene.objects if o not in before and o.type == 'MESH']
    for o in new:
        base = "base_body" if tag == "body" else o.data.name.split(".")[0]
        o.name = f"{tag}:{base}"; M[(tag, base)] = o
    print("LOADED", tag, sorted(k[1] for k in M if k[0] == tag))
sc = bpy.context.scene; sc.render.engine = "BLENDER_WORKBENCH"; sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "TEXTURE"
sc.display.shading.show_backface_culling = False
sc.render.resolution_x = sc.render.resolution_y = 420; sc.world = bpy.data.worlds.new("W"); sc.world.color = (0.86, 0.84, 0.8)
cam = bpy.data.objects.new("C", bpy.data.cameras.new("C")); sc.collection.objects.link(cam); sc.camera = cam; cam.data.type = "ORTHO"; cam.data.ortho_scale = 1.08
pmap = {"helmet": None, "top": "top", "belt": "belt", "pants": "pants", "boot_R": "boot_R", "boot_L": "boot_L", "arm_R": "body_arm_R", "arm_L": "body_arm_L"}
for cname, cfg in combos.items():
    show = {("body", "base_body"), ("peasant", "body_head")}
    for slot, s in cfg.items():
        if s == "none": continue
        if s == "peasant":
            if slot == "helmet": show.add(("peasant", "hair_topknot"))
            else:
                show.add(("peasant", pmap[slot]))
                if slot.startswith("arm_"): show.add(("peasant", "bracer_" + slot[-1]))
        else:
            show.add((s, slot))
            if slot.startswith("arm_") and s in FOREARM_ONLY and cfg.get("top") != s:
                show.add(("peasant", "body_arm_" + slot[-1]))   # bare upper arm under a sleeveless top
    for k, o in M.items(): o.hide_render = k not in show
    for yaw in (90, 45, -90):
        cam.rotation_euler = (math.radians(90), 0, math.radians(yaw)); cam.location = Vector((0, 0, 0)) - (cam.rotation_euler.to_matrix() @ Vector((0, 0, -1))) * 5
        sc.render.filepath = f"{OUT}/{cname}_{yaw}.png"; bpy.ops.render.render(write_still=True)
print("DONE")
