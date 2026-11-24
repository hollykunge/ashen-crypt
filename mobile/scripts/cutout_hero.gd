extends Node
## 主角：3D 角色模型（scripts/model_hero.gd）在离屏画布里从侧面渲染，战场和行装把这块画布贴到脚底位置。
## 对外接口沿用原来的皮影主角（dress / fit / drive / draw / present_outfit / release_point），
## 战场（arena.gd）和行装页（armory_figure.gd）不用改调用方式。

const ModelHero = preload("res://scripts/model_hero.gd")
const WeaponDesign = preload("res://scripts/weapon_design.gd")

## 原来分格人物（ready 那一格）从脚底到头顶的高度，分格像素。战场按它定人物大小，站位、判定都不用改
const SPRITE_HEIGHT := 74.0
## 画布大小和脚底在画布里的位置，以身高为单位：举手、往后抡、往前劈、倒地都要框得住
const BOX := Vector2(3.1, 1.9)
const FEET := Vector2(1.25, 1.75)
## 一次出招里两刀之间，前一刀收势占多少（其余是下一刀起手）
const FOLLOW_SHARE := 0.45
## 模型身高（米，脚底到头顶），画布按它换算
const MODEL_HEIGHT := 1.80

## 游戏里的护甲类别 → 模型的款式（游侠那套没有对应的护甲类别，只在试穿台里用）
const OUTFITS := {"cloth": "peasant", "leather": "leather", "chain": "chain"}
## 上衣的护甲类别 → 头饰
const HEADGEAR := {"cloth": "hat", "leather": "leather", "chain": "iron"}
## 游戏的装备槽 → 模型的槽
const SLOT_OF := {"armor": "torso", "gloves": "arms", "greaves": "legs", "boots": "feet"}

## 每种兵器的出招动作和时间（帧，24fps）：hit 是打中 / 撒放那一帧，end 是收势。
## 剑：右手从头后抡下来，第 11 帧刀过身前；长枪：右手直拳当双手前刺，第 7 帧刺到头；
## 弓：左手前伸（弓手），第 4 帧撒放。施法、战术都用左手前伸那一下
const MOVES := {
	"sword": {"attack": "Sword_Attack", "hit": 11.0, "end": 37.0},
	"jian": {"attack": "Sword_Attack", "hit": 11.0, "end": 37.0},
	"spear": {"attack": "Punch_Cross", "hit": 7.0, "end": 24.0},
	"bow": {"attack": "Spell_Simple_Shoot", "hit": 4.0, "end": 12.0},
}
const CAST := "Spell_Simple_Shoot"
## 剑的出招（测试和外部按这个对时）
const ATTACK := "Sword_Attack"
const ATTACK_HIT := 11.0 / 24.0
const ATTACK_END := 37.0 / 24.0
## 一个步态循环走多远（以身高计），用来让脚步和移动距离对上，不打滑
const GAIT := {"Walk_Loop": 1.05, "Sprint_Loop": 2.2}
## 米 → 分格像素
const PX_PER_M := SPRITE_HEIGHT / MODEL_HEIGHT

var viewport := SubViewport.new()
var hero: ModelHero
var camera := Camera3D.new()
var _texture: Texture2D
var _density := 1.0  # 真实屏幕像素 / 界面逻辑像素
var _height := 0.0
var _look: Dictionary = {}
var form := "sword"
var _action := ""
var _clock := 0.0     # 循环动作（待机、戒备）自己走的时间
var _manual := false  # 本帧动作时间由 drive 指定
## 兵器是 3D 模型，挂在手骨上、四指握拳攥住（model_hero.gd 的 hold）。这里只取手的位置给弓箭出手点用
var _skeleton: Skeleton3D
var _skeleton_xform := Transform3D.IDENTITY  # 骨架 → 角色根节点
var _moving := false
var _drawing := false  # 弓：拉满还没撒放


func _init() -> void:
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(8, 8)
	add_child(viewport)

	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#8a7d72")
	env.environment.ambient_light_energy = 0.55
	viewport.add_child(env)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.25
	key.light_color = Color("#fff1dd")
	viewport.add_child(key)
	key.transform = Transform3D.IDENTITY.looking_at(Vector3(3.0, -4.0, -2.5), Vector3.UP)

	hero = ModelHero.new()
	viewport.add_child(hero)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = BOX.y * MODEL_HEIGHT
	viewport.add_child(camera)
	# 角色朝 +Z；相机在角色右侧（-X）看过去，画面里角色朝右。脚底落在画布的 FEET 处
	var width := camera.size * BOX.x / BOX.y
	var center := Vector3(0.0, camera.size * (FEET.y / BOX.y - 0.5), width * (0.5 - FEET.x / BOX.x))
	camera.transform = Transform3D(Basis.looking_at(Vector3.RIGHT, Vector3.UP), center + Vector3(-6.0, 0.0, 0.0))
	_texture = viewport.get_texture()

	_skeleton = hero.find_child("Skeleton3D", true, false)
	var node: Node = _skeleton
	while node != hero:
		_skeleton_xform = (node as Node3D).transform * _skeleton_xform
		node = node.get_parent()


func _ready() -> void:
	hero.anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var first := _action if not _action.is_empty() else "Sword_Idle"
	_action = ""
	_play(first)
	if not _look.is_empty():
		dress(_look)


