extends RefCounted

const SHEETS := [
	preload("res://art/roster/knight-man.webp"),
	preload("res://art/roster/knight-woman.webp"),
	preload("res://art/roster/ranger-man.webp"),
	preload("res://art/roster/ranger-woman.webp"),
	preload("res://art/roster/mage-man.webp"),
	preload("res://art/roster/mage-woman.webp")
]
const STAGES := [
	preload("res://art/roster/knight-man-stage.webp"),
	preload("res://art/roster/knight-woman-stage.webp"),
	preload("res://art/roster/ranger-man-stage.webp"),
	preload("res://art/roster/ranger-woman-stage.webp"),
	preload("res://art/roster/mage-man-stage.webp"),
	preload("res://art/roster/mage-woman-stage.webp")
]
const ALTERNATE_SHEETS := [
	preload("res://art/roster/knight-man-alt.webp"),
	preload("res://art/roster/knight-woman-alt.webp"),
	preload("res://art/roster/ranger-man-alt.webp"),
	preload("res://art/roster/ranger-woman-alt.webp"),
	preload("res://art/roster/mage-man-alt.webp"),
	preload("res://art/roster/mage-woman-alt.webp")
]
const ALTERNATE_STAGES := [
	preload("res://art/roster/knight-man-alt-stage.webp"),
	preload("res://art/roster/knight-woman-alt-stage.webp"),
	preload("res://art/roster/ranger-man-alt-stage.webp"),
	preload("res://art/roster/ranger-woman-alt-stage.webp"),
	preload("res://art/roster/mage-man-alt-stage.webp"),
	preload("res://art/roster/mage-woman-alt-stage.webp")
]
const ALTERNATE_WEAPONS := ["warhammer", "twin_blades", "wand"]
const CELL := Vector2(128, 112)
const FEET := Vector2(64, 103)
const FRAMES := 8
const CONFIRM_TIME := 0.76
const ROW := {&"idle": 0, &"walk": 1, &"attack": 2, &"skill": 3, &"tactic": 4, &"retreat": 5, &"hurt": 6, &"defeat": 7}
const IDLE_TIME := [2.2, 1.65, 1.95, 1.65, 2.4, 2.05]

static func id(role: int, style: int) -> int:
	return role * 2 + style

static func battle_art(hero: int, weapon: String) -> Texture2D:
	return ALTERNATE_SHEETS[hero] if weapon in ALTERNATE_WEAPONS else SHEETS[hero]

static func stage_art(hero: int, weapon: String) -> Texture2D:
	return ALTERNATE_STAGES[hero] if weapon in ALTERNATE_WEAPONS else STAGES[hero]

static func region(motion: StringName, phase: float) -> Rect2:
	var frame := clampi(floori(phase * FRAMES), 0, FRAMES - 1)
	return Rect2(Vector2(frame, ROW[motion]) * CELL, CELL)

static func stage_region(pose: int) -> Rect2:
	return Rect2(Vector2(pose % 3, floori(pose / 3.0)) * CELL * 2.0, CELL * 2.0)
