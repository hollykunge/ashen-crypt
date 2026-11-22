extends SceneTree
## 走路时量两只脚：前脚掌（boot 的 ball）、脚跟离地多高，踩地时前脚掌往前后滑了多少；顺手存一排分解图。
##   godot --path mobile --fixed-fps 60 --resolution 1400x420 --script res://prototype/cutout/heel_check.gd -- [walk|run] [分解图.png] [heel 角度，覆盖 rig.json]
const HEEL := Vector2(56, 298)  # 靴子图里脚跟最后面、贴地的那一点
var r
var n := 0
var gait := "walk"
var out := ""
var strip: Image
var slip := {"near": [], "far": []}  # 每只脚每次踩地一组
var down := {"near": false, "far": false}
func _initialize():
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var a := OS.get_cmdline_user_args()
	gait = a[0] if a.size() > 0 else "walk"
	out = a[1] if a.size() > 1 else ""
	var bg := ColorRect.new(); bg.color = Color(0.25, 0.26, 0.3); bg.size = Vector2(1400, 420); root.add_child(bg)
	r = load("res://prototype/cutout/cutout_rig.gd").new()
	root.add_child(r)
	r.setup("res://prototype/cutout/swordsman/rig.json", "res://prototype/cutout/swordsman/parts")
	r.position = Vector2(200, 400)
	if a.size() > 2:
		var cfg: Dictionary = r.rig.duplicate(true)
		cfg[gait]["heel"] = float(a[2])
		r.reload_params(cfg)
	r.play(gait)

func _local(side: String, p: Vector2) -> Vector2:
	var s: Vector2 = r._s("shin")
	var ankle: Vector2 = r._v(r.rig.parts.shin.ankle)
	var g: Vector2 = r._bones["foot_" + side].global_transform * ((p - ankle) * s)
	return r.global_transform.affine_inverse() * g

func _process(d):
	n += 1
	var g: Dictionary = r._walk if gait == "walk" else r._run
	var period: float = g.period
	var frames := int(round(period / d))
	if n > 20 and n <= 20 + frames:
		var ph := fposmod(r._action_t / period, 1.0)
		var line := "%.2f" % ph
		for side in ["near", "far"]:
			var u := fposmod(ph + (0.5 if side == "far" else 0.0), 1.0)
			var ball := _local(side, r._v(r.rig.parts.boot.ball))
			var heel := _local(side, HEEL)
			line += "  %s 掌(%.0f,%.1f) 跟高%.1f" % [side, ball.x, -ball.y, -heel.y]
			# 踩地时前脚掌应该跟着地面匀速往后退：减掉地面走过的距离，剩下的就是打滑
			if u < g.duty:
				if not down[side]:
					slip[side].append([])
				slip[side][-1].append(ball.x + r._action_t * r.walk_speed() / r.scale.x)
			down[side] = u < g.duty
		if n % 4 == 0:
			print(line)
	if out != "" and n > 20 and n <= 20 + frames and (n - 21) % int(ceil(frames / 8.0)) == 0:
		RenderingServer.force_draw(false)
		var shot := root.get_texture().get_image().get_region(Rect2i(40, 20, 320, 400))
		if strip == null:
			strip = Image.create(320 * 8, 400, false, shot.get_format())
		var i := (n - 21) / int(ceil(frames / 8.0))
		if i < 8:
			strip.blit_rect(shot, Rect2i(0, 0, 320, 400), Vector2i(320 * i, 0))
	if n > 20 + frames:
		for side in slip:
			for v in slip[side]:
				if v.size() > 2:
					print("%s 一次踩地（%d 帧）前脚掌前后滑了 %.1f 像素" % [side, v.size(), v.max() - v.min()])
		if strip:
			strip.save_png(out)
		return true
	return false
