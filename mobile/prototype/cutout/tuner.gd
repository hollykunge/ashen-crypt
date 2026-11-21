extends Node2D
## 皮影调参面板：左边实时看角色动，右边拖滑块改参数，满意了点「保存」写回 <角色>/rig.json。
##
##   prototype/cutout/tune.sh            # 调主角
##   prototype/cutout/tune.sh shanxiao   # 调山魈
##
## 外观（部件大小）改了会重建骨骼，动作参数改了立刻生效。「站直对比」把设定图侧面放在旁边、画上 1/16 身高的方格。
## 保存前会把原来的 rig.json 备份成 rig.json.bak（每次打开面板只备份一次）。

const ROOT := "res://prototype/cutout/"
const Rig := preload("res://prototype/cutout/cutout_rig.gd")
const PREVIEW_W := 820.0
const GROUND := 660.0
const ACTIONS := [["run", "跑步"], ["walk", "走路"], ["idle", "待机"], ["attack", "劈砍"], ["stand", "站直对比"]]
## 设定图侧面（只有主角有）：图和第 3 格（严格侧面）的范围
const REF := ["res://art/side/source/hero/turnaround-male.png", Rect2(805, 0, 330, 1024)]

## 滑块表：[分组, 参数路径, 名字, 最小, 最大, 说明]
## 路径用 / 分层；scale 后面跟 /x、/y 的是横竖分开缩放。
const SLIDERS := [
	["外观", "scale", "整体大小", 0.2, 0.6, "整个人在画面里多大，只影响预览和游戏里的显示大小"],
	["外观", "far_tint", "远侧手脚明暗", 0.5, 1.0, "远侧那只手和腿压暗多少；1 是不压暗。压太暗会像两条不同颜色的裤子"],
	["外观", "parts/head/scale", "头", 0.4, 1.2, "头的大小"],
	["外观", "parts/torso/scale", "躯干", 0.6, 1.2, "躯干的大小（肩宽、胸厚、腰高一起变）"],
	["外观", "parts/upper_arm/scale", "上臂", 0.5, 1.2, "上臂的大小"],
	["外观", "parts/forearm/scale/x", "前臂粗细", 0.5, 1.2, "前臂横向缩放"],
	["外观", "parts/forearm/scale/y", "前臂长短", 0.5, 1.2, "前臂竖向缩放"],
	["外观", "parts/hand/scale/x", "手宽", 0.08, 0.4, "握剑手的宽度（四指那一排）"],
	["外观", "parts/hand/scale/y", "手长", 0.05, 0.4, "握剑手从手腕到指节的长度"],
	["外观", "parts/crotch/scale", "裤裆", 0.15, 0.6, "两腿之间那块裤裆的大小；迈大步时腿不再像飘着"],
	["外观", "parts/hand/grip_angle", "剑在手里的斜度", -20.0, 60.0, "手里剑柄的方向：0 是跟垂下的前臂垂直、剑尖朝正前方，越大剑尖越往下"],
	["外观", "parts/weapon/scale", "剑", 0.6, 1.6, "剑的大小"],
	["外观", "parts/thigh/scale", "大腿", 0.6, 1.3, "大腿的大小"],
	["外观", "parts/pelvis/scale/x", "臀胯宽", 0.15, 0.45, "腰带下面那块臀胯的宽度（后面的臀部、前面的胯一起变）"],
	["外观", "parts/pelvis/scale/y", "臀胯高", 0.1, 0.4, "臀胯从腰带到裆的高度；髋关节跟着一起移"],
	["外观", "parts/pelvis/hip/y", "髋关节在臀胯里的高低", 200.0, 600.0, "大腿绕臀胯图里哪一行转（越大越靠下）"],
	["外观", "parts/torso/hip/y", "髋关节位置", 290.0, 450.0, "大腿绕哪儿转（躯干图里的像素，越大越靠下）；真的髋关节在腰带下面一截，绕腰转腿会显得又长又甩"],
	["外观", "parts/thigh/pivot/y", "大腿接点", 30.0, 200.0, "大腿图从哪儿开始算（越大，大腿顶上塞进下摆的越多，露出来的腿越短）；跟髋关节位置一起往下挪，站着的总高度不变"],
	["外观", "parts/shin/scale/x", "小腿和靴子粗细", 0.5, 1.2, "小腿、靴子横向缩放；脚掌长短也跟着变"],
	["外观", "parts/shin/scale/y", "小腿长短", 0.6, 1.3, "小腿竖向缩放"],
	["外观", "parts/skirt_front/scale", "前摆", 0.6, 1.2, "长衣前片的大小"],
	["外观", "parts/skirt_back/scale", "后摆", 0.6, 1.2, "长衣后片的大小"],

	["跑步", "run/period", "一步多快（秒/两步）", 0.4, 1.2, "两步一个周期的秒数，越小跑得越快"],
	["跑步", "run/lean", "上身前倾", 0.0, 40.0, "躯干在腰上前倾的角度"],
	["跑步", "run/head", "头跟着前倾", 0.0, 1.0, "0 是头保持竖直，1 是头跟躯干一样斜"],
	["跑步", "run/reach", "前脚落点", 0.1, 0.6, "前脚落在胯前多远（腿长为单位）"],
	["跑步", "run/push", "后脚蹬多远", 0.2, 0.9, "蹬地的脚伸到胯后多远；比前脚落点大，整个人才是往前斜的"],
	["跑步", "run/kick", "脚跟上踢", 0.0, 0.7, "脚离地后往上踢多高"],
	["跑步", "run/knee", "抬膝", 0.0, 0.7, "腿往前摆时脚抬多高（膝盖跟着提）"],
	["跑步", "run/heel", "后脚踮脚跟", 0.0, 60.0, "蹬地那只脚离地前脚跟抬起的最大角度（脚绕前脚掌转）"],
	["跑步", "run/hip", "胯高", 0.8, 1.0, "胯离地多高；1 是腿完全伸直。越低越像蹲着跑"],
	["跑步", "run/bob", "上下起伏", 0.0, 0.1, "落地压低、腾空升高的幅度"],
	["跑步", "run/duty", "着地时长", 0.2, 0.6, "一只脚踩在地上的时间占比；小于 0.5 才有两脚离地的腾空"],
	["跑步", "run/arm", "空手摆幅", 0.0, 70.0, "远侧空手前后摆的角度"],
	["跑步", "run/elbow", "空手屈肘", 0.0, 130.0, "远侧空手的肘弯多少"],
	["跑步", "run/pump", "往前摆时多屈", 0.0, 40.0, "手往前摆时肘再多弯多少"],
	["跑步", "run/near_arm", "持剑手摆幅比例", 0.0, 1.0, "拿剑的手摆幅占空手的比例"],
	["跑步", "run/near_up", "持剑手上臂", -40.0, 40.0, "拿剑那只手的上臂往前（正）往后（负）"],
	["跑步", "run/near_lo", "持剑手屈肘", 0.0, 120.0, "拿剑那只手的肘弯多少；弯多了剑会翘起来"],
	["跑步", "run/near_blade", "持剑手腕", -15.0, 15.0, "手腕往下压（正）往上翘（负）"],
	["跑步", "run/drag", "下摆后飘", 0.0, 40.0, "跑起来下摆被风往后带的角度"],

	["走路", "walk/period", "一步多快（秒/两步）", 0.6, 1.6, "两步一个周期的秒数"],
	["走路", "walk/lean", "上身前倾", -5.0, 25.0, "躯干前倾的角度"],
	["走路", "walk/head", "头跟着前倾", 0.0, 1.0, "0 是头保持竖直"],
	["走路", "walk/reach", "前脚落点", 0.1, 0.5, "前脚落在胯前多远"],
	["走路", "walk/push", "后脚蹬多远", 0.1, 0.5, "后脚离地时在胯后多远"],
	["走路", "walk/knee", "抬脚", 0.0, 0.3, "迈步时脚抬多高"],
	["走路", "walk/heel", "后脚踮脚跟", 0.0, 50.0, "另一条腿往前迈时，支撑脚脚跟抬起的最大角度（脚绕前脚掌转，离地那一刻最大）"],
	["走路", "walk/heel_from", "何时开始踮", 0.2, 0.95, "从踩地那段的哪儿开始抬脚跟（占踩地时间的比例）；越小抬得越早"],
	["走路", "walk/hip", "胯高", 0.85, 1.0, "胯离地多高；1 是腿完全伸直"],
	["走路", "walk/bob", "上下起伏", 0.0, 0.06, "胯的起伏"],
	["走路", "walk/duty", "着地时长", 0.5, 0.75, "一只脚踩地的时间占比；大于 0.5 有双脚着地"],
	["走路", "walk/arm", "空手摆幅", 0.0, 45.0, "远侧空手前后摆的角度"],
	["走路", "walk/elbow", "空手屈肘", 0.0, 60.0, "远侧空手的肘弯多少"],
	["走路", "walk/near_arm", "持剑手摆幅比例", 0.0, 1.0, "拿剑的手摆幅占空手的比例"],
	["走路", "walk/near_up", "持剑手上臂", -30.0, 30.0, "拿剑那只手的上臂往前（正）往后（负）"],
	["走路", "walk/near_lo", "持剑手屈肘", 0.0, 90.0, "拿剑那只手的肘弯多少"],
	["走路", "walk/near_blade", "持剑手腕", -15.0, 15.0, "手腕往下压（正）往上翘（负）"],

	["待机", "idle/torso", "上身前倾", -10.0, 20.0, "站着时躯干前倾的角度"],
	["待机", "idle/neck", "低头", -20.0, 20.0, "正值低头、负值抬头"],
	["待机", "idle/hip", "胯高", 0.85, 1.0, "1 是腿伸直站"],
	["待机", "idle/foot_near_x", "前脚位置", -0.2, 0.4, "近侧脚在胯前多远"],
	["待机", "idle/foot_far_x", "后脚位置", -0.4, 0.2, "远侧脚在胯前多远（负值在后）"],
	["待机", "idle/arm_near_up", "持剑手上臂", -30.0, 60.0, "拿剑那只手的上臂往前（正）往后（负）"],
	["待机", "idle/arm_near_lo", "持剑手屈肘", 0.0, 120.0, "拿剑那只手的肘弯多少"],
	["待机", "idle/blade", "持剑手腕", -15.0, 15.0, "手腕往下压（正）往上翘（负）"],
	["待机", "idle/arm_far_up", "空手上臂", -30.0, 40.0, "远侧空手的上臂"],
	["待机", "idle/arm_far_lo", "空手屈肘", 0.0, 90.0, "远侧空手的肘弯多少"],
]

