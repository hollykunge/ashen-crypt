extends Control

const Combat = preload("res://scripts/combat.gd")
const Arena = preload("res://scripts/arena.gd")
const Sound = preload("res://scripts/sound.gd")
const Gothic = preload("res://scripts/gothic.gd")
const Gear = preload("res://scripts/gear.gd")
const Forge = preload("res://scripts/forge.gd")
const EquipmentSlot = preload("res://scripts/equipment_slot.gd")
const CharacterPage = preload("res://scripts/character_page.gd")
const Roster = preload("res://scripts/roster.gd")
const Appearance = preload("res://scripts/appearance.gd")
const Stick = preload("res://scripts/stick.gd")
const Turnover = preload("res://scripts/layer_turnover.gd")
const TribulationNotice = preload("res://scripts/tribulation_notice.gd")
const PlaceNotice = preload("res://scripts/place_notice.gd")
const SideArt = preload("res://scripts/side_art.gd")
const BattleStrip = preload("res://scripts/battle_strip.gd")
const CampPouch = preload("res://scripts/camp_pouch.gd")
const TitlePage = preload("res://scripts/title_page.gd")
const CharacterSelect = preload("res://scripts/character_select.gd")
const HeroSheet = preload("res://scripts/hero_sheet.gd")
const OfflineCard = preload("res://scripts/offline_card.gd")
const CAMP = preload("res://art/ink/mountain-road.png")
const FORGE_BG = preload("res://art/ink/mountain-road.png")
const SPELL_ATLAS = preload("res://art/immortals/spells.webp")
const SPELL_GRADE = preload("res://art/gothic_grade.gdshader")
const FONT = preload("res://art/fonts/game.otf")
const HEADING_FONT = preload("res://art/fonts/heading.tres")

const NIGHT := Color("#f0e0bf")
const INK := Color("#302820")
const GOLD := Color("#785b3e")
const MUTED := Color("#766858")
const IRON := Color("#e4d1ac")
const BORDER := Color("#9b7955")
const CRIMSON := Color("#8f3d32")
const SPELL_CELL := Vector2(128, 128)
const SPELL_INDEX := {
	&"sword": 0, &"slash": 1, &"cleave": 2, &"retreat": 3,
	&"arrow": 4, &"fan": 5, &"heavy": 6, &"portal": 7,
	&"spark": 8, &"sigil": 9, &"frost": 10, &"pause": 11
}

var run := Combat.new()
var profile := Gear.new()
var sounds := Sound.new()
var state: StringName = &"title"
# 三个角色各一份存档，save_base 是第一格的文件名；测试把它换成临时文件。
var save_base := Gear.SAVE_PATH
var active_slot := -1
# 本次挂机的统计，换角色时清零。灵砂按击杀掉落，攒一会儿再一起写进存档。
const CHECKPOINT_INTERVAL := 15.0
var farm_seconds := 0.0
var farm_kills := 0
var farm_silver := 0
var farm_materials := 0
var pending_silver := 0
var checkpoint_left := CHECKPOINT_INTERVAL
var silver_rng := RandomNumberGenerator.new()
var touches: Dictionary = {}
var action_buttons: Dictionary = {}
var action_glyphs: Dictionary = {}
var cooldown_sweeps: Dictionary = {}
var cooldown_totals: Dictionary = {}
var sound_buttons: Array[Button] = []
var spell_textures: Dictionary = {}
var spell_grade := ShaderMaterial.new()

var safe: MarginContainer
var camp: TextureRect
var camp_shade: TextureRect
var battle_shade: TextureRect
var battle_portrait: TextureRect
var retinue_faces: HBoxContainer
var selection: CharacterPage
var title_page: TitlePage
var roster_page: CharacterSelect
var hero_sheet: HeroSheet
var offline_card: OfflineCard
var hero_chip: Button
var hero_face: TextureRect
var roster_button: Button
var battle: VBoxContainer
var battle_header: GridContainer
var battle_tools: HBoxContainer
var pouch: CampPouch
var challenge_sweep: Gothic.Sweep
# 上一次报过地名的层；从炉坊、告示回到挂机不再报一遍。
var announced_layer := 0
var farm_actions: HBoxContainer
var challenge_button: Button
var challenge_caption := ""
var boss_controls: VBoxContainer
var skill_row: HBoxContainer
var manual_movement: HBoxContainer
var mode_button: Button
var speed_button: Button
var stop_route_button: Button
var next_layer_left := 0.0
var control_mode := Combat.ControlMode.ASSISTED
var battle_speed := 1
var gear_slots := {}
var tribulation_notice: TribulationNotice
var place_notice: PlaceNotice
var forge_return_to_notice := false
var turnover: Turnover
var retry_until := 0.0
var original_design_size: Vector2i
var forge: Forge
var life_meter: Gothic.Meter
var mana_meter: Gothic.Meter
var life_value: Label
var mana_value: Label
var field: Arena
var stick: Stick
var gear_card: Node
# 战斗时顶上只留 strip（日暮月三波、余敌小点、层主血条），过层和层主登场用 banner 在正中写一行大字，停一会儿就淡掉。
var strip: BattleStrip
var banner: VBoxContainer
var banner_title: Label
var banner_sub: Label
var banner_fade: Tween
var hint_time := 0.0
var boss_announced := false

func _ready() -> void:
	original_design_size = get_window().content_scale_size
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	spell_grade.shader = SPELL_GRADE
	spell_grade.set_shader_parameter("grade_weight", 0.68)
	spell_grade.set_shader_parameter("exposure", 1.14)
	var ui_style := Theme.new()
	ui_style.default_font = FONT
	ui_style.default_font_size = 16
	for control_type in ["OptionButton", "LineEdit", "PopupMenu", "CheckBox"]:
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			ui_style.set_color(key, control_type, INK)
		ui_style.set_color("font_disabled_color", control_type, MUTED)
	for key in ["normal", "hover", "pressed", "focus", "disabled"]:
		ui_style.set_stylebox(key, "OptionButton", _box(IRON, BORDER, 1, 6))
	ui_style.set_stylebox("panel", "PopupMenu", _box(NIGHT, BORDER, 1, 6))
	theme = ui_style
	add_child(sounds)
	run.feedback.connect(sounds.play)
	silver_rng.randomize()
	run.material_collected.connect(_stash_material)
	run.enemy_slain.connect(_on_enemy_slain)
	_build_view()
	resized.connect(_adapt_safe_area)
	_adapt_safe_area()
	_show_title()

