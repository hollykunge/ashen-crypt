extends RefCounted

signal feedback(cue: StringName)
signal material_collected(id: String, quantity: int)

const Gear = preload("res://scripts/gear.gd")

const HEROES: Array[Dictionary] = [
	{"name": "守墓剑士", "skill": "破墓斩", "tactic": "裂地斩", "hp": 156, "speed": 106.0, "damage": 31, "interval": 0.33, "reach": 103.0, "cooldown": 3.6, "color": Color("#ffbd76")},
	{"name": "灰林游侠", "skill": "散射", "tactic": "重矢", "hp": 109, "speed": 122.0, "damage": 24, "interval": 0.24, "reach": 490.0, "cooldown": 3.3, "color": Color("#8af1c6")},
	{"name": "余火术士", "skill": "烬火印", "tactic": "霜环", "hp": 105, "speed": 101.0, "damage": 35, "interval": 0.43, "reach": 460.0, "cooldown": 4.1, "color": Color("#ddb2ff")}
]
const FOES: Array[Dictionary] = [
	{"hp": 44, "speed": 81.0, "damage": 9, "size": 57.0, "radius": 15.0},
	{"hp": 59, "speed": 119.0, "damage": 12, "size": 63.0, "radius": 18.0},
	{"hp": 410, "speed": 69.0, "damage": 24, "size": 105.0, "radius": 31.0}
]
const WAVES := [
	[4, 0, 0], [5, 2, 0], [5, 4, 0], [6, 6, 0], [4, 3, 1]
]
const HOME := Vector2(418, 383)
const FOOTWORK := Rect2(353, 355, 130, 56)
const SLAM_RADIUS := 105.0
const BOSS := 2
const MAX_MANA := 100.0
const SKILL_COST := 30.0
const TACTIC_COST := 22.0
const MOTIONS := {
	&"attack": [-1, 0, -2, 1, 2, -1],
	&"retreat": [3, 4, 5],
	&"hurt": [6, 7, 8],
	&"skill": [-2],
	&"tactic": [-2]
}

var hero_id := 0
var hero_style := 0
var weapon_id := ""
var hero: Dictionary = HEROES[0]
var position := HOME
var hp := 156
var max_hp := 156
var level := 1
var xp := 0
var kills := 0
var ash := 0
var wave := 0
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
var dodge_crit := false
var crit_ready := false
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
var stride := 0.0
var facing := 0.0
var motion: StringName
var motion_time := 0.0
var motion_duration := 0.0
var next_wave := -1.0

var enemies: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var drops: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var popups: Array[Dictionary] = []

func _init() -> void:
	loot_rng.randomize()
	combat_rng.randomize()

func reset(choice: int, bonuses: Dictionary = {}, style: int = 0, equipped_weapon: String = "") -> void:
	hero_id = choice
	hero_style = style
	hero = HEROES[choice].duplicate()
	var weapon := Gear.weapon(equipped_weapon, choice)
	weapon_id = weapon.get("id", "")
	if not weapon.is_empty():
		hero.interval = weapon.interval
		hero.reach = weapon.reach
	gear_attack = int(bonuses.get("attack", 0))
	hero.damage += gear_attack
	hero.speed *= 1.0 + float(bonuses.get("speed", 0)) / 100.0
	damage_reduction = clampf(float(bonuses.get("armor", 0)) / 100.0, 0.0, 0.65)
	crit_chance = clampf(float(bonuses.get("crit", 0)) / 100.0, 0.0, 1.0)
	dodge_crit = int(bonuses.get("dodge_crit", 0)) > 0
	crit_ready = false
	basic_critical = false
	thorns = int(bonuses.get("thorns", 0))
	kill_heal = int(bonuses.get("kill_heal", 0))
	retreat_cooldown = maxf(0.45, 1.35 - float(bonuses.get("dodge_ms", 0)) / 1000.0)
	position = HOME
	hp = int(hero.hp) + int(bonuses.get("hp", 0))
	max_hp = hp
	level = 1
	xp = 0
	kills = 0
	ash = 0
	materials_found = 0
	wave = -1
	result = &""
	max_mana = MAX_MANA + float(bonuses.get("mana", 0))
	mana = max_mana
	mana_recovery = 10.0 + float(bonuses.get("regen", 0))
	var mana_factor := 1.0 - clampf(float(bonuses.get("mana_discount", 0)) / 100.0, 0.0, 0.50)
	skill_cost = ceilf(SKILL_COST * mana_factor)
	tactic_cost = ceilf(TACTIC_COST * mana_factor)
	skill_left = 0.0
	tactic_left = 0.0
	retreat_left = 0.0
	invulnerable = 0.0
	dodge_left = 0.0
	stride = 0.0
	facing = 0.0
	motion = &""
	enemies.clear()
	shots.clear()
	drops.clear()
	effects.clear()
	popups.clear()
	_start_wave()

