extends RefCounted

signal feedback(cue: StringName)
signal material_collected(id: String, quantity: int)

const Gear = preload("res://scripts/gear.gd")

const HEROES: Array[Dictionary] = [
	{"name": "神将", "skill": "镇山诀", "tactic": "裂岳", "hp": 156, "speed": 106.0, "damage": 31, "interval": 0.33, "reach": 103.0, "cooldown": 3.6, "color": Color("#ffbd76")},
	{"name": "神射", "skill": "连珠箭", "tactic": "贯云矢", "hp": 109, "speed": 122.0, "damage": 24, "interval": 0.24, "reach": 490.0, "cooldown": 3.3, "color": Color("#8af1c6")},
	{"name": "雷法", "skill": "五雷印", "tactic": "寒霄诀", "hp": 105, "speed": 101.0, "damage": 35, "interval": 0.43, "reach": 460.0, "cooldown": 4.1, "color": Color("#ddb2ff")}
]
# 十天干精怪共用战斗结构，各有形制、数值与层主招式。
const ARCHETYPES := {
	"jia": {"name": "藤巨妖", "skill": "青藤冲撞", "art": 0, "speed": 92.0, "vitality": 1.06, "force": 1.0, "radius": 71.0, "windup": 0.96, "effect": "knock"},
	"yi": {"name": "缠藤精", "skill": "藤缚汲生", "art": 0, "speed": 94.0, "vitality": 0.94, "force": 0.91, "radius": 66.0, "windup": 0.87, "effect": "heal"},
	"bing": {"name": "火狐", "skill": "烈焰爆燃", "art": 1, "speed": 111.0, "vitality": 0.92, "force": 1.11, "radius": 76.0, "windup": 0.88, "effect": "flare"},
	"ding": {"name": "烬祟", "skill": "阴焰焚灵", "art": 1, "speed": 97.0, "vitality": 0.88, "force": 1.04, "radius": 75.0, "windup": 0.93, "effect": "drain"},
	"wu": {"name": "磐石精", "skill": "磐山坠", "art": 2, "speed": 76.0, "vitality": 1.20, "force": 1.10, "radius": 86.0, "windup": 1.08, "effect": "knock"},
	"ji": {"name": "蚀壤精", "skill": "重壤蚀灵", "art": 2, "speed": 79.0, "vitality": 1.12, "force": 1.04, "radius": 83.0, "windup": 1.01, "effect": "drain"},
	"geng": {"name": "岳卫", "skill": "金甲震地", "art": 2, "speed": 84.0, "vitality": 1.15, "force": 1.10, "radius": 79.0, "windup": 1.02, "effect": "knock"},
	"xin": {"name": "刃魈", "skill": "寒刃突袭", "art": 0, "speed": 108.0, "vitality": 0.90, "force": 1.14, "radius": 64.0, "windup": 0.82, "effect": "knock"},
	"ren": {"name": "激流妖", "skill": "激潮洗灵", "art": 0, "speed": 105.0, "vitality": 0.98, "force": 0.99, "radius": 80.0, "windup": 0.98, "effect": "drain"},
	"gui": {"name": "寒魄", "skill": "寒霜封步", "art": 1, "speed": 102.0, "vitality": 0.94, "force": 1.03, "radius": 72.0, "windup": 0.91, "effect": "chill"}
}
const HOME := Vector2(418, 383)
const FOOTWORK := Rect2(330, 312, 201, 143)
const ENEMY_FOOTWORK := Rect2(264, 270, 479, 206)
const PLAYER_BODY := Vector2(35.0, 32.0)
const BODY_MARGIN := Vector2(13.0, 0.0)
const ENEMY_BODY_WIDTHS := [0.76, 0.91, 0.84]
const ENEMY_MELEE_MARGIN := 15.0
const TELEGRAPH_ASPECT := 0.64
const MAX_MANA := 100.0
const SKILL_COST := 30.0
const TACTIC_COST := 22.0
const PLAYER := {"hp": 150, "speed": 115.0, "damage": 34, "cooldown": 3.2, "color": Color("#e5cb93")}
const PROJECTILE_START := 15.0
const BLADE_CUES := {"long_blade": [0.17, 0.43, 0.69], "dual_blades": [0.13, 0.33, 0.54, 0.75], "sword": [0.20, 0.56]}
const BLADE_SLICES := {
	"long_blade": [Vector2(0.0, 0.27), Vector2(0.27, 0.56), Vector2(0.56, 1.0)],
	"dual_blades": [Vector2(0.0, 0.54), Vector2(0.54, 1.0), Vector2(0.0, 0.45), Vector2(0.45, 1.0)],
	"sword": [Vector2(0.0, 0.42), Vector2(0.42, 1.0)]
}
# 远程形制：普攻放弹道，不用贴身。法器（法杖、短杖）的弹道带溅射。
const RANGED_FORMS := ["bow", "staff", "wand"]
const SPELL_FORMS := ["staff", "wand"]
# 长枪一枪扎出去的宽度：只扫到枪杆这一路，前后站成一串的都会被穿。
const THRUST_WIDTH := 30.0
const ATTACK_BUFFER := 0.16
const COMBO_WINDOW := 1.25
# 连战每层三波：两波成群的小怪，最后一波是层主。
const WAVE_SIZES := [5, 7, 1]
# 小怪成群：单只的血量、伤害和个头都比层主小得多，一轮连斩正好清掉贴身的一排。
# 血量与伤害是相对同层「散怪」公式的倍率；drop 把挂机每只怪的掉落折回去，材料流水不因怪多而涨。
const MINION := {"hp": 0.55, "damage": 0.60, "size": 48.0, "radius": 13.0, "drop": 0.56, "charge": 1.5}
# 怪群按三路纵深、一列一列地从前方压上来。
const HORDE_ROWS := [0.0, -66.0, 66.0]
const HORDE_COLUMN := 88.0
const FARM_HORDE := 5
# 小怪隔着一路纵深也能出手，所以被围住时两侧的也会咬人；离得远时小跑着压上来，一群怪几乎同时到。
const FLANK_DEPTH := 72.0
const CHARGE_DISTANCE := 170.0
const FARM_SPAWN_INTERVAL := 0.5
const WAVE_SPACING := 176.0
const RUN_SPEED := 228.0
const ENEMY_ATTACK_WINDUP := 0.22
const ENEMY_ATTACK_RECOVERY := 0.26
const ENEMY_DEATH_DURATION := 0.46
const ENEMY_DEATH_LIFETIME := 0.75
# 击打特效的寿命按图集的播放帧数定（FxArt：普通 10 帧、暴击 14 帧，30 fps）。
# 战斗不 preload 画面层，两边由测试对齐。
const HIT_LIFETIME := 10.0 / 30.0
const CRIT_LIFETIME := 14.0 / 30.0
enum ControlMode { MANUAL, ASSISTED, AUTOMATIC }

