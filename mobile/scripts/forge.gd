extends VBoxContainer

signal close_requested

const Gear = preload("res://scripts/gear.gd")
const Loadout = preload("res://scripts/loadout.gd")
const Rules = preload("res://scripts/rules/forge_rules.gd")
const WuXing = preload("res://scripts/rules/wuxing.gd")
const Roster = preload("res://scripts/roster.gd")
const EquipmentSlot = preload("res://scripts/equipment_slot.gd")
const Armory = preload("res://scripts/armory.gd")
const GOOD := EquipmentSlot.GOOD
const BAD := EquipmentSlot.BAD

var ui
var profile: Gear
var draft := Gear.new_draft()
var inventory := false
var armory: Armory
var tab_forge: Button
var tab_gear: Button
var back: Button
var heading: Label
var context: Label
var preview: VBoxContainer
var preview_slot: EquipmentSlot
var preview_name: Label
var preview_stats: Label
var preview_effect: Label
var preview_pattern: Label
var pure_label: Label
var progress: ProgressBar
var polarity_bar: ProgressBar
var compass: Compass
var charge_label: Label
var status: Label
var notice: Label
var notice_panel: PanelContainer
var confirm: Button
var smith_options: VBoxContainer
var forge_scroll: ScrollContainer
var details_button: Button
var detail_cover: ColorRect
var detail_title: Label
var detail_body: Label
var detail_scroll: ScrollContainer
var detail_close: Button
var detail_return_focus: Control
var slot_buttons := {}
var process_buttons := {}
var stock_labels := {}
var plus_buttons := {}
var minus_buttons := {}
var parts_grid: GridContainer
var parts_toggle: Button
var extras: VBoxContainer
var forms: Button
# 护甲、护手、鞋子的甲型：布衣、皮甲、链甲（女角色的护甲叫丝衣、皮衣、盔甲）。只改样子。
var types: OptionButton
var socket_controls: HBoxContainer
var preview_ling := ""
var pending := false

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var header: HBoxContainer = ui._hbox(8)
	add_child(header)
	back = ui._icon_button(&"back", "返回战场", false, Vector2(43, 43))
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_secondary(back)
	back.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(back)
	var headers: VBoxContainer = ui._vbox(0)
	headers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(headers)
	heading = _text("兜率炉坊", 29, ui.INK)
	heading.add_theme_font_override("font", ui.HEADING_FONT)
	ui.heading_plate(heading)
	heading.custom_minimum_size = Vector2(152, 36)
	heading.size_flags_horizontal = SIZE_SHRINK_CENTER
	headers.add_child(heading)
	context = _text("", 12, ui.GOLD)
	headers.add_child(context)
	tab_forge = _button("投料锻造", 44, func() -> void: _forge_for_slot(armory.filter_slot))
	tab_gear = _button("装备行囊", 44, func() -> void: _select_tab(true))
	for button in [tab_forge, tab_gear]:
		button.size_flags_horizontal = Control.SIZE_SHRINK_END
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.add_child(button)
	header.add_child(ui._sound_button())
	_build_preview()

	smith_options = ui._vbox(5)
	smith_options.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(smith_options)
	_build_inputs()
	armory = Armory.new()
	armory.forge = self
	armory.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(armory)
	notice_panel = _surface(self, 6, false)
	notice = _text("", 12, ui.GOLD)
	notice_panel.add_child(notice)
	notice_panel.hide()
	_select_tab(false)

func open(encounter_ling: String = "", slot: String = "") -> void:
	preview_ling = encounter_ling
	notice_panel.hide()
	armory.reset(slot, profile.equipped(slot))
	_select_tab(true)

func _forge_for_slot(slot: String) -> void:
	if not slot.is_empty():
		draft.slot = slot
	notice_panel.hide()
	_select_tab(false)
	forge_scroll.scroll_vertical = 0

