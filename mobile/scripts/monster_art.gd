extends RefCounted

const Combat = preload("res://scripts/combat.gd")
const ATLASES := [
	preload("res://art/side/monsters/shanxiao.png"),
	preload("res://art/side/monsters/fire-fox.png"),
	preload("res://art/side/monsters/guardian.png"),
	preload("res://art/side/monsters/vine-spirit.png"),
]
const CELL := Vector2(160, 96)
const PIVOT := Vector2(80, 76)
const STANDING_HEIGHT := 64.0
const WALK_FRAME_DISTANCE := 9.0
const WINDUP_FRAME := 4
const STRIKE_FRAME := 5
const FOLLOW_THROUGH_FRAME := 6
const IDLE_FRAME := 7

static func variant(art: int, stem: String) -> int:
	return 3 if stem in ["jia", "yi"] else art

static func live_frame(enemy: Dictionary) -> int:
	if enemy.windup > 0.0 or enemy.attack_windup > 0.0:
		return WINDUP_FRAME
	if enemy.attack_recovery > 0.0:
		return STRIKE_FRAME if enemy.attack_recovery > Combat.ENEMY_ATTACK_RECOVERY * 0.53 else FOLLOW_THROUGH_FRAME
	if enemy.moving:
		return floori(enemy.stride / WALK_FRAME_DISTANCE) % 4
	return IDLE_FRAME

static func death_frame(age: float) -> int:
	return 8 + clampi(floori(age / (Combat.ENEMY_DEATH_DURATION / 4.0)), 0, 3)

static func draw_frame(canvas: CanvasItem, art: int, frame: int, height: float, ink: Color) -> void:
	var origin := Vector2(frame % 4, floori(frame / 4.0)) * CELL
	var pixels := height / STANDING_HEIGHT
	canvas.draw_texture_rect_region(ATLASES[art], Rect2(-PIVOT * pixels, CELL * pixels), Rect2(origin, CELL), ink)
