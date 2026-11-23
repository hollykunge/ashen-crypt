extends Node
## 刀客使用完整手绘帧，枪弓暂用原拆件；战场和行装共用同一离屏画布及脚底锚点。
const Rig = preload("res://prototype/cutout/cutout_rig.gd")
const ReferenceFrames = preload("res://scripts/reference_frames.gd")
const ReferenceBlade = preload("res://scripts/reference_blade.gd")
const MaleBase = preload("res://scripts/hero_puppet.gd")
const HeldWeapon = preload("res://scripts/held_weapon.gd")
const UNPREMULTIPLY = preload("res://scripts/unpremultiply.gdshader")
const ROOT := "res://art/ink/hero/"
## 游戏里的护甲类别对应刀客的外观目录。
const OUTFITS := {"cloth": "parts", "leather": "set-leather", "chain": "set-mail"}
## 原来分格人物（ready 那一格）从脚底到头顶的高度，分格像素。皮影主角缩到一样高，战场的站位、判定都不用改
const SPRITE_HEIGHT := 74.0
## 画布大小和脚底在画布里的位置，以身高为单位：剑举过头、往后抡、往前劈出去都要框得住
const BOX := Vector2(3.1, 1.9)
const FEET := Vector2(1.25, 1.75)
## 一次出招里两刀之间，前一刀收势占多少（其余是下一刀起手）
const FOLLOW_SHARE := 0.45
const SPEAR_CARRY_ANGLE := -0.98

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
var _weapon_canvas := Node2D.new()
var _puppet_weapon := Node2D.new()
var _look: Dictionary = {}
var form := "sword"
var _draw_bowstring := false
var _bow_angle := -1.2
var _brace_spear := false
var _spear_angle := SPEAR_CARRY_ANGLE
var painted := Sprite2D.new()

var male_base := MaleBase.new()
var painted_blade := Polygon2D.new()
var painted_frame := "ready"
var _painted_key := ""


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
	painted.centered = false
	painted.scale = Vector2.ONE * (_height_local / ReferenceFrames.HEIGHT)
	painted.position = -ReferenceFrames.FOOT * painted.scale
	painted.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	holder.add_child(painted)
	painted.add_child(male_base)

	painted.add_child(painted_blade)
	ReferenceBlade.setup(painted_blade)
	_set_painted_frame("ready")
	_weapon_canvas.scale = Vector2.ONE * (_height_local / (SPRITE_HEIGHT * rig.scale.x))
	_weapon_canvas.z_index = 15
	_weapon_canvas.z_as_relative = false
	_weapon_canvas.draw.connect(_draw_weapon)
	rig.add_child(_weapon_canvas)
	_puppet_weapon.scale = Vector2.ONE * _height_local / SPRITE_HEIGHT
	_puppet_weapon.z_as_relative = false
	_puppet_weapon.hide()
	_puppet_weapon.z_index = 15
	holder.add_child(_puppet_weapon)
	_puppet_weapon.draw.connect(_draw_puppet_weapon)
	var fix := ShaderMaterial.new()
	fix.shader = UNPREMULTIPLY
	_fix.material = fix
	_fix.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	_fix.z_as_relative = false
	viewport.add_child(_fix)
	_texture.diffuse_texture = viewport.get_texture()
	_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


## 按装备切换整帧衣装及混搭遮罩，同时保留枪弓的拆件外观。
func dress(look: Dictionary) -> void:
	_look = look
	form = look.get("form", "sword")
	painted.visible = _uses_puppet() or (form == "sword" and look.get("gender") != "female")
	rig.visible = not painted.visible
	rig.show_weapon = form == "sword"
	rig._sprites.weapon[0].modulate = Color.WHITE.lerp(look.get("weapon", Color.WHITE), 0.18)
	rig.show_trail = form == "sword"
	_weapon_canvas.visible = not rig.show_weapon
	rig._sprites.far_hand[0].z_index = 16 if form != "sword" else 10 + Rig.Z.arm_far_hand
	var types: Dictionary = look.get("armor_types", {})
	var outfit := {}
	for slot in ["armor", "gloves", "greaves", "boots"]:
		outfit[slot] = ROOT + OUTFITS.get(types.get(slot, "cloth"), "parts")
	outfit.pants = ROOT + OUTFITS.cloth
	var key := str(outfit)
	if key != _outfit_key:
		_outfit_key = key
		rig.set_outfit(outfit)
	_set_painted_frame(painted_frame,not male_base.visible)
	_puppet_weapon.visible = _uses_puppet() and form in ["jian","bow"] and look.get("armed", false)
	if _uses_puppet():
		male_base.dye_panels(look.get("dyes", {}))
	_puppet_weapon.queue_redraw()
	_tint_slot("armor", look.get("robe", Color.WHITE), look.get("robe_amount", 0.0))
	_tint_slot("pants", Color.WHITE, 0.0)
	_tint_slot("gloves", look.get("hands", Color.WHITE), look.get("hands_amount", 0.0))
	_tint_slot("greaves", look.get("greaves", Color.WHITE), look.get("greaves_amount", 0.0))
	_tint_slot("boots", look.get("boots", Color.WHITE), look.get("boots_amount", 0.0))


