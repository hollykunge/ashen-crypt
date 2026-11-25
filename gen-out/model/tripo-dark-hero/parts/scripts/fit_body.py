"""blender -b -P fit_body.py -- <raw_body.glb> <_all_slots.glb> <out.glb> <report.json>
Fit a generated bare body under the peasant-3 slots: orient, scale, align, crop head/arms, push poke-through inside clothes."""
import bpy, bmesh, sys, os, math, json, numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
a = sys.argv[sys.argv.index("--")+1:]; RAW, SLOTS, OUT, REP = a[:4]; EXTRA = a[4].split(",") if len(a) > 4 and a[4] else []
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SLOTS)
slots = {o.name: o for o in bpy.context.scene.objects if o.type == 'MESH'}
extra = []
for k, ep in enumerate(EXTRA):   # other outfits already aligned to the peasant frame: the body must fit inside them too
    b0 = set(bpy.context.scene.objects); bpy.ops.import_scene.gltf(filepath=ep)
    for o in bpy.context.scene.objects:
        if o not in b0 and o.type == 'MESH':
            base = o.data.name.split(".")[0]; o.name = f"E{k}:{base}"; extra.append((base, o))
before = set(bpy.context.scene.objects)
bpy.ops.import_scene.gltf(filepath=RAW)
new = [o for o in bpy.context.scene.objects if o not in before and o.type == 'MESH']
bpy.ops.object.select_all(action='DESELECT')
for o in new: o.select_set(True)
bpy.context.view_layer.objects.active = new[0]
if len(new) > 1: bpy.ops.object.join()
body = bpy.context.view_layer.objects.active; body.name = "base_body"
bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
rep = {}
V = lambda: np.array([tuple(v.co) for v in body.data.vertices])
def xf(M):
    body.data.transform(M); body.data.update()
P = V(); lo, hi = P.min(0), P.max(0); rep["raw_bbox"] = [lo.round(3).tolist(), hi.round(3).tolist()]
# arms span the widest horizontal axis: make it Y like the peasant
if (hi - lo)[0] > (hi - lo)[1]:
    xf(Matrix.Rotation(math.radians(90), 4, 'Z')); rep["rotated_z90"] = True
# uniform scale: sole..scalp of peasant = -0.5..0.467
P = V(); h = P[:, 2].max() - P[:, 2].min(); s = (0.467 + 0.5) / h
xf(Matrix.Scale(s, 4)); rep["scale"] = round(s, 4)
P = V()
# centre: feet/legs on peasant y-centre, chest x-centre of the vest
vest = np.array([tuple(slots["top"].matrix_world @ v.co) for v in slots["top"].data.vertices])
band = (vest[:, 2] > 0.18) & (vest[:, 2] < 0.26)
vc = (vest[band].min(0) + vest[band].max(0)) / 2
P = V(); dz = -0.5 - P[:, 2].min()
bb = P[(P[:, 2] + dz > 0.18) & (P[:, 2] + dz < 0.26) & (np.abs(P[:, 1] - np.median(P[:, 1])) < 0.2)]
bc = (bb.min(0) + bb.max(0)) / 2
xf(Matrix.Translation(Vector((vc[0] - bc[0], vc[1] - bc[1], dz)))); rep["translate"] = [round(float(vc[0]-bc[0]),4), round(float(vc[1]-bc[1]),4), round(float(dz),4)]
P = V(); band = (P[:, 2] > 0.18) & (P[:, 2] < 0.26) & (np.abs(P[:, 1]) < 0.2)
rep["chest_width_y"] = [round(float(P[band, 1].min()),3), round(float(P[band, 1].max()),3)]
rep["vest_width_y"] = [round(float(vest[(vest[:,2]>0.18)&(vest[:,2]<0.26), 1].min()),3), round(float(vest[(vest[:,2]>0.18)&(vest[:,2]<0.26), 1].max()),3)]
# crop: head above neck seam, arms beyond the shoulder
bm = bmesh.new(); bm.from_mesh(body.data)
kill = []
for f in bm.faces:
    c = f.calc_center_median()
    if c.z > 0.30: kill.append(f)                               # head/neck: peasant head mesh starts at 0.26
    elif abs(c.y) > 0.165 and c.z > -0.12: kill.append(f)       # arms & hands: peasant arm parts start at |y|~0.13
bmesh.ops.delete(bm, geom=kill, context='FACES')
loose = [v for v in bm.verts if not v.link_faces]; bmesh.ops.delete(bm, geom=loose, context='VERTS')
bm.to_mesh(body.data); bm.free(); body.data.update()
# push poke-through inside the covering clothes (top, pants, belt, boots), with smoothed displacement
cover = []
for o in [slots[n] for n in ("top", "pants", "belt", "boot_L", "boot_R")] + [o for b, o in extra if b in ("top", "pants", "belt", "boot_L", "boot_R")]:
    cbm = bmesh.new(); cbm.from_mesh(o.data); cbm.transform(o.matrix_world); cover.append(BVHTree.FromBMesh(cbm))
bm = bmesh.new(); bm.from_mesh(body.data); bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5); bm.to_mesh(body.data); bm.free(); body.data.update()
me = body.data; nv = len(me.vertices)
nbr = [[] for _ in range(nv)]
for e in me.edges:
    a_, b_ = e.vertices; nbr[a_].append(b_); nbr[b_].append(a_)
