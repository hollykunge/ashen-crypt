extends SceneTree

const WuXing = preload("res://scripts/rules/wuxing.gd")
const Materials = preload("res://scripts/rules/materials.gd")
const Forge = preload("res://scripts/rules/forge_rules.gd")
const Derive = preload("res://scripts/rules/derive.gd")
const Bazi = preload("res://scripts/rules/bazi.gd")
const Origins = preload("res://scripts/rules/origins.gd")
const Realm = preload("res://scripts/rules/realm.gd")
const Appearance = preload("res://scripts/appearance.gd")
const WornSprites = preload("res://scripts/worn_sprites.gd")
const HeldWeapon = preload("res://scripts/held_weapon.gd")
const SideArt = preload("res://scripts/side_art.gd")
const Motion = preload("res://scripts/motion.gd")
const Roster = preload("res://scripts/roster.gd")
const Gear = preload("res://scripts/gear.gd")
const Combat = preload("res://scripts/combat.gd")
const MonsterArt = preload("res://scripts/monster_art.gd")
const Places = preload("res://scripts/rules/places.gd")
const FxArt = preload("res://scripts/fx_art.gd")
const ForgeArt = preload("res://scripts/forge_art.gd")
const PURE_MATERIALS := {"jin": "geng", "mu": "jia", "shui": "ren", "huo": "bing", "tu": "wu"}

var _checks := 0
var _failures := 0

