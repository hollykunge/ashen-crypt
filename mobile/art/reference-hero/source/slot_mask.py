"""Paint independent wrist, boot and greave channels on registered body frames."""
import numpy as np
from PIL import Image


def outfit_slots(wrists, lower, legs):
    coverage = np.asarray(lower)
    y, x = np.nonzero(coverage)
    pixels = np.column_stack((x + 0.5, y + 0.5))
    nearest = np.full(len(x), np.inf)
    boot_share = np.zeros(len(x))
    for knee, ankle, toe in np.asarray(legs, dtype=float):
        shin = ankle - knee
        foot = toe - ankle
        # The cuff turns with the joint, including when the shoe is airborne.
        normal = shin / np.linalg.norm(shin) + foot / np.linalg.norm(foot)
        normal /= max(np.linalg.norm(normal), 1e-6)
        cuff = np.clip((pixels - ankle) @ normal / 2 + 0.5, 0, 1)
        distance = np.full(len(x), np.inf)
        for start, axis in ((knee, shin), (ankle, foot)):
            projection = np.clip((pixels - start) @ axis / (axis @ axis), 0, 1)
            delta = pixels - start - projection[:, None] * axis
            distance = np.minimum(distance, np.sum(delta * delta, axis=1))
        closer = distance <= nearest
        boot_share[closer] = cuff[closer]
        nearest = np.minimum(nearest, distance)

    boots = np.zeros_like(coverage)
    boots[y, x] = np.rint(coverage[y, x] * boot_share).astype(np.uint8)
    return Image.merge("RGB", (wrists, Image.fromarray(boots), Image.fromarray(coverage - boots)))
