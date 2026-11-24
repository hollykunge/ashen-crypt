extends Node3D
## 3D 角色试穿台：上半屏是侧面角色，下半屏按钮换各槽款式、切动作、转身。
## 截图自检：godot --path mobile res://prototype/model_hero/model_hero_demo.tscn -- --shots <目录>
##（按 SHOTS 依次摆好款式和动作，每张存一张 png 后退出）

const ModelHero = preload("res://scripts/model_hero.gd")

const SLOT_NAMES := {"torso": "上衣", "arms": "手臂", "legs": "裤子", "feet": "鞋", "shoulder": "肩甲", "hood": "兜帽"}
const VARIANT_NAMES := {"peasant": "布衣", "ranger": "游侠", "leather": "皮甲", "none": "无"}
const ACTIONS := [
	["Idle_Loop", "待机"], ["Walk_Loop", "走"], ["Jog_Fwd_Loop", "慢跑"], ["Sprint_Loop", "冲刺"],
	["Sword_Idle", "戒备"], ["Sword_Attack", "挥砍"], ["Hit_Chest", "受击·胸"], ["Hit_Head", "受击·头"],
	["Death01", "倒地"], ["Roll", "翻滚"],
]
const ALL_SAME := {"布衣全套": "peasant", "游侠全套": "ranger", "皮甲全套": "leather"}
## 自检截图：[款式, 动作, 动作播到第几秒]
const SHOTS := [
	[{"torso": "leather", "arms": "leather", "legs": "leather", "feet": "leather", "shoulder": "leather", "hood": "none"}, "Idle_Loop", 0.5],
	[{"torso": "peasant", "arms": "peasant", "legs": "peasant", "feet": "peasant", "shoulder": "none", "hood": "none"}, "Walk_Loop", 0.4],
	[{"torso": "ranger", "arms": "ranger", "legs": "ranger", "feet": "ranger", "shoulder": "ranger", "hood": "ranger"}, "Sprint_Loop", 0.2],
	[{"torso": "peasant", "arms": "leather", "legs": "ranger", "feet": "leather", "shoulder": "leather", "hood": "none"}, "Sword_Attack", 0.75],
	[{"torso": "leather", "arms": "leather", "legs": "leather", "feet": "leather", "shoulder": "leather", "hood": "ranger"}, "Death01", 2.4],
]

var hero: Node3D
var camera := Camera3D.new()
var _slot_buttons := {}
var _facing := 1.0


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#c9c3b6")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#8a7d72")
	env.environment.ambient_light_energy = 0.55
	add_child(env)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.25
	key.light_color = Color("#fff1dd")
	add_child(key)
	key.look_at_from_position(Vector3(-3.0, 4.0, 2.5), Vector3.ZERO)

	hero = ModelHero.new()
	add_child(hero)
	hero.hold("sword", {})
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.3  # 竖屏下半是按钮：人物放在上半屏，脚底在按钮区上面
	add_child(camera)
	_aim_camera()
	_build_ui()

	var args := OS.get_cmdline_user_args()
	var i := args.find("--shots")
	if i >= 0 and i + 1 < args.size():
		_take_shots(args[i + 1])


func _aim_camera(follow := 0.0) -> void:
	# 角色朝 +Z；相机放在角色右侧（-X）看过去，角色在画面里朝右。转身就把相机挪到另一侧
	camera.look_at_from_position(Vector3(-6.0 * _facing, -0.2, follow), Vector3(0.0, -0.2, follow))


var _follow := 0.0


func _process(delta: float) -> void:
	# 镜头左右跟着骨盆走（倒地时身体往后躺出去），上下不动
	_follow = lerpf(_follow, hero.hip_position().z, 1.0 - exp(-6.0 * delta))
	_aim_camera(_follow)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -330
	panel.offset_left = 10
	panel.offset_right = -10
	panel.offset_bottom = -12
	panel.add_theme_constant_override("separation", 6)
	layer.add_child(panel)

	var sets := HBoxContainer.new()
	for label in ALL_SAME:
		var b := _button(label)
		b.pressed.connect(_wear_all.bind(ALL_SAME[label]))
		sets.add_child(b)
	var turn := _button("转身")
	turn.pressed.connect(func(): _facing = -_facing; _aim_camera())
	sets.add_child(turn)
	var weapon := _button("兵器：剑")
	weapon.pressed.connect(func():
		var forms := ["sword", "spear", "bow"]
		var next: String = forms[(forms.find(hero.weapon_form) + 1) % forms.size()]
		hero.hold(next, {})
		weapon.text = "兵器：" + {"sword": "剑", "spear": "长枪", "bow": "弓"}[next])
	sets.add_child(weapon)
	panel.add_child(sets)

	var grid := GridContainer.new()
	grid.columns = 3
	for slot in SLOT_NAMES:
		var b := _button("")
		b.pressed.connect(_cycle.bind(slot))
		_slot_buttons[slot] = b
		grid.add_child(b)
	panel.add_child(grid)

	var moves := GridContainer.new()
	moves.columns = 4
	for a in ACTIONS:
		var b := _button(a[1])
		b.pressed.connect(hero.play.bind(a[0]))
		moves.add_child(b)
	panel.add_child(moves)
	_refresh()


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 40)
	b.add_theme_font_size_override("font_size", 15)
	return b


func _cycle(slot: String) -> void:
	var variants: Array = ModelHero.SLOTS[slot].keys()
	var next: String = variants[(variants.find(hero.outfit[slot]) + 1) % variants.size()]
	hero.set_slot(slot, next)
	_refresh()


func _wear_all(variant: String) -> void:
	for slot in ["torso", "arms", "legs", "feet"]:
		hero.outfit[slot] = variant
	hero.outfit.shoulder = variant if variant != "peasant" else "none"
	hero.outfit.hood = "none"
	hero.apply_outfit()
	_refresh()


func _refresh() -> void:
	for slot in _slot_buttons:
		_slot_buttons[slot].text = "%s：%s" % [SLOT_NAMES[slot], VARIANT_NAMES[hero.outfit[slot]]]


func _take_shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for k in SHOTS.size():
		var shot: Array = SHOTS[k]
		hero.outfit = shot[0].duplicate()
		hero.apply_outfit()
		_refresh()
		hero.anim.play(hero.anim_name(shot[1]), 0.0)
		hero.anim.seek(shot[2], true)
		hero.anim.pause()
		_follow = hero.hip_position().z
		for _f in 3:
			await RenderingServer.frame_post_draw
		var path := dir.path_join("shot_%d_%s.png" % [k, shot[1]])
		get_viewport().get_texture().get_image().save_png(path)
		print("SHOT ", path)
	get_tree().quit()
