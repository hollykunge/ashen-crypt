extends Node3D
## 3D 角色模型（gen-out/model 用 export_godot.py 导出的 hero.glb）：按槽换装、播放动作、卡通着色加描边。
## 骨架和部件名与 Blender 里一致；角色朝 +Z，左手在 +X。

const SCENE := preload("res://art/model-hero/hero.glb")
## 兵器零件（gen-out/model/scripts/build_weapons.py）：原点都在握点，+Y 朝刃尖 / 枪头 / 上弓臂，+X 是刃宽（弓腹朝前）
const WEAPONS := preload("res://art/model-hero/weapons.glb")
const TOON := preload("res://scripts/model_toon.gdshader")
const OUTLINE := preload("res://scripts/model_outline.gdshader")

## 发髻（发包、发尾、发带、簪子，gen-out/model/scripts/build_topknot.py；头发本身是往后梳、贴头皮的发壳）：
## 戴头饰时藏起来（头饰盖住头顶），戴兜帽时连头发一起藏
const TOPKNOT := ["Head_Hair_Bun", "Head_Hair_Tail", "Head_Band", "Head_Pin"]
const HEAD := ["Head_Skin", "Head_Eyes", "Head_Eyebrows", "Head_Hair_Main", "Head_Hair_Beard"] + TOPKNOT
## 槽 → 款式 → 部件。和 gen-out/model/scripts/render_lib.py 的 SLOTS / LEATHER / CHAIN 对应
const SLOTS := {
	"torso": {
		"peasant": ["Male_Peasant_Body"],
		"ranger": ["Male_Ranger_Body", "Male_Ranger_Body_Belt_1", "Male_Ranger_Body_Belt_2"],
		"leather": ["Leather_Body", "Leather_Belt_1", "Leather_Belt_2"],
		"chain": ["Chain_Body", "Chain_Belt_1", "Chain_Belt_2"],
	},
	"arms": {
		"peasant": ["Male_Peasant_Arms"],
		"ranger": ["Male_Ranger_Arms"],
		"leather": ["Leather_Arms", "Leather_Bracer"],
		"chain": ["Chain_Arms", "Chain_Bracer"],
	},
	"legs": {
		"peasant": ["Male_Peasant_Legs"],
		"ranger": ["Male_Ranger_Legs"],
		"leather": ["Leather_Legs", "Leather_ThighGuard"],
		"chain": ["Chain_Legs"],
	},
	"feet": {
		"peasant": ["Male_Peasant_Feet"],
		"ranger": ["Male_Ranger_Feet_Boots"],
		"leather": ["Leather_Boots"],
		"chain": ["Chain_Boots"],
	},
	"shoulder": {
		"none": [],
		"ranger": ["Male_Ranger_Acc_Pauldron"],
		"leather": ["Leather_Pauldron_L", "Leather_Pauldron_R"],
		"chain": ["Chain_Pauldron_L", "Chain_Pauldron_R"],
	},
	"hood": {
		"none": [],
		"ranger": ["Male_Ranger_Head_Hood"],
	},
	## 头饰（gen-out/model/scripts/build_headgear.py）：斗笠、皮兜鍪、铁兜鍪
	"headgear": {
		"none": [],
		"hat": ["Head_Hat"],
		"leather": ["Head_Helm_Leather"],
		"iron": ["Head_Helm_Iron"],
	},
}
## 循环播放的动作；其余（挥砍、受击、倒地、翻滚）播一次停在最后一帧
const LOOPING := ["Idle_Loop", "Walk_Loop", "Jog_Fwd_Loop", "Sprint_Loop", "Sword_Idle"]

