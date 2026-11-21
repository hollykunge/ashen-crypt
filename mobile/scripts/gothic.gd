extends RefCounted

const ORB_MATERIAL = preload("res://art/ember_orb.gdshader")

class Orb extends Control:
	var fraction := 1.0
	var glow := Color("#b34135")
	var shade := Color("#3e1413")
	var highlight := Color("#f6a28a")
	var glass: ShaderMaterial

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var face := ColorRect.new()
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glass = ShaderMaterial.new()
		glass.shader = ORB_MATERIAL
		glass.set_shader_parameter("amount", fraction)
		glass.set_shader_parameter("light_ink", glow)
		glass.set_shader_parameter("deep_ink", shade)
		glass.set_shader_parameter("glint_ink", highlight)
		face.material = glass
		add_child(face)
		face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func set_amount(current: float, total: float) -> void:
		var next := clampf(current / maxf(total, 1.0), 0.0, 1.0)
		if absf(next - fraction) >= 0.005 or (next != fraction and (next == 0.0 or next == 1.0)):
			fraction = next
			glass.set_shader_parameter("amount", fraction)

class Dock extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x < 100.0 or size.y < 55.0:
			return
		var w := size.x
		var h := size.y
		var rim := PackedVector2Array([Vector2(3, 22), Vector2(17, 7), Vector2(52, 7), Vector2(69, 17), Vector2(w - 69, 17), Vector2(w - 52, 7), Vector2(w - 17, 7), Vector2(w - 3, 22), Vector2(w - 3, h - 20), Vector2(w - 15, h - 6), Vector2(15, h - 6), Vector2(3, h - 20)])
		draw_colored_polygon(rim, Color("#14100fee"))
		var detail := rim.duplicate()
		detail.append(rim[0])
		draw_polyline(detail, Color("#7f6145"), 1.25, true)
		draw_line(Vector2(62, h - 11), Vector2(w - 62, h - 11), Color("#a27b51"), 1.0, true)
		draw_line(Vector2(66, 21), Vector2(w - 66, 21), Color("#583f2b"), 1.0, true)
		for rivet in [Vector2(66, h - 13), Vector2(w - 66, h - 13)]:
			draw_circle(rivet, 1.5, Color("#c7a473"), true, -1.0, true)

# 血条：掉血先留一截「余血」慢慢退，看得见这一下挨了多少。
class Meter extends Control:
	var fraction := 1.0
	var chip := 1.0
	var ink := Color("#c65c4c")
	var plate := Color("#191617")
	var ticks := 0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
		set_process(true)

	func _process(delta: float) -> void:
		if chip <= fraction + 0.001:
			if chip != fraction:
				chip = fraction
				queue_redraw()
			return
		chip = maxf(fraction, chip - delta * maxf(0.22, (chip - fraction) * 2.4))
		queue_redraw()

	func set_amount(current: float, total: float) -> void:
		var next := clampf(current / maxf(total, 0.001), 0.0, 1.0)
		if is_equal_approx(next, fraction):
			return
		if next > fraction:
			chip = next
		fraction = next
		queue_redraw()

	func _draw() -> void:
		var bounds := Rect2(Vector2.ZERO, size)
		draw_rect(bounds, plate)
		if chip > fraction:
			draw_rect(Rect2(0.0, 0.0, size.x * chip, size.y), Color(ink.lerp(Color.WHITE, 0.55), 0.55))
		var filled := Rect2(0.0, 0.0, size.x * fraction, size.y)
		draw_rect(filled, ink)
		if size.y >= 6.0 and fraction > 0.0:
			draw_rect(Rect2(0.0, 0.0, filled.size.x, maxf(1.0, size.y * 0.28)), Color(1, 1, 1, 0.16))
		for i in range(1, ticks):
			var x := size.x * float(i) / ticks
			draw_line(Vector2(x, 0.0), Vector2(x, size.y), Color(0.04, 0.06, 0.05, 0.55), 1.0)

# 技能按钮上的冷却扫盘：一圈由满到空的暗罩，比单看秒数直观。
class Sweep extends Control:
	var fraction := 0.0
	var starved := false
	var ink := Color("#121013")
	var edge := Color("#d8bd8a")

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func show_amount(left: float, total: float, out_of_mana: bool) -> void:
		var next := clampf(left / maxf(total, 0.001), 0.0, 1.0)
		if is_equal_approx(next, fraction) and starved == out_of_mana:
			return
		fraction = next
		starved = out_of_mana
		queue_redraw()

	func _draw() -> void:
		if fraction <= 0.001 and not starved:
			return
		var center := size * 0.5
		var radius := size.length() * 0.5
		if starved and fraction <= 0.001:
			draw_rect(Rect2(Vector2.ZERO, size), Color("#1d2a3c99"))
			return
		if fraction >= 0.999:
			draw_rect(Rect2(Vector2.ZERO, size), Color(ink, 0.62))
			return
		var span := TAU * fraction
		var points := PackedVector2Array([center])
		var steps := maxi(3, ceili(span / 0.22))
		for i in range(steps + 1):
			points.append(center + Vector2.from_angle(-PI * 0.5 + span * i / steps) * radius)
		draw_colored_polygon(points, Color(ink, 0.62))
		var tip := center + Vector2.from_angle(-PI * 0.5 + span) * radius
		draw_line(center, tip, Color(edge, 0.45), 1.0, true)

