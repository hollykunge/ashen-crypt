extends RefCounted

const Equipment = preload("res://scripts/equipment.gd")
const Materials = preload("res://scripts/rules/materials.gd")
const Rules = preload("res://scripts/rules/forge_rules.gd")
const Derive = preload("res://scripts/rules/derive.gd")
const WuXing = preload("res://scripts/rules/wuxing.gd")
const Bazi = preload("res://scripts/rules/bazi.gd")
const Origins = preload("res://scripts/rules/origins.gd")
const Realm = preload("res://scripts/rules/realm.gd")
const Loadout = preload("res://scripts/loadout.gd")

const SAVE_PATH := "user://forge-profile.json"
const VERSION := Realm.SAVE_VERSION
const SLOTS := Equipment.SLOTS
const SLOT_NAMES := Equipment.SLOT_NAMES
const WEAPON_FORMS := {
	"long_blade": {"interval": 0.38, "reach": 119.0},
	"hammer": {"interval": 0.54, "reach": 102.0},
	"bow": {"interval": 0.29, "reach": 530.0},
	"staff": {"interval": 0.49, "reach": 460.0},
	"dual_blades": {"interval": 0.31, "reach": 82.0}
}
const MATERIAL_COLORS := {"jin": Color("#e1c592"), "mu": Color("#a9cb93"), "shui": Color("#8ac7dc"),
	"huo": Color("#efa588"), "tu": Color("#c3ad79")}
const MATERIAL_ICONS := {"jin": 0, "mu": 1, "shui": 1, "huo": 2, "tu": 0}

# V3 的三种原料按旧名称对应的当前材料阶折价；返还时保留同等买入价值。
const LEGACY_MATERIALS := {"iron": "geng", "bone": "dragon_bone", "ember": "bing"}
const LEGACY_WEAPON_COSTS := {
	"greatsword": {"iron": 4, "bone": 2}, "warhammer": {"iron": 4, "bone": 2, "ember": 1},
	"longbow": {"iron": 2, "bone": 4}, "twin_blades": {"iron": 1, "bone": 4, "ember": 1},
	"spellstaff": {"iron": 2, "bone": 3, "ember": 1}, "wand": {"iron": 2, "bone": 2, "ember": 1}
}
const STARTING_MATERIALS := {
	"official": {"jia": 3, "geng": 3}, "pauper": {"geng": 4, "bing": 2, "gui": 2}
}

var save_path: String
var state := _empty_profile()
var storage_error := ""

func _init(path: String = SAVE_PATH) -> void:
	save_path = path

func load_profile() -> void:
	state = _empty_profile()
	storage_error = ""
	if not FileAccess.file_exists(save_path):
		return
	var raw := FileAccess.get_file_as_string(save_path)
	var parsed = JSON.parse_string(raw)
	if not parsed is Dictionary:
		storage_error = "存档读取失败"
		return
	var version: int = int(parsed.get("version", 0))
	if version == VERSION and parsed.get("character") is Dictionary and parsed.get("materials") is Dictionary \
			and parsed.get("items") is Dictionary and parsed.get("equipped") is Dictionary:
		state = parsed
		return
	if version not in [1, 2, 3]:
		storage_error = "存档读取失败"
		return
	var backup := save_path + ".v%d.bak" % version
	if not FileAccess.file_exists(backup):
		var file := FileAccess.open(backup, FileAccess.WRITE)
		if file == null or not file.store_string(raw):
			storage_error = "旧存档备份失败"
			return
		file.close()
	var migrated := _empty_profile()
	migrated.materials = _legacy_refund(parsed)
	_commit(migrated)

