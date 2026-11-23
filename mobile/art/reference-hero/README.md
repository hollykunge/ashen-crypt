# 原图刀客

刀形角色在战场、随侍与行装页使用同一套完整人物帧。原先的拆件外观只继续用于长枪和弓，试演中明确标为待重绘。

`source/approved.jpg` 是用户确认的 1280×640 三姿势参考，保持原文件不变。布衣 `idle`、`ready`、`strike` 直接提取原图中的站姿、备战与斩击；仅去除纸背景、分离的刀光和地面线，再平移到统一画布，没有重画五官、肢体、服饰，也没有横向压缩。每个保留的不透明像素保持原 RGB。显示时由游戏做正常等比缩放和取样，因此最终屏幕像素不等于素材像素。

上述 `frames/` 原稿继续保留，方便对照。游戏中的站姿与战斗姿势另用 `bodies/`：移除原稿里长度不一致的刀刃，仅在刀刃遮挡区域补回衣料，人物脸、发髻和肢体保留原稿。新刀刃由 `reference_blade.gd` 从原图备战姿势取纹理，通过独立 `Polygon2D` 贴在各帧握柄前端，刀根到刀尖固定为 190 素材像素（人物站高约 500 像素），姿势只改变它的位置与角度。四种衣装共用刀刃，不再随命中或收刀帧缩短。走跑仍使用完整帧中原有的携刀画稿。

走路八帧、跑步八帧、战斗过渡八帧由内置 ImageGen 参考原图补绘。走跑修订版要求左右支撑交替、持刀手与同侧腿反向运动；前一版重复半周期的图保存在 `source/*-halfcycle.png`，运行时不使用。新增姿势的脸和衣褶仍有补绘差异，不能把三个原图关键姿势的像素核对结论推广到全部动画帧。

## 运行与对照

在标题页点「手绘试演 · 动作与换装」，或者从仓库根目录执行 `./preview-ink.ps1`。站姿、备战、斩击定格三个按钮显示原图人物姿势与统一长度的刀刃；攻击按钮展示完整出刀、命中、收刀循环，「慢斩」以 0.3 倍动作速度检查握持与刀长。走跑由移动距离驱动八帧循环，统一脚底锚点，跑步腾空帧抬离地面。攻击命中姿势对齐游戏每一斩的结算时刻。

后撤与受击使用补绘的防守姿势再回到备战，技能使用掌势再回到备战；这些是简化表现，并非各自完整八帧的独立动作。

## 衣装与性能

新版男性底身和单穿布衣上衣时，共用[完整环首刀透明素材](weapons/ring-dao.png)。[武器节点](../../scripts/ring_dao.gd)定义固定握点、刀尖和人物坐标下的等比尺寸，动作表只指定握点位置和朝向。备战和斩击各有独立的[握刀手](source/guard-hands-prompts.json)，四指盖住柄面，食指贴着铜护手的后沿，拇指收在柄后。布衣上衣当前提供备战、斩击两帧。[绘制提示词](source/ring-dao-prompt.json)。

制作站姿衣片时请用同一张 800×640 画布上的[侧面底稿](source/standing-views/side.png)和[正面底稿](source/standing-views/front.png)。两幅图共用脚底线和身高，各视角的肩、腰、腕、膝、踝坐标见[衣片定位点](source/standing-views/anchors.json)。[导出脚本](source/register_standing_views.gd)按游戏侧面站姿登记正面原画。

男性刀客四个防具栏清空时，战场与行装都显示 [独立底身图集](bodies/male)。图集中只有穿不透明短内裤的赤脚人物；刀单独挂在握点，武器栏清空即为空手。打开「手绘试演」默认进入这个状态。站姿、备战、斩击共用一张图集，走、跑、战斗过渡各有八帧。每组沿用统一的缩放，落脚线和握点记在 [male_base.gd](../../scripts/male_base.gd)。[底身原稿](source/base-male-prompts.json)与[肌肉线条简化稿](source/base-male-lean-prompts.json)记录了正面及四张动作图集的 ImageGen 提示词。已装备防具的角色仍使用下述衣装帧。

布衣沿用原稿。皮甲和链甲都覆盖 27 帧，包括站姿、备战、斩击、八帧走路、八帧跑步和八帧战斗过渡。两套装备共用已经确认的画稿。行走、跑步和出招时，肩甲、前臂、分片下摆与靴子跟随该帧关节。每一帧分别标出护腕、小腿和鞋面，护腿与靴子可独立替换，战场、随侍和行装页使用同一渲染器。

用 Pillow、NumPy、SciPy 运行 `source/pack_keyposes.py` 重建备战和斩击，再运行 `source/pack_motion.py` 重建其余装备图。图集是 `source/keyposes-*.png`，动作关节坐标在 `source/motion_sockets.py`。运行时直接读取 `keyposes/` 中的完成帧和部位遮罩。以普通战场比例录制四种穿搭可运行：

```sh
godot --path mobile --resolution 1280x900 --fixed-fps 24 --script res://tests/wardrobe_motion_movie.gd -- <输出目录>
```

## 素材与复现

源图与生成原稿位于 `source/`，该目录用 `.gdignore` 排除 Godot 导入；游戏加载 `frames/`、`keyposes/`、`bodies/cloth/` 与 `portrait.png`。完整修订提示词记录在 [generation-prompts.json](generation-prompts.json)，刀刃移除与遮挡修复提示词见 [blade-edit-prompt.json](blade-edit-prompt.json)，均使用内置 `image_gen.imagegen`。

`pack.gd` 是确定性资产打包：分离原图背景、切分图集、统一整个人物的缩放、注册头部与落脚位置、合成衣装遮罩。它不生成新姿势，也不分别拉伸四肢。画布为 800×640，脚底锚点 `(300, 560)`，原图站姿身高约 500 像素。

```sh
godot --headless --path mobile --script res://art/reference-hero/pack.gd
godot --headless --path mobile --script res://art/reference-hero/pack.gd -- board
godot --headless --path mobile --script res://art/reference-hero/pack.gd -- costume <source/leather.png绝对路径> leather
godot --headless --path mobile --script res://art/reference-hero/pack.gd -- costume <source/chain.png绝对路径> chain
godot --headless --path mobile --script res://art/reference-hero/weapon_layout.gd
# source/blade-removal.png 为已保留的受约束编辑结果；只合成刀刃遮挡区域。
godot --headless --path mobile --script res://art/reference-hero/pack_weapon.gd
godot --headless --path mobile --editor --import
godot --headless --path mobile --script res://tests/reference_fidelity_check.gd
godot --headless --path mobile --script res://tests/reference_blade_check.gd
godot --path mobile --script res://tests/reference_review.gd -- <原图与游戏渲染对照.png>
godot --path mobile --script res://tests/weapon_outfit_review.gd -- <四套衣装对照.png>
godot --path mobile --script res://tests/weapon_outfit_review.gd -- <斩击六帧.png> blades
godot --path mobile --resolution 1280x900 --fixed-fps 30 --script res://tests/ink_preview_check.gd -- <截图目录>
godot --path mobile --resolution 1280x900 --fixed-fps 30 --script res://tests/ink_preview_movie.gd -- <JPEG帧目录>
godot --path mobile --resolution 1280x900 --fixed-fps 30 --script res://tests/ink_preview_movie.gd -- <JPEG帧目录> weapon
ffmpeg -framerate 30 -i <JPEG帧目录>/%05d.jpg -c:v libx264 -crf 19 -pix_fmt yuv420p -movflags +faststart preview.mp4
```

像素核对与运行测试只能验证素材保留、渲染切换和游戏接入，动作观感需结合实际视频检查。
