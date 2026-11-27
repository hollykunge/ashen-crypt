"""生成女主装备模板 PSD：底身当底稿，每个装备槽一个空图层组，在 GIMP 里照着底身直接画装备。

    python make_gear_template.py [修瑕版 PSD] [输出 PSD]

模板里（从下往上）：
- 「底身（参考，勿动）」组：修瑕版的 16 层原样放进来，全部锁定，只当底稿看；
- 每个槽一个组，组名「槽-款式名」，组里每个部件一层空图层，图层名照底身的部件名。

装备不分布衣、皮甲、链甲，款式随意：画新款式就把一个槽的组整组复制一份、改个款式名。
某个部件那层留空，就表示这款装备不盖这个部件（露出底身）。
左右一律是角色本人的左右，和底身图层名一致。
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from psd_tools import PSDImage
from psd_tools.api.layers import Group, PixelLayer
from psd_tools.constants import ProtectedFlags, Tag

SRC = Path(sys.argv[1]) if len(sys.argv) > 1 else (
    Path(__file__).resolve().parent / "source/原排布-参考手形-耳垂铆钉-参考图右手握拳-手部描边精修-修瑕.psd")
DST = Path(sys.argv[2]) if len(sys.argv) > 2 else SRC.with_name("女主装备模板.psd")

# 槽 → 这个槽能盖住的部件（图层名）。靴筒是新加的一节：挂在小腿上、压在小腿外面，靴子才能包住小腿下段
# （脚本身压在小腿下面）。
GEAR = {
    "上衣": ["躯干", "右上臂", "左上臂"],
    "护腕": ["右前臂", "左前臂", "右手握刀拳", "左手"],
    "护腿": ["右大腿", "左大腿", "右小腿", "左小腿"],
    "靴子": ["右脚", "左脚", "右靴筒", "左靴筒"],
}
EXAMPLE = "款式一"
REFERENCE = "底身（参考，勿动）"


def name(item, text, legacy):
    """图层名：Unicode 名写中文（GIMP 读这个），旧式名字段只能放 MacRoman，写英文占位。"""
    item._record.name = legacy
    item.tagged_blocks.set_data(Tag.UNICODE_LAYER_NAME, text)


def main():
    src = PSDImage.open(SRC)
    out = PSDImage.new("RGBA", src.size)
    empty = Image.new("RGBA", src.size, (0, 0, 0, 0))

    ref = Group.new(out, "reference", open_folder=False)
    name(ref, REFERENCE, "reference")
    for i, layer in enumerate(src):
        px = PixelLayer.frompil(layer.topil().convert("RGBA"), ref, "base", layer.top, layer.left)
        px._record.name = layer._record.name
        if Tag.UNICODE_LAYER_NAME in layer.tagged_blocks:
            px.tagged_blocks.set_data(Tag.UNICODE_LAYER_NAME, layer.tagged_blocks.get_data(Tag.UNICODE_LAYER_NAME))
        px.lock(ProtectedFlags.COMPLETE)
    ref.lock(ProtectedFlags.COMPLETE)

    for k, (slot, parts) in enumerate(GEAR.items()):
        g = Group.new(out, "gear", open_folder=True)
        name(g, f"{slot}-{EXAMPLE}", f"gear-{k}")
        for j, part in enumerate(parts):
            px = PixelLayer.frompil(empty, g, "part", 0, 0)
            name(px, part, f"part-{k}-{j}")
    out.save(DST)
    print("已存", DST)


if __name__ == "__main__":
    main()
