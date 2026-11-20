"""把法器原画里的兵器抠出来，拼成手持兵器图集和炉坊的形制图标。

    python art/side/pack_weapons.py           # 在 mobile 目录下运行
    python art/side/pack_weapons.py --preview out_dir

原画是 source/armory.png（6 列 × 5 行，深色底）。手持兵器的握点、朝向在 held_weapon.gd 的 FORMS 里
按 128×128 的素材空间标定，一格原画正好对应一格素材空间，这里只负责抠底、清理和放大倍数。

    held-weapons.png   4 列 × 2 行，每格 CELL 像素：刀、锤、杖头、弓、枪头、短杖、剑
    ../forge-weapons.webp 的替代品 forge-weapons.png   4 列 × 2 行的形制图标，顺序见 ICONS

原画里没有剑，剑是这里按同一套配色画出来的。
"""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

HERE = Path(__file__).resolve().parent
CELL = 192
SPACE = 128.0
GRID = (6, 5)
BACKDROP = np.array([3.0, 18.0, 18.0])
# 手持图集的格序，held_weapon.gd 的 FORMS.cell 与此对应。
HELD = ["blade", "hammer", "staff", "bow", "spear", "wand", "sword"]
# 炉坊图标的格序，forge_art.gd 的 FORM_ICONS 与此对应。
ICONS = ["long_blade", "hammer", "bow", "dual_blades", "staff", "wand", "spear", "sword"]
SOURCE_CELL = {"blade": 12, "hammer": 10, "staff": 13, "bow": 11, "spear": 9, "wand": 14}


def source_cell(sheet, index):
    width, height = sheet.width / GRID[0], sheet.height / GRID[1]
    column, row = index % GRID[0], index // GRID[0]
    return sheet.crop((round(column * width), round(row * height), round((column + 1) * width), round((row + 1) * height)))


def matte(cell):
    """去掉深青色的底。先从四边往里漫，再补上被纹饰围住的小块底色（环与环之间、戟刃之间）。"""
    rgb = np.asarray(cell.convert("RGB")).astype(np.float32)
    distance = np.sqrt(((rgb - BACKDROP) ** 2).sum(-1))
    loose = distance < 30.0
    labels, _ = ndimage.label(loose)
    border = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    outside = np.isin(labels, border[border > 0])
    tight, count = ndimage.label(distance < 14.0)
    sizes = ndimage.sum(np.ones_like(tight), tight, range(1, count + 1))
    holes = np.isin(tight, [i + 1 for i, size in enumerate(sizes) if size >= 24])
    solid = ~(outside | holes)
    solid = ndimage.binary_opening(solid, iterations=1)
    return solid


def keep_largest(mask, seed=None):
    """只留一块相连的形状：给了种子点就留种子所在的那块，否则留最大的。"""
    labels, count = ndimage.label(mask)
    if count == 0:
        return mask
    if seed is not None and labels[seed[1], seed[0]] > 0:
        return labels == labels[seed[1], seed[0]]
    sizes = ndimage.sum(mask, labels, range(1, count + 1))
    return labels == int(np.argmax(sizes)) + 1


def finish(cell, mask):
    """按蒙版出一格带透明度的图：边缘留一点羽化，透明处的颜色向内延伸，线性取样时不会透出底色。"""
    rgb = np.asarray(cell.convert("RGB")).astype(np.float32)
    soft = ndimage.gaussian_filter(mask.astype(np.float32), 0.7)
    alpha = np.clip((soft - 0.35) / 0.4, 0.0, 1.0) * ndimage.binary_dilation(mask, iterations=1)
    nearest = ndimage.distance_transform_edt(~mask, return_distances=False, return_indices=True)
    filled = rgb[nearest[0], nearest[1]]
    out = np.dstack([filled, alpha * 255.0]).clip(0, 255).astype(np.uint8)
    return Image.fromarray(out, "RGBA").resize((CELL, CELL), Image.LANCZOS)


