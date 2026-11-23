"""Fit the approved painted equipment pieces to every remaining swordsman pose.
Run with Pillow, NumPy and SciPy. Coordinates of atlas polygons use the 800 x 500
review grid. Motion sockets use quarter-size game frames (200 x 160).
"""

from pathlib import Path

import numpy as np
from motion_sockets import sockets, trunk
from slot_mask import outfit_slots
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps
from scipy.ndimage import distance_transform_edt

ROOT = Path(__file__).resolve().parent.parent
SIZE = (800, 640)
OUT = ROOT / "keyposes"


def polygon(text):
    return [tuple(map(float, p.split(","))) for p in text.split()]


# Separate the original illustrated plate, sleeve, skirt panels and greaves.
# The skirt is cut from the rear pose: both panels are clear of the hilt there.
CUTS = {
    "leather": {
        "pauldron": "176,79 183,85 193,120 181,122 178,134 159,141 151,150 137,157 122,148 105,150 109,139 113,131 104,130 111,118 119,109 112,102 117,96 139,85 158,82",
        "rear_pauldron": "562,94 583,97 602,99 622,102 630,105 624,111 643,111 650,117 643,126 630,130 622,141 609,141 602,151 578,152 575,139",
        "chest": "164,84 178,79 206,90 222,108 232,124 226,162 222,192 213,208 211,236 178,242 177,219 151,214 146,195 139,177 137,145 145,109",
        "back": "539,94 560,90 579,94 602,105 596,142 608,159 596,187 590,212 592,236 534,234 529,203 522,174 519,142 521,110",
        "sleeve": "104,152 100,141 111,126 102,125 114,102 110,98 132,86 157,82 175,85 192,121 183,137 170,142 157,151 145,164 131,152 119,145",
        "panelL": "537,230 568,232 562,266 552,286 541,282 518,314 518,300 508,304 513,278 498,288 508,258",
        "panelR": "565,232 588,230 604,244 622,256 629,269 648,285 628,281 640,300 617,292 601,281 589,313 574,290 561,298 560,274",
        "brace": "673,117 689,119 713,126 719,130 713,153 704,158 682,161 669,162 666,154 669,130",
        "shin": "229,385 248,376 276,376 280,397 273,414 275,437 280,452 249,459 239,449 243,425 235,408",
        "foot": "243,445 271,442 280,457 295,465 307,472 306,485 240,486 239,468",
    },
    "chain": {
        "mantle": "502,130 508,116 520,104 541,95 554,92 567,94 576,96 590,96 603,99 618,107 613,115 605,120 601,128 590,131 583,140 572,141 566,148 554,151 547,155 537,152 530,153 521,148 515,146 513,139 507,139",
        "chest": "177,82 192,78 218,100 230,115 238,140 240,163 240,192 221,210 220,231 180,235 179,218 155,219 155,198 149,170 153,140 160,101",
        "back": "540,94 560,91 581,94 604,101 617,108 603,137 610,153 598,180 587,204 580,232 519,235 521,202 514,176 515,141 522,105",
        "sleeve": "94,164 104,149 118,136 128,120 135,111 151,102 168,100 186,110 194,133 181,149 164,154 153,179 150,191 140,181 134,169 120,164 108,167 99,180",
        "panelL": "539,228 566,231 561,263 551,293 540,327 531,359 523,360 514,348 503,350 492,341 483,344 473,338 461,338 463,325 477,301 490,279 511,254",
        "panelR": "556,233 577,229 592,250 612,267 634,286 650,300 648,305 639,306 627,312 615,318 605,320 597,327 585,326 582,341 575,354 568,351 564,339 559,316 552,289",
        "brace": "684,120 692,122 710,128 706,142 704,151 691,152 677,156 677,147",
        "shin": "243,374 264,377 285,373 286,389 286,415 288,440 289,456 264,458 260,438 253,415 246,400",
        "foot": "260,448 282,441 291,458 303,467 315,471 321,477 321,486 259,486 257,471",
    },
}


