extends Control

const Gear = preload("res://scripts/gear.gd")
const ForgeArt = preload("res://scripts/forge_art.gd")

const Combat = preload("res://scripts/combat.gd")
const CombatFX = preload("res://scripts/combat_fx.gd")
const FxArt = preload("res://scripts/fx_art.gd")
const Roster = preload("res://scripts/roster.gd")
const Motion = preload("res://scripts/motion.gd")
const Figure = preload("res://scripts/figure.gd")
const Rig = preload("res://scripts/rig.gd")
const Appearance = preload("res://scripts/appearance.gd")
const SideArt = preload("res://scripts/side_art.gd")
const MonsterArt = preload("res://scripts/monster_art.gd")
const CutoutHero = preload("res://scripts/cutout_hero.gd")
const WORLD_CENTER_X := 538.0
const SIDE_DEPTH := 0.18
const HERO_SCALE := 1.34
const FOE_SCALE := 1.30
const LANDSCAPE_ACTOR_MAGNIFICATION := 1.40
const CUT_IN_TIME := 0.43
# 连战镜头在原取景上整体推近：站位、人物和背景同比放大，交手距离的观感不变，
# 只是空地少了，人物占得更满。
const PORTRAIT_BATTLE_ZOOM := 1.75   # 竖屏战斗推近：人物大一些（借街机格斗那种大人物）
const LANDSCAPE_BATTLE_ZOOM := 1.22
# 竖屏把地面线压低，下方空雪地让给人物；镜头中心左移，主角和精怪各占画面一侧。
const PORTRAIT_BATTLE_FLOOR := 0.765
const PORTRAIT_BATTLE_CENTER_X := 493.0
const SNOW_HAZE = preload("res://scripts/snow_haze.gdshader")
const ATMOSPHERE = preload("res://scripts/atmosphere.gdshader")
# 挂机时一整天的长度（秒）。前一半是白天，再走过黄昏入夜，最后经过拂晓回到白天。
const DAY_LENGTH := 300.0
# 天色每秒最多变多少。连战换波时跑图那几秒，正好从一段天色走到下一段。
const DAYLIGHT_PACE := 0.22
# 最前面那层剪影相对镜头的速度：长卷走 1，它走 1.6。
const NEAR_PARALLAX := 1.6
# 暗黑调色的力度（0 关掉，1 全开）和四角压暗。挂机取景远，压角轻一点。
const GRADE := 1.0
const VIGNETTE := 0.7
## 皮影戏幕布：长卷换成被灯照透的暖琥珀幕布、景物成深褐影子（snow_haze.gdshader 的 screen），0 关掉
const PIYING_SCREEN := 1.0
## 皮影布景：镂空雕刻的远山、树、亭台、民房、石桥，立在人物身后的台口上，随镜头慢慢挪（_draw_scenery）。
## [图, 高度（画面高的比例）, 视差（长卷走 1 它走多少）, 出现的权重]；远山走得最慢，在最后面
const SCENERY := [
	["mountains", 0.34, 0.35, 0.0], ["pine", 0.21, 0.6, 1.0], ["pavilion", 0.17, 0.6, 0.6],
	["house", 0.15, 0.6, 0.9], ["bridge", 0.08, 0.6, 0.4], ["deadtree", 0.19, 0.6, 1.0],
]
const SCENERY_DIR := "res://art/piying/stage/"
## 布景调淡、半透，颜色贴近幕布，退到人物后面当陪衬（人物、精怪是最鲜明的一层）；远山更淡
const SCENERY_INK := Color(0.92, 0.72, 0.52, 0.42)
const SCENERY_FAR_INK := Color(0.9, 0.7, 0.5, 0.3)
static var _scenery_tex := {}
## 幕布四边烧暗的力度（皮影戏台口外是黑的）
const PIYING_VIGNETTE := 0.45
const VIGNETTE_CAMP := 0.6

var run: Combat
var hero_element := "jin"
var scale_to_screen := 1.0
var actor_zoom := 1.0
var art_review_scale := 1.0
# 主角每个像素在屏幕上的边长，连击数等贴着人物的界面按它避让头顶。
var hero_pixels := 1.0
var world_center_x := WORLD_CENTER_X
var haze := ShaderMaterial.new()
var world_offset := Vector2.ZERO
var camp_view := false
var ash_time := 0.0
# 装备外观，由 main 在换装备或开场时写入。
var look: Dictionary = Appearance.bare():
	set(value):
		look = value
		if cutout != null:
			cutout.dress(look)
var cutout: CutoutHero
var retinue: CutoutHero
# 打击反馈：震屏、闪白、顿感都只影响画面，不碰结算。
# shake 是「创伤值」0~1：每次打击往上加，按秒线性回落；画面位移按它的 1.5 次方算，
# 小打小闹几乎不抖，连续重击才明显。抖动偏向打击方向（shake_dir），另有一下沿打击方向的镜头冲击（kick）。
const SHAKE_PIXELS := 14.0
const SHAKE_EXPONENT := 1.5
var shake := 0.0
var shake_seed := 0.0
var shake_dir := Vector2.RIGHT
var kick := Vector2.ZERO
# 打击溅出的血雾、火星和灰烬，只在画面层，单位是战场坐标。
const MAX_SPARKS := 180
const ICHOR := Color("#7a1712")
const ICHOR_DARK := Color("#2a0b0a")
const EMBER := Color("#ff8a3d")
const ASH := Color("#8f8a86")
var sparks: Array[Dictionary] = []
var spark_rng := RandomNumberGenerator.new()
var glare := 0.0
var glare_ink := Color("#ffd9a8")
var hold := 0.0
var held_motion: StringName
var held_phase := 0.0
var jitter := Vector2.ZERO
var follow := Vector2.ZERO
var camera_limits := Vector2.ZERO
var hero_pose: Dictionary = Motion.REST
var floor_height := 0.0
var street_floor := SideArt.FLOOR
var lane_depth := SIDE_DEPTH
# 连战取景：推近、地面线压低、镜头沿长卷跑。原来叫 snow_pass，那时连战只有雪道一张图。
var route_view := false
# 当前地域的长卷（SideArt.plate_for），带地面线、远景雾色、天气与阴影色。
var plate: Dictionary = SideArt.FALLBACK_PLATE
var layer_travel := false
var snow_drift := 0.0
var backdrop := TextureRect.new()
var fog := GradientTexture2D.new()
var cut_in_left := 0.0
var cut_in_name := ""
# 天色：0 白天，0.5 黄昏，1 入夜。连战第一波是白天，第二波黄昏，层主在夜里；挂机按 DAY_LENGTH 一天一轮。
var daylight := 0.0
var day_clock := 0.0
var light := ShaderMaterial.new()
var atmosphere := ColorRect.new()
var near := Control.new()

func _ready() -> void:
	cutout = CutoutHero.new()
	add_child(cutout)
	cutout.dress(look)
	texture_filter = TEXTURE_FILTER_NEAREST
	spark_rng.randomize()
	backdrop.texture = SideArt.FALLBACK_PLATE.texture
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.texture_filter = TEXTURE_FILTER_LINEAR
	backdrop.show_behind_parent = true
	backdrop.mouse_filter = MOUSE_FILTER_IGNORE
	haze.shader = SNOW_HAZE
	haze.set_shader_parameter("floor_line", SideArt.SNOW_FLOOR)
	backdrop.material = haze
	add_child(backdrop)
	# 子节点的先后就是画的先后：长卷在本层的人物之下，然后是人物，再是最前面的剪影，最后一层天光。
	near.mouse_filter = MOUSE_FILTER_IGNORE
	near.set_anchors_preset(PRESET_FULL_RECT)
	near.draw.connect(_draw_near)
	add_child(near)
	light.shader = ATMOSPHERE
	atmosphere.material = light
	atmosphere.mouse_filter = MOUSE_FILTER_IGNORE
	atmosphere.set_anchors_preset(PRESET_FULL_RECT)
	add_child(atmosphere)
	var mist := Gradient.new()
	mist.offsets = PackedFloat32Array([0.0, 0.52, 1.0])
	mist.colors = PackedColorArray([Color("#92919400"), Color("#9291941c"), Color("#92919400")])
	fog.gradient = mist
	fog.width = 1
	fog.height = 128
	fog.fill_to = Vector2.DOWN
	resized.connect(_fit_stage)
	_fit_stage()

