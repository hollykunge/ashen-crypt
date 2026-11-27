extends RefCounted

const GARMENT_DYES := {"本色": Color.WHITE, "朱砂": Color("#ed7768"), "靛蓝": Color("#76a8f3"),
	"松绿": Color("#82ca95"), "赭金": Color("#edbc68"), "紫藤": Color("#bb91df")}

# 五行用色，全游戏一份：取敦煌壁画的矿物颜料。
#   木 石绿   火 赭红   土 土黄   金 白垩   水 青金
# 兵器、装备图标、人物染袍、刃光与界面上的五行字色都从这里取，同一行在哪儿都是同一种颜色。
# 底子（锈铁、旧铜、旧骨、麻皮）不随五行变，五行只落在布条、绳穗和染色上。

# 颜料本色：器物上朱红的布条绳穗按这一档重染，也是穗子、杆漆的底色。
const PIGMENT := {"mu": Color("#5f8d68"), "huo": Color("#a9472f"), "tu": Color("#b38a48"),
	"jin": Color("#d6cdb6"), "shui": Color("#40608f")}
# 染布：比颜料再沉一点，衣袍、靴子吃这一档。
const DYE := {"mu": Color("#5b7f5c"), "huo": Color("#8f3f2c"), "tu": Color("#9a7442"),
	"jin": Color("#b8ae98"), "shui": Color("#3d5680")}
# 浅色：界面上的五行字、立绘偏色。
const LIGHT := {"mu": Color("#bcd3b8"), "huo": Color("#e2b2a0"), "tu": Color("#e3cfa2"),
	"jin": Color("#efe9db"), "shui": Color("#b3c3dc")}
# 纸本界面的字色：保留五行色相，降低明度以保证浅底可读。
const INK := {"mu": Color("#365b40"), "huo": Color("#8f3b2b"), "tu": Color("#80602c"),
	"jin": Color("#655b48"), "shui": Color("#35547e")}
# 光：刃光、灵珠，要在暗处亮得起来。
const GLOW := {"mu": Color("#a9d9a6"), "huo": Color("#f2a083"), "tu": Color("#ecc98a"),
	"jin": Color("#f4eedf"), "shui": Color("#9dbbe8")}
# 阴阳边光：阳偏暖白，阴偏冷青。
const YANG := Color("#efd9a8")
const YIN := Color("#a9c3cc")
# 底子：暗铁和旧铜。五行只在上面淡淡偏一点。
const IRON := Color("#ecebe7")
const BRONZE := Color("#c4ae86")
