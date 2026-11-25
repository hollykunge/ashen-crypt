"""皮甲上衣的札甲片、链甲（上衣、袖子、裤子）的锁子环，重做成整齐的花纹。

导出给游戏、出陈列时排在前面跑，只改内存里的材质：
  blender -b gen-out/model/ashen_char_3outfits.blend -P gen-out/model/scripts/detail_armor.py \
          -P gen-out/model/scripts/export_godot.py -- mobile/art/model-hero/hero.glb 1024
想把新材质存进 .blend（要用存这个文件的 Blender 5.3，4.5 打开会丢东西）：
  blender -b gen-out/model/ashen_char_3outfits.blend -P gen-out/model/scripts/detail_armor.py -- save

原来的做法（build_leather.py 的 lamellar、build_chain.py 的 ring_mail）有两个毛病：
- 皮甲：砖块纹贴在按包围盒拉伸、斜着投影的坐标上，甲片绕到侧面就变形、断成乱纹；铆钉是 Voronoi 随机点，满身黄点。
- 链甲：环是三维格子里的一圈圈球壳，身体表面从不同深度切过去，切出大小不一的点和圈，像波点衫。
这里先把每个部件的表面摊成二维坐标（绕身体或四肢的角度 × 沿轴的长度，单位都是米），再在上面画规整的花纹：
- 皮甲：一排排下端圆角的札甲片，上下排错开半片，每片上沿有两个穿绳孔和一道横向编绳，每片颜色略有深浅，
  下沿压暗（被下一排盖住的地方）。
- 链甲：两套错开半格的环套在一起（四套一的样子），每个环上半圈亮、下半圈暗，环间露出深色衬里。
坐标用 Generated（静止姿势的原始网格坐标），导出时按静止姿势烘焙，花纹不会跟着动作游走。
"""
import bpy, sys
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def srgb(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c) + (1.0,)


# 皮甲
LEATHER = srgb("7a2e24")
LEATHER_GAP = srgb("1c0f0c")
CORD = srgb("8a6a44")              # 编绳：浅褐皮绳
COLLAR = srgb("5a2019")            # 领口、肩顶一圈素皮
COLLAR_FROM = 1.47                  # 这个高度以上（米）表面转平，甲片会被拉散，改成素皮
PLATE_W, PLATE_H = 0.034, 0.062   # 一片甲的宽、高（米）
PLATE_GAP, PLATE_ROUND = 0.0022, 0.009
# 链甲
STEEL = srgb("7d848a")
MAIL_GAP = srgb("33363a")
RING = 0.012                       # 环距（米）
RING_ROW = 0.72                    # 行距 / 环距：上下排挤得近一些，环叠着环
RING_TILT = 0.45                   # 环斜着放（弧度），一排排斜环才像锁子甲

# 部件 → 表面怎么摊开：轴上一点、轴向、0° 方向（朝前或朝上）、名义半径、左右是否镜像（两只手臂、两条腿）
# 都是从网格量的：上衣中轴在 y≈0.037；手臂 T 字平伸、轴在 (y 0.063, z 1.441)；腿轴在 x≈±0.089、y≈0.053
SURFACES = {
    "torso": dict(origin=(0.0, 0.037, 0.0), axis=(0, 0, 1), front=(0, -1, 0), radius=0.16, mirror=False),
    "arm": dict(origin=(0.0, 0.063, 1.441), axis=(1, 0, 0), front=(0, 0, 1), radius=0.05, mirror=True),
    "leg": dict(origin=(0.089, 0.053, 0.0), axis=(0, 0, -1), front=(0, -1, 0), radius=0.07, mirror=True),
}


