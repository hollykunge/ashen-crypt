extends Node2D
## 皮影式拼件角色：部件图挂在骨骼节点上，动作全由代码算关节角度。
##
## rig.json 记录每个部件的关节点（部件图里的像素坐标），可选地覆盖待机姿势、走路幅度和攻击关键帧。
## 换装就是把某根骨头上的图换成另一套（set_outfit），骨骼和动作都不变。
## 远侧的手脚复用近侧的图，压暗、错开一点当纵深。
##
## 可选部件：skirt_front / skirt_back（长衣下摆前后片，挂在腰上，跟着大腿摆）、weapon（握在近侧手里）。

## 远侧手脚压暗多少，做前后纵深；压太狠会像两条不同颜色的裤子。rig.json 的 far_tint 可覆盖（0～1）
const FAR_TINT := 0.82
const FAR_SHIFT := Vector2(-6, -4)  # 远侧手脚往后错开一点做纵深；错太多，远侧肩头会从后背露出来像驼峰

## 层级：数字大的画在前面。整个人物再抬 10 层，压在背景上面。
## 下摆是一圈包住两条腿的布，侧面看到的是靠镜头那一侧的布面，所以前后两片都压在两条腿前面，
## 腿只从下摆底下和两片之间的开衩露出来，不会画到布上面去。
const Z := {
	"arm_far_up": -9, "arm_far_hand": -8, "arm_far_lo": -7, "leg_far_up": -6, "leg_far_lo": -6, "boot_far": -5,
	"crotch": -4, "leg_near_up": -3, "leg_near_lo": -3, "boot_near": -2, "skirt_back": -2, "pelvis": -1, "head_behind": -1, "torso": 0, "skirt_front": 1, "collar": 2, "head": 4,
	"weapon": 5, "arm_near_up": 6, "arm_near_hand": 7, "arm_near_lo": 8,
}

## 角度约定（度）：手臂往前摆为正；肘往前弯为正；躯干前倾为正；
## 兵器 blade 是相对前臂的角度，0 时剑跟前臂垂直、剑尖朝前，正值剑尖往下压。
## 腿不用角度：先定两只脚踩在哪（foot_near / foot_far，以腿长为单位，x 往前、y 往上为抬脚），
## 再由 IK 倒推大腿、小腿的角度，所以支撑脚不会在地上打滑。
## hip：胯离地多高（以腿长为单位，1 是腿完全伸直）；dx：胯往前挪多少（腿长为单位）。
const IDLE := {
	"torso": 6, "neck": -4, "arm_near_up": 8, "arm_near_lo": 18, "arm_far_up": -4, "arm_far_lo": 14, "blade": 0.0,
	"hip": 0.86, "dx": 0.0, "foot_near_x": 0.16, "foot_near_y": 0.0, "foot_far_x": -0.12, "foot_far_y": 0.0,
	"drag": 0.0, "foot_near_heel": 0.0, "foot_far_heel": 0.0,
}
## 走路：stride 一步的长度、lift 抬脚高度、bob 胯的起伏，都以腿长为单位；period 两步一个周期（秒）；
## duty 一只脚踩在地上的时间占周期的比例（大于一半才有双脚同时着地的那一下）。
## hold：抬脚后脚先在后面停多久才往前甩（占抬脚时间的比例），跑步时脚跟往上踢就靠它；
## pump：手臂往前摆时肘多弯多少度；drag：下摆被风往后带的角度；
## head：头跟着身子前倾的比例（0 是头竖直、1 是跟躯干一样斜）。
## heel：支撑脚后半段脚跟抬起的最大角度（度，脚绕前脚掌转），另一条腿往前迈时这只脚就踮起来蹬地；
## heel_from：从支撑段的哪儿开始抬（占踩地时间的比例，默认是脚退到胯正下方那一刻）。
const WALK := {"lean": 12, "stride": 0.5, "lift": 0.12, "bob": 0.025, "arm": 24, "elbow": 22, "period": 1.1,
	"duty": 0.6, "hip": 0.84, "near_arm": 1.0, "near_up": 8, "near_lo": 22, "near_blade": 0.0,
	"hold": 0.0, "pump": 8, "drag": 0.0, "head": 0.2, "heel": 24.0}
## 跑：一只脚着地不到半个周期，中间有两脚都离地的腾空；着地时胯压到最低（缓冲），腾空时最高
const RUN := {"lean": 16, "stride": 0.8, "lift": 0.3, "bob": 0.04, "arm": 34, "elbow": 80, "period": 0.68,
	"duty": 0.34, "hip": 0.88, "near_arm": 0.6, "near_up": 4, "near_lo": 60, "near_blade": 40.0,
	"hold": 0.2, "pump": 14, "drag": 10.0, "head": 0.5, "heel": 0.0}

## 攻击按关键姿势插值：起手往后仰、手举过头；挥击从头顶往前下方猛抓，前脚上一步、重心压低；
## 打中停一下（顿帧）；跟招；收势。第 2 段（起手 → 挥击）快出慢收，其余缓入缓出。
## step 是前脚往前迈多少（腿长为单位），后脚一直钉在原地。rig.json 的 attack 可整段替换。
const STRIKE := {"torso": 38, "neck": -28, "arm_near_up": 38, "arm_near_lo": -4, "arm_far_up": 24, "arm_far_lo": 25,
	"dx": 0.16, "hip": 0.74, "step": 0.28}
