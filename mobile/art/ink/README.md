# 手绘界面与场景预览

这套素材采用简化手绘、墨线轮廓和纸本配色。刀客已改为直接保留原图关键姿势的完整人物帧，详见 [原图刀客](../reference-hero/README.md)。本目录的拆件人物只继续用于尚待重绘的长枪和弓。

## 查看

从游戏标题页点「手绘试演 · 动作与换装」，或运行仓库根目录的 `preview-ink.ps1`。

试演直接使用游戏的角色、装备推导和战场渲染。可整套切换布衣、皮甲和链甲，也可点上衣、护腕、护腿和靴子逐件切换。刀客新增站姿、备战和斩击定格三个原图对照。动作包括走、跑、攻击、后撤、受击、技能。「实战」恢复真实挂机战斗，「行装」进入实际背包并支持试穿。长枪、弓可查看上一版拆件表现，按钮已标注待重绘。

试演每次建立独立临时角色，退出场景后清理；不读取或覆盖三个正常角色位。

## 已接入范围

- 标题、选角、创角、战斗、行装、炉坊使用统一纸色面板、深墨文字、朱红强调与墨线图标。
- 刀客的布衣、皮甲、链甲与混搭使用 `art/reference-hero` 的完整人物帧，原参考中的披肩、发髻、脸型与肢体比例不再受旧骨骼拆件限制。
- `hero/parts`、`hero/set-leather`、`hero/set-mail` 与 `hero/rig.json` 保留枪弓的上一版拆件、IK 与动作时间轴。
- 武器逻辑仍沿用原剑、枪、弓规则；刀客整帧中的弯刀直接跟随手部画稿。
- 第一地域采用 `mountain-road.png` 手绘场景，藤精采用 `vine-spirit.png` 十二帧图集。其他地域长卷和三类怪物仍保留原素材，未冒充完成全游戏美术替换。

## 素材制作与复现

图片通过内置 ImageGen 生成；提示词记录在 `generation-prompts.json`。`hero/source` 保留生成原图和空间参考，原写实人物保存在原目录。

`pack_character.gd` 只执行确定性的图集切分、坐标归一化与遮罩打包：以 alpha > 0.25 的有效轮廓定位，保留原关节点尺寸，小腿与脚部按原分界拆开，衣装不包含会改变人物身份的头部和手部。

```sh
godot --headless --path mobile --script res://art/ink/pack_character.gd -- pack <cloth-atlas.png> <hero/parts>
godot --headless --path mobile --script res://art/ink/pack_character.gd -- pack <leather-atlas.png> <hero/set-leather>
godot --headless --path mobile --script res://art/ink/pack_character.gd -- pack <chain-atlas.png> <hero/set-mail>
godot --headless --path mobile --script res://tests/ink_preview_check.gd
godot --path mobile --resolution 1440x1000 --fixed-fps 30 --script res://tests/ink_preview_check.gd -- <截图目录>
godot --path mobile --resolution 1280x900 --fixed-fps 30 --script res://tests/ink_preview_movie.gd -- <帧目录>
ffmpeg -framerate 30 -i <帧目录>/%05d.jpg -c:v libx264 -crf 19 -pix_fmt yuv420p -movflags +faststart preview.mp4
```
