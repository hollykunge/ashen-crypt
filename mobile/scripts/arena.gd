extends Control

const Gear = preload("res://scripts/gear.gd")
const ForgeArt = preload("res://scripts/forge_art.gd")

const Combat = preload("res://scripts/combat.gd")
const Roster = preload("res://scripts/roster.gd")
const Motion = preload("res://scripts/motion.gd")
const Figure = preload("res://scripts/figure.gd")
const Rig = preload("res://scripts/rig.gd")
const Appearance = preload("res://scripts/appearance.gd")
const CRYPT = preload("res://art/immortals/battle-terrace.webp")
const CAMP_DEPTH = preload("res://scripts/camp_depth.gdshader")
const ENEMY := [preload("res://art/immortals/shanxiao.webp"), preload("res://art/immortals/fire-fox.webp"), preload("res://art/immortals/guardian.webp")]
const WORLD_CENTER_X := 538.0
const HERO_SCALE := 1.24
const FOE_SCALE := 1.20

var run: Combat
var portrait_id := 0
var hero_element := "jin"
var scale_to_screen := 1.0
var world_offset := Vector2.ZERO
var backdrop := TextureRect.new()
var camp_depth := ShaderMaterial.new()
var camp_view := false
var ash_time := 0.0
# 装备外观，由 main 在换装备或开场时写入。
var look: Dictionary = Appearance.bare()
# 打击反馈：震屏、闪白、顿感都只影响画面，不碰结算。
var shake := 0.0
var shake_seed := 0.0
var glare := 0.0
var glare_ink := Color("#ffd9a8")
var hold := 0.0
var jitter := Vector2.ZERO
var follow := Vector2.ZERO
var hero_pose: Dictionary = Motion.REST

func _ready() -> void:
	# 立绘是 288 高的工笔画，战斗里要缩到一百出头；不开 mipmap 的话每一帧都在重新抽样，
	# 线条会闪、会碎，人就显得脏。战场这一层统一走带 mipmap 的线性采样。
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	camp_depth.shader = CAMP_DEPTH
	backdrop.texture = CRYPT
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.show_behind_parent = true
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_fit_stage)
	_fit_stage()

func set_camp_view(active: bool) -> void:
	camp_view = active
	follow = Vector2.ZERO
	shake = 0.0
	glare = 0.0
	backdrop.material = camp_depth if active else null
	backdrop.texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if active else TEXTURE_FILTER_PARENT_NODE
	_fit_stage()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	ash_time = fposmod(ash_time + delta, 120.0)
	_drain_pulses()
	_track_camera(delta)
	shake = maxf(0.0, shake - delta * (9.0 if camp_view else 6.5))
	glare = maxf(0.0, glare - delta * 4.2)
	hold = maxf(0.0, hold - delta)
	shake_seed += delta * 47.0
	queue_redraw()

# 把战斗抛出的打击事件翻成画面反馈。挂机时一律减半，免得挂着挂着屏幕一直在抖。
func _drain_pulses() -> void:
	if run == null or run.pulses.is_empty():
		return
	var damp := 0.45 if camp_view else 1.0
	for pulse in run.pulses:
		var power: float = pulse.power
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
			&"revive":
				_glare(Color("#b6f0a8"), 0.7)
		hold = maxf(hold, 0.05 if pulse.kind in [&"crit", &"hurt", &"quake", &"stomp"] else 0.0)
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
	scale_to_screen = minf(size.x / (480.0 if camp_view else 445.0), size.y / 625.0)
	var anchor := Vector2(WORLD_CENTER_X, Combat.HOME.y) + follow
	world_offset = size * Vector2(0.5, 0.65 if camp_view else 0.56) - anchor * scale_to_screen
	queue_redraw()

# 镜头跟着战况挪一点点：人与层主分得越开，视角越往中间让。幅度刻意压得很小，免得晕。
func _track_camera(delta: float) -> void:
	var wish := Vector2.ZERO
	if not camp_view and run != null:
		var focus: Vector2 = run.position
		var far: Vector2 = run.enemies[0].pos if not run.enemies.is_empty() else focus
		focus = focus.lerp(far, 0.38)
		wish = (focus - Vector2(WORLD_CENTER_X, Combat.HOME.y)) * 0.40
		wish = Vector2(clampf(wish.x, -46.0, 46.0), clampf(wish.y, -18.0, 18.0))
	var next := follow.lerp(wish, clampf(delta * 3.2, 0.0, 1.0))
	if next.distance_squared_to(follow) < 0.0004:
		return
	follow = next
	_fit_stage()