const ATTACK := [
	[0.00, {}],
	[0.32, {"torso": -14, "neck": -2, "arm_near_up": 170, "arm_near_lo": 40, "arm_far_up": -30, "arm_far_lo": 30,
		"dx": -0.06, "hip": 0.84, "step": 0.0}],
	[0.41, STRIKE],
	[0.49, STRIKE],
	[0.64, {"torso": 42, "neck": -30, "arm_near_up": -22, "arm_near_lo": 24, "arm_far_up": 30, "arm_far_lo": 30,
		"dx": 0.2, "hip": 0.72, "step": 0.3}],
	[1.10, {}],
]

## 跟随：这些量不直接取姿势里的值，而是用弹簧去追，慢半拍、略微过冲，看着有分量。
## [刚度, 阻尼比]：刚度越大追得越快，阻尼比小于 1 会晃一下再停。
const SPRINGS := {
	# 手臂、手腕的弹簧要硬：软了会慢半拍，跑快时手跟腿差出四分之一圈，看着就是顺拐。上臂不加弹簧
	"arm_near_lo": [900.0, 0.75], "arm_far_lo": [700.0, 0.7], "neck": [200.0, 0.6], "blade": [900.0, 0.75],
	"skirt_front": [260.0, 0.6], "skirt_back": [220.0, 0.6],
	"skirt_front_lo": [70.0, 0.3], "skirt_back_lo": [60.0, 0.3],
	# IK 算出来的腿部角度再过一层很硬的弹簧（不过冲、滞后不到一帧）：腿快伸直时膝盖角对胯高、脚位极其敏感，
	# 差一点就跳一大截，这层把跳变压平，脚也不会打滑
	"leg_near_up": [2500.0, 1.0], "leg_near_lo": [2500.0, 1.0], "leg_far_up": [2500.0, 1.0], "leg_far_lo": [2500.0, 1.0],
}
const BLEND := 0.2  # 换动作时从上一个姿势过渡过去的秒数
const SOFT_IK := 0.06  # 软 IK 从腿长的 94% 开始收

var rig: Dictionary
var _bones := {}
var _sprites := {}  # 部件名 -> 用这张图的 Sprite2D 列表
var _idle := IDLE.duplicate()
var _walk := WALK.duplicate()
var _run := RUN.duplicate()
var _attack: Array = ATTACK
var _strike_from := 1  # 攻击关键帧里从第几段开始挥下去（起手那一帧的序号）
var _time := 0.0
var _action := "idle"
var _action_t := 0.0
var _leg := 1.0  # 腿长（大腿 + 小腿，部件图像素），走路、攻击的长度都以它为单位
var _last := {}  # 上一帧的最终姿势
var _from := {}  # 换动作那一刻的姿势，BLEND 秒内从它过渡过去
var _spring := {}  # 弹簧量的 [当前值, 速度]
var _trail: Line2D  # 刀光：挥剑时剑尖最近走过的一段
var _tips: Array = []  # [时间, 剑尖位置]
var _soft := 0.0  # 当前软 IK 的程度：走、跑时 SOFT_IK，站着、劈砍时 0（腿要能伸直）
var freeze_t := -1.0  # 调参面板用：>= 0 时攻击定格在这个时刻，方便对着某一帧调


## 贴图缓存：调参面板改部件大小时要重建骨骼，不用每次从硬盘重读图
static var _textures := {}


func setup(rig_path: String, outfit) -> void:
	setup_dict(JSON.parse_string(FileAccess.get_file_as_string(rig_path)), outfit)


func setup_dict(cfg: Dictionary, outfit) -> void:
	reload_params(cfg)
	_build()
	set_outfit(outfit)
	_leg = _at("thigh", "end").length() + _at("shin", "sole").length()


## 只换动作参数（待机、走、跑、攻击、远侧明暗），不重建骨骼。调参面板拖滑块时用。
func reload_params(cfg: Dictionary) -> void:
	# 在副本上展开 same_as：这件跟另一件共用关节点和缩放（远侧手臂跟近侧手臂轮廓一样，只是画的是内侧），
	# 自己写了的键优先。近侧调粗细长短时远侧跟着变；调参面板存回去的还是原样的 same_as
	rig = cfg.duplicate(true)
	for part in rig.parts:
		var p: Dictionary = rig.parts[part]
		if p.has("same_as"):
			var src: Dictionary = rig.parts[p.same_as]
			for k in src:
				if not p.has(k):
					p[k] = src[k]
	_idle = IDLE.duplicate()
	_idle.merge(rig.get("idle", {}), true)
	_walk = WALK.duplicate()
	_walk.merge(rig.get("walk", {}), true)
	_run = RUN.duplicate()
	_run.merge(rig.get("run", {}), true)
	_attack = rig.get("attack", ATTACK)
	_strike_from = int(rig.get("attack_strike", 1))
	var k: float = rig.get("far_tint", FAR_TINT)
	for part in _sprites:
		for s in _sprites[part]:
			if s.has_meta("far"):
				s.modulate = Color(k, k * 0.98, k)


func current_action() -> String:
	return _action


func _has(part: String) -> bool:
	return rig.parts.has(part)


func _bone(name: String, parent: Node2D, at: Vector2) -> Node2D:
	var b := Node2D.new()
	b.name = name
	b.position = at
	parent.add_child(b)
	_bones[name] = b
	return b


func _attach(bone: Node2D, part: String, slot: String, far := false) -> void:
	var s := Sprite2D.new()
	s.centered = false
	s.z_index = Z[slot] + 10
	s.z_as_relative = false
	if far:
		var k: float = rig.get("far_tint", FAR_TINT)
		s.modulate = Color(k, k * 0.98, k)
		s.set_meta("far", true)
	bone.add_child(s)
	if not _sprites.has(part):
		_sprites[part] = []
	_sprites[part].append(s)


