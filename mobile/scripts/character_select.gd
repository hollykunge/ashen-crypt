extends VBoxContainer

# 列仙图录：三个角色位。有人的格子能「入山」或删掉，空格子「立下命籍」去创角。

signal play_requested(slot: int)
signal create_requested(slot: int)
signal back_requested

const Gear = preload("res://scripts/gear.gd")
const Roster = preload("res://scripts/roster.gd")
const SideArt = preload("res://scripts/side_art.gd")
const WuXing = preload("res://scripts/rules/wuxing.gd")

var ui
var save_base := Gear.SAVE_PATH
var list: GridContainer
var wide := false
var notice: Label
# 删人要按两下：第一下把按钮换成「确认删除」，再按才删。
var armed_delete := -1

func build(main) -> void:
	ui = main
	add_theme_constant_override("separation", 10)
	var row: HBoxContainer = ui._hbox(10)
	var panel := PanelContainer.new()
	var backing: ArtPlate = ui.paper_box(0.98, 0)
	backing.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", backing)
	add_child(panel)
	panel.add_child(row)
	var back: Button = ui._icon_button(&"back", "返回", false, Vector2(48, 48))
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: back_requested.emit())
	row.add_child(back)
	var stack: VBoxContainer = ui._vbox(2)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(stack)
	var nameplate: Label = ui._label("列仙图录", 22, ui.INK)
	ui.heading_plate(nameplate)
	nameplate.custom_minimum_size = Vector2(150, 35)
	nameplate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(nameplate)
	var subtitle: Label = ui._label("择一人入山 · 最多 %d 位" % Gear.MAX_CHARACTERS, 12, ui.GOLD)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(subtitle)
	var sound: Button = ui._sound_button()
	sound.custom_minimum_size = back.custom_minimum_size
	sound.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sound)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	list = GridContainer.new()
	list.add_theme_constant_override("h_separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	notice = ui._label("", 12, Color("#ff9a79"))
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.hide()
	add_child(notice)
	resized.connect(_fit_cards)

func _fit_cards() -> void:
	var landscape := size.x >= size.y * 1.17
	if landscape != wide:
		wide = landscape
		list.columns = 3 if wide else 1
		refresh()
	list.add_theme_constant_override("v_separation", clampi(roundi(size.y * 0.025), 8, 24))
	for card in list.get_children():
		card.custom_minimum_size.y = _card_height()

func _card_height() -> float:
	return minf(228, size.y * 0.58) if wide else clampf(size.y * 0.194, 126, 200)

func refresh() -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for slot in range(Gear.MAX_CHARACTERS):
		var profile = Gear.peek(slot, save_base)
		if profile.has_character():
			_person_card(slot, profile)
		elif profile.storage_error.is_empty():
			_empty_card(slot)
		else:
			_broken_card(slot, profile.storage_error)

func count() -> int:
	var total := 0
	for slot in range(Gear.MAX_CHARACTERS):
		if Gear.peek(slot, save_base).has_character():
			total += 1
	return total

func show_error(text: String) -> void:
	notice.text = text
	notice.visible = not text.is_empty()

# 每一格使用云头框，空位降低透明度。


func _frame(faint := false) -> BoxContainer:
	var panel := PanelContainer.new()
	var paper: ArtPlate = ui.paper_box(0.62 if faint else 1.0, 8)
	panel.add_theme_stylebox_override("panel", paper)
	panel.custom_minimum_size.y = _card_height()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(panel)
	var row: BoxContainer = ui._vbox(8) if wide else ui._hbox(7)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)
	return row

func _person_card(slot: int, profile) -> void:
	var row := _frame()
	var identity: BoxContainer = ui._hbox(6) if wide else row
	if wide:
		row.add_child(identity)
	var person: Dictionary = profile.character()
	var female: bool = person.get("gender") == "female"
	var stem := String(person.get("day_stem", "geng"))
	var element := WuXing.stem_element(stem)
	# 头像垫一圈镂空皮饰。
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(54, 74) if wide else Vector2(64, 90)
	identity.add_child(holder)
	var face: TextureRect = ui._image(SideArt.portrait(person.get("gender", "")))
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	holder.add_child(face)
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var facts: VBoxContainer = ui._vbox(3)
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facts.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_child(facts)
	var title: HBoxContainer = ui._hbox(8)
	facts.add_child(title)
	title.add_child(ui._label(profile.display_name(), 18, ui.INK))
	var seal := Seal.new()
	seal.text = Gear.stem_name(stem)
	seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.add_child(seal)
	# 卡片窄，信息拆成几行短句，不折行（太长就截断）
	facts.add_child(_fact("%s · %s · %s" % ["女" if female else "男", Gear.fate_caption(stem),
		String(profile.origin().get("name", ""))], ui.GOLD))
	facts.add_child(_fact("%s · 第 %d 层" % [profile.realm().name, profile.layer()], ui.MUTED))
	var seen: float = profile.last_seen()
	facts.add_child(_fact("%s%s" % [String(profile.place().get("name", "")), " · " + _ago(seen) if seen > 0.0 else ""], ui.MUTED))
	facts.add_child(_fact("灵砂 %d" % profile.silver(), ui.MUTED))

	var actions: VBoxContainer = ui._vbox(4)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(actions)
	var play: Button = ui._button("入山", true, 37)
	play.custom_minimum_size.x = 96.0
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.add_theme_font_size_override("font_size", 18)
	play.pressed.connect(_play.bind(slot))
	actions.add_child(play)
	actions.add_child(_delete_button(slot))

