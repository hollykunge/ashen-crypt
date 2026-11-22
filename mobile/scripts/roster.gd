extends RefCounted

const Pigments = preload("res://scripts/pigments.gd")
# 五行字色与边色，取自 pigments.gd 的敦煌矿物色。
const ELEMENT_TINTS = Pigments.LIGHT
const ELEMENT_GLOW = Pigments.GLOW

const NAMES := ["二郎神", "九天玄女", "后羿", "青鸟仙子", "雷部天师", "电母"]
const CONFIRM_TIME := 0.55

const PORTRAITS := [
	preload("res://art/immortals/portrait-0.webp"),
	preload("res://art/immortals/portrait-1.webp"),
	preload("res://art/immortals/portrait-2.webp"),
	preload("res://art/immortals/portrait-3.webp"),
	preload("res://art/immortals/portrait-4.webp"),
	preload("res://art/immortals/portrait-5.webp")
]

static func id(role: int, style: int) -> int:
	return role * 2 + style
