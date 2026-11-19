extends SceneTree

# 开发用：启动主场景，等若干帧后截图存盘再退出。
# 用法 godot --path mobile --script res://tests/_shot.gd -- <输出路径> [点击序列] [测试存档] [等待帧数]
# 点击序列形如 "600,1180;360,700"，按帧序依次在这些坐标发一次左键点击。

var _frames := 0
var _out := "user://shot.png"
var _clicks: Array = []
var _click_index := 0
var _settle_frames := 20

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		for pair in args[1].split(";", false):
			var xy := pair.split(",")
			if xy.size() == 2:
				_clicks.append(Vector2(float(xy[0]), float(xy[1])))
	var scene: PackedScene = load("res://main.tscn")
	var game = scene.instantiate()
	if args.size() > 2:
		game.profile.save_path = args[2]
	if args.size() > 3:
		_settle_frames = maxi(_settle_frames, int(args[3]))
	root.add_child(game)

func _process(_delta: float) -> bool:
	_frames += 1
	# 前 20 帧让界面稳定，之后每 12 帧投一次点击，最后再等 20 帧截图
	if _frames > 20 and _click_index < _clicks.size() and (_frames - 20) % 12 == 0:
		_tap(_clicks[_click_index])
		_click_index += 1
		return false
	if _frames < 24 + _clicks.size() * 12 + _settle_frames:
		return false
	var image := root.get_texture().get_image()
	var error := image.save_png(_out)
	if error != OK:
		printerr("截图写入失败：%s [%d]" % [_out, error])
		quit(1)
		return true
	print("截图已存：%s  %dx%d" % [_out, image.get_width(), image.get_height()])
	return true

func _tap(at: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		Input.parse_input_event(event)
