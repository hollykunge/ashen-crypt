# 余烬地牢 · Ashen Crypt

**主角美术已定稿：** 主角是 3D 角色模型，游戏里实时渲染成侧面，布衣、皮甲、链甲按槽混搭，剑、长枪、弓是 3D 零件握在手里。以后只在这套上修和加，不再换路线，规矩见 [主角美术定稿](mobile/art/model-hero/README.md)。调试版标题页有「试演 · 动作与换装」，Windows 也可运行 `preview-ink.ps1`，见 [界面与场景预览](mobile/art/ink/README.md)。

《余烬地牢》是一款中国神仙题材的 2D 动作游戏。玩家在列仙图录中选择二郎神、九天玄女、后羿、青鸟仙子、雷部天师或电母，领取土地公的敕令，守住昆仑山门。五道敕令沿用五波战斗，最后一关需要降伏镇山兽。Godot 版可以用掉落的材料在兜率炉坊打造武器、护腕、靴子、上衣和护腿。


## 设计文档

**主角是个凡人，看见人间疾苦，为救万民而求仙；成了仙才知道人间的苦正是仙界做的，于是屠仙。** 第一幕是成仙之路（1–50 层），待诏期（51–60 层）揭开真相，第二幕是屠仙（61 层起）。**现在做第一幕，第二幕的接口在[叙事主线](docs/story.md)里留好。**

**没有年龄、阳寿、家人时间线，也没有大运流年。** 层数就是层数，世界的轮转由**地气**管，十层走满一遍天干。

