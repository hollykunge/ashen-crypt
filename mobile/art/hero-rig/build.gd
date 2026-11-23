extends SceneTree
## 从一张基准原画切出整套拆件，所有部件共用同一张画布、同一个缩放。用法和原理见同目录 README.md。
##
##   godot --headless --path mobile --script res://art/hero-rig/build.gd -- <套装名>
##
## source/<套装>/master.png   全身侧面基准姿势（白底）
## source/<套装>/armless.png  同一张图去掉手臂，躯干补完整
## source/<套装>/arm.png      同一张图只留手臂
## source/<套装>/fist.png     （可选）只把手换成握拳
## source/<套装>/cut.json     （衣装）腰带上下沿、鞋口：切口沿画好的边走
## source/joints.json         关节中心（基准 master 的像素坐标），所有套装共用
##
## 做法：
## 1. 去白底；衣装原画对回基准图；armless、arm 对回 master。
## 2. 头、躯干、臀胯、腿取自 armless；上臂、前臂、手取自 arm。
## 3. 在每个关节处沿骨骼的垂线切开。压在前面的那件沿画好的边切（短裤腰头、腰带、鞋口），
##    垫在后面的那件带以关节为圆心的圆头；没有现成的边（光身的肘、膝、踝）两边都带圆头。
##    转到任何角度都互相盖住，不露缝。
## 4. 手臂整体绕肩转正，让上臂竖直向下，动作参数里 0 度就是自然下垂。
## 5. 写出 parts/<套装>/*.png；base 时把量出的接点和 source/motion.json 合成 rig.json。

## 第二个参数可以换一套人物目录（比如 res://art/hero-rig-34/），默认是现在用的这套
var ROOT := "res://art/hero-rig/"
const PAD := 4
const MARGIN := 80

