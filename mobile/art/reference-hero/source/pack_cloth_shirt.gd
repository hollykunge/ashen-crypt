extends SceneTree
## Pack the two painted indigo panels onto the unchanged male key-pose coordinates.
const MaleBase = preload("res://scripts/male_base.gd")
const INPUT := "res://art/reference-hero/source/cloth-shirt-keys.png"
const REFERENCE_CROP := Rect2i(480, 90, 1200, 560)

func _initialize() -> void:
	var painting := Image.load_from_file(INPUT)
	var output := ProjectSettings.globalize_path(MaleBase.SHIRT_ROOT)
	if painting == null or DirAccess.make_dir_recursive_absolute(output) != OK:
		quit(1)
		return
	var ratio := Vector2(painting.get_size()) / Vector2(REFERENCE_CROP.size)
	for pose: String in MaleBase.SHIRT_REGIONS:
		var bounds: Rect2i = MaleBase.SHIRT_REGIONS[pose]
		var origin := (Vector2(bounds.position - REFERENCE_CROP.position) * ratio).round()
		var size := (Vector2(bounds.size) * ratio).round()
		var panel := painting.get_region(Rect2i(Vector2i(origin), Vector2i(size)))
		for y in panel.get_height():
			for x in panel.get_width():
				var pixel := panel.get_pixel(x, y)
				# Pigment separation also preserves the unpainted gap around the near fist.
				var blue := pixel.b8 - pixel.r8
				var coverage := smoothstep(-3.0, 5.0, blue)
				if pixel.a8 < 8 or coverage == 0.0:
					panel.set_pixel(x, y, Color.TRANSPARENT)
				else:
					pixel.a = minf(1.0, pixel.a * 255.0 / 253.0) * coverage
					panel.set_pixel(x, y, pixel)
		panel.fix_alpha_edges()
		panel.resize(bounds.size.x, bounds.size.y, Image.INTERPOLATE_LANCZOS)
		if panel.save_png(output.path_join(pose + ".png")) != OK:
			quit(1)
			return
	quit(0)
