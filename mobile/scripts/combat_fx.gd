extends RefCounted

const IVORY := Color("#fff1c9")
const CINNABAR := Color("#b6452f")
## 皮影戏：刀光换成一片带卷云火舌的金橙焰弧（art/piying/fx/slash.png，凸面朝右），按刀光的转轴、半径、倾角贴上去
const PIYING := true
const PIYING_SLASH := preload("res://art/piying/fx/slash.png")
## 月牙在刀光椭圆里占的范围（以椭圆半轴为单位）：左边到右边、上到下
const PIYING_SLASH_BOX := Rect2(-0.40, -1.04, 1.50, 2.08)

static func slash(canvas: CanvasItem, origin: Vector2, effect: Dictionary, age: float, actor_zoom: float) -> void:
	var side := -1.0 if cos(float(effect.angle)) < 0.0 else 1.0
	var stroke: int = effect.stroke
	var final: bool = effect.finisher
	var slant := -1.0 if stroke % 2 == 0 else 1.0
	var pivot := origin + Vector2(24.0 * side, -41.0 + slant * 8.0) * actor_zoom
	var swing: float = effect.radius * (0.52 + age * 0.37) * (1.13 if final else 1.0)
	var axes := Vector2(swing, swing * (0.76 if final else 0.54))
	var lean := slant * 0.51
	var opacity := pow(1.0 - age, 0.92)
	var tint: Color = effect.color
	if PIYING:
		var box := PIYING_SLASH_BOX
		var pts := PackedVector2Array()
		for c in [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]:
			pts.append(pivot + (c * axes).rotated(lean) * Vector2(side, 1.0))
		canvas.draw_polygon(pts, PackedColorArray([Color(1, 1, 1, opacity)]),
			PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]), PIYING_SLASH)
		return
	_crescent(canvas, pivot, axes, side, lean, 15.0 if final else 11.0, Color(CINNABAR, opacity * 0.50))
	_crescent(canvas, pivot, axes * 0.98, side, lean, 9.0 if final else 5.5, Color(tint, opacity))
	_crescent(canvas, pivot, axes * 0.94, side, lean + 0.09, 3.0, Color(IVORY, opacity))
	_sparks(canvas, pivot + Vector2(swing * 0.68 * side, slant * 22.0), side, age, Color(tint, opacity), 10 if final else 6)

# 枪芒：从肩前直直地送出去一道梭形的光，越往前越细，枪尖处炸一把火星。
static func thrust(canvas: CanvasItem, origin: Vector2, effect: Dictionary, age: float, actor_zoom: float) -> void:
	var side := -1.0 if cos(float(effect.angle)) < 0.0 else 1.0
	var opacity := pow(1.0 - age, 1.4)
	var tint: Color = effect.color
	var start := origin + Vector2(26.0 * side, -45.0 * actor_zoom)
	var length: float = effect.radius * (0.62 + age * 0.44)
	var tip := start + Vector2(length * side, 0.0)
	for layer in [[7.5, Color(CINNABAR, opacity * 0.45)], [4.4, Color(tint, opacity)], [1.6, Color(IVORY, opacity)]]:
		var girth: float = layer[0]
		canvas.draw_colored_polygon(PackedVector2Array([start, start.lerp(tip, 0.34) - Vector2(0.0, girth),
			tip, start.lerp(tip, 0.34) + Vector2(0.0, girth)]), layer[1])
	_sparks(canvas, tip, side, age, Color(tint, opacity), 8)

