extends SceneTree

# 开发用：用主角 3D 模型给上衣、护腕、护腿、靴子各渲一张图标（布衣、皮甲、链甲各一张），
# 存进 art/model-hero/icons/。装备格画的就是身上那件，染色在游戏里按同一个颜色乘上去。
# 改了模型（hero.glb）以后重跑：
#   godot --path mobile --script res://tests/_gear_icons.gd

const ModelHero = preload("res://scripts/model_hero.gd")
const OUT := "res://art/model-hero/icons/"
const RENDER := 1024
## 出图的最长边（像素）：装备格最大约 90 逻辑像素，高清屏 2 倍够用
const ICON := 192
## 游戏的装备槽 → 模型的槽；上衣连肩甲一起画
const SLOTS := {"armor": ["torso", "shoulder"], "gloves": ["arms"], "greaves": ["legs"], "boots": ["feet"]}
const TYPES := {"cloth": "peasant", "leather": "leather", "chain": "chain"}
## 每槽从哪个方向看（相机朝向角色的方向，角色朝 +Z、左手在 +X）
const VIEWS := {
	"armor": Vector3(-0.55, 0.12, 1.0),
	"gloves": Vector3(-1.0, 0.05, 0.35),
	"greaves": Vector3(-0.55, 0.08, 1.0),
	"boots": Vector3(-1.0, 0.25, 0.45),
}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.size = Vector2i(RENDER, RENDER)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	# 灯光和游戏里主角画布（cutout_hero.gd）一样
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#8a7d72")
	env.environment.ambient_light_energy = 0.55
	viewport.add_child(env)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.25
	key.light_color = Color("#fff1dd")
	viewport.add_child(key)
	key.transform = Transform3D.IDENTITY.looking_at(Vector3(3.0, -4.0, -2.5), Vector3.UP)
	var hero := ModelHero.new()
	viewport.add_child(hero)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.1
	viewport.add_child(camera)
	await process_frame
	hero.play("Idle_Loop", 0.0)
	hero.anim.seek(0.0, true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for slot: String in SLOTS:
		var dir: Vector3 = VIEWS[slot].normalized()
		var target := Vector3(0.0, 0.95, 0.0)
		camera.transform = Transform3D(Basis.looking_at(-dir, Vector3.UP), target + dir * 6.0)
		for type: String in TYPES:
			var wanted: Array = []
			for part_slot: String in SLOTS[slot]:
				var variant: String = TYPES[type]
				if part_slot == "shoulder" and variant == "peasant":
					continue
				wanted += ModelHero.SLOTS[part_slot][variant]
			for part: String in hero._meshes:
				hero._meshes[part].visible = part in wanted
				if part in wanted:
					hero.shape(part)
			for i in 3:
				await RenderingServer.frame_post_draw
			var image := viewport.get_texture().get_image()
			var used := image.get_used_rect()
			if used.size.x <= 0:
				push_error("%s %s 什么都没渲出来" % [slot, type])
				continue
			var pad := int(maxf(used.size.x, used.size.y) * 0.04)
			image = image.get_region(used.grow(pad).intersection(Rect2i(Vector2i.ZERO, image.get_size())))
			var scale := float(ICON) / maxf(image.get_width(), image.get_height())
			image.resize(maxi(1, roundi(image.get_width() * scale)), maxi(1, roundi(image.get_height() * scale)),
				Image.INTERPOLATE_LANCZOS)
			var path := OUT + "%s_%s.png" % [slot, type]
			image.save_png(ProjectSettings.globalize_path(path))
			print("写出 ", path, " ", image.get_size())
	quit()
