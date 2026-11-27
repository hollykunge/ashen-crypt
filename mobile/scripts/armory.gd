extends BoxContainer

const Gear = preload("res://scripts/gear.gd")
const Loadout = preload("res://scripts/loadout.gd")
const WuXing = preload("res://scripts/rules/wuxing.gd")
const Combat = preload("res://scripts/combat.gd")
const Slot = preload("res://scripts/equipment_slot.gd")
const DisplayFigure = preload("res://scripts/armory_figure.gd")
const WORN_SLOT_WIDTH := 76
const BAG_SLOT_SIZE := 74
const BAG_GAP := 4

var forge
var ui
var profile: Gear
var preview_ling: String:
	get: return forge.preview_ling
var selected_uid := ""
var filter_slot := ""
var advanced := false
var merging := false
var merge_armed := false
var merge_partner := ""
var merge_sockets: Array[String] = []
var inventory_stack: VBoxContainer
var board: GridContainer
var overview: BoxContainer
var change_button: Button
var preview_delta: Label
var worn: VBoxContainer
var bag: VBoxContainer
var sheet: VBoxContainer
var outfit_slots := {}
var stage: DisplayFigure
var worn_count: Label
var patterns: Button
var vitals: Label
var bag_count: Label
var category: OptionButton
var order: OptionButton
var bag_grid: GridContainer
var bag_scroll: ScrollContainer
var empty_hint: Label
var craft_button: Button
var empty_plate: StyleBoxTexture
var detail_scroll: ScrollContainer
var detail_body: VBoxContainer
var detail_title: Label
var detail_meta: Label
var reveal: Tween
var detail_icon: Slot
var equip_button: Button
var breakdown: Button
var bag_items := {}
var current_stats := {}

func _ready() -> void:
	ui = forge.ui
	profile = forge.profile
	add_theme_constant_override("separation", 8)
	stage = DisplayFigure.new()
	stage.mouse_filter = MOUSE_FILTER_IGNORE
	stage.size_flags_horizontal = SIZE_EXPAND_FILL
	stage.size_flags_vertical = SIZE_EXPAND_FILL
	stage.clip_contents = true
	add_child(stage)
	stage.item_rect_changed.connect(_fit_backdrop)
	inventory_stack = ui._vbox(4)
	inventory_stack.size_flags_horizontal = SIZE_EXPAND_FILL
	inventory_stack.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(inventory_stack)
	worn = _pane()
	bag = _pane()
	sheet = _pane()
	_build_outfit()
	_build_bag()
	_build_detail()
	get_viewport().size_changed.connect(_adapt)
	resized.connect(_adapt)
	_adapt()

func _pane() -> VBoxContainer:
	var stack: VBoxContainer = forge._card(inventory_stack, 6)
	stack.add_theme_constant_override("separation", 6)
	var panel: PanelContainer = stack.get_parent()
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	panel.size_flags_vertical = SIZE_EXPAND_FILL
	return stack

func _line(parent: Node, title: String, pixels: int, ink: Color) -> Label:
	var label: Label = forge._text(title, pixels, ink)
	parent.add_child(label)
	return label

