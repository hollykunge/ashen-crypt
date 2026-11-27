# 皮影风界面改造任务（交给 Codex）

游戏战场已经改成皮影戏（皮影主角、皮影精怪、暖琥珀幕布），但界面还是上一版的「水墨宣纸」风：
毛笔浓墨按钮（art/ui-icons/stroke-*.png）、宣纸签面板（paper-card.png）、墨团（ink-blot.png）、
水墨线条图标（art/ui-icons/raw/sheet-1～4.png 切出来的 *.png）、标题页水墨远山。
任务：把**整个游戏界面**改成统一的皮影戏风格，包括按钮、面板、图标、装备格、各个页面的底子。

## 皮影风格定义（所有新图都按这个出）

- 材质：半透明的染色牛皮/驴皮，刀刻镂空纹样（云纹、回纹、卷草、万字、铜钱纹），边缘是刀刻的利落轮廓，不是毛笔。
- 颜色只用皮影的几种传统染色：朱红 #b8321f、墨黑 #241510、靛青 #2f4f6a、草绿 #4f6b2e、皮子本色琥珀 #d9a35b。
  透光感：被身后灯光照透，颜色饱和、有微微的透光渐变，镂空处透出后面的幕布光。
- 幕布：暖琥珀米黄 #f3d59a ～ #e7b66d，中间亮、四边暗（戏台口外是黑的）。
- 图标：一个物件一张皮子剪影，镂空花纹表达细节，可见的铆钉/关节小圆钉点缀；44px 下轮廓要清楚。
- 按钮：一块刀刻的皮子牌（长条形、两头有云头或如意头），普通按钮墨黑/深褐皮子，主按钮朱红皮子；字是幕布米黄色。
- 面板：一块大的镂空边框皮子框，中间是半透明的幕布纸（字要看得清），四角云头纹。
- 禁止：毛笔笔触、水墨晕染、宣纸纹、写实光影、3D 质感、渐变光晕、外发光。

## 场上的规矩（已经在代码里做了，界面别破坏）

- 皮影戏台上人物要少：同时上场的精怪最多 3 只（scripts/combat.gd 的 STAGE_CAP）。
- 背景要素净：幕布上长卷只留很淡的影子，布景稀疏（scripts/arena.gd、scripts/snow_haze.gdshader）。
  界面元素也要克制：战斗时 HUD 尽量小、少、靠边，不要挡人物。

## 要改的东西

1. **出图**：用你内置的出图工具生成新的皮影风素材，覆盖下面这些文件（文件名、尺寸比例、透明底、九宫格边距尽量和原来一样，
   代码就不用大改）。出图流程和切图脚本参考 art/ui-icons/PROMPTS.md、art/ui-icons/slice.py、prototype/cutout/cut.py。
   - art/ui-icons/stroke-wide.png、stroke-square.png（按钮底）
   - art/ui-icons/paper-card.png（面板底）
   - art/ui-icons/ink-blot.png（头像垫底）
   - art/ui-icons/raw/sheet-1～4.png 及切出的全部图标（名字见 PROMPTS.md 和 scripts/gothic.gd 的 ART_NAMES）
   - 标题页背景（scripts/title_page.gd 用的远山等），改成皮影戏台：幕布 + 稀疏的皮影远山/亭子剪影
   - 装备格、背包格、锻造页里装备的图标底子（scripts/equipment_slot.gd、armory.gd、forge.gd、forge_art.gd 用到的图）
   原始出图存进对应目录的 raw/ 或 source/，出图提示词写进 art/ui-icons/PROMPTS.md（替换掉水墨版的段落），以后能重出。
2. **代码**：scripts/main.gd（_restyle、brush_button、paper_box、wash_box、颜色常量 CRIMSON/NIGHT/WASH 等）、scripts/gothic.gd、
   title_page.gd、character_select.gd、character_page.gd、armory.gd、forge.gd、place_notice.gd、tribulation_notice.gd、
   offline_card.gd、layer_turnover.gd、battle_strip.gd、camp_pouch.gd 里的配色、字色、面板样式，统一到皮影风。
   注释里「毛笔」「水墨」「宣纸」之类的说法改成和新风格一致。
