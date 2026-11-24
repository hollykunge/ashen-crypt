"""Build the hero's Chinese weapons as low-poly modular parts and export them for Godot.

blender -b --factory-startup -P build_weapons.py -- <out.glb> [out.blend]

Parts follow the game's weapon designs (mobile/scripts/weapon_design.gd), so a forged weapon keeps its look:
  剑 sword / jian : blade jian | qixing | bolang, guard ruyi | disc | bar | crescent, grip, pommel hex | ring | knob | cloud, tassel
  长枪 spear      : pole, butt cap, socket, head leaf | snake | ji, red tassel (红缨)
  弓 bow          : limbs chang | fanqu (fanqu also stands for jiao / yun), grip wrap, string
Every part is its own object named <form>_<kind>[_<variant>], all sharing one origin: the grip centre, where the fist
closes. Axes (Blender): +Z toward the tip (blade / spear head / upper bow limb), +X the blade's width (the bow's belly,
toward the target), Y the blade's thickness. glTF turns that into Godot +Y tip, +X width.
Materials are named by role (steel, trim, wrap, accent, wood, core, cap, string, tassel); the game colours them from
the forged design, so only flat placeholder colours are set here. Sizes in metres.
"""
import bpy, bmesh, sys, os, math
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
OUT = os.path.abspath(argv[0])
OUT_BLEND = os.path.abspath(argv[1]) if len(argv) > 1 else None

for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)

ROLES = {"steel": (0.55, 0.57, 0.60), "trim": (0.62, 0.50, 0.30), "wrap": (0.45, 0.20, 0.15),
         "accent": (0.61, 0.29, 0.21), "wood": (0.49, 0.35, 0.24), "core": (0.18, 0.13, 0.10),
         "cap": (0.65, 0.54, 0.37), "string": (0.83, 0.77, 0.65), "tassel": (0.72, 0.20, 0.16)}
MATS = {}
for name, rgb in ROLES.items():
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.bl_idname == "ShaderNodeBsdfPrincipled")
    p.inputs["Base Color"].default_value = (*rgb, 1.0)
    p.inputs["Roughness"].default_value = 0.6
    MATS[name] = m


