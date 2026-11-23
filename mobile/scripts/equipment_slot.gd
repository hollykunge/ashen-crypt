extends Button

const Gear = preload("res://scripts/gear.gd")
const Roster = preload("res://scripts/roster.gd")
const ForgeArt = preload("res://scripts/forge_art.gd")
const HeldWeapon = preload("res://scripts/held_weapon.gd")
const WeaponDesign = preload("res://scripts/weapon_design.gd")
const Appearance = preload("res://scripts/appearance.gd")
const GearDesign = preload("res://scripts/gear_design.gd")

const GOOD := Color("#4f7045")
const BAD := Color("#a13f32")
const INK := Color("#302820")
const BORDER := Color("#9b7955")
const PLATE := Color("#ecddbe")
const FORTUNES := {
	"旺": Color("#b29251"), "相": Color("#557447"), "休": Color("#515b5a"),
	"囚": Color("#71362e"), "死": Color("#282a2c")
}
var occupied := false
var simple := false
var highlighted := false
var caption := ""
var _icon: Texture2D
var _fabric_tint := Color.WHITE
var _ink_icon: Texture2D
static var _ink_icons := {}
# 零件拼的兵器直接画在格子里；原画兵器仍用形制图标。
var _design := {}
var _gear := {}
var _form := ""
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
	var icon_index: int = Gear.Equipment.EMPTY_ICONS[index]
	if occupied:
		icon_index = ForgeArt.item_index(index, main, person.get("gender") == "female")
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
	# 兵器画零件拼成的那一件，其余四槽画按这件装备挑出的图标；空槽画同一套图的素样，淡淡一层。
	_design = {}
	_gear = {}
	_form = form if ForgeArt.FORM_ICONS.has(form) else "sword"
	_icon = ForgeArt.texture(icon_index)
	_ink_icon = null
	_fabric_tint = Gear.Pigments.GARMENT_DYES.get(derived.get("dye", "本色"), Color.WHITE) if slot in Gear.ARMOR_TYPE_SLOTS else Color.WHITE
	if slot in Gear.ARMOR_TYPE_SLOTS or (slot == "weapon" and _form == "sword"):
		var style: String = derived.get("armor_type", "cloth")
		var folder: String = {"leather": "set-leather", "chain": "set-mail"}.get(style, "parts")
		var part: String = {"armor": "torso", "gloves": "forearm", "greaves": "shin", "boots": "boot", "weapon": "weapon"}[slot]
		if slot == "weapon":
			folder = "parts"
		var path := "res://art/ink/hero/" + folder + "/" + part + ".png"
		if not _ink_icons.has(path):
			var texture := load(path) as Texture2D
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(texture.get_image().get_used_rect())
			_ink_icons[path] = atlas
		_ink_icon = _ink_icons[path]
	if slot == "weapon":
		_icon = ForgeArt.weapon_icon(_form)
		var design := WeaponDesign.pick(derived, _form, Appearance.amount_of(derived)) if occupied \
			else WeaponDesign.plain(_form)
		if not (WeaponDesign.painted_blade(design) and WeaponDesign.painted_head(design)):
			_design = design
	elif _ink_icon == null:
		var female: bool = person.get("gender") == "female"
		_gear = GearDesign.pick(derived, slot, female) if occupied else GearDesign.plain(slot, female)
	tooltip_text = title
	accessibility_name = title
	queue_redraw()

func _draw() -> void:
	if simple:
		_draw_item()
		return
	var compact := size.x <= 44.0
	var bounds := Rect2(Vector2.ZERO, size)
	draw_style_box(_plate(PLATE.lightened(0.08) if is_hovered() else PLATE, 3), bounds)
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
	var edge := _edge.darkened(0.30) if occupied else Color("#594b40")
	if highlighted or has_focus():
		edge = Color("#f0cf93")
	var fill := Color("#dfc9a2") if is_hovered() or highlighted else Color("#ecddbe")
	draw_rect(bounds, fill)
	var caption_size := 13 if size.x >= 70 else 11
	var art_height := size.y - (caption_size + 4.0 if not caption.is_empty() else 2.0)
	var side := minf(art_height, size.x - 4)
	if _icon:
		var rect := Rect2(Vector2((size.x - side) * 0.5, (art_height - side) * 0.5 + 1), Vector2.ONE * side)
		_draw_icon(rect, Color.WHITE if occupied else Color(0.72, 0.68, 0.62, 0.34))
	draw_rect(bounds.grow(-0.5), edge, false, 1)
	if occupied:
		draw_line(Vector2(2, 1.5), Vector2(size.x - 2, 1.5), _edge, 2)
	if highlighted:
		draw_rect(bounds.grow(-2.5), edge, false, 1)
	if not caption.is_empty():
		draw_string(get_theme_default_font(), Vector2(0, size.y - 3), (caption.left(4) + "…" if caption.length() > 5 else caption),
			HORIZONTAL_ALIGNMENT_CENTER, size.x, caption_size, INK if occupied else Color("#b6a492"))

func _draw_icon(rect: Rect2, ink: Color) -> void:
	if _ink_icon != null:
		var factor := minf(rect.size.x / _ink_icon.get_width(), rect.size.y / _ink_icon.get_height()) * 0.90
		var size := _ink_icon.get_size() * factor
		draw_texture_rect(_ink_icon, Rect2(rect.get_center() - size * 0.5, size), false, ink * _fabric_tint)
		return
	if not _gear.is_empty():
		GearDesign.draw(self, _gear, rect.grow(-rect.size.x * 0.04), ink)
		return
	# 兵器图标和装备图标一样提亮一点，做旧的铁在暗色格子里才看得清。
	var lifted := Color(ink.r * GearDesign.LIFT, ink.g * GearDesign.LIFT, ink.b * GearDesign.LIFT, ink.a)
	if not _design.is_empty() and HeldWeapon.draw_icon(self, _form, _design, rect.grow(-rect.size.x * 0.06), lifted):
		return
	draw_texture_rect(_icon, rect, false, ink)

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
