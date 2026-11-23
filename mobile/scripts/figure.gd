extends RefCounted

# 角色绘制。
#
# 立绘只有两张，所以这里不按帧画，而是把整张画切成横带，按高度加权地弯折、压扁、倾斜，
# 再叠上装备决定的袍色、边光、披帛、腕光、符牌与脚下法阵。
# 所有坐标都在「脚底为原点、上为负 y」的角色本地系里算，调用方只给落脚点和缩放。

const Motion = preload("res://scripts/motion.gd")
const Rig = preload("res://scripts/rig.gd")

# 横带越多形变越柔和，手机上 7 带已经看不出接缝。
const BANDS := 12
const OVERLAP := 0.0

# 画一具会弯折的身体：整张立绘切成横带，逐带按姿态挪位。
static func body(canvas: CanvasItem, rig: Rig, texture: Texture2D, tint: Color) -> void:
	var left := -rig.width * float(rig.pose.pivot)
	var right := left + rig.width
	var ink := Color(tint, tint.a * float(rig.pose.fade))
	for band in range(BANDS):
		var v0 := float(band) / BANDS
		var v1 := float(band + 1) / BANDS
		var y0 := -rig.height * (1.0 - v0)
		var y1 := -rig.height * (1.0 - v1) + (OVERLAP if band < BANDS - 1 else 0.0)
		var quad := PackedVector2Array([rig.at(left, y0), rig.at(right, y0), rig.at(right, y1), rig.at(left, y1)])
		var uvs := PackedVector2Array([Vector2(0.0, v0), Vector2(1.0, v0), Vector2(1.0, v1), Vector2(0.0, v1)])
		canvas.draw_colored_polygon(quad, ink, uvs, texture)

# 染袍：护甲的五行色罩在整条剪影上。
# 立绘的袍子本来就接近黑，乘色是染不上的，所以这里把颜色推到过曝再压低不透明度，
# 等于在剪影范围内刷一层色，暗处吃色、亮处只偏一点点，远看就是换了一身行头。
static func dye(canvas: CanvasItem, rig: Rig, texture: Texture2D, color: Color, amount: float) -> void:
	if amount <= 0.02:
		return
	var saturated := Color(color.r * 6.0, color.g * 6.0, color.b * 6.0,
		(0.11 + 0.26 * amount) * float(rig.pose.fade))
	body(canvas, rig, texture, saturated)

# 边光：把同一张画在四周偏移着描一遍，阴阳越偏颜色越明显。
static func rim(canvas: CanvasItem, rig: Rig, texture: Texture2D, color: Color, amount: float) -> void:
	if amount <= 0.02:
		return
	var ink := Color(color, 0.42 * amount * float(rig.pose.fade))
	for offset in [Vector2(-1.7, 0.0), Vector2(1.7, 0.0), Vector2(0.0, -1.7), Vector2(0.0, 1.5)]:
		body(canvas, rig.moved(offset), texture, ink)

# 残影：动作曲线里的 ghost 轨决定几道、多浓。
static func ghosts(canvas: CanvasItem, rig: Rig, texture: Texture2D, color: Color, back: Vector2) -> void:
	var strength := float(rig.pose.ghost)
	if strength <= 0.03:
		return
	for i in range(3, 0, -1):
		var fade := strength * (0.26 - i * 0.055)
		if fade <= 0.0:
			continue
		body(canvas, rig.moved(back * float(i)), texture, Color(color, fade))

# 披帛：护甲的五行色，挂在肩后随动作飘。没有护甲就不画。
static func sash(canvas: CanvasItem, rig: Rig, look: Dictionary, clock: float, drive: float) -> void:
	if not look.cape:
		return
	var ink: Color = look.cape_color
	var fade := float(rig.pose.fade)
	# 一条绸带画三遍：外层最虚最宽，里层最实最窄，末端收成尖，才有丝的轻。
	for layer in range(3):
		var girth := 1.0 - layer * 0.34
		var alpha := (0.22 + layer * 0.22) * fade
		canvas.draw_colored_polygon(_ribbon(rig, look, clock, drive, girth),
			Color(ink.lerp(Color.WHITE, layer * 0.18), alpha))

