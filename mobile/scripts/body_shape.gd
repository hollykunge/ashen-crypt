extends RefCounted
## 主角体型：模型加载时把身体和所有衣服的顶点一起按同一个形变场推一遍（绑定姿势、骨架空间里算），
## 衣服和身体推得一样多，不会穿模；骨骼不动，所以动作、握兵器、出手点都不受影响。
## 男主角：胳膊、肩头、胸、脖子、大腿加粗，魁梧些；女主角：胸、臀加圆，胯稍宽，腰收一点。
## 坐标：Y 朝上，角色朝 +Z，左手在 +X；绑定姿势是 T 字（两臂沿 X 平伸）。
##
## 脸：原模型是西方人脸（鼻梁高、眉骨突、眼窝深），这里压低鼻梁鼻尖、削平眉骨、填浅眼窝、颧骨略往外，
## 眉毛外梢往上挑成剑眉；女主角下颌收窄成瓜子脸；男主角的络腮胡把两腮的收进皮肤底下，只留下巴一撮和八字须。
## 坐标按量出来的五官位置定（男：两眼 y 1.698、z 0.070，鼻尖 y 1.657、z 0.115；女：两眼 y 1.656、z 0.063，鼻尖 y 1.617、z 0.112）
##
## 两种形变：
##   capsule：以线段 a→b 为轴，半径 r 以内的点沿离轴方向放大 s 倍（截面变粗）。轴两头 fade 米内渐弱
##   squash：c、radii 椭球里的点往 a→b 那条线上下压扁 s（细眉）
##   blob：以 c 为中心、半轴 radii 的椭球内，点朝 dir 推，最多推 dir 的长度（米），越靠中心推得越多

