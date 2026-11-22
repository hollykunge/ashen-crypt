extends SceneTree
## 几个动作并排各摆一个，全身截一张图，对比姿势用。
##   godot --path mobile --script res://prototype/cutout/pose_shot.gd -- 输出.png idle,ready [ready 的参数 JSON]
## 第三个参数可以临时覆盖 rig.json 的 ready（不写回文件），试默认值用。
var rigs := []
var n := 0
func _initialize():
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var a := OS.get_cmdline_user_args()
	var actions: PackedStringArray = (a[1] if a.size() > 1 else "idle,ready").split(",")
	var size := Vector2i(1200, 520)
	DisplayServer.window_set_size(size)
	root.size = size
	var bg := ColorRect.new(); bg.color = Color(0.58, 0.47, 0.36); bg.size = Vector2(size); root.add_child(bg)
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://prototype/cutout/hero/rig.json"))
	if a.size() > 2:
		var over: Dictionary = JSON.parse_string(a[2])
		var ready: Dictionary = cfg.get("ready", {})
		ready.merge(over, true)
		cfg["ready"] = ready
	for i in actions.size():
		var r = load("res://prototype/cutout/cutout_rig.gd").new()
		root.add_child(r)
		r.setup_dict(cfg.duplicate(true), "res://prototype/cutout/hero/parts")
		r.scale *= 1.2
		r.position = Vector2(size.x / actions.size() * (i + 0.42), size.y - 30)
		r.play(actions[i])
		rigs.append(r)
func _process(d):
	n += 1
	if n == 40:
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
		return true
	return false