func _build_view() -> void:
	var base := ColorRect.new()
	base.color = NIGHT
	_fill(base)
	add_child(base)

	camp = _image(CAMP)
	camp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_fill(camp)
	add_child(camp)
	camp_shade = _image(_camp_gradient())
	_fill(camp_shade)
	add_child(camp_shade)
	field = Arena.new()
	field.clip_contents = true
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.run = run
	add_child(field)
	_fill(field)
	battle_shade = _image(_battle_gradient())
	add_child(battle_shade)
	_fill(battle_shade)

	safe = MarginContainer.new()
	_fill(safe)
	add_child(safe)
	var page := _vbox(0)
	safe.add_child(page)

	title_page = TitlePage.new()
	title_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	title_page.build(self)
	title_page.start_requested.connect(_show_roster)
	page.add_child(title_page)
	roster_page = CharacterSelect.new()
	roster_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_page.build(self)
	roster_page.play_requested.connect(_play_slot)
	roster_page.create_requested.connect(_create_in_slot)
	roster_page.back_requested.connect(_show_title)
	roster_page.hide()
	page.add_child(roster_page)

	selection = CharacterPage.new()
	selection.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_selection()
	page.add_child(selection)

	battle = _vbox(9)
	battle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(battle)
	_build_battle()
	forge = Forge.new()
	forge.ui = self
	forge.profile = profile
	forge.size_flags_vertical = Control.SIZE_EXPAND_FILL
	forge.close_requested.connect(_close_forge)
	forge.hide()
	page.add_child(forge)
	stick = Stick.new()
	stick.hide()
	add_child(stick)
	_fill(stick)
	_build_overlay()

func _build_selection() -> void:
	selection.ui = self
	selection.profile = profile
	selection.journey_requested.connect(_begin_new_character)
	selection.back_requested.connect(_show_roster)

func _build_battle() -> void:
	battle.add_theme_constant_override("separation", 7)
	battle_header = GridContainer.new()
	battle_header.add_theme_constant_override("h_separation", 10)
	battle_header.add_theme_constant_override("v_separation", 5)
	battle.add_child(battle_header)
	var stage_info := _vbox(5)
	stage_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_header.add_child(stage_info)

	# 顶栏左边不写字：挂机时是头像和一只材料袋，连战时是日暮月三波。层数、地名在进层那一下用正中大字报。
	var camp_row := _hbox(8)
	stage_info.add_child(camp_row)
	hero_chip = _button("", false, 56)
	hero_chip.custom_minimum_size = Vector2(46, 56)
	hero_chip.clip_contents = true
	_describe(hero_chip, "角色信息")
	hero_chip.pressed.connect(_open_hero_sheet)
	hero_face = _image(SideArt.PORTRAIT)
	hero_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hero_chip.add_child(hero_face)
	_fill(hero_face)
	hero_face.offset_left = 2.0
	hero_face.offset_top = 2.0
	hero_face.offset_right = -2.0
	hero_face.offset_bottom = -2.0
	camp_row.add_child(hero_chip)
	pouch = CampPouch.new()
	pouch.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	camp_row.add_child(pouch)
	strip = BattleStrip.new()
	strip.waves = Combat.WAVE_SIZES.size()
	strip.hide()
	stage_info.add_child(strip)

	var switches := _hbox(7)
	switches.size_flags_horizontal = Control.SIZE_SHRINK_END
	switches.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	battle_header.add_child(switches)
	battle_tools = _hbox(6)
	switches.add_child(battle_tools)
	mode_button = _icon_button(&"assist", "", false, Vector2(44, 44))
	mode_button.pressed.connect(_cycle_control_mode)
	battle_tools.add_child(mode_button)
	speed_button = _icon_button(&"speed1", "", false, Vector2(44, 44))
	speed_button.pressed.connect(_cycle_battle_speed)
	battle_tools.add_child(speed_button)
	stop_route_button = _icon_button(&"leave", "停止连战", false, Vector2(44, 44))
	stop_route_button.pressed.connect(_stop_route)
	stop_route_button.hide()
	battle_tools.add_child(stop_route_button)
	roster_button = _icon_button(&"leave", "返回选角", false, Vector2(44, 44))
	roster_button.pressed.connect(_show_roster)
	switches.add_child(roster_button)
	switches.add_child(_sound_button())

	var tags := _hud_card(battle, 6)
	gear_card = tags.get_parent()
	var slot_row := _hbox(8)
	slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tags.add_child(slot_row)
	for slot in Gear.SLOTS:
		var frame := EquipmentSlot.new(44)
		frame.pressed.connect(_press_camp_slot.bind(slot))
		slot_row.add_child(frame)
		gear_slots[slot] = frame

	var spring := _space(1)
	spring.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle.add_child(spring)
	banner = _vbox(2)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.alignment = BoxContainer.ALIGNMENT_CENTER
	banner_title = _label("", 40, Color("#3b3025"))
	banner_sub = _label("", 20, GOLD)
	for line in [banner_title, banner_sub]:
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.add_theme_constant_override("outline_size", 8)
		line.add_theme_color_override("font_outline_color", Color(NIGHT, 0.85))
		banner.add_child(line)
	spring.add_child(banner)
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	banner.offset_top = 28.0
	banner.hide()
	farm_actions = _hbox(7)
	battle.add_child(farm_actions)
	# 底栏三枚图标：行囊、告示牌、出发。调息时出发键上转一圈读条，不报秒数。
	var forge_button := _icon_button(&"pack", "行装", false, Vector2(56, 56))
	forge_button.pressed.connect(_open_forge)
	farm_actions.add_child(forge_button)
	var notice_button := _icon_button(&"notice", "本层告示", false, Vector2(56, 56))
	notice_button.pressed.connect(_show_place_notice)
	farm_actions.add_child(notice_button)
	var push := Control.new()
	push.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	farm_actions.add_child(push)
	challenge_button = _icon_button(&"march", "", true, Vector2(96, 56))
	challenge_button.pressed.connect(_challenge)
	challenge_sweep = Gothic.Sweep.new()
	challenge_button.add_child(challenge_sweep)
	_fill(challenge_sweep)
	farm_actions.add_child(challenge_button)
	for tile in [forge_button, notice_button, challenge_button]:
		var glyph: Control = tile.get_node("Glyph")
		glyph.offset_left = -18.0
		glyph.offset_right = 18.0
		glyph.offset_top = -18.0
		glyph.offset_bottom = 18.0

	boss_controls = _vbox(5)
	battle.add_child(boss_controls)
	manual_movement = _hbox(5)
	manual_movement.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	boss_controls.add_child(manual_movement)
	_add_action(manual_movement, &"back", "后退", false, false)
	_add_action(manual_movement, &"forward", "前进", false, false)

	var hud := _hbox(7)
	boss_controls.add_child(hud)
	var identity := _hud_card(hud, 6, 0.88)
	# 生命、灵力平时只看两条，按住头像这一块才报数。
	identity.get_parent().gui_input.connect(_hold_vitals)
	var portrait_row := _hbox(6)
	identity.add_child(portrait_row)
	battle_portrait = _image(SideArt.PORTRAIT)
	battle_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	battle_portrait.custom_minimum_size = Vector2(43, 56)
	portrait_row.add_child(battle_portrait)
	var vitals := _vbox(2)
	vitals.custom_minimum_size.x = 64.0
	vitals.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait_row.add_child(vitals)
	life_value = _label("", 11, INK)
	life_value.hide()
	vitals.add_child(life_value)
	life_meter = _meter(Color("#be6251"), 5)
	vitals.add_child(life_meter)
	mana_value = _label("", 11, INK)
	mana_value.hide()
	vitals.add_child(mana_value)
	mana_meter = _meter(Color("#79a7a6"), 5)
	vitals.add_child(mana_meter)
	retinue_faces = _hbox(4)
	portrait_row.add_child(retinue_faces)
	for index in range(3):
		var face := _image(SideArt.PORTRAIT)
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		face.custom_minimum_size = Vector2(40.0, 56.0)
		face.modulate = Color("#b7c3c5")
		retinue_faces.add_child(face)
	_update_retinue()
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.add_child(gap)
	skill_row = _hbox(5)
	hud.add_child(skill_row)
	_add_action(skill_row, &"attack", "普攻", true, true)
	_add_action(skill_row, &"skill", "破阵", false, true)
	_add_action(skill_row, &"tactic", "震慑", false, true)
	_add_action(skill_row, &"retreat", "后撤", false, true)
	_update_control_labels()

