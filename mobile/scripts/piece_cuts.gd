extends RefCounted
const DIR := "res://art/reference-hero/puppet/"
const NAMES := {"far_forearm":"内侧前臂","far_upper_arm":"内侧上臂","far_hand":"内侧手",
	"pelvis":"内裤腰部","short_leg":"外裤口","far_short_leg":"内裤口","thigh":"外侧大腿","far_thigh":"内侧大腿"}
static var baked := {}

static func source(part: String) -> Texture2D:
	return load(DIR+"cut_sources/"+part+".png")

static func original_outline(part: String) -> PackedVector2Array:
	var image: Image = load(DIR+part+".png").get_image()
	if image.is_compressed():
		image.decompress()
	var mask := BitMap.new()
	mask.create_from_image_alpha(image,0.45)
	var best := PackedVector2Array()
	var max_area := 0.0
	for poly in mask.opaque_to_polygons(Rect2i(Vector2i.ZERO,image.get_size()),2.0):
		var area := 0.0
		for i in poly.size():
			area += poly[i].cross(poly[(i+1)%poly.size()])
		if absf(area)>max_area:
			best = poly
			max_area = absf(area)
	return best

static func decode(data: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for v in data:
		result.append(Vector2(v[0],v[1]))
	return result

static func texture(part: String, points: Array) -> Texture2D:
	if baked.has(part) and baked[part].points == points:
		return baked[part].texture
	var poly := decode(points)
	var raw := source(part).get_image()
	if raw.is_compressed():
		raw.decompress()
	raw.convert(Image.FORMAT_RGBA8)
	var result := Image.create_empty(raw.get_width(),raw.get_height(),false,Image.FORMAT_RGBA8)
	# Intersect the contour with each row; keep source alpha and soften fractional edges.
	for row in result.get_height():
		var y := float(row)+0.5
		var crossings := PackedFloat32Array()
		for i in poly.size():
			var a := poly[i]
			var b := poly[(i+1)%poly.size()]
			if (a.y<=y and b.y>y) or (b.y<=y and a.y>y):
				crossings.append(lerpf(a.x,b.x,(y-a.y)/(b.y-a.y)))
		crossings.sort()
		for i in range(0,crossings.size()-1,2):
			var lo := clampi(floori(crossings[i]),0,result.get_width())
			var hi := clampi(ceili(crossings[i+1]),0,result.get_width())
			if hi <= lo:
				continue
			result.blit_rect(raw,Rect2i(lo,row,hi-lo,1),Vector2i(lo,row))
			for x in [lo,hi-1]:
				var col := raw.get_pixel(x,row)
				col.a *= clampf(minf(x+1,crossings[i+1])-maxf(x,crossings[i]),0,1)
				result.set_pixel(x,row,col)
	result.fix_alpha_edges()
	result.generate_mipmaps()
	var tex := ImageTexture.create_from_image(result)
	baked[part] = {"texture":tex,"points":points.duplicate(true)}
	return tex
