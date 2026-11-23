extends SceneTree
## Render the approved sheet above the same three poses through the actual in-game hero renderer.
const Hero = preload("res://scripts/cutout_hero.gd")

class Review extends Control:
	var original: Texture2D
	var actors := []
	var font: Font = preload("res://art/fonts/game.otf")
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 1280), Color("#e8d0aa"))
		draw_texture(original, Vector2.ZERO)
		draw_line(Vector2(20, 640), Vector2(1260, 640), Color("#695642"), 2)
		draw_string(font, Vector2(24, 682), "游戏中实际渲染 · 布衣刀客", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("#302b26"))
		var feet := [Vector2(175, 1194), Vector2(500, 1194), Vector2(860, 1194)]
		for i in actors.size():
			actors[i].draw(self, feet[i], 1.0, Color.WHITE)
		for pair in [[150, "站姿"], [475, "备战"], [880, "斩击"]]:
			draw_string(font, Vector2(pair[0], 1240), pair[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("#302b26"))

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var output := SubViewport.new()
	output.size = Vector2i(1280, 1280)
	output.disable_3d = true
	output.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(output)
	var review := Review.new()
	review.original = ImageTexture.create_from_image(Image.load_from_file("res://art/reference-hero/source/approved.jpg"))
	output.add_child(review)
	for motion in [&"idle", &"", &"strike"]:
		var actor := Hero.new()
		review.add_child(actor)
		actor.dress({"form": "sword", "armor_types": {"armor": "cloth", "gloves": "cloth", "boots": "cloth"}})
		actor.fit(500.0 / 74.0, 1.0)
		actor.drive(motion, 0.0, 0.0, false, [0.20, 0.56])
		review.actors.append(actor)
	for i in 4:
		await process_frame
		review.queue_redraw()
	RenderingServer.force_draw(false)
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		output.get_texture().get_image().save_png(args[0])
	quit()
