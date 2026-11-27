"""把 AI 出的拆件图切成单个部件，并检查能不能跟光身版对上。

    cd shanxiao   # 在角色目录里运行
    python3 ../cut.py source/parts.png parts --names head,torso,upper_arm,forearm,thigh,shin
    python3 ../cut.py source/armor-1.png armor-1 --like parts --may-grow torso   # 切护甲版，逐件对齐到光身版
                                                    # --may-grow：提示词里允许伸出轮廓的件（护肩那件）

白底转透明 → 按连通块分件 → 太小的碎屑丢掉。--like 时每个护甲件找光身版里位置最近的那件，
挪到跟光身件的轮廓重合最多的位置，再打印重合度：低于 0.85 的件说明 AI 改了形状，要重出。
"""
import json
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
MIN_AREA = 2500  # 小于这个像素数的连通块当碎屑
ERODE = 2  # 轮廓往里收几像素
MARGIN = 80  # 换装件四周多留的画布，放得下冒出身体轮廓的护甲
SEARCH = 24  # 对齐时上下左右最多挪几像素
GROW = 0.06  # 不该长的件伸出原轮廓超过这个比例就提示
SOFT = (225, 248)  # 亮度在这两值之间的白底像素做半透明过渡，边缘不发白


def to_alpha(sheet):
    rgb = np.asarray(sheet.convert("RGB")).astype(np.float32)
    if sheet.mode == "RGBA" and np.asarray(sheet)[..., 3].min() < 250:
        return np.asarray(sheet.convert("RGBA")).copy()
    # 离白色越近越透明；用最暗通道判断，免得浅色毛尖被当成底色
    low = rgb.min(-1)
    alpha = np.clip((SOFT[1] - low) / (SOFT[1] - SOFT[0]), 0, 1)
    # 半透明边缘把白底混进来的那部分去掉，免得部件描上一圈白边
    a = np.maximum(alpha, 1e-3)[..., None]
    rgb = np.clip((rgb - 255 * (1 - a)) / a, 0, 255)
    # 出图工具常在轮廓外描一圈浅色细线，往里收两像素把它削掉
    for _ in range(ERODE):
        p = np.pad(alpha, 1, mode="constant")
        alpha = np.minimum.reduce([p[1:-1, 1:-1], p[:-2, 1:-1], p[2:, 1:-1], p[1:-1, :-2], p[1:-1, 2:]])
    return np.dstack([rgb, alpha * 255]).astype(np.uint8)


def components(mask):
    h, w = mask.shape
    label = np.zeros((h, w), np.int32)
    found = []
    ys, xs = np.nonzero(mask)
    for y0, x0 in zip(ys, xs):
        if label[y0, x0]:
            continue
        n = len(found) + 1
        label[y0, x0] = n
        queue = deque([(y0, x0)])
        pts = []
        while queue:
            y, x = queue.popleft()
            pts.append((y, x))
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                yy, xx = y + dy, x + dx
                if 0 <= yy < h and 0 <= xx < w and mask[yy, xx] and not label[yy, xx]:
                    label[yy, xx] = n
                    queue.append((yy, xx))
        found.append(np.array(pts))
    return label, found