var who := "hero"
var cfg: Dictionary
var outfits: Array = []
var outfit_i := 0
var action := "run"
var rig: Node2D
var save_path := ""
var _backed_up := false
var _rebuild_in := -1.0
var _attack_t := 0.0
var _scroll := 0.0
var _rows := {}  # 路径 -> [HSlider, 数值 Label]
var _status: Label
var _ref_tex: Texture2D
var _ref_fig := Rect2()  # 设定图里人物占的范围（在 REF 那一格里的坐标）
var _selftest := ""
var _act_pick: OptionButton
var _font: Font
var labels: Array = []


func _ready() -> void:
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().size = Vector2i(1380, 820)
	get_window().title = "皮影调参"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		who = args[0]
	if args.size() > 2 and args[1] == "selftest":
		_selftest = args[2]
	save_path = ProjectSettings.globalize_path(ROOT + who + "/rig.json")
	cfg = JSON.parse_string(FileAccess.get_file_as_string(ROOT + who + "/rig.json"))
	var demo: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + who + "/demo.json"))
	outfits = demo.outfits
	labels = demo.get("labels", outfits)
	# Godot 自带字体缺不少汉字（「远」「蹬」会变方框），用游戏自己的中文字体
	_font = load("res://art/fonts/game.otf")
	_load_ref()
	_build_ui()
	_rebuild()
	if _selftest != "":
		_run_selftest()


