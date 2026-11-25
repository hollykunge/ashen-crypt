extends Node3D
## 3D 角色模型（gen-out/model 用 export_godot.py 导出的 hero.glb）：按槽换装、播放动作、卡通着色加描边。
## 骨架和部件名与 Blender 里一致；角色朝 +Z，左手在 +X。

const SCENE := preload("res://art/model-hero/hero.glb")
## 兵器零件（gen-out/model/scripts/build_weapons.py）：原点都在握点，+Y 朝刃尖 / 枪头 / 上弓臂，+X 是刃宽（弓腹朝前）
const WEAPONS := preload("res://art/model-hero/weapons.glb")
const TOON := preload("res://scripts/model_toon.gdshader")
const OUTLINE := preload("res://scripts/model_outline.gdshader")
const BodyShape := preload("res://scripts/body_shape.gd")

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
## 女主角（gen-out/model/scripts/build_female.py，导出 female.glb）：骨架和动作与男主角同名，部件不同。
## 只有布衣（女农夫）和游侠两套原装，皮甲、链甲是游侠那套重新上色；没有头饰，发髻一直露着
## 只有女主角才加载（不和男模型一起常驻内存）
const FEMALE_SCENE := "res://art/model-hero/female.glb"
const FEMALE_HEAD := ["Head_Skin", "Head_Eyes", "Head_Eyebrows", "Head_Hair_Main"]
const FEMALE_SLOTS := {
	"torso": {
		"peasant": ["F_Peasant_Body"],
		"ranger": ["F_Ranger_Body", "F_Ranger_Body_1", "F_Ranger_Body_2"],
		"leather": ["F_Leather_Body", "F_Leather_Body_1", "F_Leather_Body_2"],
		"chain": ["F_Chain_Body", "F_Chain_Body_1", "F_Chain_Body_2"],
	},
	"arms": {
		"peasant": ["F_Peasant_Arms"],
		"ranger": ["F_Ranger_Arms", "F_Ranger_Arms_1"],
		"leather": ["F_Leather_Arms", "F_Leather_Arms_1"],
		"chain": ["F_Chain_Arms", "F_Chain_Arms_1"],
	},
	"legs": {
		"peasant": ["F_Peasant_Legs"],
		"ranger": ["F_Ranger_Legs"],
		"leather": ["F_Leather_Legs"],
		"chain": ["F_Chain_Legs"],
	},
	"feet": {
		"peasant": ["F_Peasant_Feet"],
		"ranger": ["F_Ranger_Feet"],
		"leather": ["F_Leather_Feet"],
		"chain": ["F_Chain_Feet"],
	},
	"shoulder": {
		"none": [],
		"ranger": ["F_Ranger_Acc_Pauldrons"],
		"leather": ["F_Leather_Acc_Pauldrons"],
		"chain": ["F_Chain_Acc_Pauldrons"],
	},
	"hood": {
		"none": [],
		"ranger": ["F_Ranger_Head_Hood"],
	},
	"headgear": {"none": [], "hat": [], "leather": [], "iron": []},
}
## Tripo 分槽男主角（gen-out/model/tripo-dark-hero/parts，导出 hero_tripo.glb）：短打、皮甲、链甲三套 Tripo 模型
## 拆成部件，和一副打底身体（无头无臂，按三套衣服最内层收缩过）一起蒙在短打那副骨架上（骨骼名、动作和 hero.glb 相同），
## 各槽可以混搭。用 ModelHero.new("tripo") 创建；只有用到时才加载
const TRIPO_SCENE := "res://art/model-hero/hero_tripo.glb"
## 始终露着：打底身体和短打的头（脸和短发一体）
const TRIPO_HEAD := ["body__base_body", "peasant3__body_head"]
const _TRIPO_TORSO := {
	"peasant": ["peasant3__top", "peasant3__belt"],
	"leather": ["leather2__top", "leather2__belt"],
	"chain": ["chain2__top", "chain2__belt"],
}
const _TRIPO_ARMS := {
	"peasant": ["peasant3__body_arm_L", "peasant3__body_arm_R", "peasant3__bracer_L", "peasant3__bracer_R"],
	"leather": ["leather2__arm_L", "leather2__arm_R"],
	"chain": ["chain2__arm_L", "chain2__arm_R"],
}
const _TRIPO_LEGS := {"peasant": ["peasant3__pants"], "leather": ["leather2__pants"], "chain": ["chain2__pants"]}
const _TRIPO_FEET := {
	"peasant": ["peasant3__boot_L", "peasant3__boot_R"],
	"leather": ["leather2__boot_L", "leather2__boot_R"],
	"chain": ["chain2__boot_L", "chain2__boot_R"],
}
## 没有游侠那套，退回短打；肩甲长在上衣里，没有单独的肩甲和兜帽；没有斗笠，不戴头盔就露出发髻
const TRIPO_SLOTS := {
	"torso": {"peasant": _TRIPO_TORSO.peasant, "ranger": _TRIPO_TORSO.peasant, "leather": _TRIPO_TORSO.leather, "chain": _TRIPO_TORSO.chain},
	"arms": {"peasant": _TRIPO_ARMS.peasant, "ranger": _TRIPO_ARMS.peasant, "leather": _TRIPO_ARMS.leather, "chain": _TRIPO_ARMS.chain},
	"legs": {"peasant": _TRIPO_LEGS.peasant, "ranger": _TRIPO_LEGS.peasant, "leather": _TRIPO_LEGS.leather, "chain": _TRIPO_LEGS.chain},
	"feet": {"peasant": _TRIPO_FEET.peasant, "ranger": _TRIPO_FEET.peasant, "leather": _TRIPO_FEET.leather, "chain": _TRIPO_FEET.chain},
	"shoulder": {"none": [], "ranger": [], "leather": [], "chain": []},
	"hood": {"none": [], "ranger": []},
	"headgear": {
		"none": ["peasant3__hair_topknot"],
		"hat": ["peasant3__hair_topknot"],
		"leather": ["leather2__helmet"],
		"iron": ["chain2__helmet"],
	},
}
## 链甲的手臂槽只有前臂护腕和手，上半截袖子长在链甲上衣上：上衣不是链甲时补上短打的光胳膊
const TRIPO_UPPER_ARMS := ["peasant3__body_arm_L", "peasant3__body_arm_R"]
var tripo := false
var female := false
var slots: Dictionary = SLOTS
var head_parts: Array = HEAD
var topknot: Array = TOPKNOT
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
## 兵器：古兵器素材包里挑的整件（gen-out/model/scripts/import_pack_weapons.py 导出），按锻造出的刃型 / 枪头 /
## 弓臂（weapon_design.gd 的 blade / head）挑一件，贴图照原样，只套卡通着色和描边
const STRING_COLOR := Color("#d4c4a5")
var weapon_form := ""
var grip_mode := "fist"
## 垂手持剑（along）时兵器在手骨本地坐标里再转多少度（欧拉角，度）。行装页正面站着时，
## 顺着手垂下来的刀会斜着横过两腿，往外撇一点让刀身落在腿外侧
var along_tilt := Vector3.ZERO
## plane 握法：兵器贴着侧面（相机看过去的那个平面）朝前上方伸出，抬多少度。
## 戒备动作里手是垂着的，照拳头的握轴拿，剑和枪会横着戳向镜头，侧视里只剩一小截还插进身体
const PLANE_PITCH := {"spear": 12.0, "bow": 55.0}   # 行装页：弓斜着朝前上方提在左手
const PLANE_PITCH_DEFAULT := 20.0
## upright 握法（战场上的弓）：弓竖着、上弓臂略朝前倾，弓腹朝目标。原来按左拳的握轴拿，
## 拉弓时弓平躺着横在身前（俯视看弓臂左右横着），不像在射箭
const UPRIGHT_PITCH := 80.0
## 挥砍时刀剑绕拳眼往刀背那边翻多少度（cutout_hero.gd 按出招进度设）：蓄力时刀背过肩，
## 劈下去之前翻回来。动作素材是空手的，照拳头握轴拿，蓄力时刀尖朝前、下劈前刀竖在脸前
var swing_cock := 0.0
## 长枪：右手握在离枪尾多远（米）；左手握在右手前面多远。两只手都握在杆上，
## 不然前刺是单手一拳，枪尾从头上穿过去
const SPEAR_REAR_GRIP := 0.22
const SPEAR_HAND_GAP := 0.42
const SUPPORT_ELBOW := Vector3(0.7, -1.0, -0.2)   # 左肘朝外、朝下
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