func set_camp_view(active: bool) -> void:
	camp_view = active
	layer_travel = false
	route_view = not active and run != null and run.continuous
	# 底图跟着地方走：旱村、疫城、矿山、边塞、泽国、上界各一条长卷。所有取景都加远景空气透视，
	# 人物和精怪因此从背景里跳出来。
	plate = SideArt.plate_for(run.dungeon_layer if run != null else 1)
	backdrop.texture = plate.texture
	haze.set_shader_parameter("floor_line", plate.floor)
	haze.set_shader_parameter("haze_color", plate.haze)
	var depth: float = plate.depth
	haze.set_shader_parameter("haze", 0.24 * depth)
	haze.set_shader_parameter("flatten", 0.16 * depth)
	haze.set_shader_parameter("desaturate", 0.24 * depth)
	haze.set_shader_parameter("screen", PIYING_SCREEN)
	street_floor = plate.floor
	lane_depth = 0.30 if route_view else SIDE_DEPTH
	follow = Vector2.ZERO
	shake = 0.0
	kick = Vector2.ZERO
	sparks.clear()
	glare = 0.0
	hold = 0.0
	cut_in_left = 0.0
	daylight = _target_daylight()
	_fit_stage()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	ash_time = fposmod(ash_time + delta, 120.0)
	if run != null:
		if run.companions > 0 and retinue == null:
			retinue = CutoutHero.new()
			add_child(retinue)
			retinue.dress(Appearance.bare())
		elif run.companions == 0 and retinue != null:
			retinue.queue_free()
			retinue = null
		snow_drift = fposmod(snow_drift + delta * (0.39 if run.advancing or layer_travel else 0.06), 4.0)
	_drain_pulses()
	_track_camera(delta)
	shake = maxf(0.0, shake - delta * (2.6 if camp_view else 1.7))
	kick = kick.lerp(Vector2.ZERO, 1.0 - exp(-delta * 20.0))
	_step_sparks(delta if run == null or run.hitstop <= 0.0 else delta * 0.15)
	glare = maxf(0.0, glare - delta * 4.2)
	hold = maxf(0.0, hold - delta)
	cut_in_left = maxf(0.0, cut_in_left - delta)
	shake_seed += delta * 47.0
	if camp_view:
		day_clock = fposmod(day_clock + delta, DAY_LENGTH)
	daylight = move_toward(daylight, _target_daylight(), delta * DAYLIGHT_PACE)
	_update_light()
	queue_redraw()
	near.queue_redraw()

func _target_daylight() -> float:
	if run == null:
		return 0.0
	if camp_view:
		var hour := day_clock / DAY_LENGTH
		if hour < 0.5:
			return 0.0
		if hour < 0.62:
			return smoothstep(0.5, 0.62, hour)
		if hour < 0.86:
			return 1.0
		return 1.0 - smoothstep(0.86, 1.0, hour)
	if run.continuous:
		return float(run.wave_index) / float(Combat.WAVE_SIZES.size() - 1)
	return 1.0 if run.challenging else 0.0

# 天色和主角身边那圈光交给 atmosphere.gdshader。白天整层天光关掉，省一次读屏。
func _update_light() -> void:
	if run == null or size.y <= 0.0:
		return
	var warm := clampf(1.0 - absf(daylight - 0.5) * 2.0, 0.0, 1.0)
	var dark := clampf((daylight - 0.45) / 0.55, 0.0, 1.0)
	if plate.get("ink", false):
		# 纸本场景保留墨线和中间调，天色仍随关卡变化。
		atmosphere.visible = warm > 0.01 or dark > 0.01 or PIYING_SCREEN > 0.0
		light.set_shader_parameter("grade", 0.0)
		light.set_shader_parameter("vignette", PIYING_VIGNETTE if PIYING_SCREEN > 0.0 else 0.10)
		light.set_shader_parameter("warm", warm * 0.12)
		light.set_shader_parameter("night", dark * 0.22)
		light.set_shader_parameter("aspect", size.x / size.y)
		return
	# 暗黑调色常开：白天也是阴天，压饱和、压暗、冷灰阴影，只留血色和火光。
	atmosphere.visible = GRADE > 0.0 or warm > 0.01 or dark > 0.01
	if not atmosphere.visible:
		return
	light.set_shader_parameter("grade", GRADE)
	light.set_shader_parameter("vignette", VIGNETTE_CAMP if camp_view else VIGNETTE)
	var body := world_offset + jitter + _floor(run.position) * scale_to_screen - Vector2(0.0, 40.0 * hero_pixels)
	light.set_shader_parameter("warm", warm * 0.85)
	light.set_shader_parameter("night", dark * 0.82)
	light.set_shader_parameter("lamp", body / size)
	light.set_shader_parameter("lamp_radius", 120.0 * hero_pixels / size.y)
	light.set_shader_parameter("aspect", size.x / size.y)

# 把战斗抛出的打击事件翻成画面反馈。挂机时一律减半，免得挂着挂着屏幕一直在抖。
func _drain_pulses() -> void:
	if run == null or run.pulses.is_empty():
		return
	var damp := 0.45 if camp_view else 1.0
	for pulse in run.pulses:
		var power: float = pulse.power
		if not camp_view and pulse.kind in [&"cast", &"stomp"]:
			cut_in_left = CUT_IN_TIME
			cut_in_name = "破阵" if pulse.kind == &"cast" else "震慑"
		# 打击方向：从主角指向挨打的一方；主角挨打时反过来。
		var origin: Vector2 = pulse.get("from", run.position)
		var away := Vector2(signf(pulse.pos.x - origin.x), 0.0)
		if away.x == 0.0:
			away = Vector2.RIGHT
		match pulse.kind:
			&"hit":
				_trauma(0.16 * power * damp, away, 2.4 * power * damp)
				_splash(pulse, away, 8 + roundi(power * 4.0), false)
			&"crit":
				_trauma(0.34 * power * damp, away, 5.0 * damp)
				_glare(Color("#ffd9a8"), 0.5 * damp)
				_splash(pulse, away, 12 + roundi(power * 4.0), true)
			&"kill":
				_trauma(0.24 * power * damp, away, 3.5 * damp)
				_cinders(pulse, away, 10 + roundi(power * 8.0))
			&"hurt":
				_trauma(0.42 * power * damp, Vector2(-signf(run.facing) if run.facing != 0.0 else -1.0, 0.0), 5.0 * damp)
				_glare(Color("#b3261c"), 0.9 * damp)
			&"stomp", &"quake":
				_trauma(0.5 * power * damp, Vector2.DOWN, 6.0 * damp)
			&"cast":
				_trauma(0.2 * power * damp, away, 0.0)
				_glare(run.trail_color, 0.22 * damp)
			&"revive":
				_glare(Color("#b6f0a8"), 0.7)
		if pulse.kind in [&"crit", &"hurt", &"quake"] and not run.motion.is_empty():
			hold = 0.055
			held_motion = run.motion
			held_phase = run.motion_time / maxf(run.motion_duration, 0.01)
	run.pulses.clear()

func _glare(ink: Color, amount: float) -> void:
	if amount <= glare:
		return
	glare = amount
	glare_ink = ink

func _trauma(amount: float, direction: Vector2, punch: float) -> void:
	shake = minf(1.0, shake + amount)
	shake_dir = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	kick += shake_dir * punch

