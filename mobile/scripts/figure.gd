extends RefCounted

# 战场上叠加于皮影角色的五行特效。
const Motion = preload("res://scripts/motion.gd")
const Rig = preload("res://scripts/rig.gd")

# 腕光：出手瞬间手上那一团，护手的五行色。
static func hands(canvas: CanvasItem, rig: Rig, look: Dictionary) -> void:
	var amount := float(look.hands_amount) * maxf(float(rig.pose.ghost), float(rig.pose.charge))
	if amount <= 0.04:
		return
	var grip := rig.at(rig.width * (0.42 if Motion.is_striking(rig.pose.frame) else 0.16), -rig.height * 0.58)
	for i in range(3):
		var radius := (9.0 - i * 2.6) * rig.zoom * (0.6 + amount)
		canvas.draw_circle(grip, radius, Color(look.hands, 0.10 + 0.13 * amount), true, -1.0, true)

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
