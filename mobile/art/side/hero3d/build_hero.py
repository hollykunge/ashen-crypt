# 3D 渲 2D：把设定图侧面像切出的零件（cut_parts.py → parts/、parts.json）挂到一套侧视骨骼上，
# 写三段动作，从侧面正交渲成逐帧图。画上的褶皱、脸、绑腿都跟着骨头动，换装照样按分区染。
# 每帧出三样东西：
#   color/<动作>_<帧>.png   原画配色的画面
#   ids/<动作>_<帧>.png     染色分区：袍裤红、镶边腰带绿、护腕蓝、靴黄、符牌品红，其余黑
#   grips.json              每帧右手握点和剑尖在图上的像素坐标
# 用法：blender -b -P build_hero.py -- <输出目录>
#
# 骨骼只在侧视平面里转（绕世界 Y 轴），所以每根骨头只有一个角度：
#   对朝下的骨头（四肢）角度为负 = 往前摆；膝盖往后弯是正，肘往前弯是负。
#   对朝上的骨头（脊柱、头）角度为正 = 往前倾。
# 零件是贴着原画的薄片，前后由 parts.json 的 depth 排：近侧胳膊最前，远侧胳膊在身子后面。
# 剑是真 3D 的，挂在右手骨头上。

import bpy
import json
import math
import os
import sys
from mathutils import Matrix, Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "/tmp/hero3d"
SIZE = 384
ORTHO = 3.2
CAMERA_X = 0.25
GROUND_PIXEL = 352
CAMERA_Z = (GROUND_PIXEL - SIZE / 2) / SIZE * ORTHO
FPS = 24

with open(os.path.join(HERE, "parts.json")) as handle:
    PARTS = json.load(handle)

# ── 比例：设定图的头只有身高的十分之一（十头身的时装画比例），游戏里显得头小。
# 按正常成年人修到约七头半：头绕脖子放大，腿和胳膊只微收（原画腿长本来就占身高一半，是正常的），
# 袍摆跟着略收。最后整体等比缩放，头顶回到原来的高度。改完会打印头身比和腿长占比核对。
HEAD_SCALE = 1.4
LEG_SCALE = 0.93
ARM_SCALE = 0.97
ROBE_SCALE = 0.95
# 设定图上量的：头顶（不算发髻）和下巴的高度，单位米。
CROWN_Z = (988 - 50) * 0.00205
CHIN_Z = (988 - 140) * 0.00205


