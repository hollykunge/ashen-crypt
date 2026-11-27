extends SceneTree

const Main = preload("res://main.tscn")
const Gear = preload("res://scripts/gear.gd")
const Places = preload("res://scripts/rules/places.gd")
var save_path := "user://test-playthrough-" + Crypto.new().generate_random_bytes(6).hex_encode() + ".json"
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = Main.instantiate()
	game.settings_path = save_path + ".settings"
	game.save_base = save_path
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	_check(_test_migration() == true, "迁移和锻造工艺测试完整执行")
	_check(_play(game) == true, "流程测试完整执行")
	_check(_test_armory() == true, "角色装备的对比和换装流程完整执行")
	_check(_test_tribulation() == true, "天劫流程完整执行")
	_check(_test_continuous_route() == true, "连战流程完整执行")
	_check(_test_relief() == true, "驻留行善与抗敕流程完整执行")
	_check(_test_roster(game) == true, "多角色、离线收益与角色信息流程完整执行")
	_test_gallery(game)
	_test_settings(game)
	for slot in range(Gear.MAX_CHARACTERS):
		var slot_file := Gear.slot_path(slot, save_path)
		for path in [slot_file, slot_file + ".tmp"]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
	for path in [save_path, save_path + ".settings", save_path + ".tmp", save_path + ".legacy", save_path + ".legacy.v3.bak",
			save_path + ".armory", save_path + ".jie", save_path + ".jie.tmp", save_path + ".route", save_path + ".route.tmp",
			save_path + ".relief", save_path + ".relief.tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("实玩流程：%d 项失败" % failures)
	quit(1 if failures else 0)

func _play(game) -> bool:
	_check(game.state == &"title" and game.title_page.visible and not game.battle.visible, "开机先看到标题页")
	_check(_press(game, "进入游戏") and game.state == &"roster" and game.roster_page.visible, "标题页进入选角页")
	_check(_count_text(game.roster_page, "创建角色") == Gear.MAX_CHARACTERS, "没有存档时三个角色位都是空的")
	if not _check(_press(game, "创建角色") and game.state == &"selection" and game.active_slot == 0, "空位进入创角"):
		return false
	_press(game, "性别")
	_check(_press(game, "女"), "性别页可更换角色")
	_press(game, "日干")
	_check(_press(game, "甲\n阳木") and game.selection.portrait.texture == game.SideArt.PORTRAIT_FEMALE
		and game.selection.portrait.modulate == game.Roster.ELEMENT_TINTS.mu.lerp(Color.WHITE, 0.67),
		"甲木女性显示对应立绘和五行色")
	var pane: Rect2 = game.selection.page_area.get_global_rect()
	game.selection._swipe_event(-1, pane.get_center() + Vector2(55, 0), true)
	game.selection._swipe_event(-1, pane.get_center() - Vector2(55, 0), false)
	_check(game.selection.current_page == 2, "横滑从日干进入月令")
	_press(game, "日干")
	_press(game, "庚\n阳金")
	if not _check(_press(game, "入山") and game.profile.has_character() and game.state == &"farm", "创角后自动进入挂机"):
		return false
	game.run.combat_rng.seed = 123
	game.run.loot_rng.seed = 123
	var stock_before: int = game.profile.stock("geng")
	var bare_damage: int = game.run.hero.damage
	_ticks(game, 340)
	if not _check(game.state == &"farm" and game.run.result.is_empty() and game.profile.layer() == 1
			and game.profile.stock("jia") > 0 and game.profile.stock("geng") == stock_before
			and game.pouch.drop.name == "硬木心" and not game.boss_controls.visible,
			"无输入持续刷甲年材料，不推进、不结算"):
		return false
	var farm_position: Vector2 = game.run.position
	game.run.hp = 0
	_ticks(game, 1)
	_check(game.run.hp == game.run.max_hp and game.run.position.distance_to(farm_position) < 3.0
		and game.state == &"farm", "挂机死亡原地恢复")

	var farming_kills: int = game.run.kills
	if not _check(_press_named(game, "行装") and game.state == &"forge", "挂机途中回炉"):
		return false
	_check(game.forge.inventory and _press(game, "打造第一件装备") and not game.forge.inventory, "空背包可以直接去锻造")
	var farm_material: int = game.profile.stock("jia")
	for _i in range(4):
		game.forge.plus_buttons.geng.pressed.emit()
	game.forge.plus_buttons.jia.pressed.emit()
	_check(game.profile.stock("geng") == stock_before and game.profile.stock("jia") == farm_material
		and game.forge.preview_stats.text.contains("物理攻击"), "消耗前预览实际掉落与初始材料")
	_press(game, "打造")
	_check(game.profile.stock("geng") == stock_before and game.profile.items().is_empty(), "首次点击只预备确认")
	if not _check(_press(game, "确认消耗并打造") and game.profile.stock("geng") == stock_before - 4
			and game.profile.stock("jia") == farm_material - 1, "确认打造后扣材料并产生成品"):
		return false
	if not _check(_press(game, "装备") and not game.profile.equipped("weapon").is_empty(), "装备刚出炉的长刀"):
		return false
	var item: Dictionary = game.profile.item(game.profile.equipped("weapon"))
	_check(item.materials == {"geng": 4, "jia": 1} and not item.has("stats") and not item.has("budget"), "装备只存锻造输入")
	game.forge.close_requested.emit()
	_check(game.state == &"farm" and game.run.hero.damage > bare_damage and game.run.kills == farming_kills,
		"返场重算装备并继续原战场")
	var old_entry: Dictionary = game.profile.describe(item, true)
	game._start_encounter(true)
	if not _check(game.state == &"boss" and game.boss_controls.visible and game.run.enemies.size() == 1
			and game.run.archetype.name == "藤巨妖", "冲层后进入藤巨妖的手操战"):
		return false
	_check(game.mode_button.accessibility_name == "自动普攻" and not game.manual_movement.visible, "挑战默认原地自动普攻")
	_check(game.mode_button.text.is_empty() and game.speed_button.text.is_empty(), "战斗工具按钮只画图标不写字")
	_check(_press_named(game, "1×") and game.battle_speed == 2, "战斗按钮切至两倍速")
	var spawn_before: float = game.run.enemies[0].spawn
	game._physics_process(1.0 / 60.0)
	_check(is_equal_approx(game.run.enemies[0].spawn, spawn_before - 2.0 / 60.0), "两倍速推进两个固定战斗步")
	_check(_press_named(game, "2×") and _press_named(game, "3×") and game.battle_speed == 1, "倍速可循环回正常")
	_check(_press_named(game, "自动普攻") and game.mode_button.accessibility_name == "全自动", "可切至自动施法")
	_check(_press_named(game, "全自动") and game.mode_button.accessibility_name == "手动" and game.manual_movement.visible,
		"手动模式恢复走位按钮")
	_ticks(game, 120)
	_check(game.run.enemies[0].hp == game.run.enemies[0].max_hp and game.run.skill_left == 0.0, "手动模式保留走位和出招控制")
	game.touches = {0: &"forward", 1: &"attack"}
	for tick in range(1200):
		if game.state != &"boss":
			break
		if tick % 40 == 0:
			game.run.skill()
		if tick % 55 == 12:
			game.run.tactic()
		game._physics_process(1.0 / 60.0)
	if not _check(game.state == &"farm" and game.profile.layer() == 2 and game.turnover.visible,
			"操控角色战胜层主，自动切入第二层并播放演出"):
		return false
	var new_entry: Dictionary = game.profile.describe(item, true)
	_check(game.turnover.cards.size() == 5 and game.turnover.outgoing.text == "甲木" and game.turnover.incoming.text == "乙木"
		and game.turnover.cards.weapon.label.text.contains("阴阳势") and not is_equal_approx(old_entry.shi, new_entry.shi)
		and game.run.encounter_stem == "yi" and not game.boss_controls.visible,
		"五个槽位演出使用前后推导，下一层装备与当令已刷新")
	_ticks(game, 400)
	_check(game.profile.stock("yi") > 0 and game.pouch.drop.name == "藤筋", "新层继续自动掉落")
	game.challenge_button.pressed.emit()
	if not _check(game.state == &"place_notice" and game.place_notice.is_visible_in_tree(),
			"点击连战先看本层告示"):
		return false
	if not _check(_take_edict(game) and game.state == &"boss", "可再次冲层"):
		return false
	var before_loss: Dictionary = game.profile.state.materials.duplicate()
	for _tick in range(2100):
		if game.state != &"boss":
			break
		game._physics_process(1.0 / 60.0)
	if not _check(game.state == &"farm" and game.profile.layer() == 2 and game.profile.state.materials == before_loss
			and game.profile.challenge_wait() >= 29, "战败仅触发调息，保留层数与材料"):
		return false
	game.challenge_button.pressed.emit()
	_check(game.state == &"farm" and game.challenge_button.accessibility_name.begins_with("调息") and game.challenge_button.text.is_empty(), "调息期间留在挂机")
	var reloaded := Gear.new(save_path)
	reloaded.load_profile()
	_check(reloaded.layer() == 2 and reloaded.equipped("weapon") == item.uid
		and reloaded.challenge_wait() > 0, "重新载入层数、装备与调息")
	for id in Gear.Materials.MATERIALS:
		_check(reloaded.stock(id) == game.profile.stock(id), "重新载入 %s 库存" % id)
	_check(int(reloaded.state.version) == 4 and reloaded.storage_error.is_empty(), "游戏存档确实写出 v4")
	return true

func _test_armory() -> bool:
	var game = Main.instantiate()
	game.settings_path = save_path + ".settings"
	game.save_base = save_path + ".armory"
	root.add_child(game)
	game.set_physics_process(false)
	_to_creator(game)
	_press(game, "入山")
	var blade := Gear.new_draft()
	blade.materials = {"geng": 4}
	var bow := Gear.new_draft()
	bow.weapon_form = "bow"
	bow.materials = {"ren": 5}
	game.profile.collect("geng", 4)
	game.profile.collect("ren", 5)
	game.profile.craft(blade)
	game.profile.craft(bow)
	game.profile.toggle_equip(blade.uid)
	game._enter_farm()
	var armory = game.forge.armory
	game.gear_slots.weapon.pressed.emit()
	_check(armory.selected_uid == blade.uid and armory.equip_button.text == "卸下", "点战场武器进入已穿戴的物品")
	if not _check(_press(game, "查看同部位背包") and armory.bag_items.has(bow.uid) and not armory.bag_items.has(blade.uid),
			"背包过滤同部位，排除已穿戴的物品"):
		return false
	armory.bag_items[bow.uid].pressed.emit()
	var before: Dictionary = armory.current_stats.duplicate()
	var table: GridContainer
	for child in armory.detail_body.get_children():
		if child is GridContainer:
			table = child
	_check(table != null and table.get_child_count() >= 6 and game.profile.equipped("weapon") == blade.uid,
		"选择武器显示当前和换上后的对比，预览不会换装")
	var displayed := {}
	for index in range(3, table.get_child_count(), 3):
		displayed[table.get_child(index).text] = table.get_child(index + 2).text.split(" ")[0]
	_press(game, "装备")
	var projected: Dictionary = armory.current_stats.duplicate()
	_check(before.reach < projected.reach and displayed["攻击距离"] == str(roundi(projected.reach))
		and displayed["物理攻击"] == str(roundi(projected.attack)), "预览的新数值与实际穿戴相符")
	_press(game, "查看同部位背包")
	_check(armory.bag_items.has(blade.uid) and not armory.bag_items.has(bow.uid), "替换后旧武器回到背包")
	armory.outfit_slots.boots.pressed.emit()
	_check(armory.empty_hint.visible and _press(game, "打造靴子") and game.forge.draft.slot == "boots", "空槽能跳转到对应的锻造部位")
	game.forge.close_requested.emit()
	_check(game.run.weapon_form == "bow" and game.run.hero.damage == projected.attack and game.run.hero.reach == projected.reach
		and game.run.max_hp == projected.hp, "角色装备所示数值与实战一致")
	var reloaded := Gear.new(game.profile.save_path)
	reloaded.load_profile()
	_check(reloaded.equipped("weapon") == bow.uid and reloaded.items().size() == 2, "换装重启后仍保留两件物品")
	game.queue_free()
	return true

func _test_tribulation() -> bool:
	var game = Main.instantiate()
	game.settings_path = save_path + ".settings"
	game.save_base = save_path + ".jie"
	root.add_child(game)
	game.set_physics_process(false)
	_to_creator(game)
	# 流程测试按帧数推进，顿帧会拖慢节奏，这里关掉。
	game.run.hitstop_scale = 0.0
	if not _check(_press(game, "入山"), "可创建天劫测试角色"):
		game.queue_free()
		return false
	for _i in range(18):
		game.profile.advance_layer()
	game.profile.collect("ren", 4)
	var water := Gear.new_draft()
	water.materials = {"ren": 4}
	game.profile.craft(water)
	game.profile.toggle_equip(water.uid)
	game._enter_farm()
	game.challenge_button.pressed.emit()
	_take_edict(game)
	for _wave in range(3):
		_clear_wave(game)
		if game.run.advancing:
			_ticks(game, 55)
	_ticks(game, 120)
	var notice = game.tribulation_notice
	if not _check(game.state == &"jie_notice" and notice.is_visible_in_tree() and game.profile.layer() == 20
			and not game.run.challenging and game.run.encounter_stem == "gui" and game.profile.realm().name == "筑基",
			"从第19层连战抵达火劫时停在告示，等待期间仍按癸水挂机"):
		game.queue_free()
		return false
	_check(notice.get_node("%Description").text.contains("水行落囚位") and notice.table.get_child_count() == 6
		and notice.table.get_child(4).text == "旺  1.30" and notice.table.get_child(5).text == "囚  0.85",
		"火劫告示显示已装备水系武器的本层地气和渡劫倍率")
	_press(game, "调整装备")
	_check(game.state == &"forge" and game.forge.preview_ling == "bing", "备劫炉坊按丙火当令预演")
	game.forge.armory.outfit_slots.weapon.pressed.emit()
	_check(_press(game, "卸下"), "可在备劫时卸下武器")
	game.forge.close_requested.emit()
	_check(game.state == &"jie_notice" and notice.get_node("%Empty").is_visible_in_tree() and not notice.table.visible,
		"备劫回炉后重新显示告示，并按实际穿戴刷新为空装")
	_check(_press(game, "留在本层挂机") and game.state == &"farm" and game.run.encounter_stem == "gui",
		"可以放弃本次渡劫并留在第20层挂机")
	_press_named(game, "行装")
	game.forge.armory.bag_items[water.uid].pressed.emit()
	_check(_press(game, "装备"), "挂机回炉可重新穿上水系武器")
	game.forge.close_requested.emit()
	_check(game.state == &"farm" and _press_named(game, "准备渡劫 · 第20层")
		and game.state == &"place_notice" and _take_edict(game) and notice.is_visible_in_tree(),
		"普通回炉返回挂机，主动挑战先看地点告示再看备战告示")
	_press(game, "迎接天劫")
	if not _check(game.state == &"boss" and game.run.encounter_stem == "bing"
			and is_equal_approx(game.profile.describe(water, true, "bing").q, 0.85)
			and game.gear_slots.weapon.occupied and game.gear_slots.weapon._fortune == "囚"
			and game.profile.realm().name == "筑基", "天劫对实战和装备槽角标同时覆盖当令"):
		game.queue_free()
		return false
	for _wave in range(3):
		_clear_wave(game)
		if game.run.advancing:
			_ticks(game, 55)
	_check(game.state == &"next_layer" and game.profile.layer() == 21 and game.profile.realm().name == "结丹"
		and game.banner_title.text == "破境" and game.banner_sub.text == "结丹", "渡劫成功才破境")
	_ticks(game, 42)
	_check(game.state == &"boss" and game.run.dungeon_layer == 21 and game.run.wave_index == 0,
		"破境后自动进入下一层")
	game.queue_free()
	return true

func _test_continuous_route() -> bool:
	var game = Main.instantiate()
	game.settings_path = save_path + ".settings"
	game.save_base = save_path + ".route"
	root.add_child(game)
	game.set_physics_process(false)
	_to_creator(game)
	# 流程测试按帧数推进，顿帧会拖慢节奏，这里关掉。
	game.run.hitstop_scale = 0.0
	if not _check(_press(game, "入山"), "可创建连战测试角色"):
		return false
	game.challenge_button.pressed.emit()
	_take_edict(game)
	if not _check(game.state == &"boss" and game.run.continuous and game.run.wave_index == 0
			and game.run.enemies.size() == game.Combat.STAGE_CAP
			and game.run.enemies.size() + game.run.wave_reserve == game.Combat.WAVE_SIZES[0] and not game.run.enemies[0].boss
			and game.stop_route_button.visible, "点击开始连战进入精怪波次"):
		return false
	game.control_mode = game.Combat.ControlMode.MANUAL
	game.run.hp -= 10
	game.run.mana = 30.0
	_clear_wave(game)
	var arrival_x: float = game.run.position.x
	_check(game.run.advancing and game.strip.advancing and game.strip.foes == 0 and game.profile.layer() == 1,
		"普通波全清后向前推进")
	_ticks(game, 10)
	_check(game.run.position.x > arrival_x and game.run.hp == game.run.max_hp - 10 and game.run.mana < game.run.max_mana,
		"手动模式也会跑图，血量和灵力沿用同一场战斗")
	_ticks(game, 48)
	_check(game.run.wave_index == 1 and game.run.enemies.size() == game.Combat.STAGE_CAP
			and game.run.enemies.size() + game.run.wave_reserve == game.Combat.WAVE_SIZES[1]
		and not game.run.boss_wave(), "到达后刷新第二波")
	_clear_wave(game)
	_ticks(game, 53)
	_check(game.run.wave_index == 2 and game.run.boss_wave() and game.run.enemies[0].boss, "第二波结束后遭遇层主")
	var old_stock: int = game.profile.stock("jia")
	_clear_wave(game)
	var restored := Gear.new(game.profile.save_path)
	restored.load_profile()
	_check(game.state == &"next_layer" and restored.layer() == 2 and restored.stock("jia") == old_stock + 3,
		"通关先持久化层数并只结算一次奖励")
	var victory_x: float = game.run.position.x
	_ticks(game, 18)
	_check(game.run.enemy_fall_in_progress() and is_equal_approx(game.run.position.x, victory_x),
		"层主倒地期间保留战场，通关演出随后再向前推进")
	_ticks(game, 27)
	_check(game.state == &"boss" and game.run.dungeon_layer == 2 and game.run.wave_index == 0
		and game.run.continuous, "层主战之后自动开始下一层第一波")
	_check(_press_named(game, "停止连战") and game.state == &"farm" and game.profile.layer() == 2, "中途停止可回到当前层挂机")
	_ticks(game, 60)
	_check(game.state == &"farm" and game.profile.layer() == 2, "停止后不会继续自动挑战")
	game.queue_free()
	return true

func _clear_wave(game) -> void:
	for _frame in range(600):
		var last_batch: bool = game.run.wave_reserve == 0
		for foe in game.run.enemies:
			foe.spawn = 0.0
			game.run._damage_enemy(foe, 100000, 0.0)
		_ticks(game, 1)
		if last_batch:
			return
	_check(false, "候场精怪未能在时限内全部登场")

func _ticks(game, count: int) -> void:
	for _tick in range(count):
		game._physics_process(1.0 / 60.0)


func _test_migration() -> bool:
	var legacy_path := save_path + ".legacy"
	var file := FileAccess.open(legacy_path, FileAccess.WRITE)
	if not _check(file != null, "可写旧存档测试夹具"):
		return false
	file.store_string(JSON.stringify({"version": 3, "materials": {"iron": 1, "bone": 2, "ember": 3},
		"owned": ["warhammer", "chain_mail"]}))
	file.close()
	var profile := Gear.new(legacy_path)
	profile.load_profile()
	_check(int(profile.state.version) == 4 and profile.state.materials == {"geng": 7, "dragon_bone": 7, "bing": 4}
		and FileAccess.file_exists(legacy_path + ".v3.bak"), "旧库存和成品用料等值返还并保留备份")
	profile.load_profile()
	_check(profile.stock("geng") == 7 and profile.stock("dragon_bone") == 7
		and profile.stock("bing") == 4, "重复读取不会二次返还")
	if not _check(profile.create_character({"gender": "male", "day_stem": "geng", "month_branch": "mao",
			"hour_branch": "si", "origin": "pauper"}), "迁移后可以继续创角"):
		return false
	var steam := Gear.new_draft()
	steam.materials = {"bing": 2, "gui": 2}
	steam.process.append("harmonize")
	if not _check(profile.craft(steam) and profile.describe(profile.item(steam.uid)).clash.get("id") == "steam",
			"调和产出蒸汽反应"):
		return false
	_check(is_equal_approx(float(profile.state.residue), 2.0), "溢出残渣按穷人出身全额返还")
	var blade := Gear.new_draft()
	blade.materials = {"geng": 2}
	if not _check(profile.advance_layer() and profile.craft(blade), "第二层继续打造同部位成品"):
		return false
	var combined := profile.merge_items(steam.uid, blade.uid)
	if not _check(not combined.is_empty() and profile.item(blade.uid).is_empty() and profile.item(steam.uid).is_empty(),
			"熔合消耗两个源装备并写出新成品"):
		return false
	_check(profile.rotate_item(combined) and int(profile.item(combined).wear) == 1, "穷人的熔合成品轮转不额外磨损")
	profile.load_profile()
	_check(float(profile.describe(profile.item(combined)).budget) > 0.0, "熔合配方重读后仍可推导")
	# 两件旧饰品仍各自保留。已穿戴的项链优先占用新护腿栏。
	var old := profile.state.duplicate(true)
	old.equipped.erase("greaves")
	for slot in ["charm", "ring"]:
		var legacy := Gear.new_draft()
		legacy.slot = slot
		legacy.forge_level = 1
		legacy.materials = {"geng": 2}
		legacy.name = "旧物" + slot
		legacy.merge_sources = [legacy.duplicate(true), legacy.duplicate(true)]
		old.items[legacy.uid] = legacy
		old.equipped[slot] = legacy.uid
	file = FileAccess.open(legacy_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	profile.load_profile()
	_check(profile.state.equipped.size() == 5 and profile.equipped("greaves") == old.equipped.charm,
		"两件已穿的旧饰品映射为一个护腿栏")
	var spare := profile.item(old.equipped.ring)
	_check(spare.slot == "greaves" and spare.name == "旧物ring" and spare.merge_sources[0].slot == "greaves",
		"背包与熔合来源保留旧装备")
	_check(profile.toggle_equip(spare.uid), "可以替换迁移后的护腿")
	profile.load_profile()
	_check(profile.equipped("greaves") == spare.uid and profile.state.items.size() == old.items.size(),
		"重读后保留装备及护腿选择")
	_check(profile.loadout().entries.greaves.budget > 0.0, "迁移后的熔合护腿参与属性计算")
	return true

# 驻留行善、违规的代价、抗敕。对应 docs/story.md §1.2 与 §2.1。
func _test_relief() -> bool:
	var game = Main.instantiate()
	game.settings_path = save_path + ".settings"
	game.save_base = save_path + ".relief"
	root.add_child(game)
	game.set_physics_process(false)
	_to_creator(game)
	if not _check(_press(game, "入山"), "可创建行善测试角色"):
		return false

	# 一、炼气未成，规矩未立：行善不要代价。这是教学段，就是要让玩家觉得救人划算。
	_set_layer(game, 5)
	var stem: String = game.profile.ling()
	var gift: String = Places.relief_gift(5)
	var stem_before: int = game.profile.stock(stem)
	var gift_before: int = game.profile.stock(gift)
	var forge_before: int = game.profile.furnace_level()
	game._show_place_notice()
	if not _check(game.state == &"place_notice" and game.place_notice.is_visible_in_tree(),
			"挂机时可调出本层告示"):
		return false
	if not _check(not game.place_notice.get_node("%Cost").visible, "规矩未立则不写代价"):
		return false
	if not _check(_press_prefix(game.place_notice, "驻留") and game.state == &"farm",
			"可以驻留行善并回到挂机"):
		return false
	_check(game.profile.layer() == 5, "行善不推进层数")
	_check(game.profile.stock(stem) == stem_before + Gear.AID_MATERIALS, "本地人送同干材料")
	_check(game.profile.stock(gift) == gift_before + 1, "本地人另送一件 T3")
	_check(game.profile.furnace_level() == forge_before, "炼气未成，行善不掉炉温")
	_check(game.profile.narrative().aided_layers == [5] and int(game.profile.narrative().mortals_saved) == 1,
		"行善记进叙事记录")
	_check(game.profile.narrative().rules_broken.no_aid.is_empty(), "规矩未立则不算违规")
	_check(not game.profile.relief_pending(), "蒙荫覆盖的是下一层，不是本层")
	_set_layer(game, 6)
	_check(game.profile.relief_pending(), "下一层蒙荫生效")

	# 二、渡过木劫之后：同一个选择开始要代价，而且代价在确认前就写明。
	_set_layer(game, 12)
	var realm_before: String = game.profile.realm().name
	forge_before = game.profile.furnace_level()
	game._show_place_notice()
	_check(game.place_notice.get_node("%Cost").visible
		and game.place_notice.get_node("%Cost").text.contains("境界 −1"), "告示在确认前写明境界 −1")
	if not _check(_press_prefix(game.place_notice, "驻留"), "第 12 层仍可选择行善"):
		return false
	_check(game.profile.layer() == 12, "违规行善也不退层数")
	_check(game.profile.realm().name != realm_before, "违规行善退一个境界")
	_check(game.profile.furnace_level() == forge_before - 1, "退境界连带掉一档炉温")
	_check(game.profile.narrative().rules_broken.no_aid == [12], "违规层数记下来了")

	# 三、天劫那一层已经是灾的终局，没有行善这个选项；抗敕也还没有身份。
	_set_layer(game, 20)
	game._show_place_notice()
	_check(not game.place_notice.get_node("%Aid").visible, "天劫层没有行善按钮")
	_check(not game.place_notice.get_node("%Refuse").visible, "炼神之前没有抗敕的身份")
	game._close_place_notice()

	# 四、炼神之后才抗得了敕。先把上面欠的境界补回来，单独验这条路。
	var cleared: Dictionary = game.profile.state.duplicate(true)
	cleared.character.realm_offset = 0
	game.profile._commit(cleared)
	_set_layer(game, 41)
	game._show_place_notice()
	if not _check(game.place_notice.get_node("%Refuse").visible, "炼神之后出现抗敕"):
		return false
	var toll: int = int(game.profile.place().toll)
	if not _check(_press(game.place_notice, "抗敕") and game.state == &"farm", "可以抗敕并回到挂机"):
		return false
	_check(game.profile.narrative().edicts_refused == [41], "抗敕记进叙事记录")
	_check(game.profile.harder_edict(), "抗敕后敕令改派更重者")
	game._show_place_notice()
	_check(game.place_notice.get_node("%Sight").text.contains(str(roundi(toll * 1.5))),
		"改派后的告示报更重的待救人数")
	game.queue_free()
	return true

# 直接落在某一层，用来验证规矩在不同境界下的解锁与代价。
func _set_layer(game, layer: int) -> void:
	var next: Dictionary = game.profile.state.duplicate(true)
	next.character.layer = layer
	game.profile._commit(next)
	game._enter_farm()

# 地点告示上的「接敕」。按钮文案固定，驻留那个按钮带着当地的行善内容所以要另找。
func _take_edict(game) -> bool:
	return _press(game.place_notice, "接敕")

# 标题页 → 选角页 → 第一格空位进创角。
func _to_creator(game) -> void:
	_press(game, "进入游戏")
	_press(game, "创建角色")

func _count_text(node: Node, title: String) -> int:
	var total := 1 if node is Button and node.text == title and node.is_visible_in_tree() else 0
	for child in node.get_children():
		total += _count_text(child, title)
	return total

# 选角页、离线收益、角色信息：两个角色互不串档，删人要按两下。
func _test_roster(game) -> bool:
	if not _check(game.profile.has_character() and game.active_slot == 0, "第一格有角色"):
		return false
	game._enter_farm()
	var first_layer: int = game.profile.layer()
	_check(game.hero_chip.visible and game.roster_button.visible, "挂机页有头像和返回选角")
	game.hero_chip.pressed.emit()
	_check(game.hero_sheet.visible and _count_text(game.hero_sheet, "返回选角") == 1, "点头像打开角色信息")
	var silver_before: int = game.profile.silver()
	game.run.combat_rng.seed = 7
	game.silver_rng.seed = 7
	_ticks(game, 900)
	_check(game.farm_kills > 0 and game.farm_seconds > 14.0 and game.farm_materials > 0, "挂机统计记下击杀、时长和材料")
	_check(game.profile.silver() + game.pending_silver == silver_before + game.farm_silver, "挂机灵砂只在攒着或已入账")
	var sheet_text: String = game.hero_sheet.live.farm.get_child(3).text
	_check(sheet_text == "%d · 每时 %d" % [game.farm_kills, roundi(game.farm_kills / game.farm_seconds * 3600.0)],
		"角色信息显示每时击杀")
	if not _check(_press(game.hero_sheet, "返回选角") and game.state == &"roster", "从角色信息回到选角"):
		return false
	var saved := Gear.new(Gear.slot_path(0, save_path))
	saved.load_profile()
	_check(saved.silver() == silver_before + game.farm_silver and saved.last_seen() > 0.0, "离开角色时灵砂与离开时刻写进存档")
	_check(_count_text(game.roster_page, "入山") == 1 and _count_text(game.roster_page, "创建角色") == Gear.MAX_CHARACTERS - 1,
		"选角页列出已有角色和剩下的空位")

	# 第二格立一个新角色，起道号。
	if not _check(_press(game, "创建角色") and game.active_slot == 1, "第二格进入创角"):
		return false
	game.selection.name_field.text = "  青崖子\n"
	_press(game, "入山")
	_check(game.state == &"farm" and game.profile.display_name() == "青崖子" and game.profile.layer() == 1
		and game.profile.save_path == Gear.slot_path(1, save_path), "第二个角色有自己的道号和存档")
	game._show_roster()
	_check(_count_text(game.roster_page, "入山") == 2, "两个角色都在选角页")

	# 第一格离开两小时：回来时补发离线收益，按效率五成计。
	var aged := Gear.new(Gear.slot_path(0, save_path))
	aged.load_profile()
	var now := Time.get_unix_time_from_system()
	aged.checkpoint(now - 7200.0, 0, 3000.0)
	var stem: String = aged.ling()
	var stock_before := aged.stock(stem)
	var coins_before := aged.silver()
	game._play_slot(0)
	_check(game.profile.layer() == first_layer and game.offline_card.visible, "回到第一个角色弹出离线收益")
	var report: Dictionary = game.offline_card.report
	_check(int(report.kills) == 3000 and int(report.materials) > 0
		and game.profile.stock(stem) == stock_before + int(report.materials)
		and game.profile.silver() == coins_before + int(report.silver), "离线两小时按每时三千的五成发放并入账")
	_check(_press(game.offline_card, "收下") and not game.offline_card.visible, "收下后关掉离线收益")
	game._settle_offline()
	_check(not game.offline_card.visible, "刚结算过不再重复发")

	# 离开超过十二小时只计十二小时。
	var capped := Gear.new(Gear.slot_path(0, save_path))
	capped.load_profile()
	capped.checkpoint(now - 86400.0, 0, 1000.0)
	var long_report := capped.offline_report(now, 0.56)
	_check(int(long_report.counted) == Gear.OFFLINE_CAP_SECONDS and int(long_report.kills) == 6000, "离线最多计十二小时")

	# 删除第二个角色：第一下只是待确认，第二下才删。
	game._show_roster()
	_check(_press(game.roster_page, "删除"), "可按删除")
	_check(FileAccess.file_exists(Gear.slot_path(1, save_path)) and FileAccess.file_exists(Gear.slot_path(0, save_path)),
		"第一下不删")
	_check(_press(game.roster_page, "确认删除") and _count_text(game.roster_page, "入山") == 1,
		"第二下删掉一个角色")
	_check(game.roster_page.count() == 1, "只剩一个角色")
	_check(_press_named(game.roster_page, "返回") and game.state == &"title", "选角页可返回标题页")
	return true

func _press_prefix(node: Node, prefix: String) -> bool:
	if node is Button and node.text.begins_with(prefix) and node.is_visible_in_tree() and not node.disabled:
		node.pressed.emit()
		return true
	for child in node.get_children():
		if _press_prefix(child, prefix):
			return true
	return false

func _press(node: Node, title: String) -> bool:
	if node is Button and node.text == title and node.is_visible_in_tree() and not node.disabled:
		node.pressed.emit()
		return true
	for child in node.get_children():
		if _press(child, title):
			return true
	return false

# 只画图标的按钮按读屏名字找。
func _press_named(node: Node, title: String) -> bool:
	if node is Button and node.accessibility_name == title and node.is_visible_in_tree() and not node.disabled:
		node.pressed.emit()
		return true
	for child in node.get_children():
		if _press_named(child, title):
			return true
	return false

func _check(condition: bool, message: String) -> bool:
	if not condition:
		failures += 1
		printerr(message)
	return condition

func _test_settings(game) -> void:
	game._open_settings()
	var panel = game.settings
	var sliders: Array[Node] = panel.find_children("*", "HSlider", true, false)
	_check(sliders.size() == 3, "声音分类提供三条音量轨")
	for i in sliders.size():
		sliders[i].value = 0.35 + 0.1 * i
	panel.show_tab(1)
	_press(panel, "三倍")
	panel.show_tab(2)
	_press(panel, "手动")
	_press(panel, "返回")
	var restarted = Main.instantiate()
	restarted.save_base = save_path
	restarted.settings_path = game.settings_path
	root.add_child(restarted)
	_check(restarted.battle_speed == 3 and int(restarted.control_mode) == 0, "新场景载入倍速与手动操作")
	for i in 3:
		var bus_index := AudioServer.get_bus_index(["Master", "Music", "SFX"][i])
		_check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(bus_index)), 0.35 + 0.1 * i), "重载音量总线 %d" % i)
	_check(restarted.sounds.voices[0].bus == &"SFX" and restarted.sounds.enabled, "游戏音效走音效总线")
	restarted._open_settings()
	_press(restarted.settings, "恢复默认")
	_check(restarted.battle_speed == 1 and int(restarted.control_mode) == 1 and not restarted.sounds.enabled, "恢复原有战斗和音效默认值")
	restarted.queue_free()

func _test_gallery(game) -> void:
	var forge = game.forge
	var original: String = forge.draft.weapon_form
	forge._open_weapons()
	var gallery = game.weapon_gallery
	_check(gallery.cards.size() == 4, "四个兵器挂幡")
	gallery.cards[3].pressed.emit()
	_press(gallery, "返回")
	_check(forge.draft.weapon_form == original, "取消兵器预选保留原草案")
	forge._open_weapons()
	gallery = game.weapon_gallery
	gallery.cards[3].pressed.emit()
	_press(gallery, "选用")
	_check(forge.draft.weapon_form == "bow", "选用弓写入实际锻造草案")
