extends RefCounted

const SideArt = preload("res://scripts/side_art.gd")
const WeaponDesign = preload("res://scripts/weapon_design.gd")
const Parts = preload("res://scripts/weapon_parts_atlas.gd")
# 手持兵器图集由 art/side/pack_weapons.py 从法器原画抠出，4 列 × 2 行。
const ATLAS_SHEET = preload("res://art/side/held-weapons.png")
const ATLAS_GRID := Vector2(4, 2)
static var ATLAS: CanvasTexture = SideArt.smooth(ATLAS_SHEET)
static var PARTS: CanvasTexture = SideArt.smooth(Parts.SHEET)
const BOW_SCALE := 0.48
const BOW_STRING := Color("#d4c4a5")
const HEAD_SCALE := {"spear": 0.30}

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

# ground 给了的话（脚底线的 y），柄尾一直接到地面，拄着站。
static func draw_pole(canvas: CanvasItem, form: String, origin: Vector2, angle: float, ink: Color,
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

static func draw_bow(canvas: CanvasItem, palm: Vector2, nock: Vector2, drawing: bool, angle: float, ink: Color,
		design := {}, light := Color.WHITE) -> void:
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
	# The painted limbs meet to the side of the atlas cell's center line.
	var root_x: float = {"fanqu": 13.0, "jiao": 13.0, "chang": 15.0, "yun": 8.0}[design.head]
	var limbs := frame.translated_local(Vector2(0.0, -root_x * k))
	var top := limbs * (Vector2(tip.y, tip.x) * k)
	var bottom := limbs * (Vector2(-tip.y, tip.x) * k)
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
	_draw_part(canvas, design.head, limbs, 0.0, k, false, design, light)
	_draw_part(canvas, design.head, limbs, 0.0, k, false, design, light, true)
	var grip_k := k * 1.3
	var half: float = float(Parts.PARTS[design.grip].length) * 0.5
	_draw_part(canvas, design.grip, frame, -half, grip_k, false, design, light)
	if design.tassel.a > 0.0 and not _painted(design.head):
		_tassel(canvas, frame * Vector2(-half * grip_k, 0.0), design.tassel, design.tassel_alt, light, 6.0, 6, zoom)

static func draw_sword(canvas: CanvasItem, grip: Vector2, angle: float, ink: Color, design: Dictionary) -> void:
	if WeaponDesign.painted_blade(design):
		_draw_art(canvas, "sword", grip, angle, ink)
	else:
		_draw_assembled(canvas, design, Transform2D(angle, grip), 0.29, ink)


static func _draw_assembled(canvas: CanvasItem, design: Dictionary, frame: Transform2D, k: float, light: Color) -> void:
	var half: float = float(Parts.PARTS[design.grip].length) * 0.5
	var guard_at := half - 1.0
	var blade_at := guard_at + float(Parts.PARTS[design.guard].length) - 1.5
	var pommel_at := -half + 1.0
	canvas.draw_line(frame * Vector2(guard_at * k, 0), frame * Vector2((blade_at + 2.0) * k, 0),
		design.steel * light, 3.5 * k, true)
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
		"jian", "sword":
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
		"jian", "sword":
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
