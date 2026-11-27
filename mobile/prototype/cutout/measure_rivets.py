"""Measure painted fasteners in local image pixels. Seed windows identify the anatomical joint."""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import map_coordinates

ROOT = Path(__file__).resolve().parent
# Approximate search windows, independent of the currently configured pivot.
WINDOWS = {
    "piying": {"head": (211, 283, 15), "hair": (318, 25, 15),
               "torso:neck": (128, 40, 12), "pelvis": (156, 25, 12),
               "upper_arm": (76, 32, 14), "forearm": (51, 32, 14),
               "hand": (45, 31, 13), "far_hand": (42, 33, 14),
               "thigh": (102, 29, 14), "shin": (62, 30, 14)},
    "nvjiang": {"head": (172, 310, 12), "torso:shoulder": (36, 60, 10),
                "upper_arm": (50, 27, 10), "forearm": (45, 27, 10),
                "hand": (39, 28, 10), "far_hand": (34, 25, 9),
                "thigh": (59, 26, 10), "shin": (69, 28, 11)}
}


def measure(image, window, bare_leather):
    x, y, radius = window
    rgba = np.asarray(image.convert("RGBA"), dtype=float)
    # Gold center bordered by a dark circular rim. Compare two concentric rings.
    gold = (rgba[:, :, 0] * .55 + rgba[:, :, 1] * .45) * rgba[:, :, 3] / 255
    best = (-np.inf, None)
    angles = np.arange(48) * np.pi / 24
    yy, xx = np.mgrid[y-12:y+13, x-12:x+13]
    def ring(r):
        return map_coordinates(gold, [yy[..., None] + np.sin(angles) * r,
                                      xx[..., None] + np.cos(angles) * r], order=1)
    for r in range(max(4, radius - 4), radius + 6):
        contrast = ring(r - 2) - ring(r + 1)
        # Reward an edge around the whole disk. A bright specular spot has
        # strong contrast only on the illuminated side of the fastener.
        scores = np.quantile(contrast, .25, axis=-1) + .25 * contrast.mean(axis=-1)
        if bare_leather:
            outside = ring(r + 3) - ring(r)
            scores = np.quantile(outside, .25, axis=-1) + .35 * outside.mean(axis=-1)
        row, col = np.unravel_index(scores.argmax(), scores.shape)
        if scores[row, col] > best[0]:
            best = (scores[row, col], [int(xx[row, col]), int(yy[row, col]), r])
    return best[1]


def detect(who):
    return {key: measure(Image.open(ROOT / who / "parts" / (key.split(":")[0] + ".png")), window, who == "nvjiang" and key != "head")
            for key, window in WINDOWS[who].items()}


def debug_parts(path, cfg, circles):
    # Keep the assembled Godot render at left. Isolated parts make hidden
    # fasteners and unpainted seam pivots independently inspectable.
    stand = Image.open(path).convert("RGBA")
    board = Image.new("RGB", (1130, 750), "#626568")
    visible = stand.crop((80, 65, 375, 385))
    visible = visible.resize((531, 576), Image.Resampling.LANCZOS)
    board.paste(visible, (0, 45), visible)
    draw = ImageDraw.Draw(board)
    draw.text((18, 18), "Standing rig | red: pivot   green: measured disk", fill="white")
    for i, (part, spec) in enumerate(cfg["parts"].items()):
        image = Image.open(ROOT / path.stem.removeprefix("rig-debug-") / "parts" / (part + ".png")).convert("RGBA")
        x, y = 515 + i % 4 * 153, 20 + i // 4 * 184
        scale = min(140 / image.width, 147 / image.height)
        image = image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS)
        board.paste(image, (x, y), image)
        joints = [spec["pivot"]]
        for key, (cx, cy, radius) in circles.items():
            if key.split(":")[0] != part:
                continue
            r = max(3, radius * scale)
            px, py = x + cx * scale, y + cy * scale
            draw.ellipse((px-r, py-r, px+r, py+r), outline="#76ff78", width=2)
            if ":" in key:
                joints.append(spec[key.split(":")[1]])
        for cx, cy in joints:
            px, py = x + cx * scale, y + cy * scale
            draw.line((px-4, py, px+4, py), fill="red", width=1)
            draw.line((px, py-4, px, py+4), fill="red", width=1)
        draw.text((x, y+147), part + " " + str(spec["pivot"]), fill="white")
    board.crop((0, 0, 1130, 630)).save(path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--debug", type=Path, help="Annotate freshly rendered Godot standing sheets in this folder")
    parser.add_argument("--report", type=Path, help="Write measured centers and radii for the Godot overlay")
    args = parser.parse_args()
    report = {}
    for who in WINDOWS:
        path = ROOT / who / "rig.json"
        cfg = json.loads(path.read_text(encoding="utf8"))
        circles = detect(who)
        print(who, json.dumps(circles))
        report[who] = circles
        if args.debug:
            debug_parts(args.debug / ("rig-debug-" + who + ".png"), cfg, circles)
        if args.apply:
            for key, (x, y, radius) in circles.items():
                part, _, joint = key.partition(":")
                cfg["parts"][part][joint or "pivot"] = [x, y]
            path.write_text(json.dumps(cfg, indent=1, ensure_ascii=False) + "\n", encoding="utf8")
    if args.report:
        args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf8")
