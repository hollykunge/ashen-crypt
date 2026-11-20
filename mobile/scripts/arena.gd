extends Control

const Gear = preload("res://scripts/gear.gd")
const ForgeArt = preload("res://scripts/forge_art.gd")

const Combat = preload("res://scripts/combat.gd")
const CombatFX = preload("res://scripts/combat_fx.gd")
const Roster = preload("res://scripts/roster.gd")
const Motion = preload("res://scripts/motion.gd")
const Figure = preload("res://scripts/figure.gd")
const Rig = preload("res://scripts/rig.gd")
const Appearance = preload("res://scripts/appearance.gd")
const SideArt = preload("res://scripts/side_art.gd")
const HeldWeapon = preload("res://scripts/held_weapon.gd")
const WornSprites = preload("res://scripts/worn_sprites.gd")
const MonsterArt = preload("res://scripts/monster_art.gd")
const WORLD_CENTER_X := 538.0
const SIDE_DEPTH := 0.18
const HERO_SCALE := 1.34
const FOE_SCALE := 1.30
const LANDSCAPE_ACTOR_MAGNIFICATION := 1.40
const CUT_IN_TIME := 0.43
# 连战镜头在原取景上整体推近：站位、人物和背景同比放大，交手距离的观感不变，
# 只是空地少了，人物占得更满。
const PORTRAIT_BATTLE_ZOOM := 1.24
const LANDSCAPE_BATTLE_ZOOM := 1.22
# 竖屏把地面线压低，下方空雪地让给人物；镜头中心左移，主角和精怪各占画面一侧。
const PORTRAIT_BATTLE_FLOOR := 0.765
const PORTRAIT_BATTLE_CENTER_X := 493.0
const SNOW_HAZE = preload("res://scripts/snow_haze.gdshader")

var run: Combat
var portrait_id := 0
var hero_element := "jin"
var scale_to_screen := 1.0
var actor_zoom := 1.0
# 主角每个像素在屏幕上的边长，连击数等贴着人物的界面按它避让头顶。
var hero_pixels := 1.0
var world_center_x := WORLD_CENTER_X
var haze := ShaderMaterial.new()
var world_offset := Vector2.ZERO
var camp_view := false
var ash_time := 0.0
# 装备外观，由 main 在换装备或开场时写入。
var retinue_look := Appearance.bare()
var hero_sprite: Texture2D = SideArt.SPRITES[0]
var look: Dictionary = Appearance.bare():
	set(value):
		look = value
		hero_sprite = WornSprites.texture(portrait_id % 2 == 1, look)
		if look.form == "bow":
			HeldWeapon.BowPose.texture(hero_sprite, portrait_id % 2, false)
# 打击反馈：震屏、闪白、顿感都只影响画面，不碰结算。
var shake := 0.0
var shake_seed := 0.0
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
var snow_pass := false
var layer_travel := false
var snow_drift := 0.0
var backdrop := TextureRect.new()
var fog := GradientTexture2D.new()
var cut_in_left := 0.0
var cut_in_name := ""