# ---------- 参数读写 ----------

func _defaults(group: String) -> Dictionary:
	match group:
		"run":
			return Rig.RUN
		"walk":
			return Rig.WALK
		"idle":
			return Rig.IDLE
	return {}


func _get_value(path: String) -> float:
	var keys := path.split("/")
	if keys[0] in ["run", "walk", "idle"]:
		var d: Dictionary = cfg.get(keys[0], {})
		var key := keys[1]
		if d.has(key):
			return float(d[key])
		var g := _defaults(keys[0]).duplicate()
		g.merge(d, true)
		match key:
			"reach", "push":
				return float(g.get("stride", 0.5)) * 0.5
			"knee":
				return float(g.get("lift", 0.1))
			"kick":
				return float(g.get("lift", 0.1)) * 0.4
			"heel_from":
				return float(g.get("reach", g.get("stride", 0.5) * 0.5)) / (float(g.get("reach", g.get("stride", 0.5) * 0.5)) + float(g.get("push", g.get("stride", 0.5) * 0.5)))
		return float(g.get(key, 0.0))
	if keys[0] == "parts":
		var p: Dictionary = cfg.parts.get(keys[1], {})
		var v = p.get(keys[2], 1.0 if keys[2] == "scale" else 0.0)
		if keys.size() > 3:
			if v is Array:
				return float(v[0 if keys[3] == "x" else 1])
			return float(v)
		if v is Array:
			return float(v[0])
		return float(v)
	if path == "far_tint":
		return float(cfg.get("far_tint", Rig.FAR_TINT))
	return float(cfg.get(path, 1.0))


