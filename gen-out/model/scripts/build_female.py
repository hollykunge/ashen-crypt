"""女主角：Quaternius 女性骨架 + 女农夫、女游侠两套衣服 + 由女游侠重新上色的皮甲、链甲 + Superhero 女头 + 发髻。

blender -b --factory-startup -P build_female.py -- gen-out/model/female_char.blend

骨骼名和层级与男主角的 Rig 一样（UE 风格 65 根）。之后照男主角的流程：
  add_actions.py 套动作 → export_godot.py 烘贴图导出 mobile/art/model-hero/female.glb → render_portrait.py 出头像。
贴图写到旁边的 textures/，用相对路径引用（和 ashen_char_3outfits.blend 一样）。

部件（游戏 model_hero.gd 的 FEMALE_SLOTS 按这些名字找）：
  头      Head_Skin Head_Eyes Head_Eyebrows Head_Hair_Main（发髻）
  布衣    F_Peasant_Body / _Arms / _Legs / _Feet
  游侠    F_Ranger_Body(+_1 _2 腰带) / _Arms(+_1 护腕) / _Legs / _Feet / _Acc_Pauldrons / _Head_Hood
  皮甲    F_Leather_*：游侠那套复制，暗红皮、炭黑袖、深褐裤
  链甲    F_Chain_*：游侠那套复制，钢灰
"""
import bpy, sys, os, bmesh, hashlib

argv = sys.argv[sys.argv.index("--") + 1:]
OUT = os.path.abspath(argv[0])

Q = r"D:\quaternius"
UBC = Q + r"\UBC_Standard\Universal Base Characters[Standard]"
PARTS = Q + r"\Outfits_Fantasy_Standard\Modular Character Outfits - Fantasy[Standard]\Exports\glTF (Godot-Unreal)\Modular Parts"
HAIR = UBC + r"\Hairstyles\Rigged to Head Bone\glTF (Godot -Unreal)"

bpy.ops.wm.read_factory_settings(use_empty=True)
col = bpy.data.collections.new("Parts")
bpy.context.scene.collection.children.link(col)
bpy.context.scene.render.fps = 24