func _v(a) -> Vector2:
	return Vector2(a[0], a[1])


## 部件的缩放：AI 画的比例不对（头太大、手太长、靴子太粗）时在 rig.json 里按件调，不用重出图。
## 一个数是等比缩放；[横, 竖] 两个数分开缩，比如靴子只收窄、腿不变短。
func _s(part: String) -> Vector2:
	var k = rig.parts[part].get("scale", 1.0)
	if k is Array:
		return Vector2(k[0], k[1])
	return Vector2(k, k)


## 某个部件上一个关节点相对它自己转轴的位置（已乘上这件的缩放）
func _at(part: String, key: String) -> Vector2:
	return (_v(rig.parts[part][key]) - _v(rig.parts[part].pivot)) * _s(part)


func _build() -> void:
	var hips := _bone("hips", self, Vector2.ZERO)
	var torso := _bone("torso", hips, Vector2.ZERO)
	_attach(torso, "torso", "torso")
	var hip_at := _hip_at()
	var neck := _bone("neck", torso, _at("torso", "neck"))
	# 立领：一圈里衣的领子，挂在躯干上，压在脖子根和衣服的交界处，脖子不会光秃秃地插在衣服上
	if _has("collar"):
		var cl := _bone("collar", torso, (_v(rig.parts.collar.at) - _v(rig.parts.torso.pivot)) * _s("torso"))
		_attach(cl, "collar", "collar")
	# 头默认压在躯干上；behind 时垫在躯干下面，让衣领盖住脖子根的切口
	_attach(neck, "head", "head_behind" if rig.parts.head.get("behind", false) else "head")
	for side in ["far", "near"]:
		var far: bool = side == "far"
		var off := FAR_SHIFT if far else Vector2.ZERO
		# 远侧手臂隔着身体，看到的是内侧；有 far_upper_arm / far_forearm 就用它们，没有就借近侧的图
		var p_up := "far_upper_arm" if far and _has("far_upper_arm") else "upper_arm"
		var p_lo := "far_forearm" if far and _has("far_forearm") else "forearm"
		var up := _bone("arm_%s_up" % side, torso, _at("torso", "shoulder") + off)
		_attach(up, p_up, "arm_%s_up" % side, far)
		var lo := _bone("arm_%s_lo" % side, up, _at(p_up, "end"))
		_attach(lo, p_lo, "arm_%s_lo" % side, far)
		# 有单独的握剑手（hand）时：近侧前臂只用到手腕，手腕圆头塞进护腕底下，剑挂在手里画好的剑柄上
		if not far and _has("hand"):
			_cut_forearm(p_lo)
			var hand := _bone("arm_near_hand", lo, _split_point(p_lo))
			_attach(hand, "hand", "arm_near_hand")
		# 远侧那只空手看到的是掌心一侧，用单独的 far_hand；内侧前臂本身画到手腕为止，接在它的 wrist 上
		if far and _has("far_hand"):
			var at := _at(p_lo, "wrist") if rig.parts[p_lo].has("wrist") else _split_point(p_lo)
			if not rig.parts[p_lo].has("wrist"):
				_cut_forearm(p_lo)
			var fh := _bone("arm_far_hand", lo, at)
			_attach(fh, "far_hand", "arm_far_hand", true)
		var th := _bone("leg_%s_up" % side, hips, hip_at + off)
		_attach(th, "thigh", "leg_%s_up" % side, far)
		var sh := _bone("leg_%s_lo" % side, th, _at("thigh", "end"))
		_attach(sh, "shin", "leg_%s_lo" % side, far)
		# 靴子单独一件（鞋子槽），跟小腿共用关节点和缩放，压在小腿的裤管上面；裤管归裤子槽
		if _has("boot"):
			_attach(sh, "boot", "boot_%s" % side, far)
			# 有 split 时在脚踝处切开：靴筒跟着小腿，脚绕脚踝转，踩地时放平；foot_scale 单独缩脚（绕脚踝缩）
			if rig.parts.boot.has("split"):
				_split("boot", sh, "foot_%s" % side, "boot_%s" % side, far)
				var fs: float = rig.parts.boot.get("foot_scale", 1.0)
				_bones["foot_%s" % side].scale = Vector2(fs, fs)
	# 臀胯：腰带下面一块裤子上段（后面鼓出臀部、前面是胯），压在两条大腿上面；
	# 大腿顶端藏在它里面，腿是从臀胯底下长出来的，不是直接插在腰上
	if _has("pelvis"):
		var pv := _bone("pelvis", hips, (_v(rig.parts.pelvis.at) - _v(rig.parts.torso.pivot)) * _s("torso"))
		_attach(pv, "pelvis", "pelvis")
	# 裤裆：两条大腿只在胯上一个点相连，迈大步时中间是空的，腿像飘着；垫一块裤裆在两腿之间
	if _has("crotch"):
		var cr := _bone("crotch", hips, hip_at)
		_attach(cr, "crotch", "crotch")
	# 下摆挂在胯上而不是躯干上：躯干前倾时下摆仍然往下垂。
	# 有 split 时一片切成上下两截：上半截被大腿顶起来盖住腿，下半截挂在它底边往下垂，布就能搭在膝盖上
	for flap in ["skirt_back", "skirt_front"]:
		if _has(flap):
			var b := _bone(flap, hips, (_v(rig.parts[flap].at) - _v(rig.parts.torso.pivot)) * _s("torso"))
			_attach(b, flap, flap)
			if rig.parts[flap].has("split"):
				_split(flap, b, flap + "_lo", flap, false)
	if _has("weapon"):
		var w: Node2D
		if _bones.has("arm_near_hand"):
			# 剑的转轴（缠绳中点）对准手里剑柄的中点，剑身顺着手里剑柄的方向（grip_angle）
			w = _bone("weapon", _bones.arm_near_hand, _at("hand", "grip"))
			# 手的横竖缩放不一样时，手里剑柄的斜度也跟着变，剑要顺着缩放后的方向挂
			var a := deg_to_rad(float(rig.parts.hand.grip_angle))
			var k := _s("hand")
			w.rotation = atan2(sin(a) * k.y, cos(a) * k.x)
		else:
			w = _bone("weapon", _bones.arm_near_lo, _at("forearm", "hand"))
		_attach(w, "weapon", "weapon")
	scale = Vector2(rig.scale, rig.scale)


