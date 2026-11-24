import bpy, sys, os, hashlib
out = sys.argv[sys.argv.index("--") + 1]
tex_dir = os.path.join(os.path.dirname(out), "textures")
os.makedirs(tex_dir, exist_ok=True)
# same fixed side camera / key light / world as the render scripts, so the file opens ready to render
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render_lib as R
R.enable_leather()
cam = R.setup_scene()
R.frame_camera(cam, R.all_part_names(), [0, 2, 4, 6, 8, 10, 12, 14])
for o in bpy.data.objects:
    if o.type == "MESH":
        o.hide_viewport = False; o.hide_render = False
by_hash = {}
packed = 0
for i in bpy.data.images:
    if i.source != "FILE":
        continue
    if i.packed_file:
        data = bytes(i.packed_file.data); packed += 1
        base = os.path.basename(i.filepath) or (i.name + ".png")
    else:
        src = bpy.path.abspath(i.filepath)
        if not os.path.exists(src):
            src = src.replace("_png.png", ".png")
        if not os.path.exists(src):
            print("MISSING", i.name, src); continue
        data = open(src, "rb").read(); base = os.path.basename(src)
    h = hashlib.sha1(data).hexdigest()
    if h not in by_hash:
        name = base.replace("_png.png", ".png")
        if any(n == name for n in by_hash.values()):
            name = h[:6] + "_" + name
        by_hash[h] = name
        open(os.path.join(tex_dir, name), "wb").write(data)
    if i.packed_file:
        i.unpack(method="REMOVE")
    i.filepath = "//textures/" + by_hash[h]
    i.reload()
bpy.ops.wm.save_as_mainfile(filepath=out, compress=True, relative_remap=False)
print("SAVED", out, "unique textures", len(by_hash), "were packed", packed)