## 握拳：四指每节绕本地 X 轴弯多少度（_01 指根、_02、_03），拇指绕本地 Z 轴（左右手方向相反）。
## 动作素材里多数时候手是张开的，拿兵器的手每帧在动画之后改成握拳
const CURL := {"01": 70.0, "02": 85.0, "03": 55.0}
const CURL_SIGN := 1.0
const THUMB := {"02": 25.0, "03": 35.0}
const FINGERS := ["index", "middle", "ring", "pinky"]
## 哪只手握拳（"r"、"l"）
var fists := {"r": false, "l": false}
## 兵器：零件按锻造出的样子挑（weapon_design.gd 的 blade / guard / pommel / head），按用途上色
## 剑身放大（x 刃宽、z 刃厚，刃长不变）：照实的剑在手机战场上只有几个像素宽，侧过来时细成一根线、混进地面
const BLADE_SCALE := Vector3(1.35, 1.0, 2.0)
## 刀身本来就宽，只加厚（侧过来时别细成一根线）
const DAO_BLADE_SCALE := Vector3(1.0, 1.0, 2.0)
const STRING_COLOR := Color("#d4c4a5")
const SPEAR_TUFT := Color("#b8342a")
var weapon_form := ""
var grip_mode := "fist"
## plane 握法：兵器贴着侧面（相机看过去的那个平面）朝前上方伸出，抬多少度。
## 戒备动作里手是垂着的，照拳头的握轴拿，剑和枪会横着戳向镜头，侧视里只剩一小截还插进身体
const PLANE_PITCH := {"spear": 12.0, "bow": 55.0}   # 行装页：弓斜着朝前上方提在左手
const PLANE_PITCH_DEFAULT := 20.0
## 拉弓：右手从弓弦拉到下巴右侧（模型空间：朝 +Z，左手 +X，相机在 -X）
const DRAW_ANCHOR := Vector3(-0.07, -0.06, 0.06)   # 相对头骨
const ELBOW_HINT := Vector3(-0.6, -0.2, -1.0)       # 右肘朝外、朝后
var draw_pull := 0.0     # 0 手在弦上，1 拉满到下巴
var draw_reach := 0.0    # 右臂多大程度听拉弓的（0 照动作，1 完全拉弓）
var draw_string := false # 弓弦跟着右手（撒放以后弦弹直）
var _string_parts: Array[MeshInstance3D] = []  # 拉弦时的两段弦
var _kit: Node3D           # 兵器零件（weapons.glb 的实例），挂在握兵器那只手上
var _kit_parts := {}       # 零件名 → MeshInstance3D
var _hands := {}           # "r" / "l" → BoneAttachment3D

var outfit := {"torso": "leather", "arms": "leather", "legs": "leather", "feet": "leather",
	"shoulder": "leather", "hood": "none", "headgear": "leather"}
var anim: AnimationPlayer
var skeleton: Skeleton3D
var _meshes := {}  # 部件名 → MeshInstance3D
var _materials := {}  # 部件名 → [卡通材质]（染色用）
var hull_outline := true


## 模型在创建时就装好（不等进场景树），这样还没上场就能先换装、定动作
func _init() -> void:
	var model := SCENE.instantiate()
	add_child(model)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		_meshes[String(node.name)] = node
		_toonify(node)
	anim = model.find_child("AnimationPlayer", true, false)
	skeleton = model.find_child("Skeleton3D", true, false)
	anim.mixer_applied.connect(apply_fists)
	_kit = WEAPONS.instantiate()
	for node in _kit.find_children("*", "MeshInstance3D", true, false):
		_kit_parts[String(node.name)] = node
		_toonify(node, 0.003)
		node.visible = false
		if String(node.name).begins_with("sword_blade_") or String(node.name).begins_with("sword_inlay_"):
			node.scale *= BLADE_SCALE
		elif String(node.name).begins_with("dao_blade_"):
			node.scale *= DAO_BLADE_SCALE
	for i in 2:
		var piece := MeshInstance3D.new()
		var rod := CylinderMesh.new()
		rod.top_radius = 0.0035
		rod.bottom_radius = 0.0035
		rod.height = 1.0
		rod.radial_segments = 6
		rod.rings = 1
		var base := StandardMaterial3D.new()
		base.resource_name = "string"
		rod.material = base
		piece.mesh = rod
		piece.name = "bow_string_drawn_%d" % i
		piece.visible = false
		_kit.add_child(piece)
		_toonify(piece, 0.002)
		for mat: ShaderMaterial in _materials[String(piece.name)]:
			mat.set_shader_parameter("tint", STRING_COLOR)
		_string_parts.append(piece)
	for side in ["r", "l"]:
		var hand := BoneAttachment3D.new()
		skeleton.add_child(hand)
		hand.bone_name = "hand_" + side
		_hands[side] = hand
	for name in LOOPING:
		var a := anim_name(name)
		if anim.has_animation(a):
			anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	apply_outfit()


