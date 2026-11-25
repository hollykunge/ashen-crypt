# 按槽换装部件（短打 / 皮甲 / 链甲）

所有 GLB 都在同一个坐标系里（短打 peasant-3 的原始坐标）：Blender Z 朝上，角色面朝 +X，脚底 z = -0.5，身高约 1。
同一槽位的不同套装可以直接互换，不用再挪位置。

## 来源资产（Tripo）

| 套装 | 原模型 | 拆分任务 → 拆分后模型 |
|---|---|---|
| 短打 peasant-3 | `01a212de-22d6-756d-bcfb-4fbc31670154` | `01a21313-e7da-…` → `01a21314-a877-740e-ae9f-19a3fadbf7e8` |
| 皮甲 leather-2 | `01a212de-40ec-78bb-8466-d22adb77a5d8` | `01a2132b-8938-…` → `01a2132c-bd9c-72db-8c22-0d321c1602a5` |
| 链甲 chain-2 | `01a212dd-c4fb-79e8-8ad4-501b80d4cc43` | `01a2132b-8be2-…` → `01a2132c-c55a-7b25-9c08-ce7b4773c250` |
| 光身体 | 文生 `01a2131d-55ce-…` → `01a21320-faba-7b26-b898-2e42655c361c` | — |

## 文件

- `slots/`：短打的槽位，本身就是基准坐标。
- `leather-2/slots_aligned/`、`chain-2/slots_aligned/`：已对齐到短打坐标的槽位，混搭用这两个目录。`slots/` 是未对齐的原始切分。
- `base_body/base_body.glb`：打底身体（无头、无手臂），已按三套衣服的最内层收缩，三套随便穿都不穿模。
  `base_body_peasant_only.glb` 是只按短打收缩的旧版（更壮）。`suit_check.jpg` 是旧版的检查图。
- `mix_check.jpg`：混搭效果检查图。
- `scripts/`：切分、对齐、收缩、渲染脚本，以及各套的配置。

## 槽位与显示规则

| 槽位 | 短打 | 皮甲 | 链甲 |
|---|---|---|---|
| 头盔 helmet | `hair_topknot`（发髻） | `helmet` | `helmet`（含红缨、链甲护颈） |
| 上衣 top | `top`（坎肩＋衣摆） | `top`（胸甲＋护肩＋甲裙） | `top`（链甲衫＋护肩＋上半截袖子＋甲裙） |
| 腰带 belt | `belt` | `belt` | `belt` |
| 裤子 pants | `pants`（只有衣摆下露出的部分） | `pants`（含袍片） | `pants` |
| 靴子 boot_R / boot_L | ✓ | ✓ | ✓ |
| 手臂 arm_R / arm_L | `body_arm_*` ＋ `bracer_*` | `arm_*`（整条袖子＋护腕＋手） | `arm_*`（只有前臂护腕＋手） |

始终显示：`base_body`，以及短打的 `body_head`。皮甲、链甲的 `head` 是从头盔里切出来的脸，混搭时不用。

规则（与 `scripts/mix.py` 一致）：
- 手臂槽选短打时，显示 `body_arm_*` 和 `bracer_*`；选皮甲或链甲时，隐藏短打的 `body_arm_*`。
- 链甲手臂只有前臂。如果上衣不是链甲，要同时显示短打的 `body_arm_*` 来补上臂。
- 戴任何头盔时，隐藏 `hair_topknot`。

## 绑骨（`rigged/`）

所有部件都蒙皮到同一副骨架上。这副骨架来自 `tripo-dark-hero/duanda_rigged.blend`，就是项目里 `build_tripo_hero.py` 做的短打骨架：`Rig` 有 67 根骨骼，12 个动作。那个文件只读，没改动。

- `rigged/outfits_rigged.glb`：给 Godot 用。包含 `Rig`、28 个蒙皮部件、12 个动作，T 字静止姿势。导出参数和 `export_godot.py` 相同。
  部件名格式是 `套装__槽位`，套装取 `peasant3`、`leather2`、`chain2` 或 `body`，例如 `chain2__helmet`、`body__base_body`。显示规则同上。
