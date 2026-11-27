"""Prepare the two native transparent V7 elements and render edge proofs."""
from pathlib import Path
import sys

import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import check_edges

raw = Path(__file__).resolve().parent
art = raw.parents[2]
check_edges.OUT = art / "piying/ui-shots-v7/edges"
check_edges.OUT.mkdir(parents=True, exist_ok=True)
for name, output in [("bank", "stage/bank"), ("ruyi", "v4/ruyi")]:
    src = raw / (name + ".png")
    im = Image.open(src)
    assert im.mode == "RGBA" and all(im.getpixel(p)[3] == 0 for p in
        [(0, 0), (0, im.height-1), (im.width-1, 0), (im.width-1, im.height-1)])
    # Discard near-invisible export noise outside the contour, retain antialiasing.
    alpha = im.getchannel("A").point(lambda a: a if a > 7 else 0)
    im.putalpha(alpha)
    x, y, r, b = alpha.getbbox()
    im = im.crop((max(0, x-2), y-2, min(im.width, r+2), b+2))
    pixels = np.array(im)
    empty = pixels[:, :, 3] == 0
    indices = distance_transform_edt(empty, return_distances=False, return_indices=True)
    pixels[empty, :3] = pixels[tuple(indices[:, empty])][:, :3]
    dest = art / "piying" / (output + ".png")
    Image.fromarray(pixels).save(dest)
    for path in (src, dest):
        point = None
        if name == "bank":
            # The left and right edges meet the adjacent tile. Inspect the exposed lip.
            with Image.open(path) as sample:
                x = sample.width // 3
                column = np.asarray(sample.getchannel("A"))[:, x]
                point = (x, int(np.flatnonzero(column > 96)[0]))
        check_edges.inspect(path, point)
