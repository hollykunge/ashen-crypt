# 月夜皮影角色

斗笠少年位于 `piying/`，鬼面女将位于 `nvjiang/`。两套角色各自在 `parts/` 保存透明部件，`rig.json` 保存关节、层级和动作参数。每套 `source/` 中的 `parts-2.png` 是选用的原稿，`style_ref.png` 是风格参考。

从仓库根目录运行以下命令可查看动作或打开调参面板。将末尾的 `piying` 改为 `nvjiang` 即可查看女将。

```sh
godot --path mobile res://prototype/cutout/demo.tscn -- piying
godot --path mobile res://prototype/cutout/tuner.tscn -- piying
```

战斗与行装通过 `scripts/puppet_hero.gd` 加载同一套骨骼。精怪和月夜布景的原稿分别保存在 `monsters/source/` 和 `stage/source/`。
