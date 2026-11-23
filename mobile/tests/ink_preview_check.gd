extends SceneTree
## Headless integration checks; optionally captures real rendered screens with -- <directory>.
var failures := 0
var captures := ""

func _initialize() -> void:
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec", 1000.0)
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		captures = args[0]
		DirAccess.make_dir_recursive_absolute(captures)
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr(message)

func _covers(sprite: Sprite2D, point: Vector2) -> bool:
	var uv := Vector2i((sprite.to_local(point) - sprite.get_rect().position).floor())
	var pixels := sprite.texture.get_image()
	return Rect2i(Vector2i.ZERO, pixels.get_size()).has_point(uv) and pixels.get_pixelv(uv).a > 0.85

func _shot(name: String) -> void:
	if captures.is_empty():
		return
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(captures + "/" + name + ".png")

func _process(_delta: float) -> bool:
	if not captures.is_empty():
		_clear_tooltips(root)
	return false

func _clear_tooltips(node: Node) -> void:
	if node is Control:
		node.tooltip_text = ""
	for child in node.get_children():
		_clear_tooltips(child)

func _run() -> void:
	var preview = load("res://ink_preview.tscn").instantiate()
	root.add_child(preview)
	await process_frame
	await process_frame
	_check(preview.outfits.size() == 3 and preview.weapons.has_all(["jian","sword","bow","spear"]), "试演提供三套衣装和全部四种武器")
	var actor = preview.game.field.cutout
	_check(preview.game.profile.loadout().entries.is_empty() and actor.male_base.visible and not actor.male_base.sword.visible,
		"底身起始状态五栏全空，显示独立的男性空手原画")
	for pose in ["idle", "ready", "strike", "walk-7", "run-3", "combat-5"]:
		actor._set_painted_frame(pose)
		_check(actor.male_base._sprites.torso[0].texture != null and actor.male_base._sprites.hand[0].visible
			and actor.painted.texture == null and not actor.painted_blade.visible, "底身动作残留旧衣装或兵器 " + pose)
	preview._set_weapon("sword")
	_check(actor.male_base.visible and actor.male_base.sword.visible and preview.game.profile.loadout().entries.size() == 1,
		"只拿刀仍然使用同一底身")
	for pose in ["ready", "strike"]:
		actor._set_painted_frame(pose)
		var body: Texture2D = actor.male_base._sprites.torso[0].texture
		var body_transform: Transform2D = actor.male_base.transform
		var grip: Transform2D = actor.male_base.sword.transform
		preview.piece_buttons.armor.pressed.emit()
		actor._set_painted_frame(pose)
		_check(preview.game.profile.equipped("armor") == preview.outfits.cloth.armor
			and preview.game.profile.loadout().entries.size() == 2, "只穿布衣上衣并保留刀")
		_check(actor.male_base.is_visible_in_tree() and actor.male_base._worn.has("armor")
			and actor.male_base._sprites.torso[0].texture != body
			and actor.male_base._worn.armor.ends_with("/cloth"),
			"上衣整件替换躯干和两侧上臂 " + pose)
		_check(actor.male_base.transform == body_transform
			and actor.male_base.sword.transform == grip
			and actor.male_base.sword.visible, "穿衣保持原身和持刀坐标 " + pose)
		var base = actor.male_base
		_check(base.grip_hand.visible and not base._sprites.hand[0].visible
			and base.sword.get_parent().get_parent() == base._bones.arm_near_hand
			and base.grip_hand.z_index > base.sword.z_index, "握刀换成拳头，拳头压在刀柄上 " + pose)
		# 刀柄握点落在拳头里
		var held: Vector2 = base.sword.to_global(base.RingDao.GRIP + base.sword.offset)
		_check(_covers(base.grip_hand, held), "握点在拳头里 " + pose)
		preview.piece_buttons.armor.pressed.emit()
		actor._set_painted_frame(pose)
		_check(not actor.male_base._worn.has("armor") and actor.male_base._sprites.torso[0].texture == body
			and preview.game.profile.loadout().entries.size() == 1, "脱衣只清除上衣 " + pose)
	preview._set_style("base")
	for pose in ["ready", "strike"]:
		actor._set_painted_frame(pose)
		_check(not actor.male_base.sword.visible and not actor.male_base.grip_hand.visible
			and preview.game.profile.loadout().entries.is_empty(), "卸下武器后恢复空手 " + pose)
	_check(actor.male_base._sprites.hand[0].visible, "卸刀后独立空手回到原来的腕关节")
	_check_puppet(actor.male_base)
	var combo_cues: Array = preview.game.run.attack_cues()
	var base = actor.male_base
	base.drive_combo(combo_cues[0],combo_cues)
	var first_pose: Dictionary = base._pose_attack(base.drive_t)
	base.drive_combo(combo_cues[1],combo_cues)
	var finish_pose: Dictionary = base._pose_attack(base.drive_t)
	_check(finish_pose.arm_near_up - first_pose.arm_near_up > 40.0 and
		is_equal_approx(first_pose.step,finish_pose.step), "连招第二击从低处回挑，前脚保持落地")
	base.sample_frame("ready")
	preview._set_action("bag")
	_check(preview.game.forge.armory.stage.actor.male_base.visible, "行装空栏时使用同一底身")
	preview._set_style("cloth")
	_check(actor.male_base.visible and actor.painted.texture == null, "穿回布衣可恢复现有衣装")
	preview.action_buttons.cycle.pressed.emit()
	_check(actor.male_base.is_visible_in_tree() and actor.male_base._worn.has("armor") and actor.male_base.sword.visible,
		"从衣装试演进入刀客连演时使用关节人物")
	preview._set_style("cloth")
	var cloth_uid: String = preview.outfits.cloth.armor
	var profile = preview.game.profile
	var original_stats: Dictionary = profile.describe(profile.item(cloth_uid)).stats
	_check(profile.dye_item(cloth_uid, "靛蓝"), "布衣可单独染色")
	preview._equip()
	_check(actor.male_base._sprites.torso[0].modulate != Color.WHITE and actor.male_base._sprites.torso[0].modulate == actor.male_base._sprites.upper_arm[1].modulate, "上衣和近侧上臂使用同一染色")
	var reloaded = profile.get_script().new(profile.save_path)
	reloaded.load_profile()
	_check(reloaded.item(cloth_uid).dye == "靛蓝" and reloaded.describe(reloaded.item(cloth_uid)).stats == original_stats, "读档保留染色及原有属性")
	_check(not profile.dye_item(preview.weapons.jian,"松绿") and profile.dye_item(cloth_uid,"本色"), "仅衣装可染色并能恢复本色")
	preview._equip()
	var identity: Texture2D = actor.rig._sprites.head[0].texture
	var skin: Texture2D = actor.rig._sprites.hand[0].texture
	var cloth: Texture2D = actor.rig._sprites.torso[0].texture

	_check_wardrobe_frames(actor)
	for style in ["cloth", "leather", "chain", "mixed"]:
		preview._set_style(style)
		for weapon in ["sword", "jian", "spear", "bow"]:
			preview._set_weapon(weapon)
			_check(actor.rig._sprites.head[0].texture == identity, "换装不改变头部")
			_check(actor.rig._sprites.hand[0].texture == skin, "换装不改变手部")
			_check(actor.form == weapon, "试演兵器同步到角色")
		_check(style == "cloth" or actor.rig._sprites.torso[0].texture != cloth, "护甲外观实际替换贴图")
		preview._set_weapon("sword")
		preview._set_action("ready")
		for frame in 20:
			await process_frame
		_shot("outfit-" + style)
		if style == "leather":
			preview.action_buttons.cycle.pressed.emit()
			_check(actor.male_base.is_visible_in_tree() and preview.style == "leather", "整套皮甲连演保持当前装束和关节人物")
			for slot in ["gloves", "greaves", "boots"]:
				_check(actor.male_base._worn.get(slot, "").ends_with("/leather"), "双侧护具可见 " + slot)
		_check(actor.painted.visible and not actor.rig.visible, "刀客使用整帧人物，旧拆件不参与绘制")
		preview.action_buttons.cleave.pressed.emit()
		_check(preview.style == style and preview.game.run.motion == &"cleave","重劈保留当前衣装 "+style)
		for phase in [0.1,0.38,0.5,0.8]:
			actor.drive(&"cleave",phase,0.0,false,[])
			_check(actor.male_base.visible and actor.painted.texture == null and actor.male_base.sword.is_visible_in_tree(), "重劈使用原骨架和武器")
			for slot in ["gloves", "greaves", "boots"]:
				_check(actor.male_base._worn.get(slot, "") == actor.male_base.PARTS + actor._look.armor_types[slot],"重劈保留独立护具 "+slot)
	preview._set_style("cloth")
	for slot in preview.Gear.ARMOR_TYPE_SLOTS:
		var before: Dictionary = preview.game.profile.state.equipped.duplicate()
		preview.piece_buttons[slot].pressed.emit()
		for other in before:
			var changed: bool = before[other] != preview.game.profile.equipped(other)
			_check(changed == (other == slot), "单件替换波及其他装备 " + slot + "/" + other)
		_check(actor._look.armor_types[slot] == "leather", "战场接收单件试穿 " + slot)
		for tick in 3:
			await process_frame
		_shot("piece-" + slot)
		preview._set_style("cloth")
	for action in ["idle", "strike", "walk", "run", "attack", "attack_slow", "retreat", "hurt", "skill"]:
		preview._set_action(action)
		for frame in 20:
			await process_frame
		if action in ["retreat", "hurt", "skill"]:
			_check(actor.painted_frame in ["combat-6", "combat-7", "ready"], "特殊动作显示整帧姿势")
		if action in ["idle", "strike"]:
			_check(actor.painted_frame == action, "原图定格姿势实际出现在游戏画布")
		_shot("action-" + action)
	preview._set_action("auto")
	for frame in 50:
		await process_frame
	_check(preview.game.farm_seconds > 0.0, "实战模式推进真实战斗")
	_shot("combat")
	preview._set_action("bag")
	for frame in 5:
		await process_frame
	_check(preview.game.state == &"forge", "试演进入实际行装页")
	_check(preview.game.forge.armory.outfit_slots.keys().size() == 5, "行装只显示五个装备部位")
	_shot("inventory")
	var armory = preview.game.forge.armory
	var worn: Dictionary = preview.game.profile.state.equipped.duplicate()
	for slot in ["greaves", "boots"]:
		var other := "boots" if slot == "greaves" else "greaves"
		armory.inspect(preview.outfits.chain[slot])
		var tried: Dictionary = armory.stage.actor._look.armor_types
		_check(tried[slot] == "chain" and tried[other] == "cloth", "行装可单独试穿 " + slot)
		_check(preview.game.profile.state.equipped == worn, "试穿不写入穿戴栏 " + slot)
	preview.game.forge._select_tab(false)
	for frame in 5:
		await process_frame
	_shot("forge")
	preview.game._show_title()
	for frame in 5:
		await process_frame
	_shot("title")
	preview.game._show_roster()
	for frame in 5:
		await process_frame
	_shot("roster")
	preview.game._create_in_slot(1)
	for frame in 5:
		await process_frame
	_shot("creator")
	var save: String = preview.save_path
	preview.queue_free()
	await process_frame
	_check(not FileAccess.file_exists(save), "试演关闭后移除临时角色存档")
	print("手绘试演：%d 项失败" % failures)
	quit(1 if failures else 0)