# 普攻溅一小蓬暗红血雾，暴击多一倍还夹火星。顺着打击方向喷，带重力落地。
func _splash(pulse: Dictionary, away: Vector2, count: int, heavy: bool) -> void:
	var height := float(pulse.get("height", 48.0))
	var at := _floor(pulse.pos) - Vector2(away.x * height * 0.18, height * 0.55) * FOE_SCALE * actor_zoom
	for i in range(count):
		var angle := spark_rng.randf_range(-0.9, 0.45)
		var speed := spark_rng.randf_range(70.0, 190.0) * (1.35 if heavy else 1.0)
		var velocity := Vector2(cos(angle) * away.x, sin(angle)) * speed
		var ember := heavy and i % 3 == 0
		_spark(at, velocity, spark_rng.randf_range(0.28, 0.55), EMBER if ember else (ICHOR if i % 2 else ICHOR_DARK),
			spark_rng.randf_range(3.0, 6.0) if not ember else 3.0, 0.0 if ember else 520.0, ember)

# 倒下化灰：一阵往上飘的火星和灰片，扣「余烬」这个题。
func _cinders(pulse: Dictionary, away: Vector2, count: int) -> void:
	var height := float(pulse.get("height", 48.0))
	var at := _floor(pulse.pos) - Vector2(0.0, height * 0.4) * FOE_SCALE * actor_zoom
	for i in range(count):
		var spread := Vector2(spark_rng.randf_range(-0.5, 0.5) * height, spark_rng.randf_range(-0.4, 0.4) * height) * actor_zoom
		var velocity := Vector2(away.x * spark_rng.randf_range(10.0, 70.0), -spark_rng.randf_range(40.0, 120.0))
		var ember := i % 2 == 0
		_spark(at + spread, velocity, spark_rng.randf_range(0.6, 1.2), EMBER if ember else ASH,
			spark_rng.randf_range(2.0, 3.5), -30.0, ember)

func _spark(at: Vector2, velocity: Vector2, life: float, ink: Color, pixels: float, gravity: float, glow: bool) -> void:
	if sparks.size() >= MAX_SPARKS:
		sparks.remove_at(0)
	sparks.append({"pos": at, "vel": velocity, "life": life, "total": life, "ink": ink, "size": pixels,
		"gravity": gravity, "glow": glow})

func _step_sparks(delta: float) -> void:
	if sparks.is_empty() or delta <= 0.0:
		return
	for spark in sparks:
		spark.life -= delta
		spark.vel = spark.vel * exp(-delta * 2.2) + Vector2(0.0, spark.gravity * delta)
		spark.pos += spark.vel * delta
	sparks = sparks.filter(func(spark: Dictionary) -> bool: return spark.life > 0.0)

## 火花：全部攒成一个三角形列表一次画完（原来每颗火花的光晕和亮点各画一次）
func _draw_sparks() -> void:
	_world_transform()
	if sparks.is_empty():
		return
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for spark in sparks:
		var fade: float = clampf(spark.life / spark.total, 0.0, 1.0)
		var ink: Color = spark.ink
		var pixels: float = spark.size * (0.6 + 0.4 * fade)
		var p: Vector2 = spark.pos
		if spark.glow:
			var glow := Color(ink, 0.18 * fade)
			var r := pixels * 2.2
			for k in range(10):
				pts.append_array([p, p + Vector2.from_angle(TAU * k / 10.0) * r, p + Vector2.from_angle(TAU * (k + 1) / 10.0) * r])
				cols.append_array([glow, glow, glow])
			ink = ink.lerp(Color("#ffd28a"), fade * 0.5)
		var c := Color(ink, fade)
		var h := pixels * 0.5
		if PIYING_SCREEN > 0.0:
			# 皮影戏：碎屑是剪纸的菱形小片，飞的时候翻转（宽窄跟着翻）
			var spin: float = spark.life * 9.0 + spark.total * 13.0
			var long := Vector2.from_angle(spin) * h * 1.6
			var wide := Vector2.from_angle(spin + PI * 0.5) * h * (0.35 + 0.65 * absf(sin(spin * 1.7)))
			pts.append_array([p - long, p + wide, p + long, p - long, p + long, p - wide])
		else:
			pts.append_array([p + Vector2(-h, -h), p + Vector2(h, -h), p + Vector2(h, h), p + Vector2(-h, -h), p + Vector2(h, h), p + Vector2(-h, h)])
		cols.append_array([c, c, c, c, c, c])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), PackedInt32Array(), pts, cols)

## 皮影布景：远山一排连着铺在最后面；前面每隔一段按种子摆一件（树、亭台、民房、石桥、枯树），
## 有的位置空着。同一层每次进来摆法一样（种子取自层数）。都贴着画面坐标画，底边落在台口（地面线）稍后
func _draw_scenery() -> void:
	if PIYING_SCREEN <= 0.0 or size.y <= 0.0:
		return
	draw_set_transform(Vector2.ZERO)
	var base := floor_height - size.y * 0.012 + jitter.y
	var layer_seed: int = (run.dungeon_layer if run != null else 1) * 131
	for spec in SCENERY:
		if not _scenery_tex.has(spec[0]):
			var path: String = SCENERY_DIR + spec[0] + ".png"
			_scenery_tex[spec[0]] = load(path) if ResourceLoader.exists(path) else null
	# 远山：一张接一张铺满，走得最慢
	var hills: Texture2D = _scenery_tex.mountains
	if hills != null:
		var h: float = size.y * float(SCENERY[0][1])
		var w := h * hills.get_width() / hills.get_height()
		var shift := fposmod(-follow.x * scale_to_screen * float(SCENERY[0][2]) + jitter.x, w)
		var x := shift - w
		while x < size.x:
			draw_texture_rect(hills, Rect2(x, base - h, w, h), false, SCENERY_FAR_INK)
			x += w
	# 近一层的景物：按格子摆，每格最多一件
	var spacing := size.y * 0.30
	var parallax: float = SCENERY[1][2]
	var offset := -follow.x * scale_to_screen * parallax + jitter.x
	var first := floori((-offset - spacing * 2.0) / spacing)
	var last := ceili((size.x - offset + spacing) / spacing)
	var total := 0.0
	for spec in SCENERY.slice(1):
		total += float(spec[3])
	for i in range(first, last + 1):
		var r := _hash(i + layer_seed)
		if r < 0.45:
			continue
		var pick := _hash(i * 7 + layer_seed + 3) * total
		var spec: Array = SCENERY[1]
		for s in SCENERY.slice(1):
			pick -= float(s[3])
			if pick <= 0.0:
				spec = s
				break
		var tex: Texture2D = _scenery_tex.get(spec[0])
		if tex == null:
			continue
		var h: float = size.y * float(spec[1]) * (0.85 + 0.3 * _hash(i + layer_seed + 11))
		var w := h * tex.get_width() / tex.get_height()
		var flip := -1.0 if _hash(i + layer_seed + 29) < 0.5 else 1.0
		var x := i * spacing + offset + (_hash(i + layer_seed + 17) - 0.5) * spacing * 0.6
		draw_set_transform(Vector2(x, base), 0.0, Vector2(flip, 1.0))
		draw_texture_rect(tex, Rect2(-w * 0.5, -h, w, h), false, SCENERY_INK)
	draw_set_transform(Vector2.ZERO)

