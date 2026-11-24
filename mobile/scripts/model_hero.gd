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
const STRING_COLOR := Color("#d4c4a5")
const SPEAR_TUFT := Color("#b8342a")
var weapon_form := ""
var grip_mode := "fist"
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
			var blade := _pick(design.get("blade", ""), ["jian", "qixing", "bolang"])
			show = ["sword_blade_" + blade, "sword_grip",
				"sword_guard_" + _pick(design.get("guard", ""), ["disc", "bar", "ruyi", "crescent"]),
				"sword_pommel_" + _pick(design.get("pommel", ""), ["knob", "hex", "ring", "cloud"])]
			if blade == "qixing":
				show.append("sword_inlay_qixing")
			if Color(design.get("tassel", Color.TRANSPARENT)).a > 0.0:
				show.append("sword_tassel")
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


## 握法：fist 沿拳头的握轴（平时），along 顺着手伸出（长枪前刺、垂手持剑），against 逆着手（垂手拄枪）
func set_grip_mode(mode: String) -> void:
	if mode == grip_mode:
		return
	grip_mode = mode
	if _kit.get_parent() != null:
		_kit.transform = _grip_transform("l" if weapon_form == "bow" else "r")


func _rest_origin(bone: String) -> Vector3:
	return skeleton.get_bone_rest(skeleton.find_bone(bone)).origin


## 动画每次套到骨架上以后，把要握拳那只手的手指改成握拳（相对静止姿势设定，重复调用结果一样）
func apply_fists() -> void:
	for side in fists:
		if not fists[side]:
			continue
		var thumb_sign := 1.0 if side == "r" else -1.0
		for finger in FINGERS:
			for joint in CURL:
				_bend("%s_%s_%s" % [finger, joint, side], Vector3.RIGHT, CURL_SIGN * CURL[joint])
		for joint in THUMB:
			_bend("thumb_%s_%s" % [joint, side], Vector3.BACK, -thumb_sign * THUMB[joint])


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
