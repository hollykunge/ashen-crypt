"""把 AI 出的皮影特效图（2×3：团花爆点、火焰星芒、月牙刀光、花瓣、火苗、纸屑）打成游戏的击打特效帧图。

    python3 mobile/prototype/cutout/pack_puppet_fx.py <特效图.png> <输出目录> [--preview 预览.png]

和 scripts/fx_art.gd 的 SHEETS 同规格：一行一个五行（金木水火土、空手），一列一帧。
命中（hit）：镂空团花从小炸开、转一点、淡掉，几片花瓣往前飞；暴击（crit）：火焰星芒叠团花一起炸开。
"""
import argparse
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from cut_grid import ALPHA, DILATE, dilate, label, to_alpha  # noqa: E402

ROWS = ["jin", "mu", "shui", "huo", "tu", "none"]
# 五行的颜色：原图是红金两色，直接相乘蓝色会发褐，所以先取明暗再上色（空手保持原色）
TINT = {"jin": (1.0, 0.9, 0.55), "mu": (0.45, 0.92, 0.38), "shui": (0.38, 0.68, 1.0),
        "huo": (1.0, 0.42, 0.2), "tu": (0.92, 0.66, 0.3), "none": None}
# 规格照 fx_art.gd：格子、帧数；center 是爆点在格子里的位置（原来那套特效的中心）
# TEXEL：贴图比格子的逻辑尺寸大几倍（fx_art.gd 的 texel），层主身上放大也不糊
TEXEL = 2
SHEETS = {"hit": {"cell": (113, 79), "frames": 10, "center": (42, 32), "size": 58},
          "crit": {"cell": (178, 135), "frames": 7, "center": (80, 70), "size": 112}}
for _s in SHEETS.values():
    _s["cell"] = tuple(v * TEXEL for v in _s["cell"])
    _s["center"] = tuple(v * TEXEL for v in _s["center"])
    _s["size"] *= TEXEL


def pieces(path):
    """按 2×3 切出六件，每件裁到自己的外框"""
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
        q = min(int(ys[sel].mean() * 2 / H), 1) * 3 + min(int(xs[sel].mean() * 3 / W), 2)
        owner.setdefault(q, []).append(i)
    out = []
    for q in range(6):
        m = np.isin(lab, owner.get(q, []))
        ys, xs = np.nonzero(m)
        p = rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1].copy()
        p[..., 3][~m[ys.min():ys.max() + 1, xs.min():xs.max() + 1]] = 0
        out.append(Image.fromarray(p))
    return out


def tinted(img, tint, alpha):
    a = np.asarray(img).astype(np.float32)
    if tint is not None:
        lum = (a[..., :3] @ np.array([0.299, 0.587, 0.114], np.float32))[..., None]
        a[..., :3] = a[..., :3] * 0.15 + np.clip(lum * 1.7, 0, 255) * np.array(tint, np.float32) * 0.85
    a[..., 3] *= alpha
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def stamp(cell, img, center, size, angle, alpha, tint):
    w, h = img.size
    s = size / max(w, h)
    if s * max(w, h) < 2:
        return
    im = img.resize((max(int(w * s), 1), max(int(h * s), 1)), Image.LANCZOS).rotate(angle, resample=Image.BICUBIC, expand=True)
    im = tinted(im, tint, alpha)
    cell.alpha_composite(im, (int(center[0] - im.width / 2), int(center[1] - im.height / 2)))


def build(kind, parts, rng):
    spec = SHEETS[kind]
    cw, ch = spec["cell"]
    n = spec["frames"]
    burst, star, _slash, petal, ember, _ash = parts
    sheet = Image.new("RGBA", (cw * n, ch * len(ROWS)), (0, 0, 0, 0))
    # 几片花瓣、火苗的飞行路线：从爆点往前、往上飞散（每个五行同一套，只换颜色）
    flyers = [(rng.uniform(-0.6, 0.9), rng.uniform(0.5, 1.0), rng.choice([petal, ember]), rng.uniform(0, 360)) for _ in range(5 if kind == "hit" else 9)]
    for r, el in enumerate(ROWS):
        for f in range(n):
            t = f / (n - 1)
            cell = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
            cx, cy = spec["center"]
            grow = 1 - (1 - min(t / 0.45, 1)) ** 3  # 前四成多一点快速炸开
            fade = 1.0 if t < 0.5 else max(0.0, 1 - (t - 0.5) / 0.5)
            if kind == "crit":
                stamp(cell, star, (cx, cy), spec["size"] * (0.35 + 0.75 * grow), -40 * t, fade, TINT[el])
                stamp(cell, burst, (cx, cy), spec["size"] * (0.25 + 0.45 * grow), 60 * t, fade, TINT[el])
            else:
                stamp(cell, burst, (cx + 14 * t, cy), spec["size"] * (0.3 + 0.8 * grow), 50 * t, fade, TINT[el])
            for dx, up, img, a0 in flyers:
                d = spec["size"] * 0.9 * t
                px = cx + (0.4 + dx) * d
                py = cy - up * d + 0.6 * spec["size"] * t * t
                stamp(cell, img, (px, py), spec["size"] * 0.16, a0 + 400 * t, min(1.0, fade * 1.3) * (t > 0.08), TINT[el])
            sheet.paste(cell, (f * cw, r * ch))
    return sheet


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sheet"); ap.add_argument("out"); ap.add_argument("--preview")
    a = ap.parse_args()
    import random
    rng = random.Random(7)
    parts = pieces(a.sheet)
    out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
    sheets = {k: build(k, parts, rng) for k in SHEETS}
    for k, s in sheets.items():
        s.save(out / f"{k}.png")
        print(k, s.size)
    if a.preview:
        h = sum(s.height for s in sheets.values())
        p = Image.new("RGB", (max(s.width for s in sheets.values()), h), (205, 160, 100))
        y = 0
        for s in sheets.values():
            p.paste(s, (0, y), s); y += s.height
        p.save(a.preview)


if __name__ == "__main__":
    main()
