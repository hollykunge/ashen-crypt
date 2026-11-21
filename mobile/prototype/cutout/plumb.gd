extends SceneTree
## 站姿铅垂线：脖子根在髋关节前后多少度、耳朵在脖子根前后多少度（正值靠前）。正常站立：前者 0～3°、后者 -2～2°。
##   godot --path mobile --headless --fixed-fps 30 --script res://prototype/cutout/plumb.gd -- stand <躯干tilt> <头tilt>
var r
var n := 0
func _initialize():
	var a := OS.get_cmdline_user_args()
	r = load("res://prototype/cutout/cutout_rig.gd").new()
	root.add_child(r)
	var cfg = JSON.parse_string(FileAccess.get_file_as_string("res://prototype/cutout/hero/rig.json"))
	cfg.parts.torso.tilt = float(a[1]); cfg.parts.head.tilt = float(a[2])
	cfg.idle.torso = 0.0
	r.setup_dict(cfg, "res://prototype/cutout/hero/parts")
	r.play(a[0])
func _process(d):
	n += 1
	if n < 40:
		return false
	var hip: Vector2 = r._bones.leg_near_up.global_position
	var neck: Vector2 = r._bones.neck.global_position
	var head_spr: Sprite2D
	for c in r._bones.neck.get_children():
		if c is Sprite2D: head_spr = c
	var ear: Vector2 = head_spr.global_transform * Vector2(95, 120)
	var a := OS.get_cmdline_user_args()
	print("躯干%s 头%s：脖子根相对髋 %.1f°（正值靠前） 耳朵相对脖子根 %.1f°" % [a[1], a[2], rad_to_deg((neck - hip).angle_to(Vector2.UP)) * -1, rad_to_deg((ear - neck).angle_to(Vector2.UP)) * -1])
	return true