var W := 0
var H := 0
var _joints := {}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var outfit: String = args[0] if args.size() > 0 else "base"
	if args.size() > 1:
		ROOT = args[1].trim_suffix("/") + "/"
	var src := ProjectSettings.globalize_path(ROOT + "source/" + outfit + "/")
	var joints: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "source/joints.json"))
	_joints = joints
	var master := _key_white(Image.load_from_file(src + "master.png"))
	var armless := _key_white(Image.load_from_file(src + "armless.png"))
	W = master.get_width()
	H = master.get_height()
	if outfit != "base":
		# 衣装原画是在基准图上改的，可能整体挪了几像素：按头和小腿对回基准图
		var base_master := _key_white(Image.load_from_file(ProjectSettings.globalize_path(ROOT + "source/base/master.png")))
		var s0 := _register(base_master, master, joints)
		print("衣装对齐偏移 ", s0)
		master = _translated(master, s0)
	if armless.get_size() != master.get_size():
		armless.resize(W, H, Image.INTERPOLATE_LANCZOS)
	var shift := _register(master, armless, joints)
	print("armless 对齐偏移 ", shift)
	armless = _translated(armless, shift)
	# 3/4 侧身时远侧腿露在近侧腿旁边：另出一张去掉远侧腿的（solo.png），腿和臀胯从它切
	var legs := armless
	if FileAccess.file_exists(src + "solo.png"):
		legs = _key_white(Image.load_from_file(src + "solo.png"))
		if legs.get_size() != master.get_size():
			legs.resize(W, H, Image.INTERPOLATE_LANCZOS)
		legs = _translated(legs, _register(master, legs, joints))
	# 手臂单独出一张（只留手臂、其余擦白），按颜色对准 master
	var arm := _key_white(Image.load_from_file(src + "arm.png"))
	if arm.get_size() != master.get_size():
		arm.resize(W, H, Image.INTERPOLATE_LANCZOS)
	# 衣装的手臂对准基准手臂（空手、肤色部分完全一样），基准手臂对准基准原画
	var arm_ref := master
	if outfit != "base":
		arm_ref = _key_white(Image.load_from_file(ProjectSettings.globalize_path(ROOT + "source/base/arm.png")))
		arm_ref = _translated(arm_ref, _register_color(_key_white(Image.load_from_file(ProjectSettings.globalize_path(ROOT + "source/base/master.png"))), arm_ref))
	var arm_shift := _register_color(arm_ref, arm)
	print("手臂对齐偏移 ", arm_shift)
	arm = _translated(arm, arm_shift)
	arm = _only_component(arm, joints.elbow)
	var j := {}
	for k in joints:
		if joints[k] is Array:
			j[k] = Vector2(joints[k][0], joints[k][1])
	# 手臂绕肩转正：上臂竖直向下
	var arm_turn: float = (j.elbow - j.shoulder).angle() - PI / 2.0
	arm = _rotated(arm, j.shoulder, -arm_turn)
	for k in ["elbow", "wrist", "knuckle"]:
		if j.has(k):
			j[k] = j.shoulder + (j[k] - j.shoulder).rotated(-arm_turn)
	print("手臂转正 ", rad_to_deg(arm_turn), " 度")
	var r := {}
	r.neck = _half_width(armless, j.neck, Vector2.UP)
	r.waist = _half_width(armless, j.waist, Vector2.UP)
	r.hip = _half_width(legs, j.hip, Vector2.UP)
	r.knee = _half_width(legs, j.knee, (j.ankle - j.knee))
	r.ankle = _half_width(legs, j.ankle, (j.ankle - j.knee))
	r.elbow = _half_width(arm, j.elbow, j.elbow - j.shoulder)
	r.wrist = _half_width(arm, j.wrist, j.wrist - j.elbow)
	for k in r:
		r[k] = r[k] * float(joints.get("cap", {}).get(k, 1.0))
		if joints.get("cap_px", {}).has(k):
			r[k] = float(joints.cap_px[k])
	print("圆头半径 ", r)
	var up := Vector2.UP
	var leg_axis: Vector2 = (j.ankle - j.knee).normalized()
	var thigh_axis: Vector2 = (j.knee - j.hip).normalized()
	var arm_axis := Vector2.DOWN
	# 脚踝切在跟腱和脚背折角那一条（最窄处），不是踝骨中心：圆头才盖得住整条切口
	var ankle_line: Vector2 = Vector2(j.ankle.x, float(joints.get("ankle_line_y", j.ankle.y)))
	# 每件：取自哪张、在哪些切线的哪一侧、带哪些圆头
	var pieces := {
		"head": [armless, [[j.neck, up, true]], [[j.neck, r.neck]]],
		# 腰：臀胯压在躯干上面，上沿就是短裤腰头（画好的边），躯干往下多伸一截垫在腰头底下
		# 腰：臀胯（短裤）压在躯干上面，上沿就是画好的腰头边（按颜色分出短裤）；
		# 躯干往下多伸一截垫在腰头底下，这一截的短裤颜色换成上方的肤色
		"torso": [_skin_under(armless, int(joints.waistband) - 12), [[j.neck, up, false], [Vector2(0, joints.torso_under), up, true]], [[j.waist, r.waist]]],
		"pelvis": [_cloth_only(legs, int(joints.waistband) - 12), [[j.hip, up, true]], [[j.hip, r.hip]]],
		# 裆：一块只有髋部圆头的短裤，垫在两条大腿后面，迈大步时两腿之间不露空
		"crotch": [legs, [], [[j.hip, r.hip]]],
		"thigh": [legs, [[j.hip, up, false], [j.knee, -thigh_axis, true]], [[j.hip, r.hip], [j.knee, r.knee]]],
		"shin": [legs, [[j.knee, -thigh_axis, false], [ankle_line, -leg_axis, true]], [[j.knee, r.knee], [j.ankle, r.ankle]]],
		"foot": [legs, [[ankle_line, -leg_axis, false]], [[j.ankle, r.ankle]]],
		"upper_arm": [arm, [[j.elbow, -arm_axis, true]], [[j.elbow, r.elbow]]],
		"forearm": [arm, [[j.elbow, -arm_axis, false], [j.wrist, -arm_axis, true]], [[j.elbow, r.elbow], [j.wrist, r.wrist]]],
		"hand": [arm, [[j.wrist, -arm_axis, false]], [[j.wrist, r.wrist]]],
	}
	# 衣装的腰：腰带下沿是画好的边，躯干（连腰带）压在下摆上面、不带圆头；
	# 下摆那一件从腰带上沿以下开始，垫在腰带底下，带腰部圆头盖住转动时的缝
	var cut_cfg: Dictionary = {}
	if FileAccess.file_exists(src + "cut.json"):
		cut_cfg = JSON.parse_string(FileAccess.get_file_as_string(src + "cut.json"))
	if cut_cfg.has("belt_top"):
		var bottom := _line(cut_cfg.belt_bottom)
		var top := _line(cut_cfg.belt_top)
		pieces.torso = [armless, [[j.neck, up, false], [bottom[0], bottom[1], true]], []]
		pieces.pelvis = [legs, [[top[0], top[1], false], [j.hip, up, true]], [[j.waist, r.waist], [j.hip, r.hip]]]
	# 裙甲：大腿和裆那两件里，裙甲下沿以上换成裤子的颜色
	if cut_cfg.has("skirt_hem"):
		var trousers := _extrude_below(legs, int(cut_cfg.skirt_hem))
		pieces.thigh[0] = trousers
		pieces.crotch[0] = trousers
		# 臀胯那件一直切到裙甲下沿，不按髋关节切，裙甲两角才完整
		var hem := Vector2(0, float(cut_cfg.skirt_hem) + 4.0)
		pieces.pelvis[1] = [pieces.pelvis[1][0], [hem, up, true]]
	# 鞋：鞋口是画好的边，脚那件从鞋口切、压在小腿上面不带圆头；小腿往下多伸一截垫在鞋口底下。
	# 这样混搭时，别套的护腿下沿不会跟着鞋子出现
	if cut_cfg.has("shoe_top"):
		var shoe := _line(cut_cfg.shoe_top)
		var under: Vector2 = shoe[0] - shoe[1] * 14.0
		pieces.shin = [legs, [[j.knee, -thigh_axis, false], [under, shoe[1], true]], [[j.knee, r.knee]]]
		pieces.foot = [legs, [[shoe[0], shoe[1], false]], []]
	# 领口：衣领上沿是画好的边。头那件切到领口以下一截（垫在衣领底下），躯干从领口切、压在头上面。
	# 按水平线切脖子时，3/4 侧身的胡子尖会落到躯干里，抬头时分出去一截
	if cut_cfg.has("collar"):
		var collar := _line(cut_cfg.collar)
		pieces.head = [armless, [[collar[0] - collar[1] * 22.0, collar[1], true]], []]
		pieces.torso[1][0] = [collar[0], collar[1], false]
	# 握刀的拳头：同一条手臂只把手换成握拳的那张，切法和空手一样
	if FileAccess.file_exists(src + "fist.png"):
		var fist := _key_white(Image.load_from_file(src + "fist.png"))
		if fist.get_size() != master.get_size():
			fist.resize(W, H, Image.INTERPOLATE_LANCZOS)
		fist = _translated(fist, _register_color(master, fist))
		fist = _only_component(fist, joints.elbow)
		fist = _rotated(fist, j.shoulder, -arm_turn)
		fist = _clear_enclosed_white(fist)
		pieces["grip_hand"] = [fist, [[j.wrist, -arm_axis, false]], [[j.wrist, r.wrist]]]
	# 远侧（内侧）手：自然半握的空手，走路、备战时不像一块平板。只在基准套装出，衣装不换手
	if FileAccess.file_exists(src + "relaxed.png"):
		var relaxed := _key_white(Image.load_from_file(src + "relaxed.png"))
		if relaxed.get_size() != master.get_size():
			relaxed.resize(W, H, Image.INTERPOLATE_LANCZOS)
		relaxed = _translated(relaxed, _register_color(master, relaxed))
		relaxed = _only_component(relaxed, joints.elbow)
		relaxed = _rotated(relaxed, j.shoulder, -arm_turn)
		pieces["far_hand"] = [relaxed, [[j.wrist, -arm_axis, false]], [[j.wrist, r.wrist]]]
	elif outfit == "base":
		pieces["far_hand"] = pieces.hand
	var out_dir := ProjectSettings.globalize_path(ROOT + "parts/" + outfit + "/")
	DirAccess.make_dir_recursive_absolute(out_dir)
	# 每件的裁切框：基准套装按实际轮廓裁；衣装沿用基准的框再四边多留 MARGIN（衣服比身体宽），
	# 接点坐标所有套装通用，引擎按 outfit.json 的 margin 挪回去
	var rects := {}
	var rects_path := ProjectSettings.globalize_path(ROOT + "parts/rects.json")
	if outfit != "base":
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(rects_path))
		for name in saved:
			var a: Array = saved[name]
			rects[name] = Rect2i(a[0], a[1], a[2], a[3]).grow(MARGIN)
	var origins := {}
	for name: String in pieces:
		var spec: Array = pieces[name]
		var cut := _cut(spec[0], spec[1], spec[2])
		var box: Rect2i = rects.get(name, cut.get_used_rect().grow(PAD).intersection(Rect2i(0, 0, W, H)))
		var piece := Image.create_empty(box.size.x, box.size.y, false, Image.FORMAT_RGBA8)
		piece.blit_rect(cut, box, Vector2i.ZERO)
		piece.save_png(out_dir + name + ".png")
		rects[name] = box
		origins[name] = Vector2(box.position)
	if outfit == "base":
		var out := {}
		for name in rects:
			out[name] = [rects[name].position.x, rects[name].position.y, rects[name].size.x, rects[name].size.y]
		FileAccess.open(rects_path, FileAccess.WRITE).store_string(JSON.stringify(out))
		_write_rig(j, origins, r, armless.get_used_rect())
	else:
		FileAccess.open(out_dir + "outfit.json", FileAccess.WRITE).store_string(JSON.stringify({"margin": MARGIN, "pelvis_front": not cut_cfg.has("belt_top")}))
	if outfit == "base":
		FileAccess.open(out_dir + "outfit.json", FileAccess.WRITE).store_string(JSON.stringify({"margin": 0, "pelvis_front": not cut_cfg.has("belt_top")}))
	print("完成 ", outfit)
	quit()