var weapon_form := "long_blade"
# 斩击与弹道的颜色由兵器的五行决定，画面层在换装备时写进来。
var trail_color := Color("#e5cb93")
# 武器主行，决定击打特效取哪一行配色；空手为空串。由画面层按外观写入。
var hit_element := ""
var hero: Dictionary = PLAYER
var position := HOME
var hp := 156
var max_hp := 156
var kills := 0
var result: StringName
var mana := MAX_MANA
var max_mana := MAX_MANA
var mana_recovery := 10.0
var skill_cost := SKILL_COST
var tactic_cost := TACTIC_COST
var retreat_cooldown := 1.35
var damage_reduction := 0.0
var crit_chance := 0.0
var basic_critical := false
var thorns := 0
var kill_heal := 0
var gear_attack := 0
var materials_found := 0
var loot_rng := RandomNumberGenerator.new()
var combat_rng := RandomNumberGenerator.new()
var skill_left := 0.0
var tactic_left := 0.0
var retreat_left := 0.0
var invulnerable := 0.0
var dodge_left := 0.0
var dodge_moves := false
var stride := 0.0
var step_direction := Vector2.RIGHT
var facing := 0.0
var motion: StringName
var motion_time := 0.0
var motion_duration := 0.0
var attack_buffer_left := 0.0
var strike_contacts := {}
var combo_hits := 0
var combo_left := 0.0
var dungeon_layer := 1
var challenging := false
var continuous := false
var wave_index := 0
var section_x := 0.0
var advancing := false
var encounter_stem := "jia"
var archetype: Dictionary = ARCHETYPES.jia
var spawn_in := 0.0
var serial_counter := 0
var player_slow := 0.0
var gear := {}
var shield := 0.0
var companions := 0
var companion_left := 0.75
var recovery_left := 1.0
var hits := 0
var damage_taken := 0
var trigger_tokens := {}

var enemies: Array[Dictionary] = []
var fallen_enemies: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var drops: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var popups: Array[Dictionary] = []
# 给画面层用的打击事件队列：震屏、顿帧、闪白都从这里取，不参与任何结算。
var pulses: Array[Dictionary] = []

const MAX_PULSES := 12

func _init() -> void:
	loot_rng.randomize()
	combat_rng.randomize()

func reset(layer: int, bonuses: Dictionary, form: String, boss_fight: bool = false, stem: String = "",
		continuous_route: bool = false) -> void:
	dungeon_layer = layer
	challenging = boss_fight
	continuous = boss_fight and continuous_route
	wave_index = 0
	section_x = 0.0
	advancing = false
	encounter_stem = Gear.WuXing.ling_of(layer) if stem.is_empty() else stem
	archetype = ARCHETYPES[encounter_stem]
	spawn_in = 0.88
	serial_counter = 0
	player_slow = 0.0
	_apply_equipment(bonuses, form)
	basic_critical = false
	position = HOME
	hp = max_hp
	shield = _stat("shield")
	kills = 0
	materials_found = 0
	result = &""
	mana = max_mana
	skill_cost = SKILL_COST
	tactic_cost = TACTIC_COST
	skill_left = 0.0
	tactic_left = 0.0
	retreat_left = 0.0
	invulnerable = 0.0
	dodge_left = 0.0
	dodge_moves = false
	stride = 0.0
	step_direction = Vector2.RIGHT
	facing = 0.0
	motion = &""
	attack_buffer_left = 0.0
	strike_contacts.clear()
	combo_hits = 0
	combo_left = 0.0
	companion_left = 0.75
	recovery_left = 1.0
	hits = 0
	damage_taken = 0
	trigger_tokens.clear()
	enemies.clear()
	fallen_enemies.clear()
	shots.clear()
	drops.clear()
	effects.clear()
	popups.clear()
	pulses.clear()
	if challenging:
		_spawn_wave()
	else:
		_spawn_enemy(0.28)
		_spawn_enemy(0.50)
	_trigger("战斗开始时")

func refresh_equipment(bonuses: Dictionary, form: String) -> void:
	var health_ratio := float(hp) / float(max_hp)
	var mana_ratio := mana / max_mana
	var old_shield := _stat("shield")
	if form != weapon_form:
		motion = &""
		attack_buffer_left = 0.0
	_apply_equipment(bonuses, form)
	hp = maxi(1, roundi(health_ratio * float(max_hp)))
	mana = mana_ratio * max_mana
	var new_shield := _stat("shield")
	shield = minf(new_shield, shield + maxf(0.0, new_shield - old_shield))

func _apply_equipment(bonuses: Dictionary, form: String) -> void:
	weapon_form = form
	hero = PLAYER.duplicate()
	gear = bonuses
	var weapon: Dictionary = Gear.WEAPON_FORMS[form]
	hero.interval = float(weapon.interval) / (1.0 + _stat("attack_speed") / 100.0)
	hero.reach = weapon.reach
	gear_attack = roundi(_stat("attack"))
	hero.damage = roundi(float(PLAYER.damage) * _stat("attack_multiplier", 1.0)) + gear_attack
	hero.speed *= 1.0 + _stat("speed") / 100.0
	damage_reduction = clampf(_stat("armor") / 100.0, 0.0, 0.75)
	crit_chance = clampf(_stat("crit") / 100.0, 0.0, 0.75)
	thorns = roundi(_stat("thorns") + _stat("deflect"))
	kill_heal = roundi(_stat("kill_heal"))
	retreat_cooldown = maxf(0.45, 1.35 - _stat("dodge_ms") / 1000.0)
	max_hp = maxi(1, roundi((float(PLAYER.hp) + _stat("hp")) * _stat("hp_multiplier", 1.0)))
	max_mana = MAX_MANA + _stat("mana")
	mana_recovery = 10.0 + _stat("regen")
	companions = int(gear.get("companions", 0))

const BUSY_MOTIONS := [&"attack", &"skill", &"tactic", &"retreat"]

func attack(buffer := true) -> void:
	# 受击与复活只是演出，不该锁住出手；真正占手的是自己的四个动作。
	if result != &"" or advancing:
		return
	if motion in BUSY_MOTIONS:
		if buffer and motion != &"retreat":
			attack_buffer_left = ATTACK_BUFFER
		return
	facing = _direction_to_enemy()
	attack_buffer_left = 0.0
	strike_contacts.clear()
	_start_motion(&"attack", hero.interval)

func attack_cues() -> Array:
	const SINGLE := {"hammer": 0.53, "spear": 0.40}
	return BLADE_CUES.get(weapon_form, [SINGLE.get(weapon_form, 1.0 / 3.0)])

