# 余烬地牢 · Ashen Crypt

《余烬地牢》是一款中国神仙题材的 2D 动作游戏。玩家在列仙图录中选择二郎神、九天玄女、后羿、青鸟仙子、雷部天师或电母，领取土地公的敕令，守住昆仑山门。五道敕令沿用五波战斗，最后一关需要降伏镇山兽。Godot 版可以用掉落的材料在兜率炉坊打造武器、护具和饰品。


## 设计文档

**主角是个凡人，为救家人与世间疾苦而求仙。** 全作分两个阶段：第一阶段是成仙之路，第二阶段揭穿成仙本是骗局。**现在只做第一阶段。**

角色、装备、精怪和山门各层共用一套阴阳五行。规则由策划定义，具体装备由玩家自己组合出来。

- [阴阳五行世界模型](docs/wuxing-world.md)：五行生克、十天干、旺相休囚死、精怪生成与流年轮转。
- [规则锻造系统设计](docs/crafting-rules.md)：功率预算守恒、生克结算、境遇与契合、形制矩阵、触发语法与格局。
- [命格与运限](docs/bazi-destiny.md)：没有职业，只有男女与出生时辰排出的八字；十神决定什么装备适合你，大运与流年决定层数与规则。
- [出身与灵砂](docs/origins.md)：官宦、富商、普通人、穷人各有两优两劣；官宦的随侍数随流年在 0~3 之间变化。
- [成仙主线](docs/ascension.md)：一甲子六十层走完五境界，五道天劫对应五行，五条规矩约束一生；渡劫失败则转世重修，但买不回时间。
- [叙事与两阶段结构](docs/story.md)：成仙是骗局，而前四份文档里的系统早已是伏笔；一层即一年，一个甲子就是一辈子。

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
| 一个关卡 | **一层 = 一个流年 = 一道敕令** | `main.gd` 的「%s敕令 · %d/%d」 |
| 打造装备处 | **兜率炉坊** | `forge.gd`、`main.gd` |
| 选角与备战处 | **列仙图录**（选角）、**点将台**（备战） | `main.gd`、`index.html` |
| 敌人 | **精怪**（泛称）、山魈／火狐／镇山兽（具体） | `combat.gd`、`game.js` |
| 蓝条 | **灵力**（上限／每秒回蓝） | `equipment.gd`、`main.gd` |
| 货币 | **灵砂** | `main.gd` 的「击杀 %d · 灵砂 %d · 材料 %d」 |
| 打造材料 | **材料**（天干材料：庚铁、丙焰砂、龙骨……） | `gear.gd` |

两点说明：

- **项目名仍是《余烬地牢》**（`index.html` 的 `<title>` 未改），所以文档标题沿用，没有跟着题材改名。
- 原型目前是**五道敕令**的五波战斗；设计文档里的 **60 层 = 6 大运 = 1 甲子**结构取代它，一道敕令即一层。
- 出身文档里的货币按代码统一写作**灵砂**。若要让「银两」作为凡俗货币与灵砂并存（富商持银两、修行者用灵砂），那是另一套经济设计。

## Godot 手机版

用 Godot 4.7.2 导入 [mobile/project.godot](mobile/project.godot)，再运行工程。立下命籍后点击「入山」进入山门，在山门可以回炉坊锻造或挑战层主。手机版支持横屏和竖屏。

导出 iOS 工程时，把 [导出配置示例](mobile/export_presets.cfg.example) 复制为 `mobile/export_presets.cfg`。在 Godot 的 iOS 导出设置中填入自己的 Team ID 和 Bundle Identifier，再使用 Xcode 配置签名。

### 战斗表现

战场采用侧视构图，远山、残祠、石路和场上精灵沿着同一条地面线排列。[战场渲染](mobile/scripts/arena.gd) 把场上的前后走位投影成石路上的小幅纵深，也按同一套投影绘制预警和弹道。

男女修行人各用一张 4 列 × 3 行的像素图集，每格为 96 × 96 像素，脚底锚点和武器握点定义在 [side_art.gd](mobile/scripts/side_art.gd)。[motion.gd](mobile/scripts/motion.gd) 根据战斗动作在脚步、起手、挥击、跟招、收势、后撤和受击之间切帧。装备继续影响武器形制、袍色、刃光与符阵。 [侧视素材与生成提示词](mobile/art/side/prompts.json)

手操战的走位用浮动摇杆（[stick.gd](mobile/scripts/stick.gd)）：在战场区按下即生摇杆，松手即收，键盘 WASD 与前后键同时保留。

点击「开始连战」后，每层先清两波精怪，再打层主。清完一波会自动跑向下一波，击败层主后结算并自动开下一层。点「停止连战」可返回当前层挂机，战败则进入调息。

连战默认自动接敌和普攻，技能牌可手动释放。点击操作模式可切到全自动或手动，倍速键在 1×、2×、3× 之间切换。桌面端也可用 M 和 V 切换。

### 开发用脚本

```sh
godot --headless --path mobile --script res://tests/run_tests.gd        # 规则与表现的单元断言
godot --headless --path mobile --script res://tests/run_playthrough.gd  # 创角到渡劫的实玩流程
godot --path mobile --script res://tests/_shot.gd -- shot.png           # 截图
godot --path mobile --script res://tests/_dress.gd -- shot.png huo hammer pose 30 attack 0.45
godot --headless --path mobile --script res://tests/_fit_art.gd -- D:/out/ready-0.png ready-0 1.0
```

`_dress.gd` 会按指定五行把六个槽位全打满再截图，可以同时核对装备外观和动作姿态。`_fit_art.gd` 用于整理 `art/immortals` 中的单张立绘素材。

## 网页原型

在仓库根目录启动静态文件服务，再用浏览器打开 `http://localhost:8000`。

```sh
python3 -m http.server 8000
```

网页入口是 [index.html](index.html)，游戏逻辑位于 [game.js](game.js)。

字体的版权与 SIL 开源字体许可证见 [mobile/art/fonts](mobile/art/fonts)。两端共用的神仙画像、战斗造型、场景与法器图集位于 [mobile/art/immortals](mobile/art/immortals)。
