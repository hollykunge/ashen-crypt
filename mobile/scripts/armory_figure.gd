extends Control

const HeldWeapon = preload("res://scripts/held_weapon.gd")
const Figure = preload("res://scripts/figure.gd")
const Rig = preload("res://scripts/rig.gd")
const Appearance = preload("res://scripts/appearance.gd")

const WornSprites = preload("res://scripts/worn_sprites.gd")

var sprite: Texture2D
var look := {}
var female := false

func display(config: Dictionary, person: Dictionary, form: String) -> void:
	look = Appearance.build(config.entries, config.patterns, form)
	female = person.get("gender") == "female"
	sprite = WornSprites.texture(female, look)
	queue_redraw()

func _draw() -> void:
	if look.is_empty() or size.x < 1 or size.y < 1:
		return
	# 五种持械站姿使用同一取景比例，切换武器时脚底保持在同一位置。
	var bounds := Rect2(-32, -88, 76, 93)
	var factor := minf((size.y - 6.0) / bounds.size.y, (size.x - 6.0) / bounds.size.x)
	if factor <= 0.0:
		return
	var foot := size * 0.5 - bounds.get_center() * factor
	var rig := Rig.new(foot, factor, 1.0, 69.0, 52.0)
	var halo_rig := Rig.new(foot, minf(factor, size.x / 100.0))
	Figure.halo(self, halo_rig, look, 0.8)
	draw_set_transform(foot, 0.0, Vector2.ONE * factor)
	HeldWeapon.draw_actor(self, sprite, int(female), 0, look)
	draw_set_transform(Vector2.ZERO)
	Figure.charms(self, rig, look, 0.8)
