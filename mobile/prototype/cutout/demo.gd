extends Node2D
## 皮影小样的演示：同一个角色的几套外观并排，同一套骨骼、同一串动作，只是挂的部件图不同。
## 角色目录里的 demo.json 写要并排的外观目录和标签。
##
##   godot --path mobile res://prototype/cutout/demo.tscn -- hero                          # 开窗口直接看
##   godot --path mobile --fixed-fps 30 res://prototype/cutout/demo.tscn -- hero <目录>     # 每帧截图存进目录

const ROOT := "res://prototype/cutout/"
const GROUND := 570.0
## 动作表：[开始时间, 动作]
const TIMELINE := [[0.0, "idle"], [1.0, "walk"], [2.4, "run"], [4.4, "attack"], [5.6, "idle"], [6.2, "attack"], [7.4, "idle"]]
const LENGTH := 8.2

var rigs: Array = []
var labels: Array = []
var attack_name := "攻击"
var _t := 0.0
var _step := 0
var _scroll := 0.0
var _frames_dir := ""  # 给了目录就每帧截一张图存进去（godot ... demo.tscn -- <目录>，配 --fixed-fps 30）
var _frame := 0
var _stand := false
var _screen := false  # demo.json 的 stage 为 "screen" 时铺皮影戏幕布


func _ready() -> void:
	# 工程按竖屏手机缩放画面；小样按窗口像素直接画
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().size = Vector2i(1280, 660)
	var args := OS.get_cmdline_user_args()
	var who: String = args[0] if args.size() > 0 else "shanxiao"
	if args.size() > 1:
		_frames_dir = args[1]
		Engine.max_fps = 0
		# 录帧时窗口要在最前面：被别的窗口（比如调参面板）挡住时 macOS 不刷新它，截到的全是旧画面
		get_window().always_on_top = true
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + who + "/demo.json"))
	labels = cfg.labels
	attack_name = cfg.get("attack", attack_name)
	_screen = cfg.get("stage", "") == "screen"
	var outfits: Array = cfg.outfits
	# 第三个参数 stand：只摆一个笔直站着的光身版，截一张图就退出，拿去跟设定图比比例
	_stand = args.size() > 2 and args[2] == "stand"
	if _stand:
		outfits = [outfits[0]]
	for i in outfits.size():
		var r := preload("res://prototype/cutout/cutout_rig.gd").new()
		add_child(r)
		r.setup(ROOT + who + "/rig.json", r.resolve_outfit(ROOT + who + "/", outfits[i]))
		r.position = Vector2(1280.0 / outfits.size() * (i + 0.5) - 30, GROUND)
		r.scale *= float(cfg.get("zoom", 1.0))  # 只摆一个角色时可以放大看细节
		if _stand:
			r.scale *= 1.45  # 比比例时画大一点，细节看得清
			r.position.y = 640.0
		rigs.append(r)


func _process(delta: float) -> void:
	_t += delta
	if _stand:
		for r in rigs:
			r.play("stand")
		if _frame == 4:
			get_viewport().get_texture().get_image().save_png(_frames_dir + "/stand.png")
			get_tree().quit()
		_frame += 1
		return
	while _step < TIMELINE.size() and _t >= TIMELINE[_step][0]:
		for r in rigs:
			r.play(TIMELINE[_step][1])
		_step += 1
	if TIMELINE[_step - 1][1] in ["walk", "run"]:
		_scroll += delta * rigs[0].walk_speed()
	if _frames_dir != "" and _frame > 1:
		# 屏幕关了、锁屏或窗口被挡住时 macOS 不画窗口，截到的是旧画面；截图前强制画一帧
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_png("%s/%04d.png" % [_frames_dir, _frame])
	_frame += 1
	if _t >= LENGTH:
		get_tree().quit()
	queue_redraw()


func _draw() -> void:
	var size := get_viewport_rect().size
	if _stand:
		# 比比例时铺纯品红底、不画地面和影子，compare.py 好把人物轮廓干净地抠出来
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0, 1))
		return
	if _screen:
		_draw_screen(size)
		_draw_labels(size)
		return
	# 暗调底：上冷下暖的渐变，一条地面线，地上的石缝随走路往后滚
	for y in range(0, int(size.y), 4):
		var u := y / size.y
		draw_rect(Rect2(0, y, size.x, 4), Color(0.10, 0.11, 0.13).lerp(Color(0.20, 0.17, 0.15), u))
	draw_rect(Rect2(0, GROUND, size.x, size.y - GROUND), Color(0.13, 0.11, 0.10))
	draw_line(Vector2(0, GROUND), Vector2(size.x, GROUND), Color(0.32, 0.27, 0.23), 2.0)
	var gap := 90.0
	var x := -fmod(_scroll, gap)
	while x < size.x:
		draw_line(Vector2(x, GROUND + 14), Vector2(x - 26, GROUND + 70), Color(0.2, 0.17, 0.15), 2.0)
		x += gap
	for r in rigs:
		draw_set_transform(Vector2.ZERO)
		var shadow := Rect2(r.position.x - 95, GROUND - 9, 190, 18)
		draw_ellipse_shadow(shadow)
	_draw_labels(size)


func _draw_labels(size: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var ink := Color(0.35, 0.16, 0.07) if _screen else Color(0.85, 0.8, 0.72)
	for i in rigs.size():
		draw_string(font, Vector2(rigs[i].position.x - 40, 40), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ink)
	var act: String = TIMELINE[_step - 1][1]
	var names := {"idle": "待机（呼吸）", "walk": "走路", "run": "跑动", "attack": attack_name}
	draw_string(font, Vector2(20, size.y - 24), "动作：" + names[act], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)


## 皮影戏的幕布：灯在幕后正中，幕布被照得暖黄，越往四边越暗；底下一根木条当台口，影人踩在台口上。
## 影人贴着幕布，没有落在地上的影子。幕布上有几道竖的布纹和随走路往后滚的淡云纹
func _draw_screen(size: Vector2) -> void:
	var lamp := Vector2(size.x * 0.5, size.y * 0.42)
	var reach := size.length() * 0.55
	var step := 6
	for y in range(0, int(size.y), step):
		for x in range(0, int(size.x), step * 4):
			var d := (Vector2(x + step * 2, y) - lamp).length() / reach
			var c := Color(0.96, 0.78, 0.47).lerp(Color(0.55, 0.27, 0.10), clampf(d, 0.0, 1.0))
			c = c.lerp(Color(0.18, 0.07, 0.03), clampf(d - 0.75, 0.0, 1.0) * 1.6)
			draw_rect(Rect2(x, y, step * 4, step), c)
	var x0 := -fmod(_scroll * 0.3, 160.0)
	while x0 < size.x:
		draw_line(Vector2(x0, 0), Vector2(x0, GROUND), Color(0.5, 0.25, 0.08, 0.06), 3.0)
		x0 += 160.0
	draw_rect(Rect2(0, GROUND, size.x, size.y - GROUND), Color(0.16, 0.07, 0.03))
	draw_line(Vector2(0, GROUND), Vector2(size.x, GROUND), Color(0.42, 0.2, 0.07), 3.0)


func draw_ellipse_shadow(r: Rect2) -> void:
	var pts := PackedVector2Array()
	for k in 32:
		var a := k * TAU / 32
		pts.append(r.get_center() + Vector2(cos(a) * r.size.x / 2, sin(a) * r.size.y / 2))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.45))