func _ready() -> void:
	if anim.current_animation.is_empty():
		play("Idle_Loop", 0.0)


## Godot 导入 glTF 时把名字结尾的 _Loop 去掉（并自动设成循环），这里用 Blender 里的动作名也能找到
func anim_name(action: String) -> String:
	if anim.has_animation(action):
		return action
	return action.trim_suffix("_Loop")


func set_slot(slot: String, variant: String) -> void:
	outfit[slot] = variant
	apply_outfit()


func apply_outfit() -> void:
	var wanted := HEAD.duplicate()
	for slot in outfit:
		wanted += SLOTS[slot][outfit[slot]]
	var gear: String = outfit.get("headgear", "none")
	if outfit.get("hood", "none") != "none":  # 戴兜帽时藏起头发和头饰
		for part in ["Head_Hair_Main"] + TOPKNOT + SLOTS.headgear[gear]:
			wanted.erase(part)
	elif gear != "none":  # 头饰盖住头顶：发髻收在里面
		for part in TOPKNOT:
			wanted.erase(part)
	for part in _meshes:
		_meshes[part].visible = part in wanted


func play(action: String, blend := 0.15) -> void:
	var a := anim_name(action)
	if anim.has_animation(a):
		anim.play(a, blend)


## 拿起一种兵器：剑、长枪握在右手，弓在左手；四指握拳攥住握柄。design 是 weapon_design.gd 挑出的样子
func hold(form: String, design: Dictionary) -> void:
	weapon_form = form
	var side := "l" if form == "bow" else "r"
	fists = {"r": true, "l": form in ["spear", "bow"]}
	if _kit.get_parent() != null:
		_kit.get_parent().remove_child(_kit)
	_hands[side].add_child(_kit)
	_kit.transform = _grip_transform(side)
	var show: Array = []
	match form:
		"spear":
			show = ["spear_pole", "spear_cap", "spear_tassel",
				"spear_head_" + _pick(design.get("head", ""), ["leaf", "snake", "ji"])]
		"bow":
			var limbs := "chang" if design.get("head", "") == "chang" else "fanqu"
			show = ["bow_limbs_" + limbs, "bow_grip", "bow_string_" + limbs]
		_:
			# 刀（形制 sword）用 dao_ 那套零件，剑（形制 jian）用 sword_ 那套；锻造的刃型、护手、首的名字两套通用
			var kit := kit_of(form)
			var blade := _pick(design.get("blade", ""), ["jian", "qixing", "bolang"])
			show = [kit + "_blade_" + blade, kit + "_grip",
				kit + "_guard_" + _pick(design.get("guard", ""), ["disc", "bar", "ruyi", "crescent"]),
				kit + "_pommel_" + _pick(design.get("pommel", ""), ["knob", "hex", "ring", "cloud"])]
			if blade == "qixing" and kit == "sword":
				show.append("sword_inlay_qixing")
			if Color(design.get("tassel", Color.TRANSPARENT)).a > 0.0:
				show.append(kit + "_tassel")
	_bow_limbs = limbs_of(design) if form == "bow" else ""
	var pole: Dictionary = design.get("pole", {})
	var tassel: Color = design.get("tassel", Color.TRANSPARENT)
	var colors := {
		"steel": Color(design.get("steel", Color("#8d9196"))).darkened(0.3), "trim": design.get("trim", Color("#a0804c")),
		"wrap": design.get("wrap", Color("#6f2a1c")), "accent": design.get("accent", SPEAR_TUFT),
		"wood": pole.get("wood", Color("#7c5a3c")), "core": pole.get("core", Color("#2e2219")),
		"cap": pole.get("cap", Color("#a58a5e")), "string": STRING_COLOR,
		"tassel": tassel if tassel.a > 0.0 else SPEAR_TUFT,
	}
	for part in _kit_parts:
		var mesh: MeshInstance3D = _kit_parts[part]
		mesh.visible = part in show
		for i in mesh.get_surface_override_material_count():
			var mat := mesh.get_surface_override_material(i) as ShaderMaterial
			var role: String = mat.get_meta("role", "")
			mat.set_shader_parameter("tint", Color(colors.get(role, Color.WHITE), 1.0))
	apply_fists()


