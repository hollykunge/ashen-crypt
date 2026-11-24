"""Turn the leather set's boots into front-laced tall boots (原画那种前面系带的长靴).

blender -b ashen_char_3outfits.blend -P build_laced_boots.py -- [out.blend]   (no out -> save in place)

Leather_Boots started as a copy of the ranger boots: a plain tall shell per leg plus ~1190 small loose pieces
(buckled straps, pyramid studs, a folded cuff). This script
1. keeps only the largest island per leg (the plain shell) — rebuilt from Male_Ranger_Feet_Boots each run, so the
   script can be re-run;
2. adds criss-cross laces on the front of each shin: eyelet pairs are found by casting rays at the rest-pose shell,
   cords are thin tubes 2 mm off the surface, each lace vertex copies the skin weights of the nearest shell vertex
   (so the laces follow calf and foot); eyelets are small brass studs;
3. joins laces and eyelets into Leather_Boots as extra material slots, so the outfit slot table does not change.
"""
import bpy, bmesh, sys, math
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else bpy.data.filepath
rig = bpy.data.objects["Rig"]
col = bpy.data.collections["Parts"]
Z0, Z1, CROSSES = 0.13, 0.43, 7   # lacing from the instep to just under the boot top
HALF = 0.017                      # eyelets this far either side of the shin's front centre
CORD = 0.0028


def srgb(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c) + (1.0,)


def flat_mat(name, hexcol, rough=0.7, metal=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.bl_idname == "ShaderNodeBsdfPrincipled")
    p.inputs["Base Color"].default_value = srgb(hexcol)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    return m


# ---- 1. fresh shell: copy the ranger boots again, keep the biggest island per leg, keep the leather recolour
old = bpy.data.objects["Leather_Boots"]
leather_mat = old.data.materials[0]
src = bpy.data.objects["Male_Ranger_Feet_Boots"]
boots = src.copy()
boots.data = src.data.copy()
bpy.data.objects.remove(old, do_unlink=True)
boots.name = boots.data.name = "Leather_Boots"
col.objects.link(boots)
boots.data.materials[0] = leather_mat
bm = bmesh.new(); bm.from_mesh(boots.data); bm.verts.ensure_lookup_table()
seen, islands = set(), []
for v in bm.verts:
    if v.index in seen:
        continue
    stack, comp = [v], []
    seen.add(v.index)
    while stack:
        x = stack.pop(); comp.append(x)
        for e in x.link_edges:
            w = e.other_vert(x)
            if w.index not in seen:
                seen.add(w.index); stack.append(w)
    islands.append(comp)
islands.sort(key=len, reverse=True)
keep = {v.index for comp in islands[:2] for v in comp}
bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.index not in keep], context="VERTS")
bm.to_mesh(boots.data); bm.free()
print("SHELL kept", len(boots.data.vertices), "of", len(src.data.vertices), "verts")

# ---- 2. laces
me = boots.data
co = [v.co.copy() for v in me.vertices]
tree = BVHTree.FromPolygons(co, [list(p.vertices) for p in me.polygons])
kd = KDTree(len(co))
for i, c in enumerate(co):
    kd.insert(c, i)
kd.balance()
groups = {g.index: g.name for g in boots.vertex_groups}


def front_point(x, z):
    hit, nrm, _, _ = tree.ray_cast(Vector((x, -1.0, z)), Vector((0, 1, 0)), 2.0)
    return (hit + nrm * 0.002, nrm) if hit else (None, None)


lace = bmesh.new()
uv = lace.loops.layers.uv.new("UVMap")
weights = {}   # lace vert -> {group name: w}
stud_faces, cord_faces = [], []


def tube(a, b, r, sides=5):
    d = (b - a).normalized()
    side = d.cross(Vector((0, 1, 0)))
    if side.length < 1e-4:
        side = d.cross(Vector((1, 0, 0)))
    side.normalize(); up = d.cross(side)
    ring = lambda c: [lace.verts.new(c + (side * math.cos(2 * math.pi * k / sides) + up * math.sin(2 * math.pi * k / sides)) * r)
                      for k in range(sides)]
    ra, rb = ring(a), ring(b)
    faces = []
    for k in range(sides):
        f = lace.faces.new((ra[k], ra[(k + 1) % sides], rb[(k + 1) % sides], rb[k]))
        for li, (u, vv) in zip(f.loops, ((k / sides, 0), ((k + 1) / sides, 0), ((k + 1) / sides, 1), (k / sides, 1))):
            li[uv].uv = (u, vv)
        faces.append(f)
    return ra + rb, faces


for side_x in (1, -1):
    pairs = []
    for i in range(CROSSES + 1):
        z = Z0 + (Z1 - Z0) * i / CROSSES
        ring = [c for c in co if abs(c.z - z) < 0.04 and c.x * side_x > 0] or [Vector((0.091 * side_x, 0, z))]
        xc = sum(c.x for c in ring) / len(ring)
        l, _ = front_point(xc - HALF, z)
        r, _ = front_point(xc + HALF, z)
        if l and r:
            pairs.append((l, r))
    for i in range(len(pairs) - 1):
        (l0, r0), (l1, r1) = pairs[i], pairs[i + 1]
        for a, b in ((l0, r1), (r0, l1)):
            mid = (a + b) * 0.5
            hit, n = front_point(mid.x, mid.z)
            m2 = hit + n * 0.001 if hit else mid
            for p, q in ((a, m2), (m2, b)):
                vs, fs = tube(p, q, CORD)
                cord_faces += fs
    for l, r in pairs:
        for p in (l, r):
            vs, fs = tube(p - Vector((0, 0.002, 0)), p + Vector((0, 0.003, 0)), 0.0045, 6)
            stud_faces += fs
    # loose ends hanging from the top pair
    l, r = pairs[-1]
    top = (l + r) * 0.5
    for dx in (-0.006, 0.006):
        vs, fs = tube(top + Vector((dx, -0.002, 0)), top + Vector((dx * 2.5, -0.012, -0.055)), CORD)
        cord_faces += fs

lace.verts.ensure_lookup_table()
lace_obj = bpy.data.objects.new("Leather_BootLaces", bpy.data.meshes.new("Leather_BootLaces"))
col.objects.link(lace_obj)
for f in cord_faces:
    f.material_index = 0
for f in stud_faces:
    f.material_index = 1
lace.to_mesh(lace_obj.data); lace.free()
lace_obj.data.materials.append(flat_mat("Leather_Lace", "c9a876", 0.8))
lace_obj.data.materials.append(flat_mat("Leather_Eyelet", "b08a4a", 0.4, 0.8))
# skin weights from the nearest shell vertex
for g in boots.vertex_groups:
    lace_obj.vertex_groups.new(name=g.name)
for v in lace_obj.data.vertices:
    _, idx, _ = kd.find(v.co)
    for g in me.vertices[idx].groups:
        lace_obj.vertex_groups[groups[g.group]].add([v.index], g.weight, "REPLACE")

# ---- 3. join laces into the boots (boots keep their name, armature and slot 0)
bpy.ops.object.select_all(action="DESELECT")
lace_obj.select_set(True); boots.select_set(True)
bpy.context.view_layer.objects.active = boots
bpy.ops.object.join()
print("LACED", boots.name, "verts", len(boots.data.vertices), "materials", [m.name for m in boots.data.materials])
bpy.ops.wm.save_as_mainfile(filepath=OUT, relative_remap=True)
print("SAVED", OUT)