func _cycle_control_mode() -> void:
	_clear_input()
	control_mode = (int(control_mode) + 1) % Combat.ControlMode.size() as Combat.ControlMode
	_update_control_labels()

func _cycle_battle_speed() -> void:
	battle_speed = battle_speed % 3 + 1
	_update_control_labels()

# 按钮上不写字，名字留给读屏和长按提示。
func _update_control_labels() -> void:
	_set_icon(mode_button, [&"manual", &"assist", &"auto"][control_mode])
	_describe(mode_button, ["手动", "自动普攻", "全自动"][control_mode])
	_restyle(mode_button, control_mode == Combat.ControlMode.AUTOMATIC)
	_set_icon(speed_button, StringName("speed%d" % battle_speed))
	_describe(speed_button, "%d×" % battle_speed)
	manual_movement.visible = control_mode == Combat.ControlMode.MANUAL

func _hold_vitals(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
	elif event is InputEventScreenTouch:
		pressed = event.pressed
	else:
		return
	life_value.visible = pressed
	mana_value.visible = pressed

# 正中一行大字，淡入、停一下、淡出。只在过层、层主登场这种时刻用。
func _announce(title: String, sub := "") -> void:
	banner_title.text = title
	banner_title.visible = not title.is_empty()
	banner_sub.text = sub
	banner_sub.visible = not sub.is_empty()
	if banner_fade != null:
		banner_fade.kill()
	banner.modulate.a = 0.0
	banner.show()
	banner_fade = create_tween()
	banner_fade.tween_property(banner, "modulate:a", 1.0, 0.25)
	banner_fade.tween_interval(1.3)
	banner_fade.tween_property(banner, "modulate:a", 0.0, 0.6)
	banner_fade.tween_callback(banner.hide)

func _update_retinue() -> void:
	var wide := size.x >= size.y * 1.17
	retinue_faces.visible = wide and run.companions > 0
	retinue_faces.accessibility_name = "随侍 %d 人" % run.companions
	for i in range(retinue_faces.get_child_count()):
		retinue_faces.get_child(i).visible = i < run.companions

func _hud_card(parent: Node, padding: int, opacity := 0.94) -> VBoxContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(Color(NIGHT, opacity), Color(BORDER, 0.80), 1, padding))
	parent.add_child(card)
	var content := _vbox(4)
	card.add_child(content)
	return content

func _meter(ink: Color, height: int, segments: int = 0) -> Gothic.Meter:
	var bar := Gothic.Meter.new()
	bar.ink = ink
	bar.ticks = segments
	bar.custom_minimum_size.y = height
	return bar

func _build_overlay() -> void:
	tribulation_notice = preload("res://tribulation_notice.tscn").instantiate()
	add_child(tribulation_notice)
	tribulation_notice.configure(self)
	tribulation_notice.prepare_requested.connect(_open_forge)
	tribulation_notice.challenge_requested.connect(_start_encounter.bind(true, true))
	tribulation_notice.stay_requested.connect(_close_notice)

	place_notice = preload("res://place_notice.tscn").instantiate()
	add_child(place_notice)
	place_notice.configure(self)
	place_notice.accept_requested.connect(_accept_edict)
	place_notice.aid_requested.connect(_aid_place)
	place_notice.refuse_requested.connect(_refuse_edict)

	turnover = Turnover.new()
	turnover.ui = self
	_fill(turnover)
	add_child(turnover)
	turnover.hide()

	hero_sheet = HeroSheet.new()
	add_child(hero_sheet)
	_fill(hero_sheet)
	hero_sheet.build(self)
	hero_sheet.roster_requested.connect(_show_roster)
	offline_card = OfflineCard.new()
	add_child(offline_card)
	_fill(offline_card)
	offline_card.build(self)