var _bow_limbs := ""

## 刀剑用哪套零件：刀（sword）是 dao_，剑（jian）是 sword_
static func kit_of(form: String) -> String:
	return "dao" if form == "sword" else "sword"


static func limbs_of(design: Dictionary) -> String:
	return "chang" if design.get("head", "") == "chang" else "fanqu"


static func _pick(value: String, allowed: Array) -> String:
	return value if value in allowed else allowed[0]


## 握点在手骨本地坐标里的位置和朝向：拳眼在指根和弯下来的中指第二节之间；
## 兵器沿指根连线（小指 → 食指）伸出，刃宽朝指节指的方向（刃口跟着拳面走）
func _grip_transform(side: String) -> Transform3D:
	var index := _rest_origin("index_01_" + side)
	var pinky := _rest_origin("pinky_01_" + side)
	var middle := _rest_origin("middle_01_" + side)
	var m01 := skeleton.get_bone_rest(skeleton.find_bone("middle_01_" + side))
	m01.basis = Basis(m01.basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, deg_to_rad(CURL_SIGN * CURL["01"]))) \
		.scaled(m01.basis.get_scale())
	var curled := m01 * _rest_origin("middle_02_" + side)
	var knuckles := (index + pinky) * 0.5
	var y := (index - pinky).normalized()
	var x := (middle - y * middle.dot(y)).normalized()
	if grip_mode != "fist":
		# along：顺着手（手腕 → 指根）伸出去。前刺时拳面朝下，指根连线是横的，枪会横过来，改成顺着小臂刺出；
		# 垂手站着时顺着手往下，剑尖朝地。against：反过来，手垂着时枪尖朝天、拄着站
		var along := middle.normalized() * (1.0 if grip_mode == "along" else -1.0)
		x = (y - along * y.dot(along)).normalized()
		y = along
	var z := x.cross(y)
	return Transform3D(Basis(x, y, z), knuckles.lerp(curled, 0.5))


## 握法：fist 沿拳头的握轴（出招），along 顺着手伸出（长枪前刺、垂手持剑），against 逆着手（垂手拄枪），
## plane 贴着侧面朝前上方（戒备、走跑；每帧按手的姿势重算，见 _apply_plane）
func set_grip_mode(mode: String) -> void:
	if mode == grip_mode:
		return
	grip_mode = mode
	if _kit.get_parent() != null:
		if mode == "plane":
			_apply_plane()
		else:
			_kit.transform = _grip_transform("l" if weapon_form == "bow" else "r")


## 兵器在模型空间里的朝向定死：刃尖朝前上方，刃面朝相机（-X），握点仍在拳眼。
## 骨架空间就是模型空间（Rig、Skeleton3D 都没有变换）
func _apply_plane() -> void:
	var side := "l" if weapon_form == "bow" else "r"
	var hand := _global_of("hand_" + side)
	var pitch := deg_to_rad(PLANE_PITCH.get(weapon_form, PLANE_PITCH_DEFAULT))
	var y := Vector3(0.0, sin(pitch), cos(pitch))
	# 刃面朝相机；弓的弓腹（零件 +X）要朝前（+Z），所以弓的 z 反过来取 -X
	var z := Vector3.LEFT if weapon_form == "bow" else Vector3.RIGHT
	var want := Basis(y.cross(z), y, z)
	var size := hand.basis.get_scale().x
	var grip := _grip_transform(side)
	_kit.transform = Transform3D(hand.basis.inverse() * want.scaled(Vector3.ONE * size), grip.origin)


func _rest_origin(bone: String) -> Vector3:
	return skeleton.get_bone_rest(skeleton.find_bone(bone)).origin


