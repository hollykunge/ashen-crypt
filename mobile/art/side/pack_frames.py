"""把男女修行人的原画拼成游戏用的高清图集，并分出可以按装备染色的衣料图层。

    python art/side/pack_frames.py            # 在 mobile 目录下运行
    python art/side/pack_frames.py --preview out_dir   # 另存五行染色的对照图

原画是 source/frames-*.png（1536×1024，4 列 × 3 行）。游戏里每格的逻辑尺寸是 96×96，
脚底锚点、握点和关节坐标都按这个尺寸标在脚本里（side_art.gd / held_weapon.gd / worn_sprites.gd）。
这里按 TEXEL 倍输出贴图，逻辑坐标不变，所以那些标定不用动。

每个性别输出五张图：
    frames-<sex>.png          底图，TEXEL×96 一格
    dye/<sex>-cloth.png       袍、裤、袖       → 护甲的袍色
    dye/<sex>-trim.png        衣领、镶边、腰带 → 阴阳镶边色
    dye/<sex>-bracers.png     前臂             → 护手
    dye/<sex>-boots.png       靴               → 鞋子
    dye/<sex>-charm.png       腰间符牌         → 项链
染色图层同时是「哪里染」的模板（alpha 不为 0 处）和「怎么留明暗」的叠色：运行时先在模板内
平涂染料，再把这张图叠回去——黑的地方压暗、白的地方提亮，等于染料乘以原画的明暗。
这样换装只用引擎自带的整图混合，不用逐像素算。
"""
import argparse
import re
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = Path(__file__).resolve().parent
SCRIPTS = HERE.parent.parent / "scripts"
TEXEL = 3
CELL = 96
SIZE = CELL * TEXEL

# 每格在原画里的位置：(缩放, 左上角 x, 左上角 y)。原画坐标 = 左上角 + 格内逻辑坐标 / 缩放。
# 由旧的 96 像素图集配准得来，脚底仍落在 PIVOT，握点与关节的标定沿用。
LAYOUT = {
    "male": [
        (0.2313, -19.71, -58.03), (0.2307, 349.52, -60.53), (0.2297, 747.80, -62.46), (0.2309, 1129.50, -58.20),
        (0.2313, -29.66, 284.22), (0.2309, 357.52, 283.80), (0.2309, 736.77, 283.80), (0.2303, 1123.15, 282.54),
        (0.2307, -13.86, 626.47), (0.2316, 365.83, 627.22), (0.2317, 748.29, 630.88), (0.2313, 1121.37, 627.72),
    ],
    "female": [
        (0.2296, -7.89, -60.15), (0.2306, 365.46, -61.46), (0.2310, 755.79, -61.03), (0.2318, 1124.97, -59.20),
        (0.2318, -23.99, 284.80), (0.2300, 368.83, 280.29), (0.2312, 765.39, 280.80), (0.2308, 1133.04, 281.13),
        (0.2315, 8.37, 627.55), (0.2300, 375.42, 625.29), (0.2307, 742.17, 627.22), (0.2310, 1141.45, 626.97),
    ],
}
LAYERS = ["cloth", "trim", "bracers", "boots", "charm"]
SHADOW = np.array([0.070, 0.040, 0.085])


def vectors(text):
    return [(float(a), float(b)) for a, b in re.findall(r"Vector2\(\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\)", text)]


def gd_const(path, name):
    """取出 GDScript 里一个常量数组的全部 Vector2，顺序与源码一致。"""
    source = (SCRIPTS / path).read_text(encoding="utf-8")
    start = source.index("const %s :=" % name)
    depth = 0
    for index in range(source.index("[", start), len(source)):
        depth += {"[": 1, "]": -1}.get(source[index], 0)
        if depth == 0:
            return vectors(source[start:index])
    raise ValueError(name)