func _physics_process(delta: float) -> void:
	if active_slot >= 0 and state not in [&"title", &"roster", &"selection"]:
		checkpoint_left -= delta
		if checkpoint_left <= 0.0:
			checkpoint_left = CHECKPOINT_INTERVAL
			_checkpoint()
	if state in [&"farm", &"jie_notice", &"place_notice"]:
		farm_seconds += delta
	hero_sheet.tick(self, delta)
	if field.visible:
		run.advance_enemy_deaths(delta)
	if state == &"next_layer":
		next_layer_left = maxf(0.0, next_layer_left - delta)
		if not run.enemy_fall_in_progress():
			field.layer_travel = true
			var previous := run.position
			run.position.x += delta * Combat.RUN_SPEED
			run.track_steps(previous)
		if next_layer_left == 0.0:
			_challenge()
		return
	elif state in [&"farm", &"jie_notice", &"place_notice"]:
		run.step(delta)
	elif state == &"boss":
		if run.result == &"victory":
			if not run.enemy_fall_in_progress():
				_finish_challenge(run.result)
			return
		var left := _held(&"back") or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
		var right := _held(&"forward") or Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
		var up := Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
		var down := Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
		var direction := Vector2(int(right) - int(left), int(down) - int(up))
		# 摇杆优先：按下就用摇杆的方向，键盘与前后键仍然可用。
		var steer := stick.value()
		if steer != Vector2.ZERO:
			direction = steer
		var attack := _held(&"attack") or Input.is_physical_key_pressed(KEY_J)
		for _tick in range(battle_speed):
			run.step(delta, direction, attack, control_mode)
			if run.result.is_empty():
				continue
			if run.result == &"victory" and not run.continuous:
				_clear_input()
			else:
				_finish_challenge(run.result)
			break
	else:
		return
	_update_battle()

