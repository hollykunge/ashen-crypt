extends "res://prototype/cutout/cutout_rig.gd"
## 男刀客的拆件骨骼人物。所有部件从同一张基准原画切出（art/hero-rig），共用一个缩放，
## 接点就是原画上的关节中心，所以不需要逐件对位或单独缩放。
## 换装：每套衣装是同一基准姿势画出、同一套切法切开的整组部件，按装备槽整件替换。
const Frames = preload("res://scripts/reference_frames.gd")
const RingDao = preload("res://scripts/ring_dao.gd")
const Cleave = preload("res://scripts/leaping_cleave.gd")
## 默认的人物目录；new(其他目录) 可以换一整套（比如 3/4 侧身小样 res://art/hero-rig-34/）
const ROOT := "res://art/hero-rig/"
const PARTS := ROOT + "parts/"
var cfg: Dictionary
var parts_dir := PARTS
## 刀从握点到刀尖占身高的比例
const BLADE_SHARE := 0.48

var sword := RingDao.new()
var grip_hand := Sprite2D.new()
var rear_grip := Sprite2D.new()
var _armed := false
var _worn := {}

func _init(root := ROOT) -> void:
	cfg = load(root + "rig.json").data
	parts_dir = root + "parts/"
	setup_dict(cfg, parts_dir + "base")
	attack_from = "ready"
	blend_time = 0.10
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# 空着的内侧手垂在胯边：前臂中段不能被大腿盖住
	for part in ["far_forearm", "far_hand"]:
		if _sprites.has(part):
			for s in _sprites[part]:
				s.z_index = _sprites.pelvis[0].z_index - 1
	# 短裤腰头压在躯干下沿上面（切口就是画好的腰头边）
	_sprites.pelvis[0].z_index = _sprites.torso[0].z_index + 1
	var hand: Node2D = _bones.arm_near_hand
	var grasp := _bone("weapon", hand, Vector2.ZERO)
	grasp.add_child(sword)
	sword.z_as_relative = false
	sword.z_index = 15
	var grip: Dictionary = rig.grip
	var height := _rest_height()
	var fist_part := "grip_hand" if rig.parts.has("grip_hand") else "hand"
	sword.position = (_v(grip.at) if grip.has("at") else _v(rig.parts.hand.pivot)) - _v(rig.parts[fist_part].pivot)
	sword.rotation = deg_to_rad(float(grip.get("bearing", 0.0))) - (RingDao.TIP - RingDao.GRIP).angle()
	sword.scale = Vector2.ONE * (BLADE_SHARE * height / (RingDao.TIP - RingDao.GRIP).length())
	weapon_tip_marker = Marker2D.new()
	weapon_tip_marker.position = RingDao.TIP + sword.offset
	sword.add_child(weapon_tip_marker)
	# 握刀的拳头盖在刀柄上，刀柄从指缝里穿出去
	for s: Sprite2D in [grip_hand, rear_grip]:
		s.centered = false
		s.z_as_relative = false
	grip_hand.z_index = 19
	grasp.add_child(grip_hand)
	rear_grip.z_index = 16
	_bones.arm_far_hand.add_child(rear_grip)
	rear_grip.hide()
	_build_skins()
	scale = Vector2.ONE * (Frames.HEIGHT / stand_height())
	position = Frames.FOOT
	equip(false, false)

## 站直时脚底到头顶（部件像素），用来定刀长
func _rest_height() -> float:
	return float(rig.rest_height)