func _tint_slot(slot: String, color: Color, amount: float) -> void:
	var tint := Color.WHITE.lerp(color, amount * 0.32)
	tint = _look.get("dyes", {}).get(slot, tint)
	var far: float = rig.rig.get("far_tint", Rig.FAR_TINT)
	for part in rig.rig.slots[slot]:
		if part in ["hand", "far_hand"]:
			continue
		for sprite: Sprite2D in rig._sprites[part]:
			sprite.modulate = tint * (Color(far, far * 0.98, far) if sprite.has_meta("far") else Color.WHITE)


func present_outfit() -> void:
	_set_painted_frame("idle")
	_weapon_pose(false, false, 0.0, 0.0)
	if _uses_puppet() and form in ["jian","bow"]:
		male_base.drive_motion(&"idle",0.0,false,-1.0,rig.pose_override)
	if form == "spear":
		_spear_angle = -1.40
		rig.pose_override = {"arm_near_up": 12.0, "arm_near_lo": 38.0}
	rig.play("idle")
	rig.drive_t = -1.0


## 按移动距离推进步态，并把持械动作的关键帧对准战斗结算。
func drive(motion: StringName, phase: float, walked: float, running: bool, cues: Array) -> void:
	var distance := walked / maxf(_height,1.0)
	_set_painted_frame(ReferenceFrames.frame_for(motion, phase, distance, running, cues),false)
	var moving := motion.is_empty() and walked > 0.0
	var attacking := motion == &"attack" and not cues.is_empty()
	_weapon_pose(moving, attacking, phase, float(cues[0]) if attacking else 0.0)
	var reacting := _reaction_pose(motion,phase)
	if male_base.visible:
		if form in ["jian","bow"]:
			male_base.drive_motion(motion,distance,running,-1.0,rig.pose_override)
			return
		if motion == &"cleave":
			male_base.drive_cleave(phase)
			return
		if attacking and cues.size() == 2 and male_base.sword.visible:
			male_base.drive_combo(phase,cues)
			return
		var seconds := -1.0
		if attacking:
			seconds = attack_time(phase,cues,male_base.attack_hit_time(),male_base.attack_end_time()).y
		male_base.drive_motion(motion,distance,running,seconds,rig.pose_override if reacting else {})
		return
	if reacting:
		_slash = -1
		rig.play("ready")
		rig.drive_t = -1.0
		return
	if moving:
		_slash = -1
		rig.play("run" if running else "walk")
		rig.drive_t = rig.gait_time(walked / (rig.leg_length() * holder.scale.y))
		return
	if not attacking or form == "bow":
		_slash = -1
		rig.play("ready")
		rig.drive_t = -1.0
		return
	var beat := attack_time(phase, cues, rig.attack_hit_time(), rig.attack_end_time())
	if beat.x != _slash or phase < _last_phase - 0.01:
		rig.play("ready")
		rig.play("attack")
	_slash = int(beat.x)
	_last_phase = phase
	rig.drive_t = beat.y


func _uses_puppet() -> bool:
	return form in ["sword","jian","bow"] and _look.get("gender") == "male"

func _set_painted_frame(frame: String, sample_pose := true) -> void:
	painted_frame = frame
	var types: Dictionary = _look.get("armor_types", {})
	var use_base: bool = _uses_puppet()
	var armed: bool = _look.get("armed", false)
	if use_base and sample_pose:
		male_base.sample_frame(frame)
	var key := ("puppet" if use_base else frame) + form + str(types) + str(use_base) + str(armed)
	if key != _painted_key:
		_painted_key = key
		male_base.visible = use_base
		male_base.set_process(use_base)
		if use_base:
			painted.material = null
			painted.texture = null
			painted_blade.hide()
			male_base.equip(armed,types.has("armor"),types.get("armor") in ["chain","leather"],types)
			male_base.sword.self_modulate.a = 1.0 if form == "sword" else 0.0
			male_base.show_trail = form == "sword"
			return
		ReferenceFrames.apply(painted, frame, types)
		ReferenceBlade.apply(painted_blade, frame)


