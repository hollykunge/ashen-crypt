"""把古兵器素材包（60 款古代兵器，3d66 691525）里挑中的刀、剑、枪、弓整件导出给游戏，替换 weapons.glb。

blender -b --factory-startup -P gen-out/model/scripts/import_pack_weapons.py -- <古代兵器.fbx> <out.glb> [贴图边长=512]

素材的授权在项目方手里。每件兵器整件用（贴图照原样），游戏里只换卡通着色和描边，不再按五行上色。
每件处理成和原来零件一样的约定：原点在握点（拳心），+Z 朝刃尖 / 枪头 / 上弓臂，+X 是刀的刃口、弓腹（朝目标）一侧，
Y 是厚度；导出给 Godot 后 +Y 朝尖、+X 朝刃。
- 刀、剑：从下往上找刃根（第一段厚度突然变薄、只剩刃身的地方之下就是格），握点在柄首到格之间、偏格一点。
- 枪：握点在离枪尾三成处。
- 弓：握点在弓弣（上下正中、弦以外的那段）；弓弦拆成单独一件 bow_string_*，拉弓时游戏把它换成跟手的两段。
名字沿用游戏的锻造结果：刀 dao_blade_{jian,qixing,bolang}、剑 sword_blade_{...}、枪 spear_head_{leaf,snake,ji}、
弓 bow_limbs_{chang,fanqu} + bow_string_{chang,fanqu}（model_hero.gd 的 hold 按这些名字挑）。
"""
import bpy, bmesh, sys, os, math
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
SRC = os.path.abspath(argv[0])
OUT = os.path.abspath(argv[1])
TEX = int(argv[2]) if len(argv) > 2 else 512

# 刀的刃口统一朝 +X：游戏里出招打中那一下是零件的 +X 那侧砍在前头（在游戏里量过朝向）。
# 素材里柳叶刀、宽头大刀外鼓的刃口本来就朝 +X；錾花刀的刃（量过最薄的那侧）朝 -X，绕 Z 转半圈
FLIP = {"dao_blade_qixing"}
PICK = {
    "dao_blade_jian": ("yksc_34", "blade", 1.05),     # 柳叶刀
    "dao_blade_qixing": ("yksc_18", "blade", 1.00),   # 錾花刀
    "dao_blade_bolang": ("yksc_55", "blade", 1.10),   # 宽头大刀
    "sword_blade_jian": ("yksc_2", "blade", 1.05),    # 素剑
    "sword_blade_qixing": ("yksc_39", "blade", 1.05), # 圆格花剑
    "sword_blade_bolang": ("yksc_60", "blade", 1.05), # 红柄剑
    "spear_head_leaf": ("yksc_1", "spear", 2.70),     # 黑缨柳叶枪
    "spear_head_snake": ("yksc_62", "spear", 2.70),   # 花枪
    "spear_head_ji": ("yksc_45", "spear", 2.70),      # 月牙戟
    "bow_limbs_chang": ("yksc_15", "bow", 1.40),      # 长弓
    "bow_limbs_fanqu": ("yksc_64", "bow", 1.40),      # 描金反曲弓
}

for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.import_scene.fbx(filepath=SRC)
source = {o.name.split(".")[0]: o for o in bpy.context.scene.objects if o.type == "MESH"}
keep = set()   # 留下的物体名


def world_verts(o):
    return [o.matrix_world @ v.co for v in o.data.vertices]


def apply_transform(o, m):
    """把 m 乘进网格（世界坐标），物体本身归零"""
    o.data.transform(o.matrix_world)
    o.matrix_world = Matrix.Identity(4)
    o.data.transform(m)
    o.data.update()


def bounds(vs):
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    return lo, hi


def axis_at(vs, z, k=30):
    """某个高度上兵器中轴的 x、y：取离这个高度最近的 k 个顶点求平均（低模的柄上顶点稀，按距离挑而不是按切片）"""
    near = sorted(vs, key=lambda v: abs(v.z - z))[:k]
    return sum(v.x for v in near) / len(near), sum(v.y for v in near) / len(near)


def blade_grip_z(vs, lo, hi):
    """从柄首往上扫：柄和首的截面是圆的（宽≈厚），刃（和格）是扁的（宽远大于厚）；
    第一段连着变扁的地方就是格／刃根，握点在柄首到那里的五成五处"""
    n = 120
    step = (hi.z - lo.z) / n
    flat = []
    for i in range(n):
        z0 = lo.z + i * step
        sl = [v for v in vs if z0 <= v.z < z0 + step]
        if len(sl) < 3:
            flat.append(None)
            continue
        w = max(v.x for v in sl) - min(v.x for v in sl)
        t = max(v.y for v in sl) - min(v.y for v in sl)
        flat.append(w / max(t, 1e-4))
    guard = None
    for i in range(int(n * 0.05), int(n * 0.6)):
        run = [f for f in flat[i:i + 3] if f is not None]
        if len(run) == 3 and all(f > 2.2 for f in run):
            guard = lo.z + i * step
            break
    if guard is None:
        guard = lo.z + (hi.z - lo.z) * 0.22
    return lo.z + (guard - lo.z) * 0.55, guard


