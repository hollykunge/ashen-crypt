"""把精怪的像素图集平滑放大，和高清的人物放在一起不显粗。

    python art/side/pack_monsters.py            # 在 mobile 目录下运行
    python art/side/pack_monsters.py --preview out_dir

原图是 source/monsters/*.png：4 列 × 3 行，每格 160×96 的像素画（四步走、起手、挥击、收招、
待机、四格倒地）。游戏里每格的逻辑尺寸仍是 160×96（monster_art.gd 的 CELL / PIVOT 不变），
输出的贴图是它的 TEXEL 倍。

放大不是简单拉伸：先用带容差的 EPX 把斜线和弧线的锯齿补圆（做两遍，得到 4 倍），再缩到
TEXEL 倍。颜色只取原图已有的，所以不会糊，细节也不会凭空多出来——它解决的是「粗」，不是「少」。
哪天有了真正的高清十二格原画，直接放进 source/monsters（每格不小于 160×TEXEL），这里会跳过
放大、只做缩放。
"""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
TEXEL = 3
CELL = (160, 96)
GRID = (4, 3)
NAMES = ["shanxiao", "fire-fox", "guardian", "vine-spirit"]
# 两个颜色差多少以内算「同一块」。生成的像素画不是严格限色，同一块毛皮里也有细微色差。
TOLERANCE = 28.0


def alike(a, b):
    return np.sqrt(((a.astype(np.float32) - b.astype(np.float32)) ** 2).sum(-1)) < TOLERANCE


def epx(pixels):
    """EPX / Scale2x：一个像素的上、左两邻相同而与另外两邻不同，就把那个角让给邻色。"""
    padded = np.pad(pixels, ((1, 1), (1, 1), (0, 0)), mode="edge")
    here = padded[1:-1, 1:-1]
    up, down = padded[:-2, 1:-1], padded[2:, 1:-1]
    left, right = padded[1:-1, :-2], padded[1:-1, 2:]
    height, width = here.shape[:2]
    out = np.zeros((height * 2, width * 2, 4), pixels.dtype)
    out[0::2, 0::2] = np.where((alike(left, up) & ~alike(left, down) & ~alike(up, right))[..., None], up, here)
    out[0::2, 1::2] = np.where((alike(up, right) & ~alike(up, left) & ~alike(right, down))[..., None], right, here)
    out[1::2, 0::2] = np.where((alike(down, left) & ~alike(down, right) & ~alike(left, up))[..., None], left, here)
    out[1::2, 1::2] = np.where((alike(right, down) & ~alike(right, up) & ~alike(down, left))[..., None], down, here)
    return out


def enlarge(sheet):
    target = (CELL[0] * GRID[0] * TEXEL, CELL[1] * GRID[1] * TEXEL)
    if sheet.width >= target[0]:
        return sheet.resize(target, Image.LANCZOS)
    pixels = np.asarray(sheet.resize((CELL[0] * GRID[0], CELL[1] * GRID[1]), Image.NEAREST)).copy()
    # 全透明处的颜色归零，免得透明像素里残留的杂色被当成「不同的邻居」。
    pixels[pixels[..., 3] == 0] = 0
    smooth = Image.fromarray(epx(epx(pixels)), "RGBA")
    return smooth.resize(target, Image.LANCZOS)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview")
    args = parser.parse_args()
    (HERE / "monsters").mkdir(exist_ok=True)
    for name in NAMES:
        sheet = Image.open(HERE / "source" / "monsters" / (name + ".png")).convert("RGBA")
        out = enlarge(sheet)
        out.save(HERE / "monsters" / (name + ".png"), optimize=True)
        print("已出图：%s  %dx%d → %dx%d" % (name, sheet.width, sheet.height, out.width, out.height))
        if args.preview:
            folder = Path(args.preview)
            folder.mkdir(parents=True, exist_ok=True)
            cell = (CELL[0] * TEXEL, CELL[1] * TEXEL)
            before = sheet.resize(out.size, Image.NEAREST).crop((0, 0, cell[0] * 2, cell[1] * 2))
            after = out.crop((0, 0, cell[0] * 2, cell[1] * 2))
            board = Image.new("RGBA", (cell[0] * 4, cell[1] * 2), (122, 122, 140, 255))
            board.alpha_composite(before, (0, 0))
            board.alpha_composite(after, (cell[0] * 2, 0))
            board.save(folder / ("monster-%s.png" % name))


if __name__ == "__main__":
    main()
