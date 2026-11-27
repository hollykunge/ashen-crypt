extends SceneTree

const WuXing = preload("res://scripts/rules/wuxing.gd")
const Materials = preload("res://scripts/rules/materials.gd")
const Forge = preload("res://scripts/rules/forge_rules.gd")
const Derive = preload("res://scripts/rules/derive.gd")
const Bazi = preload("res://scripts/rules/bazi.gd")
const Origins = preload("res://scripts/rules/origins.gd")
const Realm = preload("res://scripts/rules/realm.gd")
const Appearance = preload("res://scripts/appearance.gd")
const ArmoryFigure = preload("res://scripts/armory_figure.gd")
const SideArt = preload("res://scripts/side_art.gd")
const Motion = preload("res://scripts/motion.gd")
const Roster = preload("res://scripts/roster.gd")
const Gear = preload("res://scripts/gear.gd")
const GearStyles = preload("res://scripts/gear_styles.gd")
const Combat = preload("res://scripts/combat.gd")
const MonsterArt = preload("res://scripts/monster_art.gd")
const Places = preload("res://scripts/rules/places.gd")
const FxArt = preload("res://scripts/fx_art.gd")
const ForgeArt = preload("res://scripts/forge_art.gd")
const CutoutHero = preload("res://scripts/cutout_hero.gd")
const PURE_MATERIALS := {"jin": "geng", "mu": "jia", "shui": "ren", "huo": "bing", "tu": "wu"}

var _checks := 0
var _failures := 0

func _initialize() -> void:
	var suites := [_test_conservation_tables, _test_bazi, _test_neutral_equipment, _test_companions,
		_test_places, _test_rules, _test_tribulations, _test_forge_examples, _test_forge_rules, _test_appearance, _test_weapon_grips, _test_motion, _test_blade_flurry, _test_cutout_hero, _test_new_forms, _test_weapon_migration,
		_test_control_modes, _test_hit_feel, _test_monster_motion, _test_body_spacing, _test_fx_art, _test_plates, _test_horde]
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
	run.reset(1, {}, "sword", false)
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
	run.reset(1, {}, "sword", true)
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
	# 这里逐帧验走位，顿帧会把帧数拉长，单独关掉；顿帧另有测试。
	run.hitstop_scale = 0.0
	run.reset(1, {}, "sword", true)
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
	_check(run._basic_attack_reaches(foe), "剑够得着碰撞边缘处的层主")
	run.attack()
	var before_swing := run.position
	run._step_player(0.1, Vector2.LEFT)
	_check(run.position == before_swing, "挥击期间站稳脚底")
	run.step(1.0 / 60.0, Vector2.LEFT)
	_check(run.position.x < before_swing.x and run.stride > 0.0, "主动后退可以退出普攻并恢复步态")

	run.reset(1, {}, "sword", true, "", true)
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
	for slot in ["weapon", "armor", "gloves", "greaves", "boots"]:
		entries[slot] = Derive.derive({"slot": slot, "materials": {"bing": 6}, "process": ["forge_fine"]}, 3)
	var fire := Appearance.build(entries, {"yiqi": ["huo"]}, "sword")
	_check(fire.dressed and fire.cape and fire.tints.size() == 4 and fire.pieces.size() == 5 and fire.styles.is_empty(),
		"五件装备分别传到外观（没选款式就不带款式名）")
	_check(fire.robe.is_equal_approx(Appearance.ROBE_TINTS.huo), "护甲主导火行时染火色袍")
	_check(fire.weapon.is_equal_approx(Appearance.EDGE_TINTS.huo), "兵器主导火行时刃光为火色")
	_check(fire.polarity > 0.9 and fire.rim.is_equal_approx(Appearance.YANG_TRIM), "纯阳装备配阳边光")
	_check(fire.halo >= 1, "成格才有脚下法阵")
	var water := Appearance.build({"armor": entries.armor.duplicate(true),
		"weapon": Derive.derive(_weapon({"ren": 6}), 3)}, {}, "sword")
	_check(not water.weapon.is_equal_approx(fire.weapon), "换一把水行兵器就换一色刃光")
	_check(not water.cape_color.is_equal_approx(Color.TRANSPARENT) and water.halo == 0, "未成格时没有法阵")
	var bare := Appearance.bare()
	_check(not bare.dressed and not bare.cape and bare.halo == 0 and is_zero_approx(bare.robe_amount),
		"没有装备就是素身")
	for element in WuXing.WUXING:
		_check(Appearance.ROBE_TINTS.has(element) and Appearance.EDGE_TINTS.has(element),
			"%s行有成套的袍色与刃色" % element)
	for slot in Gear.ARMOR_TYPE_SLOTS:
		_check(fire.tints.has(slot) and fire.tints[slot].is_equal_approx(Appearance.garment_tint(slot, entries[slot])),
			"%s：模型和装备格图标用同一个颜色" % slot)
		for kind in ["cloth", "leather", "chain"]:
			var icon := ForgeArt.garment_icon(Gear.SLOTS.find(slot) - 1, kind)
			_check(Rect2(Vector2.ZERO, icon.atlas.get_size()).encloses(icon.region), "%s %s 皮影护具图标" % [kind, slot])
	var figure := ArmoryFigure.new()
	root.add_child(figure)
	for gender in ["male", "female"]:
		figure.display({}, {"gender": gender}, "jian", true)
		_check(figure.actor.puppet.who == ("nvjiang" if gender == "female" else "piying"), "试穿显示对应皮影")
		_check(figure.trying_label.visible, "试穿提示")
	figure.free()
	return true

