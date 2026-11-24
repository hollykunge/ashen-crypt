# 角色模型：共用骨架 + 四套可换装衣服

`ashen_char_3outfits.blend` 最初是用 Blender 4.5 LTS 存的，修肩甲后用 Blender 5.3 重新存过。`render_lib.py` 两个版本的渲染引擎名都认：4.x 叫 EEVEE Next，5.x 又改回了 EEVEE。贴图放在旁边的 `textures/` 里，用相对路径 `//textures/...` 引用，所以整个 `model/` 文件夹拷到哪台电脑上都能直接打开。打开时已经设好了侧面正交相机 `SideCam`、主光 `Key` 和世界光，直接按 F12 就能渲染。

素材来自 Quaternius 的三套资源，全部是 CC0：Modular Character Outfits – Fantasy、Universal Base Characters、Universal Animation Library。

## 场景里有什么

- **骨架：** `Rig`，65 根骨骼，UE 风格命名（`pelvis`、`spine_01`、`upperarm_l` 等）。默认挂着 `Sprint_Loop`，场景帧率 24fps。
  - 角色朝 -Y 方向，左侧骨骼在 +X，相机放在 -X 方向。
- **动作（12 个，原地不位移）：** 都存在文件里（fake user），在 Action 编辑器里切换，或者用 `split_and_render.py` 的第 5 个参数指定。对照图见 `actions_check.jpg`（皮甲全套，每个动作取 6 帧）。

| 动作 | 帧 | 用途 |
|---|---|---|
| `Idle_Loop` | 0–60 | 待机 |
| `Walk_Loop` | 0–32 | 走路 |
| `Jog_Fwd_Loop` | 0–22 | 慢跑 |
| `Sprint_Loop` | 0–16 | 冲刺 |
| `Sword_Idle` | 0–40 | 持兵器戒备 |
| `Sword_Attack` | 0–37 | 挥砍，单次 |
| `Hit_Chest` / `Hit_Head` | 0–8 / 0–10 | 受击（胸 / 头），单次 |
| `Death01` | 0–58 | 向后倒地，单次 |
| `Roll` | 0–35 | 前滚翻，单次 |
| `Punch_Cross` | 0–24 | 右手直拳，游戏里当长枪双手前刺 |
| `Spell_Simple_Shoot` | 0–12 | 左手前伸，游戏里当拉弓撒放和施法 |

  - 动作来自 Universal Animation Library v3.0 免费版（quaternius.itch.io/universal-animation-library，`Universal Animation Library[Standard].zip`，用的是不带根运动的 `Unreal-Godot/UAL1_Standard.glb`），由 `scripts/add_actions.py` 重定向到 `Rig` 上。
  - 不能直接套用原关键帧：两边骨骼同名，但 Blender 导入后有些骨骼的静止朝向不一样（`spine_03` 差 11°，脖子差 6°，拇指和脚也有偏差），我们的腿也比动作库的人体模型长约 5 cm。所以是逐帧把每根骨骼相对静止姿势的转角搬过来，位置按我们自己的骨长算，骨盆位移按骨盆高度比例（1.035）缩放。
  - 兵器是单独的 3D 零件（`scripts/build_weapons.py` → `mobile/art/model-hero/weapons.glb`）：剑三种刃（素、七星、波浪）、四种护手、四种柄首和穗子，长枪三种枪头（柳叶、蛇矛、戟）带红缨，弓两种（长弓、反曲）。零件按锻造结果挑，按用途上色。游戏里挂在手骨上，四指握拳攥住（`mobile/scripts/model_hero.gd` 的 `hold`）。
  - 加动作：把名字加进 `add_actions.py` 的 `WANT` 列表，然后重跑，已有的同名动作会被替换。
- **所有部件：** 都绑定在 `Rig` 上，用 Armature 修改器。