func _build_outfit() -> void:
	var panel: PanelContainer = worn.get_parent()
	panel.size_flags_horizontal = SIZE_FILL
	var header: HBoxContainer = ui._hbox(8)
	worn.add_child(header)
	worn_count = _line(header, "", 15, ui.INK)
	worn_count.size_flags_horizontal = SIZE_EXPAND_FILL
	patterns = forge._button("五行格局", 36, _show_patterns)
	patterns.size_flags_horizontal = SIZE_SHRINK_CENTER
	patterns.size_flags_vertical = SIZE_SHRINK_CENTER
	patterns.custom_minimum_size.x = 76
	header.hide()
	overview = BoxContainer.new()
	overview.add_theme_constant_override("separation", 5)
	worn.add_child(overview)
	board = forge._grid(overview, 3, 3)
	board.size_flags_horizontal = SIZE_EXPAND_FILL
	for slot in Gear.SLOTS:
		var cell := Slot.new(50)
		cell.simple = true
		cell.caption = _slot_name(slot)
		cell.size_flags_horizontal = SIZE_EXPAND_FILL
		cell.pressed.connect(_open_slot.bind(slot))
		board.add_child(cell)
		outfit_slots[slot] = cell
	board.add_child(patterns)
	var summary: VBoxContainer = ui._vbox(2)
	overview.add_child(summary)
	summary.alignment = BoxContainer.ALIGNMENT_CENTER
	vitals = _line(summary, "", 13, ui.INK)
	preview_delta = _line(summary, "", 12, Slot.GOOD)
	preview_delta.autowrap_mode = TextServer.AUTOWRAP_OFF
	preview_delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vitals.autowrap_mode = TextServer.AUTOWRAP_OFF
	vitals.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vitals.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _build_bag() -> void:
	var header: HBoxContainer = ui._hbox(6)
	bag.add_child(header)
	bag_count = _line(header, "背包", 18, ui.INK)
	bag_count.size_flags_horizontal = SIZE_EXPAND_FILL
	category = forge._option()
	category.accessibility_name = "筛选装备部位"
	category.add_item("全部部位")
	for label in Gear.SLOT_NAMES:
		category.add_item(label)
	category.item_selected.connect(func(index: int) -> void:
		_open_bag("" if index == 0 else Gear.SLOTS[index - 1]))
	header.add_child(category)
	order = forge._option()
	order.accessibility_name = "装备排序与契合筛选"
	for label in ["默认顺序", "契合优先", "只看忌神"]:
		order.add_item(label)
	order.item_selected.connect(func(_index: int) -> void:
		bag_scroll.scroll_vertical = 0
		refresh())
	header.add_child(order)
	for option in [category, order]:
		option.custom_minimum_size.y = 40
		option.size_flags_horizontal = SIZE_SHRINK_END
	bag_scroll = forge._scroll(bag)
	bag_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var content: VBoxContainer = ui._vbox(9)
	content.size_flags_horizontal = SIZE_EXPAND_FILL
	bag_scroll.add_child(content)
	empty_plate = Slot.tile_plate()
	bag_grid = forge._grid(content, 4, BAG_GAP)
	bag_grid.size_flags_horizontal = SIZE_SHRINK_CENTER
	bag_scroll.resized.connect(_fit_grid)
	bag_scroll.get_v_scroll_bar().visibility_changed.connect(_fit_grid, CONNECT_DEFERRED)
	empty_hint = _line(content, "", 13, ui.MUTED)
	empty_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	craft_button = forge._button("", 44, func() -> void: forge._forge_for_slot(filter_slot))
	content.add_child(craft_button)
	change_button = forge._button("换装", 34, _choose_backup)
	change_button.custom_minimum_size.x = 120
	change_button.size_flags_horizontal = SIZE_SHRINK_CENTER
	bag.add_child(change_button)

func _choose_backup() -> void:
	if not bag_items.is_empty():
		inspect(str(bag_items.keys()[0]))

func _fit_grid() -> void:
	var width := bag_scroll.size.x
	if bag_scroll.get_v_scroll_bar().visible:
		width -= bag_scroll.get_v_scroll_bar().size.x
	var columns := clampi(floori((width + BAG_GAP) / ((BAG_SLOT_SIZE if vertical else 54) + BAG_GAP)), 1, 8)
	if bag_grid.columns != columns:
		bag_grid.columns = columns
		_pad_grid()

func _build_detail() -> void:
	var header: HBoxContainer = ui._hbox(8)
	sheet.add_child(header)
	detail_icon = Slot.new(46)
	detail_icon.simple = true
	detail_icon.mouse_filter = MOUSE_FILTER_IGNORE
	detail_icon.focus_mode = FOCUS_NONE
	header.add_child(detail_icon)
	var names: VBoxContainer = ui._vbox(1)
	names.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(names)
	detail_title = _line(names, "", 17, ui.INK)
	detail_meta = _line(names, "", 12, ui.MUTED)
	var back: Button = forge._button("返回背包", 42, func() -> void: _open_bag(filter_slot))
	back.size_flags_horizontal = SIZE_SHRINK_END
	header.add_child(back)
	detail_scroll = forge._scroll(sheet)
	detail_body = ui._vbox(5)
	detail_body.size_flags_horizontal = SIZE_EXPAND_FILL
	detail_scroll.add_child(detail_body)
	var actions: HBoxContainer = ui._hbox(8)
	sheet.add_child(actions)
	breakdown = forge._button("更多操作", 44, func() -> void:
		advanced = not advanced
		merging = false
		merge_armed = false
		refresh()
		detail_scroll.scroll_vertical = 0)
	actions.add_child(breakdown)
	equip_button = ui._button("装备", true, 44)
	equip_button.size_flags_horizontal = SIZE_EXPAND_FILL
	equip_button.pressed.connect(_toggle_equipped)
	actions.add_child(equip_button)