# ---------- 去白底 ----------

## 从画布四边往里灌：接近纯白、低饱和的像素当背景。边缘一圈按「和白色混了多少」反推透明度，
## 墨线外缘的半透明保住，颜色还原成不掺白的原色，缩小时不会泛白边。
func _key_white(img: Image) -> Image:
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var d := img.get_data()
	var bg := PackedByteArray()
	bg.resize(w * h)
	var stack := PackedInt32Array()
	for x in w:
		stack.append(x); stack.append((h - 1) * w + x)
	for y in h:
		stack.append(y * w); stack.append(y * w + w - 1)
	while not stack.is_empty():
		var i: int = stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		if bg[i] == 1:
			continue
		var r := d[i * 4]; var g := d[i * 4 + 1]; var b := d[i * 4 + 2]
		var lo := mini(r, mini(g, b))
		var hi := maxi(r, maxi(g, b))
		if lo < 232 or hi - lo > 14:
			continue
		bg[i] = 1
		var x := i % w
		var y := i / w
		if x > 0: stack.append(i - 1)
		if x < w - 1: stack.append(i + 1)
		if y > 0: stack.append(i - w)
		if y < h - 1: stack.append(i + w)
	for i in w * h:
		if bg[i] == 1:
			d[i * 4 + 3] = 0
			continue
		var x := i % w
		var y := i / w
		var edge := false
		for o in [[-1, 0], [1, 0], [0, -1], [0, 1], [-2, 0], [2, 0], [0, -2], [0, 2]]:
			var xx: int = x + o[0]
			var yy: int = y + o[1]
			if xx >= 0 and yy >= 0 and xx < w and yy < h and bg[yy * w + xx] == 1:
				edge = true
				break
		if not edge:
			continue
		# 墨线约 (70,50,40)：按最暗通道离白色多远估透明度
		var lo := mini(d[i * 4], mini(d[i * 4 + 1], d[i * 4 + 2]))
		var a := clampf((255.0 - lo) / 190.0, 0.0, 1.0)
		if a < 0.03:
			d[i * 4 + 3] = 0
			continue
		for c in 3:
			d[i * 4 + c] = int(clampf((d[i * 4 + c] - (1.0 - a) * 255.0) / a, 0.0, 255.0))
		d[i * 4 + 3] = int(a * 255.0)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, d)

