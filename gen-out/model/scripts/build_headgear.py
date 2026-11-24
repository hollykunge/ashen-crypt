"""Chinese headgear for the hero, one per armour type (the hair is hidden under it, except below the rim).

blender -b ashen_char_3outfits.blend -P build_headgear.py -- [out.blend]   (no out -> save in place; re-running rebuilds)

  斗笠    Head_Hat          cloth (布衣 / no armour): woven bamboo hat on an inner band, cords tied under the chin
  皮兜鍪  Head_Helm_Leather leather (皮甲): segmented red leather dome, dark brow band, brass knob, leather 顿项
  铁兜鍪  Head_Helm_Iron    chain (链甲): slightly pointed iron dome, brow rim, brass finial with a red 盔缨, mail 顿项
Each piece is one object (several material slots), weighted 100% to the Head bone so it stays rigid.
The domes are shaped from the head itself: the scalp of Head_Skin (faces above a brow line) is pushed out, smoothed
round and given a little thickness, so they sit on the head whatever the hair does. The 顿项 (neck/ear guard) is a
skirt round the sides and back, hanging from the dome's lower edge and flaring a little.
Materials reuse the outfit's own: Leather_Pauldron_Mat, Chain_Steel_Plate, a copy of the chain mail (rings re-scaled
for this mesh); the cloth is new. Slot "headgear" in render_lib.SLOTS / model_hero.gd.
"""
import bpy, bmesh, sys, math
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else bpy.data.filepath
rig = bpy.data.objects["Rig"]
col = bpy.data.collections["Parts"]
NAMES = ("Head_Hat", "Head_Wrap", "Head_Helm_Leather", "Head_Helm_Iron")
for n in NAMES:
    if n in bpy.data.objects:
        bpy.data.objects.remove(bpy.data.objects[n], do_unlink=True)


def srgb(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c) + (1.0,)


def principled(name, replace=True):
    m = bpy.data.materials.get(name)
    if m and replace:
        bpy.data.materials.remove(m)
        m = None
    m = m or bpy.data.materials.new(name)
    m.use_nodes = True
    return m, next(n for n in m.node_tree.nodes if n.bl_idname == "ShaderNodeBsdfPrincipled")


def flat(name, hexcol, rough=0.8, metal=0.0):
    m, p = principled(name)
    p.inputs["Base Color"].default_value = srgb(hexcol)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    return m