func _test_weapon_grips() -> bool:
	var body := CutoutHero.new()
	root.add_child(body)
	for gender in ["male", "female"]:
		for form in Gear.WEAPON_FORMS:
			body.dress({"form": form, "gender": gender})
			body.fit(1.0, 1.0)
			body.drive(&"attack", 0.25, 0.0, false, [0.33])
			_check(body.puppet.rig.current_action() == "attack", "%s 皮影挥砍" % form)
			for gait in ["run", "walk", "ready"]:
				body.drive(&"", 0.0, 0.0 if gait == "ready" else 3.0, gait == "run", [])
				_check(body.puppet.rig.current_action() == gait, "%s 皮影步态" % gait)
	body.free()
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
	var walking := Motion.walk(1.2)
	var standing := Motion.idle(0.4)
	_check(not Vector2(walking.shift).is_equal_approx(Vector2(standing.shift)), "走位与吐纳不是同一个姿态")
	return true

# 皮影主角：每一刀的「打中」对准结算那一下，刀内时刻只往前走；护甲类别随装备传到外观里。
func _test_cutout_hero() -> bool:
	var cues: Array = Combat.BLADE_CUES.sword
	var hit := 0.43
	var end := 1.1
	for i in cues.size():
		var at := CutoutHero.PuppetHero.attack_time(cues[i], cues, hit, end)
		_check(int(at.x) == i and is_equal_approx(at.y, hit), "皮影劈砍：第 %d 刀打中对准结算" % (i + 1))
	var last := Vector2(-1, -1)
	for step in range(101):
		var at := CutoutHero.PuppetHero.attack_time(step / 100.0, cues, hit, end)
		if at.x == last.x:
			_check(at.y >= last.y - 0.0001, "皮影劈砍：同一刀里时刻不倒退（进度 %.2f）" % (step / 100.0))
		last = at
	_check(is_equal_approx(CutoutHero.PuppetHero.attack_time(1.0, cues, hit, end).y, end), "皮影劈砍：最后一刀收到整段结束")
	var look := Appearance.build({"armor": {"style": "青布短打"}, "boots": {"style": "云头靴"}, "gloves": {}}, {}, "sword")
	_check(look.styles.get("armor") == "青布短打" and look.styles.get("boots") == "云头靴"
		and not look.styles.has("gloves"), "外观带上各槽的款式名，没选款式的槽不写")
	_check(GearStyles.who_for("female") == "nvjiang" and GearStyles.who_for("male") == "piying", "男女主各用自己那套皮影")
	_check(GearStyles.outfit("piying", {"armor": "没画过的款式", "greaves": ""}).is_empty(), "没画过的款式、空款式都不换图")
	# 骨骼的换装槽名要和游戏的装备槽一致，换装才对得上
	for who in ["piying", "nvjiang", "body_f"]:
		var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://prototype/cutout/%s/rig.json" % who))
		for slot in cfg.get("slots", {}):
			_check(slot in Gear.ARMOR_TYPE_SLOTS, "%s 的换装槽 %s 是游戏里的装备槽" % [who, slot])
	var rig := CutoutHero.PuppetHero.Rig.new()
	rig.setup("res://prototype/cutout/body_f/rig.json", "res://prototype/cutout/body_f/parts")
	var outfit := {"greaves": "res://prototype/cutout/body_f/gear/greaves/某款"}
	_check(rig._dir_for("far_thigh", outfit) == outfit.greaves and rig._dir_for("shin", outfit) == outfit.greaves,
		"护腿款式换左右大腿、小腿")
	_check(rig._dir_for("torso", outfit) == rig.rig.base_dir and rig._dir_for("foot", outfit) == rig.rig.base_dir,
		"别的槽没穿就用光身原图")
	rig.free()
	return true

