extends RefCounted

# 角色动作表。
#
# frame 轨给出每个动作的分解姿态，位移、残影与尘土走独立曲线。
# 侧视战场用 SideArt 绘出每格像素精灵，Rig 也可以使用这些曲线为画面挂接装备特效。
#
# 约定：
# - phase 为 0~1 的动作进度，连续动作（待机、走位）用 clock 秒数。
# - shift / bend 单位是角色本地像素，+x 朝角色面向，+y 向下。
# - bend 是上半身相对脚底的水平偏移，渲染层按高度加权，等于一个腰部的弯折。

# 动作名对应角色精灵的分解姿态。
const READY := &"ready"
const STRIKE := &"strike"
const WINDUP := &"windup"
const RECOVER := &"recover"
const FOLLOW := &"follow"
const CAST := &"cast"
const GUARD := &"guard"
const DODGE := &"dodge"
const HURT := &"hurt"

# 兵器甩在身前的那几格，特效挂点要往前移。
const EXTENDED := [STRIKE, FOLLOW, CAST]

static func is_striking(frame: StringName) -> bool:
	return EXTENDED.has(frame)

# 一次动作的默认姿态。渲染层只读这些键。
const REST := {
	"frame": READY, "shift": Vector2.ZERO, "scale": Vector2.ONE, "bend": 0.0, "tilt": 0.0,
	"pivot": 0.5, "ghost": 0.0, "flash": 0.0, "dust": 0.0, "fade": 1.0, "charge": 0.0
}