## 动画每次套到骨架上以后，把要握拳那只手的手指改成握拳（相对静止姿势设定，重复调用结果一样）
func apply_fists() -> void:
	_apply_draw()
	if grip_mode == "plane" and _kit.get_parent() != null:
		_apply_plane()
	for side in fists:
		if not fists[side]:
			continue
		var thumb_sign := 1.0 if side == "r" else -1.0
		for finger in FINGERS:
			for joint in CURL:
				_bend("%s_%s_%s" % [finger, joint, side], Vector3.RIGHT, CURL_SIGN * CURL[joint])
		for joint in THUMB:
			_bend("thumb_%s_%s" % [joint, side], Vector3.BACK, -thumb_sign * THUMB[joint])


## 拉弓：射箭动作原本是单手施法，右手垂在腰边。这里用两段骨的 IK 把右手送到弓弦上、往后拉到下巴，
## 弓弦拆成两段跟着右手走；撒放以后弦弹直，右臂慢慢交回给动作。
func _apply_draw() -> void:
	var drawn := weapon_form == "bow" and draw_reach > 0.0 and _kit.get_parent() != null
	var nock := _string_nock()
	var pull_string := drawn and draw_string and not _bow_limbs.is_empty()
	if not _bow_limbs.is_empty() and _kit_parts.has("bow_string_" + _bow_limbs):
		_kit_parts["bow_string_" + _bow_limbs].visible = not pull_string
	for piece in _string_parts:
		piece.visible = pull_string
	if not drawn:
		return
	var head := _global_of("Head").origin
	var target := nock.lerp(head + DRAW_ANCHOR, draw_pull)
	_reach("upperarm_r", "lowerarm_r", "hand_r", target, ELBOW_HINT, draw_reach)
	if pull_string:
		var hand := _global_of("hand_r")
		var knuckles := (_global_of("index_01_r").origin
			+ _global_of("middle_01_r").origin) * 0.5
		var grip := hand.origin.lerp(knuckles, 0.7)
		var to_kit := (_global_of("hand_l") * _kit.transform).affine_inverse()
		var tips := _string_tips()
		var held := to_kit * grip
		for i in 2:
			_rod(_string_parts[i], tips[i], held)


## 弓弦两头（兵器零件坐标）：弦沿 +Y，取包围盒的上下两端
func _string_tips() -> Array:
	var mesh: MeshInstance3D = _kit_parts["bow_string_" + _bow_limbs]
	var box := mesh.get_aabb()
	var mid := box.get_center()
	return [mesh.transform * Vector3(mid.x, box.position.y, mid.z), mesh.transform * Vector3(mid.x, box.end.y, mid.z)]


## 弦正中在骨架空间的位置（右手从这里搭上弦）
func _string_nock() -> Vector3:
	if _bow_limbs.is_empty() or _kit.get_parent() == null:
		return Vector3.ZERO
	var tips := _string_tips()
	var to_skel := _global_of("hand_l") * _kit.transform
	return to_skel * ((tips[0] + tips[1]) * 0.5)