func skill() -> void:
	if result != &"" or advancing or skill_left > 0.0 or dodge_left > 0.0 or mana < skill_cost:
		return
	facing = _direction_to_enemy()
	mana -= skill_cost
	skill_left = float(hero.cooldown) * (1.0 - _stat("cooldown") / 100.0)
	_start_motion(&"skill", 0.34)
	var power := roundi(float(hero.damage) * 1.65 + _stat("skill_damage") + _stat("elemental_power"))
	var form := &"seal_burst"
	if weapon_form == "bow":
		form = &"arrow_seal"
		for spread in [-0.20, 0.0, 0.20]:
			_fire(facing + spread, power, 880.0, hero.reach, 2, 0.0, false, true)
	elif weapon_form in SPELL_FORMS:
		form = &"spell_seal"
		_fire(facing, power, 660.0, hero.reach, 1, 105.0, false, true)
	else:
		_crush(position + Vector2.from_angle(facing) * 65.0, 125.0, power, 200.0)
	var center := position + Vector2.from_angle(facing) * 65.0 if form == &"seal_burst" else position
	_cast_effect(form, center, trail_color, 125.0 if form == &"seal_burst" else 65.0)
	_trigger("消耗灵力时")
	_trigger("释放技能时")
	_pulse(&"cast", position, 1.2)
	feedback.emit(&"skill")

func tactic() -> void:
	if result != &"" or advancing or tactic_left > 0.0 or dodge_left > 0.0 or mana < tactic_cost:
		return
	facing = _direction_to_enemy()
	mana -= tactic_cost
	tactic_left = 4.6 * (1.0 - _stat("cooldown") / 100.0)
	_start_motion(&"tactic", 0.42)
	var power := roundi(float(hero.damage) * 1.20 + _stat("skill_damage"))
	var center := position + Vector2.from_angle(facing) * 78.0
	_crush(center, 118.0, power, 310.0)
	_cast_effect(&"quake_seal", center, Color("#e7b46e"), 118.0)
	_trigger("消耗灵力时")
	_trigger("释放技能时")
	_pulse(&"stomp", position, 1.5)
	feedback.emit(&"skill")

func retreat(travel := true) -> void:
	if result != &"" or advancing or retreat_left > 0.0:
		return
	dodge_left = 0.31
	dodge_moves = travel
	retreat_left = retreat_cooldown
	attack_buffer_left = 0.0
	_start_motion(&"retreat", 0.38)
	_ring(position, Color("#cfc3dd"), 39)
	_trigger("后撤后")
	_pulse(&"dash", position, 0.6)
	feedback.emit(&"retreat")

func step(delta: float, direction: Vector2 = Vector2.ZERO, hold_attack: bool = false,
		control_mode: ControlMode = ControlMode.MANUAL) -> void:
	if result != &"":
		return
	var assisted := challenging and not advancing and control_mode != ControlMode.MANUAL \
		and direction.is_zero_approx() and not hold_attack
	var target := _nearest_enemy() if not challenging or assisted else {}
	if challenging and not direction.is_zero_approx() and not hold_attack and motion == &"attack":
		motion = &""
	if advancing:
		hold_attack = false
	elif not challenging:
		direction = Vector2.ZERO
		hold_attack = _basic_attack_reaches(target)
	elif assisted and control_mode == ControlMode.AUTOMATIC and _in_imminent_danger(target):
		retreat(false)
	_step_player(delta, direction)
	if not challenging:
		_farm_actions(target)
	elif assisted and not target.is_empty():
		if control_mode == ControlMode.AUTOMATIC:
			_farm_actions(target)
		hold_attack = _basic_attack_reaches(target)
	elif hold_attack and not direction.is_zero_approx():
		hold_attack = _basic_attack_reaches(_nearest_enemy())
	if hold_attack or (attack_buffer_left > 0.0 and motion.is_empty()):
		attack(false)
	_step_shots(delta)
	_step_enemies(delta)
	_step_drops(delta)
	_tick_bonus(delta)
	combo_left = maxf(0.0, combo_left - delta)
	if combo_left == 0.0:
		combo_hits = 0
	for effect in effects:
		effect.life -= delta
	for popup in popups:
		popup.life -= delta
		popup.offset.y -= 12.0 * delta
	effects = effects.filter(func(effect: Dictionary) -> bool: return effect.life > 0.0)
	popups = popups.filter(func(popup: Dictionary) -> bool: return popup.life > 0.0)
	if challenging:
		if hp <= 0:
			result = &"defeat"
		elif enemies.is_empty() and not advancing:
			if boss_wave():
				result = &"victory"
			else:
				advancing = true
				stride = 0.0
				facing = 0.0
				motion = &""
				attack_buffer_left = 0.0
				dodge_left = 0.0
				shots.clear()
		return
	if hp <= 0:
		hp = max_hp
		mana = max_mana
		shield = _stat("shield")
		invulnerable = 1.2
		_start_motion(&"revive", 0.62)
		_ring(position, Color("#a4db99"), 62.0)
		_pulse(&"revive", position, 1.0)
	spawn_in = maxf(0.0, spawn_in - delta)
	if spawn_in == 0.0 and enemies.size() < FARM_HORDE:
		_spawn_enemy()
		spawn_in = FARM_SPAWN_INTERVAL

func _strike_padding(enemy: Dictionary) -> float:
	return maxf(float(enemy.stats.radius) * 0.55, float(enemy.body.x) - 23.0)

func _basic_attack_reaches(enemy: Dictionary) -> bool:
	if enemy.is_empty() or enemy.hp <= 0 or enemy.spawn > 0.0:
		return false
	var reach := float(hero.reach)
	if weapon_form not in RANGED_FORMS:
		reach = minf(reach + _strike_padding(enemy), _enemy_contact_distance(enemy) + 26.0)
	return position.distance_to(enemy.pos) < reach - 3.0

func _enemy_contact_distance(enemy: Dictionary) -> float:
	return PLAYER_BODY.x + float(enemy.body.x) + BODY_MARGIN.x

# 沿前后、纵深逐轴截住位移。移动者只改变自己的落点。
func _move_body(origin: Vector2, step: Vector2, body: Vector2, bounds: Rect2, mover: Dictionary = {}) -> Vector2:
	var point := origin
	for axis in range(2):
		if is_zero_approx(step[axis]):
			continue
		var desired := clampf(point[axis] + step[axis], bounds.position[axis], bounds.end[axis])
		if not mover.is_empty():
			desired = _clip_body_axis(point, desired, position, body + PLAYER_BODY + BODY_MARGIN, axis)
		for other in enemies:
			if other.spawn > 0.0 or other.hp <= 0 or is_same(mover, other):
				continue
			desired = _clip_body_axis(point, desired, other.pos, body + Vector2(other.body) + BODY_MARGIN, axis)
		point[axis] = desired
	return point