static func _legacy_refund(saved: Dictionary) -> Dictionary:
	var totals := {"iron": 0, "bone": 0, "ember": 0}
	var stockpile = saved.get("materials", {})
	if stockpile is Dictionary:
		for id in totals:
			totals[id] = _quantity(stockpile.get(id, 0))
	var seen := {}
	var owned = saved.get("owned", [])
	if owned is Array:
		for id in owned:
			if not id is String or seen.has(id):
				continue
			seen[id] = true
			var cost: Dictionary = LEGACY_WEAPON_COSTS.get(id, {})
			if id in ["iron_edge", "forged_edge"]:
				cost = LEGACY_WEAPON_COSTS["greatsword" if id == "iron_edge" else "warhammer"]
			for recipe in Equipment.ITEMS:
				if recipe.id == id:
					cost = recipe.cost
					break
			for key in cost:
				totals[key] += int(cost[key])
	var refund := {}
	for old in totals:
		if totals[old] > 0:
			refund[LEGACY_MATERIALS[old]] = totals[old]
	return refund

static func material(id: String) -> Dictionary:
	if not Materials.MATERIALS.has(id):
		return {}
	var source: Dictionary = Materials.MATERIALS[id]
	var element := WuXing.stem_element(source.stem)
	return {"name": source.name, "tier": source.tier, "purity": source.purity,
		"tint": MATERIAL_COLORS.get(element, Color("#d6c7a3")), "icon": MATERIAL_ICONS.get(element, 0)}

static func stem_name(id: String) -> String:
	var index := WuXing.STEMS.find(id)
	return WuXing.STEM_NAMES[index] if index >= 0 else ""

func has_character() -> bool:
	return not character().is_empty()

func character() -> Dictionary:
	return state.character

func origin() -> Dictionary:
	return Origins.ORIGINS.get(character().get("origin", ""), {})

func hour_talent() -> Dictionary:
	return Bazi.HOUR_TALENTS.get(character().get("hour_branch", ""), {})

func create_character(draft: Dictionary) -> bool:
	if has_character():
		return false
	var person := Realm.new_profile(draft.gender, draft.day_stem, draft.month_branch, draft.hour_branch, draft.origin)
	if person.is_empty():
		return false
	var next := state.duplicate(true)
	next.character = person
	var stockpile: Dictionary = STARTING_MATERIALS.get(draft.origin, {})
	for id in stockpile:
		next.materials[id] = stock(id) + int(stockpile[id])
	var talent: Dictionary = Bazi.HOUR_TALENTS[draft.hour_branch]
	if talent.has("starting_equipment_stem"):
		var item := new_draft()
		item.slot = "armor"
		item.materials = {talent.starting_equipment_stem: 4}
		item.forge_level = 1
		next.items[item.uid] = item
		next.equipped.armor = item.uid
	_credit_stipend(next)
	return _commit(next)

func layer() -> int:
	return maxi(1, int(character().get("layer", 1)))

func ling() -> String:
	return WuXing.ling_of(layer())

func realm() -> Dictionary:
	var index := floori((layer() - 1) / 10.0)
	return Realm.REALMS[index] if index < Realm.REALMS.size() else Realm.WAITING

func layer_caption() -> String:
	var year := Bazi.year_of(layer())
	return "第 %d 层 · %s%s年 · %s · 阳寿 %d" % [layer(), stem_name(year[0]),
		WuXing.BRANCHES[year[1]].name, realm().name, Realm.lifespan(floori((layer() - 1) / 10.0))]

static func ling_caption(stem: String) -> String:
	return stem_name(stem) + String(WuXing.ELEMENT_NAMES[WuXing.stem_element(stem)])

func challenge_wait() -> int:
	return maxi(0, ceili(float(state.get("challenge_retry_at", 0.0)) - Time.get_unix_time_from_system()))

func start_challenge_cooldown() -> bool:
	var next := state.duplicate(true)
	next.challenge_retry_at = Time.get_unix_time_from_system() + 30.0
	return _commit(next)

func advance_layer(rewards: Dictionary = {}) -> bool:
	if not has_character():
		return false
	var next := state.duplicate(true)
	next.character.layer = layer() + 1
	var completed := floori(layer() / 10.0)
	next.character.realm = mini(completed + 1, Realm.REALMS.size())
	next.character.lifespan = Realm.lifespan(completed)
	next.erase("challenge_retry_at")
	for id in rewards:
		if Materials.MATERIALS.has(id):
			next.materials[id] = mini(999999, stock(id) + _quantity(rewards[id]))
	_credit_stipend(next)
	return _commit(next)

