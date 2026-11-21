extends VBoxContainer

signal journey_requested
signal back_requested

const Gear = preload("res://scripts/gear.gd")
const Loadout = preload("res://scripts/loadout.gd")
const Roster = preload("res://scripts/roster.gd")
const WuXing = preload("res://scripts/rules/wuxing.gd")
const PORTRAIT_LIGHT = preload("res://scripts/portrait_light.gdshader")
const SideArt = preload("res://scripts/side_art.gd")
const GOOD := Color("#b0d193")
const BAD := Color("#ffaca0")
const PAGES := ["性别", "日干", "月令", "时辰", "出身"]
const TALENTS := [
	["炉温 +1", "初始炉温提高一档"], ["投料格 +1", "初始投料格多一格"],
	["硬木护甲", "开局得到一件硬木护甲"], ["材料 +10%", "材料掉落概率提高 10%"],
	["开局可转阴", "解锁转阴，向阴形偏移"], ["开局可调和", "解锁调和，化相克为反应"],
	["开局可转阳", "解锁转阳，向阳形偏移"], ["返还 +20%", "残渣返还提高 20%"],
	["开局可精锻", "解锁精锻，锻造数值稳定"], ["暴击 +3%", "暴击率提高 3%"],
	["生命 +10%", "初始生命提高 10%"], ["开局可轮转", "解锁五行轮转，沿相生换行"]
]
const ORIGIN_NOTES := {
	"official": ["随侍随本层地气增减 · 每境界可领俸禄", "攻击 −30%、生命 −10% · 财气之层孤身"],
	"merchant": ["开局拥有 2000 灵砂", "生命 −10% · 材料掉落 −25%"],
	"commoner": ["生命 +20% · 身强度收敛，更易成均衡、太极", "攻击 −15% · 开局无物资"],
	"pauper": ["攻击 +25% · 残渣全返，轮转不添磨损", "生命 −20% · 无灵砂掉落及随侍"]
}
const CATALOG_DUTIES := [
	"巡守山门 · 主持木劫", "传授军略 · 主持土劫", "巡查云路 · 主持金劫",
	"往来传敕 · 主持水劫", "执掌雷令 · 主持火劫", "协理雷部 · 随劫监护"
]

var ui
var profile: Gear
var draft := {"gender": "male", "day_stem": "geng", "month_branch": "mao", "hour_branch": "si", "origin": "pauper"}
var creator: VBoxContainer
var gallery: VBoxContainer
var portrait: TextureRect
var portrait_frame: PortraitFrame
var portrait_tag: Label
var reading: Label
var helpful: Label
var unhelpful: Label
var talent_summary: Label
var origin_good: Label
var origin_bad: Label
var error: Label
var name_field: LineEdit
var page_area: PanelContainer
var pages: Array[VBoxContainer] = []
var tabs: Array[Button] = []
var choice_buttons := {}
var current_page := 1
var swipe_pointer := -2
var swipe_origin := Vector2.ZERO

func _ready() -> void:
	creator = ui._vbox(6)
	creator.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(creator)
	_build_creator()
	gallery = ui._vbox(8)
	gallery.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(gallery)
	_build_gallery()
	gallery.hide()

func show_home() -> void:
	gallery.hide()
	creator.show()
	error.hide()
	_refresh_creator()

# 每次从选角页进来都是一张新命籍：道号清空，回到日干页。
func start_new() -> void:
	name_field.text = ""
	_show_page(1)
	show_home()

