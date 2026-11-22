extends Node
## 皮影主角接进战斗：prototype/cutout 的拆件骨骼画在一块离屏画布（SubViewport）上，
## 战场 _draw 到主角时把这块画布当一张图贴在脚下。前后遮挡、残影、五行染色、淡出都跟原来的分格人物一样走 _draw。
## 目前只有男主角拿剑有这套图：备战架势、走、跑、劈砍有骨骼动作；受击、闪避、施法这些还没做，先摆备战架势，
## 闪白、残影、位移照旧叠上去（中途换回分格人物的话，像换了个人，更扎眼）。

const Rig = preload("res://prototype/cutout/cutout_rig.gd")
const UNPREMULTIPLY = preload("res://scripts/unpremultiply.gdshader")
const ROOT := "res://prototype/cutout/hero/"
## 总开关：关掉就全用分格人物
const ENABLED := true
## 游戏里的护甲类别 → 小样里的整套外观目录（链甲用的是小样里叫 set-iron 的那套）
const OUTFITS := {"cloth": "parts", "leather": "set-leather", "chain": "set-iron"}
## 原来分格人物（ready 那一格）从脚底到头顶的高度，分格像素。皮影主角缩到一样高，战场的站位、判定都不用改
const SPRITE_HEIGHT := 74.0
## 画布大小和脚底在画布里的位置，以身高为单位：剑举过头、往后抡、往前劈出去都要框得住
const BOX := Vector2(2.8, 1.9)
const FEET := Vector2(1.2, 1.75)
## 一次出招里两刀之间，前一刀收势占多少（其余是下一刀起手）
const FOLLOW_SHARE := 0.45

var viewport := SubViewport.new()
var holder := Node2D.new()
var _fix := ColorRect.new()  # 盖在画布最上面，把预乘的透明度还原（unpremultiply.gdshader）
var _texture := CanvasTexture.new()  # 贴画布用线性取样（工程默认最近邻，非整数缩放会出锯齿）
var _density := 1.0  # 真实屏幕像素 / 界面逻辑像素
var rig: Node2D
var _height_local := 1.0
var _height := 0.0
var _outfit_key := ""
var _slash := -1
var _last_phase := 0.0


static func supports(female: bool, form: String) -> bool:
	return ENABLED and not female and form == "sword"


func _init() -> void:
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# 工程默认最近邻取样（像素风界面），骨骼部件是高清原画，缩小要线性加多级渐远
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	viewport.size = Vector2i(8, 8)
	add_child(viewport)
	viewport.add_child(holder)
	rig = Rig.new()
	holder.add_child(rig)
	rig.setup(ROOT + "rig.json", ROOT + "parts")
	rig.blend_time = 0.08
	# 战斗里站着摆备战架势（rig.json 的 ready），劈砍也从它起手、收回到它
	rig.attack_from = "ready"
	_height_local = rig.stand_height()
	var fix := ShaderMaterial.new()
	fix.shader = UNPREMULTIPLY
	_fix.material = fix
	_fix.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	_fix.z_as_relative = false
	viewport.add_child(_fix)
	_texture.diffuse_texture = viewport.get_texture()
	_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


## 按装备换整套部件图：护甲槽管躯干和上臂，裤子跟着护甲，护手、靴子各按各的
func dress(look: Dictionary) -> void:
	var types: Dictionary = look.get("armor_types", {})
	var outfit := {}
	for slot in ["armor", "gloves", "boots"]:
		outfit[slot] = ROOT + OUTFITS.get(types.get(slot, "cloth"), "parts")
	outfit.pants = outfit.armor
	var key := str(outfit)
	if key != _outfit_key:
		_outfit_key = key
		rig.set_outfit(outfit)


## 每帧按战斗状态选动作、对时刻。返回 false 表示这一帧要画分格人物（现在总是 true，留着给以后没法凑合的动作）。
## walked：这一段走过的屏幕像素；phase：出招进度（已含顿帧）；cues：这一招里每一刀打中的进度。
func drive(motion: StringName, phase: float, walked: float, running: bool, cues: Array) -> bool:
	if motion.is_empty():
		_slash = -1
		if walked > 0.0:
			rig.play("run" if running else "walk")
			rig.drive_t = rig.gait_time(walked / (rig.leg_length() * holder.scale.y))
		else:
			rig.play("ready")
			rig.drive_t = -1.0
		return true
	if motion != &"attack" or cues.is_empty():
		_slash = -1
		rig.play("ready")
		rig.drive_t = -1.0
		return true
	var beat := attack_time(phase, cues, rig.attack_hit_time(), rig.attack_end_time())
	# 换一刀（或者新的一招从头开始）就从当前姿势快速过渡到起手
	if beat.x != _slash or phase < _last_phase - 0.01:
		rig.play("ready")
		rig.play("attack")
	_slash = int(beat.x)
	_last_phase = phase
	rig.drive_t = beat.y
	return true


## 出招进度 → [第几刀, 骨骼劈砍的时刻]。每一刀的「打中」对准结算的那一下（cues）；
## 前一刀打中以后收一小段，剩下的时间给下一刀起手；最后一刀收到整段结束。
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


## 让画布跟着人物在屏幕上的大小走。pixels：分格人物每个分格像素在屏幕上多大（界面逻辑像素）；
## density：一个逻辑像素是几个真实屏幕像素。画布按真实像素画，贴回来时再缩，手机高清屏上才不糊
func fit(pixels: float, density: float) -> void:
	var height := SPRITE_HEIGHT * pixels
	if absf(height - _height) < 0.5 and is_equal_approx(density, _density):
		return
	_height = height
	_density = density
	var real := height * density
	viewport.size = Vector2i(ceili(BOX.x * real), ceili(BOX.y * real))
	_fix.size = Vector2(viewport.size)
	holder.position = FEET * real
	holder.scale = Vector2.ONE * (real / _height_local)


## 把画布贴到 canvas 上：feet 是脚底的屏幕位置，facing 朝向，offset 是残影往后错开的屏幕像素
func draw(canvas: CanvasItem, feet: Vector2, facing: float, ink: Color, offset := Vector2.ZERO) -> void:
	canvas.draw_set_transform(feet, 0.0, Vector2(facing, 1.0))
	canvas.draw_texture_rect(_texture, Rect2(offset - FEET * _height, Vector2(viewport.size) / _density), false, ink)
	canvas.draw_set_transform(Vector2.ZERO)
