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
const SideArt = preload("res://scripts/side_art.gd")
const CAMP = preload("res://art/immortals/ruined-shrine-flagstones.webp")
const FORGE_BG = preload("res://art/immortals/soot-furnace-flagstones.webp")
const SPELL_ATLAS = preload("res://art/immortals/spells.webp")
const SPELL_GRADE = preload("res://art/gothic_grade.gdshader")
const FONT = preload("res://art/fonts/game.otf")
const HEADING_FONT = preload("res://art/fonts/heading.tres")

const NIGHT := Color("#151315")
const INK := Color("#eee5d6")
const GOLD := Color("#c4a582")
const MUTED := Color("#c0b7ad")
const IRON := Color("#292524")
const BORDER := Color("#827059")
const CRIMSON := Color("#762e26")
const SPELL_CELL := Vector2(128, 128)
const SPELL_INDEX := {
	&"sword": 0, &"slash": 1, &"cleave": 2, &"retreat": 3,
	&"arrow": 4, &"fan": 5, &"heavy": 6, &"portal": 7,
	&"spark": 8, &"sigil": 9, &"frost": 10, &"pause": 11
}

var run := Combat.new()
var profile := Gear.new()
var sounds := Sound.new()
var state: StringName = &"selection"
var touches: Dictionary = {}
var action_buttons: Dictionary = {}
var action_glyphs: Dictionary = {}
var cooldown_labels: Dictionary = {}
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
var battle: VBoxContainer
var battle_header: GridContainer
var battle_tools: HBoxContainer
var battle_info: Control
var battle_context: Label
var encounter_label: Label
var ling_label: Label
var farm_readout: VBoxContainer
var farm_health: Gothic.Meter
var farm_status: Label
var loot_line: Label
var recent_loot := ""
var loot_animation: Tween
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
var boss_readout: VBoxContainer
var boss_health: Gothic.Meter
var boss_hint: Label
var gear_slots := {}
var tribulation_notice: TribulationNotice
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

func _ready() -> void:
	original_design_size = get_window().content_scale_size
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	spell_grade.shader = SPELL_GRADE
	spell_grade.set_shader_parameter("grade_weight", 0.68)
	spell_grade.set_shader_parameter("exposure", 1.14)
	var ui_style := Theme.new()
	ui_style.default_font = FONT
	ui_style.default_font_size = 16
	theme = ui_style
	add_child(sounds)
	run.feedback.connect(sounds.play)
	profile.load_profile()
	run.material_collected.connect(_stash_material)
	_build_view()
	resized.connect(_adapt_safe_area)
	_adapt_safe_area()
	if profile.has_character():
		_enter_farm()
	else:
		_show_selection()

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
	selection.journey_requested.connect(_enter_farm)

