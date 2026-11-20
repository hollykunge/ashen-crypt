extends RefCounted

const SideArt = preload("res://scripts/side_art.gd")
const BowPose = preload("res://scripts/bow_pose.gd")
const WeaponDesign = preload("res://scripts/weapon_design.gd")
const Parts = preload("res://scripts/weapon_parts_atlas.gd")
# 手持兵器图集由 art/side/pack_weapons.py 从法器原画抠出，4 列 × 2 行。
const ATLAS_SHEET = preload("res://art/side/held-weapons.png")
const ATLAS_GRID := Vector2(4, 2)
static var ATLAS: CanvasTexture = SideArt.smooth(ATLAS_SHEET)
static var PARTS: CanvasTexture = SideArt.smooth(Parts.SHEET)
# 零件拼的兵器，素材空间一单位折合多少人物逻辑像素。
const BLADE_SCALE := {"sword": 0.29}
const BOW_SCALE := 0.48
const BOW_STRING := Color("#d4c4a5")
const HEAD_SCALE := {"spear": 0.30}

# 两手取自男女各自动作原画里的拳心。第一只手领招，第二只手持副刀或拉弦。
const LEAD := [
	[Vector2(59, 56), Vector2(66, 53), Vector2(63, 53), Vector2(65, 59), Vector2(38, 33), Vector2(78, 41),
	 Vector2(70, 64), Vector2(61, 43), Vector2(51, 50), Vector2(61, 45), Vector2(79, 32), Vector2(63, 52)],
	[Vector2(59, 55), Vector2(62, 52), Vector2(61, 55), Vector2(63, 58), Vector2(34, 33), Vector2(75, 45),
	 Vector2(65, 64), Vector2(60, 50), Vector2(53, 56), Vector2(59, 42), Vector2(77, 37), Vector2(60, 55)]
]
const SUPPORT := [
	[Vector2(46, 57), Vector2(41, 55), Vector2(36, 55), Vector2(40, 56), Vector2(36, 35), Vector2(75, 42),
	 Vector2(67, 62), Vector2(57, 46), Vector2(39, 59), Vector2(34, 52), Vector2(42, 50), Vector2(51, 54)],
	[Vector2(44, 56), Vector2(36, 56), Vector2(36, 56), Vector2(42, 58), Vector2(35, 35), Vector2(72, 46),
	 Vector2(63, 64), Vector2(47, 49), Vector2(33, 58), Vector2(32, 51), Vector2(40, 54), Vector2(51, 54)]
]
# 刀由近手持握，依每一格衣袖的走向选拳心。迈步时前后手会交替出现在轮廓外。
const NEAR_IS_LEAD := [
	[true, false, true, false, true, true, true, false, false, false, false, false],
	[true, false, false, false, true, true, true, false, false, false, false, false]
]
const SWING := [-0.76, 0.18, -0.12, -0.34, -2.04, -0.16, 0.55, -0.74, -0.48, -0.24, -0.42, 0.09]

# 三种兵形：剑由零件拼，长枪是杆加枪头，弓是弓臂。
const KINDS := ["sword", "spear", "bow"]
# 旧的整张原画兵器（零件图缺失时的兜底）：素材空间为 128 × 128，一格原画。沿柄从握点看向护手或兵器头；
# 横向翻转让刀的亮刃迎着下斩方向。
const FORMS := {
	"bow": {"cell": 3, "grip": Vector2(56, 60), "forward": Vector2(120, 8), "scale": Vector2(0.36, -0.36)},
	"spear": {"cell": 4, "grip": Vector2(52.7, 70.7), "forward": Vector2(107.5, 12.5), "scale": Vector2(0.27, 0.27)},
	"sword": {"cell": 6, "grip": Vector2(64, 89), "forward": Vector2(64, 20), "scale": Vector2(0.31, 0.31)}
}
# 长柄兵器的杆由这里画：butt 是后手之后露出的柄尾，socket 是兵器头接在后手之前多远，
# clip 是原画只取上面多高（下面那截短柄让给画出来的长杆）。单位是人物的逻辑像素。
const POLES := {
	"spear": {"butt": -17.0, "socket": 33.0, "clip": 128.0,
		"wood": Color("#5a5560"), "core": Color("#1d1a1c"), "cap": Color("#d0ab73")}
}
# 双拳并在一起的那几格看不出杆的朝向，长枪按出枪的路线单独给：收在肩后、平刺、枪尖略沉、收回。
const SPEAR_AIM := {4: -0.07, 5: -0.03, 6: 0.16, 7: -0.46}
# 握拳处从人物贴图上再盖一小块回来，半径是逻辑像素。
const FIST := 3.2
# 待机一律用直立的第 0 格，兵器单手垂在身侧：剑尖斜指前方地面，枪竖着拄地，弓斜提。
# 数值是兵器从握点指出去的方向（弧度，0 朝前，正值往下）。
const IDLE := {"sword": 1.10, "spear": -1.50, "bow": -1.36}
const IDLE_RIGHT := [SUPPORT[0][0], SUPPORT[1][0]]
const IDLE_LEFT := [LEAD[0][0], LEAD[1][0]]
# 拄地的长柄兵器，柄尾落在脚底线往上这么多。
const GROUNDED := ["spear"]
const BUTT_CLEARANCE := 1.5

