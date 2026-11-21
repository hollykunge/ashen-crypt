"""把 gen_hero.sh 出的人物原画裁成游戏用的图。

    python3 art/side/pack_portraits.py                       # 在 mobile 目录下运行：两张半身像
    python3 art/side/pack_portraits.py fullbody-female       # 只出指定的几张
    python3 art/side/pack_portraits.py --dye-only fullbody-male fullbody-female   # 原画不动，只按遮罩重出染色图层
    python3 art/side/pack_portraits.py --dye-only fullbody-male --preview out_dir  # 另存染色分区与五行对照图

半身像 portrait-*：source/hero/portrait-*.png → portrait-*.webp。裁掉透明边，从头顶往下按
宽:高 = 0.81 留到腰带下面，缩到 780 高。行装页按 FACE_X 以脸为中心裁两侧，战斗头像取中间。

全身像 fullbody-*：source/fullbody/fullbody-*.png → fullbody-*.webp。按不透明处的外框裁齐，
缩到 1100 高。行装页（armory_figure.gd）按高度放进格子，女角再按 HEIGHT 矮一截。
全身像同时出五张染色图层 dye/fullbody-<sex>-<区>.png（格式见 shader_layer），行装页的 dye.gdshader 按身上的装备现染。
分区以遮罩 masks/fullbody-<sex>.png 为准，颜色约定和战斗图集一样（见 pack_frames.py）；遮罩不存在时
按 FRONT 里标的画面比例和颜色自动分一次写出来，之后手修遮罩、加 --dye-only 重跑即可（--reclassify 重新自动分区）。
"""
import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import pack_frames  # noqa: E402

ASPECT = 0.81
PORTRAIT_HEIGHT = 780
FULLBODY_HEIGHT = 1100

# 正面全身像的分区，坐标是占画面宽高的比例 (左, 上, 右, 下)。
#   head    颈线以上，脸和头发都不染
#   lapel   交领所在的那一片，里面的骨白布算镶边
#   cuffs   卷起的袖口（男角才有）
#   bracers 两条前臂的绑腕
#   sash    腰带连同垂下的飘带
#   charm   腰间的铜符牌和串珠
#   boots   靴筒上沿以下
#   neck    脖子：除了交领都不染
#   skin    可能露出皮肤的地方（脸、胸口、手臂、手）；别处的暖色是袍子磨旧的毛边，不算皮肤
FRONT = {
    "male": {
        "head": 0.138,
        # 脖子背光，颜色偏暗偏灰，按肤色认不全：这一块里除了交领都不染。
        "neck": [(0.40, 0.127, 0.625, 0.162)],
        "lapel": [(0.33, 0.13, 0.69, 0.37)],
        "cuffs": [(0.0, 0.30, 0.22, 0.41), (0.78, 0.30, 1.0, 0.41)],
        "bracers": [(0.0, 0.395, 0.17, 0.52), (0.83, 0.395, 1.0, 0.52)],
        "sash": (0.27, 0.33, 0.74, 0.76),
        "charm": (0.33, 0.39, 0.44, 0.53),
        "boots": 0.838,
        "skin": [(0.36, 0.0, 0.64, 0.32), (0.0, 0.37, 0.24, 0.62), (0.76, 0.37, 1.0, 0.62)],
    },
    "female": {
        "head": 0.165,
        "neck": [],
        "lapel": [(0.40, 0.16, 0.72, 0.23), (0.43, 0.23, 0.72, 0.33)],
        "cuffs": [],
        "bracers": [(0.0, 0.375, 0.155, 0.52), (0.835, 0.375, 1.0, 0.52)],
        "sash": (0.30, 0.30, 1.0, 0.90),
        "charm": (0.34, 0.37, 0.49, 0.535),
        "boots": 0.855,
        "skin": [(0.38, 0.0, 0.66, 0.31), (0.0, 0.43, 0.20, 0.60), (0.80, 0.43, 1.0, 0.60)],
    },
}


def opaque_box(art):
    return art.getchannel("A").point(lambda a: 255 if a > 24 else 0).getbbox()


