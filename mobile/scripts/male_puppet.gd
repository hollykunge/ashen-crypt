extends "res://prototype/cutout/cutout_rig.gd"
## The approved male figure: independent body pieces, wearable panels, and one rigid dao.
const Frames = preload("res://scripts/reference_frames.gd")
const RingDao = preload("res://scripts/ring_dao.gd")
const Cleave = preload("res://scripts/leaping_cleave.gd")
const CONFIG = preload("res://art/reference-hero/puppet/rig.json")
const ART := "res://art/reference-hero/puppet/"
const GRIP_ART = preload("res://art/reference-hero/puppet/closed-grip.png")
const NEAR_WRIST := Vector2(1573,340)
const GRIP := Vector2(1608,346)
const HAND_ORIGIN := Vector2(1565,318)

# Ease relative to the body-part template, with each panel pinned at its own joint.
const GARMENT_FIT := {
	"cloth": {"torso": Vector2(1.04, 1.02), "sleeve": Vector2(1.04, 1.04),
		"thigh": Vector2(1.05, 1.0), "shin": Vector2(1.04, 1.0)},
	"leather": {"torso": Vector2(1.02, 0.99), "sleeve": Vector2(1.02, 0.90)},
	"chain": {"torso": Vector2(1.04, 1.02), "sleeve": Vector2(1.04, 0.94),
		"shin": Vector2(1.03, 1.0)}
}

var sword := RingDao.new()
var gripping_hand := Sprite2D.new()
var rear_grip := Sprite2D.new()
const REAR_CONTACT := Vector2(94,68)
# The rear palm is painted on a 112 x 80 canvas; its wrist is the local origin.
const REAR_PALM := Vector2(53,-19)
var shirt: Sprite2D
var resting_torso: Texture2D
var turned_torso: Texture2D
var sleeves: Array[Sprite2D] = []
var near_sleeve: Sprite2D
var resting_sleeve: Texture2D
var overhead_sleeve: Texture2D
var guards := {"gloves": [], "greaves": [], "boots": []}
const Edits = preload("res://scripts/motion_edits.gd")
const HEM_PIXEL := {"near": Vector2(136,171), "far": Vector2(128,197)}
const Cuts = preload("res://scripts/piece_cuts.gd")
var original_pieces := {}
var motion_edits: Dictionary = Edits.DEFAULTS.data
var hem_panels := {}
var hem_rest := {}
var arm_rest := Vector3.ZERO
var edit_clip := ""
var edit_frame := 0.0
var combo_phase := 0.0
var empty_hand: Sprite2D

func _init() -> void:
	setup_dict(CONFIG.data,CONFIG.data.base_dir)
	# The relaxed inner hand passes beside the hip. The thigh must not cover
	# the middle of the forearm while its wrist remains visible below.
	for part in ["far_forearm", "far_hand"]:
		_sprites[part][0].z_index = _sprites.pelvis[0].z_index - 1
	attack_from = "ready"
	blend_time = 0.10
	scale = Vector2.ONE * (Frames.HEIGHT / stand_height())
	position = Frames.FOOT
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for sprite: Sprite2D in _sprites.hand:
		if not sprite.has_meta("far"):
			empty_hand = sprite
	shirt = _panel("shirt",_bones.torso,_sprites.torso[0],_v(rig.parts.torso.pivot) + Vector2(1,3))
	for side: String in ["far","near"]:
		var upper: Node2D = _bones["arm_"+side+"_up"]
		var sleeve := _panel("sleeve",upper,upper.get_child(0),Vector2(113,109))
		sleeves.append(sleeve)
		if side == "near":
			near_sleeve = sleeve
		var thigh: Node2D = _bones["leg_"+side+"_up"]
		var shorts := _panel("far_short_leg" if side == "far" else "short_leg",thigh,thigh.get_child(0),Vector2.ZERO)
		shorts.scale = _s("pelvis") * Vector2(0.96,1.0)
		shorts.position = -Vector2(108,68)*shorts.scale
		hem_panels[side] = shorts
		hem_rest[side] = shorts.transform
		_guard("gloves","leather-bracer",_bones["arm_"+side+"_lo"],"forearm")
		_guard("greaves","leather-thigh",thigh,"thigh")
		_guard("greaves","leather-shin",_bones["leg_"+side+"_lo"],"shin")
		_guard("boots","leather-boot",_bones["foot_"+side],"foot")
	var hand: Node2D = _bones.arm_near_hand
	var grasp := _bone("weapon",hand,Vector2.ZERO)
	grasp.rotation = deg_to_rad(83.0)
	grasp.scale = Vector2.ONE*(0.6793/scale.x)
	grasp.add_child(sword)
	sword.z_as_relative = false
	sword.z_index = 15
	sword.attach_at(GRIP-NEAR_WRIST,deg_to_rad(-34.0),0.6793)
	weapon_tip_marker = Marker2D.new()
	weapon_tip_marker.position = RingDao.TIP + sword.offset
	sword.add_child(weapon_tip_marker)
	gripping_hand.texture = GRIP_ART
	gripping_hand.centered = false
	gripping_hand.scale = Vector2.ONE*0.4
	gripping_hand.position = HAND_ORIGIN-NEAR_WRIST
	gripping_hand.z_as_relative = false
	gripping_hand.z_index = 19
	grasp.add_child(gripping_hand)
	rear_grip.texture = preload("res://art/reference-hero/puppet/rear-grip.png")
	rear_grip.centered = false
	rear_grip.offset = -Vector2(12,60)
	rear_grip.z_as_relative = false
	rear_grip.z_index = 16
	rear_grip.modulate = _sprites.far_hand[0].modulate
	_bones.arm_far_hand.add_child(rear_grip)
	rear_grip.hide()
	equip(false,false)
	for part in Cuts.NAMES:
		original_pieces[part] = piece_sprite(part).texture
	apply_piece_cuts()