func _build_creator() -> void:
	_header(creator, "立下命籍", "昆仑山门", true, true)
	_build_portrait()

	var tab_row: HBoxContainer = ui._hbox(4)
	creator.add_child(tab_row)
	for index in range(PAGES.size()):
		var tab := _button(PAGES[index], 37, _show_page.bind(index))
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_row.add_child(tab)
		tabs.append(tab)

	page_area = PanelContainer.new()
	page_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_area.add_theme_stylebox_override("panel", ui._box(Color(ui.NIGHT, 0.96), ui.BORDER, 1, 9))
	creator.add_child(page_area)
	var scroller := ScrollContainer.new()
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page_area.add_child(scroller)
	var content: VBoxContainer = ui._vbox(0)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroller.add_child(content)
	for index in range(PAGES.size()):
		var page: VBoxContainer = ui._vbox(7)
		page.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(page)
		pages.append(page)

	var gender := _grid(pages[0], 2)
	_add_choice(gender, "gender", "male", "男", 94)
	_add_choice(gender, "gender", "female", "女", 94)

	var days := _grid(pages[1], 5)
	for index in range(WuXing.STEMS.size()):
		var stem: String = WuXing.STEMS[index]
		var element := WuXing.stem_element(stem)
		var polarity := "阳" if WuXing.stem_polarity(stem) > 0 else "阴"
		var button := _add_choice(days, "day_stem", stem,
			"%s\n%s%s" % [WuXing.STEM_NAMES[index], polarity, WuXing.ELEMENT_NAMES[element]], 62)
		button.add_theme_font_size_override("font_size", 17)

	var months := _grid(pages[2], 4)
	for id in WuXing.BRANCH_ORDER:
		var branch: Dictionary = WuXing.BRANCHES[id]
		_add_choice(months, "month_branch", id, "%s月 · %s" % [branch.name, WuXing.ELEMENT_NAMES[branch.element]], 43)

	pages[3].add_child(_text("选你的时辰", 16, ui.GOLD))
	var hours := _grid(pages[3], 3)
	for index in range(WuXing.BRANCH_ORDER.size()):
		var id: String = WuXing.BRANCH_ORDER[index]
		var branch: Dictionary = WuXing.BRANCHES[id]
		var button := _add_choice(hours, "hour_branch", id, "%s · %s" % [branch.name, TALENTS[index][0]], 36)
		button.tooltip_text = "%02d:00–%02d:00 · %s" % [branch.hours[0], branch.hours[1], TALENTS[index][1]]

	var origins := _grid(pages[4], 2)
	for id in Gear.Origins.ORIGINS:
		_add_choice(origins, "origin", id, Gear.Origins.ORIGINS[id].name, 44)
	origin_good = _text("", 13, GOOD)
	origin_bad = _text("", 13, BAD)
	pages[4].add_child(origin_good)
	pages[4].add_child(origin_bad)

	error = _text("", 12, BAD)
	error.hide()
	creator.add_child(error)
	name_field = LineEdit.new()
	name_field.placeholder_text = "道号（可不填，最多 %d 字）" % Gear.NAME_LIMIT
	name_field.max_length = Gear.NAME_LIMIT
	name_field.custom_minimum_size.y = 40
	name_field.add_theme_font_size_override("font_size", 15)
	name_field.add_theme_color_override("font_color", ui.INK)
	name_field.add_theme_color_override("font_placeholder_color", ui.MUTED)
	name_field.add_theme_stylebox_override("normal", ui._box(Color(ui.NIGHT, 0.96), ui.BORDER, 1, 9))
	name_field.add_theme_stylebox_override("focus", ui._box(Color(ui.NIGHT, 0.96), ui.GOLD, 1, 9))
	creator.add_child(name_field)
	var commit := _button("入山", 50, _create)
	commit.add_theme_font_override("font", ui.HEADING_FONT)
	commit.add_theme_font_size_override("font_size", 23)
	ui._restyle(commit, true)
	creator.add_child(commit)
	_show_page(current_page)
	_refresh_creator()

