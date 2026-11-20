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
import json
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

    return out


# ---------- 弓 ----------

def limb(pen, bend, length, width, start, end, fill_back, fill_belly, edge=True):
    """弓臂的一段：从握把正中往上长，bend(t) 是横向偏移（负值弯向弓弦一侧），width(t) 是半宽。
    外侧（+u，背向射手）受光，内侧（弓腹）背光。只画 t 在 [start, end] 这一段。"""
    cx, base = BASE
    center = lambda t: (cx + bend(t), base - length * t)
    t0, t1 = start, end
    sub = lambda t: center(t0 + (t1 - t0) * t)
    w = lambda t: width(t0 + (t1 - t0) * t)
    lefts, rights, mids = strip(sub, w, w, 60)
    outline = lefts + rights[::-1]
    pen.poly(outline, fill_belly)
    pen.poly(inset(lefts, mids, 0.1) + inset(rights, mids, 0.95)[::-1], fill_back)
    pen.line(inset(rights, mids, 0.5)[2:-2], HIGH, 0.45)
    if edge:
        pen.line(outline + [outline[0]], INK, 0.7)
    return center


def bows():
    cx, base = BASE
    out = {}

    def make(name, length, bend, width, ear_from, ear_width, extras=None, belly=False, likes_cloud=False):
        body, horn, ears = Pen(), Pen(), Pen()
        center = limb(body, bend, length, width, 0.0, ear_from + 0.02, LIGHT, MID)
        if belly:
            # 角弓的弓腹贴一条牛角，浅色，单独一层按骨色染。
            limb(horn, lambda t: bend(t) - width(t) * 0.55, length, lambda t: width(t) * 0.42,
                0.1, ear_from, HIGH, LIGHT, edge=False)
        limb(ears, bend, length, ear_width, ear_from, 1.0, LIGHT, MID)
        tip = center(1.0)
        if likes_cloud:
            # 云头弓弰：弰尖卷成一个小涡。
            ears.ellipse((tip[0] + 1.6, tip[1] + 0.4), 2.6, 2.6, MID, INK, 0.7)
            ears.ellipse((tip[0] + 1.6, tip[1] + 0.4), 1.2, 1.2, HIGH)
        # 弦扣：弰尖一道刻口。
        ears.line([(tip[0] - 1.6, tip[1] + 2.4), (tip[0] + 0.4, tip[1] + 1.4)], INK, 0.6)
        if extras:
            extras(body, center)
        layers = [(body, "wood")]
        if belly:
            layers.append((horn, "bone"))
        layers.append((ears, "trim"))
        reach = max(abs(bend(i / 40)) + width(i / 40) for i in range(41)) + 3.0
        out[name] = {"layers": layers, "length": length + 2.0, "width": reach, "tip": tip}

    def bands(pen, center):
        for t in (0.26, 0.42, 0.58):
            x, y = center(t)
            pen.line([(x - 3.4, y + 0.6), (x + 3.4, y - 0.6)], INK, 1.6)
            pen.line([(x - 3.0, y + 0.6), (x + 3.0, y - 0.6)], HIGH, 0.7)

    # 反曲弓：弓臂往弦一侧弯，到弓弰再往前折出去。弰尖仍得落在弓把后面（弦一侧），不然弦会跑到弓前头。
    make("fanqu", 60.0, lambda t: -18.0 * t ** 2 + 11.0 * max(0.0, (t - 0.78) / 0.22) ** 1.8,
        lambda t: 3.4 - 1.6 * t if t > 0.14 else 3.6, 0.78, lambda t: 1.9 - 0.8 * (t - 0.78) / 0.22)
    # 角弓：短而反曲得狠，弓腹贴一条牛角。
    make("jiao", 52.0, lambda t: -17.0 * t ** 2 + 11.0 * max(0.0, (t - 0.70) / 0.30) ** 1.6,
        lambda t: 3.8 - 1.8 * t if t > 0.14 else 4.0, 0.72, lambda t: 2.0 - 0.9 * (t - 0.70) / 0.30, belly=True)
    # 长弓：一道平平的弧，弰头只包一小截。
    make("chang", 66.0, lambda t: -12.0 * t ** 2, lambda t: 3.0 - 1.4 * t if t > 0.12 else 3.3, 0.93,
        lambda t: 1.7 - 0.5 * (t - 0.93) / 0.07)
    # 云纹弓：反曲弓的身形，弓臂缠三道箍，弰头卷云。
    make("yun", 58.0, lambda t: -16.0 * t ** 2 + 10.0 * max(0.0, (t - 0.80) / 0.20) ** 1.8,
        lambda t: 3.5 - 1.6 * t if t > 0.14 else 3.7, 0.80, lambda t: 1.9 - 0.7 * (t - 0.80) / 0.20,
        extras=bands, likes_cloud=True)
    return out


