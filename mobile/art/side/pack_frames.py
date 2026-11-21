"""把男女修行人的原画拼成游戏用的高清图集，并按分区遮罩出可以按装备染色的衣料图层。

    python art/side/pack_frames.py                       # 在 mobile 目录下运行
    python art/side/pack_frames.py --preview out_dir     # 另存五行染色的对照图
    python art/side/pack_frames.py --reclassify          # 丢掉手修过的遮罩，按颜色和关节重新自动分区

原画是 source/frames-*.png（1536×1024，4 列 × 3 行，gen_hero.sh 按 hero-prompts.json 出图）。游戏里每格的逻辑尺寸是 96×96，
脚底锚点、握点和关节坐标都按这个尺寸标在脚本里（side_art.gd / held_weapon.gd / worn_sprites.gd）。
这里按 TEXEL 倍输出贴图，逻辑坐标不变，所以那些标定不用动。

分区遮罩 masks/<sex>.png 是「哪块布染什么」的唯一依据，和图集一样大，每个像素涂一种纯色（MASK_COLORS）：
    蓝 cloth  袍、裤、袖        绿 bracers 绑腕
    黄 collar 交领、袖口        红 boots   靴
    橙 sash   腰带和飘带        紫 charm   腰间符牌
    透明      不染（脸、手、头发、皮肤）
遮罩不存在时按颜色和关节自动分一次写出来；之后在 Krita / Photoshop 里把图集垫在下面、对着修遮罩，
再跑一遍本脚本即可，脚本不会覆盖已有的遮罩（除非加 --reclassify）。

每个性别输出六张图：
    frames-<sex>.png          底图，TEXEL×96 一格
    dye/<sex>-cloth.png       袍、裤、袖       → 护甲的袍色
    dye/<sex>-trim.png        交领、袖口、腰带 → 阴阳镶边色
    dye/<sex>-bracers.png     前臂             → 护手
    dye/<sex>-boots.png       靴               → 鞋子
    dye/<sex>-charm.png       腰间符牌         → 项链
染色图层同时是「哪里染」的模板（alpha 不为 0 处）和「怎么留明暗」的叠色：先在模板内平涂染料，
再把这张图叠回去——黑的地方压暗、白的地方提亮，等于染料乘以原画的明暗。
战斗图集在换装时由 worn_sprites.gd 合成一次；行装页的全身像由 dye.gdshader 每帧现染。
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
# 每个性别一个缩放；各格按脚底落在 PIVOT、轮廓与上一版最贴合来定偏移，关节和握点再按新原画逐格重标。
LAYOUT = {
    "male": [
        (0.2362, -6.52, -50.73), (0.2362, 357.01, -50.73), (0.2362, 746.60, -50.73), (0.2362, 1134.46, -50.73),
        (0.2362, -22.24, 291.27), (0.2362, 352.97, 291.27), (0.2362, 746.86, 291.27), (0.2362, 1128.41, 291.27),
        (0.2362, -0.61, 630.27), (0.2362, 354.81, 630.27), (0.2362, 730.99, 630.27), (0.2362, 1126.01, 630.27),
    ],
    "female": [
        (0.2264, -13.50, -67.08), (0.2264, 359.75, -67.08), (0.2264, 749.50, -67.08), (0.2264, 1129.42, -67.08),
        (0.2264, -27.62, 274.92), (0.2264, 354.17, 274.92), (0.2264, 745.92, 274.92), (0.2264, 1129.17, 274.92),
        (0.2264, -11.54, 618.92), (0.2264, 361.33, 618.92), (0.2264, 716.75, 618.92), (0.2264, 1131.50, 618.92),
    ],
}
# 每格的头心（逻辑坐标）。人物是侧身略带四分之三，头比近肩靠前得多，按肩膀推算会偏，所以逐格标出。
HEADS = {
    "male": [(53, 24), (53, 24), (55, 24), (56, 34), (52, 28), (55, 35),
             (55, 38), (56, 27), (30, 33), (33, 29), (51, 26), (54, 25)],
    "female": [(46, 24), (49, 24), (48, 24), (49, 33), (51, 25), (50, 30),
               (49, 33), (48, 25), (31, 32), (33, 29), (49, 27), (47, 24)],
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
            "fists": [lead[index, f], support[index, f]], "head": np.array(HEADS[sex][f], float)} for f in range(12)]
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
    return Image.fromarray(pixels.astype(np.uint8))


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
    centre = pose["head"]
    above_neck = (grid - (centre - spine * 7.0)) @ spine > 0
    forward = np.array([-spine[1], spine[0]])
    if forward[0] < 0:
        forward = -forward
    distance = np.hypot(*np.moveaxis(grid - centre, -1, 0))
    behind = (grid - shoulder) @ forward < 1.5
    arms = capsule(grid, shoulder, pose["elbow"], 5.0) | capsule(grid, pose["elbow"], pose["wrist"], 4.6)
    arms |= capsule(grid, shoulder, pose["far_elbow"], 5.0) | capsule(grid, pose["far_elbow"], pose["far_wrist"], 4.6)

    warm = (hue < 48) | (hue > 345)
    skin = body & warm & (saturation > 0.24) & (value > 0.50) & (red - blue > 0.10)
    if sex == "female":
        # 女角肤色白，领口露出的胸口饱和度低，和骨白的交领只差一点暖色。
        # 但前臂上的米色绑腕也是这个颜色：前臂那一段（拳头除外）不用这条放宽的规则。
        wrists = np.zeros_like(body)
        for elbow, wrist in [(pose["elbow"], pose["wrist"]), (pose["far_elbow"], pose["far_wrist"])]:
            wrists |= capsule(grid, elbow, wrist, 5.5, 4.5)
        for fist in pose["fists"]:
            wrists &= np.hypot(*np.moveaxis(grid - fist, -1, 0)) > 4.0
        skin |= body & warm & (saturation > 0.17) & (value > 0.55) & (red - blue > 0.13) & ~wrists
    if sex == "male":
        # 男角脖子在耳下背光，偏暗，头心附近暗一点的暖色也算皮肤（袍子是冷灰，不会混进来）。
        skin |= body & warm & (saturation > 0.30) & (value > 0.22) & (red - blue > 0.08) & (distance <= 12.0)
    fists = np.zeros_like(body)
    for fist in pose["fists"]:
        fists |= np.hypot(*np.moveaxis(grid - fist, -1, 0)) <= 5.0
    hands = skin & fists

    # 头发：从头上的深色出发，沿着身体轮廓以外、背后的深色往下长（女角的马尾垂在背后）。
    torso = capsule(grid, shoulder + spine * 1.0, belt - spine * 30.0, 8.0, 15.0)
    dark = body & (value < 0.42) & ~skin
    sleeves = ndimage.binary_dilation(arms, iterations=TEXEL)
    # 脸贴着近肩时（前冲那格），肩头的袖子范围会盖到下巴，头心附近一律算头。
    core = above_neck & (distance <= 13.0) & (~sleeves | (distance <= 7.0))
    crown = above_neck & behind & (distance <= 24.0) & ~arms
    seeds = dark & (core | crown)
    grow = dark & ~torso & ~arms & behind & (distance <= 27.0) & (saturation < 0.34)
    if sex == "male":
        # 男角只有发髻，不披发，肩又宽又高：前倾时背后的黑领口、肩头都挨着头心，按女角那套会被当成头发、
        # 整块漏染。所以男角的头收紧成一个圆，头发只在头心水平线以上找（按画面水平，不按脊线：
        # 身子前倾时脊线是斜的，沿它划的线在背后会低到肩头）。
        crown_line = grid[..., 1] < centre[1] + 1.0
        # 头心水平线以下是脸、下巴和脖子，紧挨着衣领和肩头：低头、前冲的几格里，按圆圈划会把领口和后肩
        # 一起划进头里，整块漏染。这里只认长得像脸的：皮肤，加上眉眼、胡茬那些极暗的点（袍子没那么黑），
        # 以及被它们围起来的地方。
        face = (skin | (body & (value < 0.14))) & ~crown_line & (distance <= 11.5)
        face = ndimage.binary_closing(face, iterations=2)
        face = ndimage.binary_fill_holes(face) & body & (distance <= 12.0)
        # 后脑勺下半那一角挨着后领：那里只认比袍子更黑的头发和皮肤。
        nape = ((grid - centre) @ forward < -3.0) & (grid[..., 1] > centre[1] - 2.0)
        back_hair = skin | (body & (value < 0.19))
        core = (crown_line & (distance <= 10.5) & (~nape | back_hair)) | face | (distance <= 6.0)
        # 发髻和头顶在眉线以上，能伸得远；和眉眼齐平的那一圈只到后脑勺，再往两边就是抬起的肩头了。
        above_brow = grid[..., 1] < centre[1] - 4.0
        scalp = (above_brow & (distance <= 20.0)) | (crown_line & (distance <= 11.5))
        crown = scalp & ~arms & (dark | skin)
        seeds = dark & (core | crown)
        grow = dark & scalp & ~arms & (saturation < 0.34)
    if sex == "female":
        # 女角的马尾贴着后背一直垂到腰，躯干只让开贴近脊线的一窄条，马尾才不会被当成袍子染掉。
        spine_only = capsule(grid, shoulder + spine * 1.0, belt - spine * 30.0, 4.0, 9.0)
        grow |= dark & ~spine_only & ~arms & behind & (distance <= 32.0) & (saturation < 0.30) & (value < 0.30)
        # 马尾搭过近肩：肩头往上四格以内、最黑的那些也算头发（袖子在这儿颜色和头发分不开，只能按位置）。
        over_shoulder = (grid - shoulder) @ spine > -4.0
        grow |= dark & arms & over_shoulder & behind & (distance <= 20.0) & (value < 0.22)
    labels, _ = ndimage.label(seeds | grow)
    hair = np.isin(labels, np.unique(labels[seeds])) & (labels > 0)
    ribbon = np.zeros_like(body)
    if sex == "female":
        ribbon = body & ((hue < 20) | (hue > 345)) & (saturation > 0.36) & (distance <= 27.0) & ~torso
    head = core | crown | hair | ribbon

    # 靴：小腿下半到脚面。裤脚堆在靴筒上沿，只收最暗的那部分。
    # 每只靴子按自己的脚踝截高度：两腿一前一后时用同一条横线截，会把两腿之间垂下的衣摆、裤脚一起划进去。
    # 女角腿细，靴筒也窄一圈。
    boots = np.zeros_like(body)
    girth = 1.0 if sex == "male" else 0.82
    for ankle in pose["ankles"]:
        knee_side = np.array([ankle[0] + (belt[0] - ankle[0]) * 0.13, ankle[1] - 7.6])
        leg = capsule(grid, knee_side, ankle + np.array([0.0, 1.5]), 5.2 * girth, 4.6 * girth)
        leg |= capsule(grid, ankle + np.array([-2.5, 1.0]), ankle + np.array([8.5, 2.6]), 3.6, 2.8)
        shaft = leg & (grid[..., 1] > ankle[1] - 9.5) & body & (value < 0.34)
        # 靴跟、靴背比标的那根柱子宽：裤脚以下、挨着靴子的深色都归靴子。
        heel = ndimage.binary_dilation(shaft, iterations=3 * TEXEL) & (grid[..., 1] > ankle[1] - 5.5)
        boots |= shaft | (heel & body & (value < 0.34))
    boots &= ~head

    # 前臂：近侧在衣襟前，远侧只在轮廓外露出一截。
    # 男角的袖子卷到肘上，肘下露一截皮肉，再往下才是绑腕：绑腕从那截皮肉的下沿算起，
    # 不然卷起的袖口、露出的胳膊都会被划进绑腕，染成护手的颜色。
    bracers = np.zeros_like(body)
    for elbow, wrist, start, radius in [(pose["elbow"], pose["wrist"], 0.12, (3.9, 3.0)),
            (pose["far_elbow"], pose["far_wrist"], 0.15, (3.4, 2.8))]:
        reach = capsule(grid, elbow + (wrist - elbow) * start, wrist, *radius)
        if sex == "male":
            axis = wrist - elbow
            along = ((grid - elbow) @ axis) / max(float(axis @ axis), 1e-6)
            bare = reach & skin & ~fists & (along < 0.85)
            if bare.sum() >= 4 * TEXEL * TEXEL:
                reach &= along > float(np.percentile(along[bare], 90))
        bracers |= reach
        if sex == "female":
            # 女角袖子收得窄，绑腕比标的前臂粗一圈：外圈只收浅色的绑带，不收深色的袖子。
            wide = capsule(grid, elbow + (wrist - elbow) * start, wrist, radius[0] + 2.0, radius[1] + 2.0)
            bracers |= wide & (saturation < 0.30) & (value > 0.36)
    bracers &= body & ~head & ~skin & ~boots

    # 符牌：腰带下面那块铜牌。
    near_belt = capsule(grid, belt + np.array([-3.0, -2.0]), belt + np.array([5.0, 13.0]), 7.5)
    charm = body & near_belt & (hue > 24) & (hue < 56) & (saturation > 0.34) & (value > 0.36) & ~fists & ~head
    charm = ndimage.binary_opening(charm, iterations=1)
    charm = ndimage.binary_dilation(charm, iterations=2) & body & near_belt & ~fists & (value > 0.16) & (saturation > 0.16)

    # 镶边：骨白的交领和卷起的袖口，加各自的腰带（男靛、女朱）。
    # 浅色布只按明度挑会碎成一条条：背光那半边交领暗下去就被分进袍子，染出来一截镶边色一截袍色。
    # 所以先挑最亮的那些当种子，再往相连的、稍暗的同色布里长，最后合拢小缝、去掉碎屑。
    # 铜符牌是暖黄的，会落进肤色的阈值里，要从「皮肤」里摘出来。
    garment = body & ~head & ~(skin & ~charm) & ~hands
    fist_line = fists & (np.hypot(*np.moveaxis(grid - pose["fists"][0], -1, 0)) <= 3.4)
    collar = capsule(grid, shoulder + spine * 2.0, belt, 11.0)
    # 卷起的袖口只有男角有，在两肘附近（远侧那只胳膊的上臂没标，按肘画一圈）。女角袖子是整条的，
    # 前臂上的浅色是绑腕，不能当袖口挑走。
    if sex == "male":
        cuffs = ndimage.binary_dilation(arms, iterations=2 * TEXEL)
        for elbow in [pose["elbow"], pose["far_elbow"]]:
            cuffs |= np.hypot(*np.moveaxis(grid - elbow, -1, 0)) <= 8.0
        cuffs &= ~bracers
    else:
        cuffs = np.zeros_like(body)
    pale = garment & (saturation < 0.30)
    lapel = pale & (value > 0.42) & (collar | cuffs)
    lapel = ndimage.binary_opening(lapel, iterations=1)
    near_lapel = ndimage.binary_dilation(lapel, iterations=2 * TEXEL)
    lapel |= pale & (value > 0.30) & near_lapel & (collar | cuffs)
    lapel = ndimage.binary_closing(lapel, iterations=TEXEL) & garment
    lapel = drop_specks(lapel, 12 * TEXEL * TEXEL)
    if sex == "male":
        sash = garment & (blue - red > 0.012) & (value > 0.12)
    else:
        # 朱红腰带的褶子背光处饱和度掉得厉害，阈值放低，再合拢、填洞，飘带才是整条的。
        sash = garment & ((hue < 26) | (hue > 340)) & (saturation > 0.22) & (value > 0.10)
    sash = ndimage.binary_opening(sash, iterations=1)
    sash = ndimage.binary_closing(sash, iterations=2 * TEXEL)
    sash = ndimage.binary_fill_holes(sash) & garment
    sash = drop_specks(sash, 10 * TEXEL * TEXEL)
    trim = (lapel | sash) & ~charm & ~bracers & ~boots

    cloth = garment & ~boots & ~bracers & ~charm & ~trim
    # 半透明的轮廓像素不染：平涂会把它们填成不透明，轮廓就起锯齿；留着原画的深色正好当勾边。
    solid = cell[..., 3] > 0.92
    regions = tidy({"cloth": cloth, "trim": trim, "bracers": bracers, "boots": boots, "charm": charm},
        # 拳头边缘的暗线是手的轮廓，不是袖子。
        garment & solid & ~fist_line)
    regions["_sash"] = sash
    regions["_lapel"] = lapel
    return regions


def drop_specks(mask, least):
    """去掉面积小于 least 的孤立小块。"""
    labels, count = ndimage.label(mask)
    if count == 0:
        return mask
    sizes = ndimage.sum(mask, labels, np.arange(1, count + 1))
    return mask & np.isin(labels, np.flatnonzero(sizes >= least) + 1)


def tidy(regions, garment):
    """把五个染色区收拾成整块：碎屑并进周围的大区，缝隙补上，区与区的分界抹平。

    按阈值分出来的区会夹着零星的异色像素，染完就是袍子上一点一点的旧色、镶边上一截一截的袍色。
    这里让衣料上每个像素都恰好属于一个区，小于一撮的碎块交给最近的邻区，最后做一次众数平滑。
    """
    names = LAYERS
    label = np.full(garment.shape, -1, np.int32)
    for index, name in enumerate(names):
        label[regions[name] & garment & (label < 0)] = index
    # 碎屑：每个区里面积太小的连通块先清掉，等下按最近的邻区补。
    least = {"charm": 6 * TEXEL * TEXEL}
    for index, name in enumerate(names):
        mine = label == index
        kept = drop_specks(mine, least.get(name, 5 * TEXEL * TEXEL))
        label[mine & ~kept] = -1
    # 衣料上没归属的像素（阈值夹缝、刚清掉的碎屑）跟最近的已分区像素走。
    holes = garment & (label < 0)
    if holes.any() and (label >= 0).any():
        _, (iy, ix) = ndimage.distance_transform_edt(label < 0, return_indices=True)
        label[holes] = label[iy[holes], ix[holes]]
    # 众数平滑：分界处的锯齿和单像素的跳色抹掉，细的交领线保留。
    votes = np.stack([ndimage.uniform_filter((label == i).astype(np.float32), size=TEXEL + 2) for i in range(len(names))])
    smooth = votes.argmax(0)
    keep_small = label == names.index("charm")
    label = np.where(garment & ~keep_small & (label >= 0), smooth, label)
    return {name: garment & (label == index) for index, name in enumerate(names)}


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


# 遮罩的六种颜色。涂的时候用纯色、硬边画笔；读的时候按最近的颜色归类，边上带一点抗锯齿也认得出来。
MASK_COLORS = {"cloth": (70, 110, 220), "collar": (245, 225, 110), "sash": (235, 140, 40),
    "bracers": (90, 200, 120), "boots": (215, 70, 60), "charm": (225, 90, 225)}
MASK_DIR = HERE / "masks"


def write_mask(path, regions):
    """把分区（cloth/trim/bracers/boots/charm 及 _lapel）写成一张纯色遮罩。"""
    shape = regions["cloth"].shape
    out = np.zeros(shape + (4,), np.uint8)
    paint = {"cloth": regions["cloth"], "collar": regions["trim"] & regions["_lapel"],
        "sash": regions["trim"] & ~regions["_lapel"], "bracers": regions["bracers"],
        "boots": regions["boots"], "charm": regions["charm"]}
    for name, mask in paint.items():
        out[mask, :3] = MASK_COLORS[name]
        out[mask, 3] = 255
    path.parent.mkdir(exist_ok=True)
    Image.fromarray(out).save(path, optimize=True)


def read_mask(path, pixels):
    """读回遮罩，换成各染色区。只染底图上实打实不透明的像素，半透明的勾边留原画当描边。"""
    paint = np.asarray(Image.open(path).convert("RGBA")).astype(np.float32)
    assert paint.shape[:2] == pixels.shape[:2], "遮罩 %s 的尺寸 %s 和底图 %s 对不上" % (path.name, paint.shape[:2], pixels.shape[:2])
    names = list(MASK_COLORS)
    palette = np.array([MASK_COLORS[name] for name in names], np.float32)
    distance = np.linalg.norm(paint[..., None, :3] - palette, axis=-1)
    nearest = distance.argmin(-1)
    painted = (paint[..., 3] >= 128) & (distance.min(-1) <= 90.0)
    solid = pixels[..., 3] > 0.92
    picked = {name: painted & solid & (nearest == index) for index, name in enumerate(names)}
    return {"cloth": picked["cloth"], "trim": picked["collar"] | picked["sash"], "bracers": picked["bracers"],
        "boots": picked["boots"], "charm": picked["charm"], "_lapel": picked["collar"], "_sash": picked["sash"]}


def build(sex, poses, reclassify=False):
    sheet = pack(sex)
    pixels = np.asarray(sheet).astype(np.float32) / 255.0
    mask_path = MASK_DIR / ("%s.png" % sex)
    if reclassify or not mask_path.exists():
        guessed = {name: np.zeros(pixels.shape[:2], bool) for name in LAYERS + ["_lapel"]}
        for frame in range(12):
            x, y = (frame % 4) * SIZE, (frame // 4) * SIZE
            found = classify(pixels[y:y + SIZE, x:x + SIZE], poses[frame], sex)
            for name in guessed:
                guessed[name][y:y + SIZE, x:x + SIZE] = found[name]
        write_mask(mask_path, guessed)
        print("已按颜色和关节自动分区：masks/%s.png" % sex)
    regions = read_mask(mask_path, pixels)
    layers = {name: np.zeros(pixels.shape, np.float32) for name in LAYERS}
    for frame in range(12):
        x, y = (frame % 4) * SIZE, (frame // 4) * SIZE
        window = (slice(y, y + SIZE), slice(x, x + SIZE))
        shaded = shade_layer(pixels[window], {name: mask[window] for name, mask in regions.items()})
        for name in LAYERS:
            layers[name][window] = shaded[name]
    return sheet, {name: Image.fromarray((layer * 255.0 + 0.5).astype(np.uint8)) for name, layer in layers.items()}


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
    return Image.fromarray((out * 255.0 + 0.5).astype(np.uint8))


def hex_color(text):
    return tuple(int(text[i:i + 2], 16) / 255.0 for i in (1, 3, 5))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", help="另存染色对照图的目录")
    parser.add_argument("--reclassify", action="store_true", help="重新自动分区，覆盖 masks/ 里的遮罩")
    args = parser.parse_args()
    poses = joints()
    (HERE / "dye").mkdir(exist_ok=True)
    for sex in ["male", "female"]:
        sheet, layers = build(sex, poses[sex], args.reclassify)
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
            Image.fromarray(canvas).save(out / ("classes-%s.png" % sex))


if __name__ == "__main__":
    main()