func _build_portrait() -> void:
	var frame := Control.new()
	frame.custom_minimum_size.y = 360
	frame.clip_contents = true
	creator.add_child(frame)
	var backing := Panel.new()
	backing.add_theme_stylebox_override("panel", ui._box(Color("#181617a8"), ui.BORDER, 1, 0))
	ui._fill(backing)
	frame.add_child(backing)

	portrait = ui._image(SideArt.PORTRAITS[0])
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ui._fill(portrait)
	portrait.offset_left = 12.0
	portrait.offset_right = -12.0
	portrait.offset_top = 6.0
	portrait.offset_bottom = -7.0
	var material := ShaderMaterial.new()
	material.shader = PORTRAIT_LIGHT
	material.set_shader_parameter("soften_edges", true)
	portrait.material = material
	frame.add_child(portrait)

	portrait_frame = PortraitFrame.new()
	ui._fill(portrait_frame)
	frame.add_child(portrait_frame)

	portrait_tag = _text("", 17, ui.INK)
	portrait_tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	portrait_tag.position = Vector2(16, 12)
	portrait_tag.add_theme_constant_override("outline_size", 7)
	portrait_tag.add_theme_color_override("font_outline_color", ui.NIGHT)
	frame.add_child(portrait_tag)

	var summary := PanelContainer.new()
	summary.add_theme_stylebox_override("panel", ui._box(Color(ui.NIGHT, 0.94), ui.BORDER, 1, 8))
	frame.add_child(summary)
	summary.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	summary.offset_left = 8
	summary.offset_right = -8
	summary.offset_top = -99
	summary.offset_bottom = -8
	var labels: VBoxContainer = ui._vbox(1)
	summary.add_child(labels)
	reading = _text("", 14, ui.INK)
	helpful = _text("", 12, GOOD)
	unhelpful = _text("", 12, BAD)
	talent_summary = _text("", 12, ui.GOLD)
	talent_summary.autowrap_mode = TextServer.AUTOWRAP_OFF
	for label in [reading, helpful, unhelpful, talent_summary]:
		labels.add_child(label)

func _show_page(index: int) -> void:
	current_page = index
	for i in range(pages.size()):
		pages[i].visible = i == index
		ui._restyle(tabs[i], i == index)

func _input(event: InputEvent) -> void:
	if not is_instance_valid(page_area) or not creator.is_visible_in_tree():
		swipe_pointer = -2
		return
	if event is InputEventScreenTouch:
		_swipe_event(event.index, event.position, event.pressed and not event.canceled)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		_swipe_event(-1, event.position, event.pressed)

func _swipe_event(pointer: int, point: Vector2, pressed: bool) -> void:
	if pressed and page_area.get_global_rect().has_point(point):
		swipe_pointer = pointer
		swipe_origin = point
	elif not pressed and swipe_pointer == pointer:
		swipe_pointer = -2
		var gap := point - swipe_origin
		if absf(gap.x) >= 47.0 and absf(gap.x) >= absf(gap.y) * 1.20:
			_show_page(clampi(current_page + (1 if gap.x < 0 else -1), 0, PAGES.size() - 1))
			get_viewport().set_input_as_handled()

func _add_choice(parent: Control, field: String, id: String, label: String, height: int) -> Button:
	var button := _button(label, height, _choose.bind(field, id))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	if not choice_buttons.has(field):
		choice_buttons[field] = {}
	choice_buttons[field][id] = button
	return button

func _choose(field: String, id: String) -> void:
	draft[field] = id
	_refresh_creator()

func _refresh_creator() -> void:
	for field in choice_buttons:
		for id in choice_buttons[field]:
			ui._restyle(choice_buttons[field][id], draft[field] == id)
	var day_element := WuXing.stem_element(draft.day_stem)
	var female: bool = draft.gender == "female"
	portrait.texture = SideArt.PORTRAITS[int(female)]
	portrait.modulate = Roster.ELEMENT_TINTS[day_element].lerp(Color.WHITE, 0.67)
	portrait_frame.tint = Roster.ELEMENT_GLOW[day_element].lerp(ui.GOLD, 0.68)
	portrait_frame.queue_redraw()
	portrait_tag.text = "%s · %s%s" % [Gear.stem_name(draft.day_stem),
		"阳" if WuXing.stem_polarity(draft.day_stem) > 0 else "阴", WuXing.ELEMENT_NAMES[day_element]]
	origin_good.text = "所得  " + ORIGIN_NOTES[draft.origin][0]
	origin_bad.text = "所限  " + ORIGIN_NOTES[draft.origin][1]
	var s := Loadout.strength(draft)
	var tier := "中和"
	if absf(s) >= 0.85:
		tier = "极强" if s > 0.0 else "极弱"
	elif absf(s) > 0.15:
		tier = "偏强" if s > 0.0 else "偏弱"
	reading.text = "身强度 %+.2f · %s" % [s, tier]
	var favorable := PackedStringArray()
	var unfavorable := PackedStringArray()
	for element in WuXing.WUXING:
		var group := Gear.Bazi.element_group(day_element, element)
		var fit := Loadout.fit_group(draft.day_stem, element, s)
		var term := "%s%s" % [WuXing.ELEMENT_NAMES[element], Loadout.GROUP_NAMES[group]]
		if fit > 0:
			favorable.append(term)
		elif fit < 0:
			unfavorable.append(term)
	helpful.text = "用神  " + (" · ".join(favorable) if not favorable.is_empty() else "五行皆可")
	unhelpful.text = "忌神  " + (" · ".join(unfavorable) if not unfavorable.is_empty() else "—")
	var hour_index := WuXing.BRANCH_ORDER.find(draft.hour_branch)
	talent_summary.text = "%s时天赋  ·  %s" % [WuXing.BRANCHES[draft.hour_branch].name, TALENTS[hour_index][1]]

