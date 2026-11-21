"""把四面设定图里的侧面像切成可以挂骨骼的零件。

原画是正侧面、双臂下垂，和 build_hero.py 的骨骼静止姿势一致，所以每块零件直接按原画位置
贴到对应的骨头上，画上的褶皱、脸和绑腿都跟着骨头动。要处理的只有三件事：
  1. 去掉灰底。
  2. 胳膊、手盖住的那块躯干、袍子要补出来，不然胳膊一抬，身上还留着一条画上去的胳膊。
     补法是从四周往里扩散颜色，再撒一点颗粒，手机上看是一片旧布。
  3. 大腿藏在袍子后面，原画上没有。用露出来的裤腿往上接。
另外按颜色和部位分出染色区（袍裤、镶边腰带、护腕、靴、符牌），每块零件出一张同位置的分区图。
原画是张开的手，握不住剑：把手指压扁成一排蜷起的指节，改成拳头。

用法：python3 cut_parts.py  → 写出 parts/*.png 与 parts.json
"""

import json
import os
from collections import deque

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
SIDE = os.path.join(HERE, "..")
OUT = os.path.join(HERE, "parts")
# 侧面像在设定图里的范围（避开左右两个人像），以及像素到米的换算：脚底 y=988 是地面，x=960 是身体中轴。
CROP = (805, 0, 1120, 1000)
GROUND_Y = 988
AXIS_X = 960
METERS_PER_PIXEL = 0.00205

# 零件：骨头、前后（y，越小越靠镜头）、多边形（设定图坐标）。远侧的胳膊和腿用近侧的图，压暗。
POLYS = {
    "head": [(880, 12), (1005, 12), (1045, 85), (1040, 140), (1010, 152), (965, 165), (930, 152), (875, 120), (855, 75)],
    "torso_upper": [(890, 130), (1000, 130), (1035, 175), (1055, 240), (1060, 330), (870, 330), (862, 250), (875, 175)],
    "torso_lower": [(868, 300), (1060, 300), (1068, 360), (1062, 420), (872, 420), (866, 360)],
    "robe": [(872, 395), (1062, 395), (1075, 450), (1085, 560), (1092, 700), (1080, 770), (1040, 750), (1000, 765),
             (900, 765), (868, 785), (820, 775), (826, 650), (848, 560), (862, 470)],
    "upper_arm": [(905, 188), (985, 183), (1025, 213), (1037, 260), (1012, 322), (994, 352), (992, 390), (975, 405),
                  (925, 405), (905, 372), (884, 352), (879, 300), (881, 240)],
    "forearm": [(912, 372), (987, 372), (994, 410), (1006, 468), (1013, 508), (996, 528), (958, 528), (948, 490),
                (928, 440), (910, 405)],
    "thigh": [(890, 500), (1005, 500), (1008, 640), (1002, 770), (890, 770), (884, 640)],
    "shin": [(888, 735), (1004, 735), (1000, 800), (978, 842), (964, 900), (968, 938), (902, 938), (898, 880), (892, 820)],
    "foot": [(893, 922), (968, 918), (1002, 934), (1042, 954), (1044, 987), (900, 994), (890, 960)],
}
# 手的范围（只用来从躯干、袍子上抠掉原画的手，零件本身换成拳头）。
# 镶边、腰带、袖口：颜色和袍子差得不多，按部位圈出来，再用亮度把布和缝隙分开。
SASH = [(866, 368), (1066, 372), (1068, 412), (868, 414)]
CUFF = [(886, 316), (996, 312), (1002, 372), (900, 380)]
COLLAR = [(945, 132), (1012, 138), (1052, 238), (1064, 330), (1034, 332), (1008, 242), (972, 172)]
HAND = [(952, 498), (1014, 496), (1025, 530), (1022, 562), (1006, 578), (978, 578), (962, 562), (955, 530)]
# 拳头从原画这只手改出来：手背（y 512~546，连着绑腕下沿）原样保留，下垂的手指（546~580）
# 压扁成一排蜷起的指节，再修成圆角。剑柄从指节那一排横穿过去，GRIP 就是那儿。
FIST_BOX = (950, 512, 1020)
FIST_SPLIT = 546
FIST_BOTTOM = 580
FIST_CURL = 17
GRIP = (987, 553)

