"""Pack the reference-guided night theatre artwork into Godot textures."""
from pathlib import Path
from PIL import Image, ImageOps

HERE = Path(__file__).resolve().parent
STAGE = HERE.parent / "piying/stage"
FX = HERE.parent / "piying/fx"
GLYPHS = "dao jian spear bow slash sigil retreat portal pause march pack notice back forward leave sound mute manual assist auto".split()


def source(name):
    with Image.open(HERE / "raw" / f"night-{name}.png") as image:
        return image.copy()


def cut(image, box, limit, threshold=18):
    tile = image.crop(box)
    bounds = tile.getchannel("A").point(lambda a: 255 if a > threshold else 0).getbbox()
    if bounds is None:
        raise ValueError(f"Empty cell at {box}")
    tile = tile.crop(bounds)
    tile.thumbnail(limit, Image.Resampling.LANCZOS)
    return tile


def grid(name, columns, rows, limit, edges=None):
    sheet = source(name)
    xs = edges or [i / columns for i in range(columns + 1)]
    for y in range(rows):
        for x in range(columns):
            yield cut(sheet, (round(xs[x] * sheet.width), round(y * sheet.height / rows),
                              round(xs[x + 1] * sheet.width), round((y + 1) * sheet.height / rows)), limit)


def atlas(name, raw_name, rows, edges=None):
    sheet = Image.new("RGBA", (512, 128 * rows))
    for i, cell in enumerate(grid(raw_name, 4, rows, (120, 120), edges)):
        sheet.paste(cell, (128 * (i % 4) + (128 - cell.width) // 2,
                           128 * (i // 4) + (128 - cell.height) // 2))
    sheet.save(HERE / f"{name}.png")


def main():
    river = source("river")
    river.save(HERE / "stage.webp", quality=91)
    scroll = Image.new("RGB", (river.width * 2, river.height))
    scroll.paste(river)
    scroll.paste(ImageOps.mirror(river), (river.width, 0))
    scroll.save(STAGE / "river-scroll.webp", quality=90)
    source("river-portrait").save(STAGE / "river-portrait.webp", quality=92)
    source("title").save(HERE / "stage-portrait.webp", quality=91)

    scenery = source("scenery")
    for name, box in {
        "moon": (0, 0, 468, 512), "mountains": (488, 0, 1008, 512), "bridge": (1009, 0, 1536, 512),
        "pavilion": (0, 512, 512, 1024), "willow": (512, 512, 1024, 1024), "reeds": (1024, 512, 1536, 1024)
    }.items():
        cut(scenery, box, (540, 512), 12).save(STAGE / f"{name}.png")

    fittings = source("fittings")
    for path, box, limit in [
        (HERE / "badge.png", (0, 0, 386, 512), (160, 160)),
        (HERE / "paper-card.png", (1040, 0, 1536, 512), (180, 100)),
        (HERE / "lamp.png", (0, 512, 416, 1024), (112, 112)),
        (FX / "slash.png", (420, 512, 1040, 1024), (512, 512)),
        (HERE / "portrait.png", (1040, 512, 1536, 1024), (256, 256))
    ]:
        cut(fittings, box, limit).save(path)
    plaque = cut(fittings, (397, 0, 1031, 512), (324, 62))
    plaque.resize((180, 33), Image.Resampling.LANCZOS).save(HERE / "plaque.png")
    with Image.open(HERE / "paper-card.png") as panel:
        panel.resize((64, 64), Image.Resampling.LANCZOS).save(HERE / "slot-plate.png")

    for name, cell in zip(GLYPHS, grid("glyphs", 5, 4, (128, 128)), strict=True):
        cell.save(HERE / f"{name}.png")
    faces = source("faces")
    cut(faces, (0, 0, 512, 512), (256, 256)).save(HERE / "portrait-female.png")
    for x in range(3):
        cut(faces, (512*x, 512, 512*(x+1), 1024), (128, 128)).save(HERE / f"speed{x+1}.png")
    for i, cell in enumerate(grid("gallery", 3, 2, (256, 256))):
        cell.save(HERE / f"immortal-{i}.png")
    atlas("gear", "gear", 3, (0, 0.285, 0.50, 0.73, 1))
    atlas("weapons", "weapon-forms", 3)
    atlas("materials", "materials", 4)


if __name__ == "__main__":
    main()