func _input(event: InputEvent) -> void:
	if forge.detail_cover != null and forge.detail_cover.visible:
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_ESCAPE:
				forge.close_derivation()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_TAB:
				get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: Key = event.physical_keycode if event.physical_keycode else event.keycode
		if key == KEY_ESCAPE:
			if offline_card.visible or hero_sheet.visible:
				offline_card.close()
				hero_sheet.close()
				get_viewport().set_input_as_handled()
				return
			match state:
				&"roster": _show_title()
				&"selection": _show_roster()
				&"forge":
					if forge.inventory and not forge.armory.selected_uid.is_empty():
						forge.armory.inspect("")
					else:
						_close_forge()
				&"jie_notice": _close_notice()
				&"place_notice": _close_place_notice()
				&"boss", &"next_layer":
					if not run.continuous:
						return
					_stop_route()
				_: return
			get_viewport().set_input_as_handled()
			return
		if state == &"boss":
			match key:
				KEY_J: run.attack()
				KEY_Q: run.skill()
				KEY_E: run.tactic()
				KEY_SPACE: run.retreat()
				KEY_M: _cycle_control_mode()
				KEY_V: _cycle_battle_speed()
	if state != &"boss":
		return
	if event is InputEventScreenTouch:
		_handle_pointer(event.index, event.position, event.pressed and not event.canceled)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_pointer(-1, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		stick.drag(event.index, event.position)
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		stick.drag(-1, event.position)

func _handle_pointer(pointer: int, point: Vector2, pressed: bool) -> void:
	if not pressed:
		var moved := stick.release(pointer)
		if touches.erase(pointer) or moved:
			_update_pressed()
			get_viewport().set_input_as_handled()
		return
	for action in action_buttons:
		var control: Button = action_buttons[action]
		if control.disabled or not control.is_visible_in_tree() or not control.get_global_rect().has_point(point):
			continue
		touches[pointer] = action
		_update_pressed()
		match action:
			&"attack": run.attack()
			&"skill": run.skill()
			&"tactic": run.tactic()
			&"retreat": run.retreat()
		get_viewport().set_input_as_handled()
		return
	_fit_stick()
	if stick.accepts(point):
		stick.begin(pointer, point)
		get_viewport().set_input_as_handled()

# 走位区从战况条下沿延伸到技能牌上方。
func _fit_stick() -> void:
	if not is_instance_valid(battle_header) or not is_instance_valid(boss_controls):
		return
	var top := battle_header.get_global_rect().end.y + 6.0
	var bottom: float = boss_controls.get_global_rect().position.y - 6.0
	stick.set_zone(Rect2(0.0, top, size.x, maxf(0.0, bottom - top)))

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_clear_input()
		_checkpoint()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_checkpoint()
	elif what == NOTIFICATION_APPLICATION_RESUMED and is_instance_valid(safe):
		_adapt_safe_area()
		# 手机切到后台时整个循环停了，回来按离开的时长补发挂机收益。
		if state in [&"farm", &"jie_notice", &"place_notice", &"forge"]:
			_settle_offline()

# 开机、选角、创角三页共用山门背景，其余都收起。
func _show_camp_page(page: Control) -> void:
	_clear_input()
	battle.hide()
	field.hide()
	battle_shade.hide()
	forge.hide()
	stick.hide()
	tribulation_notice.hide()
	place_notice.hide()
	turnover.dismiss()
	hero_sheet.hide()
	offline_card.hide()
	banner.hide()
	_fit_forge()
	camp.texture = CAMP
	camp.self_modulate = Color.WHITE
	camp_shade.texture = _camp_gradient()
	camp.show()
	camp_shade.show()
	for other in [title_page, roster_page, selection]:
		other.visible = other == page

func _show_title() -> void:
	_leave_character()
	state = &"title"
	_show_camp_page(title_page)
	roster_page.save_base = save_base
	title_page.refresh(roster_page.count())

func _show_roster() -> void:
	_leave_character()
	state = &"roster"
	_show_camp_page(roster_page)
	roster_page.save_base = save_base
	roster_page.refresh()

func _show_selection() -> void:
	state = &"selection"
	_show_camp_page(selection)
	selection.start_new()

# 选中一格：换成那一格的存档，本次挂机的统计从零记。
func _use_slot(slot: int) -> void:
	_leave_character()
	active_slot = slot
	profile.save_path = Gear.slot_path(slot, save_base)
	profile.load_profile()
	farm_seconds = 0.0
	farm_kills = 0
	farm_silver = 0
	farm_materials = 0
	pending_silver = 0
	checkpoint_left = CHECKPOINT_INTERVAL
	announced_layer = 0
	retry_until = 0.0
	run.drops.clear()

func _create_in_slot(slot: int) -> void:
	_use_slot(slot)
	if profile.has_character():
		_show_roster()
		return
	if not profile.storage_error.is_empty():
		_show_roster()
		roster_page.show_error(profile.storage_error)
		return
	_show_selection()

func _play_slot(slot: int) -> void:
	_use_slot(slot)
	if not profile.has_character():
		_show_roster()
		roster_page.show_error(profile.storage_error if not profile.storage_error.is_empty() else "这一格没有角色")
		return
	_enter_farm()
	_settle_offline()

func _begin_new_character() -> void:
	_enter_farm()
	_checkpoint()

# 离开当前角色前：场上没捡的材料收进袋，攒着的灵砂入账，记下离开的时刻。
func _leave_character() -> void:
	if active_slot < 0 or not profile.has_character():
		return
	if state in [&"farm", &"jie_notice", &"place_notice", &"forge"] and not run.challenging:
		run.collect_pending_materials()
	_checkpoint()

func _checkpoint() -> void:
	if active_slot < 0 or not profile.has_character() or state in [&"title", &"roster", &"selection"]:
		return
	var measured := farm_kills / farm_seconds * 3600.0 if farm_seconds >= 120.0 else 0.0
	if profile.checkpoint(Time.get_unix_time_from_system(), pending_silver, measured):
		pending_silver = 0

func _drop_multiplier() -> float:
	return float(profile.bonuses().get("material_drop_multiplier", 1.0)) * float(Combat.MINION.drop)

func _settle_offline() -> void:
	if active_slot < 0 or not profile.has_character():
		return
	var now := Time.get_unix_time_from_system()
	var report := profile.offline_report(now, _drop_multiplier())
	if not profile.claim_offline(report, now):
		_announce("", profile.storage_error)
		return
	if report.is_empty():
		return
	if state == &"farm":
		_update_battle()
	offline_card.present(self, report)

func _on_enemy_slain(_boss: bool) -> void:
	if run.challenging or active_slot < 0:
		return
	farm_kills += 1
	var coins := Gear.roll_farm_silver(silver_rng, profile.layer(), profile.silver_multiplier())
	pending_silver += coins
	farm_silver += coins

func _open_hero_sheet() -> void:
	if state != &"farm" or not profile.has_character():
		return
	_clear_input()
	hero_sheet.present(self)

func _enter_farm() -> void:
	_start_encounter(false)

func _start_encounter(challenge: bool, continuous_route := false) -> void:
	if not profile.has_character():
		return
	if run.encounter_stem == profile.ling() and not run.challenging:
		run.collect_pending_materials()
	_clear_input()
	tribulation_notice.hide()
	place_notice.hide()
	battle.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	turnover.dismiss()
	var person := profile.character()
	var weapon := profile.item(profile.equipped("weapon"))
	var element := Gear.WuXing.stem_element(person.day_stem)
	battle_portrait.texture = SideArt.PORTRAIT
	hero_face.texture = battle_portrait.texture
	hero_face.modulate = Roster.ELEMENT_TINTS[element].lerp(Color.WHITE, 0.67)
	field.hero_element = element
	var outfit := profile.loadout()
	var form: String = weapon.get("weapon_form", "sword")
	var layer_tribulation := Gear.Realm.jie_ling_of(profile.layer())
	var tribulation := layer_tribulation if challenge else ""
	var ling := profile.ling() if tribulation.is_empty() else tribulation
	if ling != profile.ling():
		outfit = profile.loadout({}, true, ling)
	var bonuses := Gear.Loadout.bonuses(outfit, profile.person_context(), profile.layer())
	# 五个槽位的五行与阴阳同时决定数值和外观：换一件装备，场上的人就跟着换一身。
	field.look = Appearance.build(outfit.entries, outfit.patterns, form, person.get("gender", ""))
	run.trail_color = field.look.trail
	run.leaping_cleave = run.Cleave.supports(field.look)
	run.hit_element = String(field.look.pieces.get("weapon", {}).get("element", ""))
	if state == &"forge" and not challenge and run.dungeon_layer == profile.layer():
		run.refresh_equipment(bonuses, form)
	else:
		run.reset(profile.layer(), bonuses, form, challenge, ling, continuous_route)
		boss_announced = false
	state = &"boss" if challenge else &"farm"
	_set_loadout_slots(outfit.entries, person, challenge)
	farm_actions.visible = not challenge
	challenge_caption = ("开始连战 · 第%d层" if layer_tribulation.is_empty() else "准备渡劫 · 第%d层") % profile.layer()
	_set_icon(challenge_button, &"march" if layer_tribulation.is_empty() else &"jie")
	boss_controls.visible = challenge
	battle_tools.visible = challenge
	pouch.visible = not challenge
	hero_chip.visible = not challenge
	roster_button.visible = not challenge
	strip.visible = challenge
	strip.single = challenge and not run.continuous
	_layout_header()
	# 连战开场报层数和地名；单场冲层一上来就是层主，由层主登场那一下报。
	if challenge and run.continuous:
		_announce("第 %d 层" % profile.layer(), String(profile.place().get("name", "")))
	_update_retinue()
	stop_route_button.visible = challenge and run.continuous
	gear_card.visible = not challenge
	stick.visible = challenge
	if not challenge and announced_layer != profile.layer():
		announced_layer = profile.layer()
		var place := profile.place()
		var calamity := String(place.get("calamity", ""))
		_announce(String(place.get("name", "")), "第 %d 层%s" % [profile.layer(), " · %s灾" % calamity if not calamity.is_empty() else ""])

	selection.hide()
	title_page.hide()
	roster_page.hide()
	forge.hide()
	_fit_forge()
	camp.hide()
	camp_shade.hide()
	field.set_camp_view(not challenge)
	field.show()
	battle_shade.visible = not run.continuous
	battle.show()
	var symbols := {"sword": &"sword", "spear": &"cleave", "bow": &"arrow"}
	_set_glyph(&"attack", symbols.get(form, &"sword"))
	_set_glyph(&"skill", &"slash")
	_set_glyph(&"tactic", &"sigil")
	_describe(action_buttons[&"attack"], "普攻 · " + Gear.Rules.NAME_PARTS.weapons[form])
	_update_battle()
	field.queue_redraw()
	if challenge:
		sounds.play(&"start")

func _set_loadout_slots(entries: Dictionary, person: Dictionary, read_only: bool) -> void:
	for slot in Gear.SLOTS:
		var frame: EquipmentSlot = gear_slots[slot]
		frame.display(slot, entries.get(slot, {}), person, run.weapon_form)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE if read_only else Control.MOUSE_FILTER_STOP
		frame.focus_mode = Control.FOCUS_NONE if read_only else Control.FOCUS_ALL

func _press_camp_slot(slot: String) -> void:
	if state != &"farm":
		return
	_open_forge(slot)

func _update_battle() -> void:
	if state == &"next_layer":
		return
	if state != &"boss":
		var ling := profile.ling()
		pouch.show_state(Gear.material(ling), profile.stock(ling), run.hp, run.max_hp, profile.relief_pending())
		var wait := maxi(profile.challenge_wait(), ceili(retry_until - Time.get_unix_time_from_system()))
		_describe(challenge_button, ("调息 %d 秒 · " % wait + challenge_caption) if wait > 0 else challenge_caption)
		challenge_sweep.show_amount(wait, 30.0, false)
		return
	var enemy: Dictionary = run.enemies[0] if not run.enemies.is_empty() else {}
	strip.current = run.wave_index
	strip.advancing = run.advancing
	var living := 0
	var total_health := 0
	var remaining_health := 0
	for foe in run.enemies:
		total_health += int(foe.max_hp)
		remaining_health += int(foe.hp)
		if foe.hp > 0:
			living += 1
	var boss_up := run.boss_wave() and not enemy.is_empty()
	strip.boss_ratio = float(remaining_health) / maxf(total_health, 1) if boss_up else -1.0
	strip.foes_total = 0 if run.boss_wave() else int(Combat.WAVE_SIZES[run.wave_index])
	strip.foes = 0 if run.advancing else living
	# 层主蓄力时不报字：地上有红圈，后撤键跟着一明一暗。
	var preparing: bool = not enemy.is_empty() and enemy.windup > 0.0
	strip.warning = preparing and boss_up
	hint_time = fposmod(hint_time + get_physics_process_delta_time() * 7.0, TAU) if preparing else 0.0
	action_buttons[&"retreat"].self_modulate = Color.WHITE.lerp(Color("#ff8f7a"), 0.5 + 0.5 * sin(hint_time)) if preparing else Color.WHITE
	if run.boss_wave() and not boss_announced and not enemy.is_empty() and enemy.spawn > 0.0:
		boss_announced = true
		var tribulation := Gear.Realm.jie_ling_of(run.dungeon_layer)
		_announce(run.archetype.name if tribulation.is_empty() else "%s劫" % Gear.WuXing.ELEMENT_NAMES[Gear.WuXing.stem_element(tribulation)],
			"层主")
	life_meter.set_amount(run.hp, run.max_hp)
	mana_meter.set_amount(run.mana, run.max_mana)
	life_value.text = "生命 %d" % run.hp
	mana_value.text = "灵力 %d" % int(run.mana)
	action_buttons[&"attack"].disabled = run.advancing
	_cooldown(&"skill", run.skill_left, run.mana < run.skill_cost)
	_cooldown(&"tactic", run.tactic_left, run.mana < run.tactic_cost)
	_cooldown(&"retreat", run.retreat_left, false)

func _cooldown(action: StringName, left: float, out_of_mana: bool) -> void:
	var button: Button = action_buttons[action]
	button.disabled = run.advancing or left > 0.0 or out_of_mana
	action_glyphs[action].modulate.a = 0.42 if button.disabled else 1.0
	# 转一圈的时长按本次冷却的峰值记，读条才不会跳。
	var total := maxf(float(cooldown_totals.get(action, 0.0)), left)
	cooldown_totals[action] = total
	cooldown_sweeps[action].show_amount(left, total, out_of_mana)

func _challenge() -> void:
	if state not in [&"farm", &"next_layer"]:
		return
	if state == &"farm" and (profile.challenge_wait() > 0 or Time.get_unix_time_from_system() < retry_until):
		return
	# 连战途中不打断：敕令在起点就接过了，中途只在天劫层停下（渡劫告示）。
	# 要驻留行善就得先停下连战 —— 这正是「继续爬」和「留下来救人」的取舍。
	if state == &"next_layer":
		_accept_edict()
		return
	# 从挂机主动进层：先看这是什么地方、仙界派你来做什么。
	turnover.dismiss()
	_show_place_notice()

# 接敕：天劫层再过一道渡劫告示，其余直接进战斗。
func _accept_edict() -> void:
	place_notice.hide()
	var tribulation := Gear.Realm.jie_ling_of(profile.layer())
	if tribulation.is_empty():
		_start_encounter(true, true)
		return
	# 渡劫前先落回挂机，这样告示上的境遇对比和「调整装备」都按本层算。
	if state == &"next_layer":
		_enter_farm()
	turnover.dismiss()
	state = &"jie_notice"
	battle.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	tribulation_notice.present(profile, tribulation)

# 驻留行善：层数不前进，换回复、材料、下一层的减益豁免与随侍士气。
func _aid_place() -> void:
	var place := profile.place()
	if not profile.aid_layer():
		_announce("", profile.storage_error)
		_close_place_notice()
		return
	# 重入挂机，让谢礼进的材料和下一层的蒙荫立刻反映到场上；它会顺手收起告示。
	_enter_farm()
	_announce(place.name, place.aid)

func _refuse_edict() -> void:
	var place := profile.place()
	if not profile.refuse_edict():
		_announce("", profile.storage_error)
		_close_place_notice()
		return
	_close_place_notice()
	_announce("抗敕", place.name)

func _show_place_notice() -> void:
	if not profile.has_character():
		return
	turnover.dismiss()
	state = &"place_notice"
	battle.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	place_notice.present(profile)

func _close_place_notice() -> void:
	place_notice.hide()
	battle.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	state = &"farm"

func _close_notice() -> void:
	tribulation_notice.hide()
	battle.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	state = &"farm"

func _stop_route() -> void:
	if run.continuous and state in [&"boss", &"next_layer"]:
		_enter_farm()

func _stash_material(id: String, quantity: int) -> void:
	if not profile.collect(id, quantity):
		_announce("", profile.storage_error)
		return
	if not run.challenging:
		farm_materials += quantity
	if id == profile.ling():
		pouch.bump()

func _open_forge(slot: String = "") -> void:
	if state not in [&"farm", &"jie_notice"]:
		return
	var preview_ling := Gear.Realm.jie_ling_of(profile.layer())
	run.collect_pending_materials()
	_checkpoint()
	forge_return_to_notice = state == &"jie_notice"
	state = &"forge"
	_clear_input()
	tribulation_notice.hide()
	turnover.dismiss()
	battle.hide()
	field.hide()
	battle_shade.hide()
	stick.hide()
	camp.texture = FORGE_BG
	camp.self_modulate = Color(0.80, 0.77, 0.74)
	camp_shade.texture = _forge_vignette()
	camp_shade.show()
	camp.show()
	forge.show()
	forge.open(preview_ling, slot)

func _close_forge() -> void:
	_enter_farm()
	if forge_return_to_notice:
		forge_return_to_notice = false
		# 从渡劫告示进的炉坊，回来还该是渡劫告示 —— 不要再过一遍地点告示。
		_accept_edict()

func _finish_challenge(outcome: StringName) -> void:
	if outcome == &"defeat":
		retry_until = Time.get_unix_time_from_system() + 30.0
		profile.start_challenge_cooldown()
		_enter_farm()
		return
	var from_stem := run.encounter_stem
	var old_entries: Dictionary = {} if run.continuous else profile.loadout({}, true, from_stem).entries
	var old_layer := profile.layer()
	var rewards := {profile.ling(): 3}
	if old_layer % 5 == 0:
		rewards["relic_core"] = 1
	if not profile.advance_layer(rewards):
		_enter_farm()
		_announce("", profile.storage_error)
		return
	retry_until = 0.0
	sounds.play(&"level")
	var is_breakthrough := not Gear.Realm.jie_ling_of(old_layer).is_empty()
	if run.continuous:
		state = &"next_layer"
		next_layer_left = 0.65
		_clear_input()
		stick.hide()
		run.motion = &""
		run.facing = 0.0
		run.stride = 0.0
		if is_breakthrough:
			_announce("破境", String(profile.realm().name))
		for action in [&"attack", &"skill", &"tactic", &"retreat"]:
			action_buttons[action].disabled = true
		return
	var new_entries: Dictionary = profile.loadout().entries
	_enter_farm()
	turnover.play(from_stem, profile.ling(), old_entries, new_entries, profile.layer(),
		String(profile.realm().name) if is_breakthrough else "")

func _toggle_sound() -> void:
	sounds.enabled = not sounds.enabled
	for index in range(sound_buttons.size() - 1, -1, -1):
		var button := sound_buttons[index]
		if not is_instance_valid(button) or not button.is_inside_tree():
			sound_buttons.remove_at(index)
			continue
		_set_icon(button, &"sound" if sounds.enabled else &"mute")
		_describe(button, "关闭音效" if sounds.enabled else "开启音效")
	if sounds.enabled:
		sounds.play(&"pickup")
	else:
		sounds.mute_all()

func _adapt_safe_area() -> void:
	var top := 12
	var bottom := 12
	var left := 16
	var right := 16
	if OS.has_feature("mobile"):
		var pixels := Vector2(DisplayServer.window_get_size())
		var insets := DisplayServer.get_display_safe_area()
		if pixels.x > 0 and pixels.y > 0 and insets.has_area():
			var ratio := size / pixels
			top += maxi(0, roundi(insets.position.y * ratio.y))
			left += maxi(0, roundi(insets.position.x * ratio.x))
			bottom += maxi(0, roundi((pixels.y - insets.end.y) * ratio.y))
			right += maxi(0, roundi((pixels.x - insets.end.x) * ratio.x))
	safe.add_theme_constant_override("margin_top", top)
	safe.add_theme_constant_override("margin_bottom", bottom)
	safe.add_theme_constant_override("margin_left", left)
	safe.add_theme_constant_override("margin_right", right)
	var wide := size.x >= size.y * 1.17
	_layout_header()
	gear_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if wide else Control.SIZE_FILL
	farm_actions.size_flags_horizontal = Control.SIZE_SHRINK_END if wide else Control.SIZE_FILL
	farm_actions.custom_minimum_size.x = minf(320.0, size.x * 0.30) if wide else 0.0
	skill_row.custom_minimum_size.x = minf(355.0, size.x * 0.31) if wide else 0.0
	battle_portrait.custom_minimum_size.x = 58.0 if wide else 43.0
	_update_retinue()
	for page in [selection, roster_page, title_page]:
		page.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if wide else Control.SIZE_FILL
		page.custom_minimum_size.x = minf(620.0, size.x * 0.65) if wide else 0.0
	_fit_forge()

# 顶栏左边只有袋子或三波记号，都很窄，横竖屏都和右边的按钮并排。
func _layout_header() -> void:
	battle_header.columns = 2

func _fit_forge() -> void:
	if forge == null:
		return
	var window := get_window()
	var wide := window.size.x >= window.size.y * 1.17
	var armory_open := state == &"forge" and forge.inventory
	var design := Vector2i(original_design_size.y, original_design_size.x) if wide and armory_open else original_design_size
	if window.content_scale_size != design:
		window.content_scale_size = design
	forge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if wide and not armory_open else Control.SIZE_FILL
	forge.custom_minimum_size.x = minf(620.0, size.x * 0.65) if wide and not armory_open else 0.0

func _held(action: StringName) -> bool:
	return touches.values().has(action)

func _clear_input() -> void:
	touches.clear()
	run.attack_buffer_left = 0.0
	if stick != null:
		stick.clear()
	_update_pressed()

func _update_pressed() -> void:
	for action in action_buttons:
		var down := _held(action)
		action_buttons[action].set_pressed_no_signal(down)
		# 按住时图标提亮一档，手指盖住按钮也知道自己按着的是哪个。
		var glyph: Control = action_glyphs[action]
		glyph.modulate = Color(1.35, 1.28, 1.12) if down else Color.WHITE
		glyph.scale = Vector2.ONE * (0.92 if down else 1.0)
		glyph.pivot_offset = glyph.size * 0.5

func _add_action(row: HBoxContainer, action: StringName, title: String, primary: bool, skill_slot: bool) -> void:
	var tile := _icon_button(action, title, primary, Vector2(44, 70 if skill_slot else 44))
	if skill_slot:
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var glyph: Gothic.Glyph = tile.get_node("Glyph")
		# 招式只画图，不写名字；冷却靠转圈的读条，不报秒数。
		glyph.offset_left = -22
		glyph.offset_right = 22
		glyph.offset_top = -22
		glyph.offset_bottom = 22
		tile.clip_contents = true
	tile.toggle_mode = true
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tile)
	action_buttons[action] = tile
	action_glyphs[action] = tile.get_node("Glyph")
	if action in [&"skill", &"tactic", &"retreat"]:
		var sweep := Gothic.Sweep.new()
		tile.add_child(sweep)
		_fill(sweep)
		cooldown_sweeps[action] = sweep

