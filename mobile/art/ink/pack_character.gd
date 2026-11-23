extends SceneTree
## Deterministic atlas packing only; artwork is authored with ImageGen.
## -- template <output.png> | pack <atlas.png> <outfit-dir>
const ORIGINAL := "res://prototype/cutout/swordsman/parts/"
const NAMES := ["head", "hair", "torso", "pelvis", "upper_arm", "forearm",
	"hand", "far_hand", "thigh", "shin", "weapon", "boot"]
const CELL := Vector2i(512, 512)

func _solid_bounds(image: Image) -> Rect2i:
	var first := image.get_size()
	var last := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.25:
				first = first.min(Vector2i(x, y))
				last = last.max(Vector2i(x, y))
	return Rect2i(first, last - first + Vector2i.ONE) if last.x >= 0 else Rect2i()

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("template <output.png> | pack <atlas.png> <outfit-dir>")
		quit(1)
		return
	if args[0] == "template":
		var sheet := Image.create(2048, 1536, false, Image.FORMAT_RGBA8)
		for i in NAMES.size():
			var image := Image.load_from_file(ORIGINAL + NAMES[i] + ".png")
			var part := image.get_region(image.get_used_rect())
			var factor := minf(400.0 / part.get_width(), 420.0 / part.get_height())
			part.resize(roundi(part.get_width() * factor), roundi(part.get_height() * factor), Image.INTERPOLATE_LANCZOS)
			var cell := Vector2i(i % 4, i / 4) * CELL
			var origin := cell + (CELL - part.get_size()) / 2
			sheet.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), origin)
		sheet.save_png(args[1])
	elif args[0] == "monster" and args.size() == 3:
		var source := Image.load_from_file(args[1])
		var reference := Image.load_from_file("res://art/side/monsters/vine-spirit.png")
		var packed := Image.create(reference.get_width(), reference.get_height(), false, Image.FORMAT_RGBA8)
		var source_cell := Vector2i(source.get_width() / 4, source.get_height() / 3)
		var target_cell := Vector2i(reference.get_width() / 4, reference.get_height() / 3)
		for i in 12:
			var index := Vector2i(i % 4, i / 4)
			var original := reference.get_region(Rect2i(index * target_cell, target_cell))
			var target := _solid_bounds(original)
			var frame := source.get_region(Rect2i(index * source_cell, source_cell))
			var part := frame.get_region(_solid_bounds(frame))
			part.resize(target.size.x, target.size.y, Image.INTERPOLATE_LANCZOS)
			packed.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), index * target_cell + target.position)
		packed.save_png(args[2])
	elif args[0] == "pack" and args.size() == 3:
		var atlas := Image.load_from_file(args[1])
		if atlas.is_empty() or atlas.detect_alpha() == Image.ALPHA_NONE:
			printerr("Atlas must contain genuine alpha transparency")
			quit(1)
			return
		var cell := Vector2i(atlas.get_width() / 4, atlas.get_height() / 3)
		DirAccess.make_dir_recursive_absolute(args[2])
		for i in NAMES.size():
			var name: String = NAMES[i]
			if name == "boot":
				continue # Calf and split boot must share the exact same pixels.
			if not args[2].ends_with("/parts") and name in ["head", "hair", "hand", "far_hand", "weapon"]:
				# Missing skin components intentionally fall back to the base character.
				var skin_path := args[2] + "/" + name + ".png"
				if FileAccess.file_exists(skin_path):
					DirAccess.remove_absolute(skin_path)
				if FileAccess.file_exists(skin_path + ".import"):
					DirAccess.remove_absolute(skin_path + ".import")
				continue
			var source := atlas.get_region(Rect2i(Vector2i(i % 4, i / 4) * cell, cell))
			var used := _solid_bounds(source)
			if not used.has_area():
				printerr("Missing atlas component: " + name)
				quit(1)
				return
			var original := Image.load_from_file(ORIGINAL + name + ".png")
			var target := _solid_bounds(original)
			if name == "shin":
				var boot := Image.load_from_file(ORIGINAL + "boot.png")
				target = target.merge(_solid_bounds(boot))
			var part := source.get_region(used)
			for y in part.get_height():
				for x in part.get_width():
					if part.get_pixel(x, y).a < 0.08:
						part.set_pixel(x, y, Color.TRANSPARENT)
			part.resize(target.size.x, target.size.y, Image.INTERPOLATE_LANCZOS)
			var packed := Image.create(original.get_width(), original.get_height(), false, Image.FORMAT_RGBA8)
			packed.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), target.position)
			if name == "shin":
				var boot := packed.duplicate()
				boot.fill_rect(Rect2i(0, 0, boot.get_width(), 201), Color.TRANSPARENT)
				boot.save_png(args[2] + "/boot.png")
				packed.fill_rect(Rect2i(0, 228, packed.get_width(), packed.get_height() - 228), Color.TRANSPARENT)
			packed.save_png(args[2] + "/" + name + ".png")
		print("Packed 12 aligned components: ", args[2])
	else:
		quit(1)
		return
	quit()
