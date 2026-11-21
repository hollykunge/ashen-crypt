extends Control

const PHASES := ["待机", "起手", "提剑", "蓄力", "举剑", "过顶", "挥出", "落剑", "回收", "收势", "归位"]

@onready var viewport: SubViewport = $Stage/Viewport
@onready var field = $Stage/Viewport/Arena
@onready var slow: Button = %Slow
@onready var zoom: Button = %Zoom
@onready var phase: Label = %Phase

func _ready() -> void:
	get_window().content_scale_size = Vector2i(844, 390)
	if OS.has_feature("pc") and get_window().size.x < get_window().size.y:
		get_window().size = Vector2i(844, 390)
	get_window().title = "守门人 · 挥剑试演"
	%Attack.pressed.connect(field.swing)
	slow.toggled.connect(func(on: bool): field.player.speed_scale = 0.35 if on else 1.0)
	zoom.toggled.connect(_set_zoom)
	%Previous.pressed.connect(field.step_drawing.bind(-1))
	%Next.pressed.connect(field.step_drawing.bind(1))
	field.player.frame_changed.connect(_update_phase)
	field.player.animation_changed.connect(_update_phase)
	viewport.size_changed.connect(_update_camera)
	_update_phase()
	_update_camera()

func _update_phase() -> void:
	phase.text = PHASES[clampi(field.player.frame, 0, PHASES.size() - 1)] if field.player.animation == &"swing" else "待机"

func _set_zoom(on: bool) -> void:
	field.close_view = on
	_update_camera()

func _update_camera() -> void:
	var factor := 2.65 if field.close_view else 1.0
	var anchor := Vector2(viewport.size.x * 0.46, field.floor_height)
	viewport.canvas_transform = Transform2D(0, Vector2.ONE * factor, 0, anchor * (1.0 - factor))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: field.swing()
			KEY_LEFT: field.step_drawing(-1)
			KEY_RIGHT: field.step_drawing(1)
			KEY_S: slow.button_pressed = not slow.button_pressed
			KEY_Z: zoom.button_pressed = not zoom.button_pressed
			_: return
		get_viewport().set_input_as_handled()