func _build_battle() -> void:
	battle.add_theme_constant_override("separation", 7)
	battle_header = GridContainer.new()
	battle_header.add_theme_constant_override("h_separation", 10)
	battle_header.add_theme_constant_override("v_separation", 5)
	battle.add_child(battle_header)
	var stage_info := _vbox(5)
	stage_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_header.add_child(stage_info)

	# 层数与流年并进标题行右侧，顶栏少一整条，把高度让给战场。
	var info := _hud_card(stage_info, 9, 0.79)
	battle_info = info.get_parent()
	battle_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var heading := _hbox(6)
	info.add_child(heading)
	encounter_label = _label("", 21, INK)
	encounter_label.add_theme_font_override("font", HEADING_FONT)
	encounter_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	encounter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_child(encounter_label)
	var year := _vbox(0)
	year.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(year)
	battle_context = _label("", 11, MUTED)
	battle_context.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	year.add_child(battle_context)
	ling_label = _label("", 12, GOLD)
	ling_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	year.add_child(ling_label)

	farm_readout = _vbox(4)
	info.add_child(farm_readout)
	var feed := Control.new()
	feed.clip_contents = true
	feed.custom_minimum_size.y = 24
	farm_readout.add_child(feed)
	loot_line = _label("", 13, Color("#c4e0a4"))
	_fill(loot_line)
	feed.add_child(loot_line)
	farm_health = _meter(Color("#8cb286"), 5)
	farm_readout.add_child(farm_health)
	farm_status = _label("", 11, MUTED)
	farm_readout.add_child(farm_status)

	boss_readout = _vbox(5)
	info.add_child(boss_readout)
	boss_health = _meter(Color("#c65c4c"), 9, 5)
	boss_readout.add_child(boss_health)
	boss_hint = _label("", 12, INK)
	boss_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boss_readout.add_child(boss_hint)

	var switches := _hbox(7)
	switches.size_flags_horizontal = Control.SIZE_SHRINK_END
	switches.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	battle_header.add_child(switches)
	battle_tools = _hbox(6)
	switches.add_child(battle_tools)
	mode_button = _button("", false, 44.0)
	mode_button.custom_minimum_size.x = 96
	mode_button.pressed.connect(_cycle_control_mode)
	battle_tools.add_child(mode_button)
	speed_button = _button("1×", false, 44.0)
	speed_button.custom_minimum_size.x = 52
	speed_button.pressed.connect(_cycle_battle_speed)
	battle_tools.add_child(speed_button)
	stop_route_button = _button("停止连战", false, 44.0)
	stop_route_button.add_theme_font_size_override("font_size", 13)
	stop_route_button.pressed.connect(_stop_route)
	stop_route_button.hide()
	battle_tools.add_child(stop_route_button)
	switches.add_child(_sound_button())

	var tags := _hud_card(battle, 6)
	gear_card = tags.get_parent()
	var strip := _hbox(8)
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	tags.add_child(strip)
	for slot in Gear.SLOTS:
		var frame := EquipmentSlot.new(44)
		frame.pressed.connect(_press_camp_slot.bind(slot))
		strip.add_child(frame)
		gear_slots[slot] = frame

	var spring := _space(1)
	spring.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle.add_child(spring)
	farm_actions = _hbox(7)
	battle.add_child(farm_actions)
	var forge_button := _button("行装", false, 53.0)
	forge_button.custom_minimum_size.x = 89
	forge_button.pressed.connect(_open_forge)
	farm_actions.add_child(forge_button)
	challenge_button = _button("", true, 53.0)
	challenge_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	challenge_button.add_theme_font_size_override("font_size", 16)
	challenge_button.pressed.connect(_challenge)
	farm_actions.add_child(challenge_button)

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
	var portrait_row := _hbox(6)
	identity.add_child(portrait_row)
	battle_portrait = _image(SideArt.PORTRAITS[0])
	battle_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	battle_portrait.custom_minimum_size = Vector2(43, 56)
	portrait_row.add_child(battle_portrait)
	var vitals := _vbox(2)
	vitals.custom_minimum_size.x = 64.0
	vitals.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait_row.add_child(vitals)
	life_value = _label("", 11, INK)
	vitals.add_child(life_value)
	life_meter = _meter(Color("#be6251"), 5)
	vitals.add_child(life_meter)
	mana_value = _label("", 11, INK)
	vitals.add_child(mana_value)
	mana_meter = _meter(Color("#79a7a6"), 5)
	vitals.add_child(mana_meter)
	retinue_faces = _hbox(4)
	portrait_row.add_child(retinue_faces)
	for index in range(3):
		var face := _image(SideArt.PORTRAITS[0])
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

func _update_control_labels() -> void:
	mode_button.text = ["手动", "自动普攻", "全自动"][control_mode]
	_describe(mode_button, mode_button.text + " · 切换战斗操作")
	_restyle(mode_button, control_mode == Combat.ControlMode.AUTOMATIC)
	speed_button.text = "%d×" % battle_speed
	_describe(speed_button, "战斗速度 " + speed_button.text)
	manual_movement.visible = control_mode == Combat.ControlMode.MANUAL

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

	turnover = Turnover.new()
	turnover.ui = self
	_fill(turnover)
	add_child(turnover)
	turnover.hide()

func _physics_process(delta: float) -> void:
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
	elif state in [&"farm", &"jie_notice"]:
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
				boss_health.set_amount(0.0, 1.0)
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
			match state:
				&"forge":
					if forge.inventory and not forge.armory.selected_uid.is_empty():
						forge.armory.inspect("")
					else:
						_close_forge()
				&"jie_notice": _close_notice()
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
	elif what == NOTIFICATION_APPLICATION_RESUMED and is_instance_valid(safe):
		_adapt_safe_area()

func _show_selection() -> void:
	state = &"selection"
	battle.hide()
	field.hide()
	battle_shade.hide()
	forge.hide()
	stick.hide()
	camp.texture = CAMP
	camp.self_modulate = Color.WHITE
	camp_shade.texture = _camp_gradient()
	camp.show()
	camp_shade.show()
	selection.show()
	selection.show_home()

func _enter_farm() -> void:
	_start_encounter(false)