for name, (src_name, kind, length) in PICK.items():
    o = source[src_name].copy()
    o.data = source[src_name].data.copy()
    bpy.context.scene.collection.objects.link(o)
    vs = world_verts(o)
    lo, hi = bounds(vs)
    # 最薄的水平方向当厚度（Y）：要是 X 更薄，绕 Z 转 90°
    if hi.x - lo.x < hi.y - lo.y:
        c = (lo + hi) / 2
        apply_transform(o, Matrix.Translation(c) @ Matrix.Rotation(math.radians(90), 4, "Z") @ Matrix.Translation(-c))
        vs = world_verts(o)
        lo, hi = bounds(vs)
    scale = length / (hi.z - lo.z)
    c = (lo + hi) / 2
    if kind == "blade":
        gz, guard = blade_grip_z(vs, lo, hi)
        grip = Vector((*axis_at(vs, gz), gz))
    elif kind == "spear":
        gz = lo.z + (hi.z - lo.z) * 0.30
        grip = Vector((*axis_at(vs, gz), gz))
    else:  # bow：弓弣在上下正中、离弦最远的那段
        near = [v for v in vs if abs(v.z - c.z) < (hi.z - lo.z) * 0.04]
        far = max(v.x for v in near)
        riser = [v for v in near if v.x > far - 0.05]
        grip = Vector((sum(v.x for v in riser) / len(riser), sum(v.y for v in riser) / len(riser), c.z))
    turn = Matrix.Rotation(math.pi, 4, "Z") if name in FLIP else Matrix.Identity(4)
    apply_transform(o, Matrix.Scale(scale, 4) @ turn @ Matrix.Translation(-grip))
    o.name = name
    o.data.name = name
    keep.add(name)
    print("PLACED", name, src_name, "scale %.3f" % scale)
    if kind == "bow":
        # 弓弦：拆成散件，又细又竖的那几块就是弦（有的弓弦在正中断开成上下两截），其余并回弓身。
        # 先改个临时名：拆开后原物体可能正好是弦那块，最后的名字要留给并好的弓身
        o.name = "tmp_" + name
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.separate(type="LOOSE")
        bpy.ops.object.mode_set(mode="OBJECT")
        pieces = list(bpy.context.selected_objects)
        strings, limbs = [], []
        for p in pieces:
            lo2, hi2 = bounds(world_verts(p))
            ext = hi2 - lo2
            thin = ext.x < 0.03 and ext.y < 0.03 and ext.z > length * 0.25
            (strings if thin else limbs).append(p)
        # 弦上缠的线箍（有的弓弦正中一小截红箍是单独一块）：整块落在弦那条线上的也算弦，
        # 不然拉弓时弦换成跟手的两段，这一截会悬在原地
        if strings:
            line_x = sum(sum(v.x for v in world_verts(p)) / len(p.data.vertices) for p in strings) / len(strings)
            for p in list(limbs):
                lo2, hi2 = bounds(world_verts(p))
                if lo2.x > line_x - 0.02 and hi2.x < line_x + 0.02 and hi2.y - lo2.y < 0.03 and hi2.z - lo2.z < length * 0.25:
                    limbs.remove(p)
                    strings.append(p)

        def join(parts, new_name):
            bpy.ops.object.select_all(action="DESELECT")
            for p in parts:
                p.select_set(True)
            bpy.context.view_layer.objects.active = parts[0]
            if len(parts) > 1:
                bpy.ops.object.join()
            joined = bpy.context.view_layer.objects.active
            joined.name = new_name
            joined.data.name = new_name
            return joined

        keep.discard(name)
        keep.add(join(limbs, name).name)
        variant = name.split("_")[-1]
        span = sum((bounds(world_verts(p))[1] - bounds(world_verts(p))[0]).z for p in strings)
        if strings and span > length * 0.7:
            string = join(strings, f"bow_string_{variant}")
            keep.add(string.name)
            lo2, hi2 = bounds(world_verts(string))
            print("STRING", string.name, len(strings), "pieces", [round(x, 3) for x in hi2 - lo2])
        else:
            print("NO STRING FOUND for", name)
            if strings:
                keep.discard(name)
                keep.add(join(limbs + strings, name).name)

for o in list(bpy.context.scene.objects):
    if o.name not in keep:
        bpy.data.objects.remove(o, do_unlink=True)
keep = [bpy.data.objects[n] for n in sorted(keep)]
for o in keep:
    o.matrix_world = Matrix.Identity(4)
    for poly in o.data.polygons:
        poly.use_smooth = True
# 贴图缩到 TEX 见方（手机上兵器只有一两百像素）
for img in bpy.data.images:
    if img.users and img.size[0] > TEX:
        img.scale(TEX, int(TEX * img.size[1] / img.size[0]))
        print("TEX", img.name, img.size[:])

bpy.ops.object.select_all(action="DESELECT")
for o in keep:
    o.select_set(True)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_apply=True,
                          export_animations=False, export_image_format="AUTO")
print("WEAPONS", OUT, sorted(o.name for o in keep), os.path.getsize(OUT) // 1024, "KB")
