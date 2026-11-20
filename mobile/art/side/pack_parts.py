"""画兵器零件，拼成零件图集，并写出 Godot 用的零件表。

    python art/side/pack_parts.py              # 在 mobile 目录下运行
    python art/side/pack_parts.py --preview out_dir

每件兵器由零件拼成：刃、护手、握柄、柄首；长柄兵器换杆头；短杖整根一件。拼法和挑件在
scripts/weapon_design.gd 与 scripts/held_weapon.gd 里。

零件一律竖着画在 128×128 的素材空间里：接口（靠手的那头）在 BASE，朝上长出去。
大多数零件画成灰度，游戏里按五行乘上钢色、饰色、缠绳色或灵光色，同一件零件就能出五种材质；
刃口的高光、宝石这类不该被染的，另画一层，原色叠上去。

    weapon-parts.png            GRID 列 × 行，每格 CELL 像素
    ../../scripts/weapon_parts_atlas.gd   零件表：格序、长度、宽度、血槽走线、握点

原画零件：source/parts/<零件名>.png 存在时，用它顶替脚本画的那一件（出图规格见 parts-prompts.json）。
原画会被抠到边界、按零件表的长度缩放、底边中点对到接口，再转成灰度，照样按五行染色；
脚本画的刃口高光、宝石这些附加层随之不用。

需要 Pillow 和 NumPy。
"""
import argparse
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
TABLE = HERE.parent.parent / "scripts" / "weapon_parts_atlas.gd"
SPACE = 128
SCALE = 6
CELL = 192
COLUMNS = 8
BASE = (64.0, 124.0)

INK = 38
DARK = 104
MID = 158
LIGHT = 208
HIGH = 240


def gray(value, alpha=255):
    if isinstance(value, tuple):
        return value if len(value) == 4 else value + (alpha,)
    return (value, value, value, alpha)


def smoothstep(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


class Pen:
    """一层画布，坐标用素材空间，画的时候放大 SCALE 倍。"""

    def __init__(self):
        size = SPACE * SCALE
        self.image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        self.draw = ImageDraw.Draw(self.image)

    @staticmethod
    def p(points):
        return [(x * SCALE, y * SCALE) for x, y in points]

    def poly(self, points, fill, edge=None, width=0.8):
        self.draw.polygon(self.p(points), fill=gray(fill))
        if edge is not None:
            self.line(list(points) + [points[0]], edge, width)

    def line(self, points, fill, width, alpha=255):
        self.draw.line(self.p(points), fill=gray(fill, alpha), width=max(1, round(width * SCALE)), joint="curve")

    def ellipse(self, center, rx, ry, fill, edge=None, width=0.8):
        x, y = center
        box = self.p([(x - rx, y - ry), (x + rx, y + ry)])
        self.draw.ellipse(box, fill=gray(fill) if fill is not None else None,
            outline=gray(edge) if edge is not None else None, width=round(width * SCALE) if edge is not None else 0)

    def rect(self, x0, y0, x1, y1, fill, edge=None, width=0.8):
        self.poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], fill, edge, width)


def finish(pen, grain=True):
    """压一层细颗粒和轻微模糊，和原画的笔触接上，再缩到一格。"""
    image = pen.image
    if grain:
        pixels = np.asarray(image).astype(np.float32)
        size = pixels.shape[0]
        noise = np.random.default_rng(11).normal(0.0, 1.0, (size, size))
        noise = np.asarray(Image.fromarray(((noise * 40) + 128).clip(0, 255).astype(np.uint8))
            .filter(ImageFilter.GaussianBlur(SCALE * 0.5))).astype(np.float32) / 40.0 - 3.2
        pixels[..., :3] = np.clip(pixels[..., :3] * (1.0 + 0.28 * noise[..., None]), 0, 255)
        image = Image.fromarray(pixels.astype(np.uint8))
    image = image.filter(ImageFilter.GaussianBlur(SCALE * 0.16))
    return image.resize((CELL, CELL), Image.LANCZOS)


# ---------- 刃 ----------

def strip(center, left, right, count=96):
    """沿中线 center(t) 两侧各量出 left(t)、right(t) 的宽度。左侧是 -u（刀背），右侧 +u（刃口）。"""
    lefts, rights, mids = [], [], []
    for i in range(count + 1):
        t = i / count
        x, y = center(t)
        ax, ay = center(min(1.0, t + 1e-3))
        bx, by = center(max(0.0, t - 1e-3))
        dx, dy = ax - bx, ay - by
        length = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / length, dx / length
        lefts.append((x - nx * left(t), y - ny * left(t)))
        rights.append((x + nx * right(t), y + ny * right(t)))
        mids.append((x, y))
    return lefts, rights, mids