func _fit_backdrop() -> void:
	if not is_visible_in_tree():
		return
	var edge: Vector2 = stage.get_global_rect().end - ui.global_position
	ui.armory_stage.size = Vector2(ui.size.x, edge.y + 3) if vertical else Vector2(edge.x + 10, ui.size.y)

func _adapt() -> void:
	var view := get_viewport_rect().size
	var room: float = view.x - ui.safe.get_theme_constant("margin_left") - ui.safe.get_theme_constant("margin_right")
	vertical = room < 640.0 or view.x < view.y * 1.17
	var inspecting := not selected_uid.is_empty()
	overview.vertical = vertical
	board.columns = 5 if vertical else 3
	var patterns_parent: Container = worn_count.get_parent() if vertical else board
	if patterns.get_parent() != patterns_parent:
		patterns.reparent(patterns_parent)
	worn_count.get_parent().visible = vertical
	stage.size_flags_stretch_ratio = 0.83
	inventory_stack.size_flags_stretch_ratio = 1.26
	stage.custom_minimum_size = Vector2(0, 135 if vertical else 0)
	worn.get_parent().visible = not inspecting
	worn.get_parent().size_flags_vertical = SIZE_FILL
	worn.get_parent().size_flags_horizontal = SIZE_FILL
	for cell: Slot in outfit_slots.values():
		cell.custom_minimum_size = Vector2(43, 74 if vertical else 60)
	bag.get_parent().visible = not inspecting
	sheet.get_parent().visible = inspecting
	_fit_backdrop.call_deferred()
	_show_vitals()
	for cell in bag_grid.get_children():
		cell.custom_minimum_size = Vector2.ONE * (BAG_SLOT_SIZE if vertical else 54)

func reset(slot: String, uid: String) -> void:
	filter_slot = slot
	category.select(Gear.SLOTS.find(slot) + 1)
	order.select(0)
	bag_scroll.scroll_vertical = 0
	_set_selection(uid)

func _set_selection(uid: String) -> void:
	selected_uid = uid
	advanced = false
	merging = false
	merge_armed = false
	merge_partner = ""
	merge_sockets.clear()
	detail_scroll.scroll_vertical = 0

func _open_bag(slot: String) -> void:
	filter_slot = slot
	category.select(Gear.SLOTS.find(slot) + 1)
	bag_scroll.scroll_vertical = 0
	inspect("")

func _open_slot(slot: String) -> void:
	reset(slot, profile.equipped(slot))
	forge._message("")
	refresh()

func inspect(uid: String) -> void:
	_set_selection(uid)
	forge._message("")
	refresh()
	var pane := sheet if not uid.is_empty() else bag
	if reveal:
		reveal.kill()
	bag.modulate.a = 1.0
	sheet.modulate.a = 1.0
	reveal = create_tween()
	reveal.tween_property(pane, "modulate:a", 1.0, 0.13).from(0.73)

func _slot_name(slot: String) -> String:
	return Gear.SLOT_NAMES[Gear.SLOTS.find(slot)]