static func _clip_body_axis(point: Vector2, desired: float, other: Vector2, clearance: Vector2, axis: int) -> float:
	var cross_axis := 1 - axis
	if absf(point[cross_axis] - other[cross_axis]) >= clearance[cross_axis]:
		return desired
	if desired > point[axis] and other[axis] > point[axis]:
		return maxf(point[axis], minf(desired, other[axis] - clearance[axis]))
	if desired < point[axis] and other[axis] < point[axis]:
		return minf(point[axis], maxf(desired, other[axis] + clearance[axis]))
	return desired

static func _bodies_overlap(point: Vector2, other: Vector2, clearance: Vector2) -> bool:
	return absf(point.x - other.x) < clearance.x and absf(point.y - other.y) < clearance.y

func _spawn_space_clear(enemy: Dictionary) -> bool:
	var body: Vector2 = enemy.body
	if _bodies_overlap(enemy.pos, position, body + PLAYER_BODY + BODY_MARGIN):
		return false
	for other in enemies:
		if other.spawn <= 0.0 and other.hp > 0 and not is_same(enemy, other):
			if _bodies_overlap(enemy.pos, other.pos, body + Vector2(other.body) + BODY_MARGIN):
				return false
	return true

func _place_spawning_enemy(enemy: Dictionary, bounds: Rect2) -> bool:
	var preferred: Vector2 = enemy.pos
	var front := maxf(preferred.x, position.x + _enemy_contact_distance(enemy) + 24.0)
	for x in [preferred.x, front, bounds.end.x]:
		for y in [preferred.y, HOME.y - 72.0, HOME.y + 72.0]:
			enemy.pos = Vector2(clampf(x, bounds.position.x, bounds.end.x), clampf(y, bounds.position.y, bounds.end.y))
			if _spawn_space_clear(enemy):
				return true
	enemy.pos = preferred
	return false

func _in_imminent_danger(target: Dictionary) -> bool:
	if target.is_empty() or target.windup <= 0.0 or target.windup > 0.28 or retreat_left > 0.0:
		return false
	var gap: Vector2 = position - target.strike_at
	gap.y /= TELEGRAPH_ASPECT
	return gap.length_squared() <= float(target.strike_radius) * float(target.strike_radius)

func _farm_actions(target: Dictionary) -> void:
	if target.is_empty() or motion != &"":
		return
	var gap := position.distance_to(target.pos)
	var reach := float(hero.reach)
	if weapon_form not in RANGED_FORMS:
		reach = maxf(155.0, reach + _strike_padding(target))
	if gap < reach:
		if skill_left <= 0.0 and mana >= skill_cost:
			skill()
		elif tactic_left <= 0.0 and mana >= tactic_cost and gap < 175.0:
			tactic()

func boss_wave() -> bool:
	return challenging and (not continuous or wave_index == WAVE_SIZES.size() - 1)

func _spawn_wave() -> void:
	if boss_wave():
		_spawn_enemy(0.62)
	else:
		for slot in range(WAVE_SIZES[wave_index]):
			_spawn_enemy(0.22 + slot * 0.07)

func _spawn_enemy(delay: float = 0.38) -> void:
	var strong := boss_wave()
	var tribulation := strong and not Gear.Realm.jie_ling_of(dungeon_layer).is_empty()
	var growth := float(dungeon_layer - 1)
	var scale_hp := (67.0 + growth * 2.2) * float(MINION.hp) if not strong else (245.0 + growth * 11.0)
	var scale_damage := (7.5 + growth * 0.36) * float(MINION.damage) if not strong else 35.0 + growth * 1.25
	if tribulation:
		scale_hp *= 1.60
		scale_damage *= 1.24
	var max_health := maxi(1, roundi(scale_hp * float(archetype.vitality)))
	var offset := Vector2(196.0, 0.0)
	if not strong:
		# 连战按波内次序排位；挂机的怪陆续补进来，按出生序号轮着占三路。
		var slot := enemies.size() if challenging else serial_counter % (HORDE_ROWS.size() * 2)
		var row := slot % HORDE_ROWS.size()
		offset = Vector2(150.0 + floorf(slot / float(HORDE_ROWS.size())) * HORDE_COLUMN + (0.0 if row == 0 else 24.0),
			HORDE_ROWS[row])
	# 同一种怪挤在一起，个头略有参差才不像复制出来的。只影响画面，身位仍按标准个头算。
	var base_size := 118.0 if tribulation else (107.0 if strong else float(MINION.size))
	var stats := {"radius": 29.0 if strong else float(MINION.radius),
		"size": base_size if strong else base_size * (0.92 + 0.08 * float(serial_counter % 3)),
		"speed": float(archetype.speed) * (0.83 if strong else 1.0),
		"damage": maxi(1, roundi(scale_damage * float(archetype.force)))}
	var danger_radius := float(archetype.radius) * (1.23 if tribulation else 1.0)
	var body := Vector2(base_size * ENEMY_BODY_WIDTHS[archetype.art], 35.0 if strong else 31.0)
	var preferred := HOME + offset + Vector2(section_x, 0.0)
	enemies.append({"serial": serial_counter, "pos": preferred, "art": archetype.art, "hp": max_health, "body": body,
		"max_hp": max_health, "stats": stats, "boss": strong, "spawn": delay, "hit": 0.0,
		"cooldown": 1.2 if strong else 0.15, "windup": 0.0, "windup_total": archetype.windup, "strike_at": Vector2.ZERO,
		"strike_radius": danger_radius, "stride": 0.0, "moving": false,
		"attack_windup": 0.0, "attack_recovery": 0.0, "stagger": 0.0, "slow": 0.0})
	serial_counter += 1

func collect_pending_materials() -> void:
	for drop in drops:
		material_collected.emit(drop.material, drop.quantity)
	drops.clear()

func _start_motion(kind: StringName, duration: float) -> void:
	motion = kind
	motion_time = 0.0
	motion_duration = duration

func track_steps(previous: Vector2) -> void:
	var movement := position - previous
	var distance := movement.length()
	if distance <= 0.001 or not motion.is_empty():
		stride = 0.0
		return
	var direction := movement / distance
	if step_direction.dot(direction) < 0.5:
		stride = 0.0
	stride += distance
	step_direction = direction

