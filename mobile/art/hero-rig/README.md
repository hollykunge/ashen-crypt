# 刀客拆件人物

男刀客在战场、随侍和行装页用的骨骼人物。脚本是 [hero_puppet.gd](../../scripts/hero_puppet.gd)，骨骼和动作沿用 [cutout_rig.gd](../../prototype/cutout/cutout_rig.gd)。

## 做法

所有部件都从一张全身侧面基准原画里切出来，统一用一个缩放。接点就是原画上的关节中心。部件不需要逐件对位，也不需要单独缩放。

1. **基准原画**：`source/base/master.png`。人物严格侧面朝右、立正并脚，远侧手脚藏在身后，近侧手臂自然下垂。
2. **分层**：同一张图再生成两张。`armless.png` 去掉手臂并把躯干补全，`arm.png` 只留手臂。头、躯干、臀胯和腿从前一张切，上臂、前臂和手从后一张切。
3. **关节**：在 `source/joints.json` 里写关节中心（基准图像素坐标）。每个关节沿骨骼的垂线切开。
   - 压在前面的那件沿画好的边切，例如短裤腰头、腰带和鞋口。
   - 垫在后面的那件带一个以关节为圆心的圆头。
   - 没有现成边的地方（光身的肘、膝、踝）两边都带圆头。
4. **衣装**：布衣、皮甲、链甲各自在基准图上"换衣服"，姿势和位置不变，再按同一套接点切开。接点所有套装共用，所以混搭时按装备槽整件替换贴图就行：

   | 装备槽 | 部件 |
   |---|---|
   | 上衣 | 躯干、上臂、臀胯、裆 |
   | 护腕 | 前臂、手 |
   | 护腿 | 大腿、小腿 |
   | 靴子 | 脚 |

5. **远侧手脚**：复用近侧贴图，压暗并错开一点做纵深。

## 重新生成

在 `mobile` 目录下运行：

```sh
godot --headless --path . --script res://art/hero-rig/build.gd -- base
godot --headless --path . --script res://art/hero-rig/build.gd -- cloth
godot --headless --path . --script res://art/hero-rig/build.gd -- leather
godot --headless --path . --script res://art/hero-rig/build.gd -- chain
godot --headless --path . --import
```

- `base` 会把量出的接点和 `source/motion.json` 合成 `rig.json`。
- 动作参数改 `source/motion.json`，不要直接改 `rig.json`。
- 量坐标用 `grid.gd`，它把原画裁一块、放大并画格子：

  ```sh
  godot --headless --path . --script res://art/hero-rig/grid.gd -- <图> <输出> x y w h 倍数 [点x,点y ...]
  ```

### 原画怎么出

原画都由 Codex 自带的生图工具生成。

- `master`：以 `art/reference-hero/source/standing-views/side.png` 为参考出基准图。衣装的 `master` 是在基准图上编辑出来的。
- `armless`、`arm`：都在各自的 `master` 上编辑。去手臂时要求"其余像素保持不变"，只留手臂时要求"其余擦成纯白"。
- 衣装的手臂如果出来大小不对，就在基准的 `arm.png` 上加袖子和护腕。布衣就是这样做的。
- 提示词里不要写刀、剑这些字，会被安全审核拦下。握拳那张用的是"握一根扫帚柄"。

新衣装必须守这几条，否则切不干净：
- 下摆不过大腿根；
- 袖口在肘上；
- 鞋口在踝下；
- 衣服贴身，不往外飘。

## 检查

```sh
godot --path . --script res://tests/hero_rig_check.gd -- <截图目录>
```

检查会让每套衣装摆遍所有动作帧，画在品红底上，找被人物围住的细缝并逐帧列出。

列出来的不一定都是接缝，需要放大截图看。两腿交叉、手臂贴着下巴围出来的空当，属于姿势本身的负形；1～4 像素的点是抗锯齿边。