def cloth(name, base, dark):
    """Plain woven cloth with soft fold streaks."""
    m, p = principled(name)
    N, L = m.node_tree.nodes, m.node_tree.links
    tc = N.new("ShaderNodeTexCoord")
    wave = N.new("ShaderNodeTexWave"); wave.inputs["Scale"].default_value = 4; wave.inputs["Distortion"].default_value = 2
    L.new(tc.outputs["Generated"], wave.inputs["Vector"])
    ramp = N.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = srgb(dark); ramp.color_ramp.elements[1].color = srgb(base)
    L.new(wave.outputs["Fac"], ramp.inputs["Fac"]); L.new(ramp.outputs["Color"], p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = 0.9
    return m


def segmented(name, src):
    """Copy of an outfit material with darker vertical seams every few centimetres (helmet made of strips)."""
    m = bpy.data.materials[src].copy()
    old = bpy.data.materials.get(name)
    if old:
        bpy.data.materials.remove(old)
    m.name = name
    N, L = m.node_tree.nodes, m.node_tree.links
    p = next(n for n in N if n.bl_idname == "ShaderNodeBsdfPrincipled")
    base = p.inputs["Base Color"].links[0].from_socket
    tc = N.new("ShaderNodeTexCoord")
    sep = N.new("ShaderNodeSeparateXYZ"); L.new(tc.outputs["Object"], sep.inputs[0])
    ang = N.new("ShaderNodeMath"); ang.operation = "ARCTAN2"
    L.new(sep.outputs["X"], ang.inputs[0]); L.new(sep.outputs["Y"], ang.inputs[1])
    strips = N.new("ShaderNodeMath"); strips.operation = "MULTIPLY"; strips.inputs[1].default_value = 8 / math.pi
    L.new(ang.outputs[0], strips.inputs[0])
    fr = N.new("ShaderNodeMath"); fr.operation = "FRACT"; L.new(strips.outputs[0], fr.inputs[0])
    seam = N.new("ShaderNodeMapRange")
    seam.inputs["From Min"].default_value = 0.0; seam.inputs["From Max"].default_value = 0.12
    seam.inputs["To Min"].default_value = 0.45; seam.inputs["To Max"].default_value = 1.0
    L.new(fr.outputs[0], seam.inputs["Value"])
    mul = N.new("ShaderNodeMix"); mul.data_type = "RGBA"; mul.blend_type = "MULTIPLY"; mul.inputs[0].default_value = 1.0
    ins = [i for i in mul.inputs if i.type == "RGBA"]
    L.new(base, ins[0]); L.new(seam.outputs["Result"], ins[1])
    L.new(next(s for s in mul.outputs if s.type == "RGBA"), p.inputs["Base Color"])
    return m


def mail_for(name, dims):
    """The chain mail material with its ring spacing re-scaled for a mesh of these dimensions."""
    m = bpy.data.materials["Chain_Mail_Body"].copy()
    old = bpy.data.materials.get(name)
    if old:
        bpy.data.materials.remove(old)
    m.name = name
    mp = next(n for n in m.node_tree.nodes if n.bl_idname == "ShaderNodeMapping")
    mp.inputs["Scale"].default_value = dims / 0.016
    return m


# ------------------------------------------------------------------ geometry helpers
def ang_of(p):
    return math.atan2(p.x - AXIS.x, -(p.y - AXIS.y))   # 0 = face (-Y), +-pi = back


def head_fit():
    """Ellipsoid (centre, radii) that just contains the skull and the hair above ear level."""
    pts = [v.co for v in bpy.data.objects["Head_Skin"].data.vertices if v.co.z > 1.66]
    pts += [v.co for v in bpy.data.objects["Head_Hair_Main"].data.vertices]
    ys = [p.y for p in pts]
    c = Vector((0.0, (min(ys) + max(ys)) / 2, 1.70))
    r0 = Vector((max(abs(p.x) for p in pts), (max(ys) - min(ys)) / 2, max(p.z for p in pts) - c.z))
    k = max(math.sqrt(((p.x - c.x) / r0.x) ** 2 + ((p.y - c.y) / r0.y) ** 2 + ((p.z - c.z) / r0.z) ** 2)
            for p in pts if p.z > c.z - 0.02)
    return c, r0 * k


CENTER, RADII = head_fit()
AXIS = Vector((CENTER.x, CENTER.y, 0.0))


def dome(offset, rim_front, rim_back, peak=0.0, n_phi=48, n_th=12):
    """A smooth dome over the head: the fitted ellipsoid grown by `offset`, cut at a brow line that runs from
    rim_front (forehead) down to rim_back (nape). Returns (bmesh, rim) with rim = [(angle, radius, z)] of the open edge."""
    r = RADII + Vector((offset, offset, offset))
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    top = bm.verts.new(CENTER + Vector((0, 0, r.z + peak)))
    rows, rim = [], []
    for i in range(n_phi):
        phi = -math.pi + 2 * math.pi * i / n_phi            # 0 = face, +-pi = back
        back = (1 - math.cos(phi)) / 2
        z_rim = rim_front + (rim_back - rim_front) * back * back * (3 - 2 * back)
        th_max = math.acos(max(-0.95, min(0.95, (z_rim - CENTER.z) / r.z)))
        col_ = []
        for j in range(1, n_th + 1):
            th = th_max * j / n_th
            p = CENTER + Vector((r.x * math.sin(th) * math.sin(phi), -r.y * math.sin(th) * math.cos(phi), r.z * math.cos(th)))
            p.z += peak * math.cos(th) ** 6                  # pointed crown
            col_.append(bm.verts.new(p))
        rows.append(col_)
        e = col_[-1].co
        rim.append((phi, Vector((e.x - AXIS.x, e.y - AXIS.y)).length, e.z))
    for i in range(n_phi):
        a, b = rows[i], rows[(i + 1) % n_phi]
        f = bm.faces.new((top, b[0], a[0]))
        for lp, (u, v) in zip(f.loops, ((0.5, 0), ((i + 1) / n_phi, 1 / n_th), (i / n_phi, 1 / n_th))):
            lp[uv].uv = (u, v)
        for j in range(n_th - 1):
            f = bm.faces.new((a[j], b[j], b[j + 1], a[j + 1]))
            for lp, (u, v) in zip(f.loops, ((i / n_phi, (j + 1) / n_th), ((i + 1) / n_phi, (j + 1) / n_th),
                                            ((i + 1) / n_phi, (j + 2) / n_th), (i / n_phi, (j + 2) / n_th))):
                lp[uv].uv = (u, v)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.003)
    return bm, rim