func xp_target() -> int:
	return level * 3 + 1

func pose() -> int:
	if motion == &"":
		return -1
	var frames: Array = MOTIONS[motion]
	return frames[mini(frames.size() - 1, floori(motion_time / motion_duration * frames.size()))]

func attack() -> void:
	if result != &"" or motion != &"":
		return
	facing = _direction_to_enemy()
	_start_motion(&"attack", hero.interval)

func skill() -> void:
	if result != &"" or skill_left > 0.0 or dodge_left > 0.0 or mana < skill_cost:
		return
	facing = _direction_to_enemy()
	mana -= skill_cost
	skill_left = hero.cooldown
	_start_motion(&"skill", 0.34 if weapon_id == "warhammer" else 0.24)
	var power := 63 + (level - 1) * 7 + gear_attack
	if weapon_id == "warhammer":
		_crush(position + Vector2.from_angle(facing) * 35.0, 111.0, power, 440.0)
	elif weapon_id == "twin_blades":
		_sweep(power, 118.0, facing, hero.color, 200.0)
	else:
		_release_class_skill(power)
	feedback.emit(&"skill")

func _release_class_skill(power: int) -> void:
	match hero_id:
		0:
			_ring(position, hero.color, 157)
			for enemy in enemies:
				if position.distance_to(enemy.pos) < 157.0:
					_damage_enemy(enemy, power, 390)
		1:
			for spread in [-0.36, -0.18, 0.0, 0.18, 0.36]:
				_fire(facing + spread, roundi(power * 0.73), 880, 530)
		2:
			var enemy := _nearest_enemy()
			var distance := 145.0 if enemy.is_empty() else position.distance_to(enemy.pos)
			var center := position + Vector2.from_angle(facing) * minf(distance, hero.reach)
			_ring(center, hero.color, 135)
			_ring(center, Color("#f4d08c"), 74)
			for target in enemies:
				if center.distance_to(target.pos) < 135.0:
					_damage_enemy(target, power + 13, 135)

func tactic() -> void:
	if result != &"" or tactic_left > 0.0 or dodge_left > 0.0 or mana < tactic_cost:
		return
	facing = _direction_to_enemy()
	mana -= tactic_cost
	tactic_left = 4.6
	_start_motion(&"tactic", 0.32 if weapon_id == "warhammer" else 0.24)
	var power := 42 + (level - 1) * 6 + gear_attack
	if weapon_id == "warhammer":
		_crush(position + Vector2.from_angle(facing) * 74.0, 90.0, power + 9, 320.0)
	elif weapon_id == "twin_blades":
		_sweep(power + 17, 98.0, facing, Color("#cbffe4"), 310.0)
	else:
		_release_class_tactic(power)
	feedback.emit(&"skill")

func _release_class_tactic(power: int) -> void:
	match hero_id:
		0:
			var impact := position + Vector2.from_angle(facing) * 105.0
			_ring(impact, Color("#e49060"), 102.0)
			for enemy in enemies:
				if Vector2(enemy.pos).distance_to(impact) < 102.0:
					_damage_enemy(enemy, power, 230.0)
		1:
			_fire(facing, power + 17, 1000.0, 560.0)
		2:
			_ring(position, Color("#91d0ff"), 145.0)
			for enemy in enemies:
				if enemy.spawn <= 0.0 and Vector2(enemy.pos).distance_to(position) < 145.0:
					_damage_enemy(enemy, power, 205.0)
					enemy.slow = 0.85

func retreat() -> void:
	if result != &"" or retreat_left > 0.0:
		return
	dodge_left = 0.17
	retreat_left = retreat_cooldown
	if dodge_crit:
		crit_ready = true
	_start_motion(&"retreat", 0.23)
	_ring(position, Color("#cfc3dd"), 39)
	feedback.emit(&"retreat")

