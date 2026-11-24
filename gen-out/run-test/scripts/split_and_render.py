"""Split outfit parts into far/mid/near pieces, frame the camera, render one layer per slot-variant-side,
and render the true 3D image of every outfit combination for validation.

blender -b char.blend -P split_and_render.py -- <out_dir> <frames comma list>
"""
import bpy, bmesh, sys, os, json, itertools
sys.path.insert(0, os.path.dirname(__file__))
import render_lib as R

argv = sys.argv[sys.argv.index("--") + 1:]
OUT = argv[0]
FRAMES = [int(x) for x in argv[1].split(",")]
os.makedirs(OUT, exist_ok=True)

# camera sits on the character's right side (-X): right-side bones are near, left-side bones are far
SIDE_BONES = ("clavicle", "upperarm", "lowerarm", "hand", "thumb", "index", "middle", "ring", "pinky",
              "thigh", "calf", "foot", "ball")


def side_of_group(name):
    low = name.lower()
    if any(low.startswith(b) for b in SIDE_BONES):
        if low.endswith("_r") or "_r_" in low:
            return "near"
        if low.endswith("_l") or "_l_" in low:
            return "far"
    return "mid"


def split_object(o):
    gside = {g.index: side_of_group(g.name) for g in o.vertex_groups}
    bm = bmesh.new()
    bm.from_mesh(o.data)
    dl = bm.verts.layers.deform.active
    vside = {}
    for v in bm.verts:
        acc = {"far": 0.0, "mid": 0.0, "near": 0.0}
        if dl is not None:
            for gi, w in v[dl].items():
                acc[gside.get(gi, "mid")] += w
        vside[v.index] = max(acc, key=acc.get)
    fside = {}
    for f in bm.faces:
        votes = {"far": 0, "mid": 0, "near": 0}
        for v in f.verts:
            votes[vside[v.index]] += 1
        fside[f.index] = max(votes, key=votes.get)
    bm.free()
    out = {}
    for side in ("far", "mid", "near"):
        if side not in fside.values():
            continue
        n = o.copy()
        n.data = o.data.copy()
        n.name = f"{o.name}__{side}"
        for c in o.users_collection:
            c.objects.link(n)
        bm = bmesh.new()
        bm.from_mesh(n.data)
        bm.faces.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if fside[f.index] != side], context="FACES")
        bm.to_mesh(n.data)
        bm.free()
        out[side] = n.name
    return out


pieces = {}
for name in R.all_part_names():
    pieces[name] = split_object(bpy.data.objects[name])

# head without hair (used when the hood is on)
R.SLOTS["head"]["hooded"] = [n for n in R.SLOTS["head"]["bare"] if n != "Head_Hair_SimpleParted"]

cam = R.setup_scene()
R.frame_camera(cam, R.all_part_names(), FRAMES)

# ---- one layer per slot / variant / side (parts of the same slot are rendered together -> exact occlusion inside a slot)
layers = {}
for slot, variants in R.SLOTS.items():
    for variant, parts in variants.items():
        for side in ("far", "mid", "near"):
            objs = [pieces[p][side] for p in parts if side in pieces[p]]
            if not objs:
                continue
            layers.setdefault(slot, {}).setdefault(variant, []).append(side)
            R.show_only(objs)
            for fr in FRAMES:
                bpy.context.scene.frame_set(fr)
                R.render_to(os.path.join(OUT, "layers", slot, variant, side, f"f{fr:02d}.png"))

# ---- 3D truth for every combination (hood on -> hair hidden, same as objects_for)
slots = [s for s in R.SLOTS if s != "head"]
short = {"peasant": "p", "ranger": "r", "none": "0"}
combos = {}
for vals in itertools.product(*[[v for v in R.SLOTS[s]] for s in slots]):
    m = dict(zip(slots, vals))
    m["head"] = "bare"
    combos["".join(short[m[s]] for s in slots)] = m
for cname, outfit in combos.items():
    R.show_only(R.objects_for(outfit))
    for fr in FRAMES:
        bpy.context.scene.frame_set(fr)
        R.render_to(os.path.join(OUT, "truth3d", cname, f"f{fr:02d}.png"))

json.dump(combos, open(os.path.join(OUT, "combos.json"), "w"), indent=1)
json.dump({"slot_order_key": slots, "layers": layers, "pieces": pieces, "frames": FRAMES,
           "ortho_scale": cam.data.ortho_scale, "cam_location": list(cam.location),
           "fps": bpy.context.scene.render.fps, "resolution": [R.W, R.H]},
          open(os.path.join(OUT, "render_meta.json"), "w"), indent=1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "scene_split.blend"))
print("DONE layers", sum(len(s) for v in layers.values() for s in v.values()), "combos", len(combos))