static func placement(form: String, grip: Vector2, angle: float) -> Transform2D:
	var spec: Dictionary = FORMS[form]
	var source_axis: Vector2 = spec.forward - spec.grip
	var axes := Transform2D(angle, Vector2.ZERO).scaled_local(spec.scale)
	var pose := axes * Transform2D(-source_axis.angle(), Vector2.ZERO)
	pose.origin = grip - pose.basis_xform(spec.grip)
	return pose

static func _draw_art(canvas: CanvasItem, form: String, grip: Vector2, angle: float, ink: Color, height := 128.0) -> void:
	var pose := placement(form, grip, angle)
	var corners := PackedVector2Array([Vector2.ZERO, Vector2(128, 0), Vector2(128, height), Vector2(0, height)])
	var cell: int = FORMS[form].cell
	var column := Vector2(cell % int(ATLAS_GRID.x), floori(cell / ATLAS_GRID.x))
	var uvs := PackedVector2Array()
	for p in corners:
		uvs.append((column + p / 128.0) / ATLAS_GRID)
	canvas.draw_polygon(pose * corners, PackedColorArray([ink]), uvs, ATLAS)

# 出手格的箭尖，坐标原点在角色脚底。法术弹道已经没有了，后两个参数只为兼容旧的调用。
static func release_point(sex: int, _magic := false, _wand := false) -> Vector2:
	return LEAD[sex][10] - SideArt.PIVOT + Vector2(8, 0)

static func arrow_length(sex: int) -> float:
	return release_point(sex, false).distance_to(BowPose.nock_hand(sex, false) - SideArt.PIVOT)

static func body_frame(form: String, frame: int) -> int:
	if form == "bow" and frame in [4, 5]:
		return 10
	return frame

static func blade_hand(sex: int, body: int, offhand := false) -> Vector2:
	return LEAD[sex][body] if NEAR_IS_LEAD[sex][body] != offhand else SUPPORT[sex][body]

# 兵器画在身体上面，握柄的那只手得再盖回来：从同一张人物贴图上取拳头那一小圆，
# 换装后的护手、戒指也就跟着在柄前面了。hand 是分格内的逻辑坐标。
static func _fist(canvas: CanvasItem, sprite: Texture2D, source: Vector2, origin: Vector2, hand: Vector2, ink: Color) -> void:
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	var size := sprite.get_size()
	for i in range(14):
		var at := hand + Vector2.from_angle(i * TAU / 14.0) * FIST
		points.append(origin + at)
		uvs.append((source + at * SideArt.TEXEL) / size)
	canvas.draw_polygon(points, PackedColorArray([ink]), uvs, sprite)

