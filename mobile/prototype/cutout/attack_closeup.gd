extends SceneTree
## 劈砍特写：在几个时刻定格截图，存成 <目录>/atk-0.png …
##   godot --path mobile --resolution 900x900 --script res://prototype/cutout/attack_closeup.gd -- <目录>
var r
var n := 0
var times := [0.0, 0.3, 0.38, 0.43, 0.55, 0.68, 0.9]
var i := 0
func _initialize():
	DisplayServer.window_set_size(Vector2i(900, 900))
	root.size = Vector2i(900, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var bg := ColorRect.new(); bg.color = Color(0.25, 0.26, 0.3); bg.size = Vector2(900, 900); root.add_child(bg)
	r = load("res://prototype/cutout/cutout_rig.gd").new()
	root.add_child(r)
	r.setup("res://prototype/cutout/swordsman/rig.json", "res://prototype/cutout/swordsman/parts")
	r.scale *= 4.8
	r.position = Vector2(330 + 4.8 * 12.0, 3060.0 * 0.5 + 4.8 * 18.0)
	r.play("attack")
func _process(d):
	n += 1
	r.freeze_t = times[i]
	if n % 25 == 0:
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "/atk-%d.png" % i)
		i += 1
		if i >= times.size():
			return true
	return false
