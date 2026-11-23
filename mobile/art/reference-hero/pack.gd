extends SceneTree
## Keep the original painted pixels for the three approved poses; register whole-figure frames.
const ROOT := "res://art/reference-hero/"
const Regions = preload("res://art/reference-hero/garment_regions.gd")
const SIZE := Vector2i(800, 640)
const FOOT := Vector2i(300, 560)

func _solid(image: Image) -> Rect2i:
	var a := image.get_size()
	var b := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.35:
				a = a.min(Vector2i(x, y))
				b = b.max(Vector2i(x, y))
	return Rect2i(a, b - a + Vector2i.ONE)

func _paper(c: Color) -> bool:
	return c.r > 0.69 and c.g > 0.51 and c.b > 0.31 and c.r > c.g + 0.015 and c.g > c.b + 0.025

func _key_pose(image: Image, rect: Rect2i, anchor: Vector2i, name: String) -> void:
	var crop := image.get_region(rect)
	crop.convert(Image.FORMAT_RGBA8)
	var w := crop.get_width()
	var h := crop.get_height()
	var removed := PackedByteArray()
	removed.resize(w * h)
	var queue := PackedInt32Array()
	var seeds := {"idle": [Vector2i(181, 535)], "ready": [Vector2i(500, 475)], "strike": [Vector2i(900, 480)]}
	for seed in seeds[name]:
		var point: Vector2i = seed - rect.position
		queue.append(point.y * w + point.x)
	for x in w:
		queue.append(x)
		queue.append((h - 1) * w + x)
	for y in h:
		queue.append(y * w)
		queue.append(y * w + w - 1)
	var cursor := 0
	while cursor < queue.size():
		var index := queue[cursor]
		cursor += 1
		if removed[index]:
			continue
		var x := index % w
		var y := index / w
		if not _paper(crop.get_pixel(x, y)):
			continue
		removed[index] = 1
		if x > 0: queue.append(index - 1)
		if x + 1 < w: queue.append(index + 1)
		if y > 0: queue.append(index - w)
		if y + 1 < h: queue.append(index + w)
	# Keep the connected figure, not isolated paper grain or the detached painted slash arc.
	var visited := PackedByteArray()
	visited.resize(w * h)
	var biggest := PackedInt32Array()
	for seed in w * h:
		if removed[seed] or visited[seed]: continue
		var component := PackedInt32Array([seed])
		visited[seed] = 1
		cursor = 0
		while cursor < component.size():
			var index := component[cursor]
			cursor += 1
			var x := index % w
			var y := index / w
			for offset in [-1, 1, -w, w]:
				var next: int = index + offset
				if next < 0 or next >= w * h or (offset == -1 and x == 0) or (offset == 1 and x == w - 1): continue
				if removed[next] or visited[next]: continue
				visited[next] = 1
				component.append(next)
		if component.size() > biggest.size(): biggest = component
	var keep := PackedByteArray()
	keep.resize(w * h)
	for index in biggest: keep[index] = 1
	for y in h:
		for x in w:
			var source_point := rect.position + Vector2i(x, y)
			var on_shoe := false
			match name:
				"idle": on_shoe = (source_point.x >= 92 and source_point.x <= 151) or (source_point.x >= 154 and source_point.x <= 227)
				"ready": on_shoe = (source_point.x >= 356 and source_point.x <= 405) or (source_point.x >= 542 and source_point.x <= 643)
				"strike": on_shoe = (source_point.x >= 720 and source_point.x <= 769) or (source_point.x >= 1018 and source_point.x <= 1100)
			if not keep[y * w + x] or (source_point.y >= 540 and not on_shoe):
				crop.set_pixel(x, y, Color(0, 0, 0, 0))
	var output := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	output.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), FOOT - (anchor - rect.position))
	output.save_png(ROOT + "frames/" + name + ".png")

func _sequence(name: String, height: float) -> void:
	var atlas := Image.load_from_file(ROOT + "source/" + name + ".png")
	var cell := Vector2i(atlas.get_width() / 4, atlas.get_height() / 2)
	for i in 8:
		var image := atlas.get_region(Rect2i(Vector2i(i % 4, i / 4) * cell, cell))
		var used := _solid(image)
		var part := image.get_region(used)
		# Uniform scale within each clip; no independent limb or horizontal scaling.
		var factor := height / (float(cell.y) * 0.94)
		var head_total := 0.0
		var head_count := 0
		var rear := used.end.x
		for y in used.size.y:
			for x in used.size.x:
				var pixel := part.get_pixel(x, y)
				if pixel.a < 0.5: continue
				var row := float(y) / used.size.y
				if row > 0.08 and row < 0.23 and pixel.r > 0.45 and pixel.r > pixel.b * 1.15:
					head_total += x
					head_count += 1
				if row > 0.94: rear = mini(rear, x)
		part.resize(roundi(used.size.x * factor), roundi(used.size.y * factor), Image.INTERPOLATE_LANCZOS)
		var output := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
		var anchor_x := roundi(head_total / maxf(head_count, 1) * factor - (65.0 if name == "run" else 25.0))
		if name == "combat": anchor_x = roundi(rear * factor + FOOT.x - 157.0)
		# Bent airborne legs shorten the silhouette. Lift the figure so flight raises the hips/head.
		var lift := 52 if name == "run" and i in [3, 7] else 0
		output.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), FOOT - Vector2i(anchor_x, part.get_height() + lift))
		output.save_png(ROOT + "frames/%s-%d.png" % [name, i])

