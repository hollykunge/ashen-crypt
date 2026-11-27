extends RefCounted

const WEAPONS = preload("res://art/piying/v4/weapons.png")
const GARMENTS = preload("res://art/piying/v4/garments.png")
const WEAPON_GRID := Vector2(3, 2)
const FORM_ICONS := {"sword": 0, "jian": 3}

static func weapon_region(form: String, variant := 0) -> Rect2:
	var index: int = FORM_ICONS[form] + clampi(variant, 0, 2)
	var cell := WEAPONS.get_size() / WEAPON_GRID
	return Rect2(Vector2(index % int(WEAPON_GRID.x), floori(index / WEAPON_GRID.x)) * cell, cell)

static func weapon_icon(form: String, variant := 0) -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = WEAPONS
	result.region = weapon_region(form, variant)
	result.filter_clip = true
	return result

static func garment_icon(slot_index: int, kind: String) -> AtlasTexture:
	var row := maxi(0, ["cloth", "leather", "chain"].find(kind))
	var item := AtlasTexture.new()
	item.atlas = GARMENTS
	var cell := GARMENTS.get_size() / Vector2(4, 3)
	item.region = Rect2(Vector2(slot_index, row) * cell, cell)
	item.filter_clip = true
	return item

const MATERIALS = preload("res://art/ui-icons/materials.png")
const MATERIAL_IDS := ["jia", "yi", "bing", "ding", "wu", "ji", "geng", "xin", "ren", "gui",
	"zhengyue_ingot", "dragon_bone", "xuanming_sand", "geng_jing", "taiji_pill", "relic_core"]

static func material_region(id: String) -> Rect2:
	var index := MATERIAL_IDS.find(id)
	if index < 0:
		index = MATERIAL_IDS.size() - 1
	var cell := MATERIALS.get_size() / 4.0
	return Rect2(Vector2(index % 4, floori(index / 4.0)) * cell, cell)
