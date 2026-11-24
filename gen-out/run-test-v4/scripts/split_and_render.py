"""Split outfit parts into far/mid/near pieces, frame the camera, render one layer per slot-variant-side,
and render the true 3D image of every outfit combination for validation.

blender -b char.blend -P split_and_render.py -- <out_dir> <frames comma list>
"""
import bpy, sys, os, json, itertools
sys.path.insert(0, os.path.dirname(__file__))
import render_lib as R

argv = sys.argv[sys.argv.index("--") + 1:]
OUT = argv[0]
FRAMES = [int(x) for x in argv[1].split(",")]
STYLE = set(argv[2].split("+")) if len(argv) > 2 and argv[2] != "none" else set()
SS = 2 if STYLE else 1  # styled renders are supersampled 2x and downscaled afterwards
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


SIDE_VAL = {"far": 0.0, "mid": 0.5, "near": 1.0}


def tag_sides(o):
    """Tag every face corner with its side (far/mid/near) in a float color attribute; the mesh stays whole,
    so the outline shell (Solidify copies corner data) is still the silhouette of the complete part."""
    gside = {g.index: side_of_group(g.name) for g in o.vertex_groups}
    me = o.data
    vside = []
    for v in me.vertices:
        acc = {"far": 0.0, "mid": 0.0, "near": 0.0}
        for g in v.groups:
            acc[gside.get(g.group, "mid")] += g.weight
        vside.append(max(acc, key=acc.get))
    attr = me.color_attributes.get("side_tag") or me.color_attributes.new("side_tag", "FLOAT_COLOR", "CORNER")
    present = set()
    for p in me.polygons:
        votes = {"far": 0, "mid": 0, "near": 0}
        for vi in p.vertices:
            votes[vside[vi]] += 1
        side = max(votes, key=votes.get)
        present.add(side)
        val = SIDE_VAL[side]
        for li in p.loop_indices:
            attr.data[li].color = (val, val, val, 1.0)
    return {side: o.name for side in ("far", "mid", "near") if side in present}


SEL_NODES = []


def add_side_mask(mat):
    """Faces whose side_tag differs from the selected side become holdout (they still occlude, but leave alpha 0)."""
    nt = mat.node_tree
    N, L = nt.nodes, nt.links
    out = next((n for n in N if n.bl_idname == "ShaderNodeOutputMaterial" and n.is_active_output), None) or         next((n for n in N if n.bl_idname == "ShaderNodeOutputMaterial"), None)
    if out is None or not out.inputs["Surface"].links:
        return
    surf = out.inputs["Surface"].links[0].from_socket
    at = N.new("ShaderNodeAttribute"); at.attribute_name = "side_tag"; at.attribute_type = "GEOMETRY"
    sep = N.new("ShaderNodeSeparateColor")
    L.new(at.outputs["Color"], sep.inputs[0])
    sel = N.new("ShaderNodeValue"); sel.name = "SIDE_SEL"; sel.outputs[0].default_value = -1.0
    SEL_NODES.append(sel)
    d = N.new("ShaderNodeMath"); d.operation = "SUBTRACT"
    L.new(sep.outputs[0], d.inputs[0]); L.new(sel.outputs[0], d.inputs[1])
    ab = N.new("ShaderNodeMath"); ab.operation = "ABSOLUTE"; L.new(d.outputs[0], ab.inputs[0])
    gt = N.new("ShaderNodeMath"); gt.operation = "GREATER_THAN"; gt.inputs[1].default_value = 0.25
    L.new(ab.outputs[0], gt.inputs[0])
    on = N.new("ShaderNodeMath"); on.operation = "GREATER_THAN"; on.inputs[1].default_value = -0.5
    L.new(sel.outputs[0], on.inputs[0])
    m = N.new("ShaderNodeMath"); m.operation = "MULTIPLY"
    L.new(gt.outputs[0], m.inputs[0]); L.new(on.outputs[0], m.inputs[1])
    ho = N.new("ShaderNodeHoldout")
    mix = N.new("ShaderNodeMixShader")
    L.new(m.outputs[0], mix.inputs["Fac"]); L.new(surf, mix.inputs[1]); L.new(ho.outputs[0], mix.inputs[2])
    L.new(mix.outputs[0], out.inputs["Surface"])


def select_side(side):
    v = -1.0 if side is None else SIDE_VAL[side]
    for n in SEL_NODES:
        n.outputs[0].default_value = v


# camera first (same framing as the unstyled run), then style the original parts, then split them
cam = R.setup_scene()
R.frame_camera(cam, R.all_part_names(), FRAMES)
if STYLE:
    import style_lib
    style_lib.apply(STYLE, cam, R.all_part_names())
    bpy.context.scene.render.resolution_percentage = 100 * SS

pieces = {}
for name in R.all_part_names():
    pieces[name] = tag_sides(bpy.data.objects[name])
for mat in bpy.data.materials:
    if mat.use_nodes:
        add_side_mask(mat)

# head without hair (used when the hood is on)
R.SLOTS["head"]["hooded"] = [n for n in R.SLOTS["head"]["bare"] if n != "Head_Hair_SimpleParted"]


# ---- one layer per slot / variant / side (parts of the same slot are rendered together -> exact occlusion inside a slot)
layers = {}
for slot, variants in R.SLOTS.items():
    for variant, parts in variants.items():
        for side in ("far", "mid", "near"):
            if not any(side in pieces[p] for p in parts):
                continue
            layers.setdefault(slot, {}).setdefault(variant, []).append(side)
            R.show_only(parts)  # whole parts visible; other sides become holdout
            select_side(side)
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
select_side(None)
for cname, outfit in combos.items():
    R.show_only(R.objects_for(outfit))
    for fr in FRAMES:
        bpy.context.scene.frame_set(fr)
        R.render_to(os.path.join(OUT, "truth3d", cname, f"f{fr:02d}.png"))

json.dump(combos, open(os.path.join(OUT, "combos.json"), "w"), indent=1)
json.dump({"slot_order_key": slots, "layers": layers, "pieces": pieces, "frames": FRAMES,
           "ortho_scale": cam.data.ortho_scale, "cam_location": list(cam.location),
           "fps": bpy.context.scene.render.fps, "resolution": [R.W, R.H],
           "style": sorted(STYLE), "supersample": SS},
          open(os.path.join(OUT, "render_meta.json"), "w"), indent=1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "scene_split.blend"))
print("DONE layers", sum(len(s) for v in layers.values() for s in v.values()), "combos", len(combos))