const SHAPES := {
	"male": [
		# —— 脸 ——
		# 眉骨削平、往后收
		{"type": "blob", "c": Vector3(0.03, 1.716, 0.092), "radii": Vector3(0.04, 0.02, 0.03), "dir": Vector3(0.0, -0.001, -0.008)},
		# 眼窝填浅（眼珠、眼皮一起往前一点）
		{"type": "blob", "c": Vector3(0.034, 1.698, 0.07), "radii": Vector3(0.03, 0.02, 0.03), "dir": Vector3(0.0, 0.0, 0.003)},
		# 颧骨往外、往前
		{"type": "blob", "c": Vector3(0.056, 1.672, 0.062), "radii": Vector3(0.03, 0.03, 0.04), "dir": Vector3(0.006, 0.001, 0.004)},
		# 剑眉：眉梢往上挑，眉头略压
		{"type": "blob", "c": Vector3(0.06, 1.708, 0.06), "radii": Vector3(0.03, 0.03, 0.05), "dir": Vector3(0.0, 0.006, 0.0), "parts": ["Head_Eyebrows"]},
		{"type": "blob", "c": Vector3(0.012, 1.712, 0.09), "radii": Vector3(0.02, 0.02, 0.04), "dir": Vector3(0.0, -0.002, 0.0), "parts": ["Head_Eyebrows"]},
		# 络腮胡：两腮、鬓角、下颌两侧收进皮肤底下，只留下巴和八字须
		{"type": "blob", "c": Vector3(0.07, 1.64, 0.01), "radii": Vector3(0.045, 0.08, 0.09), "toward": Vector3(0.0, 1.64, -0.02), "amount": 0.022, "parts": ["Head_Hair_Beard"]},
		{"type": "blob", "c": Vector3(0.055, 1.585, 0.03), "radii": Vector3(0.035, 0.045, 0.07), "toward": Vector3(0.0, 1.61, -0.02), "amount": 0.02, "parts": ["Head_Hair_Beard"]},
		# 上臂、前臂（左右对称，生成时镜像 X）
		{"type": "capsule", "a": Vector3(0.17, 1.455, -0.065), "b": Vector3(0.45, 1.455, -0.07), "r": 0.14, "s": 0.42, "fade": 0.05},
		{"type": "capsule", "a": Vector3(0.45, 1.455, -0.07), "b": Vector3(0.66, 1.455, -0.065), "r": 0.12, "s": 0.22, "fade": 0.05},
		# 三角肌：肩头往外、往上鼓
		{"type": "blob", "c": Vector3(0.20, 1.47, -0.06), "radii": Vector3(0.11, 0.11, 0.12), "dir": Vector3(0.035, 0.03, 0.0)},
		# 斜方肌：脖子两侧往上隆
		{"type": "blob", "c": Vector3(0.09, 1.50, -0.06), "radii": Vector3(0.10, 0.08, 0.09), "dir": Vector3(0.01, 0.03, 0.0)},
		# 胸大肌：往前挺
		{"type": "blob", "c": Vector3(0.085, 1.34, 0.10), "radii": Vector3(0.12, 0.11, 0.13), "dir": Vector3(0.012, 0.006, 0.045)},
		# 背阔：背后两侧往外
		{"type": "blob", "c": Vector3(0.14, 1.27, -0.09), "radii": Vector3(0.11, 0.15, 0.11), "dir": Vector3(0.035, 0.0, -0.015)},
		# 大腿
		{"type": "capsule", "a": Vector3(0.09, 0.92, -0.036), "b": Vector3(0.09, 0.56, -0.036), "r": 0.15, "s": 0.16, "fade": 0.08},
		# 小腿肚
		{"type": "blob", "c": Vector3(0.09, 0.38, -0.08), "radii": Vector3(0.07, 0.12, 0.08), "dir": Vector3(0.0, 0.0, -0.015)},
	],
	"male_center": [
		# 鼻子：鼻尖、鼻梁往回收
		{"type": "blob", "c": Vector3(0.0, 1.665, 0.103), "radii": Vector3(0.03, 0.045, 0.04), "dir": Vector3(0.0, 0.0, -0.014)},
		{"type": "blob", "c": Vector3(0.0, 1.695, 0.09), "radii": Vector3(0.02, 0.03, 0.03), "dir": Vector3(0.0, 0.0, -0.006)},
		# 眉心
		{"type": "blob", "c": Vector3(0.0, 1.713, 0.095), "radii": Vector3(0.02, 0.02, 0.03), "dir": Vector3(0.0, 0.0, -0.005)},
		# 脖子
		{"type": "capsule", "a": Vector3(0.0, 1.47, -0.03), "b": Vector3(0.0, 1.60, -0.02), "r": 0.09, "s": 0.22, "fade": 0.03, "max_y": 1.585},
		# 胸腔整体厚实一些（截面放大），不碰平伸的胳膊
		{"type": "capsule", "a": Vector3(0.0, 1.08, -0.02), "b": Vector3(0.0, 1.40, -0.01), "r": 0.21, "s": 0.08, "fade": 0.07},
	],
	"female": [
		# —— 脸：照仙侠美人的样子，鹅蛋脸、小鼻子、小嘴、细眉 ——
		# 眉骨削平
		{"type": "blob", "c": Vector3(0.03, 1.674, 0.088), "radii": Vector3(0.04, 0.02, 0.03), "dir": Vector3(0.0, -0.001, -0.007)},
		# 眼窝填浅
		{"type": "blob", "c": Vector3(0.0345, 1.656, 0.063), "radii": Vector3(0.03, 0.02, 0.03), "dir": Vector3(0.0, 0.0, 0.003)},
		# 苹果肌略饱满（往前，不往外，脸不显宽）
		{"type": "blob", "c": Vector3(0.042, 1.628, 0.07), "radii": Vector3(0.028, 0.025, 0.035), "dir": Vector3(0.0, 0.0, 0.004)},
		# 颧骨两侧往里收一点
		{"type": "blob", "c": Vector3(0.068, 1.635, 0.03), "radii": Vector3(0.03, 0.035, 0.05), "dir": Vector3(-0.004, 0.0, 0.0)},
		# 眉梢上挑
		{"type": "blob", "c": Vector3(0.06, 1.666, 0.054), "radii": Vector3(0.03, 0.03, 0.05), "dir": Vector3(0.0, 0.004, 0.0), "parts": ["Head_Eyebrows"]},
		# 细眉：沿眉线上下压扁（只压眉毛，眼线在下面不动）
		{"type": "squash", "a": Vector3(0.008, 1.672, 0.0), "b": Vector3(0.045, 1.681, 0.0), "c": Vector3(0.027, 1.677, 0.075), "radii": Vector3(0.028, 0.016, 0.06), "s": 0.4, "min_y": 1.665, "parts": ["Head_Eyebrows"]},
		{"type": "squash", "a": Vector3(0.045, 1.681, 0.0), "b": Vector3(0.066, 1.675, 0.0), "c": Vector3(0.055, 1.679, 0.06), "radii": Vector3(0.022, 0.016, 0.06), "s": 0.4, "min_y": 1.665, "parts": ["Head_Eyebrows"]},
		# 鼻翼收窄
		{"type": "blob", "c": Vector3(0.014, 1.612, 0.095), "radii": Vector3(0.014, 0.014, 0.02), "dir": Vector3(-0.003, 0.0, 0.0)},
		# 小嘴：嘴角往里
		{"type": "blob", "c": Vector3(0.023, 1.584, 0.083), "radii": Vector3(0.014, 0.012, 0.02), "dir": Vector3(-0.0035, 0.0, 0.0)},
		# 鹅蛋脸：下颌角往里、往上收
		{"type": "blob", "c": Vector3(0.062, 1.56, 0.0), "radii": Vector3(0.045, 0.05, 0.08), "dir": Vector3(-0.013, 0.003, 0.0)},
		{"type": "blob", "c": Vector3(0.04, 1.545, 0.05), "radii": Vector3(0.03, 0.03, 0.04), "dir": Vector3(-0.006, 0.0, 0.0)},
		# —— 身材：细颈削肩纤臂，丰胸细腰宽胯 ——
		# 上臂、前臂纤细
		{"type": "capsule", "a": Vector3(0.17, 1.418, -0.054), "b": Vector3(0.39, 1.418, -0.059), "r": 0.11, "s": -0.12, "fade": 0.05},
		{"type": "capsule", "a": Vector3(0.39, 1.418, -0.059), "b": Vector3(0.62, 1.418, -0.052), "r": 0.09, "s": -0.1, "fade": 0.05},
		# 削肩：肩头往下、往里一点
		{"type": "blob", "c": Vector3(0.15, 1.44, -0.05), "radii": Vector3(0.07, 0.06, 0.09), "dir": Vector3(-0.006, -0.008, 0.0)},
		# 胸：往前鼓、略往上提
		{"type": "blob", "c": Vector3(0.075, 1.285, 0.075), "radii": Vector3(0.095, 0.095, 0.12), "dir": Vector3(0.01, 0.002, 0.066)},
		# 臀：往后、略往上翘
		{"type": "blob", "c": Vector3(0.075, 0.89, -0.11), "radii": Vector3(0.10, 0.12, 0.12), "dir": Vector3(0.008, 0.012, -0.055)},
		# 胯：两侧往外
		{"type": "blob", "c": Vector3(0.15, 0.92, -0.04), "radii": Vector3(0.08, 0.13, 0.12), "dir": Vector3(0.032, 0.0, 0.0)},
		# 大腿根略丰满
		{"type": "capsule", "a": Vector3(0.11, 0.90, -0.05), "b": Vector3(0.11, 0.66, -0.045), "r": 0.13, "s": 0.06, "fade": 0.08},
	],
	"female_center": [
		# 鼻尖、鼻梁往回收，鼻子小巧
		{"type": "blob", "c": Vector3(0.0, 1.622, 0.1), "radii": Vector3(0.028, 0.045, 0.04), "dir": Vector3(0.0, -0.001, -0.014)},
		{"type": "blob", "c": Vector3(0.0, 1.653, 0.085), "radii": Vector3(0.02, 0.03, 0.03), "dir": Vector3(0.0, 0.0, -0.005)},
		{"type": "blob", "c": Vector3(0.0, 1.671, 0.09), "radii": Vector3(0.02, 0.02, 0.03), "dir": Vector3(0.0, 0.0, -0.004)},
		# 下巴略尖、往前
		{"type": "blob", "c": Vector3(0.0, 1.535, 0.07), "radii": Vector3(0.025, 0.025, 0.04), "dir": Vector3(0.0, -0.003, 0.003)},
		# 细颈
		{"type": "capsule", "a": Vector3(0.0, 1.43, -0.03), "b": Vector3(0.0, 1.55, -0.02), "r": 0.075, "s": -0.12, "fade": 0.03, "max_y": 1.535},
		# 收腰：腰两侧往里
		{"type": "capsule", "a": Vector3(0.0, 1.04, -0.03), "b": Vector3(0.0, 1.20, -0.02), "r": 0.20, "s": -0.13, "fade": 0.06},
	],
}

