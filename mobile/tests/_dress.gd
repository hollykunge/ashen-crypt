extends SceneTree

# 开发用：按指定五行给六个槽位各打一件装备、穿上，再截图，用来核对装备外观与动作。
#
# 用法 godot --path mobile --script res://tests/_dress.gd -- <输出> [五行] [兵器] [模式] [帧数] [动作] [进度] [male|female]
#   模式 farm   挂机画面
#   模式 bag    行装页
#   模式 boss   层主战，站着不动
#   模式 fight  层主战，持续前压并出招
#   模式 stick  层主战，并按出摇杆
#   模式 pose   层主战，把角色定格在 [动作] 的 [进度] 上，例如 attack 0.4
# 例 ... -- shot.png huo hammer pose 40 attack 0.45

const Main = preload("res://main.tscn")
const Gear = preload("res://scripts/gear.gd")
const PURE := {"jin": "geng", "mu": "jia", "shui": "ren", "huo": "bing", "tu": "wu"}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://dress.png"
	var element: String = args[1] if args.size() > 1 else "huo"
	var form: String = args[2] if args.size() > 2 else "long_blade"
	var mode: String = args[3] if args.size() > 3 else "farm"
	var settle: int = int(args[4]) if args.size() > 4 else 60
	var clip: String = args[5] if args.size() > 5 else "attack"
	var phase: float = float(args[6]) if args.size() > 6 else 0.4
	var gender: String = args[7] if args.size() > 7 else "male"
	var save := "user://dress-%s-%s.json" % [element, form]
	if FileAccess.file_exists(save):
		DirAccess.remove_absolute(save)
	var game = Main.instantiate()
	game.profile.save_path = save
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.profile.create_character({"gender": gender, "day_stem": "geng", "month_branch": "mao",
		"hour_branch": "si", "origin": "commoner"})
	var material: String = PURE[element]
	game.profile.collect(material, 240)
	for slot in Gear.SLOTS:
		var draft := Gear.new_draft()
		draft.slot = slot
		draft.weapon_form = form
		draft.materials = {material: 6}
		if not game.profile.craft(draft):
			printerr("打造失败：%s %s" % [slot, game.profile.craft_error(draft)])
			continue
		game.profile.toggle_equip(draft.uid)
	game._enter_farm()
	if mode == "bag":
		game._open_forge()
	elif mode != "farm":
		game.challenge_button.pressed.emit()
		# 进层先过本层告示；截图要的是战斗，直接接敕。
		if game.state == &"place_notice":
			game._accept_edict()
	for frame in range(settle):
		game._physics_process(1.0 / 60.0)
		if mode == "stick" and frame == settle - 18:
			game._fit_stick()
			game.stick.begin(-1, Vector2(96, 512))
			game.stick.drag(-1, Vector2(132, 470))
		elif mode == "fight":
			game.touches = {0: &"forward", 1: &"attack"}
			if frame % 47 == 20:
				game.run.skill()
			if frame % 61 == 33:
				game.run.tactic()
		await process_frame
	if mode == "pose":
		game.run.motion = StringName(clip)
		game.run.motion_duration = 1.0
		game.run.motion_time = phase
		game.field.queue_redraw()
		await process_frame
		await process_frame
	var image := root.get_texture().get_image()
	if image.save_png(out) != OK:
		printerr("截图写入失败：" + out)
		quit(1)
		return
	print("截图已存：%s  %s · %s · %s" % [out, element, form, mode])
	quit(0)