func _test_blade_flurry() -> bool:
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
	_check(run.combo_hits == 2, "剑每道刃光均单独判定")
	_check(enemy.max_hp - enemy.hp == roundi(run.hero.damage * 0.89), "剑一轮两剑保持伤害预算")
	_check(run.hits == 1, "剑的装备触发按原有命中次数结算")
	run.step(Combat.COMBO_WINDOW)
	_check(run.combo_hits == 0, "连击计数超时清空")

	run.reset(1, {}, "sword", true)
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


func _test_new_forms() -> bool:
	_check(Gear.WEAPON_FORMS.keys() == ["sword", "jian"], "游戏只保留刀剑")
	for form in Gear.WEAPON_FORMS:
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
	_check(run.combo_hits == 2, "刀一轮两斩")
	_check(enemy.max_hp - enemy.hp == roundi(run.hero.damage * 0.89), "刀的两斩合起来是一次普攻的伤害")

	run.reset(1, {}, "jian", true)
	var front := run.enemies[0]
	front.spawn = 0.0
	front.cooldown = 10.0
	front.stats.speed = 0.0
	front.pos = Combat.HOME + Vector2(80, 0)
	var back: Dictionary = front.duplicate(true)
	back.serial += 1
	back.pos = Combat.HOME + Vector2(104, 0)
	var flank: Dictionary = front.duplicate(true)
	flank.serial += 2
	flank.pos = Combat.HOME + Vector2(80, 100)
	run.enemies.append_array([back, flank])
	run.attack()
	for i in range(18):
		run.step(1.0 / 60.0)
	_check(front.hp < front.max_hp and back.hp < back.max_hp, "剑直刺命中前方一线的两只精怪")
	_check(flank.hp == flank.max_hp, "剑直刺避开侧翼目标")
	return true

func _test_weapon_migration() -> bool:
	var path := "user://migration-" + Crypto.new().generate_random_bytes(8).hex_encode() + ".json"
	var profile := Gear.new(path)
	var entry := Gear.new_draft()
	entry.weapon_form = "spear"
	entry.name = "玄铁长枪"
	entry.merge_sources = [{"weapon_form": "bow", "name": "寒弓"}, Gear.new_draft()]
	profile.state.items[entry.uid] = entry
	profile.state.equipped.weapon = entry.uid
	_check(profile._commit(profile.state), "写入旧装备样本")
	profile.load_profile()
	var migrated := profile.item(entry.uid)
	_check(profile.equipped("weapon") == entry.uid and migrated.weapon_form == "sword" and migrated.name == "玄铁刀", "已装备长枪迁移为刀")
	_check(migrated.merge_sources[0] == {"weapon_form": "jian", "name": "寒剑"}, "熔合来源弓迁移为剑")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(saved.items[entry.uid] == migrated, "磁盘已保存迁移后的兵形、装备名和来源")
	Gear.delete_slot(0, path)
	# 装备不再分布衣、皮甲、链甲：旧存档的甲型去掉，款式空着（不换图）
	var old := {"slot": "armor", "armor_type": "leather"}
	_check(Gear._migrate_item(old) and not old.has("armor_type") and old.get("style", "") == "", "旧存档的甲型去掉，款式空着")
	var styled := Derive.derive({"slot": "greaves", "style": "青布绑腿", "materials": {"bing": 6}, "process": ["forge_fine"]}, 3)
	var plain := Derive.derive({"slot": "greaves", "materials": {"bing": 6}, "process": ["forge_fine"]}, 3)
	_check(styled.style == "青布绑腿" and styled.name.contains("青布绑腿"), "有款式名的装备用款式名当叫法")
	_check(plain.name.contains("护腿"), "没选款式的装备叫槽名")

	return true