func _fit_stage() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var wide := size.x >= size.y * 1.17
	var stage_height := 435.0 if route_view else (590.0 if camp_view else 510.0)
	var zoom := (LANDSCAPE_BATTLE_ZOOM if wide else PORTRAIT_BATTLE_ZOOM) if route_view else 1.0
	scale_to_screen = minf(size.x / (445.0 if camp_view else 414.0), size.y / stage_height) * zoom
	# 取景按原来的地面线算，推近后再把地面线挪到新位置。
	var framing_floor := size.y * ((0.79 if wide else 0.72) if route_view else (0.755 if wide else 0.70))
	var portrait_battle := route_view and not wide
	floor_height = size.y * PORTRAIT_BATTLE_FLOOR if portrait_battle else framing_floor
	world_center_x = PORTRAIT_BATTLE_CENTER_X if portrait_battle else WORLD_CENTER_X
	var native := backdrop.texture.get_size()
	var margin := 340.0 if route_view else 104.0
	# 地面锚点对齐角色脚底，同时覆盖地面上、下两段视口。
	var framing := maxf(framing_floor / street_floor, (size.y - framing_floor) / (1.0 - street_floor))
	var cover := maxf(floor_height / street_floor, (size.y - floor_height) / (1.0 - street_floor))
	var backdrop_scale := maxf(maxf((size.x + margin) / native.x, framing / native.y) * zoom, cover / native.y)
	var street_size := native * backdrop_scale
	# 人物随原画缩放，战斗坐标仍使用原来的投影。窄屏至少容下两个人物分格（推近时同比放宽）。
	var art_scale := SideArt.SNOW_ACTOR_SCALE if route_view else SideArt.STREET_ACTOR_SCALE
	if wide:
		art_scale *= LANDSCAPE_ACTOR_MAGNIFICATION
	hero_pixels = minf(street_size.y * art_scale, size.x / (2.0 * SideArt.CELL.x) * zoom)
	hero_pixels *= art_review_scale
	actor_zoom = hero_pixels / (HERO_SCALE * scale_to_screen)
	# 地面和脚底共用同一段镜头位移，图片边缘同时限制镜头的行程。
	var overflow := street_size.x - size.x
	# 一个地域十层沿长卷从左走到右（SideArt.plate_progress）。连战每层还要留出自己两段波距加过层的行程给镜头。
	var progress := SideArt.plate_progress(run.dungeon_layer) if run != null else 0.0
	var initial_left: float
	if route_view:
		var edge := street_size.x * float(plate.margin)
		var start := maxf(minf(76.0 * scale_to_screen, overflow * 0.20), edge)
		var stride := minf(overflow, (Combat.WAVE_SPACING * 2.0 + 160.0) * scale_to_screen)
		initial_left = -lerpf(start, maxf(start, overflow - stride - edge), progress)
	else:
		initial_left = -overflow * lerpf(0.06, 0.94, progress)
	if plate.get("ink", false):
		initial_left = -overflow * lerpf(0.34, 0.66, progress)
	camera_limits = Vector2(initial_left, initial_left + overflow) / scale_to_screen
	follow.x = clampf(follow.x, camera_limits.x, camera_limits.y)
	var anchor := Vector2(world_center_x + follow.x, Combat.HOME.y)
	world_offset = Vector2(size.x * 0.5, floor_height) - anchor * scale_to_screen
	backdrop.position = Vector2(initial_left - follow.x * scale_to_screen, floor_height - street_size.y * street_floor)
	backdrop.size = street_size
	queue_redraw()

# 交手时停住镜头。换波跑图或主角靠近画面边缘时才移动。
func _track_camera(delta: float) -> void:
	if camp_view or run == null:
		return
	var wish: float
	var traveling := run.advancing or layer_travel
	if traveling:
		wish = clampf(run.position.x - Combat.HOME.x, run.section_x, run.section_x + Combat.WAVE_SPACING)
	else:
		var band := maxf(24.0, size.x * 0.5 / scale_to_screen - 56.0)
		var relative_x := run.position.x - (world_center_x + follow.x)
		wish = follow.x + relative_x - clampf(relative_x, -band, band)
	wish = clampf(wish, camera_limits.x, camera_limits.y)
	if absf(wish - follow.x) < 0.02:
		return
	follow.x = wish if traveling else lerpf(follow.x, wish, clampf(delta * 3.2, 0.0, 1.0))
	_fit_stage()