static func _credit_stipend(next: Dictionary) -> void:
	var person: Dictionary = next.character
	var official: Dictionary = Origins.ORIGINS.official
	var period: int = official.stipend_period
	if person.origin != "official" or (int(person.layer) - 1) % period != 0:
		return
	var sequence := Bazi.luck_sequence(Bazi.month_pillar_index(person.month_branch), person.gender, 60)
	if sequence.is_empty():
		return
	var index := floori((int(person.layer) - 1) / float(period)) % sequence.size()
	var stem: String = sequence[index][0]
	for id in Materials.MATERIALS:
		var source: Dictionary = Materials.MATERIALS[id]
		if source.stem == stem and source.tier in official.stipend_tiers:
			next.materials[id] = int(next.materials.get(id, 0)) + 1
			return
	# 没有对应的高阶材料时，同干低阶材料补足九点纯度。
	var count := ceili(9.0 / float(Materials.MATERIALS[stem].purity))
	next.materials[stem] = int(next.materials.get(stem, 0)) + count

func furnace_level() -> int:
	return mini(realm().forge_cap, 1 + floori((layer() - 1) / 10.0) + int(hour_talent().get("forge_level", 0)))

func material_slots() -> int:
	return mini(12, int(Rules.FORGE_TIERS[furnace_level()].slots) + int(hour_talent().get("material_slots", 0)))

func socket_limit() -> int:
	return int(realm().sockets)

func process_unlocked(process: String) -> bool:
	var talent: Array = hour_talent().get("unlocks", [])
	var unlock := "quench" if process == "quench_yin" else process
	return process == "forge_rough" or talent.has(unlock) or layer() >= 2

func stock(id: String) -> int:
	return _quantity(state.materials.get(id, 0))

static func _quantity(value: Variant) -> int:
	if (value is int or value is float) and is_finite(float(value)):
		return int(clampf(float(value), 0.0, 999999.0))
	return 0

static func new_draft() -> Dictionary:
	return {"uid": Crypto.new().generate_random_bytes(8).hex_encode(), "slot": "weapon", "process": ["forge_rough"],
		"materials": {}, "sockets": [], "rotation": 0, "wear": 0, "name": "", "weapon_form": "long_blade"}

func item(uid: String) -> Dictionary:
	return state.items.get(uid, {})

func equipped(slot: String) -> String:
	return state.equipped.get(slot, "")

func items() -> Array:
	return state.items.values()

func describe(item_input: Dictionary, contextual: bool = false, encounter_ling: String = "") -> Dictionary:
	var temperature := int(item_input.get("forge_level", furnace_level()))
	var resolved := _resolve_sources(item_input)
	var active_ling := ling() if encounter_ling.is_empty() else encounter_ling
	return Derive.derive(resolved, temperature, active_ling, character()) if contextual else Derive.derive(resolved, temperature)

func _resolve_sources(input: Dictionary) -> Dictionary:
	if not input.has("merge_sources"):
		return input
	var sources: Array = input.merge_sources
	var temperature := int(input.forge_level)
	var merged := Derive.merge_items(_resolve_sources(sources[0]), _resolve_sources(sources[1]), temperature, input.sockets)
	var result := input.duplicate()
	if not merged.is_empty():
		result.merged = merged.merged
	return result

func loadout(override_item: Dictionary = {}, contextual: bool = true, encounter_ling: String = "") -> Dictionary:
	var entries := {}
	for slot in SLOTS:
		var input := item(equipped(slot))
		if not override_item.is_empty() and override_item.slot == slot:
			input = override_item
		if not input.is_empty():
			entries[slot] = describe(input, contextual, encounter_ling)
	return Loadout.summarize(entries, character(), ling() if encounter_ling.is_empty() else encounter_ling)

func bonuses(encounter_ling: String = "") -> Dictionary:
	return Loadout.bonuses(loadout({}, true, encounter_ling), character(), layer())

