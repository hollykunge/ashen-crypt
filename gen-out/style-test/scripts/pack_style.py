"""Downscale 2x renders, build comparison sheets and per-variant mp4s.

python pack_style.py <render_dir> <dest gen-out/style-test>
"""
import os, sys
from PIL import Image, ImageDraw, ImageFont
import av

RD, DEST = sys.argv[1], sys.argv[2]
VARIANTS = [("base", "V0 原始"), ("toon", "V1 卡通着色"), ("toon_outline", "V2 +描边"),
            ("toon_outline_light", "V3 +三点光/AO"), ("toon_outline_light_paint", "V4 +笔触/暗土配色")]
COMBOS = [("ranger", "游侠整套"), ("mix", "混搭")]
FRAMES = [0, 2, 4, 6, 8, 10, 12, 14]
W, H = 480, 832
LIGHT, DARK = (217, 210, 197), (42, 34, 28)
FONT = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 22)


def on(im, bg):
    c = Image.new("RGBA", im.size, bg + (255,))
    c.alpha_composite(im)
    return c.convert("RGB")


# 1) downscale every 2x frame -> frames/<variant>/<combo>/fNN.png (transparent, 480x832)
for v, _ in VARIANTS:
    for c, _ in COMBOS:
        d = os.path.join(DEST, "frames", v, c)
        os.makedirs(d, exist_ok=True)
        for fr in FRAMES:
            im = Image.open(os.path.join(RD, v, c, f"f{fr:02d}_2x.png")).convert("RGBA")
            im.resize((W, H), Image.LANCZOS).save(os.path.join(d, f"f{fr:02d}.png"))


def frame(v, c, fr):
    return Image.open(os.path.join(DEST, "frames", v, c, f"f{fr:02d}.png")).convert("RGBA")


# 2) comparison sheets: same frame, one column per variant, rows = combos; light + dark background
CROP = (0, 120, W, H - 20)  # trim empty head-room
cw, ch = CROP[2] - CROP[0], CROP[3] - CROP[1]
for fr in (4, 10):
    for bgname, bg in (("light", LIGHT), ("dark", DARK)):
        txt = (40, 32, 26) if bgname == "light" else (220, 210, 195)
        sheet = Image.new("RGB", (cw * len(VARIANTS), 40 + ch * len(COMBOS)), bg)
        d = ImageDraw.Draw(sheet)
        for i, (v, label) in enumerate(VARIANTS):
            d.text((i * cw + 12, 8), label, fill=txt, font=FONT)
            for j, (c, clabel) in enumerate(COMBOS):
                sheet.paste(on(frame(v, c, fr), bg).crop(CROP), (i * cw, 40 + j * ch))
                if i == 0:
                    d.text((8, 40 + j * ch + 6), clabel, fill=txt, font=FONT)
        sheet.save(os.path.join(DEST, f"compare_f{fr:02d}_{bgname}.png"))

# 3) per-variant mp4: ranger | mix side by side, 12 fps (8 of 16 frames from a 24 fps loop), loop x6
os.makedirs(os.path.join(DEST, "video"), exist_ok=True)
for v, label in VARIANTS:
    out = av.open(os.path.join(DEST, "video", f"{v}.mp4"), "w")
    st = out.add_stream("libx264", rate=12)
    st.width, st.height = W * 2, H
    st.pix_fmt = "yuv420p"
    st.options = {"crf": "18"}
    cells = []
    for fr in FRAMES:
        canvas = Image.new("RGB", (W * 2, H), LIGHT)
        for j, (c, _) in enumerate(COMBOS):
            canvas.paste(on(frame(v, c, fr), LIGHT), (j * W, 0))
        ImageDraw.Draw(canvas).text((12, 10), label, fill=(40, 32, 26), font=FONT)
        cells.append(canvas)
    for _ in range(6):
        for cimg in cells:
            for p in st.encode(av.VideoFrame.from_image(cimg)):
                out.mux(p)
    for p in st.encode():
        out.mux(p)
    out.close()
print("packed", DEST)