# 骨头（设定图坐标，头 → 尾），与 build_hero.py 共用。
BONES = {
    "hips": ((960, 520), (960, 440)),
    "spine": ((960, 440), (965, 300)),
    "chest": ((965, 300), (975, 175)),
    "neck": ((975, 175), (980, 140)),
    "head": ((980, 140), (970, 40)),
    "upper_arm": ((955, 225), (950, 388)),
    "forearm": ((950, 388), (985, 515)),
    "hand": ((985, 515), (1000, 565)),
    "thigh": ((952, 520), (945, 755)),
    "shin": ((945, 755), (935, 940)),
    "foot": ((935, 940), (1030, 975)),
}

PARTS = [
    # 名字, 图, 骨头, 前后
    ("arm_far", "upper_arm", "upper_arm.L", 0.34),
    ("forearm_far", "forearm", "forearm.L", 0.35),
    ("fist_far", "fist", "hand.L", 0.36),
    ("thigh_far", "thigh", "thigh.L", 0.14),
    ("shin_far", "shin", "shin.L", 0.15),
    ("foot_far", "foot", "foot.L", 0.16),
    ("torso_lower", "torso_lower", "spine", 0.01),
    ("torso_upper", "torso_upper", "chest", 0.0),
    ("head", "head", "head", -0.04),
    ("thigh", "thigh", "thigh.R", -0.12),
    ("shin", "shin", "shin.R", -0.13),
    ("foot", "foot", "foot.R", -0.14),
    ("robe", "robe", "skirt", -0.2),
    ("upper_arm", "upper_arm", "upper_arm.R", -0.34),
    ("forearm", "forearm", "forearm.R", -0.35),
    ("fist", "fist", "hand.R", -0.37),
]
FAR_SHADE = 0.62

ID_COLORS = {"none": (0, 0, 0), "cloth": (255, 0, 0), "trim": (0, 255, 0), "bracers": (0, 0, 255),
             "boots": (255, 255, 0), "charm": (255, 0, 255)}


def polygon_mask(points, size, offset):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).polygon([(x - offset[0], y - offset[1]) for x, y in points], fill=255)
    return np.array(mask) > 0


def remove_background(rgb):
    """从边框往里灌：和底色相近、又连着边框的像素当背景。"""
    height, width, _ = rgb.shape
    background = np.median(np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]]), axis=0)
    close = np.linalg.norm(rgb.astype(float) - background, axis=2) < 26
    seen = np.zeros((height, width), bool)
    queue = deque()
    for x in range(width):
        for y in (0, height - 1):
            if close[y, x]:
                seen[y, x] = True
                queue.append((y, x))
    for y in range(height):
        for x in (0, width - 1):
            if close[y, x] and not seen[y, x]:
                seen[y, x] = True
                queue.append((y, x))
    while queue:
        y, x = queue.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < height and 0 <= nx < width and close[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                queue.append((ny, nx))
    alpha = Image.fromarray(np.where(seen, 0, 255).astype(np.uint8))
    # 收一像素再柔一下边，去掉灰底残边。
    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.7))
    return np.array(alpha)