## 换装。outfit 可以是一个目录（整套：目录里有的部件就换，没有的沿用光身版），
## 也可以是 {装备槽: 目录}（混搭：rig.json 的 slots 写每个槽管哪些部件，比如护甲用铁甲、裤子用皮甲）。
## 换装件的画布四周比光身件多留 margin 像素（各目录的 outfit.json），贴图时往左上挪回去。
func set_outfit(outfit) -> void:
	for part in _sprites:
		var dir := _dir_for(part, outfit)
		var path := "%s/%s.png" % [dir, part]
		var m := _margin(dir)
		if not FileAccess.file_exists(path):
			path = "%s/%s.png" % [rig.base_dir, part]
			m = 0.0
		if not _textures.has(path):
			_textures[path] = ImageTexture.create_from_image(Image.load_from_file(path))
		var tex: Texture2D = _textures[path]
		var k := _s(part)
		for s in _sprites[part]:
			s.texture = tex
			s.scale = k
			s.position = (-_v(rig.parts[part].pivot) - Vector2(m, m)) * k
			if s.has_meta("cut"):
				_cut(s, part, tex, m)


func _dir_for(part: String, outfit) -> String:
	if outfit is String:
		return outfit
	for slot in rig.get("slots", {}):
		if part in rig.slots[slot] and outfit.has(slot):
			return outfit[slot]
	return rig.base_dir


static var _margins := {}


func _margin(dir: String) -> float:
	if not _margins.has(dir):
		var f := dir + "/outfit.json"
		_margins[dir] = float(JSON.parse_string(FileAccess.get_file_as_string(f)).margin) if FileAccess.file_exists(f) else 0.0
	return _margins[dir]


## demo.json / 调参面板里写的外观（目录名或 {槽: 目录名}）换成完整路径
static func resolve_outfit(root: String, entry):
	if entry is String:
		return root + entry
	var out := {}
	for slot in entry:
		out[slot] = root + entry[slot]
	return out


## 一件切两截（下摆、前臂）：上半截取到切口往下多 OVERLAP 像素，下半截从切口往上多 OVERLAP 开始，
## 两截叠住不露缝。切口在部件图里的位置是 split（y），转轴的 x 是 split_x（没有就用 pivot 的 x）。
const OVERLAP := 18.0


## 髋关节相对腰带（hips 骨头）的位置：有臀胯就用臀胯图里标的 hip，没有就用躯干的 hip，再没有就在腰带上
func _hip_at() -> Vector2:
	if _has("pelvis") and rig.parts.pelvis.has("hip"):
		return (_v(rig.parts.pelvis.at) - _v(rig.parts.torso.pivot)) * _s("torso") + _at("pelvis", "hip")
	if rig.parts.torso.has("hip"):
		return _at("torso", "hip")
	return Vector2.ZERO


## 前臂只用到手腕：图里原来的拳头已经由 wrist_cut.py 按护腕底边抠掉了，这里不再切图
func _cut_forearm(part: String) -> void:
	if rig.parts[part].has("split") and not rig.parts[part].get("cleaned", false):
		_sprites[part][-1].set_meta("cut", "upper")


func _split_point(part: String) -> Vector2:
	var p: Dictionary = rig.parts[part]
	return (Vector2(p.get("split_x", p.pivot[0]), p.split) - _v(p.pivot)) * _s(part)


func _split(part: String, parent: Node2D, bone: String, slot: String, far: bool) -> void:
	_sprites[part][-1].set_meta("cut", "upper")
	var lo := _bone(bone, parent, _split_point(part))
	_attach(lo, part, slot, far)
	_sprites[part][-1].set_meta("cut", "lower")


func _cut(s: Sprite2D, part: String, tex: Texture2D, m: float) -> void:
	var split: float = rig.parts[part].split + m
	var split_x: float = rig.parts[part].get("split_x", rig.parts[part].pivot[0]) + m
	var size := tex.get_size()
	s.region_enabled = true
	var overlap: float = rig.parts[part].get("overlap", OVERLAP)
	if s.get_meta("cut") == "upper":
		s.region_rect = Rect2(0, 0, size.x, split + overlap)
	else:
		s.region_rect = Rect2(0, split - OVERLAP, size.x, size.y - split + OVERLAP)
		# 下半截的转轴在切口上
		s.position = -Vector2(split_x, OVERLAP) * _s(part)


func play(action: String) -> void:
	if action == _action:
		return
	_from = _last.duplicate()
	_action = action
	_action_t = 0.0


