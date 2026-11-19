extends RefCounted

const ATLAS = preload("res://art/forge-items.webp")
const WEAPONS = preload("res://art/forge-weapons.webp")
const EQUIPMENT = preload("res://art/forge-equipment.webp")
const CELL := Vector2(48, 48)

static func texture(index: int) -> AtlasTexture:
	var item := AtlasTexture.new()
	item.atlas = EQUIPMENT if index >= 15 else WEAPONS if index >= 9 else ATLAS
	item.filter_clip = true
	if index >= 15:
		var cell := index - 15
		item.region = Rect2(Vector2(cell % 4, floori(cell / 4.0)) * CELL, CELL)
	else:
		item.region = region(index - 9 if index >= 9 else index)
	return item

static func region(index: int) -> Rect2:
	return Rect2(Vector2(index % 3, floori(index / 3.0)) * CELL, CELL)
