extends Node
## 皮影主角：prototype/cutout 的拆件骨骼（piying 那套皮影刀客）画在一块离屏画布（SubViewport）上，
## 战场、行装页贴到主角脚下时把这块画布当一张图贴上去，和 3D 主角画布（cutout_hero.gd）用法一样。
## cutout_hero.gd 在有皮影部件的时候把活交给它（who_for）：男主角拿刀剑是皮影刀客（piying），
## 女主角拿刀、剑、枪是鬼面女将（nvjiang，招牌兵器是月牙长刀，三种近战兵器都画它）；弓还是 3D。
## 有骨骼动作的：备战、走、跑、劈砍；受击、闪避、施法这些还没做，先摆备战架势，
## 闪白、残影、位移照旧由战场叠上去。
const Rig = preload("res://prototype/cutout/cutout_rig.gd")
const UNPREMULTIPLY = preload("res://scripts/unpremultiply.gdshader")
const ROOT := "res://prototype/cutout/"
## 战场里人物的身高（分格像素），和 cutout_hero.gd 一样，站位、判定都不用改
const SPRITE_HEIGHT := 74.0
## 画布大小和脚底在画布里的位置，以身高为单位：刀举过头、往后抡、往前劈出去都要框得住
const BOX := Vector2(3.1, 1.9)
const FEET := Vector2(1.25, 1.75)
## 一次出招里两刀之间，前一刀收势占多少（其余是下一刀起手）
const FOLLOW_SHARE := 0.45
## 没有逐刀时刻（cues）的招式（比如跃斩）按一刀算，打在这个进度上
const DEFAULT_CUE := 0.5

var viewport := SubViewport.new()
var holder := Node2D.new()
var rig: Node2D
var texture := CanvasTexture.new()  # 贴画布用线性取样（工程默认最近邻，非整数缩放会出锯齿）
var _fix := ColorRect.new()  # 盖在画布最上面，把预乘的透明度还原（unpremultiply.gdshader）
var _density := 1.0  # 真实屏幕像素 / 界面逻辑像素
var _height_local := 1.0
var _height := 0.0
var _slash := -1
var _last_phase := 0.0


## 哪个皮影角色（prototype/cutout 下的目录名）；没有对应的皮影部件时返回空串，交回 3D
static func who_for(look: Dictionary) -> String:
	var form: String = look.get("form", "sword")
	if look.get("gender", "") == "female":
		return "nvjiang" if form in ["sword", "jian", "spear"] else ""
	return "piying" if form in ["sword", "jian"] else ""


var who := ""


func _init(character := "piying") -> void:
	who = character
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# 工程默认最近邻取样（像素风界面），皮影部件是高清原画，缩小要线性加多级渐远
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	viewport.size = Vector2i(8, 8)
	add_child(viewport)
	viewport.add_child(holder)
	rig = Rig.new()
	holder.add_child(rig)
	rig.setup(ROOT + who + "/rig.json", ROOT + who + "/parts")
	rig.blend_time = 0.08
	# 战斗里站着摆备战架势（rig.json 的 ready），劈砍也从它起手、收回到它
	rig.attack_from = "ready"
	_height_local = rig.stand_height()
	var fix := ShaderMaterial.new()
	fix.shader = UNPREMULTIPLY
	fix.set_shader_parameter("puppet_light", true)
	_fix.material = fix
	_fix.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	_fix.z_as_relative = false
	viewport.add_child(_fix)
	texture.diffuse_texture = viewport.get_texture()
	texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


## 停画（藏起来、或者交回 3D 主角时）
func set_active(on: bool) -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	rig.set_process(on)


## 行装页：站着摆备战架势。皮影只有侧面，不像 3D 那样转过来
func present() -> void:
	_slash = -1
	rig.play("ready")
	rig.drive_t = -1.0