func _sound_button() -> Button:
	var tile := _icon_button(&"mute", "开启音效", false, Vector2(44, 44))
	tile.pressed.connect(_toggle_sound)
	sound_buttons.append(tile)
	return tile

func _icon_button(symbol: StringName, title: String, accent: bool, minimum: Vector2) -> Button:
	var tile := _button("", accent, minimum.y)
	tile.custom_minimum_size = minimum
	_describe(tile, title)
	var glyph := Gothic.Glyph.new()
	glyph.name = "Glyph"
	glyph.ink = NIGHT if accent else INK
	tile.add_child(glyph)
	glyph.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	glyph.offset_left = -13.0
	glyph.offset_right = 13.0
	glyph.offset_top = -13.0
	glyph.offset_bottom = 13.0
	if symbol == &"portal":
		glyph.offset_left = -23.0
		glyph.offset_right = 23.0
		glyph.offset_top = -23.0
		glyph.offset_bottom = 23.0
	elif symbol == &"pause":
		glyph.offset_left = -16.0
		glyph.offset_right = 16.0
		glyph.offset_top = -16.0
		glyph.offset_bottom = 16.0
	_set_icon(tile, symbol)
	return tile

func _describe(button: Button, title: String) -> void:
	button.accessibility_name = title
	button.tooltip_text = title

