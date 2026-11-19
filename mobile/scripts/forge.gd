extends VBoxContainer

signal close_requested

const Gear = preload("res://scripts/gear.gd")
const Equipment = preload("res://scripts/equipment.gd")
const Art = preload("res://scripts/forge_art.gd")
const BRASS := Color("#cfb280")
const LIGHT := Color("#eee4d2")
const MUTED := Color("#b7a99b")
const DANGER := Color("#f0a196")

var ui
var profile: Gear
var recipes: Array[Button] = []
var class_buttons: Array[Button] = []
var visible_recipes: Array[Dictionary] = []
var slot_buttons: Array[Button] = []
var slot_icons: Array[TextureRect] = []
var slot_titles: Array[Label] = []
var set_summary: Label
var recipe_header: Label
var recipe_grid: GridContainer
var stock_labels: Array[Label] = []
var detail_icon: TextureRect
var detail_name: Label
var detail_stat: Label
var detail_trait: Label
var detail_affix: Label
var set_name: Label
var set_two: Label
var set_three: Label
var cost_row: HBoxContainer
var status: Label
var action: Button
var selected := 0
var active_slot := 0
var role := 0
var confirmation := ""

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var header: HBoxContainer = ui._hbox(12)
	var back: Button = ui._icon_button(&"back", "返回", false, Vector2(46, 46))
	back.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(back)
	var title: Label = ui._label("墓火锻造", 29, LIGHT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color("#1b120e"))
	title.add_theme_constant_override("outline_size", 7)
	header.add_child(title)
	var balance := Control.new()
	balance.custom_minimum_size.x = 46
	header.add_child(balance)
	add_child(header)
	var scene_gap: Control = ui._space(0)
	scene_gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scene_gap)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 4.0
	scroll.custom_minimum_size.y = 520.0
	add_child(scroll)
	var stack: VBoxContainer = ui._vbox(10)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(stack)

	var stock: HBoxContainer = _tray(stack, 6, Color("#211b16f5"))
	for material in Gear.MATERIALS:
		var entry: HBoxContainer = ui._hbox(4)
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.alignment = BoxContainer.ALIGNMENT_CENTER
		entry.add_child(_icon(material.icon, 26))
		var value: Label = ui._label("", 13, LIGHT)
		stock_labels.append(value)
		entry.add_child(value)
		stock.add_child(entry)

	var classes: HBoxContainer = ui._hbox(6)
	stack.add_child(classes)
	for index in range(Gear.CLASSES.size()):
		var tab: Button = ui._button(Gear.CLASSES[index], false, 44.0)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(open_role.bind(index))
		classes.add_child(tab)
		class_buttons.append(tab)

	var loadout := GridContainer.new()
	loadout.columns = 3
	loadout.add_theme_constant_override("h_separation", 6)
	loadout.add_theme_constant_override("v_separation", 6)
	stack.add_child(loadout)
	for i in range(Gear.SLOTS.size()):
		var button: Button = ui._button("", false, 54)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_choose_slot.bind(i))
		loadout.add_child(button)
		slot_buttons.append(button)
		var slot: HBoxContainer = ui._hbox(5)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(slot)
		slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.offset_left = 6.0
		slot.offset_right = -4.0
		var icon := _icon(-1, 27)
		slot_icons.append(icon)
		slot.add_child(icon)
		var labels: VBoxContainer = ui._vbox(0)
		labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		labels.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(labels)
		labels.add_child(ui._label(Equipment.SLOT_NAMES[i], 11, BRASS))
		var name_label: Label = ui._label("", 11, LIGHT)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		slot_titles.append(name_label)
		labels.add_child(name_label)

	set_summary = ui._label("", 12, Color("#cfdaa3"))
	set_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(set_summary)
	recipe_header = ui._label("", 15, BRASS)
	stack.add_child(recipe_header)
	recipe_grid = GridContainer.new()
	recipe_grid.add_theme_constant_override("h_separation", 6)
	stack.add_child(recipe_grid)
	for index in range(Gear.recipes_for(0, "armor").size()):
		var tile: Button = ui._button("", false, 70)
		tile.add_theme_font_size_override("font_size", 13)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.pressed.connect(_select.bind(index))
		recipe_grid.add_child(tile)
		var portrait := _icon(-1, 44)
		tile.add_child(portrait)
		portrait.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		portrait.offset_left = -22
		portrait.offset_right = 22
		portrait.offset_top = 3
		portrait.offset_bottom = 47
		recipes.append(tile)

	var sheet: HBoxContainer = _tray(stack, 10, Color("#231b17fa"))
	var details: VBoxContainer = ui._vbox(5)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet.add_child(details)
	var identity: HBoxContainer = ui._hbox(8)
	details.add_child(identity)
	detail_icon = _icon(-1, 42)
	identity.add_child(detail_icon)
	var names: VBoxContainer = ui._vbox(0)
	identity.add_child(names)
	detail_name = ui._label("", 19, LIGHT)
	names.add_child(detail_name)
	detail_stat = ui._label("", 13, BRASS)
	detail_stat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(detail_stat)
	detail_trait = ui._label("", 12, MUTED)
	detail_trait.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(detail_trait)
	detail_affix = ui._label("", 12, Color("#b9d4f4"))
	detail_affix.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(detail_affix)
	set_name = ui._label("", 12, LIGHT)
	details.add_child(set_name)
	set_two = ui._label("", 12, MUTED)
	set_two.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(set_two)
	set_three = ui._label("", 12, MUTED)
	set_three.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(set_three)
	cost_row = ui._hbox(8)
	details.add_child(cost_row)
	status = ui._label("", 13, MUTED)
	details.add_child(status)
	action = ui._icon_button(&"hammer", "打造", true, Vector2(51, 51))
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	action.pressed.connect(_activate)
	sheet.add_child(action)
	open_role(0)