func _create() -> void:
	var named := draft.duplicate()
	named.name = name_field.text
	if profile.create_character(named):
		journey_requested.emit()
	else:
		error.text = profile.storage_error if not profile.storage_error.is_empty() else "无法立下命籍"
		error.show()

class PortraitFrame extends Control:
	var tint := Color("#c4a582")

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var corner := PackedVector2Array([Vector2(0, 17), Vector2.ZERO, Vector2(23, 0),
			Vector2(23, 4), Vector2(5, 4), Vector2(5, 12)])
		for sign_x in [1.0, -1.0]:
			var origin := Vector2(5.0 if sign_x > 0.0 else size.x - 5.0, 5.0)
			draw_set_transform(origin, 0.0, Vector2(sign_x, 1.0))
			draw_polyline(corner, Color(tint, 0.76), 1.0, true)


func _header(parent: VBoxContainer, title: String, subtitle: String, catalog: bool = true, back: bool = false) -> void:
	var row: HBoxContainer = ui._hbox(6)
	parent.add_child(row)
	if back:
		var leave := _button("返回", 39, func() -> void: back_requested.emit())
		leave.custom_minimum_size.x = 56.0
		row.add_child(leave)
	var stack: VBoxContainer = ui._vbox(0)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(stack)
	var upper := _text(subtitle, 12, ui.GOLD)
	stack.add_child(upper)
	var nameplate := _text(title, 34, ui.INK)
	nameplate.add_theme_font_override("font", ui.HEADING_FONT)
	nameplate.add_theme_color_override("font_outline_color", ui.NIGHT)
	nameplate.add_theme_constant_override("outline_size", 6)
	stack.add_child(nameplate)
	if catalog:
		row.add_child(_button("仙班名录", 39, _show_gallery))
		row.add_child(ui._sound_button())

func _show_gallery() -> void:
	creator.hide()
	gallery.show()

func _build_gallery() -> void:
	_header(gallery, "仙班名录", "敕令来源与天劫主持者", false)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gallery.add_child(scroll)
	var list := GridContainer.new()
	list.columns = 2
	list.add_theme_constant_override("h_separation", 8)
	list.add_theme_constant_override("v_separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var gallery_light := ShaderMaterial.new()
	gallery_light.shader = PORTRAIT_LIGHT
	for i in range(Roster.NAMES.size()):
		var entry := _card(list)
		var frame: Control = entry.get_parent()
		frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var art: TextureRect = ui._image(Roster.PORTRAITS[i])
		art.material = gallery_light
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.custom_minimum_size.y = 146
		entry.add_child(art)
		entry.add_child(_text(Roster.NAMES[i], 17, ui.GOLD))
		entry.add_child(_text(CATALOG_DUTIES[i], 12, ui.INK))
	gallery.add_child(_button("返回", 44, show_home))

func _grid(parent: Node, columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(grid)
	return grid

func _card(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ui._box(Color(ui.NIGHT, 0.94), ui.BORDER, 1, 10))
	parent.add_child(panel)
	var box: VBoxContainer = ui._vbox(4)
	panel.add_child(box)
	return box

func _button(text: String, height: int, callback: Callable) -> Button:
	var button: Button = ui._button(text, false, height)
	button.add_theme_font_size_override("font_size", 13 if height < 47 else 17)
	button.pressed.connect(callback)
	return button

func _text(text: String, pixels: int, color: Color) -> Label:
	var label: Label = ui._label(text, pixels, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