def reproportion(data):
    bones = data["bones"]
    neck = bones["head"][0]
    shoulder = bones["upper_arm"][0]
    hip_z = bones["thigh"][0][1]
    ankle_z = bones["shin"][1][1]
    sash_z = 1.21

    def leg(point):
        x, z = point
        if z >= hip_z:
            return [x, z]
        if z >= ankle_z:
            return [x, hip_z - (hip_z - z) * LEG_SCALE]
        return [x, hip_z - (hip_z - ankle_z) * LEG_SCALE - (ankle_z - z)]

    def about(center, k):
        return lambda point: [center[0] + (point[0] - center[0]) * k, center[1] + (point[1] - center[1]) * k]

    foot_shift = leg([0, ankle_z])[1] - ankle_z
    maps = {
        "head": about(neck, HEAD_SCALE),
        "arm": about(shoulder, ARM_SCALE),
        "leg": leg,
        "foot": lambda point: [point[0], point[1] + foot_shift],
        "robe": lambda point: [point[0], point[1] if point[1] >= sash_z else sash_z - (sash_z - point[1]) * ROBE_SCALE],
        "body": lambda point: list(point),
    }
    segment = {"head": "head", "upper_arm": "arm", "forearm": "arm", "hand": "arm", "thigh": "leg", "shin": "leg",
               "foot": "foot", "skirt": "robe"}

    def segment_of(bone):
        return segment.get(bone.split(".")[0], "body")

    for name in list(bones):
        bones[name] = [maps[segment_of(name)](point) for point in bones[name]]
    for part in data["parts"]:
        remap = maps[segment_of(part["bone"])]
        corner_a, corner_b = remap(part["min"]), remap(part["max"])
        part["min"] = [min(corner_a[0], corner_b[0]), min(corner_a[1], corner_b[1])]
        part["max"] = [max(corner_a[0], corner_b[0]), max(corner_a[1], corner_b[1])]
    data["grip"] = maps["arm"](data["grip"])
    # 脚底回到地面，再等比放大到原来的头顶高度。
    ground = foot_shift
    crown_before = max(part["max"][1] for part in data["parts"] if part["bone"] == "head")
    for name in bones:
        bones[name] = [[x, z - ground] for x, z in bones[name]]
    for part in data["parts"]:
        part["min"][1] -= ground
        part["max"][1] -= ground
    data["grip"] = [data["grip"][0], data["grip"][1] - ground]
    crown = max(part["max"][1] for part in data["parts"] if part["bone"] == "head")
    target = 2.0
    k = target / crown
    for name in bones:
        bones[name] = [[x * k, z * k] for x, z in bones[name]]
    for part in data["parts"]:
        part["min"] = [v * k for v in part["min"]]
        part["max"] = [v * k for v in part["max"]]
    data["grip"] = [v * k for v in data["grip"]]
    data["skirt_top"] = (sash_z - ground) * k
    head_map = maps["head"]
    crown_z = (head_map([0, CROWN_Z])[1] - ground) * k
    chin_z = (head_map([0, CHIN_Z])[1] - ground) * k
    hip_z = bones["thigh"][0][1]
    print("reproportion: %.2f heads tall, legs %.0f%% of height, scale %.3f"
          % (crown_z / (crown_z - chin_z), 100 * hip_z / crown_z, k))


reproportion(PARTS)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.eevee.taa_render_samples = 32
    scene.render.resolution_x = SIZE
    scene.render.resolution_y = SIZE
    scene.render.film_transparent = True
    scene.render.fps = FPS
    scene.view_settings.view_transform = "Standard"
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.25, 0.25, 0.27, 1)
    scene.world = world
    return scene


# ── 材质 ──────────────────────────────────────────────────────────────

def painted(name, color_path, id_path):
    """原画零件：贴图直接当自发光输出（明暗已经画在图上），透明处用贴图的 alpha 抠掉。
    同一个材质里放两张图，渲分区那一遍把输出换成分区图。"""
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()
    color = nodes.new("ShaderNodeTexImage")
    color.image = bpy.data.images.load(color_path)
    color.interpolation = "Cubic"
    color.extension = "CLIP"
    zone = nodes.new("ShaderNodeTexImage")
    zone.image = bpy.data.images.load(id_path)
    zone.interpolation = "Closest"
    zone.extension = "CLIP"
    pick = nodes.new("ShaderNodeMix")
    pick.data_type = "RGBA"
    pick.name = "Pick"
    pick.inputs[0].default_value = 0.0
    links.new(color.outputs["Color"], pick.inputs[6])
    links.new(zone.outputs["Color"], pick.inputs[7])
    glow = nodes.new("ShaderNodeEmission")
    links.new(pick.outputs[2], glow.inputs[0])
    clear = nodes.new("ShaderNodeBsdfTransparent")
    mix = nodes.new("ShaderNodeMixShader")
    links.new(color.outputs["Alpha"], mix.inputs[0])
    links.new(clear.outputs[0], mix.inputs[1])
    links.new(glow.outputs[0], mix.inputs[2])
    out = nodes.new("ShaderNodeOutputMaterial")
    links.new(mix.outputs[0], out.inputs[0])
    return material


