"""把 raw/ 里出好的图标图集切成一张张透明底图标。

用法：python mobile/art/ui-icons/slice.py
raw/sheet-N.png 是 3 列 × 2 行的白底图集（见 PROMPTS.md）；raw/<图标名>.png 是单独重出的一格，会覆盖图集里那一格。
白底按亮度抠成透明（墨色越深越不透明），朱砂色保留原色。输出 <图标名>.png，最长边 128 像素。
"""
from pathlib import Path

from PIL import Image, ImageOps

HERE = Path(__file__).resolve().parent
RAW = HERE / "raw"
SIZE = 128
SHEETS = {
    "sheet-1": ["dao", "jian", "spear", "bow", "slash", "sigil"],
    "sheet-2": ["retreat", "manual", "assist", "auto", "speed1", "speed2"],
    "sheet-3": ["speed3", "pause", "leave", "mute", "sound", "back"],
    "sheet-4": ["forward", "pack", "notice", "march", "jie", "portal"],
}
# 亮度高于 WHITE 的算纸白（全透明），低于 INK 的算实墨（不透明）
WHITE = 236
INK = 120


def key_white(cell: Image.Image) -> Image.Image:
    cell = cell.convert("RGB")
    gray = ImageOps.grayscale(cell)
    alpha = gray.point(lambda v: 0 if v >= WHITE else 255 if v <= INK else round(255 * (WHITE - v) / (WHITE - INK)))
    out = cell.convert("RGBA")
    out.putalpha(alpha)
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            cr, cg, cb, a = px[x, y]
            if 0 < a < 255:  # 半透明处减掉混进来的白底，免得抠完边缘发白
                t = a / 255
                # 白底混进来的部分减掉：c = t*ink + (1-t)*255 → ink = (c - (1-t)*255) / t
                px[x, y] = tuple(max(0, min(255, round((c - (1 - t) * 255) / t))) for c in (cr, cg, cb)) + (a,)
    return out


def finish(icon: Image.Image, name: str) -> None:
    box = icon.getbbox()
    if box is None:
        print(f"{name}: 空白，跳过")
        return
    icon = icon.crop(box)
    pad = round(max(icon.size) * 0.04)
    canvas = Image.new("RGBA", (icon.width + pad * 2, icon.height + pad * 2), (0, 0, 0, 0))
    canvas.paste(icon, (pad, pad))
    scale = SIZE / max(canvas.size)
    canvas = canvas.resize((max(1, round(canvas.width * scale)), max(1, round(canvas.height * scale))), Image.LANCZOS)
    canvas.save(HERE / f"{name}.png")
    print(f"写出 {name}.png {canvas.size}")


def main() -> None:
    for sheet, names in SHEETS.items():
        path = RAW / f"{sheet}.png"
        if not path.exists():
            continue
        image = Image.open(path)
        w, h = image.width / 3, image.height / 2
        for i, name in enumerate(names):
            if (RAW / f"{name}.png").exists():
                continue
            col, row = i % 3, i // 3
            # 每格往里收 3%，切掉可能压到格边的杂笔
            m = 0.03
            cell = image.crop((round((col + m) * w), round((row + m) * h), round((col + 1 - m) * w), round((row + 1 - m) * h)))
            finish(key_white(cell), name)
    for names in SHEETS.values():
        for name in names:
            single = RAW / f"{name}.png"
            if single.exists():
                finish(key_white(Image.open(single)), name)


# 按钮底图：照 raw/stroke-reference.png 出的黑墨一笔。raw/stroke-wide.png 长的给文字按钮，raw/stroke-square.png 短的给图标按钮。
# 抠成白色加透明（游戏里按按钮配色染色），按 STROKES 给的高度缩小：九宫格的边在游戏里按贴图像素原样画，贴图要和按钮差不多大
STROKES = {"stroke-wide": 48, "stroke-square": 56}


def strokes() -> None:
    for name, height in STROKES.items():
        path = RAW / f"{name}.png"
        if not path.exists():
            continue
        gray = ImageOps.grayscale(Image.open(path))
        alpha = gray.point(lambda v: 0 if v >= WHITE else 255 if v <= INK else round(255 * (WHITE - v) / (WHITE - INK)))
        box = alpha.getbbox()
        alpha = alpha.crop(box)
        scale = height / alpha.height
        alpha = alpha.resize((max(1, round(alpha.width * scale)), height), Image.LANCZOS)
        out = Image.new("RGBA", alpha.size, (255, 255, 255, 0))
        out.putalpha(alpha)
        out.save(HERE / f"{name}.png")
        print(f"写出 {name}.png {out.size}")


# 卡片底：raw/paper-card.png 是黑底上的一张毛边宣纸（游戏里九宫格拉伸），抠掉黑底；
# raw/ink-blot.png 是白底上的一团淡墨晕（垫在头像后面），按亮度抠白底
def paper() -> None:
    path = RAW / "paper-card.png"
    if path.exists():
        image = Image.open(path).convert("RGB")
        gray = ImageOps.grayscale(image)
        alpha = gray.point(lambda v: 0 if v <= 18 else 255 if v >= 70 else round(255 * (v - 18) / 52))
        out = image.convert("RGBA")
        out.putalpha(alpha)
        out = out.crop(alpha.getbbox())
        scale = 200 / out.height
        out = out.resize((round(out.width * scale), 200), Image.LANCZOS)
        out.save(HERE / "paper-card.png")
        print(f"写出 paper-card.png {out.size}")
    path = RAW / "ink-blot.png"
    if path.exists():
        gray = ImageOps.grayscale(Image.open(path))
        alpha = gray.point(lambda v: 0 if v >= 250 else round(255 * (250 - v) / 250))
        out = Image.new("RGBA", gray.size, (38, 30, 24, 0))
        out.putalpha(alpha)
        out = out.crop(alpha.getbbox()).resize((256, 256), Image.LANCZOS)
        out.save(HERE / "ink-blot.png")
        print(f"写出 ink-blot.png {out.size}")


if __name__ == "__main__":
    main()
    strokes()
    paper()
