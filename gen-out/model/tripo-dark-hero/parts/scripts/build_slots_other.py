"""blender -b -P build_slots_other.py -- <segmented.glb> <out_dir> <config.json>
config: {"top":[parts], "belt":[parts], "arms":[parts], "legs":[parts], "boot_extra":[parts], "helmet":[parts], "helmet_extra":[parts], "belt_from":part|null}"""
import bpy, bmesh, sys, os, json, colorsys, numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from splitlib import *
argv = sys.argv[sys.argv.index("--")+1:]; GLB, OUT, CFG = argv; cfg = json.load(open(CFG)); os.makedirs(OUT, exist_ok=True)
objs = load(GLB); sc = bpy.context.scene
P = lambda i: objs[f"tripo_part_{i}"]
def dup(src, name):
    o = src.copy(); o.data = src.data.copy(); o.name = name; sc.collection.objects.link(o); return o
def hue(o):
    me = o.data; uv = me.uv_layers.active.data; H = []
    px, W, Hh = tex_pixels(me)
    for p in me.polygons:
        us = [uv[i].uv for i in p.loop_indices]; u = sum(x[0] for x in us)/len(us); v = sum(x[1] for x in us)/len(us)
        H.append(colorsys.rgb_to_hsv(*px[int(v*Hh) % Hh, int(u*W) % W, :3]))
    return np.array(H)
def flip_small(mask, adj, minsize=30):
    m = mask.copy()
    for val in (True, False):
        for c in components(m == val, adj):
            if len(c) < minsize: m[c] = not val
    return m
slots = {}; rep = {}
def add(slot, o): slots.setdefault(slot, []).append(o)
def side_of(o):
    return "R" if np.mean([ (o.matrix_world @ v.co).y for v in o.data.vertices]) < 0 else "L"
for i in cfg["top"]: add("top", dup(P(i), f"top_{i}"))
for i in cfg.get("belt", []): add("belt", dup(P(i), f"belt_{i}"))
for i in cfg["arms"]:
    o = dup(P(i), f"arm_{i}"); add("arm_" + side_of(o), o)
for i in cfg.get("helmet_extra", []): add("helmet", dup(P(i), f"helmetx_{i}"))
for i in cfg.get("boot_extra", []):
    o = dup(P(i), f"bootx_{i}"); add("boot_" + side_of(o), o)
# legs: boot vs pants by nearest reference colour, boot = what connects to the sole
for i in cfg["legs"]:
    o = dup(P(i), f"tmpleg_{i}"); weld(o); C, N, L, Sa = face_data(o); adj = adjacency(o)
    z0 = C[:, 2].min(); feat = np.stack([L * 3, Sa * 2], 1)
    sole = C[:, 2] < z0 + 0.06; up = (C[:, 2] > z0 + 0.16) & (C[:, 2] < z0 + 0.26)
    rb, rp = np.median(feat[sole], 0), np.median(feat[up], 0)
    boot = (np.linalg.norm(feat - rb, axis=1) < np.linalg.norm(feat - rp, axis=1)) & (C[:, 2] < z0 + 0.2)
    boot = flip_small(smooth(boot, adj, 3), adj)
    keep = np.zeros(len(C), bool)
    for c in components(boot, adj):
        if sole[c].any(): keep[c] = True
    s = side_of(o)
    add("boot_" + s, extract(o, keep, f"boot_{s}_{i}")); add("pants", extract(o, ~keep, f"pants_{i}"))
    rep[f"leg_{i}"] = {"side": s, "boot_faces": int(keep.sum()), "pants_faces": int((~keep).sum()), "boot_top_z": round(float(C[keep, 2].max()), 3)}
# helmet vs face: largest skin-coloured component on the front of the head
for i in cfg["helmet"]:
    o = dup(P(i), f"tmphead_{i}"); weld(o); C, N, L, Sa = face_data(o); adj = adjacency(o); Hs = hue(o)
    cx = (C[:, 0].min() + C[:, 0].max()) / 2
    fc = cfg.get("face", {})
    skin = (Hs[:, 0] > 0.02) & (Hs[:, 0] < 0.11) & (Sa > fc.get("sat", 0.25)) & (Sa < 0.7) & (L > fc.get("lum", 0.2)) & (C[:, 0] > cx - 0.01)
    if "zmax" in fc: skin &= C[:, 2] < fc["zmax"]
    if "yhalf" in fc: skin &= np.abs(C[:, 1] - np.median(C[:, 1])) < fc["yhalf"]
    skin = flip_small(smooth(skin, adj, 2), adj, 15)
    comps = sorted(components(skin, adj), key=len, reverse=True)
    face = np.zeros(len(C), bool)
    if comps: face[comps[0]] = True
    if fc:
        for c in sorted(components(~face, adj), key=len, reverse=True)[1:]: face[c] = True   # beard/brows enclosed by the face
    add("head", extract(o, face, f"head_{i}")); add("helmet", extract(o, ~face, f"helmet_{i}"))
    rep[f"head_{i}"] = {"face_faces": int(face.sum()), "helmet_faces": int((~face).sum())}
# red sash fused with the armour skirt
if cfg.get("belt_from") is not None:
    i = cfg["belt_from"]; o = dup(P(i), f"tmpsash_{i}"); weld(o); C, N, L, Sa = face_data(o); adj = adjacency(o); Hs = hue(o)
    red = ((Hs[:, 0] < 0.04) | (Hs[:, 0] > 0.93)) & (Sa > 0.38)
    red = flip_small(smooth(red, adj, 2), adj, 25)
    add("belt", extract(o, red, f"belt_{i}")); add("top", extract(o, ~red, f"top_{i}"))
    rep["sash"] = {"belt_faces": int(red.sum()), "skirt_faces": int((~red).sum())}
for o in list(objs.values()): bpy.data.objects.remove(o)
for o in list(sc.objects):
    if o.name.startswith("tmp"): bpy.data.objects.remove(o)
tris = {}
for name, ol in slots.items():
    o = join(ol, name) if len(ol) > 1 else ol[0]; o.name = name; o.data.name = name
    o.data.calc_loop_triangles(); tris[name] = len(o.data.loop_triangles); slots[name] = o
for name, o in slots.items():
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, f"{name}.glb"), export_format='GLB', use_selection=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "_all_slots.glb"), export_format='GLB', use_selection=True)
rep["tris"] = tris; rep["tris_total"] = sum(tris.values())
json.dump(rep, open(os.path.join(OUT, "slots.json"), "w"), indent=1); print("REPORT", json.dumps(rep))