static func _ribbon(rig: Rig, look: Dictionary, clock: float, drive: float, girth: float) -> PackedVector2Array:
	var length: float = rig.height * (0.54 + 0.32 * float(look.cape_length))
	var top := -rig.height * 0.74
	var swing := 6.0 + sin(clock * 2.3) * 4.0 + drive * 14.0 - float(rig.pose.bend) * 0.9
	var front := PackedVector2Array()
	var back := PackedVector2Array()
	var segments := 8
	for i in range(segments + 1):
		var ratio := float(i) / segments
		var droop := top + length * ratio
		# 绸带挂在肩后，越往下甩得越远，离开身体轮廓才看得见。
		var sway := -rig.width * 0.24 - swing * ratio * ratio - sin(clock * 3.1 + ratio * 2.6) * 3.8 * ratio
		var span := rig.width * 0.115 * girth * (1.0 - ratio * ratio * 0.92)
		front.append(rig.at(sway - span, droop))
		back.insert(0, rig.at(sway + span, droop))
	front.append_array(back)
	return front

# 腕光：出手瞬间手上那一团，护手的五行色。
static func hands(canvas: CanvasItem, rig: Rig, look: Dictionary) -> void:
	var amount := float(look.hands_amount) * maxf(float(rig.pose.ghost), float(rig.pose.charge))
	if amount <= 0.04:
		return
	var grip := rig.at(rig.width * (0.42 if Motion.is_striking(rig.pose.frame) else 0.16), -rig.height * 0.58)
	for i in range(3):
		var radius := (9.0 - i * 2.6) * rig.zoom * (0.6 + amount)
		canvas.draw_circle(grip, radius, Color(look.hands, 0.10 + 0.13 * amount), true, -1.0, true)

# 刃光：兵器的五行色，蓄力与挥击时最亮。
static func edge(canvas: CanvasItem, rig: Rig, look: Dictionary, clock: float) -> void:
	var amount := float(look.weapon_amount)
	if amount <= 0.04:
		return
	var striking := Motion.is_striking(rig.pose.frame)
	var pulse := 0.42 + 0.22 * sin(clock * 3.4) + (0.5 if striking else 0.0) + float(rig.pose.charge) * 0.5
	var tip := rig.at(rig.width * (0.56 if striking else 0.30), -rig.height * (0.62 if striking else 0.80))
	for i in range(4):
		var radius := (17.0 - i * 3.6) * rig.zoom * (0.5 + amount * 0.8)
		canvas.draw_circle(tip, radius, Color(look.weapon, 0.085 * pulse * (1.0 + amount)), true, -1.0, true)

# 脚下法阵：成了格局才有，环数与格局强弱挂钩。
static func halo(canvas: CanvasItem, rig: Rig, look: Dictionary, clock: float) -> void:
	var rings: int = look.halo
	if rings <= 0:
		return
	var center := rig.ground() + Vector2(0.0, 2.0 * rig.zoom)
	for i in range(rings):
		var radius := (30.0 + i * 9.0) * rig.zoom
		var spin := clock * (0.5 + i * 0.28) * (1.0 if i % 2 == 0 else -1.0)
		var alpha := 0.62 - i * 0.12
		var marks := 12 + i * 5
		for mark in range(marks):
			var angle := spin + mark * TAU / marks
			var point := center + Vector2(cos(angle) * radius, sin(angle) * radius * 0.34)
			var pixels := (2.6 if mark % 3 == 0 else 1.8) * rig.zoom
			canvas.draw_rect(Rect2(point - Vector2.ONE * pixels * 0.5, Vector2.ONE * pixels), Color(look.halo_color, alpha))

# 尘土：落脚、蹬地、砸地时从脚下往后扬。
static func dust(canvas: CanvasItem, rig: Rig, look: Dictionary, seed_value: float) -> void:
	var amount := float(rig.pose.dust)
	if amount <= 0.05:
		return
	var ink: Color = look.boots if float(look.boots_amount) > 0.0 else Color("#cbb9a0")
	var count := mini(9, 3 + roundi(amount * 4.0))
	for i in range(count):
		var drift := sin(seed_value * 3.3 + i * 2.17)
		var spread := (0.4 + absf(drift)) * amount
		var point := rig.ground() + Vector2(-(7.0 + i * 5.5) * spread, -(2.0 + i * 2.2) * spread) * rig.zoom * rig.facing
		var pixels := (2.0 + (i % 3)) * rig.zoom
		canvas.draw_rect(Rect2(point, Vector2.ONE * pixels), Color(ink, clampf(0.34 * amount - i * 0.03, 0.0, 0.5)))

# 受击白闪：把身体再描一层近白的叠色。
static func flash(canvas: CanvasItem, rig: Rig, texture: Texture2D) -> void:
	var amount := float(rig.pose.flash)
	if amount <= 0.02:
		return
	body(canvas, rig, texture, Color(1.0, 0.94, 0.9, 0.55 * amount))
