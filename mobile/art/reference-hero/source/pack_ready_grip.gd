extends SceneTree
## Extract the near hand from each registered guard-contact painting. The far thumb is occluded.
const MaleBase = preload("res://scripts/male_base.gd")
const SOURCE := "res://art/reference-hero/source/"
const CROP_ORIGINS := {"ready": Vector2(535,353), "strike": Vector2(1490,261)}
const REFERENCE_SIZE := Vector2(240,160)
const DENSITY := 2
const SUPERSAMPLE := 3

func _initialize() -> void:
	for pose: String in CROP_ORIGINS:
		var art := Image.load_from_file(SOURCE + pose + "-guard-hand.png")
		if art == null:
			quit(1)
			return
		var outline := PackedVector2Array()
		var matte: Image
		if pose == "ready":
			outline = _ready_outline(art)
			if outline.is_empty():
				push_error("Could not isolate the ready hand")
				quit(1)
				return
		else:
			matte = Image.load_from_file(SOURCE + "strike-hand-mask.svg")
			if matte == null or matte.get_size() != art.get_size():
				push_error("Strike hand matte must match its painting")
				quit(1)
				return
		var bounds: Rect2i = MaleBase.HAND_REGIONS[pose]
		var ratio := Vector2(art.get_size()) / REFERENCE_SIZE
		var samples := DENSITY * SUPERSAMPLE
		var result := Image.create_empty(bounds.size.x*samples, bounds.size.y*samples, false, Image.FORMAT_RGBA8)
		for y in result.get_height():
			for x in result.get_width():
				var atlas := Vector2(bounds.position) + (Vector2(x,y) + Vector2(0.5,0.5)) / samples
				var source: Vector2 = (atlas - CROP_ORIGINS[pose]) * ratio
				var coverage := 0.0
				if pose == "ready":
					# Register the wrist contour and curled tips to the unarmed silhouette.
					source.x += 20.0 * (1.0-smoothstep(450,630,source.x)) * smoothstep(345,460,source.y)
					source.x -= 4.0 * smoothstep(650,810,source.x)
					if source.y > 500.0:
						var stretch := 1.0 + 0.25 * smoothstep(360,520,source.x)
						source.y = 500.0 + (source.y - 500.0) / stretch
					if not Geometry2D.is_point_in_polygon(source, outline):
						continue
					coverage = smoothstep(700,825,source.x+source.y)
				else:
					# Align the upper and lower wrist edges through the short crossfade.
					source.y += lerpf(6,-12,smoothstep(390,595,source.y)) * (1.0-smoothstep(385,475,source.x))
					var wrist_end := lerpf(530,425,smoothstep(400,570,source.y))
					coverage = matte.get_pixelv(Vector2i(source)).a * smoothstep(wrist_end-45,wrist_end,source.x)
					if coverage <= 0.0:
						continue
				var pixel := art.get_pixelv(Vector2i(source))
				pixel.a = coverage
				result.set_pixel(x,y,pixel)
		result.fix_alpha_edges()
		result.resize(bounds.size.x*DENSITY, bounds.size.y*DENSITY, Image.INTERPOLATE_LANCZOS)
		if result.save_png(MaleBase.ROOT + pose + "-fingers.png") != OK:
			quit(1)
			return
	quit()

func _ready_outline(art: Image) -> PackedVector2Array:
	var skin := BitMap.new()
	skin.create(art.get_size())
	for y in range(220,790):
		for x in range(180,960):
			var p := art.get_pixel(x,y)
			if p.r8 > 105 and p.g8 > 62 and p.r8-p.g8 > 15 and p.r8-p.b8 > 33:
				skin.set_bit(x,y,true)
	for shape in skin.opaque_to_polygons(Rect2i(Vector2i.ZERO,art.get_size()),1.0):
		if Geometry2D.is_point_in_polygon(Vector2(573,525),shape):
			return Geometry2D.offset_polygon(shape,7.0,Geometry2D.JOIN_ROUND)[0]
	return PackedVector2Array()