def portrait(sex):
    art = Image.open(HERE / "source" / "hero" / ("portrait-%s.png" % sex)).convert("RGBA")
    left, top, right, bottom = opaque_box(art)
    width = right - left
    height = min(bottom - top, round(width / ASPECT))
    crop = art.crop((left, top, right, top + height))
    return crop.resize((round(crop.width * PORTRAIT_HEIGHT / crop.height), PORTRAIT_HEIGHT), Image.LANCZOS)


def fullbody(sex):
    art = Image.open(HERE / "source" / "fullbody" / ("fullbody-%s.png" % sex)).convert("RGBA")
    crop = art.crop(opaque_box(art))
    return crop.resize((round(crop.width * FULLBODY_HEIGHT / crop.height), FULLBODY_HEIGHT), Image.LANCZOS)


def boxes(shape, rects):
    """几个按比例给的矩形合成一张遮罩。"""
    height, width = shape
    mask = np.zeros(shape, bool)
    for left, top, right, bottom in rects:
        mask[round(top * height):round(bottom * height), round(left * width):round(right * width)] = True
    return mask


def classify_front(pixels, sex):
    """正面全身像分出五个染色区。思路同 pack_frames.classify：先按颜色和位置粗分，再 tidy 收成整块。"""
    zone = FRONT[sex]
    shape = pixels.shape[:2]
    rgb = pixels[..., :3]
    body = pixels[..., 3] > 0.5
    peak, low = rgb.max(-1), rgb.min(-1)
    value = peak
    saturation = np.where(peak > 0, (peak - low) / np.maximum(peak, 1e-6), 0.0)
    red, green, blue = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hue = np.degrees(np.arctan2(np.sqrt(3) * (green - blue), 2 * red - green - blue)) % 360
    ys = (np.arange(shape[0])[:, None] + 0.5) / shape[0] * np.ones((1, shape[1]))

    head = body & (ys < zone["head"])
    # 皮肤：暖色、够亮、够艳，而且在露肉的地方。连成一片的才算，零星几点是布上的反光。
    # 朱红的飘带垂到手边，比皮肤更红更艳，先从「暖色」里剔掉。
    warm = ((hue < 45) | (hue > 350)) & ~(((hue < 12) | (hue > 340)) & (saturation > 0.35))
    skin = body & boxes(shape, zone["skin"]) & warm & (saturation > 0.26) & (value > 0.40) & (red - blue > 0.12)
    # 背光的脖子、指缝暗一些，挨着亮皮肤的才收进来，免得把磨旧的褐色袍边也算成肉。
    shaded = body & boxes(shape, zone["skin"]) & warm & (saturation > 0.30) & (value > 0.20) & (red - blue > 0.07)
    skin |= shaded & ndimage.binary_dilation(skin, iterations=8)
    skin = ndimage.binary_opening(skin, iterations=1)
    skin = ndimage.binary_closing(skin, iterations=2) & body
    skin = pack_frames.drop_specks(skin, 120)
    garment = body & ~head & ~skin

    # 靴：靴筒上沿以下全是靴子，脚下没有别的布。
    boots = garment & (ys > zone["boots"])

    # 符牌：铜黄、发亮，在腰间那一小块里。串珠细，靠膨胀连上。
    charm_zone = boxes(shape, [zone["charm"]])
    charm = garment & charm_zone & (hue > 18) & (hue < 60) & (saturation > 0.28) & (value > 0.30)
    charm = ndimage.binary_opening(charm, iterations=1)
    charm = ndimage.binary_dilation(charm, iterations=3) & garment & charm_zone & (value > 0.14)
    charm = ndimage.binary_fill_holes(charm)

    # 绑腕：前臂那一段里不是皮肤的都算。
    bracers = garment & boxes(shape, zone["bracers"]) & ~charm

    # 镶边：交领和袖口的骨白布，先挑亮的再往相连的稍暗处长；腰带按色相。
    pale = garment & (saturation < 0.34)
    pale_zone = boxes(shape, zone["lapel"] + zone["cuffs"])
    lapel = pale & pale_zone & (value > 0.42)
    lapel = ndimage.binary_opening(lapel, iterations=1)
    lapel |= pale & pale_zone & (value > 0.28) & ndimage.binary_dilation(lapel, iterations=6)
    lapel = ndimage.binary_closing(lapel, iterations=3) & garment & pale_zone
    lapel = ndimage.binary_fill_holes(lapel) & garment
    # 每个框里只留成条的大块：胸口、膝头的高光也是浅色低饱和，零星挑出来会染成一块块镶边色。
    kept = np.zeros_like(lapel)
    for rect in zone["lapel"] + zone["cuffs"]:
        inside = lapel & boxes(shape, [rect])
        labels, count = ndimage.label(inside)
        if count:
            sizes = ndimage.sum(inside, labels, np.arange(1, count + 1))
            least = max(300.0, 0.2 * float(sizes.max()))
            kept |= np.isin(labels, np.flatnonzero(sizes >= least) + 1)
    # 交领上磨出来的暗斑也是交领的一部分，补上，免得领子上点着几粒袍色。
    lapel = ndimage.binary_fill_holes(ndimage.binary_closing(kept, iterations=3)) & garment
    sash_zone = boxes(shape, [zone["sash"]])
    # 先挑颜色最正的当种子，再沿着相连的、同一色系但更暗更旧的像素长出去：飘带末端磨得发黑发灰，
    # 只按严格的阈值挑，尾巴会断成几截，剩下的染成袍色。
    if sex == "male":
        # 靛蓝腰带：比袍子偏冷偏紫。
        seed = garment & sash_zone & ((hue > 200) & (hue < 345) | (blue - red > 0.0)) & (value > 0.08)
        family = garment & sash_zone & ((hue > 190) & (hue < 352) | (blue - red > -0.012)) & (value > 0.04)
    else:
        seed = garment & sash_zone & ((hue < 14) | (hue > 340)) & (saturation > 0.36) & (value > 0.16)
        # 女角的袍子本身就偏红褐，色系放宽了会顺着长满整条裙子：饱和度要高过袍子，也只许离种子不远。
        family = garment & sash_zone & ((hue < 16) | (hue > 335)) & (saturation > 0.30) & (value > 0.08)
    seed = pack_frames.drop_specks(ndimage.binary_opening(seed, iterations=2), 400)
    family &= ndimage.binary_dilation(seed, iterations=12)
    sash = ndimage.binary_propagation(seed, mask=family)
    sash = ndimage.binary_closing(sash, iterations=5)
    sash = ndimage.binary_fill_holes(sash) & garment & sash_zone
    sash = pack_frames.drop_specks(sash, 400)
    trim = (lapel | sash) & ~charm & ~bracers & ~boots

    cloth = garment & ~boots & ~bracers & ~charm & ~trim
    solid = pixels[..., 3] > 0.92
    neck = boxes(shape, zone["neck"]) & ~trim
    regions = pack_frames.tidy({"cloth": cloth & ~neck, "trim": trim, "bracers": bracers, "boots": boots, "charm": charm},
        garment & solid & ~neck)
    regions["_sash"] = sash
    regions["_lapel"] = lapel
    return regions