# ---------- 对齐 ----------

## 去手臂那张是重新生成的，可能整体挪了几个像素。只比头和小腿（手臂碰不到的地方）的轮廓，
## 找让两张重合最多的平移。
func _register(a: Image, b: Image, joints: Dictionary) -> Vector2i:
	var da := a.get_data()
	var db := b.get_data()
	var rows := []
	var neck_y := int(joints.neck[1])
	var knee_y := int(joints.knee[1])
	for y in range(0, neck_y, 3):
		rows.append(y)
	for y in range(knee_y, H, 3):
		rows.append(y)
	var best := Vector2i.ZERO
	var best_score := -1.0
	for step in [4, 1]:
		var center := best
		var span := 24 if step == 4 else 4
		for dy in range(-span, span + 1, step):
			for dx in range(-span, span + 1, step):
				var s := Vector2i(center.x + dx, center.y + dy)
				var score := 0.0
				for y: int in rows:
					var yb: int = y - s.y
					if yb < 0 or yb >= H:
						continue
					for x in range(0, W, 3):
						var xb: int = x - s.x
						if xb < 0 or xb >= W:
							continue
						var pa := da[(y * W + x) * 4 + 3] > 127
						var pb := db[(yb * W + xb) * 4 + 3] > 127
						if pa and pb:
							score += 1.0
						elif pa != pb:
							score -= 1.0
				if score > best_score:
					best_score = score
					best = s
	return best

