class_name ArtPlate
extends StyleBox

## Source cuts are measured in the native artwork. The destination caps stay
## at UI scale even on phones that render several physical pixels per UI unit.
var patch := StyleBoxTexture.new()
var corner_limit := 20.0
var end_fraction := Vector2(0.07, 0.09)
var full_height := false
var backing := Color.TRANSPARENT
var texture: Texture2D:
	set(value):
		patch.texture = value
	get:
		return patch.texture
var modulate_color: Color:
	set(value):
		patch.modulate_color = value
	get:
		return patch.modulate_color

func _draw(canvas: RID, rect: Rect2) -> void:
	if texture == null or not rect.has_area():
		return
	if backing.a > 0.0:
		RenderingServer.canvas_item_add_rect(canvas, rect.grow(-2.0), backing)
	var native := texture.get_size()
	var cut := (native * end_fraction).round().max(Vector2.ONE)
	var density := minf(rect.size.y / native.y if full_height else corner_limit / maxf(cut.x, cut.y),
		minf(rect.size.x / (2.0 * cut.x), rect.size.y / (2.0 * cut.y)))
	patch.texture_margin_left = cut.x
	patch.texture_margin_right = cut.x
	patch.texture_margin_top = cut.y
	patch.texture_margin_bottom = cut.y
	RenderingServer.canvas_item_add_set_transform(canvas, Transform2D(0.0, Vector2.ONE * density, 0.0, rect.position))
	patch.draw(canvas, Rect2(Vector2.ZERO, rect.size / density))
	RenderingServer.canvas_item_add_set_transform(canvas, Transform2D.IDENTITY)