func open_role(index: int) -> void:
	role = index
	for i in range(class_buttons.size()):
		ui._restyle(class_buttons[i], i == role)
	_choose_slot(0)

func _choose_slot(index: int) -> void:
	active_slot = index
	var slot: String = Gear.SLOTS[index]
	visible_recipes = Gear.recipes_for(role, slot)
	recipe_grid.columns = visible_recipes.size()
	selected = 0
	var current := profile.equipped(slot, role)
	for i in range(visible_recipes.size()):
		if visible_recipes[i].id == current:
			selected = i
			break
	confirmation = ""
	refresh()

func refresh() -> void:
	for i in range(Gear.MATERIALS.size()):
		var material: Dictionary = Gear.MATERIALS[i]
		stock_labels[i].text = "%s %d" % [material.name, profile.stock(material.id)]
	for i in range(Gear.SLOTS.size()):
		var item := Gear.recipe(profile.equipped(Gear.SLOTS[i], role))
		slot_icons[i].texture = Art.texture(item.get("icon", 9 + role * 2 if i == 0 else Equipment.EMPTY_ICONS[i]))
		slot_icons[i].modulate.a = 0.32 if item.is_empty() else 1.0
		var empty_name: String = Gear.DEFAULT_WEAPON_NAMES[role] if i == 0 else "空"
		slot_titles[i].text = empty_name if item.is_empty() else item.name
		ui._restyle(slot_buttons[i], i == active_slot)
		ui._describe(slot_buttons[i], Equipment.SLOT_NAMES[i] + " · " + slot_titles[i].text)
	var counts := profile.set_counts(role)
	var active := PackedStringArray()
	for family in Equipment.SETS:
		var pieces: int = counts.get(family, 0)
		if pieces >= 2:
			active.append("%s %d 件" % [Equipment.SETS[family].name, pieces])
	set_summary.text = " · ".join(active)
	set_summary.visible = not active.is_empty()
	recipe_header.text = Equipment.SLOT_NAMES[active_slot] + "图纸"
	for i in range(recipes.size()):
		var tile := recipes[i]
		tile.visible = i < visible_recipes.size()
		if not tile.visible:
			continue
		var recipe := visible_recipes[i]
		tile.text = recipe.name
		tile.get_child(0).texture = Art.texture(recipe.icon)
		ui._restyle(tile, i == selected)
		for mode in ["normal", "hover", "pressed", "disabled"]:
			tile.get_theme_stylebox(mode).set_content_margin(SIDE_TOP, 45)
		tile.get_child(0).modulate.a = 1.0 if i == selected or profile.owns(recipe.id) or profile.can_craft(recipe.id) else 0.62

	var current := visible_recipes[selected]
	var owned := profile.owns(current.id)
	var equipped: bool = profile.equipped(current.slot, role) == current.id
	detail_icon.texture = Art.texture(current.icon)
	detail_name.text = current.name
	detail_stat.text = current.get("detail", Equipment.describe(current.stats))
	detail_trait.text = current.get("trait", "")
	detail_trait.visible = not detail_trait.text.is_empty()
	var affix := profile.affix(current.id)
	detail_affix.text = ""
	if not affix.is_empty():
		detail_affix.text = "%s · %s" % [affix.name, Equipment.describe(affix.stats)]
	elif current.slot != "weapon" and not owned:
		detail_affix.text = "打造时随机附加一条词缀"
	detail_affix.visible = not detail_affix.text.is_empty()
	_show_set(current.get("set", ""), counts)
	for child in cost_row.get_children():
		cost_row.remove_child(child)
		child.queue_free()
	if not owned:
		for material in Gear.MATERIALS:
			if not current.cost.has(material.id):
				continue
			var needed: int = current.cost[material.id]
			var count := profile.stock(material.id)
			var cost: HBoxContainer = ui._hbox(2)
			cost.add_child(_icon(material.icon, 18))
			var value: Label = ui._label("%d/%d" % [count, needed], 12, LIGHT if count >= needed else DANGER)
			value.tooltip_text = material.name
			cost.add_child(value)
			cost_row.add_child(cost)
	cost_row.visible = not owned
	var available := profile.can_craft(current.id)
	var message := "材料不足"
	if owned:
		message = "已装备" if equipped else "可装备"
	elif available:
		message = "可打造"
	status.text = profile.storage_error if not profile.storage_error.is_empty() else (confirmation if not confirmation.is_empty() else message)
	status.add_theme_color_override("font_color", DANGER if not profile.storage_error.is_empty() else (BRASS if owned or available else MUTED))
	action.disabled = (not owned and not available) or profile.storage_error == "存档读取失败"
	action.get_node("Glyph").modulate.a = 0.46 if action.disabled else 1.0
	ui._set_icon(action, &"unequip" if equipped else (&"equip" if owned else &"hammer"))
	ui._describe(action, "卸下" if equipped else ("装备" if owned else "打造"))