func _set_value(path: String, value: float) -> void:
	value = snappedf(value, 0.001)
	var keys := path.split("/")
	if keys[0] in ["run", "walk", "idle"]:
		if not cfg.has(keys[0]):
			cfg[keys[0]] = {}
		cfg[keys[0]][keys[1]] = value
		rig.reload_params(cfg)
	elif keys[0] == "parts":
		var p: Dictionary = cfg.parts[keys[1]]
		if keys.size() > 3:
			var cur = p.get(keys[2], 1.0)
			var pair: Array = cur if cur is Array else [cur, cur]
			pair = pair.duplicate()
			pair[0 if keys[3] == "x" else 1] = value
			p[keys[2]] = pair
		else:
			p[keys[2]] = value
		_rebuild_in = 0.15  # 部件大小一变就要重建骨骼；拖动时等手停一下再建
	else:
		cfg[path] = value
		if path == "scale":
			_rebuild_in = 0.15
		else:
			rig.reload_params(cfg)
	if _rows.has(path):
		_rows[path][1].text = _fmt(value)
	_status.text = "有改动，还没保存"


func _fmt(v: float) -> String:
	return ("%.0f" % v) if absf(v) >= 10.0 else ("%.2f" % v)


func _save() -> void:
	if not _backed_up and FileAccess.file_exists(save_path) and _selftest == "":
		var old := FileAccess.get_file_as_string(save_path)
		var bak := FileAccess.open(save_path + ".bak", FileAccess.WRITE)
		bak.store_string(old)
		bak.close()
		_backed_up = true
	# 只写滑块管的那几个数：先读硬盘上现在的 rig.json，再把每个滑块的值写进对应位置，其余一概不碰。
	# 面板打开以后别处改过的东西（新部件、关节点）不会被面板里的旧值盖回去
	var disk = JSON.parse_string(FileAccess.get_file_as_string(save_path)) if FileAccess.file_exists(save_path) else {}
	if not disk is Dictionary:
		disk = {}
	for path in _rows:
		_put(disk, path, _get_value(path))
	if cfg.has("attack"):
		disk["attack"] = cfg.attack.duplicate(true)  # 劈砍关键帧整段归面板管
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(disk, " ", false))
	f.close()
	_status.text = "已保存 %s" % Time.get_time_string_from_system()


## 把一个滑块的值写进 d（路径规则同 _set_value）
func _put(d: Dictionary, path: String, value: float) -> void:
	var keys := path.split("/")
	if keys[0] in ["run", "walk", "idle"]:
		if not d.has(keys[0]):
			d[keys[0]] = {}
		d[keys[0]][keys[1]] = value
	elif keys[0] == "parts":
		if not d.has("parts") or not d.parts.has(keys[1]):
			return
		var p: Dictionary = d.parts[keys[1]]
		if keys.size() > 3:
			var cur = p.get(keys[2], 1.0)
			var pair: Array = (cur if cur is Array else [cur, cur]).duplicate()
			pair[0 if keys[3] == "x" else 1] = value
			p[keys[2]] = pair
		else:
			p[keys[2]] = value
	else:
		d[path] = value


func _revert() -> void:
	cfg = JSON.parse_string(FileAccess.get_file_as_string(ROOT + who + "/rig.json"))
	for path in _rows:
		_rows[path][0].set_value_no_signal(_get_value(path))
		_rows[path][1].text = _fmt(_get_value(path))
	_rebuild()
	_status.text = "已撤销到上次保存的样子"


# ---------- 预览 ----------

func _rebuild() -> void:
	if rig:
		rig.queue_free()
	rig = Rig.new()
	add_child(rig)
	rig.setup_dict(cfg.duplicate(true), Rig.resolve_outfit(ROOT + who + "/", _current_outfit()))
	rig.reload_params(cfg)  # 之后滑块直接改 cfg，骨骼跟着读
	rig.scale *= 1.3
	rig.position = Vector2(PREVIEW_W * 0.42, GROUND)
	rig.play(action)
	rig.freeze_t = _freeze_time()