func refresh() -> void:
	var config := profile.loadout({}, true, preview_ling)
	var person := profile.character()
	var input := profile.item(selected_uid)
	if input.is_empty():
		selected_uid = ""
	_adapt()
	var weapon := profile.item(profile.equipped("weapon"))
	var form: String = weapon.get("weapon_form", "sword")
	# 点开背包里一件还没穿的装备，正中的人物先试穿给你看；穿着的那件或没选东西时照实显示。
	var trying: bool = not input.is_empty() and profile.equipped(input.slot) != input.uid
	if trying:
		var worn_form: String = input.get("weapon_form", form) if input.slot == "weapon" else form
		stage.display(profile.loadout(input, true, preview_ling), person, worn_form, true)
	else:
		stage.display(config, person, form)
	current_stats = _combat_values(config, form)
	for slot in Gear.SLOTS:
		var cell: Slot = outfit_slots[slot]
		cell.highlighted = slot == input.get("slot", "weapon" if filter_slot.is_empty() else filter_slot)
		cell.display(slot, config.entries.get(slot, {}), person, form)
	worn_count.text = "已穿戴   %d / %d" % [config.entries.size(), Gear.SLOTS.size()]
	_show_vitals()
	if selected_uid.is_empty():
		_refresh_bag()
	else:
		_refresh_detail(input, config, form)

func _show_vitals() -> void:
	if current_stats.is_empty():
		return
	var gap := "    " if vertical else "\n"
	vitals.text = gap.join(["攻击  %d" % current_stats.attack, "生命  %d" % current_stats.hp,
		"减伤  %s%%" % String.num(current_stats.armor, 1)])

func _refresh_bag() -> void:
	forge._clear(bag_grid)
	bag_items.clear()
	var visible_items: Array[Dictionary] = []
	var total := 0
	for input in profile.items():
		if profile.equipped(input.slot) == input.uid:
			continue
		total += 1
		if not filter_slot.is_empty() and input.slot != filter_slot:
			continue
		var live := profile.describe(input, true, preview_ling)
		if order.selected == 2 and Loadout.badge(live, profile.character()).fit >= 0:
			continue
		visible_items.append({"item": input, "live": live})
	if order.selected == 1:
		visible_items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.live.f > b.live.f)
	bag_count.text = "背包  %d" % total
	for entry in visible_items:
		var input: Dictionary = entry.item
		var cell := Slot.new(BAG_SLOT_SIZE if vertical else 54)
		cell.simple = true
		var item_name: String = entry.live.name
		cell.caption = item_name.get_slice("·", 1) if input.name.is_empty() and item_name.count("·") == 1 and item_name.get_slice("·", 0).length() == 1 else item_name
		cell.display(input.slot, entry.live, profile.character(), input.get("weapon_form", ""))
		cell.pressed.connect(inspect.bind(input.uid))
		bag_grid.add_child(cell)
		bag_items[input.uid] = cell
	_pad_grid()
	empty_hint.visible = visible_items.is_empty()
	empty_hint.text = "背包里还没有备用装备" if total == 0 else "没有符合筛选条件的装备"
	preview_delta.hide()
	if not visible_items.is_empty():
		var candidate: Dictionary = visible_items[0].item
		var baseline := profile.item(profile.equipped("weapon"))
		var form: String = baseline.get("weapon_form", "sword")
		if candidate.slot == "weapon":
			form = candidate.get("weapon_form", form)
		var projected := _combat_values(profile.loadout(candidate, true, preview_ling), form)
		for stat in ["attack", "hp", "armor", "reach"]:
			var old := _value_points(current_stats[stat])
			var next := _value_points(projected[stat])
			if old == next:
				continue
			var caption: String = {"attack":"攻击", "hp":"生命", "armor":"减伤", "reach":"距离"}[stat]
			var delta := _value_points(absf(projected[stat] - current_stats[stat]))
			var sign_text := "+" if projected[stat] > current_stats[stat] else "−"
			preview_delta.text = ("%s %s%s   %s → %s" if vertical else "%s %s%s\n%s → %s") % [caption, sign_text, delta, old, next]
			preview_delta.add_theme_color_override("font_color", Slot.GOOD if projected[stat] > current_stats[stat] else Slot.BAD)
			preview_delta.show()
			break
		var first_cell: Slot = bag_items[candidate.uid]
		first_cell.highlighted = true
		first_cell.queue_redraw()
	change_button.visible = not visible_items.is_empty()
	craft_button.visible = visible_items.is_empty()
	craft_button.text = "打造" + ("第一件装备" if profile.items().is_empty() and filter_slot.is_empty() else ("装备" if filter_slot.is_empty() else _slot_name(filter_slot)))