func _empty_card(slot: int) -> void:
	var row := _frame(true)
	var facts: VBoxContainer = ui._vbox(3)
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facts.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(facts)
	facts.add_child(ui._label("虚位以待 · 第 %d 格" % (slot + 1), 17, ui.MUTED))
	facts.add_child(_line("择性别、日干、月令、时辰与出身，立一位新人。", Color(ui.MUTED, 0.85)))
	var create: Button = ui._button("创建角色", true, 37)
	create.custom_minimum_size.x = 100.0
	create.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	create.add_theme_font_size_override("font_size", 16)
	create.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	create.pressed.connect(_create.bind(slot))
	row.add_child(create)

func _broken_card(slot: int, error: String) -> void:
	var row := _frame(true)
	var facts: VBoxContainer = ui._vbox(3)
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facts.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(facts)
	facts.add_child(ui._label("第 %d 格 · %s" % [slot + 1, error], 18, Color("#ff9a79")))
	facts.add_child(_line("这份存档读不出来。删掉之后这一格可以重新创角。", ui.MUTED))
	var actions: VBoxContainer = ui._vbox(6)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(actions)
	actions.add_child(_delete_button(slot))

## 名字旁的一方朱砂印，印文是日干
class Seal extends Control:
	var text := ""

	func _init() -> void:
		custom_minimum_size = Vector2(24, 24)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var red := Color("#b8321f")
		draw_rect(Rect2(Vector2.ZERO, size), red, true)
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color("#dfb268"), false, 1.0)
		var font := get_theme_default_font()
		var pixels := int(size.y * 0.66)
		var base := size.y * 0.5 + (font.get_ascent(pixels) - font.get_descent(pixels)) * 0.5
		draw_string(font, Vector2(0, base), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, pixels, Color("#f1dfb4"))

func _delete_button(slot: int) -> Button:
	var armed := armed_delete == slot
	# 删除操作确认时标红。
	var remove := Button.new()
	remove.text = "确认删除" if armed else "删除"
	remove.flat = true
	remove.focus_mode = Control.FOCUS_NONE
	remove.custom_minimum_size = Vector2(76, 30)
	remove.add_theme_font_size_override("font_size", 13)
	var ink: Color = Color("#ff9a79") if armed else ui.MUTED
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		remove.add_theme_color_override(color_name, ink)
	remove.pressed.connect(_delete.bind(slot))
	return remove

func _fact(text: String, color: Color) -> Label:
	var label: Label = ui._label(text, 12, color)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size.x = 40.0
	return label

func _line(text: String, color: Color) -> Label:
	var label: Label = ui._label(text, 13, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _play(slot: int) -> void:
	armed_delete = -1
	play_requested.emit(slot)

func _create(slot: int) -> void:
	armed_delete = -1
	create_requested.emit(slot)

func _delete(slot: int) -> void:
	if armed_delete != slot:
		armed_delete = slot
		show_error("再按一次「确认删除」：角色、装备和材料都会删掉，不能恢复。")
		refresh()
		return
	armed_delete = -1
	if Gear.delete_slot(slot, save_base):
		show_error("")
	else:
		show_error("删除失败，请稍后再试")
	refresh()

static func _ago(seen: float) -> String:
	var gap := maxf(0.0, Time.get_unix_time_from_system() - seen)
	if gap < 60.0:
		return "刚刚在线"
	if gap < 3600.0:
		return "%d 分钟前" % floori(gap / 60.0)
	if gap < 86400.0:
		return "%d 小时前" % floori(gap / 3600.0)
	return "%d 天前" % floori(gap / 86400.0)
