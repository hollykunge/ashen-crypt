"""把躯干图后背鼓出去的那块按一条直线削掉，背立直。原图存成 torso.orig.png。

    python3 ../back_trim.py parts set-leather set-iron     # 在角色目录里运行

直线从领口后面 TOP 到腰 BOTTOM（光身躯干图的像素坐标）；线左边（后面）的像素去掉，留 3 像素软边。
换装目录的躯干图四周多 margin（outfit.json），坐标跟着平移。腰以下不动。
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

TOP = (36.0, 25.0)
BOTTOM = (14.0, 200.0)


def trim(folder: Path):
    src = folder / "torso.png"
    orig = folder / "torso.orig.png"
    if not orig.exists():
        orig.write_bytes(src.read_bytes())
    m = json.loads((folder / "outfit.json").read_text())["margin"] if (folder / "outfit.json").exists() else 0
    im = np.asarray(Image.open(orig).convert("RGBA")).copy()
    h, w = im.shape[:2]
    ys, xs = np.mgrid[0:h, 0:w].astype(float)
    (x0, y0), (x1, y1) = (TOP[0] + m, TOP[1] + m), (BOTTOM[0] + m, BOTTOM[1] + m)
    line_x = x0 + (x1 - x0) * (ys - y0) / (y1 - y0)
    keep = np.where((ys >= y0) & (ys <= y1), np.clip((xs - line_x) / 3.0, 0, 1), 1.0)
    im[..., 3] = (im[..., 3] * keep).astype(np.uint8)
    Image.fromarray(im).save(src)
    print("后背削直：", src)


if __name__ == "__main__":
    for d in sys.argv[1:]:
        trim(Path(d))
