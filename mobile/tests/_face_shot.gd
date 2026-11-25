extends SceneTree

# 开发用：脸部近景对比。上排原模型、下排改过（body_shape.gd），各按正面、三分之一侧、正侧渲
#   godot --path mobile --script res://tests/_face_shot.gd -- <输出 png> [male|female]
const ModelHero = preload("res://scripts/model_hero.gd")
const BodyShape = preload("res://scripts/body_shape.gd")
const VIEWS := [0.0, 35.0, 90.0]   # 相机绕人物转的角度：0 正面
const SIZE := 520

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var gender: String = args[1] if args.size() > 1 else "male"
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#e8dcc0")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#8a7d72")
	env.environment.ambient_light_energy = 0.8
	viewport.add_child(env)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.34
	viewport.add_child(camera)
	var sheet := Image.create(SIZE * VIEWS.size(), SIZE * 2, false, Image.FORMAT_RGBA8)
	for row in 2:
		BodyShape.enabled = row == 1
		BodyShape._cache.clear()
		var hero := ModelHero.new(gender)
		hero.set_hull_outline(false)  # 游戏里只描外轮廓；模型自带的描边会把鼻孔等内部也描一圈
		hero.outfit.headgear = "none"
		hero.outfit.torso = "peasant"
		hero.apply_outfit()
		viewport.add_child(hero)
		await process_frame
		hero.play("Idle_Loop", 0.0)
		hero.anim.seek(0.0, true)
		var head := hero.skeleton.get_bone_global_pose(hero.skeleton.find_bone("Head")).origin + Vector3(0, 0.08, 0)
		for i in VIEWS.size():
			var dir := Vector3(sin(deg_to_rad(VIEWS[i])), 0.0, cos(deg_to_rad(VIEWS[i])))
			camera.transform = Transform3D(Basis.looking_at(-dir, Vector3.UP), head + dir * 3.0)
			# 主光从相机左上方
			for n in viewport.get_children():
				if n is DirectionalLight3D: n.free()
			for spec in [[1.2, Color("#fff1dd"), Vector3(-0.6, 0.7, 1.0)], [0.45, Color("#d8e0ff"), Vector3(0.8, 0.1, 0.6)], [0.9, Color("#ffe2b0"), Vector3(0.3, 0.4, -1.0)]]:
				var light := DirectionalLight3D.new()
				light.light_energy = spec[0]
				light.light_color = spec[1]
				viewport.add_child(light)
				var from: Vector3 = Basis.looking_at(-dir, Vector3.UP) * spec[2]
				light.transform = Transform3D.IDENTITY.looking_at(-from, Vector3.UP)
			for k in 3:
				await RenderingServer.frame_post_draw
			var img := viewport.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(img, Rect2i(0, 0, SIZE, SIZE), Vector2i(i * SIZE, row * SIZE))
		hero.free()
		await process_frame
	sheet.save_png(args[0])
	print("SAVED")
	quit()