def trim_stub(art):
    """出图常在刃根多带一截细细的刀茎，接到护手里会压在握柄上：从底往上，比刃根窄一截的行都切掉。"""
    alpha = np.asarray(art.getchannel("A")) > 128
    widths = alpha.sum(1)
    rows = np.where(widths > 0)[0]
    if rows.size == 0:
        return art
    lower = widths[rows[int(rows.size * 0.7)]:rows[-1] + 1]
    reference = np.median(lower[lower > 0])
    cut = rows[-1]
    while cut > rows[0] and widths[cut] < reference * 0.8:
        cut -= 1
    return art.crop((0, 0, art.width, cut + 1))


def cinnabar(pixels):
    """原画里褪色朱红的布条、绳子、穗子的分量（0~1）：偏红的色相、够饱和、不太暗。
    皮革、旧铜、土黄偏橙，色相落在窗外，留在底子里不被重染。"""
    rgb = pixels[..., :3]
    high = rgb.max(-1)
    low = rgb.min(-1)
    chroma = high - low
    saturation = chroma / np.maximum(high, 1.0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hue = np.where(high == r, ((g - b) / np.maximum(chroma, 1.0)) % 6.0,
        np.where(high == g, (b - r) / np.maximum(chroma, 1.0) + 2.0, (r - g) / np.maximum(chroma, 1.0) + 4.0)) * 60.0
    hue = np.where(hue > 180.0, hue - 360.0, hue)
    reddish = np.clip((24.0 - np.abs(hue - 4.0)) / 10.0, 0.0, 1.0)
    return reddish * np.clip((saturation - 0.28) / 0.17, 0.0, 1.0) * np.clip((high - 55.0) / 40.0, 0.0, 1.0)


def painted(name, kind, spec):
    """读 source/parts/<name>.png 顶替脚本画的零件；没有就返回 None。

    原画拆两层：底子保留原画本来的颜色（锈铁、旧铜、旧骨、皮革），游戏里只乘一层接近白的钢色；
    朱红的布条绳穗抽成灰度，游戏里按主行的颜料色重染（握柄的缠绳按缠绳色）。"""
    path = HERE / "source" / "parts" / (name + ".png")
    if not path.exists():
        return None
    art = Image.open(path).convert("RGBA")
    bounds = art.getchannel("A").point(lambda a: 255 if a > 24 else 0).getbbox()
    if bounds is None:
        print("原画零件是空的，仍用脚本画的：%s" % path.name)
        return None
    art = art.crop(bounds)
    if kind == "blade":
        art = trim_stub(art)
    if kind == "gear":
        # 装备图标：整件放进格子正中，长边占 120 单位。
        ratio = 120.0 * SCALE / max(art.width, art.height)
        width, height = max(1, round(art.width * ratio)), max(1, round(art.height * ratio))
        place = (round(64 * SCALE - width / 2), round(64 * SCALE - height / 2))
        spec["box"] = (place[0] / SCALE, place[1] / SCALE, width / SCALE, height / SCALE)
    elif kind in ("guard", "pommel"):
        # 护手、柄首又扁又宽，按宽度对齐，厚度随原画；拼的时候刃和握柄按新的厚度接。
        width = round(spec["width"] * 2 * SCALE)
        height = max(1, round(art.height * width / art.width))
        spec["length"] = height / SCALE
    else:
        height = round(spec["length"] * SCALE)
        # 出图的弓臂都偏细，缩到游戏里只剩一根线：横向加宽一些。
        stretch = 1.6 if kind == "bow" else 1.0
        width = max(1, min(round(art.width * height / art.height * stretch), (SPACE - 4) * SCALE))
    if kind != "gear":
        place = (round(BASE[0] * SCALE - width / 2), round(BASE[1] * SCALE) - height)
    art = art.resize((width, height), Image.LANCZOS)
    pixels = np.asarray(art).astype(np.float32)
    alpha = pixels[..., 3]
    accent = cinnabar(pixels)
    value = pixels[..., :3].max(-1)
    lit = accent > 0.5
    top = np.percentile(value[lit], 98) if lit.any() else 255.0
    value = np.clip(value * (240.0 / max(top, 1.0)), 0, 255)
    base = np.dstack([pixels[..., :3], alpha * (1.0 - accent)]).astype(np.uint8)
    paint = np.dstack([value, value, value, alpha * accent]).astype(np.uint8)
    layers = []
    for data, tint in ((base, "steel"), (paint, "wrap" if kind == "grip" else "accent")):
        if data[..., 3].max() < 12:
            continue
        pen = Pen()
        pen.image.alpha_composite(Image.fromarray(data), place)
        layers.append((pen, tint))
    if kind != "gear":
        spec["width"] = max(spec["width"], width / SCALE / 2)
    spec.pop("groove", None)
    return layers


def from_prompts(kind):
    """只有原画、没有脚本替身的零件：装备图标（gear）。
    名字、槽位、甲型、长度和握点取自 parts-prompts.json。"""
    prompts = json.loads((HERE / "parts-prompts.json").read_text(encoding="utf-8"))
    out = {}
    for key, entry in prompts["assets"].items():
        if entry.get("kind") != kind:
            continue
        spec = {"layers": [], "length": float(entry.get("length", 120.0)), "width": 12.0}
        for field in ("slot", "armor_type", "sex", "hold"):
            if field in entry:
                spec[field] = entry[field]
        out[key[len("parts/"):-len(".png")]] = spec
    return out


def gd_vector(point):
    return "Vector2(%.1f, %.1f)" % (point[0] - BASE[0], BASE[1] - point[1])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview")
    args = parser.parse_args()
    groups = [("blade", blades()), ("guard", guards()), ("grip", grips()), ("pommel", pommels()),
        ("head", heads()), ("bow", bows()),
        ("gear", from_prompts("gear"))]
    cells = []
    table = []
    for kind, parts in groups:
        for name, spec in parts.items():
            layers = []
            source = painted(name, kind, spec)
            if source is not None:
                # 七星这类沿中脊的灵光点还对得上直刃，留着；别的附加层（刃口高光、宝石）随原画作废。
                keep = [layer for layer in spec["layers"][1:] if layer[1] == "glow" and kind == "blade"]
                spec["layers"] = source + keep
            elif not spec["layers"]:
                continue
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
        "# groove 是血槽走线（以接口为原点、沿轴为 +y），hold 是短杖从柄尾到握点的距离，tip 是弓弰挂弦处（同一坐标）。",
        "# 弓只画上半张，下半张由游戏沿弓把镜像。",
        "# layers 每层是 [格序, 染色]：steel 底子（近白，淡淡偏五行）、accent 朱砂纹饰换成的五行颜料色、trim 饰色、wrap 缠绳、bone 骨色、wood 弓臂漆色、glow 灵光，空串不染。gear 是装备图标，box 是它在格子里的范围。",
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
        if "slot" in spec:
            fields.append('"slot": "%s"' % spec["slot"])
        if "armor_type" in spec:
            fields.append('"armor_type": "%s"' % spec["armor_type"])
        if "sex" in spec:
            fields.append('"sex": "%s"' % spec["sex"])
        if "box" in spec:
            fields.append('"box": Rect2(%.1f, %.1f, %.1f, %.1f)' % spec["box"])
        if "tip" in spec:
            fields.append('"tip": %s' % gd_vector(spec["tip"]))
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
