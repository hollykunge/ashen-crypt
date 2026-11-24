"""Build the deliverable folder from render + compose outputs.

python pack.py <render_dir> <compose_dir> <dest gen-out/run-test> <preview combos comma list>
"""
import json, os, shutil, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import av

RD, CD, DEST = sys.argv[1], sys.argv[2], sys.argv[3]
PREVIEW = sys.argv[4].split(",")
meta = json.load(open(os.path.join(RD, "render_meta.json")))
FRAMES = meta["frames"]
BG = tuple(int(sys.argv[5][i:i + 2], 16) for i in (0, 2, 4)) if len(sys.argv) > 5 else (236, 236, 236)
os.makedirs(DEST, exist_ok=True)


def flat(im, bg=BG):
    c = Image.new("RGBA", im.size, bg + (255,))
    c.alpha_composite(im.convert("RGBA"))
    return c.convert("RGB")


# 1) swappable layers (the actual game assets), copied as-is
shutil.copytree(os.path.join(RD, "layers"), os.path.join(DEST, "layers"), dirs_exist_ok=True)

# 2) full-outfit frames rendered directly in 3D (reference) + 2D-stacked versions of every combo
for name, code in (("peasant", "pppp00"), ("ranger", "rrrrrr")):
    shutil.copytree(os.path.join(RD, "truth3d", code), os.path.join(DEST, "frames", name), dirs_exist_ok=True)
shutil.copytree(os.path.join(CD, "composite"), os.path.join(DEST, "stacked"), dirs_exist_ok=True)

# 3) overlay: peasant vs ranger per frame, 50/50 blend + outlines (cyan = peasant, magenta = ranger)
ov_dir = os.path.join(DEST, "overlay")
os.makedirs(ov_dir, exist_ok=True)
tiles = []
for fr in FRAMES:
    a = Image.open(os.path.join(RD, "truth3d", "pppp00", f"f{fr:02d}.png")).convert("RGBA")
    b = Image.open(os.path.join(RD, "truth3d", "rrrrrr", f"f{fr:02d}.png")).convert("RGBA")
    blend = Image.blend(flat(a), flat(b), 0.5)
    out = np.asarray(blend).copy()
    for im, col in ((a, (0, 200, 255)), (b, (255, 0, 180))):
        m = Image.fromarray(((np.asarray(im)[..., 3] > 127) * 255).astype(np.uint8))
        edge = np.asarray(m.filter(ImageFilter.FIND_EDGES)) > 0
        out[edge] = col
    # skeleton is shared: mark the head/hand/foot/hip positions from the 3D bones is unnecessary; show the outline only
    o = Image.fromarray(out)
    ImageDraw.Draw(o).text((8, 8), f"f{fr:02d}  cyan=peasant  magenta=ranger", fill=(0, 0, 0))
    o.save(os.path.join(ov_dir, f"overlay_f{fr:02d}.png"))
    tiles.append(o)
strip = Image.new("RGB", (sum(t.width for t in tiles), tiles[0].height))
x = 0
for t in tiles:
    strip.paste(t, (x, 0))
    x += t.width
strip.resize((strip.width // 2, strip.height // 2), Image.LANCZOS).save(os.path.join(ov_dir, "overlay_strip.png"))

# 4) checks: 3D truth vs 2D stack vs diff, for the preview combos
os.makedirs(os.path.join(DEST, "check"), exist_ok=True)
for c in PREVIEW:
    shutil.copy(os.path.join(CD, f"check_{c}.png"), os.path.join(DEST, "check", f"check_{c}.png"))
for f in ("mix_metrics.md", "mix_metrics.json"):
    shutil.copy(os.path.join(CD, f), os.path.join(DEST, "check", f))

# 5) preview animation: preview combos side by side, looping, from the 2D-stacked frames
cells = []
for fr in FRAMES:
    row = [flat(Image.open(os.path.join(CD, "composite", c, f"f{fr:02d}.png"))) for c in PREVIEW]
    canvas = Image.new("RGB", (row[0].width * len(row), row[0].height), BG)
    for i, im in enumerate(row):
        canvas.paste(im, (i * im.width, 0))
        ImageDraw.Draw(canvas).text((i * im.width + 8, 8), PREVIEW[i], fill=(60, 60, 60))
    cells.append(canvas.resize((canvas.width // 2, canvas.height // 2), Image.LANCZOS))
fps = 12  # 8 frames sampled from a 16-frame 24fps loop -> 12 fps keeps real speed
cells[0].save(os.path.join(DEST, "preview_mix.gif"), save_all=True, append_images=cells[1:], duration=int(1000 / fps), loop=0)
out = av.open(os.path.join(DEST, "preview_mix.mp4"), "w")
st = out.add_stream("libx264", rate=fps)
st.width, st.height = cells[0].width // 2 * 2, cells[0].height // 2 * 2
st.pix_fmt = "yuv420p"
for _ in range(6):  # repeat the loop a few times
    for c in cells:
        for p in st.encode(av.VideoFrame.from_image(c.crop((0, 0, st.width, st.height)))):
            out.mux(p)
for p in st.encode():
    out.mux(p)
out.close()

# 6) contact sheet of the two full outfits
rows = []
for name in ("peasant", "ranger"):
    ims = [flat(Image.open(os.path.join(DEST, "frames", name, f"f{fr:02d}.png"))) for fr in FRAMES]
    r = Image.new("RGB", (ims[0].width * len(ims), ims[0].height), BG)
    for i, im in enumerate(ims):
        r.paste(im, (i * im.width, 0))
    rows.append(r)
sheet = Image.new("RGB", (rows[0].width, rows[0].height * len(rows)), BG)
for i, r in enumerate(rows):
    sheet.paste(r, (0, i * r.height))
sheet.resize((sheet.width // 2, sheet.height // 2), Image.LANCZOS).save(os.path.join(DEST, "frames_sheet.png"))
print("packed", DEST)
