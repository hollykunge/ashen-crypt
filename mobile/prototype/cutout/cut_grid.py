"""把 AI 出的皮影拆件图按网格切成单个部件，自动估出各件的关节点，写出 rig.json。

    cd piying   # 在角色目录里运行
    python3 ../cut_grid.py source/parts-1.png parts --rows 3 --cols 4 \
        --names head,hair,torso,pelvis,upper_arm,forearm,hand,far_hand,thigh,shin,weapon,skirt_front \
        --template ../swordsman/rig.template.json

和 cut.py 的区别：皮影的镂空花纹、流苏会碎成很多不相连的小块，按连通块切会把它们当碎屑丢掉；
这里一格就是一件，格子里所有不透明的像素都归这一件。出图要求见 prompts.json：
每件竖直下垂、上端是钉着铆钉的圆盘（转轴），所以关节点可以按轮廓估出来，拼起来再看、再在 rig.json 里微调。
"""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image

PAD = 8  # 部件四周留的透明边
ALPHA = 24  # 不透明度低于它算透明
DILATE = 6  # 把镂空碎块连成一件时膨胀几像素


def to_alpha(img):
    """有真透明就直接用；否则白底转透明（离白越近越透明）"""
    a = np.asarray(img.convert("RGBA")).copy()
    if a[..., 3].min() < 250:
        return a
    rgb = a[..., :3].astype(np.float32)
    low = rgb.min(-1)
    alpha = np.clip((248 - low) / (248 - 225), 0, 1)
    k = np.maximum(alpha, 1e-3)[..., None]
    a[..., :3] = np.clip((rgb - 255 * (1 - k)) / k, 0, 255)
    a[..., 3] = alpha * 255
    return a


def dilate(m, n):
    for _ in range(n):
        p = np.pad(m, 1)
        m = p[1:-1, 1:-1] | p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:]
    return m


def label(m):
    """连通块标记（8 邻接）：每个前景像素先拿自己的序号，反复取邻居里最大的，直到不再变"""
    lab = np.where(m, np.arange(1, m.size + 1).reshape(m.shape), 0)
    while True:
        p = np.pad(lab, 1)
        nb = np.maximum.reduce([p[1 + dy:p.shape[0] - 1 + dy, 1 + dx:p.shape[1] - 1 + dx]
                                for dy in (-1, 0, 1) for dx in (-1, 0, 1)])
        new = np.where(m, nb, 0)
        if np.array_equal(new, lab):
            return lab
        lab = new


def rows_span(m, y):
    xs = np.nonzero(m[int(np.clip(y, 0, m.shape[0] - 1))])[0]
    return (xs.min(), xs.max()) if len(xs) else (None, None)


def center_x(m, y0, y1):
    """y0..y1 这几行不透明像素的平均横向中心"""
    cs = []
    for y in range(int(y0), int(y1) + 1):
        lo, hi = rows_span(m, y)
        if lo is not None:
            cs.append((lo + hi) / 2)
    return float(np.mean(cs)) if cs else m.shape[1] / 2


def top_disc(m):
    """上端圆盘的圆心：取顶上一段里最宽那一行的宽度当直径"""
    ys = np.nonzero(m.any(1))[0]
    t, h = ys.min(), ys.max() - ys.min()
    best_w, best_y = 0, t
    for y in range(t, t + max(int(h * 0.2), 3)):
        lo, hi = rows_span(m, y)
        if lo is not None and hi - lo > best_w and y - t < (hi - lo) * 0.75:
            best_w, best_y = hi - lo, y
    r = best_w / 2
    return [round(center_x(m, t, t + r), 1), round(float(t + r), 1)]


def hole(m):
    """拳头里穿刀柄的孔：被不透明像素包住的最大一块透明区域的中心"""
    from collections import deque
    h, w = m.shape
    seen = np.zeros_like(m)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if not m[y, x] and not seen[y, x]:
                seen[y, x] = True; q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if not m[y, x] and not seen[y, x]:
                seen[y, x] = True; q.append((y, x))
    while q:  # 先把跟外面连着的透明区域都标掉
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            yy, xx = y + dy, x + dx
            if 0 <= yy < h and 0 <= xx < w and not m[yy, xx] and not seen[yy, xx]:
                seen[yy, xx] = True; q.append((yy, xx))
    inner = ~m & ~seen
    best = []
    lab = np.zeros_like(m, dtype=np.int32)
    n = 0
    for y0, x0 in zip(*np.nonzero(inner)):
        if lab[y0, x0]:
            continue
        n += 1; lab[y0, x0] = n; pts = [(y0, x0)]; q = deque([(y0, x0)])
        while q:
            y, x = q.popleft()
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                yy, xx = y + dy, x + dx
                if 0 <= yy < h and 0 <= xx < w and inner[yy, xx] and not lab[yy, xx]:
                    lab[yy, xx] = n; pts.append((yy, xx)); q.append((yy, xx))
        if len(pts) > len(best):
            best = pts
    if not best:
        return None
    p = np.array(best)
    return [round(float(p[:, 1].mean()), 1), round(float(p[:, 0].mean()), 1)]


