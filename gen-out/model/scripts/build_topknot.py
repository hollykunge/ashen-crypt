"""Comb the hair back into a topknot (束发髻), like the swordsman in the original art.

blender -b ashen_char_3outfits.blend -P build_topknot.py -- [out.blend]   (no out -> save in place; re-running rebuilds)

The pack only has modern cuts (short parted hair; Hair_Buns is two side buns over a bare crown), so the hair is rebuilt:
  Head_Hair_Main  REPLACED: a cap cut from the head's own scalp (Head_Skin faces above a hairline that runs from the
                  forehead, down past the temples, to the nape), pushed 4-7 mm off the skin, so the hair lies flat
                  against the skull and is combed back. Skin weights and UVs come with the faces. Material MI_Hair_Cap:
                  fine combed-back streaks (style_lib paints every MI_Hair* material dark brown and keeps the streaks;
                  Godot does the same for meshes named Head_Hair*).
                  The original short hair is kept in the file as mesh "Head_Hair_Short" (fake user).
  Head_Hair_Bun   the knot on the crown, leaning back
  Head_Hair_Tail  a short tail of hair from under the knot down toward the nape
  Head_Band       red cloth band round the base of the knot
  Head_Pin        簪: a thin bronze rod through the knot, left to right, with a knob at one end
Knot, tail, band and pin are weighted 100% to the Head bone and have simple UVs (needed for baking).
Hood on: the slot tables hide Head_Hair_Main and all of the above (render_lib.TOPKNOT, model_hero.gd TOPKNOT).
"""
import bpy, bmesh, sys, math
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else bpy.data.filepath
rig = bpy.data.objects["Rig"]
col = bpy.data.collections["Parts"]
EXTRA = ("Head_Hair_Bun", "Head_Hair_Tail", "Head_Band", "Head_Pin")


def srgb(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c) + (1.0,)


def flat_mat(name, hexcol, rough=0.8, metal=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.bl_idname == "ShaderNodeBsdfPrincipled")
    p.inputs["Base Color"].default_value = srgb(hexcol)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    return m