func _step_player(delta: float, direction: Vector2) -> void:
	var old := position
	var was_advancing := advancing
	var bounds := Rect2(FOOTWORK.position + Vector2(section_x, 0.0), FOOTWORK.size)
	if advancing:
		var destination := HOME + Vector2(section_x + WAVE_SPACING, 0.0)
		position = position.move_toward(destination, RUN_SPEED * delta)
		if position == destination:
			section_x += WAVE_SPACING
			wave_index += 1
			advancing = false
			_spawn_wave()
	elif dodge_left > 0.0 and dodge_moves:
		var target := _nearest_enemy()
		var away := 1.0 if not target.is_empty() and target.pos.x < position.x else -1.0
		var step := Vector2(away * minf(delta, dodge_left) * 300.0, 0.0)
		position = _move_body(position, step, PLAYER_BODY, bounds)
	elif motion.is_empty():
		var pace := 0.58 if player_slow > 0.0 else 1.0
		var motion_step := direction.limit_length() * float(hero.speed) * pace * delta * Vector2(1.0, 0.48)
		position = _move_body(position, motion_step, PLAYER_BODY, bounds)
	player_slow = maxf(0.0, player_slow - delta)
	if was_advancing and not advancing:
		stride = 0.0
	else:
		track_steps(old)
	mana = minf(max_mana, mana + delta * mana_recovery)
	skill_left = maxf(0.0, skill_left - delta)
	tactic_left = maxf(0.0, tactic_left - delta)
	retreat_left = maxf(0.0, retreat_left - delta)
	invulnerable = maxf(0.0, invulnerable - delta)
	dodge_left = maxf(0.0, dodge_left - delta)
	attack_buffer_left = maxf(0.0, attack_buffer_left - delta)
	if motion != &"":
		var previous := motion_time
		motion_time += delta
		if motion == &"attack":
			var cues := attack_cues()
			for index in range(cues.size()):
				var release := motion_duration * float(cues[index])
				if previous < release and motion_time >= release:
					_release_attack(index)
		if motion_time >= motion_duration:
			motion = &""

func _nearest_enemy() -> Dictionary:
	var closest: Dictionary = {}
	var distance := INF
	for enemy in enemies:
		if enemy.spawn > 0.0 or enemy.hp <= 0:
			continue
		var gap := position.distance_squared_to(enemy.pos)
		if gap < distance:
			distance = gap
			closest = enemy
	return closest

func _direction_to_enemy() -> float:
	var target := _nearest_enemy()
	return 0.0 if target.is_empty() else (Vector2(target.pos) - position).angle()

func _release_attack(index: int) -> void:
	if index == 0:
		basic_critical = combat_rng.randf() < crit_chance
	var damage: int = hero.damage
	if basic_critical:
		damage = roundi(float(damage) * (1.5 + (_stat("crit_damage") + _stat("keen_sight")) / 100.0))
	match weapon_form:
		"hammer":
			_crush(position + Vector2.from_angle(facing) * 36.0, float(hero.reach) - 30.0, damage, 295.0, basic_critical)
			feedback.emit(&"hammer_hit")
		"long_blade", "dual_blades", "sword":
			_blade_strike(index, damage)
		"spear":
			_thrust(damage)
		"bow":
			_fire(facing, damage, 910.0, hero.reach, 2, 0.0, basic_critical)
			feedback.emit(&"shot")
		"staff":
			_fire(facing, damage, 640.0, hero.reach, 1, 53.0, basic_critical)
			feedback.emit(&"shot")
		"wand":
			_fire(facing, damage, 760.0, hero.reach, 1, 34.0, basic_critical)
			feedback.emit(&"shot")

# 长枪：沿面朝方向一条窄路上的全扎到，离得最远的那只也吃满伤害。
func _thrust(damage: int) -> void:
	var forward := Vector2.from_angle(facing)
	var reach: float = hero.reach
	effects.append({"type": &"thrust", "pos": position, "angle": facing, "color": trail_color,
		"radius": reach, "life": 0.20, "duration": 0.20})
	for enemy in enemies:
		var gap: Vector2 = enemy.pos - position
		var along := gap.dot(forward)
		if enemy.spawn > 0.0 or enemy.hp <= 0 or along <= -6.0 or along >= reach + _strike_padding(enemy) \
				or absf(gap.dot(forward.orthogonal())) > THRUST_WIDTH + float(enemy.stats.radius) * 0.5:
			continue
		_damage_enemy(enemy, damage, 150.0, basic_critical)
	feedback.emit(&"slash_finish")

func _blade_strike(index: int, damage: int) -> void:
	var slices: Array = BLADE_SLICES[weapon_form]
	var final := index == slices.size() - 1
	var second_pair := weapon_form == "dual_blades" and index >= 2
	var group := int(second_pair)
	var raw := roundi(damage * 0.62) if second_pair else damage
	var reach: float = hero.reach
	var angle := facing + (0.25 if second_pair else -0.25) if weapon_form == "dual_blades" else facing
	var lifetime := 0.24 if final else 0.15
	effects.append({"type": &"flurry", "pos": position, "angle": facing, "color": trail_color,
		"radius": reach, "life": lifetime, "duration": lifetime, "stroke": index, "finisher": final})
	for enemy in enemies:
		var gap: Vector2 = enemy.pos - position
		if enemy.spawn > 0.0 or enemy.hp <= 0 or gap.length() >= reach + _strike_padding(enemy) \
				or cos(gap.angle() - angle) <= -0.05:
			continue
		# 副切片共享原本的一次命中触发，双刀仍有两次独立触发机会。
		var first_contact: bool = strike_contacts.get(enemy.serial, -1) != group
		if _damage_enemy(enemy, raw, 92.0 if final else 8.0, basic_critical, false, slices[index], first_contact):
			strike_contacts[enemy.serial] = group
	feedback.emit(&"slash_finish" if final else &"slash")

func _crush(center: Vector2, radius: float, damage: int, force: float, critical: bool = false) -> void:
	effects.append({"type": &"crush", "pos": center, "color": Color("#ffcb86"), "radius": radius, "life": 0.34, "duration": 0.34})
	for enemy in enemies:
		if center.distance_to(enemy.pos) < radius + _strike_padding(enemy):
			_damage_enemy(enemy, damage, force, critical)

func _fire(angle: float, damage: int, speed: float, reach: float, hits: int = 1, splash: float = 0.0,
		critical: bool = false, empowered: bool = false) -> void:
	var forward := Vector2.from_angle(angle)
	shots.append({"pos": position + forward * PROJECTILE_START, "source": position, "reach": reach,
		"velocity": forward * speed, "life": (reach - PROJECTILE_START) / speed, "damage": damage,
		"magic": weapon_form in SPELL_FORMS, "wand": weapon_form == "wand", "color": trail_color, "hits": hits, "struck": [],
		"splash": splash, "critical": critical, "empowered": empowered})

func _cast_effect(kind: StringName, point: Vector2, color: Color, radius: float) -> void:
	const DURATION := 0.47
	effects.append({"type": kind, "pos": point, "angle": facing, "color": color,
		"radius": radius, "life": DURATION, "duration": DURATION})

func _ring(point: Vector2, color: Color, radius: float, effect_type: StringName = &"ring") -> void:
	const LIFETIME := 0.38
	effects.append({"type": effect_type, "pos": point, "color": color, "radius": radius, "life": LIFETIME, "duration": LIFETIME})