func toggle_equip(uid: String) -> bool:
	var input := item(uid)
	if input.is_empty():
		return false
	var slot: String = input.slot
	var next := state.duplicate(true)
	next.equipped[slot] = "" if equipped(slot) == uid else uid
	return _commit(next)

func rename_item(uid: String, title: String) -> bool:
	if item(uid).is_empty():
		return false
	var next := state.duplicate(true)
	next.items[uid].name = title.strip_edges().left(24)
	return _commit(next)

func rotate_item(uid: String) -> bool:
	if not process_unlocked("rotate") or item(uid).is_empty():
		return false
	var next := state.duplicate(true)
	var rotated: Dictionary = next.items[uid]
	rotated.rotation = (int(rotated.rotation) + 1) % 5
	rotated.wear = int(rotated.wear) + int(origin().get("rotation_wear", Rules.PROCESSES.rotate.wear))
	if WuXing.SHENG.has(rotated.get("sealed_element", "")):
		rotated.sealed_element = WuXing.SHENG[rotated.sealed_element]
	return _commit(next)

func merge_draft(first_uid: String, second_uid: String, sockets: Array = []) -> Dictionary:
	var first := item(first_uid)
	var second := item(second_uid)
	if not process_unlocked("merge") or first.is_empty() or second.is_empty() or first_uid == second_uid or first.slot != second.slot:
		return {}
	if sockets.size() > socket_limit():
		return {}
	var combined := Derive.merge_items(_resolve_sources(first), _resolve_sources(second), furnace_level(), sockets)
	if combined.is_empty() or combined.sockets.size() != sockets.size():
		return {}
	var draft := new_draft()
	draft.slot = combined.slot
	draft.weapon_form = combined.weapon_form
	draft.process = []
	draft.forge_level = furnace_level()
	draft.sockets = combined.sockets
	draft.wear = combined.wear
	draft.merge_sources = [first, second]
	return draft

func merge_items(first_uid: String, second_uid: String, sockets: Array = []) -> String:
	var combined := merge_draft(first_uid, second_uid, sockets)
	if combined.is_empty():
		return ""
	var next := state.duplicate(true)
	if next.equipped[combined.slot] in [first_uid, second_uid]:
		next.equipped[combined.slot] = ""
	next.items.erase(first_uid)
	next.items.erase(second_uid)
	next.items[combined.uid] = combined
	return combined.uid if _commit(next) else ""

func craft_cost(input: Dictionary) -> Dictionary:
	var costs: Dictionary = input.materials.duplicate()
	for stem in input.sockets:
		costs[stem] = int(costs.get(stem, 0)) + 1
	if input.process.has("forge_fine"):
		var charge := describe(input)
		var dominant := Loadout.dominant(charge.wuxing)
		var found := false
		for id in Materials.MATERIALS:
			var source: Dictionary = Materials.MATERIALS[id]
			if source.tier < 2 or not source.wuxing.has(dominant):
				continue
			if stock(id) > int(costs.get(id, 0)):
				costs[id] = int(costs.get(id, 0)) + int(Rules.PROCESSES.forge_fine.extra_matching_high_tier)
				found = true
				break
		if not found:
			return {}
	for process in input.process:
		var core_cost: int = Rules.PROCESSES.get(process, {}).get("relic_core_cost", 0)
		if core_cost > 0:
			costs["relic_core"] = int(costs.get("relic_core", 0)) + core_cost
	if input.process.has("seal"):
		var fee := WuXing.stem_for(input.get("sealed_element", ""), 1.0)
		if not fee.is_empty():
			costs[fee] = int(costs.get(fee, 0)) + 1
	return costs