def obj(name, bm, role):
    me = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    me.materials.append(MATS[role])
    for poly in me.polygons:
        poly.use_smooth = False
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def loft(rings, cap_start=True, cap_end=True):
    """rings: list of lists of Vector (same count each). A single-point ring makes a cone tip."""
    bm = bmesh.new()
    vrings = [[bm.verts.new(p) for p in r] for r in rings]
    for a, b in zip(vrings, vrings[1:]):
        if len(a) == 1 and len(b) == 1:
            continue
        if len(b) == 1:
            for i in range(len(a)):
                bm.faces.new((a[i], a[(i + 1) % len(a)], b[0]))
        elif len(a) == 1:
            for i in range(len(b)):
                bm.faces.new((b[(i + 1) % len(b)], b[i], a[0]))
        else:
            n = len(a)
            for i in range(n):
                bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
    if cap_start and len(vrings[0]) > 2:
        bm.faces.new(list(reversed(vrings[0])))
    if cap_end and len(vrings[-1]) > 2:
        bm.faces.new(vrings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def ring(z, rx, ry, n=8, cx=0.0, cy=0.0, phase=0.0):
    return [Vector((cx + rx * math.cos(phase + 2 * math.pi * i / n), cy + ry * math.sin(phase + 2 * math.pi * i / n), z))
            for i in range(n)]


def diamond(z, w, t, cx=0.0):
    return [Vector((cx + w / 2, 0, z)), Vector((cx, t / 2, z)), Vector((cx - w / 2, 0, z)), Vector((cx, -t / 2, z))]


def cylinder(z0, z1, r, n=8, r1=None):
    return loft([ring(z0, r, r, n), ring(z1, r1 if r1 is not None else r, r1 if r1 is not None else r, n)])


def sphere(c, rx, ry, rz, seg=8, rings_=5):
    pts = []
    for k in range(1, rings_):
        a = math.pi * k / rings_
        pts.append(ring(c.z - rz * math.cos(a), rx * math.sin(a), ry * math.sin(a), seg, c.x, c.y))
    return loft([[Vector((c.x, c.y, c.z - rz))]] + pts + [[Vector((c.x, c.y, c.z + rz))]], False, False)


def merge(*bms):
    out = bmesh.new()
    for b in bms:
        me = bpy.data.meshes.new("tmp")
        b.to_mesh(me)
        out.from_mesh(me)
        bpy.data.meshes.remove(me)
        b.free()
    return out


def tassel(z_top, length, spread, strands=11, cx=0.0, drop=-1.0):
    """A bunch of thin strands hanging from z_top (drop=-1: toward -Z)."""
    parts = []
    for i in range(strands):
        a = 2 * math.pi * i / strands
        end = Vector((cx + spread * math.cos(a), spread * math.sin(a), z_top + drop * length * (0.85 + 0.15 * math.sin(3 * a))))
        start = Vector((cx, 0, z_top))
        d = (end - start)
        side = d.cross(Vector((0, 0, 1))).normalized() * 0.007 if abs(d.normalized().z) < 0.99 else Vector((0.007, 0, 0))
        side2 = d.cross(side).normalized() * 0.007
        parts.append(loft([[start + side, start + side2, start - side, start - side2],
                           [end + side * 0.6, end + side2 * 0.6, end - side * 0.6, end - side2 * 0.6]]))
    knot = sphere(Vector((cx, 0, z_top)), 0.012, 0.012, 0.012, 6, 4)
    return merge(knot, *parts)


# ------------------------------------------------------------------ 剑
GRIP_HALF = 0.10
BLADE_BASE = 0.125
BLADE_LEN = 0.74


def blade(kind):
    rings = []
    steps = 14
    for i in range(steps + 1):
        u = i / steps
        z = BLADE_BASE + u * BLADE_LEN * 0.93
        w = 0.040 - 0.010 * u
        if kind == "bolang":
            w += 0.008 * math.sin(u * math.pi * 6.0)
        rings.append(diamond(z, w, 0.009 - 0.003 * u))
    rings.append([Vector((0, 0, BLADE_BASE + BLADE_LEN))])
    return loft(rings, True, False)


for kind in ("jian", "qixing", "bolang"):
    obj(f"sword_blade_{kind}", blade(kind), "steel")
# 七星：刃面两侧各七颗铜星
stars = []
for i in range(7):
    z = BLADE_BASE + 0.08 + i * 0.075
    for side in (-1, 1):
        stars.append(sphere(Vector((0, side * 0.0045, z)), 0.004, 0.0015, 0.004, 6, 3))
obj("sword_inlay_qixing", merge(*stars), "trim")

g0 = GRIP_HALF
obj("sword_guard_disc", loft([ring(g0, 0.045, 0.030, 12), ring(g0 + 0.016, 0.045, 0.030, 12)]), "trim")
obj("sword_guard_bar", loft([ring(g0, 0.075, 0.014, 4, phase=math.pi / 4), ring(g0 + 0.02, 0.075, 0.014, 4, phase=math.pi / 4)]), "trim")
obj("sword_guard_ruyi", merge(loft([ring(g0, 0.055, 0.013, 6), ring(g0 + 0.018, 0.055, 0.013, 6)]),
                               sphere(Vector((0.058, 0, g0 + 0.012)), 0.018, 0.013, 0.018, 8, 5),
                               sphere(Vector((-0.058, 0, g0 + 0.012)), 0.018, 0.013, 0.018, 8, 5)), "trim")
# 月牙护手：两头朝刃尖翘起
cres = []
for i in range(9):
    u = -1.0 + 2.0 * i / 8
    x = 0.075 * u
    z = g0 + 0.008 + 0.035 * u * u
    cres.append([Vector((x, 0.012, z - 0.008)), Vector((x, 0.012, z + 0.008)), Vector((x, -0.012, z + 0.008)), Vector((x, -0.012, z - 0.008))])
bm = bmesh.new()
vs = [[bm.verts.new(p) for p in r] for r in cres]
for a, b in zip(vs, vs[1:]):
    for k in range(4):
        bm.faces.new((a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]))
bm.faces.new(vs[0][::-1]); bm.faces.new(vs[-1])
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
obj("sword_guard_crescent", bm, "trim")

obj("sword_grip", cylinder(-GRIP_HALF, GRIP_HALF, 0.016, 8), "wrap")
p0 = -GRIP_HALF
obj("sword_pommel_hex", loft([ring(p0, 0.021, 0.021, 6), ring(p0 - 0.03, 0.021, 0.021, 6), [Vector((0, 0, p0 - 0.04))]], True, False), "trim")
obj("sword_pommel_knob", sphere(Vector((0, 0, p0 - 0.018)), 0.022, 0.022, 0.022, 10, 6), "trim")
obj("sword_pommel_cloud", sphere(Vector((0, 0, p0 - 0.016)), 0.034, 0.018, 0.02, 10, 6), "trim")
# 环首：在刃宽那个平面里立一个环
tor = []
R, r = 0.032, 0.007
for i in range(13):
    a = 2 * math.pi * i / 12
    c = Vector((R * math.cos(a), 0, p0 - R - 0.004 + R * math.sin(a)))
    n = Vector((math.cos(a), 0, math.sin(a)))
    tor.append([c + (n * math.cos(b) + Vector((0, 1, 0)) * math.sin(b)) * r for b in [2 * math.pi * k / 6 for k in range(6)]])
bm = bmesh.new()
vs = [[bm.verts.new(p) for p in rr] for rr in tor[:-1]]
for i in range(12):
    a, b = vs[i], vs[(i + 1) % 12]
    for k in range(6):
        bm.faces.new((a[k], a[(k + 1) % 6], b[(k + 1) % 6], b[k]))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