func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	backdrop.texture = SideArt.STREET
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.texture_filter = TEXTURE_FILTER_LINEAR
	backdrop.show_behind_parent = true
	backdrop.mouse_filter = MOUSE_FILTER_IGNORE
	haze.shader = SNOW_HAZE
	haze.set_shader_parameter("floor_line", SideArt.SNOW_FLOOR)
	add_child(backdrop)
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
	snow_pass = not active and run != null and run.continuous
	backdrop.texture = SideArt.SNOW_PASS if snow_pass else SideArt.STREET
	backdrop.material = haze if snow_pass else null
	street_floor = SideArt.SNOW_FLOOR if snow_pass else SideArt.FLOOR
	lane_depth = 0.30 if snow_pass else SIDE_DEPTH
	follow = Vector2.ZERO
	shake = 0.0
	glare = 0.0
	hold = 0.0
	cut_in_left = 0.0
	_fit_stage()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	ash_time = fposmod(ash_time + delta, 120.0)
	if snow_pass and run != null:
		snow_drift = fposmod(snow_drift + delta * (0.39 if run.advancing or layer_travel else 0.06), 4.0)
	_drain_pulses()
	_track_camera(delta)
	shake = maxf(0.0, shake - delta * (9.0 if camp_view else 6.5))
	glare = maxf(0.0, glare - delta * 4.2)
	hold = maxf(0.0, hold - delta)
	cut_in_left = maxf(0.0, cut_in_left - delta)
	shake_seed += delta * 47.0
	queue_redraw()

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
		match pulse.kind:
			&"hit":
				shake = maxf(shake, 0.16 * power * damp)
			&"crit":
				shake = maxf(shake, 0.34 * power * damp)
				_glare(Color("#ffd9a8"), 0.5 * damp)
			&"kill":
				shake = maxf(shake, 0.22 * power * damp)
			&"hurt":
				shake = maxf(shake, 0.40 * power * damp)
				_glare(Color("#ff9d86"), 0.85 * damp)
				_rumble(roundi(28.0 * power))
			&"stomp", &"quake":
				shake = maxf(shake, 0.46 * power * damp)
				_rumble(22)
			&"cast":
				shake = maxf(shake, 0.20 * power * damp)
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

func _rumble(milliseconds: int) -> void:
	if OS.has_feature("mobile") and milliseconds > 0:
		Input.vibrate_handheld(milliseconds)

func _fit_stage() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var wide := size.x >= size.y * 1.17
	var stage_height := 435.0 if snow_pass else (590.0 if camp_view else 510.0)
	var zoom := (LANDSCAPE_BATTLE_ZOOM if wide else PORTRAIT_BATTLE_ZOOM) if snow_pass else 1.0
	scale_to_screen = minf(size.x / (445.0 if camp_view else 414.0), size.y / stage_height) * zoom
	# 取景按原来的地面线算，推近后再把地面线挪到新位置。
	var framing_floor := size.y * ((0.79 if wide else 0.72) if snow_pass else (0.755 if wide else 0.70))
	var portrait_battle := snow_pass and not wide
	floor_height = size.y * PORTRAIT_BATTLE_FLOOR if portrait_battle else framing_floor
	world_center_x = PORTRAIT_BATTLE_CENTER_X if portrait_battle else WORLD_CENTER_X
	var native := backdrop.texture.get_size()
	var margin := 340.0 if snow_pass else 104.0
	# 地面锚点对齐角色脚底，同时覆盖地面上、下两段视口。
	var framing := maxf(framing_floor / street_floor, (size.y - framing_floor) / (1.0 - street_floor))
	var cover := maxf(floor_height / street_floor, (size.y - floor_height) / (1.0 - street_floor))
	var backdrop_scale := maxf(maxf((size.x + margin) / native.x, framing / native.y) * zoom, cover / native.y)
	var street_size := native * backdrop_scale
	# 人物随原画缩放，战斗坐标仍使用原来的投影。窄屏至少容下两个人物分格（推近时同比放宽）。
	var art_scale := SideArt.SNOW_ACTOR_SCALE if snow_pass else SideArt.STREET_ACTOR_SCALE
	if wide:
		art_scale *= LANDSCAPE_ACTOR_MAGNIFICATION
	hero_pixels = minf(street_size.y * art_scale, size.x / (2.0 * SideArt.CELL.x) * zoom)
	actor_zoom = hero_pixels / (HERO_SCALE * scale_to_screen)
	# 地面和脚底共用同一段镜头位移，图片边缘同时限制镜头的行程。
	var overflow := street_size.x - size.x
	var initial_left := -minf(76.0 * scale_to_screen, overflow * 0.20) if snow_pass else -overflow * 0.5
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
	jitter = Vector2(0.0, cos(shake_seed * 2.3) * 4.0) * shake * scale_to_screen
	_draw_mist()
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
	if snow_pass:
		_draw_snow()
	else:
		_draw_ash()
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
	var portrait: Texture2D = SideArt.PORTRAITS[portrait_id % 2]
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

