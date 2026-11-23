extends RefCounted
## One painted steel blade, attached to the hilt in each stance/attack frame.
## Coordinates are in the unchanged 800x640 source frames; no perspective scaling.
const LENGTH := 190.0
const SOURCE_ROOT := Vector2(302, 314)
const SOURCE_TIP := Vector2(467, 236)
const SOURCE_OUTLINE := [Vector2(302,303), Vector2(350,288), Vector2(399,270), Vector2(438,251),
	Vector2(467,236), Vector2(461,252), Vector2(449,273), Vector2(425,287),
	Vector2(377,306), Vector2(307,326), Vector2(302,323)]
const POSES := {
	"ready": [Vector2(302,314), Vector2(467,236), SOURCE_OUTLINE],
	"combat-1": [Vector2(220,286), Vector2(342,337), [Vector2(218,276),Vector2(254,300),Vector2(297,322),Vector2(344,334),Vector2(339,343),Vector2(314,348),Vector2(280,339),Vector2(247,323),Vector2(211,296)]],
	"combat-2": [Vector2(439,260), Vector2(550,220), [Vector2(439,244),Vector2(479,243),Vector2(520,232),Vector2(552,218),Vector2(546,241),Vector2(530,257),Vector2(505,268),Vector2(477,275),Vector2(438,278)]],
	"strike": [Vector2(564,249), Vector2(697,213), [Vector2(563,239),Vector2(625,236),Vector2(668,225),Vector2(699,211),Vector2(692,232),Vector2(678,248),Vector2(652,257),Vector2(564,261)]],
	"combat-4": [Vector2(522,281), Vector2(596,305), [Vector2(523,268),Vector2(557,283),Vector2(584,286),Vector2(599,300),Vector2(598,311),Vector2(576,317),Vector2(548,308),Vector2(514,290)]],
	"combat-5": [Vector2(298,312), Vector2(450,230), [Vector2(298,301),Vector2(350,282),Vector2(402,255),Vector2(452,227),Vector2(449,253),Vector2(426,276),Vector2(392,294),Vector2(356,308),Vector2(302,325)]],
	"combat-6": [Vector2(267,277), Vector2(368,179), [Vector2(261,266),Vector2(304,239),Vector2(342,206),Vector2(368,176),Vector2(370,194),Vector2(357,220),Vector2(333,244),Vector2(304,265),Vector2(271,287)]],
	"combat-7": [Vector2(196,387), Vector2(296,495), [Vector2(198,377),Vector2(225,420),Vector2(256,464),Vector2(298,491),Vector2(297,498),Vector2(275,499),Vector2(249,488),Vector2(220,463),Vector2(187,396)]],
	"idle": [Vector2(262,359), Vector2(386,444), [Vector2(264,349),Vector2(309,391),Vector2(349,424),Vector2(388,442),Vector2(380,450),Vector2(351,451),Vector2(323,439),Vector2(292,416),Vector2(253,371)]]
}

static func setup(blade: Polygon2D) -> void:
	blade.texture = load("res://art/reference-hero/frames/ready.png")
	blade.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	blade.uv = PackedVector2Array(SOURCE_OUTLINE)
	var vertices := PackedVector2Array()
	for point in SOURCE_OUTLINE: vertices.append(point - SOURCE_ROOT)
	blade.polygon = vertices
	blade.scale = Vector2.ONE * (LENGTH / SOURCE_ROOT.distance_to(SOURCE_TIP))

static func apply(blade: Polygon2D, frame: String) -> void:
	blade.visible = POSES.has(frame)
	if not blade.visible: return
	var pose: Array = POSES[frame]
	blade.position = pose[0]
	blade.rotation = (pose[1] - pose[0]).angle() - (SOURCE_TIP - SOURCE_ROOT).angle()

static func tip_for(frame: String) -> Vector2:
	var pose: Array = POSES[frame]
	return pose[0] + (pose[1] - pose[0]).normalized() * LENGTH

static func removal_contour(frame: String) -> PackedVector2Array:
	var pose: Array = POSES[frame]
	var expanded := Geometry2D.offset_polygon(PackedVector2Array(pose[2]), 4.0)[0]
	var forward: Vector2 = (pose[1] - pose[0]).normalized()
	var side := forward.orthogonal() * 1000.0
	var root: Vector2 = pose[0] + forward
	var half_plane := PackedVector2Array([root+side,root-side,root-side+forward*1000.0,root+side+forward*1000.0])
	return Geometry2D.intersect_polygons(expanded,half_plane)[0]
