# 删光旧美术、旧模型，去掉枪和弓（交给 Codex）

用户要求：**旧的全部删除，包括人物、界面、模型，一个不留。** 现在游戏只保留月夜皮影这一套
（STYLE-V2.md、STYLE-V4.md、HERO-YOUTH.md 定下的：斗笠少年男主角 `prototype/cutout/piying`、鬼面女将女主角 `prototype/cutout/nvjiang`、
皮影精怪 `art/piying/monsters`、月夜布景、v4 界面）。

已经删掉（不用管）：仓库根目录的网页版原型（index.html、game.js、styles.css、assets/、preview-ink.ps1）和 gen-out/（Blender、Tripo 源文件）。

## 用户的决定：去掉长枪和弓

- 兵器只留 **刀（sword）和剑（jian）**。长枪（spear）、弓（bow）从游戏里整个拿掉：兵器种类、锻造（含兵器挂幡页）、掉落、装备生成、
  技能和招式里专属枪/弓的部分、远程射击（shots）、试演、图标、文案、存档。
- **旧存档迁移**：读档时把枪换成刀、弓换成剑（weapon_form 和装备名、形制一起改），不能因为旧存档里有枪弓而崩。写一条测试覆盖。
- 平衡别乱动：刀剑的数值不变；只是删掉枪弓的分支。相关测试改成只测刀剑。

## 要删的旧东西（删之前确认没有现行代码再引用；有引用就改成皮影版或一起删掉）

1. **3D 主角**：`art/model-hero/` 整个目录（hero.glb、hero_tripo.glb、female.glb、weapons.glb、烘焙贴图、icons/、portrait*.png、README.md），
   `scripts/model_hero.gd`、`model_toon.gdshader`、`model_outline.gdshader`、`model_silhouette.gdshader`、`portrait_light.gdshader`、
   `prototype/model_hero/`，以及只为 3D 服务的脚本（body_shape.gd、appearance.gd、figure.gd、rig.gd、motion.gd、held_weapon.gd、weapon_parts_atlas.gd、
   weapon_design.gd 里 3D 零件部分等——逐个查，确实只服务旧路线的才删）。
   `scripts/cutout_hero.gd` 改成只用皮影（puppet_hero.gd），没有 3D 回退。
   装备格、锻造里的**兵器图标**现在来自 3D 零件（`equipment_slot.gd` 的 `ModelHero.weapon_part`、`forge_art.gd`），改成皮影版兵器图（`art/piying/v4/weapons.png`、
   `art/ui-icons/weapons.png` 之类 Codex 第四版出过的），刀剑的不同形制/五行可以用调色区分。
2. **旧侧面画卷与兵器图集**：`art/side/`（plates 长卷、held-weapons.png、weapon-parts.png、source/）——月夜布景已经取代长卷的，删掉，并改掉引用（side_art.gd）。
3. **旧水墨界面**：`art/ink/`、`art/ui-icons/` 里已经不用的水墨笔触图和旧 raw 原图、`art/` 根目录的旧图（camp.webp、crypt*.webp、forge-*.webp/png、
   furnace-vault.webp、hero-vault.webp、spell-icons.webp、gothic_grade.gdshader、ember_orb.gdshader、各种 *-prompts.json），`art/immortals/` 里旧的仙人立绘
   （现在仙班用的是 `ui-icons/immortal-*.png`），`art/fx/` 旧特效。**用到的留下，没用到的删掉**；文件名还叫 stroke/paper/ink 但内容已经是皮影新图的，可以留，最好改个名并同步代码。
4. **旧皮影原型**：`prototype/cutout/swordsman/`、`prototype/cutout/hero/`（若存在）、`prototype/cutout/shanxiao/` 等不再使用的角色；
   `piying/source/`、`nvjiang/source/` 里没选用的备选图可以删（选用的那张和 style_ref 留下，以后重出要用）。
5. **旧截图与开发脚本**：`tests/` 里只为 3D 或旧水墨服务的截图脚本（_model_dress.gd、_gear_icons.gd、_face_shot.gd、_hand_shot.gd、_body_sweep.gd、
   _fit_art.gd、_stitch_plates.gd、ink_preview*.gd 等，逐个查）、`scripts/ink_preview.gd` 等；`art/piying/UI-BRIEF.md`（第一版暖琥珀，已作废）。
6. **文档**：根目录 README.md 和 mobile 里各 README 去掉 3D 主角、网页原型、水墨界面、枪弓的说明，改成现在的皮影版；
   第 3 行「主角美术已定稿：3D 角色模型」那段改成皮影版的说明。docs/ 里的设计文档如果提到枪弓或 3D，简单改一下或加一句已移除。

## 验收

- `godot --headless --path mobile --import` 没有缺失资源报错；`run_tests.gd`、`run_playthrough.gd` 都 0 失败。
- 全项目 grep 不再有 `model_hero`、`.glb`、`spear`、`bow`（除了旧存档迁移代码和它的测试）、`art/side`、`art/ink`、`art/model-hero` 的引用。
- 截图：标题、挂机、连战、行装（男、女各一张）、锻造（兵器挂幡只剩刀剑）、仙班，存到 `mobile/art/piying/ui-shots-v4/`（覆盖同名），自己看有没有缺图、空白、报错图标。
- 不要 git commit / push。不要留临时文件。

完成后在本文件末尾追加「完成情况」：删了哪些目录/文件（按类列，带大致体积）、哪些旧东西因为还在用而留下、存档迁移怎么做的。

## 完成情况

2026-11-27 已完成月夜皮影清理。以下体积按本次删除的 Git 工作树文件原大小估算，含对应导入说明，不含开始前已暂存删除的网页与建模源档。

| 删除类别 | 大致体积 |
| --- | ---: |
| 旧主角模型、烘焙贴图、装备图标、模型试穿场景 | 49.6 MiB |
| 旧侧面长卷、精怪画稿、手持兵器及零件图集 | 29.4 MiB |
| 旧界面图标、水墨笔触、原始图集 | 26.1 MiB |
| 旧角色原型和未选用的男女拆件候选图 | 7.7 MiB |
| 旧截图、旧试演、渲染和拼图测试脚本 | 6.4 MiB |
| 水墨布景、旧仙人立绘、像素特效及美术根目录旧图 | 9.9 MiB |
| 模型控制器、专用着色器、零件脚本和作废的界面说明 | 约 0.1 MiB |

共删除 674 个跟踪文件，约 129.2 MiB。男女两套皮影保留第二张选用原稿及风格参考。旧项目图标已替换，装备格、锻造预览和挂幡共用六格皮影刀剑图集。

仍在使用的资源包括仙班六张头像、月夜布景、材料和界面图标、按钮纸牌与灵珠着色器。外观、动作、骨架与人物特效脚本继续为五行染色、战场残影、脚下法阵和粒子提供数据。战场、随侍和行装统一加载皮影骨架。

当前版本存档在读档时逐件迁移，长枪换刀，弓换剑；同步改写装备名中的旧兵器字样，递归处理熔合来源。保留物品编号、穿戴关系、材料与工艺，发生迁移时通过临时文件原子替换写回。更早版本沿用原备份和材料折价流程。

Godot 4.7.2 已完成无头导入，未报缺失资源。规则测试 2662 条断言、实玩流程均为 0 项失败。标题、挂机、连战、男女行装、炉坊、横竖兵器挂幡和仙班已在桌面图形客户端截图复核，见 `ui-shots-v4/`。本机另有 Windows 根证书读取和编辑器启动 Android 调试桥子进程的环境报错。
