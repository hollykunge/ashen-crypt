"""Build the hero's Chinese weapons as modular parts and export them for Godot.

blender -b --factory-startup -P build_weapons.py -- <out.glb> [out.blend]

古朴华丽：剑身起脊、近格处错金菱纹，剑格嵌宝，柄缠菱形绳、两头铜箍，剑首起同心圈；枪头起脊、铜銎带箍，
杆上髹漆描金，镦尖，红缨蓬松；弓是反曲角弓，弓弰骨白，弦垫、漆带描金，弓弣缠绳。

Parts follow the game's weapon designs (mobile/scripts/weapon_design.gd), so a forged weapon keeps its look:
  剑 sword / jian : blade jian | qixing | bolang, guard ruyi | disc | bar | crescent, grip, pommel hex | ring | knob | cloud, tassel
  长枪 spear      : pole, butt cap + socket, head leaf | snake | ji, red tassel (红缨)
  弓 bow          : limbs chang | fanqu (fanqu also stands for jiao / yun), grip wrap, string
Every part is its own object named <form>_<kind>[_<variant>], all sharing one origin: the grip centre, where the fist
closes. Axes (Blender): +Z toward the tip (blade / spear head / upper bow limb), +X the blade's width (the bow's belly,
toward the target), Y the blade's thickness. glTF turns that into Godot +Y tip, +X width.
A part may carry several materials (one surface each); every material is named by its role (steel, trim, wrap, accent,
wood, core, cap, string, tassel) and the game colours each surface from the forged design (model_hero.gd hold), so
only flat placeholder colours are set here. The bow string stays one straight segment between the two limb tips
(model_hero.gd reads its ends from the bounding box). Sizes in metres.
"""
import bpy, bmesh, sys, os, math
from mathutils import Vector

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


# ------------------------------------------------------------------ geometry helpers
def smooth(bm, on=True):
    for f in bm.faces:
        f.smooth = on
    return bm


def merge(*bms):
    out = bmesh.new()
    for b in bms:
        me = bpy.data.meshes.new("tmp")
        b.to_mesh(me)
        out.from_mesh(me)
        bpy.data.meshes.remove(me)
        b.free()
    return out


def obj(name, pieces):
    """pieces: [(bmesh, role), ...] -> one object, one material slot per role"""
    if not isinstance(pieces, list):
        pieces = [pieces]
    roles = []
    out = bmesh.new()
    for bm, role in pieces:
        if role not in roles:
            roles.append(role)
        idx = roles.index(role)
        for f in bm.faces:
            f.material_index = idx
        me = bpy.data.meshes.new("tmp")
        bm.to_mesh(me)
        out.from_mesh(me)
        bpy.data.meshes.remove(me)
        bm.free()
    me = bpy.data.meshes.new(name)
    out.normal_update()
    out.to_mesh(me)
    out.free()
    for role in roles:
        me.materials.append(MATS[role])
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


def lathe(profile, n=16, cx=0.0):
    """profile: [(z, r)] from bottom to top -> closed solid of revolution around Z"""
    return smooth(loft([ring(z, r, r, n, cx) if r > 1e-5 else [Vector((cx, 0, z))] for z, r in profile]))


def cylinder(z0, z1, r, n=12, r1=None):
    return smooth(loft([ring(z0, r, r, n), ring(z1, r1 if r1 is not None else r, r1 if r1 is not None else r, n)]))


def sphere(c, rx, ry, rz, seg=10, rings_=6):
    pts = []
    for k in range(1, rings_):
        a = math.pi * k / rings_
        pts.append(ring(c.z - rz * math.cos(a), rx * math.sin(a), ry * math.sin(a), seg, c.x, c.y))
    return smooth(loft([[Vector((c.x, c.y, c.z - rz))]] + pts + [[Vector((c.x, c.y, c.z + rz))]], False, False))


def prism(outline, y0, y1):
    """outline: [(x, z)] counter-clockwise in the XZ plane, extruded from y0 to y1 (a flat plate)"""
    return loft([[Vector((x, y0, z)) for x, z in outline], [Vector((x, y1, z)) for x, z in outline]])


def plate(outline, half, bevel=0.0):
    """a flat plate in the XZ plane, thickness 2*half, edges bevelled inward by `bevel`"""
    if bevel <= 0:
        return prism(outline, -half, half)
    c = Vector((sum(x for x, _ in outline) / len(outline), 0, sum(z for _, z in outline) / len(outline)))
    inner = [(c.x + (x - c.x) * (1 - bevel), c.z + (z - c.z) * (1 - bevel)) for x, z in outline]
    return loft([[Vector((x, -half * 0.55, z)) for x, z in inner], [Vector((x, -half, z)) for x, z in outline],
                 [Vector((x, half, z)) for x, z in outline], [Vector((x, half * 0.55, z)) for x, z in inner]])


def tube(points, r, n=6):
    """a thin round tube along a polyline"""
    rings = []
    for i, p in enumerate(points):
        d = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
        a = d.cross(Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))).normalized()
        b = d.cross(a).normalized()
        rings.append([p + (a * math.cos(2 * math.pi * k / n) + b * math.sin(2 * math.pi * k / n)) * r for k in range(n)])
    return smooth(loft(rings))