func _set_glyph(action: StringName, symbol: StringName) -> void:
	_set_icon(action_buttons[action], symbol)

func _set_icon(button: Button, symbol: StringName) -> void:
	var glyph: Gothic.Glyph = button.get_node("Glyph")
	glyph.symbol = symbol
	glyph.art = null # 墨线图标与手绘人物使用同一套简洁轮廓。
	glyph.material = spell_grade if glyph.art != null else null
	glyph.queue_redraw()

func _spell_texture(symbol: StringName) -> Texture2D:
	if not SPELL_INDEX.has(symbol):
		return null
	if not spell_textures.has(symbol):
		var index: int = SPELL_INDEX[symbol]
		var artwork := AtlasTexture.new()
		artwork.atlas = SPELL_ATLAS
		artwork.filter_clip = true
		var origin := SPELL_CELL * Vector2(index % 4, floori(index / 4.0))
		artwork.region = Rect2(origin + Vector2(5, 5), SPELL_CELL - Vector2(10, 10))
		spell_textures[symbol] = artwork
	return spell_textures[symbol]

func _label(text: String, font_size: int, color: Color) -> Label:
	var title := Label.new()
	title.text = text
	if font_size >= 19:
		title.add_theme_font_override("font", HEADING_FONT)
	title.add_theme_font_size_override("font_size", font_size)
	title.add_theme_color_override("font_color", color)
	return title