func _draw_ash() -> void:
	draw_set_transform(Vector2.ZERO)
	for i in range(24):
		var drift := float(i) * 0.61803399
		var x := fposmod(drift + sin(i * 2.48 + ash_time * 0.40) * 0.048, 1.0)
		var path := fposmod(i * 0.346 - ash_time * (0.034 + (i % 3) * 0.012), 1.0)
		var point := Vector2(x * size.x, (0.89 - path * 0.72) * size.y)
		var ember := i % 4 == 0
		var alpha := sin(path * PI) * (0.52 if ember else 0.24)
		var ink := Color("#ed9c5d") if ember else Color("#b1b7c1")
		if ember:
			draw_circle(point, 3.1, Color(ink, alpha * 0.15), true, -1.0, true)
		draw_circle(point, 1.25 if ember else 0.72, Color(ink, alpha), true, -1.0, true)

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

# 将地面的落脚点换算到当前分格的局部坐标。
func _foot_shift(gait: Dictionary, facing: float, actor_scale: float, lean: float) -> Vector2:
	var plant := _step_vector() * float(gait.plant) / actor_scale
	return plant.rotated(-lean * facing) * Vector2(facing, 1.0) - Vector2(gait.sole)

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

func _draw_hero() -> void:
	var base := _floor(run.position)
	var hero_scale := HERO_SCALE * actor_zoom
	var facing := -1.0 if cos(run.facing) < 0.0 else 1.0
	hero_pose = _hero_pose()
	var running := run.advancing or layer_travel
	var sprite_index := portrait_id % 2
	var frame := SideArt.frame_for(hero_pose.frame)
	var retreating := run.motion == &"retreat" and run.dodge_moves
	var shift_x := 0.56 * facing if retreating else 0.0
	var nudge := Vector2(hero_pose.shift) * Vector2(shift_x, 0.44)
	var point := base + nudge
	var lean := 0.0
	var gait := {}
	if run.motion.is_empty() and run.stride > 0.0:
		if absf(run.step_direction.x) > 0.15:
			facing = signf(run.step_direction.x)
		gait = SideArt.gait(run.stride, hero_scale, sprite_index, running)
		frame = gait.frame
		lean = 0.11 if running else 0.0
	var sprite := hero_sprite
	var ink: Color = Roster.ELEMENT_TINTS.get(hero_element, Color.WHITE).lerp(Color.WHITE, 0.88)
	ink = ink.lerp(Color(1.45, 1.32, 1.22), float(hero_pose.flash) * 0.60)
	ink.a = float(hero_pose.fade)
	_shadow(base + Vector2(nudge.x, 0.0), Vector2(25, 4) * actor_zoom, Color("#23364a9e") if snow_pass else Color("#0c090ae0"))
	if snow_pass and running and not gait.is_empty():
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
	_at_actor(point, facing, hero_scale, lean)
	if float(hero_pose.ghost) > 0.1 and (run.motion != &"retreat" or retreating):
		var offset := 13.0 if run.motion == &"retreat" else -10.0
		if float(hero_pose.ghost) > 0.65 and run.motion == &"attack":
			HeldWeapon.draw_actor(self, sprite, sprite_index, frame, look, Color(look.trim, float(hero_pose.ghost) * 0.12),
				{}, Vector2.ZERO, Vector2(offset * 2.1, 0))
		HeldWeapon.draw_actor(self, sprite, sprite_index, frame, look, Color(look.trim, float(hero_pose.ghost) * 0.23),
			{}, Vector2.ZERO, Vector2(offset, 0))
	var feet := Vector2.ZERO if gait.is_empty() else _foot_shift(gait, facing, hero_scale, lean)
	HeldWeapon.draw_actor(self, sprite, sprite_index, frame, look, ink, gait, feet)
	draw_set_transform(Vector2.ZERO)
	Figure.hands(self, rig, look)
	Figure.charms(self, rig, look, ash_time)
	Figure.dust(self, rig, look, ash_time)
	_world_transform()

