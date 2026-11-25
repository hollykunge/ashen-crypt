"""blender -b -P render_parts.py -- <model.glb> <cell_dir> <manifest.json>
Per mesh part: isolated textured front, isolated back, and in-context (part textured, rest ghosted)."""
import bpy, sys, os, math, json
from mathutils import Vector
argv = sys.argv[sys.argv.index("--")+1:]
GLB, OUTDIR, MAN = argv[0], argv[1], argv[2]
os.makedirs(OUTDIR, exist_ok=True)
CELL = 320
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
sc = bpy.context.scene
meshes = [o for o in sc.objects if o.type == 'MESH']
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"
sc.display.shading.color_type = "TEXTURE"
sc.display.shading.show_cavity = True
sc.display.shading.show_backface_culling = False
sc.render.resolution_x = sc.render.resolution_y = CELL
sc.world = bpy.data.worlds.new("W"); sc.world.color = (0.86, 0.84, 0.80)
sc.view_settings.view_transform = "Standard"

def bbox(objs):
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi

cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.type = "ORTHO"
def aim(objs, yaw, pad=1.15):
    lo, hi = bbox(objs); c = (lo+hi)/2; size = max(hi-lo)
    cam.data.ortho_scale = size*pad
    d = Vector((math.sin(math.radians(yaw)), -math.cos(math.radians(yaw)), 0))
    cam.location = c + d*(size*4+2)
    cam.rotation_euler = (math.radians(90), 0, math.radians(yaw))
    cam.data.clip_end = size*10+10

ghost = bpy.data.materials.new("Ghost"); ghost.diffuse_color = (0.55, 0.57, 0.62, 1.0)
orig = {o.name: [s.material for s in o.material_slots] for o in meshes}
def set_ghost(o, on):
    for i, s in enumerate(o.material_slots):
        s.material = ghost if on else orig[o.name][i]

def render(path):
    sc.render.filepath = path; bpy.ops.render.render(write_still=True)

info = []
for o in meshes:
    o.data.calc_loop_triangles()
    info.append({"name": o.name, "tris": len(o.data.loop_triangles)})
# full model row first
rows = []
row = []
for yaw, lab in ((90, "front"), (55, "3/4"), (-90, "back")):
    for m in meshes: m.hide_render = False
    aim(meshes, yaw); p = os.path.join(OUTDIR, f"full_{yaw}.png"); render(p); row.append([f"FULL {lab}", p])
rows.append(row)
for idx, o in enumerate(meshes):
    row = []
    # isolated front / back
    for m in meshes: m.hide_render = (m is not o)
    for yaw, lab in ((90, "front"), (-90, "back")):
        aim([o], yaw); p = os.path.join(OUTDIR, f"p{idx}_{yaw}.png"); render(p)
        row.append([f"{o.name} {lab} ({info[idx]['tris']} tri)", p])
    # context
    for m in meshes: m.hide_render = False; set_ghost(m, m is not o)
    aim(meshes, 55); p = os.path.join(OUTDIR, f"p{idx}_ctx.png"); render(p); row.append([f"{o.name} in context", p])
    for m in meshes: set_ghost(m, False)
    rows.append(row)
json.dump({"rows": rows, "info": info}, open(MAN, "w"), ensure_ascii=False, indent=1)
print("DONE", len(meshes))
