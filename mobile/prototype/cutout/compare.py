"""笔直站姿跟设定图侧面并排，按方格比比例和粗细。

    python3 compare.py hero <输出.png>

两边都缩放到同样的身高（头顶到脚底），以脚后跟为竖线起点、脚底为横线起点，画边长 = 身高 / 16 的方格：
横着数格子比高低（腰、裆、膝在第几格），竖着数格子比粗细（腿、靴子、脚掌占几格）。
另外沿身高量几处宽度，打印成表：拼出来的宽度 / 设定图的宽度，大于 1 就是比设定图粗。
"""
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
GODOT = Path.home() / "Applications/Godot.app/Contents/MacOS/Godot"
# 设定图第 3 格是严格侧面
REF = ("../../art/side/source/hero/turnaround-male.png", (805, 0, 1135, 1024))
FONT = "/System/Library/Fonts/Hiragino Sans GB.ttc"
HEIGHT = 640  # 对照图里人物的身高（像素）
CELLS = 16
# 量宽度的位置：从头顶往下占身高的比例，及其名字
ROWS = [(0.30, "胸"), (0.42, "腰"), (0.62, "大腿（拳下）"), (0.72, "膝"), (0.80, "小腿"), (0.88, "靴筒"), (0.97, "脚掌")]


def mask_of(img, bg_column):
    """人物的蒙版：跟同一行背景色差得多的像素。bg_column 是每行背景色（取画面最左一列）。"""
    a = np.asarray(img.convert("RGB")).astype(int)
    bg = np.asarray(bg_column).astype(int)[:, None, :]
    m = np.abs(a - bg).sum(-1) > 60
    # 只留连成一片最宽的那段列（设定图左边会带进旁边那个人的一条边）
    cols = m.sum(0) > 2
    runs, start = [], None
    for x, on in enumerate(list(cols) + [False]):
        if on and start is None:
            start = x
        elif not on and start is not None:
            runs.append((start, x))
            start = None
    x0, x1 = max(runs, key=lambda r: m[:, r[0]:r[1]].sum())
    m[:, :x0] = False
    m[:, x1:] = False
    return m


def normalize(img, m):
    """裁到人物、缩放到 HEIGHT 高，返回图、蒙版、脚后跟 x。"""
    rows = np.nonzero(m.any(1))[0]
    cols = np.nonzero(m.any(0))[0]
    t, b = rows.min(), rows.max() + 1
    l, r = cols.min(), cols.max() + 1
    k = HEIGHT / (b - t)
    pad = 30
    box = (l - pad / k, t, r + pad / k, b)
    size = (round((box[2] - box[0]) * k), HEIGHT)
    im = img.crop(tuple(round(v) for v in box)).resize(size, Image.LANCZOS)
    # 底色统一换成深灰，两边看着一样
    mm_full = Image.fromarray((m * 255).astype(np.uint8)).crop(tuple(round(v) for v in box)).resize(size)
    # 门限取高一点，边缘那圈混了品红的半透明像素不要
    im = Image.composite(im, Image.new("RGB", size, (70, 70, 76)), mm_full.point(lambda v: 255 if v > 220 else 0))
    mm = Image.fromarray((m * 255).astype(np.uint8)).crop(tuple(round(v) for v in box)).resize(size)
    mm = np.asarray(mm) > 127
    foot = mm[int(HEIGHT * 0.95):]
    heel = np.nonzero(foot.any(0))[0].min()
    return im, mm, heel


def widths(mm):
    out = []
    for f, _ in ROWS:
        y = min(HEIGHT - 1, int(HEIGHT * f))
        band = mm[max(0, y - 2):y + 3].any(0)
        xs = np.nonzero(band)[0]
        out.append((xs.max() - xs.min() + 1) / HEIGHT if len(xs) else 0.0)
    return out


def main(who, out):
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run([str(GODOT), "--path", str(HERE.parent.parent), "--fixed-fps", "30",
                        "res://prototype/cutout/demo.tscn", "--", who, tmp, "stand"],
                       check=True, capture_output=True)
        rig = Image.open(Path(tmp) / "stand.png").convert("RGB")
    rig_m = mask_of(rig, [(255, 0, 255)] * rig.height)  # 站姿截图是纯品红底
    ref = Image.open(HERE / REF[0]).convert("RGB").crop(REF[1])
    ref_m = mask_of(ref, [ref.getpixel((ref.width - 3, y)) for y in range(ref.height)])
    panels = [("拼出来的（笔直站姿）",) + normalize(rig, rig_m), ("设定图侧面",) + normalize(ref, ref_m)]

    top, gap, left = 50, 40, 50
    table_h = 30 + 24 * len(ROWS)
    width = left + sum(p[1].width for p in panels) + gap * len(panels)
    canvas = Image.new("RGB", (width, top + HEIGHT + 20 + table_h), (40, 40, 46))
    d = ImageDraw.Draw(canvas)
    font = ImageFont.truetype(FONT, 18)
    small = ImageFont.truetype(FONT, 13)
    cell = HEIGHT / CELLS
    x = left
    for title, im, mm, heel in panels:
        canvas.paste(im, (x, top))
        d.text((x, 14), title, fill=(230, 220, 200), font=font)
        # 方格：横线从脚底往上数，竖线从脚后跟往两边数
        for k in range(CELLS + 1):
            y = top + HEIGHT - k * cell
            d.line([(x, y), (x + im.width, y)], fill=(90, 160, 220) if k % 2 == 0 else (60, 100, 140), width=1)
        k = -int(heel / cell)
        while heel + k * cell <= im.width:
            gx = x + heel + k * cell
            d.line([(gx, top), (gx, top + HEIGHT)], fill=(220, 170, 80) if k == 0 else (110, 100, 70), width=1)
            k += 1
        x += im.width + gap
    for k in range(0, CELLS + 1, 2):
        d.text((6, top + HEIGHT - k * cell - 8), f"{k // 2}/8", fill=(120, 180, 230), font=small)

    # 宽度表
    a, b = widths(panels[0][2]), widths(panels[1][2])
    y = top + HEIGHT + 20
    d.text((left, y), "宽度（占身高）    拼出来的    设定图    比值", fill=(230, 220, 200), font=small)
    print("位置        拼出来的  设定图  比值")
    for (f, name), wa, wb in zip(ROWS, a, b):
        y += 24
        ratio = wa / wb if wb else 0
        mark = "  偏粗" if ratio > 1.15 else ("  偏细" if ratio < 0.85 else "")
        line = f"{name}（{f:.2f}）  {wa:.3f}  {wb:.3f}  {ratio:.2f}{mark}"
        d.text((left, y), line, fill=(255, 150, 120) if mark else (200, 200, 200), font=small)
        print(line)
    canvas.save(out)
    print("对照图：", out)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
