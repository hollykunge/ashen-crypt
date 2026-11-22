# 皮影小样

主角的皮影模型在 `swordsman/`。山魈小样在 `shanxiao/`。

| 文件 | 用途 |
| --- | --- |
| `<角色>/rig.json` | 部件接点、缩放、各动作参数和劈砍关键帧 |
| `<角色>/demo.json` | 演示中的外观及混搭组合 |
| `cutout_rig.gd` | 拼接部件，通过腿部 IK 和弹簧播放动作 |
| `cut.py` | 按连通块切件，可将护甲件对齐到基础轮廓 |
| `demo.tscn` | 并排预览整套装备与混搭 |
| `render.sh <角色> <目录>` | 渲染 MP4 和 GIF |

## 调参和换装

在仓库根目录运行。

    mobile/prototype/cutout/tune.sh
    mobile/prototype/cutout/tune.sh shanxiao

动作下拉框切换跑步、走路、待机、备战、劈砍和站直。「播放速度」可以放慢全程。「站直」按人物身高画十六格，方便检查比例。

护甲、护手、裤子、鞋子可以独立选布衣、皮甲和链甲。布衣部件在 `parts/`，皮甲在 `set-leather/`，链甲在 `set-mail/`。护甲管躯干和上臂，护手管前臂，裤子管臀胯、大腿和靴口以上，鞋子管靴口以下。衣装拆件模板在 `swordsman/source/outfit-template.png`。

「保存」把调过的参数写进 `rig.json`。首次保存会备份到 `rig.json.bak`。「撤销改动」恢复上次保存的数值。

「劈砍关键帧」可以选起手、挥下、打中和收势。勾选「定格在这一帧」后，可以直接检查关节角度、重心和脚位。「打中」和后面的停顿帧共用姿势。

## 战斗

玩家角色和随侍共用刀客骨骼。行走和冲刺的步态按走过的距离推进。劈砍、持枪和拉弦跟随各自的战斗动作，出手对准伤害和箭矢结算。护甲同时决定裤子样式，护腕和靴子独立换装。战场将离屏画布绘制在角色脚下，也用同一画布绘制残影。

项目目录直接读 PNG，导出包读 Godot 导入的纹理。两条路径都生成多级渐远。外观目录可通过 `outfit.json` 的 `margin` 修正留白。

## 检查

- 比较站姿和侧面参考。运行 `python3 mobile/prototype/cutout/compare.py swordsman <侧面参考图> <输出.png>`。
- 检查骨骼跳转。运行 `godot --headless --path mobile --fixed-fps 30 --script res://prototype/cutout/spin_check.gd -- swordsman`。
- 在战斗中截取动作。运行 `godot --path mobile --resolution 780x1688 --script res://tests/_cutout_battle.gd -- <目录> [张数] [间隔帧] [route]`。