def ring_pt(a, r, z):
    return Vector((AXIS.x + r * math.sin(a), AXIS.y - r * math.cos(a), z))


def band(bm, uv, rim, height, out, mat_index, closed=True):
    """A band hugging the dome's lower edge (brow band / rim)."""
    rows = [[bm.verts.new(ring_pt(a, r + out, z + dz)) for a, r, z in rim] for dz in (-0.004, height)]
    rows_out = [[bm.verts.new(ring_pt(a, r + out + 0.004, z + dz)) for a, r, z in rim] for dz in (-0.004, height)]
    n = len(rim)
    faces = []
    for ring_a, ring_b in ((rows[0], rows[1]), (rows_out[0], rows_out[1]), (rows[0], rows_out[0]), (rows[1], rows_out[1])):
        for i in range(n if closed else n - 1):
            faces.append(bm.faces.new((ring_a[i], ring_a[(i + 1) % n], ring_b[(i + 1) % n], ring_b[i])))
    for i, f in enumerate(faces):
        f.material_index = mat_index
        for lp, (u, v) in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
            lp[uv].uv = ((i % n + u) / n, v * 0.25)


def skirt(bm, uv, rim, length, flare, from_deg, mat_index, rows=5):
    """顿项: hangs from the rim round the sides and back (|angle| > from_deg), flaring out."""
    part = [s for s in rim if abs(math.degrees(s[0])) >= from_deg]
    part.sort(key=lambda s: (s[0] % (2 * math.pi)))
    grid = []
    for k in range(rows + 1):
        t = k / rows
        grid.append([bm.verts.new(ring_pt(a, r + 0.004 + flare * t, z - 0.002 - length * t)) for a, r, z in part])
    for k in range(rows):
        for i in range(len(part) - 1):
            f = bm.faces.new((grid[k][i], grid[k][i + 1], grid[k + 1][i + 1], grid[k + 1][i]))
            f.material_index = mat_index
            for lp, (u, v) in zip(f.loops, ((i, k), (i + 1, k), (i + 1, k + 1), (i, k + 1))):
                lp[uv].uv = (u / len(part), v / rows)
    bmesh.ops.solidify(bm, geom=[f for f in bm.faces if f.material_index == mat_index], thickness=0.003)


def blob(bm, uv, c, r, mat_index, seg=10, rings=6):
    rows = []
    for i in range(rings + 1):
        th = math.pi * i / rings
        rows.append([bm.verts.new(c + Vector((r.x * math.sin(th) * math.cos(2 * math.pi * j / seg),
                                              r.y * math.sin(th) * math.sin(2 * math.pi * j / seg), r.z * math.cos(th))))
                     for j in range(seg)])
    for i in range(rings):
        for j in range(seg):
            f = bm.faces.new((rows[i][j], rows[i][(j + 1) % seg], rows[i + 1][(j + 1) % seg], rows[i + 1][j]))
            f.material_index = mat_index
            for lp, (u, v) in zip(f.loops, ((j / seg, i / rings), ((j + 1) / seg, i / rings),
                                            ((j + 1) / seg, (i + 1) / rings), (j / seg, (i + 1) / rings))):
                lp[uv].uv = (u, v)


def strands(bm, uv, top, ends, width, mat_index):
    """Flat ribbons / tassel strands from `top` to each end point."""
    for e in ends:
        d = (e - top).normalized()
        s = d.cross(Vector((1, 0, 0))).normalized() * width
        if s.length < 1e-5:
            s = Vector((0, width, 0))
        a, b, c, dd = (bm.verts.new(top - s), bm.verts.new(top + s), bm.verts.new(e + s * 0.6), bm.verts.new(e - s * 0.6))
        f = bm.faces.new((a, b, c, dd)); f.material_index = mat_index
        for lp, (u, v) in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
            lp[uv].uv = (u, v)
    bmesh.ops.solidify(bm, geom=[f for f in bm.faces if f.material_index == mat_index and len(f.verts) == 4], thickness=0.002)


def make(name, bm, mats):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    for p in me.polygons:
        p.use_smooth = True
    for m in mats:
        me.materials.append(m)
    o = bpy.data.objects.new(name, me)
    col.objects.link(o)
    o.parent = rig
    o.vertex_groups.new(name="Head").add(list(range(len(me.vertices))), 1.0, "REPLACE")
    o.modifiers.new("Armature", "ARMATURE").object = rig
    return o


def uv_layer(bm):
    return bm.loops.layers.uv.get("UVMap") or bm.loops.layers.uv.verify()