func craft_error(input: Dictionary) -> String:
	if not has_character() or not SLOTS.has(input.slot):
		return "先立下命籍"
	if input.materials.is_empty():
		return "先投至少一份材料"
	if input.process.has("seal") and not WuXing.WUXING.has(input.get("sealed_element", "")):
		return "请选择封印的行"
	for process in input.process:
		if not process_unlocked(process):
			return "%s在第二层开放" % Rules.PROCESSES[process].name
	if input.sockets.size() > socket_limit():
		return "当前境界的镶嵌槽不足"
	var seen := {}
	for socket in input.sockets:
		if seen.has(socket) or not WuXing.STEMS.has(socket):
			return "镶嵌需使用不同天干"
		seen[socket] = true
	var count := 0
	for id in input.materials:
		var amount := _quantity(input.materials[id])
		if not Materials.MATERIALS.has(id) or amount <= 0:
			return "投料有误"
		count += amount
	if count > material_slots():
		return "投料格不足"
	var costs := craft_cost(input)
	if costs.is_empty():
		return "精锻还需一份主行的二阶及以上材料"
	for id in costs:
		if stock(id) < int(costs[id]):
			return "%s库存不足" % material(id).get("name", "材料")
	if describe(input).wuxing.is_empty():
		return "封印后没有可用材料"
	return ""

func craft(input: Dictionary) -> bool:
	if not craft_error(input).is_empty() or state.items.has(input.uid):
		return false
	var next := state.duplicate(true)
	var costs := craft_cost(input)
	for id in costs:
		next.materials[id] = stock(id) - int(costs[id])
	var stored := input.duplicate(true)
	stored.forge_level = furnace_level()
	var derived := describe(stored)
	var residue: float = derived.steps[0].residue
	var overflow := maxf(0.0, float(derived.steps[0].purity) - float(derived.steps[0].cap))
	var refund := float(origin().get("residue_refund", Rules.SHENG_KE_PARAMS.overflow_refund))
	residue += overflow * (refund - float(Rules.SHENG_KE_PARAMS.overflow_refund))
	next.residue = float(next.residue) + residue * (1.0 + float(hour_talent().get("residue_refund_bonus", 0.0)))
	next.items[stored.uid] = stored
	return _commit(next)

func collect(id: String, quantity: int) -> bool:
	if not Materials.MATERIALS.has(id) or quantity <= 0:
		return false
	var next := state.duplicate(true)
	next.materials[id] = mini(999999, stock(id) + quantity)
	return _commit(next)

func silver() -> int:
	return int(character().get("silver", 0))

func gain_silver(quantity: int) -> bool:
	if not has_character() or quantity <= 0:
		return false
	var next := state.duplicate(true)
	next.character.silver = silver() + quantity
	return _commit(next)

func buy_remaining() -> int:
	var bought := int(state.purchase_count) if int(state.purchase_layer) == layer() else 0
	return maxi(0, Origins.SILVER_BUY_CAP - bought)

func buy_material(id: String) -> bool:
	if not origin().get("unlocks", []).has("buy_materials") or not WuXing.STEMS.has(id) or buy_remaining() == 0:
		return false
	var price: int = Origins.SILVER_PRICES[Materials.MATERIALS[id].tier].buy
	if silver() < price:
		return false
	var next := state.duplicate(true)
	next.character.silver = silver() - price
	next.materials[id] = stock(id) + 1
	next.purchase_layer = layer()
	next.purchase_count = Origins.SILVER_BUY_CAP - buy_remaining() + 1
	return _commit(next)

static func roll_farm_quantity(random: RandomNumberGenerator, guaranteed: bool, multiplier: float) -> int:
	if not guaranteed and random.randf() >= minf(1.0, 0.84 * multiplier):
		return 0
	return 2 if random.randf() < minf(1.0, 0.27 * multiplier) else 1

func _commit(next: Dictionary) -> bool:
	if storage_error in ["存档读取失败", "旧存档备份失败"]:
		return false
	var temporary := save_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		storage_error = "存档写入失败"
		return false
	var written := file.store_string(JSON.stringify(next))
	file.flush()
	var result := file.get_error()
	file.close()
	if not written or result != OK or DirAccess.rename_absolute(temporary, save_path) != OK:
		storage_error = "存档写入失败"
		return false
	state = next
	storage_error = ""
	return true

static func _empty_profile() -> Dictionary:
	return {"version": VERSION, "character": {}, "materials": {}, "items": {}, "residue": 0.0, "purchase_layer": 0,
		"purchase_count": 0, "equipped": {"weapon": "", "armor": "", "gloves": "", "charm": "", "ring": "", "boots": ""}}
