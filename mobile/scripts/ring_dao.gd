extends Sprite2D
## Rigid full-length weapon. Coordinates use the standalone drawing, from pommel to tip.
const ART := preload("res://art/reference-hero/weapons/ring-dao.png")
const GRIP := Vector2(193, 68.5)
const TIP := Vector2(1027, 5.5)
const MODEL_SCALE := 0.255

func _init() -> void:
	texture = ART
	centered = false
	offset = -GRIP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func attach_at(grip_position: Vector2, bearing: float, atlas_scale: float) -> void:
	position = grip_position
	rotation = bearing - (TIP - GRIP).angle()
	# Body atlases have different resolutions. Preserve one size in character space.
	scale = Vector2.ONE * (MODEL_SCALE / atlas_scale)