## 模型在创建时就装好（不等进场景树），这样还没上场就能先换装、定动作。gender 为 "female" 时用女主角模型，
## 为 "tripo" 时用 Tripo 分槽男主角
func _init(gender := "male") -> void:
	female = gender == "female"
	tripo = gender == "tripo"
	slots = FEMALE_SLOTS if female else (TRIPO_SLOTS if tripo else SLOTS)
	head_parts = FEMALE_HEAD if female else (TRIPO_HEAD if tripo else HEAD)
	topknot = [] if female or tripo else TOPKNOT   # Tripo 的发髻放在 headgear 的 none / hat 里
	var model: Node
	if female or tripo:
		model = (load(FEMALE_SCENE if female else TRIPO_SCENE) as PackedScene).instantiate()
	else:
		model = SCENE.instantiate()
	add_child(model)
	for node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
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


## 兵器零件在 hold() 之前不在节点树里，角色被释放时要顺手释放（没拿兵器就被换掉、或测试里直接 new 出来的角色）
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_kit) and _kit.get_parent() == null:
		_kit.free()


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
	var wanted := head_parts.duplicate()
	for slot in outfit:
		wanted += slots[slot][outfit[slot]]
	var gear: String = outfit.get("headgear", "none")
	if outfit.get("hood", "none") != "none":  # 戴兜帽时藏起头发和头饰
		for part in ["Head_Hair_Main"] + topknot + slots.headgear[gear]:
			wanted.erase(part)
	elif gear != "none":  # 头饰盖住头顶：发髻收在里面
		for part in topknot:
			wanted.erase(part)
	if tripo and outfit.get("arms", "") == "chain" and outfit.get("torso", "") != "chain":
		wanted += TRIPO_UPPER_ARMS
	for part in _meshes:
		_meshes[part].visible = part in wanted
		if part in wanted:
			shape(part)