static func cast(canvas: CanvasItem, origin: Vector2, effect: Dictionary, age: float) -> void:
	var strength := pow(1.0 - age, 1.28)
	var tint: Color = effect.color
	var kind: StringName = effect.type
	var side := -1.0 if cos(float(effect.angle)) < 0.0 else 1.0
	var radius: float = effect.radius * (0.50 + 0.59 * age)
	var center := origin - Vector2(0.0, 42.0)
	if kind == &"arrow_impact":
		_sparks(canvas, center, side, age, Color(tint, strength), 12)
		return
	if kind == &"arrow_seal":
		for i in range(-1, 2):
			var arrow := center + Vector2((23.0 + age * 83.0) * side, i * (11.0 + age * 15.0))
			canvas.draw_line(arrow - Vector2(47.0 * side, i * 9.0), arrow, Color(tint, strength * 0.65), 3.0, true)
			_talisman(canvas, arrow, 7.0, strength, tint)
		return
	_ring(canvas, origin, Vector2(radius, radius * 0.20), Color(tint, strength), 2.3, 40)
	_ring(canvas, origin, Vector2(radius * 0.78, radius * 0.155), Color(tint, strength * 0.57), 1.2, 8)
	var number := 5 if kind == &"quake_seal" or kind == &"seal_burst" else 3
	for i in range(number):
		var anchor := origin + Vector2(cos(TAU * i / number) * radius, sin(TAU * i / number) * radius * 0.17)
		_talisman(canvas, anchor - Vector2(0, 16.0 + 64.0 * age), 9.0 + i % 2 * 4.0, strength, tint)
	match kind:
		&"seal_burst":
			_crescent(canvas, center - Vector2(side * 23.0, 14.0), Vector2(radius, radius * 0.60),
				side, 0.72 - age * 0.35, 15.0, Color(CINNABAR, strength * 0.73))
			_crescent(canvas, center + Vector2(side * 19.0, 11.0), Vector2(radius * 0.79, radius * 0.58),
				-side, -0.75 + age * 0.26, 10.0, Color(tint.lerp(IVORY, 0.48), strength))
			_sparks(canvas, center, side, age, Color(tint, strength), 15)
		&"quake_seal":
			for i in range(-3, 4):
				var end := origin + Vector2(i * radius * 0.34, 8.0 + absf(float(i)) * 3.1)
				canvas.draw_polyline(PackedVector2Array([origin, origin.lerp(end, 0.45) + Vector2(0, -7), end]),
					Color(IVORY, strength), 1.8, true)
			_sparks(canvas, origin, side, age, Color(tint, strength), 15)
		&"spell_impact":
			for i in range(-1, 2):
				var foot := origin + Vector2(i * radius * 0.57, -8.0)
				var bolt := PackedVector2Array([foot + Vector2(34.0 * i + 23.0, -162.0), foot + Vector2(-12, -93),
					foot + Vector2(19, -106), foot + Vector2(-18, -49), foot + Vector2(4, -59), foot])
				canvas.draw_polyline(bolt, Color(tint, strength * 0.45), 8.0, true)
				canvas.draw_polyline(bolt, Color(IVORY, strength), 2.0, true)
		&"spell_seal":
			_ring(canvas, center, Vector2.ONE * 26.0, Color(tint, strength * 0.88), 2.3, 6)
			_talisman(canvas, center, 19.0, strength, tint)

static func _crescent(canvas: CanvasItem, pivot: Vector2, axes: Vector2, side: float,
		lean: float, thickness: float, color: Color) -> void:
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	# 横切的刃口沿着弧线收细，拖尾的透明度随弧长下降。
	for rim in range(2):
		for i in range(23):
			var t := float(i if rim == 0 else 22 - i) / 22.0
			var angle := -1.04 + 2.16 * t
			var inset := (0.65 + sin(t * PI) * thickness) * rim
			var edge := (Vector2.from_angle(angle) * (axes - Vector2.ONE * inset)).rotated(lean)
			points.append(pivot + edge * Vector2(side, 1.0))
			colors.append(Color(color, color.a * (0.20 + 0.8 * sin(t * PI)) * (1.0 if rim == 0 else 0.42)))
	canvas.draw_polygon(points, colors)

static func _ring(canvas: CanvasItem, origin: Vector2, axes: Vector2, ink: Color, width: float, sides: int) -> void:
	var points := PackedVector2Array()
	for i in range(sides + 1):
		points.append(origin + Vector2.from_angle(TAU * i / sides) * axes)
	canvas.draw_polyline(points, ink, width, true)

static func _talisman(canvas: CanvasItem, center: Vector2, height: float, alpha: float, tint: Color) -> void:
	var corners := PackedVector2Array([center + Vector2(-height * 0.26, -height),
		center + Vector2(height * 0.48, -height * 0.85), center + Vector2(height * 0.26, height),
		center + Vector2(-height * 0.48, height * 0.85)])
	canvas.draw_colored_polygon(corners, Color(tint.lerp(IVORY, 0.55), alpha * 0.78))
	canvas.draw_polyline(PackedVector2Array([center + Vector2(1, -height * 0.64),
		center + Vector2(-2, height * 0.38), center + Vector2(3, height * 0.36)]), Color(CINNABAR, alpha), 1.4)
	for line in [-0.24, 0.06]:
		canvas.draw_line(center + Vector2(-height * 0.22, height * line),
			center + Vector2(height * 0.24, height * line - 1.0), Color(CINNABAR, alpha), 1.0)

static func _sparks(canvas: CanvasItem, origin: Vector2, side: float, age: float, color: Color, count: int) -> void:
	for i in range(count):
		var ray := Vector2((14.0 + (i * 17) % 73) * side, float((i * 23) % 83 - 41))
		var point := origin + ray * (0.22 + age * 1.25) + Vector2(0.0, age * age * 28.0)
		canvas.draw_line(point - ray * (0.14 * (1.0 - age)), point, color, 1.0 + i % 3, true)
