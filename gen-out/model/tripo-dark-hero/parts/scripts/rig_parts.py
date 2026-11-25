"""blender -b duanda_rigged.blend -P rig_parts.py -- <parts_dir> <peasant-3.glb> <out.blend> <report.json>
Skin every slot part (three outfits + base body) to the existing Duanda rig, then save to a NEW .blend.
1. recover each bone's A-pose skin matrix by least squares from Duanda_Body (rest = T-pose) vs the original A-pose mesh;
2. per part vertex, interpolate weights from the nearest A-pose Duanda triangle, restricted to bones allowed for that slot;
3. unpose each part vertex with the inverse of its blended skin matrix, parent to Rig with an Armature modifier."""
import bpy, bmesh, sys, os, json, math, numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
a = sys.argv[sys.argv.index("--")+1:]; PD, PEA_GLB, OUT, REP = a
rep = {}
rig = bpy.data.objects["Rig"]; body = bpy.data.objects["Duanda_Body"]
rig.animation_data.action = None
for pb in rig.pose.bones: pb.matrix_basis = Matrix()
bones = [b.name for b in rig.data.bones]; bi = {n: i for i, n in enumerate(bones)}
# --- model-space transform used by build_tripo_hero.py (preset duanda)
MS = Matrix.Translation((0, -0.04, 0)) @ Matrix.Scale(1.8, 4) @ Matrix.Translation((0, 0, 0.5)) @ Matrix.Rotation(math.radians(-90), 4, "Z")
def import_meshes(path):
    before = set(bpy.data.objects); bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    ms = [o for o in new if o.type == 'MESH']
    for o in ms:
        o.parent = None; o.data.transform(o.matrix_world); o.matrix_world = Matrix(); o.data.transform(MS)
    for o in new:
        if o.type != 'MESH': bpy.data.objects.remove(o, do_unlink=True)
    return ms
# --- 1. A-pose skin matrices
orig = import_meshes(PEA_GLB)[0]
assert len(orig.data.vertices) == len(body.data.vertices), (len(orig.data.vertices), len(body.data.vertices))
A = np.array([tuple(v.co) for v in orig.data.vertices]); T = np.array([tuple(v.co) for v in body.data.vertices])
gname = {g.index: g.name for g in body.vertex_groups}
W = np.zeros((len(T), len(bones)))
for v in body.data.vertices:
    for g in v.groups:
        n = gname[g.group]
        if n in bi and g.weight > 0: W[v.index, bi[n]] = g.weight
W /= np.maximum(W.sum(1, keepdims=True), 1e-9)
Th = np.hstack([T, np.ones((len(T), 1))])                         # n x 4
X = np.hstack([W[:, [b]] * Th for b in range(len(bones))])        # n x (4*B)
used = np.where(W.sum(0) > 1e-6)[0]
cols = np.concatenate([np.arange(4 * b, 4 * b + 4) for b in used])
sol, *_ = np.linalg.lstsq(X[:, cols], A, rcond=None)              # (4*U) x 3
S = {}
for k, b in enumerate(used):
    m = sol[4 * k:4 * k + 4].T                                    # 3 x 4
    S[bones[b]] = np.vstack([m, [0, 0, 0, 1]])
for n in bones:                                                   # unweighted bones inherit the parent's matrix
    if n not in S:
        p = rig.data.bones[n].parent
        while p is not None and p.name not in S: p = p.parent
        S[n] = S[p.name] if p is not None else np.eye(4)
pred = np.einsum("nb,bij,nj->ni", W, np.array([S[n] for n in bones]), Th)[:, :3]
rep["skin_fit_residual_mm"] = {"mean": round(float(np.linalg.norm(pred - A, axis=1).mean() * 1000 / 1.8), 3),
                               "max": round(float(np.linalg.norm(pred - A, axis=1).max() * 1000 / 1.8), 3)}
print("FIT", rep["skin_fit_residual_mm"])
bpy.data.objects.remove(orig, do_unlink=True)
# --- 2. weight sources: A-pose Duanda triangles, filtered by allowed bones per slot
ARM = ("upperarm_", "lowerarm_", "hand_", "thumb_", "index_", "middle_", "ring_", "pinky_")
FOREARM = ("lowerarm_", "hand_", "thumb_", "index_", "middle_", "ring_", "pinky_")
dom = np.argmax(W, 1)
bm = bmesh.new(); bm.from_mesh(body.data); bm.verts.ensure_lookup_table()
for v in bm.verts: v.co = Vector(A[v.index])
bmesh.ops.triangulate(bm, faces=bm.faces[:]); bm.faces.ensure_lookup_table()
tris = np.array([[v.index for v in f.verts] for f in bm.faces])
def source(allow):
    keep = [i for i, t in enumerate(tris) if all(allow(bones[dom[v]]) for v in t)]
    sub = bmesh.new()
    vs = [sub.verts.new(Vector(A[i])) for i in range(len(A))]
    for i in keep: sub.faces.new([vs[j] for j in tris[i]])
    sub.faces.ensure_lookup_table()
    return BVHTree.FromBMesh(sub), np.array([tris[i] for i in keep])
SRC = {"all": source(lambda n: True),
       "no_arms": source(lambda n: not n.startswith(ARM)),
       "no_forearm": source(lambda n: not n.startswith(FOREARM))}
def slot_rule(slot):
    if slot in ("helmet", "hair_topknot"): return "rigid_head"     # headgear moves with the skull as one piece
    if slot.startswith(("arm_", "body_arm_", "bracer_")): return "all"
    if slot in ("top", "base_body"): return "no_forearm"
    return "no_arms"
