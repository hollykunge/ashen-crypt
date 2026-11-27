extends SceneTree

# 开发用：男女主角各渲一张半身头像，存成 art/model-hero/portrait.png、portrait_female.png。
# 选角、角色页、战斗头像都用它。直接用行装页那块画布（cutout_hero.gd 的 present_outfit），
# 角度、打光、墨线描边都和行装页一样；新角色的样子（布衣、斗笠、刀）。
# 改了模型以后重跑：
#   godot --path mobile --script res://tests/_portraits.gd

const CutoutHero = preload("res://scripts/cutout_hero.gd")
const Appearance = preload("res://scripts/appearance.gd")
const OUT := {"male": "res://art/model-hero/portrait.png", "female": "res://art/model-hero/portrait_female.png"}
const SIZE := Vector2i(230, 300)
## 取景：从人物最高处往下取多少（以人物高度计）
const CROP := 0.5

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for gender: String in OUT:
		var actor := CutoutHero.new()
		root.add_child(actor)
		actor.dress(Appearance.build({}, {}, "sword", gender))
		actor.present_outfit()
		actor.fit(16.0, 1.0)
		for i in 4:
			await RenderingServer.frame_post_draw
		# 男主角拿刀时画的是皮影主角（puppet_hero.gd）那块画布
		var image: Image = (actor.puppet.viewport.get_texture() if actor._puppet_on else actor._texture).get_image()
		var used := image.get_used_rect()
		var height := int(used.size.y * CROP)
		var width := int(height * float(SIZE.x) / SIZE.y)
		# 横向按头放在中间：取最高处那几行像素的中心
		var top := image.get_region(Rect2i(used.position.x, used.position.y + int(height * 0.25), used.size.x, int(height * 0.1)))
		var head_x := used.position.x + top.get_used_rect().get_center().x
		var head_top := used.position.y
		if actor._puppet_on:
			# 皮影主角的兵器可能比头高（女将竖端的长刀），最高处不一定是头：按骨骼里脖子的位置找头、按身高取景
			var real: float = actor.puppet._height * actor.puppet._density
			height = int(real * CROP)
			width = int(height * float(SIZE.x) / SIZE.y)
			head_x = int(actor.puppet.rig._bones.neck.get_global_transform().origin.x)
			head_top = int(CutoutHero.FEET.y * real - real)
		var rect := Rect2i(head_x - width / 2, head_top - int(height * 0.07), width, height)
		var crop := Image.create(width, height, false, Image.FORMAT_RGBA8)
		image.convert(Image.FORMAT_RGBA8)
		crop.blit_rect(image, rect, Vector2i.ZERO)
		crop.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
		crop.save_png(ProjectSettings.globalize_path(OUT[gender]))
		print("写出 ", OUT[gender], " ", crop.get_size())
		actor.free()
		await process_frame
	quit()
