extends SceneTree

# 开发用：新建一个测试角色进挂机战斗，隔几帧截一张战场，看皮影主角在游戏里的样子。
# 用法 godot --path mobile --script res://tests/_cutout_battle.gd -- <输出目录> [张数] [间隔帧数] [route]
# 第四个参数写 route 就开连战（会跑图）。存档写在 user:// 下的临时文件，跑完删掉。

const Main = preload("res://main.tscn")
var save_path := "user://test-cutout-" + Crypto.new().generate_random_bytes(6).hex_encode() + ".json"
var out_dir := "user://cutout"
var shots := 8
var every := 20
var route := false
var game
var frame := 0
var taken := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		shots = int(args[1])
	if args.size() > 2:
		every = int(args[2])
	route = args.size() > 3 and args[3] == "route"
	DirAccess.make_dir_recursive_absolute(out_dir)
	game = Main.instantiate()
	game.save_base = save_path
	root.add_child(game)
	_start.call_deferred()

func _start() -> void:
	_press(game, "进入游戏")
	_press(game, "创建角色")
	_press(game, "入山")
	# 环境变量 GENDER=female：把刚建的角色改成女主角（存档和场上的外观一起改）
	if OS.get_environment("GENDER") == "female":
		game.profile.state.character.gender = "female"
		var her: Dictionary = game.field.look.duplicate()
		her.gender = "female"
		game.field.look = her
	if route:
		game.challenge_button.pressed.emit()
		_press(game.place_notice, "接敕")
	var field = game.field
	print("form=%s cutout=%s" % [field.look.form, field.cutout != null])

func _process(_delta: float) -> bool:
	frame += 1
	if frame < 40 or (frame - 40) % every != 0:
		return false
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	var run = game.run
	var path := "%s/shot-%02d.png" % [out_dir, taken]
	image.save_png(path)
	var hero = game.field.cutout
	print("%s motion=%s stride=%.1f advancing=%s hero_action=%s t=%.2f outfit=%s" % [path, run.motion, run.stride, run.advancing,
		hero._action if hero != null else "-", hero.hero.anim.current_animation_position if hero != null else 0.0,
		hero.hero.outfit if hero != null else {}])
	if hero != null and OS.get_environment("CUTOUT_DEBUG") != "":
		hero.viewport.get_texture().get_image().save_png(path.replace(".png", "-vp.png"))
	taken += 1
	if taken >= shots:
		_cleanup()
		return true
	return false

func _cleanup() -> void:
	for slot in range(game.Gear.MAX_CHARACTERS):
		var slot_file: String = game.Gear.slot_path(slot, save_path)
		for path in [slot_file, slot_file + ".tmp"]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
	for path in [save_path, save_path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func _press(node: Node, title: String) -> bool:
	if node is Button and node.text == title and node.is_visible_in_tree() and not node.disabled:
		node.pressed.emit()
		return true
	for child in node.get_children():
		if _press(child, title):
			return true
	return false