func _pad_grid() -> void:
	var columns := bag_grid.columns
	var target := columns * maxi(2, ceili(float(bag_items.size()) / columns))
	while bag_grid.get_child_count() > target:
		var last := bag_grid.get_child(-1)
		bag_grid.remove_child(last)
		last.queue_free()
	while bag_grid.get_child_count() < target:
		var empty := Panel.new()
		empty.mouse_filter = MOUSE_FILTER_IGNORE
		empty.custom_minimum_size = Vector2.ONE * (BAG_SLOT_SIZE if vertical else 54)
		empty.add_theme_stylebox_override("panel", empty_plate)
		bag_grid.add_child(empty)

func _kind(input: Dictionary) -> String:
	if input.slot == "weapon":
		return Gear.Rules.NAME_PARTS.weapons.get(input.get("weapon_form", "sword"), "武器")
	var style: String = input.get("armor_type", "cloth")
	if input.slot == "armor":
		var names: Dictionary = Gear.Rules.NAME_PARTS.armor_types_female if profile.character().get("gender") == "female" else Gear.Rules.NAME_PARTS.armor_types
		return names.get(style, "上衣")
	return Gear.Rules.NAME_PARTS.gear_types.get(style, "布") + _slot_name(input.slot)

func _combat_values(config: Dictionary, form: String) -> Dictionary:
	var bonuses := Loadout.bonuses(config, profile.character(), profile.layer())
	var snapshot := Combat.new()
	snapshot._apply_equipment(bonuses, form)
	var values := {"attack": float(snapshot.hero.damage), "hp": float(snapshot.max_hp),
		"armor": snapshot.damage_reduction * 100.0, "interval": float(snapshot.hero.interval),
		"reach": float(snapshot.hero.reach), "mana": snapshot.max_mana, "crit": snapshot.crit_chance * 100.0,
		"retreat_seconds": snapshot.retreat_cooldown, "matchup": float(bonuses.weapon_matchup),
		"feed": float(bonuses.feed_enemy_ratio) * 100.0}
	for stat in Loadout.STAT_NAMES:
		if not values.has(stat) and stat not in ["attack_speed", "dodge_cooldown"]:
			values[stat] = float(bonuses.get(stat, 0.0))
	return values

func _refresh_detail(input: Dictionary, config: Dictionary, form: String) -> void:
	forge._clear(detail_body)
	var live := profile.describe(input, true, preview_ling)
	var element := Loadout.dominant(live.wuxing)
	var equipped := profile.item(profile.equipped(input.slot))
	var active: bool = equipped.get("uid", "") == input.uid
	detail_icon.display(input.slot, live, profile.character(), input.get("weapon_form", ""))
	detail_title.text = live.name
	var tint: Color = Gear.MATERIAL_COLORS.get(element, ui.GOLD)
	detail_title.add_theme_color_override("font_color", tint.lerp(ui.INK, 0.72))
	detail_meta.text = "%s  ·  %s行  ·  %s" % [_kind(input), WuXing.ELEMENT_NAMES.get(element, "无"), "已穿戴" if active else "背包"]
	equip_button.text = "卸下" if active else "装备"
	breakdown.text = "返回属性" if advanced else "更多操作"
	if input.slot in Gear.ARMOR_TYPE_SLOTS:
		var row := HFlowContainer.new()
		detail_body.add_child(row)
		for dye in Gear.Pigments.GARMENT_DYES:
			var choice: Button = forge._button(dye, 32, _dye.bind(input.uid, dye))
			choice.disabled = dye == input.get("dye", "本色")
			row.add_child(choice)
	if advanced:
		_management(input)
		return
	if active:
		_line(detail_body, "装备词条", 14, ui.GOLD)
		for stat in live.stats:
			_line(detail_body, "%s   +%s 点" % [Loadout.STAT_NAMES.get(stat, stat), String.num(live.stats[stat], 1)], 14, ui.INK)
		detail_body.add_child(forge._button("查看同部位背包", 40, _open_bag.bind(input.slot)))
	else:
		var other: String = profile.describe(equipped).name if not equipped.is_empty() else "空槽"
		_line(detail_body, "替换  " + other, 14, ui.INK)
		var affixes := PackedStringArray()
		var intrinsic := profile.describe(input)
		for stat in intrinsic.stats:
			affixes.append("%s +%s" % [Loadout.STAT_NAMES.get(stat, stat), _value_points(intrinsic.stats[stat])])
		if not affixes.is_empty():
			_line(detail_body, "固有词条   " + "   ".join(affixes), 12, ui.MUTED)
		var after := profile.loadout(input, true, preview_ling)
		var projected := _combat_values(after, input.get("weapon_form", form) if input.slot == "weapon" else form)
		_comparison(current_stats, projected)
		if after.patterns != config.patterns:
			_line(detail_body, "格局   %s → %s" % [Loadout.pattern_names(config.patterns), Loadout.pattern_names(after.patterns)], 12, ui.GOLD)
		if not equipped.is_empty():
			var lost: String = forge._effect_text(profile.describe(equipped, true, preview_ling))
			if not lost.is_empty():
				_line(detail_body, "换下效果   " + lost, 12, ui.MUTED)
	var effect: String = forge._effect_text(live)
	if not effect.is_empty():
		_line(detail_body, "装备效果   " + effect, 13, Slot.GOOD)