## 每帧按战斗状态选动作、对时刻。walked：这一段走过的屏幕像素；phase：出招进度（已含顿帧）；
## cues：这一招里每一刀打中的进度
func drive(motion: StringName, phase: float, walked: float, running: bool, cues: Array) -> void:
	if motion.is_empty():
		_slash = -1
		if walked > 0.0:
			rig.play("run" if running else "walk")
			rig.drive_t = rig.gait_time(walked / maxf(rig.leg_length() * holder.scale.y, 0.001))
		else:
			rig.play("ready")
			rig.drive_t = -1.0
		return
	if not motion in [&"attack", &"cleave"]:
		present()
		return
	var beats: Array = cues if not cues.is_empty() else [DEFAULT_CUE]
	var beat := attack_time(phase, beats, rig.attack_hit_time(), rig.attack_end_time())
	# 换一刀（或者新的一招从头开始）就从当前姿势快速过渡到起手
	if beat.x != _slash or phase < _last_phase - 0.01:
		rig.play("ready")
		rig.play("attack")
	_slash = int(beat.x)
	_last_phase = phase
	rig.drive_t = beat.y


## 出招进度 → [第几刀, 骨骼劈砍的时刻]（和 cutout_hero.gd 的同名函数一样）
static func attack_time(phase: float, cues: Array, hit: float, end: float) -> Vector2:
	var count := cues.size()
	var start := 0.0
	for i in count:
		var cue: float = cues[i]
		var last := i == count - 1
		var finish := 1.0 if last else cue + (float(cues[i + 1]) - cue) * FOLLOW_SHARE
		if phase < finish or last:
			if phase < cue:
				return Vector2(i, hit * clampf((phase - start) / maxf(cue - start, 0.001), 0.0, 1.0))
			var settle := end if last else lerpf(hit, end, 0.4)
			return Vector2(i, lerpf(hit, settle, clampf((phase - cue) / maxf(finish - cue, 0.001), 0.0, 1.0)))
		start = finish
	return Vector2(count - 1, end)


## 握刀拳头的位置（相对脚底，分格像素，x 朝前、y 朝下）
func release_point() -> Vector2:
	var hand: Node2D = rig._bones.get("arm_near_hand", rig._bones.get("arm_near_lo"))
	if hand == null:
		return Vector2(10.0, -SPRITE_HEIGHT * 0.5)
	var p: Vector2 = (rig.get_global_transform().affine_inverse() * hand.get_global_transform()).origin
	return (rig.transform * p) * SPRITE_HEIGHT / _height_local


## 让画布跟着人物在屏幕上的大小走（参数同 cutout_hero.gd 的 fit）
func fit(pixels: float, density: float) -> void:
	var height := SPRITE_HEIGHT * pixels
	if absf(height - _height) < 0.5 and is_equal_approx(density, _density):
		return
	_height = height
	_density = density
	var real := height * density
	viewport.size = Vector2i(maxi(ceili(BOX.x * real), 8), maxi(ceili(BOX.y * real), 8))
	_fix.size = Vector2(viewport.size)
	holder.position = FEET * real
	holder.scale = Vector2.ONE * (real / _height_local)


## 把画布贴到 canvas 上：feet 是脚底的屏幕位置，facing 朝向，offset 是残影往后错开的屏幕像素
func draw(canvas: CanvasItem, feet: Vector2, facing: float, ink: Color, offset := Vector2.ZERO) -> void:
	canvas.draw_set_transform(feet, 0.0, Vector2(facing, 1.0))
	canvas.draw_texture_rect(texture, Rect2(offset - FEET * _height, Vector2(viewport.size) / _density), false, ink * Color(1.09, 1.045, 1.0))
	if offset == Vector2.ZERO:
		for bone in ["arm_near_lo", "leg_near_lo", "arm_near_up"]:
			var joint := _joint(bone)
			var radius := clampf(_height * 0.011, 1.2, 3.4)
			canvas.draw_circle(joint, radius, Color("#573518"), true, -1, true)
			canvas.draw_circle(joint - Vector2.ONE * radius * 0.22, radius * 0.58, Color("#ddb669"), true, -1, true)
	canvas.draw_set_transform(Vector2.ZERO)

func _joint(bone: String) -> Vector2:
	var node: Node2D = rig._bones[bone]
	return holder.to_local(node.global_position) * _height / _height_local
