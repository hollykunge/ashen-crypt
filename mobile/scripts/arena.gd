extends Control

const Gear = preload("res://scripts/gear.gd")
const ForgeArt = preload("res://scripts/forge_art.gd")

const Combat = preload("res://scripts/combat.gd")
const Roster = preload("res://scripts/roster.gd")
const CRYPT = preload("res://art/furnace-vault.webp")
const GRADE = preload("res://art/gothic_grade.gdshader")
const ENEMY := [preload("res://art/fighter-3.webp"), preload("res://art/fighter-4.webp"), preload("res://art/fighter-5.webp")]
const WORLD_CENTER_X := 538.0
const HERO_SCALE := 1.24
const FOE_SCALE := 1.20

var run: Combat
var scale_to_screen := 1.0
var world_offset := Vector2.ZERO
var backdrop := TextureRect.new()
var ash_time := 0.0

func _ready() -> void:
	var grade := ShaderMaterial.new()
	grade.shader = GRADE
	grade.set_shader_parameter("grade_weight", 0.12)
	grade.set_shader_parameter("exposure", 1.25)
	backdrop.texture = CRYPT
	backdrop.material = grade
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.show_behind_parent = true
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_fit_stage)
	_fit_stage()

func _process(delta: float) -> void:
	if is_visible_in_tree():
		ash_time = fposmod(ash_time + delta, 120.0)
		queue_redraw()

func _fit_stage() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	scale_to_screen = minf(size.x / 480.0, size.y / 625.0)
	var anchor := Vector2(WORLD_CENTER_X, Combat.HOME.y)
	world_offset = size * Vector2(0.5, 0.52) - anchor * scale_to_screen
	queue_redraw()

func _draw() -> void:
	if run == null or size.x <= 0.0 or size.y <= 0.0:
		return
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
		draw_string_outline(font, center, popup.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, 4, Color(0.10, 0.06, 0.14, opacity))
		draw_string(font, center, popup.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, ink)
	_draw_ash()

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
	draw_set_transform(world_offset, 0.0, Vector2.ONE * scale_to_screen)

func _at_actor(point: Vector2, facing: float, actor_scale: float) -> void:
	draw_set_transform(world_offset + point * scale_to_screen, 0.0, Vector2(facing, 1.0) * scale_to_screen * actor_scale)

func _draw_hero() -> void:
	var point := run.position
	_shadow(point, Vector2(32, 12), Color("#0c090ac5"))
	_arc(point + Vector2(0, 2), Vector2(26, 9), 0.27, 5.72, 2.1, Color(run.hero.color, 0.8))
	if run.crit_ready:
		_arc(point, Vector2(33, 12), ash_time * 3.0, 2.4, 2.0, Color("#d1fba3"))
	var id := Roster.id(run.hero_id, run.hero_style)
	var motion := run.motion
	var phase := run.motion_time / maxf(run.motion_duration, 0.01)
	if run.result == &"defeat":
		motion = &"defeat"
		phase = 1.0
	var slide := Vector2.ZERO
	match motion:
		&"":
			motion = &"walk" if run.stride > 0.0 else &"idle"
			phase = fposmod(run.stride / 6.0, 1.0) if motion == &"walk" else fposmod(ash_time / Roster.IDLE_TIME[id], 1.0)
		&"attack", &"skill", &"tactic":
			slide.x = sin(clampf(phase, 0.0, 1.0) * PI) * (7.0 if run.hero_id == 0 else 3.0)
		&"hurt":
			slide.x = -8.0 * sin(clampf(phase, 0.0, 1.0) * PI)
	_at_actor((point + slide).snapped(Vector2.ONE), 1.0, HERO_SCALE)
	var ink := Color(1.26, 1.26, 1.26) if run.motion == &"hurt" and run.motion_time < 0.07 else Color.WHITE
	var source := Roster.region(motion, phase)
	var artwork := Roster.battle_art(id, run.weapon_id)
	if run.dodge_left > 0.0:
		draw_texture_rect_region(artwork, Rect2(-Roster.FEET + Vector2(14, 0), Roster.CELL), source, Color(1, 1, 1, 0.22))
	draw_texture_rect_region(artwork, Rect2(-Roster.FEET, Roster.CELL), source, ink)
	_world_transform()

func _draw_enemy(enemy: Dictionary) -> void:
	var info: Dictionary = Combat.FOES[enemy.type]
	var height: float = info.size
	_shadow(enemy.pos, Vector2(height * 0.36, height * 0.135), Color("#0c090ac5"))
	var lift := 6.0 if enemy.windup > 0.0 else 0.0
	var bounce := 3.0 * (floori(enemy.stride) % 2)
	_at_actor(Vector2(enemy.pos) - Vector2(0, lift + bounce), -1.0, FOE_SCALE)
	_draw_sprite(ENEMY[enemy.type], height, 0.5, Color(1.48, 1.48, 1.48) if enemy.hit > 0.0 else Color.WHITE)
	_world_transform()
	if enemy.hit > 0.0 or enemy.type == Combat.BOSS:
		var width := 76.0 if enemy.type == Combat.BOSS else 37.0
		var origin: Vector2 = enemy.pos - Vector2(width / 2.0, height * FOE_SCALE + 8.0)
		draw_rect(Rect2(origin - Vector2.ONE, Vector2(width + 2.0, 6.0)), Color("#241b37"))
		draw_rect(Rect2(origin, Vector2(width * float(enemy.hp) / float(info.hp), 4.0)), Color("#ffd07a") if enemy.type == Combat.BOSS else Color("#ff637f"))

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
			draw_circle(enemy.pos, Combat.SLAM_RADIUS, Color("#e45a6c35"))
			_arc(enemy.pos, Vector2.ONE * Combat.SLAM_RADIUS, 0.0, TAU, 3.0, Color("#ff7b8e"))
		elif enemy.spawn > 0.0 and enemy.spawn < 0.75:
			var width: float = 13.0 + 17.0 * enemy.spawn
			_arc(enemy.pos, Vector2(width, width * 0.4), 0.0, TAU, 3.0, Color("#bc9aff"))

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

func _shadow(point: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(16):
		points.append(point + Vector2.from_angle(i * TAU / 16.0) * radius)
	draw_colored_polygon(points, color)

func _arc(center: Vector2, radius: Vector2, start: float, sweep: float, pixels: float, color: Color) -> void:
	var dots := maxi(1, ceili(maxf(radius.x, radius.y) * sweep / 3.0))
	for i in range(dots + 1):
		_square(center + Vector2.from_angle(start + sweep * i / dots) * radius, pixels, color)

func _square(point: Vector2, pixels: float, color: Color) -> void:
	draw_rect(Rect2(point.snapped(Vector2.ONE * 3.0), Vector2.ONE * pixels), color)
