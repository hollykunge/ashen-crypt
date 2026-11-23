extends Control
const Cuts = preload("res://scripts/piece_cuts.gd")
signal edited(part: String, points: Array)
signal notice(text: String)
var key := "far_forearm"
var poly := PackedVector2Array()
var raw: Texture2D
var grabbed := -1
var backup := PackedVector2Array()
var tex_rect := Rect2()
var factor := 1.0

func inspect(part: String, cuts: Dictionary) -> void:
	key = part
	raw = Cuts.source(key)
	poly = Cuts.decode(cuts[key]) if cuts.has(key) else Cuts.original_outline(key)
	grabbed = -1
	queue_redraw()

func _draw() -> void:
	if raw == null: return
	draw_rect(Rect2(Vector2.ZERO,size),Color("#32332f"))
	var available := size-Vector2(38,68)
	factor = minf(available.x/raw.get_width(),available.y/raw.get_height())
	var span := raw.get_size()*factor
	tex_rect = Rect2((size-span)*0.5,span)
	draw_rect(tex_rect,Color("#726c64"))
	draw_texture_rect(raw,tex_rect,false,Color("#ffffff58"))
	var display := PackedVector2Array()
	for p in poly: display.append(tex_rect.position+p*factor)
	if display.size()>=3:
		if not Geometry2D.triangulate_polygon(display).is_empty():
			var uv := PackedVector2Array()
			for pt in poly:
				uv.append(pt/raw.get_size())
			draw_polygon(display,PackedColorArray([Color.WHITE]),uv,raw)
		var closed := display.duplicate()
		closed.append(display[0])
		draw_polyline(closed,Color("#71f0db"),2,true)
		for i in display.size():
			draw_circle(display[i],5 if grabbed==i else 3.4,Color("#ffe9a2"),true,-1,true)
	draw_string(ThemeDB.fallback_font,Vector2(10,22),"原始图块 · "+Cuts.NAMES[key],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)

func _gui_input(event: InputEvent) -> void:
	if not raw or factor<=0: return
	if event is InputEventMouseButton:
		var pt: Vector2 = (event.position-tex_rect.position)/factor
		if event.pressed:
			var nearest := -1
			var best := 10.0/factor
			for i in poly.size():
				var dist := poly[i].distance_to(pt)
				if dist<best:
					nearest = i
					best = dist
			backup = poly.duplicate()
			if event.button_index==MOUSE_BUTTON_RIGHT and nearest>=0 and poly.size()>3:
				poly.remove_at(nearest)
				commit()
			elif event.button_index==MOUSE_BUTTON_LEFT:
				grabbed = nearest
				if event.double_click and nearest<0:
					for i in poly.size():
						var hit := Geometry2D.get_closest_point_to_segment(pt,poly[i],poly[(i+1)%poly.size()])
						var dist := pt.distance_to(hit)
						if dist<best:
							best = dist
							grabbed = i+1
					if grabbed>=0:
						poly.insert(grabbed,pt)
			accept_event()
		elif event.button_index==MOUSE_BUTTON_LEFT and grabbed>=0:
			grabbed = -1
			if poly != backup: commit()
	elif event is InputEventMouseMotion and grabbed>=0:
		poly[grabbed] = ((event.position-tex_rect.position)/factor).clamp(Vector2.ZERO,raw.get_size())
	queue_redraw()

func commit() -> void:
	if Geometry2D.triangulate_polygon(poly).is_empty() or crosses():
		poly = backup.duplicate()
		notice.emit("轮廓不能交叉")
		return
	var points := []
	for p in poly:
		points.append([p.x,p.y])
	edited.emit(key,points)

func crosses() -> bool:
	for i in poly.size():
		var n := (i+1)%poly.size()
		for j in range(i+2,poly.size()):
			var m := (j+1)%poly.size()
			if m!=i and Geometry2D.segment_intersects_segment(poly[i],poly[n],poly[j],poly[m])!=null:
				return true
	return false