def inset(outer, mids, ratio):
    return [(m[0] + (o[0] - m[0]) * ratio, m[1] + (o[1] - m[1]) * ratio) for o, m in zip(outer, mids)]


def single_edge(center, back, edge, rings=()):
    """单刃刀：刀背一面暗，刃口一面亮，近刃口一道开锋的白。另一层是刃口的高光，不染色。"""
    lefts, rights, mids = strip(center, back, edge)
    pen = Pen()
    outline = lefts + rights[::-1]
    pen.poly(outline, MID)
    pen.poly(lefts + mids[::-1], DARK + 18)
    pen.poly(mids + inset(rights, mids, 0.55)[::-1], LIGHT - 20)
    pen.poly(inset(rights, mids, 0.55) + rights[::-1], HIGH)
    spine = inset(lefts, mids, 0.55)
    pen.line(spine[4:-12], DARK - 20, 0.5)
    for t, radius in rings:
        x, y = spine[int(t * (len(spine) - 1))]
        pen.ellipse((x + 0.6, y), radius, radius, None, INK, 0.7)
        pen.ellipse((x + 0.6, y), radius - 0.6, radius - 0.6, None, HIGH, 0.4)
    pen.line(outline + [outline[0]], INK, 0.8)
    shine = Pen()
    shine.line(inset(rights, mids, 0.82)[8:-6], (255, 255, 255), 0.45, 190)
    glint = inset(rights, mids, 0.7)[int(len(mids) * 0.58)]
    shine.ellipse(glint, 0.9, 0.9, (255, 255, 255, 220))
    groove = [mids[i] for i in range(10, int(len(mids) * 0.78), 6)]
    return pen, shine, groove


def double_edge(center, half, star=False):
    """双刃剑：中脊一线最亮，左面受光、右面背光，两侧开锋。"""
    lefts, rights, mids = strip(center, half, half)
    pen = Pen()
    outline = lefts + rights[::-1]
    pen.poly(outline, MID)
    pen.poly(lefts + mids[::-1], LIGHT)
    pen.poly(mids + rights[::-1], DARK + 30)
    pen.poly(lefts + inset(lefts, mids, 0.6)[::-1], HIGH)
    pen.poly(inset(rights, mids, 0.6) + rights[::-1], MID + 10)
    pen.line(mids[3:-6], 252, 0.45)
    pen.line(outline + [outline[0]], INK, 0.8)
    shine = Pen()
    shine.line(inset(lefts, mids, 0.85)[10:-8], (255, 255, 255), 0.4, 170)
    glow = None
    if star:
        # 七星：沿中脊错落七粒，北斗的勺子朝着剑尖。
        glow = Pen()
        dots = [(0.12, -1.0), (0.2, 0.9), (0.28, -0.6), (0.36, 0.7), (0.46, 0.0), (0.55, -0.8), (0.64, 0.6)]
        trail = []
        for t, side in dots:
            x, y = mids[int(t * (len(mids) - 1))]
            trail.append((x + side * half(t) * 0.45, y))
        glow.line(trail, 255, 0.35, 150)
        for x, y in trail:
            glow.ellipse((x, y), 1.0, 1.0, 255)
    groove = [mids[i] for i in range(8, int(len(mids) * 0.8), 6)]
    return pen, shine, glow, groove