func _process(delta: float) -> void:
	if _rebuild_in >= 0.0:
		_rebuild_in -= delta
		if _rebuild_in < 0.0:
			_rebuild()
	if action == "attack" and rig.freeze_t < 0.0:
		_attack_t += delta
		if _attack_t > 1.7:
			_attack_t = 0.0
			rig.play("idle")
			rig.play("attack")
	if action in ["walk", "run"]:
		_scroll += delta * rig.walk_speed()
	queue_redraw()


func _figure_top() -> float:
	var top := INF
	for part in rig._sprites:
		for s in rig._sprites[part]:
			if not s.is_visible_in_tree() or s.texture == null:
				continue
			var r: Rect2 = s.get_rect()
			for c in [r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]:
				top = minf(top, (s.global_transform * c).y)
	return top


func _draw() -> void:
	for y in range(0, 820, 4):
		var u := y / 820.0
		draw_rect(Rect2(0, y, PREVIEW_W, 4), Color(0.10, 0.11, 0.13).lerp(Color(0.20, 0.17, 0.15), u))
	draw_rect(Rect2(0, GROUND, PREVIEW_W, 820 - GROUND), Color(0.13, 0.11, 0.10))
	draw_line(Vector2(0, GROUND), Vector2(PREVIEW_W, GROUND), Color(0.32, 0.27, 0.23), 2.0)
	var x := -fmod(_scroll, 90.0)
	while x < PREVIEW_W:
		draw_line(Vector2(x, GROUND + 14), Vector2(x - 26, GROUND + 70), Color(0.2, 0.17, 0.15), 2.0)
		x += 90.0
	if not rig:
		return
	var c := rig.position.x
	var pts := PackedVector2Array()
	for k in 32:
		var a := k * TAU / 32
		pts.append(Vector2(c + cos(a) * 110, GROUND + sin(a) * 10))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.45))
	if action == "stand":
		_draw_compare()


## 站直对比：设定图侧面缩放到跟预览里的人一样高，摆在右边；画 1/16 身高的方格
func _draw_compare() -> void:
	var top := _figure_top()
	var h := GROUND - top
	if h < 10.0:
		return
	if _ref_tex and _ref_fig.size.y > 0:
		var k := h / _ref_fig.size.y
		var dest := Rect2(PREVIEW_W * 0.68, top, _ref_fig.size.x * k, h)
		var src := Rect2(REF[1].position + _ref_fig.position, _ref_fig.size)
		draw_texture_rect_region(_ref_tex, dest, src)
	for i in 17:
		var y := GROUND - h * i / 16.0
		draw_line(Vector2(0, y), Vector2(PREVIEW_W, y), Color(0.35, 0.6, 0.85, 0.55 if i % 2 == 0 else 0.25), 1.0)
		if i % 2 == 0:
			draw_string(_font, Vector2(6, y - 3), "%d/8" % (i / 2), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.5, 0.7, 0.9))


func _load_ref() -> void:
	if who != "hero" or not FileAccess.file_exists(REF[0]):
		return
	var img := Image.load_from_file(REF[0])
	_ref_tex = ImageTexture.create_from_image(img)
	var area: Rect2 = REF[1]
	var bg := img.get_pixel(int(area.end.x) - 3, 3)
	var x0 := INF
	var x1 := -INF
	var y0 := INF
	var y1 := -INF
	for y in range(int(area.position.y), int(area.end.y), 2):
		for xx in range(int(area.position.x), int(area.end.x), 2):
			var p := img.get_pixel(xx, y)
			if absf(p.r - bg.r) + absf(p.g - bg.g) + absf(p.b - bg.b) > 0.25:
				x0 = minf(x0, xx)
				x1 = maxf(x1, xx)
				y0 = minf(y0, y)
				y1 = maxf(y1, y)
	if y1 > y0:
		_ref_fig = Rect2(Vector2(x0, y0) - area.position, Vector2(x1 - x0, y1 - y0))