## 体型（body_shape.gd）：部件第一次露出来时才推形，没穿的衣服不白算
func shape(part: String) -> void:
	var node: MeshInstance3D = _meshes[part]
	if tripo or node.has_meta("shaped"):  # 形变场按 hero.glb 的身材量的，Tripo 模型比例不同，不推
		return
	node.set_meta("shaped", true)
	node.mesh = BodyShape.shaped("female" if female else "male", part, node.mesh)


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
	# 每种形制按锻造出的刃型 / 枪头 / 弓臂挑一件整件兵器；贴图照原样，不按五行上色（五行只管属性）
	var show: Array = [weapon_part(form, design)]
	if form == "bow":
		show.append("bow_string_" + limbs_of(design))
	_bow_limbs = limbs_of(design) if form == "bow" else ""
	for part in _kit_parts:
		_kit_parts[part].visible = part in show
	apply_fists()


## 一件兵器在 weapons.glb 里的名字：刀 dao_blade_*、剑 sword_blade_*、枪 spear_head_*、弓 bow_limbs_*
static func weapon_part(form: String, design: Dictionary) -> String:
	match form:
		"spear":
			return "spear_head_" + _pick(design.get("head", ""), ["leaf", "snake", "ji"])
		"bow":
			return "bow_limbs_" + limbs_of(design)
	return kit_of(form) + "_blade_" + _pick(design.get("blade", ""), ["jian", "qixing", "bolang"])


var _bow_limbs := ""

## 刀剑用哪套零件：刀（sword）是 dao_，剑（jian）是 sword_
static func kit_of(form: String) -> String:
	return "dao" if form == "sword" else "sword"


static func limbs_of(design: Dictionary) -> String:
	return "chang" if design.get("head", "") == "chang" else "fanqu"


static func _pick(value: String, allowed: Array) -> String:
	return value if value in allowed else allowed[0]