def blades():
    bx, by = BASE
    out = {}

    def liuye(t):
        return (bx + 1.5 - 9.0 * t ** 2.3, by - 82.0 * t)
    pen, shine, groove = single_edge(liuye,
        lambda t: (2.3 - 0.5 * t) * (1 - smoothstep(0.93, 1.0, t)),
        lambda t: (3.0 + 1.5 * math.sin(math.pi * t * 0.85)) * (1 - smoothstep(0.80, 1.0, t)))
    out["liuye"] = {"layers": [(pen, "steel"), (shine, "")], "length": 82.0, "width": 6.0, "groove": groove}

    def yanling(t):
        bend = max(0.0, (t - 0.6) / 0.4)
        return (bx + 1.0 - 7.5 * bend ** 2, by - 80.0 * t)
    pen, shine, groove = single_edge(yanling,
        lambda t: 2.1 * (1 - smoothstep(0.95, 1.0, t)),
        lambda t: 3.1 * (1 - smoothstep(0.72, 1.0, t) ** 0.8))
    out["yanling"] = {"layers": [(pen, "steel"), (shine, "")], "length": 80.0, "width": 5.5, "groove": groove}

    def guitou(t):
        return (bx + 0.5 - 3.0 * t ** 2, by - 76.0 * t)
    pen, shine, groove = single_edge(guitou,
        lambda t: 2.6 * (1 - smoothstep(0.97, 1.0, t)),
        lambda t: (3.2 + 5.2 * t ** 1.4) * (1 - smoothstep(0.86, 1.0, t)),
        rings=[(0.3, 1.5), (0.45, 1.5), (0.6, 1.5)])
    out["guitou"] = {"layers": [(pen, "steel"), (shine, "")], "length": 76.0, "width": 9.0, "groove": groove[:3]}

    def straight(t):
        return (bx, by - 84.0 * t)
    pen, shine, _, groove = double_edge(straight, lambda t: 3.2 * (1 - 0.2 * t) * (1 - smoothstep(0.86, 1.0, t)))
    out["jian"] = {"layers": [(pen, "steel"), (shine, "")], "length": 84.0, "width": 3.6, "groove": groove}

    pen, shine, glow, groove = double_edge(straight, lambda t: 3.0 * (1 - 0.15 * t) * (1 - smoothstep(0.86, 1.0, t)), True)
    out["qixing"] = {"layers": [(pen, "steel"), (shine, ""), (glow, "glow")], "length": 84.0, "width": 3.6, "groove": groove}

    def wave(t):
        return 3.0 * (1 - 0.1 * t) * (1 + 0.24 * math.sin(t * math.pi * 11)) * (1 - smoothstep(0.84, 1.0, t))
    pen, shine, _, groove = double_edge(straight, wave)
    out["bolang"] = {"layers": [(pen, "steel"), (shine, "")], "length": 84.0, "width": 4.0, "groove": groove}
    return out


# ---------- 护手、握柄、柄首 ----------

def guards():
    cx, base = BASE
    out = {}
    # 如意：两头下卷，正中一粒宝石。
    g = base - 4.8
    shape = [(cx - 12.5, g + 3.6), (cx - 11.0, g - 0.8), (cx - 5.0, g - 1.6), (cx, g - 3.0),
        (cx + 5.0, g - 1.6), (cx + 11.0, g - 0.8), (cx + 12.5, g + 3.6), (cx + 8.5, g + 4.4),
        (cx + 4.0, g + 3.0), (cx, g + 4.8), (cx - 4.0, g + 3.0), (cx - 8.5, g + 4.4)]
    pen = Pen()
    pen.poly(shape, MID, INK, 0.9)
    pen.poly([(cx - 10.6, g - 0.2), (cx - 5.0, g - 1.0), (cx, g - 2.2), (cx + 5.0, g - 1.0),
        (cx + 10.6, g - 0.2), (cx + 5.0, g + 0.6), (cx, g - 0.4), (cx - 5.0, g + 0.6)], HIGH)
    pen.poly([(cx - 8.5, g + 3.6), (cx - 4.0, g + 2.2), (cx, g + 4.0), (cx + 4.0, g + 2.2),
        (cx + 8.5, g + 3.6), (cx + 4.0, g + 3.0), (cx, g + 4.6), (cx - 4.0, g + 3.0)], DARK)
    gem = Pen()
    gem.ellipse((cx, g + 1.1), 1.8, 1.8, 255, (60, 60, 60), 0.4)
    gem.ellipse((cx - 0.5, g + 0.5), 0.6, 0.6, (255, 255, 255, 230))
    out["ruyi"] = {"layers": [(pen, "trim"), (gem, "glow")], "length": 7.8, "width": 12.5}

    # 圆盘：侧看是一枚扁圆，上沿受光。
    pen = Pen()
    pen.ellipse((cx, base - 3.6), 9.0, 3.6, MID, INK, 0.9)
    pen.ellipse((cx, base - 4.4), 7.6, 2.2, LIGHT)
    pen.line([(cx - 6.5, base - 5.4), (cx + 4.0, base - 6.0)], HIGH, 0.6)
    pen.ellipse((cx, base - 3.4), 2.4, 1.2, DARK)
    out["disc"] = {"layers": [(pen, "trim")], "length": 6.6, "width": 9.0}

    # 一字：细横档，两头圆珠。
    pen = Pen()
    pen.rect(cx - 10.0, base - 3.6, cx + 10.0, base - 0.8, MID, INK, 0.8)
    pen.line([(cx - 9.5, base - 2.9), (cx + 9.5, base - 2.9)], HIGH, 0.7)
    for side in (-1, 1):
        pen.ellipse((cx + side * 11.0, base - 2.2), 2.4, 2.4, LIGHT, INK, 0.8)
        pen.ellipse((cx + side * 11.0 - 0.6, base - 2.9), 0.8, 0.8, HIGH)
    pen.poly([(cx - 3.0, base - 3.6), (cx, base - 6.0), (cx + 3.0, base - 3.6)], LIGHT, INK, 0.7)
    out["bar"] = {"layers": [(pen, "trim")], "length": 5.2, "width": 13.4}

    # 月牙：两角朝刃尖翘起。
    pen = Pen()
    arc_outer, arc_inner = [], []
    for i in range(41):
        a = math.pi * (i / 40)
        arc_outer.append((cx - 12.0 * math.cos(a), base - 1.0 - 2.4 * math.sin(a) - 6.0 * (1 - math.sin(a)) ** 1.6))
        arc_inner.append((cx - 9.0 * math.cos(a), base - 3.8 - 1.4 * math.sin(a) - 5.0 * (1 - math.sin(a)) ** 1.6))
    shape = arc_outer + arc_inner[::-1]
    pen.poly(shape, MID, INK, 0.8)
    pen.line(arc_inner[3:-3], HIGH, 0.6)
    pen.ellipse((cx, base - 3.2), 2.0, 1.6, LIGHT, INK, 0.6)
    out["crescent"] = {"layers": [(pen, "trim")], "length": 5.0, "width": 12.5}
    return out