def joints():
    """每格的关节：近肩、腰带、近肘、近腕、两踝、远肘、远腕、两拳。"""
    far = np.array(gd_const("worn_sprites.gd", "FAR_ARMS")).reshape(2, 12, 2, 2)
    lead = np.array(gd_const("held_weapon.gd", "LEAD")).reshape(2, 12, 2)
    support = np.array(gd_const("held_weapon.gd", "SUPPORT")).reshape(2, 12, 2)
    out = {}
    for index, (sex, name) in enumerate([("male", "MALE"), ("female", "FEMALE")]):
        near = np.array(gd_const("worn_sprites.gd", name)).reshape(12, 6, 2)
        out[sex] = [{"shoulder": near[f, 0], "belt": near[f, 1], "elbow": near[f, 2], "wrist": near[f, 3],
            "ankles": [near[f, 4], near[f, 5]], "far_elbow": far[index, f, 0], "far_wrist": far[index, f, 1],
            "fists": [lead[index, f], support[index, f]]} for f in range(12)]
    return out


def split_frames(alpha):
    """原画里十二个人各自的包围盒，用来挡掉相邻格伸进来的衣角。"""
    def runs(mask, least=20):
        found, start = [], None
        for i, on in enumerate(list(mask) + [False]):
            if on and start is None:
                start = i
            elif not on and start is not None:
                if i - start >= least:
                    found.append((start, i))
                start = None
        return found
    boxes = []
    for top, bottom in runs(alpha.any(1)):
        for left, right in runs(alpha[top:bottom].any(0)):
            boxes.append((left, top, right, bottom))
    assert len(boxes) == 12, "原画应当正好十二格，实得 %d" % len(boxes)
    return boxes