func _draw() -> void:
	if run == null or size.x <= 0.0 or size.y <= 0.0:
		return
	jitter = Vector2(sin(shake_seed * 1.7) * 7.0, cos(shake_seed * 2.3) * 4.0) * shake * scale_to_screen
	_world_transform()
	_draw_telegraphs()
	_draw_drops()

	var actors: Array[Dictionary] = [{"pos": run.position, "hero": true}]
	for enemy in run.enemies:
		if enemy.spawn <= 0.0:
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
		var center: Vector2 = popup.pos - Vector2(font.get_string_size(popup.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x * 0.5, 0.0)
		if popup.has("material"):
			var item := Gear.material(popup.material)
			draw_texture_rect_region(ForgeArt.ATLAS, Rect2(Vector2(popup.pos) - Vector2(24, 19), Vector2(23, 23)), ForgeArt.region(item.icon), Color(1, 1, 1, opacity))
			pixels = 16
			ink = Color(item.tint, opacity)
			center = popup.pos
		# 挂机画面整体发虚，伤害数字加一块描边衬底才读得出来；手操时只描边，别挡视野。
		var rise := (1.0 - minf(popup.life / 0.6, 1.0))
		var lifted := center - Vector2(0.0, rise * 4.0)
		if camp_view:
			var text_width := font.get_string_size(popup.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
			var plate := Rect2(lifted.x - 5.0, lifted.y - font.get_ascent(pixels) - 2.0, text_width + 10.0, font.get_height(pixels) + 4.0)
			draw_rect(plate, Color(0.04, 0.08, 0.07, 0.62 * opacity))
		draw_string_outline(font, lifted, popup.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, 5 if critical else 4,
			Color(0.08, 0.05, 0.10, opacity))
		draw_string(font, lifted, popup.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, ink)
	_draw_ash()
	_draw_glare()

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
	for i in range(20):
		var drift := float(i) * 0.61803399
		var x := fposmod(drift + sin(i * 2.48 + ash_time * 0.28) * 0.027, 1.0)
		var path := fposmod(i * 0.346 - ash_time * (0.034 + (i % 3) * 0.012), 1.0)
		var y := (0.82 - path * 0.68) * size.y
		var alpha := sin(path * PI) * (0.34 if i % 4 == 0 else 0.17)
		var point := Vector2(roundf(x * size.x), roundf(y))
		draw_rect(Rect2(point, Vector2(2, 2) if i % 4 == 0 else Vector2.ONE), Color(0.98, 0.57, 0.23, alpha))

func _world_transform() -> void:
	draw_set_transform(world_offset + jitter, 0.0, Vector2.ONE * scale_to_screen)

func _at_actor(point: Vector2, facing: float, actor_scale: float) -> void:
	draw_set_transform(world_offset + jitter + point * scale_to_screen, 0.0, Vector2(facing, 1.0) * scale_to_screen * actor_scale)

# 角色本地系 → 屏幕系的换算，交给 Rig 用。
func _screen(point: Vector2) -> Vector2:
	return world_offset + jitter + point * scale_to_screen

# 当前该播哪条动作曲线。没有在出招就按有没有在挪步，在走位与吐纳之间二选一。
func _hero_pose() -> Dictionary:
	if run.motion == &"":
		return Motion.walk(run.stride) if run.stride > 0.0 else Motion.idle(ash_time)
	var phase := run.motion_time / maxf(run.motion_duration, 0.01)
	# 顿感：重击瞬间把动作停在原地几十毫秒，打击更实。
	if hold > 0.0:
		phase = maxf(0.0, phase - hold * 1.4)
	return Motion.sample(Motion.clip_for(run.motion, run.weapon_form), phase)

func _draw_hero() -> void:
	var point := run.position
	var tint: Color = Roster.ELEMENT_GLOW.get(hero_element, Color("#e5cb93"))
	var emphasis := 1.8 if camp_view else 1.0
	hero_pose = _hero_pose()
	hero_pose.pivot = Roster.frame_pivot(hero_pose.frame)
	var artwork := Roster.battle_art(portrait_id, run.weapon_form, hero_pose.frame)
	var height := 109.0 * emphasis
	var width := float(artwork.get_width()) * height / float(artwork.get_height())
	var rig := Rig.new(_screen(point), scale_to_screen * HERO_SCALE, 1.0, height, width, hero_pose)

	_shadow(point, Vector2(26, 9) * emphasis * lerpf(1.0, 0.82, clampf(-float(hero_pose.shift.y) / 16.0, 0.0, 1.0)),
		Color("#0c090ac5"))
	_arc(point + Vector2(0, 2), Vector2(24, 8) * emphasis, 0.27, 5.72, 2.1, Color(tint, 0.8))
	if run.shield > 0.0:
		_arc(point, Vector2(32, 11), ash_time * 3.0, 2.4, 2.0, Color("#d1fba3"))
	draw_set_transform(Vector2.ZERO)
	Figure.halo(self, rig, look, ash_time)
	Figure.sash(self, rig, look, ash_time, clampf(run.stride * 0.1, 0.0, 1.0) + float(hero_pose.ghost))
	Figure.ghosts(self, rig, artwork, tint, Vector2(-11.0, 0.0))
	Figure.rim(self, rig, artwork, look.rim, float(look.rim_amount))
	var ink: Color = Roster.ELEMENT_TINTS.get(hero_element, Color.WHITE).lerp(Color.WHITE, 0.70)
	Figure.body(self, rig, artwork, ink)
	Figure.dye(self, rig, artwork, look.robe, float(look.robe_amount))
	Figure.flash(self, rig, artwork)
	Figure.edge(self, rig, look, ash_time)
	Figure.hands(self, rig, look)
	Figure.charms(self, rig, look, ash_time)
	Figure.dust(self, rig, look, ash_time)
	_world_transform()

func _draw_enemy(enemy: Dictionary) -> void:
	var height: float = enemy.stats.size
	var tint: Color = Roster.ELEMENT_GLOW[Gear.WuXing.stem_element(run.encounter_stem)]
	var lift := 7.0 if enemy.windup > 0.0 else 0.0
	var bounce := 3.0 * (floori(enemy.stride) % 2)
	_shadow(enemy.pos, Vector2(height * 0.33, height * 0.125), Color("#0c090ac5"))
	if enemy.boss:
		_arc(enemy.pos, Vector2(height * 0.42, height * 0.15), 0.0, TAU, 2.5, Color(tint, 0.75))
	_at_actor(Vector2(enemy.pos) - Vector2(0, lift + bounce), -1.0, FOE_SCALE)
	var artwork: Texture2D = ENEMY[enemy.art]
	var ink := Color(1.48, 1.48, 1.48) if enemy.hit > 0.0 else Color.WHITE.lerp(tint, 0.30)
	# 贴身站位时精怪会把人整个盖住，挡在前面的那只让出一点通透度。
	var half := artwork.get_width() * height / artwork.get_height() * FOE_SCALE * 0.5
	if enemy.pos.y >= run.position.y - 3.0 and absf(enemy.pos.x - run.position.x) < half:
		ink.a = 0.55
	_draw_sprite(artwork, height, 0.5, ink)
	_world_transform()
	if enemy.hit > 0.0 and not enemy.boss:
		var width := 34.0
		var origin: Vector2 = enemy.pos - Vector2(width / 2.0, height * FOE_SCALE + 8.0)
		draw_rect(Rect2(origin - Vector2.ONE, Vector2(width + 2.0, 5.0)), Color("#241b37"))
		draw_rect(Rect2(origin, Vector2(width * float(enemy.hp) / float(enemy.max_hp), 3.0)), Color("#f0a580"))

func _draw_sprite(texture: Texture2D, height: float, pivot: float, color: Color) -> void:
	var width := texture.get_width() * height / texture.get_height()
	draw_texture_rect(texture, Rect2(-width * pivot, 3.0 - height, width, height), false, color)

func _draw_projectile(shot: Dictionary) -> void:
	var direction := Vector2(shot.velocity).normalized()
	var tip: Vector2 = shot.pos - Vector2(0, 50 if shot.magic else 53)
	if shot.magic:
		var echo := 5 if shot.wand else 8
		for i in range(echo, -1, -1):
			var sway := sin(i * 2.0 + tip.x * 0.10) * mini(i, 4)
			var point := tip - direction * (i * 4.0) + direction.orthogonal() * sway
			_square(point, maxf(2.0, float(echo + 1 - i)), Color("#fff2ff") if i == 0 else Color(shot.color, 1.0 - i * 0.09))
		return
	var tail := tip - direction * 24.0
	var normal := direction.orthogonal()
	draw_line(tail, tip, Color("#aa9776"), 2.0)
	draw_colored_polygon(PackedVector2Array([tip + direction * 4.0, tip - direction * 4.0 + normal * 3.0, tip - direction * 4.0 - normal * 3.0]), Color("#f3ecdc"))
	draw_line(tail - normal * 2.0, tail + direction * 5.0, Color(shot.color), 2.0)
	draw_line(tail + normal * 2.0, tail + direction * 5.0, Color(shot.color), 2.0)

func _draw_telegraphs() -> void:
	for enemy in run.enemies:
		if enemy.windup > 0.0:
			var radius: float = enemy.strike_radius
			var focus: Vector2 = enemy.strike_at
			var phase := 1.0 - float(enemy.windup) / float(enemy.windup_total)
			draw_set_transform(world_offset + focus * scale_to_screen, 0.0,
				Vector2(1.0, Combat.TELEGRAPH_ASPECT) * scale_to_screen)
			draw_circle(Vector2.ZERO, radius, Color("#d94f3e42"))
			draw_circle(Vector2.ZERO, radius * phase, Color("#ee6c5445"))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 56, Color("#ff9578"), 3.0, true)
			_world_transform()
		elif enemy.spawn > 0.0 and enemy.spawn < 0.75:
			var width: float = 13.0 + 17.0 * enemy.spawn
			_arc(enemy.pos, Vector2(width, width * 0.4), 0.0, TAU, 3.0, Color("#ccb87f"))

func _draw_drops() -> void:
	for drop in run.drops:
		var point: Vector2 = drop.pos - Vector2(0, 9 - (floori(drop.age * 5.0) % 2) * 3)
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
	ink.a = 1.0 - progress
	if effect.type == &"slash":
		var radius: float = effect.radius * (0.46 + progress * 0.43)
		var point: Vector2 = effect.pos - Vector2(0, 14)
		_arc(point, Vector2.ONE * (radius + 3.0), effect.angle - 1.46, 2.92, 10.0, Color(0.94, 0.32, 0.10, ink.a * 0.30))
		_arc(point, Vector2.ONE * radius, effect.angle - 1.42, 2.84, 6.0, ink)
		_arc(point, Vector2.ONE * (radius - 3.0), effect.angle - 1.12, 2.24, 3.0, Color(1, 0.94, 0.77, ink.a))
		for i in range(8):
			var angle: float = effect.angle + (i - 3.5) * 0.27
			var spark := point + Vector2.from_angle(angle) * (radius + 6.0 + i % 3 * progress * 17.0)
			_square(spark, 2.0 if i % 2 == 0 else 3.0, Color(1.0, 0.56, 0.23, ink.a))
	elif effect.type == &"thunder":
		for i in range(-2, 3):
			var offset := float(i) * float(effect.radius) * 0.48
			var base: Vector2 = effect.pos + Vector2(offset, -absf(offset) * 0.18)
			var bolt := PackedVector2Array([base + Vector2(-offset * 0.35, -118), base + Vector2(-8, -59), base + Vector2(8, -64), base])
			draw_polyline(bolt, ink, 3.0, true)
	elif effect.type == &"crush":
		var radius: float = effect.radius * (0.20 + 0.80 * progress)
		var point: Vector2 = effect.pos
		draw_circle(point, maxf(6.0, radius * 0.25), Color(1.0, 0.65, 0.32, ink.a * 0.35))
		_arc(point, Vector2(radius, radius * 0.55), 0.0, TAU, 6.0, ink)
		for i in range(7):
			var ray := Vector2.from_angle(i * TAU / 7.0) * Vector2(radius, radius * 0.55)
			var kink := ray * 0.44 + Vector2(4 * (i % 3 - 1), 4)
			draw_polyline(PackedVector2Array([point, point + kink, point + ray * 0.84]), Color(ink, ink.a * 0.76), 2.0)
			_square(point + ray - Vector2(0, 14.0 * sin(progress * PI)), 4.0, Color("#e99358", ink.a))
	else:
		var radius: float = effect.radius * (0.25 + 0.75 * progress)
		_arc(effect.pos, Vector2(radius, radius * 0.64), 0.0, TAU, 4.0, ink)
		for i in range(10):
			var mark := Vector2.from_angle(i * TAU / 10.0) * Vector2(radius * 1.07, radius * 0.75)
			_square(effect.pos + mark - Vector2(0, progress * 10.0), 3.0 if i % 2 else 6.0, ink)

# 影子画三层：外圈最虚，内圈最实，免得脚下像破了个洞。
func _shadow(point: Vector2, radius: Vector2, color: Color) -> void:
	for layer in range(3):
		var spread := radius * (1.22 - layer * 0.26)
		var points := PackedVector2Array()
		for i in range(16):
			points.append(point + Vector2.from_angle(i * TAU / 16.0) * spread)
		draw_colored_polygon(points, Color(color, color.a * (0.20 + layer * 0.17)))

func _arc(center: Vector2, radius: Vector2, start: float, sweep: float, pixels: float, color: Color) -> void:
	var dots := maxi(1, ceili(maxf(radius.x, radius.y) * sweep / 3.0))
	for i in range(dots + 1):
		_square(center + Vector2.from_angle(start + sweep * i / dots) * radius, pixels, color)

func _square(point: Vector2, pixels: float, color: Color) -> void:
	draw_rect(Rect2(point.snapped(Vector2.ONE * 3.0), Vector2.ONE * pixels), color)