obj("sword_pommel_ring", bm, "trim")
obj("sword_tassel", tassel(p0 - 0.03, 0.16, 0.03), "tassel")

# ------------------------------------------------------------------ 长枪
BUTT, TOP = -0.80, 1.40
obj("spear_pole", cylinder(BUTT, TOP, 0.017, 8, 0.015), "wood")
obj("spear_cap", merge(cylinder(BUTT - 0.03, BUTT + 0.04, 0.020, 8), cylinder(TOP - 0.02, TOP + 0.06, 0.019, 8, 0.014)), "cap")
H0 = TOP + 0.06


def spear_head(kind):
    rings = []
    steps = 12
    length = 0.34 if kind == "snake" else 0.28
    for i in range(steps + 1):
        u = i / steps
        if kind == "leaf":
            w = 0.012 + 0.05 * math.sin(math.pi * min(1.0, u * 1.3)) * (1 - u) ** 0.3
            cx = 0.0
        elif kind == "snake":
            w = 0.03 * (1 - u) + 0.01
            cx = 0.014 * math.sin(u * math.pi * 3.0)
        else:  # ji: a straight spike, side blade added below
            w = 0.03 * (1 - u) + 0.012
            cx = 0.0
        rings.append(diamond(H0 + u * length * 0.92, w, 0.010 * (1 - 0.6 * u), cx))
    rings.append([Vector((0, 0, H0 + length))])
    return loft(rings, True, False)


obj("spear_head_leaf", spear_head("leaf"), "steel")
obj("spear_head_snake", spear_head("snake"), "steel")
ji = spear_head("ji")
# 戟的月牙侧刃：从枪头根部向 +X 伸出一道弯刃
side = [[Vector((0.02 + 0.09 * (i / 8), 0.005, H0 + 0.02 + 0.13 * (i / 8) * (1 - i / 8) * 4 * 0.5)),
         Vector((0.02 + 0.09 * (i / 8), 0.0, H0 + 0.05 + 0.13 * (i / 8) * (1 - i / 8) * 4 * 0.5)),
         Vector((0.02 + 0.09 * (i / 8), -0.005, H0 + 0.02 + 0.13 * (i / 8) * (1 - i / 8) * 4 * 0.5))] for i in range(9)]
bm = bmesh.new()
vs = [[bm.verts.new(p) for p in rr] for rr in side]
for a, b in zip(vs, vs[1:]):
    for k in range(3):
        bm.faces.new((a[k], a[(k + 1) % 3], b[(k + 1) % 3], b[k]))
bm.faces.new(vs[0][::-1]); bm.faces.new(vs[-1])
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
obj("spear_head_ji", merge(ji, bm), "steel")
obj("spear_tassel", tassel(TOP + 0.03, 0.13, 0.05, 11), "tassel")

# ------------------------------------------------------------------ 弓
HALF = 0.66


def bow_limbs(kind):
    def curve(u):  # u in [0,1] from grip to tip; returns x (toward the target is +X)
        x = -0.17 * u ** 1.6
        if kind == "fanqu":
            x += 0.07 * max(0.0, (u - 0.75) / 0.25) ** 2
        return x
    parts = []
    for sgn in (1, -1):
        rings = []
        for i in range(11):
            u = i / 10
            z = sgn * (0.06 + u * (HALF - 0.06))
            w = 0.034 * (1 - 0.6 * u)
            t = 0.018 * (1 - 0.5 * u)
            x = curve(u)
            rings.append([Vector((x + t / 2, w / 2, z)), Vector((x + t / 2, -w / 2, z)),
                          Vector((x - t / 2, -w / 2, z)), Vector((x - t / 2, w / 2, z))])
        parts.append(loft(rings))
    riser = loft([[Vector((0.012, 0.017, -0.07)), Vector((0.012, -0.017, -0.07)), Vector((-0.012, -0.017, -0.07)), Vector((-0.012, 0.017, -0.07))],
                  [Vector((0.012, 0.017, 0.07)), Vector((0.012, -0.017, 0.07)), Vector((-0.012, -0.017, 0.07)), Vector((-0.012, 0.017, 0.07))]])
    return merge(riser, *parts), curve(1.0)


limbs, tip_x = bow_limbs("chang")
obj("bow_limbs_chang", limbs, "wood")
limbs, tip_x_f = bow_limbs("fanqu")
obj("bow_limbs_fanqu", limbs, "wood")
obj("bow_grip", cylinder(-0.06, 0.06, 0.02, 8), "wrap")
for kind, tx in (("chang", tip_x), ("fanqu", tip_x_f)):
    a, b = Vector((tx, 0, HALF)), Vector((tx, 0, -HALF))
    obj(f"bow_string_{kind}", loft([ring(b.z, 0.0025, 0.0025, 4, b.x), ring(a.z, 0.0025, 0.0025, 4, a.x)]), "string")

os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_apply=True, export_animations=False)
if OUT_BLEND:
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
print("WEAPONS", OUT, sorted(o.name for o in bpy.data.objects))
