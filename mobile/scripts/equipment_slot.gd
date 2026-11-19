extends Button

const Gear = preload("res://scripts/gear.gd")
const Roster = preload("res://scripts/roster.gd")
const ForgeArt = preload("res://scripts/forge_art.gd")

const GOOD := Color("#b0d193")
const BAD := Color("#ffaca0")
const INK := Color("#eee3cf")
const BORDER := Color("#98825c")
const PLATE := Color("#071716")
const FORTUNES := {
	"旺": Color("#b29251"), "相": Color("#557447"), "休": Color("#515b5a"),
	"囚": Color("#71362e"), "死": Color("#282a2c")
}
# 需要区分男女式样时使用 [男, 女]。每行依次为武器、护甲、护手、项链、戒指、鞋子。
const ICONS := {
	"jin": [[10, 12], 7, 17, 26, 23, 20],
	"mu": [11, 15, 18, 29, 24, 21],
	"huo": [9, [4, 15], 17, [26, 27], 25, 19],
	"shui": [13, 16, 18, [5, 29], 24, [21, 22]],
	"tu": [[10, 12], 4, 17, 5, 24, [20, 22]]
}

var occupied := false
var _icon: Texture2D
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

func display(slot: String, derived: Dictionary, person: Dictionary) -> void:
	var index := Gear.SLOTS.find(slot)
	var title: String = Gear.SLOT_NAMES[index]
	var main := Gear.Loadout.dominant(derived.get("wuxing", {}))
	occupied = not main.is_empty()
	var icon_index: int = Gear.Equipment.EMPTY_ICONS[index]
	if occupied:
		var variant: Variant = ICONS[main][index]
		icon_index = variant[int(person.get("gender") == "female")] if variant is Array else variant
		_polarity = derived.yin_yang
		_edge = Roster.ELEMENT_GLOW[main]
		_tint = Roster.ELEMENT_TINTS[main]
		_fortune = derived.jingyu.get(main, "")
		var day_stem: String = person.day_stem
		var stem := Gear.WuXing.stem_for(main, _polarity)
		_god = Gear.Bazi.GOD_EFFECTS[Gear.Bazi.ten_god(day_stem, stem)].name
		var fit := Gear.Loadout.fit_group(day_stem, main, Gear.Loadout.strength(person))
		_god_color = GOOD if fit > 0 else (BAD if fit < 0 else INK)
		title += " · %s · %s%s · 阴阳 %+.2f · 查看推导" % [derived.name, _fortune, _god, _polarity]
	else:
		title += " · 去投料打造"
	_icon = ForgeArt.texture(icon_index)
	tooltip_text = title
	accessibility_name = title
	queue_redraw()

func _draw() -> void:
	var compact := size.x <= 44.0
	var bounds := Rect2(Vector2.ZERO, size)
	draw_style_box(_plate(PLATE.lightened(0.08) if is_hovered() else PLATE, 3), bounds)
	if _icon != null:
		var inset := 2.0 if compact else 4.0
		draw_texture_rect(_icon, bounds.grow(-inset), false, Color(1, 1, 1, 1.0 if occupied else 0.18))
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
