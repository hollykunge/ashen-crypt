# 主角美术：已定稿（2026-11-25）

主角就用这一套，**不再换路线**。之前走过手绘帧、皮影拆件、2D 分层出图，最后定在 3D 模型。以后只在这套上修和加，不推倒重来。

## 定下来的是什么

| 项 | 定稿 | 在哪 |
| --- | --- | --- |
| 渲染方式 | 3D 模型在游戏里实时渲染，离屏画布侧面出图，再画进 2D 战场和行装页 | `scripts/model_hero.gd`、`scripts/cutout_hero.gd` |
| 模型源文件 | Quaternius 共用骨架（CC0），65 根骨骼 | `gen-out/model/ashen_char_3outfits.blend` |
| 画风 | 三阶卡通着色 + 深棕描边；战场再叠暗黑调色 | `scripts/model_toon.gdshader`、`scripts/model_outline.gdshader`、`scripts/arena.gd` 的 `GRADE` |
| 衣装 | 布衣、皮甲、链甲，五个槽可混搭；头饰跟着上衣的护甲类别走（斗笠、皮兜鍪、铁兜鍪） | `.blend` 里的 `Leather_*`、`Chain_*`、`Head_*` |
| 甲面花纹 | 皮甲上衣是札甲片加编绳、领口肩顶素皮；链甲是斜放的锁子环 | `gen-out/model/scripts/detail_armor.py`，导出前跑 |
| 发型 | 往后梳、扎发髻 | `Head_Hair_Bun` / `Tail` / `Band` / `Pin` |
| 兵器 | 刀、剑、长枪、弓：古兵器素材包里挑的整件，按锻造出的刃型 / 枪头 / 弓臂挑一件，挂在手骨上；只套卡通着色和描边，不按五行上色 | `weapons.glb`、`gen-out/model/scripts/import_pack_weapons.py` |
| 动作 | 12 个（待机、走、跑、戒备、挥砍、受击、倒地、翻滚、前刺、撒放等） | `.blend` 里的 Action，`gen-out/model/scripts/add_actions.py` |
| 头像 | 模型渲的侧面半身像 | `portrait.png` |
| 装备格图标 | 上衣、护腕、护腿、靴子按布衣／皮甲／链甲各渲一张，游戏里按身上同一个颜色染（`appearance.gd` 的 `garment_tint`） | `icons/`，由 `tests/_gear_icons.gd` 生成 |
| 兵器格图标 | 手里那 11 件 3D 兵器各渲一张，兵器格按 `model_hero.gd` 的 `weapon_part` 挑同一件，图标和手里拿的是同一把；改了 `weapons.glb` 要重跑 | `icons/weapon_*.png`，由 `tests/_weapon_icons.gd` 生成 |
| 握法 | 出招按拳头握；戒备、走跑时剑和枪贴着侧面朝前上方（`plane`）；拉弓时右臂用两段骨 IK 搭弦拉到下巴，弓弦跟着手（`model_hero.gd` 的 `_apply_plane`、`_apply_draw`） | `scripts/model_hero.gd`、`scripts/cutout_hero.gd` |
| 剑身 | 比照实尺寸加宽、加厚（`model_hero.gd` 的 `BLADE_SCALE`），手机战场上才看得见 | `scripts/model_hero.gd` |

模型怎么搭、怎么导出，见 [gen-out/model/README.md](../../../gen-out/model/README.md)。

## 以后可以做的

- 修问题：穿模、动作别扭、某个搭配看着不对。
- 加动作：放进 `add_actions.py` 的 `WANT` 列表重跑。
- 加装备件：照皮甲、链甲的做法，从现有部件复制再换材质，写成可以重跑的脚本，再导出。
- 调颜色：只调某件衣服或兵器的配色，不动着色器的整体参数。

## 不再做的

- 换回手绘帧、皮影拆件或 2D 分层出图。
- 换整体画风（着色阶数、描边、调色）。
- 重做脸、体型、骨架。

真要动这几条，先写清楚为什么现在这套不行，再决定。

## 还没解决的

- **女性主角**：创角可以选女，但模型只有男性。要补的话，用同一副骨架和 Universal Base Characters 里的女性身体，衣装照现在的办法复制过去；在补上之前，女性角色也用男模型显示。