# ---------- 界面 ----------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var theme := Theme.new()
	theme.default_font = _font
	theme.default_font_size = 15
	var panel := PanelContainer.new()
	panel.theme = theme
	panel.position = Vector2(PREVIEW_W, 0)
	panel.size = Vector2(1380 - PREVIEW_W, 820)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)

	var top := HBoxContainer.new()
	box.add_child(top)
	var act := OptionButton.new()
	_act_pick = act
	for a in ACTIONS:
		act.add_item(a[1])
	act.selected = 0
	act.item_selected.connect(func(i):
		action = ACTIONS[i][0]
		_attack_t = 0.0
		rig.play(action))
	top.add_child(act)
	if cfg.has("slots"):
		_build_slot_pickers(box)
	else:
		var out := OptionButton.new()
		for o in labels:
			out.add_item(o)
		out.item_selected.connect(func(i):
			outfit_i = i
			_rebuild())
		top.add_child(out)
	var save := Button.new()
	save.text = "保存"
	save.pressed.connect(_save)
	top.add_child(save)
	var revert := Button.new()
	revert.text = "撤销改动"
	revert.pressed.connect(_revert)
	top.add_child(revert)

	var speed := HBoxContainer.new()
	box.add_child(speed)
	var sl := Label.new()
	sl.text = "播放速度"
	speed.add_child(sl)
	var ss := HSlider.new()
	ss.min_value = 0.1
	ss.max_value = 1.5
	ss.step = 0.05
	ss.value = 1.0
	ss.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ss.value_changed.connect(func(v): Engine.time_scale = v)
	speed.add_child(ss)

	_status = Label.new()
	_status.text = "拖滑块实时看；鼠标停在名字上有说明"
	box.add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var groups := {}
	for row in SLIDERS:
		var path: String = row[1]
		if path.begins_with("parts/") and not cfg.parts.has(path.split("/")[1]):
			continue
		if path.begins_with("parts/hand/grip_angle") and not cfg.parts.has("hand"):
			continue
		var group: String = row[0]
		if not groups.has(group):
			var head := Button.new()
			head.text = "▼ " + group
			head.alignment = HORIZONTAL_ALIGNMENT_LEFT
			list.add_child(head)
			var g := VBoxContainer.new()
			list.add_child(g)
			groups[group] = g
			head.pressed.connect(func():
				g.visible = not g.visible
				head.text = ("▼ " if g.visible else "▶ ") + group)
		var line := HBoxContainer.new()
		groups[group].add_child(line)
		var name := Label.new()
		name.text = row[2]
		name.tooltip_text = row[5]
		name.mouse_filter = Control.MOUSE_FILTER_PASS
		name.custom_minimum_size = Vector2(150, 0)
		line.add_child(name)
		var s := HSlider.new()
		s.min_value = row[3]
		s.max_value = row[4]
		s.step = 0.001 if float(row[4]) - float(row[3]) <= 2.0 else 0.5
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.tooltip_text = row[5]
		s.value = _get_value(path)
		line.add_child(s)
		var val := Label.new()
		val.text = _fmt(_get_value(path))
		val.custom_minimum_size = Vector2(52, 0)
		line.add_child(val)
		s.value_changed.connect(func(v): _set_value(path, v))
		_rows[path] = [s, val]
	if cfg.has("attack"):
		_build_attack_ui(list)


## 按装备槽选：每个槽一个下拉框，选项是 demo.json 里的整套（目录名），可以随便混搭
const SLOT_NAMES := {"armor": "护甲", "pants": "裤子", "gloves": "护手", "boots": "鞋子"}
var _equip := {}


func _build_slot_pickers(box: VBoxContainer) -> void:
	var sets := []
	for i in outfits.size():
		if outfits[i] is String:
			sets.append([outfits[i], labels[i]])
	var row := HBoxContainer.new()
	box.add_child(row)
	for slot in cfg.slots:
		var l := Label.new()
		l.text = SLOT_NAMES.get(slot, slot)
		row.add_child(l)
		var pick := OptionButton.new()
		for s in sets:
			pick.add_item(s[1])
		_equip[slot] = sets[0][0]
		pick.item_selected.connect(func(i):
			_equip[slot] = sets[i][0]
			_rebuild())
		row.add_child(pick)


func _current_outfit():
	if _equip.is_empty():
		return outfits[outfit_i]
	return _equip