## 一圈步态里每只脚的位置（相对胯，以腿长为单位，y 往上为抬脚）。
## 踩地那段：从胯前 reach 匀速退到胯后 push（身体在往前走）。push 比 reach 大，蹬地的腿伸到身后很远，
## 整个人从脚到头是一条往前斜的线，前倾靠这个，不靠弯腰。
## 抬脚那段按动画里的几个关键位置走：离地 → 脚跟往上踢（kick）→ 从胯下往前摆、膝盖上提（knee）
## → 往前探出去 → 落地。头尾的速度跟踩地时一样，脚落地、离地的那一下不会滑。
func _gait_foot(u: float, g: Dictionary) -> Vector2:
	var reach: float = g.get("reach", g.stride * 0.5)
	var push: float = g.get("push", g.stride * 0.5)
	var duty: float = g.duty
	u = fposmod(u, 1.0)
	if u < duty:
		return Vector2(reach - (reach + push) * u / duty, 0.0)
	var k: float = (u - duty) / (1.0 - duty)
	var kick: float = g.get("kick", g.lift * 0.4)
	var knee: float = g.get("knee", g.lift)
	# 关键点在时间上排匀：脚不会在中段猛甩；最后一点就停在落地点上方，不往前多探（多探再缩回来就是「回弹」）
	var keys := [
		[0.0, Vector2(-push, 0.0)],
		[0.27, Vector2(-push * 0.8, kick)],
		[0.56, Vector2(reach * 0.05 - push * 0.1, knee)],
		[0.83, Vector2(reach * 0.96, knee * 0.3)],
		[1.0, Vector2(reach, 0.0)],
	]
	# 离地时脚跟着地面往后退的速度起步；落地时只带一半，减速着地，不会冲过头再往回拉
	var v_ground := Vector2(-(reach + push) / duty * (1.0 - duty), 0.0)
	for i in range(keys.size() - 1):
		var t0: float = keys[i][0]
		var t1: float = keys[i + 1][0]
		if k <= t1:
			var p0: Vector2 = keys[i][1]
			var p1: Vector2 = keys[i + 1][1]
			var m0: Vector2 = v_ground if i == 0 else (p1 - keys[i - 1][1]) / (t1 - keys[i - 1][0])
			var m1: Vector2 = v_ground * 0.35 if i == keys.size() - 2 else (keys[i + 2][1] - p0) / (keys[i + 2][0] - t0)
			var h := t1 - t0
			var x := (k - t0) / h
			var x2 := x * x
			var x3 := x2 * x
			var pos: Vector2 = p0 * (2 * x3 - 3 * x2 + 1) + m0 * h * (x3 - 2 * x2 + x) + p1 * (-2 * x3 + 3 * x2) + m1 * h * (x3 - x2)
			return Vector2(pos.x, maxf(pos.y, 0.0))
	return keys[-1][1]


## 脚跟抬起的角度（度）。踩地前半段脚放平；过了 heel_from 脚跟慢慢抬起来、前脚掌钉在地上，
## 到离地那一刻抬到 heel（另一条腿这时正往前迈）；离地后在抬脚段的前四成里慢慢放回去，落地时又是平的。
func _gait_heel(u: float, g: Dictionary) -> float:
	var top: float = g.get("heel", 0.0)
	if top <= 0.0:
		return 0.0
	var duty: float = g.duty
	u = fposmod(u, 1.0)
	if u < duty:
		var reach: float = g.get("reach", g.stride * 0.5)
		var push: float = g.get("push", g.stride * 0.5)
		var from: float = g.get("heel_from", reach / (reach + push)) * duty
		if u <= from:
			return 0.0
		# 先慢后快：脚跟刚离地时几乎不动，快蹬出去时翻得最快，离地那一刻停住（跟抬脚段接上）
		return top * smoothstep(from, duty, u)
	var k: float = (u - duty) / (1.0 - duty)
	return top * (1.0 - smoothstep(0.0, 0.4, k))


## 当前步态下地面往后退的速度（屏幕像素/秒），演示里的石缝按这个速度滚，脚就钉在地上
func walk_speed() -> float:
	var g := _run if _action == "run" else _walk
	var stride: float = g.get("reach", g.stride * 0.5) + g.get("push", g.stride * 0.5)
	return stride / (g.duty * g.period) * _leg * scale.x


func _pose_idle(t: float) -> Dictionary:
	var breath := sin(t * TAU / 2.6)
	var sway := sin(t * TAU / 3.7)
	var p := _idle.duplicate()
	p.torso += breath * 1.2
	p.neck -= breath * 1.5
	p.hip += breath * 0.004
	p.dx += sway * 0.012  # 重心在两脚之间慢慢挪
	for k in ["arm_near_up", "arm_far_up"]:
		p[k] += breath * 1.5
	return p