def cut(path, out_dir):
    rgba = to_alpha(Image.open(path))
    # 连通块用稍硬的阈值，半透明的毛边挂在最近的块上
    label, comps = components(rgba[..., 3] > 60)
    pieces = []
    for n, pts in enumerate(comps, 1):
        if len(pts) < MIN_AREA:
            continue
        y0, x0 = pts.min(0)
        y1, x1 = pts.max(0) + 1
        pad = 6
        y0, x0 = max(0, y0 - pad), max(0, x0 - pad)
        y1, x1 = min(rgba.shape[0], y1 + pad), min(rgba.shape[1], x1 + pad)
        crop = rgba[y0:y1, x0:x1].copy()
        own = label[y0:y1, x0:x1]
        # 只留本块和紧邻本块的软边，其他块的像素清掉
        near = (own == n)
        grown = near.copy()
        for _ in range(3):
            g = grown.copy()
            g[1:] |= grown[:-1]; g[:-1] |= grown[1:]; g[:, 1:] |= grown[:, :-1]; g[:, :-1] |= grown[:, 1:]
            grown = g
        crop[~grown] = 0
        pieces.append({"box": [int(x0), int(y0), int(x1), int(y1)], "area": int(len(pts)), "img": crop})
    pieces.sort(key=lambda p: (p["box"][1] // 300, p["box"][0]))
    out_dir.mkdir(parents=True, exist_ok=True)
    for old in out_dir.glob("piece-*.png"):
        old.unlink()
    for i, p in enumerate(pieces):
        Image.fromarray(p["img"]).save(out_dir / f"piece-{i}.png")
    meta = [{"index": i, "box": p["box"], "area": p["area"]} for i, p in enumerate(pieces)]
    (out_dir / "pieces.json").write_text(json.dumps(meta, indent=1))
    preview(rgba, pieces, out_dir / "preview.png")
    print(f"{path}: {len(pieces)} 件")
    for m in meta:
        print("  ", m)
    return pieces


def preview(rgba, pieces, out):
    bg = Image.new("RGBA", (rgba.shape[1], rgba.shape[0]), (70, 70, 78, 255))
    bg.alpha_composite(Image.fromarray(rgba))
    d = ImageDraw.Draw(bg)
    for i, p in enumerate(pieces):
        x0, y0, x1, y1 = p["box"]
        d.rectangle([x0, y0, x1, y1], outline=(255, 210, 60, 255), width=3)
        d.text((x0 + 6, y0 + 4), str(i), fill=(255, 230, 90, 255))
    bg.convert("RGB").save(out)


def align(like_dir, out_dir, may_grow=()):
    """护甲件逐件对齐到光身件。

    AI 改图时位置基本不动，所以先按两张图里的框直接对位，再在 ±SEARCH 像素里挪，找跟光身件轮廓
    重合最多的位置。护甲件存成「光身件画布四周各加 MARGIN」的大小，护肩冒出来的部分也放得下；
    关节点不变，rig 按 outfit.json 里的 margin 把图往左上挪回去。
    """
    names = json.loads((like_dir / "names.json").read_text())
    base = json.loads((like_dir / "pieces.json").read_text())
    mine = json.loads((out_dir / "pieces.json").read_text())
    report = []
    for m in mine:
        cx, cy = (m["box"][0] + m["box"][2]) / 2, (m["box"][1] + m["box"][3]) / 2
        b = min(base, key=lambda b: ((b["box"][0] + b["box"][2]) / 2 - cx) ** 2 + ((b["box"][1] + b["box"][3]) / 2 - cy) ** 2)
        a_img = np.asarray(Image.open(like_dir / f"piece-{b['index']}.png"))
        m_arr = np.asarray(Image.open(out_dir / f"piece-{m['index']}.png"))
        ah, aw = a_img.shape[:2]
        a_on = np.zeros((ah + 2 * MARGIN, aw + 2 * MARGIN), bool)
        a_on[MARGIN:MARGIN + ah, MARGIN:MARGIN + aw] = a_img[..., 3] > 128
        ox, oy = m["box"][0] - b["box"][0] + MARGIN, m["box"][1] - b["box"][1] + MARGIN
        # 按交并比找位置：只看「盖住多少」的话，护甲画得比原件大时挪到哪都算盖住
        best = None
        for dy in range(-SEARCH, SEARCH + 1, 2):
            for dx in range(-SEARCH, SEARCH + 1, 2):
                canvas = paste(m_arr, a_on.shape, ox + dx, oy + dy)
                m_on = canvas[..., 3] > 128
                iou = (a_on & m_on).sum() / max((a_on | m_on).sum(), 1)
                if best is None or iou > best[0]:
                    best = (iou, dx, dy, canvas)
        _, dx, dy, canvas = best
        m_on = canvas[..., 3] > 128
        cover = (a_on & m_on).sum() / max(a_on.sum(), 1)
        # 长出：护甲件伸到原轮廓外面的面积，占原件的比例。护肩该长；长在不该长的件上，多半是 AI 把护甲画错了件
        grow = (m_on & ~a_on).sum() / max(a_on.sum(), 1)
        name = names[b["index"]]
        Image.fromarray(canvas).save(out_dir / f"{name}.png")
        report.append({"part": name, "shift": [ox - MARGIN + dx, oy - MARGIN + dy],
                       "cover": round(float(cover), 3), "grow": round(float(grow), 3)})
    for r in report:
        flag = ""
        if r["cover"] < 0.85:
            flag = "   <-- 形状被改了，重出"
        elif r["grow"] > GROW and r["part"] not in may_grow:
            flag = "   <-- 这件不该长出这么多，护甲可能画错了件"
        print("  ", r, flag)
    (out_dir / "align.json").write_text(json.dumps(report, indent=1))
    (out_dir / "outfit.json").write_text(json.dumps({"margin": MARGIN}))


def paste(arr, shape, x, y):
    canvas = np.zeros(shape + (4,), np.uint8)
    h, w = arr.shape[:2]
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(shape[1], x + w), min(shape[0], y + h)
    if x1 > x0 and y1 > y0:
        canvas[y0:y1, x0:x1] = arr[y0 - y:y1 - y, x0 - x:x1 - x]
    return canvas


if __name__ == "__main__":
    # 路径都按当前目录算，在角色目录（shanxiao/、hero/）里运行
    src, out = Path(sys.argv[1]), Path(sys.argv[2])
    pieces = cut(src, out)
    if "--names" in sys.argv:
        names = sys.argv[sys.argv.index("--names") + 1].split(",")
        (out / "names.json").write_text(json.dumps(names))
        for i, n in enumerate(names):
            (out / f"{n}.png").write_bytes((out / f"piece-{i}.png").read_bytes())
    if "--like" in sys.argv:
        grow_ok = sys.argv[sys.argv.index("--may-grow") + 1].split(",") if "--may-grow" in sys.argv else []
        align(Path(sys.argv[sys.argv.index("--like") + 1]), out, grow_ok)