func _button(text: String, accent: bool, height: float) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = height
	_restyle(button, accent)
	return button

func _restyle(button: Button, accent: bool) -> void:
	var fill := CRIMSON if accent else IRON
	var ink := NIGHT if accent else INK
	var edge := Color("#6c4331") if accent else BORDER
	var normal := _box(fill, edge, 1, 6)
	var hover := _box(fill.lightened(0.08), edge, 1, 6)
	var pressed := _box(fill.darkened(0.15), edge, 1, 6)
	if accent:
		for style in [normal, hover, pressed]:
			style.border_width_bottom = 2
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", _box(Color("#d8c8ab"), Color("#b29a79"), 1, 6))
	for color_name in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(color_name, ink)
	button.add_theme_color_override("font_disabled_color", MUTED)

func _box(fill: Color, edge: Color, thickness: int, padding: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(thickness)
	box.set_corner_radius_all(1)
	box.shadow_color = Color("#372a1b18")
	box.shadow_size = 2
	box.shadow_offset = Vector2(1, 2)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		box.set_content_margin(side, padding)
	return box

func _image(texture: Texture2D) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image

func _camp_gradient() -> GradientTexture2D:
	var shade := Gradient.new()
	shade.offsets = PackedFloat32Array([0.0, 0.30, 0.75, 1.0])
	shade.colors = PackedColorArray([Color("#f0e0bf60"), Color("#f0e0bf00"), Color("#f0e0bf18"), Color("#f0e0bf50")])
	var texture := GradientTexture2D.new()
	texture.gradient = shade
	texture.width = 2
	texture.height = 256
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	return texture

func _forge_vignette() -> GradientTexture2D:
	var shade := Gradient.new()
	shade.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
	shade.colors = PackedColorArray([Color("#f0e0bf18"), Color("#f0e0bf50"), Color("#f0e0bfc0")])
	var texture := GradientTexture2D.new()
	texture.gradient = shade
	texture.width = 128
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 1.0)
	return texture

func _battle_gradient() -> GradientTexture2D:
	var shade := Gradient.new()
	shade.offsets = PackedFloat32Array([0.0, 0.20, 0.74, 1.0])
	shade.colors = PackedColorArray([Color("#f0e0bf50"), Color("#f0e0bf00"), Color("#f0e0bf00"), Color("#f0e0bf40")])
	var texture := GradientTexture2D.new()
	texture.gradient = shade
	texture.width = 2
	texture.height = 256
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	return texture

func _vbox(gap: int) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", gap)
	return stack

func _hbox(gap: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", gap)
	return row

func _space(amount: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2.ONE * amount
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer

func _fill(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