# 顿帧、击退、倒地打飞：打中要停一下，小怪往外退，层主几乎推不动。
func _test_hit_feel() -> bool:
	var run := Combat.new()
	run.reset(1, {}, "sword", true, "", true)
	run.enemies.resize(1)
	var foe := run.enemies[0]
	foe.spawn = 0.0
	foe.cooldown = 30.0
	foe.hp = 100000
	foe.max_hp = 100000
	foe.pos = run.position + Vector2(run._enemy_contact_distance(foe) + 4.0, 0.0)
	var before := Vector2(foe.pos)
	run._damage_enemy(foe, 10, 0.0)
	_near(run.hitstop, Combat.HITSTOP[&"hit"], "连战普攻顿帧按表", 0.0001)
	var frozen_motion := run.motion_time
	run.step(1.0 / 60.0)
	_check(run.motion_time == frozen_motion and Vector2(foe.pos) == before, "顿帧期间整场停住")
	for _tick in range(30):
		run.step(1.0 / 60.0)
	_check(foe.pos.x > before.x + Combat.KNOCKBACK * 0.6, "普攻把小怪往外推")
	run.hitstop = 0.0
	run._damage_enemy(foe, 10, 0.0, true)
	_near(run.hitstop, Combat.HITSTOP[&"crit"], "暴击顿得更久", 0.0001)
	run.hitstop_scale = 0.0
	run.hitstop = 0.0
	run._damage_enemy(foe, 10, 0.0)
	_check(run.hitstop == 0.0, "hitstop_scale 为 0 时不顿")
	run.hitstop_scale = 1.0

	# 挂机顿帧减半。
	run.reset(1, {}, "sword")
	run._freeze(Combat.HITSTOP[&"hit"])
	_near(run.hitstop, Combat.HITSTOP[&"hit"] * Combat.FARM_HITSTOP, "挂机顿帧减半", 0.0001)

	# 击杀：倒地带打飞距离。
	run.reset(1, {}, "sword", true, "", true)
	run.enemies.resize(1)
	var victim := run.enemies[0]
	victim.spawn = 0.0
	victim.pos = run.position + Vector2(80.0, 0.0)
	run._damage_enemy(victim, int(victim.hp) + 5, 0.0)
	_check(run.fallen_enemies.size() == 1 and run.fallen_enemies[0].launch.x > 0.0, "倒地的精怪朝远离主角的方向飞出")
	_near(run.hitstop, Combat.HITSTOP[&"kill"], "击杀顿帧", 0.0001)

	# 层主只被推动一点点，也不吃普攻硬直。
	var boss := {"pos": run.position + Vector2(60, 0), "hp": 999, "boss": true, "stagger": 0.0}
	run._shove(boss, 20.0)
	_check(absf(boss.shove.x) <= 20.0 * 0.15 * Combat.SHOVE_DECAY + 0.001 and boss.stagger == 0.0, "层主几乎推不动")
	return true

func _test_control_modes() -> bool:
	var run := Combat.new()
	# 这里逐帧验走位，顿帧会把帧数拉长，单独关掉；顿帧另有测试。
	run.hitstop_scale = 0.0
	run.reset(1, {}, "sword", true)
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
	# 精怪只会被普攻往外推一小步再贴回来，主角原地不追。
	_check(run.position == stance and absf(enemy.pos.y - enemy_stance.y) < 0.001
		and absf(enemy.pos.x - enemy_stance.x) <= Combat.KNOCKBACK * 3.0 and is_zero_approx(run.stride),
		"进入普攻距离后主角站定交手，精怪只被击退一小步")
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
		var texel: int = sheet.get("texel", 1)
		_check(Vector2i(texture.get_size()) == Vector2i(cell.x * int(sheet.frames), cell.y * FxArt.ROWS.size()) * texel,
			"%s 图集尺寸 = 帧数 × 五行行数（乘清晰度倍数）" % kind)
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
	run.reset(1, {}, "sword", true)
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
	run.reset(1, {}, "sword", true, "", true)
	_check(run.enemies.size() == mini(Combat.WAVE_SIZES[0], Combat.STAGE_CAP)
		and run.wave_reserve == Combat.WAVE_SIZES[0] - run.enemies.size(), "第一波台上最多三只，其余候场")
	var boss_run := Combat.new()
	boss_run.reset(1, {}, "sword", true)
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
	run.reset(1, {}, "sword", true, "", true)
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
	farm.reset(1, {}, "sword", false)
	var peak := 0
	for _tick in range(60 * 20):
		farm.step(1.0 / 60.0)
		peak = maxi(peak, farm.enemies.size())
	_check(peak >= 2 and peak <= Combat.FARM_HORDE, "挂机场上有几只但不超过皮影戏台的上限（峰值 %d）" % peak)
	_check(farm.kills >= 20, "挂机二十秒击退二十只以上")

	# 全自动空手打第一层的两波小怪，打得完而且死不了。
	var auto := Combat.new()
	auto.combat_rng.seed = 21
	auto.reset(1, {}, "sword", true, "", true)
	var ticks := 0
	while auto.result == &"" and auto.wave_index < 2 and ticks < 60 * 60:
		auto.step(1.0 / 60.0, Vector2.ZERO, false, Combat.ControlMode.AUTOMATIC)
		ticks += 1
	_check(auto.wave_index == 2 and auto.result != &"defeat" and auto.kills == Combat.WAVE_SIZES[0] + Combat.WAVE_SIZES[1],
		"全自动清完两波怪群（%.1f 秒，余血 %d/%d）" % [ticks / 60.0, auto.hp, auto.max_hp])
	_check(auto.hp * 2 > auto.max_hp, "两波怪群下来余血过半")
	return true