3. **验收**：
   - `godot --headless --path mobile --script res://tests/run_tests.gd` 必须 0 项失败。
   - 用 `godot --path mobile --script res://tests/_shot.gd -- <png> [点击序列]` 和 `tests/_cutout_battle.gd`、`tests/_armory_shot.gd`
     截下标题页、选角页、挂机战斗、角色信息、行装、锻造页，自己看图检查：风格统一、字看得清、没有残留的水墨毛笔元素。
     截图存到 mobile/art/piying/ui-shots/。
   - 不要动皮影主角、精怪、幕布的战场画法和 combat.gd 的规则。
   - 不要 git commit，也不要 push。

完成后在本文件末尾追加「完成情况」：改了哪些文件、出了哪些图、还有哪些页面没改到或不满意。
## 完成情况

- 标题、列仙图录、立下命籍和仙班名录已接入皮影戏台背景、云头皮牌、双主角侧像和六位仙班侧像。标题保留「吾行」原题字。战斗 HUD 的操作图标靠边排列，主角头像、材料袋和波次条使用同一套镂刻图形。
- 角色信息、离线收益、进层和天劫告示、转层、行装与锻造改用皮框幕面。兵器图标随刀身、枪头或弓臂形制变化，护具图区分布、皮、链三类并保留染色。空槽、试穿和已穿戴状态沿用现有交互。
- 内置图像生成工具产出 11 张原图，位于 `../ui-icons/raw/`：四张操作图集、配件图、横竖两张戏台、护具图、兵器图、双主角侧像和仙班图。派生的 24 个操作图标、普通与朱红按钮、卡片、头像皮环、装备底板、装备图集、头像及两个背景位于 `../ui-icons/`。出图提示和实际切图入口分别为 `PROMPTS.md` 和 `slice.py`。
- 界面脚本涉及 `main.gd`、`gothic.gd`、`title_page.gd`、`character_select.gd`、`character_page.gd`、`side_art.gd`、`roster.gd`、`sheet.gd`、`offline_card.gd`、`equipment_slot.gd`、`armory.gd`、`forge.gd`、`forge_art.gd`、`place_notice.gd`、`tribulation_notice.gd`、`layer_turnover.gd`、`battle_strip.gd` 与 `camp_pouch.gd`。
- Godot 4.7.2 规则测试 2727 条断言、0 项失败，实玩流程 0 项失败。`tests/run_playthrough.gd` 的连战夹具已按既有三只同台规则核对台上与候场数量，并等候补登场再清波。
- `ui-shots/` 保存了 14 张 Godot 实际渲染截图，包括 390 × 844 的标题、选角、创角、仙班、挂机、角色信息、空行囊、满装行囊、投料锻造、两类告示、离线收益及转层，以及 844 × 390 的满装行囊。已逐图复查并修正云纹遮字、方牌切片串图、创角侧像与说明重叠、转层文字对比度和锻造页头按钮过高。
- 说明所列的玩家页面已完成。开发专用「试演 · 动作与换装」场景未改版，本次验收使用 Windows 版 Godot，未在 Android 真机上验证。

### 第二轮

1. 男主角头像现由 `prototype/cutout/piying/parts/hair.png`、`head.png`、`torso.png` 合成。`slice.py` 读取同一套 `rig.json` 中的发饰、颈部锚点和部件比例，按战场遮挡顺序叠放后裁到胸口。挂机、角色信息、创角和连战头像共用该图。女头像沿用原图集右格。
2. 挂机场景将地域卷影强度设为零，取消近景树木、前景草石与横雾，只在地面附近保留一道浅色山影。连战保留移动布景，降低长卷和远山对比度。移除了旱村的旧水墨山路贴图引用。
3. 挂机和连战的伤害数字统一用描边字。生成并切分 16 格透明皮影材料图集，地面掉落、拾取提示与挂机材料袋共用。普通回复和奖励掉落也改用透明图标。连战技能冷却改为环形读条，消除整块深色遮罩。
4. 「开始连战」「准备渡劫」共用朱红云头长牌，按钮中央显示当前动作。连战普攻等主操作改用朱红皮牌配浅色圆饰。
5. `ui-shots/` 已更新 19 张 Godot 实际截图，包括装备详情、五行格局和横屏行装。`battle-entry.png`、`battle.png` 是按 `_cutout_battle.gd -- <目录> 2 60` 得到的两帧默认挂机画面；`battle-settled.png` 为进场地名消退后的挂机，`battle-route.png` 为加 `route` 的连战。已逐页回看。Windows Godot 4.7.2 运行 `run_tests.gd` 得到 2727 条断言、0 项失败，`run_playthrough.gd` 为 0 项失败。此次改动限于显示与素材，未改战斗规则。
