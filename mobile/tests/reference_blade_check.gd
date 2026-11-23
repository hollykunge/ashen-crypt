extends SceneTree
const Hero = preload("res://scripts/cutout_hero.gd")
const Blade = preload("res://scripts/reference_blade.gd")
const RingDao = preload("res://scripts/ring_dao.gd")
const HEADS := {"idle":Vector2i(302,111),"ready":Vector2i(348,165),"strike":Vector2i(405,180),
	"combat-1":Vector2i(391,174),"combat-2":Vector2i(395,174),"combat-4":Vector2i(380,173),
	"combat-5":Vector2i(330,170),"combat-6":Vector2i(253,170),"combat-7":Vector2i(308,170)}
var failures := 0
var poses := 0

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var actor := Hero.new()
	root.add_child(actor)
	actor.fit(2.0,1.0)
	var dao_poses := _check_modular_dao(actor)
	var canonical: Texture2D = actor.painted_blade.texture
	for style in ["cloth","leather","chain","mixed"]:
		var types := {"armor":"chain","gloves":"leather","greaves":"cloth","boots":"leather"} if style=="mixed" else {"armor":style,"gloves":style,"greaves":style,"boots":style}
		actor.dress({"form":"sword","armor_types":types})
		for frame in Blade.POSES:
			actor._set_painted_frame(frame)
			var blade: Polygon2D = actor.painted_blade
			var root_point: Vector2 = blade.transform * Vector2.ZERO
			var tip: Vector2 = blade.transform * blade.polygon[4]
			_check(blade.visible and blade.texture==canonical,"换装或换帧改变了共用刀刃: "+style+"/"+frame)
			_check(is_equal_approx(root_point.distance_to(tip),190.0),"实际渲染刀长发生变化: "+style+"/"+frame)
			_check(root_point.is_equal_approx(Blade.POSES[frame][0]),"刀根没有对准原握柄: "+frame)
			for vertex in blade.polygon:
				_check(Rect2(0,0,800,640).has_point(blade.transform*vertex),"刀尖超出人物画布: "+frame)
			poses += 1
	for frame in HEADS:
		var original := load("res://art/reference-hero/frames/"+frame+".png").get_image() as Image
		var body := load("res://art/reference-hero/bodies/cloth/"+frame+".png").get_image() as Image
		var region := Rect2i(HEADS[frame]-Vector2i(45,60),Vector2i(90,110))
		var identical := true
		for y in range(region.position.y,region.end.y):
			for x in range(region.position.x,region.end.x):
				if original.get_pixel(x,y)!=body.get_pixel(x,y): identical=false
		_check(identical,"刀刃修复改变了已经确认的脸和发髻: "+frame)
	actor.queue_free()
	await process_frame
	print("独立整刀：%d 个衣装/姿势组合；旧版刀刃：%d 个组合，%d 项失败" % [dao_poses,poses,failures])
	quit(1 if failures else 0)

func _check_modular_dao(actor) -> int:
	var frames := ["idle", "ready", "strike"]
	for motion in ["walk", "run", "combat"]:
		for i in 8:
			frames.append("%s-%d" % [motion, i])
	var total := 0
	for types in [{}, {"armor": "cloth"}]:
		actor.dress({"form":"sword", "gender":"male", "armed":true, "armor_types":types})
		for frame in frames:
			actor._set_painted_frame(frame)
			var base = actor.male_base
			var sword: Sprite2D = base.sword
			base._process(1.0/30.0)
			var model: Transform2D = base.transform * base._relative(sword)
			var tip := model * (RingDao.TIP + sword.offset)
			var grip := model * (RingDao.GRIP + sword.offset)
			_check(base.visible and sword.visible and sword.texture == RingDao.ART, frame + " 没有使用同一张整刀图")
			_check(not sword.region_enabled and sword.offset == -RingDao.GRIP, frame + " 裁切了武器或改变了握点")
			_check(is_equal_approx(model.x.length(), RingDao.MODEL_SCALE)
				and is_equal_approx(model.y.length(), RingDao.MODEL_SCALE)
				and is_zero_approx(model.x.dot(model.y)) and model.determinant() > 0, frame + " 拉伸或扭曲了整刀")
			_check(is_equal_approx(grip.distance_to(tip), RingDao.GRIP.distance_to(RingDao.TIP) * RingDao.MODEL_SCALE),
				frame + " 改变了从刀柄到刀尖的距离")
			total += 1
	return total
