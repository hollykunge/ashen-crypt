extends SceneTree

# 开发用：把主角（cutout_hero.gd，3D 模型 + 手里的兵器）按几套装备、兵器穿上，摆几个动作，各截一张画布。
# 用法 godot --path mobile --script res://tests/_model_dress.gd -- <输出目录>

const CutoutHero = preload("res://scripts/cutout_hero.gd")
const CLOTH := {"armor": "cloth", "gloves": "cloth", "greaves": "cloth", "boots": "cloth"}
const LEATHER := {"armor": "leather", "gloves": "leather", "greaves": "leather", "boots": "leather"}
const CHAIN := {"armor": "chain", "gloves": "chain", "greaves": "chain", "boots": "chain"}
# [护甲, 兵器, 动作, 进度, 走过的距离, 跑]
const CASES := [
	[CLOTH, "sword", &"", 0.0, 0.0, false],
	[LEATHER, "sword", &"attack", 0.30, 0.0, false],
	[LEATHER, "sword", &"attack", 0.48, 0.0, false],
	[CHAIN, "sword", &"", 0.0, 140.0, true],
	[CLOTH, "spear", &"", 0.0, 0.0, false],
	[LEATHER, "spear", &"attack", 0.48, 0.0, false],
	[CHAIN, "spear", &"", 0.0, 60.0, false],
	[CLOTH, "bow", &"", 0.0, 0.0, false],
	[LEATHER, "bow", &"attack", 0.30, 0.0, false],
	[CHAIN, "jian", &"attack", 0.48, 0.0, false],
]
var out := "user://dress"
var hero
var frame := 0
var index := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	hero = CutoutHero.new()
	root.add_child(hero)
	hero.fit(float(OS.get_environment("DRESS_SCALE")) if OS.get_environment("DRESS_SCALE") != "" else 3.0, 1.0)

func _process(_delta: float) -> bool:
	frame += 1
	var case: Array = CASES[index]
	if frame % 12 == 1:
		hero.dress({"armor_types": case[0], "form": case[1]})
	hero.drive(case[2], case[3], case[4], case[5], [0.48])
	if frame % 12 != 0:
		return false
	var path := "%s/d_%d.png" % [out, index]
	hero.viewport.get_texture().get_image().save_png(path)
	print("SHOT ", path, " ", case[1], " ", hero._action)
	index += 1
	return index >= CASES.size()
