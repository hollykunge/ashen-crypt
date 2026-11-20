extends RefCounted

const Places = preload("res://scripts/rules/places.gd")
const SNOW_PASS = preload("res://art/side/kunlun-snow-pass.webp")
const PORTRAITS := [preload("res://art/side/portrait-male.webp"), preload("res://art/side/portrait-female.webp")]
const SPRITES := [preload("res://art/side/frames-male.png"), preload("res://art/side/frames-female.png")]
const CELL := Vector2(96, 96)
const PIVOT := Vector2(47, 89)
const FLOOR := 0.76
const SNOW_FLOOR := 0.79
# 每一个人物像素占背景高度的比例，按山门石阶和雪道前景标定。
# 使用原画比例，导入时降低纹理分辨率也会保持同样的人物大小。
const STREET_ACTOR_SCALE := 1.64 / 887.0
const SNOW_ACTOR_SCALE := 1.52 / 887.0
const KNEE_Y := 70.0
# 支撑脚从前脚跟滚到后脚尖。坐标在各自的 96 像素分格内。
const SOLES := [
	{1: Vector2(65, 88), 11: Vector2(54, 89), 2: Vector2(34, 88)},
	{1: Vector2(62, 88), 11: Vector2(53, 89), 2: Vector2(33, 88)},
]
const FRAMES := {&"ready": 0, &"guard": 3, &"windup": 4, &"strike": 5, &"follow": 6,
	&"recover": 7, &"dodge": 8, &"hurt": 9, &"cast": 10}

# 每个地域一条长卷，由 art/side/plates/prompts.json 的四幅拼成，地面线都按 79% 出图。
# haze 是远景空气透视的颜色（snow_haze.gdshader），weather 决定前景飘的东西，shadow 是脚下阴影。
# 长卷本身已经按远近压过色，空气透视只取雪道的一半（PLATE_DEPTH），不然远处的地标会被洗没。
const PLATES := {
	"drought": {"path": "res://art/side/plates/drought.webp", "floor": 0.79, "haze": Color("#d6c4a0"),
		"weather": &"dust", "shadow": Color("#3b2a1a9c")},
	"plague": {"path": "res://art/side/plates/plague.webp", "floor": 0.79, "haze": Color("#b8b69b"),
		"weather": &"ash", "shadow": Color("#1c1a16b4")},
	"mine": {"path": "res://art/side/plates/mine.webp", "floor": 0.79, "haze": Color("#9da3a8"),
		"weather": &"grit", "shadow": Color("#121416bc")},
	"war": {"path": "res://art/side/plates/war.webp", "floor": 0.79, "haze": Color("#a8b5c6"),
		"weather": &"ash", "shadow": Color("#1a2230ac")},
	"flood": {"path": "res://art/side/plates/flood.webp", "floor": 0.79, "haze": Color("#a7b6bb"),
		"weather": &"rain", "shadow": Color("#1f2a2eac")},
	"court": {"path": "res://art/side/plates/court.webp", "floor": 0.79, "haze": Color("#dde5ee"),
		"weather": &"mist", "shadow": Color("#3a4a66a0")},
}
# 长卷缺失时（还没出图、或日后新增地域）退回昆仑雪道，画面照常能跑。
const PLATE_DEPTH := 0.5
# 长卷两头各有一段为拼接留的空地（每幅两侧 18%，折合整卷约 5%），镜头不往那里停。
const PLATE_MARGIN := 0.05
const FALLBACK_PLATE := {"key": "kunlun", "texture": SNOW_PASS, "floor": SNOW_FLOOR, "depth": 1.0, "margin": 0.0,
	"haze": Color(0.80, 0.85, 0.89), "weather": &"snow", "shadow": Color("#23364aa8")}

static var _plate_cache := {}

# 按层取地域长卷。贴图按需加载，只留当前一张：六条长卷全常驻，手机上要吃掉上百兆显存。
static func plate_for(layer: int) -> Dictionary:
	var key := String(Places.block_of(layer).plate)
	var spec: Dictionary = PLATES.get(key, {})
	if spec.is_empty() or not ResourceLoader.exists(spec.path):
		return FALLBACK_PLATE
	if not _plate_cache.has(key):
		_plate_cache.clear()
		var plate := spec.duplicate()
		plate["key"] = key
		plate["depth"] = PLATE_DEPTH
		plate["margin"] = PLATE_MARGIN
		plate["texture"] = load(spec.path)
		_plate_cache[key] = plate
	return _plate_cache[key]

# 这一层落在长卷的哪儿：一个地域十层，从左端走到右端，天劫那层在最右。
static func plate_progress(layer: int) -> float:
	var span := Places.LAYERS_PER_BLOCK - 1
	return float(posmod(maxi(1, layer) - 1, Places.LAYERS_PER_BLOCK)) / float(span)

static func frame_for(pose: StringName) -> int:
	return FRAMES.get(pose, 0)

static func gait(distance: float, actor_scale: float, sprite: int, running: bool) -> Dictionary:
	var step_length := (33.0 if running else 22.0) * actor_scale
	var phase := fposmod(distance / step_length, 1.0)
	var frame := 1 if phase < 0.29 else (11 if phase < 0.70 else 2)
	return {"frame": frame, "sole": SOLES[sprite][frame] - PIVOT,
		"plant": (0.5 - phase) * step_length, "phase": phase, "step_length": step_length}

static func draw_gait(canvas: CanvasItem, sprite: Texture2D, gait_pose: Dictionary,
		foot_shift: Vector2, ink: Color) -> void:
	var source := frame_region(gait_pose.frame)
	var upper := Vector2(CELL.x, KNEE_Y)
	canvas.draw_texture_rect_region(sprite, Rect2(-PIVOT, upper), Rect2(source.position, upper), ink)
	# 只让膝盖以下跟随落脚点，肩、腰和武器仍随角色位置连续移动。
	var top := Vector2(0.0, KNEE_Y) - PIVOT
	var sole_height := float(gait_pose.sole.y) + PIVOT.y - KNEE_Y
	var bottom := Vector2(0.0, CELL.y) - PIVOT + foot_shift * ((CELL.y - KNEE_Y) / sole_height)
	var right := Vector2(CELL.x, 0.0)
	var points := PackedVector2Array([top, top + right, bottom + right, bottom])
	var tex_size := sprite.get_size()
	var uv_top := (source.position + Vector2(0.0, KNEE_Y)) / tex_size
	var uv_bottom := (source.position + Vector2(0.0, CELL.y)) / tex_size
	var uv_right := right / tex_size
	canvas.draw_polygon(points, PackedColorArray([ink]),
		PackedVector2Array([uv_top, uv_top + uv_right, uv_bottom + uv_right, uv_bottom]), sprite)

static func frame_region(frame: int) -> Rect2:
	var cell := Vector2(frame % 4, floori(frame / 4.0))
	return Rect2(cell * CELL, CELL)