func _pose_gait(t: float, g: Dictionary) -> Dictionary:
	var ph: float = t / float(g.period)
	var fn := _gait_foot(ph, g)
	var ff := _gait_foot(ph + 0.5, g)
	# 支撑脚走到胯正下方时：走路胯最高（腿伸直撑起来），跑步胯最低（落地缓冲），腾空时最高
	var reach: float = g.get("reach", g.stride * 0.5)
	var push: float = g.get("push", g.stride * 0.5)
	var under: float = g.duty * reach / (reach + push)
	var mid := cos(TAU * 2.0 * (ph - under))
	var up := mid if g.duty > 0.5 else -mid
	# 手跟对侧的大腿反着摆。大腿抬得最靠前是在脚往前摆的后段（抬脚那段的七成处），不是脚落地那一刻，
	# 所以按那一刻对齐：近侧大腿最靠前时 swing = 1，远侧手正好在最前、近侧手在最后
	var thigh_peak: float = g.duty + 0.7 * (1.0 - g.duty)
	var swing := cos(TAU * (ph - thigh_peak))
	var p := _idle.duplicate()
	p.merge({
		# 头跟着身子往前探 head 那么多（占前倾的比例），其余由脖子往回收，眼睛还看着前方
		"torso": g.lean + up * 1.5, "neck": g.lean * (g.head - 0.3),
		"hip": g.hip + g.bob * up, "dx": 0.0,
		"foot_near_x": fn.x, "foot_near_y": fn.y, "foot_far_x": ff.x, "foot_far_y": ff.y,
		"foot_near_heel": _gait_heel(ph, g), "foot_far_heel": _gait_heel(ph + 0.5, g),
		# 手跟对侧的腿一起摆：远侧手跟近侧腿同进同退，往前摆时肘多弯一点（pump）。
		# 拿剑的近侧手摆幅按 near_arm 打折，剑尖斜向前下，不平举在身前
		"arm_far_up": 4 + g.arm * swing, "arm_far_lo": g.elbow + g.pump * maxf(0.0, swing),
		"arm_near_up": g.near_up - g.arm * g.near_arm * swing,
		"arm_near_lo": g.near_lo + g.pump * maxf(0.0, -swing), "blade": g.near_blade,
		"drag": g.drag,
	}, true)
	return p


func _pose_attack(t: float) -> Dictionary:
	var idle := _pose_idle(_time)
	idle.step = 0.0
	var keys := []
	for k in _attack:
		var pose := idle.duplicate()
		pose.merge(k[1], true)
		keys.append([k[0], pose])
	var out := idle
	for i in range(keys.size() - 1):
		var a = keys[i]
		var b = keys[i + 1]
		if t <= b[0]:
			var u: float = (t - a[0]) / (b[0] - a[0])
			# 挥下去那两段（起手 → 半路 → 打中）用加速曲线，越砍越快；其余缓入缓出
			u = u * u if i == _strike_from else (1.0 - pow(1.0 - u, 2.0) if i == _strike_from + 1 else smoothstep(0.0, 1.0, u))
			out = {}
			for key in a[1]:
				out[key] = lerpf(a[1][key], b[1][key], u)
			break
	# 后脚钉在原地，前脚按 step 往前迈。step 连着变的几段（上步、收步）合成一整段，只抬一次脚：
	# 原来每段各抬一次，两段交界那一帧脚落回地面又抬起来，膝盖一弯一直，看着就是腿抖一下。
	# 抬脚高度用 sin²，起脚、落脚两头都是平的，不会一帧之内猛抬猛落
	var step: float = out.step
	out.foot_near_x = idle.foot_near_x + step
	out.foot_near_y = 0.0
	var spans := []
	var i0 := -1
	for i in range(keys.size() - 1):
		var moving: bool = absf(keys[i + 1][1].step - keys[i][1].step) > 0.05
		if moving and i0 < 0:
			i0 = i
		if (not moving or i == keys.size() - 2) and i0 >= 0:
			spans.append([keys[i0][0], keys[i if not moving else i + 1][0]])
			i0 = -1
	for sp in spans:
		if t > sp[0] and t < sp[1]:
			out.foot_near_y = 0.07 * pow(sin(PI * (t - sp[0]) / (sp[1] - sp[0])), 2.0)
	out.foot_far_x = idle.foot_far_x
	out.foot_far_y = 0.0
	return out


func _process(delta: float) -> void:
	_time += delta
	_action_t += delta
	if freeze_t >= 0.0 and _action == "attack":
		_action_t = freeze_t
	var pose: Dictionary
	match _action:
		"walk":
			pose = _pose_gait(_action_t, _walk)
		"run":
			pose = _pose_gait(_action_t, _run)
		"attack":
			pose = _pose_attack(_action_t)
		"stand":
			# 笔直站姿：腿伸直、并脚，其余关节归零，只用来跟设定图比比例
			pose = {}
			for k in IDLE:
				pose[k] = 0.0
			pose.hip = 1.0
		_:
			pose = _pose_idle(_time)
	# 换动作后的头 BLEND 秒，从换之前的姿势过渡过来
	if not _from.is_empty() and _action_t < BLEND and _action != "stand":
		var u := smoothstep(0.0, 1.0, _action_t / BLEND)
		for k in pose:
			if _from.has(k):
				pose[k] = lerpf(_from[k], pose[k], u)
	_last = pose.duplicate()
	_apply(pose, delta)
	_update_trail()


## 刀光：攻击挥下去那一段（起手到收势前）记下剑尖最近 TRAIL_TIME 秒的位置，画成从淡到亮的一条弧带
const TRAIL_TIME := 0.1


