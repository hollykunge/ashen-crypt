# 手绘界面与场景预览

这套素材采用简化手绘、墨线轮廓和纸本配色。主角现在用 3D 角色模型（`art/model-hero`，来源和重新导出见 `gen-out/model/README.md`），原来的皮影刀客、原图人物帧和拆件（`art/reference-hero`、`art/hero-rig`、本目录 `hero/`）已删除。

## 查看

从游戏标题页点「手绘试演 · 动作与换装」，或运行仓库根目录的 `preview-ink.ps1`。

试演直接使用游戏的角色、装备推导和战场渲染。可整套切换布衣、皮甲和链甲，也可点上衣、护腕、护腿和靴子逐件切换。动作包括走、跑、攻击、后撤、受击、技能。「实战」恢复真实挂机战斗，「行装」进入实际背包并支持试穿。

试演每次建立独立临时角色，退出场景后清理；不读取或覆盖三个正常角色位。

主角模型单独的试穿台：`godot --path mobile res://prototype/model_hero/model_hero_demo.tscn`。

## 已接入范围

- 标题、选角、创角、战斗、行装、炉坊使用统一纸色面板、深墨文字、朱红强调与墨线图标。
- 主角的布衣、皮甲、链甲与混搭由 3D 模型按槽换装，在离屏画布里从侧面渲染（`scripts/cutout_hero.gd`、`scripts/model_hero.gd`）。兵器是 3D 零件（`art/model-hero/weapons.glb`，由 `gen-out/model/scripts/build_weapons.py` 生成），按锻造结果挑刃形、护手、柄首、枪头、弓臂并上色，挂在手骨上、四指握拳攥住：剑握在右手，长枪右手握，弓在左手。装备格里的兵器图标仍用原来的 2D 零件图（`scripts/held_weapon.gd`）。
- 第一地域采用 `mountain-road.png` 手绘场景，藤精采用 `vine-spirit.png` 十二帧图集。其他地域长卷和三类怪物仍保留原素材，未冒充完成全游戏美术替换。

## 素材制作与复现

图片通过内置 ImageGen 生成；提示词记录在 `generation-prompts.json`。

`pack_character.gd` 只执行确定性的图集切分、坐标归一化与遮罩打包（原来用于拆件人物）。

```sh
godot --path mobile --resolution 1280x900 --fixed-fps 30 --script res://tests/ink_preview_movie.gd -- <帧目录>
ffmpeg -framerate 30 -i <帧目录>/%05d.jpg -c:v libx264 -crf 19 -pix_fmt yuv420p -movflags +faststart preview.mp4
```
