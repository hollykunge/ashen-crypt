"""Pack independent straight-alpha PNG sources. Run from any directory."""
import argparse
import json
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps
from scipy import ndimage

HERE = Path(__file__).resolve().parent
MOBILE = HERE.parents[1]
ART = MOBILE / "art/piying"
SOURCE = HERE / "raw/v6"
CUTOUT = MOBILE / "prototype/cutout"
sys.path.insert(0, str(CUTOUT))
import pack_puppet_fx as effects
import pack_puppet_monsters as monsters


def bleed(image):
    pixels = np.array(image.convert("RGBA"))
    outside = pixels[:, :, 3] == 0
    if outside.any() and not outside.all():
        y, x = ndimage.distance_transform_edt(outside, return_distances=False, return_indices=True)
        pixels[outside, :3] = pixels[y[outside], x[outside], :3]
    return Image.fromarray(pixels)


def prepare_native(path):
    """Clear sub-visible alpha dust in empty margins without eroding the silhouette."""
    with Image.open(path) as original:
        im = original.copy()
    if im.mode != "RGBA":
        raise ValueError(f"{path}: opaque element must be regenerated")
    alpha = np.array(im.getchannel("A"))
    if alpha.min() != 0 or alpha.max() < 128:
        raise ValueError(f"{path}: invalid coverage")
    dust = (alpha > 0) & ((alpha <= 3) | (ndimage.maximum_filter(alpha, size=7) < 16))
    if dust.any():
        alpha[dust] = 0
        im.putalpha(Image.fromarray(alpha))
        im.save(path, compress_level=4)
    if alpha[0, 0] or alpha[-1, 0] or alpha[0, -1] or alpha[-1, -1]:
        raise ValueError(f"{path}: element touches a corner")


def source(key):
    with Image.open(SOURCE / (key + ".png")) as original:
        if original.mode != "RGBA":
            raise ValueError(f"{key}: expected RGBA")
        alpha = original.getchannel("A")
        # Ignore sub-visible specks when locating the object, retain its soft edge.
        bounds = alpha.point(lambda a: 255 if a >= 16 else 0).getbbox()
        if not bounds or alpha.getextrema()[0] != 0:
            raise ValueError(f"{key}: missing transparent background")
        left, top, right, bottom = bounds
        tile = original.crop((left - 4, top - 4, right + 4, bottom + 4))
        tile.putalpha(tile.getchannel("A").point(lambda a: 0 if a <= 2 else a))
        return tile


def save(im, path, limit=None):
    if limit:
        im.thumbnail(limit, Image.Resampling.LANCZOS)
    bleed(im).save(path)


def pack_grid(group, count, columns, cell_size, destination):
    # Each density variant retains its aspect ratio and a four-pixel gutter on all sides.
    sheet = Image.new("RGBA", (columns * cell_size, (count // columns) * cell_size))
    for index in range(count):
        item = source(f"{group}/{index}")
        item.thumbnail((cell_size - 8, cell_size - 8), Image.Resampling.LANCZOS)
        x = (index % columns) * cell_size + (cell_size - item.width) // 2
        y = (index // columns) * cell_size + (cell_size - item.height) // 2
        sheet.paste(item, (x, y))
    save(sheet, destination)


def pack_rig(key):
    directory, name = key.split("/")
    box = json.loads((SOURCE / "registration.json").read_text())[key]
    left, top, right, bottom = box["bounds"]
    part = ImageOps.contain(source(key), (right-left, bottom-top), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", tuple(box["canvas"]))
    canvas.paste(part, ((left+right-part.width)//2, (top+bottom-part.height)//2))
    save(canvas, CUTOUT / directory / "parts" / (name + ".png"))


def pack(key):
    group, name = key.split("/")
    if group in ("nvjiang", "piying"):
        pack_rig(key)
    elif group == "title":
        if name == "hero":
            save(source(key), ART / "v4/title-hero.png", (1400, 1700))
        else:
            path = "title.webp" if name == "wide" else "title-tall.webp"
            Image.open(SOURCE / (key + ".png")).convert("RGB").save(ART / "v4" / path, quality=94)
    elif group == "monsters":
        item = source(key)
        item = item.crop(item.getchannel("A").point(lambda a: 255 if a > monsters.ALPHA else 0).getbbox())
        item.thumbnail((monsters.MAX_W, monsters.HEIGHT), Image.Resampling.LANCZOS)
        width, height = monsters.CELL
        atlas = Image.new("RGBA", (width * 4, height * 3))
        for index, pose in enumerate(monsters.FRAMES):
            atlas.paste(monsters.frame(item, index, *pose), ((index%4)*width, (index//4)*height))
        save(atlas, ART / "monsters" / (name + ".png"))
    elif group in ("ui", "v4", "stage") or key == "fx/slash":
        item = source(key)
        if key == "stage/bank":
            # Cut a repeatable interior strip. Mirroring the adjoining tile matches both edges.
            item = item.crop((item.width//8, 0, item.width*7//8, item.height))
            pair = Image.new("RGBA", (item.width*2, item.height))
            pair.paste(item)
            pair.paste(ImageOps.mirror(item), (item.width, 0))
            item = pair
        dest = HERE if group == "ui" else ART / group
        limit = (512, 512) if group == "ui" and name != "paper-card" else (2400, 1600)
        save(item, dest / (name + ".png"), (192, 192) if key == "v4/knob" else limit)
        if key == "v4/button":
            save(item, HERE / "plaque.png")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("keys", nargs="*")
    args = parser.parse_args()
    spec = json.loads((SOURCE / "prompts.json").read_text(encoding="utf-8-sig"))
    for key in args.keys or spec["assets"]:
        if key not in ("title/wide", "title/tall"):
            prepare_native(SOURCE / (key + ".png"))
        pack(key)
    if not args.keys:
        pack_grid("materials", 16, 4, 256, HERE / "materials.png")
        pack_grid("garments", 12, 4, 384, ART / "v4/garments.png")
        pack_grid("weapons", 6, 3, 512, ART / "v4/weapons.png")
        parts = [source("fx/" + n) for n in ("hit", "crit", "petal", "ember")]
        for name in effects.SHEETS:
            sheet = effects.build(name, parts, random.Random(7))
            save(sheet, ART / "fx" / (name + ".png"))


if __name__ == "__main__":
    main()