func piece_sprite(part: String) -> Sprite2D:
	if part == "short_leg": return hem_panels.near
	if part == "far_short_leg": return hem_panels.far
	return _sprites[part][0]

func apply_piece_cuts() -> void:
	var cuts: Dictionary = motion_edits.get("cuts",{})
	for part in original_pieces:
		piece_sprite(part).texture = Cuts.texture(part,cuts[part]) if cuts.has(part) else original_pieces[part]

func _panel(part: String, bone: Node2D, skin: Sprite2D, pivot: Vector2) -> Sprite2D:
	var panel := Sprite2D.new()
	panel.centered = false
	panel.texture = Frames.cached_texture(ART+part+".png")
	panel.scale = skin.scale
	panel.position = -pivot*panel.scale
	panel.set_meta("fit_pivot", pivot)
	panel.set_meta("template_scale", skin.scale)
	panel.z_as_relative = false
	panel.z_index = skin.z_index
	panel.modulate = skin.modulate
	panel.set_meta("base_modulate", skin.modulate)
	bone.add_child(panel)
	return panel

func _guard(slot: String, part: String, bone: Node2D, body_part: String) -> void:
	var skin: Sprite2D = bone.get_child(0)
	var panel := _panel(part,bone,skin,_v(rig.parts[body_part].pivot))
	panel.set_meta("piece",part.trim_prefix("leather-"))
	guards[slot].append(panel)

func _fit_panel(panel: Sprite2D, style: String, piece: String) -> void:
	var ease: Vector2 = GARMENT_FIT.get(style, {}).get(piece, Vector2.ONE)
	var template_scale: Vector2 = panel.get_meta("template_scale")
	var pivot: Vector2 = panel.get_meta("fit_pivot")
	panel.scale = template_scale * ease
	panel.position = -pivot * panel.scale

func equip(armed: bool, dressed: bool, leather := false, pieces: Dictionary = {}) -> void:
	# The rigid breastplate covers the ribcage; keep the exposed neck above its collar.
	var torso: Sprite2D = _sprites.torso[0]
	torso.region_rect = Rect2(Vector2.ZERO,Vector2(torso.texture.get_width(),100))
	torso.region_enabled = dressed and leather
	var material_name: String = pieces.get("armor","leather")
	resting_torso = Frames.cached_texture(ART + (material_name+"-torso.png" if leather else "shirt.png"))
	_fit_panel(shirt, material_name, "torso")
	shirt.texture = resting_torso
	shirt.visible = dressed
	resting_sleeve = Frames.cached_texture(ART + (material_name+"-shoulder.png" if leather else "sleeve.png"))
	overhead_sleeve = null
	turned_torso = null
	if dressed and not leather:
		turned_torso = preload("res://art/reference-hero/puppet/shirt-turned.png")
		overhead_sleeve = preload("res://art/reference-hero/puppet/sleeve-raised.png")
	elif dressed and material_name == "leather":
		turned_torso = preload("res://art/reference-hero/puppet/leather-torso-turned.png")
		overhead_sleeve = preload("res://art/reference-hero/puppet/leather-shoulder-raised.png")
	for sleeve in sleeves:
		_fit_panel(sleeve, material_name, "sleeve")
		sleeve.texture = resting_sleeve
		sleeve.visible = dressed
	for slot in guards:
		var worn := pieces.has(slot)
		for panel: Sprite2D in guards[slot]:
			if worn:
				_fit_panel(panel, pieces[slot], panel.get_meta("piece"))
				panel.texture = Frames.cached_texture(ART + pieces[slot] + "-" + panel.get_meta("piece") + ".png")
			panel.visible = worn
			if slot != "gloves":
				panel.get_parent().get_child(0).visible = not worn
	show_weapon = armed
	sword.visible = armed
	gripping_hand.visible = armed
	_bones.weapon.visible = armed
	empty_hand.visible = not armed