# 击中：只记下在哪、打的是多高的东西、暴没暴、用哪一行五行配色、朝哪边飞溅。画面层查图集。
# 暴击只在一刀的首次接触上显示，与 _pulse 的「crit」口径一致，免得连斩每一段都炸一次。
func _impact(enemy: Dictionary, critical: bool) -> void:
	var lifetime := CRIT_LIFETIME if critical else HIT_LIFETIME
	effects.append({"type": &"impact", "pos": enemy.pos, "radius": enemy.stats.size, "angle": facing,
		"critical": critical, "element": hit_element, "color": trail_color, "life": lifetime, "duration": lifetime})

# 只记录「发生了什么、在哪里、多重」，画面层自行决定震多少、顿多久。
func _pulse(kind: StringName, point: Vector2, power: float) -> void:
	pulses.append({"kind": kind, "pos": point, "power": power})
	if pulses.size() > MAX_PULSES:
		pulses = pulses.slice(pulses.size() - MAX_PULSES)

func _damage_enemy(enemy: Dictionary, damage: int, force: float, critical: bool = false, secondary: bool = false,
		slice: Vector2 = Vector2(0.0, 1.0), primary_hit: bool = true) -> bool:
	if enemy.spawn > 0.0 or enemy.hp <= 0:
		return false
	var heal_after_hit := 0.0
	var full_damage := damage
	if not secondary:
		damage += roundi(_stat("impact") * 0.55 + _stat("pressure") * 0.25)
		var resistance := (0.11 if enemy.boss else 0.03) - (_stat("armor_break") + _stat("penetration")) / 100.0
		damage = maxi(1, roundi(float(damage) * (1.0 - maxf(0.0, resistance - float(enemy.get("breach", 0.0))))))
		damage = maxi(1, roundi(float(damage) * _stat("weapon_matchup", 1.0)))
		full_damage = damage
		damage = roundi(full_damage * slice.y) - roundi(full_damage * slice.x)
		if damage == 0:
			return false
		heal_after_hit = float(damage) * _stat("feed_enemy_ratio")
		if primary_hit:
			force += _stat("impact") * 5.0
	enemy.hp -= damage
	if heal_after_hit > 0.0 and enemy.hp > 0:
		enemy.hp = mini(enemy.max_hp, int(enemy.hp) + roundi(heal_after_hit))
	enemy.hit = 0.15
	if force >= 180.0:
		_stagger_enemy(enemy, force)
	var popup_offset := Vector2.ZERO
	if not secondary:
		combo_hits += 1
		combo_left = COMBO_WINDOW
		var stagger := combo_hits % 3 - 1
		popup_offset = Vector2(stagger * 22.0, -absf(stagger) * 16.0)
		_impact(enemy, critical and primary_hit)
		_pulse(&"crit" if critical and primary_hit else &"hit", enemy.pos, clampf(float(damage) / maxf(float(hero.damage), 1.0), 0.3, 2.2))
	popups.append({"pos": enemy.pos, "height": enemy.stats.size, "offset": popup_offset,
		"text": str(damage), "life": 0.6, "critical": critical})
	if not secondary and primary_hit:
		var alive: bool = enemy.hp > 0
		var leech := _stat("lifesteal") + _stat("drain")
		if leech > 0.0:
			_heal(float(full_damage) * minf(0.60, leech / 100.0))
		if alive:
			var burn := _stat("burn") + _stat("venom") + _stat("ignite") + _stat("scorch_armor")
			if burn > 0.0:
				_mark_damage(enemy, burn * (1.0 + _stat("burn_damage") / 100.0), 2.0 + _stat("ignite_cap") * 0.03)
			if _stat("chill") + _stat("pressure") > 0.0:
				enemy.slow = maxf(enemy.slow, 0.45 + (_stat("chill") + _stat("pressure") + _stat("slow_power")) / 100.0)
			_trigger_hit(enemy, force, critical)
			_clash(enemy)
			if challenging:
				_companion_strike(enemy)
		if alive:
			return true
	if enemy.hp > 0:
		return true
	kills += 1
	fallen_enemies.append({"pos": enemy.pos, "art": enemy.art, "height": enemy.stats.size,
		"facing": -1.0 if enemy.pos.x > position.x else 1.0, "age": 0.0})
	if kill_heal > 0:
		_heal(float(kill_heal))
	if not challenging:
		var amount := Gear.roll_farm_quantity(loot_rng, kills == 1,
			_stat("material_drop_multiplier", 1.0) * float(MINION.drop))
		if amount > 0:
			drops.append({"pos": enemy.pos, "material": encounter_stem, "quantity": amount,
				"age": 0.0, "collected": false})
	_ring(enemy.pos - Vector2(0, 12), Color("#d28f58"), 41)
	_pulse(&"kill", enemy.pos, 1.6 if enemy.boss else 0.7)
	if not secondary:
		_trigger("击杀时", enemy)
		if kill_heal > 0:
			_trigger("击杀回血时", enemy)
	return true

func _stagger_enemy(enemy: Dictionary, force: float) -> void:
	var duration := minf(force / 1600.0, 0.22) * (0.28 if enemy.boss else 1.0)
	enemy.stagger = maxf(enemy.stagger, duration)

func advance_enemy_deaths(delta: float) -> void:
	for index in range(fallen_enemies.size() - 1, -1, -1):
		var fallen := fallen_enemies[index]
		fallen.age += delta
		if fallen.age >= ENEMY_DEATH_LIFETIME:
			fallen_enemies.remove_at(index)

func enemy_fall_in_progress() -> bool:
	return not fallen_enemies.is_empty() and float(fallen_enemies.back().age) < ENEMY_DEATH_DURATION

func _damage_player(damage: int, attacker: Dictionary = {}) -> void:
	if invulnerable > 0.0:
		return
	if dodge_left > 0.0 or combat_rng.randf() < (_stat("dodge") + _stat("keen_step")) / 100.0:
		_trigger("闪避成功时", attacker)
		return
	invulnerable = 0.49 + _stat("stability") * 0.002
	var incoming := float(damage) * (1.0 - damage_reduction)
	if combat_rng.randf() < _stat("block") / 100.0:
		incoming *= 0.5
		_trigger("格挡成功时", attacker)
	if shield > 0.0:
		var absorbed := minf(shield, incoming)
		shield -= absorbed
		incoming -= absorbed
		if shield <= 0.0:
			_trigger("护盾破裂时", attacker)
	var loss := maxi(0, roundi(incoming - _stat("mitigation") * 0.16))
	if loss >= hp:
		_trigger("受致命伤时（每局 1 次）", attacker, true)
	hp = maxi(0, hp - loss)
	if loss > 0:
		combo_hits = 0
		combo_left = 0.0
	attack_buffer_left = 0.0
	_start_motion(&"hurt", 0.34)
	_ring(position, Color("#ec756f"), 34)
	_pulse(&"hurt", position, clampf(float(loss) / maxf(float(max_hp) * 0.12, 1.0), 0.5, 2.4))
	feedback.emit(&"hurt")
	damage_taken += 1
	_trigger("受击时", attacker)
	if damage_taken == 10:
		_trigger("受击累计 10 次", attacker)
	if hp * 2 < max_hp:
		_trigger("生命低于 50%", attacker)
	if _stat("energy_absorb") > 0.0:
		mana = minf(max_mana, mana + _stat("energy_absorb"))
		_trigger("受击回蓝时", attacker)
	if thorns > 0 and hp > 0 and not attacker.is_empty():
		_damage_enemy(attacker, thorns, 0.0, false, true)
		_trigger("荆棘触发时", attacker)
		_ring(attacker.pos, Color("#f1bc76"), 26.0)