| 槽位 | 农夫 peasant | 游侠 ranger | 皮甲 leather（自制） | 链甲 chain（自制） |
|---|---|---|---|---|
| 头（所有衣服共用） | `Head_Skin` `Head_Eyes` `Head_Eyebrows` `Head_Hair_Main` `Head_Hair_Beard` | 同左 | 同左 | 同左 |
| 上衣 torso | `Male_Peasant_Body` | `Male_Ranger_Body` + `_Belt_1/2` | `Leather_Body` + `Leather_Belt_1/2` | `Chain_Body` + `Chain_Belt_1/2` |
| 手臂 arms | `Male_Peasant_Arms` | `Male_Ranger_Arms` | `Leather_Arms` + `Leather_Bracer` | `Chain_Arms` + `Chain_Bracer` |
| 裤子 legs | `Male_Peasant_Legs` | `Male_Ranger_Legs` | `Leather_Legs` + `Leather_ThighGuard` | `Chain_Legs` |
| 鞋 feet | `Male_Peasant_Feet` | `Male_Ranger_Feet_Boots` | `Leather_Boots` | `Chain_Boots` |
| 肩甲 shoulder | 无 | `Male_Ranger_Acc_Pauldron`（只有左肩） | `Leather_Pauldron_L/R` | `Chain_Pauldron_L/R` |
| 兜帽 hood | 无 | `Male_Ranger_Head_Hood`（戴兜帽时隐藏 `Head_Hair_Main`） | 无 | 无 |

## 皮甲套装是怎么做的（`scripts/build_leather.py`）

- `Leather_Body`：复制了游侠上衣的网格，用程序化材质做出暗红甲片：交错的甲片行、每行下缘压暗、黄铜铆钉。纹理用 Generated 坐标，也就是静止姿势下的坐标，所以贴在身上，跑动时不会游动。
- `Leather_Arms`、`Leather_Legs`、`Leather_Boots`、`Leather_Belt_*`：复制了游侠对应部件，按原贴图的亮度重新上色，保留了原来的纹理细节。靴子和腰带上的金属扣，用饱和度做遮罩保留了原色。
- `Leather_Bracer`：用的是游侠护腕。它只在完整套装文件里有，模块化部件里没有，重新上成红色。
- `Leather_Pauldron_L`：游侠肩甲换成红皮材质。`_R` 是它的镜像复制，同时把 `_l` 和 `_r` 的顶点组对调了。
- `Leather_ThighGuard`（新建）：从裤子表面切出大腿外侧和前侧的面，沿法线往外推 1.6 cm，再用 Solidify 加 8 mm 厚度。

## 链甲套装是怎么做的（`scripts/build_chain.py`）

做法和皮甲一样，都是从现有部件复制再换材质。脚本可以重复跑，会先删掉旧的 `Chain_*` 再重建。游戏里的「链甲」就是这一套。

- `Chain_Body`、`Chain_Arms`（只换袖子，皮肤不动）、`Chain_Legs`：分别复制游侠的上衣、手臂、裤子，换成程序化锁子甲。环间距 1.6 cm，每行错开半个环，环的上半圈亮一点，环与环之间压暗。和皮甲一样用 Generated 坐标（按网格尺寸换算成米），所以跑动时花纹贴在身上不游动。
- `Chain_Bracer`、`Chain_Pauldron_L/R`：复制皮甲的护腕和肩甲（肩甲已经过 `fit_pauldrons.py` 调整，权重也一起带过来），换成钢板材质。
- `Chain_Belt_1/2`、`Chain_Boots`：复制游侠的腰带和靴子，按亮度重新上成深色皮革，金属扣保留原色。
- 颜色比 Blender 出图时调亮了一档：Godot 里的卡通光照会把它压暗，原来那档在游戏里看是深石板色。

## 已知问题，回家可以接着改的