func _initialize() -> void:
	var suites := [_test_conservation_tables, _test_bazi, _test_neutral_equipment, _test_companions,
		_test_places, _test_rules, _test_tribulations, _test_forge_examples, _test_forge_rules, _test_appearance, _test_weapon_grips, _test_motion, _test_blade_flurry, _test_new_forms,
		_test_control_modes, _test_monster_motion, _test_body_spacing, _test_fx_art, _test_plates, _test_horde]
	for suite: Callable in suites:
		_check(suite.call() == true, "测试组意外中断：%s" % suite.get_method())
	print("规则测试：%d 条断言，%d 项失败" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr(message)
		assert(condition, message)

func _sum(values: Array) -> float:
	var total := 0.0
	for value in values:
		total += float(value)
	return total

func _near(actual: float, expected: float, label: String, tolerance: float = 0.000001) -> void:
	_check(absf(actual - expected) <= tolerance, "%s：实际 %.8f，预期 %.8f" % [label, actual, expected])

func _test_monster_motion() -> bool:
	var run := Combat.new()
	run.reset(1, {}, "long_blade", false)
	run.enemies.resize(1)
	var foe := run.enemies[0]
	foe.spawn = 0.0
	run._step_enemies(0.12)
	_check(foe.moving and MonsterArt.live_frame(foe) == 1, "精怪走路按位移切换步态")
	foe.pos = run.position + Vector2(48.0, 0.0)
	foe.cooldown = 0.0
	var hp_before := run.hp
	run._step_enemies(0.01)
	_check(MonsterArt.live_frame(foe) == 4 and run.hp == hp_before, "普通攻击先起手")
	run._step_enemies(Combat.ENEMY_ATTACK_WINDUP)
	_check(MonsterArt.live_frame(foe) == 5 and run.hp < hp_before, "普通攻击在挥击帧造成伤害")
	run._step_enemies(Combat.ENEMY_ATTACK_RECOVERY * 0.6)
	_check(MonsterArt.live_frame(foe) == 6, "挥击后接收招动作")
	foe.cooldown = 0.0
	foe.attack_recovery = 0.0
	run.invulnerable = 0.0
	run._step_enemies(0.01)
	hp_before = run.hp
	run.position.x -= 75.0
	run._step_enemies(Combat.ENEMY_ATTACK_WINDUP)
	_check(MonsterArt.live_frame(foe) == 5 and run.hp == hp_before, "走出近战范围后挥击落空")
	run._damage_enemy(foe, 100000, 0.0)
	_check(run._nearest_enemy().is_empty() and run.kills == 1 and run.fallen_enemies.size() == 1
		and MonsterArt.death_frame(run.fallen_enemies[0].age) == 8, "死亡精怪即时退出战斗并开始倒地")
	run.advance_enemy_deaths(Combat.ENEMY_DEATH_DURATION)
	_check(not run.enemy_fall_in_progress() and MonsterArt.death_frame(run.fallen_enemies[0].age) == 11,
		"倒地完成后保留末帧")
	run.advance_enemy_deaths(Combat.ENEMY_DEATH_LIFETIME)
	_check(run.fallen_enemies.is_empty(), "死亡动画结束后清理")
	run.reset(1, {}, "long_blade", true)
	foe = run.enemies[0]
	foe.spawn = 0.0
	foe.pos = run.position + Vector2(68.0, 0.0)
	foe.cooldown = 0.0
	run._step_enemies(0.01)
	_check(foe.windup > 0.0 and MonsterArt.live_frame(foe) == 4, "层主在红圈预警期间蓄势")
	run._step_enemies(foe.windup_total)
	_check(foe.windup == 0.0 and MonsterArt.live_frame(foe) == 5, "层主出招和红圈结算同步")
	return true

func _test_body_spacing() -> bool:
	var run := Combat.new()
	run.reset(1, {}, "dual_blades", true)
	var foe := run.enemies[0]
	foe.spawn = 0.0
	foe.cooldown = 20.0
	foe.stats.speed = 0.0
	var clearance := run._enemy_contact_distance(foe)
	var planted := run.position + Vector2(clearance + 38.0, 0.0)
	foe.pos = planted
	for _tick in range(90):
		run.step(1.0 / 60.0, Vector2.RIGHT)
	_near(foe.pos.x - run.position.x, clearance, "持续前进在身体边缘停下", 0.001)
	_check(foe.pos == planted and is_zero_approx(run.stride) and not foe.moving, "双方停住后没有推挤或踏步")
	_check(run._basic_attack_reaches(foe), "双刀够得着碰撞边缘处的层主")
	run.attack()
	var before_swing := run.position
	run._step_player(0.1, Vector2.LEFT)
	_check(run.position == before_swing, "挥击期间站稳脚底")
	run.step(1.0 / 60.0, Vector2.LEFT)
	_check(run.position.x < before_swing.x and run.stride > 0.0, "主动后退可以退出普攻并恢复步态")

	run.reset(1, {}, "long_blade", true, "", true)
	# 连战第一波是一群小怪；这里只留一只当前排，单验「后来者不挤占、不推人」。
	run.enemies.resize(1)
	var front := run.enemies[0]
	front.spawn = 0.0
	front.pos = run.position + Vector2(run._enemy_contact_distance(front) + 10.0, 0.0)
	front.cooldown = 20.0
	run._spawn_enemy(0.01)
	var behind := run.enemies[1]
	behind.pos = front.pos
	run._step_enemies(0.02)
	_check(behind.spawn <= 0.0 and behind.pos != front.pos, "在已占据的位置生成时改用空位")
	var before_block := Vector2(front.pos)
	for _tick in range(180):
		run.step(1.0 / 60.0)
	var gap := Vector2(behind.pos) - Vector2(front.pos)
	var combined := Vector2(front.body) + Vector2(behind.body) + Combat.BODY_MARGIN
	_check(front.pos == before_block and (absf(gap.x) + 0.01 >= combined.x or absf(gap.y) + 0.01 >= combined.y),
		"后排接敌时保留体积并且不推前排")
	return true

func _test_conservation_tables() -> bool:
	_near(_sum(WuXing.JINGYU.values()), 5.0, "境遇守恒")
	_near(_sum(WuXing.SHI.values()), 2.0, "势守恒")
	_near(_sum(WuXing.CLASH.values()), 5.0, "生克守恒")
	_near(_sum(Bazi.F_WEAK.values()), 5.0, "身弱契合守恒")
	_near(_sum(Bazi.F_STRONG.values()), 5.0, "身强契合守恒")
	for ling in WuXing.WUXING:
		var states := {}
		for element in WuXing.WUXING:
			var state := WuXing.jingyu(element, ling)
			_check(WuXing.JINGYU.has(state) and not states.has(state), "%s当令的境遇分划" % ling)
			states[state] = true
			var child: String = WuXing.SHENG[element]
			var order := ["si", "qiu", "xiu", "wang", "xiang"]
			_check(WuXing.jingyu(child, ling) == order[(order.find(state) + 1) % order.size()], "轮转阶梯")
	_near(WuXing.yin_yang(0.15, -1.0), 1.0, "太极边界")
	_near(WuXing.yin_yang(1.0, -1.0), 1.2, "阴阳异性")
	_near(WuXing.yin_yang(-1.0, -1.0), 0.88, "阴阳同性")
	return true

func _test_bazi() -> bool:
	for day in WuXing.STEMS:
		var gods := {}
		for stem in WuXing.STEMS:
			var god := Bazi.ten_god(day, stem)
			_check(Bazi.GOD_EFFECTS.has(god) and not gods.has(god), "%s日干的十神分划" % day)
			gods[god] = true
		_check(gods.size() == 10, "%s日干须覆盖十神" % day)
	var jia_gods := ["bijian", "jiecai", "shishen", "shangguan", "piancai", "zhengcai", "qisha", "zhengguan", "pianyin", "zhengyin"]
	for index in range(WuXing.STEMS.size()):
		_check(Bazi.ten_god("jia", WuXing.STEMS[index]) == jia_gods[index], "甲日干的生克与阴阳方向")
	_check(Bazi.hour_stem("geng", "zi") == "bing" and Bazi.hour_stem("gui", "hai") == "gui", "五鼠遁")
	_near(Bazi.body_strength("jia", "shen", "zi"), 0.10, "身强度本命柱、月令与时柱")
	_near(Bazi.body_strength("jia", "mao", "zi"), 1.0, "身强度上限")
	_near(Bazi.body_strength("geng", "zi", "zi"), -1.0, "身强度下限")
	var seen := {}
	for layer in range(1, 11):
		seen[WuXing.ling_of(layer)] = true
	_check(seen.size() == WuXing.STEMS.size(), "十层走满十干地气")
	_check(WuXing.ling_of(11) == WuXing.ling_of(1) and WuXing.ling_of(60) == WuXing.ling_of(10),
		"地气每十层归周")
	_check(Bazi.LING_GODS.size() == 5, "地气十神的五组遭遇")
	return true

func _test_neutral_equipment() -> bool:
	var item := _weapon({"taiji_pill": 4})
	for day in WuXing.STEMS:
		for strength in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			for ling in WuXing.STEMS:
				var derived := Derive.derive(item, 3, ling, {"day_stem": day, "s": strength})
				_near(derived.f, 1.0, "均衡契合")
				_near(derived.q, 1.0, "均衡境遇")
				_near(derived.shi, 1.0, "太极势")
	var neutral := Derive.derive(item, 3)
	for target in WuXing.WUXING:
		var multiplier := WuXing.weighted_clash(neutral.wuxing, target) * WuXing.yin_yang(neutral.yin_yang, 1.0)
		_near(multiplier, 1.0, "均衡太极对%s的生克" % target)
	for element in PURE_MATERIALS:
		var pure := _weapon({PURE_MATERIALS[element]: 4})
		var mean_q := 0.0
		var mean_shi := 0.0
		for ling in WuXing.STEMS:
			var derived := Derive.derive(pure, 3, ling)
			mean_q += float(derived.q) / WuXing.STEMS.size()
			mean_shi += float(derived.shi) / WuXing.STEMS.size()
		_near(mean_q, 1.0, "%s行十层平均 Q" % element)
		_near(mean_shi, 1.0, "%s行十层平均势" % element)
	return true

func _test_companions() -> bool:
	var signature := [0, 0, 1, 1, 1, 1, 2, 2, 3, 3]
	for day in WuXing.STEMS:
		var distribution := []
		for layer in range(1, 11):
			distribution.append(Origins.companions(day, layer))
		distribution.sort()
		_check(distribution == signature, "%s日干的随侍数分布" % day)
		_check(distribution.min() == 0 and distribution.max() == 3, "%s日干的随侍数范围" % day)
		_near(_sum(distribution) / distribution.size(), 1.40, "%s日干的随侍数均值" % day)
	return true

func _test_places() -> bool:
	_check(Places.PLACES.size() == 60, "六十层每层一个地方")
	_check(Places.BLOCKS.size() == 6, "六个十层段")
	var names := {}
	for layer in range(1, 61):
		var place := Places.place_of(layer)
		_check(int(place.layer) == layer, "第 %d 层的地点标回本层" % layer)
		_check(not String(place.name).is_empty(), "第 %d 层有地名" % layer)
		_check(not String(place.sight).is_empty(), "第 %d 层有灾情陈述" % layer)
		_check(not String(place.edict).is_empty(), "第 %d 层有敕令" % layer)
		_check(not String(place.region).is_empty(), "第 %d 层有地域" % layer)
		_check(not String(place.plate).is_empty(), "第 %d 层有底图分组" % layer)
		names[String(place.name)] = true
	_check(names.size() == 60, "六十个地名互不重复")
	# 前五十层能行善，天劫那一层除外 —— 焦原、沉渊这些已经是灾的终局，救不回来了。
	for layer in range(1, 51):
		var tribulation_layer := layer % 10 == 0
		_check(Places.can_aid(layer) != tribulation_layer,
			"第 %d 层%s驻留行善" % [layer, "不该能" if tribulation_layer else "该能"])
		_check(int(Places.place_of(layer).toll) > 0, "第 %d 层有待救者" % layer)
	# 待诏期替上界办事，没有可救的人，也不记伤亡。
	for layer in range(51, 61):
		_check(not Places.can_aid(layer), "第 %d 层（待诏）无行善" % layer)
		_check(int(Places.place_of(layer).toll) == 0, "第 %d 层（待诏）不记伤亡" % layer)
	for index in range(5):
		var gift := Places.relief_gift(index * 10 + 1)
		_check(Materials.MATERIALS.has(gift), "第 %d 段的 T3 谢礼是真材料" % (index + 1))
	_check(Places.relief_gift(55).is_empty(), "待诏期没有谢礼")
	# 越界回落，不崩。
	_check(Places.place_of(0).layer == 1 and Places.place_of(999).layer == 60, "层数越界回落到两端")
	return true

func _test_rules() -> bool:
	# 规矩在渡过对应天劫之后才立：第 i 条要 realms_cleared() >= i。
	var profile := Gear.new("user://test-rules.json")
	profile.state.character = Realm.new_profile("male", "geng", "mao", "si", "commoner")
	_check(profile.realm_index() == 0 and not profile.rule_unlocked("no_aid"), "炼气未成则第一条规矩未立")
	profile.state.character.layer = 11
	_check(profile.realm_index() == 1 and profile.rule_unlocked("no_aid"), "渡过木劫后第一条规矩生效")
	_check(not profile.rule_unlocked("no_calamity"), "第二条规矩要到筑基")
	profile.state.character.layer = 21
	_check(profile.unlocked_rules().size() == 2, "第 21 层在身两条规矩")
	profile.state.character.layer = 60
	_check(profile.unlocked_rules().size() == 5, "第 60 层五条规矩俱在")

	# 境界 −1 要真的掉一档炉温，而层数不退。
	profile.state.character.layer = 21
	var before_realm: String = profile.realm().name
	var before_forge := profile.furnace_level()
	var before_sockets := profile.socket_limit()
	Gear._apply_rule(profile.state, "no_aid", 21)
	_check(profile.layer() == 21, "违规不退层数")
	_check(profile.realm_index() == 1 and profile.realm().name != before_realm, "违规退一个境界")
	_check(profile.furnace_level() == before_forge - 1, "退境界连带掉一档炉温")
	_check(profile.socket_limit() <= before_sockets, "退境界不会凭空多出镶嵌槽")
	_check(profile.narrative().rules_broken.no_aid == [21], "违规层数记进存档")

	# 境界最多退到未成炼气，offset 不无限累积。
	for _i in range(6):
		Gear._apply_rule(profile.state, "no_aid", 21)
	_check(profile.realm_index() == 0, "境界退到底就不再退")
	_check(int(profile.state.character.realm_offset) == -2, "offset 夹在已挣得的境界数上")

	# 门槛加成按规矩累加（目前只写不读，渡劫门槛尚未在战斗里生效）。
	Gear._apply_rule(profile.state, "no_calamity", 25)
	_near(profile.jie_threshold_bonus(), 0.10, "逆天灾抬高下一劫门槛")
	_check(profile.narrative().rules_broken.no_calamity == [25], "逆天灾也记层数")

	# sever 是布尔，不是层数列表。
	Gear._apply_rule(profile.state, "sever", 60)
	_check(profile.narrative().rules_broken.sever == true, "尽忘人间记为布尔")
	return true

func _test_tribulations() -> bool:
	var neutral := _weapon({"taiji_pill": 4})
	for realm in Realm.REALMS:
		var ling := Realm.jie_ling_of(realm.layers[1])
		_check(WuXing.stem_element(ling) == realm.jie, "%s的天劫覆盖当令" % realm.name)
		var derived := Derive.derive(neutral, realm.forge_cap, ling, {"day_stem": "jia", "s": -0.5})
		var clash := WuXing.weighted_clash(derived.wuxing, realm.jie)
		var polarity := WuXing.yin_yang(derived.yin_yang, WuXing.stem_polarity(ling))
		var baseline: float = derived.q * derived.shi * derived.f * clash * polarity
		_near(baseline, 1.0, "%s的均衡实战基准" % realm.name)
		_near(Realm.JIE_THRESHOLD, baseline * 0.95, "%s的门槛随均衡基准计算" % realm.name)
		_check(Realm.JIE_THRESHOLD < baseline, "%s的均衡通路" % realm.name)
	_near(Realm.jie_threshold(2.0), 1.9, "门槛按给定均衡基准缩放")
	var profile := Realm.new_profile("female", "jia", "mao", "zi", "merchant")
	_check(profile.version == 4 and profile.silver == 2000 and profile.layer == 1
		and profile.narrative.rules_broken.has("no_calamity"), "规则档案版本及初始值")
	return true

func _test_forge_examples() -> bool:
	var sheng := Derive.derive(_weapon({"jia": 6, "bing": 6}), 3)
	_example_stat(sheng, "attack_speed", 21.3, "§9.1 攻速点")
	_example_stat(sheng, "lifesteal", 2.8, "§9.1 吸血")
	_near(sheng.budget, 43.2, "§9.1 预算")
	_check(sheng.f == 1.0 and sheng.q == 1.0 and sheng.shi == 1.0, "炉坊内在品质口径")

	var clash := Derive.derive(_weapon({"gui": 6, "bing": 6}, ["forge_fine", "harmonize"]), 3)
	_example_stat(clash, "impact", 7.0, "§9.2 冲击")
	_example_stat(clash, "chill", 6.0, "§9.2 冰冻减速")
	_example_stat(clash, "attack_speed", 2.0, "§9.2 攻速点")
	_example_stat(clash, "burn", 4.0, "§9.2 灼烧")
	_check(clash.clash.get("id") == "steam", "§9.2 蒸汽反应")
	_near(clash.clash.get("strength", -1.0), 36.0, "§9.2 反应强度", 0.05)
	_near(clash.steps[0].residue, 7.2, "溢出纯度返还 60%")

	var pure := Derive.derive(_weapon({"geng_jing": 4}), 3)
	_example_stat(pure, "attack", 70.2, "§9.3 物理攻击")
	_check(pure.stats.size() == 1, "§9.3 纯金单形")
	_near(pure.budget, 43.2, "§9.3 预算")
	return true

func _test_forge_rules() -> bool:
	for slot in Forge.FORM_MATRIX:
		for element in WuXing.WUXING:
			_check(Forge.FORM_MATRIX[slot][element].size() == 2 and Forge.TRIGGER_CONDITIONS[slot][element].size() == 2,
				"%s部位 %s 行阴阳双形" % [slot, element])
	for material in Materials.MATERIALS.values():
		if not material.wuxing.is_empty():
			_near(_sum(material.wuxing.values()), 1.0, "%s行向量归一化" % material.name)
	var raw_clash := Derive.derive(_weapon({"gui": 6, "bing": 6}), 3)
	_near(raw_clash.budget, 43.2 * 0.875, "蛮干相克耗散")
	_check(raw_clash.clash.is_empty(), "蛮干与反应互斥")
	var crafted := _weapon({"geng_jing": 4})
	crafted.sockets = ["jia", "jia", "ding", "bing"]
	var before := crafted.duplicate(true)
	var with_sockets := Derive.derive(crafted, 3)
	_check(crafted == before, "求值的输入保持纯净")
	_check(with_sockets.triggers.size() == 2 and with_sockets.triggers[1].stem == "ding", "镶嵌天干去重与槽上限")
	var allocation: Dictionary = with_sockets.steps[-1]
	_near(allocation.socket_budget, 43.2 * 0.40, "两槽的预算税")
	_near(with_sockets.triggers[0].strength, 43.2 * 0.15, "镶嵌强度来自所扣预算")
	_near(allocation.budget, allocation.stat_budget + allocation.socket_budget + allocation.clash_budget, "装备预算分配")
	crafted.rotation = 5
	_check(Derive.derive(crafted, 3) == with_sockets, "五轮回原行")
	crafted.rotation = 1
	_check(Derive.derive(crafted, 3).wuxing == {"shui": 1.0}, "轮转沿生链前进")
	var rough := _weapon({"geng": 4}, ["forge_rough"])
	rough.uid = "test-run"
	_check(Derive.derive(rough, 3) == Derive.derive(rough.duplicate(true), 3), "粗锻数值受稳定 UID 决定")
	var merged := Derive.merge_items(_weapon({"jia": 4}), _weapon({"bing": 4}), 3)
	var combined := Derive.derive(merged, 3)
	_near(combined.budget, 18.0 + 0.45 * 10.8, "熔合预算")
	_near(combined.wuxing.mu, 10.8 / 28.8, "熔合行向量按预算加权")
	_check(merged.wear == 1, "熔合磨损")
	_near(Bazi.affinity({"mu": 1.0}, "jia", 0.0), 1.14, "中和补偿")
	_near(Forge.stat_value("attack_speed", 21.3), 21.3 / 81.3, "攻速软上限曲线")
	return true

# 装备外观必须由推导结果决定：换行换色，不成格不发光，没装备就素身。
func _test_appearance() -> bool:
	var entries := {}
	for slot in ["weapon", "armor", "gloves", "charm", "ring", "boots"]:
		entries[slot] = Derive.derive({"slot": slot, "materials": {"bing": 6}, "process": ["forge_fine"]}, 3)
	var fire := Appearance.build(entries, {"yiqi": ["huo"]}, "long_blade")
	_check(fire.dressed and fire.cape and fire.charm and fire.ring, "六件齐备时外观层全开")
	_check(fire.robe.is_equal_approx(Appearance.ROBE_TINTS.huo), "护甲主导火行时染火色袍")
	_check(fire.weapon.is_equal_approx(Appearance.EDGE_TINTS.huo), "兵器主导火行时刃光为火色")
	_check(fire.polarity > 0.9 and fire.rim.is_equal_approx(Appearance.YANG_TRIM), "纯阳装备配阳边光")
	_check(fire.halo >= 1, "成格才有脚下法阵")
	var water := Appearance.build({"armor": entries.armor.duplicate(true),
		"weapon": Derive.derive(_weapon({"ren": 6}), 3)}, {}, "long_blade")
	_check(not water.weapon.is_equal_approx(fire.weapon), "换一把水行兵器就换一色刃光")
	_check(not water.cape_color.is_equal_approx(Color.TRANSPARENT) and water.halo == 0, "未成格时没有法阵")
	var bare := Appearance.bare()
	_check(not bare.dressed and not bare.cape and bare.halo == 0 and is_zero_approx(bare.robe_amount),
		"没有装备就是素身")
	for element in WuXing.WUXING:
		_check(Appearance.ROBE_TINTS.has(element) and Appearance.EDGE_TINTS.has(element),
			"%s行有成套的袍色与刃色" % element)
	for female in [false, true]:
		var base: Texture2D = SideArt.SPRITES[int(female)]
		_check(WornSprites.texture(female, bare) == base, "卸下服饰恢复男女各自的底图")
		var sheet := WornSprites.texture(female, fire)
		_check(sheet == WornSprites.texture(female, fire), "预览与战斗复用相同外观的图集")
		var original := SideArt.pixels(base)
		var painted := SideArt.pixels(sheet)
		_check(painted.get_size() == original.get_size() and original.get_size() == Vector2i(SideArt.CELL * SideArt.TEXEL) * Vector2i(4, 3),
			"人物图集是 4×3 格，每格为逻辑尺寸的 TEXEL 倍")
		for frame in range(12):
			var area := Rect2i(SideArt.frame_region(frame))
			_check(original.get_region(area).get_data() != painted.get_region(area).get_data(), "穿戴在第 %d 格动作中可见" % frame)
		for slot in ["armor", "gloves", "boots", "charm", "ring"]:
			var one := Appearance.build({slot: entries[slot]}, {}, "long_blade")
			var dressed := SideArt.pixels(WornSprites.texture(female, one))
			var rest := Rect2i(SideArt.frame_region(0))
			_check(dressed.get_region(rest).get_data() != original.get_region(rest).get_data(), "单穿 %s 在站姿中可见" % slot)
			var head := Rect2i(Vector2i(50, 14) * SideArt.TEXEL, Vector2i(10, 15) * SideArt.TEXEL)
			_check(dressed.get_region(head).get_data() == original.get_region(head).get_data(), "单穿 %s 保留脸部原画" % slot)
		# 染色只换颜色不换轮廓：透明的地方仍然透明，半透明的勾边最多被填实一点。
		var silhouette_kept := true
		for y in range(0, original.get_height(), 5):
			for x in range(0, original.get_width(), 5):
				if absf(original.get_pixel(x, y).a - painted.get_pixel(x, y).a) > 0.1:
					silhouette_kept = false
		_check(silhouette_kept, "换装不改人物轮廓")
		var chest := Vector2i(SideArt.frame_region(0).position) + Vector2i(48, 47) * SideArt.TEXEL
		var robe := painted.get_pixelv(chest)
		_check(robe.r > robe.b * 1.3 and robe.r > robe.g, "火行护甲把袍子染成暖色")
	var water_look := Appearance.build({"armor": Derive.derive({"slot": "armor", "materials": {"ren": 6}, "process": ["forge_fine"]}, 3)}, {}, "long_blade")
	var water_sheet := SideArt.pixels(WornSprites.texture(false, water_look))
	var water_chest := water_sheet.get_pixelv(Vector2i(48, 47) * SideArt.TEXEL)
	_check(water_chest.b > water_chest.r * 1.2, "水行护甲把袍子染成冷色")
	return true

func _test_weapon_grips() -> bool:
	var atlas := SideArt.pixels(HeldWeapon.ATLAS)
	var art_cell := Vector2(atlas.get_size()) / HeldWeapon.ATLAS_GRID
	_check(HeldWeapon.FORMS.size() == Gear.WEAPON_FORMS.size(), "每种形制都有手持原画")
	for form in Gear.WEAPON_FORMS:
		var spec: Dictionary = HeldWeapon.FORMS[form]
		var column := Vector2(int(spec.cell) % int(HeldWeapon.ATLAS_GRID.x), floori(int(spec.cell) / HeldWeapon.ATLAS_GRID.x))
		var grip := Vector2i((column + Vector2(spec.grip) / 128.0) * art_cell)
		_check(atlas.get_pixelv(grip).a > 0.8, "%s 原画的握柄中心可见" % form)
		if form in ["long_blade", "dual_blades"]:
			# 沿人物右向出刀时，刀柄、护手、刀尖依次向前，亮刃随下劈朝地。
			var pose := HeldWeapon.placement(form, Vector2.ZERO, 0.0)
			var guard := pose * Vector2(78, 33)
			var tip := pose * Vector2(5, 96)
			var pommel := pose * Vector2(100, 5)
			var edge := pose * Vector2(54, 72)
			var spine := pose * Vector2(40, 72)
			_check(pommel.x < 0 and guard.x > 0 and tip.x > guard.x and edge.y > spine.y,
				"%s 柄尾留在拳后，开刃的一侧朝向下劈方向" % form)
			var span := tip.distance_to(pommel)
			_check(span > 24 and span < (45 if form == "long_blade" else 32), "%s 随角色身高定尺" % form)
		for sex in [0, 1]:
			var sprite: Texture2D = SideArt.SPRITES[sex]
			var body := SideArt.pixels(sprite)
			for frame in range(12):
				var pose := HeldWeapon.body_frame(form, frame)
				var source := Vector2i(SideArt.frame_region(pose).position)
				var hands := [HeldWeapon.LEAD[sex][pose]]
				if form in ["long_blade", "dual_blades"]:
					hands = [HeldWeapon.blade_hand(sex, pose)]
				if form == "dual_blades":
					hands.append(HeldWeapon.blade_hand(sex, pose, true))
				if form in ["hammer", "spear"] and frame == 0:
					hands.append(HeldWeapon.SUPPORT[sex][pose])
				for hand: Vector2 in hands:
					_check(body.get_pixelv(source + Vector2i(hand * SideArt.TEXEL)).a > 0.5,
						"%s 第 %d 帧握点落在人物手上" % [form, frame])
			if form == "bow":
				for release in [false, true]:
					var archer := SideArt.pixels(HeldWeapon.BowPose.texture(sprite, sex, release))
					var nock := HeldWeapon.BowPose.nock_hand(sex, release)
					var hand: Vector2 = HeldWeapon.LEAD[sex][10]
					_check(archer.get_pixelv(Vector2i(nock * SideArt.TEXEL)).a > 0.8 and absf(nock.y - hand.y) <= 1.0,
						"拉弦手与弓把等高，满弓与撒放格均有手部原画")
	return true

# 动作曲线要首尾归位，否则动作之间会跳帧；每种兵器都得有自己的普攻。
func _test_motion() -> bool:
	for clip_name in Motion.CLIPS:
		var opening := Motion.sample(clip_name, 0.0)
		var closing := Motion.sample(clip_name, 1.0)
		if clip_name != &"retreat":
			_check(Vector2(closing.shift).length() < 0.001 and is_zero_approx(closing.bend)
				and is_zero_approx(closing.tilt), "%s 收招回到站姿" % clip_name)
		_check(Vector2(opening.scale).is_equal_approx(Vector2.ONE) or clip_name == &"revive",
			"%s 起手不预先变形" % clip_name)
		_check(closing.frame == Motion.READY or clip_name == &"retreat", "%s 最后落回待机画" % clip_name)
	for form in Gear.WEAPON_FORMS:
		var clip := Motion.clip_for(&"attack", form)
		_check(Motion.CLIPS.has(clip), "%s 有自己的普攻曲线" % form)
		_check(Roster.battle_art(0, form, Motion.READY) != null
			and Roster.battle_art(0, form, Motion.WINDUP) != null, "%s 的待机与起手都能取到画" % form)
	var walking := Motion.walk(1.2)
	var standing := Motion.idle(0.4)
	_check(not Vector2(walking.shift).is_equal_approx(Vector2(standing.shift)), "走位与吐纳不是同一个姿态")
	return true

func _test_blade_flurry() -> bool:
	var run := Combat.new()
	for form in ["long_blade", "dual_blades"]:
		run.reset(1, {}, form, true)
		var enemy := run.enemies[0]
		enemy.spawn = 0.0
		enemy.cooldown = 10.0
		enemy.stats.speed = 0.0
		enemy.pos = Combat.HOME + Vector2(70, 0)
		var dual: bool = form == "dual_blades"
		var loss := roundi(run.hero.damage * 0.89)
		if dual:
			loss += roundi(roundi(run.hero.damage * 0.62) * 0.89)
		run.attack()
		for i in range(24):
			run.step(1.0 / 60.0)
		_check(run.combo_hits == (4 if dual else 3), "%s 每道刃光均单独判定" % form)
		_check(enemy.max_hp - enemy.hp == loss, "%s 一轮连斩保持伤害预算" % form)
		_check(run.hits == (2 if dual else 1), "%s 装备触发按原有命中次数结算" % form)
		run.step(Combat.COMBO_WINDOW)
		_check(run.combo_hits == 0, "连击计数超时清空")

	run.reset(1, {}, "long_blade", true)
	run.attack()
	run.step(0.28)
	run.attack()
	run.step(0.11)
	_check(run.motion == &"attack" and is_zero_approx(run.motion_time), "收招前点按会接上下一轮普攻")
	run.attack()
	run.retreat()
	run.step(0.40)
	_check(run.motion.is_empty() and is_zero_approx(run.attack_buffer_left), "后撤取消待续普攻")
	return true

# 三种后加的形制各有各的打法，不是换皮。
func _test_new_forms() -> bool:
	for form in ["spear", "sword", "wand"]:
		_check(Gear.WEAPON_FORMS.has(form) and Forge.NAME_PARTS.weapons.has(form) and ForgeArt.FORM_ICONS.has(form),
			"%s 在数值表、名称表和炉坊图标里都登记了" % form)
		var icon := ForgeArt.weapon_region(form)
		_check(Rect2(Vector2.ZERO, ForgeArt.WEAPONS.get_size()).encloses(icon), "%s 的炉坊图标落在图集内" % form)
	var run := Combat.new()
	run.reset(1, {}, "sword", true)
	var enemy := run.enemies[0]
	enemy.spawn = 0.0
	enemy.cooldown = 10.0
	enemy.stats.speed = 0.0
	enemy.pos = Combat.HOME + Vector2(70, 0)
	run.attack()
	for i in range(24):
		run.step(1.0 / 60.0)
	_check(run.combo_hits == 2, "长剑一轮两剑")
	_check(enemy.max_hp - enemy.hp == roundi(run.hero.damage * 0.89), "长剑两剑合起来是一次普攻的伤害")

	run.reset(1, {}, "spear", true)
	var front := run.enemies[0]
	front.spawn = 0.0
	front.cooldown = 10.0
	front.stats.speed = 0.0
	front.pos = Combat.HOME + Vector2(80, 0)
	var back: Dictionary = front.duplicate(true)
	back.serial = front.serial + 1
	back.pos = Combat.HOME + Vector2(140, 0)
	var flank: Dictionary = front.duplicate(true)
	flank.serial = front.serial + 2
	flank.pos = Combat.HOME + Vector2(80, 80)
	run.enemies.append(back)
	run.enemies.append(flank)
	run.attack()
	for i in range(30):
		run.step(1.0 / 60.0)
	_check(front.hp < front.max_hp and back.hp < back.max_hp, "长枪一枪扎穿前后站成一串的两只")
	_check(flank.hp == flank.max_hp, "长枪扫不到隔了一路的侧翼")
	_check(float(Gear.WEAPON_FORMS.spear.reach) > float(Gear.WEAPON_FORMS.long_blade.reach), "长枪比长刃够得远")

	run.reset(1, {}, "wand", true)
	var target := run.enemies[0]
	target.spawn = 0.0
	target.cooldown = 10.0
	target.stats.speed = 0.0
	target.pos = Combat.HOME + Vector2(240, 0)
	run.attack()
	run.step(float(run.hero.interval) * 0.36)
	_check(run.shots.size() == 1 and run.shots[0].magic and run.shots[0].wand, "短杖隔着距离放出一发轻法弹")
	_check(float(Gear.WEAPON_FORMS.wand.interval) < float(Gear.WEAPON_FORMS.staff.interval)
		and float(Gear.WEAPON_FORMS.wand.reach) < float(Gear.WEAPON_FORMS.staff.reach), "短杖比法杖快，也比法杖近")
	for sex in [0, 1]:
		var tip := HeldWeapon.release_point(sex, true, true)
		var palm: Vector2 = HeldWeapon.LEAD[sex][10] - SideArt.PIVOT
		_check(tip.x > palm.x and tip.distance_to(palm) < HeldWeapon.release_point(sex, true).distance_to(palm),
			"短杖的法弹从杖尖出手，比法杖贴身")
	return true

func _test_control_modes() -> bool:
	var run := Combat.new()
	run.reset(1, {}, "long_blade", true)
	var enemy := run.enemies[0]
	enemy.spawn = 0.0
	enemy.cooldown = 30.0
	enemy.pos = Combat.HOME + Vector2(190, 0)
	for tick in range(60):
		run.step(1.0 / 60.0, Vector2.ZERO, false, Combat.ControlMode.ASSISTED)
	_check(run.position == Combat.HOME and run.combo_hits > 0, "原地等精怪接近后自动普攻")
	_check(is_zero_approx(run.skill_left) and is_zero_approx(run.tactic_left), "自动普攻保留手动施法")
	enemy.pos = run.position + Vector2(run._enemy_contact_distance(enemy) + 4.0, 0.0)
	var stance := run.position
	var enemy_stance := Vector2(enemy.pos)
	for _tick in range(20):
		run.step(1.0 / 60.0, Vector2.ZERO, false, Combat.ControlMode.ASSISTED)
	_check(run.position == stance and enemy.pos == enemy_stance and is_zero_approx(run.stride), "进入普攻距离后双方都站定交手")
	var x_before := run.position.x
	run.step(1.0 / 60.0, Vector2.LEFT, false, Combat.ControlMode.ASSISTED)
	_check(run.position.x < x_before, "主动移动时仍能手动走位")
	for tick in range(32):
		run.step(1.0 / 60.0, Vector2.ZERO, false, Combat.ControlMode.AUTOMATIC)
	_check(run.skill_left > 0.0 or run.tactic_left > 0.0, "全自动会释放技能")
	enemy.windup = 0.20
	enemy.strike_at = run.position
	stance = run.position
	run.step(1.0 / 60.0, Vector2.ZERO, false, Combat.ControlMode.AUTOMATIC)
	_check(run.dodge_left > 0.0 and run.retreat_left > 0.0 and run.position == stance, "全自动在红圈命中前原地闪避")
	return true

func _weapon(materials: Dictionary, process: Array = ["forge_fine"]) -> Dictionary:
	return {"slot": "weapon", "materials": materials, "process": process}

func _example_stat(result: Dictionary, stat: String, expected: float, label: String) -> void:
	_near(result.stats.get(stat, -1.0), expected, label, 0.05)

func _test_fx_art() -> bool:
	_near(FxArt.ART_HEIGHT, MonsterArt.STANDING_HEIGHT, "特效像素与精怪像素同一张网格")
	_near(Combat.HIT_LIFETIME, FxArt.duration(&"hit"), "普通击打寿命等于图集播放时长")
	_near(Combat.CRIT_LIFETIME, FxArt.duration(&"crit"), "暴击寿命等于图集播放时长")
	for kind in FxArt.SHEETS:
		var sheet: Dictionary = FxArt.SHEETS[kind]
		var cell: Vector2i = sheet.cell
		var texture: Texture2D = sheet.texture
		_check(Vector2i(texture.get_size()) == Vector2i(cell.x * int(sheet.frames), cell.y * FxArt.ROWS.size()),
			"%s 图集尺寸 = 帧数 × 五行行数" % kind)
		var pivot: Vector2 = sheet.pivot
		_check(Rect2(Vector2.ZERO, Vector2(cell)).has_point(pivot), "%s 锚点落在格内" % kind)
		var image := texture.get_image()
		if image.is_compressed():
			image.decompress()
		for element in FxArt.ROWS:
			var first := image.get_region(Rect2i(FxArt.region(kind, element, 0)))
			_check(first.get_used_rect().size != Vector2i.ZERO, "%s 的 %s 行第一帧有画" % [kind, element])
		_check(FxArt.frame_at(kind, -1.0) == 0 and FxArt.frame_at(kind, 1.0) == int(sheet.frames) - 1,
			"%s 播放进度夹在帧数内" % kind)
	_check(FxArt.row_of("huo") == 3 and FxArt.row_of("") == FxArt.ROWS.size() - 1
		and FxArt.row_of("未知") == FxArt.ROWS.size() - 1, "认不得的五行落到空手那一行")

	# 实战里真的打出击打特效：带着武器五行、出手方向与暴击标记。
	# 暴击只在一刀的首次接触上显示 —— 连斩的后几段即便同属暴击也按普通击打画。
	var run := Combat.new()
	run.reset(1, {}, "long_blade", true)
	run.hit_element = "huo"
	run.facing = 0.0
	var enemy := run.enemies[0]
	enemy.spawn = 0.0
	enemy.pos = Combat.HOME + Vector2(70, 0)
	for case in [[false, true, false], [true, true, true], [true, false, false]]:
		run.effects.clear()
		enemy.hp = enemy.max_hp
		run._damage_enemy(enemy, 5, 0.0, case[0], false, Vector2(0.0, 1.0), case[1])
		var hits := run.effects.filter(func(effect: Dictionary) -> bool: return effect.type == &"impact")
		_check(hits.size() == 1, "每次命中恰好一个击打特效")
		if hits.size() != 1:
			continue
		var hit: Dictionary = hits[0]
		_check(hit.critical == case[2], "暴击标记：暴击 %s · 首次接触 %s" % [case[0], case[1]])
		_check(hit.element == "huo" and cos(float(hit.angle)) > 0.0, "击打带着武器五行与出手方向")
		_near(hit.duration, Combat.CRIT_LIFETIME if case[2] else Combat.HIT_LIFETIME, "击打寿命按暴击与否")
	return true

func _test_plates() -> bool:
	# 每个地域都有自己的长卷，而且真出了图：足够长、手机装得下、地面线在合理范围。
	for block in Places.BLOCKS:
		_check(SideArt.PLATES.has(String(block.plate)), "%s 地域有长卷配置" % block.plate)
	for key in SideArt.PLATES:
		var spec: Dictionary = SideArt.PLATES[key]
		_check(ResourceLoader.exists(spec.path), "%s 长卷已出图" % key)
		if not ResourceLoader.exists(spec.path):
			continue
		var size: Vector2 = (load(spec.path) as Texture2D).get_size()
		_check(size.x <= 8192.0, "%s 长卷宽 %d，不超过手机常见的贴图上限" % [key, size.x])
		_check(size.x / size.y >= 6.0, "%s 长卷够长（宽高比 %.1f）" % [key, size.x / size.y])
		_check(float(spec.floor) > 0.5 and float(spec.floor) < 0.95, "%s 地面线落在下半幅" % key)
		_check(StringName(spec.weather) in [&"snow", &"rain", &"ash", &"dust", &"grit", &"mist"], "%s 天气有画法" % key)
	# 一个地域十层沿长卷从左走到右，天劫那层在最右，换地域从头开始。
	_near(SideArt.plate_progress(1), 0.0, "第 1 层在长卷最左")
	_near(SideArt.plate_progress(10), 1.0, "木劫那层在长卷最右")
	_near(SideArt.plate_progress(11), 0.0, "进入筑基换新长卷，从头开始")
	_near(SideArt.plate_progress(15), 4.0 / 9.0, "第 15 层在长卷中段")
	_near(SideArt.plate_progress(60), 1.0, "待诏期最后一层在最右")
	_check(SideArt.plate_for(3).key == "drought" and SideArt.plate_for(25).key == "mine"
		and SideArt.plate_for(57).key == "court", "层号对上地域长卷")
	_check(SideArt._plate_cache.size() == 1, "长卷只常驻当前一张")
	return true

func _test_horde() -> bool:
	# 连战：前两波成群的小怪，最后一波一个层主。
	_check(Combat.WAVE_SIZES[0] >= 5 and Combat.WAVE_SIZES[1] >= 5 and Combat.WAVE_SIZES[-1] == 1, "小怪成群，层主独战")
	var run := Combat.new()
	run.combat_rng.seed = 11
	run.reset(1, {}, "long_blade", true, "", true)
	_check(run.enemies.size() == Combat.WAVE_SIZES[0], "第一波一次放出整群")
	var boss_run := Combat.new()
	boss_run.reset(1, {}, "long_blade", true)
	var boss: Dictionary = boss_run.enemies[0]
	for foe in run.enemies:
		_check(not foe.boss and foe.max_hp * 4 < boss.max_hp and foe.stats.damage * 3 < boss.stats.damage
			and foe.stats.size < boss.stats.size, "小怪的血量、伤害、个头都远小于层主")
	# 一轮普攻的总伤害打得掉大半只小怪：带上装备就是一轮清一排。
	_check(run.enemies[0].max_hp <= roundi(float(run.hero.damage) * 1.25), "空手两轮、有装备一轮清掉一只小怪")

	# 整群落位后互不重叠，也不压在主角身上。
	for _tick in range(150):
		run._step_enemies(1.0 / 60.0)
	var crowded := false
	for i in range(run.enemies.size()):
		var a: Dictionary = run.enemies[i]
		crowded = crowded or a.spawn > 0.0 or Combat._bodies_overlap(a.pos, run.position,
			Vector2(a.body) + Combat.PLAYER_BODY + Combat.BODY_MARGIN - Vector2(0.01, 0.01))
		for j in range(i + 1, run.enemies.size()):
			var b: Dictionary = run.enemies[j]
			crowded = crowded or Combat._bodies_overlap(a.pos, b.pos,
				Vector2(a.body) + Vector2(b.body) + Combat.BODY_MARGIN - Vector2(0.01, 0.01))
	_check(not crowded, "怪群全部落位且保留各自的体积")
	var rows := {}
	for foe in run.enemies:
		rows[roundi(foe.pos.y / 20.0)] = true
	_check(rows.size() >= 3, "怪群分三路纵深压上来，而不是排成一列")

	# 侧翼的小怪也会咬人。
	run.reset(1, {}, "long_blade", true, "", true)
	run.enemies.resize(1)
	var flanker: Dictionary = run.enemies[0]
	flanker.spawn = 0.0
	flanker.cooldown = 0.0
	flanker.pos = run.position + Vector2(run._enemy_contact_distance(flanker), 64.0)
	var before := run.hp
	run._step_enemies(0.01)
	run._step_enemies(Combat.ENEMY_ATTACK_WINDUP)
	_check(run.hp < before, "隔一路纵深的小怪也能咬到")

	# 挂机：场上同时最多 FARM_HORDE 只。
	var farm := Combat.new()
	farm.combat_rng.seed = 5
	farm.loot_rng.seed = 5
	farm.reset(1, {}, "long_blade", false)
	var peak := 0
	for _tick in range(60 * 20):
		farm.step(1.0 / 60.0)
		peak = maxi(peak, farm.enemies.size())
	_check(peak > 3 and peak <= Combat.FARM_HORDE, "挂机场上成群但不超过上限（峰值 %d）" % peak)
	_check(farm.kills >= 20, "挂机二十秒击退二十只以上")

	# 全自动空手打第一层的两波小怪，打得完而且死不了。
	var auto := Combat.new()
	auto.combat_rng.seed = 21
	auto.reset(1, {}, "long_blade", true, "", true)
	var ticks := 0
	while auto.result == &"" and auto.wave_index < 2 and ticks < 60 * 60:
		auto.step(1.0 / 60.0, Vector2.ZERO, false, Combat.ControlMode.AUTOMATIC)
		ticks += 1
	_check(auto.wave_index == 2 and auto.result != &"defeat" and auto.kills == Combat.WAVE_SIZES[0] + Combat.WAVE_SIZES[1],
		"全自动清完两波怪群（%.1f 秒，余血 %d/%d）" % [ticks / 60.0, auto.hp, auto.max_hp])
	_check(auto.hp * 2 > auto.max_hp, "两波怪群下来余血过半")
	return true