def imp(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def adopt(objs, arm):
    keep = [o for o in objs if o.type == "MESH" and not o.name.startswith("Icosphere")]
    for o in keep:
        mw = o.matrix_world.copy()
        o.parent = arm
        o.matrix_world = mw
        for m in o.modifiers:
            if m.type == "ARMATURE":
                m.object = arm
        for c in o.users_collection:
            c.objects.unlink(o)
        col.objects.link(o)
    for o in objs:
        if o not in keep and o is not arm:
            bpy.data.objects.remove(o, do_unlink=True)
    return keep


first = imp(PARTS + r"\Female_Peasant_Body.gltf")
arm = next(o for o in first if o.type == "ARMATURE")
arm.name = "Rig"
for c in arm.users_collection:
    c.objects.unlink(arm)
col.objects.link(arm)
for o in adopt(first, arm):
    o.name = "F_Peasant_Body"
for f in ["Female_Peasant_Arms", "Female_Peasant_Feet", "Female_Peasant_Legs",
          "Female_Ranger_Acc_Pauldrons", "Female_Ranger_Arms", "Female_Ranger_Body", "Female_Ranger_Feet",
          "Female_Ranger_Head_Hood", "Female_Ranger_Legs"]:
    for i, o in enumerate(adopt(imp(PARTS + "\\" + f + ".gltf"), arm)):
        o.name = f.replace("Female_", "F_") + (f"_{i}" if i else "")

# 头：Superhero 女性全身只留脖子以上
for o in adopt(imp(UBC + r"\Base Characters\Godot - UE\Superhero_Female_FullBody.gltf"), arm):
    if o.name.lower().startswith("superhero"):
        o.name = "Head_Skin"
        bm = bmesh.new()
        bm.from_mesh(o.data)
        keep = {o.vertex_groups[n].index for n in ("Head", "neck_01", "neck_02") if n in o.vertex_groups}
        dl = bm.verts.layers.deform.active
        bad = [v for v in bm.verts
               if sum(w for g, w in v[dl].items() if g in keep) / (sum(v[dl].values()) or 1.0) < 0.5]
        bmesh.ops.delete(bm, geom=bad, context="VERTS")
        bm.to_mesh(o.data)
        bm.free()
    elif o.name.startswith("Eyes"):
        o.name = "Head_Eyes"
    else:
        bpy.data.objects.remove(o, do_unlink=True)
for f, name in (("Eyebrows_Female", "Head_Eyebrows"), ("Hair_Buns", "Head_Hair_Main")):
    for o in adopt(imp(HAIR + "\\" + f + ".gltf"), arm):
        o.name = name
for o in list(bpy.data.objects):
    if o.name.startswith("Icosphere"):
        bpy.data.objects.remove(o, do_unlink=True)


# ---- 皮甲、链甲：复制游侠那套，按原贴图亮度重新上色（同 build_chain.py 的 recolor，灰色金属扣保留原色）
def srgb(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c) + (1.0,)


def mix_rgba(N, blend="MIX"):
    n = N.new("ShaderNodeMix"); n.data_type = "RGBA"; n.blend_type = blend
    ins = [i for i in n.inputs if i.type == "RGBA"]
    return n, n.inputs[0], ins[0], ins[1], next(s for s in n.outputs if s.type == "RGBA")


def recolor(o, slot_index, target, keep=0.18):
    m = o.data.materials[slot_index].copy()
    m.name = f"{o.name}_M{slot_index}"
    o.data.materials[slot_index] = m
    N, L = m.node_tree.nodes, m.node_tree.links
    p = next(n for n in N if n.bl_idname == "ShaderNodeBsdfPrincipled")
    albedo = p.inputs["Base Color"].links[0].from_socket
    bw = N.new("ShaderNodeRGBToBW"); L.new(albedo, bw.inputs[0])
    gain = N.new("ShaderNodeMath"); gain.operation = "MULTIPLY"; gain.inputs[1].default_value = 2.2
    L.new(bw.outputs[0], gain.inputs[0])
    _, f, a, b, tinted = mix_rgba(N, "MULTIPLY")
    f.default_value = 1.0; a.default_value = target
    L.new(gain.outputs[0], b)
    _, f2, a2, b2, out = mix_rgba(N)
    L.new(tinted, a2); L.new(albedo, b2)
    sep = N.new("ShaderNodeSeparateColor"); sep.mode = "HSV"; L.new(albedo, sep.inputs[0])
    inv = N.new("ShaderNodeMapRange")
    inv.inputs["From Min"].default_value = 0.08; inv.inputs["From Max"].default_value = 0.25
    inv.inputs["To Min"].default_value = 0.9; inv.inputs["To Max"].default_value = keep
    L.new(sep.outputs[1], inv.inputs["Value"]); L.new(inv.outputs["Result"], f2)
    L.new(out, p.inputs["Base Color"])


def dup(src, new):
    s = bpy.data.objects[src]
    o = s.copy()
    o.data = s.data.copy()
    o.name = o.data.name = new
    col.objects.link(o)
    return o


# 部件 → (皮甲颜色, 链甲颜色)；F_Ranger_Arms 的第 2 个材质是皮肤，不动
SETS = {
    "Body": ("7a2e24", "8a9096"), "Body_1": ("3b2818", "2e2a27"), "Body_2": ("3b2818", "2e2a27"),
    "Arms": ("2c2826", "6e757b"), "Arms_1": ("7a2e24", "9aa1a6"),
    "Legs": ("2a211c", "3d3f42"), "Feet": ("7a2e24", "2e2a27"), "Acc_Pauldrons": ("7a2e24", "9aa1a6"),
}
for part, colors in SETS.items():
    for kind, hexc in zip(("Leather", "Chain"), colors):
        o = dup("F_Ranger_" + part, f"F_{kind}_{part}")
        # 上衣原来是绿的，留一点原色就发橄榄色，几乎全换掉
        keep = 0.05 if part == "Body" else 0.12 if part in ("Feet", "Body_1", "Body_2") else 0.18
        recolor(o, 0, srgb(hexc), keep=keep)

parts = sorted(o.name for o in col.objects if o.type == "MESH")
print("PARTS", parts)

# ---- 贴图写到 textures/，相对路径引用
tex_dir = os.path.join(os.path.dirname(OUT), "textures")
os.makedirs(tex_dir, exist_ok=True)
for i in bpy.data.images:
    if i.source != "FILE":
        continue
    if i.packed_file:
        data = bytes(i.packed_file.data)
        name = (os.path.basename(i.filepath) or i.name + ".png")
    else:
        src = bpy.path.abspath(i.filepath)
        if not os.path.exists(src):
            src = src.replace("_png.png", ".png")
        if not os.path.exists(src):
            print("MISSING", i.name, src)
            continue
        data = open(src, "rb").read()
        name = os.path.basename(src)
    name = name.replace("_png.png", ".png")
    dst = os.path.join(tex_dir, name)
    if os.path.exists(dst) and hashlib.sha1(open(dst, "rb").read()).digest() != hashlib.sha1(data).digest():
        name = hashlib.sha1(data).hexdigest()[:6] + "_" + name
        dst = os.path.join(tex_dir, name)
    if not os.path.exists(dst):
        open(dst, "wb").write(data)
    if i.packed_file:
        i.unpack(method="REMOVE")
    i.filepath = "//textures/" + name
    i.reload()
bpy.ops.wm.save_as_mainfile(filepath=OUT, compress=True, relative_remap=False)
print("SAVED", OUT)