- `rigged/outfits_rigged.blend`：上面那个文件的 Blender 工程。
- `rigged/anim_check.jpg`：五种组合，每种是 T 字静止姿势加 6 个动作帧。

做法（`scripts/rig_parts.py`）：
1. 用原模型的 A 字顶点和 `Duanda_Body` 的 T 字顶点、权重，最小二乘反推每根骨骼"T 字到 A 字"的变换。残差是 0，说明顶点一一对应。
2. 每个部件的顶点从 A 字姿势的身体网格上就近插值权重，并按槽位限制可用骨骼：
   - 手臂：全部骨骼；
   - 上衣、打底身体：不用前臂和手；
   - 其余槽位：不用任何手臂骨；
   - 头盔、发髻：整块绑 `Head`。

   另外，上衣和裤子在髋部以下的顶点，会把骨盆、左右大腿、左右小腿的权重沿网格平滑扩散 15 轮，减轻跨步时衣摆被扯出的尖角。平滑前先按位置合并 UV 缝两侧的重复顶点，保证它们权重一致，不会裂开。改前改后的对比见 `rigged/skirt_weights_before_after.jpg`。
3. 对每个顶点求混合骨骼变换的逆矩阵，把部件从 A 字搬到 T 字。

## 已知限制

- 衣摆、甲裙仍然靠腿骨带动，两腿之间的布会被拉伸。平滑权重后尖角少了，但皮甲小跑时两腿间的袍片还有少量锯齿。要根除得给衣摆加骨骼。
- 链甲护颈是头盔的一部分，整块跟着头转。极端转头时可能和护肩穿插。
- 脸和头盔的切分：皮甲的额箍颜色和肤色太接近，所以皮甲的脸只取眉线以下、正面中间的区域，被脸包住的胡子、眉毛也归给脸（`scripts/cfg_leather.json` 里的 `face` 参数）。修正后，皮甲的整体缩放从 0.974 改成 1.013，和按领口高度估的结果一致。
- 短打的裤子只有衣摆下面那一截。配短甲裙时，大腿上部露出的是身体的皮肤和短裤。
- 身体的膝盖、肩口切边处还有些棱角。手腕桥接的那段是单一肤色。

## 接入游戏（mobile/）

接在合并了 PR #5（hero-art-lock）之后的 main 上。

- `rigged/outfits_rigged.glb` 复制为 `mobile/art/model-hero/hero_tripo.glb`。Godot 导入时会把 35 张贴图解到同目录，文件名以 `hero_tripo_` 开头。
- `scripts/model_hero.gd`：
  - `ModelHero.new("tripo")` 加载 Tripo 分槽男主角。它沿用女主角那套 `slots`、`head_parts` 的切换方式，槽位表是 `TRIPO_SLOTS`。
  - 链甲护臂配非链甲上衣时，补上短打的光胳膊。
  - 跳过 `BodyShape` 推形：形变场是按 hero.glb 的身材量的，Tripo 模型比例不同。
  - 染色跳过皮肤。
  - 主角被释放时，顺手释放还没挂上的兵器零件。
- `scripts/cutout_hero.gd`：`MODEL_OF := {"male": "tripo"}`，战场和行装页的男主角改用 Tripo 模型。女主角，以及图标渲染等直接 new 的 `ModelHero` 都不变。
- `tests/run_tests.gd`：男主角的断言改成检查 Tripo 部件，原来男模型的发髻、兜帽、靴子断言改为直接测 `ModelHero.new()`。

装真机：
1. 把 `mobile/export_presets.cfg` 放进工作树（它被 git 忽略）。
2. `godot --headless --path mobile --export-release "iOS" <目录>/ashencrypt.ipa`，导出的是 Xcode 工程。
3. 把工程里的 `CODE_SIGN_IDENTITY = "Apple Distribution"` 改成 `"Apple Development"`。
4. `xcodebuild ... -configuration Release -allowProvisioningUpdates build`，签名编译。
5. `xcrun devicectl device install app --device <UDID> <app>`，安装。