## armed：手里有刀；dressed、leather 沿用旧接口（是否穿上衣、是否甲）；pieces：{装备槽: cloth/leather/chain}
func equip(armed: bool, dressed: bool, _leather := false, pieces: Dictionary = {}) -> void:
	_armed = armed
	var outfit := {}
	for slot in rig.slots:
		var style: String = pieces.get(slot, "")
		if slot == "armor" and dressed and style.is_empty():
			style = "cloth"
		if not style.is_empty() and ResourceLoader.exists("%s%s/%s.png" % [parts_dir, style, rig.slots[slot][0]], "Texture2D"):
			outfit[slot] = parts_dir + style
	if str(outfit) != str(_worn):
		_worn = outfit
		set_outfit(outfit)
		# 光身短裤的腰头压在躯干上；穿了衣服换成腰带（躯干那件）压在下摆上
		var armor_dir: String = outfit.get("armor", rig.base_dir)
		var front := true
		if FileAccess.file_exists(armor_dir + "/outfit.json"):
			front = JSON.parse_string(FileAccess.get_file_as_string(armor_dir + "/outfit.json")).get("pelvis_front", true)
		_sprites.pelvis[0].z_index = _sprites.torso[0].z_index + (1 if front else -1)
	var fist_part := "grip_hand" if rig.parts.has("grip_hand") else "hand"
	var glove_dir: String = outfit.get("gloves", rig.base_dir)
	if not ResourceLoader.exists("%s/%s.png" % [glove_dir, fist_part], "Texture2D"):
		glove_dir = rig.base_dir
	var fist := Frames.cached_texture("%s/%s.png" % [glove_dir, fist_part])
	for s: Sprite2D in [grip_hand, rear_grip]:
		s.texture = fist
		s.offset = -_v(rig.parts[fist_part].pivot) - Vector2.ONE * _margin(glove_dir)
	rear_grip.modulate = _sprites.far_hand[0].modulate
	show_weapon = armed
	sword.visible = armed
	grip_hand.visible = armed
	_bones.weapon.visible = armed
	_sprites.hand[0].visible = not armed

## 染色：每个装备槽管的部件一起乘颜色
func dye_panels(dyes: Dictionary) -> void:
	for slot in rig.slots:
		var tint: Color = dyes.get(slot, Color.WHITE) if _worn.has(slot) else Color.WHITE
		for part: String in rig.slots[slot]:
			for s: Sprite2D in _sprites.get(part, []):
				var base: Color = s.modulate if not s.has_meta("base_modulate") else s.get_meta("base_modulate")
				s.set_meta("base_modulate", base)
				s.modulate = base * tint

func sample_frame(frame: String) -> void:
	_attack = cfg.attack
	pose_override.clear()
	if frame.begins_with("walk-") or frame.begins_with("run-"):
		var motion := frame.get_slice("-", 0)
		play(motion)
		var period: float = _walk.period if motion == "walk" else _run.period
		drive_t = frame.get_slice("-", 1).to_int() * period / 8.0
	elif frame == "strike" or frame.begins_with("combat-"):
		play("attack")
		var key_order := [0, 1, 2, 3, 4, 5, 0, 1]
		drive_t = attack_hit_time() if frame == "strike" else float(_attack[key_order[frame.get_slice("-", 1).to_int()]][0])
	else:
		play("idle" if frame == "idle" else "ready")
		drive_t = -1.0

func drive_combo(phase: float, cues: Array) -> void:
	pose_override.clear()
	_attack = cfg.combo
	play("attack")
	var first := float(_attack[3][0])
	var second := float(_attack[6][0])
	if phase <= float(cues[0]):
		drive_t = remap(phase, 0.0, cues[0], 0.0, first)
	elif phase <= float(cues[1]):
		drive_t = remap(phase, cues[0], cues[1], first, second)
	else:
		drive_t = remap(phase, cues[1], 1.0, second, attack_end_time())

func _tracing_weapon_tip() -> bool:
	if pose_override.has("foot_far_heel") and _action == "attack":
		return drive_t >= Cleave.BLADE_RELEASE and drive_t <= Cleave.IMPACT + 0.04
	if is_same(_attack, cfg.combo) and _action_t >= float(_attack[5][0]) and _action_t <= float(_attack[7][0]):
		return true
	return super._tracing_weapon_tip()

func drive_cleave(phase: float) -> void:
	play("attack")
	pose_override = Cleave.pose(phase)
	pose_override["rear_grip"] = smoothstep(0.0, 0.14, phase) * (1.0 - smoothstep(0.85, 1.0, phase))
	drive_t = phase

func drive_motion(motion: StringName, distance: float, running: bool, attack_seconds: float, reaction: Dictionary) -> void:
	_attack = cfg.attack
	pose_override = reaction
	if motion.is_empty() and distance > 0.0:
		play("run" if running else "walk")
		drive_t = gait_time(distance * Frames.HEIGHT / leg_length())
	elif attack_seconds >= 0.0:
		play("attack")
		drive_t = attack_seconds
	elif motion == &"strike":
		play("attack")
		drive_t = attack_hit_time()
	else:
		play("idle" if motion == &"idle" else "ready")
		drive_t = -1.0

func _apply(pose: Dictionary, dt: float) -> void:
	super._apply(pose, dt)
	if rear_grip.get_parent():
		_support_grip(pose.get("rear_grip", 0.0) if sword.visible else 0.0)
	_update_skins()