func _rod(piece: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var along := b - a
	var y := along.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	piece.transform = Transform3D(Basis(x, y * along.length(), y.cross(x)), (a + b) * 0.5)


## 两段骨 IK：把 tip 骨的原点送到 target，肘朝 hint 那边弯；weight 在动作姿势和 IK 之间插值
func _reach(root_bone: String, mid_bone: String, tip_bone: String, target: Vector3, hint: Vector3, weight: float) -> void:
	var ri := skeleton.find_bone(root_bone)
	var mi := skeleton.find_bone(mid_bone)
	var ti := skeleton.find_bone(tip_bone)
	var a := _global(ri).origin
	var b := _global(mi).origin
	var c := _global(ti).origin
	var upper := a.distance_to(b)
	var lower := b.distance_to(c)
	var reach := clampf(a.distance_to(target), absf(upper - lower) + 0.001, (upper + lower) * 0.999)
	var toward := (target - a).normalized()
	var bend := hint - toward * hint.dot(toward)
	if bend.length_squared() < 1e-6:
		return
	bend = bend.normalized()
	var cos_a := clampf((upper * upper + reach * reach - lower * lower) / (2.0 * upper * reach), -1.0, 1.0)
	var elbow := a + toward * upper * cos_a + bend * upper * sqrt(1.0 - cos_a * cos_a)
	var wrist := a + toward * reach
	_swing(ri, b - a, elbow - a, weight)
	b = _global(mi).origin
	c = _global(ti).origin
	_swing(mi, c - b, wrist - b, weight)


## 把一根骨在骨架空间里转一下，让它从 from 方向转到 to 方向（按 weight 只转一部分）
func _swing(bone: int, from: Vector3, to: Vector3, weight: float) -> void:
	if from.length_squared() < 1e-8 or to.length_squared() < 1e-8:
		return
	var turn := Quaternion(from.normalized(), to.normalized())
	turn = Quaternion.IDENTITY.slerp(turn, clampf(weight, 0.0, 1.0))
	var pose := _global(bone)
	pose.basis = Basis(turn) * pose.basis
	var parent := skeleton.get_bone_parent(bone)
	var local := (_global(parent).affine_inverse() * pose) if parent >= 0 else pose
	skeleton.set_bone_pose_rotation(bone, local.basis.get_rotation_quaternion())


## 骨在骨架空间的当下姿势，直接由各级本地姿势乘出来。
## 动画刚写进骨架时（mixer_applied 回调里），get_bone_global_pose 还是上一次的缓存，不能用
func _global(bone: int) -> Transform3D:
	var pose := skeleton.get_bone_pose(bone)
	var parent := skeleton.get_bone_parent(bone)
	while parent >= 0:
		pose = skeleton.get_bone_pose(parent) * pose
		parent = skeleton.get_bone_parent(parent)
	return pose


func _global_of(bone: String) -> Transform3D:
	return _global(skeleton.find_bone(bone))


func _bend(bone: String, axis: Vector3, degrees: float) -> void:
	var b := skeleton.find_bone(bone)
	if b < 0:
		return
	var rest := skeleton.get_bone_rest(b).basis.get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(b, rest * Quaternion(axis, deg_to_rad(degrees)))


## 给一个槽的所有款式统一上色（染色）；白色就是原色
func set_tint(slot: String, color: Color) -> void:
	for variant in SLOTS[slot]:
		for part in SLOTS[slot][variant]:
			for mat in _materials.get(part, []):
				mat.set_shader_parameter("tint", color)


## 骨盆的全局位置（倒地、翻滚时身体会离开原点，镜头跟着它走）
func hip_position() -> Vector3:
	var skel := find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return global_position
	return skel.global_transform * skel.get_bone_global_pose(skel.find_bone("pelvis")).origin


func actions() -> PackedStringArray:
	return anim.get_animation_list()


func _toonify(mesh: MeshInstance3D, outline := 0.006) -> void:
	var hair := 1.0 if mesh.name.begins_with("Head_Hair") or mesh.name == "Head_Eyebrows" else 0.0
	for i in mesh.mesh.get_surface_count():
		var base := mesh.mesh.surface_get_material(i) as BaseMaterial3D
		var toon := ShaderMaterial.new()
		toon.shader = TOON
		if base and base.albedo_texture:
			toon.set_shader_parameter("albedo_tex", base.albedo_texture)
		if base:  # 兵器零件的材质按用途命名（steel、trim……），上色时按名字找
			toon.set_meta("role", base.resource_name)
		toon.set_shader_parameter("hair", hair)
		var line := ShaderMaterial.new()
		line.shader = OUTLINE
		line.set_shader_parameter("width", outline)
		# 眼睛、眉毛不描边，不然脸上一圈黑
		if not mesh.name in ["Head_Eyes", "Head_Eyebrows"]:
			toon.set_meta("hull", line)
			if hull_outline:
				toon.next_pass = line
		mesh.set_surface_override_material(i, toon)
		_materials.get_or_add(String(mesh.name), []).append(toon)


## 每个部件一份外扩背面的描边（画得细，内部的线也有），但每帧绘制次数多一倍多。
## 游戏里的主角画布改用屏幕空间描边（model_silhouette.gdshader），这里就关掉；试穿台等大图保留。
func set_hull_outline(on: bool) -> void:
	hull_outline = on
	for part in _materials:
		for mat: ShaderMaterial in _materials[part]:
			mat.next_pass = mat.get_meta("hull") if on and mat.has_meta("hull") else null
