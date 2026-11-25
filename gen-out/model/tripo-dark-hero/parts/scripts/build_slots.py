"""blender -b -P build_slots.py -- <segmented.glb> <out_dir>  -> slot GLBs + slots.json"""
import bpy, bmesh, sys, os, math, json, numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from splitlib import *
argv = sys.argv[sys.argv.index("--")+1:]; GLB, OUT = argv[0], argv[1]; os.makedirs(OUT, exist_ok=True)
objs = load(GLB); sc = bpy.context.scene
def dup(src, name):
    o = src.copy(); o.data = src.data.copy(); o.name = name; sc.collection.objects.link(o); return o
def flip_small(mask, adj, minsize=40):
    m = mask.copy()
    for val in (True, False):
        for c in components(m == val, adj):
            if len(c) < minsize: m[c] = not val
    return m
slots = {}; report = {}
# ---------- lower body: robe hem vs pants (crease flood fill from waist)
p0 = dup(objs["tripo_part_0"], "tmp_p0"); weld(p0)
C, N, L, Sa = face_data(p0); adj = adjacency(p0)
fn = np.array([tuple(p.normal) for p in p0.data.polygons]); cos_t = math.cos(math.radians(45))
reg = C[:, 2] > np.percentile(C[:, 2], 97); st = list(np.nonzero(reg)[0])
while st:
    f = st.pop()
    for g in adj[f]:
        if not reg[g] and fn[f] @ fn[g] > cos_t: reg[g] = True; st.append(g)
reg = flip_small(smooth(reg, adj, 2), adj)
pc = sorted(components(~reg, adj), key=len, reverse=True)
for c in pc[1:]: reg[c] = True  # stray robe flaps cut off by creases go back to the hem
hem = extract(p0, reg, "top_hem"); pants = extract(p0, ~reg, "pants")
report["hem_faces"] = int(reg.sum()); report["pants_faces"] = int((~reg).sum())
# ---------- arms: bracer / armhole rim / skin, then bridge the wrist gap with skin
rims = []
for side, (ua, hd) in {"R": ("tripo_part_4", "tripo_part_5"), "L": ("tripo_part_6", "tripo_part_8")}.items():
    arm = join([dup(objs[ua], "a" + side), dup(objs[hd], "h" + side)], "tmp_arm" + side); weld(arm)
    C, N, L, Sa = face_data(arm); adj = adjacency(arm)
    dark = smooth((L < 0.33) | (Sa < 0.22), adj, 3)
    ay = np.abs(C[:, 1]); sh = C[ay < np.percentile(ay, 5)].mean(0); tip = C[ay > np.percentile(ay, 98)].mean(0)
    ax = tip - sh; t = (C - sh) @ ax / (ax @ ax)
    br = np.zeros(len(C), bool); rim = np.zeros(len(C), bool)
    for c in components(dark, adj):
        tm = t[c].mean()
        if len(c) > 20 and tm > 0.45: br[c] = True
        elif len(c) > 20 and tm < 0.15: rim[c] = True
    skin = ~(br | rim)
    slots[f"bracer_{side}"] = [extract(arm, br, f"bracer_{side}")]
    rims.append(extract(arm, rim, f"top_armhole_{side}"))
    body = extract(arm, skin, f"body_arm_{side}")
    # pick a skin UV near the wrist for filler faces
    sk_idx = np.nonzero(skin & (t > 0.45) & (t < 0.6))[0]
    sk_idx = sk_idx[np.argsort(-L[sk_idx])][: max(1, len(sk_idx) // 3)]  # bright = skin, not shadow
    pick = int(sk_idx[len(sk_idx) // 2])
    # map original face index -> body face index: extract keeps order of kept faces
    body_face = int(np.cumsum(skin)[pick] - 1)
    bm = bmesh.new(); bm.from_mesh(body.data); bm.faces.ensure_lookup_table()
    uvl = bm.loops.layers.uv.active
    ref = bm.faces[body_face]; ref_uv = ref.loops[0][uvl].uv.copy(); ref_mat = ref.material_index
    # boundary edges created by removing the bracer: those whose position lies in the bracer band
    mw = body.matrix_world
    def tt(v): p = np.array(mw @ v.co); return (p - sh) @ ax / (ax @ ax)
    bt = t[br]; lo_t, hi_t = bt.min() - 0.03, bt.max() + 0.03
    cut = [e for e in bm.edges if e.is_boundary and all(lo_t < tt(v) < hi_t for v in e.verts)]
    nf0 = len(bm.faces)
    ok = "bridge"
    try:
        r = bmesh.ops.bridge_loops(bm, edges=cut)
        newf = r["faces"]
    except Exception as ex:
        ok = f"cap ({ex.__class__.__name__})"
        r = bmesh.ops.holes_fill(bm, edges=cut, sides=0); newf = r["faces"]
    for f in newf:
        f.material_index = ref_mat
        for lp in f.loops: lp[uvl].uv = ref_uv
    bm.to_mesh(body.data); bm.free(); body.data.update()
    slots[f"body_arm_{side}"] = [body]
    report[f"arm_{side}"] = {"bracer_faces": int(br.sum()), "rim_faces": int(rim.sum()), "skin_faces": int(skin.sum()),
                             "wrist_fill": ok, "fill_faces": len(newf), "cut_edges": len(cut)}
slots["top"] = [dup(objs["tripo_part_1"], "top_vest"), hem] + rims
slots["pants"] = [pants]
slots["belt"] = [dup(objs["tripo_part_2"], "belt")]
slots["boot_R"] = [dup(objs["tripo_part_3"], "boot_R")]
slots["boot_L"] = [dup(objs["tripo_part_7"], "boot_L")]
slots["body_head"] = [dup(objs["tripo_part_9"], "body_head")]
slots["hair_topknot"] = [dup(objs["tripo_part_10"], "hair_topknot")]
# ---------- export
for o in list(objs.values()): bpy.data.objects.remove(o)
for o in list(sc.objects):
    if o.name.startswith("tmp_"): bpy.data.objects.remove(o)
summary = {}
for name, ol in slots.items():
    if len(ol) > 1:
        o = join(ol, name)
    else:
        o = ol[0]; o.name = name
    o.data.name = name
    o.data.calc_loop_triangles(); summary[name] = len(o.data.loop_triangles)
    slots[name] = o
for name, o in slots.items():
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, f"{name}.glb"), export_format='GLB', use_selection=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "_all_slots.glb"), export_format='GLB', use_selection=True)
report["tris"] = summary; report["tris_total"] = sum(summary.values())
json.dump(report, open(os.path.join(OUT, "slots.json"), "w"), indent=1, ensure_ascii=False)
print("REPORT", json.dumps(report))
