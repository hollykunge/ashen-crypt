extends RefCounted
## Cut the approved standing painting into joint-local textures. All outlines below
## are in the registered 800 x 640 view, before the independent pieces rotate.
const SHEET := "res://art/reference-hero/bodies/male/keys.png"
const OUT := "res://art/reference-hero/puppet/"
const FLOOR := Vector2(280,560)
const SOURCE_FLOOR := Vector2(223,806)
const SOURCE_SCALE := 0.6793

# The torso extends under the deltoid and into the waistband for overlap.
const TRUNK := [Vector2(263,124),Vector2(285,119),Vector2(303,137),Vector2(299,149),
	Vector2(302,155),Vector2(319,166),Vector2(327,194),Vector2(318,214),Vector2(317,242),
	Vector2(316,276),Vector2(313,281),Vector2(253,279),Vector2(253,254),Vector2(248,240),
	Vector2(244,229),Vector2(240,219),Vector2(237,195),Vector2(236,172),Vector2(240,157),Vector2(259,141)]
const UPPER := [Vector2(240,155),Vector2(249,156),Vector2(256,162),Vector2(260,171),
	Vector2(260,182),Vector2(257,191),Vector2(253,200),Vector2(250,215),Vector2(245,229),
	Vector2(238,244),Vector2(232,251),Vector2(220,253),Vector2(212,249),Vector2(207,242),
	Vector2(207,231),Vector2(214,193),Vector2(216,166),Vector2(224,155)]
const FOREARM := [Vector2(215,234),Vector2(225,232),Vector2(234,234),Vector2(238,244),
	Vector2(242,250),Vector2(242,278),Vector2(238,296),Vector2(241,321),
	Vector2(237,328),Vector2(220,328),Vector2(214,318),Vector2(209,282),Vector2(205,260),Vector2(207,243)]
const HIPS := [Vector2(255,268),Vector2(278,271),Vector2(299,274),Vector2(315,272),
	Vector2(322,299),Vector2(322,312),Vector2(294,317),Vector2(267,313),
	Vector2(243,312),Vector2(245,297),Vector2(250,282)]
const NEAR_SHORT := [Vector2(249,289),Vector2(275,286),Vector2(297,302),Vector2(296,317),
	Vector2(292,336),Vector2(281,331),Vector2(269,328),Vector2(257,327),Vector2(245,328),
	Vector2(242,314),Vector2(244,301)]
const FAR_SHORT := [Vector2(287,296),Vector2(317,290),Vector2(323,311),Vector2(324,331),
	Vector2(309,334),Vector2(291,337),Vector2(287,328)]
const INNER_UPPER := [Vector2(292,157),Vector2(298,156),Vector2(307,162),Vector2(315,174),
	Vector2(319,194),Vector2(317,214),Vector2(317,240),Vector2(315,249),Vector2(301,254),
	Vector2(291,246),Vector2(285,215),Vector2(281,180),Vector2(284,164)]
const INNER_FOREARM := [Vector2(299,237),Vector2(315,236),Vector2(319,244),Vector2(324,256),
	Vector2(328,276),Vector2(332,294),Vector2(341,316),Vector2(340,325),Vector2(326,329),
	Vector2(318,307),Vector2(311,288),Vector2(300,269),Vector2(294,248)]
const INNER_HAND := [Vector2(324,313),Vector2(338,310),Vector2(346,321),Vector2(353,336),
	Vector2(351,356),Vector2(342,366),Vector2(328,365),Vector2(324,359),Vector2(324,341)]
var source: Image