# ground 给了的话（脚底线的 y），柄尾一直接到地面，拄着站。
static func _draw_pole(canvas: CanvasItem, form: String, origin: Vector2, angle: float, ink: Color,
		ground := INF, design := {}, light := Color.WHITE) -> void:
	var t := Transform2D(angle, origin)
	var pole: Dictionary = POLES[form].duplicate()
	if not design.get("pole", {}).is_empty():
		pole.merge(design.pole, true)
	var axis := t.x
	var across := t.y
	var butt := float(pole.butt)
	if ground < INF and axis.y < -0.5:
		butt = minf(butt, (ground - BUTT_CLEARANCE - origin.y) / axis.y)
	var start: Vector2 = origin + axis * butt
	var socket: Vector2 = origin + axis * float(pole.socket)
	var wood: Color = pole.wood
	var core: Color = pole.core
	var cap: Color = pole.cap
	# 杆：一道深色的芯勾出轮廓，上沿压一条受光的木色，两头各箍一道铜。
	canvas.draw_line(start, socket, core * ink, 2.9, true)
	canvas.draw_line(start - across * 0.45, socket - across * 0.45, wood * ink, 1.3, true)
	canvas.draw_line(start - across * 0.9, socket - across * 0.9, wood.lightened(0.35) * ink, 0.45, true)
	canvas.draw_line(start, start + axis * 2.4, cap * ink, 3.1, true)
	canvas.draw_line(start + axis * 2.4, start + axis * 3.0, core * ink, 3.1, true)
	canvas.draw_line(socket - axis * 2.2, socket + axis, cap.darkened(0.08) * ink, 3.3, true)
	if form == "spear":
		var band := start.lerp(socket, 0.30)
		canvas.draw_line(band, band + axis * 1.8, cap * ink, 3.1, true)
	if design.is_empty() or WeaponDesign.painted_head(design):
		_draw_art(canvas, form, socket, angle, ink, float(pole.clip))
		return
	var frame := Transform2D(angle, socket)
	var k: float = HEAD_SCALE[form]
	_draw_part(canvas, design.head, frame, -1.5, k, false, design, light)
	if form == "spear" and not _painted(design.head):
		var tuft: Color = design.tassel if design.tassel.a > 0.0 else Color("#b8342a")
		_tassel(canvas, frame * Vector2(1.2, 0.0), tuft, tuft, light, 7.5, 9)

static func _draw_bow(canvas: CanvasItem, palm: Vector2, nock: Vector2, drawing: bool, horizontal: bool, ink: Color,
		held := -1.20, design := {}, light := Color.WHITE) -> void:
	var angle := -PI / 2 if horizontal else held
	if not design.is_empty() and not WeaponDesign.painted_head(design):
		_draw_bow_parts(canvas, design, Transform2D(angle, palm), BOW_SCALE, light, nock if drawing else Vector2.INF)
		return
	var pose := placement("bow", palm, angle)
	var top := pose * Vector2(120, 8)
	var bottom := pose * Vector2(9, 119)
	var string_center := nock if drawing else (top + bottom) * 0.5
	canvas.draw_polyline(PackedVector2Array([top, string_center, bottom]), Color("#d4c4a5") * ink, 0.7, true)
	if drawing:
		var aim := (palm - nock).normalized()
		var tip := palm + aim * 8
		canvas.draw_line(nock, tip, Color("#ba8c58") * ink, 1.0, true)
		canvas.draw_colored_polygon(PackedVector2Array([tip + aim * 2.5, tip + aim.orthogonal() * 1.25,
			tip - aim.orthogonal() * 1.25]), Color("#c4cbd0") * ink)
	_draw_art(canvas, "bow", palm, angle, ink)

