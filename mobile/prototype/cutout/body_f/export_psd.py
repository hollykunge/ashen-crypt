"""从美术给的分片 PSD 导出女主光身底图部件。

    cd prototype/cutout/body_f && python export_psd.py [PSD 路径]

PSD 每层一件、已经是圆头，铆钉画在关节上（耳钉单独一层，导出时合进头件）。这里做三件事：
1. 每层只留最大的那块，扔掉图层里散落的杂点；
2. 找铆钉（铜色小圆）当关节点：四肢上面那颗是 pivot、下面那颗是 end，躯干上是脖子、两肩、两胯；
3. 四肢转成 pivot 在上、end 在正下方，存 parts/<名字>.png（名字照 PSD 图层名，见 NAMES），关节点写 parts/joints.json，
   并同步进 ../rig.json 的 parts（骨骼部件用哪张图写在 file 里；只改关节点和 file，手调的缩放、握刀位置这些不动）。
图层名在 PSD 里是 GBK 乱码，按图层顺序对应 NAMES。
左右一律是角色本人的左右，和 PSD 图层名一致：右边身体的件排在画布左边，左边身体的件排在画布右边。
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from psd_tools import PSDImage
from scipy import ndimage

HERE = Path(__file__).resolve().parent
PSD = Path(sys.argv[1]) if len(sys.argv) > 1 else (
    Path(__file__).resolve().parent / "source/原排布-参考手形-耳垂铆钉-参考图右手握拳-手部描边精修-修瑕.psd")  # fix_psd.py 修过的那份
OUT = HERE / "parts"
# 图层顺序（PSD 图层名）：头片、躯干、右上臂、左上臂、右前臂、左前臂、右手、左手、右手握刀拳、
# 右大腿、左大腿、右小腿、左小腿、右脚、左脚、耳垂铆钉
NAMES = ["head", "torso", "upper_arm_right", "upper_arm_left", "forearm_right", "forearm_left",
         "hand_right", "hand_left", "fist_right", "thigh_right", "thigh_left", "shin_right", "shin_left",
         "foot_right", "foot_left", "ear_rivet"]
MERGE = {"ear_rivet": "head"}  # 这些层合进另一件，不单独导出
PAD = 6


def main_blob(rgba):
    a = rgba[..., 3]
    lab, k = ndimage.label(a > 0, structure=np.ones((3, 3)))
    sizes = ndimage.sum(a > 0, lab, range(1, k + 1))
    out = rgba.copy()
    out[lab != 1 + int(np.argmax(sizes)), 3] = 0
    return out


def rivets(rgba, small=False):
    """铜铆钉：偏暖、偏暗的实心小圆，返回圆心（x, y）列表。small：拳头上那颗小号铆钉（约 8 像素）。"""
    c = rgba.astype(int)
    r, g, b, a = c[..., 0], c[..., 1], c[..., 2], c[..., 3]
    s = r + g + b
    bronze = (a > 200) & (r - b > 30) & (g - b > 10) & (s < 450) & (s > 120)
    lab, k = ndimage.label(bronze)
    found = []
    for i in range(1, k + 1):
        m = lab == i
        n = m.sum()
        ys, xs = np.nonzero(m)
        w, h = np.ptp(xs) + 1, np.ptp(ys) + 1
        # 铆钉直径约 14-16 像素；皮子本身的暖色块要么很大、要么不圆
        lo, hi, dmin, dmax = (25, 120, 5, 12) if small else (80, 300, 10, 22)
        if lo <= n <= hi and dmin <= w <= dmax and dmin <= h <= dmax and n > 0.5 * w * h:
            found.append((round(float(xs.mean()), 1), round(float(ys.mean()), 1)))
    return sorted(found, key=lambda p: p[1])


def crop(rgba):
    ys, xs = np.nonzero(rgba[..., 3] > 0)
    x0, y0 = max(xs.min() - PAD, 0), max(ys.min() - PAD, 0)
    return rgba[y0:ys.max() + PAD + 1, x0:xs.max() + PAD + 1], (x0, y0)


def hang(rgba, pivot, end):
    """绕 pivot 转，让 end 落到 pivot 正下方。返回新图和 (pivot, end, 转了几度)。"""
    angle = float(np.degrees(np.arctan2(end[0] - pivot[0], end[1] - pivot[1])))
    arr, p = turn(rgba, pivot, angle)
    length = float(np.hypot(end[0] - pivot[0], end[1] - pivot[1]))
    return arr, p, (p[0], p[1] + length), angle


def turn(rgba, pivot, angle):
    """绕 pivot 顺时针转 angle 度（和 hang 同一个方向约定），裁边，返回新图和 pivot 的新位置。"""
    h, w = rgba.shape[:2]
    big = max(h, w) * 2
    canvas = Image.new("RGBA", (big, big))
    ox, oy = big // 2 - pivot[0], big // 2 - pivot[1]
    canvas.paste(Image.fromarray(rgba), (round(ox), round(oy)))
    rot = canvas.rotate(-angle, resample=Image.Resampling.BICUBIC, center=(big / 2, big / 2))
    arr, (x0, y0) = crop(np.asarray(rot))
    return arr, (big / 2 - x0, big / 2 - y0)


def r1(p):
    return [round(float(p[0]), 1), round(float(p[1]), 1)]


def main():
    psd = PSDImage.open(PSD)
    layers = list(psd)
    if len(layers) != len(NAMES):
        raise SystemExit(f"PSD 有 {len(layers)} 层，预期 {len(NAMES)} 层")
    OUT.mkdir(exist_ok=True)
    joints = {"source": str(PSD), "canvas": list(psd.size)}
    full = {}  # 每件铺在整张画布上，方便把耳钉之类的层合进去
    for name, layer in zip(NAMES, layers):
        canvas = Image.new("RGBA", psd.size)
        canvas.alpha_composite(Image.fromarray(main_blob(np.asarray(layer.topil().convert("RGBA")))),
                               (layer.bbox[0], layer.bbox[1]))
        if name in MERGE:
            full[MERGE[name]].alpha_composite(canvas)
        else:
            full[name] = canvas
    pieces = {}
    for name, canvas in full.items():
        rgba, (cx, cy) = crop(np.asarray(canvas))
        found = rivets(rgba) or rivets(rgba, small=True)  # 修过的拳头是标准铆钉，原稿是小号的
        at = (cx, cy)  # 这件在 PSD 排布里的左上角
        info = {"psd_at": [int(at[0]), int(at[1])], "rivets": [r1(p) for p in found]}
        kind = name.rsplit("_", 1)[0] if name.endswith(("_right", "_left")) else name
        if kind in ("upper_arm", "forearm", "thigh", "shin"):
            if len(found) != 2:
                raise SystemExit(f"{name}: 找到 {len(found)} 颗铆钉，应为 2")
            rgba, p, e, ang = hang(rgba, found[0], found[1])
            info.update(pivot=r1(p), end=r1(e), turned=round(ang, 1))
        elif kind in ("hand", "fist", "foot"):
            if len(found) != 1:
                raise SystemExit(f"{name}: 找到 {len(found)} 颗铆钉，应为 1")
            info["pivot"] = r1(found[0])
            if kind == "foot":
                ys, xs = np.nonzero(rgba[..., 3] > 128)
                info["sole"] = [info["pivot"][0], float(ys.max())]
        elif kind == "head":
            info["pivot"] = r1(found[-1])  # 脖子圆头上那颗
        elif kind == "torso":
            if len(found) != 5:
                raise SystemExit(f"torso: 找到 {len(found)} 颗铆钉，应为 5（脖子、两肩、两胯）")
            neck = found[0]
            shoulders = sorted(found[1:3])
            hips = sorted(found[3:5])
            info.update(neck=r1(neck), shoulder_back=r1(shoulders[0]), shoulder_front=r1(shoulders[1]),
                        hip_back=r1(hips[0]), hip_front=r1(hips[1]), pivot=r1(hips[0]))
        pieces[name] = (rgba, info)
    save_rig_parts(pieces, joints)


# 骨骼部件 ← 用哪张图。人物侧身朝右，观众看到的是她身体的右侧：
# 近侧（画在身体前面、右手握刀）= 右边身体，远侧（画在身体后面、压暗）= 左边身体。
RIG = {
    "head": "head", "torso": "torso",
    "upper_arm": "upper_arm_right", "forearm": "forearm_right", "hand": "fist_right",
    "far_upper_arm": "upper_arm_left", "far_forearm": "forearm_left", "far_hand": "hand_left",
    "thigh": "thigh_right", "shin": "shin_right", "foot": "foot_right",
    "far_thigh": "thigh_left", "far_shin": "shin_left", "far_foot": "foot_left",
}
# 手在 PSD 里是跟着排布里挨着的那条前臂原来的斜度画的；前臂转直了，手也按同样角度转过来，挂上去才对得上。
# 右手握刀拳在排布里叠在左手的位置上（画布右边），挨着的是左前臂
HAND_FOLLOWS = {"hand_right": "forearm_right", "hand_left": "forearm_left", "fist_right": "forearm_left"}


def save_rig_parts(pieces, joints):
    for old in OUT.glob("*.png"):
        old.unlink()
    for name, (rgba, info) in pieces.items():
        if name in HAND_FOLLOWS:
            turned = pieces[HAND_FOLLOWS[name]][1]["turned"]
            rgba, p = turn(rgba, info["pivot"], turned)
            info = dict(info, pivot=r1(p), turned=turned)
        Image.fromarray(rgba).save(OUT / f"{name}.png")
        info["size"] = [rgba.shape[1], rgba.shape[0]]
        joints[name] = info
        print(name, {k: v for k, v in info.items() if k in ("pivot", "end", "turned")})
    joints["rig"] = RIG
    (OUT / "joints.json").write_text(json.dumps(joints, ensure_ascii=False, indent=1), encoding="utf-8")
    sync_rig({part: joints[src] for part, src in RIG.items()})


def sync_rig(j):
    """把铆钉定出来的关节点写进 ../rig.json 的 parts；手调的键（scale、grip、grip_angle、behind 等）保留。"""
    path = HERE / "rig.json"
    rig = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
    parts = rig.setdefault("parts", {})
    t = j["torso"]
    hips = [(t["hip_back"][0] + t["hip_front"][0]) / 2, (t["hip_back"][1] + t["hip_front"][1]) / 2]
    def sole(shin, foot):
        return r1([j[shin]["end"][0] + j[foot]["sole"][0] - j[foot]["pivot"][0],
                   j[shin]["end"][1] + j[foot]["sole"][1] - j[foot]["pivot"][1]])
    auto = {
        "head": {"pivot": j["head"]["pivot"]},
        # 躯干连着内裤是一整块：绕两胯中点转，近侧胳膊、腿挂在后肩、后胯，远侧挂在前肩、前胯
        "torso": {"pivot": r1(hips), "neck": t["neck"], "shoulder": t["shoulder_back"],
                  "far_shoulder": t["shoulder_front"], "hip": t["hip_back"], "far_hip": t["hip_front"]},
        "upper_arm": {"pivot": j["upper_arm"]["pivot"], "end": j["upper_arm"]["end"]},
        "far_upper_arm": {"pivot": j["far_upper_arm"]["pivot"], "end": j["far_upper_arm"]["end"]},
        # 前臂画到手腕圆头为止，手单独一件：手腕就是下面那颗铆钉，不用再切图
        "forearm": {"pivot": j["forearm"]["pivot"], "wrist": j["forearm"]["end"],
                    "split": j["forearm"]["end"][1], "split_x": j["forearm"]["end"][0], "cleaned": True},
        "far_forearm": {"pivot": j["far_forearm"]["pivot"], "wrist": j["far_forearm"]["end"]},
        "hand": {"pivot": j["hand"]["pivot"]},
        "far_hand": {"pivot": j["far_hand"]["pivot"]},
        # 腿：近侧右腿、远侧左腿各用自己那套（左右大腿的轮廓是镜像的）。
        # 脚单独一件挂在脚踝铆钉上；sole 是脚放平时脚底在小腿图坐标里的位置（IK 让它踩地）
        "thigh": {"pivot": j["thigh"]["pivot"], "end": j["thigh"]["end"]},
        "shin": {"pivot": j["shin"]["pivot"], "ankle": j["shin"]["end"], "sole": sole("shin", "foot")},
        "foot": {"pivot": j["foot"]["pivot"], "sole": j["foot"]["sole"]},
        "far_thigh": {"pivot": j["far_thigh"]["pivot"], "end": j["far_thigh"]["end"]},
        "far_shin": {"pivot": j["far_shin"]["pivot"], "ankle": j["far_shin"]["end"], "sole": sole("far_shin", "far_foot")},
        "far_foot": {"pivot": j["far_foot"]["pivot"], "sole": j["far_foot"]["sole"]},
    }
    for name, keys in auto.items():
        keys["file"] = RIG[name]
        parts.setdefault(name, {}).update(keys)
    parts.setdefault("head", {}).setdefault("behind", True)
    # 装备槽各换哪些骨骼部件（槽名同游戏：armor 上衣、gloves 护腕、greaves 护腿、boots 靴子）
    rig["slots"] = {
        "armor": ["torso", "upper_arm", "far_upper_arm"],
        "gloves": ["forearm", "far_forearm", "hand", "far_hand"],
        "greaves": ["thigh", "far_thigh", "shin", "far_shin"],
        "boots": ["foot", "far_foot"],
    }
    path.write_text(json.dumps(rig, ensure_ascii=False, indent=1), encoding="utf-8")
    print("已更新", path)


if __name__ == "__main__":
    main()
