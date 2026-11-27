extends RefCounted

const CELL := Vector2(128, 128)

# 皮影兵器保持与手持模型相同的刀身、枪头或弓臂形制。
const WEAPONS = preload("res://art/piying/v4/weapons.png")
const GARMENTS = preload("res://art/piying/v4/garments.png")
const WEAPON_GRID := Vector2(4, 3)
const FORM_ICONS := {"bow": 7, "spear": 8, "jian": 4, "sword": 0}
const WEAPON_PARTS := [
	"dao_blade_jian", "dao_blade_qixing", "dao_blade_bolang", "bow_limbs_chang",
	"sword_blade_jian", "sword_blade_qixing", "sword_blade_bolang", "bow_limbs_fanqu",
	"spear_head_leaf", "spear_head_snake", "spear_head_ji"
]

static func weapon_region(form: String, part := "") -> Rect2:
	var index := WEAPON_PARTS.find(part)
	if index < 0:
		index = FORM_ICONS[form]
	var cell := WEAPONS.get_size() / WEAPON_GRID
	return Rect2(Vector2(index % int(WEAPON_GRID.x), floori(index / WEAPON_GRID.x)) * cell, cell)

static func weapon_icon(form: String, part := "") -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = WEAPONS
	result.region = weapon_region(form, part)
	result.filter_clip = true
	return result

static func garment_icon(slot_index: int, kind: String) -> AtlasTexture:
	var row := maxi(0, ["cloth", "leather", "chain"].find(kind))
	var item := AtlasTexture.new()
	item.atlas = GARMENTS
	item.region = Rect2(Vector2(slot_index, row) * CELL, CELL)
	item.filter_clip = true
	return item

const MATERIALS = preload("res://art/ui-icons/materials.png")
const MATERIAL_IDS := ["jia", "yi", "bing", "ding", "wu", "ji", "geng", "xin", "ren", "gui",
	"zhengyue_ingot", "dragon_bone", "xuanming_sand", "geng_jing", "taiji_pill", "relic_core"]

static func material_region(id: String) -> Rect2:
	var index := MATERIAL_IDS.find(id)
	if index < 0:
		index = MATERIAL_IDS.size() - 1
	return Rect2(Vector2(index % 4, floori(index / 4.0)) * CELL, CELL)
