"""把 AI 出的一张皮影精怪图（2×2 四只）切开，每只按皮影戏的挑签子动法摆成游戏用的 4×3 帧图。

    python3 mobile/prototype/cutout/pack_puppet_monsters.py <精怪图.png> <输出目录> [--preview 预览.png]

皮影里的妖怪多是一整块皮子，艺人挑着签子演：走起来整块一颠一摇，蓄力往后一仰，出击往前一扑，
被打死往后翻倒。所以每只只要一张图，12 帧都是同一张图转一转、挪一挪：
    0-3 走（颠、摇）  4 蓄力  5 出击  6 收招  7 待机  8-11 倒地
格子、落脚点、身高和 monster_art.gd 一致（每格 160×96 × TEXEL 3，脚在 (80, 76)，站高 64）。
"""
import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from cut_grid import ALPHA, DILATE, dilate, label, to_alpha  # noqa: E402

TEXEL = 3
CELL = (160 * TEXEL, 96 * TEXEL)
PIVOT = (80 * TEXEL, 76 * TEXEL)
HEIGHT = 64 * TEXEL - 2  # 站着从脚到头顶
MAX_W = 150 * TEXEL  # 太长的（狐狸尾巴）按宽度收
NAMES = ["shanxiao", "fire-fox", "guardian", "vine-spirit"]  # 图上左上、右上、左下、右下
# 每帧：(往前倾的角度°, 横移, 上提, 不透明度)，倾角绕脚底转（正值往前、朝右扑），位移以身高为单位
FRAMES = [
    (-3, 0.00, 0.00, 1), (2, 0.01, 0.06, 1), (4, 0.0, 0.00, 1), (-1, 0.01, 0.06, 1),  # 走：落地、颠起、落地、颠起
    (-11, -0.06, 0.02, 1),  # 蓄力：往后仰
    (14, 0.16, 0.05, 1),  # 出击：往前扑、身子离地
    (6, 0.09, 0.0, 1),  # 收招
    (0, 0.0, 0.0, 1),  # 待机
    (-22, -0.02, 0.0, 1), (-50, -0.06, 0.0, 1), (-78, -0.1, -0.02, 0.8), (-90, -0.12, -0.05, 0.45),  # 往后翻倒、淡掉
]


def split_sheet(path):
    rgba = to_alpha(Image.open(path))
    H, W = rgba.shape[:2]
    solid = rgba[..., 3] > ALPHA
    lab = label(dilate(solid, DILATE))
    lab[~solid] = 0
    ys, xs = np.nonzero(lab)
    ids = lab[ys, xs]
    owner = {}
    for i in np.unique(ids):
        sel = ids == i
        q = min(int(ys[sel].mean() * 2 / H), 1) * 2 + min(int(xs[sel].mean() * 2 / W), 1)
        owner.setdefault(q, []).append(i)
    out = []
    for q in range(4):
        m = np.isin(lab, owner.get(q, []))
        ys, xs = np.nonzero(m)
        piece = rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1].copy()
        piece[..., 3][~m[ys.min():ys.max() + 1, xs.min():xs.max() + 1]] = 0
        out.append(Image.fromarray(piece))
    return out


def feet_x(img):
    a = np.asarray(img)[..., 3] > ALPHA
    rows = np.nonzero(a.any(1))[0]
    low = a[rows.max() - max(int(len(rows) * 0.06), 2):rows.max() + 1]
    xs = np.nonzero(low.any(0))[0]
    return (xs.min() + xs.max()) / 2


def frame(img, k, tilt, dx, up, alpha):
    """把精怪绕脚底转 tilt 度（往前为正）、挪一挪，贴到一格里；脚底对在 PIVOT"""
    w, h = img.size
    fx = feet_x(img)
    cell = Image.new("RGBA", CELL, (0, 0, 0, 0))
    # 往后翻倒时绕后脚跟转，往前扑时绕前脚掌转，才像整块皮子立在台口上翻过去
    a = np.asarray(img)[..., 3] > ALPHA
    cols = np.nonzero(a[-max(int(h * 0.06), 2):].any(0))[0]
    pivot_x = cols.min() if tilt < 0 else cols.max() if tilt > 0 else fx
    big = Image.new("RGBA", (w * 3, h * 3), (0, 0, 0, 0))
    big.paste(img, (w, h))
    px, py = w + pivot_x, h + h  # 转轴：脚底那一行
    rot = big.rotate(-tilt, resample=Image.BICUBIC, center=(px, py))  # PIL 逆时针为正，往前（顺时针）取负
    if alpha < 1:
        r = np.asarray(rot).copy()
        r[..., 3] = (r[..., 3] * alpha).astype(np.uint8)
        rot = Image.fromarray(r)
    # 转轴在格子里的落点：脚底中点对在 PIVOT，转轴相对脚底中点不变，再加上这一帧的位移
    ox = PIVOT[0] + (pivot_x - fx) + dx * h - px
    oy = PIVOT[1] - up * h - py
    # 翻倒以后躺平的身子可能比格子还靠外，整块挪回格子里（留一点边）
    bx = np.nonzero((np.asarray(rot)[..., 3] > ALPHA).any(0))[0]
    if len(bx):
        ox = min(max(ox, 6 - bx.min()), CELL[0] - 6 - bx.max())
    cell.paste(rot, (int(round(ox)), int(round(oy))), rot)
    return cell


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sheet"); ap.add_argument("out"); ap.add_argument("--preview")
    a = ap.parse_args()
    out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
    previews = []
    for name, img in zip(NAMES, split_sheet(a.sheet)):
        w, h = img.size
        s = min(HEIGHT / h, MAX_W / w)
        img = img.resize((max(int(w * s), 1), max(int(h * s), 1)), Image.LANCZOS)
        atlas = Image.new("RGBA", (CELL[0] * 4, CELL[1] * 3), (0, 0, 0, 0))
        for k, f in enumerate(FRAMES):
            atlas.paste(frame(img, k, *f), ((k % 4) * CELL[0], (k // 4) * CELL[1]))
        atlas.save(out / f"{name}.png")
        previews.append(atlas)
        print(name, img.size)
    if a.preview:
        p = Image.new("RGB", (CELL[0] * 4, CELL[1] * 3 * len(previews)), (205, 175, 125))
        for i, at in enumerate(previews):
            p.paste(at, (0, i * CELL[1] * 3), at)
        p.resize((p.width // 2, p.height // 2)).save(a.preview)


if __name__ == "__main__":
    main()
