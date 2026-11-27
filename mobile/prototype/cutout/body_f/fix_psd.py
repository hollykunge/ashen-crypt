"""修 source/ 里女主分片 PSD 原稿的几处小毛病，另存一份（-修瑕.psd），不动原文件。

    python fix_psd.py [原 PSD] [输出 PSD]

修什么（其它像素一律不动）：
1. 两只张开的手：手腕圆头是另贴的一块皮，纹理比手掌细、和手掌之间有一道横缝，描边在缝两头错开 1-2 像素、粗细也不一样。
   圆头皮子：明暗颜色留它自己的（整体亮度对齐手掌），细纹换成这只手自己手掌的细纹（整体平移过来）；铆钉一圈不动。
   描边：缝上下各 7 行内，外缘位置按上下干净行插值摆正，描边剖面从上面那行逐行渐变到下面那行。
2. 右手握刀拳：皮子比别的件暗、偏冷、花纹大一号 → 明暗留拳头自己的、整体颜色对齐张开的左手（排布里它就叠在左手上）、
   细纹换成大腿上一整块皮子的细纹（按拳头轮廓找能整块盖住的位置，不平铺不镜像）；
   小号铆钉（约 8 像素）换成和其它关节一样的标准铆钉（从左手拓过来），位置不变。
3. 每层只留最大的一块，去掉散落的杂点；描边外面贴着的一圈近乎全透明的黄红白碎像素也去掉（耳垂铆钉那层不动）。
4. 右手握刀拳那层挪到画布右下的空地，不再和张开的左手叠在一起。

左右一律指角色本人的左右（和 PSD 图层名一致）；说画布上的位置时写明「画布左边 / 画布右边」。
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from psd_tools import PSDImage
from psd_tools.api.layers import PixelLayer
from psd_tools.constants import Tag
from scipy import ndimage

SRC = Path(sys.argv[1]) if len(sys.argv) > 1 else (
    Path(__file__).resolve().parent / "source/原排布-参考手形-耳垂铆钉-参考图右手握拳-手部描边精修.psd")
DST = Path(sys.argv[2]) if len(sys.argv) > 2 else SRC.with_name(SRC.stem + "-修瑕.psd")
# 图层顺序同 export_psd.py
# 图层顺序同 PSD（角色本人的左右）。右边身体的件排在画布左边，左边身体的件排在画布右边
NAMES = ["头片", "躯干", "右上臂", "左上臂", "右前臂", "左前臂", "右手", "左手", "右手握刀拳",
         "左大腿", "右大腿", "左小腿", "右小腿", "左脚", "右脚", "耳垂铆钉"]
HAND_RIGHT, HAND_LEFT, FIST_RIGHT, THIGH_LEFT = 6, 7, 8, 10
FIST_MOVE = (40, 200)  # 右手握刀拳往下挪到空地（画布右边，左前臂、左大腿右边那片）


def main_blob(rgba):
    """只留最大的一块；再去掉贴在描边外面、离实心轮廓超过 2 像素的近乎全透明的碎像素（不透明度不到 10/255）。"""
    a = rgba[..., 3]
    out = rgba.copy()
    lab, k = ndimage.label(a > 0, structure=np.ones((3, 3)))
    if k > 1:
        sizes = ndimage.sum(a > 0, lab, range(1, k + 1))
        out[lab != 1 + int(np.argmax(sizes))] = 0
    near = ndimage.binary_dilation(out[..., 3] > 128, iterations=2)
    out[~near & (out[..., 3] < 10)] = 0
    return out


def lum(rgba):
    return rgba[..., :3].astype(float).mean(-1)


def rivet_center(rgba, small=False):
    c = rgba.astype(int)
    r, g, b, a = c[..., 0], c[..., 1], c[..., 2], c[..., 3]
    s = r + g + b
    m = (a > 200) & (r - b > 30) & (g - b > 10) & (s < 450) & (s > 120)
    lab, k = ndimage.label(m)
    best = None
    for i in range(1, k + 1):
        ys, xs = np.nonzero(lab == i)
        n, w, h = len(xs), np.ptp(xs) + 1, np.ptp(ys) + 1
        lo, hi, dmin, dmax = (25, 120, 5, 12) if small else (80, 300, 10, 22)
        if lo <= n <= hi and dmin <= w <= dmax and dmin <= h <= dmax and n > 0.5 * w * h:
            best = (xs.mean(), ys.mean())
    return best


def texture_source(candidates, mask):
    """依次在候选件（大腿、躯干）上找一个位置，让 mask 的每个像素都落在整块皮子上，返回那块的高频细纹。"""
    from scipy.signal import fftconvolve
    need = mask.sum()
    best = None
    for k, piece in enumerate(candidates):
        core = (skin_weight(piece) > 0.99).astype(float)
        hit = fftconvolve(core, mask[::-1, ::-1].astype(float), mode="valid")
        y, x = np.unravel_index(np.argmax(hit), hit.shape)
        cov = hit[y, x] / need
        if best is None or cov > best[0]:
            best = (cov, k, y, x)
        if cov > 0.999:
            break
    cov, k, y, x = best
    h, w = mask.shape
    rgb = candidates[k][y:y + h, x:x + w, :3].astype(float)
    lowp = low_pass(candidates[k][y:y + h, x:x + w], skin_weight(candidates[k][y:y + h, x:x + w]) > 0.99, 3)
    print(f"  拳头细纹取自第 {k} 个候选件 ({x}, {y})，覆盖 {cov:.1%}")
    return rgb - lowp


def best_shift(core, target, search=range(15, 60, 2), side=range(-30, 31, 2)):
    """找一个 (dy, dx)，让 target 里的像素挪 (dy, dx) 后尽量都落在 core 上。"""
    ty, tx = np.nonzero(target)
    H, W = core.shape
    best, best_cov = (0, 0), -1
    for dy in search:
        for dx in side:
            yy, xx = ty + dy, tx + dx
            ok = (yy >= 0) & (yy < H) & (xx >= 0) & (xx < W)
            cov = core[yy[ok], xx[ok]].sum()
            if cov > best_cov:
                best, best_cov = (dy, dx), cov
    return best, best_cov / max(1, len(ty))


def hf_strength(rgba, mask):
    L = lum(rgba)
    return float((L - ndimage.gaussian_filter(L, 3))[mask].std())


def low_pass(rgba, mask, sigma):
    """只用 mask 里的像素做模糊（不把描边的深色糊进来）。"""
    num = ndimage.gaussian_filter(np.where(mask[..., None], rgba[..., :3].astype(float), 0), (sigma, sigma, 0))
    den = ndimage.gaussian_filter(mask.astype(float), sigma)[..., None]
    return num / np.maximum(den, 1e-3)


def skin_weight(rgba, lo=180, hi=205):
    """1=纯皮子，0=描边/指缝线/铆钉；中间的抗锯齿像素按亮度过渡。"""
    return np.clip((lum(rgba) - lo) / (hi - lo), 0, 1) * (rgba[..., 3] > 200)


def fix_step(out, seam, side, rows=7, strip=8):
    """缝两头描边错开、粗细也对不上：窗口内每行外缘那一段（描边+抗锯齿，strip 像素）
    按上下两条干净行的外缘位置插值摆正，剖面也从上面那行逐行渐变到下面那行。"""
    a = out[..., 3]
    W = a.shape[1]

    def edge(y):
        xs = np.nonzero(a[y] > 128)[0]
        return xs.max() if side == "canvas_right" else xs.min()

    ya, yb = seam - rows - 1, seam + rows + 1
    ea, eb = edge(ya), edge(yb)
    src = out.copy()
    if side == "canvas_right":
        seg_a, seg_b = src[ya, ea - strip + 1:ea + 3].copy(), src[yb, eb - strip + 1:eb + 3].copy()
    else:
        seg_a, seg_b = src[ya, ea - 2:ea + strip].copy(), src[yb, eb - 2:eb + strip].copy()
    for y in range(ya + 1, yb):
        t = (y - ya) / (yb - ya)
        target = int(round(ea + (eb - ea) * t))
        seg = seg_a * (1 - t) + seg_b * t
        e_now = edge(y)
        if side == "canvas_right":
            lo = min(e_now, target) - strip + 1
            out[y, lo:target - strip + 1] = src[y, lo - 1]  # 外缘往外挪时，里面空出的用本行皮子补
            out[y, target - strip + 1:target + 3] = seg
            out[y, target + 3:min(W, max(e_now, target) + 4)] = 0
        else:
            hi_ = max(e_now, target) + strip
            out[y, target + strip:hi_] = src[y, hi_]
            out[y, target - 2:target + strip] = seg
            out[y, max(0, min(e_now, target) - 3):target - 2] = 0
    return out


def fix_open_hand(rgba, seam, side):
    """seam：手腕贴片和手掌之间那道横缝所在的行（层内坐标）。"""
    out = rgba.astype(float).copy()
    H, W = rgba.shape[:2]
    YY, XX = np.mgrid[0:H, 0:W]
    rv = rivet_center(rgba)
    skin = skin_weight(rgba)
    core = skin > 0.99
    palm = ndimage.binary_erosion(core & (YY >= seam + 2), iterations=2)
    disc = (skin > 0) & (YY < seam + 2)
    # 圆头的细纹：用这只手自己手掌的细纹，整体平移过来（不放大、不镜像）
    (dy, dx), cov = best_shift(palm, disc)
    rgb = rgba[..., :3].astype(float)
    hi = rgb - low_pass(rgba, core, 3)
    _, (ny, nx) = ndimage.distance_transform_edt(~palm, return_indices=True)
    sy, sx = np.clip(YY + dy, 0, H - 1), np.clip(XX + dx, 0, W - 1)
    ok = palm[sy, sx]
    sy, sx = np.where(ok, sy, ny[sy, sx]), np.where(ok, sx, nx[sy, sx])
    # 低频（颜色、明暗）留圆头自己的，整体亮度对齐手掌（贴片略浅）
    low = low_pass(rgba, core & (YY < seam), 3)
    low_palm = low_pass(rgba, palm, 3)
    low = low + (low_palm[palm].mean(0) - low[core & (YY < seam)].mean(0))
    # 缝以下那几行（渐变区）的底色直接用手掌的，别从圆头往下外推
    low = np.where((YY >= seam)[..., None], low_pass(rgba, core & (YY >= seam), 3), low)
    new = low + hi[sy, sx]
    # 缝和缝下一行全换，再往下 5 行渐变回原图；铆钉一圈不动
    w = np.clip((seam + 6 - YY) / 5.0, 0, 1) * skin
    w[((XX - rv[0]) ** 2 + (YY - rv[1]) ** 2) <= 10.5 ** 2] = 0
    out[..., :3] = out[..., :3] * (1 - w[..., None]) + new * w[..., None]
    out = fix_step(out, seam, side)
    print(f"  手腕纹理取自手掌偏移 ({dy}, {dx})，覆盖 {cov:.0%}")
    return np.clip(out, 0, 255).astype(np.uint8)


def fix_fist(fist, hand, sources):
    """拳头皮子对齐 hand（张开的左手）：低频明暗留拳头的、整体颜色对齐 hand、细纹换成大腿上整块皮子的细纹；铆钉换标准号。"""
    out = fist.astype(float).copy()
    Hf, Wf = fist.shape[:2]
    skin = skin_weight(fist)
    core = skin > 0.99
    h_core = skin_weight(hand) > 0.99
    low = low_pass(fist, core, 4)
    h_low = low_pass(hand, h_core, 4)
    low = low + (h_low[h_core].mean(0) - low[core].mean(0))
    ys, xs = np.nonzero(skin > 0)
    y0, x0, y1, x1 = ys.min(), xs.min(), ys.max() + 1, xs.max() + 1
    tex = np.zeros((Hf, Wf, 3))
    tex[y0:y1, x0:x1] = texture_source(sources, skin[y0:y1, x0:x1] > 0)
    new_skin = low + tex
    out[..., :3] = out[..., :3] * (1 - skin[..., None]) + new_skin * skin[..., None]

    # 铆钉：去掉小号的（用周围新皮子填），贴上 hand（左手）那颗标准铆钉
    small = rivet_center(fist, small=True)
    big = rivet_center(hand)
    YY, XX = np.mgrid[0:Hf, 0:Wf]
    old = ((XX - small[0]) ** 2 + (YY - small[1]) ** 2) <= 6.5 ** 2
    out[old, :3] = new_skin[old]  # 先用新皮子盖掉小铆钉
    R = 9.5
    Hh, Wh = hand.shape[:2]
    hy, hx = np.mgrid[0:Hh, 0:Wh]
    src = ((hx - big[0]) ** 2 + (hy - big[1]) ** 2) <= R ** 2
    sy, sx = np.nonzero(src)
    dy = np.round(sy - big[1] + small[1]).astype(int)
    dx = np.round(sx - big[0] + small[0]).astype(int)
    inb = (dy >= 0) & (dy < Hf) & (dx >= 0) & (dx < Wf)
    sy, sx, dy, dx = sy[inb], sx[inb], dy[inb], dx[inb]
    # 只拓铆钉本体（偏暗、偏铜色），外圈按距离羽化进拳头皮子
    d = np.hypot(sx - big[0], sy - big[1])
    body = np.clip((R - d) / 1.5, 0, 1) * (lum(hand)[sy, sx] < 200)
    out[dy, dx, :3] = out[dy, dx, :3] * (1 - body[:, None]) + hand[sy, sx, :3] * body[:, None]
    return np.clip(out, 0, 255).astype(np.uint8)


def main():
    psd = PSDImage.open(SRC)
    layers = list(psd)
    if len(layers) != len(NAMES):
        raise SystemExit(f"PSD 有 {len(layers)} 层，预期 {len(NAMES)} 层")
    pix = []
    for layer in layers:
        pix.append([main_blob(np.asarray(layer.topil().convert("RGBA"))), list(layer.bbox[:2])])
    # 图层名原样写回（PSD 里存的是 GIMP 写的 GBK 字节，psd-tools 按 MacRoman 读写，来回不变）
    names = layers

    # 右手（画布左边）的描边错位在它画布右侧的外缘，左手（画布右边）的在画布左侧的外缘
    for i, seam_world, side in ((HAND_RIGHT, 849, "canvas_right"), (HAND_LEFT, 853, "canvas_left")):
        rgba, (x0, y0) = pix[i]
        pix[i][0] = fix_open_hand(rgba, seam_world - y0, side)
    pix[FIST_RIGHT][0] = fix_fist(pix[FIST_RIGHT][0], pix[HAND_LEFT][0], [pix[THIGH_LEFT][0], pix[1][0]])
    pix[FIST_RIGHT][1] = [pix[FIST_RIGHT][1][0] + FIST_MOVE[0], pix[FIST_RIGHT][1][1] + FIST_MOVE[1]]

    out = PSDImage.new("RGBA", psd.size)
    for (rgba, (x0, y0)), name in zip(pix, names):
        ys, xs = np.nonzero(rgba[..., 3] > 0)
        crop = rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        layer = PixelLayer.frompil(Image.fromarray(crop), out, "layer", int(y0 + ys.min()), int(x0 + xs.min()))
        # 名字：旧式名字段和 Unicode 名块都照原层抄过去
        layer._record.name = name._record.name
        if Tag.UNICODE_LAYER_NAME in name.tagged_blocks:
            layer.tagged_blocks.set_data(Tag.UNICODE_LAYER_NAME, name.tagged_blocks.get_data(Tag.UNICODE_LAYER_NAME))
        out.append(layer)
    out.save(DST)
    print("已存", DST)


if __name__ == "__main__":
    main()
