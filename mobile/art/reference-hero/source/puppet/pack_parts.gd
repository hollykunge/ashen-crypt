extends SceneTree
## Cut the painted layers into independent pieces. A rounded overlap at each hinge
## covers the joint throughout rotation without drawing a line across the skin.
const SOURCE := "res://art/reference-hero/source/puppet/"
const OUT := "res://art/reference-hero/puppet/"
const REGIONS := {
	"torso":Rect2i(112,118,328,581), "pelvis":Rect2i(119,617,311,278), "short_leg":Rect2i(134,688,215,205),
	"upper_arm":Rect2i(648,87,225,445), "forearm":Rect2i(660,394,184,407),
	"hand":Rect2i(699,704,166,240), "thigh":Rect2i(1120,53,232,417),
	"shin":Rect2i(1113,312,223,550), "foot":Rect2i(1115,763,327,190),
	"shirt":Rect2i(111,115,329,683), "sleeve":Rect2i(648,87,225,321)
}

# Rear outline measured on the registered side view. Under the hand the line
# eases into the existing leg, leaving the rotating hip socket covered.
const HIP_EDGE := [Vector2(255,252),Vector2(255,268),Vector2(252,280),Vector2(248,288),
	Vector2(245,300),Vector2(244,308),Vector2(245,320),Vector2(238,340),Vector2(219,360)]
const HIP_VIEWS := {
	"thigh": Transform2D(Vector2(0.341834,0.028252),Vector2(-0.035865,0.433948),Vector2(222.9976,258.7166)),
	"far_thigh": Transform2D(Vector2(0.342641,-0.015681),Vector2(0.019906,0.434972),Vector2(254.9221,259.2701)),
	"short_leg": Transform2D(Vector2(0.334724,0.027665),Vector2(-0.023336,0.282355),Vector2(227.5938,279.0872)),
	"far_short_leg": Transform2D(Vector2(0.30847,-0.132862),Vector2(0.112075,0.260208),Vector2(214.3613,295.186))
}

func _initialize() -> void:
	var body := Image.load_from_file(SOURCE+"body.png")
	var clothes := Image.load_from_file(SOURCE+"shirt.png")
	var inner := Image.load_from_file(SOURCE+"far-limbs.png")
	var extremities := Image.load_from_file(SOURCE+"hands-feet.png")
	var keys := Image.load_from_file(ProjectSettings.globalize_path("res://art/reference-hero/bodies/male/keys.png"))
	if body == null or clothes == null or inner == null or keys == null or extremities == null or body.get_size() != clothes.get_size():
		quit(1)
		return
	inner.resize(910,1024,Image.INTERPOLATE_LANCZOS)
	var far := Image.create_empty(1536,1024,false,Image.FORMAT_RGBA8)
	far.blit_rect(inner,Rect2i(Vector2i.ZERO,inner.get_size()),Vector2i(626,0))
	var head := keys.get_region(Rect2i(152,70,141,155))
	for y in head.get_height():
		for x in head.get_width():
			var p := head.get_pixel(x,y)
			var edge := 145.0 - maxf(0.0,absf(x-66.0)-24.0)*0.55
			p.a *= 1.0-smoothstep(edge-4,edge,y)
			head.set_pixel(x,y,p)
	_save(head,"head")
	var pieces: Array = REGIONS.keys()
	for limb in ["upper_arm","forearm","hand","thigh","shin","foot"]:
		pieces.append("far_"+limb)
	for name_: String in pieces:
		var part := name_.trim_prefix("far_")
		var cloth := part in ["shirt","sleeve"]
		var rect: Rect2i = REGIONS[part]
		var painting := far if name_ != part else (clothes if cloth else body)
		var image := painting.get_region(rect)
		if part in ["hand","foot"]:
			image = _extremity(extremities, part == "foot", name_ == part, rect.size)
		for y in image.get_height():
			for x in image.get_width():
				var pos := Vector2(rect.position)+Vector2(x,y)
				var pixel := image.get_pixel(x,y)
				var a := minf(1.0,pixel.a*255.0/253.0)
				match part:
					"torso":
						a *= 1.0-smoothstep(668,693,pos.y)
						a *= smoothstep(135,169,pos.y)
					"pelvis":
						a *= smoothstep(618,645,pos.y)
						var rise := absf(pos.x-276)/145.0
						var bottom := 831.0-47.0*rise*rise
						a *= 1.0-smoothstep(bottom-16.0,bottom,pos.y)
					"short_leg":
						# Rounded upper overlap disappears inside the hip when the thigh swings.
						a *= _cap(pos,Vector2(242,756),Vector2(99,64),false)
						a *= 1.0-smoothstep(94,100,absf(pos.x-242))
					"upper_arm": a *= _cap(pos,Vector2(732,462),Vector2(58,58),true)
					"forearm":
						a *= _cap(pos,Vector2(732,462),Vector2(58,52),false)
						a *= _cap(pos,Vector2(764,745),Vector2(39,47),true)
					"hand": a *= _cap(pos,Vector2(764,745),Vector2(39,38),false)
					"thigh": a *= _cap(pos,Vector2(1242,384),Vector2(56,37),true)
					"shin":
						a *= _cap(pos,Vector2(1242,384),Vector2(67,63),false)
						a *= _cap(pos,Vector2(1204,809),Vector2(39,35),true)
					"foot": a *= _cap(pos,Vector2(1204,809),Vector2(46,45),false)
					"shirt","sleeve":
						a = smoothstep(0.55,0.92,pixel.a)*smoothstep(-24,-8,pixel.b8-pixel.r8)
				pixel.a = a
				image.set_pixel(x,y,pixel if pixel.a8 > 0 else Color.TRANSPARENT)
		if name_ == "short_leg":
			var far_shorts := Image.create_from_data(image.get_width(),image.get_height(),false,image.get_format(),image.get_data())
			_fit_hip(far_shorts, HIP_VIEWS.far_short_leg)
			_save(far_shorts,"far_short_leg")
		if name_ in ["thigh","far_thigh"]:
			_save(image,"cut_sources/"+name_)
		if HIP_VIEWS.has(name_):
			_fit_hip(image,HIP_VIEWS[name_])
		if name_ in ["thigh", "far_thigh"]:
			_fit_leg_opening(image,HIP_VIEWS[name_],name_ == "far_thigh")
		_save(image,name_)
	quit(0 if preload("res://art/reference-hero/source/puppet/pack_side_body.gd").new().pack() else 1)