func pack() -> bool:
	source = Image.load_from_file(SHEET)
	if source == null:
		return false
	var trunk := Transform2D(Vector2(0.34986,0),Vector2(0,0.27783),Vector2(204.4302,123.7431))
	var upper := Transform2D(Vector2(0.290551,0.050925),Vector2(-0.055993,0.319462),Vector2(216.5909,115.9241))
	var ok := _cut("torso", Vector2i(346,581), trunk, TRUNK)
	ok = _cut("upper_arm", Vector2i(225,445), upper, UPPER) and ok
	var inner_upper := Transform2D(Vector2(0.294697,-0.012912),Vector2(0.014197,0.324021),Vector2(268.1537,128.1287))
	ok = _cut("far_upper_arm", Vector2i(225,445), inner_upper, INNER_UPPER) and ok
	var inner_fore := Transform2D(Vector2(0.267442,-0.097585),Vector2(0.096147,0.263501),Vector2(272.4384,237.66))
	ok = _cut("far_forearm", Vector2i(184,407), inner_fore, INNER_FOREARM) and ok
	var inner_hand := Transform2D(Vector2(0.244887,-0.089355),Vector2(0.077598,0.212665),Vector2(302.6565,321.5565))
	ok = _cut("far_hand", Vector2i(216,240), inner_hand, INNER_HAND) and ok
	var fore := Transform2D(Vector2(0.284645,0.005088),Vector2(-0.005013,0.280449),Vector2(199.8464,220.5631))
	ok = _cut("forearm", Vector2i(184,407), fore, FOREARM) and ok
	var hip := Transform2D(Vector2(0.349858,0.001028),Vector2(-0.000832,0.283317),Vector2(206.9944,262.015))
	ok = _cut("pelvis", Vector2i(345,278), hip, HIPS) and ok
	var near_short := Transform2D(Vector2(0.334724,0.027665),Vector2(-0.023336,0.282355),Vector2(227.5938,279.0872))
	var far_short := Transform2D(Vector2(0.335514,-0.015355),Vector2(0.012952,0.283022),Vector2(262.0848,278.8859))
	ok = _cut("short_leg", Vector2i(215,205), near_short, NEAR_SHORT) and ok
	ok = _cut("far_short_leg", Vector2i(215,218), far_short, FAR_SHORT) and ok
	return ok

func _sample(at: Vector2) -> Color:
	var uv := (at-FLOOR)/SOURCE_SCALE + SOURCE_FLOOR
	var ij := Vector2i(uv.floor())
	var f := uv - Vector2(ij)
	return source.get_pixelv(ij).lerp(source.get_pixelv(ij+Vector2i.RIGHT),f.x).lerp(
		source.get_pixelv(ij+Vector2i.DOWN).lerp(source.get_pixelv(ij+Vector2i.ONE),f.x),f.y)

func _cut(part: String, size: Vector2i, view: Transform2D, outline: PackedVector2Array) -> bool:
	var layer := Image.create_empty(size.x,size.y,false,Image.FORMAT_RGBA8)
	var save_source := part in ["far_upper_arm","far_forearm","far_hand","pelvis","short_leg","far_short_leg"]
	var uncut := Image.create_empty(size.x,size.y,false,Image.FORMAT_RGBA8) if save_source else null
	for y in size.y:
		for x in size.x:
			var at := view * Vector2(x+0.5,y+0.5)
			var inside := Geometry2D.is_point_in_polygon(at,outline)
			if not inside and not save_source:
				continue
			var pixel := _sample(at)
			if part == "torso":
				# Reconstruct the small covered patch behind the separate arm.
				var edge := lerpf(260,245,clampf((at.y-188.0)/41.0,0,1))
				if at.y > 183 and at.y < 230 and at.x < edge + 1:
					pixel = _sample(Vector2(edge+6.0+absf(at.x-edge)*0.35,at.y))
				pixel.a *= 1.0-smoothstep(274,281,at.y)
			elif part == "forearm":
				pixel.a *= smoothstep(233,243,at.y)
				pixel.a *= 1.0-smoothstep(320,328,at.y)
			elif part == "far_upper_arm":
				# The chest hides this surface in the template. Reuse arm skin beneath the overlap.
				pixel = _sample(Vector2(234+0.30*(at.x-299),clampf(at.y-3,162,239)))
				pixel.a *= 1.0-smoothstep(247,255,at.y)
			elif part == "far_forearm":
				var inner_edge := lerpf(315,325,clampf((at.y-267)/50.0,0,1))
				var blend := smoothstep(inner_edge+0.5,inner_edge+4.0,at.x)
				if blend < 1.0:
					var hidden := _sample(Vector2(222+0.2*(at.x-inner_edge),clampf(at.y,242,315)))
					pixel = hidden.lerp(pixel,blend)
				pixel.a *= smoothstep(236,245,at.y)
				pixel.a *= 1.0-smoothstep(318,329,at.y)
			elif part == "far_hand":
				pixel.a *= smoothstep(311,321,at.y)
			elif part == "upper_arm":
				# Feather the internal shoulder seam, preserving the painted outer edge.
				pixel.a *= 1.0-smoothstep(249,260,at.x)*(1.0-smoothstep(182,197,at.y))
				pixel.a *= 1.0-smoothstep(242,252,at.y)
			if save_source:
				uncut.set_pixel(x,y,pixel)
			if inside:
				layer.set_pixel(x,y,pixel)
	if save_source:
		uncut.fix_alpha_edges()
		if uncut.save_png(OUT+"cut_sources/"+part+".png") != OK:
			return false
	layer.fix_alpha_edges()
	return layer.save_png(OUT+part+".png") == OK
