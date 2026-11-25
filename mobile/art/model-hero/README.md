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
| 头像 | 模型渲的大半个正面半身像（和行装页同一个角度 `cutout_hero.gd` 的 `PRESENT_YAW`） | `portrait.png`、`portrait_female.png`，由 `tests/_portraits.gd` 生成 |
| 装备格图标 | 上衣、护腕、护腿、靴子按布衣／皮甲／链甲各渲一张，游戏里按身上同一个颜色染（`appearance.gd` 的 `garment_tint`） | `icons/`，由 `tests/_gear_icons.gd` 生成 |
| 兵器格图标 | 手里那 11 件 3D 兵器各渲一张，兵器格按 `model_hero.gd` 的 `weapon_part` 挑同一件，图标和手里拿的是同一把；改了 `weapons.glb` 要重跑 | `icons/weapon_*.png`，由 `tests/_weapon_icons.gd` 生成 |
| 握法 | 出招按拳头握；戒备、走跑时剑和枪贴着侧面朝前上方（`plane`）；拉弓时右臂用两段骨 IK 搭弦拉到下巴，弓弦跟着手（`model_hero.gd` 的 `_apply_plane`、`_apply_draw`） | `scripts/model_hero.gd`、`scripts/cutout_hero.gd` |
| 剑身 | 比照实尺寸加宽、加厚（`model_hero.gd` 的 `BLADE_SCALE`），手机战场上才看得见 | `scripts/model_hero.gd` |
| 体型 | 男主角胳膊、肩头、胸、脖子、大腿加粗；女主角胸、臀加圆，胯稍宽，腰收一点。模型加载后按同一个形变场推身体和衣服的顶点（部件第一次露出来时才推），骨骼不动，动作和握法不受影响；对比图 `tests/_body_sweep.gd` | `scripts/body_shape.gd` |
| 脸 | 原素材是西方人脸，按武侠脸改：压低鼻梁鼻尖、削平眉骨、填浅眼窝、颧骨略往外，眉梢上挑成剑眉；女主角照仙侠美人的样子：鹅蛋脸、小鼻子、鼻翼收窄、小嘴、柳叶细眉，细颈削肩纤臂、丰胸细腰宽胯；男主角络腮胡两腮收进皮肤底下，只留下巴一撮和八字须。和体型同一套形变场；近景对比图 `tests/_face_shot.gd` | `scripts/body_shape.gd` |
| 发色 | 头发、眉毛、胡子统一乌黑（`model_toon.gdshader` 的 `hair_color`） | `scripts/model_toon.gdshader` |

模型怎么搭、怎么导出，见 [gen-out/model/README.md](../../../gen-out/model/README.md)。

## 男主角改用 Tripo 分槽模型（2026-11-26）

战场和行装页的**男主角**改用 `hero_tripo.glb`。它把三套 Tripo 生成的整身模型拆成部件：短打 peasant-3、皮甲 leather-2、链甲 chain-2。部件和一副打底身体一起蒙在短打那副骨架上，骨骼名和 12 个动作都与 `hero.glb` 相同，按槽混搭。

- **怎么选模型**：`cutout_hero.gd` 的 `MODEL_OF := {"male": "tripo"}`。部件对照表是 `model_hero.gd` 的 `TRIPO_SLOTS`。
- **不推形**：Tripo 模型不套 `body_shape.gd`，那套形变场是按 `hero.glb` 的身材量的。
- **不变的**：女主角、头像 `portrait.png`、装备格和兵器格图标仍用 `hero.glb` / `female.glb`。所以男主角的头像、图标和战场上的样子不一致，要统一就得用 Tripo 模型重渲。
- **来源和做法**：拆分、对齐、打底身体、绑骨都见 [gen-out/model/tripo-dark-hero/parts/README.md](../../../gen-out/model/tripo-dark-hero/parts/README.md)。

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