def fill(rgb, hole, rng, grain_patch=None):
    """从洞的四周往里扩散颜色：先在缩小的图上填满，再逐级放大细化，最后叠上借来的布纹。"""
    image = rgb.astype(float)
    known = ~hole
    levels = []
    current_image, current_known = image.copy(), known.copy()
    while min(current_known.shape) > 8:
        levels.append((current_image, current_known))
        h, w = current_known.shape
        weights = current_known.astype(float)
        summed = current_image * weights[..., None]
        h2, w2 = h // 2, w // 2
        summed = summed[:h2 * 2, :w2 * 2].reshape(h2, 2, w2, 2, 3).sum((1, 3))
        count = weights[:h2 * 2, :w2 * 2].reshape(h2, 2, w2, 2).sum((1, 3))
        current_image = np.where(count[..., None] > 0, summed / np.maximum(count, 1)[..., None], 0)
        current_known = count > 0
    coarse = current_image
    for level_image, level_known in reversed(levels):
        h, w = level_known.shape
        up = np.array(Image.fromarray(np.clip(coarse, 0, 255).astype(np.uint8)).resize((w, h), Image.BILINEAR)).astype(float)
        coarse = np.where(level_known[..., None], level_image, up)
    grain = rng.normal(0, 4, coarse.shape[:2])[..., None]
    if grain_patch is not None:
        # 布纹 = 一块袍子减去它自己的模糊，只留褶皱和磨损的细节，平铺进洞里。
        patch = grain_patch.astype(float)
        blurred = np.array(Image.fromarray(grain_patch).filter(ImageFilter.GaussianBlur(6))).astype(float)
        detail = (patch - blurred).mean(axis=2, keepdims=True)
        reps = (coarse.shape[0] // detail.shape[0] + 1, coarse.shape[1] // detail.shape[1] + 1, 1)
        grain = grain + np.tile(detail, reps)[:coarse.shape[0], :coarse.shape[1]] * 1.1
    result = np.where(hole[..., None], np.clip(coarse + grain, 0, 255), image)
    return result.astype(np.uint8)


def classify(rgb, alpha, offset):
    """按颜色和部位分染色区。"""
    r, g, b = [rgb[..., i].astype(int) for i in range(3)]
    height, width = alpha.shape
    ys, xs = np.mgrid[0:height, 0:width]
    ys = ys + offset[1]
    xs = xs + offset[0]
    luma = 0.299 * r + 0.587 * g + 0.114 * b
    spread = np.max(rgb, axis=2).astype(int) - np.min(rgb, axis=2).astype(int)
    skin = (r > g) & (g > b) & (r - b > 38) & (r > 95)
    zone = np.full((height, width), "cloth", dtype=object)
    sash = polygon_mask(SASH, (width, height), offset)
    cuff = polygon_mask(CUFF, (width, height), offset) & (luma > 80)
    collar = polygon_mask(COLLAR, (width, height), offset) & (luma > 70)
    # 身后飘的腰带尾巴偏蓝紫。
    tails = (xs < 900) & (ys > 540) & (b >= r - 2) & (b > g)
    zone[sash | cuff | collar | tails] = "trim"
    forearm = polygon_mask(POLYS["forearm"], (width, height), offset)
    zone[forearm & ~skin & (luma > 60)] = "bracers"
    zone[ys > 842] = "boots"
    charm = (xs > 1036) & (xs < 1078) & (ys > 420) & (ys < 512) & (r - b > 20)
    zone[charm] = "charm"
    zone[skin & ~charm] = "none"
    zone[(ys < 150)] = "none"
    ids = np.zeros((height, width, 3), np.uint8)
    for name, color in ID_COLORS.items():
        ids[zone == name] = color
    return ids


def to_meters(point):
    return [round((point[0] - AXIS_X) * METERS_PER_PIXEL, 4), round((GROUND_Y - point[1]) * METERS_PER_PIXEL, 4)]


def main():
    os.makedirs(OUT, exist_ok=True)
    rng = np.random.default_rng(7)
    sheet = Image.open(os.path.join(SIDE, "source", "hero", "turnaround-male.png")).convert("RGB")
    crop = np.array(sheet.crop(CROP))
    offset = CROP[:2]
    size = (crop.shape[1], crop.shape[0])
    alpha = remove_background(crop)
    ids = classify(crop, alpha, offset)

    arm = polygon_mask(POLYS["upper_arm"], size, offset) | polygon_mask(POLYS["forearm"], size, offset)
    hand = polygon_mask(HAND, size, offset)
    # 身子那一层：抠掉胳膊和手，补出底下的衣服；补出的地方按周围定成袍色（染色区也补成 cloth）。
    body_hole = (arm | hand) & (alpha > 0)
    robe_patch = crop[600 - offset[1]:720 - offset[1], 870 - offset[0]:940 - offset[0]]
    body = fill(crop, body_hole, rng, robe_patch)
    body_ids = ids.copy()
    body_ids[body_hole] = ID_COLORS["cloth"]
    body_alpha = alpha.copy()
    body_alpha[arm | hand] = 255
    # 腿那一层：袍子下摆以上没有画，用 y 760~830 的裤腿往上平铺。
    legs = crop.copy()
    legs_ids = ids.copy()
    legs_alpha = alpha.copy()
    thigh = polygon_mask(POLYS["thigh"], size, offset)
    sample_top, sample_bottom = 765 - offset[1], 830 - offset[1]
    band = crop[sample_top:sample_bottom]
    for y in range(500 - offset[1], sample_top):
        row = band[(sample_top - y) % (sample_bottom - sample_top)]
        legs[y][thigh[y]] = row[thigh[y]]
        legs_ids[y][thigh[y]] = ID_COLORS["cloth"]
        legs_alpha[y][thigh[y]] = 255
    layers = {"body": (body, body_ids, body_alpha), "arm": (crop, ids, alpha), "legs": (legs, legs_ids, legs_alpha)}
    source_of = {"head": "body", "torso_upper": "body", "torso_lower": "body", "robe": "body",
                 "upper_arm": "arm", "forearm": "arm", "thigh": "legs", "shin": "legs", "foot": "legs"}

    meta = {"meters_per_pixel": METERS_PER_PIXEL, "ground_y": GROUND_Y, "axis_x": AXIS_X,
            "bones": {name: [to_meters(a), to_meters(b)] for name, (a, b) in BONES.items()}, "parts": []}

    cuts = {}
    for name, points in POLYS.items():
        rgb, zone, layer_alpha = layers[source_of[name]]
        mask = polygon_mask(points, size, offset)
        # 零件边缘柔一点，关节处叠在一起不露缝。
        soft = np.array(Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2)))
        part_alpha = (layer_alpha.astype(float) * soft / 255.0).astype(np.uint8)
        x0, y0 = min(p[0] for p in points) - 4, min(p[1] for p in points) - 4
        x1, y1 = max(p[0] for p in points) + 4, max(p[1] for p in points) + 4
        box = (x0 - offset[0], y0 - offset[1], x1 - offset[0], y1 - offset[1])
        color = np.dstack([rgb, part_alpha])[box[1]:box[3], box[0]:box[2]]
        zone_rgba = np.dstack([zone, (part_alpha > 8).astype(np.uint8) * 255])[box[1]:box[3], box[0]:box[2]]
        cuts[name] = (Image.fromarray(color), Image.fromarray(zone_rgba), (x0, y0, x1, y1))

    # 拳头：手背原样，手指压扁成指节，圆角修边，底下压一道蜷指的暗影。
    x0f, y0f, x1f = FIST_BOX
    back = sheet.crop((x0f, y0f, x1f, FIST_SPLIT))
    fingers = sheet.crop((x0f, FIST_SPLIT, x1f, FIST_BOTTOM)).resize((x1f - x0f, FIST_CURL), Image.LANCZOS)
    fist = Image.new("RGB", (x1f - x0f, back.size[1] + FIST_CURL))
    fist.paste(back, (0, 0))
    fist.paste(fingers, (0, back.size[1]))
    rgb = np.array(fist).astype(float)
    rows = rgb.shape[0]
    for row in range(rows - 6, rows):
        rgb[row] *= 0.62 + 0.06 * (rows - row)
    outline = Image.new("L", fist.size, 0)
    ImageDraw.Draw(outline).rounded_rectangle((3, 0, fist.size[0] - 2, fist.size[1] - 1), radius=14, fill=255)
    outline = outline.filter(ImageFilter.GaussianBlur(0.8))
    fist = Image.fromarray(np.dstack([np.clip(rgb, 0, 255).astype(np.uint8), np.array(outline)]))
    fist_ids = Image.new("RGBA", fist.size, (0, 0, 0, 0))
    fist_ids.putalpha(outline.point(lambda a: 255 if a > 8 else 0))
    fx0, fy0 = x0f, y0f
    cuts["fist"] = (fist, fist_ids, (fx0, fy0, fx0 + fist.size[0], fy0 + fist.size[1]))
    meta["grip"] = to_meters(GRIP)

    for name, image_name, bone, depth in PARTS:
        color, zone, box = cuts[image_name]
        far = name.endswith("_far")
        if far:
            color = color.copy()
            rgb = np.array(color).astype(float)
            rgb[..., :3] *= FAR_SHADE
            color = Image.fromarray(rgb.astype(np.uint8))
        color.save(os.path.join(OUT, name + ".png"))
        zone.save(os.path.join(OUT, name + "-ids.png"))
        meta["parts"].append({"name": name, "bone": bone, "depth": depth,
                              "min": to_meters((box[0], box[3])), "max": to_meters((box[2], box[1]))})
    with open(os.path.join(HERE, "parts.json"), "w") as handle:
        json.dump(meta, handle, indent=1, ensure_ascii=False)
    print("cut", len(meta["parts"]), "parts")


main()