class Graph:
    """节点小帮手：少写几行 nodes.new / links.new"""

    def __init__(self, mat):
        self.nt = mat.node_tree
        self.N, self.L = self.nt.nodes, self.nt.links

    def link(self, src, dst):
        if isinstance(src, (int, float)):
            dst.default_value = src
        elif isinstance(src, tuple):
            dst.default_value = src
        else:
            self.L.new(src, dst)

    def math(self, op, a, b=0.0, c=None):
        n = self.N.new("ShaderNodeMath"); n.operation = op
        self.link(a, n.inputs[0]); self.link(b, n.inputs[1])
        if c is not None:
            self.link(c, n.inputs[2])
        return n.outputs[0]

    def vmath(self, op, a, b=(0.0, 0.0, 0.0), scale=None):
        n = self.N.new("ShaderNodeVectorMath"); n.operation = op
        self.link(a, n.inputs[0])
        if op not in ("ABSOLUTE", "LENGTH", "FRACTION", "FLOOR", "NORMALIZE", "SCALE"):
            self.link(b, n.inputs[1])
        if scale is not None:
            self.link(scale, n.inputs["Scale"])
        return n.outputs["Value"] if op in ("LENGTH", "DOT_PRODUCT") else n.outputs["Vector"]

    def xyz(self, x=0.0, y=0.0, z=0.0):
        n = self.N.new("ShaderNodeCombineXYZ")
        self.link(x, n.inputs[0]); self.link(y, n.inputs[1]); self.link(z, n.inputs[2])
        return n.outputs[0]

    def split(self, v):
        n = self.N.new("ShaderNodeSeparateXYZ"); self.link(v, n.inputs[0])
        return n.outputs[0], n.outputs[1], n.outputs[2]

    def remap(self, v, a, b, c, d):
        n = self.N.new("ShaderNodeMapRange"); n.clamp = True
        self.link(v, n.inputs["Value"])
        n.inputs["From Min"].default_value, n.inputs["From Max"].default_value = a, b
        n.inputs["To Min"].default_value, n.inputs["To Max"].default_value = c, d
        return n.outputs["Result"]

    def mix(self, fac, a, b, blend="MIX"):
        n = self.N.new("ShaderNodeMix"); n.data_type = "RGBA"; n.blend_type = blend; n.clamp_result = True
        ins = [i for i in n.inputs if i.type == "RGBA"]
        self.link(fac, n.inputs[0]); self.link(a, ins[0]); self.link(b, ins[1])
        return next(s for s in n.outputs if s.type == "RGBA")

    def gray(self, value):
        """标量当成灰度颜色（乘到颜色上调明暗）"""
        return self.xyz(value, value, value)


def fresh(name):
    old = bpy.data.materials.get(name)
    if old:
        old.name = name + "_old"
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    return m, p, Graph(m)


def surface(g, obj, kind):
    """部件表面摊成 (u 绕轴弧长, v 沿轴长度)，米"""
    s = SURFACES[kind]
    co = [v.co for v in obj.data.vertices]
    lo = Vector((min(c.x for c in co), min(c.y for c in co), min(c.z for c in co)))
    hi = Vector((max(c.x for c in co), max(c.y for c in co), max(c.z for c in co)))
    tc = g.N.new("ShaderNodeTexCoord")
    mp = g.N.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = hi - lo
    mp.inputs["Location"].default_value = lo
    g.link(tc.outputs["Generated"], mp.inputs["Vector"])
    p = mp.outputs[0]
    if s["mirror"]:
        x, y, z = g.split(p)
        p = g.xyz(g.math("ABSOLUTE", x), y, z)
    axis = Vector(s["axis"]).normalized()
    front = Vector(s["front"]).normalized()
    side = axis.cross(front)
    rel = g.vmath("SUBTRACT", p, tuple(s["origin"]))
    t = g.vmath("DOT_PRODUCT", rel, tuple(axis))
    radial = g.vmath("SUBTRACT", rel, g.vmath("SCALE", tuple(axis), scale=t))
    a = g.vmath("DOT_PRODUCT", radial, tuple(front))
    b = g.vmath("DOT_PRODUCT", radial, tuple(side))
    angle = g.math("ARCTAN2", b, a)
    return g.math("MULTIPLY", angle, s["radius"]), t


