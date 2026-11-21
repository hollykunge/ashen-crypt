extends SceneTree
## 站姿（或别的动作）上半身特写：900×900 窗口里放大渲染一张，看脖子、领口这些细节。
##   godot --path mobile --resolution 900x900 --script res://prototype/cutout/closeup.gd -- stand 输出.png
## 站姿上半身特写：放大 3 倍渲染，存成图
var r
var n := 0
func _initialize():
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DisplayServer.window_set_size(Vector2i(900, 900))
	root.size = Vector2i(900, 900)
	var bg := ColorRect.new(); bg.color = Color(0.25, 0.26, 0.3); bg.size = Vector2(900, 900); root.add_child(bg)
	r = load("res://prototype/cutout/cutout_rig.gd").new()
	root.add_child(r)
	r.setup("res://prototype/cutout/hero/rig.json", "res://prototype/cutout/hero/parts")
	# 第三个参数是放大倍数（默认 9.6，只看到肩；4.8 能看到腰）
	var a := OS.get_cmdline_user_args()
	var zoom := float(a[2]) if a.size() > 2 else 9.6
	r.scale *= zoom
	r.position = Vector2(330 + (9.6 - zoom) * 12.0, 3060.0 * zoom / 9.6 + (9.6 - zoom) * 18.0)
	r.play(OS.get_cmdline_user_args()[0])
func _process(d):
	n += 1
	if n == 30:
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[1])
		return true
	return false