def grips():
    cx, base = BASE
    length = 18.0
    top = base - length
    out = {}
    # 缠绳：斜缠一道道交叠。
    pen = Pen()
    pen.rect(cx - 2.9, top, cx + 2.9, base, MID, INK, 0.8)
    pen.rect(cx - 2.5, top + 0.2, cx - 0.8, base - 0.2, LIGHT)
    for k in range(9):
        y = top + 0.8 + k * 2.0
        pen.line([(cx - 2.6, y + 1.5), (cx + 2.6, y)], DARK - 30, 0.45)
        pen.line([(cx - 2.6, y + 0.8), (cx + 0.4, y)], HIGH, 0.3)
    out["cord"] = {"layers": [(pen, "wrap")], "length": length, "width": 2.9}

    # 竹节：一节一节的箍。
    pen = Pen()
    pen.rect(cx - 2.7, top, cx + 2.7, base, MID, INK, 0.8)
    pen.rect(cx - 2.3, top + 0.2, cx - 0.6, base - 0.2, LIGHT)
    for k in range(5):
        y = top + 2.0 + k * 3.6
        pen.rect(cx - 3.1, y, cx + 3.1, y + 1.2, DARK, INK, 0.5)
        pen.line([(cx - 2.8, y + 0.3), (cx + 1.0, y + 0.3)], HIGH, 0.3)
    out["bands"] = {"layers": [(pen, "wrap")], "length": length, "width": 3.1}

    # 鲨皮：细粒的珠皮，两头铜箍。
    pen = Pen()
    pen.rect(cx - 2.8, top, cx + 2.8, base, MID, INK, 0.8)
    rng = np.random.default_rng(5)
    for _ in range(70):
        x, y = cx + rng.uniform(-2.3, 2.3), rng.uniform(top + 2.2, base - 2.2)
        pen.ellipse((x, y), 0.45, 0.45, HIGH if x < cx else LIGHT)
    for y in (top + 0.2, base - 1.8):
        pen.rect(cx - 3.2, y, cx + 3.2, y + 1.6, DARK + 20, INK, 0.5)
    out["ray"] = {"layers": [(pen, "wrap")], "length": length, "width": 3.2}
    return out


