extends SceneTree
## Apply the inpainted under-blade cloth only inside authored blade contours.
## Every face, limb and clothing pixel outside those contours remains unchanged.
const Blade = preload("res://scripts/reference_blade.gd")
const NAMES := ["ready", "combat-1", "combat-2", "strike", "combat-4", "combat-5", "combat-6", "combat-7", "idle"]
const ROOT := "res://art/reference-hero/"

func _body_bounds(image: Image) -> Rect2i:
	var bits := BitMap.new()
	bits.create_from_image_alpha(image, 0.4)
	var polygons := bits.opaque_to_polygons(Rect2i(Vector2i.ZERO, image.get_size()), 1.0)
	var largest := Rect2i()
	for polygon in polygons:
		var bounds := Rect2(polygon[0], Vector2.ZERO)
		for point in polygon: bounds = bounds.expand(point)
		if bounds.get_area() > largest.get_area(): largest = Rect2i(bounds.grow(3))
	return largest.intersection(Rect2i(Vector2i.ZERO, image.get_size()))

func _initialize() -> void:
	var edited := Image.load_from_file(ROOT + "source/blade-removal.png")
	var cell := Vector2i(edited.get_width() / 3, edited.get_height() / 3)
	for i in NAMES.size():
		var name: String = NAMES[i]
		var contour := Blade.removal_contour(name)
		var area := Rect2(contour[0], Vector2.ZERO)
		for point in contour: area = area.expand(point)
		var work := Rect2i(area.grow(2)).intersection(Rect2i(0,0,800,640))
		var base := Image.load_from_file(ROOT + "frames/" + name + ".png")
		var bare := base.duplicate()
		for y in range(work.position.y, work.end.y):
			for x in range(work.position.x, work.end.x):
				if Geometry2D.is_point_in_polygon(Vector2(x,y), contour): bare.set_pixel(x,y,Color(0,0,0,0))
		# Close only narrow under-blade gaps; do not copy a shifted generated hilt into empty air.
		var backfill := BitMap.new()
		backfill.create_from_image_alpha(bare,0.1)
		var neighborhood := work.grow(36).intersection(Rect2i(0,0,800,640))
		backfill.grow_mask(18,neighborhood)
		backfill.grow_mask(-18,neighborhood)
		var target := _body_bounds(bare)
		var patch := edited.get_region(Rect2i(Vector2i(i % 3, i / 3) * cell, cell))
		var patch_bounds := _body_bounds(patch)
		patch = patch.get_region(patch_bounds)
		patch.resize(target.size.x, target.size.y, Image.INTERPOLATE_LANCZOS)
		for style in ["cloth", "leather", "chain"]:
			var original := base if style == "cloth" else Image.load_from_file(ROOT + "costumes/" + style + "/" + name + ".png")
			var output := original.duplicate()
			for y in range(work.position.y, work.end.y):
				for x in range(work.position.x, work.end.x):
					if not Geometry2D.is_point_in_polygon(Vector2(x,y), contour): continue
					var point := Vector2i(x,y)
					var color := Color(0,0,0,0)
					if target.has_point(point) and backfill.get_bitv(point):
						color = patch.get_pixelv(point - target.position)
					output.set_pixelv(point, color)
			# Keep the full figure plus its antialiased edges, removing detached source specks.
			var body := _body_bounds(output)
			var clean := Image.create(800,640,false,Image.FORMAT_RGBA8)
			clean.blit_rect(output,body,body.position)
			DirAccess.make_dir_recursive_absolute(ROOT + "bodies/" + style)
			clean.save_png(ROOT + "bodies/" + style + "/" + name + ".png")
	print("Prepared nine body poses for a shared fixed-length blade")
	quit()
