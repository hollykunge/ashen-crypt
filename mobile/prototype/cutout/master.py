"""总拆件图：所有能换的部件按游戏里的实际比例摆在一张图上，AI 在它上面一次改出一整套装备，再按位置切回。

    cd hero
    python3 ../master.py compose                       # 拼 source/master.png 和 master.json（位置表）
    python3 ../master.py extract source/set-leather-1.png set-leather   # 切回成一套装备目录

拼图：每件按 rig.json 里的缩放（展开 same_as）乘上同一个系数 K 摆上去，AI 看到的就是一个人身上各件的真实比例。
切回：按位置表裁出每件，在 ±SEARCH 像素里挪，找跟光身件轮廓交并比最大的位置；只留光身轮廓外扩 GROW_PX 以内的像素
（护肩可以冒出来一点，但不会混进旁边部件的边）；再按缩放倒数放回原图分辨率，画布四周多留 MARGIN，跟换装件的规矩一样。
打印每件的重合度（cover）和长出（grow），跟 cut.py 一样的判断。
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import cut  # noqa: E402
from cut import to_alpha  # noqa: E402

# 去白底时轮廓只往里收 1 像素：总图上小部件（手）分辨率低，收 2 像素放回原图就削掉一大圈
cut.ERODE = 1

K = 1.15  # 游戏里的局部单位 → 总图像素
MARGIN = 80  # 切回来的件，四周比光身件多留的画布（光身图像素）
SEARCH = 16
GROW_PX = 26
SHEET = (1536, 1024)

# 装备槽 → 部件；每行一个槽，摆的顺序就是行里从左到右
SLOTS = {
    "armor": ["torso", "upper_arm", "far_upper_arm"],
    "gloves": ["forearm", "hand", "far_forearm"],
    "pants": ["pelvis", "thigh", "shin"],
    "boots": ["boot"],
}
# 每件在总图上的左上角（总图像素）；行高按最大的件留够
LAYOUT = {
    "torso": (60, 30), "upper_arm": (330, 50), "far_upper_arm": (560, 50),
    "forearm": (840, 60), "hand": (1040, 80), "far_forearm": (1240, 60),
    "pelvis": (60, 520), "thigh": (360, 420), "shin": (620, 520),
    "boot": (960, 520),
}


def rig_parts(rig):
    parts = json.loads(json.dumps(rig["parts"]))
    for p in parts.values():
        if "same_as" in p:
            for k, v in parts[p["same_as"]].items():
                p.setdefault(k, v)
    return parts


def scale_of(p):
    s = p.get("scale", 1.0)
    return (s[0], s[1]) if isinstance(s, list) else (s, s)


def base_image(name):
    return Image.open(f"parts/{name}.png").convert("RGBA")


def compose():
    rig = json.loads(Path("rig.json").read_text())
    parts = rig_parts(rig)
    sheet = Image.new("RGBA", SHEET, (255, 255, 255, 255))
    table = {}
    for slot, names in SLOTS.items():
        for name in names:
            im = base_image(name)
            sx, sy = scale_of(parts[name])
            size = (max(1, round(im.width * sx * K)), max(1, round(im.height * sy * K)))
            small = im.resize(size, Image.LANCZOS)
            x, y = LAYOUT[name]
            sheet.alpha_composite(small, (x, y))
            table[name] = {"slot": slot, "box": [x, y, size[0], size[1]], "k": [size[0] / im.width, size[1] / im.height],
                           "base": [im.width, im.height]}
    sheet.convert("RGB").save("source/master.png")
    Path("master.json").write_text(json.dumps(table, indent=1))
    print("总拆件图：source/master.png", SHEET, "；", len(table), "件")


def dilate(mask, r):
    out = mask.copy()
    for _ in range(r):
        g = out.copy()
        g[1:] |= out[:-1]; g[:-1] |= out[1:]; g[:, 1:] |= out[:, :-1]; g[:, :-1] |= out[:, 1:]
        out = g
    return out


def extract(src, out_dir):
    table = json.loads(Path("master.json").read_text())
    sheet = to_alpha(Image.open(src))
    if sheet.shape[1] != SHEET[0] or sheet.shape[0] != SHEET[1]:
        sheet = np.asarray(Image.fromarray(sheet).resize(SHEET, Image.LANCZOS))
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    report = []
    for name, t in table.items():
        x, y, w, h = t["box"]
        kx, ky = t["k"]
        base = np.asarray(base_image(name).resize((w, h), Image.LANCZOS))[..., 3] > 128
        pad = SEARCH + GROW_PX + 4
        H, W = sheet.shape[:2]
        x0, y0 = max(0, x - pad), max(0, y - pad)
        x1, y1 = min(W, x + w + pad), min(H, y + h + pad)
        crop = sheet[y0:y1, x0:x1]
        on = crop[..., 3] > 128
        # 光身件在裁出来那块里的位置
        bx, by = x - x0, y - y0
        best = None
        for dy in range(-SEARCH, SEARCH + 1, 2):
            for dx in range(-SEARCH, SEARCH + 1, 2):
                m = np.zeros_like(on)
                ys, xs = by + dy, bx + dx
                m[max(0, ys):ys + h, max(0, xs):xs + w] = base[max(0, -ys):, max(0, -xs):][:m[max(0, ys):ys + h, max(0, xs):xs + w].shape[0], :m[max(0, ys):ys + h, max(0, xs):xs + w].shape[1]]
                iou = (m & on).sum() / max((m | on).sum(), 1)
                if best is None or iou > best[0]:
                    best = (iou, dx, dy, m)
        _, dx, dy, m = best
        keep = dilate(m, GROW_PX)
        piece = crop.copy()
        piece[~keep] = 0
        cover = (m & on).sum() / max(m.sum(), 1)
        grow = (on & keep & ~m).sum() / max(m.sum(), 1)
        # 裁出「光身件位置（已对齐）四周各 MARGIN 原图像素」那一块，按缩放倒数放回原图分辨率
        mx, my = MARGIN * kx, MARGIN * ky
        cx0, cy0 = bx + dx - mx, by + dy - my
        cw, ch = w + 2 * mx, h + 2 * my
        region = Image.fromarray(piece).crop((round(cx0), round(cy0), round(cx0 + cw), round(cy0 + ch)))
        bw, bh = t["base"]
        region = region.resize((bw + 2 * MARGIN, bh + 2 * MARGIN), Image.LANCZOS)
        region.save(out / f"{name}.png")
        flag = ""
        if cover < 0.85:
            flag = "   <-- 形状被改了，重出"
        report.append({"part": name, "shift": [dx, dy], "cover": round(float(cover), 3), "grow": round(float(grow), 3)})
        print("  ", report[-1], flag)
    (out / "outfit.json").write_text(json.dumps({"margin": MARGIN}))
    (out / "align.json").write_text(json.dumps(report, indent=1))


if __name__ == "__main__":
    if sys.argv[1] == "compose":
        compose()
    else:
        extract(sys.argv[2], sys.argv[3])