func _check_puppet(base) -> void:
	var b: Dictionary = base._bones
	for part in ["upper_arm", "forearm", "thigh", "shin", "foot"]:
		# 远侧肢体复用近侧贴图（同一张原画），只压暗做纵深
		var near_sprite: Sprite2D = base._sprites[part][1]
		var far_sprite: Sprite2D = base._sprites[part][0]
		_check(far_sprite.texture != null and far_sprite.has_meta("far") and far_sprite.modulate.v < near_sprite.modulate.v,
			"远侧肢体压暗 " + part)
	_check(b.neck.get_parent() == b.torso and b.torso.get_parent() == b.hips, "头颈、躯干和胯共用骨架")
	for side in ["near","far"]:
		var shoulder: Node2D = b["arm_"+side+"_up"]
		var elbow: Node2D = b["arm_"+side+"_lo"]
		var wrist: Node2D = b["arm_"+side+"_hand"]
		var hip: Node2D = b["leg_"+side+"_up"]
		var knee: Node2D = b["leg_"+side+"_lo"]
		var ankle: Node2D = b["foot_"+side]
		_check(shoulder.get_parent()==b.torso and elbow.get_parent()==shoulder and wrist.get_parent()==elbow,
			"上臂、下臂、手逐级相连 "+side)
		_check(hip.get_parent()==b.hips and knee.get_parent()==hip and ankle.get_parent()==knee,
			"大腿、小腿和独立足部逐级相连 "+side)
		var lengths := Vector2(elbow.position.length(),ankle.position.length())
		for pose in ["idle","ready","walk-3","run-6","combat-1","strike","combat-5"]:
			base.sample_frame(pose)
			for tick in 12:
				base._process(1.0/30.0)
			_check(is_equal_approx(base._relative(shoulder).origin.distance_to(base._relative(elbow).origin),lengths.x)
				and is_equal_approx(base._relative(knee).origin.distance_to(base._relative(ankle).origin),lengths.y),
				"动作中骨长稳定 "+side+"/"+pose)