def pommels():
    cx, base = BASE
    out = {}
    # 六棱首。
    pen = Pen()
    b = base
    shape = [(cx - 3.8, b), (cx + 3.8, b), (cx + 5.0, b - 3.8), (cx + 2.6, b - 7.0), (cx - 2.6, b - 7.0), (cx - 5.0, b - 3.8)]
    pen.poly(shape, MID, INK, 0.9)
    pen.poly([(cx - 3.4, b - 0.4), (cx + 0.6, b - 0.4), (cx - 0.2, b - 6.4), (cx - 3.6, b - 3.8)], HIGH)
    pen.poly([(cx + 1.4, b - 0.4), (cx + 3.6, b - 0.6), (cx + 4.4, b - 3.8), (cx + 2.2, b - 6.4)], DARK)
    out["hex"] = {"layers": [(pen, "trim")], "length": 7.0, "width": 5.0}

    # 环首：短颈接一个圆环，环首刀的样子。
    pen = Pen()
    pen.rect(cx - 2.2, b - 4.0, cx + 2.2, b, MID, INK, 0.7)
    ring = (cx, b - 9.0)
    pen.ellipse(ring, 5.4, 5.4, MID, INK, 0.9)
    pen.ellipse(ring, 3.2, 3.2, (0, 0, 0, 0), INK, 0.7)
    pen.draw.arc(Pen.p([(ring[0] - 4.4, ring[1] - 4.4), (ring[0] + 4.4, ring[1] + 4.4)]), 150, 290,
        fill=gray(HIGH), width=round(0.9 * SCALE))
    pen.draw.arc(Pen.p([(ring[0] - 4.4, ring[1] - 4.4), (ring[0] + 4.4, ring[1] + 4.4)]), 330, 100,
        fill=gray(DARK), width=round(0.9 * SCALE))
    out["ring"] = {"layers": [(pen, "trim")], "length": 14.4, "width": 5.4}

    # 圆珠首。
    pen = Pen()
    pen.rect(cx - 2.0, b - 2.6, cx + 2.0, b, MID, INK, 0.7)
    pen.ellipse((cx, b - 5.6), 3.7, 3.7, MID, INK, 0.9)
    pen.ellipse((cx - 1.0, b - 6.4), 1.8, 1.8, LIGHT)
    pen.ellipse((cx - 1.4, b - 6.9), 0.7, 0.7, HIGH)
    out["knob"] = {"layers": [(pen, "trim")], "length": 9.3, "width": 3.7}

    # 云头：如意云朵。
    pen = Pen()
    pen.rect(cx - 2.0, b - 2.4, cx + 2.0, b, MID, INK, 0.7)
    for dx, dy, r in [(-3.2, -4.6, 2.6), (3.2, -4.6, 2.6), (0.0, -7.2, 3.0)]:
        pen.ellipse((cx + dx, b + dy), r, r, MID, INK, 0.8)
    for dx, dy, r in [(-3.2, -4.6, 1.6), (3.2, -4.6, 1.6), (0.0, -7.2, 2.0)]:
        pen.ellipse((cx + dx - 0.4, b + dy - 0.4), r, r, LIGHT)
    pen.draw.arc(Pen.p([(cx - 1.6, b - 8.8), (cx + 1.6, b - 5.6)]), 180, 450, fill=gray(DARK), width=round(0.5 * SCALE))
    out["cloud"] = {"layers": [(pen, "trim")], "length": 10.2, "width": 5.8}
    return out


# ---------- 杆头与短杖 ----------

def collar(pen, top, base, half):
    """杆头的銎：一截套管，两道箍。"""
    cx = BASE[0]
    pen.rect(cx - half, top, cx + half, base, MID, INK, 0.8)
    pen.rect(cx - half + 0.4, top + 0.3, cx - 0.4, base - 0.3, LIGHT)
    for y in (top + 1.0, base - 2.4):
        pen.rect(cx - half - 0.6, y, cx + half + 0.6, y + 1.4, DARK, INK, 0.5)