## 按装备换各槽款式，按染色给各槽上色。
func dress(look: Dictionary) -> void:
	_look = look
	form = look.get("form", "sword")
	if not MOVES.has(form):
		form = "sword"
	var design: Dictionary = look.get("design", {})
	hero.hold(form, design if not design.is_empty() else WeaponDesign.plain(form))
	var types: Dictionary = look.get("armor_types", {})
	for slot in SLOT_OF:
		hero.outfit[SLOT_OF[slot]] = OUTFITS.get(types.get(slot, "cloth"), "peasant")
	# 肩甲跟着上衣走：皮甲配皮肩甲，链甲配钢肩甲，布衣不带
	var torso: String = hero.outfit.torso
	hero.outfit.shoulder = torso if torso != "peasant" and types.has("armor") else "none"
	hero.outfit.hood = "none"
	# 头饰跟着上衣的护甲类别：布衣或没穿护甲戴斗笠，皮甲戴皮兜鍪，链甲戴铁兜鍪
	hero.outfit.headgear = HEADGEAR.get(types.get("armor", "cloth"), "hat")
	hero.apply_outfit()
	var dyes: Dictionary = look.get("dyes", {})
	_tint("armor", look.get("robe", Color.WHITE), look.get("robe_amount", 0.0), dyes)
	_tint("gloves", look.get("hands", Color.WHITE), look.get("hands_amount", 0.0), dyes)
	_tint("greaves", look.get("greaves", Color.WHITE), look.get("greaves_amount", 0.0), dyes)
	_tint("boots", look.get("boots", Color.WHITE), look.get("boots_amount", 0.0), dyes)


func _tint(slot: String, color: Color, amount: float, dyes: Dictionary) -> void:
	var tint: Color = dyes.get(slot, Color.WHITE.lerp(color, amount * 0.32))
	hero.set_tint(SLOT_OF[slot], tint)
	if slot == "armor":
		hero.set_tint("shoulder", tint)


## 行装页：站着待机。
func present_outfit() -> void:
	# 垂手站着：剑尖朝地垂在手里，长枪拄着站，弓照常握
	hero.set_grip_mode({"spear": "against", "bow": "fist"}.get(form, "along"))
	_play("Idle_Loop")
	_manual = false


## 按战斗状态选动作并定时间：走跑按移动距离推步态，出招让「打中」对准结算的那一下（cues）。
func drive(motion: StringName, phase: float, walked: float, running: bool, cues: Array) -> void:
	var distance := walked / maxf(_height, 1.0)
	_manual = true
	_moving = motion.is_empty() and walked > 0.0
	hero.set_grip_mode("along" if form == "spear" and motion in [&"attack", &"cleave"] else "fist")
	_drawing = false
	match motion:
		&"attack", &"cleave":
			var move: Dictionary = MOVES[form]
			var hit: float = move.hit / 24.0
			var end: float = move.end / 24.0
			var seconds := phase * end
			if motion == &"attack" and not cues.is_empty():
				seconds = attack_time(phase, cues, hit, end).y
			_drawing = form == "bow" and seconds < hit
			_pose_at(move.attack, seconds)
		&"skill", &"tactic":
			_pose_at(CAST, phase * _length(CAST))
		&"hurt":
			_pose_at("Hit_Chest", phase * _length("Hit_Chest"))
		&"retreat":
			_pose_at("Hit_Head", phase * _length("Hit_Head"))
		&"revive":  # 倒地倒着放：从地上站起来
			_pose_at("Death01", (1.0 - phase) * _length("Death01"))
		_:
			if walked > 0.0:
				var gait := "Sprint_Loop" if running else "Walk_Loop"
				_pose_at(gait, fposmod(distance / GAIT[gait], 1.0) * _length(gait))
			else:
				_manual = false
				_play("Sword_Idle")


func _process(delta: float) -> void:
	if hero.anim == null:
		return
	if not _manual:
		_clock += delta
		hero.anim.seek(fposmod(_clock, maxf(_length(_action), 0.01)), true)


func _play(action: String) -> void:
	if action != _action:
		_action = action
		_clock = 0.0
		if hero.anim != null:
			hero.play(action, 0.0)


func _pose_at(action: String, seconds: float) -> void:
	_play(action)
	hero.anim.seek(clampf(seconds, 0.0, _length(action)), true)


func _length(action: String) -> float:
	var a: String = hero.anim_name(action)
	return hero.anim.get_animation(a).length if hero.anim.has_animation(a) else 0.0


## 弓箭出手点（相对脚底，分格像素）：弓手（左手）前面一点
func release_point() -> Vector2:
	if form == "bow":
		return _point("hand_l") + Vector2(6.0, 0.0)
	return _fist()


## 骨骼在侧面画布里的位置（分格像素，原点脚底，x 朝前、y 朝下）
func _point(bone: String) -> Vector2:
	return _project(_bone3d(bone))


func _bone3d(bone: String) -> Vector3:
	return _skeleton_xform * _skeleton.get_bone_global_pose(_skeleton.find_bone(bone)).origin


func _project(p: Vector3) -> Vector2:
	return Vector2(p.z, -p.y) * PX_PER_M


## 右拳握点：手掌到指根之间
func _fist() -> Vector2:
	var knuckles := (_bone3d("index_01_r") + _bone3d("pinky_01_r")) * 0.5
	return _project(_bone3d("hand_r").lerp(knuckles, 0.65))


## 出招进度 → [第几刀, 动作里打中那一下的秒数]。每一刀的「打中」对准结算的那一下（cues）；
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
	viewport.size = Vector2i(maxi(ceili(BOX.x * real), 8), maxi(ceili(BOX.y * real), 8))


## 把画布贴到 canvas 上：feet 是脚底的屏幕位置，facing 朝向，offset 是残影往后错开的屏幕像素
func draw(canvas: CanvasItem, feet: Vector2, facing: float, ink: Color, offset := Vector2.ZERO) -> void:
	canvas.draw_set_transform(feet, 0.0, Vector2(facing, 1.0))
	canvas.draw_texture_rect(_texture, Rect2(offset - FEET * _height, Vector2(viewport.size) / _density), false, ink)
	canvas.draw_set_transform(Vector2.ZERO)