func _update_trail() -> void:
	if not _bones.has("weapon") or not rig.parts.weapon.has("tip"):
		return
	if _trail == null:
		_trail = Line2D.new()
		_trail.width = 46.0
		_trail.z_index = 40
		_trail.z_as_relative = false
		_trail.joint_mode = Line2D.LINE_JOINT_ROUND
		_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
		var g := Gradient.new()
		g.set_color(0, Color(0.85, 0.9, 1.0, 0.0))
		g.set_color(1, Color(0.95, 0.97, 1.0, 0.75))
		_trail.gradient = g
		var c := Curve.new()
		c.add_point(Vector2(0, 0.15))
		c.add_point(Vector2(1, 1.0))
		_trail.width_curve = c
		add_child(_trail)
	# 只在起手到打中那一段记；打中以后剑停着，刀光在 TRAIL_TIME 里自己淡掉
	var swinging: bool = _action == "attack" and _action_t > 0.3 and _action_t < 0.45 and freeze_t < 0.0
	if swinging:
		var w: Node2D = _bones.weapon
		var tip := (_v(rig.parts.weapon.tip) - _v(rig.parts.weapon.pivot)) * _s("weapon")
		var c := to_local(_bones.arm_near_up.global_position)
		_tips.append([_time, to_local(w.to_global(tip)), c])
	while not _tips.is_empty() and _time - _tips[0][0] > TRAIL_TIME:
		_tips.pop_front()
	# 两帧之间剑尖走的是以肩膀为圆心的一段弧；按角度和半径插值补点，刀光才是圆的，不是折线
	var pts := PackedVector2Array()
	for i in _tips.size():
		if i == 0:
			pts.append(_tips[0][1])
			continue
		var a: Array = _tips[i - 1]
		var b: Array = _tips[i]
		var va: Vector2 = a[1] - a[2]
		var vb: Vector2 = b[1] - b[2]
		var da := wrapf(vb.angle() - va.angle(), -PI, PI)
		for k in range(1, 9):
			var u := k / 8.0
			var center: Vector2 = a[2].lerp(b[2], u)
			var r := lerpf(va.length(), vb.length(), u)
			pts.append(center + Vector2.from_angle(va.angle() + da * u) * r)
	_trail.points = pts


func _follow(key: String, target: float, dt: float) -> float:
	if _action == "stand":
		return target
	if not _spring.has(key):
		_spring[key] = [target, 0.0]
	var st: Array = _spring[key]
	# 角度按最短方向追：IK 算出来的角度会跨 ±180°（比如 179° 下一帧变 -179°，其实只差 2°），
	# 不这样处理，弹簧会以为要转一大圈，小腿就跟着转圈
	if key.begins_with("leg_"):
		target = st[0] + wrapf(target - st[0], -180.0, 180.0)
	var k: float = SPRINGS[key][0]
	var c: float = 2.0 * sqrt(k) * SPRINGS[key][1]
	# 半隐式欧拉，每帧分几小步算，帧率低也不会炸
	var n := 4
	var h := dt / n
	for i in n:
		st[1] += (k * (target - st[0]) - c * st[1]) * h
		st[0] += st[1] * h
	return st[0]


## 两节骨头的 IK：胯在 hip、脚底要踩到 target，膝盖朝前弯。返回 [大腿转角, 小腿转角]（弧度，小腿相对大腿）。
## heel：脚跟抬起的角度（弧度），脚绕前脚掌（boot 的 ball）转，脚踝跟着往上、往前抬，前脚掌不动。
func _leg_ik(hip: Vector2, target: Vector2, heel := 0.0) -> Array:
	var v1 := _at("thigh", "end")
	var v2 := _at("shin", "sole")
	# 脚踝分开时对准脚踝：脚放平后，脚踝在脚底正上方（脚底 → 脚踝那段，按脚的缩放）
	if _bones.has("foot_near") and rig.parts.shin.has("ankle"):
		var fs: float = rig.parts.boot.get("foot_scale", 1.0)
		var ankle := _at("shin", "ankle")
		var ball := _at("boot", "ball") if rig.parts.boot.has("ball") else _at("shin", "sole")
		# 前脚掌在脚底点前面多远（脚绕脚踝缩放，所以前脚掌到脚踝那段也乘 fs）
		var ball_at := target + (ball - _at("shin", "sole")) * fs
		target = ball_at + ((ankle - ball) * fs).rotated(heel)
		v2 = ankle
	var l1 := v1.length()
	var l2 := v2.length()
	var to := target - hip
	# 软 IK：腿快伸直时，脚的位置稍微一变，算出来的膝盖角度就会剧烈跳（啪地绷直、下一帧又弯回去）。
	# 距离超过腿长的 (1 - SOFT_IK) 以后按指数慢慢逼近腿长，膝盖永远留一点弯，变化是平滑的
	var full := l1 + l2
	var d := to.length()
	var knee_start := full * (1.0 - _soft)
	if _soft > 0.001 and d > knee_start:
		d = knee_start + full * _soft * (1.0 - exp(-(d - knee_start) / (full * _soft)))
	d = clampf(d, absf(l1 - l2) + 1.0, full - 0.01)
	var a := acos(clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0))
	var thigh_dir := to.angle() - a  # 往前（画面 +x）那边偏，膝盖就朝前
	var knee := hip + Vector2.from_angle(thigh_dir) * l1
	var shin_dir := (target - knee).angle()
	var r1 := thigh_dir - v1.angle()
	var r2 := shin_dir - v2.angle() - r1
	return [r1, r2]


