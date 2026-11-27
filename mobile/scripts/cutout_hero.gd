extends Node

const PuppetHero = preload("res://scripts/puppet_hero.gd")
const SPRITE_HEIGHT := PuppetHero.SPRITE_HEIGHT

var puppet: PuppetHero
var _pixels := 1.0
var _density := 1.0
var _canvas: CanvasItem

func dress(look: Dictionary) -> void:
	var who := "nvjiang" if look.get("gender") == "female" else "piying"
	if puppet != null:
		if puppet.who == who:
			return
		remove_child(puppet)
		puppet.queue_free()
	puppet = PuppetHero.new(who)
	add_child(puppet)
	puppet.fit(_pixels, _density)

func present_outfit() -> void:
	puppet.present()

func drive(motion: StringName, phase: float, walked: float, running: bool, cues: Array) -> void:
	puppet.drive(motion, phase, walked, running, cues)

func fit(pixels: float, density: float) -> void:
	_pixels = pixels
	_density = density
	if puppet != null:
		puppet.fit(pixels, density)

func draw(canvas: CanvasItem, feet: Vector2, facing: float, ink: Color, offset := Vector2.ZERO) -> void:
	_canvas = canvas
	puppet.draw(canvas, feet, facing, ink, offset)

func _process(_delta: float) -> void:
	if puppet != null:
		puppet.set_active(is_instance_valid(_canvas) and _canvas.is_visible_in_tree())