def pack(sex):
    original = Image.open(HERE / "source" / ("frames-%s.png" % sex)).convert("RGBA")
    boxes = split_frames(np.array(original)[..., 3] > 40)
    pad = 200
    sheet = Image.new("RGBA", (SIZE * 4, SIZE * 3), (0, 0, 0, 0))
    for frame, (scale, left, top) in enumerate(LAYOUT[sex]):
        alone = Image.new("RGBA", (original.width + 2 * pad, original.height + 2 * pad), (0, 0, 0, 0))
        l, t, r, b = boxes[frame]
        alone.paste(original.crop((l - 4, t - 4, r + 4, b + 4)), (l - 4 + pad, t - 4 + pad))
        span = CELL / scale
        cell = alone.resize((SIZE, SIZE), Image.LANCZOS, box=(left + pad, top + pad, left + pad + span, top + pad + span))
        sheet.paste(cell, ((frame % 4) * SIZE, (frame // 4) * SIZE))
    # 原画身体内部的不透明度只有 0.99 上下，拉满到 1：染色时平涂的是不透明色，两边要对得上。
    pixels = np.asarray(sheet).astype(np.float32)
    pixels[..., 3] = np.clip(pixels[..., 3] * (255.0 / 249.0), 0.0, 255.0)
    return Image.fromarray(pixels.astype(np.uint8), "RGBA")


def capsule(grid, start, end, radius_start, radius_end=None):
    """两点之间的一段粗线，半径可以渐变。坐标是格内逻辑单位。"""
    radius_end = radius_start if radius_end is None else radius_end
    start, end = np.asarray(start, float), np.asarray(end, float)
    axis = end - start
    length = max(float(np.hypot(*axis)), 1e-6)
    along = np.clip(((grid - start) @ axis) / length ** 2, 0.0, 1.0)
    nearest = start + along[..., None] * axis
    return np.hypot(*np.moveaxis(grid - nearest, -1, 0)) <= radius_start + (radius_end - radius_start) * along


def classify(cell, pose, sex):
    """把一格里的不透明像素分到五个染色区，其余（脸、手、头发）不动。"""
    rgb = cell[..., :3]
    body = cell[..., 3] > 0.5
    peak = rgb.max(-1)
    low = rgb.min(-1)
    value = peak
    chroma = peak - low
    saturation = np.where(peak > 0, chroma / np.maximum(peak, 1e-6), 0.0)
    red, green, blue = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hue = np.degrees(np.arctan2(np.sqrt(3) * (green - blue), 2 * red - green - blue)) % 360

    ys, xs = np.mgrid[0:SIZE, 0:SIZE]
    grid = np.stack([(xs + 0.5) / TEXEL, (ys + 0.5) / TEXEL], -1)
    shoulder, belt = pose["shoulder"], pose["belt"]
    spine = (shoulder - belt) / np.hypot(*(shoulder - belt))
    # 颈线以上、头心附近是头：脸、发髻、发簪都不染。出拳时前伸的手臂也会越过颈线，所以要单独让开。
    above_neck = (grid - (shoulder + spine * 1.5)) @ spine > 0
    forward = np.array([-spine[1], spine[0]])
    if forward[0] < 0:
        forward = -forward
    # 头比肩膀靠前：标的是近侧的肩，脸朝右，头心要往面朝方向挪一点。
    centre = shoulder + spine * 9.0 + forward * 5.0
    distance = np.hypot(*np.moveaxis(grid - centre, -1, 0))
    behind = (grid - shoulder) @ forward < 1.5
    arms = capsule(grid, shoulder, pose["elbow"], 5.0) | capsule(grid, pose["elbow"], pose["wrist"], 4.6)
    arms |= capsule(grid, shoulder, pose["far_elbow"], 5.0) | capsule(grid, pose["far_elbow"], pose["far_wrist"], 4.6)

    warm = (hue < 48) | (hue > 345)
    skin = body & warm & (saturation > 0.24) & (value > 0.50) & (red - blue > 0.10)
    fists = np.zeros_like(body)
    for fist in pose["fists"]:
        fists |= np.hypot(*np.moveaxis(grid - fist, -1, 0)) <= 5.0
    hands = skin & fists

    # 头发：从头上的深色出发，沿着身体轮廓以外、背后的深色往下长（女角的马尾垂在背后）。
    torso = capsule(grid, shoulder + spine * 1.0, belt - spine * 30.0, 8.0, 15.0)
    dark = body & (value < 0.42) & ~skin
    sleeves = ndimage.binary_dilation(arms, iterations=TEXEL)
    core = above_neck & (distance <= 13.0) & ~sleeves
    crown = above_neck & behind & (distance <= 24.0) & ~arms
    seeds = dark & (core | crown)
    grow = dark & ~torso & ~arms & behind & (distance <= 27.0) & (saturation < 0.34)
    labels, _ = ndimage.label(seeds | grow)
    hair = np.isin(labels, np.unique(labels[seeds])) & (labels > 0)
    ribbon = np.zeros_like(body)
    if sex == "female":
        ribbon = body & ((hue < 20) | (hue > 345)) & (saturation > 0.36) & (distance <= 27.0) & ~torso
    head = core | crown | hair | ribbon

    # 靴：小腿下半到脚面。裤脚堆在靴筒上沿，只收最暗的那部分。
    boots = np.zeros_like(body)
    for ankle in pose["ankles"]:
        knee_side = np.array([ankle[0] + (belt[0] - ankle[0]) * 0.13, ankle[1] - 7.6])
        boots |= capsule(grid, knee_side, ankle + np.array([0.0, 1.5]), 5.2, 4.6)
        boots |= capsule(grid, ankle + np.array([-2.5, 1.0]), ankle + np.array([8.5, 2.6]), 3.6, 2.8)
    boots &= body & ~head & (value < 0.34) & (grid[..., 1] > min(a[1] for a in pose["ankles"]) - 9.5)

    # 前臂：近侧在衣襟前，远侧只在轮廓外露出一截。
    forearm = capsule(grid, pose["elbow"] + (pose["wrist"] - pose["elbow"]) * 0.12, pose["wrist"], 3.9, 3.0)
    forearm |= capsule(grid, pose["far_elbow"] + (pose["far_wrist"] - pose["far_elbow"]) * 0.15, pose["far_wrist"], 3.4, 2.8)
    bracers = forearm & body & ~head & ~skin & ~boots

    # 符牌：腰带下面那块铜牌。
    near_belt = capsule(grid, belt + np.array([-3.0, -2.0]), belt + np.array([5.0, 13.0]), 7.5)
    charm = body & near_belt & (hue > 24) & (hue < 56) & (saturation > 0.34) & (value > 0.36) & ~fists & ~head
    charm = ndimage.binary_opening(charm, iterations=1)
    charm = ndimage.binary_dilation(charm, iterations=2) & body & near_belt & ~fists & (value > 0.16) & (saturation > 0.16)

    # 镶边：骨白的交领，加各自的腰带（男靛、女朱）。
    lapel = body & ~head & (value > 0.46) & (saturation < 0.27) & capsule(grid, shoulder + spine * 2.0, belt, 11.0)
    if sex == "male":
        sash = body & ~head & (blue - red > 0.012) & (value > 0.12)
    else:
        sash = body & ~head & ((hue < 22) | (hue > 345)) & (saturation > 0.36) & (value > 0.16) & ~skin
    sash = ndimage.binary_opening(sash, iterations=1)
    sash = ndimage.binary_dilation(sash, iterations=1) & body & ~head & ~skin
    trim = (lapel | sash) & ~charm & ~bracers & ~boots & ~hands

    cloth = body & ~head & ~skin & ~hands & ~boots & ~bracers & ~charm & ~trim
    # 拳头边缘的暗线是手的轮廓，不是袖子。
    cloth &= ~(fists & (np.hypot(*np.moveaxis(grid - pose["fists"][0], -1, 0)) <= 3.4))
    # 半透明的轮廓像素不染：平涂会把它们填成不透明，轮廓就起锯齿；留着原画的深色正好当勾边。
    solid = cell[..., 3] > 0.92
    return {"cloth": cloth & solid, "trim": trim & solid, "bracers": bracers & solid, "boots": boots & solid,
        "charm": charm & solid, "_sash": sash, "_lapel": lapel}


def shade_layer(cell, regions):
    """模板内每个像素该压暗还是提亮多少。各区按自己的明度分布归一，黑袍染出来才不发闷。"""
    luminance = cell[..., :3] @ np.array([0.299, 0.587, 0.114])
    out = {}
    for name in LAYERS:
        mask = regions[name]
        layer = np.zeros(cell.shape, np.float32)
        parts = [(mask, 1.0)]
        if name == "trim":
            # 衣领和腰带各按各的明度归一；腰带压暗一档，免得和衣领抢成一片亮色。
            parts = [(mask & regions["_lapel"], 1.0), (mask & ~regions["_lapel"], 0.80)]
        for part, gain in parts:
            if part.sum() < 8:
                continue
            values = luminance[part]
            ceiling = max(float(np.percentile(values, 96)), 0.05)
            shade = np.clip(luminance / ceiling, 0.0, 1.6) ** 0.92 * gain
            darken = np.clip(1.0 - shade, 0.0, 0.90)
            lighten = np.clip((shade - 1.0) * 0.5, 0.0, 0.30)
            layer[part, 3] = np.maximum(np.where(shade[part] < 1.0, darken[part], lighten[part]), 2.0 / 255.0)
            layer[part, :3] = np.where((shade[part] < 1.0)[:, None], SHADOW, np.array([1.0, 0.97, 0.9]))
        out[name] = layer
    return out


def build(sex, poses):
    sheet = pack(sex)
    pixels = np.asarray(sheet).astype(np.float32) / 255.0
    layers = {name: np.zeros(pixels.shape, np.float32) for name in LAYERS}
    for frame in range(12):
        x, y = (frame % 4) * SIZE, (frame // 4) * SIZE
        cell = pixels[y:y + SIZE, x:x + SIZE]
        shaded = shade_layer(cell, classify(cell, poses[frame], sex))
        for name in LAYERS:
            layers[name][y:y + SIZE, x:x + SIZE] = shaded[name]
    return sheet, {name: Image.fromarray((layer * 255.0 + 0.5).astype(np.uint8), "RGBA") for name, layer in layers.items()}


def dyed(sheet, layers, colors):
    """与 worn_sprites.gd 同一套算法的离线版，只用于出对照图。"""
    out = np.asarray(sheet).astype(np.float32) / 255.0
    out = out.copy()
    for name, color in colors.items():
        layer = np.asarray(layers[name]).astype(np.float32) / 255.0
        stencil = layer[..., 3] > 0
        out[stencil, :3] = np.array(color)
        alpha = layer[..., 3:4]
        out[..., :3] = out[..., :3] * (1 - alpha) + layer[..., :3] * alpha
    return Image.fromarray((out * 255.0 + 0.5).astype(np.uint8), "RGBA")


def hex_color(text):
    return tuple(int(text[i:i + 2], 16) / 255.0 for i in (1, 3, 5))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", help="另存染色对照图的目录")
    args = parser.parse_args()
    poses = joints()
    (HERE / "dye").mkdir(exist_ok=True)
    for sex in ["male", "female"]:
        sheet, layers = build(sex, poses[sex])
        sheet.save(HERE / ("frames-%s.png" % sex), optimize=True)
        for name, layer in layers.items():
            layer.save(HERE / "dye" / ("%s-%s.png" % (sex, name)), optimize=True)
        print("已出图：%s  %dx%d" % (sex, sheet.width, sheet.height))
        if args.preview:
            out = Path(args.preview)
            out.mkdir(parents=True, exist_ok=True)
            robes = {"jin": "#cdb87f", "mu": "#6f9c63", "shui": "#5d87b8", "huo": "#b05a3c", "tu": "#9a7a4c"}
            edges = {"jin": "#ffeeb4", "mu": "#b6f7a4", "shui": "#a8d8ff", "huo": "#ffb07a", "tu": "#f0cf94"}
            strip = Image.new("RGBA", (SIZE * 6, SIZE * 3), (122, 122, 140, 255))
            for column, element in enumerate([None, "jin", "mu", "shui", "huo", "tu"]):
                look = sheet
                if element:
                    trim = "#ffd89a" if column % 2 else "#9fc8d8"
                    look = dyed(sheet, layers, {"cloth": hex_color(robes[element]), "trim": hex_color(trim),
                        "bracers": hex_color(robes[element]), "boots": hex_color(robes[element]),
                        "charm": hex_color(edges[element])})
                for row, frame in enumerate([0, 5, 8]):
                    box = ((frame % 4) * SIZE, (frame // 4) * SIZE, (frame % 4 + 1) * SIZE, (frame // 4 + 1) * SIZE)
                    strip.alpha_composite(look.crop(box), (column * SIZE, row * SIZE))
            strip.save(out / ("dye-%s.png" % sex))
            classes = Image.new("RGBA", sheet.size, (30, 30, 36, 255))
            tints = {"cloth": (90, 120, 220), "trim": (240, 220, 120), "bracers": (120, 220, 140),
                "boots": (220, 110, 90), "charm": (240, 120, 240)}
            base = np.asarray(sheet)
            canvas = np.asarray(classes).copy()
            grey = (base[..., :3].mean(-1, keepdims=True) * 0.6 + 60).astype(np.uint8)
            canvas[base[..., 3] > 128, :3] = np.repeat(grey, 3, -1)[base[..., 3] > 128]
            for name, tint in tints.items():
                canvas[np.asarray(layers[name])[..., 3] > 0, :3] = tint
            Image.fromarray(canvas, "RGBA").save(out / ("classes-%s.png" % sex))


if __name__ == "__main__":
    main()