def cut(name, cell):
    mask = matte(cell)
    size = cell.width
    ys, xs = np.mgrid[0:size, 0:size]
    unit = size / SPACE
    if name == "blade":
        # 原画是一对刀，手里只拿上面那把：沿它的刀身留一条，握柄旁边再放宽到刀穗。
        pommel, tip = np.array([100.0, 5.0]) * unit, np.array([4.0, 96.0]) * unit
        axis = (tip - pommel) / np.hypot(*(tip - pommel))
        along = (xs - pommel[0]) * axis[0] + (ys - pommel[1]) * axis[1]
        across = (xs - pommel[0]) * axis[1] - (ys - pommel[1]) * axis[0]
        mask &= (across < 14.5 * unit) | ((across < 26.0 * unit) & (along < 48.0 * unit))
        mask = keep_largest(mask, (int(60 * unit), int(52 * unit)))
    elif name == "bow":
        # 弦由游戏按拉弓的手来画，原画里那根直弦去掉：留弓身这一块粗的。
        mask = keep_largest(ndimage.binary_opening(mask, iterations=3))
        mask = ndimage.binary_dilation(mask, iterations=2) & matte(cell)
    elif name == "spear":
        # 枪杆由游戏按双手的握距来画，这里只留枪头、铜箍和枪缨：把铜箍以下沿杆身方向的一条削掉。
        socket = np.array([52.7, 70.7]) * unit
        axis = np.array([0.685, -0.728])
        along = (xs - socket[0]) * axis[0] + (ys - socket[1]) * axis[1]
        across = np.abs((xs - socket[0]) * -axis[1] + (ys - socket[1]) * axis[0])
        mask &= ~((along < -3.0 * unit) & (across < 7.0 * unit))
        mask = keep_largest(mask)
    else:
        mask = keep_largest(mask)
    return finish(cell, mask)


def lerp(a, b, t):
    return tuple(int(round(x + (y - x) * t)) for x, y in zip(a, b))


