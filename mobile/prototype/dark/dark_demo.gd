extends Node2D
## 暗黑风小样：古墓背景 + 火把光 + 刀客走、打、换装。
##   godot --path mobile res://prototype/dark/dark_demo.tscn
##   录视频：根目录放 override.cfg 把窗口改成 1600x900，再加 --write-movie <输出.avi> --fixed-fps 30
const Puppet = preload("res://scripts/hero_puppet.gd")
const Cleave = preload("res://scripts/leaping_cleave.gd")
const SIZE := Vector2(1600, 900)
const FLOOR := 800.0
const ZOOM := 0.95
## 背景图里两支火把的位置（背景贴图像素）
const TORCHES := [Vector2(296, 368), Vector2(1250, 368)]
const BG_SCALE := 1600.0 / 1536.0
const BG_Y := -95.0

const FULL := {
	"cloth": {"armor": "cloth", "gloves": "cloth", "greaves": "cloth", "boots": "cloth"},
	"leather": {"armor": "leather", "gloves": "leather", "greaves": "leather", "boots": "leather"},
	"chain": {"armor": "chain", "gloves": "chain", "greaves": "chain", "boots": "chain"},
	"plate": {"armor": "plate", "gloves": "plate", "greaves": "plate", "boots": "plate"},
	"mixed": {"armor": "plate", "gloves": "leather", "greaves": "chain", "boots": "cloth"},
}
const NAMES := {"cloth": "布衣", "leather": "皮甲", "chain": "链甲", "plate": "玄铁重甲",
	"mixed": "混搭：玄铁上衣 · 皮护腕 · 链甲护腿 · 布鞋"}
## [开始秒, 动作, 衣装]
const SCRIPT := [
	[0.0, "walk", "plate"], [3.4, "ready", "plate"], [4.6, "combo", "plate"], [6.9, "cleave", "plate"],
	[8.8, "ready", "cloth"], [9.6, "attack", "cloth"],
	[11.6, "ready", "leather"], [12.4, "attack", "leather"],
	[14.4, "ready", "chain"], [15.2, "attack", "chain"],
	[17.2, "ready", "mixed"], [18.0, "combo", "mixed"], [20.4, "cleave", "mixed"],
	[22.3, "run", "mixed"], [24.2, "end", ""],
]
const COMBO_CUES := [0.20, 0.56]
const COMBO_SECONDS := 1.6

var hero = Puppet.new()
var stage := SubViewport.new()
var lit := Sprite2D.new()
var light := ShaderMaterial.new()
var caption := Label.new()
var t := 0.0
var step := -1
var action := ""
var start_t := 0.0
var shadow := Node2D.new()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var bg := Sprite2D.new()
	bg.texture = load("res://prototype/dark/tomb.png")
	bg.centered = false
	bg.scale = Vector2.ONE * BG_SCALE
	bg.position = Vector2(0, BG_Y)
	add_child(bg)
	for p in TORCHES:
		add_child(_embers(_torch_screen(p)))
	shadow.draw.connect(func(): shadow.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.22)); shadow.draw_circle(Vector2.ZERO, 120.0, Color(0, 0, 0, 0.55)))
	add_child(shadow)
	# 人物先画进透明画布，整张再打光：边光沿整个人的外轮廓，不会在部件接缝上起线
	stage.size = Vector2i(SIZE)
	stage.transparent_bg = true
	stage.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	hero.scale *= ZOOM
	hero.position = Vector2(-120, FLOOR)
	stage.add_child(hero)
	lit.texture = stage.get_texture()
	lit.centered = false
	light.shader = load("res://prototype/dark/hero_light.gdshader")
	lit.material = light
	add_child(lit)
	var grade := ColorRect.new()
	grade.size = SIZE
	grade.material = ShaderMaterial.new()
	grade.material.shader = load("res://prototype/dark/grade.gdshader")
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grade)
	caption.add_theme_font_override("font", preload("res://art/fonts/game.otf"))
	caption.add_theme_font_size_override("font_size", 34)
	caption.add_theme_color_override("font_color", Color("d8c3a0"))
	caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	caption.add_theme_constant_override("outline_size", 8)
	caption.position = Vector2(48, 40)
	add_child(caption)

func _torch_screen(p: Vector2) -> Vector2:
	return p * BG_SCALE + Vector2(0, BG_Y)

func _embers(at: Vector2) -> CPUParticles2D:
	var e := CPUParticles2D.new()
	e.position = at + Vector2(0, -20)
	e.amount = 26
	e.lifetime = 2.2
	e.direction = Vector2.UP
	e.spread = 25.0
	e.gravity = Vector2(0, -30)
	e.initial_velocity_min = 20.0
	e.initial_velocity_max = 55.0
	e.scale_amount_min = 1.5
	e.scale_amount_max = 3.5
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.75, 0.35, 1.0))
	ramp.set_color(1, Color(1.0, 0.35, 0.1, 0.0))
	e.color_ramp = ramp
	return e

func _process(delta: float) -> void:
	t += delta
	while step + 1 < SCRIPT.size() and t >= float(SCRIPT[step + 1][0]):
		step += 1
		_begin(SCRIPT[step])
	if action == "end":
		get_tree().quit()
		return
	var local := t - start_t
	match action:
		"walk", "run":
			hero.play(action)
			hero.drive_t = -1.0
			hero.pose_override = {}
			hero.position.x += hero.walk_speed() * delta
		"ready":
			hero.drive_motion(&"ready", 0.0, false, -1.0, {})
		"attack":
			hero.drive_motion(&"", 0.0, false, local if local < hero.attack_end_time() else -1.0, {})
			if local >= hero.attack_end_time():
				hero.drive_motion(&"ready", 0.0, false, -1.0, {})
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
	_update_light()
	shadow.position = Vector2(hero.position.x + 10, FLOOR + 4)

func _begin(entry: Array) -> void:
	action = entry[1]
	start_t = t
	var look: String = entry[2]
	if look.is_empty():
		return
	var pieces: Dictionary = FULL[look]
	hero.equip(true, true, pieces.armor in ["leather", "chain", "plate"], pieces)
	caption.text = NAMES[look]

## 光从最近的火把来：方向朝火把，越近越亮；火苗闪烁
func _update_light() -> void:
	var chest: Vector2 = hero.position + Vector2(0, -300)
	var best := Vector2.ZERO
	var best_d := INF
	for p in TORCHES:
		var s := _torch_screen(p)
		if chest.distance_to(s) < best_d:
			best_d = chest.distance_to(s)
			best = s
	var flicker := 0.9 + 0.1 * sin(t * 13.0) * sin(t * 7.3 + 1.0)
	light.set_shader_parameter("light_dir", (best - chest).normalized())
	light.set_shader_parameter("light_amount", clampf(1.45 - best_d / 800.0, 0.65, 1.25) * flicker)