func _build_preview() -> void:
	preview = _card(self, 9)
	var top: HBoxContainer = ui._hbox(12)
	preview.add_child(top)
	var visual: VBoxContainer = ui._vbox(0)
	top.add_child(visual)
	preview_slot = EquipmentSlot.new()
	preview_slot.pressed.connect(_press_preview)
	visual.add_child(preview_slot)
	compass = Compass.new()
	compass.custom_minimum_size = Vector2(88, 79)
	visual.add_child(compass)
	var report: VBoxContainer = ui._vbox(5)
	report.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(report)
	preview_name = _text("待投料", 16, ui.GOLD)
	report.add_child(preview_name)
	pure_label = _text("", 11, ui.MUTED)
	report.add_child(pure_label)
	polarity_bar = ProgressBar.new()
	polarity_bar.show_percentage = false
	polarity_bar.custom_minimum_size.y = 3
	polarity_bar.add_theme_stylebox_override("background", ui._box(Color("#2f4f6a"), ui.NIGHT, 0, 0))
	polarity_bar.add_theme_stylebox_override("fill", ui._box(ui.GOLD, ui.NIGHT, 0, 0))
	report.add_child(polarity_bar)
	preview_stats = _text("", 12, ui.INK)
	report.add_child(preview_stats)
	preview_effect = _text("", 11, GOOD)
	report.add_child(preview_effect)
	preview_pattern = _text("", 11, ui.GOLD)
	report.add_child(preview_pattern)
	progress = ProgressBar.new()
	progress.show_percentage = false
	progress.custom_minimum_size.y = 5
	progress.add_theme_stylebox_override("background", ui._box(ui.NIGHT, ui.NIGHT, 0, 0))
	progress.add_theme_stylebox_override("fill", ui._box(ui.GOLD, ui.GOLD, 0, 0))
	preview.add_child(progress)
	charge_label = _text("", 12, ui.INK)
	preview.add_child(charge_label)

func _build_inputs() -> void:
	forge_scroll = _scroll(smith_options)
	var content: VBoxContainer = ui._vbox(7)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	forge_scroll.add_child(content)

	var tray := _card(content, 7)
	var caption: HBoxContainer = ui._hbox(6)
	tray.add_child(caption)
	var label := _text("投料盘", 15, ui.GOLD)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.add_child(label)
	parts_toggle = _button("高阶材料", 28, func() -> void: parts_grid.visible = not parts_grid.visible)
	parts_toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
	caption.add_child(parts_toggle)
	var grid := _grid(tray, 2, 4)
	for id in WuXing.STEMS:
		_add_material(grid, id)
	parts_grid = _grid(tray, 2, 4)
	for id in Gear.Materials.MATERIALS:
		if id not in WuXing.STEMS and id != "relic_core":
			_add_material(parts_grid, id)
	parts_grid.hide()

	var work := _card(content, 7)
	var slot_row := _chip_row(work)
	for i in range(Gear.SLOTS.size()):
		var id: String = Gear.SLOTS[i]
		var control := _chip(Gear.SLOT_NAMES[i], _choose_slot.bind(id))
		slot_buttons[id] = control
		slot_row.add_child(control)
	var process_row := _chip_row(work)
	for id in ["forge_rough", "forge_fine", "harmonize", "forge_yang", "quench_yin"]:
		var control := _chip(Rules.PROCESSES[id].name, _toggle_process.bind(id))
		process_buttons[id] = control
		process_row.add_child(control)
	var switches: HBoxContainer = ui._hbox(5)
	work.add_child(switches)
	var more := _button("形制 / 进阶", 28, func() -> void: extras.visible = not extras.visible)
	switches.add_child(more)
	details_button = _button("查看推导", 28, _press_preview)
	switches.add_child(details_button)
	extras = ui._vbox(5)
	work.add_child(extras)
	forms = _button("兵器形制", 38, _open_weapons)
	caption.add_child(forms)
	types = _option()
	for id in Gear.ARMOR_TYPES:
		types.add_item({"cloth": "布甲", "leather": "皮甲", "chain": "链甲"}[id])
		types.set_item_metadata(types.item_count - 1, id)
	types.item_selected.connect(func(index: int) -> void:
		draft.armor_type = types.get_item_metadata(index)
		_changed())
	extras.add_child(types)
	var processes := _chip_row(extras)
	for id in ["seal", "reverse_yin_yang", "engrave"]:
		var control := _chip(Rules.PROCESSES[id].name, _toggle_process.bind(id))
		process_buttons[id] = control
		processes.add_child(control)
	var seal := _option()
	seal.add_item("封印所选行")
	for element in WuXing.WUXING:
		seal.add_item(WuXing.ELEMENT_NAMES[element])
	seal.item_selected.connect(func(index: int) -> void:
		draft.sealed_element = WuXing.WUXING[index - 1] if index > 0 else ""
		_changed())
	extras.add_child(seal)
	socket_controls = ui._hbox(5)
	extras.add_child(socket_controls)
	extras.hide()
	var footer := _card(smith_options, 6)
	status = _text("", 12, ui.MUTED)
	footer.add_child(status)
	confirm = _primary("打造", _craft)
	footer.add_child(confirm)