def dye_layers(image, sex, reclassify=False):
    pixels = np.asarray(image).astype(np.float32) / 255.0
    mask_path = pack_frames.MASK_DIR / ("fullbody-%s.png" % sex)
    if reclassify or not mask_path.exists():
        pack_frames.write_mask(mask_path, classify_front(pixels, sex))
        print("已按颜色和位置自动分区：masks/fullbody-%s.png" % sex)
    regions = pack_frames.read_mask(mask_path, pixels)
    shaded = pack_frames.shade_layer(pixels, regions)
    return regions, {name: Image.fromarray((layer * 255.0 + 0.5).astype(np.uint8)) for name, layer in shaded.items()}


# 着色器用的图层格式。战斗图集那种「不透明度既管在不在区里、又管压暗多少」的图层，缩小取样时边上
# 被透明处摊薄，压暗跟着减半，黑袍染完就镶一圈亮边。全身像只给 dye.gdshader 用，改成各管各的：
#   A 在不在这一区（0 或 1）   R 压暗多少（向 SHADOW）   G 提亮多少（向 HIGHLIGHT，满格是 LIGHTEN_MAX）
# 区外的 R、G 从最近的区内像素抄过来，取样跨过边界时明暗不被摊薄。
LIGHTEN_MAX = 0.30


