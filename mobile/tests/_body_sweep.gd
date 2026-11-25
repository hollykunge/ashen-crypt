extends SceneTree

# 开发用：主角体型对比图。上排原模型、下排改过体型，各按正面、三分之一侧、正侧、背面渲一张
#   godot --path mobile --script res://tests/_body_sweep.gd -- <输出 png> [male|female] [cloth|leather|chain]
const CutoutHero = preload("res://scripts/cutout_hero.gd")
const Appearance = preload("res://scripts/appearance.gd")
const BodyShape = preload("res://scripts/body_shape.gd")
const VIEWS := [-90.0, -35.0, 0.001, 90.0]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var gender: String = args[1] if args.size() > 1 else "male"
	var armor: String = args[2] if args.size() > 2 else "cloth"
	var sheet: Image
	for row in 2:
		BodyShape.enabled = row == 1
		var actor := CutoutHero.new()
		root.add_child(actor)
		var look := Appearance.build({}, {}, "sword", gender)
		var types := {}
		for slot in ["armor", "gloves", "greaves", "boots"]:
			types[slot] = armor
		look["armor_types"] = types
		actor.dress(look)
		actor.present_outfit()
		actor.fit(9.0, 1.0)
		for i in VIEWS.size():
			actor._turn(VIEWS[i])
			for k in 4:
				await RenderingServer.frame_post_draw
			var img: Image = actor._texture.get_image()
			img = img.get_region(Rect2i(int(img.get_width() * 0.24), int(img.get_height() * 0.08), int(img.get_width() * 0.34), int(img.get_height() * 0.9)))
			img.convert(Image.FORMAT_RGBA8)
			if sheet == null:
				sheet = Image.create(img.get_width() * VIEWS.size(), img.get_height() * 2, false, Image.FORMAT_RGBA8)
				sheet.fill(Color("#e8dcc0"))
			sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(i * img.get_width(), row * img.get_height()))
		actor.free()
		await process_frame
	sheet.save_png(args[0])
	print("SAVED")
	quit()
