extends "res://scripts/arena.gd"

const DRAWINGS: SpriteFrames = preload("res://samples/warden_swing/swing.tres")
# Coordinates in the registered drawing canvas, from the toe line to the idle ponytail.
const FOOT_PIVOT := Vector2(610, 912)
const BODY_HEIGHT := 650.0

var player := AnimatedSprite2D.new()
var close_view := false
var breathing_time := 0.0
var inspecting := false

func _ready() -> void:
	run = Combat.new()
	run.continuous = true
	super._ready()
	set_camp_view(false)
	player.sprite_frames = DRAWINGS
	player.visible = false
	add_child(player)
	player.animation_finished.connect(_return_to_idle)
	_return_to_idle()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _process(delta: float) -> void:
	super._process(delta)
	if player.animation == &"idle" and not inspecting:
		breathing_time = fmod(breathing_time + delta * player.speed_scale, 1.2)

func swing() -> void:
	inspecting = false
	player.stop()
	player.play(&"swing")

func _return_to_idle() -> void:
	inspecting = false
	breathing_time = 0.0
	player.play(&"idle")

func step_drawing(direction: int) -> void:
	var first_step := player.animation != &"swing"
	player.animation = &"swing"
	player.pause()
	inspecting = true
	var count := DRAWINGS.get_frame_count(&"swing")
	var target := posmod(player.frame + direction, count)
	if first_step:
		target = 0 if direction > 0 else count - 1
	player.set_frame_and_progress(target, 0)
	queue_redraw()

func _draw_hero() -> void:
	var tex := DRAWINGS.get_frame_texture(player.animation, player.frame)
	var feet := Vector2(size.x * 0.46, floor_height)
	var unit := hero_pixels * 76.0 / BODY_HEIGHT
	draw_set_transform(feet, 0.0, Vector2(hero_pixels * 21, hero_pixels * 3))
	draw_circle(Vector2.ZERO, 1.0, plate.shadow, true, -1.0, true)
	var lift := 0.0
	if player.animation == &"idle":
		lift = 3.8 * (0.5 - 0.5 * cos(TAU * breathing_time / 1.2))
	var origin := feet - FOOT_PIVOT * unit
	draw_set_transform(origin, 0.0, Vector2.ONE * unit)
	# The chest lifts while the line at the boot tops and the soles stay put.
	var width := float(tex.get_width())
	var height := float(tex.get_height())
	var boot_top := FOOT_PIVOT.y - BODY_HEIGHT * 0.17
	for band in [Vector2(0, boot_top), Vector2(boot_top, height)]:
		var rect := Rect2(0, band.x, width, band.y - band.x)
		var dest := rect
		if band.x == 0:
			dest.position.y -= lift
			dest.size.y += lift
		draw_texture_rect_region(tex, dest, rect, Color(1.18, 1.16, 1.14))
	_world_transform()