def shader_layer(layer, region):
    values = np.asarray(layer).astype(np.float32) / 255.0
    dark = values[..., 0] < 0.5
    out = np.zeros(values.shape, np.float32)
    out[..., 0] = np.where(region & dark, values[..., 3], 0.0)
    out[..., 1] = np.where(region & ~dark, values[..., 3] / LIGHTEN_MAX, 0.0)
    out[..., 3] = region
    if region.any():
        _, (iy, ix) = ndimage.distance_transform_edt(~region, return_indices=True)
        out[..., :3] = out[iy, ix, :3]
    return Image.fromarray((np.clip(out, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8))


def preview(image, layers, regions, sex, out):
    out.mkdir(parents=True, exist_ok=True)
    tints = {"cloth": (90, 120, 220), "trim": (240, 220, 120), "bracers": (120, 220, 140),
        "boots": (220, 110, 90), "charm": (240, 120, 240)}
    base = np.asarray(image).copy()
    for name, tint in tints.items():
        base[regions[name], :3] = (np.array(tint) * 0.7 + base[regions[name], :3] * 0.3).astype(np.uint8)
    looks = [image, Image.fromarray(base)]
    for robe, trim in [("#8f3f2c", "#a9c3cc"), ("#5b7f5c", "#efd9a8"), ("#3d5680", "#efd9a8")]:
        colors = {name: pack_frames.hex_color(robe) for name in ["cloth", "bracers", "boots"]}
        colors["trim"] = pack_frames.hex_color(trim)
        colors["charm"] = pack_frames.hex_color("#f2a083")
        looks.append(pack_frames.dyed(image, layers, colors))
    strip = Image.new("RGBA", (image.width * len(looks), image.height), (110, 110, 130, 255))
    for index, look in enumerate(looks):
        strip.alpha_composite(look.convert("RGBA"), (index * image.width, 0))
    strip.save(out / ("fullbody-%s.png" % sex))


JOBS = {"portrait-male": lambda: portrait("male"), "portrait-female": lambda: portrait("female"),
    "fullbody-male": lambda: fullbody("male"), "fullbody-female": lambda: fullbody("female")}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("jobs", nargs="*", default=["portrait-male", "portrait-female"])
    parser.add_argument("--preview", help="另存全身像染色对照图的目录")
    parser.add_argument("--dye-only", action="store_true", help="不重出原画，只按现有的全身像和遮罩出染色图层")
    parser.add_argument("--reclassify", action="store_true", help="重新自动分区，覆盖 masks/ 里的遮罩")
    args = parser.parse_args()
    for name in args.jobs:
        if not args.dye_only:
            image = JOBS[name]()
            image.save(HERE / ("%s.webp" % name), lossless=False, quality=90)
            print("已出图 %s.webp %dx%d" % (name, image.width, image.height))
        if name.startswith("fullbody-"):
            sex = name.split("-")[1]
            # 图层按游戏里实际读到的那张（有损压缩后）来分，明暗才和底图对得上。
            shipped = Image.open(HERE / ("%s.webp" % name)).convert("RGBA")
            regions, layers = dye_layers(shipped, sex, args.reclassify)
            for layer, picture in layers.items():
                shader_layer(picture, regions[layer]).save(HERE / "dye" / ("%s-%s.png" % (name, layer)), optimize=True)
            print("已出图 dye/%s-*.png" % name)
            if args.preview:
                preview(shipped, layers, regions, sex, Path(args.preview))


if __name__ == "__main__":
    main()