static func draw_actor(canvas: CanvasItem, sprite: Texture2D, sex: int, frame: int, look: Dictionary,
		ink := Color.WHITE, gait := {}, foot_shift := Vector2.ZERO, offset := Vector2.ZERO) -> void:
	var form: String = look.form if look.form in KINDS else "sword"
	var design: Dictionary = look.get("design", {})
	if design.get("form", "") != form:
		design = WeaponDesign.plain(form)
	var body := body_frame(form, frame)
	var origin := offset - SideArt.PIVOT
	var idle := frame == 0
	var lead: Vector2 = origin + LEAD[sex][body]
	var rear: Vector2 = origin + SUPPORT[sex][body]
	var primary := origin + blade_hand(sex, body)
	if idle:
		# 人物朝右，靠镜头的是右手。直立那格身前的拳是远侧的左手，靠后、整条前臂露在外面的才是右手，
		# 待机的兵器交给右手。
		lead = origin + IDLE_RIGHT[sex]
		rear = origin + IDLE_LEFT[sex]
		primary = lead
	var angle: float = SWING[frame]
	if idle:
		angle = IDLE[form]
	var metal: Color = ink * Color.WHITE.lerp(look.weapon, 0.34)
	var drawn_bow := form == "bow" and frame in [4, 5]
	# 握拳那一小块从哪张贴图、哪一格取：满弓格用的是改过袖子的单格贴图。
	var hand_sprite := sprite
	var hand_source := SideArt.frame_region(body).position
	# 长枪收到肩后的那一格，枪杆在头的另一侧：先画杆再画人，不然杆会横在脸上。
	var shouldered := form == "spear" and frame == 4
	if shouldered:
		_draw_pole(canvas, form, lead - Vector2.from_angle(SPEAR_AIM[4]) * 5.5, SPEAR_AIM[4], metal, INF, design, ink)
	if drawn_bow:
		hand_sprite = BowPose.texture(sprite, sex, frame == 5)
		hand_source = Vector2.ZERO
		canvas.draw_texture_rect(hand_sprite, Rect2(origin, SideArt.CELL), false, ink)
	elif gait.is_empty():
		canvas.draw_texture_rect_region(sprite, Rect2(origin, SideArt.CELL), SideArt.frame_region(body), ink)
	else:
		SideArt.draw_gait(canvas, sprite, gait, foot_shift, ink)
	var hands := [lead]
	match form:
		"bow":
			var nock := origin + BowPose.nock_hand(sex, frame == 5)
			_draw_bow(canvas, lead, nock, frame == 4, drawn_bow, metal, angle if idle else -1.20, design, ink)
		"spear":
			# 架着的时候两拳夹住长柄，挥击格双拳已在身前并拢。
			var rear_grip := lead
			var two_handed := frame in [3, 4, 5, 6, 7]
			if two_handed:
				hands.append(rear)
				if lead.distance_to(rear) >= 7.0:
					angle = (lead - rear).angle()
					rear_grip = rear
				else:
					angle = SPEAR_AIM.get(frame, angle)
					rear_grip = lead - Vector2.from_angle(angle) * 5.5
			elif frame in [1, 2, 11]:
				angle = -0.98
			if not shouldered:
				_draw_pole(canvas, form, rear_grip, angle, metal, offset.y if idle and form in GROUNDED else INF, design, ink)
		_:
			hands = [primary]
			_draw_blade(canvas, form, design, primary, angle, metal, ink)
	for hand: Vector2 in hands:
		_fist(canvas, hand_sprite, hand_source, origin, hand - origin, ink)

# ---------- 零件拼的兵器 ----------

# 画一件零件。frame 是兵器本地系（原点在握点或接口，+x 朝兵器尖），along 是零件接口落在轴上哪儿（素材单位），
# reverse 让零件朝 -x 长（柄首）。每层按自己的染色乘上材质色。
# mirror 只把沿轴方向翻过来、横向不翻：弓的下半张就是上半张这样镜像出来的。
static func _draw_part(canvas: CanvasItem, name: String, frame: Transform2D, along: float, k: float, reverse: bool,
		design: Dictionary, light: Color, mirror := false) -> void:
	var spec: Dictionary = Parts.PARTS[name]
	var dir := -1.0 if reverse else 1.0
	var axial := -dir if mirror else dir
	var local := Transform2D(Vector2(0.0, k * dir), Vector2(-k * axial, 0.0),
		Vector2(k * (along + Parts.BASE.y * axial), -k * dir * Parts.BASE.x))
	var pose := frame * local
	var reach: float = float(spec.width) + 3.0
	var top := maxf(0.0, Parts.BASE.y - float(spec.length) - 3.0)
	var corners := PackedVector2Array([Vector2(Parts.BASE.x - reach, top), Vector2(Parts.BASE.x + reach, top),
		Vector2(Parts.BASE.x + reach, 128.0), Vector2(Parts.BASE.x - reach, 128.0)])
	var points := pose * corners
	for layer: Array in spec.layers:
		var cell: int = layer[0]
		var column := Vector2(cell % int(Parts.GRID.x), floori(cell / Parts.GRID.x))
		var uvs := PackedVector2Array()
		for p in corners:
			uvs.append((column + p / 128.0) / Parts.GRID)
		canvas.draw_polygon(points, PackedColorArray([_layer_ink(design, layer[1]) * light]), uvs, PARTS)

