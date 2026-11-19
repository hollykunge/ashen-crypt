extends SceneTree

const Main = preload("res://main.tscn")
const Gear = preload("res://scripts/gear.gd")
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
	_check(_test_tribulation() == true, "天劫流程完整执行")
	for path in [save_path, save_path + ".tmp", save_path + ".legacy", save_path + ".legacy.v3.bak",
			save_path + ".jie", save_path + ".jie.tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("实玩流程：%d 项失败" % failures)
	quit(1 if failures else 0)

func _play(game) -> bool:
	_press(game, "性别")
	_check(_press(game, "女"), "性别页可更换角色")
	_press(game, "日干")
	_check(_press(game, "甲\n阳木") and game.selection.portrait.texture == game.Roster.PORTRAITS[3],
		"甲木女性切换至青绿立绘")
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
			and game.loot_line.text.contains("甲木心") and not game.boss_controls.visible,
			"无输入持续刷甲年材料，不推进、不结算"):
		return false
	var farm_position: Vector2 = game.run.position
	game.run.hp = 0
	_ticks(game, 1)
	_check(game.run.hp == game.run.max_hp and game.run.position.distance_to(farm_position) < 3.0
		and game.state == &"farm", "挂机死亡原地恢复")

	var farming_kills: int = game.run.kills
	if not _check(_press(game, "回炉坊") and game.state == &"forge", "挂机途中回炉"):
		return false
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
	game.challenge_button.pressed.emit()
	if not _check(game.state == &"boss" and game.boss_controls.visible and game.run.enemies.size() == 1
			and game.run.archetype.name == "藤巨妖", "冲层后进入藤巨妖的手操战"):
		return false
	_ticks(game, 120)
	_check(game.run.enemies[0].hp == game.run.enemies[0].max_hp and game.run.skill_left == 0.0, "挑战时角色不自动攻击或施法")
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
	_check(game.profile.stock("yi") > 0 and game.loot_line.text.contains("乙藤筋"), "新层继续自动掉落")
	game.challenge_button.pressed.emit()
	if not _check(game.state == &"boss", "可再次冲层"):
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

func _test_tribulation() -> bool:
	var game = Main.instantiate()
	game.profile.save_path = save_path + ".jie"
	root.add_child(game)
	game.set_physics_process(false)
	if not _check(_press(game, "入山"), "可创建天劫测试角色"):
		game.queue_free()
		return false
	for _i in range(19):
		game.profile.advance_layer()
	game.profile.collect("ren", 4)
	var water := Gear.new_draft()
	water.materials = {"ren": 4}
	game.profile.craft(water)
	game.profile.toggle_equip(water.uid)
	game._enter_farm()
	game.challenge_button.pressed.emit()
	if not _check(game.state == &"jie_notice" and game.notice_text.text.contains("水属装备将落囚位")
			and game.run.encounter_stem == "gui" and game.profile.realm().name == "筑基", "第20层告示覆盖前说明克劫囚位"):
		game.queue_free()
		return false
	_press(game, "先回炉坊")
	_check(game.state == &"forge" and game.forge.preview_ling == "bing", "备劫炉坊按丙火当令预演")
	game.forge.close_requested.emit()
	game.challenge_button.pressed.emit()
	_press(game, "迎接天劫")
	if not _check(game.state == &"boss" and game.run.encounter_stem == "bing"
			and is_equal_approx(game.profile.describe(water, true, "bing").q, 0.85)
			and game.gear_slots.weapon.occupied and game.gear_slots.weapon._fortune == "囚"
			and game.profile.realm().name == "筑基", "天劫对实战和装备槽角标同时覆盖当令"):
		game.queue_free()
		return false
	# 用精确的临界伤害验证渡劫的落档与演出，实战胜负另由首层用例覆盖。
	_ticks(game, 55)
	game.run._damage_enemy(game.run.enemies[0], 100000, 0.0)
	_ticks(game, 1)
	_check(game.state == &"farm" and game.profile.layer() == 21 and game.profile.realm().name == "结丹"
		and game.profile.character().lifespan == 110 and game.turnover.heading.text.contains("破境"), "渡劫成功才增加境界与阳寿")
	game.queue_free()
	return true

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
			"调和产出蒸汽相激"):
		return false
	_check(is_equal_approx(float(profile.state.residue), 2.0), "溢出残渣按穷人出身全额返还")
	var blade := Gear.new_draft()
	blade.materials = {"geng": 2}
	if not _check(profile.advance_layer() and profile.craft(blade), "第二层继续打造同部位成品"):
		return false
	var combined := profile.merge_items(steam.uid, blade.uid)
	if not _check(not combined.is_empty() and profile.item(blade.uid).is_empty() and profile.item(steam.uid).is_empty(),
			"合炉消耗两个源装备并写出新成品"):
		return false
	_check(profile.rotate_item(combined) and int(profile.item(combined).wear) == 1, "穷人的合炉成品轮转不额外磨损")
	profile.load_profile()
	_check(float(profile.describe(profile.item(combined)).budget) > 0.0, "合炉配方重读后仍可推导")
	return true

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