def dims_of(bm):
    xs = [v.co.x for v in bm.verts]; ys = [v.co.y for v in bm.verts]; zs = [v.co.z for v in bm.verts]
    return Vector((max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)))


BRASS = flat("Head_Helm_Brass", "b08a4a", 0.4, 0.8)

def straw(name):
    """Woven bamboo / straw: radial ribs and concentric rings, in object coordinates round the hat's axis."""
    m, p = principled(name)
    N, L = m.node_tree.nodes, m.node_tree.links
    tc = N.new("ShaderNodeTexCoord")
    sep = N.new("ShaderNodeSeparateXYZ"); L.new(tc.outputs["Object"], sep.inputs[0])
    ang = N.new("ShaderNodeMath"); ang.operation = "ARCTAN2"
    L.new(sep.outputs["X"], ang.inputs[0]); L.new(sep.outputs["Y"], ang.inputs[1])
    ribs = N.new("ShaderNodeMath"); ribs.operation = "MULTIPLY"; ribs.inputs[1].default_value = 36 / math.pi
    L.new(ang.outputs[0], ribs.inputs[0])
    rf = N.new("ShaderNodeMath"); rf.operation = "FRACT"; L.new(ribs.outputs[0], rf.inputs[0])
    rad = N.new("ShaderNodeVectorMath"); rad.operation = "LENGTH"
    xy = N.new("ShaderNodeCombineXYZ"); L.new(sep.outputs["X"], xy.inputs["X"]); L.new(sep.outputs["Y"], xy.inputs["Y"])
    L.new(xy.outputs[0], rad.inputs[0])
    rings = N.new("ShaderNodeMath"); rings.operation = "MULTIPLY"; rings.inputs[1].default_value = 90
    L.new(rad.outputs["Value"], rings.inputs[0])
    gf = N.new("ShaderNodeMath"); gf.operation = "FRACT"; L.new(rings.outputs[0], gf.inputs[0])
    weave = N.new("ShaderNodeMath"); weave.operation = "MINIMUM"
    L.new(rf.outputs[0], weave.inputs[0]); L.new(gf.outputs[0], weave.inputs[1])
    shade = N.new("ShaderNodeMapRange")
    shade.inputs["From Min"].default_value = 0.0; shade.inputs["From Max"].default_value = 0.15
    shade.inputs["To Min"].default_value = 0.62; shade.inputs["To Max"].default_value = 1.0
    L.new(weave.outputs[0], shade.inputs["Value"])
    mul = N.new("ShaderNodeMix"); mul.data_type = "RGBA"; mul.blend_type = "MULTIPLY"; mul.inputs[0].default_value = 1.0
    ins = [i for i in mul.inputs if i.type == "RGBA"]
    ins[0].default_value = srgb("b39a64")
    L.new(shade.outputs["Result"], ins[1])
    L.new(next(s for s in mul.outputs if s.type == "RGBA"), p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = 0.9
    return m


def cone_hat(bm, uv, apex, brim_r, brim_z, seg=48, rings=8):
    """斗笠: a shallow cone from the apex down to the brim, plus a turned-down rim at the edge."""
    pts = []
    for k in range(1, rings + 1):
        t = k / rings
        r = brim_r * t
        z = apex.z + (brim_z - apex.z) * t
        pts.append([bm.verts.new(Vector((AXIS.x + r * math.sin(2 * math.pi * i / seg), AXIS.y - r * math.cos(2 * math.pi * i / seg), z)))
                    for i in range(seg)])
    lip = [bm.verts.new(v.co + Vector((0, 0, -0.012))) for v in pts[-1]]
    pts.append(lip)
    top = bm.verts.new(apex)
    for i in range(seg):
        f = bm.faces.new((top, pts[0][(i + 1) % seg], pts[0][i]))
        for lp, (u, v) in zip(f.loops, ((0.5, 0), ((i + 1) / seg, 0.1), (i / seg, 0.1))):
            lp[uv].uv = (u, v)
    for k in range(len(pts) - 1):
        for i in range(seg):
            f = bm.faces.new((pts[k][i], pts[k][(i + 1) % seg], pts[k + 1][(i + 1) % seg], pts[k + 1][i]))
            f.material_index = 1 if k == len(pts) - 2 else 0
            for lp, (u, v) in zip(f.loops, ((i / seg, k / len(pts)), ((i + 1) / seg, k / len(pts)),
                                            ((i + 1) / seg, (k + 1) / len(pts)), (i / seg, (k + 1) / len(pts)))):
                lp[uv].uv = (u, v)
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.004)


