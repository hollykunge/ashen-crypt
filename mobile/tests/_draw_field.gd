extends SceneTree

# 开发用：定格一场战斗，逐项去掉战场上画的东西，看每一项占多少次绘制调用（累计去掉）。
# 用法 godot --path mobile --resolution 1080x2340 --script res://tests/_draw_field.gd

const Main = preload("res://main.tscn")
var save_path := "user://test-field-" + Crypto.new().generate_random_bytes(6).hex_encode() + ".json"
var game
var frame := 0
var stage := 0
var last := -1
const STAGES := ["全部", "去掉伤害数字", "去掉火花", "去掉特效", "去掉天气飘尘", "去掉敌人", "去掉远景雾气", "去掉背景长卷", "去掉前景剪影", "去掉天光遮罩", "战场整个藏起来"]

func _initialize() -> void:
	game = Main.instantiate()
	game.save_base = save_path
	root.add_child(game)
	_start.call_deferred()

func _start() -> void:
	_press(game, "进入游戏"); _press(game, "创建角色"); _press(game, "入山")

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 160:
		paused = true
	if frame < 170 or (frame - 170) % 8 != 7:
		return false
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("FIELD %-12s %4d%s" % [STAGES[stage], draws, "" if last < 0 else "   (少 %d)" % (last - draws)])
	last = draws
	stage += 1
	var f = game.field
	match stage:
		1: f.run.popups.clear()
		2: f.sparks.clear()
		3: f.run.effects.clear()
		4:
			var p: Dictionary = f.plate.duplicate(); p.weather = &"none"; f.plate = p
		5: f.run.enemies.clear(); f.run.fallen_enemies.clear()
		6: f.fog = GradientTexture2D.new(); f.fog.width = 1; f.fog.height = 1
		7: f.backdrop.hide()
		8: f.near.hide()
		9: f.atmosphere.hide()
		10: f.hide()
		_:
			_cleanup(); return true
	f.queue_redraw()
	return false

func _cleanup() -> void:
	for slot in range(game.Gear.MAX_CHARACTERS):
		var slot_file: String = game.Gear.slot_path(slot, save_path)
		for path in [slot_file, slot_file + ".tmp"]:
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	for path in [save_path, save_path + ".tmp"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

func _press(node: Node, title: String) -> bool:
	if node is Button and node.text == title and node.is_visible_in_tree() and not node.disabled:
		node.pressed.emit(); return true
	for child in node.get_children():
		if _press(child, title): return true
	return false