## 握点在手骨本地坐标里的位置和朝向：拳眼是四指弯起来围出的那个洞的中心（各指四个关节握拳后的平均位置）；
## 兵器沿指根连线（小指 → 食指）伸出，刃宽朝指节指的方向（刃口跟着拳面走）。
## 原来取「指根和弯下来的中指第二节之间」，比洞心往指节那边偏了快两厘米，柄从指节底下滑出去，看着不像握在手里
func _grip_transform(side: String) -> Transform3D:
	var index := _rest_origin("index_01_" + side)
	var pinky := _rest_origin("pinky_01_" + side)
	var middle := _rest_origin("middle_01_" + side)
	var hole := Vector3.ZERO
	for finger in FINGERS:
		for p in _curled_finger(finger, side):
			hole += p
	hole /= FINGERS.size() * 4.0
	var y := (index - pinky).normalized()
	var x := (middle - y * middle.dot(y)).normalized()
	if grip_mode in ["along", "against"]:
		# along：顺着手（手腕 → 指根）伸出去。前刺时拳面朝下，指根连线是横的，枪会横过来，改成顺着小臂刺出；
		# 垂手站着时顺着手往下，剑尖朝地。against：反过来，手垂着时枪尖朝天、拄着站
		var along := middle.normalized() * (1.0 if grip_mode == "along" else -1.0)
		x = (y - along * y.dot(along)).normalized()
		y = along
	var z := x.cross(y)
	var basis := Basis(x, y, z)
	if grip_mode == "along" and not along_tilt.is_zero_approx():
		basis = Basis.from_euler(along_tilt * PI / 180.0) * basis
	return Transform3D(basis, hole)


## 一根手指握拳以后四个关节（指根、二节、三节、指尖）在手骨本地坐标里的位置：
## 从静止姿势出发，每节按 CURL 弯过去（和 apply_fists 弯的一样）
func _curled_finger(finger: String, side: String) -> Array:
	var points := []
	var chain := Transform3D.IDENTITY
	for joint in ["01", "02", "03", "04_leaf"]:
		var b := skeleton.find_bone("%s_%s_%s" % [finger, joint, side])
		if b < 0:
			break
		var rest := skeleton.get_bone_rest(b)
		if CURL.has(joint):
			rest.basis = Basis(rest.basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, deg_to_rad(CURL_SIGN * CURL[joint]))) \
				.scaled(rest.basis.get_scale())
		chain = chain * rest
		points.append(chain.origin)
	return points


## 握法：fist 沿拳头的握轴（出招），along 顺着手伸出（垂手持剑），against 逆着手（垂手拄枪），
## plane 贴着侧面朝前上方（戒备、走跑；每帧按手的姿势重算，见 _apply_plane），
## thrust 长枪前刺：枪照样穿过拳眼，把手腕转过去让拳的握轴顺着小臂朝前（见 _apply_thrust）
func set_grip_mode(mode: String) -> void:
	if mode == grip_mode:
		return
	grip_mode = mode
	if _kit.get_parent() != null:
		if mode in ["plane", "upright"]:
			_apply_plane()
		else:
			_kit.transform = _grip_transform("l" if weapon_form == "bow" else "r")


## 长枪前刺：动作是一记直拳，拳面朝前、指根连线横着，顺着拳的握轴拿枪，枪会横在身前；
## 顺着手伸出去（along）的话枪又从手掌底下穿过，看着是手搭在枪上。这里枪照样穿过拳眼（fist 的握点），
## 把手腕转过去，让拳的握轴顺着小臂朝前，枪就攥在拳里刺出去
func _apply_thrust() -> void:
	var hand := _global_of("hand_r")
	var forearm := hand.origin - _global_of("lowerarm_r").origin
	var axis := hand.basis * _grip_transform("r").basis.y
	_swing(skeleton.find_bone("hand_r"), axis, forearm, 1.0)


## 长枪双手握，左手用两段骨 IK 送到枪杆上，手腕转到拳的握轴顺着枪杆（IK 和转腕互相影响，来回做两遍）。
## 戒备：右手在后、握在离枪尾 SPEAR_REAR_GRIP 处，左手在前。前刺：动作是右手直拳、左手收在下巴前，
## 右手伸直够不到更前面，所以右手在前，左手在后握枪尾那段
func _apply_spear_hands() -> void:
	var part: MeshInstance3D = null
	for name in _kit_parts:
		if name.begins_with("spear_head_") and _kit_parts[name].visible:
			part = _kit_parts[name]
	if part == null:
		return
	var butt := (part.transform * part.get_aabb()).position.y
	var thrust := grip_mode == "thrust"
	var hold := butt + SPEAR_REAR_GRIP + (SPEAR_HAND_GAP if thrust else 0.0)
	var kit := _kit.transform
	kit.origin = _grip_transform("r").origin - kit.basis * Vector3(0.0, hold, 0.0)
	_kit.transform = kit
	var to_skel := _global_of("hand_r") * _kit.transform
	var shaft := (to_skel.basis * Vector3.UP).normalized()
	var gap := SPEAR_HAND_GAP / to_skel.basis.y.length() * (-1.0 if thrust else 1.0)
	var front := to_skel * Vector3(0.0, hold + gap, 0.0)
	var grip_l := _grip_transform("l")
	var hand_l := skeleton.find_bone("hand_l")
	for i in 2:
		var hand := _global(hand_l)
		_reach("upperarm_l", "lowerarm_l", "hand_l", front - hand.basis * grip_l.origin, SUPPORT_ELBOW, 1.0)
		hand = _global(hand_l)
		var axis := (hand.basis * grip_l.basis.y).normalized()
		_swing(hand_l, axis, shaft if axis.dot(shaft) >= 0.0 else -shaft, 1.0)


