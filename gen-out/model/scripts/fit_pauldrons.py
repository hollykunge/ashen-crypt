"""Lift pauldrons clear of every torso / sleeve / hood they can be combined with.

blender -b char_leather.blend -P fit_pauldrons.py -- <out.blend>

Works in the rest pose (mesh data coordinates; all part objects sit at the identity transform).
For each pauldron: uniform scale about the shoulder joint + offset along (joint -> pauldron centroid),
searched so every vertex ends up at least MARGIN outside all occluder surfaces. The plate keeps its shape.
"""
import bpy, bmesh, sys
from mathutils import Vector
from mathutils.bvhtree import BVHTree

OUT = sys.argv[sys.argv.index("--") + 1]
MARGIN = 0.015
rig = bpy.data.objects["Rig"]
OCCLUDERS = ["Male_Peasant_Body", "Male_Ranger_Body", "Leather_Body", "Male_Ranger_Head_Hood",
             "Male_Peasant_Arms", "Male_Ranger_Arms", "Leather_Arms"]
PAULDRONS = {"Leather_Pauldron_L": "upperarm_l", "Leather_Pauldron_R": "upperarm_r", "Male_Ranger_Acc_Pauldron": "upperarm_l"}

OCC_PTS = []
for n in OCCLUDERS:
    OCC_PTS += [v.co.copy() for v in bpy.data.objects[n].data.vertices]


def outer_tree(me, coords, pivot):
    """BVH of the pauldron's outward-facing faces (the plate's visible shell)."""
    polys = []
    for p in me.polygons:
        c = sum((coords[i] for i in p.vertices), Vector()) / len(p.vertices)
        n = (coords[p.vertices[1]] - coords[p.vertices[0]]).cross(coords[p.vertices[2]] - coords[p.vertices[0]])
        if n.length and n.normalized().dot((c - pivot).normalized()) > 0.2:
            polys.append(list(p.vertices))
    return BVHTree.FromPolygons(coords, polys)


def poke_through(me, coords, pivot, near_pts):
    """How far other garments come up to / through the plate's outer shell (only points right under a face)."""
    t = outer_tree(me, coords, pivot)
    tot, worst = 0.0, 0.0
    for p in near_pts:
        loc, nrm, _, dist = t.find_nearest(p, 0.05)
        if loc is None:
            continue
        signed = (p - loc).dot(nrm)
        if (p - loc - nrm * signed).length > 0.004:   # nearest point is on the rim: beside the plate, not under it
            continue
        need = signed + MARGIN
        if need > 0:
            tot += need
            worst = max(worst, need)
    return tot, worst


for name, bone in PAULDRONS.items():
    o = bpy.data.objects[name]
    me = o.data
    pivot = rig.data.bones[bone].head_local.copy()
    orig = [v.co.copy() for v in me.vertices]
    cen = sum(orig, Vector()) / len(orig)
    out_dir = (cen - pivot).normalized()
    rad = max((c - cen).length for c in orig) + 0.06
    near_pts = [p for p in OCC_PTS if (p - cen).length < rad]
    base_tot, base_worst = poke_through(me, orig, pivot, near_pts)
    best = None
    side = 1.0 if bone.endswith("_l") else -1.0
    lateral = Vector((side, 0, 0))
    dirs = []
    for up in (-0.6, -0.3, 0.0, 0.3, 0.6, 1.0):
        for back in (-0.3, 0.0, 0.3):
            d = (lateral + Vector((0, back, up)))
            dirs.append(d.normalized())
    for d in dirs:
        for k in range(0, 13):                  # offset 0 .. 4.8 cm
            off = 0.004 * k
            for j in range(0, 8):               # scale 1.00 .. 1.21
                s = 1.0 + 0.03 * j
                cost = off * 4 + (s - 1.0)       # prefer the smallest visible change
                if best is not None and cost >= best[0]:
                    continue
                pts = [pivot + (c - pivot) * s + d * off for c in orig]
                tot, worst = poke_through(me, pts, pivot, near_pts)
                if worst < 0.003:
                    best = (cost, s, off, tot, worst, d)
    if best is None:
        print("FIT", name, "no clear fit found; leaving as is", round(base_worst, 4))
        continue
    _, s, off, tot, worst, d = best
    for v, c in zip(me.vertices, orig):
        v.co = pivot + (c - pivot) * s + d * off
    me.update()
    print(f"FIT {name}: before worst {base_worst*100:.1f} cm -> scale {s:.2f}, offset {off*100:.1f} cm dir {tuple(round(x, 2) for x in d)}, worst {worst*100:.2f} cm")

bpy.ops.wm.save_as_mainfile(filepath=OUT)