def vec(p):
    return np.asarray(p, dtype=float)


def norm(v):
    return v / max(0.001, np.linalg.norm(v))


def perp(v):
    return np.array([-v[1], v[0]])


def poly_mask(points):
    result = Image.new("L", SIZE)
    ImageDraw.Draw(result).polygon([tuple(vec(p) * 4) for p in points], fill=255)
    return result


def limb(a, b, ra, rb):
    side = perp(norm(b - a))
    return poly_mask([a + side * ra, b + side * rb, b - side * rb, a - side * ra])


def disk(p, r):
    result = Image.new("L", SIZE)
    ImageDraw.Draw(result).ellipse(tuple(np.r_[(p - r) * 4, (p + r) * 4]), fill=255)
    return result


def union(*masks):
    result = masks[0]
    for m in masks[1:]:
        result = ImageChops.lighter(result, m)
    return result


class Kit:
    def __init__(self, style):
        self.style = style
        atlas = Image.open(ROOT / "source" / f"keyposes-{style}.png").convert("RGBA")
        self.parts = {}
        for part, coords in CUTS[style].items():
            mask = Image.new("L", atlas.size)
            points = np.array(polygon(coords)) * [atlas.width / 800, atlas.height / 500]
            ImageDraw.Draw(mask).polygon([tuple(p) for p in points], fill=255)
            piece = atlas.copy()
            if part == "chest":
                # The source sheet includes a model wearing the armour. Cover
                # its neck opening with adjacent garment material before fitting
                # the chest. Only the target pose supplies skin and collar ink.
                opening = (
                    "175,72 209,83 213,104 205,136 194,130"
                    if style == "leather"
                    else "184,72 224,85 226,120 212,127 199,118"
                )
                scale = np.array(atlas.size) / [800, 500]
                patch_mask = Image.new("L", atlas.size)
                ImageDraw.Draw(patch_mask).polygon(
                    [tuple(p) for p in np.array(polygon(opening)) * scale], fill=255
                )
                dx, dy = scale * [-19, 69]
                material = atlas.transform(
                    atlas.size,
                    Image.Transform.AFFINE,
                    (1, 0, dx, 0, 1, dy),
                    Image.Resampling.BICUBIC,
                )
                piece.paste(
                    material, mask=patch_mask.filter(ImageFilter.GaussianBlur(1.5))
                )
            piece.putalpha(ImageChops.multiply(mask, atlas.getchannel("A")))
            self.parts[part] = piece
        foot = np.array(self.parts["foot"])
        yy, xx = distance_transform_edt(
            foot[:, :, 3] < 96, return_distances=False, return_indices=True
        )
        self.shoe_paint = Image.fromarray(foot[yy, xx, :3])

    def shoe(self, canvas, base, ankle, toe):
        axis = norm(toe - ankle)
        down = perp(axis)
        if down[1] < 0:
            down = -down
        box = union(limb(ankle - axis * 2, toe, 6, 5), disk(ankle, 5), disk(toe, 4))
        alpha = ImageChops.multiply(
            base.getchannel("A"), box.filter(ImageFilter.GaussianBlur(2))
        )
        src = (
            [(274, 451), (317, 478), (264, 482)]
            if self.style == "chain"
            else [(255, 450), (302, 478), (241, 482)]
        )
        src = np.array(src) * np.array(self.shoe_paint.size) / [800, 500]
        dst = np.array([ankle, toe, ankle - axis * 2 + down * 5]) * 4
        coeff = np.linalg.solve(np.column_stack([dst, np.ones(3)]), src).T.flatten()
        paint = self.shoe_paint.transform(
            SIZE, Image.Transform.AFFINE, coeff, Image.Resampling.BILINEAR
        )
        # Use the original shoe's shading under the painted vamp. The new toe
        # and cuff may project past the cloth, while the planted sole stays put.
        shade = ImageOps.grayscale(base)
        material = (
            ImageOps.colorize(shade, "#242222", "#e3d8c9")
            if self.style == "chain"
            else ImageOps.colorize(shade, "#231813", "#ba8257")
        )
        canvas.paste(Image.blend(material, paint, 0.52), mask=alpha)
        bounds = box.getbbox()
        left, top, right, bottom = bounds
        x, y = left, top
        a, b, c, d, e, f = coeff
        local = (a, b, c + a*x + b*y, d, e, f + d*x + e*y)
        vamp = self.parts["foot"].transform(
            (right - left, bottom - top), Image.Transform.AFFINE, local, Image.Resampling.BICUBIC
        )
        footprint = alpha.crop(bounds)
        extent = footprint.getbbox()
        if extent:
            support = footprint.filter(ImageFilter.MaxFilter(11 if self.style == "chain" else 7))
            support.paste(0, (0, extent[3], support.width, support.height))
            vamp.putalpha(ImageChops.multiply(vamp.getchannel("A"), support))
            canvas.alpha_composite(vamp, (left, top))
            box.paste(ImageChops.lighter(box.crop(bounds), vamp.getchannel("A")), (left, top))
        return box

    def stamp(self, canvas, name, source, target):
        src = np.array(source) * np.array(self.parts[name].size) / [800, 500]
        dst = np.array(target) * 4
        coeff = np.linalg.solve(np.column_stack([dst, np.ones(3)]), src).T.flatten()
        tile = self.parts[name].transform(
            SIZE, Image.Transform.AFFINE, coeff, Image.Resampling.BICUBIC
        )
        canvas.alpha_composite(tile)
        return tile.getchannel("A")