co = np.array([tuple(v.co) for v in me.vertices])
def poke(co, R, margin):
    d = np.zeros_like(co); m = np.zeros(len(co), bool)
    for i, c in enumerate(co):
        best = None
        for t in cover:
            hit = t.find_nearest(Vector(c), R)
            if hit[0] is not None and (best is None or hit[3] < best[3]): best = hit
        if best is None: continue
        p, n, _, _ = best
        if (Vector(c) - p).dot(n) > -margin:
            d[i] = np.array(p - n * (margin + 0.002)) - c; m[i] = True
    return d, m
hist = []
# --- 1. radial shrink per height band, about the torso axis (above the crotch) or each leg's axis (below)
bvh_all = cover
def ray_in(o, d, maxd=0.4):
    best = None
    for t in bvh_all:
        h = t.ray_cast(Vector(o), Vector(d), maxd)
        if h[0] is not None and (best is None or h[3] < best): best = h[3]
    return best
z = co[:, 2]; cy = np.median(co[:, 1])
# crotch: highest z (below the hips) where no vertex sits on the centre line
zc = -0.5
for zz in np.arange(-0.05, -0.4, -0.005):
    b = np.abs(z - zz) < 0.004
    if b.any() and not (np.abs(co[b, 1] - cy) < 0.012).any(): zc = zz; break
hist.append(round(float(zc), 3))
side = np.where(co[:, 1] > cy, 1, -1)
BW = 0.02; zs = np.arange(-0.5, 0.32, BW); fac = {}
def axis_of(mask):
    return np.array([(co[mask, 0].min() + co[mask, 0].max()) / 2, (co[mask, 1].min() + co[mask, 1].max()) / 2])
legcloth = np.concatenate([np.array([tuple(slots[n].matrix_world @ v.co) for v in slots[n].data.vertices]) for n in ("pants", "boot_L", "boot_R")])
def cloth_leg_axis(zz, g):
    m = (np.abs(legcloth[:, 2] - zz) < BW) & (np.sign(legcloth[:, 1] - cy) == g)
    if m.sum() < 10: return None
    q = legcloth[m]; return np.array([(q[:, 0].min() + q[:, 0].max()) / 2, (q[:, 1].min() + q[:, 1].max()) / 2])
groups = {}
for k, zz in enumerate(zs):
    band = np.abs(z - zz) < BW / 2
    for g in ((0,) if zz > zc else (-1, 1)):
        m = band if g == 0 else band & (side == g)
        if m.sum() < 6: continue
        ax = axis_of(m); cax = ax if g == 0 else cloth_leg_axis(zz, g)
        if cax is None: cax = ax
        fs = []
        for i in np.nonzero(m)[0]:
            r = co[i, :2] - ax; rn = np.linalg.norm(r)
            if rn < 1e-4: continue
            dist = ray_in((cax[0], cax[1], co[i, 2]), (r[0] / rn, r[1] / rn, 0))
            if dist is not None: fs.append((dist - 0.006) / rn)
        if len(fs) >= 4: groups[(g, k)] = (ax, min(1.0, float(np.percentile(fs, 8))), cax)
# smooth factors along z per group
for g in (0, -1, 1):
    ks = sorted(k for (gg, k) in groups if gg == g)
    if not ks: continue
    raw = np.array([groups[(g, k)][1] for k in ks])
    sm = np.array([np.average(raw, weights=np.exp(-((np.array(ks) - k) ** 2) / (2 * 2.0 ** 2))) for k in ks])
    for k, f in zip(ks, sm): groups[(g, k)] = (groups[(g, k)][0], float(f), groups[(g, k)][2])
hist.append({str(g): [round(groups[(gg, k)][1], 2) for (gg, k) in sorted(groups) if gg == g] for g in (0, -1, 1)})
for i in range(len(co)):
    k = int(round((co[i, 2] + 0.5) / BW)); g = 0 if co[i, 2] > zc else side[i]
    # interpolate between neighbouring bands of the same group
    cand = [(abs(kk - (co[i, 2] + 0.5) / BW), groups[(g, kk)]) for kk in (k - 1, k, k + 1) if (g, kk) in groups]
    if not cand: continue
    w = np.array([1.0 / (c[0] + 0.3) for c in cand]); f = float(np.dot(w, [c[1][1] for c in cand]) / w.sum())
    ax = sum(c[1][0] * wi for c, wi in zip(cand, w)) / w.sum()
    cax = sum(c[1][2] * wi for c, wi in zip(cand, w)) / w.sum()
    co[i, :2] = cax + (co[i, :2] - ax) * f
# --- 2. gentle smoothed push for what still pokes through
for it in range(4):
    d, m = poke(co, 0.05, 0.004); hist.append(int(m.sum()))
    if not m.any(): break
    for _ in range(20):
        nd = d.copy()
        for i in range(nv):
            if nbr[i]:
                avg = d[nbr[i]].mean(0)
                nd[i] = np.where(np.abs(d[i]) > np.abs(avg), d[i], 0.5 * d[i] + 0.5 * avg) if m[i] else 0.5 * d[i] + 0.5 * avg
        d = nd
    co = co + d
d, m = poke(co, 0.05, 0.003); co = co + d; hist.append(int(m.sum()))
for i, v in enumerate(me.vertices): v.co = Vector(co[i])
me.update()
moved = hist
rep["verts"] = nv; rep["pushed_inside"] = moved
body.data.calc_loop_triangles(); rep["tris_after_crop"] = len(body.data.loop_triangles)
for o in list(slots.values()) + [o for b, o in extra]: bpy.data.objects.remove(o)
bpy.ops.object.select_all(action='DESELECT'); body.select_set(True); bpy.context.view_layer.objects.active = body
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True)
json.dump(rep, open(REP, "w"), indent=1); print("REPORT", json.dumps(rep))
