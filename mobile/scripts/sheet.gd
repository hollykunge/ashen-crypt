extends Control

# 挂机页上浮起的一张卡：背后压暗，点卡外面或按「关闭」收起。战斗照常在背后跑。

signal closed

var ui
var card: PanelContainer
var body: VBoxContainer

func build(main) -> void:
	ui = main
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(ui.NIGHT, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	ui._fill(dim)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	ui._fill(center)
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", ui.paper_box(1.0, 14))
	card.custom_minimum_size.x = 330.0
	center.add_child(card)
	body = ui._vbox(8)
	card.add_child(body)
	gui_input.connect(_outside)
	hide()

func open() -> void:
	show()
	move_to_front()

func close() -> void:
	if visible:
		hide()
		closed.emit()

func _outside(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if tapped and not card.get_global_rect().has_point(event.position):
		close()
		accept_event()

func _fit_width() -> void:
	card.custom_minimum_size.x = clampf(size.x - 32.0, 280.0, 380.0)

func _title(text: String, subtitle: String = "") -> void:
	if not subtitle.is_empty():
		body.add_child(_text(subtitle, 12, ui.GOLD))
	var heading: Label = ui._label(text, 26, ui.INK)
	body.add_child(heading)

func _section(text: String) -> void:
	var line: Label = ui._label(text, 13, ui.GOLD)
	line.add_theme_constant_override("line_spacing", 0)
	body.add_child(line)
	var rule := ColorRect.new()
	rule.color = Color(ui.BORDER, 0.55)
	rule.custom_minimum_size.y = 1.0
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(rule)

func _text(text: String, pixels: int, color: Color) -> Label:
	var label: Label = ui._label(text, pixels, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

# 两列的「名目 · 数值」表。
func _pairs(rows: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 3)
	for row in rows:
		grid.add_child(ui._label(String(row[0]), 14, ui.MUTED))
		var value: Label = ui._label(String(row[1]), 14, ui.INK)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(value)
	return grid

func _clear() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()

static func clock(seconds: float) -> String:
	var total := maxi(0, floori(seconds))
	var hours := floori(total / 3600.0)
	var minutes := floori((total % 3600) / 60.0)
	if hours > 0:
		return "%d 小时 %d 分" % [hours, minutes]
	if minutes > 0:
		return "%d 分 %d 秒" % [minutes, total % 60]
	return "%d 秒" % total