func step(delta: float, direction: Vector2, hold_attack: bool) -> void:
	if result != &"":
		return
	_step_player(delta, direction)
	if hold_attack:
		attack()
	_step_shots(delta)
	_step_enemies(delta)
	_step_drops(delta)
	for effect in effects:
		effect.life -= delta
	for popup in popups:
		popup.life -= delta
		popup.pos.y -= 30.0 * delta
	effects = effects.filter(func(effect: Dictionary) -> bool: return effect.life > 0.0)
	popups = popups.filter(func(popup: Dictionary) -> bool: return popup.life > 0.0)
	if hp <= 0:
		result = &"defeat"
		return
	if not enemies.is_empty():
		return
	if next_wave < 0.0:
		next_wave = 1.6
	next_wave -= delta
	if next_wave <= 0.0:
		if wave < WAVES.size() - 1:
			_start_wave()
		else:
			result = &"victory"
			feedback.emit(&"level")

func _start_wave() -> void:
	wave += 1
	next_wave = -1.0
	var order: Array[int] = []
	for type in range(FOES.size()):
		for _unit in range(WAVES[wave][type]):
			order.append(type)
	for i in range(order.size()):
		var type := order[i]
		var rank := floori(i / 6.0)
		var rank_size := mini(6, order.size() - rank * 6)
		var offset := Vector2(219 + rank * 62 + i % 2 * 18, (i % 6 - (rank_size - 1) * 0.5) * 39 + rank * 10)
		if type == BOSS:
			offset = Vector2(218, 0)
		enemies.append({"serial": wave * 100 + i, "pos": HOME + offset, "type": type, "hp": FOES[type].hp, "spawn": 0.38 + i * 0.09, "hit": 0.0, "cooldown": 0.0, "windup": 0.0, "stride": i * 0.9, "knock": Vector2.ZERO, "slow": 0.0})

func _start_motion(kind: StringName, duration: float) -> void:
	motion = kind
	motion_time = 0.0
	motion_duration = duration

func _step_player(delta: float, direction: Vector2) -> void:
	var old := position
	if dodge_left > 0.0:
		position.x = maxf(FOOTWORK.position.x, position.x - minf(delta, dodge_left) * 300.0)
	else:
		var motion_step := direction.limit_length() * float(hero.speed) * delta
		position.y = clampf(position.y + motion_step.y * 0.48, FOOTWORK.position.y, FOOTWORK.end.y)
		var front := FOOTWORK.end.x
		if motion_step.x > 0.0:
			for enemy in enemies:
				var radius: float = FOES[enemy.type].radius
				if enemy.spawn <= 0.0 and enemy.hp > 0 and absf(enemy.pos.y - position.y) <= radius + 16.0:
					front = minf(front, maxf(position.x, enemy.pos.x - radius - 34.0))
		position.x = clampf(position.x + motion_step.x, FOOTWORK.position.x, front)
	stride = stride + delta * 14.0 if old != position else 0.0
	mana = minf(max_mana, mana + delta * mana_recovery)
	skill_left = maxf(0.0, skill_left - delta)
	tactic_left = maxf(0.0, tactic_left - delta)
	retreat_left = maxf(0.0, retreat_left - delta)
	invulnerable = maxf(0.0, invulnerable - delta)
	dodge_left = maxf(0.0, dodge_left - delta)
	if motion != &"":
		var previous := motion_time
		motion_time += delta
		if motion == &"attack":
			var release := motion_duration * (0.53 if weapon_id == "warhammer" else 1.0 / 3.0)
			if previous < release and motion_time >= release:
				_release_attack()
			var followup := motion_duration * 0.66
			if weapon_id == "twin_blades" and previous < followup and motion_time >= followup:
				_release_attack(true)
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

func _release_attack(followup: bool = false) -> void:
	if not followup:
		basic_critical = crit_ready or (crit_chance > 0.0 and combat_rng.randf() < crit_chance)
		crit_ready = false
	var damage: int = hero.damage + (level - 1) * 5
	if basic_critical:
		damage = roundi(damage * 1.5)
	match weapon_id:
		"warhammer":
			_crush(position + Vector2.from_angle(facing) * 36.0, float(hero.reach) - 36.0, damage, 295.0, basic_critical)
			feedback.emit(&"hammer_hit")
		"twin_blades":
			_sweep(roundi(damage * 0.62) if followup else damage, hero.reach, facing + (0.25 if followup else -0.25), Color("#eaffd3") if followup else hero.color, 58.0, basic_critical)
			feedback.emit(&"slash")
		"longbow":
			_fire(facing, damage, 910.0, hero.reach, 2, 0.0, basic_critical)
			feedback.emit(&"shot")
		"spellstaff":
			_fire(facing, damage, 640.0, hero.reach, 1, 53.0, basic_critical)
			feedback.emit(&"shot")
		"wand":
			_fire(facing, damage, 900.0, hero.reach, 1, 0.0, basic_critical)
			feedback.emit(&"shot")
		_:
			if hero_id == 0:
				_sweep(damage, hero.reach, facing, hero.color, 115.0, basic_critical)
				feedback.emit(&"slash")
			else:
				_fire(facing, damage, 600.0 if hero_id == 2 else 840.0, hero.reach, 1, 0.0, basic_critical)
				feedback.emit(&"shot")