## 手臂图只含手臂：在 ±12 像素里找让手臂像素和 master 同位置颜色最接近的平移
func _register_color(master: Image, part: Image) -> Vector2i:
	var dm := master.get_data()
	var dp := part.get_data()
	var pts := PackedInt32Array()
	for i in range(0, W * H, 7):
		if dp[i * 4 + 3] > 200:
			pts.append(i)
	var best := Vector2i.ZERO
	var best_err := INF
	# 先每 3 像素粗找 ±30，再在最好的位置附近逐像素细找
	var cands := []
	for dy in range(-30, 31, 3):
		for dx in range(-30, 31, 3):
			cands.append(Vector2i(dx, dy))
	for stage in 2:
		if stage == 1:
			cands = []
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					cands.append(best + Vector2i(dx, dy))
		for c: Vector2i in cands:
			var dx := c.x
			var dy := c.y
			var err := 0.0
			for i in pts:
				var x := i % W + dx
				var y := i / W + dy
				if x < 0 or y < 0 or x >= W or y >= H:
					err += 300.0
					continue
				var k := (y * W + x) * 4
				err += absi(dm[k] - dp[i * 4]) + absi(dm[k + 1] - dp[i * 4 + 1]) + absi(dm[k + 2] - dp[i * 4 + 2])
			if err < best_err:
				best_err = err
				best = Vector2i(dx, dy)
	return best