def hair_mat(name):
    """Dark hair with fine streaks running front to back (combed back), in rest-pose coordinates."""
    m = bpy.data.materials.get(name)
    if m:
        bpy.data.materials.remove(m)
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree; N, L = nt.nodes, nt.links
    p = next(n for n in N if n.bl_idname == "ShaderNodeBsdfPrincipled")
    tc = N.new("ShaderNodeTexCoord")
    wave = N.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"; wave.bands_direction = "X"   # bands across X -> streaks along Y (front-back) and Z
    wave.inputs["Scale"].default_value = 60
    wave.inputs["Distortion"].default_value = 6
    wave.inputs["Detail"].default_value = 3
    L.new(tc.outputs["Generated"], wave.inputs["Vector"])
    ramp = N.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = srgb("2a2420")
    ramp.color_ramp.elements[1].color = srgb("6a5a4c")
    L.new(wave.outputs["Fac"], ramp.inputs["Fac"])
    L.new(ramp.outputs["Color"], p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = 0.55
    return m


# ---- clean up a previous run / keep the original short hair
for n in EXTRA:
    if n in bpy.data.objects:
        bpy.data.objects.remove(bpy.data.objects[n], do_unlink=True)
old = bpy.data.objects.get("Head_Hair_Main")
if old is not None:
    if old.data.name != "Head_Hair_Cap" and "Head_Hair_Short" not in bpy.data.meshes:
        old.data.name = "Head_Hair_Short"
        old.data.use_fake_user = True
    bpy.data.objects.remove(old, do_unlink=True)
if "Head_Hair_Cap" in bpy.data.meshes:
    bpy.data.meshes.remove(bpy.data.meshes["Head_Hair_Cap"])

# ---- 1. the cap: scalp faces of the head, pushed off the skin
skin = bpy.data.objects["Head_Skin"]
cap = skin.copy()
cap.data = skin.data.copy()
cap.name = "Head_Hair_Main"
cap.data.name = "Head_Hair_Cap"
col.objects.link(cap)


def hairline(c):
    """Hair covers the skull above this height: high at the forehead (-Y is the face), low at the nape."""
    back = min(1.0, max(0.0, (c.y + 0.065) / 0.15))
    back = back * back * (3 - 2 * back)
    z = 1.762 - 0.112 * back
    if abs(c.x) > 0.062 and c.y < 0.03:      # temples and above the ears: keep the ears free
        z = max(z, 1.705)
    return z


bm = bmesh.new(); bm.from_mesh(cap.data)
bm.faces.ensure_lookup_table()
drop = [f for f in bm.faces if f.calc_center_median().z < hairline(f.calc_center_median())]
bmesh.ops.delete(bm, geom=drop, context="FACES")
bm.verts.ensure_lookup_table()
bm.normal_update()
top_z = max(v.co.z for v in bm.verts)
for v in bm.verts:
    lift = 0.004 + 0.004 * max(0.0, (v.co.z - 1.70) / (top_z - 1.70))   # a little more volume on the crown
    v.co += v.normal * lift
bm.to_mesh(cap.data); bm.free()
cap.data.materials.clear()
cap.data.materials.append(hair_mat("MI_Hair_Cap"))
for p in cap.data.polygons:
    p.use_smooth = True
cv = [v.co for v in cap.data.vertices]
crown = max(cv, key=lambda c: c.z)
print("CAP faces", len(cap.data.polygons), "top", round(top_z, 3))

# ---- 2. knot, tail, band, pin
CROWN = Vector((0.0, crown.y + 0.03, crown.z - 0.004))
TILT = Matrix.Rotation(math.radians(-28), 4, "X")      # lean the knot back
tilt = lambda v: (TILT @ v.to_4d()).to_3d()


def ellipsoid(bm, uv, center, r, seg=14, rings=9):
    rows = []
    for i in range(rings + 1):
        th = math.pi * i / rings
        rows.append([bm.verts.new(center + tilt(Vector((r.x * math.sin(th) * math.cos(2 * math.pi * j / seg),
                                                          r.y * math.sin(th) * math.sin(2 * math.pi * j / seg),
                                                          r.z * math.cos(th))))) for j in range(seg)])
    for i in range(rings):
        for j in range(seg):
            q = (rows[i][j], rows[i][(j + 1) % seg], rows[i + 1][(j + 1) % seg], rows[i + 1][j])
            f = bm.faces.new(q)
            for lp, (u, v) in zip(f.loops, ((j / seg, i / rings), ((j + 1) / seg, i / rings),
                                            ((j + 1) / seg, (i + 1) / rings), (j / seg, (i + 1) / rings))):
                lp[uv].uv = (u, v)


def tube(bm, uv, pts, radii, sides=8):
    """A tube along a polyline with per-point radius (tail of hair, pin)."""
    rings = []
    for i, (p, r) in enumerate(zip(pts, radii)):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        s = d.cross(Vector((1, 0, 0)))
        if s.length < 1e-4:
            s = d.cross(Vector((0, 0, 1)))
        s.normalize(); u = d.cross(s)
        rings.append([bm.verts.new(p + (s * math.cos(2 * math.pi * k / sides) + u * math.sin(2 * math.pi * k / sides)) * max(r, 0.0006))
                      for k in range(sides)])
    for i in range(len(rings) - 1):
        for k in range(sides):
            f = bm.faces.new((rings[i][k], rings[i][(k + 1) % sides], rings[i + 1][(k + 1) % sides], rings[i + 1][k]))
            for lp, (x, y) in zip(f.loops, ((k / sides, i / len(rings)), ((k + 1) / sides, i / len(rings)),
                                            ((k + 1) / sides, (i + 1) / len(rings)), (k / sides, (i + 1) / len(rings)))):
                lp[uv].uv = (x, y)
    bm.faces.new(list(reversed(rings[0]))); bm.faces.new(rings[-1])


def torus(bm, uv, center, R, r, seg=18, sides=6):
    rings = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        c = Vector((R * math.cos(a), R * math.sin(a), 0)); n = c.normalized()
        rings.append([bm.verts.new(center + tilt(c + (n * math.cos(2 * math.pi * k / sides) +
                                                      Vector((0, 0, 1)) * math.sin(2 * math.pi * k / sides)) * r))
                      for k in range(sides)])
    for i in range(seg):
        A, B = rings[i], rings[(i + 1) % seg]
        for k in range(sides):
            f = bm.faces.new((A[k], A[(k + 1) % sides], B[(k + 1) % sides], B[k]))
            for lp, (u, v) in zip(f.loops, ((i / seg, k / sides), ((i + 1) / seg, k / sides),
                                            ((i + 1) / seg, (k + 1) / sides), (i / seg, (k + 1) / sides))):
                lp[uv].uv = (u, v)


def make(name, build, mat):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    build(bm, uv)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.materials.append(mat)
    o = bpy.data.objects.new(name, me)
    col.objects.link(o)
    o.parent = rig
    o.vertex_groups.new(name="Head").add(list(range(len(me.vertices))), 1.0, "REPLACE")
    o.modifiers.new("Armature", "ARMATURE").object = rig
    return o


knot_mat = hair_mat("MI_Hair_Knot")
bun_c = CROWN + tilt(Vector((0, 0, 0.024)))
make("Head_Hair_Bun", lambda bm, uv: ellipsoid(bm, uv, bun_c, Vector((0.036, 0.036, 0.031))), knot_mat)
# tail: leaves the back of the knot, falls back and down to just above the nape, tapering
t0 = bun_c + tilt(Vector((0, 0.028, -0.006)))
tail_pts = [t0 + Vector((0, 0.024 * k ** 0.8, -0.032 * k)) for k in range(6)]
tail_pts = [p + Vector((0, 0.012 * math.sin(i / 5 * math.pi), 0)) for i, p in enumerate(tail_pts)]
make("Head_Hair_Tail", lambda bm, uv: tube(bm, uv, tail_pts, [0.019, 0.019, 0.017, 0.014, 0.010, 0.003]), knot_mat)
make("Head_Band", lambda bm, uv: torus(bm, uv, CROWN + tilt(Vector((0, 0, 0.006))), 0.032, 0.0078),
     flat_mat("Head_Band_Mat", "8e2f22"))
pin_c = bun_c + tilt(Vector((0, 0, 0.004)))
make("Head_Pin", lambda bm, uv: (tube(bm, uv, [pin_c + Vector((-0.072, 0, 0)), pin_c + Vector((0.072, 0, 0))], [0.0028, 0.0022], 6),
                                 ellipsoid(bm, uv, pin_c + Vector((-0.075, 0, 0)), Vector((0.006, 0.006, 0.006)), 8, 5)),
     flat_mat("Head_Pin_Mat", "b8955a", 0.4, 0.8))
print("TOPKNOT crown", tuple(round(x, 3) for x in CROWN), list(EXTRA))
bpy.ops.wm.save_as_mainfile(filepath=OUT, relative_remap=True)
print("SAVED", OUT)