func dye_panels(dyes: Dictionary) -> void:
	for panel: Sprite2D in [shirt] + sleeves:
		panel.modulate = panel.get_meta("base_modulate") * dyes.get("armor", Color.WHITE)
	for slot in guards:
		for panel: Sprite2D in guards[slot]:
			panel.modulate = panel.get_meta("base_modulate") * dyes.get(slot, Color.WHITE)

func sample_frame(frame: String) -> void:
	_attack = CONFIG.data.attack
	pose_override.clear()
	if frame.begins_with("walk-") or frame.begins_with("run-"):
		var motion := frame.get_slice("-",0)
		play(motion)
		var period: float = _walk.period if motion == "walk" else _run.period
		drive_t = frame.get_slice("-",1).to_int()*period/8.0
	elif frame == "strike" or frame.begins_with("combat-"):
		play("attack")
		var key_order := [0,1,2,3,4,5,0,1]
		drive_t = attack_hit_time() if frame == "strike" else float(_attack[key_order[frame.get_slice("-",1).to_int()]][0])
	else:
		play("idle" if frame == "idle" else "ready")
		drive_t = -1.0

func drive_combo(phase: float, cues: Array) -> void:
	combo_phase = phase
	pose_override.clear()
	_attack = CONFIG.data.combo
	play("attack")
	# Retiming the whole phrase preserves the low follow-through between both impacts.
	var first := float(_attack[3][0])
	var second := float(_attack[6][0])
	if phase <= float(cues[0]):
		drive_t = remap(phase,0.0,cues[0],0.0,first)
	elif phase <= float(cues[1]):
		drive_t = remap(phase,cues[0],cues[1],first,second)
	else:
		drive_t = remap(phase,cues[1],1.0,second,attack_end_time())

func _tracing_weapon_tip() -> bool:
	if pose_override.has("foot_far_heel") and _action == "attack":
		return drive_t >= Cleave.BLADE_RELEASE and drive_t <= Cleave.IMPACT + 0.04
	if is_same(_attack, CONFIG.data.combo) and _action_t >= float(_attack[5][0]) and _action_t <= float(_attack[7][0]):
		return true
	return super._tracing_weapon_tip()

func drive_cleave(phase: float) -> void:
	play("attack")
	pose_override = Cleave.pose(phase)
	pose_override["turn_sleeve"] = 1.0
	pose_override["rear_grip"] = smoothstep(0.0,0.14,phase)*(1.0-smoothstep(0.85,1.0,phase))
	pose_override["chest_turn"] = smoothstep(0.18,Cleave.TAKEOFF,phase) * (1.0-smoothstep(Cleave.WAIST_LEAD,Cleave.BLADE_RELEASE,phase))
	drive_t = phase

func _pose_gait(t: float, g: Dictionary) -> Dictionary:
	var pose := super._pose_gait(t, g)
	if is_same(g, _run):
		var forward_peak: float = g.duty + 0.7 * (1.0 - g.duty)
		var phase := TAU * (t / float(g.period) - forward_peak)
		pose.arm_far_up = 4.0 + 29.0 * cos(phase)
		# The elbow closes after the upper arm starts forward and stays soft at the back.
		pose.arm_far_lo = 77.0 + 11.0 * cos(phase - 0.52)
		# The painted relaxed palm slopes away from the forearm in its standing view.
		pose.far_wrist = -18.0 + 4.0 * sin(phase - 0.52)
	return pose