def toon(name, color):
    """剑用的三档卡通明暗。"""
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()
    diffuse = nodes.new("ShaderNodeBsdfDiffuse")
    to_rgb = nodes.new("ShaderNodeShaderToRGB")
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    stops = ramp.color_ramp.elements
    stops[0].color = (0.45, 0.45, 0.48, 1)
    stops[1].position = 0.2
    stops[1].color = (0.75, 0.74, 0.72, 1)
    stops.new(0.6).color = (1.0, 0.98, 0.94, 1)
    tint = nodes.new("ShaderNodeVectorMath")
    tint.operation = "MULTIPLY"
    tint.inputs[1].default_value = color
    glow = nodes.new("ShaderNodeEmission")
    out = nodes.new("ShaderNodeOutputMaterial")
    links.new(diffuse.outputs[0], to_rgb.inputs[0])
    links.new(to_rgb.outputs[0], ramp.inputs[0])
    links.new(ramp.outputs[0], tint.inputs[0])
    links.new(tint.outputs[0], glow.inputs[0])
    links.new(glow.outputs[0], out.inputs[0])
    return material


def flat(name, color):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    nodes.clear()
    glow = nodes.new("ShaderNodeEmission")
    glow.inputs[0].default_value = (*color, 1)
    out = nodes.new("ShaderNodeOutputMaterial")
    material.node_tree.links.new(glow.outputs[0], out.inputs[0])
    return material


# ── 骨骼：位置取自 parts.json（设定图上量的关节），左右两侧同一套，只差前后 ────────────

def bone_points(name):
    (hx, hz), (tx, tz) = PARTS["bones"][name]
    return (hx, hz), (tx, tz)


def build_rig(scene):
    data = bpy.data.armatures.new("Rig")
    rig = bpy.data.objects.new("Rig", data)
    scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")

    def add(name, head, tail, parent, y=0.0):
        bone = data.edit_bones.new(name)
        bone.head = (head[0], y, head[1])
        bone.tail = (tail[0], y, tail[1])
        if parent:
            bone.parent = data.edit_bones[parent]

    add("root", (0, 0), (0, 0.2), None)
    for name, parent in (("hips", "root"), ("spine", "hips"), ("chest", "spine"), ("neck", "chest"), ("head", "neck")):
        add(name, *bone_points(name), parent)
    # 袍子挂在腰带上，跟着往前那条腿摆一点（skirt 不在原画骨头表里，从腰带垂到下摆）。
    hip_x = PARTS["bones"]["hips"][0][0]
    add("skirt", (hip_x, PARTS["skirt_top"]), (hip_x, PARTS["skirt_top"] * 0.4), "hips")
    for side, y in (("R", -0.3), ("L", 0.3)):
        add("upper_arm." + side, *bone_points("upper_arm"), "chest", y)
        add("forearm." + side, *bone_points("forearm"), "upper_arm." + side, y)
        add("hand." + side, *bone_points("hand"), "forearm." + side, y)
        add("thigh." + side, *bone_points("thigh"), "hips", y * 0.4)
        add("shin." + side, *bone_points("shin"), "thigh." + side, y * 0.4)
        add("foot." + side, *bone_points("foot"), "shin." + side, y * 0.4)
    bpy.ops.object.mode_set(mode="OBJECT")
    for bone in rig.pose.bones:
        bone.rotation_mode = "QUATERNION"
    return rig


SHAPES = []


def attach(obj, rig, bone):
    world = obj.matrix_world.copy()
    obj.parent = rig
    obj.parent_type = "BONE"
    obj.parent_bone = bone
    bpy.context.view_layer.update()
    obj.matrix_world = world


def card(part, rig):
    """一块零件：贴着原画位置的一张薄片，UV 正好铺满零件图。"""
    (x0, z0), (x1, z1) = part["min"], part["max"]
    y = part["depth"]
    mesh = bpy.data.meshes.new(part["name"])
    mesh.from_pydata([(x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1)], [], [(0, 1, 2, 3)])
    uv = mesh.uv_layers.new()
    for loop, coord in zip(mesh.loops, [(0, 0), (1, 0), (1, 1), (0, 1)]):
        uv.data[loop.index].uv = coord
    obj = bpy.data.objects.new(part["name"], mesh)
    bpy.context.scene.collection.objects.link(obj)
    folder = os.path.join(HERE, "parts")
    obj.data.materials.append(painted("Part." + part["name"], os.path.join(folder, part["name"] + ".png"),
                                      os.path.join(folder, part["name"] + "-ids.png")))
    attach(obj, rig, part["bone"])
    SHAPES.append(obj)