def sword():
    """一把直剑，竖着画：剑尖朝上，握柄在下。配色取自原画的刀和铜饰。"""
    scale = 6
    size = int(SPACE * scale)
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    def p(points):
        return [(x * scale, y * scale) for x, y in points]
    ink = (38, 30, 30, 255)
    steel_light, steel_mid, steel_dark = (226, 232, 236), (158, 170, 180), (104, 116, 128)
    gold_light, gold, gold_dark = (243, 218, 142), (201, 160, 84), (120, 86, 38)
    red, red_light, red_dark = (150, 44, 38), (190, 76, 62), (92, 24, 24)
    cx = 64.0
    tip, shoulder_y, guard_y = 4.0, 14.0, 76.0
    half = 5.0
    # 剑身：勾边，左明右暗两个面，中脊一道亮线。
    outline = [(cx, tip - 1.2), (cx + half * 0.72 + 1.0, shoulder_y), (cx + half + 1.0, guard_y), (cx - half - 1.0, guard_y), (cx - half * 0.72 - 1.0, shoulder_y)]
    draw.polygon(p(outline), fill=ink)
    rows = 60
    for index in range(rows):
        t0, t1 = index / rows, (index + 1) / rows
        y0, y1 = shoulder_y + (guard_y - shoulder_y) * t0, shoulder_y + (guard_y - shoulder_y) * t1
        w0, w1 = half * (0.72 + 0.28 * t0), half * (0.72 + 0.28 * t1)
        glow = 0.5 + 0.5 * np.sin(t0 * 5.2 + 0.6)
        draw.polygon(p([(cx - w0, y0), (cx, y0), (cx, y1), (cx - w1, y1)]), fill=lerp(steel_mid, steel_light, 0.55 + 0.45 * glow) + (255,))
        draw.polygon(p([(cx, y0), (cx + w0, y0), (cx + w1, y1), (cx, y1)]), fill=lerp(steel_dark, steel_mid, 0.35 + 0.5 * glow) + (255,))
    draw.polygon(p([(cx, tip), (cx - half * 0.72, shoulder_y), (cx, shoulder_y)]), fill=steel_light + (255,))
    draw.polygon(p([(cx, tip), (cx + half * 0.72, shoulder_y), (cx, shoulder_y)]), fill=steel_mid + (255,))
    draw.line(p([(cx, tip + 1.5), (cx, guard_y - 9.0)]), fill=(246, 249, 250, 255), width=int(scale * 0.55))
    draw.line(p([(cx - half * 0.86, shoulder_y + 6), (cx - half + 0.5, guard_y - 2)]), fill=(250, 252, 252, 200), width=int(scale * 0.4))
    # 近护手处的错金云纹。
    for k in range(4):
        y = guard_y - 5.0 - k * 4.2
        draw.arc(p([(cx - 2.6, y - 2.2), (cx + 2.6, y + 2.2)]), 200 + k * 40, 20 + k * 40, fill=gold + (255,), width=int(scale * 0.7))
    # 护手：两头下卷的如意形。
    guard = [(cx - 12.5, guard_y + 3.6), (cx - 11.0, guard_y - 0.8), (cx - 5.0, guard_y - 1.6), (cx, guard_y - 3.0),
        (cx + 5.0, guard_y - 1.6), (cx + 11.0, guard_y - 0.8), (cx + 12.5, guard_y + 3.6), (cx + 8.5, guard_y + 4.4),
        (cx + 4.0, guard_y + 3.0), (cx, guard_y + 5.2), (cx - 4.0, guard_y + 3.0), (cx - 8.5, guard_y + 4.4)]
    grown = [(cx + (x - cx) * 1.09, guard_y + 1.0 + (y - guard_y - 1.0) * 1.22) for x, y in guard]
    draw.polygon(p(grown), fill=ink)
    draw.polygon(p(guard), fill=gold + (255,))
    draw.polygon(p([(cx - 10.6, guard_y - 0.2), (cx - 5.0, guard_y - 1.0), (cx, guard_y - 2.2), (cx + 5.0, guard_y - 1.0),
        (cx + 10.6, guard_y - 0.2), (cx + 5.0, guard_y + 0.6), (cx, guard_y - 0.4), (cx - 5.0, guard_y + 0.6)]), fill=gold_light + (255,))
    draw.polygon(p([(cx - 8.5, guard_y + 3.6), (cx - 4.0, guard_y + 2.2), (cx, guard_y + 4.2), (cx + 4.0, guard_y + 2.2),
        (cx + 8.5, guard_y + 3.6), (cx + 4.0, guard_y + 3.0), (cx, guard_y + 5.2), (cx - 4.0, guard_y + 3.0)]), fill=gold_dark + (255,))
    draw.ellipse(p([(cx - 1.7, guard_y - 0.6), (cx + 1.7, guard_y + 2.8)]), fill=red + (255,), outline=ink, width=int(scale * 0.4))
    # 握柄：朱红缠绳。
    grip_top, grip_bottom = guard_y + 4.6, guard_y + 23.0
    draw.rectangle(p([(cx - 3.5, grip_top), (cx + 3.5, grip_bottom)]), fill=ink)
    draw.rectangle(p([(cx - 2.6, grip_top), (cx + 2.6, grip_bottom)]), fill=red + (255,))
    draw.rectangle(p([(cx - 2.6, grip_top), (cx - 1.0, grip_bottom)]), fill=red_light + (255,))
    for k in range(9):
        y = grip_top + 0.6 + k * 2.1
        draw.line(p([(cx - 2.6, y + 1.6), (cx + 2.6, y)]), fill=red_dark + (255,), width=int(scale * 0.45))
    # 剑首与剑穗。
    pommel = [(cx - 3.8, grip_bottom - 0.4), (cx + 3.8, grip_bottom - 0.4), (cx + 5.0, grip_bottom + 3.4), (cx + 2.6, grip_bottom + 6.6),
        (cx - 2.6, grip_bottom + 6.6), (cx - 5.0, grip_bottom + 3.4)]
    draw.polygon(p([(cx + (x - cx) * 1.2, grip_bottom + 3.0 + (y - grip_bottom - 3.0) * 1.2) for x, y in pommel]), fill=ink)
    draw.polygon(p(pommel), fill=gold + (255,))
    draw.polygon(p([(cx - 3.4, grip_bottom + 0.4), (cx + 0.6, grip_bottom + 0.4), (cx - 0.2, grip_bottom + 5.8), (cx - 3.6, grip_bottom + 3.4)]), fill=gold_light + (255,))
    draw.line(p([(cx + 1.4, grip_bottom + 6.6), (cx + 5.4, grip_bottom + 9.6)]), fill=gold_dark + (255,), width=int(scale * 0.6))
    draw.ellipse(p([(cx + 4.0, grip_bottom + 8.4), (cx + 7.6, grip_bottom + 12.0)]), fill=(168, 210, 180, 255), outline=ink, width=int(scale * 0.4))
    for k in range(7):
        x = cx + 3.6 + k * 0.72
        length = 12.5 - abs(k - 3) * 1.1
        draw.line(p([(cx + 5.8, grip_bottom + 11.6), (x - 0.6 + k * 0.1, grip_bottom + 12.0 + length)]),
            fill=(red_dark if k % 2 else red) + (255,), width=int(scale * 0.85))
    draw.line(p([(cx + 4.4, grip_bottom + 12.6), (cx + 7.4, grip_bottom + 12.6)]), fill=gold + (255,), width=int(scale * 0.8))
    # 压一层细颗粒，和原画的笔触接上。
    pixels = np.asarray(image).astype(np.float32)
    grain = ndimage.gaussian_filter(np.random.default_rng(7).normal(0.0, 1.0, (size, size)), scale * 0.5)
    pixels[..., :3] = np.clip(pixels[..., :3] * (1.0 + 0.5 * grain[..., None]), 0, 255)
    image = Image.fromarray(pixels.astype(np.uint8), "RGBA").filter(ImageFilter.GaussianBlur(scale * 0.18))
    return image.resize((CELL, CELL), Image.LANCZOS)


