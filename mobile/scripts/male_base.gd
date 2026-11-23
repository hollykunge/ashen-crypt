extends Sprite2D
## Independent painted body. Coordinates below are in the original 1774 x 887 sheets.
const Frames = preload("res://scripts/reference_frames.gd")
const RingDao = preload("res://scripts/ring_dao.gd")
const ROOT := "res://art/reference-hero/bodies/male/"
const SHIRT_ROOT := "res://art/reference-hero/garments/male/cloth-shirt/"
# Crops in keys.png coordinates, including a transparent filter margin.
const SHIRT_REGIONS := {"ready": Rect2i(540, 230, 258, 293), "strike": Rect2i(1150, 258, 332, 282)}
# Registered hand patches in keys.png. Both are sampled at twice the body resolution.
const HAND_REGIONS := {"ready": Rect2i(569, 396, 106, 88), "strike": Rect2i(1545, 309, 97, 68)}
const STRIKE_WRIST_X := 1574
const KEYS := ["idle", "ready", "strike"]
const KEY_COLUMNS := [0, 390, 950, 1774]
const MOTION_COLUMNS := [0, 440, 880, 1300, 1774]
const SHEET_SCALE := {"keys": 0.6793, "walk": 1.16, "run": 1.12, "combat": 1.10}
# Waist X and ground Y in the atlas, then waist X on the registered 800 x 640 canvas.
# Airborne frames retain the gap between their toes and the ground line.
const REGISTRATION := {
	"keys": [Vector3i(223,806,280), Vector3i(678,805,304), Vector3i(1287,806,349)],
	"walk": [Vector3i(207,434,308), Vector3i(661,436,308), Vector3i(1087,437,292), Vector3i(1534,437,304),
		Vector3i(226,880,316), Vector3i(656,879,304), Vector3i(1093,878,308), Vector3i(1542,878,308)],
	"run": [Vector3i(209,437,328), Vector3i(654,437,332), Vector3i(1089,436,328), Vector3i(1555,437,336),
		Vector3i(207,878,336), Vector3i(667,878,328), Vector3i(1096,872,328), Vector3i(1558,878,332)],
	"combat": [Vector3i(208,435,280), Vector3i(648,435,308), Vector3i(1066,435,324), Vector3i(1498,436,344),
		Vector3i(193,872,324), Vector3i(646,872,292), Vector3i(1020,871,232), Vector3i(1488,872,276)]
}
# Fist centre in atlas pixels and weapon bearing in degrees.
const GRIPS := {
	"keys": [Vector3i(155,488,35), Vector3i(639,443,-24), Vector3i(1608,346,-34)],
	"walk": [Vector3i(141,246,51), Vector3i(601,244,40), Vector3i(1043,253,-21), Vector3i(1562,216,-28),
		Vector3i(266,648,-30), Vector3i(624,675,37), Vector3i(1023,687,53), Vector3i(1456,686,55)],
	"run": [Vector3i(129,224,54), Vector3i(637,235,12), Vector3i(1100,226,-28), Vector3i(1607,192,-25),
		Vector3i(211,657,-24), Vector3i(587,677,37), Vector3i(1018,656,56), Vector3i(1452,646,54)],
	"combat": [Vector3i(182,223,-24), Vector3i(540,169,22), Vector3i(1149,157,-21), Vector3i(1663,150,-12),
		Vector3i(360,601,18), Vector3i(614,649,-28), Vector3i(1025,618,-46), Vector3i(1394,685,50)]
}

var sword := RingDao.new()
var shirt := Sprite2D.new()
var gripping_hand := Sprite2D.new()

func _init() -> void:
	centered = false
	region_enabled = true
	region_filter_clip_enabled = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	shirt.centered = false
	shirt.hide()
	add_child(shirt)
	add_child(sword)
	gripping_hand.centered = false
	gripping_hand.scale = Vector2(0.5, 0.5)
	gripping_hand.hide()
	add_child(gripping_hand)
	hide()

func set_pose(frame: String, armed: bool, wear_shirt := false) -> void:
	var index := KEYS.find(frame)
	var sheet := "keys"
	var columns := KEY_COLUMNS
	var row := 0
	var column := index
	if index < 0:
		sheet = frame.get_slice("-", 0)
		index = frame.get_slice("-", 1).to_int()
		columns = MOTION_COLUMNS
		row = index / 4
		column = index % 4
	texture = Frames.cached_texture(ROOT + sheet + ".png")
	var top := 444 * row
	var bottom := 444 if sheet != "keys" and row == 0 else texture.get_height()
	var origin := Vector2(columns[column], top)
	# The extended wrist is the rightmost part of strike. The armed hand replaces its tip.
	var right: int = STRIKE_WRIST_X if armed and frame == "strike" else columns[column + 1]
	region_rect = Rect2(origin, Vector2(right, bottom) - origin)
	var pin: Vector3i = REGISTRATION[sheet][index]
	var factor: float = SHEET_SCALE[sheet]
	scale = Vector2.ONE * factor
	position = Vector2(pin.z, Frames.FOOT.y) - (Vector2(pin.x, pin.y) - origin) * factor
	shirt.visible = wear_shirt
	if wear_shirt:
		shirt.position = Vector2(SHIRT_REGIONS[frame].position) - origin
		shirt.texture = Frames.cached_texture(SHIRT_ROOT + frame + ".png")
	sword.visible = armed
	gripping_hand.visible = armed and HAND_REGIONS.has(frame)
	sword.show_behind_parent = frame != "ready"
	if gripping_hand.visible:
		gripping_hand.position = Vector2(HAND_REGIONS[frame].position) - origin
		gripping_hand.texture = Frames.cached_texture(ROOT + frame + "-fingers.png")
	if armed:
		var grip: Vector3i = GRIPS[sheet][index]
		sword.attach_at(Vector2(grip.x, grip.y) - origin, deg_to_rad(grip.z), factor)
