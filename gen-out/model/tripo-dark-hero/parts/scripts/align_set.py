"""blender -b -P align_set.py -- <peasant _all_slots.glb> <set _all_slots.glb> <out_dir>
Bring another outfit's slots into the peasant-3 frame: global scale about the soles (nose height), then per-slot rigid moves."""
import bpy, sys, os, json, numpy as np
from mathutils import Vector, Matrix
a = sys.argv[sys.argv.index("--")+1:]; PEA, SET, OUT = a; os.makedirs(OUT, exist_ok=True)
def load_set(path, tag):
    before = set(bpy.context.scene.objects); bpy.ops.import_scene.gltf(filepath=path)
    d = {}
    for o in bpy.context.scene.objects:
        if o not in before and o.type == 'MESH':
            o.name = tag + o.name; d[o.name[len(tag):]] = o
    return d
bpy.ops.wm.read_factory_settings(use_empty=True)
pea = load_set(PEA, "P_"); X = load_set(SET, "X_")
for o in list(pea.values()) + list(X.values()):
    bpy.context.view_layer.objects.active = o; o.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
V = lambda o: np.array([tuple(v.co) for v in o.data.vertices])
def nose(o):
    P = V(o); z0, z1 = P[:, 2].min(), P[:, 2].max()
    m = (np.abs(P[:, 1] - np.median(P[:, 1])) < 0.012) & (P[:, 2] > z0 + 0.25 * (z1 - z0)) & (P[:, 2] < z0 + 0.75 * (z1 - z0))
    return P[m][np.argmax(P[m, 0])]
def band_center(o, z0, z1):
    P = V(o); m = (P[:, 2] > z0) & (P[:, 2] < z1); q = P[m]; return (q.min(0) + q.max(0)) / 2
def arm_seg(o):
    P = V(o); tip = P[np.argmax(np.abs(P[:, 1]))]; root = P[np.argmin(np.abs(P[:, 1]))]; return root, tip
rep = {}
nP = nose(pea["body_head"]); nX = nose(X["head"])
s = (nP[2] + 0.5) / (nX[2] + 0.5); rep["nose_peasant"] = nP.round(3).tolist(); rep["nose_set"] = nX.round(3).tolist(); rep["scale"] = round(float(s), 4)
S = Matrix.Translation((0, 0, -0.5)) @ Matrix.Scale(s, 4) @ Matrix.Translation((0, 0, 0.5))
for o in X.values(): o.data.transform(S); o.data.update()
def move(o, M): o.data.transform(M); o.data.update()
moves = {}
# boots and pants follow the feet
bt = {}
for sd in ("R", "L"):
    cP = band_center(pea[f"boot_{sd}"], -0.5, -0.45); cX = band_center(X[f"boot_{sd}"], -0.5, -0.45)
    bt[sd] = Vector((cP[0] - cX[0], cP[1] - cX[1], 0)); move(X[f"boot_{sd}"], Matrix.Translation(bt[sd])); moves[f"boot_{sd}"] = list(bt[sd])
tp = (bt["R"] + bt["L"]) / 2; move(X["pants"], Matrix.Translation(tp)); moves["pants"] = list(tp)
# top & belt: chest centre
cP = band_center(pea["top"], 0.15, 0.25); cX = band_center(X["top"], 0.15, 0.25)
tt = Vector((cP[0] - cX[0], cP[1] - cX[1], 0))
for n in ("top", "belt"): move(X[n], Matrix.Translation(tt)); moves[n] = list(tt)
# helmet & face: nose to nose
nX2 = nose(X["head"]); th = Vector(tuple(nP - nX2))
for n in ("helmet", "head"): move(X[n], Matrix.Translation(th)); moves[n] = list(th)
# arms: map set tip->root direction onto the peasant arm, pivot at the fingertip
for sd in ("R", "L"):
    rX, tX = arm_seg(X[f"arm_{sd}"]); rP, tP = arm_seg(pea[f"body_arm_{sd}"])
    dX = Vector(tuple(rX - tX)).normalized(); dP = Vector(tuple(rP - tP)).normalized()
    R = dX.rotation_difference(dP).to_matrix().to_4x4()
    M = Matrix.Translation(Vector(tuple(tP))) @ R @ Matrix.Translation(-Vector(tuple(tX)))
    move(X[f"arm_{sd}"], M); moves[f"arm_{sd}"] = {"angle_deg": round(float(np.degrees(dX.angle(dP))), 1)}
rep["moves"] = {k: ([round(float(x), 4) for x in v] if isinstance(v, list) else v) for k, v in moves.items()}
for o in pea.values(): bpy.data.objects.remove(o)
for n, o in X.items(): o.name = n; o.data.name = n
for n, o in X.items():
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, f"{n}.glb"), export_format='GLB', use_selection=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "_all_slots.glb"), export_format='GLB', use_selection=True)
json.dump(rep, open(os.path.join(OUT, "align.json"), "w"), indent=1); print("REPORT", json.dumps(rep))