# ---------- 劈砍关键帧 ----------
## 能调的关键帧：[在 attack 里的序号, 名字]。「打中」后面那一帧是停顿，跟「打中」同一个姿势，改「打中」时一起改
const ATTACK_KEYS := [[1, "起手"], [2, "挥下（半路）"], [3, "打中"], [5, "收势"]]
## 每帧能调的关节：[键, 名字, 最小, 最大, 说明]
const ATTACK_FIELDS := [
	["torso", "上身前倾", -30.0, 40.0, "负值往后仰（起手开胸），正值往前压（劈下去）"],
	["neck", "低头", -30.0, 30.0, "正值低头、负值抬头（在上身前倾的基础上）"],
	["arm_near_up", "持剑手上臂", -60.0, 200.0, "上臂往前抬多少度：0 垂下，90 平举向前，180 举过头顶"],
	["arm_near_lo", "持剑手屈肘", 0.0, 140.0, "肘弯多少度"],
	["blade", "手腕（正值往下压）", -40.0, 40.0, "手腕转多少，带着剑一起转；劈砍时最多 attack_wrist 度"],
	["arm_far_up", "空手上臂", -60.0, 120.0, "空手往前抬多少度；起手前指对手、打中时往后拉"],
	["arm_far_lo", "空手屈肘", 0.0, 140.0, "空手肘弯多少度"],
	["dx", "重心前后", -0.3, 0.4, "胯往前（正）往后（负）挪多少，腿长为单位"],
	["hip", "胯高", 0.75, 1.0, "髋关节离地多高，1 是腿伸直；太低就是蹲着砍"],
	["step", "前脚迈出", 0.0, 0.6, "前脚往前迈多远（后脚钉在原地）"],
]
var _key_i := 0
var _attack_rows := {}
var _time_slider: HSlider
var _time_val: Label
var _sword_label: Label
var _freeze: CheckBox


func _freeze_time() -> float:
	if _freeze == null or not _freeze.button_pressed:
		return -1.0
	return float(cfg.attack[ATTACK_KEYS[_key_i][0]][0])


func _build_attack_ui(list: VBoxContainer) -> void:
	var head := Button.new()
	head.text = "▼ 劈砍关键帧"
	head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	list.add_child(head)
	var g := VBoxContainer.new()
	list.add_child(g)
	head.pressed.connect(func():
		g.visible = not g.visible
		head.text = ("▼ " if g.visible else "▶ ") + "劈砍关键帧")
	var row := HBoxContainer.new()
	g.add_child(row)
	var pick := OptionButton.new()
	for k in ATTACK_KEYS:
		pick.add_item(k[1])
	pick.item_selected.connect(func(i):
		_key_i = i
		_load_attack_key())
	row.add_child(pick)
	_freeze = CheckBox.new()
	_freeze.text = "定格在这一帧"
	_freeze.toggled.connect(func(on):
		if rig == null:
			return
		if on:
			_show_attack()
		rig.freeze_t = _freeze_time())
	row.add_child(_freeze)
	_sword_label = Label.new()
	g.add_child(_sword_label)
	var tl := HBoxContainer.new()
	g.add_child(tl)
	var tn := Label.new()
	tn.text = "这一帧在第几秒"
	tn.custom_minimum_size = Vector2(150, 0)
	tl.add_child(tn)
	_time_slider = HSlider.new()
	_time_slider.step = 0.01
	_time_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_time_slider.value_changed.connect(_set_key_time)
	tl.add_child(_time_slider)
	_time_val = Label.new()
	_time_val.custom_minimum_size = Vector2(52, 0)
	tl.add_child(_time_val)
	for f in ATTACK_FIELDS:
		var line := HBoxContainer.new()
		g.add_child(line)
		var name := Label.new()
		name.text = f[1]
		name.tooltip_text = f[4]
		name.mouse_filter = Control.MOUSE_FILTER_PASS
		name.custom_minimum_size = Vector2(150, 0)
		line.add_child(name)
		var s := HSlider.new()
		s.min_value = f[2]
		s.max_value = f[3]
		s.step = 0.005 if float(f[3]) - float(f[2]) <= 2.0 else 0.5
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.tooltip_text = f[4]
		line.add_child(s)
		var val := Label.new()
		val.custom_minimum_size = Vector2(52, 0)
		line.add_child(val)
		var key: String = f[0]
		s.value_changed.connect(func(v): _set_attack_field(key, v))
		_attack_rows[key] = [s, val]
	_load_attack_key()


## 某帧某个关节的值：这一帧没写的就是待机姿势里的值
func _attack_value(idx: int, key: String) -> float:
	var d: Dictionary = cfg.attack[idx][1]
	if d.has(key):
		return float(d[key])
	if key == "step":
		return 0.0
	return _get_value("idle/" + key) if ("idle/" + key) in _rows else float(Rig.IDLE.get(key, 0.0))