static var _cache := {}
## 关掉就原样返回（对比用）
static var enabled := true


## 返回推过形的网格（按性别和部件名缓存，同一个部件只算一次）
static func shaped(gender: String, part: String, mesh: Mesh) -> Mesh:
	if not enabled:
		return mesh
	var key := gender + "/" + part
	if _cache.has(key):
		return _cache[key]
	# 只留影响范围和这个部件挨得上的那几项，靴子、头发之类基本一项都不用算
	var box := mesh.get_aabb()
	var ops := _ops(gender).filter(func(op: Dictionary) -> bool:
		return _reach(op).intersects(box) and (not op.has("parts") or part in op.parts))
	if ops.is_empty():
		_cache[key] = mesh
		return mesh
	var out := ArrayMesh.new()
	out.resource_name = mesh.resource_name
	for i in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(i)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for v in verts.size():
			verts[v] = deform(verts[v], ops)
		arrays[Mesh.ARRAY_VERTEX] = verts
		# 头部带自定义通道（CUSTOM0/1），重建时要带上它们的格式位，不然整个面丢掉
		var keep := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		for c in 4:
			keep |= Mesh.ARRAY_FORMAT_CUSTOM_MASK << (Mesh.ARRAY_FORMAT_CUSTOM_BASE + c * Mesh.ARRAY_FORMAT_CUSTOM_BITS)
		var flags: int = mesh.surface_get_format(i) & keep
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(i), arrays, [], {}, flags)
		out.surface_set_material(i, mesh.surface_get_material(i))
		out.surface_set_name(i, mesh.surface_get_name(i))
	_cache[key] = out
	return out