def along(kit, canvas, part, src_a, src_b, src_side, a, b, width):
    left = -perp(norm(b - a))
    return kit.stamp(
        canvas, part, [src_a, src_b, src_side], [a, b, (a + b) / 2 + left * width]
    )


def dressed(kit, base, pose, points):
    (
        neck,
        belt,
        shoulder,
        elbow,
        wrist,
        knuckles,
        far_elbow,
        far_wrist,
        far_hand,
        k1,
        a1,
        t1,
        k2,
        a2,
        t2,
        tip,
    ) = map(vec, points)
    chain = kit.style == "chain"
    back = pose in ("combat-3", "combat-4")
    nape, collar, waist_left, waist_right = map(vec, trunk(pose))
    belt = (waist_left + waist_right) * 0.5
    # Carry the original collar and its shadow with the head. The armoured
    # atlas has its own neckline which must not cross this painted seam.
    head_mask = poly_mask(
        [
            (nape[0] - 12, 0),
            (200, 0),
            (200, collar[1] + 2),
            collar + [0, 3],
            nape + [-2, 1],
            nape + [-2, -7],
            nape + [-12, -13],
        ]
    )
    hands = union(limb(wrist, knuckles, 2.8, 3.3), disk(knuckles, 3.1))
    if tip.any():
        direction = norm(tip - knuckles)
        guard = knuckles + direction * 5
        # Restore the curved carried blade after the skirt; dark ink and the
        # reflective edge are both part of the blade's original silhouette.
        side = perp(direction)
        middle = (guard + tip) * 0.5
        steel = poly_mask(
            [
                guard - side * 3.5,
                middle - side * 2,
                tip + direction * 2 - side * 2,
                tip + direction * 2 + side * 2,
                middle + side * 6,
                guard + side * 4,
            ]
        )
        hands = union(hands, steel, limb(knuckles - direction * 5, guard, 2.4, 3.6))
    else:
        hands = union(hands, disk(knuckles, 4.4))
    # The mantle is part of the original back contour, especially on forward
    # leaning frames. Keep it under the fitted plates on every pose.
    canvas = base.copy()
    # A boot slot includes the old shoe and its replacement, so either style
    # can be selected where their silhouettes extend past each other.
    erase = Image.new("L", SIZE)
    for knee, ankle, toe in [(k1, a1, t1), (k2, a2, t2)]:
        start = knee + (ankle - knee) * 0.25
        erase = union(
            erase, limb(start, ankle, 7.2, 7.2), limb(ankle, toe, 7, 6), disk(toe, 5)
        )
    # Keep the rear arm behind the cuirass.
    rear = union(
        limb(far_elbow, far_wrist, 5, 3.7),
        limb(far_wrist, far_hand, 3, 3.8),
        disk(far_hand, 3.6),
        limb(neck + [3, 10], far_elbow, 7, 5.5),
    )
    canvas.paste(base, mask=ImageChops.multiply(rear, base.getchannel("A")))
    slot_glove = Image.new("L", SIZE)
    slot_boot = erase.copy()

    def bracer(a, b):
        start = a + (b - a) * (0.29 if chain else 0.12)
        end = b + (b - a) * 0.12
        return along(
            kit,
            canvas,
            "brace",
            (680, 138) if chain else (671, 139),
            (706, 139) if chain else (712, 141),
            (693, 150) if chain else (691, 158),
            start,
            end,
            3.1 if chain else 4.1,
        )

    rear_guard = (
        Image.new("L", SIZE)
        if pose in ("combat-2", "run-2", "run-4")
        else bracer(far_elbow, far_wrist)
    )
    slot_glove = union(slot_glove, rear_guard, limb(far_elbow, far_wrist, 4.6, 4.2))
    for knee, ankle, toe in [(k1, a1, t1), (k2, a2, t2)]:
        delta = ankle - knee
        top = knee + delta * 0.18
        shin = along(
            kit,
            canvas,
            "shin",
            (265, 380) if chain else (252, 382),
            (273, 453) if chain else (255, 452),
            (287, 415) if chain else (276, 416),
            top,
            ankle,
            3.9 if chain else 5.1,
        )
        # A separately fitted shoe keeps the toe on the ground during ankle rotation.
        foot = kit.shoe(canvas, base, ankle, toe)
        slot_boot = union(
            slot_boot, shin, foot, limb(top, ankle, 6, 5), limb(ankle, toe, 5, 3.5)
        )
    # Split tassets follow each thigh while their upper edges stay on the sash.
    sash_depth = vec([-0.7, 5.0])
    for left, knee in [(False, k2), (True, k1)]:
        src = np.array([[523, 232], [587, 232], [555, 344]])
        dest = np.array(
            [
                waist_left + sash_depth,
                waist_right + sash_depth,
                belt + sash_depth + [0, 25 if chain else 27],
            ]
        )
        drift = np.clip((knee[0] - belt[0]) * 0.26, -8, 8)
        dest[2] += vec([drift, -min(5, max(0, (belt[1] + 27 - knee[1]) * 0.24))])
        panel = kit.stamp(canvas, "panelL" if left else "panelR", src, dest)
        slot_boot = ImageChops.subtract(slot_boot, panel)
    src = (
        [(178, 79), (149, 197), (219, 197)]
        if not chain
        else [(192, 78), (155, 200), (220, 202)]
    )
    if back:
        src = [(561, 92), (529, 204), (590, 204)]
    cuirass = Image.new("RGBA", SIZE)
    kit.stamp(
        cuirass, "back" if back else "chest", src, [nape, waist_left, waist_right]
    )
    # Both skirt panels meet the same original sash. Retain its painted slope
    # and prevent the atlas belt from introducing a competing waistline.
    along_waist = waist_right - waist_left
    waist_start = waist_left - 5 * along_waist
    waist_end = waist_right + 5 * along_waist
    above_sash = poly_mask(
        [waist_start, waist_end, waist_end + [0, -160], waist_start + [0, -160]]
    )
    chest = ImageChops.multiply(cuirass.getchannel("A"), above_sash)
    cuirass.putalpha(chest)
    canvas.alpha_composite(cuirass)
    slot_glove = ImageChops.subtract(slot_glove, chest)
    # Paint the near arm over the torso, then fit the shoulder and the wrist layers.
    arm = union(
        limb(shoulder, elbow, 4.2, 4.1), limb(elbow, wrist, 4, 2.9), disk(elbow, 3.6)
    )
    visible = ImageChops.multiply(arm, base.getchannel("A"))
    canvas.paste(base, mask=visible)
    sleeve_end = shoulder + (elbow - shoulder) * (0.86 if chain else 0.72)
    if chain:
        sleeve = along(
            kit,
            canvas,
            "sleeve",
            (163, 104),
            (126, 166),
            (174, 143),
            shoulder,
            sleeve_end,
            6.8,
        )
        # The mail collar hangs from the trunk. The arm moves under it,
        # without rotating the scalloped edge along with the elbow.
        down = norm((belt - nape) * [0.45, 1.0])
        across = -perp(down)
        pin = nape + down * 1.2
        yoke = Image.new("RGBA", SIZE)
        kit.stamp(
            yoke,
            "mantle",
            [(554, 93), (506, 127), (550, 154)],
            [pin, pin - across * 14 + down * 6, pin - across * 2 + down * 14],
        )
        mantle = ImageChops.multiply(yoke.getchannel("A"), base.getchannel("A"))
        yoke.putalpha(mantle)
        canvas.alpha_composite(yoke)
        sleeve = union(sleeve, mantle)
    else:
        # Hinge the nested leather plates at the collar and let the outer
        # edge follow part of the upper-arm swing. All plates travel together.
        outward = 1 if back else -1
        cap = shoulder + 0.58 * (elbow - shoulder) + [outward * 3.5, 0]
        pin = nape + [outward * 1.2, 1]
        axis = norm(cap - pin)
        side = perp(axis) * outward
        src = (
            [(564, 95), (640, 117), (593, 148)]
            if back
            else [(176, 82), (109, 146), (175, 132)]
        )
        sleeve = kit.stamp(
            canvas,
            "rear_pauldron" if back else "pauldron",
            src,
            [pin, cap, (pin + cap) * 0.5 + side * 9.5],
        )
    slot_glove = ImageChops.subtract(slot_glove, sleeve)
    guard = bracer(elbow, wrist)
    slot_glove = union(
        slot_glove, guard, limb(elbow + (wrist - elbow) * 0.20, wrist, 4.9, 4.1)
    )
    canvas.paste(base, mask=ImageChops.multiply(hands, base.getchannel("A")))
    canvas.paste(base, mask=head_mask)
    # A centerline test misses holes behind the neck. Check every opaque
    # source pixel and preserve the face and collar exactly, including edges.
    original = np.asarray(base)
    dressed_pixels = np.asarray(canvas)
    if np.any((original[:, :, 3] > 200) & (dressed_pixels[:, :, 3] < 150)):
        raise ValueError(f"Missing body silhouette in {pose}/{kit.style}")
    protected = np.asarray(head_mask) != 0
    if not np.array_equal(original[protected], dressed_pixels[protected]):
        raise ValueError(f"Face or collar drift in {pose}/{kit.style}")
    return canvas, slot_glove, slot_boot


def main():
    kits = [Kit("chain"), Kit("leather")]
    for pose, points in sockets().items():
        body = ROOT / "bodies" / "cloth" / (pose + ".png")
        base = Image.open(
            body if body.exists() else ROOT / "frames" / (pose + ".png")
        ).convert("RGBA")
        gloves = []
        boots = []
        for kit in kits:
            image, glove, boot = dressed(kit, base, pose, points)
            image.save(OUT / f"{pose}-{kit.style}.png")
            gloves.append(glove)
            boots.append(boot)
        legs = np.array([points[9:12], points[12:15]]) * 4
        outfit_slots(union(*gloves), union(*boots), legs).save(
            OUT / f"{pose}-slots.png"
        )


if __name__ == "__main__":
    main()