# 原画零件自己带着朱红的穗子和缠绳（打包时分到 accent 层），游戏就不再另挂一挂。
static func _painted(name: String) -> bool:
	for layer: Array in Parts.PARTS[name].layers:
		if layer[1] == "accent":
			return true
	return false

static func _layer_ink(design: Dictionary, tint: String) -> Color:
	match tint:
		"steel", "trim", "wrap", "bone", "glow", "accent":
			return design.get(tint, Color.WHITE)
		"wood":
			# 弓臂上的漆色：杆色偏暗，乘在灰度弓臂上会糊成一片，提亮一些。
			return Color(design.get("pole", {}).get("wood", Color("#a4774e"))).lightened(0.3)
	return Color.WHITE

# 弓：上半张弓臂画一遍，沿弓把镜像出下半张，握把缠绳，弦挂在两头弓弰上。
# nock 是拉弦那只手；没在拉（Vector2.INF）时弦是直的。
static func _draw_bow_parts(canvas: CanvasItem, design: Dictionary, frame: Transform2D, k: float, light: Color,
		nock := Vector2.INF) -> void:
	var spec: Dictionary = Parts.PARTS[design.head]
	var tip: Vector2 = spec.tip
	var top := frame * (Vector2(tip.y, tip.x) * k)
	var bottom := frame * (Vector2(-tip.y, tip.x) * k)
	var drawing := nock != Vector2.INF
	var middle := nock if drawing else (top + bottom) * 0.5
	var zoom := k / BOW_SCALE
	canvas.draw_polyline(PackedVector2Array([top, middle, bottom]), BOW_STRING * light, 0.7 * zoom, true)
	if drawing:
		var palm := frame.origin
		var aim := (palm - nock).normalized()
		var point := palm + aim * 8
		canvas.draw_line(nock, point, Color("#ba8c58") * light, 1.0, true)
		canvas.draw_colored_polygon(PackedVector2Array([point + aim * 2.5, point + aim.orthogonal() * 1.25,
			point - aim.orthogonal() * 1.25]), Color("#c4cbd0") * light)
	_draw_part(canvas, design.head, frame, 0.0, k, false, design, light)
	_draw_part(canvas, design.head, frame, 0.0, k, false, design, light, true)
	var grip_k := k * 1.3
	var half: float = float(Parts.PARTS[design.grip].length) * 0.5
	_draw_part(canvas, design.grip, frame, -half, grip_k, false, design, light)
	if design.tassel.a > 0.0 and not _painted(design.head):
		_tassel(canvas, frame * Vector2(-half * grip_k, 0.0), design.tassel, design.tassel_alt, light, 6.0, 6, zoom)

# 刀剑：柄首、握柄、刃、血槽灵光、护手，最后挂穗。握点在握柄正中。
static func _draw_blade(canvas: CanvasItem, form: String, design: Dictionary, hand: Vector2, angle: float,
		metal: Color, light: Color) -> void:
	if WeaponDesign.painted_blade(design) or not BLADE_SCALE.has(form):
		_draw_art(canvas, form, hand, angle, metal)
		return
	_draw_assembled(canvas, design, Transform2D(angle, hand), BLADE_SCALE[form], light)

static func _draw_assembled(canvas: CanvasItem, design: Dictionary, frame: Transform2D, k: float, light: Color) -> void:
	var half: float = float(Parts.PARTS[design.grip].length) * 0.5
	var guard_at := half - 1.0
	var blade_at := guard_at + float(Parts.PARTS[design.guard].length) - 1.5
	var pommel_at := -half + 1.0
	_draw_part(canvas, design.pommel, frame, pommel_at, k, true, design, light)
	_draw_part(canvas, design.grip, frame, -half, k, false, design, light)
	_draw_part(canvas, design.blade, frame, blade_at, k, false, design, light)
	_inlay(canvas, design, frame, blade_at, k, light)
	_draw_part(canvas, design.guard, frame, guard_at, k, false, design, light)
	if design.tassel.a > 0.0 and not _painted(design.pommel):
		var end := pommel_at - float(Parts.PARTS[design.pommel].length) + 1.5
		_tassel(canvas, frame * Vector2(end * k, 0.0), design.tassel, design.tassel_alt, light, 6.0, 6, k / 0.3)

