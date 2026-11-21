"""把前臂图里原来画的那只拳头去掉，护腕按本来的底边收口（不一刀平切）。

    python3 ../wrist_cut.py parts leather chain     # 在角色目录里运行；原图存成 forearm.orig.png
    python3 ../wrist_cut.py --hand 源图 输出 转轴x 转轴y 半宽   # 手的手腕往上收成圆弧帽

逐列从手腕区（WRIST_Y 往下）往下找：连续几行大多是皮肤，就从那里往下整列删掉。
皮肤按饱和度和亮度认：护腕的灰布饱和度低，皮护腕、铁护腕偏暗，皮肤又饱和又亮。
"""
import colorsys
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

WRIST_Y = 195  # 光身前臂图里，从这一行往下才可能是拳头
SAT, VAL = 0.34, 0.27


def skin_mask(rgb):
    r, g, b = [rgb[..., i] / 255.0 for i in range(3)]
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    return (sat > SAT) & (mx > VAL) & (r >= g)


def cut(folder: Path):
    src = folder / "forearm.orig.png"
    if not src.exists():
        src.write_bytes((folder / "forearm.png").read_bytes())
    m = json.loads((folder / "outfit.json").read_text())["margin"] if (folder / "outfit.json").exists() else 0
    im = np.asarray(Image.open(src).convert("RGBA")).copy()
    gone = skin_mask(im[..., :3].astype(float)) | (im[..., 3] < 40)
    h, w = gone.shape
    for x in range(w):
        col = gone[:, x]
        for y in range(WRIST_Y + m, h - 6):
            if col[y:y + 7].mean() > 0.8:
                im[y:, x, 3] = 0
                break
    Image.fromarray(im).save(folder / "forearm.png")
    print("已去掉拳头：", folder / "forearm.png")


def round_top(src: Path, dst: Path, pivot, half_width: float, cap: float = 60.0):
    """手腕往上只留一个圆弧帽（半宽 half_width、高 cap），塞进护腕底下；不再一刀平切。"""
    im = np.asarray(Image.open(src).convert("RGBA")).copy()
    h, w = im.shape[:2]
    ys, xs = np.mgrid[0:h, 0:w]
    d = ((xs - pivot[0]) / half_width) ** 2 + ((ys - pivot[1]) / cap) ** 2
    keep = np.where(ys >= pivot[1], 1.0, np.clip((1.15 - d) / 0.3, 0, 1))
    im[..., 3] = (im[..., 3] * keep).astype(np.uint8)
    Image.fromarray(im).save(dst)
    print("手腕收成圆弧：", dst)


if __name__ == "__main__":
    if sys.argv[1] == "--hand":
        # --hand 源图 输出 转轴x 转轴y 半宽
        a = sys.argv[2:]
        round_top(Path(a[0]), Path(a[1]), (float(a[2]), float(a[3])), float(a[4]))
    else:
        for d in sys.argv[1:]:
            cut(Path(d))