func _load_attack_key() -> void:
	var idx: int = ATTACK_KEYS[_key_i][0]
	var keys: Array = cfg.attack
	var lo: float = keys[idx - 1][0] + 0.02
	var hi: float = keys[idx + 1][0] - 0.02 if idx + 1 < keys.size() else 2.0
	if idx == 3:
		hi = keys[5][0] - 0.04  # 「打中」不能越过「收势」；停顿那一帧跟着挪
	# 改上下限时滑块会自动夹值并触发回调，把别的帧的时间写进这一帧；先屏蔽回调
	_time_slider.set_block_signals(true)
	_time_slider.min_value = lo
	_time_slider.max_value = hi
	_time_slider.value = keys[idx][0]
	_time_slider.set_block_signals(false)
	_time_val.text = "%.2f" % keys[idx][0]
	for f in ATTACK_FIELDS:
		var v := _attack_value(idx, f[0])
		_attack_rows[f[0]][0].set_value_no_signal(v)
		_attack_rows[f[0]][1].text = _fmt(v)
	_update_sword_label()
	if rig:
		rig.freeze_t = _freeze_time()


func _set_attack_field(key: String, v: float) -> void:
	if rig == null:
		return
	v = snappedf(v, 0.001)
	var idx: int = ATTACK_KEYS[_key_i][0]
	cfg.attack[idx][1][key] = v
	if idx == 3:
		cfg.attack[4][1][key] = v  # 停顿那一帧跟「打中」同一个姿势
	_attack_rows[key][1].text = _fmt(v)
	rig.reload_params(cfg)
	_update_sword_label()
	_show_attack()
	_status.text = "有改动，还没保存"


func _set_key_time(v: float) -> void:
	if rig == null:
		return  # 搭界面时设滑块范围也会触发这里，那时骨骼还没建
	var idx: int = ATTACK_KEYS[_key_i][0]
	var hold: float = cfg.attack[4][0] - cfg.attack[3][0]
	cfg.attack[idx][0] = snappedf(v, 0.01)
	if idx == 3:
		cfg.attack[4][0] = snappedf(v + hold, 0.01)
	_time_val.text = "%.2f" % v
	rig.reload_params(cfg)
	rig.freeze_t = _freeze_time()
	_status.text = "有改动，还没保存"


## 改劈砍参数时自动切到劈砍动作，看得到效果
func _show_attack() -> void:
	if action != "attack":
		action = "attack"
		_act_pick.select(3)
		_attack_t = 0.0
		rig.play("attack")


## 这一帧剑在画面里朝哪：0 朝正前、正数剑尖往下、-90 朝上
func _update_sword_label() -> void:
	var idx: int = ATTACK_KEYS[_key_i][0]
	var lim: float = cfg.get("attack_wrist", 15.0)
	var blade := clampf(_attack_value(idx, "blade"), -lim, lim)
	var a := deg_to_rad(float(cfg.parts.hand.get("grip_angle", 0.0))) if cfg.parts.has("hand") else 0.0
	var hs = cfg.parts.hand.get("scale", 1.0) if cfg.parts.has("hand") else 1.0
	var kx: float = hs[0] if hs is Array else hs
	var ky: float = hs[1] if hs is Array else hs
	var grip := rad_to_deg(atan2(sin(a) * ky, cos(a) * kx))
	var ang := -(_attack_value(idx, "arm_near_up") + _attack_value(idx, "arm_near_lo")) + blade + grip
	ang = wrapf(ang, -180.0, 180.0)
	var words := "朝前" if absf(ang) < 20 else ("朝前下" if ang > 0 and ang < 70 else ("朝下" if ang >= 70 and ang <= 110 else ("朝后下" if ang > 110 else ("朝前上" if ang > -70 else ("朝上" if ang >= -110 else "朝后上")))))
	_sword_label.text = "这一帧剑尖：%s（%.0f°）" % [words, ang]


# ---------- 自测：改几个滑块、截图、保存到测试文件，确认面板能用 ----------

func _run_selftest() -> void:
	save_path = _selftest + "/rig-test.json"
	await _frames(40)
	_shot("1-run.png")
	_rows["run/lean"][0].value = 20.0
	_rows["parts/hand/scale/y"][0].value = 0.2
	await _frames(40)
	_shot("2-changed.png")
	action = "stand"
	rig.play("stand")
	await _frames(30)
	_shot("3-stand.png")
	if cfg.has("attack"):
		_freeze.button_pressed = true
		_key_i = 2
		_load_attack_key()
		_attack_rows["torso"][0].value = 25.0
		await _frames(20)
		_shot("4-attack-freeze.png")
	_save()
	print("自测完成：", _status.text)
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(_selftest + "/" + name)