def heads():
    cx, base = BASE
    out = {}
    # 柳叶枪头。
    pen = Pen()
    collar(pen, base - 13.0, base, 2.6)
    tip, root = base - 56.0, base - 12.0
    half = lambda t: 6.2 * math.sin(math.pi * min(1.0, t * 1.15) ** 0.75) * (1 - t) ** 0.4
    lefts = [(cx - half(i / 40), root - (root - tip) * i / 40) for i in range(41)]
    rights = [(cx + half(i / 40), root - (root - tip) * i / 40) for i in range(41)]
    mids = [(cx, root - (root - tip) * i / 40) for i in range(41)]
    pen.poly(lefts + rights[::-1], MID)
    pen.poly(lefts + mids[::-1], LIGHT)
    pen.poly(mids + rights[::-1], DARK + 24)
    pen.line(mids[1:-3], HIGH, 0.6)
    pen.line(lefts + rights[::-1] + [lefts[0]], INK, 0.8)
    out["leaf"] = {"layers": [(pen, "steel")], "length": 56.0, "width": 6.2}

    # 蛇矛：刃身蜿蜒。
    pen = Pen()
    collar(pen, base - 13.0, base, 2.6)
    root, length = base - 12.0, 48.0
    snake = lambda t: (cx + 3.0 * math.sin(t * math.pi * 3.0) * (1 - t * 0.5), root - length * t)
    lefts, rights, mids = strip(snake, lambda t: 3.0 * (1 - t) ** 0.6 + 0.2, lambda t: 3.0 * (1 - t) ** 0.6 + 0.2, 80)
    pen.poly(lefts + rights[::-1], MID)
    pen.poly(lefts + mids[::-1], LIGHT)
    pen.line(mids[1:-4], HIGH, 0.5)
    pen.line(lefts + rights[::-1] + [lefts[0]], INK, 0.8)
    out["snake"] = {"layers": [(pen, "steel")], "length": 60.0, "width": 6.0}

    # 戟：直刺加一侧月牙。
    pen = Pen()
    collar(pen, base - 13.0, base, 2.6)
    root, tip = base - 12.0, base - 54.0
    pen.poly([(cx - 2.6, root), (cx - 2.2, tip + 10), (cx, tip), (cx + 2.2, tip + 10), (cx + 2.6, root)], LIGHT, INK, 0.8)
    pen.poly([(cx, root), (cx, tip + 1), (cx + 2.2, tip + 10), (cx + 2.6, root)], DARK + 30)
    pen.line([(cx, root - 1), (cx, tip + 3)], HIGH, 0.5)
    moon_out, moon_in = [], []
    for i in range(31):
        a = -math.pi * 0.42 + math.pi * 0.84 * i / 30
        moon_out.append((cx + 2.0 + 11.5 * math.cos(a), root - 12.0 + 12.0 * math.sin(a)))
        moon_in.append((cx + 2.0 + 6.5 * math.cos(a * 0.92), root - 12.0 + 8.5 * math.sin(a * 0.92)))
    pen.poly(moon_out + moon_in[::-1], MID, INK, 0.8)
    pen.line(moon_out[2:-2], HIGH, 0.6)
    out["ji"] = {"layers": [(pen, "steel")], "length": 54.0, "width": 13.5}

    # 瓜锤：一颗带瓣的瓜，顶上一粒钮。
    pen = Pen()
    collar(pen, base - 8.0, base, 3.2)
    center, rx, ry = (cx, base - 25.0), 15.0, 17.0
    pen.ellipse(center, rx, ry, MID, INK, 1.0)
    for k in range(-3, 4):
        x = center[0] + rx * 0.85 * math.sin(k * 0.42)
        band = [(center[0] + (x - center[0]) * math.sqrt(max(0.0, 1 - ((y - center[1]) / ry) ** 2)), y)
            for y in np.linspace(center[1] - ry * 0.95, center[1] + ry * 0.95, 24)]
        pen.line(band, DARK if k > 0 else LIGHT, 0.7)
    pen.ellipse((center[0] - 5.0, center[1] - 6.0), 4.0, 6.0, HIGH)
    pen.ellipse((cx, base - 43.5), 2.4, 2.4, LIGHT, INK, 0.7)
    out["gua"] = {"layers": [(pen, "steel")], "length": 46.0, "width": 15.0}

    # 方锤：一块方铁，四角包边，面上一排钉。
    pen = Pen()
    collar(pen, base - 8.0, base, 3.2)
    x0, x1, y0, y1 = cx - 13.0, cx + 13.0, base - 42.0, base - 7.0
    pen.rect(x0, y0, x1, y1, MID, INK, 1.0)
    pen.rect(x0 + 1.2, y0 + 1.2, cx - 1.0, y1 - 1.2, LIGHT)
    pen.rect(cx + 1.0, y0 + 1.2, x1 - 1.2, y1 - 1.2, DARK + 20)
    for y in (y0, y1 - 3.2):
        pen.rect(x0 - 0.8, y, x1 + 0.8, y + 3.2, DARK, INK, 0.7)
        pen.line([(x0, y + 0.8), (x1, y + 0.8)], HIGH, 0.5)
    for row in range(3):
        for col in range(3):
            p = (x0 + 6.0 + col * 7.0, y0 + 9.0 + row * 8.5)
            pen.ellipse(p, 1.5, 1.5, HIGH, INK, 0.5)
    out["fang"] = {"layers": [(pen, "steel")], "length": 43.0, "width": 13.8}

    # 宝珠杖头：四爪托一颗灵珠，珠子按五行发光。
    pen = Pen()
    collar(pen, base - 10.0, base, 3.0)
    orb = (cx, base - 26.0)
    for side in (-1, 1):
        for spread in (1.0, 0.45):
            claw = [(cx + side * 2.0 * spread, base - 9.0), (cx + side * 9.0 * spread, base - 17.0),
                (cx + side * 9.5 * spread, base - 28.0), (cx + side * 5.5 * spread, base - 35.0)]
            pen.line(claw, INK, 2.4)
            pen.line(claw, LIGHT if side < 0 else MID, 1.3)
    glow = Pen()
    glow.ellipse(orb, 7.0, 7.0, 210, (70, 70, 70), 0.7)
    glow.ellipse((orb[0] - 1.6, orb[1] - 1.8), 4.4, 4.4, 245)
    glow.ellipse((orb[0] - 2.6, orb[1] - 3.0), 1.4, 1.4, 255)
    out["orb"] = {"layers": [(pen, "trim"), (glow, "glow")], "length": 36.0, "width": 9.5}

    # 月牙铲：杖头一弯月刃，两角朝上。
    pen = Pen()
    collar(pen, base - 12.0, base, 2.8)
    pen.rect(cx - 1.8, base - 19.0, cx + 1.8, base - 11.0, MID, INK, 0.7)
    center = (cx, base - 27.0)
    outer = [(center[0] + 14.0 * math.cos(math.pi * i / 40), center[1] + 9.0 * math.sin(math.pi * i / 40)) for i in range(41)]
    inner = [(center[0] + 10.0 * math.cos(math.pi * i / 40), center[1] - 1.0 + 4.6 * math.sin(math.pi * i / 40)) for i in range(41)]
    shape = outer + [(center[0] - 13.6, center[1] - 4.0)] + inner[::-1] + [(center[0] + 13.6, center[1] - 4.0)]
    pen.poly(shape, MID, INK, 0.9)
    pen.line(inner[3:-3], HIGH, 0.7)
    pen.line(outer[22:38], LIGHT, 0.6)
    out["moon"] = {"layers": [(pen, "steel")], "length": 31.0, "width": 14.0}
    return out


