"""把部件的关节那头修成以转轴为圆心的圆头。

    python3 ../joint_caps.py parts/thigh.png 75 115.9 up      # 在角色目录里运行；原图存成 <名>.orig.png

拼件转动时，转轴另一侧那截如果不是圆的，转起来轮廓就一直变：大腿往前抬，顶端从臀部后面翘出去；
往后蹬，又在胯前顶出尖角。修成以转轴为圆心的圆，不管转多少度轮廓都不变。
半径取转轴那一行部件左右边缘到转轴的较远距离（圆刚好包住整个宽度）。
up 是修转轴上面那头（大腿顶、小腿顶），down 是修下面那头。
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image


def cap(path: Path, px: float, py: float, side: str, soft: float = 3.0):
    orig = path.with_name(path.stem + ".orig.png")
    if not orig.exists():
        orig.write_bytes(path.read_bytes())
    im = np.asarray(Image.open(orig).convert("RGBA")).copy()
    a = im[..., 3] > 128
    row = np.nonzero(a[int(py)])[0]
    r = max(px - row.min(), row.max() - px)
    h, w = a.shape
    ys, xs = np.mgrid[0:h, 0:w].astype(float)
    d = np.hypot(xs - px, ys - py)
    beyond = (ys < py) if side == "up" else (ys > py)
    keep = np.where(beyond, np.clip((r - d) / soft, 0, 1), 1.0)
    im[..., 3] = (im[..., 3] * keep).astype(np.uint8)
    Image.fromarray(im).save(path)
    print(f"{path}: 转轴 ({px}, {py}) 半径 {r:.0f}，{'上' if side == 'up' else '下'}头修成圆")


if __name__ == "__main__":
    cap(Path(sys.argv[1]), float(sys.argv[2]), float(sys.argv[3]), sys.argv[4])