**材料、属性、工艺、格局的名字一律用白话** —— 生铁、铁屑、火砂、冰核、抗打断、免伤、转阳、均衡格。五行与阴阳靠 UI 角标讲，不靠认字（[命名铁律](docs/wuxing-world.md#12-材料表)）。

角色、装备、精怪和山门各层共用一套阴阳五行。规则由策划定义，具体装备由玩家自己组合出来。

- [阴阳五行世界模型](docs/wuxing-world.md)：五行生克、十天干、旺相休囚死、精怪生成与地气轮转。
- [规则锻造系统设计](docs/crafting-rules.md)：功率预算守恒、生克结算、境遇与契合、形制矩阵、触发语法与格局。
- [命格](docs/bazi-destiny.md)：没有职业，只有命主、生月与生辰排出的命格；十神决定什么装备适合你，本层地气决定这一层怎么打。
- [出身与灵砂](docs/origins.md)：官宦、富商、普通人、穷人各有两优两劣；官宦的随侍数随本层地气在 0~3 之间变化。
- [成仙主线](docs/ascension.md)：六十层走完五境界，五道天劫对应五行，五条规矩逐条拦住你救人；渡劫失败则转世重修，但层数不退。
- [叙事主线](docs/story.md)：他为救人而成仙，成了仙才知道人是仙害的；前四份文档里的系统早已是伏笔，列仙图录最后变成击杀名单。

**四条守恒律**撑起全部平衡，各管一个维度：

| 守恒律 | 约束 | 管什么 |
| --- | --- | --- |
| 预算守恒 | 配比归一化、炉温封顶 | **空间** —— 属性怎么分配 |
| 境遇守恒 | 旺相休囚死五值之和 = 5.00 | **时间** —— 强度何时兑现 |
| 命格守恒 | 十神契合五组之和 = 5.00 | **人** —— 什么装备属于你 |
| 生克守恒 | 生克五值之和 = 5.00 | **敌** —— 打谁有加成 |

四条都不制造强弱，只制造取舍。验算结论始终一致：**所有选择的期望相等，差别只在方差。**

### 术语对照

设计文档与代码共用下表的用词，以代码里已有的字串为准。

| 概念 | 用词 | 出处 |
| --- | --- | --- |
| 关卡场所 | **昆仑山门** | `index.html`、`game.js` |
| 一个关卡 | **一层 = 一个地方 = 一道敕令** | `rules/places.gd` 的六十层地点表 |
| 进层那一屏 | **本层告示**（地名 · 灾情 · 敕令 · 在身的规矩） | `place_notice.gd` |
| 打造装备处 | **兜率炉坊** | `forge.gd`、`main.gd` |
| 选角与备战处 | **列仙图录**（选角）、**点将台**（备战） | `main.gd`、`index.html` |
| 本层当令 | **地气**（天干，`(层数−1)%10`） | `wuxing.gd::ling_of` |
| 不进层去救人 | **驻留行善** | `gear.gd::aid_layer` |
| 敌人 | **精怪**（泛称）、山魈／火狐／镇山兽（具体） | `combat.gd`、`game.js` |
| 蓝条 | **灵力**（上限／每秒回蓝） | `equipment.gd`、`main.gd` |
| 货币 | **灵砂** | `main.gd` 的「击杀 %d · 灵砂 %d · 材料 %d」 |
| 打造材料 | **材料**（白话材质名：生铁、铁屑、火砂、冰核、龙骨……） | `materials.gd` |

两点说明：

- **项目名仍是《余烬地牢》**（`index.html` 的 `<title>` 未改），所以文档标题沿用，没有跟着题材改名。
- 原型目前是**五道敕令**的五波战斗；设计文档里的 **60 层 = 5 境界 + 待诏期**结构取代它，一道敕令即一层。
- 出身文档里的货币按代码统一写作**灵砂**。若要让「银两」作为凡俗货币与灵砂并存（富商持银两、修行者用灵砂），那是另一套经济设计。

## Godot 手机版

用 Godot 4.7.2 导入 [mobile/project.godot](mobile/project.godot)，再运行工程。开机是标题页，「进入游戏」到**列仙图录**选角：一台机器最多三个角色，各存一份档（第一格沿用旧存档 `forge-profile.json`，另两格是 `forge-profile-2.json`、`-3.json`），空位点「创建角色」去立命籍、可起道号，删角色要按两下。选好角色进挂机页：左上角头像打开**角色信息**（命格、境界、属性、本次挂机的击杀／灵砂／材料与每时效率，以及「返回选角」），右上角的门形按钮也能回选角。挂机击杀两成概率掉灵砂（每十层多一枚，乘出身倍率）。**离线收益**：离开超过一分钟，回来时按挂机效率（挂满两分钟后量出的每时击杀，量到之前按 4000）的五成补发灵砂和本层材料，最多计 12 小时；手机切后台回来也会结算。挂机页里，点「行装」查看穿戴和背包（正中是人物的全身像，武器、护腕、靴子、上衣和护腿可分别更换），点背包物品预览本层换装后的属性，人物也会先试穿那件给你看。锻造入口在行装右上角。手机版支持横屏和竖屏。

点「开始连战」或「本层告示」会先看到**本层告示**：这是什么地方、正在遭什么灾、仙界派你来做什么，以及在身的规矩和违规的代价。三条路 —— **接敕**进战斗；**驻留行善**不进层，救这个地方（换材料、下一层蒙荫、随侍士气，渡过木劫之后要赔一个境界）；**抗敕**要到炼神才做得到。

导出 iOS 工程时，把 [导出配置示例](mobile/export_presets.cfg.example) 复制为 `mobile/export_presets.cfg`。在 Godot 的 iOS 导出设置中填入自己的 Team ID 和 Bundle Identifier，再使用 Xcode 配置签名。

### 战斗表现

战场采用侧视构图，远山、残祠、石路和场上精灵沿着同一条地面线排列。[战场渲染](mobile/scripts/arena.gd) 把场上的前后走位投影成石路上的小幅纵深，也按同一套投影绘制预警和弹道。

底图跟着地方走：六个地域各有一条长卷（陇右旱、河东疫、太行矿、朔方兵、江淮涝、上界），每条由四幅拼成、约 7800 像素宽，一个地域的十层沿长卷从左走到右，天劫那层在最右端。各地域另有自己的远景雾色、前景天气（热尘、灰烬、煤尘、斜雨、云絮）与脚下阴影色。长卷按需加载，只常驻当前一张。出图规格、生成脚本与拼接工具见 [mobile/art/side/plates](mobile/art/side/plates)。

**打击感**按层叠：打中时整场停顿几十毫秒（顿帧，[combat.gd](mobile/scripts/combat.gd) 的 `HITSTOP`，暴击、击杀、层主倒地依次加长，挂机减半），每一下普攻把小怪往外推一小步并带极短硬直，层主几乎推不动；倒下的精怪被打飞一段、烧成焦黑再化灰。画面层（[arena.gd](mobile/scripts/arena.gd)）的震屏按「创伤值」累加、按 1.5 次方换算位移，偏向打击方向，另有一下沿打击方向的镜头冲击；打中溅暗红血雾，暴击夹火星，击杀腾起火星与灰片。不用手机震动。调手感只改 `HITSTOP`、`KNOCKBACK`、`SHAKE_PIXELS` 这几个常量，`hitstop_scale` 为 0 即关掉顿帧。

**暗黑调色**常开（[atmosphere.gdshader](mobile/scripts/atmosphere.gdshader) 的 `gothic()`）：去掉大半饱和、拉对比、阴影偏冷灰青、亮部偏旧骨黄，只有真正的朱红（血、布穗、火）和亮处保留颜色，四角压暗。力度由 `arena.gd` 的 `GRADE`、`VIGNETTE` 控制。

**人物**借街机格斗的画法（2026-11-25）：主角是两阶硬明暗、暗部偏冷，受光边一道暖色轮廓光（[model_toon.gdshader](mobile/scripts/model_toon.gdshader)），外轮廓一圈近黑粗描边（[model_silhouette.gdshader](mobile/scripts/model_silhouette.gdshader) 的 `THICK`）；竖屏战斗镜头推近，人物更大（`arena.gd` 的 `PORTRAIT_BATTLE_ZOOM`）。场景配色照旧。

长卷之外还有两层氛围，都在 [arena.gd](mobile/scripts/arena.gd) 里。**近景剪影**：画面底边一丛丛草、芦苇、乱石或云絮，走得比镜头快（1.6 倍），拉出纵深。**天色**：连战第一波是白天，第二波黄昏，层主在夜里；挂机按五分钟一天轮转。[atmosphere.gdshader](mobile/scripts/atmosphere.gdshader) 入夜压暗发蓝，亮处（灯笼、炉火、打击光）不跟着暗，主角身边留一圈暖光。

玩家角色和随侍共用[角色画布](mobile/scripts/cutout_hero.gd)：它在离屏画布里从侧面渲染[主角模型](mobile/scripts/model_hero.gd)，再画进战场。行装试穿与战斗用的是同一个模型、同一套衣装和脚底锚点，头像也是模型渲的侧面半身像。定稿范围见[主角美术定稿](mobile/art/model-hero/README.md)。

剑一轮两斩，挥砍动作对齐每次命中时刻；长枪右手前刺，弓在左手发射远程箭矢。旧存档的长刃和双刀归剑，重锤归长枪，法杖和短杖归弓。战斗仍由 [combat.gd](mobile/scripts/combat.gd) 结算。

炉坊按装备的五行与阴阳挑选武器零件和饰色。武器和装备图标由 [weapon_design.gd](mobile/scripts/weapon_design.gd) 和 [gear_design.gd](mobile/scripts/gear_design.gd) 定款，颜色取自 [pigments.gd](mobile/scripts/pigments.gd)。原画在 `mobile/art/side/source/parts/`，由 [pack_parts.py](mobile/art/side/pack_parts.py) 打包。

精怪各用一张 4 列 × 3 行的图集（四步走、起手、挥击、收招、待机、四格倒地），每格的逻辑尺寸是 160 × 96，定义在 [monster_art.gd](mobile/scripts/monster_art.gd)。原图是像素画，[pack_monsters.py](mobile/art/side/pack_monsters.py) 用带容差的 EPX 把锯齿补圆后放大到 3 倍，和人物一样走线性取样；贴图按需加载，只留最近用到的两张。这一步只解决「粗」，细节没有变多——有了真正的高清十二格原画，放进 [art/side/source/monsters](mobile/art/side/source/monsters) 重跑脚本即可。

手操战的走位用浮动摇杆（[stick.gd](mobile/scripts/stick.gd)）：在战场区按下即生摇杆，松手即收，键盘 WASD 与前后键同时保留。

点击「开始连战」后，每层先清两波成群的小怪（五只、七只），再打层主。小怪单只的血量、伤害和个头都远小于层主，分三路纵深小跑着压上来，贴身的会从侧翼出手，一轮连斩能扫到一排。挂机时场上同时最多五只，每只的掉落按比例折回，材料流水不因怪多而涨。普通层通关后自动开下一层。抵达第 10、20、30、40、50 层时，连战会停在天劫告示。告示逐件对比已穿装备在本层和劫中的境遇倍率。可以直接迎劫，也可以点「调整装备」换装，返回告示后查看新的倍率。选择「留在本层挂机」可以稍后再挑战。连战途中点「停止连战」可回到当前层挂机，战败则进入调息。

连战默认原地自动普攻，等精怪入位后交手，技能牌可手动释放。全自动会使用技能并原地闪避，手动模式可以主动走位或后撤。倍速键在 1×、2×、3× 之间切换，桌面端也可用 M 和 V 切换操作模式和倍速。

### 开发用脚本

```sh
godot --headless --path mobile --script res://tests/run_tests.gd        # 规则与表现的单元断言
godot --headless --path mobile --script res://tests/run_playthrough.gd  # 创角到渡劫的实玩流程
godot --path mobile --script res://tests/_shot.gd -- shot.png           # 截图
godot --path mobile --script res://tests/_gear_icons.gd                 # 用主角模型重渲装备格图标
godot --path mobile --script res://tests/_dress.gd -- shot.png huo spear pose 30 attack 0.45
godot --headless --path mobile --script res://tests/_fit_art.gd -- D:/out/ready-0.png ready-0 1.0
python mobile/art/side/pack_weapons.py --preview out   # 重出手持兵器图集与形制图标
python mobile/art/side/pack_monsters.py --preview out  # 把精怪的像素图集平滑放大
```

`_dress.gd` 按指定五行穿满五个装备槽再截图，末尾可加 `female`，模式为 `bag` 时截行装页。图集脚本需要 Pillow、NumPy 和 SciPy。`_pack_fx.gd` 打包击打特效，`_stitch_plates.gd` 拼接地域长卷。

## 网页原型

在仓库根目录启动静态文件服务，再用浏览器打开 `http://localhost:8000`。

```sh
python3 -m http.server 8000
```

网页入口是 [index.html](index.html)，游戏逻辑位于 [game.js](game.js)。

字体的版权与 SIL 开源字体许可证见 [mobile/art/fonts](mobile/art/fonts)。击打特效改编自 [pixelfx](https://github.com/patch-gg/pixelfx)，来源与 MIT 许可全文见 [mobile/art/fx/NOTICE.md](mobile/art/fx/NOTICE.md)。两端共用的神仙画像、战斗造型、场景与法器图集位于 [mobile/art/immortals](mobile/art/immortals)。