func _start_encounter(challenge: bool, continuous_route := false) -> void:
	if not profile.has_character():
		return
	if run.encounter_stem == profile.ling() and not run.challenging:
		run.collect_pending_materials()
	_clear_input()
	tribulation_notice.hide()
	battle.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	turnover.dismiss()
	var person := profile.character()
	var weapon := profile.item(profile.equipped("weapon"))
	var element := Gear.WuXing.stem_element(person.day_stem)
	field.portrait_id = Roster.portrait_id(person.day_stem, person.gender == "female")
	battle_portrait.texture = SideArt.PORTRAITS[field.portrait_id % 2]
	field.hero_element = element
	var outfit := profile.loadout()
	var form: String = weapon.get("weapon_form", "long_blade")
	var layer_tribulation := Gear.Realm.jie_ling_of(profile.layer())
	var tribulation := layer_tribulation if challenge else ""
	var ling := profile.ling() if tribulation.is_empty() else tribulation
	if ling != profile.ling():
		outfit = profile.loadout({}, true, ling)
	var bonuses := Gear.Loadout.bonuses(outfit, person, profile.layer())
	# 六个槽位的五行与阴阳同时决定数值和外观：换一件装备，场上的人就跟着换一身。
	field.look = Appearance.build(outfit.entries, outfit.patterns, form)
	run.trail_color = field.look.trail
	if state == &"forge" and not challenge and run.dungeon_layer == profile.layer():
		run.refresh_equipment(bonuses, form)
	else:
		run.reset(profile.layer(), bonuses, form, challenge, ling, continuous_route)
	state = &"boss" if challenge else &"farm"
	battle_context.text = profile.layer_caption()
	encounter_label.text = "%s劫" % Gear.WuXing.ELEMENT_NAMES[Gear.WuXing.stem_element(ling)] if not tribulation.is_empty() else (
		run.archetype.name + " · 层主" if challenge else "挂机刷怪")
	ling_label.text = Gear.ling_caption(ling) + "当令"
	ling_label.add_theme_color_override("font_color", Gear.MATERIAL_COLORS[Gear.WuXing.stem_element(ling)])
	_set_loadout_slots(outfit.entries, person, challenge)
	farm_actions.visible = not challenge
	challenge_caption = ("开始连战 · 第%d层" if layer_tribulation.is_empty() else "准备渡劫 · 第%d层") % profile.layer()
	farm_readout.visible = not challenge
	boss_readout.visible = challenge
	boss_controls.visible = challenge
	battle_tools.visible = challenge
	_update_retinue()
	stop_route_button.visible = challenge and run.continuous
	gear_card.visible = not challenge
	stick.visible = challenge
	if not challenge and recent_loot.is_empty():
		loot_line.text = "材料流水  ·  " + Gear.material(ling).name

	selection.hide()
	forge.hide()
	_fit_forge()
	camp.hide()
	camp_shade.hide()
	field.set_camp_view(not challenge)
	field.show()
	battle_shade.visible = not run.continuous
	battle.show()
	var symbols := {"long_blade": &"sword", "hammer": &"heavy", "bow": &"arrow", "staff": &"spark", "dual_blades": &"slash"}
	_set_glyph(&"attack", symbols[form])
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
		farm_health.set_amount(run.hp, run.max_hp)
		farm_status.text = "生命 %d/%d   ·   本层击退 %d" % [run.hp, run.max_hp, run.kills]
		var wait := maxi(profile.challenge_wait(), ceili(retry_until - Time.get_unix_time_from_system()))
		challenge_button.text = ("调息 %d 秒\n" % wait + challenge_caption) if wait > 0 else challenge_caption
		return
	var enemy: Dictionary = run.enemies[0] if not run.enemies.is_empty() else {}
	if run.continuous:
		var wave := "第 %d / %d 波" % [run.wave_index + 1, Combat.WAVE_SIZES.size()]
		if run.advancing:
			encounter_label.text = "前往下一波"
			boss_health.set_amount(0.0, 1.0)
			boss_hint.text = "%s已清 · 向前进发" % wave
			boss_hint.add_theme_color_override("font_color", GOLD)
		elif run.boss_wave():
			var tribulation := Gear.Realm.jie_ling_of(run.dungeon_layer)
			var title: String = run.archetype.name + " · 层主" if tribulation.is_empty() else (
				"%s劫 · 层主" % Gear.WuXing.ELEMENT_NAMES[Gear.WuXing.stem_element(tribulation)])
			encounter_label.text = title
		else:
			encounter_label.text = wave
	if not enemy.is_empty():
		var total_health := 0
		var remaining_health := 0
		for foe in run.enemies:
			total_health += int(foe.max_hp)
			remaining_health += int(foe.hp)
		boss_health.set_amount(remaining_health, total_health)
		var preparing: bool = enemy.windup > 0.0
		boss_hint.text = "%s · 后撤避开红圈" % run.archetype.skill if preparing else (
			"层主生命 %d / %d" % [enemy.hp, enemy.max_hp] if run.boss_wave() else "余敌 %d" % run.enemies.size())
		boss_hint.add_theme_color_override("font_color", Color("#ffaca0") if preparing else MUTED)
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
	cooldown_labels[action].text = str(ceili(left)) if left > 0.0 else ""
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
	var tribulation := Gear.Realm.jie_ling_of(profile.layer())
	if tribulation.is_empty():
		_start_encounter(true, true)
		return
	if state == &"next_layer":
		_enter_farm()
	turnover.dismiss()
	state = &"jie_notice"
	battle.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	tribulation_notice.present(profile, tribulation)

