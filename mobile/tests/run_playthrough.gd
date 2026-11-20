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
	game.profile.save_path = save_path
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	_check(_test_migration() == true, "迁移和锻造工艺测试完整执行")
	_check(_play(game) == true, "流程测试完整执行")
	_check(_test_armory() == true, "角色装备的对比和换装流程完整执行")
	_check(_test_tribulation() == true, "天劫流程完整执行")
	_check(_test_continuous_route() == true, "连战流程完整执行")
	_check(_test_relief() == true, "驻留行善与抗敕流程完整执行")
	for path in [save_path, save_path + ".tmp", save_path + ".legacy", save_path + ".legacy.v3.bak",
			save_path + ".armory", save_path + ".jie", save_path + ".jie.tmp", save_path + ".route", save_path + ".route.tmp",
			save_path + ".relief", save_path + ".relief.tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("实玩流程：%d 项失败" % failures)
	quit(1 if failures else 0)

func _play(game) -> bool:
	_press(game, "性别")
	_check(_press(game, "女"), "性别页可更换角色")
	_press(game, "日干")
	_check(_press(game, "甲\n阳木") and game.selection.portrait.texture == game.SideArt.PORTRAITS[1]
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
			and game.loot_line.text.contains("硬木心") and not game.boss_controls.visible,
			"无输入持续刷甲年材料，不推进、不结算"):
		return false
	var farm_position: Vector2 = game.run.position
	game.run.hp = 0
	_ticks(game, 1)
	_check(game.run.hp == game.run.max_hp and game.run.position.distance_to(farm_position) < 3.0
		and game.state == &"farm", "挂机死亡原地恢复")

	var farming_kills: int = game.run.kills
	if not _check(_press(game, "行装") and game.state == &"forge", "挂机途中回炉"):
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
	_check(game.mode_button.text == "自动普攻" and not game.manual_movement.visible, "挑战默认原地自动普攻")
	_check(_press(game, "1×") and game.battle_speed == 2, "战斗按钮切至两倍速")
	var spawn_before: float = game.run.enemies[0].spawn
	game._physics_process(1.0 / 60.0)
	_check(is_equal_approx(game.run.enemies[0].spawn, spawn_before - 2.0 / 60.0), "两倍速推进两个固定战斗步")
	_check(_press(game, "2×") and _press(game, "3×") and game.battle_speed == 1, "倍速可循环回正常")
	_check(_press(game, "自动普攻") and game.mode_button.text == "全自动", "可切至自动施法")
	_check(_press(game, "全自动") and game.mode_button.text == "手动" and game.manual_movement.visible,
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
	_check(game.turnover.cards.size() == 6 and game.turnover.outgoing.text == "甲木" and game.turnover.incoming.text == "乙木"
		and game.turnover.cards.weapon.label.text.contains("阴阳势") and not is_equal_approx(old_entry.shi, new_entry.shi)
		and game.run.encounter_stem == "yi" and not game.boss_controls.visible,
		"六个槽位演出使用前后推导，下一层装备与当令已刷新")
	_ticks(game, 400)
	_check(game.profile.stock("yi") > 0 and game.loot_line.text.contains("藤筋"), "新层继续自动掉落")
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
	_check(game.state == &"farm" and game.challenge_button.text.contains("调息"), "调息期间留在挂机")
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
	game.profile.save_path = save_path + ".armory"
	root.add_child(game)
	game.set_physics_process(false)
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
	_check(armory.empty_hint.visible and _press(game, "打造鞋子") and game.forge.draft.slot == "boots", "空槽能跳转到对应的锻造部位")
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
	game.profile.save_path = save_path + ".jie"
	root.add_child(game)
	game.set_physics_process(false)
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
	_press(game, "行装")
	game.forge.armory.bag_items[water.uid].pressed.emit()
	_check(_press(game, "装备"), "挂机回炉可重新穿上水系武器")
	game.forge.close_requested.emit()
	_check(game.state == &"farm" and _press(game, "准备渡劫 · 第20层")
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
		and game.encounter_label.text.contains("破境"), "渡劫成功才破境")
	_ticks(game, 42)
	_check(game.state == &"boss" and game.run.dungeon_layer == 21 and game.run.wave_index == 0,
		"破境后自动进入下一层")
	game.queue_free()
	return true

func _test_continuous_route() -> bool:
	var game = Main.instantiate()
	game.profile.save_path = save_path + ".route"
	root.add_child(game)
	game.set_physics_process(false)
	if not _check(_press(game, "入山"), "可创建连战测试角色"):
		return false
	game.challenge_button.pressed.emit()
	_take_edict(game)
	if not _check(game.state == &"boss" and game.run.continuous and game.run.wave_index == 0
			and game.run.enemies.size() == game.Combat.WAVE_SIZES[0] and not game.run.enemies[0].boss
			and game.stop_route_button.visible, "点击开始连战进入精怪波次"):
		return false
	game.control_mode = game.Combat.ControlMode.MANUAL
	game.run.hp -= 10
	game.run.mana = 30.0
	_clear_wave(game)
	var arrival_x: float = game.run.position.x
	_check(game.run.advancing and game.encounter_label.text == "前往下一波" and game.profile.layer() == 1,
		"普通波全清后向前推进")
	_ticks(game, 10)
	_check(game.run.position.x > arrival_x and game.run.hp == game.run.max_hp - 10 and game.run.mana < game.run.max_mana,
		"手动模式也会跑图，血量和灵力沿用同一场战斗")
	_ticks(game, 48)
	_check(game.run.wave_index == 1 and game.run.enemies.size() == game.Combat.WAVE_SIZES[1]
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
	_check(_press(game, "停止连战") and game.state == &"farm" and game.profile.layer() == 2, "中途停止可回到当前层挂机")
	_ticks(game, 60)
	_check(game.state == &"farm" and game.profile.layer() == 2, "停止后不会继续自动挑战")
	game.queue_free()
	return true

func _clear_wave(game) -> void:
	for foe in game.run.enemies:
		foe.spawn = 0.0
		game.run._damage_enemy(foe, 100000, 0.0)
	_ticks(game, 1)

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
	return true

# 驻留行善、违规的代价、抗敕。对应 docs/story.md §1.2 与 §2.1。
func _test_relief() -> bool:
	var game = Main.instantiate()
	game.profile.save_path = save_path + ".relief"
	root.add_child(game)
	game.set_physics_process(false)
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

func _check(condition: bool, message: String) -> bool:
	if not condition:
		failures += 1
		printerr(message)
	return condition