func _show_set(family: String, counts: Dictionary) -> void:
	var shown := not family.is_empty()
	set_name.visible = shown
	set_two.visible = shown
	set_three.visible = shown
	if not shown:
		return
	var effect: Dictionary = Equipment.SETS[family]
	var pieces: int = counts.get(family, 0)
	set_name.text = "%s · 已穿 %d 件" % [effect.name, pieces]
	set_name.add_theme_color_override("font_color", effect.color)
	set_two.text = "2 件  " + effect.two_text
	set_three.text = "3 件  " + effect.three_text
	set_two.add_theme_color_override("font_color", effect.color if pieces >= 2 else MUTED)
	set_three.add_theme_color_override("font_color", effect.color if pieces >= 3 else MUTED)

func _select(index: int) -> void:
	selected = index
	confirmation = ""
	refresh()

func _activate() -> void:
	var current := visible_recipes[selected]
	if profile.owns(current.id):
		var equipped: bool = profile.equipped(current.slot, role) == current.id
		if profile.toggle_equip(current.id):
			confirmation = "已卸下" if equipped else "已装备"
			ui.sounds.play(&"pickup")
	elif profile.craft(current.id):
		confirmation = "打造完成 · 可装备"
		ui.sounds.play(&"level")
	refresh()

func _tray(stack: VBoxContainer, padding: int, fill: Color) -> HBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ui._box(fill, Color("#806247"), 1, padding))
	stack.add_child(panel)
	var row: HBoxContainer = ui._hbox(5)
	panel.add_child(row)
	return row

func _icon(index: int, pixels: int) -> TextureRect:
	var icon: TextureRect = ui._image(Art.texture(index) if index >= 0 else null)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(pixels, pixels)
	return icon
