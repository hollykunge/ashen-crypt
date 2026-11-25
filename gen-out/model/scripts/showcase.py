"""陈列：把主角的三套衣装、每一件装备、每一种兵器摆成一排，存成单独的 showcase.blend 看。

blender -b gen-out/model/ashen_char_3outfits.blend -P gen-out/model/scripts/detail_armor.py \n        -P gen-out/model/scripts/showcase.py -- <out.blend> [preview.png]
（先跑 detail_armor.py，皮甲、链甲才是游戏里的花纹）

不改动 ashen_char_3outfits.blend：所有东西摆在新场景「陈列」里，另存一份。
上面一排是衣装：先是三套整身（布衣、皮甲、链甲，头饰跟着上衣走，和游戏一样），
再按槽把每一件单独摆出来（上衣连肩甲、护腕、护腿、靴子、头饰，各三款）。
下面一排是兵器（mobile/art/model-hero/weapons.glb）：三种剑、三种枪、两种弓按游戏里的组合装好，
最后是护手和柄首各款，太小，放大三倍。颜色用游戏里没锻造时的默认色（model_hero.gd 的 hold）。
"""
import bpy, os, sys, math

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.abspath(argv[0]) if argv else os.path.join(HERE, "..", "showcase.blend")
PREVIEW = os.path.abspath(argv[1]) if len(argv) > 1 else None
WEAPONS = os.path.join(ROOT, "mobile", "art", "model-hero", "weapons.glb")
FONT = os.path.join(ROOT, "mobile", "art", "fonts", "game.otf")

HEAD = ["Head_Skin", "Head_Eyes", "Head_Eyebrows", "Head_Hair_Main", "Head_Hair_Beard"]
TOPKNOT = ["Head_Hair_Bun", "Head_Hair_Tail", "Head_Band", "Head_Pin"]
# 游戏里的甲型 → 各槽部件（和 mobile/scripts/model_hero.gd 的 SLOTS 一致）
OUTFITS = {
    "布衣": {"torso": ["Male_Peasant_Body"], "arms": ["Male_Peasant_Arms"], "legs": ["Male_Peasant_Legs"],
             "feet": ["Male_Peasant_Feet"], "shoulder": [], "headgear": ["Head_Hat"]},
    "皮甲": {"torso": ["Leather_Body", "Leather_Belt_1", "Leather_Belt_2"], "arms": ["Leather_Arms", "Leather_Bracer"],
             "legs": ["Leather_Legs", "Leather_ThighGuard"], "feet": ["Leather_Boots"],
             "shoulder": ["Leather_Pauldron_L", "Leather_Pauldron_R"], "headgear": ["Head_Helm_Leather"]},
    "链甲": {"torso": ["Chain_Body", "Chain_Belt_1", "Chain_Belt_2"], "arms": ["Chain_Arms", "Chain_Bracer"],
             "legs": ["Chain_Legs"], "feet": ["Chain_Boots"],
             "shoulder": ["Chain_Pauldron_L", "Chain_Pauldron_R"], "headgear": ["Head_Helm_Iron"]},
}
# 单件陈列：游戏的装备槽 → 模型的槽
PIECES = [("上衣", ["torso", "shoulder"]), ("护腕", ["arms"]), ("护腿", ["legs"]), ("靴子", ["feet"]), ("头饰", ["headgear"])]
# 兵器：名字 → 零件（共用一个原点：握点）
ARMS = [   # 古兵器素材包里挑的整件（import_pack_weapons.py），弓再加弦
    ("柳叶刀", ["dao_blade_jian"]), ("錾花刀", ["dao_blade_qixing"]), ("宽头大刀", ["dao_blade_bolang"]),
    ("素剑", ["sword_blade_jian"]), ("圆格花剑", ["sword_blade_qixing"]), ("红柄剑", ["sword_blade_bolang"]),
    ("黑缨枪", ["spear_head_leaf"]), ("花枪", ["spear_head_snake"]), ("月牙戟", ["spear_head_ji"]),
    ("长弓", ["bow_limbs_chang", "bow_string_chang"]), ("反曲弓", ["bow_limbs_fanqu", "bow_string_fanqu"]),
]
SMALL = []
# 兵器零件按用途上色：游戏里没锻造时的默认色（model_hero.gd 的 hold）
ROLE_COLORS = {"steel": "#62656a", "trim": "#a0804c", "wrap": "#6f2a1c", "accent": "#b8342a", "wood": "#7c5a3c",
               "core": "#2e2219", "cap": "#a58a5e", "string": "#d4c4a5", "tassel": "#b8342a"}

STEP = 0.85          # 衣装之间的间距（米）
WEAPON_ROW = -3.2    # 兵器那一排往下放多少


def bsdf_of(mat):
    """材质的 Principled BSDF 节点（节点名会随界面语言翻译，按类型找）"""
    if not mat.use_nodes:
        mat.use_nodes = True
    return next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)