func _select_tab(show_gear: bool) -> void:
	inventory = show_gear
	ui.portrait_back(back, str(profile.character().get("gender", "")))
	pending = false
	notice_panel.hide()
	preview.get_parent().visible = not inventory
	smith_options.visible = not inventory
	armory.visible = inventory
	tab_forge.visible = inventory
	tab_gear.visible = not inventory
	heading.text = "行装" if inventory else "兜率炉坊"
	heading.add_theme_font_size_override("font_size", 25 if inventory else 29)
	ui._fit_forge()
	_refresh()

# 甲型选单里护手、鞋子的叫法：布护手、皮靴、链靴……
func _slot_label(slot: String) -> String:
	return Rules.NAME_PARTS.slots[slot]

func _choose_slot(slot: String) -> void:
	draft.slot = slot
	_changed()

func _toggle_process(id: String) -> void:
	if id in ["forge_rough", "forge_fine"]:
		draft.process.erase("forge_rough")
		draft.process.erase("forge_fine")
		draft.process.push_front(id)
	elif draft.process.has(id):
		draft.process.erase(id)
	else:
		if id == "forge_yang":
			draft.process.erase("quench_yin")
		elif id == "quench_yin":
			draft.process.erase("forge_yang")
		draft.process.append(id)
	_changed()

func _add_material(grid: GridContainer, id: String) -> void:
	var row: HBoxContainer = ui._hbox(3)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(row)
	var minus := _button("−", 36, _amount.bind(id, -1))
	_plain_step(minus)
	minus.custom_minimum_size.x = 33
	minus.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(minus)
	var label := _text("", 11, Color(Gear.material(id).tint).lerp(ui.INK, 0.58))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var plus := _button("+", 36, _amount.bind(id, 1))
	_plain_step(plus)
	plus.custom_minimum_size.x = 33
	plus.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(plus)
	stock_labels[id] = label
	plus_buttons[id] = plus
	minus_buttons[id] = minus

