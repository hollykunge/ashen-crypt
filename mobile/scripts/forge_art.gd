extends RefCounted

const ATLAS = preload("res://art/immortals/armory.webp")
const CELL := Vector2(128, 128)

# 需要区分男女式样时使用 [男, 女]。每行依次为武器、护甲、护手、项链、戒指、鞋子。
const ICONS := {
	"jin": [[10, 12], 7, 17, 26, 23, 20],
	"mu": [11, 15, 18, 29, 24, 21],
	"huo": [9, [4, 15], 17, 26, 25, 22],
	"shui": [13, 16, 18, 5, 24, [21, 22]],
	"tu": [[10, 12], 4, 17, 5, 24, [20, 22]]
}

const WEAPONS = preload("res://art/forge-weapons.webp")
const FORM_ICONS := {"long_blade": 0, "hammer": 1, "bow": 2, "dual_blades": 3, "staff": 4}

static func item_index(slot_index: int, element: String, female: bool) -> int:
	var variant: Variant = ICONS[element][slot_index]
	return variant[int(female)] if variant is Array else variant

static func weapon_region(form: String) -> Rect2:
	var index: int = FORM_ICONS[form]
	var cell := WEAPONS.get_size() / Vector2(3, 2)
	return Rect2(Vector2(index % 3, floori(index / 3.0)) * cell, cell)

static func weapon_icon(form: String) -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = WEAPONS
	result.region = weapon_region(form)
	result.filter_clip = true
	return result

static func texture(index: int) -> AtlasTexture:
	var item := AtlasTexture.new()
	item.atlas = ATLAS
	item.region = region(index)
	item.filter_clip = true
	return item

static func region(index: int) -> Rect2:
	return Rect2(Vector2(index % 6, floori(index / 6.0)) * CELL, CELL)