class Glyph extends Control:
	var symbol: StringName = &"sword"
	var ink := Color("#d9bd87")
	var art: Texture2D

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if art != null:
			draw_texture_rect(art, Rect2(Vector2.ZERO, size), false)
			return
		var fit := minf(size.x, size.y) / 30.0
		draw_set_transform(size * 0.5 - Vector2(15, 15) * fit, 0.0, Vector2.ONE * fit)
		match symbol:
			&"anvil":
				draw_colored_polygon(PackedVector2Array([Vector2(3, 8), Vector2(27, 8), Vector2(23, 13), Vector2(18, 14), Vector2(18, 19), Vector2(22, 22), Vector2(22, 25), Vector2(8, 25), Vector2(8, 22), Vector2(12, 19), Vector2(12, 13), Vector2(6, 12)]), ink)
				_path([Vector2(9, 5), Vector2(20, 5)], 1.4)
			&"hammer":
				draw_line(Vector2(6, 24), Vector2(19, 11), ink, 3.3, true)
				draw_colored_polygon(PackedVector2Array([Vector2(13, 7), Vector2(18, 2), Vector2(28, 12), Vector2(23, 17)]), ink)
			&"equip":
				_path([Vector2(5, 14), Vector2(12, 21), Vector2(25, 8)], 2.7)
			&"unequip":
				_path([Vector2(7, 15), Vector2(23, 15)], 2.7)
			&"pause":
				draw_rect(Rect2(9, 6, 4, 18), ink)
				draw_rect(Rect2(17, 6, 4, 18), ink)
			&"play":
				draw_colored_polygon(PackedVector2Array([Vector2(10, 5), Vector2(23, 15), Vector2(10, 25)]), ink)
			&"portal", &"leave":
				_path([Vector2(5, 25), Vector2(5, 10), Vector2(12, 4), Vector2(19, 10), Vector2(19, 25)], 1.7)
				_path([Vector2(11, 16), Vector2(26, 16)], 1.7)
				if symbol == &"portal":
					_path([Vector2(21, 11), Vector2(26, 16), Vector2(21, 21)], 1.7)
				else:
					_path([Vector2(16, 11), Vector2(11, 16), Vector2(16, 21)], 1.7)
			&"retry":
				draw_arc(Vector2(15, 15), 9, -0.52, 4.63, 24, ink, 1.9, true)
				_path([Vector2(9, 6), Vector2(15, 6), Vector2(15, 11)], 1.9)
			&"mute", &"sound":
				draw_colored_polygon(PackedVector2Array([Vector2(5, 11), Vector2(10, 11), Vector2(15, 7), Vector2(15, 23), Vector2(10, 19), Vector2(5, 19)]), ink)
				if symbol == &"mute":
					_path([Vector2(19, 12), Vector2(25, 18)], 1.6)
					_path([Vector2(25, 12), Vector2(19, 18)], 1.6)
				else:
					draw_arc(Vector2(15, 15), 7, -0.7, 0.7, 12, ink, 1.6, true)
					draw_arc(Vector2(15, 15), 11, -0.7, 0.7, 12, ink, 1.6, true)
			&"back":
				_path([Vector2(21, 7), Vector2(11, 15), Vector2(21, 23)], 2.3)
			&"forward":
				_path([Vector2(9, 7), Vector2(19, 15), Vector2(9, 23)], 2.3)
			&"retreat":
				_path([Vector2(13, 8), Vector2(5, 15), Vector2(13, 22)], 2.1)
				_path([Vector2(23, 8), Vector2(15, 15), Vector2(23, 22)], 2.1)
			&"arrow", &"fan", &"heavy":
				_arrow()
				if symbol == &"fan":
					_path([Vector2(15, 4), Vector2(26, 4), Vector2(26, 15)], 1.4)
					_path([Vector2(27, 20), Vector2(27, 25), Vector2(22, 25)], 1.1)
				elif symbol == &"heavy":
					_path([Vector2(4, 20), Vector2(17, 6)], 2.3)
			&"cleave":
				_path([Vector2(6, 21), Vector2(13, 15), Vector2(24, 8)], 2.4)
				_path([Vector2(15, 22), Vector2(21, 18), Vector2(26, 13)], 1.7)
				_path([Vector2(5, 26), Vector2(24, 26)], 1.3)
			&"frost":
				for i in range(6):
					var direction := Vector2.from_angle(i * TAU / 6.0)
					var point := Vector2(15, 15) + direction * 10.0
					_path([Vector2(15, 15), point], 1.6)
					_path([point - direction.rotated(-0.55) * 4.5, point, point - direction.rotated(0.55) * 4.5], 1.3)
			&"spark", &"sigil":
				var diamond := PackedVector2Array([Vector2(15, 3), Vector2(21, 12), Vector2(26, 15), Vector2(21, 18), Vector2(15, 27), Vector2(9, 18), Vector2(4, 15), Vector2(9, 12), Vector2(15, 3)])
				draw_polyline(diamond, ink, 1.6, true)
				draw_circle(Vector2(15, 15), 2.3, ink, true, -1.0, true)
				if symbol == &"sigil":
					draw_arc(Vector2(15, 15), 12.0, 0.0, TAU, 32, Color(ink, 0.5), 1.1, true)
			&"slash":
				_path([Vector2(7, 5), Vector2(14, 14), Vector2(26, 9), Vector2(19, 20), Vector2(8, 26)], 2.0)
				_path([Vector2(4, 16), Vector2(8, 20), Vector2(13, 22)], 1.25)
			# 战斗操作三档：手动是一枚摇杆；自动普攻是一把剑绕一圈；全自动再添一颗法术星。
			&"manual":
				draw_arc(Vector2(15, 17), 10.0, 0.0, TAU, 28, Color(ink, 0.55), 1.4, true)
				draw_line(Vector2(15, 17), Vector2(19, 10), ink, 2.2, true)
				draw_circle(Vector2(19.5, 9.0), 3.6, ink, true, -1.0, true)
			&"assist", &"auto":
				_path([Vector2(9, 21), Vector2(20, 10)], 2.4)
				_path([Vector2(7, 16), Vector2(14, 23)], 1.8)
				draw_arc(Vector2(15, 15), 12.0, -2.2, 2.0, 24, Color(ink, 0.7), 1.3, true)
				_path([Vector2(5.5, 7.5), Vector2(8.0, 6.0), Vector2(8.6, 9.1)], 1.3)
				if symbol == &"auto":
					var star := Vector2(23, 7)
					for k in range(4):
						var direction := Vector2.from_angle(k * PI * 0.5)
						draw_line(star - direction * 4.0, star + direction * 4.0, ink, 1.2, true)
					draw_circle(star, 1.6, ink, true, -1.0, true)
			# 挂机底栏：行囊、告示牌、出发（渡劫层换成一道雷）。
			&"pack":
				draw_arc(Vector2(15, 9), 4.5, PI, TAU, 12, ink, 1.8, true)
				draw_colored_polygon(PackedVector2Array([Vector2(7, 11), Vector2(23, 11), Vector2(25, 25), Vector2(5, 25)]), ink)
				draw_line(Vector2(7, 16), Vector2(23, 16), Color(0.08, 0.07, 0.08, 0.8), 1.4, true)
				draw_rect(Rect2(13, 14, 4, 5), Color(0.08, 0.07, 0.08, 0.8))
			&"notice":
				_path([Vector2(8, 27), Vector2(8, 6)], 2.0)
				_path([Vector2(22, 27), Vector2(22, 6)], 2.0)
				_path([Vector2(5, 6), Vector2(25, 6)], 2.2)
				draw_rect(Rect2(10, 9, 10, 12), Color(ink, 0.9))
				for row in [12.5, 15.5, 18.5]:
					draw_line(Vector2(12, row), Vector2(18, row), Color(0.08, 0.07, 0.08, 0.75), 1.0, true)
			&"march":
				_path([Vector2(6, 8), Vector2(13, 15), Vector2(6, 22)], 2.4)
				_path([Vector2(14, 8), Vector2(21, 15), Vector2(14, 22)], 2.4)
				_path([Vector2(22, 9), Vector2(26, 15), Vector2(22, 21)], 1.6)
			&"jie":
				draw_colored_polygon(PackedVector2Array([Vector2(17, 3), Vector2(8, 17), Vector2(14, 17), Vector2(11, 27), Vector2(22, 12), Vector2(16, 12)]), ink)
			# 战斗速度：一、二、三个三角。
			&"speed1", &"speed2", &"speed3":
				var count := int(String(symbol).right(1))
				var step := 7.0
				var left := 15.0 - (count * step + 3.0) * 0.5
				for k in range(count):
					var x := left + k * step
					draw_colored_polygon(PackedVector2Array([Vector2(x, 9), Vector2(x + 10, 15), Vector2(x, 21)]),
						Color(ink, 0.55 + 0.45 * float(k + 1) / count))
			_:
				draw_colored_polygon(PackedVector2Array([Vector2(11, 19), Vector2(22, 5), Vector2(27, 3), Vector2(25, 10), Vector2(15, 22)]), ink)
				_path([Vector2(8, 17), Vector2(17, 24)], 2.0)
				_path([Vector2(12, 21), Vector2(6, 27)], 2.5)

	func _arrow() -> void:
		_path([Vector2(5, 25), Vector2(23, 7)], 1.9)
		_path([Vector2(16, 7), Vector2(23, 7), Vector2(23, 14)], 1.9)
		_path([Vector2(5, 17), Vector2(5, 25), Vector2(13, 25)], 1.3)

	func _path(points: PackedVector2Array, width: float) -> void:
		draw_polyline(points, ink, width, true)
