extends SceneTree

# 开发用：照一个普通玩家的打法，从创角自动打到第 10 层木劫渡完（第 11 层），统计每层的节奏、胜负和装备强度。
#   godot --headless --path mobile --script res://tests/_balance_run.gd -- [种子] [最多模拟分钟] [操作模式 assisted|auto] [craft|nocraft|late]
# 打法：一进挂机先用手上的材料把五个槽各打一件（每槽挑库存最多的那种材料投满料格，强过身上那件才换），
# 然后开连战一路往上打，死了就回挂机刷够调息时间、再打造升级、再连战。天劫告示直接迎劫。
# 时间都是游戏内时间（每步 1/60 秒）；调息本来按真实时间算，这里刷满 30 秒游戏时间就当调息完。

const Main = preload("res://main.tscn")
const Gear = preload("res://scripts/gear.gd")
const Combat = preload("res://scripts/combat.gd")
const STEP := 1.0 / 60.0
const GOAL_LAYER := 11
const COOLDOWN := 30.0

var game
var save_path := "user://balance-" + Crypto.new().generate_random_bytes(6).hex_encode() + ".json"
var sim := 0.0
var max_minutes := 180.0
var rows := {}          # 层 → 统计
var attempts: Array = []
var farm_since_loss := COOLDOWN
var craft_mode := "craft"   # craft 一直打造；nocraft 从不打造；late 卡关（死过一次）才开始打造


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seed := int(args[0]) if args.size() > 0 else 7
	max_minutes = float(args[1]) if args.size() > 1 else 180.0
	var mode: String = args[2] if args.size() > 2 else "assisted"
	craft_mode = args[3] if args.size() > 3 else "craft"
	game = Main.instantiate()
	game.save_base = save_path
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	_press(game, "进入游戏")
	_press(game, "创建角色")
	_press(game, "入山")
	game.run.combat_rng.seed = seed
	game.run.loot_rng.seed = seed * 31 + 1
	game.control_mode = Combat.ControlMode.AUTOMATIC if mode == "auto" else Combat.ControlMode.ASSISTED
	print("开局：出身 %s，命主 %s，起始材料 %s" % [game.profile.origin().get("name", "?"), game.profile.character().get("day_stem", "?"),
		_stock_text()])
	_row(game.profile.layer()).start = 0.0
	var last_state: StringName = &""
	while game.profile.layer() < GOAL_LAYER and sim < max_minutes * 60.0:
		match game.state:
			&"farm":
				_farm_or_attack()
			&"place_notice":
				_press(game.place_notice, "接敕")
			&"jie_notice":
				_row(game.profile.layer()).jie_seen = true
				_press(game.tribulation_notice, "迎接天劫")
			&"boss", &"next_layer":
				_fight_tick()
			&"forge":
				game.forge.close_requested.emit()
			_:
				_tick()
		if game.state != last_state:
			if OS.get_environment("BALANCE_TRACE") != "" and game.profile.layer() >= 10:
				print("  %.1fs 状态 %s → %s" % [sim, last_state, game.state])
			last_state = game.state
	_report()
	for path in [save_path, save_path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	quit(0)


func _row(layer: int) -> Dictionary:
	if not rows.has(layer):
		rows[layer] = {"start": sim, "end": -1.0, "attempts": 0, "losses": 0, "farm": 0.0, "fight": 0.0,
			"crafted": 0, "hp_left": -1.0, "hero_dmg": 0, "hero_hp": 0, "budget": 0.0, "jie_seen": false,
			"death_wave": [], "boss_hp": 0, "boss_dmg": 0, "kills": 0}
	return rows[layer]


func _tick() -> void:
	game._physics_process(STEP)
	sim += STEP


# 挂机：刚死过就刷满调息再打；否则先打造再开连战
func _farm_or_attack() -> void:
	var layer: int = game.profile.layer()
	if farm_since_loss < COOLDOWN:
		var before: int = game.run.kills
		_tick()
		farm_since_loss += STEP
		_row(layer).farm += STEP
		_row(layer).kills += game.run.kills - before
		return
	if craft_mode == "craft" or (craft_mode == "late" and _any_loss()):
		_row(layer).crafted += _upgrade_gear()
	# 调息按真实时间记，这里已经刷满游戏时间，清掉
	var next: Dictionary = game.profile.state.duplicate(true)
	next.challenge_retry_at = 0.0
	game.profile._commit(next)
	game.retry_until = 0.0
	game._enter_farm()
	var row := _row(layer)
	var stats: Dictionary = game.run.hero
	row.hero_dmg = int(stats.damage)
	row.hero_hp = int(game.run.max_hp)
	row.budget = _equipped_budget()
	game.challenge_button.pressed.emit()


func _fight_tick() -> void:
	var layer: int = game.profile.layer()
	var row := _row(layer)
	var was_boss: bool = game.state == &"boss"
	var wave: int = game.run.wave_index if game.run != null else 0
	if was_boss and game.run.boss_wave() and not game.run.enemies.is_empty():
		var boss: Dictionary = game.run.enemies[0]
		row.boss_hp = int(boss.get("max_hp", 0))
		row.boss_dmg = int(boss.stats.get("damage", 0))
	var hp_ratio: float = float(game.run.hp) / maxf(1.0, float(game.run.max_hp))
	row.min_hp = minf(float(row.get("min_hp", 1.0)), hp_ratio)
	_tick()
	row.fight += STEP
	if game.profile.layer() > layer:
		# 过层：记下打完层主时剩多少血
		row.end = sim
		row.hp_left = hp_ratio
		var fresh := _row(game.profile.layer())
		fresh.start = sim
		fresh.hero_dmg = int(game.run.hero.damage)
		fresh.hero_hp = int(game.run.max_hp)
		fresh.budget = _equipped_budget()
	elif game.state == &"farm" and was_boss:
		row.losses += 1
		row.death_wave.append(wave)
		farm_since_loss = 0.0


# 每槽挑库存最多的天干材料投满料格，算出来的功率比身上那件高一成以上才打造并换上
func _upgrade_gear() -> int:
	var made := 0
	for slot in Gear.SLOTS:
		var best := ""
		var best_count := 0
		for id in Gear.WuXing.STEMS:
			if game.profile.stock(id) > best_count:
				best = id
				best_count = game.profile.stock(id)
		var qty := mini(best_count, game.profile.material_slots())
		if qty < 2:
			continue
		var draft := Gear.new_draft()
		draft.slot = slot
		draft.materials = {best: qty}
		if not game.profile.craft_error(draft).is_empty():
			continue
		var new_budget := float(game.profile.describe(draft, true).budget)
		var worn: String = game.profile.equipped(slot)
		var old_budget := float(game.profile.describe(game.profile.item(worn), true).budget) if not worn.is_empty() else 0.0
		if new_budget > old_budget * 1.1 and game.profile.craft(draft):
			game.profile.toggle_equip(draft.uid)
			made += 1
	return made


func _any_loss() -> bool:
	for layer in rows:
		if rows[layer].losses > 0:
			return true
	return false


func _equipped_budget() -> float:
	var total := 0.0
	for slot in Gear.SLOTS:
		var worn: String = game.profile.equipped(slot)
		if not worn.is_empty():
			total += float(game.profile.describe(game.profile.item(worn), true).budget)
	return total


func _stock_text() -> String:
	var parts := []
	for id in Gear.WuXing.STEMS:
		if game.profile.stock(id) > 0:
			parts.append("%s%d" % [Gear.stem_name(id), game.profile.stock(id)])
	return " ".join(parts)


func _report() -> void:
	print("层 | 用时(分) | 其中挂机 | 连战 | 尝试/败 | 死在第几波 | 打造 | 攻击 | 血 | 装备功率 | 层主血/伤 | 过层剩血 | 最低血 | 天劫告示")
	var layers := rows.keys()
	layers.sort()
	for layer in layers:
		var r: Dictionary = rows[layer]
		if layer >= GOAL_LAYER:
			continue
		var spent: float = (r.end if r.end >= 0.0 else sim) - r.start
		print("%2d | %5.1f | %5.1f | %5.1f | %d/%d | %s | %d | %d | %d | %.0f | %d/%d | %s | %s | %s" % [layer, spent / 60.0, r.farm / 60.0,
			r.fight / 60.0, r.losses + (1 if r.end >= 0.0 else 0), r.losses, ("%d 次都死在层主" % r.death_wave.size()) if r.death_wave.size() > 3 and r.death_wave.count(2) == r.death_wave.size() else str(r.death_wave), r.crafted, r.hero_dmg, r.hero_hp, r.budget,
			r.boss_hp, r.boss_dmg, ("%.0f%%" % (r.hp_left * 100.0)) if r.hp_left >= 0.0 else "未过",
			"%.0f%%" % (float(r.get("min_hp", 1.0)) * 100.0), "是" if r.jie_seen else ""])
	print("结束：第 %d 层，境界 %s，游戏内 %.1f 分钟，库存 %s，灵砂 %d" % [game.profile.layer(), game.profile.realm().name, sim / 60.0,
		_stock_text(), game.profile.silver()])


func _press(node: Node, title: String) -> bool:
	for child in node.find_children("*", "BaseButton", true, false):
		if child.is_visible_in_tree() and not child.disabled and (child.get("text") == title or child.accessibility_name == title):
			child.pressed.emit()
			return true
	return false