func _step_enemies(delta: float) -> void:
	var bounds := Rect2(ENEMY_FOOTWORK.position + Vector2(section_x, 0.0), ENEMY_FOOTWORK.size)
	for enemy in enemies:
		if enemy.hp <= 0:
			continue
		if enemy.spawn > 0.0:
			enemy.spawn -= delta
			if enemy.spawn <= 0.0 and not _place_spawning_enemy(enemy, bounds):
				enemy.spawn = 0.12
			continue
		if float(enemy.get("dot_time", 0.0)) > 0.0:
			enemy.dot_time -= delta
			enemy.dot_tick -= delta
			if enemy.dot_tick <= 0.0:
				enemy.dot_tick += 0.5
				_damage_enemy(enemy, maxi(1, roundi(float(enemy.dot) * 0.5)), 0.0, false, true)
				if enemy.hp <= 0:
					continue
			if enemy.dot_time <= 0.0:
				enemy.erase("dot")
				enemy.erase("dot_tick")
		var stats: Dictionary = enemy.stats
		var gap: Vector2 = enemy.pos - position
		var contact := _enemy_contact_distance(enemy)
		var abreast := absf(gap.x) <= contact + ENEMY_MELEE_MARGIN
		var near := abreast and absf(gap.y) <= 46.0
		# 小怪贴上来就咬，包括侧翼。层主的红圈招式不看这个（任何方向都放），engaged 只决定它还往不往前走。
		var engaged := near and _basic_attack_reaches(enemy) if enemy.boss else abreast and absf(gap.y) <= FLANK_DEPTH
		enemy.cooldown -= delta
		enemy.hit = maxf(0.0, enemy.hit - delta)
		enemy.slow = maxf(0.0, enemy.slow - delta)
		enemy.stagger = maxf(0.0, enemy.stagger - delta)
		enemy.attack_recovery = maxf(0.0, enemy.attack_recovery - delta)
		var attacking := _step_boss_skill(enemy, delta, gap.length()) if enemy.boss else _step_enemy_attack(enemy, delta, engaged)
		enemy.moving = false
		if not engaged and not attacking and enemy.attack_recovery <= 0.0 and enemy.stagger <= 0.0:
			var speed: float = stats.speed * (0.55 if enemy.slow > 0.0 else 1.0)
			if not enemy.boss and gap.length() > CHARGE_DISTANCE:
				speed *= float(MINION.charge)
			var side := -1.0 if gap.x < 0.0 else 1.0
			var destination := position + Vector2((contact + 2.0) * side, 0.0)
			var previous: Vector2 = enemy.pos
			var step := (destination - previous).limit_length(speed * delta)
			enemy.pos = _move_body(previous, step, enemy.body, bounds, enemy)
			var distance := previous.distance_to(enemy.pos)
			enemy.moving = distance > 0.02
			if enemy.moving:
				enemy.stride += distance
			else:
				enemy.stride = 0.0
	enemies = enemies.filter(func(enemy: Dictionary) -> bool: return enemy.hp > 0)

func _step_enemy_attack(enemy: Dictionary, delta: float, near: bool) -> bool:
	if enemy.attack_windup <= 0.0:
		if not near or enemy.stagger > 0.0 or enemy.cooldown > ENEMY_ATTACK_WINDUP:
			return false
		enemy.attack_windup = ENEMY_ATTACK_WINDUP
		return true
	enemy.attack_windup = maxf(0.0, enemy.attack_windup - delta)
	if enemy.attack_windup == 0.0:
		enemy.cooldown = 0.73
		enemy.attack_recovery = ENEMY_ATTACK_RECOVERY
		if near:
			_damage_player(enemy.stats.damage, enemy)
	return true

func _step_boss_skill(enemy: Dictionary, delta: float, gap: float) -> bool:
	if enemy.windup <= 0.0:
		if gap < maxf(float(enemy.strike_radius) + 49.0, _enemy_contact_distance(enemy) + 26.0) and enemy.cooldown <= 0.0 and enemy.stagger <= 0.0:
			enemy.windup = enemy.windup_total
			enemy.strike_at = position
			return true
		return false
	enemy.windup = maxf(0.0, enemy.windup - delta)
	if enemy.windup == 0.0:
		_ring(enemy.strike_at, Color("#f0805e"), enemy.strike_radius, &"crush")
		_pulse(&"quake", enemy.strike_at, 1.9)
		enemy.cooldown = 2.0
		enemy.attack_recovery = ENEMY_ATTACK_RECOVERY
		var gap_at_impact: Vector2 = position - enemy.strike_at
		gap_at_impact.y /= TELEGRAPH_ASPECT
		if gap_at_impact.length_squared() <= pow(enemy.strike_radius, 2):
			var before := hp
			_damage_player(enemy.stats.damage, enemy)
			if hp < before:
				_boss_hit_effect(enemy)
		feedback.emit(&"skill")
	return true

func _boss_hit_effect(enemy: Dictionary) -> void:
	match archetype.effect:
		"drain":
			mana = maxf(0.0, mana - 12.0)
		"heal":
			enemy.hp = mini(enemy.max_hp, int(enemy.hp) + roundi(float(enemy.max_hp) * 0.07))
		"knock":
			_start_motion(&"hurt", 0.42)
		"chill":
			player_slow = 1.1
		"flare":
			enemy.cooldown = 1.55

func _step_shots(delta: float) -> void:
	for shot in shots:
		shot.pos += shot.velocity * minf(delta, shot.life)
		shot.life -= delta
		for enemy in enemies:
			if enemy.spawn > 0.0 or enemy.hp <= 0 or shot.struck.has(enemy.serial):
				continue
			var radius: float = enemy.stats.radius + (8.0 if shot.magic else 3.0)
			if Vector2(shot.pos).distance_squared_to(enemy.pos) < radius * radius:
				_damage_enemy(enemy, shot.damage, 105.0 if shot.magic else 60.0, shot.critical)
				shot.struck.append(enemy.serial)
				shot.hits -= 1
				_ring(shot.pos - Vector2(0, 13), shot.color, maxf(24.0, shot.splash))
				if shot.get("empowered", false):
					_cast_effect(&"spell_impact" if shot.magic else &"arrow_impact", enemy.pos, shot.color,
						maxf(34.0, shot.splash))
				if shot.splash > 0.0:
					for target in enemies:
						if target.serial != enemy.serial and Vector2(enemy.pos).distance_to(target.pos) < shot.splash:
							_damage_enemy(target, roundi(shot.damage * 0.45), 48.0, shot.critical)
				if shot.hits == 0:
					shot.life = 0.0
					break
	shots = shots.filter(func(shot: Dictionary) -> bool: return shot.life > 0.0)

