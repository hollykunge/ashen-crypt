extends SceneTree
const Frames = preload("res://scripts/reference_frames.gd")
var failures := 0
var checked := 0

func _initialize() -> void:
	var source := Image.load_from_file("res://art/reference-hero/source/approved.jpg")
	for entry in [["idle", Vector2i(175, 554)], ["ready", Vector2i(500, 554)], ["strike", Vector2i(860, 554)]]:
		var frame := Image.load_from_file(Frames.ROOT + entry[0] + ".png")
		var shift: Vector2i = Vector2i(Frames.FOOT) - entry[1]
		for y in frame.get_height():
			for x in frame.get_width():
				var pixel := frame.get_pixel(x, y)
				if pixel.a < 0.99: continue
				var original := source.get_pixelv(Vector2i(x, y) - shift)
				checked += 1
				if not Vector3(pixel.r, pixel.g, pixel.b).is_equal_approx(Vector3(original.r, original.g, original.b)):
					failures += 1
	var ready := Image.load_from_file(Frames.ROOT + "ready.png")
	if ready.get_pixel(300, 481).a > 0.01:
		printerr("备战两腿之间残留背景")
		failures += 1
	if ready.get_pixel(300, 551).a > 0.01:
		printerr("备战脚下残留概念图地面线")
		failures += 1
	var idle := Image.load_from_file(Frames.ROOT + "idle.png")
	if idle.get_pixel(225, 551).a < 0.99:
		printerr("原图站姿的左靴后跟被裁掉")
		failures += 1
	var names := ["idle", "ready", "strike"]
	for clip in ["walk", "run", "combat"]:
		for i in 8: names.append("%s-%d" % [clip, i])
	for name in names:
		var base := Image.load_from_file(Frames.ROOT + name + ".png")
		var bounds := base.get_used_rect()
		for style in ["leather", "chain"]:
			var costume := Image.load_from_file("res://art/reference-hero/costumes/%s/%s.png" % [style, name])
			if costume.get_size() != base.get_size():
				printerr("换装画布尺寸不一致: " + style + "/" + name)
				failures += 1
			for y in range(bounds.position.y, bounds.position.y + floori(bounds.size.y * 0.25)):
				for x in range(bounds.position.x, bounds.end.x):
					if base.get_pixel(x, y) != costume.get_pixel(x, y):
						printerr("换装改变了原来的头部: " + style + "/" + name)
						failures += 1
	if Frames.frame_for(&"", 0.0, 0.36, false, []) != "walk-4" or Frames.frame_for(&"", 0.0, 0.72, false, []) != "walk-0":
		printerr("行走未按完整左右步态循环")
		failures += 1
	for cue in [0.20, 0.56]:
		if Frames.attack_frame(cue, [0.20, 0.56]) != "strike":
			printerr("原图斩击姿势未对准命中时刻")
			failures += 1
	print("原图核对：%d 个不透明像素，%d 项不一致" % [checked, failures])
	quit(1 if failures else 0)