func _fit_hip(image: Image, view: Transform2D) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var at := view * Vector2(x+0.5,y+0.5)
			if at.y >= HIP_EDGE[-1].y:
				continue
			var edge: float = HIP_EDGE[0].x
			for i in range(1,HIP_EDGE.size()):
				var a: Vector2 = HIP_EDGE[i-1]
				var b: Vector2 = HIP_EDGE[i]
				if at.y <= b.y:
					edge = lerpf(a.x,b.x,clampf((at.y-a.y)/(b.y-a.y),0,1))
					break
			if at.x < edge+1.0:
				var pixel := image.get_pixel(x,y)
				pixel.a *= smoothstep(edge-0.5,edge+1.0,at.x)
				image.set_pixel(x,y,pixel)

# Each shorts leg and its thigh rotate together. Cut the covered cap in that
# shared rest space. A rounded cap stays behind the pelvis as the thigh swings.
func _fit_leg_opening(image: Image, view: Transform2D, far: bool) -> void:
	var left := 291.0 if far else 244.0
	var right := 324.0 if far else 292.0
	for y in image.get_height():
		for x in image.get_width():
			var at := view * Vector2(x+0.5,y+0.5)
			var u := clampf((at.x-left)/(right-left),0,1)
			var hem := lerpf(336,331,u) if far else lerpf(327,336,u*u)
			var depth := at.y-hem
			if depth > 22:
				continue
			var side_distance := minf(at.x-left,right-at.x)
			var sides := smoothstep(-0.75,0.75,side_distance + maxf(depth,0.0)*0.6)
			var pixel := image.get_pixel(x,y)
			var axis := clampf((at.x-lerpf(left,right,0.5)) / (0.5*(right-left)), -1, 1)
			var overlap := 4.0 + 21.0 * sqrt(maxf(0,1.0-axis*axis))
			pixel.a *= smoothstep(-overlap-0.5,-overlap+0.5,depth) * sides
			image.set_pixel(x,y,pixel)

func _extremity(atlas: Image, foot: bool, near_side: bool, canvas: Vector2i) -> Image:
	var cell := atlas.get_size()/2
	var piece := atlas.get_region(Rect2i(Vector2i(int(near_side),int(foot))*cell,cell))
	for y in piece.get_height():
		for x in piece.get_width():
			if piece.get_pixel(x,y).a < 0.08:
				piece.set_pixel(x,y,Color.TRANSPARENT)
	piece = piece.get_region(piece.get_used_rect())
	var size := Vector2i(294,183) if foot else Vector2i(130,223)
	piece.resize(size.x,size.y,Image.INTERPOLATE_LANCZOS)
	# Register the centre of the painted wrist/ankle to the forearm/shin hinge.
	var pivot := Vector2i(89,46) if foot else Vector2i(65,41)
	var row := piece.get_region(Rect2i(0,pivot.y,size.x,1)).get_used_rect()
	var offset := Vector2i(pivot.x-row.get_center().x,0)
	var result := Image.create_empty(canvas.x,canvas.y,false,Image.FORMAT_RGBA8)
	result.blit_rect(piece,Rect2i(Vector2i.ZERO,size),offset)
	return result

func _cap(p: Vector2, hinge: Vector2, radius: Vector2, distal: bool) -> float:
	if (p.y < hinge.y) == distal:
		return 1.0
	return 1.0-smoothstep(0.86,1.0,((p-hinge)/radius).length())

func _save(image: Image, part: String) -> void:
	image.fix_alpha_edges()
	assert(image.save_png(OUT+part+".png") == OK)