func _apply(pose: Dictionary, dt: float) -> void:
	if not edit_clip.is_empty():
		_bones.arm_far_hand.rotation = arm_rest.z
	super._apply(pose,dt)
	var wrist: Node2D = _bones.arm_far_hand
	wrist.rotation = lerp_angle(wrist.rotation, deg_to_rad(pose.get("far_wrist", 0.0)), 1.0-exp(-26.0*dt))
	var thrust: float = pose.get("thrust_extension", 0.0)
	if thrust > 0.0:
		var axis := weapon_tip_marker.global_position - sword.global_position
		_bones.arm_near_hand.rotation -= axis.angle() * thrust
	var twist: float = pose.get("chest_turn",0.0)
	# Shear about the waist so the neck and both shoulder joints travel with the ribs.
	_bones.torso.skew = deg_to_rad(-3.5)*twist
	if shirt and shirt.visible:
		shirt.texture = turned_torso if turned_torso and twist >= 0.5 else resting_torso
	if near_sleeve and near_sleeve.visible:
		var overhead: bool = pose.get("turn_sleeve",0.0) > 0.5 and float(pose.arm_near_up) >= 100.0
		near_sleeve.texture = overhead_sleeve if overhead and overhead_sleeve else resting_sleeve
	var previous_clip := edit_clip
	edit_clip = ""
	if _action == "run":
		edit_clip = "run"
		edit_frame = fposmod(_action_t, _run.period) / _run.period * Edits.FRAMES.run
	elif _action == "attack" and is_same(_attack, CONFIG.data.combo) and not pose.has("rear_grip"):
		edit_clip = "combo"
		edit_frame = combo_phase * Edits.FRAMES.combo
	if not edit_clip.is_empty():
		arm_rest = Vector3(_bones.arm_far_up.rotation, _bones.arm_far_lo.rotation, wrist.rotation)
		apply_motion_edits()
	elif not previous_clip.is_empty():
		for side in hem_panels:
			hem_panels[side].transform = hem_rest[side]
	if rear_grip.get_parent():
		_support_grip(pose.get("rear_grip",0.0) if sword.visible else 0.0)

func edit_value(channel: String) -> Vector2:
	var tracks: Dictionary = motion_edits.get(edit_clip,{})
	return Edits.sample(tracks.get(channel,{}),edit_frame,Edits.FRAMES[edit_clip],edit_clip == "run")

func apply_motion_edits() -> void:
	var arm := edit_value("arm")
	_bones.arm_far_up.rotation = arm_rest.x + arm.x
	_bones.arm_far_lo.rotation = arm_rest.y + arm.y
	_bones.arm_far_hand.rotation = arm_rest.z + edit_value("palm").x
	for side in hem_panels:
		var rest: Transform2D = hem_rest[side]
		# Keep the waistband fixed and displace the opening in thigh-local coordinates.
		var delta := edit_value(side)
		var anchor_y := 68.0
		var shifted_axis: Vector2 = delta / (HEM_PIXEL[side].y-anchor_y)
		hem_panels[side].transform = Transform2D(rest.x,rest.y+shifted_axis,rest.origin-shifted_axis*anchor_y)

func _support_grip(weight: float) -> void:
	var upper: Node2D = _bones.arm_far_up
	rear_grip.visible = weight >= 0.98
	_sprites.far_hand[0].visible = not rear_grip.visible
	if weight <= 0.0:
		return
	var forearm: Node2D = _bones.arm_far_lo
	var wrist: Node2D = _bones.arm_far_hand
	var target := sword.to_global(sword.offset + REAR_CONTACT - REAR_PALM)
	var span: Vector2 = upper.get_parent().to_local(target) - upper.position
	var a := forearm.position.length()
	var b := wrist.position.length()
	var reach := clampf(span.length(),absf(a-b)+0.01,a+b-0.01)
	var bend := acos(clampf((a*a+reach*reach-b*b)/(2.0*a*reach),-1.0,1.0))
	var direction := span.angle()+bend
	var elbow := Vector2.from_angle(direction)*a
	var lower_direction := (span.normalized()*reach-elbow).angle()
	var up_angle := direction-forearm.position.angle()
	var lo_angle := lower_direction-up_angle-wrist.position.angle()
	upper.rotation = lerp_angle(upper.rotation,up_angle,weight)
	forearm.rotation = lerp_angle(forearm.rotation,lo_angle,weight)
	# Copy only the handle's axes. The wrist position always comes from the arm bones.
	var axes := wrist.global_transform.affine_inverse()*sword.global_transform
	axes.origin = Vector2.ZERO
	rear_grip.transform = axes

func drive_motion(motion: StringName, distance: float, running: bool, attack_seconds: float, reaction: Dictionary) -> void:
	_attack = CONFIG.data.attack
	pose_override = reaction
	if motion.is_empty() and distance > 0.0:
		play("run" if running else "walk")
		drive_t = gait_time(distance*Frames.HEIGHT/leg_length())
	elif attack_seconds >= 0.0:
		play("attack")
		drive_t = attack_seconds
	elif motion == &"strike":
		play("attack")
		drive_t = attack_hit_time()
	else:
		play("idle" if motion == &"idle" else "ready")
		drive_t = -1.0