1. **肩甲穿模（已修，2026-11-24）：** 已用 `scripts/fit_pauldrons.py` 修好并存进 .blend，对照图见 `pauldron_fit_check.jpg`（五种搭配 × 侧面两帧 + 前后特写）。做法分三步：
   - 三块肩甲（皮甲左右、游侠左）各自整体往外上方挪 1.8 cm，形状、大小不变。这样就盖住了游侠/皮甲上衣和所有袖子。
   - 农夫上衣的袖山是方的，比肩甲外缘高 3 cm。为了它把肩甲再抬高，穿别的上衣时肩甲就悬空了，所以改成把农夫上衣肩头压到肩甲下面，最多压 2.6 cm，往四周平滑过渡。不穿肩甲时，农夫的肩峰会稍低一点，侧面看不出来。
   - 改了蒙皮权重：肩甲上沿 60% 跟锁骨走，往下渐变到下沿 100% 跟上臂走。原来肩甲整块跟上臂走，挥砍时手臂抬过头，肩甲会跟着翻起来，像鱼鳍一样竖在肩上。
   - 10 个动作逐帧量过：走、跑、待机、受击时，上衣和袖子都不穿出肩甲。只有游侠上衣有 0.3–0.7 cm 的轻微擦边，看不出来。挥砍、倒地、翻滚时手臂姿势很极端，测量分不清是穿模还是别的身体部位挡在肩甲前面，所以挥砍是看特写图确认的，手臂抬起时肩甲贴在肩上。
   - 脚本可以重复跑，第二次跑不会再改动任何东西。
2. **兜帽和肩甲（按设计保留）：** 兜帽披肩盖在肩甲内侧边缘上，看起来像斗篷披在甲外，这样是对的。要把肩甲抬到披肩上面得抬 6 cm，太夸张，所以没动。
3. **原始材质：** 头发在原始材质下是灰白色。V4 画风（三阶卡通着色、#3a2c22 描边、主光加背后轮廓光、暗土配色、深棕头发）是渲染时由 `scripts/style_lib.py` 套上去的，模型文件里存的还是原始材质。
4. **发型：** 素材包里没有顶髻。`Hair_Buns` 是两侧的发包，头顶是秃的，所以没用。
5. **靴子：** 皮甲靴还是游侠靴的形状，带搭扣，不是原画那种前面系带的长靴。

## 怎么重新出图

```powershell
# 出可换装图层 + 3D 参考图（V4 画风，2 倍渲染；第 4 个参数是随机混搭的数量，第 5 个是动作名，不写就用 Sprint_Loop）
blender -b gen-out/model/ashen_char_3outfits.blend -P gen-out/model/scripts/split_and_render.py -- out_dir 0,2,4,6,8,10,12,14 toon+outline+light+paint 60 Sprint_Loop
```

注意：现在每个动作的相机构图是分开算的。如果游戏里要几个动作同屏切换，需要先统一相机，否则人物在不同动作之间会忽大忽小。倒地和翻滚的动作幅度大，会把构图撑得很大。

渲染完以后：

1. 把 `out_dir/layers` 和 `out_dir/truth3d` 里的图缩小到 480×832，缩的时候用预乘 alpha（Pillow 里先转成 `RGBa` 再 resize）。
2. 跑 `compose.py out_dir out_dir_eval`：搜叠层顺序，并对比 2D 叠层和 3D 直出。
3. 跑 `pack.py` 打包。

## 导出给游戏（Godot）

游戏里的主角就是这个模型，实时渲染（`mobile/scripts/model_hero.gd`、`mobile/scripts/cutout_hero.gd`）。改了模型以后重新导出：

```powershell
# 烘焙每个材质的底色贴图（皮甲那些节点材质 glTF 带不过去），导出骨架、全部部件和动作
blender -b gen-out/model/ashen_char_3outfits.blend -P gen-out/model/scripts/export_godot.py -- mobile/art/model-hero/hero.glb 1024
# 主角头像（侧面半身像，230×300，透明底）
blender -b gen-out/model/ashen_char_3outfits.blend -P gen-out/model/scripts/render_portrait.py -- mobile/art/model-hero/portrait.png
```

导出只在内存里改材质，不会改动 .blend。Godot 导入 glTF 时会把动作名结尾的 `_Loop` 去掉，`model_hero.gd` 的 `anim_name()` 会处理这个。

`build_scene.py` 和 `build_leather.py` 是从 Quaternius 原始文件一步步搭场景的脚本，里面写死了路径 `D:\quaternius\...`。如果只是在这个 .blend 上继续改，用不到它们。

之前用这个模型出的图（三套衣服的分层图层、画风对比等）已经从分支里删掉了，需要的话可以从提交 `ec92450` 里找回。当时的结论：67 种搭配 × 8 帧，2D 叠层和 3D 直出的轮廓 IoU 是 0.9999，颜色不一致的像素平均 0.86%。
