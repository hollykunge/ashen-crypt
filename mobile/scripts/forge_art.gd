extends RefCounted

const ATLAS = preload("res://art/immortals/armory.webp")
const CELL := Vector2(128, 128)

static func texture(index: int) -> AtlasTexture:
	var item := AtlasTexture.new()
	item.atlas = ATLAS
	item.region = region(index)
	item.filter_clip = true
	return item

static func region(index: int) -> Rect2:
	return Rect2(Vector2(index % 6, floori(index / 6.0)) * CELL, CELL)
