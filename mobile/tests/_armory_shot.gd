extends SceneTree

# 开发用：新建测试角色进挂机，打开行装页，截一张主角试穿的样子。
# 用法 godot --path mobile --script res://tests/_armory_shot.gd -- <输出 png>
# 存档写在 user:// 下的临时文件，跑完删掉。

const Main = preload("res://main.tscn")
var save_path := "user://test-armory-" + Crypto.new().generate_random_bytes(6).hex_encode() + ".json"
var out := "user://armory.png"
var game
var frame := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	game = Main.instantiate()
	game.save_base = save_path
	root.add_child(game)
	_start.call_deferred()

func _start() -> void:
	_press(game, "进入游戏")
	_press(game, "创建角色")
	_press(game, "入山")

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 30:
		game._open_forge()
	if frame < 90:
		return false
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(out)
	print("SHOT ", out, " state=", game.state)
	_cleanup()
	return true

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
