"""Render every runtime transparent texture on black and magenta plus a 4x edge detail."""
from pathlib import Path

import numpy as np
from PIL import Image

MOBILE = Path(__file__).resolve().parents[2]
OUT = MOBILE / "art/piying/ui-shots-v6/edges"


def inspect(path, detail_point=None):
    image = Image.open(path).convert("RGBA")
    alpha = image.getchannel("A")
    if alpha.getextrema()[0] == 255:
        return
    values = np.asarray(alpha)
    # Select a visible left contour near mid-height, including soft AA and its interior.
    ys, xs = np.where(values > 96)
    if not len(xs):
        raise ValueError(f"Empty sprite: {path}")
    y = int(np.median(ys))
    row = np.argmin(abs(ys - y))
    x, y = int(xs[row]), int(ys[row])
    if detail_point is not None:
        x, y = detail_point
    detail = image.crop((x-16, y-32, x+48, y+32)).resize((256, 256), Image.Resampling.NEAREST)
    width = max(image.width, detail.width)
    pair = Image.new("RGB", (2*width, image.height+detail.height))
    for column, color in enumerate(("#000000", "#ff00ff")):
        proof = Image.new("RGB", (width, pair.height), color)
        proof.paste(image, (0, 0), alpha)
        proof.paste(detail, (0, image.height), detail)
        pair.paste(proof, (column*width, 0))
    name = "-".join(path.relative_to(MOBILE).with_suffix("").parts)
    pair.save(OUT / (name + ".png"), compress_level=3)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT.parent / ".gdignore").touch()
    paths = set((MOBILE / "art/ui-icons").glob("*.png"))
    for directory in ("fx", "stage", "v4", "monsters"):
        paths.update((MOBILE / "art/piying" / directory).glob("*.png"))
    paths.update(MOBILE.glob("prototype/cutout/*/parts/*.png"))
    paths.add(MOBILE / "art/icon.png")
    paths.update((MOBILE / "art/ui-icons/raw/v6").rglob("*.png"))
    for path in sorted(paths):
        inspect(path)


if __name__ == "__main__":
    main()
