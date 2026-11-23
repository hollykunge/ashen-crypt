extends SceneTree
## Native in-game renderer contact sheets: outfits, or all six attack poses.
const Hero = preload("res://scripts/cutout_hero.gd")

class Review extends Control:
	var entries := []
	var wardrobe := true
	var font: Font = preload("res://art/fonts/game.otf")
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size), Color("#ecdbbb"))
		draw_string(font,Vector2(25,43),"行装对照 · 同一人物 / 同一刀长" if wardrobe else "斩击六帧 · 共用同一把弯刀",HORIZONTAL_ALIGNMENT_LEFT,-1,29,Color("#302b26"))
		var cols := 4 if wardrobe else 3
		var width := 500.0 if wardrobe else 600.0
		for i in entries.size():
			var entry: Dictionary = entries[i]
			var x := (i % cols) * width
			var y := (i / cols) * 520.0 + 60.0
			draw_rect(Rect2(x+10,y+8,width-20,500),Color("#dcc59e"),false,1.0)
			draw_string(font,Vector2(x+25,y+43),entry.label,HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("#642d25"))
			draw_line(Vector2(x+25,y+465),Vector2(x+width-25,y+465),Color("#baa37e"),1.0)
			entry.actor.draw(self,Vector2(x+155,y+465),1.0,Color.WHITE)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var wardrobe := args.size() < 2 or args[1] != "blades"
	var output := SubViewport.new()
	output.size = Vector2i(2000 if wardrobe else 1800,1100)
	output.disable_3d = true
	output.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(output)
	var review := Review.new()
	review.wardrobe = wardrobe
	review.size = output.size
	output.add_child(review)
	var configs := []
	if wardrobe:
		for pose in ["ready","strike"]:
			for pair in [["cloth","布衣"],["leather","皮甲"],["chain","链甲"],["mixed","混搭"]]:
				configs.append([pair[0],pose,pair[1]+" · "+("备战" if pose=="ready" else "斩击")])
	else:
		for pair in [["ready","备战"],["combat-1","蓄力"],["combat-2","挥刀"],["strike","命中"],["combat-4","随挥"],["combat-5","收刀"]]:
			configs.append(["cloth",pair[0],pair[1]])
	for config in configs:
		var actor := Hero.new()
		review.add_child(actor)
		var style: String = config[0]
		var types := {"armor":"chain","gloves":"leather","greaves":"cloth","boots":"leather"} if style=="mixed" else {"armor":style,"gloves":style,"greaves":style,"boots":style}
		actor.dress({"form":"sword","armor_types":types})
		actor.fit(350.0/74.0,1.0)
		actor._set_painted_frame(config[1])
		review.entries.append({"actor":actor,"label":config[2]})
	for i in 4:
		await process_frame
		review.queue_redraw()
	RenderingServer.force_draw(false)
	if not args.is_empty(): output.get_texture().get_image().save_png(args[0])
	quit()