# 功率够足的兵器，刃上沿血槽亮一道灵光：外层虚、内层实。
static func _inlay(canvas: CanvasItem, design: Dictionary, frame: Transform2D, along: float, k: float, light: Color) -> void:
	var amount: float = design.get("inlay", 0.0)
	var groove: Array = Parts.PARTS[design.blade].get("groove", [])
	if amount <= 0.0 or groove.size() < 2:
		return
	var line := PackedVector2Array()
	for g: Vector2 in groove:
		line.append(frame * (Vector2(along + g.y, g.x) * k))
	var glow: Color = design.glow
	var zoom := k / 0.3
	canvas.draw_polyline(line, Color(glow, 0.28 * amount) * light, 1.1 * zoom, true)
	canvas.draw_polyline(line, Color(glow.lerp(Color.WHITE, 0.5), 0.75 * amount) * light, 0.35 * zoom, true)

# 穗子不随兵器转，总是朝下垂：一个结、几缕丝，太极的穗子黑白相间。
static func _tassel(canvas: CanvasItem, at: Vector2, color: Color, alt: Color, light: Color, length: float, strands: int,
		zoom := 1.0) -> void:
	var knot := at + Vector2(0.0, 1.1 * zoom)
	canvas.draw_line(at, knot, Color("#3a2a22") * light, 0.45 * zoom, true)
	for i in range(strands):
		var spread := (float(i) / maxf(1.0, strands - 1.0) - 0.5) * 1.8
		var tip := knot + Vector2(spread + 0.4, length * (1.0 - absf(spread) * 0.12)) * zoom
		var ink: Color = (color if i % 2 == 0 else alt) * light
		canvas.draw_line(knot + Vector2(spread * 0.25, 0.4) * zoom, tip, ink.darkened(0.25 if i % 3 == 1 else 0.0), 0.55 * zoom, true)
	canvas.draw_circle(knot, 0.85 * zoom, color.darkened(0.15) * light, true, -1.0, true)

# 图标：整件兵器斜放在 rect 里，尖朝右上。原画的兵器返回 false，由调用方用形制图标。
static func draw_icon(canvas: CanvasItem, form: String, design: Dictionary, rect: Rect2, light := Color.WHITE) -> bool:
	var angle := -PI / 4.0
	var axis := Vector2.from_angle(angle)
	var back := 0.0
	var front := 0.0
	match form:
		"sword":
			if WeaponDesign.painted_blade(design):
				return false
			var half: float = float(Parts.PARTS[design.grip].length) * 0.5
			back = half - 1.0 + float(Parts.PARTS[design.pommel].length)
			front = half - 2.5 + float(Parts.PARTS[design.guard].length) + float(Parts.PARTS[design.blade].length)
		"bow":
			if WeaponDesign.painted_head(design):
				return false
			back = float(Parts.PARTS[design.head].tip.y)
			front = back
		"spear":
			if WeaponDesign.painted_head(design):
				return false
			back = 34.0
			front = float(Parts.PARTS[design.head].length) - 1.5
		_:
			return false
	var k := rect.size.length() * 0.80 / (back + front)
	var hand := rect.get_center() - axis * (front - back) * 0.5 * k
	var frame := Transform2D(angle, hand)
	match form:
		"sword":
			_draw_assembled(canvas, design, frame, k, light)
		"bow":
			_draw_bow_parts(canvas, design, frame, k, light)
		_:
			var pole: Dictionary = POLES[form].duplicate()
			pole.merge(design.get("pole", {}), true)
			var butt := hand - axis * back * k
			canvas.draw_line(butt, hand, Color(pole.core) * light, maxf(1.5, 3.4 * k), true)
			canvas.draw_line(butt, hand, Color(pole.wood) * light, maxf(0.8, 1.6 * k), true)
			_draw_part(canvas, design.head, frame, -1.5, k, false, design, light)
			if form == "spear" and not _painted(design.head):
				var tuft: Color = design.tassel if design.tassel.a > 0.0 else Color("#b8342a")
				_tassel(canvas, hand + axis * k, tuft, tuft, light, 7.5, 9, k / 0.27)
	return true