## 只留连着种子点的那一块（去掉擦得不干净的碎屑）
func _only_component(img: Image, seed_pt: Array) -> Image:
	var d := img.get_data()
	var m := PackedByteArray()
	m.resize(W * H)
	for i in W * H:
		m[i] = 1 if d[i * 4 + 3] > 20 else 0
	var keep := _component(m, int(seed_pt[1]) * W + int(seed_pt[0]))
	for i in W * H:
		if keep[i] == 0:
			d[i * 4 + 3] = 0
	return Image.create_from_data(W, H, false, Image.FORMAT_RGBA8, d)

func _translated(img: Image, s: Vector2i) -> Image:
	var out := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	out.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), s)
	return out

func _component(m: PackedByteArray, seed: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(W * H)
	if m[seed] == 0:
		# 种子点刚好落在缝上：就近找一个手臂像素
		for r in range(1, 30):
			for o in [-r, r, -r * W, r * W]:
				if seed + o >= 0 and seed + o < W * H and m[seed + o] == 1:
					seed = seed + o
					break
			if m[seed] == 1:
				break
	var stack := PackedInt32Array([seed])
	while not stack.is_empty():
		var i: int = stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		if out[i] == 1 or m[i] == 0:
			continue
		out[i] = 1
		var x := i % W
		if x > 0: stack.append(i - 1)
		if x < W - 1: stack.append(i + 1)
		if i >= W: stack.append(i - W)
		if i < W * (H - 1): stack.append(i + W)
	return out

# ---------- 几何 ----------

## 关节处沿垂直于骨骼的方向量轮廓的半宽，作为圆头半径
func _half_width(img: Image, at: Vector2, axis: Vector2) -> float:
	var n := axis.normalized().orthogonal()
	var reach := [0.0, 0.0]
	for s in 2:
		var dir := n if s == 0 else -n
		var t := 0.0
		while t < 400.0:
			var p := at + dir * t
			if p.x < 0 or p.y < 0 or p.x >= W or p.y >= H or img.get_pixelv(Vector2i(p)).a < 0.5:
				break
			t += 1.0
		reach[s] = t
	return (reach[0] + reach[1]) * 0.5

## 留下：在所有切线指定一侧的像素，加上任一圆头里的像素（只在原图不透明处）。
## lines: [点, 法向, 留法向那一侧?]；caps: [圆心, 半径]
func _cut(src: Image, lines: Array, caps: Array) -> Image:
	var d := src.get_data()
	var out := PackedByteArray()
	out.resize(W * H * 4)
	for y in H:
		for x in W:
			var i := (y * W + x) * 4
			if d[i + 3] == 0:
				continue
			var p := Vector2(x + 0.5, y + 0.5)
			var keep := 1.0 if not lines.is_empty() else 0.0
			for l in lines:
				var s: float = (p - l[0]).dot(l[1])
				if not l[2]:
					s = -s
				keep = minf(keep, clampf(s + 1.5, 0.0, 1.0))
			for c in caps:
				var e: float = c[1] - p.distance_to(c[0])
				keep = maxf(keep, clampf(e + 0.5, 0.0, 1.0))
			if keep <= 0.0:
				continue
			out[i] = d[i]; out[i + 1] = d[i + 1]; out[i + 2] = d[i + 2]
			out[i + 3] = int(d[i + 3] * keep)
	return Image.create_from_data(W, H, false, Image.FORMAT_RGBA8, out)

## 绕 at 旋转（双线性取样）
func _rotated(img: Image, at: Vector2, angle: float) -> Image:
	var out := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	var used := img.get_used_rect()
	var inv := -angle
	var corners := [used.position, used.position + Vector2i(used.size.x, 0), used.end, used.position + Vector2i(0, used.size.y)]
	var box := Rect2(Vector2(at + (Vector2(corners[0]) - at).rotated(angle)), Vector2.ZERO)
	for c in corners:
		box = box.expand(at + (Vector2(c) - at).rotated(angle))
	box = box.grow(2).intersection(Rect2(0, 0, W, H))
	for y in range(int(box.position.y), int(box.end.y)):
		for x in range(int(box.position.x), int(box.end.x)):
			var q := at + (Vector2(x + 0.5, y + 0.5) - at).rotated(inv) - Vector2(0.5, 0.5)
			var x0 := floori(q.x)
			var y0 := floori(q.y)
			if x0 < 0 or y0 < 0 or x0 >= W - 1 or y0 >= H - 1:
				continue
			var fx := q.x - x0
			var fy := q.y - y0
			var acc := Color(0, 0, 0, 0)
			var wsum := 0.0
			for k in 4:
				var xx := x0 + (k & 1)
				var yy := y0 + (k >> 1)
				var wgt := (fx if k & 1 else 1.0 - fx) * (fy if k >> 1 else 1.0 - fy)
				var c := img.get_pixel(xx, yy)
				# 预乘透明度再插值，边缘不发黑
				acc += Color(c.r * c.a, c.g * c.a, c.b * c.a, c.a) * wgt
				wsum += wgt
			if acc.a > 0.002:
				out.set_pixel(x, y, Color(acc.r / acc.a, acc.g / acc.a, acc.b / acc.a, acc.a))
	return out

# ---------- 输出 ----------

func _pt(v: Vector2, origin: Vector2) -> Array:
	var p := v - origin
	return [snappedf(p.x, 0.1), snappedf(p.y, 0.1)]

## rig.json = source/motion.json（动作参数，手写）+ 这里量出的部件接点
func _write_rig(j: Dictionary, o: Dictionary, r: Dictionary, body: Rect2i) -> void:
	var sole := Vector2(j.ankle.x, float(_joints.sole_y))
	var parts := {
		"head": {"pivot": _pt(j.neck, o.head), "behind": true},
		"torso": {"pivot": _pt(j.waist, o.torso), "neck": _pt(j.neck, o.torso), "shoulder": _pt(j.shoulder, o.torso)},
		"pelvis": {"pivot": _pt(j.waist, o.pelvis), "at": _pt(j.waist, o.torso), "hip": _pt(j.hip, o.pelvis)},
		"upper_arm": {"pivot": _pt(j.shoulder, o.upper_arm), "end": _pt(j.elbow, o.upper_arm)},
		"forearm": {"pivot": _pt(j.elbow, o.forearm), "wrist": _pt(j.wrist, o.forearm)},
		"hand": {"pivot": _pt(j.wrist, o.hand)},
		"thigh": {"pivot": _pt(j.hip, o.thigh), "end": _pt(j.knee, o.thigh)},
		"shin": {"pivot": _pt(j.knee, o.shin), "ankle": _pt(j.ankle, o.shin), "sole": _pt(sole, o.shin)},
		"foot": {"pivot": _pt(j.ankle, o.foot), "ball": _pt(j.ball, o.foot), "foot_roll_height": 0.18},
		"far_hand": {"pivot": _pt(j.wrist, o.far_hand)},
		"crotch": {"pivot": _pt(j.hip, o.crotch)},
	}
	var rig: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "source/motion.json"))
	if o.has("grip_hand"):
		parts["grip_hand"] = {"pivot": _pt(j.wrist, o.grip_hand)}
		var g: Dictionary = rig.grip
		# 握点、掌心在基准图里量（转正前的坐标），这里换成拳头贴图里的坐标
		var turn: float = (Vector2(_joints.elbow[0], _joints.elbow[1]) - j.shoulder).angle() - PI / 2.0
		for key in ["at", "palm"]:
			var p := Vector2(g[key + "_master"][0], g[key + "_master"][1])
			g[key] = _pt(j.shoulder + (p - j.shoulder).rotated(-turn), o.grip_hand)
		g.bearing = float(g.bearing_master) - rad_to_deg(turn)
	rig.base_dir = ROOT.trim_suffix("/") + "/parts/base"
	rig.scale = 1.0
	rig.parts = parts
	rig.rest_height = float(_joints.sole_y) - body.position.y
	rig.caps = r
	FileAccess.open(ProjectSettings.globalize_path(ROOT + "rig.json"), FileAccess.WRITE).store_string(JSON.stringify(rig, "  "))