def skin_part(o, rule, smooth_legs=False):
    P = np.array([tuple(v.co) for v in o.data.vertices]); Wp = np.zeros((len(P), len(bones)))
    if rule == "rigid_head": Wp[:, bi["Head"]] = 1.0
    tree, tr = SRC["all"] if rule == "rigid_head" else SRC[rule]
    for i, p in enumerate(P if rule != "rigid_head" else []):
        loc, nrm, fi, d = tree.find_nearest(Vector(p))
        a_, b_, c_ = (A[j] for j in tr[fi])
        v0, v1, v2 = b_ - a_, c_ - a_, np.array(loc) - a_
        d00, d01, d11, d20, d21 = v0 @ v0, v0 @ v1, v1 @ v1, v2 @ v0, v2 @ v1
        den = d00 * d11 - d01 * d01 or 1e-12
        l1 = (d11 * d20 - d01 * d21) / den; l2 = (d00 * d21 - d01 * d20) / den; l0 = 1 - l1 - l2
        bc = np.clip([l0, l1, l2], 0, 1); bc /= bc.sum()
        Wp[i] = bc @ W[tr[fi]]
    Wp[Wp < 0.01] = 0; Wp /= np.maximum(Wp.sum(1, keepdims=True), 1e-9)
    if smooth_legs: Wp = smooth_skirt(o, P, Wp)
    Ph = np.hstack([P, np.ones((len(P), 1))])
    M = np.einsum("nb,bij->nij", Wp, np.array([S[n] for n in bones]))
    Tp = np.einsum("nij,nj->ni", np.linalg.inv(M), Ph)[:, :3]
    for i, v in enumerate(o.data.vertices): v.co = Vector(Tp[i])
    o.data.update()
    for b in np.where(Wp.sum(0) > 0)[0]:
        g = o.vertex_groups.new(name=bones[b])
        for i in np.where(Wp[:, b] > 0)[0]: g.add([int(i)], float(Wp[i, b]), "REPLACE")
    o.parent = rig; mod = o.modifiers.new("Armature", "ARMATURE"); mod.object = rig
    return int((Wp > 0).sum(1).max())
# skirts and hems: diffuse pelvis/leg weights below the hips so the cloth does not tear into spikes between the legs
LEGSET = [bi[n] for n in ("pelvis", "spine_01", "thigh_l", "thigh_r", "calf_l", "calf_r") if n in bi]
HIPZ = float((S["thigh_l"] @ np.append(np.array(rig.data.bones["thigh_l"].head_local), 1))[2])
SMOOTH_IT = int(os.environ.get("SKIRT_IT", 15))
def smooth_skirt(o, P, Wp):
    key = {}; uid = np.array([key.setdefault(tuple(np.round(p, 5)), len(key)) for p in P])
    U = len(key); Wu = np.zeros((U, Wp.shape[1])); cnt = np.zeros(U)
    np.add.at(Wu, uid, Wp); np.add.at(cnt, uid, 1); Wu /= cnt[:, None]
    zu = np.zeros(U); zu[uid] = P[:, 2]
    nb = [set() for _ in range(U)]
    for e in o.data.edges:
        a_, b_ = uid[e.vertices[0]], uid[e.vertices[1]]
        if a_ != b_: nb[a_].add(b_); nb[b_].add(a_)
    act = np.where(zu < HIPZ + 0.05)[0]
    for _ in range(SMOOTH_IT):
        L_ = Wu[:, LEGSET].copy(); new = L_.copy()
        for i in act:
            if nb[i]: new[i] = 0.5 * L_[i] + 0.5 * L_[list(nb[i])].mean(0)
        Wu[:, LEGSET] = new
    Wu[Wu < 0.01] = 0; Wu /= np.maximum(Wu.sum(1, keepdims=True), 1e-9)
    return Wu[uid]
SKIRT_SLOTS = ("top", "pants")
# --- 3. load all parts and skin them
SETS = {"peasant3": os.path.join(PD, "slots/_all_slots.glb"), "leather2": os.path.join(PD, "leather-2/slots_aligned/_all_slots.glb"),
        "chain2": os.path.join(PD, "chain-2/slots_aligned/_all_slots.glb"), "body": os.path.join(PD, "base_body/base_body.glb")}
coll = rig.users_collection[0]; rep["parts"] = {}
for tag, path in SETS.items():
    for o in import_meshes(path):
        slot = "base_body" if tag == "body" else o.data.name.split(".")[0]
        if tag != "peasant3" and slot == "head": bpy.data.objects.remove(o, do_unlink=True); continue
        o.name = o.data.name = f"{tag}__{slot}"
        for c in o.users_collection: c.objects.unlink(o)
        coll.objects.link(o)
        rep["parts"][o.name] = {"verts": len(o.data.vertices), "rule": slot_rule(slot), "max_influences": skin_part(o, slot_rule(slot), smooth_legs=slot in SKIRT_SLOTS and SMOOTH_IT > 0)}
        print("SKINNED", o.name)
bpy.data.objects.remove(body, do_unlink=True)
for m in list(bpy.data.meshes):
    if m.users == 0: bpy.data.meshes.remove(m)
rig.data.pose_position = "POSE"
bpy.ops.wm.save_as_mainfile(filepath=OUT, compress=True)
json.dump(rep, open(REP, "w"), indent=1); print("SAVED", OUT)