func _sweep(damage: int, reach: float, angle: float, color: Color, knock: float, critical: bool = false) -> void:
	effects.append({"type": &"slash", "pos": position, "angle": angle, "color": color, "radius": reach, "life": 0.19, "duration": 0.19})
	for enemy in enemies:
		var gap: Vector2 = enemy.pos - position
		if gap.length() < reach + FOES[enemy.type].radius * 0.55 and cos(gap.angle() - angle) > -0.05:
			_damage_enemy(enemy, damage, knock, critical)

func _crush(center: Vector2, radius: float, damage: int, knock: float, critical: bool = false) -> void:
	effects.append({"type": &"crush", "pos": center, "color": Color("#ffcb86"), "radius": radius, "life": 0.34, "duration": 0.34})
	for enemy in enemies:
		if center.distance_to(enemy.pos) < radius + FOES[enemy.type].radius * 0.55:
			_damage_enemy(enemy, damage, knock, critical)

func _fire(angle: float, damage: int, speed: float, reach: float, hits: int = 1, splash: float = 0.0, critical: bool = false) -> void:
	var forward := Vector2.from_angle(angle)
	const LAUNCH_OFFSET := 15.0
	shots.append({"pos": position + forward * LAUNCH_OFFSET, "velocity": forward * speed, "life": (reach - LAUNCH_OFFSET) / speed, "damage": damage,
		"magic": hero_id == 2, "wand": weapon_id == "wand", "color": hero.color, "hits": hits, "struck": [], "splash": splash, "critical": critical})

func _ring(point: Vector2, color: Color, radius: float) -> void:
	effects.append({"type": &"ring", "pos": point, "color": color, "radius": radius, "life": 0.38, "duration": 0.38})

func _damage_enemy(enemy: Dictionary, damage: int, knock: float, critical: bool = false) -> void:
	if enemy.spawn > 0.0 or enemy.hp <= 0:
		return
	enemy.hp -= damage
	enemy.hit = 0.15
	enemy.knock += position.direction_to(enemy.pos) * knock * (0.15 if enemy.type == BOSS else 1.0)
	popups.append({"pos": enemy.pos - Vector2(0, FOES[enemy.type].size * 0.66), "text": str(damage), "life": 0.6, "critical": critical})
	if enemy.hp > 0:
		return
	kills += 1
	if kill_heal > 0:
		hp = mini(max_hp, hp + kill_heal)
	var boss: bool = enemy.type == BOSS
	xp += 4 if boss else 1
	drops.append({"pos": enemy.pos, "heal": kills % 4 == 0 or boss, "age": 0.0, "collected": false})
	var loot := Gear.roll_loot(enemy.type, loot_rng)
	for index in range(loot.size()):
		drops.append({
			"pos": Vector2(enemy.pos) + Vector2(22.0 + 24.0 * index, -9.0),
			"material": loot[index].id, "quantity": loot[index].quantity, "age": 0.0, "collected": false
		})
	_ring(enemy.pos - Vector2(0, 12), Color("#d28f58"), 41)
	var target := xp_target()
	if xp >= target:
		xp -= target
		level += 1
		max_hp += 8
		hp = mini(max_hp, hp + 27)
		_ring(position, Color("#facd82"), 60)
		feedback.emit(&"level")

func _damage_player(damage: int, attacker: Dictionary = {}) -> void:
	if dodge_left > 0.0 or invulnerable > 0.0:
		return
	invulnerable = 0.49
	hp = maxi(0, hp - maxi(1, roundi(damage * (1.0 - damage_reduction))))
	_start_motion(&"hurt", 0.22)
	_ring(position, Color("#ec756f"), 34)
	feedback.emit(&"hurt")
	if thorns > 0 and hp > 0 and not attacker.is_empty():
		_damage_enemy(attacker, thorns, 0.0)
		_ring(attacker.pos, Color("#f1bc76"), 26.0)