## 双手握刀：内侧手臂用两节 IK 够到刀柄上近手后面一拳的位置
func _support_grip(weight: float) -> void:
	rear_grip.visible = weight >= 0.98
	_sprites.far_hand[0].visible = not rear_grip.visible
	if weight <= 0.0:
		return
	var upper: Node2D = _bones.arm_far_up
	var forearm: Node2D = _bones.arm_far_lo
	var wrist: Node2D = _bones.arm_far_hand
	var handle: Vector2 = (RingDao.GRIP - RingDao.TIP).normalized() * float(rig.grip.rear_offset)
	var palm := _v(rig.grip.palm) - _v(rig.parts.grip_hand.pivot)
	var target := sword.to_global(RingDao.GRIP + sword.offset + handle / sword.scale.x)
	target = target - (wrist.global_transform.basis_xform(palm))
	var span: Vector2 = upper.get_parent().to_local(target) - upper.position
	var a := forearm.position.length()
	var b := wrist.position.length()
	var reach := clampf(span.length(), absf(a - b) + 0.01, a + b - 0.01)
	var bend := acos(clampf((a * a + reach * reach - b * b) / (2.0 * a * reach), -1.0, 1.0))
	var direction := span.angle() + bend
	var elbow := Vector2.from_angle(direction) * a
	var lower_direction := (span.normalized() * reach - elbow).angle()
	var up_angle := direction - forearm.position.angle()
	var lo_angle := lower_direction - up_angle - wrist.position.angle()
	upper.rotation = lerp_angle(upper.rotation, up_angle, weight)
	forearm.rotation = lerp_angle(forearm.rotation, lo_angle, weight)
	wrist.rotation = lerp_angle(wrist.rotation, _bones.arm_near_hand.global_rotation - forearm.global_rotation, weight)

# ---------- 网格蒙皮：关节两侧一起弯 ----------
#
# 每个部件仍是一张贴图（按装备槽换装），但不再是硬图片：铺一层网格，网格点按到关节的距离分权重。
# 部件根部（挂在上一节骨头的那个关节）附近的点部分跟上一节骨头走，末端（下一节骨头的关节）附近的点
# 部分跟下一节骨头走（线性混合蒙皮）。关节两侧的两张图在重叠处按同一个权重变形，弯起来是一整条
# 连续的肢体，不会露缝、错位或叠出一块；离关节远的地方（肩甲、护腕、护腿中段）仍是刚性的。
# 躯干、臀胯不变形，肩、髋、脖子只让肢体和头的根部贴着躯干走。

## [部件, 所在骨头, 根部关节, 根部过渡比例, 末端骨头, 末端关节, 末端过渡比例]（%s 是 near/far）
const SKIN_PIECES := [
	["head", "neck", "neck", 0.5, "", "", 0.0],
	["upper_arm", "arm_%s_up", "shoulder", 0.6, "arm_%s_lo", "elbow", 0.9],
	["forearm", "arm_%s_lo", "elbow", 0.9, "arm_%s_hand", "wrist", 0.7],
	["hand", "arm_near_hand", "wrist", 0.7, "", "", 0.0],
	["far_hand", "arm_far_hand", "wrist", 0.7, "", "", 0.0],
	["thigh", "leg_%s_up", "hip", 0.45, "leg_%s_lo", "knee", 0.9],
	["shin", "leg_%s_lo", "knee", 0.9, "foot_%s", "ankle", 0.5],
	["foot", "foot_%s", "ankle", 0.5, "", "", 0.0],
]
## 网格：关节过渡带里每 6 像素一行，其余每 32 像素一行，每 24 像素一列（贴图像素）
const SKIN_ROW_FINE := 6.0
const SKIN_ROW := 32.0
const SKIN_COL := 24.0

var skinned := true
var _skins := []

func _joint_radius(joint: String) -> float:
	var caps: Dictionary = rig.get("caps", {})
	if caps.has(joint):
		return float(caps[joint])
	# 肩没有切圆头（上臂直接压在躯干上），按肘的粗细算
	return float(caps.get("elbow", 40.0))