def wands():
    cx, base = BASE
    out = {}
    # 骨杖：一根带节的兽骨，顶上一爪抓着灵珠，握处缠绳。
    pen = Pen()
    top = base - 56.0
    pen.rect(cx - 3.0, top + 6.0, cx + 3.0, base - 3.0, LIGHT, INK, 0.8)
    pen.line([(cx + 1.4, top + 7.0), (cx + 1.4, base - 4.0)], MID, 1.4)
    for y in (base - 3.0, top + 22.0, top + 38.0):
        pen.ellipse((cx, y), 4.6, 3.0, LIGHT, INK, 0.7)
        pen.ellipse((cx - 1.4, y - 0.8), 1.8, 1.2, HIGH)
    for side in (-1, 1):
        pen.line([(cx, top + 7.0), (cx + side * 5.6, top + 3.0), (cx + side * 4.0, top - 2.6)], INK, 2.4)
        pen.line([(cx, top + 7.0), (cx + side * 5.6, top + 3.0), (cx + side * 4.0, top - 2.6)], HIGH, 1.2)
    wrap = Pen()
    for k in range(6):
        y = base - 18.0 + k * 1.9
        wrap.line([(cx - 3.2, y + 1.4), (cx + 3.2, y)], (120, 40, 34), 1.1)
    glow = Pen()
    glow.ellipse((cx, top + 0.6), 4.4, 4.4, 220, (70, 70, 70), 0.6)
    glow.ellipse((cx - 1.2, top - 0.6), 1.7, 1.7, 255)
    out["bone"] = {"layers": [(pen, "bone"), (wrap, ""), (glow, "glow")], "length": 61.0, "width": 5.6, "hold": 13.0}

    # 如意：一根微弯的柄，顶上云头，正中嵌一颗灵石。
    pen = Pen()
    shaft = [(cx + 1.6 * math.sin(t * math.pi * 1.2), base - 44.0 * t) for t in np.linspace(0, 1, 30)]
    pen.line(shaft, INK, 6.0)
    pen.line(shaft, MID, 4.4)
    pen.line([(x - 1.0, y) for x, y in shaft], HIGH, 1.2)
    head = (cx - 0.5, base - 50.0)
    for dx, dy, r in [(-4.2, 1.0, 4.4), (4.2, 1.0, 4.4), (0.0, -2.8, 5.0)]:
        pen.ellipse((head[0] + dx, head[1] + dy), r, r, MID, INK, 0.9)
    for dx, dy, r in [(-4.6, 0.4, 2.8), (3.8, 0.4, 2.8), (-0.4, -3.4, 3.2)]:
        pen.ellipse((head[0] + dx, head[1] + dy), r, r, LIGHT)
    pen.ellipse((cx, base - 22.0), 2.8, 3.6, DARK, INK, 0.6)
    glow = Pen()
    glow.ellipse((head[0], head[1] - 0.4), 2.6, 2.6, 225, (70, 70, 70), 0.5)
    glow.ellipse((head[0] - 0.8, head[1] - 1.2), 0.9, 0.9, 255)
    glow.ellipse((cx, base - 22.0), 1.6, 2.3, 225)
    out["ruyi_wand"] = {"layers": [(pen, "trim"), (glow, "glow")], "length": 56.0, "width": 9.0, "hold": 9.0}
    return out


