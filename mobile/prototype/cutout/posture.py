"""量站姿：后背鼓多少、头往前探多少、腿直不直，跟设定图比。

    python3 posture.py swordsman <侧面参考图>

都按身高的比例。后背鼓：肩下（0.14 身高处）到腰（0.40）那段后背线，比两端连成的直线最多往后鼓出多少；
头前探：脸最前面到腰部后背的水平距离；腿：脚踝到胯的水平偏移（站直时应接近 0）。
"""
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

import compare as C


def stand_mask(who):
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run([str(C.GODOT), "--path", str(C.HERE.parent.parent), "--fixed-fps", "30",
                        "res://prototype/cutout/demo.tscn", "--", who, tmp, "stand"], check=True, capture_output=True)
        rig = Image.open(Path(tmp) / "stand.png").convert("RGB")
    return C.mask_of(rig, [(255, 0, 255)] * rig.height)


def ref_mask(reference):
    ref = Image.open(reference).convert("RGB")
    return C.mask_of(ref, [ref.getpixel((ref.width - 3, y)) for y in range(ref.height)])


def measure(m):
    rows = np.nonzero(m.any(1))[0]
    t, b = rows.min(), rows.max()
    H = b - t
    def back(f):
        return np.nonzero(m[int(t + H * f)])[0].min()
    def front(f):
        return np.nonzero(m[int(t + H * f)])[0].max()
    fs = np.arange(0.14, 0.331, 0.02)  # 到腰带上面为止，0.40 以下是臀部，会把「后背」拉到后面
    xs = np.array([back(f) for f in fs])
    chord = xs[0] + (xs[-1] - xs[0]) * (fs - fs[0]) / (fs[-1] - fs[0])
    bulge = (chord - xs).max() / H  # 往后（左）鼓为正
    lean = (xs[0] - xs[-1]) / H  # 肩下的后背比腰的后背靠前多少（正值是上身前倾）
    face = max(front(f) for f in (0.08, 0.1, 0.12))
    return {"后背鼓": round(bulge, 3), "上身前倾": round(lean, 3), "头前探": round((face - back(0.32)) / H, 3)}


if __name__ == "__main__":
    print("拼出来的", measure(stand_mask(sys.argv[1])))
    print("设定图  ", measure(ref_mask(sys.argv[2])))