func _comparison(before: Dictionary, after: Dictionary) -> void:
	var table: GridContainer = forge._grid(detail_body, 3, 4)
	for label in ["渡劫属性" if not preview_ling.is_empty() else "本层属性", "当前", "换上后"]:
		_table_cell(table, label, ui.GOLD)
	var changed := 0
	var extra := {"interval": "攻击间隔", "reach": "攻击距离", "retreat_seconds": "后撤冷却",
		"matchup": "五行伤害倍率", "feed": "为敌回血比例"}
	for stat in before:
		var old := _value(stat, before[stat])
		var next := _value(stat, after[stat])
		if old == next:
			continue
		changed += 1
		var decrease := float(after[stat]) < float(before[stat])
		var good := decrease if stat in ["interval", "retreat_seconds", "feed"] else not decrease
		_table_cell(table, extra.get(stat, Loadout.STAT_NAMES.get(stat, stat)), ui.INK)
		_table_cell(table, old + " →", ui.MUTED)
		_table_cell(table, next + (" ↓" if decrease else " ↑"), Slot.GOOD if good else Slot.BAD)
	if changed == 0:
		table.hide()
		_line(detail_body, "换装后角色数值相同", 14, ui.MUTED)

func _table_cell(table: GridContainer, title: String, ink: Color) -> void:
	var label := _line(table, title, 13, ink)
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	if table.get_child_count() % 3 != 1:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _value_points(number: float) -> String:
	return str(roundi(number)) if is_equal_approx(number, roundf(number)) else String.num(number, 1)

func _value(stat: String, number: float) -> String:
	if stat in ["interval", "retreat_seconds"]:
		return String.num(number, 2) + " 秒"
	if stat == "matchup":
		return String.num(number, 2) + "×"
	return _value_points(number) + ("%" if stat == "feed" or Gear.Rules.STAT_CURVES.has(stat) else "")

func _dye(uid: String, dye: String) -> void:
	if profile.dye_item(uid, dye):
		refresh()
	else:
		forge._message(profile.storage_error)

func _toggle_equipped() -> void:
	var input := profile.item(selected_uid)
	if input.is_empty():
		return
	var active := profile.equipped(input.slot) == selected_uid
	if not profile.toggle_equip(selected_uid):
		forge._message(profile.storage_error)
		return
	advanced = false
	merging = false
	detail_scroll.scroll_vertical = 0
	refresh()
	forge._message(("已卸下　" if active else "已装备　") + profile.describe(input).name)

func _show_patterns() -> void:
	var config := profile.loadout({}, true, preview_ling)
	var rows := PackedStringArray([Loadout.pattern_names(config.patterns), ""])
	for element in WuXing.WUXING:
		rows.append("%s行    %s%%" % [WuXing.ELEMENT_NAMES[element], String.num(float(config.weights[element]) * 100.0, 1)])
	rows.append("\n残渣 %s   ·   首领核心 %d" % [String.num(profile.state.residue, 2), profile.stock("relic_core")])
	forge.show_report("五行格局", "\n".join(rows))

