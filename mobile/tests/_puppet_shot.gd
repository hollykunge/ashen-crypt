extends SceneTree
## 临时：把男性皮影按几种姿势和衣装并排截图。
##   godot --path mobile --script res://tests/_puppet_shot.gd -- 输出.png [dress]
var Puppet = load("res://scripts/hero_puppet.gd")
var n := 0
var out := ""
func _initialize():
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var a := OS.get_cmdline_user_args()
	out = a[0]
	var dress := a[1] if a.size() > 1 else "none"
	var frames: Array = (a[2] if a.size() > 2 else "idle,ready,walk-2,walk-6,run-3,strike").split(",")
	var zoom := float(a[3]) if a.size() > 3 else 0.9
	var size := Vector2i(int(300 * frames.size() * zoom / 0.9), int(760 * zoom / 0.9))
	DisplayServer.window_set_size(size)
	root.size = size
	var bg := ColorRect.new(); bg.color = Color(0.82, 0.78, 0.7); bg.size = Vector2(size); root.add_child(bg)
	for i in frames.size():
		var p = Puppet.new(a[4] if a.size() > 4 else "res://art/hero-rig/")
		if a.size() > 5 and a[5] == "rigid":
			p.skinned = false
		root.add_child(p)
		if dress == "cloth":
			p.equip(true, true, false, {"armor": "cloth", "gloves": "cloth", "greaves": "cloth", "boots": "cloth"})
		elif dress == "leather":
			p.equip(true, true, true, {"armor": "leather", "gloves": "leather", "greaves": "leather", "boots": "leather"})
		elif dress == "chain":
			p.equip(true, true, true, {"armor": "chain", "gloves": "chain", "greaves": "chain", "boots": "chain"})
		else:
			p.equip(true, false)
		p.scale *= zoom
		p.position = Vector2(size.x / frames.size() * (i + 0.4), size.y - 40 * zoom)
		if frames[i].begins_with("at-"):
			p.drive_motion(&"", 0.0, false, float(frames[i].get_slice("-", 1)), {})
		elif frames[i].begins_with("co-"):
			p.drive_combo(float(frames[i].get_slice("-", 1)), [0.2, 0.56])
		elif frames[i].begins_with("cleave-"):
			p.drive_cleave(float(frames[i].get_slice("-", 1)))
		else:
			p.sample_frame(frames[i])
func _process(_d):
	n += 1
	if n == 30:
		root.get_texture().get_image().save_png(out)
		quit()
	return false
