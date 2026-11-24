"""Seat the pauldrons on every torso / sleeve they can be combined with.

blender -b ashen_char_3outfits.blend -P fit_pauldrons.py -- [out.blend]   (no out -> save in place)

Rest pose, mesh-data coordinates (all parts sit at the identity transform, skinned to Rig). Three steps:
1. Each pauldron gets one rigid move about its shoulder joint (uniform scale, roll, offset), the smallest that clears
   the ranger/leather tunics and all sleeves by MARGIN. The plate keeps its shape.
2. The peasant tunic's sleeve cap is square and stands ~3 cm above the plate's outer edge; clearing it by moving the
   plate would leave the plate floating on every other tunic. Instead the tunic is tucked: vertices above any pauldron's
   outer shell are pushed below it, and the push fades out smoothly over the surrounding cloth (a slightly lower
   shoulder peak; invisible in the side view the game uses).
3. Skin weights: the plate's top edge follows the collarbone 60%, fading to 100% upper arm at the bottom edge, so a
   raised arm (sword slash) does not swing the plate up into a fin. This also stops the peasant sleeve band from
   lapping over the plate in the run cycles.

The ranger hood is deliberately not handled: its cape lies over the pauldron's inner rim (mantle over armour),
which reads correctly; lifting the plate above the cape needs ~6 cm and looks absurd.
"""
import bpy, sys, math
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else bpy.data.filepath
MARGIN = 0.004
rig = bpy.data.objects["Rig"]
RIGID_OCC = ["Male_Ranger_Body", "Leather_Body", "Male_Peasant_Arms", "Male_Ranger_Arms", "Leather_Arms"]
TUCK = "Male_Peasant_Body"
PAULDRONS = {"Leather_Pauldron_L": "upperarm_l", "Leather_Pauldron_R": "upperarm_r",
             "Male_Ranger_Acc_Pauldron": "upperarm_l"}


def shell(me, coords, pivot):
    """BVH of the plate's outward-facing shell (rim faces excluded)."""
    polys = []
    for p in me.polygons:
        vs = [coords[i] for i in p.vertices]
        c = sum(vs, Vector()) / len(vs)
        n = (vs[1] - vs[0]).cross(vs[2] - vs[0])
        if n.length and n.normalized().dot((c - pivot).normalized()) > 0.5:
            polys.append(list(p.vertices))
    return BVHTree.FromPolygons(coords, polys)


def above(t, p):
    """(depth above the shell + MARGIN, shell normal) if p sits right under a shell face and too high, else None."""
    loc, nrm, _, _ = t.find_nearest(p, 0.05)
    if loc is None:
        return None
    s = (p - loc).dot(nrm)
    if (p - loc - nrm * s).length > 0.003:
        return None
    need = s + MARGIN
    return (need, nrm) if need > 0 else None


def worst(t, pts):
    w = 0.0
    for p in pts:
        r = above(t, p)
        if r:
            w = max(w, r[0])
    return w


# ---- 1. rigid fit
shells = []
for name, bone in PAULDRONS.items():
    o = bpy.data.objects[name]
    if o.data.users > 1:
        o.data = o.data.copy()
    me = o.data
    pivot = rig.data.bones[bone].head_local.copy()
    orig = [v.co.copy() for v in me.vertices]
    cen = sum(orig, Vector()) / len(orig)
    rad = max((c - cen).length for c in orig) + 0.05
    pts = [v.co.copy() for n in RIGID_OCC for v in bpy.data.objects[n].data.vertices if (v.co - cen).length < rad]
    base = worst(shell(me, orig, pivot), pts)
    side = 1.0 if bone.endswith("_l") else -1.0
    best = None
    for roll_deg in (0, 4, 8):
        R = Matrix.Rotation(math.radians(roll_deg) * side, 3, "Y")
        for up in (0.5, 1.0, 2.0):
            d = Vector((side, 0, up)).normalized()
            for k in range(0, 11):            # offset 0 .. 2 cm
                off = 0.002 * k
                for j in range(0, 4):         # scale 1.00 .. 1.06
                    s = 1.0 + 0.02 * j
                    cost = off * 6 + (s - 1.0) * 1.5 + roll_deg * 0.004
                    if best is not None and cost >= best[0]:
                        continue
                    co = [pivot + R @ ((c - pivot) * s) + d * off for c in orig]
                    w = worst(shell(me, co, pivot), pts)
                    if w < 0.002:
                        best = (cost, s, off, roll_deg, tuple(round(x, 2) for x in d), w, co)
    if best is None:
        print(f"FIT {name}: no clear fit (worst {base*100:.2f} cm); left as is")
        co = orig
    else:
        cost, s, off, roll, d, w, co = best
        for v, c in zip(me.vertices, co):
            v.co = c
        me.update()
        print(f"FIT {name}: worst {base*100:.2f} -> {w*100:.2f} cm | scale {s:.2f}, roll {roll} deg, offset {off*100:.1f} cm dir {d}")
    shells.append(shell(me, co, pivot))

# ---- 2. tuck the peasant tunic under the (moved) plates
me = bpy.data.objects[TUCK].data
co = [v.co.copy() for v in me.vertices]
nb = [[] for _ in co]
for e in me.edges:
    a, b = e.vertices
    nb[a].append(b); nb[b].append(a)
for it in range(6):
    disp = [Vector() for _ in co]
    hit = [False] * len(co)
    w = 0.0
    for i, p in enumerate(co):
        for t in shells:
            r = above(t, p)
            if r and r[0] > disp[i].length:
                disp[i] = -r[1] * (r[0] + 0.002)
                hit[i] = True
                w = max(w, r[0])
    print(f"TUCK pass {it}: worst {w*100:.2f} cm, vertices {sum(hit)}")
    if w < 0.002:
        break
    # spread the push over the neighbouring cloth so the shoulder sinks smoothly instead of creasing
    f = disp
    for _ in range(10):
        g = []
        for i in range(len(f)):
            avg = (f[i] + sum((f[j] for j in nb[i]), Vector())) / (1 + len(nb[i]))
            g.append(f[i] if hit[i] and f[i].length > avg.length else avg)
        f = g
    co = [c + d for c, d in zip(co, f)]
orig_t = [v.co.copy() for v in me.vertices]
moved = max((a - b).length for a, b in zip(co, orig_t))
for v, c in zip(me.vertices, co):
    v.co = c
me.update()
print(f"TUCK {TUCK}: max vertex move {moved*100:.2f} cm")

# ---- 3. let the top of each plate follow the collarbone
CLAV_TOP = 0.6      # clavicle share at the plate's top edge, fading (smoothstep) to 0 at the bottom edge
for name, bone in PAULDRONS.items():
    o = bpy.data.objects[name]
    side = bone[-2:]
    g_ua = o.vertex_groups[bone]
    g_cl = o.vertex_groups.get("clavicle" + side) or o.vertex_groups.new(name="clavicle" + side)
    zs = [v.co.z for v in o.data.vertices]
    z0, z1 = min(zs), max(zs)
    for v in o.data.vertices:
        t = max(0.0, min(1.0, (v.co.z - z0) / (z1 - z0)))
        w = CLAV_TOP * t * t * (3 - 2 * t)
        g_cl.add([v.index], w, "REPLACE")
        g_ua.add([v.index], 1.0 - w, "REPLACE")
    print(f"WEIGHTS {name}: top {CLAV_TOP:.0%} clavicle{side}, bottom 100% {bone}")

bpy.ops.wm.save_as_mainfile(filepath=OUT, relative_remap=True)
print("SAVED", OUT)
