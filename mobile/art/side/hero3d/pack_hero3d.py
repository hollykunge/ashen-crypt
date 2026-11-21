"""把 build_hero.py 渲出的逐帧图拼成游戏用的图集，并出一张预览动图。

用法：python3 pack_hero3d.py <渲染目录> [预览动图路径]

产物（放在本目录）：
  hero3d-color.png   上色图集，每格 384×384，一行一个动作
  hero3d-ids.png     同排布的染色分区图集
  hero3d.json        每个动作的帧数、帧率、每帧握点与剑尖（像素，相对本格左上角）
预览动图：三种染色（不染、火、水）并排，背景取疫城长卷，压一层暗黑调色。
"""

import json
import os
import sys

from PIL import Image, ImageEnhance

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCE = sys.argv[1]
PREVIEW = sys.argv[2] if len(sys.argv) > 2 else None
# 分区标记色 → 名字，与 build_hero.py 的 IDS 一致。
IDS = {(255, 0, 0): "cloth", (0, 255, 0): "trim", (0, 0, 255): "bracers", (255, 255, 0): "boots",
       (255, 0, 255): "charm"}
# 每一区原画的平均亮度，在待机第一帧上量；染色时按它把明暗归一：
# 这一点比平均亮多少，染出来就比染料亮多少。原画的袍子近乎全黑，不归一会染成一片黑。
NEUTRAL = {}


with open(os.path.join(SOURCE, "grips.json")) as handle:
    grips = json.load(handle)
size = grips["size"]
actions = list(grips["actions"].keys())
columns = max(len(grips["actions"][name]) for name in actions)


def frame(kind, name, index):
    return Image.open(os.path.join(SOURCE, kind, "%s_%02d.png" % (name, index))).convert("RGBA")


def pack(kind):
    sheet = Image.new("RGBA", (columns * size, len(actions) * size), (0, 0, 0, 0))
    for row, name in enumerate(actions):
        for index in range(len(grips["actions"][name])):
            sheet.paste(frame(kind, name, index), (index * size, row * size))
    return sheet


def region(pixel):
    best = None
    for color, name in IDS.items():
        if max(abs(pixel[i] - color[i]) for i in range(3)) < 40:
            best = name
    return best


def dye(color_frame, id_frame, dyes):
    """按分区平涂染料，再乘回原画的明暗：中性灰的亮度除以它的基准灰，得到这一点该多亮。"""
    out = color_frame.copy()
    source = color_frame.load()
    ids = id_frame.load()
    target = out.load()
    for y in range(size):
        for x in range(size):
            r, g, b, a = source[x, y]
            if a == 0:
                continue
            name = region(ids[x, y][:3])
            if name is None or name not in dyes:
                continue
            # 亮度比压成 0.7 次方，免得磨白的布边一染就亮成一片；再留两成原画的污渍。
            ratio = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0 / NEUTRAL[name]
            shade = min(max(ratio ** 0.7, 0.25), 1.45) * 0.72
            ink = dyes[name]
            original = (r, g, b)
            target[x, y] = tuple(min(255, int(ink[i] * shade * 0.8 + original[i] * 0.2)) for i in range(3)) + (a,)
    return out


def hexrgb(text):
    text = text.lstrip("#")
    return tuple(int(text[i:i + 2], 16) for i in (0, 2, 4))


def preview(path):
    # 火：朱袍、旧黄镶边；水：靛袍、骨白镶边。颜色取 pigments.gd 的 DYE 与 LIGHT。
    looks = [
        {},
        {"cloth": hexrgb("8f3f2c"), "trim": hexrgb("e3cfa2"), "bracers": hexrgb("5a4636"), "boots": hexrgb("2c2420")},
        {"cloth": hexrgb("3d5680"), "trim": hexrgb("efe9db"), "bracers": hexrgb("4a5258"), "boots": hexrgb("23262b")},
    ]
    plate = Image.open(os.path.join(HERE, "..", "plates", "plague.webp")).convert("RGB")
    crop_height = int(plate.height * 0.42)
    floor = int(plate.height * 0.79)
    panel_width = int(size * 0.95)
    backdrop = plate.crop((int(plate.width * 0.3), floor - crop_height + int(size * 0.08),
                           int(plate.width * 0.3) + panel_width * 3 * crop_height // size, floor + int(size * 0.08)))
    backdrop = backdrop.resize((panel_width * 3, size))
    backdrop = ImageEnhance.Color(backdrop).enhance(0.45)
    backdrop = ImageEnhance.Brightness(backdrop).enhance(0.62)
    # 放映顺序：待机一轮、走两轮、劈一刀、待机。
    sequence = [("idle", i) for i in range(len(grips["actions"]["idle"]))]
    sequence += [("walk", i) for i in range(len(grips["actions"]["walk"]))] * 2
    sequence += [("attack", i) for i in range(len(grips["actions"]["attack"]))]
    sequence += [("idle", i) for i in range(len(grips["actions"]["idle"]))]
    cache = {}
    frames = []
    durations = []
    for name, index in sequence:
        key = (name, index)
        if key not in cache:
            color = frame("color", name, index)
            ids = frame("ids", name, index)
            canvas = backdrop.copy().convert("RGBA")
            for column, look in enumerate(looks):
                sprite = dye(color, ids, look) if look else color
                canvas.alpha_composite(sprite, (column * panel_width + (panel_width - size) // 2, 0))
            cache[key] = canvas.convert("RGB").resize((panel_width * 3 * 3 // 4, size * 3 // 4))
        frames.append(cache[key])
        step = 2 if name == "idle" else 1
        durations.append(int(1000 / grips["fps"] * step))
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=durations, loop=0, optimize=True)


def measure():
    color = frame("color", "idle", 0).load()
    ids = frame("ids", "idle", 0).load()
    totals = {}
    for y in range(size):
        for x in range(size):
            r, g, b, a = color[x, y]
            name = region(ids[x, y][:3]) if a > 200 else None
            if name:
                total = totals.setdefault(name, [0.0, 0])
                total[0] += (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
                total[1] += 1
    for name, (luma, count) in totals.items():
        NEUTRAL[name] = luma / count
    print("zone brightness", {name: round(value, 3) for name, value in NEUTRAL.items()})


measure()
pack("color").save(os.path.join(HERE, "hero3d-color.png"))
pack("ids").save(os.path.join(HERE, "hero3d-ids.png"))
meta = {"cell": size, "ground": grips["ground"], "fps": grips["fps"], "actions": {}}
for row, name in enumerate(actions):
    meta["actions"][name] = {"row": row, "frames": len(grips["actions"][name]), "grips": grips["actions"][name]}
with open(os.path.join(HERE, "hero3d.json"), "w") as handle:
    json.dump(meta, handle, indent=1, ensure_ascii=False)
if PREVIEW:
    preview(PREVIEW)
print("packed", columns, "x", len(actions), "cells")
