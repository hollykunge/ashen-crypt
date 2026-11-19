extends RefCounted

const Equipment = preload("res://scripts/equipment.gd")
const SAVE_PATH := "user://forge-profile.json"
const VERSION := 3
const SLOTS := Equipment.SLOTS
const CLASSES := ["战士", "游侠", "法师"]
const DEFAULT_WEAPON_NAMES := ["旧大剑", "旧长弓", "旧法杖"]
const MATERIALS: Array[Dictionary] = [
	{"id": "iron", "name": "残铁", "tint": Color("#bdbbbc"), "icon": 0},
	{"id": "bone", "name": "骨片", "tint": Color("#f0d2a7"), "icon": 1},
	{"id": "ember", "name": "烬晶", "tint": Color("#f89a62"), "icon": 2}
]
const WEAPONS: Array[Dictionary] = [
	{"id": "greatsword", "role": 0, "slot": "weapon", "name": "铁纹大剑", "icon": 9, "cost": {"iron": 4, "bone": 2}, "stats": {"attack": 8},
		"interval": 0.38, "reach": 119.0, "detail": "攻击 +8 · 0.38 秒/击", "trait": "剑身较长，横扫前方群怪"},
	{"id": "warhammer", "role": 0, "slot": "weapon", "name": "墓石战锤", "icon": 10, "cost": {"iron": 5, "bone": 1, "ember": 1}, "stats": {"attack": 15},
		"interval": 0.54, "reach": 102.0, "detail": "攻击 +15 · 0.54 秒/击", "trait": "重砸近处群怪，强力击退"},
	{"id": "longbow", "role": 1, "slot": "weapon", "name": "青翎长弓", "icon": 11, "cost": {"iron": 2, "bone": 4}, "stats": {"attack": 7},
		"interval": 0.29, "reach": 530.0, "detail": "攻击 +7 · 0.29 秒/击", "trait": "最远射程，普攻穿透两个目标"},
	{"id": "twin_blades", "role": 1, "slot": "weapon", "name": "回风双刀", "icon": 12, "cost": {"iron": 4, "bone": 3}, "stats": {"attack": 4},
		"interval": 0.31, "reach": 82.0, "detail": "攻击 +4 · 0.31 秒/轮", "trait": "贴身两连斩，第二刀伤害为 62%"},
	{"id": "spellstaff", "role": 2, "slot": "weapon", "name": "星火法杖", "icon": 13, "cost": {"bone": 3, "ember": 2}, "stats": {"attack": 12, "mana": 14},
		"interval": 0.49, "reach": 460.0, "detail": "攻击 +12 · 魔法上限 +14", "trait": "0.49 秒/击，普攻溅射附近目标"},
	{"id": "wand", "role": 2, "slot": "weapon", "name": "紫萤魔棒", "icon": 14, "cost": {"iron": 2, "bone": 2, "ember": 1}, "stats": {"attack": 5, "regen": 4},
		"interval": 0.27, "reach": 365.0, "detail": "攻击 +5 · 每秒回蓝 +4", "trait": "0.27 秒/击，快速发射短程法弹"}
]
const LEGACY_WEAPONS := {
	"iron_edge": ["greatsword", "longbow", "spellstaff"],
	"forged_edge": ["warhammer", "twin_blades", "wand"]
}

var save_path: String
var state := _empty_profile()
var dirty := false
var storage_error := ""
var forge_rng := RandomNumberGenerator.new()

func _init(path: String = SAVE_PATH) -> void:
	save_path = path
	forge_rng.randomize()