# 官宦随侍与随侍伤害共用同一个人数。
func _draw_retinue() -> void:
	var spread := snow_pass and size.x >= size.y * 1.17
	for index in range(run.companions):
		var offset := Vector2(56.0 + index * 44.0, 9.0 - index * 14.0) if spread else Vector2(42.0 + index * 28.0, 2.0 - index * 2.0)
		var point := _floor(run.position) - offset
		_shadow(point, Vector2(17, 3) * actor_zoom, Color("#0c090ab8"))
		var running := run.advancing or layer_travel
		var pose := &"strike" if not running and run.companion_left >= 0.65 else &"ready"
		var frame := SideArt.frame_for(pose)
		var actor_scale := (0.97 - index * 0.055) * actor_zoom
		var facing := 1.0
		var lean := 0.0
		var gait := {}
		if pose == &"ready" and run.stride > 0.0:
			gait = SideArt.gait(run.stride + index * 9.0, actor_scale, 0, running)
			facing = -1.0 if run.step_direction.x < -0.15 else 1.0
			frame = gait.frame
			lean = 0.11 if running else 0.0
		_at_actor(point, facing, actor_scale, lean)
		var ink := Color("#929896e0")
		var feet := Vector2.ZERO if gait.is_empty() else _foot_shift(gait, facing, actor_scale, lean)
		HeldWeapon.draw_actor(self, SideArt.SPRITES[0], 0, frame, retinue_look, ink, gait, feet)
		_world_transform()

func _draw_enemy(enemy: Dictionary) -> void:
	var point := _floor(enemy.pos)
	var height: float = enemy.stats.size
	var foe_scale := FOE_SCALE * actor_zoom
	var tint: Color = Roster.ELEMENT_GLOW[Gear.WuXing.stem_element(run.encounter_stem)]
	var facing := -1.0 if enemy.pos.x > run.position.x else 1.0
	var frame := MonsterArt.live_frame(enemy)
	var art := MonsterArt.variant(enemy.art, run.encounter_stem)
	_shadow(point, Vector2(height * 0.30, height * 0.052) * actor_zoom, Color("#23364aa8") if snow_pass else Color("#0c090ae0"))
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
	var point := _floor(fallen.pos)
	var height: float = fallen.height
	var art := MonsterArt.variant(fallen.art, run.encounter_stem)
	var alpha := 1.0 - smoothstep(Combat.ENEMY_DEATH_DURATION, Combat.ENEMY_DEATH_LIFETIME, fallen.age)
	var tint: Color = Roster.ELEMENT_GLOW[Gear.WuXing.stem_element(run.encounter_stem)]
	_shadow(point, Vector2(height * 0.34, height * 0.05) * actor_zoom, Color("#0c090a", 0.65 * alpha))
	_at_actor(point, fallen.facing, FOE_SCALE * actor_zoom)
	MonsterArt.draw_frame(self, art, MonsterArt.death_frame(fallen.age), height, Color(Color.WHITE.lerp(tint, 0.16), alpha))
	_world_transform()

func _draw_projectile(shot: Dictionary) -> void:
	var direction := (Vector2(shot.velocity) * Vector2(1.0, lane_depth)).normalized()
	var height := Vector2(0, 42 if shot.magic else 46) * actor_zoom
	var tip := _floor(shot.pos) - height
	if not shot.empowered:
		var forward := Vector2(shot.velocity).normalized()
		var facing := -1.0 if forward.x < 0.0 else 1.0
		var release := HeldWeapon.release_point(portrait_id % 2, shot.magic) * Vector2(facing, 1) * HERO_SCALE * actor_zoom
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
	var tail := tip - direction * HeldWeapon.arrow_length(portrait_id % 2) * HERO_SCALE * actor_zoom
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
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 56, Color("#a23247") if snow_pass else Color("#ff9578"), 3.0, true)
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

func _draw_effect(effect: Dictionary) -> void:
	var progress: float = 1.0 - effect.life / effect.duration
	var ink: Color = effect.color
	var origin := _floor(effect.pos)
	ink.a = 1.0 - progress
	if effect.type == &"flurry":
		CombatFX.slash(self, origin, effect, progress, actor_zoom)
	elif effect.type == &"impact":
		CombatFX.impact(self, origin, float(effect.radius) * actor_zoom, ink, progress)
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
func _shadow(point: Vector2, radius: Vector2, color: Color) -> void:
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