# 加减料按钮保留简洁的大字号符号。
func _plain_step(button: Button) -> void:
	button.remove_meta(&"brush_fills")
	var clear := StyleBoxEmpty.new()
	for style in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(style, clear)
	button.add_theme_font_size_override("font_size", 22)
	for color_name in ["font_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, ui.INK)
	button.add_theme_color_override("font_hover_color", ui.GOLD)
	button.add_theme_color_override("font_pressed_color", ui.CRIMSON)
	button.add_theme_color_override("font_disabled_color", Color(ui.MUTED, 0.35))

func _amount(id: String, delta: int) -> void:
	var quantity := int(draft.materials.get(id, 0)) + delta
	if quantity <= 0:
		draft.materials.erase(id)
	else:
		draft.materials[id] = quantity
	_changed()

func _changed() -> void:
	pending = false
	notice_panel.hide()
	_refresh()

func _context_text() -> String:
	var caption := profile.layer_caption() if inventory else "%s  ·  炉温 L%d" % [profile.layer_caption(), profile.furnace_level()]
	if not preview_ling.is_empty():
		caption += "  ·  渡劫 %s当令" % Gear.ling_caption(preview_ling)
	return caption

func _refresh() -> void:
	context.text = _context_text()
	context.visible = not inventory
	if inventory:
		armory.refresh()
		return
	var result := profile.describe(draft)
	var count := 0
	for value in draft.materials.values():
		count += int(value)
	for id in stock_labels:
		var used := int(draft.materials.get(id, 0))
		var source := Gear.material(id)
		stock_labels[id].text = "%s\n%d / %d" % [source.name, used, profile.stock(id)]
		plus_buttons[id].disabled = used >= profile.stock(id) or count >= profile.material_slots()
		minus_buttons[id].disabled = used == 0
	for id in slot_buttons:
		slot_buttons[id].set_pressed_no_signal(id == draft.slot)
	for id in process_buttons:
		process_buttons[id].set_pressed_no_signal(draft.process.has(id))
	forms.visible = draft.slot == "weapon"
	forms.text = "兵器 · " + str(Rules.NAME_PARTS.weapons[draft.weapon_form])
	types.visible = draft.slot in Gear.ARMOR_TYPE_SLOTS
	if types.visible:
		var female: bool = profile.character().get("gender") == "female"
		for index in range(types.item_count):
			var id: String = types.get_item_metadata(index)
			var label: String = Rules.NAME_PARTS.gear_types[id] + _slot_label(draft.slot)
			if draft.slot == "armor":
				label = (Rules.NAME_PARTS.armor_types_female if female else Rules.NAME_PARTS.armor_types)[id]
			types.set_item_text(index, label)
		types.select(maxi(0, Gear.ARMOR_TYPES.find(draft.get("armor_type", "cloth"))))
	_refresh_sockets()
	_refresh_preview(result, count)
	var error := profile.craft_error(draft)
	confirm.disabled = not error.is_empty()
	var costs := PackedStringArray()
	if error.is_empty() and (pending or draft.process.has("forge_fine") or not draft.sockets.is_empty() or draft.process.has("engrave") or draft.process.has("reverse_yin_yang")):
		var material_costs := profile.craft_cost(draft)
		for id in material_costs:
			costs.append("%s×%d" % [Gear.material(id).name, material_costs[id]])
	status.text = error if not error.is_empty() else ("消耗 " + "  ".join(costs) if not costs.is_empty() else "预览只占投料格，确认后才扣材料")
	confirm.text = "确认消耗并打造" if pending else "打造"

func _refresh_sockets() -> void:
	_clear(socket_controls)
	var limit := profile.socket_limit()
	if limit == 0:
		socket_controls.add_child(_text("镶嵌 · 筑基开放", 12, ui.MUTED))
		return
	for index in range(limit):
		var socket := _option()
		socket.add_item("槽 %d · 空" % (index + 1))
		for stem in WuXing.STEMS:
			socket.add_item("嵌 " + Gear.stem_name(stem))
		var active: String = draft.sockets[index] if index < draft.sockets.size() else ""
		socket.select(WuXing.STEMS.find(active) + 1)
		socket.item_selected.connect(_set_socket.bind(index))
		socket_controls.add_child(socket)

func _set_socket(choice: int, index: int) -> void:
	if index < draft.sockets.size():
		draft.sockets.remove_at(index)
	if choice > 0:
		var stem: String = WuXing.STEMS[choice - 1]
		draft.sockets.erase(stem)
		draft.sockets.insert(mini(index, draft.sockets.size()), stem)
	_changed()

func _refresh_preview(result: Dictionary, count: int) -> void:
	var tier: Dictionary = Rules.FORGE_TIERS[profile.furnace_level()]
	var charge: Dictionary = result.steps[0] if not result.steps.is_empty() else {}
	var interactions: Dictionary = result.steps[1] if result.steps.size() > 1 else {}
	var total: float = charge.get("purity", 0.0)
	var residue: float = charge.get("residue", 0.0)
	var overflow := maxf(0, total - float(tier.cap))
	var refund := float(profile.origin().get("residue_refund", Rules.SHENG_KE_PARAMS.overflow_refund))
	residue += overflow * (refund - float(Rules.SHENG_KE_PARAMS.overflow_refund))
	residue *= 1.0 + float(profile.hour_talent().get("residue_refund_bonus", 0.0))
	progress.max_value = tier.cap
	progress.value = result.budget
	charge_label.text = "纯度 %s / %d  ·  投料 %d / %d" % [String.num(total, 2), tier.cap, count, profile.material_slots()]
	if total > tier.cap:
		charge_label.text += "  ·  溢出退残渣 %s" % String.num(residue, 2)
	charge_label.add_theme_color_override("font_color", BAD if total > tier.cap else ui.INK)
	preview_name.text = result.name if not result.name.is_empty() else "投料预览"
	pure_label.text = "主行纯度 %.0f%% · 阴阳 %+.2f · 阳 %.0f%%" % [result.purity * 100.0, result.yin_yang, (result.yin_yang + 1.0) * 50.0]
	polarity_bar.value = (result.yin_yang + 1.0) * 50.0
	preview_stats.text = _stat_lines(result.stats, true) if not result.stats.is_empty() else "在下方按 ＋ 加入材料"
	preview_slot.display(draft.slot, profile.describe(draft, true, preview_ling) if not result.wuxing.is_empty() else {}, profile.character(), draft.weapon_form)
	compass.visible = preview_slot.occupied
	details_button.disabled = not preview_slot.occupied
	compass.update_data(result.wuxing, _charge_weights())
	var effect := _effect_text(result)
	if float(interactions.get("loss", 0.0)) > 0.0:
		var hinted := draft.duplicate(true)
		hinted.process.append("harmonize")
		var signature: Dictionary = profile.describe(hinted).clash
		effect = "耗散 %.1f%% · 调和可化为%s反应" % [float(interactions.loss) * 100.0, signature.get("name", "")]
	preview_effect.text = effect
	preview_effect.visible = not effect.is_empty()
	preview_effect.add_theme_color_override("font_color", BAD if float(interactions.get("loss", 0.0)) > 0.0 else GOOD)
	var current := Loadout.pattern_names(profile.loadout({}, false).patterns)
	var checked := profile.loadout(draft, false) if not result.wuxing.is_empty() else profile.loadout({}, false)
	var projected := Loadout.pattern_names(checked.patterns)
	preview_pattern.text = "预算 %.1f  ·  格局 %s" % [result.budget,
		current if current == projected else current + " → " + projected]
	var hint := _zhoutian_hint(checked)
	if not hint.is_empty():
		preview_pattern.text += "  ·  " + hint

func _charge_weights() -> Dictionary:
	var distribution := {}
	var sum := 0.0
	for id in draft.materials:
		var material: Dictionary = Gear.Materials.MATERIALS[id]
		var weight := float(material.purity) * float(draft.materials[id])
		sum += weight
		for element in material.wuxing:
			distribution[element] = float(distribution.get(element, 0.0)) + weight * float(material.wuxing[element])
	for element in distribution:
		distribution[element] /= sum
	return distribution

func _press_preview() -> void:
	if preview_slot.occupied:
		show_derivation(draft, preview_ling)
	else:
		_forge_for_slot(draft.slot)

func show_derivation(item: Dictionary, encounter_ling: String = "") -> void:
	if item.is_empty():
		return
	var result := profile.describe(item)
	var live := profile.describe(item, true, encounter_ling)
	var element := Loadout.dominant(live.wuxing)
	var slot := String(item.slot)
	var slot_index := Gear.SLOTS.find(slot)
	var title: String = result.name if not result.name.is_empty() else Gear.SLOT_NAMES[slot_index]
	var report := PackedStringArray()
	if not element.is_empty():
		var person := profile.character()
		var badge := Loadout.badge(live, person)
		var fit := "用神" if badge.fit > 0 else ("忌神" if badge.fit < 0 else "中性")
		var proportions := PackedStringArray()
		for key in WuXing.WUXING:
			proportions.append("%s %.1f%%" % [WuXing.ELEMENT_NAMES[key], float(live.wuxing.get(key, 0.0)) * 100.0])
		report.append("%s  ·  主行 %s  ·  阴阳 %+.2f" % [Gear.SLOT_NAMES[slot_index], WuXing.ELEMENT_NAMES[element], live.yin_yang])
		report.append("  ".join(proportions))
		report.append("%s当令  ·  %s" % [Gear.ling_caption(profile.ling() if encounter_ling.is_empty() else encounter_ling), fit])
		report.append("%s  ·  时势 S %.2f" % [badge.text, live.shi])
		report.append("")
	report.append("内在品质")
	report.append(_explain(result, slot))
	var effect := _effect_text(result)
	if not effect.is_empty():
		report.append(effect)
	if not element.is_empty():
		report.append("\n当前实战")
		report.append(_explain(live, slot))
		effect = _effect_text(live)
		if not effect.is_empty():
			report.append(effect)
	show_report(title, "\n".join(report))

func show_report(title: String, report: String) -> void:
	if detail_cover == null:
		_build_derivation()
	detail_title.text = title
	detail_body.text = report
	detail_return_focus = get_viewport().gui_get_focus_owner()
	detail_cover.show()
	detail_scroll.scroll_vertical = 0
	detail_close.grab_focus()

func _build_derivation() -> void:
	detail_cover = ColorRect.new()
	detail_cover.color = Color(ui.NIGHT, 0.83)
	ui.add_child(detail_cover)
	ui._fill(detail_cover)
	var inset := MarginContainer.new()
	detail_cover.add_child(inset)
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inset.anchor_top = 0.12
	inset.anchor_bottom = 0.88
	inset.offset_top = 0
	inset.offset_bottom = 0
	inset.add_theme_constant_override("margin_left", 20)
	inset.add_theme_constant_override("margin_right", 20)
	var content := _card(inset, 12)
	content.add_theme_constant_override("separation", 10)
	var header: HBoxContainer = ui._hbox(10)
	content.add_child(header)
	detail_title = _text("", 19, ui.GOLD)
	detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(detail_title)
	detail_close = _button("关闭", 32, close_derivation)
	detail_close.size_flags_horizontal = Control.SIZE_SHRINK_END
	detail_close.focus_mode = Control.FOCUS_ALL
	header.add_child(detail_close)
	detail_scroll = _scroll(content)
	detail_body = _text("", 13, ui.INK)
	detail_body.add_theme_constant_override("line_spacing", 5)
	detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(detail_body)

func close_derivation() -> void:
	detail_cover.hide()
	if is_instance_valid(detail_return_focus) and detail_return_focus.is_visible_in_tree():
		detail_return_focus.grab_focus()
	detail_return_focus = null

func _explain(data: Dictionary, slot: String) -> String:
	if data.steps.size() < 4:
		return "投料后可查看计算过程。"
	var charge: Dictionary = data.steps[0]
	var relation: Dictionary = data.steps[1]
	var m: Dictionary = data.steps[2]
	var split: Dictionary = data.steps[3]
	var quality: float = m.m * m.a * m.b * m.roll
	var context_factor: float = m.q * m.shi * m.f
	var lines := PackedStringArray([
		"投料 %.1f · 炉温上限 %.0f · 工艺后预算 %.2f" % [charge.purity, charge.cap, charge.base_budget],
		"生链 %d · 耗散 %.1f%% · 基础残渣 %.2f" % [relation.chain, relation.loss * 100, charge.residue],
		"属性预算 %.2f · 反应 %.2f · 镶嵌 %.2f" % [split.stat_budget, split.clash_budget, split.socket_budget],
		"品质 %.3f = 纯度 %.3f × 锐度 %.2f × 生链 / 太极 %.2f × 工艺 %.2f" % [quality, m.m, m.a, m.b, m.roll],
		"实战 %.3f = 境遇 Q %.2f × 时势 S %.2f × 契合 F %.2f" % [context_factor, m.q, m.shi, m.f]
	])
	var combined := {}
	for element in data.wuxing:
		var shape: Array = Rules.FORM_MATRIX[slot][element]
		for i in range(2):
			var stat: String = shape[i]
			if not data.stats.has(stat):
				continue
			var form := (1.0 + float(data.yin_yang) * (1 if i == 0 else -1)) * 0.5
			if is_zero_approx(form):
				continue
			var factor := float(Rules.STAT_WEIGHTS.get(stat, 1.0))
			var line := "%.2f × 品质 %.3f × 实战 %.3f × %s %.1f%% × %s %.0f%% × 权重 %.2f" % [
				split.stat_budget, quality, context_factor, WuXing.ELEMENT_NAMES[element], data.wuxing[element] * 100,
				"阳" if i == 0 else "阴", form * 100, factor]
			if not combined.has(stat):
				combined[stat] = PackedStringArray()
			combined[stat].append(line)
	for stat in data.stats:
		lines.append("\n%s +%s" % [Loadout.STAT_NAMES.get(stat, stat), String.num(data.stats[stat], 1)])
		lines.append(" +\n".join(combined.get(stat, PackedStringArray())))
	if data.stats.is_empty():
		lines.append("成品无数值词条")
	return "\n".join(lines)

func _craft() -> void:
	if not pending:
		pending = true
		_refresh()
		return
	if not profile.craft(draft):
		_message(profile.storage_error if not profile.storage_error.is_empty() else "请核对投料与库存")
		_refresh()
		return
	armory.reset(draft.slot, draft.uid)
	draft = Gear.new_draft()
	types.select(0)
	_select_tab(true)
	_message("打造完成，已放入背包")

func _zhoutian_hint(loadout: Dictionary) -> String:
	var low := PackedStringArray()
	for element in WuXing.WUXING:
		if loadout.weights[element] < Rules.PATTERNS.zhoutian.min_weight:
			low.append(WuXing.ELEMENT_NAMES[element])
	return "补%s行，向均衡靠拢" % low[0] if low.size() == 1 else ""

func _stat_lines(stats: Dictionary, compact: bool = false) -> String:
	var lines := PackedStringArray()
	var i := 0
	for stat in stats:
		if i == 4:
			break
		var line := "%s +%s%s" % [Loadout.STAT_NAMES.get(stat, stat), String.num(stats[stat], 1),
			" 点" if Rules.STAT_CURVES.has(stat) and not compact else ""]
		if compact and i % 2 == 1:
			lines[-1] += "   " + line
		else:
			lines.append(line)
		i += 1
	var end := "\n其余 %d 条折叠 · 残渣提示" % (stats.size() - 4) if stats.size() > 4 else ""
	return "\n".join(lines) + end

func _effect_text(result: Dictionary) -> String:
	var effects := PackedStringArray()
	for trigger in result.triggers:
		effects.append("%s · %s %.1f" % [trigger.condition, trigger.action.name, trigger.strength])
	var clash: Dictionary = result.clash
	if not clash.is_empty():
		var effect := "%s反应 · 强度 %.1f" % [clash.name, clash.strength]
		if clash.id == "steam":
			effect = "蒸汽反应 %.0f%% · 范围伤害 %.0f" % [clash.chance * 100.0, clash.strength * clash.aoe_damage_scale]
		elif clash.id == "root":
			effect = "缠根反应 %.0f%% · 定身 %.1f 秒" % [clash.chance * 100.0, clash.root_seconds]
		effects.append(effect)
	return "\n".join(effects)

func _message(message: String) -> void:
	if inventory:
		context.text = message
		context.visible = not message.is_empty()
	else:
		notice.text = message
		notice_panel.visible = not message.is_empty()

func _surface(parent: Node, padding: int, outlined: bool = true) -> PanelContainer:
	var panel := PanelContainer.new()
	# 皮框幕布，次要区域降低透明度。
	panel.add_theme_stylebox_override("panel", ui.paper_box(1.0 if outlined else 0.85, padding))
	parent.add_child(panel)
	return panel

func _card(parent: Node, padding: int) -> VBoxContainer:
	var panel := _surface(parent, padding)
	var stack: VBoxContainer = ui._vbox(4)
	panel.add_child(stack)
	return stack

func _grid(parent: Node, columns: int, gap: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", gap)
	grid.add_theme_constant_override("v_separation", gap)
	parent.add_child(grid)
	return grid

func _scroll(parent: Node) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	return scroll

func _chip_row(parent: Node) -> HBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.scroll_deadzone = 8
	parent.add_child(scroll)
	var row: HBoxContainer = ui._hbox(5)
	scroll.add_child(row)
	return row

func _text(text: String, pixels: int, color: Color) -> Label:
	var label: Label = ui._label(text, pixels, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _button(title: String, height: int, callback: Callable) -> Button:
	var button: Button = ui._button(title, false, height)
	_style_secondary(button)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(callback)
	return button

# 次要操作使用深褐皮牌。
func _style_secondary(button: Button) -> void:
	ui.brush_button(button, [Color(ui.WASH, 0.82), ui.WASH.lightened(0.12), ui.WASH.darkened(0.25), Color(ui.WASH, 0.3)])
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, ui.INK)
	button.add_theme_color_override("font_disabled_color", Color(ui.INK, 0.6))

func _chip(title: String, callback: Callable) -> Button:
	var button := _button(title, 28, callback)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.toggle_mode = true
	button.remove_meta(&"brush_fills")  # 标签自己画：没选中只有字，选中显示皮牌
	for style in ["normal", "hover", "pressed", "hover_pressed"]:
		var filled: bool = style in ["pressed", "hover_pressed"]
		var shape: StyleBoxTexture = ui._brush(ui.WASH if filled else Color.TRANSPARENT)
		shape.set_content_margin(SIDE_LEFT, 9)
		shape.set_content_margin(SIDE_RIGHT, 9)
		shape.set_content_margin(SIDE_TOP, 0)
		shape.set_content_margin(SIDE_BOTTOM, 0)
		button.add_theme_stylebox_override(style, shape)
	# 已选标签显示皮牌底色。
	button.add_theme_color_override("font_color", ui.MUTED)
	button.add_theme_color_override("font_hover_color", ui.INK)
	button.add_theme_color_override("font_pressed_color", ui.INK)
	button.add_theme_color_override("font_hover_pressed_color", ui.INK)
	return button

func _primary(title: String, callback: Callable) -> Button:
	var button := _button(title, 56, callback)
	button.add_theme_font_size_override("font_size", 17)
	ui._restyle(button, true)
	return button

func _option() -> OptionButton:
	var option := OptionButton.new()
	_style_secondary(option)
	option.add_theme_font_size_override("font_size", 12)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.custom_minimum_size.y = 34
	return option

func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

class Compass extends Control:
	const ORDER := ["mu", "huo", "tu", "jin", "shui"]
	var weights := {}
	var ingredients := {}

	func update_data(distribution: Dictionary, charge: Dictionary) -> void:
		weights = distribution
		ingredients = charge
		queue_redraw()

	func _draw() -> void:
		var pivot := size * 0.5
		var radius := minf(size.x, size.y) * 0.34
		var rim := PackedVector2Array()
		var area := PackedVector2Array()
		for i in range(ORDER.size()):
			var direction := Vector2.from_angle(-PI * 0.5 + TAU * i / 5.0)
			rim.append(pivot + direction * radius)
			area.append(pivot + direction * radius * clampf(float(weights.get(ORDER[i], 0.0)) * 1.55, 0.0, 1.0))
			draw_line(pivot, rim[i], Color("#726749"), 1.0, true)
		for ratio in [0.5, 1.0]:
			var grid := PackedVector2Array()
			for point in rim:
				grid.append(pivot.lerp(point, ratio))
			grid.append(grid[0])
			draw_polyline(grid, Color("#726749"), 1.0, true)
		if not weights.is_empty():
			if weights.values().filter(func(weight: float) -> bool: return weight > 0.0).size() >= 3:
				draw_colored_polygon(area, Color("#cdb18058"))
			area.append(area[0])
			draw_polyline(area, Color("#e0c891"), 1.6, true)
		var font := get_theme_default_font()
		for i in range(ORDER.size()):
			var element: String = ORDER[i]
			var label_pos := rim[i] + (rim[i] - pivot).normalized() * 10.0 + Vector2(-6.0, 4.0)
			draw_string(font, label_pos, WuXing.ELEMENT_NAMES[element], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Roster.ELEMENT_GLOW[element])
			for relation in [WuXing.SHENG, WuXing.KE]:
				var j := ORDER.find(relation[element])
				if minf(ingredients.get(element, 0.0), ingredients.get(ORDER[j], 0.0)) >= Rules.SHENG_KE_PARAMS.pair_min:
					_arrow(pivot.lerp(rim[i], 0.84), pivot.lerp(rim[j], 0.84), GOOD if relation == WuXing.SHENG else BAD)

	func _arrow(from: Vector2, to: Vector2, ink: Color) -> void:
		var head := from.lerp(to, 0.78)
		var direction := (to - from).normalized()
		draw_line(from, head, ink, 1.15, true)
		draw_line(head, head - direction.rotated(0.55) * 6, ink, 1.15, true)
		draw_line(head, head - direction.rotated(-0.55) * 6, ink, 1.15, true)

func _open_weapons() -> void:
	if is_instance_valid(ui.weapon_gallery):
		return
	var gallery := preload("res://scripts/weapon_gallery.gd").new()
	gallery.forge = self
	ui.weapon_gallery = gallery
	ui._fit_forge()
	ui.add_child(gallery)
	ui._fill(gallery)
