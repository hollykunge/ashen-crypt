extends Node2D
## 刀客各动作演示（3/4 侧身对比）：左边正侧面玄铁重甲，右边 3/4 侧身玄铁重甲，都用网格蒙皮。
##   godot --path mobile --write-movie <输出.avi> --fixed-fps 30 res://tests/hero_rig_movie34.tscn
const Puppet = preload("res://scripts/hero_puppet.gd")
const Cleave = preload("res://scripts/leaping_cleave.gd")
const SIZE := Vector2(1600, 900)
const GROUND := 760.0
const ZOOM := 1.0
const OUTFITS := [
	["正侧面", {"armor": "plate", "gloves": "plate", "greaves": "plate", "boots": "plate"}, "res://art/hero-rig/"],
	["3/4 侧身", {}, "res://art/hero-rig-34/"],
]
## [名字, 动作, 秒数]
const CLIPS := [
	["待机", "idle", 3.0],
	["备战", "ready", 2.5],
	["走", "walk", 4.5],
	["跑", "run", 4.0],
	["劈砍", "attack", 4.2],
	["连招", "combo", 4.2],
	["腾身重劈", "cleave", 3.8],
	["受击", "hurt", 2.4],
	["后撤", "retreat", 2.4],
	["技能", "skill", 2.6],
]
const COMBO_CUES := [0.20, 0.56]
const COMBO_SECONDS := 1.6

var puppets := []
var title := Label.new()
var font: Font = preload("res://art/fonts/game.otf")
var clip := -1
var clip_t := 0.0
var scroll := 0.0

func _ready() -> void:
	get_window().size = Vector2i(SIZE)
	RenderingServer.set_default_clear_color(Color("d9cdb5"))
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for i in OUTFITS.size():
		var p = Puppet.new(OUTFITS[i][2])
		add_child(p)
		var pieces: Dictionary = OUTFITS[i][1]
		p.equip(true, pieces.has("armor"), pieces.get("armor", "") in ["leather", "chain"], pieces)
		p.scale *= ZOOM
		p.position = Vector2(SIZE.x / OUTFITS.size() * (i + 0.42), GROUND)
		puppets.append(p)
		var name_label := _label(OUTFITS[i][0], 30)
		name_label.position = Vector2(SIZE.x / OUTFITS.size() * i, GROUND + 70)
		name_label.size = Vector2(SIZE.x / OUTFITS.size(), 40)
		add_child(name_label)
	title = _label("", 54)
	title.position = Vector2(0, 34)
	title.size = Vector2(SIZE.x, 70)
	add_child(title)
	_next()

func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("3a2c22"))
	return l

func _next() -> void:
	clip += 1
	clip_t = 0.0
	if clip >= CLIPS.size():
		get_tree().quit()
		return
	title.text = CLIPS[clip][0]
	for p in puppets:
		p.pose_override = {}
		p.drive_t = -1.0

func _process(delta: float) -> void:
	if clip >= CLIPS.size():
		return
	clip_t += delta
	var kind: String = CLIPS[clip][1]
	var speed := 0.0
	for p in puppets:
		match kind:
			"idle", "ready":
				p.drive_motion(StringName(kind), 0.0, false, -1.0, {})
			"walk", "run":
				p.play(kind)
				p.drive_t = -1.0
				speed = p.walk_speed()
			"attack":
				# 一刀一停：出刀 + 0.3 秒回到备战
				var cycle: float = p.attack_end_time() + 0.3
				var t := fmod(clip_t, cycle)
				p.drive_motion(&"", 0.0, false, t if t < p.attack_end_time() else -1.0, {})
				if t >= p.attack_end_time():
					p.drive_motion(&"ready", 0.0, false, -1.0, {})
			"combo":
				var t := fmod(clip_t, COMBO_SECONDS + 0.5)
				if t < COMBO_SECONDS:
					p.drive_combo(t / COMBO_SECONDS, COMBO_CUES)
				else:
					p.drive_motion(&"ready", 0.0, false, -1.0, {})
			"cleave":
				var t := fmod(clip_t, Cleave.DURATION + 0.6)
				if t < Cleave.DURATION:
					p.drive_cleave(t / Cleave.DURATION)
				else:
					p.pose_override = {}
					p.drive_motion(&"ready", 0.0, false, -1.0, {})
			_:
				var t := fmod(clip_t, 1.2)
				p.drive_motion(&"ready", 0.0, false, -1.0, _reaction(kind, t / 0.8))
	scroll += speed * delta
	queue_redraw()
	if clip_t >= float(CLIPS[clip][2]):
		_next()

## 和 cutout_hero.gd 里战场用的受击、后撤、技能姿势一致
func _reaction(kind: String, phase: float) -> Dictionary:
	var s := sin(clampf(phase, 0.0, 1.0) * PI)
	match kind:
		"hurt":
			return {"torso": -14.0 * s, "neck": 8.0 * s, "dx": -0.07 * s, "hip": 0.94 - 0.04 * s,
				"arm_near_up": 12.0, "arm_near_lo": 65.0}
		"retreat":
			return {"torso": -10.0 * s, "neck": 5.0 * s, "dx": -0.10 * s, "hip": 0.94 - 0.04 * s,
				"arm_near_up": 38.0, "arm_near_lo": 75.0}
		_:
			return {"torso": 6.0 - 12.0 * s, "neck": 3.0 * s, "arm_near_up": 26.0 + 95.0 * s,
				"arm_near_lo": 40.0 - 15.0 * s, "arm_far_up": 31.0 + 40.0 * s, "arm_far_lo": 78.0 - 40.0 * s}

func _draw() -> void:
	draw_rect(Rect2(0, GROUND, SIZE.x, SIZE.y - GROUND), Color("c4b496"))
	draw_line(Vector2(0, GROUND), Vector2(SIZE.x, GROUND), Color("8a7558"), 3.0)
	# 地上的石缝按步速往后退，脚就钉在地上
	var gap := 90.0
	var x0 := -fmod(scroll, gap)
	while x0 < SIZE.x:
		draw_line(Vector2(x0, GROUND + 8), Vector2(x0 - 26, GROUND + 40), Color("a8936f"), 3.0)
		x0 += gap