## 兵器在模型空间里的朝向定死：刃尖朝前上方，刃面朝相机（-X），握点仍在拳眼。
## 骨架空间就是模型空间（Rig、Skeleton3D 都没有变换）
func _apply_plane() -> void:
	var side := "l" if weapon_form == "bow" else "r"
	var hand := _global_of("hand_" + side)
	var pitch := deg_to_rad(UPRIGHT_PITCH if grip_mode == "upright" else PLANE_PITCH.get(weapon_form, PLANE_PITCH_DEFAULT))
	var y := Vector3(0.0, sin(pitch), cos(pitch))
	# 刃面朝相机。弓的弓腹、刀的刃口都是零件的 +X：弓腹要朝前，刀刃要朝下（不然戒备时刀刃朝天），
	# 这两样 z 取 -X，零件的 +X 就翻到下前方
	var z := Vector3.LEFT if weapon_form in ["bow", "sword"] else Vector3.RIGHT
	var want := Basis(y.cross(z), y, z)
	var size := hand.basis.get_scale().x
	var grip := _grip_transform(side)
	_kit.transform = Transform3D(hand.basis.inverse() * want.scaled(Vector3.ONE * size), grip.origin)


func _rest_origin(bone: String) -> Vector3:
	return skeleton.get_bone_rest(skeleton.find_bone(bone)).origin


## 动画每次套到骨架上以后，把要握拳那只手的手指改成握拳（相对静止姿势设定，重复调用结果一样）
func apply_fists() -> void:
	_level_head()
	_apply_draw()
	if grip_mode in ["plane", "upright"] and _kit.get_parent() != null:
		_apply_plane()
	elif grip_mode == "thrust" and weapon_form == "spear":
		_apply_thrust()
	elif grip_mode == "fist" and weapon_form in ["sword", "jian"] and _kit.get_parent() != null:
		# 绕拳眼翻腕（零件 +Y 刀尖、+X 刃口，绕零件 Z 轴转；负角度刀尖往刃口那边转，蓄力时就是往身后）
		_kit.transform = _grip_transform("r").rotated_local(Vector3.BACK, deg_to_rad(swing_cock))
	if weapon_form == "spear" and grip_mode in ["plane", "thrust"] and _kit.get_parent() != null:
		_apply_spear_hands()
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


## 头摆正、向前平视：动作里低头（待机、戒备、走跑都有点耷拉着头）看着像在看地。
## 把头在模型空间里的朝向拉回静止姿势（平视正前方），按 HEAD_LEVEL 和动作原样混合；倒地动作照原样
const HEAD_LEVEL := 0.85
func _level_head() -> void:
	if anim.current_animation.contains("Death"):
		return
	var b := skeleton.find_bone("Head")
	if b < 0:
		return
	var parent := skeleton.get_bone_parent(b)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis.orthonormalized()
	var want := skeleton.get_bone_global_rest(b).basis.orthonormalized()
	var level := (parent_basis.inverse() * want).get_rotation_quaternion()
	var now := skeleton.get_bone_pose_rotation(b)
	skeleton.set_bone_pose_rotation(b, now.slerp(level, HEAD_LEVEL))


func _bend(bone: String, axis: Vector3, degrees: float) -> void:
	var b := skeleton.find_bone(bone)
	if b < 0:
		return
	var rest := skeleton.get_bone_rest(b).basis.get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(b, rest * Quaternion(axis, deg_to_rad(degrees)))


## 给一个槽的所有款式统一上色（染色）；白色就是原色
func set_tint(slot: String, color: Color) -> void:
	for variant in slots[slot]:
		for part in slots[slot][variant]:
			if part.contains("__body_"):  # Tripo 短打的光胳膊是皮肤，不跟着护腕染色
				continue
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