# 动作曲线。键为 [进度, 取值] 的升序数组，线性插值；frame 轨用阶梯采样。
const CLIPS := {
	# 剑：沉肩蓄力 → 前踏劈出 → 收招回位
	&"attack_sword": {
		"frame": [[0.0, READY], [0.16, WINDUP], [0.30, STRIKE], [0.60, FOLLOW], [0.80, RECOVER], [0.94, READY]],
		"shift_x": [[0.0, 0.0], [0.24, -8.0], [0.38, 15.0], [0.62, 9.0], [1.0, 0.0]],
		"shift_y": [[0.0, 0.0], [0.24, 2.0], [0.38, -3.0], [1.0, 0.0]],
		"bend": [[0.0, 0.0], [0.24, -7.0], [0.40, 11.0], [0.70, 4.0], [1.0, 0.0]],
		"tilt": [[0.0, 0.0], [0.24, -0.05], [0.40, 0.07], [1.0, 0.0]],
		"scale_y": [[0.0, 1.0], [0.24, 0.96], [0.40, 1.04], [0.70, 0.99], [1.0, 1.0]],
		"ghost": [[0.0, 0.0], [0.30, 0.0], [0.42, 0.85], [0.72, 0.0]],
		"dust": [[0.0, 0.0], [0.34, 0.0], [0.40, 1.0], [0.58, 0.0]]
	},
	# 破阵：沉身聚气后整个人撞出去
	&"skill": {
		"frame": [[0.0, READY], [0.14, WINDUP], [0.24, STRIKE], [0.56, FOLLOW], [0.86, RECOVER], [0.97, READY]],
		"shift_x": [[0.0, 0.0], [0.20, -13.0], [0.40, 22.0], [0.70, 11.0], [1.0, 0.0]],
		"shift_y": [[0.0, 0.0], [0.20, 5.0], [0.38, -7.0], [0.60, 0.0], [1.0, 0.0]],
		"bend": [[0.0, 0.0], [0.20, -12.0], [0.40, 16.0], [0.74, 4.0], [1.0, 0.0]],
		"tilt": [[0.0, 0.0], [0.20, -0.09], [0.40, 0.11], [1.0, 0.0]],
		"scale_y": [[0.0, 1.0], [0.20, 0.90], [0.38, 1.10], [0.62, 0.98], [1.0, 1.0]],
		"scale_x": [[0.0, 1.0], [0.20, 1.07], [0.38, 0.95], [1.0, 1.0]],
		"ghost": [[0.0, 0.0], [0.22, 0.3], [0.40, 1.0], [0.80, 0.0]],
		"dust": [[0.0, 0.0], [0.22, 0.6], [0.40, 1.8], [0.70, 0.0]],
		"charge": [[0.0, 0.0], [0.20, 1.0], [0.36, 0.3], [0.60, 0.0]]
	},
	# 震慑：拔身跃起再砸落，落地一次重压
	&"tactic": {
		"frame": [[0.0, READY], [0.18, WINDUP], [0.30, STRIKE], [0.60, FOLLOW], [0.84, RECOVER], [0.96, READY]],
		"shift_x": [[0.0, 0.0], [0.26, -6.0], [0.46, 12.0], [1.0, 0.0]],
		"shift_y": [[0.0, 0.0], [0.26, -14.0], [0.44, 4.0], [0.60, 0.0], [1.0, 0.0]],
		"bend": [[0.0, 0.0], [0.26, -8.0], [0.46, 12.0], [1.0, 0.0]],
		"scale_y": [[0.0, 1.0], [0.26, 1.08], [0.44, 0.84], [0.56, 1.04], [1.0, 1.0]],
		"scale_x": [[0.0, 1.0], [0.26, 0.95], [0.44, 1.14], [0.56, 0.98], [1.0, 1.0]],
		"ghost": [[0.0, 0.0], [0.30, 0.6], [0.60, 0.0]],
		"dust": [[0.0, 0.0], [0.40, 0.0], [0.47, 2.2], [0.78, 0.0]]
	},
	# 后撤：屈膝、蹬地、滑出去，拖三道残影
	&"retreat": {
		"frame": [[0.0, GUARD], [0.18, DODGE], [0.86, GUARD]],
		"shift_x": [[0.0, 0.0], [0.18, 5.0], [0.55, -26.0], [1.0, -16.0]],
		"shift_y": [[0.0, 0.0], [0.18, 4.0], [0.50, -6.0], [1.0, 0.0]],
		"bend": [[0.0, 0.0], [0.18, 8.0], [0.55, -12.0], [1.0, -4.0]],
		"tilt": [[0.0, 0.0], [0.20, 0.07], [0.60, -0.13], [1.0, -0.04]],
		"scale_y": [[0.0, 1.0], [0.18, 0.88], [0.48, 1.06], [1.0, 1.0]],
		"scale_x": [[0.0, 1.0], [0.18, 1.10], [0.48, 0.96], [1.0, 1.0]],
		"ghost": [[0.0, 0.0], [0.20, 1.0], [0.90, 0.3], [1.0, 0.0]],
		"dust": [[0.0, 0.0], [0.16, 2.0], [0.46, 0.4], [1.0, 0.0]]
	},
	# 受击：腰部先折，再弹回站姿
	&"hurt": {
		"frame": [[0.0, HURT], [0.72, READY]],
		"shift_x": [[0.0, 0.0], [0.22, -9.0], [0.60, 2.0], [1.0, 0.0]],
		"bend": [[0.0, 0.0], [0.20, -14.0], [0.55, 4.0], [1.0, 0.0]],
		"tilt": [[0.0, 0.0], [0.20, -0.11], [0.58, 0.03], [1.0, 0.0]],
		"scale_y": [[0.0, 1.0], [0.22, 0.93], [0.58, 1.02], [1.0, 1.0]],
		"flash": [[0.0, 1.0], [0.42, 0.0]],
		"dust": [[0.0, 0.5], [0.30, 0.0]]
	},
	# 原地复活：从矮处撑起来
	&"revive": {
		"frame": [[0.0, READY]],
		"shift_y": [[0.0, 10.0], [0.55, -3.0], [1.0, 0.0]],
		"bend": [[0.0, 10.0], [0.50, -4.0], [1.0, 0.0]],
		"scale_y": [[0.0, 0.76], [0.55, 1.06], [1.0, 1.0]],
		"scale_x": [[0.0, 1.14], [0.55, 0.97], [1.0, 1.0]],
		"fade": [[0.0, 0.25], [0.45, 1.0]],
		"flash": [[0.0, 0.8], [0.5, 0.0]],
		"dust": [[0.0, 1.4], [0.40, 0.0]]
	}
}

# 挂机时自动走位用的脚步循环，stride 由战斗推进。
static func walk(stride: float) -> Dictionary:
	var pose := REST.duplicate()
	var cycle := stride * 0.85
	pose.shift = Vector2(sin(cycle) * 1.6, -absf(sin(cycle)) * 3.6)
	pose.bend = 3.4 + sin(cycle) * 2.2
	pose.tilt = 0.025 + sin(cycle * 2.0) * 0.018
	pose.scale = Vector2(1.0 + absf(cos(cycle)) * 0.015, 1.0 - absf(cos(cycle)) * 0.03)
	pose.dust = 0.9 if sin(cycle) > 0.93 else 0.0
	return pose

# 站定时的吐纳：衣摆与肩线缓慢起伏，避免角色像贴图一样钉在地上。
static func idle(clock: float) -> Dictionary:
	var pose := REST.duplicate()
	var breath := sin(clock * 1.75)
	pose.shift = Vector2(0.0, -breath * 1.1 - 0.4)
	pose.bend = sin(clock * 0.9) * 1.8
	pose.tilt = sin(clock * 0.62) * 0.012
	pose.scale = Vector2(1.0 - breath * 0.006, 1.0 + breath * 0.012)
	return pose

