extends SceneTree

# 开发用：把主角手里那些 3D 兵器（weapons.glb）各渲一张图标，存进 art/model-hero/icons/weapon_<零件名>.png。
# 兵器格按 ModelHero.weapon_part 挑同一件来画，图标和人物手里拿的就是同一把。
# 改了兵器模型（weapons.glb）以后重跑：
#   godot --path mobile --script res://tests/_weapon_icons.gd

const ModelHero = preload("res://scripts/model_hero.gd")
const OUT := "res://art/model-hero/icons/"
const RENDER := 1024
const ICON := 192
## 每种形制拿一件出来、挑哪些零件：[形制, 设计]
const PIECES := [
	["sword", {"blade": "jian"}], ["sword", {"blade": "qixing"}], ["sword", {"blade": "bolang"}],
	["jian", {"blade": "jian"}], ["jian", {"blade": "qixing"}], ["jian", {"blade": "bolang"}],
	["spear", {"head": "leaf"}], ["spear", {"head": "snake"}], ["spear", {"head": "ji"}],
	["bow", {"head": "fanqu"}], ["bow", {"head": "chang"}],
]
## 刀剑枪斜放、刃尖朝右上；弓斜得少一点
const TILT := {"bow": -30.0}
const TILT_DEFAULT := -45.0

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
	# 灯光和 _gear_icons.gd、游戏里主角画布一样
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
	key.transform = Transform3D.IDENTITY.looking_at(Vector3(-2.0, -3.0, -4.0), Vector3.UP)
	# 借主角模型的卡通材质和描边：拿起兵器后把兵器从手上摘下来单独摆
	var hero := ModelHero.new()
	viewport.add_child(hero)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	viewport.add_child(camera)
	await process_frame
	# 停掉动作：不然每帧 apply_fists 会把刀剑摆回手里的握法
	hero.anim.active = false
	hero.anim.mixer_applied.disconnect(hero.apply_fists)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var done := {}
	for piece: Array in PIECES:
		var form: String = piece[0]
		var part := ModelHero.weapon_part(form, piece[1])
		if done.has(part):
			continue
		done[part] = true
		hero.hold(form, piece[1])
		var kit: Node3D = hero._kit
		kit.get_parent().remove_child(kit)
		viewport.add_child(kit)
		kit.transform = Transform3D(Basis(Vector3.BACK, deg_to_rad(TILT.get(form, TILT_DEFAULT))), Vector3.ZERO)
		hero.visible = false
		var box := AABB()
		var first := true
		for name: String in hero._kit_parts:
			var mesh: MeshInstance3D = hero._kit_parts[name]
			if not mesh.visible:
				continue
			var local := mesh.global_transform * mesh.get_aabb()
			box = local if first else box.merge(local)
			first = false
		camera.size = maxf(box.size.x, box.size.y) * 1.15
		var dir := Vector3(0.18, 0.12, 1.0).normalized()
		camera.transform = Transform3D(Basis.looking_at(-dir, Vector3.UP), box.get_center() + dir * 10.0)
		for i in 3:
			await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		var used := image.get_used_rect()
		if used.size.x <= 0:
			push_error("%s 什么都没渲出来" % part)
			continue
		var pad := int(maxf(used.size.x, used.size.y) * 0.04)
		image = image.get_region(used.grow(pad).intersection(Rect2i(Vector2i.ZERO, image.get_size())))
		var scale := float(ICON) / maxf(image.get_width(), image.get_height())
		image.resize(maxi(1, roundi(image.get_width() * scale)), maxi(1, roundi(image.get_height() * scale)),
			Image.INTERPOLATE_LANCZOS)
		var path := OUT + "weapon_%s.png" % part
		image.save_png(ProjectSettings.globalize_path(path))
		print("写出 ", path, " ", image.get_size())
	quit()
