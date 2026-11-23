extends Control

signal begin_drag
signal changed(channel: String, value: Vector2)
const LABELS := {"elbow":"肘", "wrist":"腕", "palm":"手掌", "near":"外裤口", "far":"内裤口"}
const INKS := {"elbow":Color("#ffce76"),"wrist":Color("#ffce76"),"palm":Color("#ffce76"),
	"near":Color("#84dfcf"),"far":Color("#84dfcf")}
var actor
var selected := "wrist"
var drag := ""
var delta_to_handle := Vector2.ZERO
var show_handles := true
var cut_canvas: Control

func point(key: String) -> Vector2:
	var pos: Vector2
	match key:
		"elbow": pos = actor._bones.arm_far_lo.global_position
		"wrist": pos = actor._bones.arm_far_hand.global_position
		"palm": pos = actor._bones.arm_far_hand.to_global(Vector2(5,52))
		_: pos = actor.hem_panels[key].to_global(actor.HEM_PIXEL[key])
	return get_global_transform().affine_inverse() * pos

func _draw() -> void:
	if cut_canvas and cut_canvas.visible:
		if actor and show_handles and not cut_canvas.poly.is_empty():
			var sprite: Sprite2D = actor.piece_sprite(cut_canvas.key)
			var line := PackedVector2Array()
			for pt in cut_canvas.poly:
				line.append(get_global_transform().affine_inverse()*sprite.to_global(sprite.get_rect().position+pt))
			line.append(line[0])
			draw_polyline(line,Color("#75e9d7b5"),1.3,true)
		return
	if not actor or not show_handles:
		return
	var shoulder: Vector2 = get_global_transform().affine_inverse()*actor._bones.arm_far_up.global_position
	draw_polyline(PackedVector2Array([shoulder,point("elbow"),point("wrist"),point("palm")]),Color("#d39f57"),2,true)
	for key in LABELS:
		var pos := point(key)
		draw_circle(pos,6,Color("#272521"),true,-1,true)
		draw_arc(pos,9 if selected == key else 6,0,TAU,32,INKS[key],2,true)
		if selected == key:
			draw_string(ThemeDB.fallback_font,pos+Vector2(13,-6),LABELS[key],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)

func _gui_input(event: InputEvent) -> void:
	if cut_canvas and cut_canvas.visible: return
	if not actor or not show_handles:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			drag = ""
			return
		var pick := ""
		var distance := 19.0
		for key in LABELS:
			var gap := point(key).distance_to(event.position)
			if gap < distance:
				pick = key
				distance = gap
		if point(selected).distance_to(event.position) <= 10:
			pick = selected
		if pick.is_empty():
			return
		begin_drag.emit()
		selected = pick
		drag = pick
		delta_to_handle = point(pick)-event.position
		queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion and not drag.is_empty():
		aim(get_global_transform()*(event.position+delta_to_handle))
		queue_redraw()
		accept_event()

func aim(target: Vector2) -> void:
	var upper: Node2D = actor._bones.arm_far_up
	var fore: Node2D = actor._bones.arm_far_lo
	var wrist: Node2D = actor._bones.arm_far_hand
	if drag in ["near","far"]:
		var panel: Sprite2D = actor.hem_panels[drag]
		var rest: Transform2D = actor.hem_rest[drag]
		var offset: Vector2 = panel.get_parent().to_local(target)-rest*actor.HEM_PIXEL[drag]
		# Keep the opening below its pinned waistband.
		var span: float = rest.y.y*(actor.HEM_PIXEL[drag].y-68.0)
		offset.y = clampf(offset.y,-0.8*span,span)
		offset.x = clampf(offset.x,-span,span)
		changed.emit(drag,offset)
	elif drag == "palm":
		var dir: Vector2 = fore.to_local(target)-wrist.position
		var angle := wrapf(dir.angle()-Vector2(5,52).angle()-actor.arm_rest.z,-PI,PI)
		changed.emit("palm",Vector2(angle,0))
	else:
		var dir: Vector2 = upper.get_parent().to_local(target)-upper.position
		if dir.length_squared() < 0.001:
			return
		var rotations: Vector2 = actor.edit_value("arm")
		if drag == "elbow":
			rotations.x = wrapf(dir.angle()-fore.position.angle()-actor.arm_rest.x,-PI,PI)
		else:
			var a := fore.position.length()
			var b := wrist.position.length()
			var reach := clampf(dir.length(),absf(a-b)+0.01,a+b-0.01)
			var elbow_dir := (upper.transform*fore.position-upper.position).angle()
			var actual: Vector2 = upper.get_parent().to_local(wrist.global_position)-upper.position
			var bend_side := signf(wrapf(elbow_dir-actual.angle(),-PI,PI))
			if is_zero_approx(bend_side):
				bend_side = 1
			var angle := dir.angle()+bend_side*acos(clampf((a*a+reach*reach-b*b)/(2*a*reach),-1,1))
			var lower := dir.normalized()*reach-Vector2.from_angle(angle)*a
			var up := angle-fore.position.angle()
			rotations = Vector2(wrapf(up-actor.arm_rest.x,-PI,PI),wrapf(lower.angle()-up-wrist.position.angle()-actor.arm_rest.y,-PI,PI))
		changed.emit("arm",rotations)