func _costume(source_path: String, style: String) -> void:
	var atlas := Image.load_from_file(source_path)
	var cell := Vector2i(atlas.get_width() / 4, atlas.get_height() / 7)
	var names: Array = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "source/index.json"))
	DirAccess.make_dir_recursive_absolute(ROOT + "costumes/" + style)
	for i in names.size():
		var base := Image.load_from_file(ROOT + "frames/" + names[i] + ".png")
		var part := atlas.get_region(Rect2i(Vector2i(i % 4, i / 4) * cell, cell))
		# Some edit outputs include an opaque preview background; it is never used as alpha.
		var first := cell
		var last := Vector2i(-1, -1)
		for y in cell.y:
			for x in cell.x:
				var c := part.get_pixel(x, y)
				if c.a > 0.4 and c.v < 0.62:
					first = first.min(Vector2i(x, y))
					last = last.max(Vector2i(x, y))
		var visible := Rect2i(first, last - first + Vector2i.ONE)
		var target := _solid(base)
		part = part.get_region(visible)
		part.resize(target.size.x, target.size.y, Image.INTERPOLATE_LANCZOS)
		var output := base.duplicate()
		var region: Array = Regions.POSES[names[i]]
		for y in target.size.y:
			for x in target.size.x:
				var position := target.position + Vector2i(x, y)
				if not Regions.can_paint(region, position): continue
				var original := base.get_pixelv(position)
				if original.a < 0.1: continue
				var row := float(y) / target.size.y
				var skin := smoothstep(0.04, 0.12, original.r - original.g) * smoothstep(0.02, 0.10, original.g - original.b) * smoothstep(0.30, 0.50, original.r)
				var sash := smoothstep(0.08, 0.18, original.r - original.g) * smoothstep(0.10, 0.22, original.r - original.b)
				var protected := maxf(skin if row < 0.72 else 0.0, maxf(sash, smoothstep(0.42, 0.64, original.v)))
				var amount := smoothstep(0.25, 0.29, row) * (1.0 - protected)
				var painted := part.get_pixel(x, y)
				if amount > 0.0 and painted.a > 0.5 and painted.v < 0.58:
					# Preserve the source ink/shadow values; never composite gray preview paper into clothing.
					if painted.v > original.v * 0.9 + 0.12:
						painted *= (original.v * 0.9 + 0.12) / painted.v
					var color := original.lerp(painted, amount)
					# Separate leather and steel at gameplay scale. Keep the painted ink lines,
					# skin and red sash, and limit mail highlights to the upper garment.
					var value := painted.get_luminance()
					var lit := smoothstep(0.045, 0.24, value)
					var finish := Color(0.51, 0.28, 0.14) if style == "leather" else Color(0.49, 0.55, 0.57)
					var detail := 0.0
					if style == "chain" and row < 0.56:
						var ring := Vector2(fposmod(x + (4 if (y / 6) % 2 else 0), 9) - 4, fposmod(y, 6) - 2)
						detail = 0.17 * (1.0 - smoothstep(0.5, 1.4, absf(ring.length() - 2.8)))
					var shade := finish * (0.28 + 2.3 * value + detail)
					color = color.lerp(shade, amount * lit)
					color.a = original.a
					output.set_pixelv(position, color)
		output.save_png(ROOT + "costumes/" + style + "/" + names[i] + ".png")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 3 and args[0] == "costume":
		_costume(args[1], args[2])
		quit()
		return
	if not args.is_empty() and args[0] == "board":
		var names := ["idle", "ready", "strike"]
		for clip in ["walk", "run", "combat"]:
			for i in 8: names.append("%s-%d" % [clip, i])
		var board := Image.create(1600, 2240, false, Image.FORMAT_RGBA8)
		for i in names.size():
			var frame := Image.load_from_file(ROOT + "frames/" + names[i] + ".png")
			frame.resize(400, 320, Image.INTERPOLATE_LANCZOS)
			board.blit_rect(frame, Rect2i(0, 0, 400, 320), Vector2i(i % 4, i / 4) * Vector2i(400, 320))
		board.save_png(ROOT + "source/wardrobe-layout.png")
		var index := FileAccess.open(ROOT + "source/index.json", FileAccess.WRITE)
		index.store_string(JSON.stringify(names))
		quit()
		return
	DirAccess.make_dir_recursive_absolute(ROOT + "frames")
	var source := Image.load_from_file(ROOT + "source/approved.jpg")
	_key_pose(source, Rect2i(65, 50, 215, 508), Vector2i(175, 554), "idle")
	_key_pose(source, Rect2i(343, 105, 343, 453), Vector2i(500, 554), "ready")
	_key_pose(source, Rect2i(707, 127, 569, 431), Vector2i(860, 554), "strike")
	_sequence("walk", 500.0)
	_sequence("run", 480.0)
	_sequence("combat", 455.0)
	var idle := Image.load_from_file(ROOT + "frames/idle.png")
	idle.get_region(Rect2i(240, 58, 115, 150)).save_png(ROOT + "portrait.png")
	print("Registered approved poses and 24 whole-figure animation frames")
	quit()