func _check_wardrobe_frames(actor) -> void:
	var poses := ["idle", "ready", "strike"]
	for prefix in ["walk-", "run-", "combat-"]:
		for i in 8:
			poses.append(prefix + str(i))
	for pose in poses:
		var mask: Image = load(actor.ReferenceFrames.WARDROBE + pose + "-slots.png").get_image()
		var body: Image = actor.ReferenceFrames.texture(pose).get_image()
		var coverage := Vector3i.ZERO
		for y in range(0, body.get_height(), 8):
			for x in range(0, body.get_width(), 8):
				if body.get_pixel(x, y).a < 0.9:
					continue
				var pixel := mask.get_pixel(x, y)
				coverage += Vector3i(int(pixel.r > 0.9), int(pixel.g > 0.9), int(pixel.b > 0.9))
		_check(coverage.x > 4 and coverage.y > 4 and coverage.z > 4, "动作帧缺少可见的护腕、靴子或护腿区域 " + pose)
	var styles := ["cloth", "leather", "chain"]
	for armor in styles:
		for gloves in styles:
			for greaves in styles:
				for boots in styles:
					var types := {"armor": armor, "gloves": gloves, "greaves": greaves, "boots": boots}
					actor.dress({"form": "sword", "armor_types": types})
					for pose in poses:
						actor._set_painted_frame(pose)
						var body: Texture2D = actor.painted.texture
						_check(body != null and body == actor.ReferenceFrames.texture(pose, types), "人物帧缺失或护甲不符 " + pose)
						var material: ShaderMaterial = actor.painted.material
						if armor == gloves and armor == greaves and armor == boots:
							_check(material == null, "整套衣装应直接使用原帧 " + pose)
							continue
						if material == null:
							_check(false, "缺少混搭材质 " + pose)
							continue
						var slots: Texture2D = material.get_shader_parameter("pose_slots")
						_check(slots != null and slots.resource_path.ends_with("/" + pose + "-slots.png"), "部位遮罩和动作不同步 " + pose)
						for slot in ["gloves", "greaves", "boots"]:
							var param: String = {"gloves": "glove_texture", "greaves": "greave_texture", "boots": "boot_texture"}[slot]
							var part: Texture2D = material.get_shader_parameter(param)
							_check(part != null and part == actor.ReferenceFrames.texture(pose, {"armor": types[slot]}), "部件和动作不同步 " + slot + "/" + pose)