# ---------- 按颜色分短裤和皮肤（基准光身那套用） ----------

static func _is_skin(r: int, g: int, b: int) -> bool:
	return r > 160 and r - b > 40 and g > 100

## 只留 y0 以下不是皮肤的像素：短裤和它的墨线。上沿就是画好的腰头边
func _cloth_only(img: Image, y0: int) -> Image:
	var d := img.get_data()
	for y in H:
		for x in W:
			var i := (y * W + x) * 4
			if d[i + 3] == 0:
				continue
			if y < y0 or _is_skin(d[i], d[i + 1], d[i + 2]):
				d[i + 3] = 0
	return Image.create_from_data(W, H, false, Image.FORMAT_RGBA8, d)

## y0 以下不是皮肤的像素换成同一列上方最近的肤色：躯干垫在腰头底下的那一截，转身时露出来也是肉
func _skin_under(img: Image, y0: int) -> Image:
	var d := img.get_data()
	for x in W:
		var last := PackedByteArray([0, 0, 0])
		var have := false
		for y in H:
			var i := (y * W + x) * 4
			if d[i + 3] == 0:
				continue
			if _is_skin(d[i], d[i + 1], d[i + 2]):
				last = PackedByteArray([d[i], d[i + 1], d[i + 2]])
				have = true
			elif y >= y0 and have:
				d[i] = last[0]; d[i + 1] = last[1]; d[i + 2] = last[2]
	return Image.create_from_data(W, H, false, Image.FORMAT_RGBA8, d)