# 每刀的剪影从判定帧开始，下一刀来之前收回握柄。
static func flurry(phase: float, cues: Array) -> Dictionary:
	var pose := REST.duplicate()
	pose.frame = WINDUP
	for index in range(cues.size() - 1, -1, -1):
		var cue: float = cues[index]
		if phase < cue:
			continue
		var final := index == cues.size() - 1
		var end := 1.0 if final else float(cues[index + 1])
		var beat := clampf((phase - cue) / (end - cue), 0.0, 1.0)
		pose.frame = (RECOVER if final else WINDUP) if beat > 0.72 else (STRIKE if index % 2 == 0 or final else FOLLOW)
		pose.shift = Vector2(26.0 if final else 17.0, -5.0 + float(index % 2) * 8.0) * (1.0 - beat)
		pose.ghost = (1.2 if final else 0.82) * (1.0 - beat)
		pose.dust = (1.1 if final else 0.48) * (1.0 - beat)
		break
	return pose

# 取某个动作在 phase 处的姿态；没有这条曲线就退回站姿默认值。
static func sample(clip_name: StringName, phase: float) -> Dictionary:
	var pose := REST.duplicate()
	if not CLIPS.has(clip_name):
		return pose
	var clip: Dictionary = CLIPS[clip_name]
	var t := clampf(phase, 0.0, 1.0)
	pose.frame = _stage(clip.get("frame", []), t)
	pose.shift = Vector2(_curve(clip.get("shift_x", []), t, 0.0), _curve(clip.get("shift_y", []), t, 0.0))
	pose.scale = Vector2(_curve(clip.get("scale_x", []), t, 1.0), _curve(clip.get("scale_y", []), t, 1.0))
	pose.bend = _curve(clip.get("bend", []), t, 0.0)
	pose.tilt = _curve(clip.get("tilt", []), t, 0.0)
	pose.ghost = _curve(clip.get("ghost", []), t, 0.0)
	pose.flash = _curve(clip.get("flash", []), t, 0.0)
	pose.dust = _curve(clip.get("dust", []), t, 0.0)
	pose.fade = _curve(clip.get("fade", []), t, 1.0)
	pose.charge = _curve(clip.get("charge", []), t, 0.0)
	return pose

# 把两个姿态按权重混合，用于动作衔接与叠加走位。
static func blend(base: Dictionary, over: Dictionary, weight: float) -> Dictionary:
	var w := clampf(weight, 0.0, 1.0)
	if w <= 0.0:
		return base
	var mixed := over.duplicate()
	mixed.shift = Vector2(base.shift).lerp(over.shift, w)
	mixed.scale = Vector2(base.scale).lerp(over.scale, w)
	mixed.bend = lerpf(base.bend, over.bend, w)
	mixed.tilt = lerpf(base.tilt, over.tilt, w)
	mixed.ghost = lerpf(base.ghost, over.ghost, w)
	mixed.flash = lerpf(base.flash, over.flash, w)
	mixed.dust = maxf(base.dust, over.dust)
	mixed.fade = lerpf(base.fade, over.fade, w)
	mixed.charge = lerpf(base.charge, over.charge, w)
	return mixed

# 普攻按兵器形制挑曲线，其余动作共用一条。
static func clip_for(motion: StringName, weapon_form: String) -> StringName:
	if motion == &"attack":
		var named := StringName("attack_" + weapon_form)
		return named if CLIPS.has(named) else &"attack_sword"
	return motion

static func _curve(keys: Array, t: float, fallback: float) -> float:
	if keys.is_empty():
		return fallback
	if t <= float(keys[0][0]):
		return float(keys[0][1])
	for i in range(1, keys.size()):
		var key: Array = keys[i]
		if t > float(key[0]):
			continue
		var previous: Array = keys[i - 1]
		var span := float(key[0]) - float(previous[0])
		if span <= 0.0:
			return float(key[1])
		var ratio := (t - float(previous[0])) / span
		# 平滑步进，避免关键帧之间出现折线式的机械感
		return lerpf(float(previous[1]), float(key[1]), ratio * ratio * (3.0 - 2.0 * ratio))
	return float(keys[keys.size() - 1][1])

static func _stage(keys: Array, t: float) -> StringName:
	var current := READY
	for key in keys:
		if t >= float(key[0]):
			current = key[1]
	return current
