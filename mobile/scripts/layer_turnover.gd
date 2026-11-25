extends Control

const Gear = preload("res://scripts/gear.gd")
const Roster = preload("res://scripts/roster.gd")
const HIGHER := Color("#bde6a8")
const LOWER := Color("#ffab9c")

var ui
var animation: Tween
var content: VBoxContainer
var cards := {}
var heading: Label
var flow: HBoxContainer
var outgoing: Label
var incoming: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui._fill(center)
	add_child(center)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size.x = 330
	panel.add_theme_stylebox_override("panel", ui.paper_box(1.0, 12))
	center.add_child(panel)
	content = ui._vbox(7)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	heading = _label("", 23, ui.INK)
	heading.add_theme_font_override("font", ui.HEADING_FONT)
	content.add_child(heading)
	flow = ui._hbox(12)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(flow)
	outgoing = _label("", 24, ui.MUTED)
	incoming = _label("", 24, ui.GOLD)
	flow.add_child(outgoing)
	flow.add_child(_label("→", 22, ui.GOLD))
	flow.add_child(incoming)
	content.add_child(_label("当令更替 · 全身装备境遇", 12, ui.MUTED))
	var grid := GridContainer.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 5)
	content.add_child(grid)
	for i in range(Gear.SLOTS.size()):
		var wrapper := Control.new()
		wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wrapper.custom_minimum_size = Vector2(146, 55)
		grid.add_child(wrapper)
		var plate := PanelContainer.new()
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_theme_stylebox_override("panel", ui._box(ui.IRON, Color(ui.BORDER, 0.6), 1, 3))
		ui._fill(plate)
		wrapper.add_child(plate)
		var caption := _label("", 12, ui.INK)
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plate.add_child(caption)
		cards[Gear.SLOTS[i]] = {"panel": plate, "label": caption}

func play(from: String, to: String, before: Dictionary, after: Dictionary, layer: int, breakthrough: String) -> void:
	dismiss()
	heading.text = "踏入第 %d 层" % layer if breakthrough.is_empty() else "破境 · " + breakthrough
	outgoing.text = Gear.ling_caption(from)
	incoming.text = Gear.ling_caption(to)
	outgoing.add_theme_color_override("font_color", Roster.ELEMENT_GLOW[Gear.WuXing.stem_element(from)])
	incoming.add_theme_color_override("font_color", Roster.ELEMENT_GLOW[Gear.WuXing.stem_element(to)])
	modulate.a = 0.0
	show()
	animation = create_tween().set_parallel(true)
	animation.tween_property(self, "modulate:a", 1.0, 0.22)
	for i in range(Gear.SLOTS.size()):
		var slot: String = Gear.SLOTS[i]
		var card: Dictionary = cards[slot]
		var label: Label = card.label
		var panel: PanelContainer = card.panel
		var previous: Dictionary = before.get(slot, {})
		var current: Dictionary = after.get(slot, {})
		_update_card(label, Gear.SLOT_NAMES[i], previous, current)
		panel.modulate.a = 0.0
		panel.offset_top = 17.0
		panel.offset_bottom = 17.0
		var delay := 0.18 + 0.10 * i
		animation.tween_property(panel, "modulate:a", 1.0, 0.22).set_delay(delay)
		animation.tween_property(panel, "offset_top", 0.0, 0.34).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		animation.tween_property(panel, "offset_bottom", 0.0, 0.34).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	animation.chain().tween_interval(2.50)
	animation.chain().tween_property(self, "modulate:a", 0.0, 0.32)
	animation.chain().tween_callback(hide)

func dismiss() -> void:
	if animation != null:
		animation.kill()
		animation = null
	hide()

func _update_card(label: Label, title: String, before: Dictionary, after: Dictionary) -> void:
	if before.is_empty() or after.is_empty() or after.wuxing.is_empty():
		label.text = title + "\n空位"
		label.add_theme_color_override("font_color", ui.MUTED)
		return
	var element := Gear.Loadout.dominant(after.wuxing)
	var q_change := float(after.q) - float(before.q)
	var shi_change := float(after.shi) - float(before.shi)
	var change := q_change if not is_zero_approx(q_change) else shi_change
	var arrow := " ↑" if change > 0.0001 else (" ↓" if change < -0.0001 else "")
	label.text = "%s%s\n%s %.2f  →  %s %.2f" % [title, arrow, before.jingyu[element], before.q, after.jingyu[element], after.q]
	if is_zero_approx(q_change) and not is_zero_approx(shi_change):
		label.text += "\n阴阳势 %.2f → %.2f" % [before.shi, after.shi]
	label.add_theme_color_override("font_color", HIGHER if change > 0.0001 else (LOWER if change < -0.0001 else ui.INK))

func _label(text: String, size_px: int, ink: Color) -> Label:
	var label: Label = ui._label(text, size_px, ink)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label