# ------------------------------------------------------------------ 斗笠
bm = bmesh.new()
uv = bm.loops.layers.uv.new("UVMap")
crown = CENTER.z + RADII.z
apex = Vector((AXIS.x, AXIS.y, crown + 0.075))
brim_z = crown - 0.055
cone_hat(bm, uv, apex, 0.23, brim_z)
# 内圈：帽子靠一圈篾箍坐在头上（从帽底接到头顶，侧面看帽子不悬空）
inner = [(math.radians(a), 0, 0) for a in range(-180, 180, 10)]


def under_cone(a):
    """A point of the oval inner band at angle a, tucked just under the cone (cone height depends on the radius)."""
    x, y = (RADII.x + 0.006) * math.sin(a), (RADII.y + 0.006) * math.cos(a)
    r = math.hypot(x, y)
    return Vector((AXIS.x + x, AXIS.y - y, apex.z + (brim_z - apex.z) * r / 0.23 - 0.01))


ring_top = [bm.verts.new(under_cone(a)) for a, _, _ in inner]
ring_bot = [bm.verts.new(v.co + Vector((0, 0, -0.035))) for v in ring_top]
for i in range(len(inner)):
    j = (i + 1) % len(inner)
    f = bm.faces.new((ring_top[i], ring_top[j], ring_bot[j], ring_bot[i])); f.material_index = 1
    for lp, (u, v) in zip(f.loops, ((i / 36, 0), ((i + 1) / 36, 0), ((i + 1) / 36, 1), (i / 36, 1))):
        lp[uv].uv = (u, v)
# 系带：从帽圈两侧（耳前）到下巴
chin = Vector((0.0, CENTER.y - RADII.y + 0.02, 1.565))
for sx in (1, -1):
    s = Vector((sx * (RADII.x + 0.004), CENTER.y - 0.01, crown - 0.11))
    strands(bm, uv, s, [chin + Vector((sx * 0.012, 0, 0))], 0.0035, 2)
make("Head_Hat", bm, [straw("Head_Hat_Straw"), flat("Head_Hat_Binding", "4a3524"), flat("Head_Hat_Cord", "2c2420")])

# ------------------------------------------------------------------ 皮兜鍪
bm, rim = dome(0.014, 1.738, 1.672, peak=0.01)
uv = uv_layer(bm)
for f in bm.faces:
    f.material_index = 0
band(bm, uv, rim, 0.02, 0.002, 1)
skirt(bm, uv, rim, 0.085, 0.022, 70, 2)
top = max(bm.verts, key=lambda v: v.co.z).co
blob(bm, uv, top + Vector((0, 0, 0.006)), Vector((0.011, 0.011, 0.012)), 3)
make("Head_Helm_Leather", bm, [segmented("Head_Helm_Leather_Dome", "Leather_Pauldron_Mat"),
                               flat("Head_Helm_Band_Dark", "2e211b"),
                               segmented("Head_Helm_Leather_Neck", "Leather_Pauldron_Mat"),
                               BRASS])

# ------------------------------------------------------------------ 铁兜鍪
bm, rim = dome(0.016, 1.735, 1.672, peak=0.035)
uv = uv_layer(bm)
for f in bm.faces:
    f.material_index = 0
band(bm, uv, rim, 0.018, 0.003, 1)
skirt(bm, uv, rim, 0.10, 0.026, 60, 2)
top = max(bm.verts, key=lambda v: v.co.z).co
blob(bm, uv, top + Vector((0, 0, 0.022)), Vector((0.008, 0.008, 0.03)), 3)        # finial
tassel_top = top + Vector((0, 0, 0.05))
strands(bm, uv, tassel_top, [tassel_top + Vector((0.058 * math.sin(a), 0.058 * math.cos(a) + 0.02, -0.055 - 0.02 * math.cos(a)))
                             for a in [2 * math.pi * k / 14 for k in range(14)]], 0.009, 4)
neck_dims = dims_of(bm)   # Generated coords span the whole object: rings sized for it
make("Head_Helm_Iron", bm, [bpy.data.materials["Chain_Steel_Plate"], flat("Head_Helm_Iron_Rim", "5a5f64", 0.4, 0.8),
                            mail_for("Head_Helm_Mail", neck_dims), BRASS,
                            flat("Head_Helm_Tassel", "a82a1e")])

print("HEADGEAR", list(NAMES))
bpy.ops.wm.save_as_mainfile(filepath=OUT, relative_remap=True)
print("SAVED", OUT)