## 左右对称的那组镜像一份，加上中线上的
static func _ops(gender: String) -> Array:
	var ops := []
	for op: Dictionary in SHAPES.get(gender, []):
		ops.append(op)
		var mirror := op.duplicate()
		for k in ["a", "b", "c", "dir", "toward"]:
			if mirror.has(k):
				mirror[k] = mirror[k] * Vector3(-1, 1, 1)
		ops.append(mirror)
	ops.append_array(SHAPES.get(gender + "_center", []))
	return ops


static func _reach(op: Dictionary) -> AABB:
	if op.type == "capsule":
		var r: float = op.r
		return AABB(op.a, Vector3.ZERO).expand(op.b).grow(r)
	return AABB(op.c - op.radii, op.radii * 2.0)  # blob、squash


static func deform(p: Vector3, ops: Array) -> Vector3:
	var shift := Vector3.ZERO
	for op: Dictionary in ops:
		if op.type == "capsule":
			if op.has("max_y") and p.y > op.max_y:
				continue
			var a: Vector3 = op.a
			var axis: Vector3 = op.b - a
			var length := axis.length()
			var t := clampf((p - a).dot(axis) / (length * length), 0.0, 1.0)
			var q := a + axis * t
			var off := p - q
			var d := off.length()
			if d >= op.r:
				continue
			var along := t * length
			var ends := smoothstep(0.0, float(op.fade), along) * smoothstep(0.0, float(op.fade), length - along)
			var r: float = op.r
			var w := (1.0 - smoothstep(r * 0.55, r, d)) * ends
			shift += off * op.s * w
		elif op.type == "squash":  # 往一条线上下压扁（细眉）
			var e: Vector3 = (p - op.c) / op.radii
			var d2 := e.length_squared()
			if d2 >= 1.0 or p.y < float(op.get("min_y", -INF)):
				continue
			var a: Vector3 = op.a
			var b: Vector3 = op.b
			var cy := lerpf(a.y, b.y, clampf((p.x - a.x) / (b.x - a.x), 0.0, 1.0))
			shift.y += (cy - p.y) * float(op.s) * minf(1.0, 2.0 * (1.0 - d2))
		else:
			var e: Vector3 = (p - op.c) / op.radii
			var d2 := e.length_squared()
			if d2 >= 1.0:
				continue
			var w := (1.0 - d2) * (1.0 - d2)
			if op.has("toward"):  # 往某一点收（胡子收进皮肤底下藏起来）
				shift += (op.toward - p).normalized() * float(op.amount) * w
			else:
				shift += op.dir * w
	return p + shift