func _draw() -> void:
	if run == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var amplitude := SHAKE_PIXELS * pow(shake, SHAKE_EXPONENT)
	var along := sin(shake_seed * 2.9) + 0.5 * sin(shake_seed * 6.1 + 1.3)
	var across := cos(shake_seed * 3.7) + 0.4 * sin(shake_seed * 7.9)
	var perpendicular := Vector2(-shake_dir.y, shake_dir.x)
	jitter = ((shake_dir * along * 0.7 + perpendicular * across * 0.35) * amplitude + kick) * scale_to_screen
	_draw_mist()
	_draw_scenery()
	_world_transform()
	_draw_telegraphs()
	_draw_drops()
	for fallen in run.fallen_enemies:
		_draw_fallen_enemy(fallen)
	_draw_retinue()

	var actors: Array[Dictionary] = [{"pos": run.position, "hero": true}]
	for enemy in run.enemies:
		if enemy.spawn <= 0.0 and enemy.hp > 0:
			actors.append(enemy)
	actors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pos.y < b.pos.y)
	for actor in actors:
		if actor.has("hero"):
			_draw_hero()
		else:
			_draw_enemy(actor)

	for shot in run.shots:
		_draw_projectile(shot)
	for effect in run.effects:
		_draw_effect(effect)
	_draw_sparks()
	var font := get_theme_default_font()
	for popup in run.popups:
		var opacity := minf(popup.life * 3.0, 1.0)
		var critical: bool = popup.get("critical", false)
		var pixels := 25 if critical else 20
		var ink := Color("#ffcb75", opacity) if critical else Color(1.0, 0.87, 0.65, opacity)
		var height := float(popup.get("height", 0.0)) * FOE_SCALE * actor_zoom
		var origin := _floor(popup.pos) - Vector2(0, height + 18.0) + Vector2(popup.get("offset", Vector2.ZERO))
		var center := origin - Vector2(font.get_string_size(popup.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x * 0.5, 0.0)
		if popup.has("material"):
			var item := Gear.material(popup.material)
			draw_texture_rect_region(ForgeArt.ATLAS, Rect2(origin - Vector2(24, 19), Vector2(23, 23)), ForgeArt.region(item.icon), Color(1, 1, 1, opacity))
			pixels = 16
			ink = Color(item.tint, opacity)
			center = origin
		# 挂机画面整体发虚，伤害数字加一块描边衬底才读得出来；手操时只描边，别挡视野。
		var rise := (1.0 - minf(popup.life / 0.6, 1.0))
		var lifted := center - Vector2(0.0, rise * 4.0)
		if camp_view:
			var text_width := font.get_string_size(popup.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
			var plate := Rect2(lifted.x - 5.0, lifted.y - font.get_ascent(pixels) - 2.0, text_width + 10.0, font.get_height(pixels) + 4.0)
			draw_rect(plate, Color(0.07, 0.06, 0.065, 0.70 * opacity))
		draw_string_outline(font, lifted, popup.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, 5 if critical else 4,
			Color(0.08, 0.05, 0.10, opacity))
		draw_string(font, lifted, popup.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, ink)
	match StringName(plate.weather):
		&"snow": _draw_snow()
		&"rain": _draw_rain()
		var kind: _draw_motes(kind)
	_draw_glare()
	_draw_combo()
	_draw_cut_in()

func _draw_cut_in() -> void:
	if cut_in_left <= 0.0 or run.advancing or layer_travel:
		return
	draw_set_transform(Vector2.ZERO)
	var elapsed := CUT_IN_TIME - cut_in_left
	var alpha := minf(elapsed / 0.05, 1.0) * minf(cut_in_left / 0.17, 1.0)
	var wide := size.x >= size.y * 1.17
	var portrait: Texture2D = SideArt.portrait(look.get("gender", ""))
	var width := minf(size.x * 0.20, 260.0) if wide else size.x * 0.24
	var height := width * portrait.get_height() / portrait.get_width()
	var x := 18.0 - 24.0 * (1.0 - alpha)
	var y := floor_height - height * 0.78 if wide else floor_height - height * 0.22
	draw_texture_rect(portrait, Rect2(x, y, width, height), false, Color(Color.WHITE, alpha * 0.88))
	var font := get_theme_default_font()
	var label := Vector2(x + width * 0.16, y + height * 0.90)
	var pixels := 32 if wide else 18
	draw_string_outline(font, label, cut_in_name, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, 6, Color("#1a1113", alpha))
	draw_string(font, label, cut_in_name, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, Color("#ffe1ae", alpha))

func _draw_combo() -> void:
	if camp_view or run.advancing or layer_travel or run.combo_hits < 2:
		return
	draw_set_transform(Vector2.ZERO)
	var font := get_theme_default_font()
	var n := str(run.combo_hits)
	var alpha := clampf(run.combo_left / 0.33, 0.0, 1.0)
	var lift := clampf((run.combo_left - Combat.COMBO_WINDOW + 0.14) / 0.14, 0.0, 1.0)
	var digits := 40 + roundi(lift * 6.0)
	const LABEL_SIZE := 17
	var caption := "连击"
	var width := font.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, digits).x
	var caption_width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
	# 放在人物头顶之上，镜头推近后也不压住精怪。
	var head := (SideArt.PIVOT.y - 12.0) * hero_pixels
	var anchor := Vector2(size.x * 0.87 - width - caption_width - 8.0, floor_height - head - 22.0 - lift * 5.0)
	draw_string_outline(font, anchor, n, HORIZONTAL_ALIGNMENT_LEFT, -1, digits, 5, Color("#1a1113", alpha))
	draw_string(font, anchor, n, HORIZONTAL_ALIGNMENT_LEFT, -1, digits, Color("#ffd697", alpha))
	var label := anchor + Vector2(width + 7.0, -2.0)
	draw_string_outline(font, label, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, 4, Color("#1a1113", alpha))
	draw_string(font, label, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, Color("#ead9be", alpha))

func _draw_mist() -> void:
	draw_set_transform(Vector2.ZERO)
	var mist_y := floor_height - size.y * (0.21 + 0.017 * sin(ash_time * 0.52))
	draw_texture_rect(fog, Rect2(0.0, mist_y, size.x, size.y * 0.16), false)

# 受击与暴击时从画面四边压进来的一层色，比整屏变色更不碍眼。
func _draw_glare() -> void:
	var strength := clampf(glare, 0.0, 1.0)
	var ink := glare_ink
	# 残血时四边一直压着一层红，并且会呼吸，不用盯着血条也知道快没了。
	if not camp_view and run != null and run.hp * 3 < run.max_hp:
		var danger := (1.0 - float(run.hp) * 3.0 / float(run.max_hp)) * (0.46 + 0.18 * sin(ash_time * 4.6))
		if danger > strength:
			strength = danger
			ink = Color("#d8604e")
	if strength <= 0.01:
		return
	draw_set_transform(Vector2.ZERO)
	var depth := minf(size.y * 0.22, 118.0)
	var bands := 7
	for i in range(bands):
		var ratio := float(i) / bands
		var alpha := 0.16 * strength * (1.0 - ratio)
		var inset := depth * ratio
		var thickness := depth / bands + 1.0
		draw_rect(Rect2(0.0, inset, size.x, thickness), Color(ink, alpha))
		draw_rect(Rect2(0.0, size.y - inset - thickness, size.x, thickness), Color(ink, alpha))
		draw_rect(Rect2(inset, 0.0, thickness, size.y), Color(ink, alpha * 0.7))
		draw_rect(Rect2(size.x - inset - thickness, 0.0, thickness, size.y), Color(ink, alpha * 0.7))

# 前景飘的东西随地域换：疫与兵灾是灰烬夹火星，旱是热尘，矿是煤尘，上界是云絮。
# ash 的参数就是原来 _draw_ash 的数值，换图之前的挂机画面不变。
const MOTES := {
	&"ash": {"count": 24, "ink": Color("#b1b7c1"), "ember": Color("#ed9c5d"), "rise": 1.0, "size": 1.0},
	&"dust": {"count": 22, "ink": Color("#d9c39a"), "ember": Color("#f4e2b8"), "rise": 0.55, "size": 1.15},
	&"grit": {"count": 28, "ink": Color("#8d9196"), "ember": Color("#c9a46a"), "rise": 0.35, "size": 0.9},
	&"mist": {"count": 14, "ink": Color("#eef3fa"), "ember": Color("#ffffff"), "rise": 0.22, "size": 2.8},
}

func _draw_motes(kind: StringName) -> void:
	var motes: Dictionary = MOTES.get(kind, MOTES[&"ash"])
	var rise: float = motes.rise
	var grain: float = motes.size
	draw_set_transform(Vector2.ZERO)
	for i in range(int(motes.count)):
		var drift := float(i) * 0.61803399
		var x := fposmod(drift + sin(i * 2.48 + ash_time * 0.40) * 0.048, 1.0)
		var path := fposmod(i * 0.346 - ash_time * (0.034 + (i % 3) * 0.012) * rise, 1.0)
		var point := Vector2(x * size.x, (0.89 - path * 0.72) * size.y)
		var ember := i % 4 == 0
		var alpha := sin(path * PI) * (0.52 if ember else 0.24)
		var ink: Color = motes.ember if ember else motes.ink
		if ember:
			draw_circle(point, 3.1 * grain, Color(ink, alpha * 0.15), true, -1.0, true)
		draw_circle(point, (1.25 if ember else 0.72) * grain, Color(ink, alpha), true, -1.0, true)

# 江淮泽国的斜雨。
func _draw_rain() -> void:
	draw_set_transform(Vector2.ZERO)
	for i in range(46):
		var u := fposmod(i * 0.618 + ash_time * 0.05, 1.0)
		var v := fposmod(i * 0.371 + ash_time * (0.9 + float(i % 4) * 0.18), 1.0)
		var top := Vector2(u * size.x, v * size.y * 1.1 - size.y * 0.05)
		var length := 16.0 + float(i % 5) * 7.0
		draw_line(top, top + Vector2(-length * 0.28, length), Color("#c9d6dc", 0.16 + float(i % 3) * 0.06), 1.0, true)

func _draw_snow() -> void:
	draw_set_transform(Vector2.ZERO)
	var running := run.advancing or layer_travel
	for i in range(35):
		var u := fposmod(i * 0.618 - snow_drift * (1.0 + float(i % 4) * 0.25), 1.0)
		var v := fposmod(i * 0.346 + ash_time * (0.045 + float(i % 3) * 0.012), 1.0)
		var point := Vector2(u * size.x, v * size.y)
		var bright := sin(u * PI) * (0.34 if i % 4 == 0 else 0.19)
		var ink := Color("#deeff5", bright)
		if running and i % 3 == 0:
			var length := 22.0 + float(i % 5) * 11.0
			draw_line(point, point + Vector2(length, -3), Color(ink, bright * 0.72), 1.1, true)
		else:
			draw_circle(point, 1.6 if i % 4 == 0 else 0.85, ink, true, -1.0, true)

# 镜头最前面那层剪影：沿画面底边一丛一丛，比长卷走得快，人和精怪就夹在两层中间。
# 每丛的样子由序号算出来，镜头怎么走都是同一片草。
## 这一层的所有叶片、穗头、石头、云团先攒成一个三角形列表，最后一次画完（原来每片叶子一次绘制，一屏一百多次）
var _near_pts := PackedVector2Array()
var _near_cols := PackedColorArray()


func _draw_near() -> void:
	if run == null or size.x <= 0.0:
		return
	_near_pts.clear()
	_near_cols.clear()
	_collect_near()
	if not _near_pts.is_empty():
		RenderingServer.canvas_item_add_triangle_array(near.get_canvas_item(), PackedInt32Array(), _near_pts, _near_cols)


func _near_tri(a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	_near_pts.append_array([a, b, c])
	_near_cols.append_array([color, color, color])


## 扇形（凸的轮廓，从中心连到一圈点）
func _near_fan(center: Vector2, ring: PackedVector2Array, color: Color, closed: bool) -> void:
	for k in range(ring.size() if closed else ring.size() - 1):
		_near_tri(center, ring[k], ring[(k + 1) % ring.size()], color)


## 椭圆：圆心、半径、拉伸、旋转
func _near_ellipse(center: Vector2, radius: float, stretch: Vector2, angle: float, color: Color, sides := 12) -> void:
	var ring := PackedVector2Array()
	for k in range(sides):
		var a := TAU * k / sides
		ring.append(center + (Vector2(cos(a), sin(a)) * radius * stretch).rotated(angle))
	_near_fan(center, ring, color, true)


func _collect_near() -> void:
	var kind: StringName = plate.get("near", &"grass")
	var ink: Color = plate.get("near_ink", Color("#1d1c17"))
	var dark := clampf((daylight - 0.45) / 0.55, 0.0, 1.0)
	var unit := minf(size.x, size.y) / 390.0
	var spacing := 46.0 * unit
	var shift := -follow.x * scale_to_screen * NEAR_PARALLAX + jitter.x
	var first := floori((-shift - spacing * 2.0) / spacing)
	var last := ceili((size.x - shift + spacing * 2.0) / spacing)
	for i in range(first, last + 1):
		var seed := _hash(i)
		if seed < 0.38:
			continue
		var x := i * spacing + shift + (_hash(i + 71) - 0.5) * spacing * 0.8
		match kind:
			&"rock":
				_near_rock(x, seed, unit, ink)
			&"cloud":
				_near_cloud(x, seed, unit, Color(ink.lerp(Color("#5a6a90"), dark * 0.7), 1.0 - dark * 0.45))
			_:
				_near_blades(x, seed, unit, ink, kind == &"reed")

# 一丛草：每片叶子从根部斜出去再顺风弯下来，叶尖随风摆。外面先描一圈淡的，像镜头没对上焦。
func _near_blades(x: float, seed: float, unit: float, ink: Color, reed: bool) -> void:
	var count := (6 if reed else 9) + int(seed * 6.0)
	var reach := ((44.0 + 50.0 * _hash(int(seed * 9973.0))) if reed else (18.0 + 30.0 * _hash(int(seed * 9973.0)))) * unit
	# 一阵风过来，整丛往同一边倒，各片叶子再各自错开一点。
	var wind := 0.18 + 0.14 * sin(ash_time * 0.9 + x * 0.006)
	for j in range(count):
		var pick := _hash(int(seed * 7919.0) + j)
		var tall := reach * (0.35 + 0.65 * pick)
		var lean := (float(j) / maxf(count - 1, 1) - 0.5) * (0.55 if reed else 0.9) + (pick - 0.5) * 0.3
		var bend := wind + 0.28 * pick * pick + sin(ash_time * 1.7 + j * 1.3 + x * 0.02) * 0.03
		var base := Vector2(x + lean * 14.0 * unit, size.y + 4.0)
		var width := (1.3 if reed else 0.9 + 0.8 * pick) * unit
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		for k in range(6):
			var t := float(k) / 5.0
			var point := base + Vector2((lean * 0.5 * t + bend * t * t) * tall, -tall * t * (1.0 - 0.3 * bend * t))
			var w := width * (1.0 - t * 0.9)
			left.append(point - Vector2(w, 0.0))
			right.append(point + Vector2(w, 0.0))
		var color := Color(ink, 0.88 if reed else 0.78)
		for k in range(5):  # 叶片是一条从根到尖的带子，每段两个三角形
			_near_tri(left[k], right[k], right[k + 1], color)
			_near_tri(left[k], right[k + 1], left[k + 1], color)
		if reed and pick > 0.66:
			var head := left[4].lerp(right[4], 0.5)
			_near_ellipse(head, 1.9 * unit, Vector2(1.0, 3.2), lean * 0.5 + bend * 0.9, Color(ink.lightened(0.1), 0.9), 10)

func _near_rock(x: float, seed: float, unit: float, ink: Color) -> void:
	var wide := (22.0 + 30.0 * seed) * unit
	var tall := wide * (0.45 + 0.3 * _hash(int(seed * 613.0)))
	var points := PackedVector2Array()
	for k in range(11):
		var angle := PI + PI * float(k) / 10.0
		var bump := 0.82 + 0.18 * _hash(int(seed * 331.0) + k)
		points.append(Vector2(x + cos(angle) * wide * bump, size.y + 6.0 + sin(angle) * tall * bump))
	_near_fan(Vector2(x, size.y + 6.0), points, Color(ink, 0.94), false)

func _near_cloud(x: float, seed: float, unit: float, ink: Color) -> void:
	var drift := sin(ash_time * 0.21 + seed * 9.0) * 14.0 * unit
	for k in range(5):
		var r := (16.0 + 26.0 * _hash(int(seed * 211.0) + k)) * unit
		var point := Vector2(x + drift + (float(k) - 2.0) * r * 1.3, size.y - r * 0.15 - (k % 2) * 8.0 * unit)
		_near_ellipse(point, r * 1.4, Vector2(2.4, 1.0), 0.0, Color(ink, ink.a * 0.06), 20)
		_near_ellipse(point, r, Vector2(2.4, 1.0), 0.0, Color(ink, ink.a * 0.11), 20)

static func _hash(n: int) -> float:
	return fposmod(sin(float(n) * 12.9898 + 78.233) * 43758.5453, 1.0)

func _world_transform() -> void:
	draw_set_transform(world_offset + jitter, 0.0, Vector2.ONE * scale_to_screen)

func _at_actor(point: Vector2, facing: float, actor_scale: float, lean := 0.0) -> void:
	draw_set_transform(world_offset + jitter + point * scale_to_screen, lean * facing,
		Vector2(facing, 1.0) * scale_to_screen * actor_scale)
# 保留前后走位的区分，同时让角色踩在同一条侧视石街上。
func _floor(point: Vector2) -> Vector2:
	return Vector2(point.x, lerpf(Combat.HOME.y, point.y, lane_depth))

func _step_vector() -> Vector2:
	return run.step_direction * Vector2(1.0, lane_depth)

func _hero_pose() -> Dictionary:
	if run.motion == &"":
		return Motion.REST if run.stride > 0.0 else Motion.idle(ash_time)
	var phase := run.motion_time / maxf(run.motion_duration, 0.01)
	# 顿感：重击瞬间把动作停在原地几十毫秒，打击更实。
	if hold > 0.0 and held_motion == run.motion:
		phase = minf(phase, held_phase)
	if run.motion == &"attack" and Combat.BLADE_CUES.has(run.weapon_form):
		return Motion.flurry(phase, run.attack_cues())
	if run.motion in [&"skill", &"tactic"]:
		phase = lerpf(0.30, 1.0, phase)
	return Motion.sample(Motion.clip_for(run.motion, run.weapon_form), phase)

func _drive_cutout(running: bool) -> void:
	cutout.fit(scale_to_screen * HERO_SCALE * actor_zoom, get_viewport().get_final_transform().get_scale().x)
	var phase := run.motion_time / maxf(run.motion_duration, 0.01)
	if hold > 0.0 and held_motion == run.motion:
		phase = minf(phase, held_phase)
	var walked := run.stride * _step_vector().length() * scale_to_screen
	cutout.drive(run.motion, phase, walked, running, run.attack_cues())

func _draw_hero() -> void:
	var base := _floor(run.position)
	var hero_scale := HERO_SCALE * actor_zoom
	var facing := -1.0 if cos(run.facing) < 0.0 else 1.0
	hero_pose = _hero_pose()
	var running := run.advancing or layer_travel
	_drive_cutout(running)
	var retreating := run.motion == &"retreat" and run.dodge_moves
	var shift_x := 0.56 * facing if retreating else 0.0
	var nudge := Vector2(hero_pose.shift) * Vector2(shift_x, 0.44)
	var point := base + nudge
	var gait := {}
	if run.motion.is_empty() and run.stride > 0.0:
		if absf(run.step_direction.x) > 0.15:
			facing = signf(run.step_direction.x)
		gait = SideArt.step_trace(run.stride, hero_scale, running)
	var ink: Color = Roster.ELEMENT_TINTS.get(hero_element, Color.WHITE).lerp(Color.WHITE, 0.88)
	ink = ink.lerp(Color(1.45, 1.32, 1.22), float(hero_pose.flash) * 0.60)
	ink.a = float(hero_pose.fade)
	_shadow(base + Vector2(nudge.x, 0.0), Vector2(25, 4) * actor_zoom, plate.shadow)
	if plate.weather == &"snow" and running and not gait.is_empty():
		var stamp := base + _step_vector() * float(gait.plant)
		for i in range(3):
			if run.stride < i * float(gait.step_length):
				break
			var age := (float(gait.phase) + i) / 3.0
			var origin := stamp - _step_vector() * (i * float(gait.step_length))
			_shadow(origin + Vector2(0.0, 1.4), Vector2(5.0, 1.6), Color("#58718d", 0.30 * (1.0 - age)))
			for flake in range(2):
				var offset := Vector2(-age * (10.0 + flake * 4.0), -sin(age * PI) * (5.0 + flake * 3.0))
				draw_circle(origin + offset, 2.3 - age, Color("#f2f7ff", 0.66 * (1.0 - age)), true, -1.0, true)
	if run.shield > 0.0:
		_arc(base, Vector2(26, 5) * actor_zoom, ash_time * 2.2, 2.4, 1.0, Color("#d1fba3af"))
	var rig := Rig.new(world_offset + jitter + point * scale_to_screen, scale_to_screen * hero_scale, facing,
		69.0, 52.0, Motion.REST)
	draw_set_transform(Vector2.ZERO)
	Figure.halo(self, rig, look, ash_time)
	_draw_cutout_hero(point, facing, ink, retreating)
	_draw_hero_aura(rig)

# 皮影主角：残影、本体都是同一块画布，错开、压淡贴几次。
func _draw_cutout_hero(point: Vector2, facing: float, ink: Color, retreating: bool) -> void:
	var feet := world_offset + jitter + point * scale_to_screen
	var unit := scale_to_screen * HERO_SCALE * actor_zoom
	if float(hero_pose.ghost) > 0.1 and (run.motion != &"retreat" or retreating):
		var offset := 13.0 if run.motion == &"retreat" else -10.0
		if float(hero_pose.ghost) > 0.65 and run.motion == &"attack":
			cutout.draw(self, feet, facing, Color(look.trim, float(hero_pose.ghost) * 0.12), Vector2(offset * 2.1 * unit, 0))
		cutout.draw(self, feet, facing, Color(look.trim, float(hero_pose.ghost) * 0.23), Vector2(offset * unit, 0))
	cutout.draw(self, feet, facing, ink)

func _draw_hero_aura(rig: Rig) -> void:
	Figure.hands(self, rig, look)
	Figure.dust(self, rig, look, ash_time)
	_world_transform()

# 官宦随侍按战斗数值绘制，共用一套刀客模型和动作。
func _draw_retinue() -> void:
	if retinue == null:
		return
	var spread := route_view and size.x >= size.y * 1.17
	var running := run.advancing or layer_travel
	var facing := -1.0 if run.step_direction.x < -0.15 else 1.0
	var motion := &"attack" if not running and run.companion_left >= 0.65 else &""
	var phase := lerpf(0.48, 1.0, clampf((0.75 - run.companion_left) / 0.10, 0.0, 1.0))
	var stride := run.stride * _step_vector().length() * scale_to_screen
	retinue.fit(scale_to_screen * actor_zoom * 0.9, get_viewport().get_final_transform().get_scale().x)
	retinue.drive(motion, phase, stride, running, [0.48])
	for index in range(run.companions):
		var offset := Vector2(56.0 + index * 44.0, 9.0 - index * 14.0) if spread else Vector2(42.0 + index * 28.0, 2.0 - index * 2.0)
		var point := _floor(run.position) - offset
		_shadow(point, Vector2(17, 3) * actor_zoom, Color("#0c090ab8"))
		retinue.draw(self, world_offset + jitter + point * scale_to_screen, facing, Color("#929896e0"))
		_world_transform()

func _draw_enemy(enemy: Dictionary) -> void:
	var point := _floor(enemy.pos)
	var height: float = enemy.stats.size
	var foe_scale := FOE_SCALE * actor_zoom
	var tint: Color = Roster.ELEMENT_GLOW[Gear.WuXing.stem_element(run.encounter_stem)]
	var facing := -1.0 if enemy.pos.x > run.position.x else 1.0
	var frame := MonsterArt.live_frame(enemy)
	var art := MonsterArt.variant(enemy.art, run.encounter_stem)
	_shadow(point, Vector2(height * 0.30, height * 0.052) * actor_zoom, plate.shadow)
	_at_actor(point, facing, foe_scale)
	var flash := pow(clampf((enemy.hit - 0.04) / 0.11, 0.0, 1.0), 1.7)
	var ink := Color.WHITE.lerp(tint, 0.16).lerp(Color(1.52, 1.40, 1.32), flash)
	MonsterArt.draw_frame(self, art, frame, height, ink)
	_world_transform()
	if enemy.hit > 0.0 and not enemy.boss:
		var width := 34.0
		var origin := point - Vector2(width / 2.0, height * foe_scale + 8.0)
		draw_rect(Rect2(origin - Vector2.ONE, Vector2(width + 2.0, 5.0)), Color("#241b37"))
		draw_rect(Rect2(origin, Vector2(width * float(enemy.hp) / float(enemy.max_hp), 3.0)), Color("#f0a580"))

func _draw_fallen_enemy(fallen: Dictionary) -> void:
	# 被打飞一段再落地；身子从受击的颜色烧成焦黑，最后化灰淡掉。
	var flight := 1.0 - exp(-float(fallen.age) * 9.0)
	var launch: Vector2 = fallen.get("launch", Vector2.ZERO)
	var point := _floor(fallen.pos + launch * flight)
	var height: float = fallen.height
	var art := MonsterArt.variant(fallen.art, run.encounter_stem)
	var alpha := 1.0 - smoothstep(Combat.ENEMY_DEATH_DURATION, Combat.ENEMY_DEATH_LIFETIME, fallen.age)
	var tint: Color = Roster.ELEMENT_GLOW[Gear.WuXing.stem_element(run.encounter_stem)]
	_shadow(point, Vector2(height * 0.34, height * 0.05) * actor_zoom, Color("#0c090a", 0.65 * alpha))
	_at_actor(point, fallen.facing, FOE_SCALE * actor_zoom)
	var char_amount := smoothstep(0.08, Combat.ENEMY_DEATH_DURATION, fallen.age)
	var ink := Color.WHITE.lerp(tint, 0.16).lerp(Color(0.16, 0.07, 0.06), char_amount * 0.85)
	MonsterArt.draw_frame(self, art, MonsterArt.death_frame(fallen.age), height, Color(ink, alpha))
	_world_transform()

func _draw_projectile(shot: Dictionary) -> void:
	var direction := (Vector2(shot.velocity) * Vector2(1.0, lane_depth)).normalized()
	var height := Vector2(0, 42 if shot.magic else 46) * actor_zoom
	var tip := _floor(shot.pos) - height
	if not shot.empowered:
		var forward := Vector2(shot.velocity).normalized()
		var facing := -1.0 if forward.x < 0.0 else 1.0
		var release := cutout.release_point() * Vector2(facing, 1) * HERO_SCALE * actor_zoom
		var first_point := _floor(Vector2(shot.source) + forward * Combat.PROJECTILE_START) - height
		var remaining := clampf(shot.life * Vector2(shot.velocity).length() / (shot.reach - Combat.PROJECTILE_START), 0.0, 1.0)
		tip += (_floor(shot.source) + release - first_point) * remaining
	if shot.get("empowered", false):
		draw_line(tip - direction * 66.0, tip, Color(shot.color, 0.35), 9.0, true)
		draw_line(tip - direction * 47.0, tip, Color("#fff1c9", 0.84), 2.0, true)
	if shot.magic:
		var echo := 5 if shot.wand else 8
		for i in range(echo, -1, -1):
			var sway := sin(i * 2.0 + tip.x * 0.10) * mini(i, 4)
			var point := tip - direction * (i * 4.0) + direction.orthogonal() * sway
			_square(point, maxf(2.0, float(echo + 1 - i)), Color("#fff2ff") if i == 0 else Color(shot.color, 1.0 - i * 0.09))
		return
	var tail := tip - direction * 29.0 * HERO_SCALE * actor_zoom
	var normal := direction.orthogonal()
	draw_line(tail, tip, Color("#aa9776"), 2.0)
	draw_colored_polygon(PackedVector2Array([tip + direction * 4.0, tip - direction * 4.0 + normal * 3.0, tip - direction * 4.0 - normal * 3.0]), Color("#f3ecdc"))
	draw_line(tail - normal * 2.0, tail + direction * 5.0, Color(shot.color), 2.0)
	draw_line(tail + normal * 2.0, tail + direction * 5.0, Color(shot.color), 2.0)

func _draw_telegraphs() -> void:
	for enemy in run.enemies:
		if enemy.hp <= 0:
			continue
		if enemy.windup > 0.0:
			var radius: float = enemy.strike_radius
			var focus := _floor(enemy.strike_at)
			var phase := 1.0 - float(enemy.windup) / float(enemy.windup_total)
			draw_set_transform(world_offset + focus * scale_to_screen, 0.0,
				Vector2(1.0, Combat.TELEGRAPH_ASPECT * lane_depth) * scale_to_screen)
			draw_circle(Vector2.ZERO, radius, Color("#d94f3e42"))
			draw_circle(Vector2.ZERO, radius * phase, Color("#ee6c5445"))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 56, Color("#a23247"), 3.0, true)
			_world_transform()
		elif enemy.spawn > 0.0 and enemy.spawn < 0.75:
			var width: float = 13.0 + 17.0 * enemy.spawn
			_arc(_floor(enemy.pos), Vector2(width, width * 0.16), 0.0, TAU, 1.5, Color("#ccb87f"))

func _draw_drops() -> void:
	for drop in run.drops:
		var point := _floor(drop.pos) - Vector2(0, 9 - (floori(drop.age * 5.0) % 2) * 3)
		if drop.has("material"):
			var item := Gear.material(drop.material)
			var glint: Color = item.tint
			draw_line(point + Vector2(0, 3), point - Vector2(0, 38), Color(glint, 0.52), 1.5)
			draw_circle(point, 13, Color(glint, 0.16))
			draw_texture_rect_region(ForgeArt.ATLAS, Rect2(point - Vector2(14, 14), Vector2(28, 28)), ForgeArt.region(item.icon))
			continue
		var ink := Color("#80ffc1") if drop.heal else Color("#ffbd68")
		_square(point - Vector2(3, 6), 6.0, ink)
		_square(point - Vector2(6, 0), 12.0, ink)
		_square(point - Vector2(3, -9), 6.0, ink)
		_square(point - Vector2(3, 0), 6.0, Color("#fff2d4"))

# 击打特效贴在受击者脚下，用与 _draw_enemy 相同的变换与像素比例 —— 特效的像素和精怪的像素是同一张网格。
# 图集里的火花朝右飞，出手朝左时整体翻过来。
func _draw_impact(effect: Dictionary, origin: Vector2, progress: float) -> void:
	var side := -1.0 if cos(float(effect.get("angle", 0.0))) < 0.0 else 1.0
	_at_actor(origin, side, FOE_SCALE * actor_zoom)
	FxArt.draw(self, &"crit" if effect.get("critical", false) else &"hit", String(effect.get("element", "")),
		progress, float(effect.radius))
	_world_transform()

func _draw_effect(effect: Dictionary) -> void:
	var progress: float = 1.0 - effect.life / effect.duration
	var ink: Color = effect.color
	var origin := _floor(effect.pos)
	ink.a = 1.0 - progress
	if effect.type == &"flurry":
		CombatFX.slash(self, origin, effect, progress, actor_zoom)
	elif effect.type == &"thrust":
		CombatFX.thrust(self, origin, effect, progress, actor_zoom)
	elif effect.type == &"impact":
		_draw_impact(effect, origin, progress)
	elif effect.type in [&"seal_burst", &"quake_seal", &"arrow_seal", &"spell_seal", &"arrow_impact", &"spell_impact"]:
		CombatFX.cast(self, origin, effect, progress)
	elif effect.type == &"thunder":
		for i in range(-2, 3):
			var offset := float(i) * float(effect.radius) * 0.48
			var base := origin + Vector2(offset, -absf(offset) * 0.18)
			var bolt := PackedVector2Array([base + Vector2(-offset * 0.35, -118), base + Vector2(-8, -59), base + Vector2(8, -64), base])
			draw_polyline(bolt, ink, 3.0, true)
	elif effect.type == &"crush":
		var radius: float = effect.radius * (0.20 + 0.80 * progress)
		var point := origin
		draw_circle(point, maxf(3.0, radius * 0.13), Color(1.0, 0.65, 0.32, ink.a * 0.32))
		_arc(point, Vector2(radius, radius * 0.20), 0.0, TAU, 3.0, ink)
		for i in range(7):
			var ray := Vector2.from_angle(i * TAU / 7.0) * Vector2(radius, radius * 0.20)
			var kink := ray * 0.44 + Vector2(4 * (i % 3 - 1), 4)
			draw_polyline(PackedVector2Array([point, point + kink, point + ray * 0.84]), Color(ink, ink.a * 0.76), 2.0)
			_square(point + ray - Vector2(0, 14.0 * sin(progress * PI)), 4.0, Color("#e99358", ink.a))
	else:
		var radius: float = effect.radius * (0.25 + 0.75 * progress)
		_arc(origin, Vector2(radius, radius * 0.25), 0.0, TAU, 2.0, ink)
		for i in range(10):
			var mark := Vector2.from_angle(i * TAU / 10.0) * Vector2(radius * 1.07, radius * 0.28)
			_square(origin + mark - Vector2(0, progress * 10.0), 3.0 if i % 2 else 5.0, ink)

# 影子画三层：外圈最虚，内圈最实，免得脚下像破了个洞。
# 皮影戏：影人贴着幕布演，台口上没有落地的影子，不画
func _shadow(point: Vector2, radius: Vector2, color: Color) -> void:
	if PIYING_SCREEN > 0.0:
		return
	for layer in range(3):
		var spread := radius * (1.22 - layer * 0.26)
		var points := PackedVector2Array()
		for i in range(16):
			points.append(point + Vector2.from_angle(i * TAU / 16.0) * spread)
		draw_colored_polygon(points, Color(color, color.a * (0.20 + layer * 0.17)))

func _arc(center: Vector2, radius: Vector2, start: float, sweep: float, pixels: float, color: Color) -> void:
	var segments := clampi(ceili(maxf(radius.x, radius.y) * sweep / 5.0), 4, 72)
	var points := PackedVector2Array()
	for i in range(segments + 1):
		points.append(center + Vector2.from_angle(start + sweep * i / segments) * radius)
	draw_polyline(points, color, pixels, true)

func _square(point: Vector2, pixels: float, color: Color) -> void:
	draw_rect(Rect2(point.snapped(Vector2.ONE * 3.0), Vector2.ONE * pixels), color)