func _build_skins() -> void:
	var seen := {}
	for spec in SKIN_PIECES:
		for side in ["near", "far"]:
			var bone_name: String = spec[1] % side if "%s" in spec[1] else spec[1]
			var child_name: String = spec[4] % side if "%s" in spec[4] else spec[4]
			if seen.has(spec[0] + bone_name) or not _bones.has(bone_name) or not _sprites.has(spec[0]):
				continue
			seen[spec[0] + bone_name] = true
			var bone: Node2D = _bones[bone_name]
			for sprite: Sprite2D in _sprites[spec[0]]:
				if sprite.get_parent() != bone:
					continue
				var poly := Polygon2D.new()
				poly.z_as_relative = false
				bone.add_child(poly)
				_skins.append({"poly": poly, "sprite": sprite, "bone": bone,
					"child": _bones.get(child_name) if not child_name.is_empty() else null,
					"root_blend": _joint_radius(spec[2]) * float(spec[3]),
					"end_blend": _joint_radius(spec[5]) * float(spec[6]) if not spec[5].is_empty() else 0.0,
					"key": null})

## 网格（贴图像素坐标）。fine 是需要加密的行的范围（贴图 y）
func _grid(size: Vector2, fine: Array) -> Array:
	var ys := PackedFloat32Array()
	var y := 0.0
	while y < size.y:
		ys.append(y)
		var dense := false
		for f: Vector2 in fine:
			dense = dense or (y >= f.x and y <= f.y)
		y += SKIN_ROW_FINE if dense else SKIN_ROW
	ys.append(size.y)
	var xs := PackedFloat32Array()
	var x := 0.0
	while x < size.x:
		xs.append(x)
		x += SKIN_COL
	xs.append(size.x)
	var uv := PackedVector2Array()
	for yy in ys:
		for xx in xs:
			uv.append(Vector2(xx, yy))
	var tris := []
	var cols := xs.size()
	for r in ys.size() - 1:
		for c in cols - 1:
			var a := r * cols + c
			tris.append(PackedInt32Array([a, a + 1, a + cols + 1]))
			tris.append(PackedInt32Array([a, a + cols + 1, a + cols]))
	return [uv, tris]

func _update_skins() -> void:
	for p in _skins:
		var sprite: Sprite2D = p.sprite
		var poly: Polygon2D = p.poly
		var bone: Node2D = p.bone
		var child: Node2D = p.child
		poly.visible = skinned and sprite.visible and sprite.texture != null
		sprite.self_modulate.a = 0.0 if poly.visible else 1.0
		if not poly.visible:
			continue
		var rest := sprite.transform
		var end: Vector2 = child.position if child else Vector2.ZERO
		var key := [sprite.texture, rest, end]
		if key != p.key:
			p.key = key
			poly.texture = sprite.texture
			var size: Vector2 = sprite.texture.get_size()
			# 部件的走向：有下一节就朝下一节的关节，没有就朝贴图中心
			var axis: Vector2 = end.normalized() if child else (rest * (size * 0.5)).normalized()
			var rb: float = p.root_blend
			var eb: float = p.end_blend
			var inv := rest.affine_inverse()
			var fine := [Vector2((inv * Vector2.ZERO).y - rb - 12.0, (inv * Vector2.ZERO).y + rb + 12.0)]
			if child:
				fine.append(Vector2((inv * end).y - eb - 12.0, (inv * end).y + eb + 12.0))
			var g := _grid(size, fine)
			poly.uv = g[0]
			poly.polygons = g[1]
			var verts := PackedVector2Array()
			var w_root := PackedFloat32Array()
			var w_end := PackedFloat32Array()
			for uv: Vector2 in g[0]:
				var v := rest * uv
				verts.append(v)
				w_root.append(1.0 - smoothstep(-rb, rb, v.dot(axis)) if rb > 0.0 else 0.0)
				w_end.append(smoothstep(-eb, eb, (v - end).dot(axis)) if child and eb > 0.0 else 0.0)
			p.rest = verts
			p.w_root = w_root
			p.w_end = w_end
		poly.z_index = sprite.z_index
		poly.modulate = sprite.modulate
		var back := -bone.rotation
		var turn := child.rotation if child else 0.0
		var out := PackedVector2Array()
		out.resize(p.rest.size())
		for i in p.rest.size():
			var v: Vector2 = p.rest[i]
			var a: float = p.w_root[i]
			var b: float = p.w_end[i]
			var o := v
			if a > 0.0:
				o += (v.rotated(back) - v) * a
			if b > 0.0:
				o += (end + (v - end).rotated(turn) - v) * b
			out[i] = o
		poly.polygon = out