## 拳眼：手指圈住的那一小块白底没连到画布边，去白底时灌不进去。刀柄比拳眼细，透明会漏底，
## 涂成掌心里的暗影色
func _clear_enclosed_white(img: Image) -> Image:
	var d := img.get_data()
	for i in W * H:
		if d[i * 4 + 3] > 0 and mini(d[i * 4], mini(d[i * 4 + 1], d[i * 4 + 2])) > 225:
			d[i * 4] = 92; d[i * 4 + 1] = 58; d[i * 4 + 2] = 44; d[i * 4 + 3] = 255
	return Image.create_from_data(W, H, false, Image.FORMAT_RGBA8, d)

## 两点定一条切线 → [线上一点, 朝上的法向]
func _line(pts: Array) -> Array:
	var a := Vector2(pts[0][0], pts[0][1])
	var b := Vector2(pts[1][0], pts[1][1])
	var n := (b - a).normalized().orthogonal()
	if n.y > 0:
		n = -n
	return [a, n]

## 裙甲下沿以上的像素换成同一列下沿以下第一个像素的颜色：大腿那件的顶端是「裤子接着往上」，
## 大腿抬起来转出去时不会把一块裙甲带出来
func _extrude_below(img: Image, hem: int) -> Image:
	var d := img.get_data()
	for x in W:
		var src := -1
		for y in range(hem + 3, mini(hem + 40, H)):
			if d[(y * W + x) * 4 + 3] > 200:
				src = (y * W + x) * 4
				break
		if src < 0:
			continue
		for y in range(0, hem + 3):
			var i := (y * W + x) * 4
			if d[i + 3] > 0:
				d[i] = d[src]; d[i + 1] = d[src + 1]; d[i + 2] = d[src + 2]
	return Image.create_from_data(W, H, false, Image.FORMAT_RGBA8, d)