def torus(c, R, r, axis="y", n=20, m=8):
    rings = []
    for i in range(n + 1):
        a = 2 * math.pi * i / n
        if axis == "y":    # ring standing in the XZ plane
            ctr = c + Vector((R * math.cos(a), 0, R * math.sin(a)))
            nrm, up = Vector((math.cos(a), 0, math.sin(a))), Vector((0, 1, 0))
        else:              # ring lying in the XY plane (around Z)
            ctr = c + Vector((R * math.cos(a), R * math.sin(a), 0))
            nrm, up = Vector((math.cos(a), math.sin(a), 0)), Vector((0, 0, 1))
        rings.append([ctr + (nrm * math.cos(2 * math.pi * k / m) + up * math.sin(2 * math.pi * k / m)) * r for k in range(m)])
    bm = bmesh.new()
    vs = [[bm.verts.new(p) for p in rr] for rr in rings[:-1]]
    for i in range(n):
        a, b = vs[i], vs[(i + 1) % n]
        for k in range(m):
            bm.faces.new((a[k], a[(k + 1) % m], b[(k + 1) % m], b[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return smooth(bm)


def tassel(z_top, length, spread, strands=24, cx=0.0, drop=-1.0, width=0.0045):
    """a full bunch of fine strands hanging from z_top (drop=-1: toward -Z): each flares out, then droops"""
    parts = []
    for i in range(strands):
        a = 2 * math.pi * i / strands + 0.35 * math.sin(i * 2.3)
        ln = length * (0.78 + 0.22 * math.sin(i * 1.7) ** 2)
        sp = spread * (0.6 + 0.4 * math.cos(i * 1.3) ** 2)
        pts = []
        for k in range(7):
            u = k / 6
            out = sp * math.sin(min(1.0, u * 1.6) * math.pi / 2)
            pts.append(Vector((cx + out * math.cos(a), out * math.sin(a), z_top + drop * ln * u)))
        parts.append(tube(pts, width * 0.5, 4))
    return merge(*parts)


# ================================================================== 剑
GRIP_HALF = 0.10
BLADE_BASE = 0.125
BLADE_LEN = 0.74


def blade_section(w, t, cx=0.0):
    """八点截面：刃口、斜面、中脊（刃口薄、中脊厚，剑面起两道斜面）"""
    return [Vector((cx + w / 2, 0, 0)), Vector((cx + w * 0.28, t * 0.30, 0)), Vector((cx, t / 2, 0)),
            Vector((cx - w * 0.28, t * 0.30, 0)), Vector((cx - w / 2, 0, 0)), Vector((cx - w * 0.28, -t * 0.30, 0)),
            Vector((cx, -t / 2, 0)), Vector((cx + w * 0.28, -t * 0.30, 0))]


def blade_width(kind, u):
    w = 0.042 - 0.012 * u
    if kind == "bolang":
        w += 0.007 * math.sin(u * math.pi * 7.0) * (1 - u * 0.6)
    if u > 0.86:   # 剑锋：两肩弧收到尖
        k = (u - 0.86) / 0.14
        w *= math.sqrt(max(0.0, 1 - k * k)) * (1 - 0.15 * k)
    return w


def blade_face_y(kind, u, x):
    """剑面上某一点的 y（+Y 那面），用来把错金纹贴在刃面上"""
    w = blade_width(kind, u)
    t = 0.010 - 0.004 * u
    ax = abs(x)
    if ax <= w * 0.28:
        return t / 2 - (t / 2 - t * 0.30) * ax / (w * 0.28)
    return t * 0.30 * max(0.0, 1 - (ax - w * 0.28) / (w * 0.22))


def blade(kind):
    rings = []
    steps = 30
    for i in range(steps + 1):
        u = i / steps * 0.995
        z = BLADE_BASE + u * BLADE_LEN
        w = blade_width(kind, u)
        t = 0.010 - 0.004 * u
        rings.append([v + Vector((0, 0, z)) for v in blade_section(max(w, 0.002), max(t, 0.0015))])
    rings.append([Vector((0, 0, BLADE_BASE + BLADE_LEN))])
    return loft(rings, True, False)


def inlay_strip(kind, a, b, width=0.0030, lift=0.0005):
    """错金细线：剑面上从 a 到 b（(x, u)）的一条薄金条，两面各一条"""
    out = []
    for side in (1, -1):
        quads = []
        for (x, u) in (a, b):
            z = BLADE_BASE + u * BLADE_LEN
            y = side * (blade_face_y(kind, u, x) + lift)
            quads.append((Vector((x, y, z))))
        d = (quads[1] - quads[0])
        n = Vector((d.z, 0, -d.x)).normalized() * width / 2
        ins = Vector((0, -side * 0.0007, 0))
        rings = [[quads[0] + n, quads[0] - n, quads[0] - n + ins, quads[0] + n + ins],
                 [quads[1] + n, quads[1] - n, quads[1] - n + ins, quads[1] + n + ins]]
        out.append(loft(rings))
    return merge(*out)


def lozenge_band(kind, u0, u1, count=3):
    """近格处一串菱形错金纹（越王剑那种菱格），沿中脊排"""
    strips = []
    step = (u1 - u0) / count
    for i in range(count):
        a, b = u0 + i * step, u0 + (i + 1) * step
        m = (a + b) / 2
        w = blade_width(kind, m) * 0.42
        pts = [(0.0, a), (w, m), (0.0, b), (-w, m)]
        for k in range(4):
            strips.append(inlay_strip(kind, pts[k], pts[(k + 1) % 4]))
    return merge(*strips)


for kind in ("jian", "qixing", "bolang"):
    pieces = [(blade(kind), "steel"), (lozenge_band(kind, 0.02, 0.20, 3 if kind != "bolang" else 2), "trim")]
    obj(f"sword_blade_{kind}", pieces)

# 七星：北斗七颗金星，星间错金连线，两面都有
DIPPER = [(-0.006, 0.30), (0.004, 0.36), (0.010, 0.43), (0.004, 0.50), (-0.008, 0.55), (-0.010, 0.63), (0.006, 0.66)]
stars = []
for i, (x, u) in enumerate(DIPPER):
    z = BLADE_BASE + u * BLADE_LEN
    for side in (1, -1):
        y = side * (blade_face_y("qixing", u, x) + 0.0008)
        stars.append(sphere(Vector((x, y, z)), 0.0042, 0.0012, 0.0042, 8, 4))
    if i:
        stars.append(inlay_strip("qixing", DIPPER[i - 1], (x, u), 0.0014))
obj("sword_inlay_qixing", (merge(*stars), "trim"))

# ---------------------------------------------------------------- 剑格（护手）
g0 = GRIP_HALF
GUARD_T = 0.016   # 剑格半厚：古剑的格是厚实一块


def gem(x, z, r=0.0065):
    """剑格两面各嵌一颗宝石（accent：主行颜色）"""
    y = GUARD_T + 0.0008
    return merge(sphere(Vector((x, y, z)), r, 0.0035, r, 12, 6), sphere(Vector((x, -y, z)), r, 0.0035, r, 12, 6))


def bezel(x, z, r=0.0095):
    """宝石外一圈金托：两面各一圈薄环"""
    def hoop(y0, y1):
        pts = lambda y: [Vector((x + r * math.cos(2 * math.pi * k / 16), y, z + r * math.sin(2 * math.pi * k / 16)))
                         for k in range(16)]
        return loft([pts(y0), pts(y1)], False, False)
    return merge(hoop(GUARD_T - 0.001, GUARD_T + 0.0018), hoop(-GUARD_T + 0.001, -GUARD_T - 0.0018))


# 圆格：椭圆盘，边上倒角，正中嵌宝
disc = [(0.048 * math.cos(2 * math.pi * k / 28), g0 + 0.014 + 0.014 * math.sin(2 * math.pi * k / 28)) for k in range(28)]
obj("sword_guard_disc", [(smooth(plate(disc, GUARD_T, 0.16)), "trim"), (gem(0, g0 + 0.014), "accent"),
                         (bezel(0, g0 + 0.014), "trim")])

# 凹字格：一字格两头微翘、下沿正中凹进，两面起兽面纹（菱形凸台），正中嵌宝
BAR = [(-0.064, g0 + 0.004), (-0.050, g0 + 0.000), (-0.012, g0 + 0.000), (-0.008, g0 + 0.007), (0.008, g0 + 0.007),
       (0.012, g0 + 0.000), (0.050, g0 + 0.000), (0.064, g0 + 0.004), (0.066, g0 + 0.020), (0.040, g0 + 0.024),
       (0.0, g0 + 0.026), (-0.040, g0 + 0.024), (-0.066, g0 + 0.020)]
bar = [(x * 1.12, g0 + (z - g0) * 1.25) for x, z in BAR]
boss = []
for side in (1, -1):
    boss.append(loft([[Vector((x, side * (GUARD_T - 0.0005), z)) for x, z in [(0.026, g0 + 0.013), (0, g0 + 0.022), (-0.026, g0 + 0.013), (0, g0 + 0.004)]],
                      [Vector((x, side * (GUARD_T + 0.0025), z)) for x, z in [(0.018, g0 + 0.013), (0, g0 + 0.019), (-0.018, g0 + 0.013), (0, g0 + 0.007)]]]))
obj("sword_guard_bar", [(plate(bar, GUARD_T, 0.1), "trim"), (merge(*boss), "core"), (gem(0, g0 + 0.016, 0.0055), "accent")])

# 如意格：中间方台，两头各一朵三瓣如意云头
ruyi = [smooth(plate([(-0.032, g0), (0.032, g0), (0.036, g0 + 0.026), (-0.036, g0 + 0.026)], GUARD_T, 0.12))]
for sx in (1, -1):
    for dx, dz, r in ((0.056, 0.013, 0.015), (0.045, 0.030, 0.011), (0.045, -0.003, 0.011)):
        ruyi.append(sphere(Vector((sx * dx, 0, g0 + dz)), r, GUARD_T * 0.85, r, 14, 7))
    for side in (1, -1):
        ruyi.append(torus(Vector((sx * 0.058, side * GUARD_T * 0.8, g0 + 0.013)), 0.007, 0.0017, "y", 14, 5))
obj("sword_guard_ruyi", [(merge(*ruyi), "trim"), (gem(0, g0 + 0.013), "accent")])

# 月牙格：两臂朝剑尖弯起，臂端各一颗圆珠
arm = []
for i in range(13):
    u = -1.0 + 2.0 * i / 12
    x = 0.072 * u
    z = g0 + 0.008 + 0.034 * u * u
    t = GUARD_T * (1 - 0.35 * abs(u))
    h = 0.011 * (1 - 0.3 * abs(u))
    arm.append([Vector((x, t, z - h)), Vector((x, t, z + h)), Vector((x, -t, z + h)), Vector((x, -t, z - h))])
cres = loft(arm)
obj("sword_guard_crescent", [(smooth(cres), "trim"),
                             (merge(sphere(Vector((0.075, 0, g0 + 0.045)), 0.0115, 0.0115, 0.0115),
                                    sphere(Vector((-0.075, 0, g0 + 0.045)), 0.0115, 0.0115, 0.0115)), "trim"),
                             (gem(0, g0 + 0.010, 0.0058), "accent")])

# ---------------------------------------------------------------- 柄、首、穗：剑和刀各出一套（前缀 sword / dao）
def hilt(prefix, oval=1.0):
    """柄：深色木芯、菱形缠绳、两头铜箍。oval < 1 是刀柄那种扁圆柄"""
    core_r = 0.0140
    grip_core = loft([ring(z, core_r, core_r * oval, 12) for z in (-GRIP_HALF + 0.010, GRIP_HALF - 0.010)])
    cords = []
    L = 2 * (GRIP_HALF - 0.016)
    for direction in (1, -1):
        for start in (0.0, math.pi):
            pts = []
            for k in range(49):
                u = k / 48
                a = start + direction * 2 * math.pi * 4.0 * u
                pts.append(Vector(((core_r + 0.0012) * math.cos(a), (core_r * oval + 0.0012) * math.sin(a), -L / 2 + L * u)))
            cords.append(tube(pts, 0.0019, 5))
    def ferrule(z0):
        """一道 1.4 厘米宽的铜箍，中间略鼓"""
        return smooth(loft([ring(z, r, r * oval, 16) if r > 1e-5 else [Vector((0, 0, z))] for z, r in
                            [(z0, 0.0), (z0, 0.0175), (z0 + 0.004, 0.0185), (z0 + 0.012, 0.0172), (z0 + 0.014, 0.0)]]))
    ferrules = merge(ferrule(-GRIP_HALF), ferrule(GRIP_HALF - 0.014))
    obj(f"{prefix}_grip", [(smooth(grip_core), "core"), (merge(*cords), "wrap"), (ferrules, "trim")])

    p0 = -GRIP_HALF
    # 圆首：剑是圆盘形剑首，底面两道同心圈；刀是圆顶帽，顶上一个系穗的小环
    if prefix == "dao":
        knob = lathe([(p0 - 0.026, 0.0), (p0 - 0.024, 0.008), (p0 - 0.018, 0.016), (p0 - 0.008, 0.0195), (p0 - 0.002, 0.0185),
                      (p0, 0.0170), (p0, 0.0)], 24)
        extra = torus(Vector((0, 0, p0 - 0.032)), 0.006, 0.0018, "y", 14, 5)
        obj(f"{prefix}_pommel_knob", [(knob, "trim"), (torus(Vector((0, 0, p0 - 0.010)), 0.0198, 0.0018, "z", 20, 5), "core"),
                                      (extra, "trim")])
    else:
        knob = lathe([(p0 - 0.022, 0.0), (p0 - 0.022, 0.024), (p0 - 0.018, 0.028), (p0 - 0.010, 0.027), (p0 - 0.004, 0.019),
                      (p0, 0.016), (p0, 0.0)], 24)
        rings_ = merge(torus(Vector((0, 0, p0 - 0.0225)), 0.018, 0.0014, "z", 24, 5),
                       torus(Vector((0, 0, p0 - 0.0225)), 0.010, 0.0012, "z", 20, 5))
        obj(f"{prefix}_pommel_knob", [(knob, "trim"), (rings_, "core"),
                                      (sphere(Vector((0, 0, p0 - 0.0235)), 0.004, 0.004, 0.0025, 10, 5), "accent")])
    # 六棱首：六棱柱收顶，腰上一圈箍
    hexp = loft([ring(p0, 0.017, 0.017, 6, phase=math.pi / 6), ring(p0 - 0.006, 0.022, 0.022, 6, phase=math.pi / 6),
                 ring(p0 - 0.030, 0.022, 0.022, 6, phase=math.pi / 6), ring(p0 - 0.040, 0.012, 0.012, 6, phase=math.pi / 6),
                 [Vector((0, 0, p0 - 0.046))]], True, False)
    obj(f"{prefix}_pommel_hex", [(hexp, "trim"), (torus(Vector((0, 0, p0 - 0.018)), 0.0225, 0.0022, "z", 18, 5), "core")])
    # 云头首：扁平如意云头
    cloud = [smooth(plate([(-0.016, p0), (0.016, p0), (0.018, p0 - 0.012), (-0.018, p0 - 0.012)], 0.011, 0.1))]
    for dx, dz, r in ((0.0, -0.024, 0.016), (0.018, -0.016, 0.011), (-0.018, -0.016, 0.011)):
        cloud.append(sphere(Vector((dx, 0, p0 + dz)), r, 0.010, r, 12, 6))
    obj(f"{prefix}_pommel_cloud", [(merge(*cloud), "trim"),
                                   (merge(torus(Vector((0, 0.0105, p0 - 0.024)), 0.008, 0.0014, "y", 14, 5),
                                          torus(Vector((0, -0.0105, p0 - 0.024)), 0.008, 0.0014, "y", 14, 5)), "core")])
    # 环首：在刃宽那个平面里立一个粗环，颈上一道箍（刀的环首刀环更大）
    R = 0.034 if prefix == "dao" else 0.030
    obj(f"{prefix}_pommel_ring", [(torus(Vector((0, 0, p0 - 0.006 - R)), R, 0.0075, "y", 24, 8), "trim"),
                                  (lathe([(p0 - 0.008, 0.0), (p0 - 0.008, 0.012), (p0 - 0.002, 0.016), (p0, 0.0155), (p0, 0.0)], 14), "trim"),
                                  (merge(sphere(Vector((R, 0, p0 - 0.006 - R)), 0.0085, 0.0085, 0.0085),
                                         sphere(Vector((-R, 0, p0 - 0.006 - R)), 0.0085, 0.0085, 0.0085)), "core")])
    # 穗：金珠打结，下垂一把丝穗
    obj(f"{prefix}_tassel", [(sphere(Vector((0, 0, p0 - 0.074)), 0.0075, 0.0075, 0.0085), "trim"),
                             (tube([Vector((0, 0, p0 - 0.04)), Vector((0, 0, p0 - 0.068))], 0.0016, 5), "tassel"),
                             (tassel(p0 - 0.080, 0.17, 0.026, 26, width=0.0035), "tassel")])


hilt("sword")
hilt("dao", oval=0.78)

# ================================================================== 刀
# 照古刀的样子：单刃，刃口朝 +X（挥砍时领先那侧），刀身往刀背那侧弯；刀头比刀根宽，刀尖收在刀背一侧。
# 三款和锻造的刃型对应（weapon_design.gd 的 blade）：jian → 柳叶刀，qixing → 雁翎刀，bolang → 朴刀。
DAO_BASE = 0.118
DAO_LEN = 0.70
# 照古刀：刀身宽（最宽处约刀长的六分之一），越往前越宽，刀背近乎直，刃口外鼓，刀尖是一道斜削收到刀背那侧
DAO = {
    "liuye": dict(w0=0.042, w1=0.068, bend=0.022, late=False, clip=0.0),    # 柳叶刀：中宽，通体微弯
    "yanling": dict(w0=0.040, w1=0.060, bend=0.040, late=True, clip=0.0),   # 雁翎刀：前段直，后三成上挑
    "pudao": dict(w0=0.046, w1=0.104, bend=0.012, late=False, clip=0.020),  # 朴刀：刀头宽大，刀背近尖处削进一道
}


def dao_shape(kind, u):
    """刀背、刃口的 x 和刀背厚：返回 (spine_x, edge_x, t)"""
    d = DAO[kind]
    if d["late"]:
        c = -d["bend"] * max(0.0, (u - 0.6) / 0.4) ** 2
    else:
        c = -d["bend"] * u * u
    w = d["w0"] + (d["w1"] - d["w0"]) * min(1.0, u / 0.84) ** 1.8
    spine = c - w * 0.25
    edge = c + w * 0.75
    if u > 0.84:   # 刀尖：刃口一道斜削收到刀背那侧
        k = (u - 0.84) / 0.16
        edge = spine + (edge - spine) * (1 - k ** 1.15)
    if d["clip"] > 0 and u > 0.72:   # 朴刀刀背削进去
        k = (u - 0.72) / 0.28
        spine += d["clip"] * math.sin(k * math.pi / 2) ** 1.5
        edge = max(edge, spine + 0.0015)
    t = 0.0085 * (1 - 0.55 * u)
    return spine, edge, t


def dao_section(spine, edge, t, z):
    m = spine + (edge - spine) * 0.42
    return [Vector((edge, 0, z)), Vector((m, t * 0.40, z)), Vector((spine, t / 2, z)),
            Vector((spine, -t / 2, z)), Vector((m, -t * 0.40, z))]


def dao_blade(kind):
    rings = []
    steps = 36
    for i in range(steps + 1):
        u = i / steps * 0.995
        spine, edge, t = dao_shape(kind, u)
        rings.append(dao_section(spine, max(edge, spine + 0.0015), max(t, 0.0012), DAO_BASE + u * DAO_LEN))
    spine, edge, t = dao_shape(kind, 1.0)
    rings.append([Vector((spine, 0, DAO_BASE + DAO_LEN))])
    return loft(rings, True, False)


def dao_fuller(kind, u0=0.04, u1=0.62):
    """血槽：靠刀背一侧一道深色细槽，两面都有"""
    out = []
    for side in (1, -1):
        rings = []
        for i in range(21):
            u = u0 + (u1 - u0) * i / 20
            spine, edge, t = dao_shape(kind, u)
            x = spine + (edge - spine) * 0.22
            y = side * (t * 0.47 + 0.0004)
            z = DAO_BASE + u * DAO_LEN
            hw = 0.0022
            rings.append([Vector((x - hw, y, z)), Vector((x + hw, y, z)), Vector((x + hw, y - side * 0.0006, z)),
                          Vector((x - hw, y - side * 0.0006, z))])
        out.append(loft(rings))
    return merge(*out)


def dao_collar(kind):
    """吞口：刀根上一块铜，包住刀身，刀背那侧起一道兽面似的尖"""
    spine, edge, t = dao_shape(kind, 0.0)
    pad = 0.0025
    def box(z, grow):
        return [Vector((edge + pad + grow, t / 2 + pad + grow, z)), Vector((spine - pad - grow, t / 2 + pad + grow, z)),
                Vector((spine - pad - grow, -t / 2 - pad - grow, z)), Vector((edge + pad + grow, -t / 2 - pad - grow, z))]
    body = loft([box(DAO_BASE - 0.018, 0.002), box(DAO_BASE + 0.010, 0.0015), box(DAO_BASE + 0.030, 0.0)])
    tip = loft([[Vector((spine - pad, t / 2 + pad, DAO_BASE + 0.030)), Vector((spine - pad, -t / 2 - pad, DAO_BASE + 0.030)),
                 Vector((spine + 0.010, -t / 2 - pad, DAO_BASE + 0.030)), Vector((spine + 0.010, t / 2 + pad, DAO_BASE + 0.030))],
                [Vector((spine + 0.002, 0, DAO_BASE + 0.052))]], True, False)
    return merge(body, tip)


for design_key, kind in (("jian", "liuye"), ("qixing", "yanling"), ("bolang", "pudao")):
    obj(f"dao_blade_{design_key}", [(dao_blade(kind), "steel"), (dao_fuller(kind), "core"), (dao_collar(kind), "trim")])

# ---------------------------------------------------------------- 刀镡：刀的护手是一块横在柄上的盘（垂直于刀身）
t0 = GRIP_HALF


def dao_disc(rx, ry, z0, z1, lobes=0, amp=0.0, n=40, cup=0.0):
    def outline(scale, z, lift=0.0):
        pts = []
        for k in range(n):
            a = 2 * math.pi * k / n
            r = 1.0 + amp * math.cos(lobes * a) if lobes else 1.0
            pts.append(Vector((rx * scale * r * math.cos(a), ry * scale * r * math.sin(a), z + lift)))
        return pts
    return smooth(loft([outline(0.62, z0), outline(1.0, z0 + 0.002, cup * 0.2), outline(1.0, z1, cup),
                        outline(0.62, z1 + 0.002)]), False)


def studs(z, rx, ry, count=6, r=0.0035):
    return merge(*[sphere(Vector((rx * 0.82 * math.cos(2 * math.pi * k / count + math.pi / count),
                                  ry * 0.82 * math.sin(2 * math.pi * k / count + math.pi / count), z)), r, r, r * 0.8, 8, 4)
                   for k in range(count)])


# 圆镡：椭圆盘，边上一圈深色线，上面六颗铜钉
obj("dao_guard_disc", [(dao_disc(0.046, 0.034, t0, t0 + 0.011), "trim"),
                       (torus(Vector((0, 0, t0 + 0.0115)), 0.030, 0.0014, "z", 28, 5), "core"),
                       (studs(t0 + 0.012, 0.046, 0.034), "accent")])
# S 形护手：一头朝刀尖弯，一头朝刀柄弯，两头圆珠（照 S 形格的古刀）
s_pts = []
for i in range(25):
    u = -1 + 2 * i / 24
    s_pts.append(Vector((0.068 * u, 0, t0 + 0.008 + 0.030 * math.sin(u * math.pi) * (0.5 + 0.5 * abs(u)))))
obj("dao_guard_bar", [(tube(s_pts, 0.0065, 8), "trim"),
                      (merge(sphere(s_pts[0], 0.0095, 0.0095, 0.0095), sphere(s_pts[-1], 0.0095, 0.0095, 0.0095)), "trim"),
                      (dao_disc(0.022, 0.018, t0, t0 + 0.014), "trim"),
                      (merge(sphere(Vector((0, 0.019, t0 + 0.007)), 0.0055, 0.003, 0.0055),
                             sphere(Vector((0, -0.019, t0 + 0.007)), 0.0055, 0.003, 0.0055)), "accent")])
# 云镡：四瓣云头边的盘
obj("dao_guard_ruyi", [(dao_disc(0.044, 0.036, t0, t0 + 0.012, lobes=4, amp=0.12), "trim"),
                       (torus(Vector((0, 0, t0 + 0.0125)), 0.024, 0.0016, "z", 24, 5), "core"),
                       (studs(t0 + 0.013, 0.040, 0.032, 4, 0.0042), "accent")])
# 碗镡：盘边朝刀身翘起成浅碗
obj("dao_guard_crescent", [(dao_disc(0.044, 0.036, t0, t0 + 0.010, cup=0.012), "trim"),
                           (torus(Vector((0, 0, t0 + 0.0105)), 0.022, 0.0016, "z", 24, 5), "core"),
                           (studs(t0 + 0.011, 0.034, 0.027, 8, 0.0028), "accent")])

# ================================================================== 长枪
BUTT, TOP = -0.80, 1.40
POLE_R0, POLE_R1 = 0.017, 0.0155


def pole_r(z):
    return POLE_R0 + (POLE_R1 - POLE_R0) * (z - BUTT) / (TOP - BUTT)


def band(z0, z1, role_pad=0.0012):
    return cylinder(z0, z1, pole_r(z0) + role_pad, 14, pole_r(z1) + role_pad)


# 杆：木杆，近枪头一段髹黑漆、上下描金箍，尾段一圈黑漆
lacquer = merge(band(1.12, 1.33), band(-0.70, -0.60))
gilt = merge(*[band(z, z + 0.008, 0.0022) for z in (1.112, 1.335, -0.708, -0.598)])
obj("spear_pole", [(cylinder(BUTT, TOP, POLE_R0, 14, POLE_R1), "wood"), (lacquer, "core"), (gilt, "trim")])

# 銎（枪头的铜套）和镦（枪尾的尖铜帽）
socket = lathe([(TOP - 0.03, 0.0), (TOP - 0.03, 0.0170), (TOP - 0.02, 0.0205), (TOP - 0.012, 0.0190), (TOP + 0.005, 0.0172),
                (TOP + 0.020, 0.0195), (TOP + 0.028, 0.0175), (TOP + 0.050, 0.0130), (TOP + 0.060, 0.0100),
                (TOP + 0.060, 0.0)], 16)
butt = lathe([(BUTT - 0.095, 0.0), (BUTT - 0.070, 0.0080), (BUTT - 0.040, 0.0160), (BUTT - 0.030, 0.0205),
              (BUTT - 0.020, 0.0178), (BUTT + 0.010, 0.0182), (BUTT + 0.020, 0.0200), (BUTT + 0.030, 0.0178),
              (BUTT + 0.030, 0.0)], 16)
obj("spear_cap", [(merge(socket, butt), "cap"),
                  (merge(torus(Vector((0, 0, TOP - 0.020)), 0.0205, 0.0022, "z", 18, 5),
                         torus(Vector((0, 0, TOP + 0.020)), 0.0195, 0.0020, "z", 18, 5),
                         torus(Vector((0, 0, BUTT + 0.020)), 0.0200, 0.0022, "z", 18, 5)), "trim")])
H0 = TOP + 0.06


def head_section(w, t, cx=0.0):
    return [Vector((cx + w / 2, 0, 0)), Vector((cx + w * 0.22, t * 0.35, 0)), Vector((cx, t / 2, 0)),
            Vector((cx - w * 0.22, t * 0.35, 0)), Vector((cx - w / 2, 0, 0)), Vector((cx - w * 0.22, -t * 0.35, 0)),
            Vector((cx, -t / 2, 0)), Vector((cx + w * 0.22, -t * 0.35, 0))]


def spear_head(kind):
    rings = []
    steps = 22
    length = 0.36 if kind == "snake" else (0.34 if kind == "leaf" else 0.30)
    for i in range(steps + 1):
        u = i / steps * 0.98
        if kind == "leaf":
            w = 0.012 + 0.038 * math.sin(math.pi * min(1.0, u * 1.2)) ** 0.9 * (1 - u) ** 0.45
            cx = 0.0
        elif kind == "snake":
            w = 0.044 * (1 - u) ** 0.8 + 0.010
            cx = 0.018 * math.sin(u * math.pi * 3.0) * (0.4 + 0.6 * u)
        else:  # ji: straight four-edged spike
            w = 0.028 * (1 - u) + 0.010
            cx = 0.0
        t = 0.013 * (1 - 0.6 * u)
        rings.append([v + Vector((0, 0, H0 + u * length)) for v in head_section(w, t, cx)])
    tip_x = rings[-1][0].x - (rings[-1][0].x - rings[-1][4].x) / 2
    rings.append([Vector((tip_x, 0, H0 + length))])
    return loft(rings, True, False)


# 枪头根部：一道金箍、一颗铜珠、一圈莲瓣似的小尖（照古枪那种叠起来的枪头座）
def head_mount():
    bead = sphere(Vector((0, 0, H0 - 0.002)), 0.0135, 0.0135, 0.010, 14, 7)
    petals = []
    for k in range(8):
        a = 2 * math.pi * k / 8
        d = Vector((math.cos(a), math.sin(a), 0))
        base = Vector((0, 0, H0 + 0.004))
        petals.append(loft([[base + d * 0.009 + d.cross(Vector((0, 0, 1))) * 0.004, base + d * 0.009 - d.cross(Vector((0, 0, 1))) * 0.004,
                             base + d * 0.009 + Vector((0, 0, 0.006))],
                            [base + d * 0.019 + Vector((0, 0, 0.016))]], True, False))
    return merge(bead, *petals)


def wings():
    """柳叶枪头根部两片往后掠的小翼"""
    out = []
    for sx in (1, -1):
        out.append(prism([(sx * 0.008, H0 + 0.040), (sx * 0.044, H0 + 0.008), (sx * 0.050, H0 - 0.012),
                          (sx * 0.030, H0 + 0.006), (sx * 0.008, H0 + 0.020)][::sx], -0.0025, 0.0025))
    return merge(*out)


collar = lathe([(H0 - 0.006, 0.0), (H0 - 0.006, 0.0105), (H0, 0.0125), (H0 + 0.010, 0.0105), (H0 + 0.010, 0.0)], 12)
obj("spear_head_leaf", [(merge(spear_head("leaf"), wings()), "steel"), (merge(collar, head_mount()), "trim")])
collar = lathe([(H0 - 0.006, 0.0), (H0 - 0.006, 0.0105), (H0, 0.0125), (H0 + 0.010, 0.0105), (H0 + 0.010, 0.0)], 12)
obj("spear_head_snake", [(spear_head("snake"), "steel"), (merge(collar, head_mount()), "trim")])
# 戟：直刺加一侧月牙刃，月牙外缘薄、内缘厚，背侧再出一个小钩
moon = []
for i in range(15):
    a = math.radians(-70 + 140 * i / 14)
    outer = (0.004 + 0.092 * math.cos(a), H0 + 0.06 + 0.092 * math.sin(a))
    inner = (0.004 + 0.058 * math.cos(a), H0 + 0.06 + 0.063 * math.sin(a))
    moon.append([Vector((outer[0], 0.0015, outer[1])), Vector((inner[0], 0.0055, inner[1])),
                 Vector((inner[0], -0.0055, inner[1])), Vector((outer[0], -0.0015, outer[1]))])
moon_bar = loft([[Vector((0.0, 0.006, H0 + 0.045)), Vector((0.0, -0.006, H0 + 0.045)), Vector((0.0, -0.006, H0 + 0.075)), Vector((0.0, 0.006, H0 + 0.075))],
                 [Vector((0.064, 0.005, H0 + 0.050)), Vector((0.064, -0.005, H0 + 0.050)), Vector((0.064, -0.005, H0 + 0.070)), Vector((0.064, 0.005, H0 + 0.070))]])
hook = loft([[Vector((-0.012, 0.004, H0 + 0.050)), Vector((-0.012, -0.004, H0 + 0.050)), Vector((-0.012, -0.004, H0 + 0.070)), Vector((-0.012, 0.004, H0 + 0.070))],
             [Vector((-0.045, 0.002, H0 + 0.082)), Vector((-0.045, -0.002, H0 + 0.082)), Vector((-0.045, -0.002, H0 + 0.090)), Vector((-0.045, 0.002, H0 + 0.090))],
             [Vector((-0.050, 0.0, H0 + 0.105))]], True, False)
collar = lathe([(H0 - 0.006, 0.0), (H0 - 0.006, 0.0105), (H0, 0.0125), (H0 + 0.010, 0.0105), (H0 + 0.010, 0.0)], 12)
obj("spear_head_ji", [(merge(spear_head("ji"), loft(moon), moon_bar, hook), "steel"), (merge(collar, head_mount()), "trim")])
# 红缨：蓬松一圈，系在銎上
obj("spear_tassel", [(tassel(TOP + 0.045, 0.17, 0.075, 48, width=0.0045), "tassel"),
                     (torus(Vector((0, 0, TOP + 0.045)), 0.0145, 0.0035, "z", 16, 6), "tassel")])

# ================================================================== 弓：反曲角弓
HALF = 0.66


def bow_curve(kind, u):
    """u 0..1 从弓弣到弓弰尖，返回 (x, z)：x 朝目标为正。照古弓的样子：弓弣退向弦，弓臂先往前鼓，
    再往回收，弓弰（最后一成半）是一段硬直的角，尖上往弦那侧勾一点。反曲弓鼓得更狠"""
    z = 0.07 + u * (HALF - 0.07)
    bulge = 0.075 if kind == "fanqu" else 0.050
    pts = [(0.00, 0.0), (0.10, 0.004), (0.36, bulge), (0.60, bulge * 0.45), (0.85, -0.105), (1.00, -0.150)]
    for (u0, x0), (u1, x1) in zip(pts, pts[1:]):
        if u <= u1:
            k = (u - u0) / (u1 - u0)
            k = k * k * (3 - 2 * k)
            return x0 + (x1 - x0) * k, z
    return pts[-1][1], z


def limb_section(x, z, w, t):
    return [Vector((x + t / 2, w / 2, z)), Vector((x + t / 2, -w / 2, z)), Vector((x - t / 2, -w / 2, z)), Vector((x - t / 2, w / 2, z))]


def bow(kind):
    limbs, siyahs, bands, gilt, bridges = [], [], [], [], []
    tip = None
    for sgn in (1, -1):
        main, horn = [], []
        for i in range(31):
            # 弓臂 24 段、弓弰 6 段，在 u=0.80 共用一圈，接得上
            u = i / 24 * 0.85 if i <= 24 else 0.85 + (i - 24) / 6 * 0.15
            x, z = bow_curve(kind, u)
            w = 0.034 * (1 - 0.45 * u)
            t = 0.030 * (1 - 0.50 * u)   # 照古弓：弓臂侧看厚实
            sec = limb_section(x, sgn * z, w, t)
            if i <= 24:
                main.append(sec)
            if i >= 24:
                horn.append(sec)
        limbs.append(loft(main))
        horn_end = horn[-1]
        siyahs.append(loft(horn))
        x, z = bow_curve(kind, 1.0)
        tip = (x, z)
        # 漆带：弓臂上两道红漆带，各镶两道金线
        for uc in (0.22, 0.55):
            xs, zs = bow_curve(kind, uc)
            w = 0.034 * (1 - 0.45 * uc) * 1.08
            t = 0.030 * (1 - 0.50 * uc) * 1.10
            a = [limb_section(*bow_curve(kind, uc - 0.035), w, t), limb_section(*bow_curve(kind, uc + 0.035), w, t)]
            bands.append(loft([[Vector((p.x, p.y, sgn * p.z)) for p in r] for r in a]))
            for e in (-0.04, 0.04):
                g = [limb_section(*bow_curve(kind, uc + e - 0.004), w * 1.04, t * 1.06),
                     limb_section(*bow_curve(kind, uc + e + 0.004), w * 1.04, t * 1.06)]
                gilt.append(loft([[Vector((p.x, p.y, sgn * p.z)) for p in r] for r in g]))
        # 弦垫：弓弰根上、贴着弦那侧的一小块骨；弓弰尖上一颗骨珠
        xb, zb = bow_curve(kind, 0.86)
        bridges.append(loft([limb_section(xb - 0.011, sgn * (zb - 0.012), 0.022, 0.010),
                             limb_section(xb - 0.011, sgn * (zb + 0.012), 0.022, 0.010)]))
        bridges.append(sphere(Vector((tip[0], 0, sgn * tip[1])), 0.008, 0.008, 0.008, 10, 6))
    riser = loft([limb_section(0.0, -0.075, 0.036, 0.034), limb_section(0.0, 0.075, 0.036, 0.034)])
    pieces = [(merge(riser, *limbs), "wood"), (merge(*siyahs), "cap"), (merge(*bridges), "cap"),
              (merge(*bands), "accent"), (merge(*gilt), "trim")]
    return pieces, tip


chang, tip_c = bow("chang")
obj("bow_limbs_chang", chang)
fanqu, tip_f = bow("fanqu")
obj("bow_limbs_fanqu", fanqu)
# 弓弣：缠绳，上下两道金箍
wrap = []
for k in range(14):
    z = -0.058 + k * 0.009
    wrap.append(loft([limb_section(0.0, z, 0.040, 0.038), limb_section(0.0, z + 0.006, 0.040, 0.038)]))
obj("bow_grip", [(merge(*wrap), "wrap"),
                 (merge(loft([limb_section(0.0, -0.066, 0.042, 0.040), limb_section(0.0, -0.060, 0.042, 0.040)]),
                        loft([limb_section(0.0, 0.066, 0.042, 0.040), limb_section(0.0, 0.072, 0.042, 0.040)])), "trim")])
# 弦：两头搭在弓弰尖上，直直一条
for kind, (tx, tz) in (("chang", tip_c), ("fanqu", tip_f)):
    obj(f"bow_string_{kind}", (loft([ring(-tz, 0.0022, 0.0022, 5, tx), ring(tz, 0.0022, 0.0022, 5, tx)]), "string"))

os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_apply=True, export_animations=False)
if OUT_BLEND:
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
print("WEAPONS", OUT, sorted(o.name for o in bpy.data.objects))