def box(name, loc, size, rig, bone, material):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, scale=True)
    bevel = obj.modifiers.new("Bevel", "BEVEL")
    bevel.width = min(size) * 0.25
    bevel.segments = 2
    obj.data.materials.append(material)
    obj.data.materials.append(OUTLINE)
    shell = obj.modifiers.new("Outline", "SOLIDIFY")
    shell.thickness = 0.01
    shell.offset = 1.0
    shell.use_flip_normals = True
    shell.material_offset = 1
    attach(obj, rig, bone)
    SWORD.append(obj)
    return obj


SWORD = []


def blade(fist, rig, material):
    """剑身：从护手到剑尖收窄成一个尖，侧看是一片带厚度的刃。"""
    start = fist.x + 0.085
    length = 0.9
    half = 0.024
    outline = [(start, -half), (start + length - 0.1, -half * 0.8), (start + length, 0.0),
               (start + length - 0.1, half * 0.8), (start, half)]
    verts = [(x, fist.y - 0.006, fist.z + z) for x, z in outline] + [(x, fist.y + 0.006, fist.z + z) for x, z in outline]
    count = len(outline)
    faces = [tuple(range(count)), tuple(range(2 * count - 1, count - 1, -1))]
    faces += [(i, (i + 1) % count, count + (i + 1) % count, count + i) for i in range(count)]
    mesh = bpy.data.meshes.new("Blade")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new("Blade", mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(material)
    obj.data.materials.append(OUTLINE)
    shell = obj.modifiers.new("Outline", "SOLIDIFY")
    shell.thickness = 0.008
    shell.offset = 1.0
    shell.use_flip_normals = True
    shell.material_offset = 1
    attach(obj, rig, "hand.R")
    SWORD.append(obj)


def build_body(rig):
    for part in PARTS["parts"]:
        card(part, rig)
    # 剑：握在靠镜头的右手（拳心在 hand.R 骨头中段），剑身静止时沿 +X。旧铁色，护手和柄是乌木。
    (hx, hz), (tx, tz) = PARTS["bones"]["hand"]
    grip_x, grip_z = PARTS["grip"]
    fist = Vector((grip_x, -0.33, grip_z))
    steel = toon("Steel", (0.40, 0.41, 0.42))
    hilt = toon("Hilt", (0.22, 0.15, 0.11))
    box("Pommel", fist + Vector((-0.07, 0, 0)), (0.035, 0.03, 0.035), rig, "hand.R", hilt)
    box("Guard", fist + Vector((0.07, 0, 0)), (0.025, 0.05, 0.13), rig, "hand.R", hilt)
    blade(fist, rig, steel)
    tip = bpy.data.objects.new("SwordTip", None)
    bpy.context.scene.collection.objects.link(tip)
    tip.parent = rig
    tip.parent_type = "BONE"
    tip.parent_bone = "hand.R"
    bpy.context.view_layer.update()
    tip.matrix_world = Matrix.Translation(fist + Vector((0.99, 0, 0)))
    # 原画的小臂本来就往前斜了十几度，剑按水平造出来会和小臂成 75°。绕拳心转一下，
    # 让静止时剑身正好垂直于小臂——手腕直、正握，剑和小臂成直角。
    (ex, ez), (wx, wz) = PARTS["bones"]["forearm"]
    forearm = math.degrees(math.atan2(wx - ex, wz - ez))
    turn = (forearm - 90.0) - 90.0
    pivot = Matrix.Translation(fist) @ Matrix.Rotation(math.radians(turn), 4, "Y") @ Matrix.Translation(-fist)
    bpy.context.view_layer.update()
    for obj in SWORD + [tip]:
        obj.matrix_world = pivot @ obj.matrix_world
    return tip, fist


# ── 动作：每帧给每根骨头一个侧视平面里的角度（度） ─────────────────────────────

def pose(rig, frame, angles, root=(0.0, 0.0)):
    angles = dict(angles)
    # 袍摆跟着往前那条腿走三成，往后那条一成。
    thighs = [angles.get("thigh.R", 0), angles.get("thigh.L", 0)]
    angles["skirt"] = 0.3 * min(thighs) + 0.1 * max(thighs)
    for bone in rig.pose.bones:
        degrees = angles.get(bone.name, 0.0)
        rest = bone.bone.matrix_local.to_3x3()
        axis = (rest.inverted() @ Vector((0, 1, 0))).normalized()
        bone.rotation_quaternion = Quaternion(axis, math.radians(degrees))
        bone.keyframe_insert("rotation_quaternion", frame=frame)
    root_bone = rig.pose.bones["root"]
    # root 骨头朝上，局部 X 是世界 X，局部 Y 是世界 Z。
    root_bone.location = (root[0], root[1], 0)
    root_bone.keyframe_insert("location", frame=frame)


def flat_feet(angles):
    for side in ("R", "L"):
        angles["foot." + side] = -(angles.get("thigh." + side, 0) + angles.get("shin." + side, 0))
    return angles


def keep_head(angles):
    lean = angles.get("spine", 0) + angles.get("chest", 0) + angles.get("neck", 0)
    angles["head"] = angles.get("head", 0) - lean * 0.7
    return angles


# 握剑：正握时剑身和小臂垂直，手腕是直的（hand.R = 0）。挥砍时手腕最多往剑尖方向甩 40°
# （尺偏，剑和小臂的夹角从 90° 拉开到 130°），不会往回折。
WRIST_SNAP = 40
# 持剑待机：胳膊自然垂着略往后，手腕直，剑尖斜指前方地面。
READY = {"upper_arm.R": 22, "forearm.R": -3, "hand.R": 0, "upper_arm.L": -6, "forearm.L": -20,
         "spine": 4, "chest": 2, "thigh.R": -8, "shin.R": 10, "thigh.L": 8, "shin.L": 6}


def idle(rig, start):
    frames = 24
    for f in range(frames + 1):
        t = f / frames
        breath = math.sin(t * math.tau)
        angles = dict(READY)
        angles["spine"] += 1.5 * breath
        angles["chest"] += 1.0 * breath
        angles["upper_arm.R"] += -2.0 * breath
        angles["upper_arm.L"] += 2.0 * breath
        angles["hand.R"] += 3.0 * breath
        pose(rig, start + f, keep_head(flat_feet(angles)), (0.0, -0.01 + 0.008 * breath))
    return frames


# ── 走路：先定脚落在哪，再用两节骨的反解求大腿、小腿的角度 ──────────────────────
# 一个周期两步。每只脚六成时间踩在地上（支撑期，脚掌贴地匀速往后滑，正好抵消身体前进，不打滑），
# 四成时间在空中（摆动期，抬脚往前划一道弧）。支撑期开头脚跟先着地、脚尖翘起，末尾脚跟抬起、
# 以脚尖蹬地；摆动期脚尖从朝下慢慢转到翘起，接上下一次脚跟着地。
# 胯的高度不是正弦凑的：两腿分得越开，胯得降多少才够得着地，就降多少，膝盖始终留一点弯。
# 步幅：支撑期脚相对胯从前 0.4 米滑到后 0.4 米。前脚落地时腿几乎伸直，后脚靠脚尖蹬地抬起脚踝，
# 胯的起落因此压在十厘米以内。
STANCE = 0.6
REACH = 0.985
_LEG = (Vector(PARTS["bones"]["thigh"][1]) - Vector(PARTS["bones"]["thigh"][0])).length + \
    (Vector(PARTS["bones"]["shin"][1]) - Vector(PARTS["bones"]["shin"][0])).length
# 步幅按腿长算：原来腿长 0.86 米配 0.8 米步幅，腿改短了步幅跟着按比例缩。
STRIDE = 0.93 * _LEG
LIFT = 0.13 * _LEG
HEEL_STRIKE = -14
TOE_OFF = 30
WALK_FRAMES = 16


def _vec(points, name, end):
    (x, z) = PARTS["bones"][name][end]
    return Vector((x, z))


def _angle(v):
    return math.degrees(math.atan2(v.x, v.y))


def _wrap(degrees):
    """角度差折回 ±180：朝下的骨头静止时在 -178° 附近，往前一点就跳到 +175°，差值得是 -7 而不是 353。"""
    return (degrees + 180.0) % 360.0 - 180.0


def _smooth(t):
    return t * t * (3 - 2 * t)


def leg_targets(p):
    """一只脚在相位 p 时：脚踝相对静止位置的前后偏移、抬高，以及脚尖朝下的角度。"""
    if p < STANCE:
        x = STRIDE / 2 - STRIDE * (p / STANCE)
        lift = 0.0
        tilt = 0.0
        if p < 0.12:
            tilt = HEEL_STRIKE * (1 - p / 0.12)
        elif p > 0.42:
            k = (p - 0.42) / (STANCE - 0.42)
            tilt = TOE_OFF * k * k
        foot = (_vec(None, "foot", 1) - _vec(None, "foot", 0)).length
        lift = foot * math.sin(math.radians(max(tilt, 0.0))) * 0.8
        return x, lift, tilt
    q = (p - STANCE) / (1 - STANCE)
    x = -STRIDE / 2 + STRIDE * _smooth(q)
    lift = LIFT * math.sin(math.pi * q)
    tilt = TOE_OFF + (HEEL_STRIKE - TOE_OFF) * _smooth(q)
    return x, lift, tilt


def solve_leg(hip, ankle, tilt):
    """两节骨反解：膝盖朝前。返回大腿、小腿、脚相对静止姿势要转的角度（度）。"""
    h0, k0, a0, t0 = _vec(None, "thigh", 0), _vec(None, "thigh", 1), _vec(None, "shin", 1), _vec(None, "foot", 1)
    upper, lower = (k0 - h0).length, (a0 - k0).length
    reach = ankle - hip
    distance = min(reach.length, (upper + lower) * 0.995)
    bend = math.degrees(math.acos(max(-1.0, min(1.0, (upper ** 2 + distance ** 2 - lower ** 2) / (2 * upper * distance)))))
    thigh_world = _angle(reach) - bend
    knee = hip + Vector((math.sin(math.radians(thigh_world)), math.cos(math.radians(thigh_world)))) * upper
    shin_world = _angle(ankle - knee)
    foot_world = _angle(t0 - a0) + tilt
    thigh = _wrap(thigh_world - _angle(k0 - h0))
    shin = _wrap(shin_world - _angle(a0 - k0) - thigh)
    foot = _wrap(foot_world - _angle(t0 - a0) - thigh - shin)
    return thigh, shin, foot


def walk(rig, start):
    frames = WALK_FRAMES
    hip_rest = _vec(None, "thigh", 0)
    ankle_rest = _vec(None, "shin", 1)
    upper = (_vec(None, "thigh", 1) - hip_rest).length
    lower = (ankle_rest - _vec(None, "thigh", 1)).length
    for f in range(frames + 1):
        t = f / frames
        feet = {}
        for side, phase in (("R", 0.0), ("L", 0.5)):
            feet[side] = leg_targets((t + phase) % 1.0)
        # 胯往下降到两条腿都够得着地，再多降一点留膝弯。
        drop = -0.02
        for x, lift, _tilt in feet.values():
            ankle = Vector((hip_rest.x + x, ankle_rest.y + lift))
            vertical = math.sqrt(max(0.0, (REACH * (upper + lower)) ** 2 - (ankle.x - hip_rest.x) ** 2))
            drop = min(drop, ankle.y + vertical - hip_rest.y)
        hip = hip_rest + Vector((0.0, drop))
        angles = dict(READY)
        for side, (x, lift, tilt) in feet.items():
            thigh, shin, foot = solve_leg(hip, Vector((hip_rest.x + x, ankle_rest.y + lift)), tilt)
            angles["thigh." + side] = thigh
            angles["shin." + side] = shin
            angles["foot." + side] = foot
        swing = math.cos(t * math.tau)
        # 远侧空手跟右腿同向摆（左右手脚交替），握剑的手只轻轻带一下，剑尖稳住。
        angles["upper_arm.L"] = -4 - 28 * swing
        angles["forearm.L"] = -22 - 10 * max(0.0, swing)
        angles["upper_arm.R"] = READY["upper_arm.R"] + 7 * swing
        angles["spine"] = 8 + 1.5 * math.cos(2 * t * math.tau)
        angles["chest"] = 2 - 1.0 * math.cos(2 * t * math.tau)
        pose(rig, start + f, keep_head(angles), (0.0, drop))
    return frames


# 走一个周期身子前进多少米：支撑期六成时间脚往后滑一个步幅，身子就前进这么多。
WALK_CYCLE_METERS = STRIDE / STANCE


# 下劈：预备（举剑过肩、身子后仰）→ 劈出（弓步前冲）→ 跟招 → 收势。
ATTACK_KEYS = [
    (0, READY, (0.0, 0.0)),
    # 举剑：胳膊举过头顶略往后，小臂折到脑后，剑垂在背后——大劈的蓄势，袖子不挡脸。
    (5, {"upper_arm.R": -190, "forearm.R": -80, "hand.R": 25, "upper_arm.L": -55, "forearm.L": -35,
         "spine": -8, "chest": -5, "thigh.R": -14, "shin.R": 12, "thigh.L": 12, "shin.L": 8}, (-0.04, -0.02)),
    (7, {"upper_arm.R": -200, "forearm.R": -85, "hand.R": 25, "upper_arm.L": -60, "forearm.L": -35,
         "spine": -10, "chest": -6, "thigh.R": -16, "shin.R": 14, "thigh.L": 14, "shin.L": 8}, (-0.05, -0.03)),
    # 劈出：胳膊从头顶甩到身前斜下，手腕顺势甩开。
    (9, {"upper_arm.R": -55, "forearm.R": -5, "hand.R": 35, "upper_arm.L": 30, "forearm.L": -25,
         "spine": 14, "chest": 7, "thigh.R": -40, "shin.R": 34, "thigh.L": 28, "shin.L": 14}, (0.18, -0.10)),
    (12, {"upper_arm.R": -30, "forearm.R": -5, "hand.R": WRIST_SNAP, "upper_arm.L": 35, "forearm.L": -20,
          "spine": 18, "chest": 7, "thigh.R": -42, "shin.R": 38, "thigh.L": 28, "shin.L": 16}, (0.2, -0.11)),
    (17, {"upper_arm.R": -5, "forearm.R": -10, "hand.R": 15, "upper_arm.L": -4, "forearm.L": -20,
          "spine": 8, "chest": 3, "thigh.R": -20, "shin.R": 18, "thigh.L": 14, "shin.L": 8}, (0.08, -0.03)),
    (22, READY, (0.0, 0.0)),
]


def attack(rig, start):
    frames = ATTACK_KEYS[-1][0]
    for f in range(frames + 1):
        for (f0, a0, r0), (f1, a1, r1) in zip(ATTACK_KEYS, ATTACK_KEYS[1:]):
            if f0 <= f <= f1:
                t = (f - f0) / (f1 - f0)
                # 劈出那一段（7→9）用线性，快而狠；其他段缓进缓出。
                k = t if f0 == 7 else t * t * (3 - 2 * t)
                names = set(a0) | set(a1)
                angles = {n: a0.get(n, 0) + (a1.get(n, 0) - a0.get(n, 0)) * k for n in names}
                root = (r0[0] + (r1[0] - r0[0]) * k, r0[1] + (r1[1] - r0[1]) * k)
                pose(rig, start + f, keep_head(flat_feet(angles)), root)
                break
    return frames


ACTIONS = [("idle", idle, 2), ("walk", walk, 1), ("attack", attack, 1)]


# ── 渲染 ────────────────────────────────────────────────────────────────

def setup_camera(scene):
    data = bpy.data.cameras.new("Camera")
    data.type = "ORTHO"
    data.ortho_scale = ORTHO
    camera = bpy.data.objects.new("Camera", data)
    camera.location = (CAMERA_X, -10, CAMERA_Z)
    camera.rotation_euler = (math.radians(90), 0, 0)
    scene.collection.objects.link(camera)
    scene.camera = camera
    sun_data = bpy.data.lights.new("Sun", "SUN")
    sun_data.energy = 3.0
    sun = bpy.data.objects.new("Sun", sun_data)
    direction = Vector((-0.6, 1.0, -1.1)).normalized()
    sun.rotation_mode = "QUATERNION"
    sun.rotation_quaternion = direction.to_track_quat("-Z", "Y")
    scene.collection.objects.link(sun)


def to_pixel(point):
    x = (point.x - CAMERA_X) / ORTHO * SIZE + SIZE / 2
    y = SIZE / 2 - (point.z - CAMERA_Z) / ORTHO * SIZE
    return [round(x, 2), round(y, 2)]


def use_pass(mode):
    for obj in SHAPES:
        obj.material_slots[0].material.node_tree.nodes["Pick"].inputs[0].default_value = 1.0 if mode == "ids" else 0.0
    for obj in SWORD:
        obj.hide_render = mode == "ids"
    bpy.context.scene.render.filter_size = 1.5 if mode == "color" else 0.6


def render_all(scene, rig, tip, plan):
    os.makedirs(os.path.join(OUT, "color"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "ids"), exist_ok=True)
    grips = {}
    for name, first, count, step in plan:
        grips[name] = []
        for index, f in enumerate(range(first, first + count, step)):
            scene.frame_set(f)
            hand = rig.matrix_world @ rig.pose.bones["hand.R"].matrix @ Vector((0, rig.pose.bones["hand.R"].length / 2, 0))
            elbow = rig.matrix_world @ rig.pose.bones["forearm.R"].head
            grips[name].append({"hand": to_pixel(hand), "tip": to_pixel(tip.matrix_world.translation),
                                "elbow": to_pixel(elbow)})
            for mode in ("color", "ids"):
                use_pass(mode)
                scene.render.filepath = os.path.join(OUT, mode, "%s_%02d.png" % (name, index))
                bpy.ops.render.render(write_still=True)
    with open(os.path.join(OUT, "grips.json"), "w") as handle:
        json.dump({"size": SIZE, "ground": GROUND_PIXEL, "fps": FPS, "pixels_per_meter": SIZE / ORTHO,
                   "walk_cycle_meters": WALK_CYCLE_METERS, "actions": grips}, handle, indent=1)


scene = reset_scene()
OUTLINE = flat("Outline", (0.04, 0.03, 0.03))
OUTLINE.use_backface_culling = True
rig = build_rig(scene)
tip, _fist = build_body(rig)
setup_camera(scene)
plan = []
cursor = 1
for name, action, step in ACTIONS:
    frames = action(rig, cursor)
    # 循环动作最后一帧与第一帧相同，不渲；单次动作渲到最后一帧。
    count = frames if name in ("idle", "walk") else frames + 1
    plan.append((name, cursor, count, step))
    cursor += frames + 2
render_all(scene, rig, tip, plan)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "hero3d.blend"))
print("hero3d done", OUT)
