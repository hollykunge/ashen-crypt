extends "res://samples/warden_swing/preview.gd"

var dragging := false

func _ready() -> void:
	super._ready()
	get_window().title = "守门人 · 腰侧斜切"
	%Outfit.toggled.connect(_set_outfit)
	%Dye.toggled.connect(_set_dye)
	if "--dye-preview" in OS.get_cmdline_user_args():
		%Outfit.hide()
		%Dye.button_pressed = true
	if "--leather" in OS.get_cmdline_user_args():
		%Outfit.button_pressed = true
	if "--autoplay" in OS.get_cmdline_user_args():
		zoom.button_pressed = true
		get_tree().create_timer(0.55).timeout.connect(field.swing, CONNECT_ONE_SHOT)

func _set_outfit(leather: bool) -> void:
	if leather:
		%Dye.button_pressed = false
	field.set_leather(leather)
	%Outfit.text = "皮甲 · C" if leather else "布衣 · C"

func _set_dye(enabled: bool) -> void:
	if enabled:
		%Outfit.button_pressed = false
	field.set_dye(enabled)
	%Dye.text = "墨青 · D" if enabled else "原色 · D"

func _update_camera() -> void:
	field.refresh_camera()

func _update_phase() -> void:
	var actor: AnimatedSprite3D = field.player
	var phases: PackedStringArray = actor.sprite_frames.get_meta(&"phases")
	phase.text = phases[actor.frame] if actor.animation == &"swing" else "待机"

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_D:
		%Dye.button_pressed = not %Dye.button_pressed
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C and %Outfit.visible:
		%Outfit.button_pressed = not %Outfit.button_pressed
		get_viewport().set_input_as_handled()
		return
	super._input(event)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed and not $Bar.get_global_rect().has_point(event.position)
	elif event is InputEventMouseMotion and dragging:
		field.pan(event.relative.x)
