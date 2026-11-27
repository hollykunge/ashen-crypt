extends Button

const Gear = preload("res://scripts/gear.gd")
const Roster = preload("res://scripts/roster.gd")
const ForgeArt = preload("res://scripts/forge_art.gd")
const Appearance = preload("res://scripts/appearance.gd")


const GOOD := Color("#acc894")
const BAD := Color("#ff9a79")
const INK := Color("#f1dfb4")
const BORDER := Color("#b99350")
const PLATE := Color("#182a2c")
const FORTUNES := {
	"旺": Color("#b29251"), "相": Color("#557447"), "休": Color("#515b5a"),
	"囚": Color("#71362e"), "死": Color("#282a2c")
}
static var _tile: ArtPlate
var occupied := false
var simple := false
var highlighted := false
var caption := ""
var _icon: Texture2D
var _fabric_tint := Color.WHITE
var _edge := BORDER
var _tint := INK
var _fortune := ""
var _god := ""
var _god_color := INK
var _polarity := 0.0

func _init(pixels: int = 88) -> void:
	custom_minimum_size = Vector2.ONE * pixels
	size_flags_horizontal = SIZE_SHRINK_CENTER
	size_flags_vertical = SIZE_SHRINK_CENTER
	var clear := StyleBoxEmpty.new()
	for style in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(style, clear)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func display(slot: String, derived: Dictionary, person: Dictionary, form: String = "") -> void:
	var index := Gear.SLOTS.find(slot)
	var title: String = Gear.SLOT_NAMES[index]
	var main := Gear.Loadout.dominant(derived.get("wuxing", {}))
	occupied = not main.is_empty()
	if occupied:
		_polarity = derived.yin_yang
		_edge = Roster.ELEMENT_GLOW[main]
		_tint = Roster.ELEMENT_TINTS[main]
		_fortune = derived.jingyu.get(main, "")
		var day_stem: String = person.day_stem
		var stem := Gear.WuXing.stem_for(main, _polarity)
		_god = Gear.Bazi.GOD_EFFECTS[Gear.Bazi.ten_god(day_stem, stem)].name
		var fit := Gear.Loadout.fit_group(day_stem, main, Gear.Loadout.strength(person))
		_god_color = GOOD if fit > 0 else (BAD if fit < 0 else INK)
		title += " · %s · %s%s · 阴阳 %+.2f" % [derived.name, _fortune, _god, _polarity]
	else:
		title += " · 空槽"
	_fabric_tint = Color.WHITE
	if slot == "weapon":
		if not ForgeArt.FORM_ICONS.has(form):
			form = "sword"
		var variant := posmod(String(derived.get("uid", "")).hash(), 3) if occupied else 0
		_icon = ForgeArt.weapon_icon(form, variant)
		if occupied:
			_fabric_tint = _tint.lerp(Color.WHITE, 0.65)
	else:
		# 不再分布衣、皮甲、链甲：图标的三种样子按这件装备轮换（跟兵器图标一样），空槽用第一种
		var variant := posmod(String(derived.get("uid", "")).hash(), 3) if occupied else 0
		_icon = ForgeArt.garment_icon(index - 1, ["cloth", "leather", "chain"][variant])
		if occupied:
			_fabric_tint = Appearance.garment_tint(slot, derived).lerp(Color.WHITE, 0.5)
	tooltip_text = title
	accessibility_name = title
	queue_redraw()

func _draw() -> void:
	if simple:
		_draw_item()
		return
	var compact := size.x <= 44.0
	var bounds := Rect2(Vector2.ZERO, size)
	draw_style_box(tile_plate(), bounds)
	if _icon != null:
		var inset := 2.0 if compact else 4.0
		_draw_icon(bounds.grow(-inset), Color(1, 1, 1, 1.0 if occupied else 0.18))
	if occupied:
		draw_style_box(_plate(Color.TRANSPARENT, 3, _edge, 2), bounds)
		var corner := 3.0 if compact else 5.0
		var stamp := 13.0 if compact else 19.0
		_draw_tag(_fortune, Rect2(size.x - corner - stamp, corner, stamp, stamp),
			FORTUNES.get(_fortune, PLATE), PLATE if _fortune == "旺" else INK, 9 if compact else 13)
		var tag_size := Vector2(22, 13) if compact else Vector2(34, 19)
		_draw_tag(_god, Rect2(Vector2(corner, size.y - tag_size.y - corner), tag_size),
			PLATE, _god_color, 9 if compact else 13)
		var radius := 3.0 if compact else 4.0
		var center := size - Vector2.ONE * (radius + corner + 2.0)
		draw_circle(center, radius + 2, PLATE, true, -1, true)
		draw_circle(center, radius, _tint, _polarity > 0.0, -1.0 if _polarity > 0.0 else 1.0, true)
		if is_zero_approx(_polarity):
			draw_circle(center, 1.0, _tint, true, -1, true)
	else:
		var a := Vector2.ONE
		var b := size - Vector2.ONE
		var edge := Color(BORDER, 0.30)
		for side in [Vector2(b.x, a.y), Vector2(a.x, b.y)]:
			draw_dashed_line(a, side, edge, 2.0, 5.0)
			draw_dashed_line(b, side, edge, 2.0, 5.0)
		var center := size * 0.5
		var arm := 5.0 if compact else 8.0
		draw_circle(center, arm + 4, Color(PLATE, 0.84), true, -1, true)
		draw_line(center - Vector2(arm, 0), center + Vector2(arm, 0), INK, 1.5, true)
		draw_line(center - Vector2(0, arm), center + Vector2(0, arm), INK, 1.5, true)
	if has_focus() or is_pressed():
		draw_style_box(_plate(Color.TRANSPARENT, 3, INK, 1), bounds.grow(-2.0))

func _draw_item() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	draw_style_box(tile_plate(), bounds)
	if highlighted or has_focus() or is_hovered():
		for inset in [3, 2, 1]:
			draw_rect(bounds.grow(-inset), Color(1, 0.66, 0.15, 0.8 / inset), false, inset, true)
	var title_height := 17.0 if not caption.is_empty() else 0.0
	var side := minf(size.y - title_height - 2, size.x - 6)
	if _icon:
		var origin := Vector2((size.x - side) / 2, title_height + (size.y - title_height - side) / 2)
		_draw_icon(Rect2(origin, Vector2.ONE * side), Color.WHITE if occupied else Color(0.76, 0.78, 0.73, 0.54))
	if not caption.is_empty():
		var tag := Rect2(1, 0, size.x - 2, title_height)
		draw_texture_rect(preload("res://art/piying/v4/button.png"), tag, false)
		draw_string(get_theme_default_font(), Vector2(0, 13), caption.left(5), HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, INK)

func _draw_icon(rect: Rect2, ink: Color) -> void:
	draw_texture_rect(_icon, rect, false, ink * _fabric_tint)

func _draw_tag(title: String, rect: Rect2, fill: Color, ink: Color, pixels: int) -> void:
	if title.is_empty():
		return
	draw_style_box(_plate(fill, 3), rect)
	var font := get_theme_default_font()
	var baseline := rect.get_center().y + (font.get_ascent(pixels) - font.get_descent(pixels)) * 0.5
	draw_string(font, Vector2(rect.position.x, baseline), title, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, pixels, ink)

func _plate(fill: Color, radius: int, edge: Color = Color.TRANSPARENT, width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style

static func tile_plate() -> ArtPlate:
	if _tile == null:
		_tile = ArtPlate.new()
		_tile.texture = preload("res://art/piying/v4/panel.png")
		_tile.corner_limit = 6
	return _tile