def icon(art, turn=0.0, size=160):
    """炉坊图标：裁到兵器本身、转到斜放、留一圈边。"""
    if turn:
        art = art.rotate(turn, Image.BICUBIC, expand=True)
    art = art.crop(art.getbbox())
    room = size - 16
    ratio = min(room / art.width, room / art.height)
    art = art.resize((max(1, round(art.width * ratio)), max(1, round(art.height * ratio))), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.alpha_composite(art, ((size - art.width) // 2, (size - art.height) // 2))
    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview")
    args = parser.parse_args()
    sheet = Image.open(HERE / "source" / "armory.png").convert("RGB")
    cells = {name: source_cell(sheet, index) for name, index in SOURCE_CELL.items()}
    held = {name: cut(name, cells[name]) for name in SOURCE_CELL}
    held["sword"] = sword()
    atlas = Image.new("RGBA", (CELL * 4, CELL * 2), (0, 0, 0, 0))
    for index, name in enumerate(HELD):
        atlas.paste(held[name], ((index % 4) * CELL, (index // 4) * CELL))
    atlas.save(HERE / "held-weapons.png", optimize=True)

    # 图标用整件兵器：枪和锤带杆，双刀用原画的一对。
    whole = {name: finish(cells[name], keep_largest(matte(cells[name]))) for name in ["hammer", "staff", "spear", "wand"]}
    pair = matte(cells["blade"])
    art = {"long_blade": held["blade"], "hammer": whole["hammer"], "bow": finish(cells["bow"], matte(cells["bow"])),
        "dual_blades": finish(cells["blade"], pair), "staff": whole["staff"], "wand": whole["wand"],
        "spear": whole["spear"], "sword": held["sword"]}
    turns = {"sword": -45.0}
    size = 128
    icons = Image.new("RGBA", (size * 4, size * 2), (0, 0, 0, 0))
    for index, form in enumerate(ICONS):
        icons.paste(icon(art[form], turns.get(form, 0.0), size), ((index % 4) * size, (index // 4) * size))
    icons.save(HERE.parent / "forge-weapons.png", optimize=True)
    print("已出图：held-weapons.png %dx%d，forge-weapons.png %dx%d" % (atlas.width, atlas.height, icons.width, icons.height))
    if args.preview:
        out = Path(args.preview)
        out.mkdir(parents=True, exist_ok=True)
        for name, image in [("held", atlas), ("icons", icons)]:
            board = Image.new("RGBA", image.size, (122, 122, 140, 255))
            board.alpha_composite(image)
            board.save(out / ("weapons-%s.png" % name))


if __name__ == "__main__":
    main()
