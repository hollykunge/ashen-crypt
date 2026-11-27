extends Node

const PuppetHero = preload("res://scripts/puppet_hero.gd")
const GearStyles = preload("res://scripts/gear_styles.gd")
const SPRITE_HEIGHT := PuppetHero.SPRITE_HEIGHT

var puppet: PuppetHero
var _outfit := {}  # 现在穿着的 {槽: 款式图目录}
var _pixels := 1.0
var _density := 1.0
var _canvas: CanvasItem

func dress(look: Dictionary) -> void:
	var who := GearStyles.who_for(look.get("gender", ""))
	if puppet == null or puppet.who != who:
		if puppet != null:
			remove_child(puppet)
			puppet.queue_free()
		puppet = PuppetHero.new(who)
		add_child(puppet)
		puppet.fit(_pixels, _density)
		_outfit = {}
	# 上衣、护腕、护腿、靴子按款式名换这一槽的部件图；这个角色没画的款式不换
	var outfit := GearStyles.outfit(who, look.get("styles", {}))
	if outfit != _outfit:
		_outfit = outfit
		puppet.wear(outfit)

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