func _close_notice() -> void:
	tribulation_notice.hide()
	battle.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	state = &"farm"

func _stop_route() -> void:
	if run.continuous and state in [&"boss", &"next_layer"]:
		_enter_farm()

func _stash_material(id: String, quantity: int) -> void:
	if not profile.collect(id, quantity):
		loot_line.text = profile.storage_error
		return
	var material := Gear.material(id)
	recent_loot = "+%d %s" % [quantity, material.name]
	loot_line.text = "材料流水  ·  %s   /   库存 %d" % [recent_loot, profile.stock(id)]
	loot_line.add_theme_color_override("font_color", material.tint.lerp(INK, 0.3))
	if loot_animation != null:
		loot_animation.kill()
	loot_line.position.y = 7.0
	loot_line.modulate.a = 0.30
	loot_animation = create_tween().set_parallel(true)
	loot_animation.tween_property(loot_line, "position:y", 0.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	loot_animation.tween_property(loot_line, "modulate:a", 1.0, 0.26)

func _open_forge(slot: String = "") -> void:
	if state not in [&"farm", &"jie_notice"]:
		return
	var preview_ling := Gear.Realm.jie_ling_of(profile.layer())
	run.collect_pending_materials()
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
		_challenge()

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
		loot_line.text = profile.storage_error
		return
	retry_until = 0.0
	recent_loot = ""
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
		encounter_label.text = "第 %d 层已通关" % old_layer
		if is_breakthrough:
			encounter_label.text += " · 破境"
		boss_hint.text = "即将进入第 %d 层" % profile.layer()
		boss_hint.add_theme_color_override("font_color", GOLD)
		boss_health.set_amount(0.0, 1.0)
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
	battle_header.columns = 2 if wide else 1
	battle_info.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if wide else Control.SIZE_FILL
	battle_info.custom_minimum_size.x = 340.0 if wide else 0.0
	gear_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if wide else Control.SIZE_FILL
	farm_actions.size_flags_horizontal = Control.SIZE_SHRINK_END if wide else Control.SIZE_FILL
	farm_actions.custom_minimum_size.x = minf(530.0, size.x * 0.50) if wide else 0.0
	skill_row.custom_minimum_size.x = minf(355.0, size.x * 0.31) if wide else 0.0
	battle_portrait.custom_minimum_size.x = 58.0 if wide else 43.0
	_update_retinue()
	selection.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if wide else Control.SIZE_FILL
	selection.custom_minimum_size.x = minf(620.0, size.x * 0.65) if wide else 0.0
	_fit_forge()

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
		glyph.offset_left = -21
		glyph.offset_right = 21
		glyph.offset_top = -29
		glyph.offset_bottom = 10
		tile.clip_contents = true
		var caption := _label(title, 12, INK)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.add_theme_constant_override("outline_size", 4)
		caption.add_theme_color_override("font_outline_color", NIGHT)
		tile.add_child(caption)
		_fill(caption)
		caption.offset_bottom = -4.0
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
		var counter := _label("", 12, INK)
		counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		counter.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		counter.add_theme_constant_override("outline_size", 5)
		counter.add_theme_color_override("font_outline_color", NIGHT)
		tile.add_child(counter)
		_fill(counter)
		counter.offset_right = -5
		counter.offset_bottom = -3
		cooldown_labels[action] = counter

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
	glyph.ink = INK if accent else GOLD
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
	glyph.art = _spell_texture(symbol)
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
	var ink := INK
	var edge := Color("#bd8b62") if accent else BORDER
	var normal := _box(fill, edge, 1, 6)
	var hover := _box(fill.lightened(0.08), edge, 1, 6)
	var pressed := _box(fill.darkened(0.15), edge, 1, 6)
	if accent:
		for style in [normal, hover, pressed]:
			style.border_width_bottom = 2
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", _box(Color("#151312"), Color("#42372f"), 1, 6))
	for color_name in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(color_name, ink)
	button.add_theme_color_override("font_disabled_color", MUTED)

func _box(fill: Color, edge: Color, thickness: int, padding: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(thickness)
	box.set_corner_radius_all(1)
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
	shade.colors = PackedColorArray([Color("#100e118a"), Color("#15131500"), Color("#15131520"), Color("#100e1173")])
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
	shade.colors = PackedColorArray([Color("#100d1000"), Color("#100d1000"), Color("#100d1073")])
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
	shade.colors = PackedColorArray([Color("#0d090a8a"), Color("#0d090a00"), Color("#0d0b0b00"), Color("#0d0b0b7a")])
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
