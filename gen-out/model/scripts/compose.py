"""Find a fixed 2D draw order for slot layers (data-driven), composite every outfit combination and compare
with the true 3D render.

python compose.py <render_dir> <out_dir>
"""
import json, os, sys, time
import numpy as np
from PIL import Image

RD, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
meta = json.load(open(os.path.join(RD, "render_meta.json")))
combos = json.load(open(os.path.join(RD, "combos.json")))
FRAMES, LAYERS = meta["frames"], meta["layers"]


def head_variant(outfit):
    return "hooded" if outfit.get("hood", "none") != "none" else "bare"


def variant(outfit, slot):
    return head_variant(outfit) if slot == "head" else outfit[slot]


# elements of the draw order: (slot, side)
ELEMS = sorted({(slot, side) for slot, vs in LAYERS.items() for v, sides in vs.items() for side in sides})


def load(path, scale):
    im = Image.open(path).convert("RGBA")
    if scale != 1:
        im = im.resize((im.width // scale, im.height // scale), Image.BOX)
    a = np.asarray(im).astype(np.float32) / 255.0
    a[..., :3] *= a[..., 3:4]  # premultiplied
    return a


def load_all(scale):
    lay, tru = {}, {}
    for slot, vs in LAYERS.items():
        for v, sides in vs.items():
            for side in sides:
                for fr in FRAMES:
                    lay[(slot, v, side, fr)] = load(os.path.join(RD, "layers", slot, v, side, f"f{fr:02d}.png"), scale)
    for c in combos:
        for fr in FRAMES:
            tru[(c, fr)] = load(os.path.join(RD, "truth3d", c, f"f{fr:02d}.png"), scale)
    return lay, tru


def composite(lay, outfit, fr, order):
    out = None
    for slot, side in order:
        key = (slot, variant(outfit, slot), side, fr)
        L = lay.get(key)
        if L is None:
            continue
        out = L.copy() if out is None else L + out * (1.0 - L[..., 3:4])
    return out


def mismatch(comp, truth):
    ma, mb = comp[..., 3] > 0.5, truth[..., 3] > 0.5
    union = ma | mb
    diff = np.abs(comp[..., :3] - truth[..., :3]).max(-1)
    bad = union & ((ma != mb) | (diff > 40 / 255))
    return bad, union


def score(lay, tru, order):
    b = u = 0
    for c, outfit in combos.items():
        for fr in FRAMES:
            bad, union = mismatch(composite(lay, outfit, fr, order), tru[(c, fr)])
            b += bad.sum()
            u += union.sum()
    return b / u


# ---------------- greedy insertion search at 1/4 resolution
t0 = time.time()
lay4, tru4 = load_all(4)
rank = {("shoulder", "far"): 0, ("arms", "far"): 1, ("torso", "far"): 2, ("legs", "far"): 3, ("feet", "far"): 4,
        ("legs", "mid"): 5, ("feet", "mid"): 6, ("legs", "near"): 7, ("feet", "near"): 8, ("torso", "mid"): 9,
        ("arms", "mid"): 10, ("head", "mid"): 11, ("hood", "far"): 12, ("hood", "mid"): 13, ("hood", "near"): 14,
        ("arms", "near"): 15, ("torso", "near"): 16, ("shoulder", "mid"): 17, ("shoulder", "near"): 18}
order = sorted(ELEMS, key=lambda e: rank.get(e, 99))
best = score(lay4, tru4, order)
print(f"start order score {best*100:.3f}%  ({time.time()-t0:.0f}s)", flush=True)
improved = True
passes = 0
while improved and passes < 4:
    improved = False
    passes += 1
    for e in list(order):
        base = [x for x in order if x != e]
        cand_best, cand_pos = best, None
        for pos in range(len(base) + 1):
            cand = base[:pos] + [e] + base[pos:]
            if cand == order:
                continue
            s = score(lay4, tru4, cand)
            if s < cand_best - 1e-6:
                cand_best, cand_pos = s, pos
        if cand_pos is not None:
            order = base[:cand_pos] + [e] + base[cand_pos:]
            best = cand_best
            improved = True
            print(f"  pass {passes}: move {e} -> {cand_pos}: {best*100:.3f}%", flush=True)
print("FINAL ORDER", order, f"{best*100:.3f}% (1/4 res)", flush=True)
del lay4, tru4

# ---------------- full-resolution outputs with the chosen order
lay, tru = load_all(1)


def to_img(a, bg=(236, 236, 236)):
    rgb = a[..., :3] + (1 - a[..., 3:4]) * (np.array(bg) / 255.0)
    return (np.clip(rgb, 0, 1) * 255).astype(np.uint8)


rows = []
for c, outfit in combos.items():
    cdir = os.path.join(OUT, "composite", c)
    os.makedirs(cdir, exist_ok=True)
    tiles = []
    for fr in FRAMES:
        comp = composite(lay, outfit, fr, order)
        Image.fromarray((np.clip(np.dstack([comp[..., :3] / np.maximum(comp[..., 3:4], 1e-6), comp[..., 3:4]]), 0, 1) * 255)
                        .astype(np.uint8), "RGBA").save(os.path.join(cdir, f"f{fr:02d}.png"))
        bad, union = mismatch(comp, tru[(c, fr)])
        ma, mb = comp[..., 3] > 0.5, tru[(c, fr)][..., 3] > 0.5
        rows.append({"combo": c, "frame": fr, "alpha_iou": float((ma & mb).sum() / max((ma | mb).sum(), 1)),
                     "mismatch_pct": float(bad.sum() / max(union.sum(), 1) * 100)})
        d = to_img(comp).copy()
        d[bad] = (255, 0, 255)
        tiles.append(np.concatenate([to_img(tru[(c, fr)]), to_img(comp), d], 0))
    sheet = Image.fromarray(np.concatenate(tiles, 1))
    sheet.resize((sheet.width // 2, sheet.height // 2), Image.LANCZOS).save(os.path.join(OUT, f"check_{c}.png"))

json.dump({"draw_order_back_to_front": order, "rows": rows}, open(os.path.join(OUT, "mix_metrics.json"), "w"), indent=1)
by = {}
for r in rows:
    by.setdefault(r["combo"], []).append(r)
means = sorted(((np.mean([r["mismatch_pct"] for r in rs]), c) for c, rs in by.items()))
with open(os.path.join(OUT, "mix_metrics.md"), "w", encoding="utf-8") as f:
    f.write(f"All {len(by)} combinations x {len(FRAMES)} frames.\n\n")
    f.write(f"- silhouette IoU (2D stack vs 3D): mean {np.mean([r['alpha_iou'] for r in rows]):.4f}, min {min(r['alpha_iou'] for r in rows):.4f}\n")
    f.write(f"- mismatched pixels: mean {np.mean([r['mismatch_pct'] for r in rows]):.2f}%, "
            f"best outfit {means[0][1]} {means[0][0]:.2f}%, worst outfit {means[-1][1]} {means[-1][0]:.2f}%, "
            f"worst single frame {max(r['mismatch_pct'] for r in rows):.2f}%\n\n")
    f.write("| outfit (torso arms legs feet shoulder hood) | mean IoU | mean mismatch | worst frame |\n|---|---|---|---|\n")
    for m, c in means:
        rs = by[c]
        w = max(rs, key=lambda r: r["mismatch_pct"])
        f.write(f"| {c} | {np.mean([r['alpha_iou'] for r in rs]):.4f} | {m:.2f}% | f{w['frame']:02d} {w['mismatch_pct']:.2f}% |\n")
print(open(os.path.join(OUT, "mix_metrics.md"), encoding="utf-8").read()[:1500])
