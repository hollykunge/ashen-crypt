extends SceneTree
## Assemble the existing attack poses for a constrained blade-removal edit.
const NAMES := ["ready", "combat-1", "combat-2", "strike", "combat-4", "combat-5", "combat-6", "combat-7", "idle"]
func _initialize() -> void:
	var board := Image.create(2400, 1920, false, Image.FORMAT_RGBA8)
	for i in NAMES.size():
		var frame := Image.load_from_file("res://art/reference-hero/frames/" + NAMES[i] + ".png")
		board.blit_rect(frame, Rect2i(0, 0, 800, 640), Vector2i(i % 3, i / 3) * Vector2i(800, 640))
	board.resize(1600, 1280, Image.INTERPOLATE_LANCZOS)
	board.save_png("res://art/reference-hero/source/blade-removal-layout.png")
	quit()