func _step_enemies(delta: float) -> void:
	for enemy in enemies:
		if enemy.hp <= 0:
			continue
		if enemy.spawn > 0.0:
			enemy.spawn -= delta
			continue
		var stats: Dictionary = FOES[enemy.type]
		var movement := Vector2(enemy.pos).direction_to(position)
		var gap := Vector2(enemy.pos).distance_to(position)
		var near: bool = gap < stats.radius + 37.0
		var boss: bool = enemy.type == BOSS
		enemy.cooldown -= delta
		enemy.hit = maxf(0.0, enemy.hit - delta)
		enemy.slow = maxf(0.0, enemy.slow - delta)
		var slamming := false
		if boss:
			if enemy.windup > 0.0:
				slamming = true
				enemy.windup = maxf(0.0, enemy.windup - delta)
				if enemy.windup == 0.0:
					_ring(enemy.pos, Color("#e46e4b"), SLAM_RADIUS)
					if gap < SLAM_RADIUS:
						_damage_player(stats.damage, enemy)
					enemy.cooldown = 1.25
					feedback.emit(&"skill")
			elif gap < SLAM_RADIUS * 0.72 and enemy.cooldown <= 0.0:
				slamming = true
				enemy.windup = 0.65
		if not near and not slamming:
			var speed: float = stats.speed * (0.55 if enemy.slow > 0.0 else 1.0)
			enemy.pos += movement * Vector2(1.0, 0.76) * speed * delta
			enemy.stride += delta * 12.0
		enemy.pos += enemy.knock * delta
		enemy.knock *= exp(-11.0 * delta)
		if not boss and near and enemy.cooldown <= 0.0 and invulnerable == 0.0 and dodge_left == 0.0:
			enemy.cooldown = 0.53
			_damage_player(stats.damage, enemy)
	enemies = enemies.filter(func(enemy: Dictionary) -> bool: return enemy.hp > 0)
	_separate_enemies(delta)
	for enemy in enemies:
		enemy.pos.x = clampf(enemy.pos.x, position.x + FOES[enemy.type].radius + 32.0, 874.0)
		enemy.pos.y = clampf(enemy.pos.y, 165.0, 567.0)

func _separate_enemies(delta: float) -> void:
	for i in range(enemies.size()):
		var first := enemies[i]
		if first.spawn > 0.0:
			continue
		for j in range(i + 1, enemies.size()):
			var other := enemies[j]
			if other.spawn > 0.0:
				continue
			var target_gap: float = (FOES[first.type].radius + FOES[other.type].radius) * 0.87
			var gap: Vector2 = other.pos - first.pos
			if gap.length_squared() < target_gap * target_gap:
				var shift := gap.normalized() * (target_gap - gap.length()) * minf(1.0, delta * 6.0)
				first.pos -= shift
				other.pos += shift

func _step_shots(delta: float) -> void:
	for shot in shots:
		shot.pos += shot.velocity * minf(delta, shot.life)
		shot.life -= delta
		for enemy in enemies:
			if enemy.spawn > 0.0 or enemy.hp <= 0 or shot.struck.has(enemy.serial):
				continue
			var radius: float = FOES[enemy.type].radius + (8.0 if shot.magic else 3.0)
			if Vector2(shot.pos).distance_squared_to(enemy.pos) < radius * radius:
				_damage_enemy(enemy, shot.damage, 105.0 if shot.magic else 60.0, shot.critical)
				shot.struck.append(enemy.serial)
				shot.hits -= 1
				_ring(shot.pos - Vector2(0, 13), shot.color, maxf(24.0, shot.splash))
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
			if drop.has("material"):
				materials_found += int(drop.quantity)
				popups.append({
					"pos": position + Vector2(29.0 + 41.0 * (materials_found % 2), -49.0),
					"text": "+%d" % drop.quantity, "material": drop.material, "life": 0.9
				})
				material_collected.emit(drop.material, drop.quantity)
			else:
				ash += 3 if drop.heal else 1
				if drop.heal:
					hp = mini(max_hp, hp + 24)
			feedback.emit(&"pickup")
		elif gap < 95.0 or enemies.is_empty():
			drop.pos = Vector2(drop.pos).lerp(position, minf(1.0, delta * (7.0 if enemies.is_empty() else 11.0)))
	drops = drops.filter(func(drop: Dictionary) -> bool: return not drop.collected)
