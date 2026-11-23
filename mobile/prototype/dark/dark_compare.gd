extends Node2D
## 对比：同一古墓场景里，左边正侧面（现在的拆件），右边 3/4 侧身英雄比例（新小样），同步做同一套动作。
##   godot --path mobile res://prototype/dark/dark_compare.tscn
const Puppet = preload("res://scripts/hero_puppet.gd")
const Cleave = preload("res://scripts/leaping_cleave.gd")
const SIZE := Vector2(1600, 900)
const FLOOR := 800.0
const BG_SCALE := 1600.0 / 1536.0
const BG_Y := -95.0
const HEROES := [
	["正侧面（现在）", "res://art/hero-rig/", {"armor": "plate", "gloves": "plate", "greaves": "plate", "boots": "plate"}, 470.0],
	["3/4 侧身 · 英雄比例（小样）", "res://art/hero-rig-34/", {}, 1130.0],
]
## [开始秒, 动作]
const SCRIPT := [[0.0, "ready"], [1.4, "combo"], [3.6, "ready"], [4.4, "cleave"], [6.2, "ready"],
	[7.0, "walk"], [10.0, "run"], [12.5, "attack"], [14.3, "ready"], [15.6, "end"]]
const COMBO_CUES := [0.20, 0.56]
const COMBO_SECONDS := 1.6

var heroes := []
var lights := []
var t := 0.0
var step := -1
var action := ""
var start_t := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var bg := Sprite2D.new()
	bg.texture = load("res://prototype/dark/tomb.png")
	bg.centered = false
	bg.scale = Vector2.ONE * BG_SCALE
	bg.position = Vector2(0, BG_Y)
	add_child(bg)
	for h in HEROES:
		var shadow := Node2D.new()
		shadow.position = Vector2(h[3] + 10, FLOOR + 4)
		shadow.draw.connect(func(): shadow.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.22)); shadow.draw_circle(Vector2.ZERO, 120.0, Color(0, 0, 0, 0.55)))
		add_child(shadow)
		# 每个人一张透明画布，单独打光（光从离他近的那支火把来）
		var stage := SubViewport.new()
		stage.size = Vector2i(SIZE)
		stage.transparent_bg = true
		stage.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(stage)
		var hero = Puppet.new(h[1])
		var pieces: Dictionary = h[2]
		hero.equip(true, pieces.has("armor"), true, pieces)
		hero.scale *= 0.95
		hero.position = Vector2(h[3], FLOOR)
		stage.add_child(hero)
		heroes.append(hero)
		var lit := Sprite2D.new()
		lit.texture = stage.get_texture()
		lit.centered = false
		var light := ShaderMaterial.new()
		light.shader = load("res://prototype/dark/hero_light.gdshader")
		light.set_shader_parameter("light_dir", Vector2(-1.0, -0.6) if h[3] < 800 else Vector2(1.0, -0.6))
		lit.material = light
		lights.append(light)
		add_child(lit)
		var label := _label(h[0], 30)
		label.position = Vector2(h[3] - 300, FLOOR + 40)
		label.size = Vector2(600, 40)
		add_child(label)
	var grade := ColorRect.new()
	grade.size = SIZE
	grade.material = ShaderMaterial.new()
	grade.material.shader = load("res://prototype/dark/grade.gdshader")
	grade.material.set_shader_parameter("vignette", 0.6)
	add_child(grade)

func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", preload("res://art/fonts/game.otf"))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("e2cfa8"))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	return l

func _process(delta: float) -> void:
	t += delta
	while step + 1 < SCRIPT.size() and t >= float(SCRIPT[step + 1][0]):
		step += 1
		action = SCRIPT[step][1]
		start_t = t
	if action == "end":
		get_tree().quit()
		return
	var local := t - start_t
	var flicker := 0.9 + 0.1 * sin(t * 13.0) * sin(t * 7.3 + 1.0)
	for i in heroes.size():
		var hero = heroes[i]
		lights[i].set_shader_parameter("light_amount", 1.0 * flicker)
		match action:
			"walk", "run":
				hero.play(action)
				hero.drive_t = -1.0
				hero.pose_override = {}
			"ready":
				hero.pose_override = {}
				hero.drive_motion(&"ready", 0.0, false, -1.0, {})
			"attack":
				hero.drive_motion(&"", 0.0, false, local if local < hero.attack_end_time() else -1.0, {})
			"combo":
				if local < COMBO_SECONDS:
					hero.drive_combo(local / COMBO_SECONDS, COMBO_CUES)
				else:
					hero.drive_motion(&"ready", 0.0, false, -1.0, {})
			"cleave":
				if local < Cleave.DURATION:
					hero.drive_cleave(local / Cleave.DURATION)
				else:
					hero.pose_override = {}
					hero.drive_motion(&"ready", 0.0, false, -1.0, {})