func _management(input: Dictionary) -> void:
	detail_body.add_child(forge._button("查看内在数值与五行推导", 40, forge.show_derivation.bind(input, preview_ling)))
	var rename := LineEdit.new()
	rename.placeholder_text = "装备名称"
	rename.max_length = 24
	rename.text = input.name
	rename.size_flags_horizontal = SIZE_EXPAND_FILL
	var row: HBoxContainer = ui._hbox(5)
	detail_body.add_child(row)
	row.add_child(rename)
	var rename_button: Button = forge._button("改名", 40, func() -> void:
		if profile.rename_item(input.uid, rename.text):
			refresh()
		else:
			forge._message(profile.storage_error))
	rename_button.size_flags_horizontal = SIZE_SHRINK_END
	row.add_child(rename_button)
	if profile.process_unlocked("rotate"):
		_line(detail_body, _rotation_text(input), 12, ui.MUTED)
		detail_body.add_child(forge._button("轮转五行", 40, func() -> void:
			if profile.rotate_item(input.uid):
				merge_armed = false
				refresh()
				forge._message("五行已轮转")
			else:
				forge._message(profile.storage_error)))
	var others := profile.items().filter(func(entry: Dictionary) -> bool: return entry.slot == input.slot and entry.uid != input.uid)
	if profile.process_unlocked("merge") and not others.is_empty():
		detail_body.add_child(forge._button("熔合", 40, func() -> void:
			merging = not merging
			merge_armed = false
			refresh()))
		if merging:
			_merge_options(input, others)

func _rotation_text(input: Dictionary) -> String:
	var planning := input.duplicate()
	var path := PackedStringArray()
	var first_favorable := 0
	for i in range(1, 6):
		planning.rotation = int(input.rotation) + i
		var outcome := profile.describe(planning, true, preview_ling)
		var element := Loadout.dominant(outcome.wuxing)
		if element.is_empty():
			continue
		path.append(WuXing.ELEMENT_NAMES[element] + outcome.jingyu[element])
		if first_favorable == 0 and Loadout.badge(outcome, profile.character()).fit > 0:
			first_favorable = i
	var hint := " · %d 次达用神" % first_favorable if first_favorable > 0 else ""
	return "轮转 " + " → ".join(path) + hint + "  ·  磨损 %d" % int(input.wear)

func _merge_options(input: Dictionary, items: Array) -> void:
	var picker: OptionButton = forge._option()
	var selected := 0
	for index in range(items.size()):
		var candidate: Dictionary = items[index]
		picker.add_item(profile.describe(candidate).name)
		if candidate.uid == merge_partner:
			selected = index
	merge_partner = items[selected].uid
	picker.select(selected)
	picker.item_selected.connect(func(index: int) -> void:
		merge_partner = items[index].uid
		merge_sockets.clear()
		merge_armed = false
		refresh())
	detail_body.add_child(picker)
	var source_sockets: Array = input.sockets + items[selected].sockets
	if not source_sockets.is_empty() and profile.socket_limit() > 0:
		var pick_sockets: GridContainer = forge._grid(detail_body, 4, 3)
		for stem in WuXing.STEMS:
			if not source_sockets.has(stem):
				continue
			var toggle: Button = forge._chip("留" + Gear.stem_name(stem), _merge_socket.bind(stem))
			toggle.set_pressed_no_signal(merge_sockets.has(stem))
			pick_sockets.add_child(toggle)
	var draft_item := profile.merge_draft(input.uid, merge_partner, merge_sockets)
	if draft_item.is_empty():
		return
	var result := profile.describe(draft_item)
	detail_body.add_child(forge._text("熔合预览  %s\n预算 %.1f  ·  磨损 %d" % [result.name, result.budget, draft_item.wear], 12, ui.GOLD))
	var merge_button: Button = forge._button("确认消耗两件成品" if merge_armed else "熔合打造", 35, func() -> void:
		if not merge_armed:
			merge_armed = true
			refresh()
			return
		var new_uid := profile.merge_items(input.uid, merge_partner, merge_sockets)
		if new_uid.is_empty():
			forge._message(profile.storage_error)
			return
		inspect(new_uid)
		forge._message("熔合完成"))
	detail_body.add_child(merge_button)

func _merge_socket(stem: String) -> void:
	if merge_sockets.has(stem):
		merge_sockets.erase(stem)
	elif merge_sockets.size() < profile.socket_limit():
		merge_sockets.append(stem)
	merge_armed = false
	refresh()