def lamellar(obj, kind="torso"):
    m, p, g = fresh("Leather_Lamellar")
    u, v = surface(g, obj, kind)
    rows = g.math("DIVIDE", v, PLATE_H)
    row = g.math("FLOOR", rows)
    fv = g.math("FRACT", rows)
    cols = g.math("ADD", g.math("DIVIDE", u, PLATE_W), g.math("MULTIPLY", row, 0.5))
    col = g.math("FLOOR", cols)
    fu = g.math("FRACT", cols)
    # 圆角矩形的距离场（米，片内为负）
    px = g.math("MULTIPLY", g.math("SUBTRACT", fu, 0.5), PLATE_W)
    py = g.math("MULTIPLY", g.math("SUBTRACT", fv, 0.5), PLATE_H)
    half = (PLATE_W / 2 - PLATE_GAP - PLATE_ROUND, PLATE_H / 2 - PLATE_GAP - PLATE_ROUND, 0.0)
    q = g.vmath("SUBTRACT", g.vmath("ABSOLUTE", g.xyz(px, py)), half)
    qx, qy, _ = g.split(q)
    dist = g.math("SUBTRACT", g.math("ADD", g.vmath("LENGTH", g.vmath("MAXIMUM", q, (0.0, 0.0, 0.0))),
                                     g.math("MINIMUM", g.math("MAXIMUM", qx, qy), 0.0)), PLATE_ROUND)
    inside = g.remap(dist, -0.0006, 0.0006, 1.0, 0.0)
    # 明暗：片沿一圈压暗（显出厚度）、上部被上一排盖着偏暗、每片深浅略不同
    rim = g.remap(dist, -0.0035, -0.0004, 1.0, 0.72)
    slope = g.remap(fv, 0.0, 1.0, 1.06, 0.80)
    noise = g.N.new("ShaderNodeTexWhiteNoise"); noise.noise_dimensions = "2D"
    g.link(g.xyz(col, row), noise.inputs["Vector"])
    jitter = g.remap(noise.outputs["Value"], 0.0, 1.0, 0.88, 1.08)
    shade = g.math("MULTIPLY", g.math("MULTIPLY", rim, slope), jitter)
    plate = g.mix(1.0, LEATHER, g.gray(shade), "MULTIPLY")
    color = g.mix(inside, LEATHER_GAP, plate)
    # 编绳：每片上部一道横向编绳，两头各一个穿绳孔
    cord_band = g.remap(g.math("ABSOLUTE", g.math("SUBTRACT", fv, 0.80)), 0.022, 0.036, 1.0, 0.0)
    cord_span = g.math("MULTIPLY", g.remap(fu, 0.27, 0.31, 0.0, 1.0), g.remap(fu, 0.69, 0.73, 1.0, 0.0))
    cord = g.math("MULTIPLY", g.math("MULTIPLY", cord_band, cord_span), inside)
    color = g.mix(cord, color, CORD)
    for hole_u in (0.27, 0.73):
        dx = g.math("MULTIPLY", g.math("SUBTRACT", fu, hole_u), PLATE_W)
        dy = g.math("MULTIPLY", g.math("SUBTRACT", fv, 0.80), PLATE_H)
        r = g.vmath("LENGTH", g.xyz(dx, dy))
        color = g.mix(g.math("MULTIPLY", g.remap(r, 0.0013, 0.0021, 1.0, 0.0), inside), color, LEATHER_GAP)
    # 领口、肩顶：素皮，带一点皮纹
    grain = g.N.new("ShaderNodeTexNoise"); grain.inputs["Scale"].default_value = 60.0
    plain = g.mix(1.0, COLLAR, g.gray(g.remap(grain.outputs["Fac"], 0.3, 0.7, 0.85, 1.1)), "MULTIPLY")
    color = g.mix(g.remap(v, COLLAR_FROM, COLLAR_FROM + 0.012, 0.0, 1.0), color, plain)
    g.link(color, p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = 0.65
    return m


def ring_mail(obj, kind, name):
    m, p, g = fresh(name)
    u, v = surface(g, obj, kind)
    base = g.xyz(g.math("DIVIDE", u, RING), g.math("DIVIDE", v, RING * RING_ROW))
    import math
    cos_t, sin_t = math.cos(RING_TILT), math.sin(RING_TILT)
    color = MAIL_GAP
    # 两套错开半格的环，后一套压在前一套上；每个环是斜放的椭圆，上沿亮、下沿暗
    for shift, tone in (((0.0, 0.0, 0.0), 0.82), ((0.5, 0.5, 0.0), 1.0)):
        c = g.vmath("SUBTRACT", g.vmath("FRACTION", g.vmath("ADD", base, shift)), (0.5, 0.5, 0.0))
        cx, cy, _ = g.split(c)
        cy = g.math("MULTIPLY", cy, RING_ROW)
        rx = g.math("SUBTRACT", g.math("MULTIPLY", cx, cos_t), g.math("MULTIPLY", cy, sin_t))
        ry = g.math("ADD", g.math("MULTIPLY", cx, sin_t), g.math("MULTIPLY", cy, cos_t))
        e = g.vmath("LENGTH", g.xyz(g.math("DIVIDE", rx, 0.47), g.math("DIVIDE", ry, 0.30)))
        band = g.remap(g.math("ABSOLUTE", g.math("SUBTRACT", e, 0.78)), 0.13, 0.24, 1.0, 0.0)
        light = g.remap(ry, -0.25, 0.25, 0.68 * tone, 1.18 * tone)
        ring = g.mix(1.0, STEEL, g.gray(light), "MULTIPLY")
        color = g.mix(band, color, ring)
    g.link(color, p.inputs["Base Color"])
    p.inputs["Metallic"].default_value = 0.6
    p.inputs["Roughness"].default_value = 0.5
    return m


def assign(obj_name, slot, mat):
    obj = bpy.data.objects[obj_name]
    obj.material_slots[slot].material = mat
    print("DETAIL", obj_name, slot, mat.name)


assign("Leather_Body", 0, lamellar(bpy.data.objects["Leather_Body"]))
assign("Chain_Body", 0, ring_mail(bpy.data.objects["Chain_Body"], "torso", "Chain_Mail_Body"))
assign("Chain_Arms", 0, ring_mail(bpy.data.objects["Chain_Arms"], "arm", "Chain_Mail_Arms"))
assign("Chain_Legs", 0, ring_mail(bpy.data.objects["Chain_Legs"], "leg", "Chain_Mail_Legs"))
for m in list(bpy.data.materials):
    if m.name.endswith("_old") and m.users == 0:
        bpy.data.materials.remove(m)

if argv[:1] == ["save"]:
    bpy.ops.wm.save_mainfile()
    print("SAVED", bpy.data.filepath)