func _reaction_pose(motion: StringName, phase: float) -> bool:
	var strength := sin(clampf(phase, 0.0, 1.0) * PI)
	var pose := {}
	match motion:
		&"hurt":
			pose = {"torso": -14.0 * strength, "neck": 8.0 * strength,
				"dx": -0.07 * strength, "hip": 0.94 - 0.04 * strength,
				"arm_near_up": 12.0, "arm_near_lo": 65.0}
		&"retreat":
			pose = {"torso": -10.0 * strength, "neck": 5.0 * strength,
				"dx": -0.10 * strength, "hip": 0.94 - 0.04 * strength,
				"arm_near_up": 38.0, "arm_near_lo": 75.0}
		&"skill", &"tactic":
			pose = {"torso": 6.0 - 12.0 * strength, "neck": 3.0 * strength,
				"arm_near_up": 26.0 + 95.0 * strength,
				"arm_near_lo": 40.0 - 15.0 * strength,
				"arm_far_up": 31.0 + 40.0 * strength,
				"arm_far_lo": 78.0 - 40.0 * strength}
		&"revive":
			pose = {"torso": 26.0 * (1.0 - phase), "hip": lerpf(0.75, 0.94, phase)}
		_:
			return false
	rig.pose_override.merge(pose, true)
	return true


func _weapon_pose(moving: bool, attacking: bool, phase: float, release: float) -> void:
	rig.pose_override = {}
	_draw_bowstring = false
	_bow_angle = -1.2
	_brace_spear = false
	_spear_angle = SPEAR_CARRY_ANGLE
	if moving or form == "sword":
		return
	var force := 0.0
	if attacking:
		force = smoothstep(0.0, release, phase) * (1.0 - smoothstep(release, 1.0, phase))
	if form == "bow":
		_draw_bowstring = attacking and phase <= release
		_bow_angle = lerpf(-1.2, -PI / 2.0, force)
		rig.pose_override = {
			"arm_near_up": lerpf(13.0, -5.0, force), "arm_near_lo": lerpf(35.0, 138.0, force),
			"arm_far_up": lerpf(26.0, 74.0, force), "arm_far_lo": lerpf(31.0, 27.0, force)
		}
	elif form == "jian":
		rig.pose_override = {"arm_near_up": lerpf(18.0,78.0,force), "arm_near_lo": lerpf(75.0,16.0,force),
			"arm_far_up": lerpf(20.0,-17.0,force), "arm_far_lo": 65.0, "thrust_extension": force}
	elif form == "spear":
		_brace_spear = true
		rig.pose_override = {
			"arm_near_up": lerpf(-29.0, -3.0, force), "arm_near_lo": lerpf(128.0, 108.0, force),
			"arm_far_up": lerpf(54.0, 72.0, force), "arm_far_lo": lerpf(30.0, 13.0, force)
		}


func _process(_delta: float) -> void:
	if _puppet_weapon.visible:
		_puppet_weapon.queue_redraw()
	if _weapon_canvas.visible:
		_weapon_canvas.queue_redraw()


func _grip(bone: String, offset := Vector2.ZERO) -> Vector2:
	return (rig._relative(rig._bones[bone]) * offset) / _weapon_canvas.scale.x


func _puppet_grip(far: bool) -> Vector2:
	if far:
		return _puppet_weapon.to_local(male_base._bones.arm_far_hand.to_global(Vector2(0,50)))
	return _puppet_weapon.to_local(male_base.sword.global_position)

func _draw_puppet_weapon() -> void:
	if not _puppet_weapon.visible:
		return
	var near := _puppet_grip(false)
	var design: Dictionary = _look.design
	if form == "bow":
		HeldWeapon.draw_bow(_puppet_weapon,_puppet_grip(true),near,_draw_bowstring,_bow_angle,Color.WHITE,design)
	else:
		var tip := _puppet_weapon.to_local(male_base.weapon_tip_marker.global_position)
		HeldWeapon.draw_sword(_puppet_weapon,near,(tip-near).angle(),Color.WHITE,design)

func release_point() -> Vector2:
	if _uses_puppet() and form == "bow":
		var front := _puppet_grip(true)
		return front + (front-_puppet_grip(false)).normalized()*8.0
	var bow := _grip("arm_far_hand", Vector2(0.0, 19.0))
	return bow + (bow - _grip("weapon")).normalized() * 8.0


func _draw_weapon() -> void:
	var near := _grip("weapon")
	var far := _grip("arm_far_hand", Vector2(0.0, 19.0))
	var design: Dictionary = _look.get("design", {})
	var ink := Color.WHITE.lerp(_look.get("weapon", Color.WHITE), 0.34)
	if form == "bow":
		HeldWeapon.draw_bow(_weapon_canvas, far, near, _draw_bowstring, _bow_angle, ink, design)
	elif form == "spear":
		var angle := (far - near).angle() if _brace_spear else _spear_angle
		HeldWeapon.draw_pole(_weapon_canvas, form, near, angle, ink, INF, design)
	elif form in ["sword","jian"]:
		var angle: float = rig._relative(rig._bones.weapon).get_rotation()
		HeldWeapon.draw_sword(_weapon_canvas, near, angle, ink, design)


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
	var tint := Color(1.0, 1.0, 1.0, ink.a) if painted.visible else ink
	canvas.draw_texture_rect(_texture, Rect2(offset - FEET * _height, Vector2(viewport.size) / _density), false, tint)
	canvas.draw_set_transform(Vector2.ZERO)
