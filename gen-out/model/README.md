# 角色模型：共用骨架 + 三套可换装衣服

`ashen_char_3outfits.blend` 是用 Blender 4.5 LTS 存的。贴图放在旁边的 `textures/` 里，用相对路径 `//textures/...` 引用，所以整个 `model/` 文件夹拷到哪台电脑上都能直接打开。打开时已经设好了侧面正交相机 `SideCam`、主光 `Key` 和世界光，直接按 F12 就能渲染。

素材来自 Quaternius 的三套资源，全部是 CC0：Modular Character Outfits – Fantasy、Universal Base Characters、Universal Animation Library。

## 场景里有什么

- **骨架：** `Rig`，65 根骨骼，UE 风格命名（`pelvis`、`spine_01`、`upperarm_l` 等），挂着动作 `Sprint_Loop`，共 16 帧，24fps。
  - 角色朝 -Y 方向，左侧骨骼在 +X，相机放在 -X 方向。
- **所有部件：** 都绑定在 `Rig` 上，用 Armature 修改器。

| 槽位 | 农夫 peasant | 游侠 ranger | 皮甲 leather（自制） |
|---|---|---|---|
| 头（所有衣服共用） | `Head_Skin` `Head_Eyes` `Head_Eyebrows` `Head_Hair_Main` `Head_Hair_Beard` | 同左 | 同左 |
| 上衣 torso | `Male_Peasant_Body` | `Male_Ranger_Body` + `_Belt_1/2` | `Leather_Body` + `Leather_Belt_1/2` |
| 手臂 arms | `Male_Peasant_Arms` | `Male_Ranger_Arms` | `Leather_Arms` + `Leather_Bracer` |
| 裤子 legs | `Male_Peasant_Legs` | `Male_Ranger_Legs` | `Leather_Legs` + `Leather_ThighGuard` |
| 鞋 feet | `Male_Peasant_Feet` | `Male_Ranger_Feet_Boots` | `Leather_Boots` |
| 肩甲 shoulder | 无 | `Male_Ranger_Acc_Pauldron`（只有左肩） | `Leather_Pauldron_L/R` |
| 兜帽 hood | 无 | `Male_Ranger_Head_Hood`（戴兜帽时隐藏 `Head_Hair_Main`） | 无 |

## 皮甲套装是怎么做的（`scripts/build_leather.py`）

- `Leather_Body`：复制了游侠上衣的网格，用程序化材质做出暗红甲片：交错的甲片行、每行下缘压暗、黄铜铆钉。纹理用 Generated 坐标，也就是静止姿势下的坐标，所以贴在身上，跑动时不会游动。
- `Leather_Arms`、`Leather_Legs`、`Leather_Boots`、`Leather_Belt_*`：复制了游侠对应部件，按原贴图的亮度重新上色，保留了原来的纹理细节。靴子和腰带上的金属扣，用饱和度做遮罩保留了原色。
- `Leather_Bracer`：用的是游侠护腕。它只在完整套装文件里有，模块化部件里没有，重新上成红色。
- `Leather_Pauldron_L`：游侠肩甲换成红皮材质。`_R` 是它的镜像复制，同时把 `_l` 和 `_r` 的顶点组对调了。
- `Leather_ThighGuard`（新建）：从裤子表面切出大腿外侧和前侧的面，沿法线往外推 1.6 cm，再用 Solidify 加 8 mm 厚度。

## 已知问题，回家可以接着改的

1. **肩甲穿模：** 皮甲肩甲和游侠自带的肩甲，跟农夫上衣（肩部比较高）、游侠兜帽（披肩盖在肩上）一起穿时会穿模，最深约 4.8 cm。
   - `scripts/fit_pauldrons.py` 能自动搜出一个不穿模的放大量加外推量，但搜出来的结果是放大 18%、往外推 4.8 cm，预计会显得太大，我还没在画面上验证过，所以这个文件里没有应用。
   - 手动改的话，更好的办法可能是把肩甲往肩膀外侧挪、整体做小，或者让兜帽披肩在肩部收窄一点。
2. **游侠兜帽本身也和游侠肩甲穿模：** 这是素材包里原有的问题。
3. **原始材质：** 头发在原始材质下是灰白色。V4 画风（三阶卡通着色、#3a2c22 描边、主光加背后轮廓光、暗土配色、深棕头发）是渲染时由 `scripts/style_lib.py` 套上去的，模型文件里存的还是原始材质。
4. **发型：** 素材包里没有顶髻。`Hair_Buns` 是两侧的发包，头顶是秃的，所以没用。
5. **靴子：** 皮甲靴还是游侠靴的形状，带搭扣，不是原画那种前面系带的长靴。

## 怎么重新出图

```powershell
# 出可换装图层 + 3D 参考图（V4 画风，2 倍渲染；最后一个参数是随机混搭的数量）
blender -b gen-out/model/ashen_char_3outfits.blend -P gen-out/model/scripts/split_and_render.py -- out_dir 0,2,4,6,8,10,12,14 toon+outline+light+paint 60
```

渲染完以后：

1. 把 `out_dir/layers` 和 `out_dir/truth3d` 里的图缩小到 480×832，缩的时候用预乘 alpha（Pillow 里先转成 `RGBa` 再 resize）。
2. 跑 `compose.py out_dir out_dir_eval`：搜叠层顺序，并对比 2D 叠层和 3D 直出。
3. 跑 `pack.py` 打包。

`build_scene.py` 和 `build_leather.py` 是从 Quaternius 原始文件一步步搭场景的脚本，里面写死了路径 `D:\quaternius\...`。如果只是在这个 .blend 上继续改，用不到它们。

之前用这个模型出的图（三套衣服的分层图层、画风对比等）已经从分支里删掉了，需要的话可以从提交 `ec92450` 里找回。当时的结论：67 种搭配 × 8 帧，2D 叠层和 3D 直出的轮廓 IoU 是 0.9999，颜色不一致的像素平均 0.86%。