func _step_drops(delta: float) -> void:
	for drop in drops:
		drop.age += delta
		var gap := position.distance_to(drop.pos)
		if gap < 19.0:
			drop.collected = true
			materials_found += int(drop.quantity)
			material_collected.emit(drop.material, drop.quantity)
			_trigger("拾取材料时")
			feedback.emit(&"pickup")
		elif drop.age >= 0.35:
			drop.pos = Vector2(drop.pos).lerp(position, minf(1.0, delta * 8.5))
	drops = drops.filter(func(drop: Dictionary) -> bool: return not drop.collected)

func _stat(key: String, fallback: float = 0.0) -> float:
	return float(gear.get(key, fallback))

func _heal(amount: float, events: bool = true) -> void:
	var before := hp
	hp = mini(max_hp, hp + maxi(1, roundi(amount * (1.0 + _stat("healing") / 100.0)))) if amount > 0.0 else hp
	if hp > before and events:
		_trigger("治疗生效时")
		_trigger("生命回复时")
		if hp == max_hp:
			_trigger("生命回满时")

func _mark_damage(enemy: Dictionary, power: float, seconds: float) -> void:
	if power > float(enemy.get("dot", 0.0)):
		enemy.dot = power
	enemy.dot_time = maxf(float(enemy.get("dot_time", 0.0)), seconds)
	if not enemy.has("dot_tick"):
		enemy.dot_tick = 0.5

func _tick_bonus(delta: float) -> void:
	recovery_left -= delta
	if recovery_left <= 0:
		recovery_left += 1.0
		var regeneration := _stat("regeneration") + _stat("vitality")
		if not challenging:
			regeneration += float(max_hp) * 0.065
		if regeneration > 0.0:
			_heal(regeneration)
			_trigger("再生中时")
		if mana < max_mana:
			_trigger("回蓝时")
	companion_left = maxf(0.0, companion_left - delta)
	if not challenging and companions > 0:
		_companion_strike(_nearest_enemy())

func _companion_strike(target: Dictionary) -> void:
	if companions == 0 or companion_left > 0.0 or target.is_empty() or target.hp <= 0:
		return
	companion_left = 0.75
	var damage := roundi(float(hero.damage) * Gear.Origins.COMPANION_DPS_RATIO * companions * 0.75 / float(hero.interval))
	_ring(target.pos, Color("#b0d193"), 32.0)
	_damage_enemy(target, damage, 0.0, false, true)

func _trigger_hit(enemy: Dictionary, force: float, critical: bool) -> void:
	hits += 1
	if hits == 1:
		_trigger("首次命中时", enemy)
	if hits % 3 == 0:
		_trigger("每第 3 击", enemy)
	if hits % 5 == 0:
		_trigger("连续命中 5 次", enemy)
	if critical:
		_trigger("暴击时", enemy)
		_trigger("暴伤触发时", enemy)
	if force >= 200.0:
		_trigger("震慑目标时", enemy)
	if enemy.slow > 0.0:
		_trigger("命中被减速目标时", enemy)
		_trigger("目标被减速时", enemy)
	if float(enemy.get("dot_time", 0.0)) > 0.0:
		_trigger("目标燃烧时", enemy)
		if _stat("venom") > 0.0:
			_trigger("目标中毒时", enemy)
	if _stat("armor_break") > 0.0:
		_trigger("破甲命中时", enemy)
	if _stat("penetration") > 0.0:
		_trigger("穿甲生效时", enemy)
	if _stat("pressure") > 0.0:
		_trigger("目标被重压时", enemy)

func _trigger(condition: String, target: Dictionary = {}, once: bool = false) -> void:
	if once and trigger_tokens.has(condition):
		return
	for effect in gear.get("triggers", []):
		if effect.condition != condition:
			continue
		if once:
			trigger_tokens[condition] = true
		var enemy := target if not target.is_empty() and target.hp > 0 else _nearest_enemy()
		var action: Dictionary = effect.action
		var x: float = effect.strength
		match action.id:
			"heal": _heal(x * float(action.heal_scale), false)
			"shield": shield += x * float(action.shield_scale)
			"absorb": mana = minf(max_mana, mana + x * float(action.absorb_scale))
			_:
				if enemy.is_empty():
					continue
				match action.id:
					"entangle":
						enemy.slow = maxf(enemy.slow, action.seconds)
						_heal(x * float(action.drain_per_second_scale), false)
					"flare": _area_extra(enemy.pos, roundi(x * float(action.aoe_damage_scale)), 88.0)
					"ignite": _mark_damage(enemy, x * float(action.damage_per_second_scale), action.seconds)
					"armor_break": enemy.breach = maxf(enemy.get("breach", 0.0), x * float(action.armor_loss_scale))
					"pierce": _damage_enemy(enemy, roundi(float(hero.damage) * x * float(action.damage_scale) * 1.5), 0.0, true, true)
					"flush": _stagger_enemy(enemy, x * float(action.stagger_scale))
					"freeze": enemy.slow = maxf(enemy.slow, x * float(action.duration_scale))

func _area_extra(center: Vector2, damage: int, radius: float) -> void:
	_ring(center, Color("#f3c7a3"), radius)
	for enemy in enemies:
		if center.distance_to(enemy.pos) <= radius:
			_damage_enemy(enemy, maxi(1, damage), 0.0, false, true)

func _clash(enemy: Dictionary) -> void:
	for effect in gear.get("clashes", []):
		if enemy.hp <= 0:
			return
		if combat_rng.randf() > float(effect.get("chance", 1.0)):
			continue
		var x: float = effect.strength
		match effect.id:
			"steam":
				_area_extra(enemy.pos, roundi(x * float(effect.aoe_damage_scale)), 91.0)
				enemy.cooldown = maxf(enemy.cooldown, effect.blind_seconds)
			"corrode":
				enemy.breach = minf(x * float(effect.armor_loss_scale) * float(effect.max_stacks),
					float(enemy.get("breach", 0.0)) + x * float(effect.armor_loss_scale))
			"rend": _mark_damage(enemy, x * float(effect.moving_bleed_per_second_scale), 2.0)
			"root":
				enemy.slow = maxf(enemy.slow, effect.root_seconds)
				_heal(x * float(effect.life_drain_scale), false)
			"mire": enemy.slow = maxf(enemy.slow, x * float(effect.duration_scale))