func load_profile() -> void:
	state = _empty_profile()
	dirty = false
	storage_error = ""
	if not FileAccess.file_exists(save_path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not parsed is Dictionary:
		storage_error = "存档读取失败"
		return
	var version = parsed.get("version", 0)
	if version != 1 and version != 2 and version != VERSION:
		storage_error = "存档读取失败"
		return
	var stock = parsed.get("materials", {})
	if stock is Dictionary:
		for id in state.materials:
			var value = stock.get(id, 0)
			if (value is int or value is float) and is_finite(float(value)):
				state.materials[id] = int(clampf(value, 0.0, 999999.0))
	var legacy: bool = parsed.version == 1
	var owned = parsed.get("owned", [])
	if owned is Array:
		for id in owned:
			if not id is String:
				continue
			for item_id in LEGACY_WEAPONS[id] if legacy and LEGACY_WEAPONS.has(id) else [id]:
				if not recipe(item_id).is_empty() and not owns(item_id):
					state.owned.append(item_id)
	var equipped = parsed.get("equipped", {})
	if equipped is Dictionary:
		for slot in SLOTS.slice(1):
			var id = equipped.get(slot, "")
			if id is String and state.owned.has(id) and recipe(id).get("slot") == slot:
				state.equipped[slot] = id
		var saved = equipped.get("weapon", [])
		if legacy and saved is String:
			saved = LEGACY_WEAPONS.get(saved, [])
		if saved is Array:
			for role in range(mini(CLASSES.size(), saved.size())):
				var id = saved[role]
				if id is String and owns(id) and not weapon(id, role).is_empty():
					state.equipped.weapon[role] = id
	var affixes = parsed.get("affixes", {})
	if affixes is Dictionary:
		for id in state.owned:
			var affix_id = affixes.get(id, "")
			if affix_id is String and Equipment.AFFIXES.has(affix_id) and recipe(id).slot != "weapon":
				state.affixes[id] = affix_id
	dirty = version != VERSION

func stock(id: String) -> int:
	return state.materials.get(id, 0)

func owns(id: String) -> bool:
	return state.owned.has(id)

func equipped(slot: String, role: int = 0) -> String:
	if slot == "weapon":
		return state.equipped.weapon[role] if role >= 0 and role < CLASSES.size() else ""
	return state.equipped.get(slot, "")

func affix(id: String) -> Dictionary:
	return Equipment.AFFIXES.get(state.affixes.get(id, ""), {})

func set_counts(role: int = 0) -> Dictionary:
	var counts := {}
	for slot in SLOTS:
		var item := recipe(equipped(slot, role))
		var family: String = item.get("set", "")
		if not family.is_empty():
			counts[family] = counts.get(family, 0) + 1
	return counts

func bonuses(role: int = 0) -> Dictionary:
	var stats := {"attack": 0, "hp": 0, "mana": 0, "regen": 0}
	for slot in SLOTS:
		var id := equipped(slot, role)
		_add_stats(stats, recipe(id).get("stats", {}))
		_add_stats(stats, affix(id).get("stats", {}))
	var sets := set_counts(role)
	for family in sets:
		var effect: Dictionary = Equipment.SETS[family]
		if sets[family] >= 2:
			_add_stats(stats, effect.two)
		if sets[family] >= 3:
			_add_stats(stats, effect.three)
	return stats

static func _add_stats(stats: Dictionary, extra: Dictionary) -> void:
	for stat in extra:
		stats[stat] = stats.get(stat, 0) + extra[stat]

func collect(id: String, quantity: int) -> bool:
	if not state.materials.has(id) or quantity <= 0:
		return false
	state.materials[id] = mini(999999, stock(id) + quantity)
	dirty = true
	return flush()

func can_craft(id: String) -> bool:
	var item := recipe(id)
	if item.is_empty() or owns(id):
		return false
	for material in item.cost:
		if stock(material) < int(item.cost[material]):
			return false
	return true

func craft(id: String) -> bool:
	if not can_craft(id):
		return false
	var item := recipe(id)
	var next := state.duplicate(true)
	for material in item.cost:
		next.materials[material] -= item.cost[material]
	next.owned.append(id)
	if item.slot != "weapon":
		var options := Equipment.AFFIXES.keys()
		next.affixes[id] = options[forge_rng.randi_range(0, options.size() - 1)]
	return _commit(next)

func toggle_equip(id: String) -> bool:
	if not owns(id):
		return false
	var item := recipe(id)
	var next := state.duplicate(true)
	var role: int = item.get("role", 0)
	var active := "" if equipped(item.slot, role) == id else id
	if item.slot == "weapon":
		next.equipped.weapon[role] = active
	else:
		next.equipped[item.slot] = active
	return _commit(next)

func flush() -> bool:
	return not dirty or _commit(state)

func _commit(next: Dictionary) -> bool:
	if storage_error == "存档读取失败":
		return false
	var temporary := save_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		storage_error = "存档写入失败"
		return false
	file.store_string(JSON.stringify(next))
	file.flush()
	var result := file.get_error()
	file.close()
	if result != OK or DirAccess.rename_absolute(temporary, save_path) != OK:
		storage_error = "存档写入失败"
		return false
	state = next
	dirty = false
	storage_error = ""
	return true

static func material(id: String) -> Dictionary:
	for entry in MATERIALS:
		if entry.id == id:
			return entry
	return {}

static func recipe(id: String) -> Dictionary:
	for entry in WEAPONS:
		if entry.id == id:
			return entry
	for entry in Equipment.ITEMS:
		if entry.id == id:
			return entry
	return {}

static func weapon(id: String, role: int) -> Dictionary:
	var item := recipe(id)
	return item if item.get("role", -1) == role and item.get("slot") == "weapon" else {}

static func recipes_for(role: int, slot: String) -> Array[Dictionary]:
	if slot == "weapon":
		return [WEAPONS[role * 2], WEAPONS[role * 2 + 1]]
	var items: Array[Dictionary] = []
	for entry in Equipment.ITEMS:
		if entry.slot == slot:
			items.append(entry)
	return items

static func roll_loot(foe: int, random: RandomNumberGenerator) -> Array[Dictionary]:
	if foe == 2:
		return [
			{"id": "ember", "quantity": random.randi_range(1, 2)},
			{"id": "iron" if random.randf() < 0.55 else "bone", "quantity": random.randi_range(1, 3)}
		]
	var ghoul := foe == 1
	if random.randf() >= (0.67 if ghoul else 0.52):
		return []
	var roll := random.randf()
	var rare := 0.18 if ghoul else 0.06
	var common := 0.55 if ghoul else 0.62
	var id := "ember" if roll < rare else ("iron" if roll < common else "bone")
	var extra := id != "ember" and random.randf() < (0.26 if ghoul else 0.14)
	return [{"id": id, "quantity": 2 if extra else 1}]

static func _empty_profile() -> Dictionary:
	return {
		"version": VERSION, "materials": {"iron": 0, "bone": 0, "ember": 0}, "owned": [], "affixes": {},
		"equipped": {"weapon": ["", "", ""], "armor": "", "gloves": "", "charm": "", "ring": "", "boots": ""}
	}