def painted(name, spec):
    """读 source/parts/<name>.png 顶替脚本画的零件；没有就返回 None。"""
    path = HERE / "source" / "parts" / (name + ".png")
    if not path.exists():
        return None
    art = Image.open(path).convert("RGBA")
    bounds = art.getchannel("A").point(lambda a: 255 if a > 24 else 0).getbbox()
    if bounds is None:
        print("原画零件是空的，仍用脚本画的：%s" % path.name)
        return None
    art = art.crop(bounds)
    height = round(spec["length"] * SCALE)
    width = max(1, min(round(art.width * height / art.height), (SPACE - 4) * SCALE))
    art = art.resize((width, height), Image.LANCZOS)
    pixels = np.asarray(art).astype(np.float32)
    light = pixels[..., 0] * 0.2126 + pixels[..., 1] * 0.7152 + pixels[..., 2] * 0.0722
    solid = pixels[..., 3] > 128
    top = np.percentile(light[solid], 99) if solid.any() else 255.0
    light = np.clip(light * (245.0 / max(top, 1.0)), 0, 255)
    gray_art = np.dstack([light, light, light, pixels[..., 3]]).astype(np.uint8)
    pen = Pen()
    pen.image.alpha_composite(Image.fromarray(gray_art), (round(BASE[0] * SCALE - width / 2), round(BASE[1] * SCALE) - height))
    spec["width"] = max(spec["width"], width / SCALE / 2)
    spec.pop("groove", None)
    return pen


def gd_vector(point):
    return "Vector2(%.1f, %.1f)" % (point[0] - BASE[0], BASE[1] - point[1])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview")
    args = parser.parse_args()
    groups = [("blade", blades()), ("guard", guards()), ("grip", grips()), ("pommel", pommels()),
        ("head", heads()), ("wand", wands())]
    cells = []
    table = []
    for kind, parts in groups:
        for name, spec in parts.items():
            layers = []
            source = painted(name, spec)
            if source is not None:
                spec["layers"] = [(source, spec["layers"][0][1])]
            for pen, tint in spec["layers"]:
                if pen is None:
                    continue
                layers.append((len(cells), tint))
                cells.append(finish(pen, grain=tint not in ("", "glow")))
            table.append((kind, name, spec, layers))
    rows = math.ceil(len(cells) / COLUMNS)
    atlas = Image.new("RGBA", (CELL * COLUMNS, CELL * rows), (0, 0, 0, 0))
    for index, cell in enumerate(cells):
        atlas.paste(cell, ((index % COLUMNS) * CELL, (index // COLUMNS) * CELL))
    atlas.save(HERE / "weapon-parts.png", optimize=True)

    lines = [
        "extends RefCounted",
        "",
        "# 由 art/side/pack_parts.py 生成，别手改。",
        "# 每格 128×128 素材空间，零件竖着画，接口在 BASE，朝上长出去。length 是沿轴长度，width 是半宽，",
        "# groove 是血槽走线（以接口为原点、沿轴为 +y），hold 是短杖从柄尾到握点的距离。",
        "# layers 每层是 [格序, 染色]：steel 钢色、trim 饰色、wrap 缠绳、bone 骨色、glow 灵光，空串不染。",
        "",
        "const SHEET = preload(\"res://art/side/weapon-parts.png\")",
        "const GRID := Vector2(%d, %d)" % (COLUMNS, rows),
        "const BASE := Vector2(%.1f, %.1f)" % BASE,
        "const PARTS := {",
    ]
    for kind, name, spec, layers in table:
        fields = ['"kind": "%s"' % kind, '"length": %.1f' % spec["length"], '"width": %.1f' % spec["width"],
            '"layers": [%s]' % ", ".join('[%d, "%s"]' % layer for layer in layers)]
        if "groove" in spec:
            fields.append('"groove": [%s]' % ", ".join(gd_vector(p) for p in spec["groove"]))
        if "hold" in spec:
            fields.append('"hold": %.1f' % spec["hold"])
        lines.append('\t"%s": {%s},' % (name, ", ".join(fields)))
    lines.append("}")
    TABLE.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("已出图：weapon-parts.png %dx%d，%d 件零件，%d 格" % (atlas.width, atlas.height, len(table), len(cells)))
    if args.preview:
        out = Path(args.preview)
        out.mkdir(parents=True, exist_ok=True)
        board = Image.new("RGBA", atlas.size, (122, 122, 140, 255))
        board.alpha_composite(atlas)
        board.save(out / "weapon-parts.png")


if __name__ == "__main__":
    main()