def hex_rgba(text):
    text = text.lstrip("#")
    srgb = [int(text[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
    return (*lin, 1.0)


source = bpy.context.scene
rig = bpy.data.objects["Rig"]
# 摆成待机的第一帧，比 T 字站姿好看
if rig.animation_data is None:
    rig.animation_data_create()
rig.animation_data.action = bpy.data.actions["Idle_Loop"]
if hasattr(rig.animation_data, "action_slot") and rig.animation_data.action_slot is None:
    slots = getattr(bpy.data.actions["Idle_Loop"], "slots", [])
    if len(slots):
        rig.animation_data.action_slot = slots[0]
source.frame_set(0)

show = bpy.data.scenes.new("陈列")
show.frame_start = show.frame_end = 0
show.frame_current = 0
show.render.engine = source.render.engine
show.world = source.world
font = bpy.data.fonts.load(FONT) if os.path.exists(FONT) else None


def group(name, parts, x, z=0.0):
    """一组部件做成一个集合，在陈列场景里摆一个实例。骨架不放进去（不然满屏骨头），
    部件的骨架修改器照样引用它，依赖图会把它一起算上"""
    coll = bpy.data.collections.new("陈列_" + name)
    for part in parts:
        if part in bpy.data.objects:
            coll.objects.link(bpy.data.objects[part])
        else:
            print("没有这个部件：", part)
    inst = bpy.data.objects.new(name, None)
    inst.instance_type = "COLLECTION"
    inst.instance_collection = coll
    inst.location = (x, 0.0, z)
    show.collection.objects.link(inst)
    return inst


def label(text, x, z, size=0.09):
    curve = bpy.data.curves.new("字_" + text, "FONT")
    curve.body = text
    curve.align_x = "CENTER"
    curve.size = size
    if font:
        curve.font = font
    ob = bpy.data.objects.new("字_" + text, curve)
    ob.location = (x, -0.3, z)
    ob.rotation_euler = (math.radians(90), 0, 0)   # 立起来，朝 -Y（正视图）
    mat = bpy.data.materials.get("字") or bpy.data.materials.new("字")
    mat.diffuse_color = (0.08, 0.06, 0.05, 1.0)
    bsdf_of(mat).inputs["Base Color"].default_value = (0.03, 0.02, 0.02, 1.0)
    curve.materials.append(mat)
    show.collection.objects.link(ob)
    return ob


# ---------------------------------------------------------------- 衣装
x = 0.0
label("整套衣装", x + STEP, 2.45, 0.22)
for name, slots in OUTFITS.items():
    parts = list(HEAD)
    for slot in ("torso", "arms", "legs", "feet", "shoulder", "headgear"):
        parts += slots[slot]
    group("整套_" + name, parts, x)
    label(name, x, 2.12, 0.14)
    x += STEP
x += STEP * 0.8
label("每一件装备（布衣 · 皮甲 · 链甲）", x + STEP * 6, 2.45, 0.22)
for title, slots in PIECES:
    label(title, x + STEP, 2.12, 0.16)
    for name, outfit in OUTFITS.items():
        parts = [p for slot in slots for p in outfit[slot]]
        group(f"{title}_{name}", parts, x)
        label(name, x, -0.2, 0.12)
        x += STEP
    x += STEP * 0.5
outfit_width = x

# ---------------------------------------------------------------- 兵器
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=WEAPONS)
kit = {o.name.split(".")[0]: o for o in set(bpy.data.objects) - before if o.type == "MESH"}
for o in set(bpy.data.objects) - before:   # 导入的原件先从当前场景摘下，只用复制出来的
    for c in list(o.users_collection):
        c.objects.unlink(o)


def place(parts, x, z, scale=1.0, tilt=False):
    for part in parts:
        if part not in kit:
            print("没有这个兵器零件：", part)
            continue
        ob = kit[part].copy()
        ob.location = (x, 0.0, z)
        ob.rotation_mode = "XYZ"   # glTF 导入的物体默认用四元数，改成欧拉角才吃 rotation_euler
        # 护手、柄首是绕着握轴的一圈，正看只是一条线：斜过来露出面
        ob.rotation_euler = (math.radians(-65), 0.0, math.radians(25)) if tilt else (0.0, 0.0, 0.0)
        ob.scale = (scale, scale, scale)
        show.collection.objects.link(ob)


x = 0.0
label("兵器", x + 0.2, WEAPON_ROW + 2.75, 0.22)
for name, parts in ARMS:
    # 握点在原点：剑往上 0.9 米，枪尾在握点下 0.8 米，弓上下各 0.7 米，都抬到地面以上
    lift = {"sword": 0.55, "dao": 0.55, "spear": 0.85, "bow": 0.75}[parts[0].split("_")[0]]
    place(parts, x, WEAPON_ROW + lift)
    label(name, x, WEAPON_ROW - 0.2, 0.12)
    x += 0.55
x += 0.3
for name, part in SMALL:
    place([part], x, WEAPON_ROW + 0.4, 3.0, tilt=True)
    label(name, x, WEAPON_ROW - 0.2, 0.09)
    x += 0.55
weapon_width = x

# ---------------------------------------------------------------- 灯光、相机、视图
sun = bpy.data.objects.new("陈列_主光", bpy.data.lights.new("陈列_主光", "SUN"))
sun.data.energy = 3.0
sun.rotation_euler = (math.radians(50), math.radians(-20), math.radians(-25))
show.collection.objects.link(sun)
width = max(outfit_width, weapon_width)
cam = bpy.data.objects.new("陈列_相机", bpy.data.cameras.new("陈列_相机"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = width + 0.6
cam.location = (width / 2 - 0.4, -20.0, (2.5 + WEAPON_ROW - 0.3) / 2)
cam.rotation_euler = (math.radians(90), 0, 0)
show.collection.objects.link(cam)
show.camera = cam
show.render.resolution_x = 3200
show.render.resolution_y = int(3200 * (2.5 - WEAPON_ROW + 0.5) / (width + 0.6))
show.render.film_transparent = False

bpy.context.window_manager.windows[0].scene = show if bpy.context.window_manager.windows else None
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == "VIEW_3D":
            for space in area.spaces:
                if space.type == "VIEW_3D":
                    space.shading.type = "MATERIAL"

if PREVIEW:
    bpy.context.window.scene = show if bpy.context.window else None
    show.render.filepath = PREVIEW
    bpy.ops.render.render(write_still=True, scene=show.name)

bpy.ops.wm.save_as_mainfile(filepath=OUT, copy=True)
print("陈列已存：", OUT)