func _apply(pose: Dictionary, dt: float) -> void:
	# 软 IK 只给走、跑用，换动作时慢慢过渡，不突变
	var want_soft := SOFT_IK if _action in ["walk", "run"] else 0.0
	_soft = move_toward(_soft, want_soft, dt * 0.4)
	# 画面坐标里顺时针为正：前摆＝逆时针，所以手的「往前」取负。
	# tilt 是躯干、头的「站姿底子」：躯干往后立、头往后仰几度，纠正图本身的驼背和探颈
	var torso_tilt: float = rig.parts.torso.get("tilt", 0.0)
	var head_tilt: float = rig.parts.head.get("tilt", 0.0)
	_bones.torso.rotation_degrees = pose.torso + torso_tilt
	# 头往回转抵消一半上身前倾（不是全抵消）：劈砍、跑步时头跟着身子压一点，脖子也不会转得太狠
	_bones.neck.rotation_degrees = _follow("neck", pose.neck - pose.torso * 0.5, dt) + head_tilt
	for side in ["near", "far"]:
		var up_key := "arm_%s_up" % side
		var lo_key := "arm_%s_lo" % side
		var up: float = pose[up_key]
		if SPRINGS.has(up_key):
			up = _follow(up_key, up, dt)
		# 手臂挂在躯干上，先抵消躯干的前倾，让「往前摆」按画面算
		_bones[up_key].rotation_degrees = -up - pose.torso - torso_tilt
		_bones[lo_key].rotation_degrees = -_follow(lo_key, pose[lo_key], dt)
	# 腿：胯的位置 + 两只脚的落点 → IK
	# hip 是髋关节离地的高度（腿长为单位）；腰带（hips 骨头）在髋关节上面 hip_at 那么高
	var hip_at := _hip_at()
	var hips := Vector2(pose.dx * _leg, -pose.hip * _leg) - hip_at
	_bones.hips.position = hips
	var thigh_fwd := []
	for side in ["near", "far"]:
		var off := FAR_SHIFT if side == "far" else Vector2.ZERO
		var foot := Vector2(pose["foot_%s_x" % side] * _leg, -pose["foot_%s_y" % side] * _leg) + Vector2(off.x, 0)
		var heel := deg_to_rad(pose.get("foot_%s_heel" % side, 0.0))
		var r: Array = _leg_ik(hips + hip_at + off, foot, heel)
		r[0] = deg_to_rad(_follow("leg_%s_up" % side, rad_to_deg(r[0]), dt))
		r[1] = deg_to_rad(_follow("leg_%s_lo" % side, rad_to_deg(r[1]), dt))
		_bones["leg_%s_up" % side].rotation = r[0]
		_bones["leg_%s_lo" % side].rotation = r[1]
		# 脚：踩在地上时整只脚放平（抵消大腿加小腿的转角）再按 heel 踮起脚跟，抬起来时跟着小腿自然垂；按抬脚高度过渡
		if _bones.has("foot_" + side):
			var flat := 1.0 - clampf(pose["foot_%s_y" % side] / 0.04, 0.0, 1.0)
			_bones["foot_" + side].rotation = (heel - (r[0] + r[1])) * flat
		thigh_fwd.append(-rad_to_deg(r[0]))  # 大腿往前抬为正
	# 下摆：上半截至少跟大腿转得一样多，大腿往前抬就被顶起来、往后蹬就被带起来，腿不会从布里戳出来；
	# 没被顶的时候往下垂，跑起来被风往后带（drag）。下半截挂在上半截底边，用软弹簧往「竖直 + drag」追，
	# 膝盖抬起时布就搭在膝盖上垂下去，停下来还会晃两下。
	# 臀胯跟着躯干前倾转三分之一，腰那里不至于折得太死
	if _bones.has("pelvis"):
		# 臀胯跟着躯干前倾转三分之一；再跟着两条大腿的平均方向前后倾一点（迈步时骨盆会前后翻）
		_bones.pelvis.rotation_degrees = pose.torso * 0.35 - (thigh_fwd[0] + thigh_fwd[1]) * 0.12
	# 裤裆跟着两条大腿的平均方向转一半
	if _bones.has("crotch"):
		_bones.crotch.rotation_degrees = -(thigh_fwd[0] + thigh_fwd[1]) * 0.25
	var fwd: float = maxf(0.0, thigh_fwd.max())
	var back: float = minf(0.0, thigh_fwd.min())
	var drag: float = pose.get("drag", 0.0)
	var flaps := {"skirt_front": minf(drag, -fwd - 4.0), "skirt_back": maxf(drag, -back + 4.0)}
	for flap in flaps:
		if not _bones.has(flap):
			continue
		var upper := _follow(flap, flaps[flap], dt)
		_bones[flap].rotation_degrees = upper
		if _bones.has(flap + "_lo"):
			# 下半截想竖直往下垂（再加上风），但不能比上半截往里收（前片不往后折进腿里、后片不往前折）
			var want := drag * 1.4
			want = maxf(want, upper - 35.0) if flap == "skirt_front" else minf(want, upper + 35.0)
			if flap == "skirt_front":
				want = minf(want, upper + 25.0)
			else:
				want = maxf(want, upper - 25.0)
			_bones[flap + "_lo"].rotation_degrees = _follow(flap + "_lo", want, dt) - upper
	if _bones.has("weapon"):
		var blade := _follow("blade", pose.get("blade", 0.0), dt)
		if _bones.has("arm_near_hand"):
			# 手腕只小幅转（±15°），剑的方向主要由手里画好的剑柄决定，转大了手腕会折
			# 平时手腕只小幅转（±15°）；劈砍时手腕往下压得多（attack_wrist），剑才劈得下来
			var lim: float = rig.get("attack_wrist", 15.0) if _action == "attack" else 15.0
			_bones.arm_near_hand.rotation_degrees = clampf(blade, -lim, lim)
		else:
			_bones.weapon.rotation_degrees = blade
		# 比比例时不拿剑，剑横在腿前会挡住腿的轮廓
		_bones.weapon.visible = _action != "stand"