def joints(name, m):
    ys, xs = np.nonzero(m)
    t, b, l, r = ys.min(), ys.max(), xs.min(), xs.max()
    h, w = b - t, r - l
    at = lambda f: round(float(t + f * h), 1)
    cx = lambda f0, f1: round(center_x(m, t + f0 * h, t + f1 * h), 1)
    j = {}
    if name in ("upper_arm", "thigh"):
        j = {"pivot": top_disc(m), "end": [cx(0.84, 0.9), at(0.87)]}
    elif name == "forearm":
        j = {"pivot": top_disc(m), "wrist": [cx(0.92, 0.98), at(0.96)]}
    elif name in ("hand", "far_hand"):
        j = {"pivot": top_disc(m)}
        if name == "hand":
            j["grip"] = hole(m) or [cx(0.6, 0.7), at(0.65)]
            j["grip_angle"] = 30.0
    elif name == "shin":
        j = {"pivot": top_disc(m), "ankle": [cx(0.7, 0.75), at(0.8)], "sole": [cx(0.7, 0.75), float(b)]}
    elif name == "head":
        j = {"pivot": [cx(0.9, 0.95), at(0.92)], "hair": [round(float(l + 0.3 * w), 1), at(0.25)], "behind": True}
    elif name == "hair":
        k = np.argmax(xs - ys)  # 最靠右上的一点是发带的根
        j = {"pivot": [float(xs[k]) - 6, float(ys[k]) + 6]}
    elif name == "torso":
        j = {"pivot": [cx(0.75, 0.8), at(0.78)], "neck": [cx(0.0, 0.05), at(0.03)],
             "shoulder": [cx(0.15, 0.25), at(0.18)], "hip": [cx(0.93, 0.98), at(0.97)]}
    elif name == "pelvis":
        j = {"pivot": [cx(0.0, 0.05), at(0.02)], "hip": [cx(0.3, 0.4), at(0.35)]}
    elif name == "weapon":
        col = m[:, l:l + int(0.35 * w)].sum(0)
        g = int(np.argmax(col))  # 护手是剑柄那一段最高的一列
        hx = l + g * 0.55  # 握点在护手和柄尾中间
        hy = center_x(m.T, hx - 2, hx + 2)
        tip_k = np.argmax(xs)
        j = {"pivot": [round(float(hx), 1), round(float(hy), 1)], "tip": [float(xs[tip_k]), float(ys[tip_k])]}
    elif name.startswith("skirt"):
        j = {"pivot": [cx(0.0, 0.04), at(0.01)]}
    return j


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sheet"); ap.add_argument("out")
    ap.add_argument("--rows", type=int, default=3); ap.add_argument("--cols", type=int, default=4)
    ap.add_argument("--names", required=True); ap.add_argument("--template")
    a = ap.parse_args()
    names = a.names.split(",")
    rgba = to_alpha(Image.open(a.sheet))
    H, W = rgba.shape[:2]
    out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
    # 镂空把一件切成好多不相连的碎块，先膨胀几像素把同一件的碎块连起来，再按连通块分；
    # 每块归到它中心所在的格子。AI 画的件常常伸出自己的格子（刀比格子长），按格子硬切会把它截断
    solid = rgba[..., 3] > ALPHA
    lab = label(dilate(solid, DILATE))
    lab[~solid] = 0
    owner = {}
    ys, xs = np.nonzero(lab)
    ids = lab[ys, xs]
    for i in np.unique(ids):
        sel = ids == i
        sy, sx = ys[sel].mean(), xs[sel].mean()
        owner.setdefault(min(int(sy * a.rows / H), a.rows - 1) * a.cols + min(int(sx * a.cols / W), a.cols - 1), []).append(i)
    parts = {}
    for k, name in enumerate(names):
        m_all = np.isin(lab, owner.get(k, []))
        ys, xs = np.nonzero(m_all)
        y0, y1 = max(ys.min() - PAD, 0), min(ys.max() + PAD + 1, H)
        x0, x1 = max(xs.min() - PAD, 0), min(xs.max() + PAD + 1, W)
        piece = rgba[y0:y1, x0:x1].copy()
        piece[..., 3][~m_all[y0:y1, x0:x1]] = 0
        piece[..., 3][piece[..., 3] <= ALPHA] = 0
        Image.fromarray(piece).save(out / f"{name}.png")
        parts[name] = joints(name, piece[..., 3] > ALPHA)
        print(name, piece.shape[1], "x", piece.shape[0], parts[name])
    # 跨件的接点：臀胯、前衣摆挂在躯干的腰带底边上；前臂到手腕为止，握刀手接在手腕上
    if "torso" in parts:
        hip = parts["torso"]["hip"]
        if "pelvis" in parts:
            parts["pelvis"]["at"] = hip
        for flap in ("skirt_front", "skirt_back"):
            if flap in parts:
                parts[flap]["at"] = [hip[0] + (12 if flap == "skirt_front" else -12), hip[1] - 10]
    if "forearm" in parts:
        fw = parts["forearm"]["wrist"]
        parts["forearm"].update({"split": fw[1], "split_x": fw[0], "cleaned": True})
    rig = json.load(open(a.template)) if a.template else {}
    old = rig.get("parts", {})
    rig["base_dir"] = f"res://prototype/cutout/{Path.cwd().name}/{a.out}"
    for name, j in parts.items():  # 关节点重估，手调过的缩放等其它参数保留
        keep = {k: v for k, v in old.get(name, {}).items() if k in ("scale", "behind", "tilt")} if Path("rig.json").exists() else {}
        parts[name] = {**j, **keep}
    rig["parts"] = parts
    json.dump(rig, open("rig.json", "w"), ensure_ascii=False, indent=1)
    print("写出 rig.json")


if __name__ == "__main__":
    main()
