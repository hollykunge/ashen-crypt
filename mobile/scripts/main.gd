extends Control

const Combat = preload("res://scripts/combat.gd")
const Arena = preload("res://scripts/arena.gd")
const Sound = preload("res://scripts/sound.gd")
const Gothic = preload("res://scripts/gothic.gd")
const Gear = preload("res://scripts/gear.gd")
const ForgeArt = preload("res://scripts/forge_art.gd")
const Forge = preload("res://scripts/forge.gd")
const Roster = preload("res://scripts/roster.gd")
const HeroPreview = preload("res://scripts/hero_preview.gd")
const CAMP = preload("res://art/hero-vault.webp")
const FORGE_BG = preload("res://art/furnace-vault.webp")
const CAMP_GRADE = preload("res://art/gothic_grade.gdshader")
const SPELL_ATLAS = preload("res://art/spell-icons.webp")
const FONT = preload("res://art/fonts/game.ttf")
const HEADING_FONT = preload("res://art/fonts/heading.ttf")

const NIGHT := Color("#100e0e")
const INK := Color("#eee3cf")
const GOLD := Color("#cdb180")
const MUTED := Color("#c0b3a4")
const IRON := Color("#231e1b")
const BORDER := Color("#6c5843")
const CRIMSON := Color("#452022")
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
var choice := 0
var hero_style := 0
var touches: Dictionary = {}
var action_buttons: Dictionary = {}
var action_glyphs: Dictionary = {}
var cooldown_labels: Dictionary = {}
var sound_buttons: Array[Button] = []
var spell_textures: Dictionary = {}

var safe: MarginContainer
var camp: TextureRect
var camp_shade: TextureRect
var battle_shade: TextureRect
var selection: VBoxContainer
var battle: VBoxContainer
var overlay: ColorRect
var headline: Label
var summary: Label
var overlay_action: Button
var result_forge_button: Button
var forge: Forge
var forge_return: StringName
var hero_choices: Array[Button] = []
var style_choices: Array[Button] = []
var hero_preview: HeroPreview
var enter_button: Button
var selection_utilities: Array[Button] = []
var wave_title: Label
var life_seal: Gothic.Orb
var mana_seal: Gothic.Orb
var field: Arena

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	_show_selection()

func _build_view() -> void:
	var base := ColorRect.new()
	base.color = NIGHT
	_fill(base)
	add_child(base)

	camp = _image(CAMP)
	camp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var grade := ShaderMaterial.new()
	grade.shader = CAMP_GRADE
	grade.set_shader_parameter("grade_weight", 0.12)
	grade.set_shader_parameter("exposure", 1.23)
	camp.material = grade
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

	selection = _vbox(9)
	selection.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(selection)
	_build_selection()

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
	_build_overlay()

func _build_selection() -> void:
	var utilities := _hbox(0)
	selection.add_child(utilities)
	var forge_button := _icon_button(&"anvil", "墓火锻造", false, Vector2(46, 46))
	forge_button.pressed.connect(_open_forge)
	utilities.add_child(forge_button)
	selection_utilities.append(forge_button)
	var spacer := _space(0)
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	utilities.add_child(spacer)
	var sound_button := _sound_button()
	utilities.add_child(sound_button)
	selection_utilities.append(sound_button)
	selection.add_child(_space(10))
	var title := _label("余烬地牢", 41, Color("#eee1c8"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color("#1b1412"))
	selection.add_child(title)
	hero_preview = HeroPreview.new()
	hero_preview.custom_minimum_size.y = 285.0
	hero_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selection.add_child(hero_preview)
	var styles := _hbox(5)
	styles.alignment = BoxContainer.ALIGNMENT_CENTER
	selection.add_child(styles)
	for i in range(2):
		var option := _button(["男", "女"][i], i == hero_style, 44.0)
		option.custom_minimum_size.x = 63
		option.add_theme_font_size_override("font_size", 14)
		option.accessibility_name = ["男性", "女性"][i]
		option.pressed.connect(_choose_style.bind(i))
		styles.add_child(option)
		style_choices.append(option)
	var choices := _hbox(8)
	selection.add_child(choices)
	for i in range(Combat.HEROES.size()):
		var tile := _button(Gear.CLASSES[i], false, 62.0)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.add_theme_font_size_override("font_size", 13)
		tile.pressed.connect(_choose.bind(i))
		choices.add_child(tile)
		hero_choices.append(tile)
		var portrait := _image(_spell_texture([&"sword", &"arrow", &"spark"][i]))
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tile.add_child(portrait)
		portrait.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		portrait.offset_left = -19.0
		portrait.offset_right = 19.0
		portrait.offset_top = 1.0
		portrait.offset_bottom = 39.0

	enter_button = _icon_button(&"portal", "确认角色，踏入地牢", true, Vector2(94, 54))
	enter_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	enter_button.pressed.connect(_confirm_hero)
	selection.add_child(enter_button)
	selection.add_child(_space(3))

func _build_battle() -> void:
	var status := _hbox(11)
	battle.add_child(status)
	status.add_child(_sound_button())
	wave_title = _label("", 18, INK)
	wave_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wave_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_title.add_theme_constant_override("outline_size", 6)
	wave_title.add_theme_color_override("font_outline_color", NIGHT)
	status.add_child(wave_title)
	var pause_button := _icon_button(&"pause", "暂停", false, Vector2(44, 44))
	pause_button.pressed.connect(_pause_game)
	status.add_child(pause_button)
	var spring := _space(1)
	spring.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle.add_child(spring)

	var movement := _hbox(5)
	movement.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	battle.add_child(movement)
	_add_action(movement, &"back", "后退", false, false)
	_add_action(movement, &"forward", "前进", false, false)

	var dock := Gothic.Dock.new()
	dock.custom_minimum_size.y = 76.0
	battle.add_child(dock)
	var hud := _hbox(4)
	dock.add_child(hud)
	_fill(hud)
	hud.offset_left = 3
	hud.offset_right = -3
	life_seal = _orb("生命")
	hud.add_child(life_seal)
	var skills := _hbox(4)
	skills.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skills.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hud.add_child(skills)
	_add_action(skills, &"attack", "普攻", true, true)
	_add_action(skills, &"skill", "主技能", false, true)
	_add_action(skills, &"tactic", "副技能", false, true)
	_add_action(skills, &"retreat", "后撤", false, true)
	mana_seal = _orb("魔法")
	mana_seal.glow = Color("#368acd")
	mana_seal.shade = Color("#10295a")
	mana_seal.highlight = Color("#a3ddff")
	hud.add_child(mana_seal)
	battle.add_child(_space(3))

func _build_overlay() -> void:
	overlay = ColorRect.new()
	overlay.color = Color("#0f0b0ad9")
	_fill(overlay)
	add_child(overlay)
	var center := CenterContainer.new()
	_fill(center)
	overlay.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 275
	card.add_theme_stylebox_override("panel", _box(Color("#211a17"), BORDER, 2, 20))
	center.add_child(card)
	var stack := _vbox(12)
	card.add_child(stack)
	headline = _label("", 29, INK)
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(headline)
	summary = _label("", 14, MUTED)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(summary)
	var commands := _hbox(10)
	stack.add_child(commands)
	overlay_action = _icon_button(&"play", "继续战斗", true, Vector2(90, 49))
	overlay_action.pressed.connect(_continue_or_retry)
	overlay_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	commands.add_child(overlay_action)
	result_forge_button = _icon_button(&"anvil", "墓火锻造", false, Vector2(52, 49))
	result_forge_button.pressed.connect(_open_forge)
	commands.add_child(result_forge_button)
	var leave := _icon_button(&"leave", "返回选角", false, Vector2(73, 49))
	leave.pressed.connect(_show_selection)
	commands.add_child(leave)
	overlay.hide()

func _physics_process(delta: float) -> void:
	if state != &"battle":
		return
	var left := _held(&"back") or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
	var right := _held(&"forward") or Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
	var up := Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
	var down := Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
	var direction := Vector2(int(right) - int(left), int(down) - int(up))
	run.step(delta, direction, _held(&"attack") or Input.is_physical_key_pressed(KEY_J))
	field.queue_redraw()
	_update_battle()
	if run.result != &"":
		_show_result(run.result)

func _input(event: InputEvent) -> void:
	if state == &"selection":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: Key = event.physical_keycode if event.physical_keycode else event.keycode
		if key == KEY_ESCAPE:
			if state == &"battle":
				_pause_game()
			elif state == &"paused":
				_continue_or_retry()
			elif state == &"forge":
				_close_forge()
			get_viewport().set_input_as_handled()
			return
		if state == &"battle":
			match key:
				KEY_J: run.attack()
				KEY_Q: run.skill()
				KEY_E: run.tactic()
				KEY_SPACE: run.retreat()
	if state != &"battle":
		return
	if event is InputEventScreenTouch:
		_handle_pointer(event.index, event.position, event.pressed and not event.canceled)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_pointer(-1, event.position, event.pressed)

func _handle_pointer(pointer: int, point: Vector2, pressed: bool) -> void:
	if not pressed:
		if touches.erase(pointer):
			_update_pressed()
			get_viewport().set_input_as_handled()
		return
	for action in action_buttons:
		var control: Button = action_buttons[action]
		if control.disabled or not control.get_global_rect().has_point(point):
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

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_pause_game()
		profile.flush()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		if is_instance_valid(safe):
			_adapt_safe_area()

func _choose(index: int) -> void:
	var changed := choice != index
	choice = index
	_refresh_roster(changed)

func _choose_style(index: int) -> void:
	var changed := hero_style != index
	hero_style = index
	_refresh_roster(changed)

func _refresh_roster(gesture: bool) -> void:
	hero_preview.select_hero(Roster.id(choice, hero_style), gesture, profile.equipped("weapon", choice))
	for i in range(style_choices.size()):
		_restyle(style_choices[i], i == hero_style)
	for i in range(hero_choices.size()):
		var button := hero_choices[i]
		var weapon := Gear.weapon(profile.equipped("weapon", i), i)
		button.get_child(0).texture = _class_icon(i, weapon)
		_restyle(button, i == choice)
		button.get_child(0).modulate.a = 1.0 if i == choice else 0.62
		for mode in ["normal", "hover", "pressed", "disabled"]:
			var plate := button.get_theme_stylebox(mode)
			plate.set_content_margin(SIDE_TOP, 34)
			plate.set_content_margin(SIDE_BOTTOM, 6)

func _confirm_hero() -> void:
	if state != &"selection" or hero_preview.confirming:
		return
	hero_preview.confirm()
	for control in hero_choices + style_choices + selection_utilities + [enter_button]:
		control.disabled = true
	await get_tree().create_timer(Roster.CONFIRM_TIME).timeout
	for control in hero_choices + style_choices + selection_utilities + [enter_button]:
		control.disabled = false
	if state == &"selection":
		_begin()

func _show_selection() -> void:
	state = &"selection"
	_clear_input()
	overlay.hide()
	battle.hide()
	field.hide()
	battle_shade.hide()
	forge.hide()
	camp.texture = CAMP
	camp.show()
	camp_shade.show()
	hero_preview.show()
	selection.show()
	_choose(choice)

func _begin() -> void:
	_clear_input()
	run.reset(choice, profile.bonuses(choice), hero_style, profile.equipped("weapon", choice))
	state = &"battle"
	selection.hide()
	forge.hide()
	camp.hide()
	camp_shade.hide()
	hero_preview.hide()
	overlay.hide()
	field.show()
	battle_shade.show()
	battle.show()
	_set_glyph(&"attack", [&"sword", &"arrow", &"spark"][choice])
	_set_glyph(&"skill", [&"slash", &"fan", &"sigil"][choice])
	_set_glyph(&"tactic", [&"cleave", &"heavy", &"frost"][choice])
	_describe(action_buttons[&"attack"], "普攻")
	_describe(action_buttons[&"skill"], run.hero.skill)
	_describe(action_buttons[&"tactic"], run.hero.tactic)
	var weapon := Gear.weapon(run.weapon_id, choice)
	if not weapon.is_empty():
		var attack_button: Button = action_buttons[&"attack"]
		var attack_glyph: Gothic.Glyph = attack_button.get_node("Glyph")
		attack_glyph.art = ForgeArt.texture(weapon.icon)
		attack_glyph.queue_redraw()
		_describe(attack_button, weapon.name + " · 普攻")
	match run.weapon_id:
		"warhammer":
			_describe(action_buttons[&"skill"], "撼地锤")
			_describe(action_buttons[&"tactic"], "震荡锤")
		"twin_blades":
			_set_glyph(&"skill", &"slash")
			_set_glyph(&"tactic", &"cleave")
			_describe(action_buttons[&"skill"], "旋刃")
			_describe(action_buttons[&"tactic"], "交刃")
	_update_battle()
	field.queue_redraw()
	sounds.play(&"start")

func _update_battle() -> void:
	wave_title.text = "%02d / %02d" % [run.wave + 1, Combat.WAVES.size()]
	life_seal.set_amount(run.hp, run.max_hp)
	mana_seal.set_amount(run.mana, run.max_mana)
	_cooldown(&"skill", run.skill_left, run.mana < run.skill_cost)
	_cooldown(&"tactic", run.tactic_left, run.mana < run.tactic_cost)
	_cooldown(&"retreat", run.retreat_left, false)

func _cooldown(action: StringName, left: float, out_of_mana: bool) -> void:
	var button: Button = action_buttons[action]
	button.disabled = left > 0.0 or out_of_mana
	cooldown_labels[action].text = str(ceili(left)) if left > 0.0 else ""
	action_glyphs[action].modulate.a = 0.42 if button.disabled else 1.0

func _pause_game() -> void:
	if state == &"battle":
		_show_result(&"paused")

func _stash_material(id: String, quantity: int) -> void:
	profile.collect(id, quantity)

func _open_forge() -> void:
	if state not in [&"selection", &"victory", &"defeat"]:
		return
	forge_return = state
	state = &"forge"
	_clear_input()
	overlay.hide()
	selection.hide()
	hero_preview.hide()
	battle.hide()
	field.hide()
	battle_shade.hide()
	camp.texture = FORGE_BG
	camp_shade.hide()
	camp.show()
	forge.open_role(choice)
	forge.show()

func _close_forge() -> void:
	if forge_return == &"selection":
		_show_selection()
		return
	forge.hide()
	camp.hide()
	field.show()
	battle_shade.show()
	battle.show()
	_show_result(forge_return)

func _show_result(outcome: StringName) -> void:
	state = outcome
	_clear_input()
	summary.visible = outcome != &"paused"
	result_forge_button.visible = outcome != &"paused"
	if summary.visible:
		profile.flush()
		summary.text = "击杀 %d · 余烬 %d · 材料 %d" % [run.kills, run.ash, run.materials_found]
	match outcome:
		&"paused":
			headline.text = "战斗暂停"
			_set_icon(overlay_action, &"play")
			_describe(overlay_action, "继续战斗")
		&"victory":
			headline.text = "石墓已肃清"
			_set_icon(overlay_action, &"retry")
			_describe(overlay_action, "再战一次")
		_:
			headline.text = "倒在石墓中"
			_set_icon(overlay_action, &"retry")
			_describe(overlay_action, "重新挑战")
	overlay.show()

func _continue_or_retry() -> void:
	if state == &"paused":
		overlay.hide()
		state = &"battle"
	else:
		_begin()

func _toggle_sound() -> void:
	sounds.enabled = not sounds.enabled
	for button in sound_buttons:
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

func _held(action: StringName) -> bool:
	return touches.values().has(action)

func _clear_input() -> void:
	touches.clear()
	_update_pressed()

func _update_pressed() -> void:
	for action in action_buttons:
		action_buttons[action].set_pressed_no_signal(_held(action))

func _add_action(row: HBoxContainer, action: StringName, title: String, primary: bool, skill_slot: bool) -> void:
	var tile := _icon_button(action, title, primary, Vector2(44, 52 if skill_slot else 44))
	if skill_slot:
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var glyph: Gothic.Glyph = tile.get_node("Glyph")
		glyph.offset_left = -20
		glyph.offset_right = 20
		glyph.offset_top = -21
		glyph.offset_bottom = 19
		tile.clip_contents = true
	tile.toggle_mode = true
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tile)
	action_buttons[action] = tile
	action_glyphs[action] = tile.get_node("Glyph")
	if action in [&"skill", &"tactic", &"retreat"]:
		var counter := _label("", 12, INK)
		counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		counter.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		counter.add_theme_constant_override("outline_size", 5)
		counter.add_theme_color_override("font_outline_color", NIGHT)
		tile.add_child(counter)
		_fill(counter)
		counter.offset_right = -5
		counter.offset_bottom = -3
		cooldown_labels[action] = counter

func _orb(title: String) -> Gothic.Orb:
	var orb := Gothic.Orb.new()
	orb.custom_minimum_size = Vector2(66, 66)
	orb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	orb.accessibility_name = title
	orb.tooltip_text = title
	return orb

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

func _class_icon(index: int, weapon: Dictionary) -> Texture2D:
	if not weapon.is_empty():
		return ForgeArt.texture(weapon.icon)
	return _spell_texture([&"sword", &"arrow", &"spark"][index])

func _set_icon(button: Button, symbol: StringName) -> void:
	var glyph: Gothic.Glyph = button.get_node("Glyph")
	glyph.symbol = symbol
	glyph.art = _spell_texture(symbol)
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
	var edge := Color("#aa7958") if accent else BORDER
	button.add_theme_stylebox_override("normal", _box(fill, edge, 1, 6))
	button.add_theme_stylebox_override("hover", _box(fill.lightened(0.08), edge, 1, 6))
	button.add_theme_stylebox_override("pressed", _box(fill.darkened(0.15), edge, 1, 6))
	button.add_theme_stylebox_override("disabled", _box(Color("#151312"), Color("#42372f"), 1, 6))
	for color_name in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(color_name, ink)
	button.add_theme_color_override("font_disabled_color", MUTED)

func _box(fill: Color, edge: Color, thickness: int, padding: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(thickness)
	box.set_corner_radius_all(2)
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
	shade.colors = PackedColorArray([Color("#100d0bd6"), Color("#17120c00"), Color("#17120c00"), Color("#0f0d0cbd")])
	var texture := GradientTexture2D.new()
	texture.gradient = shade
	texture.width = 2
	texture.height = 256
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	return texture

func _battle_gradient() -> GradientTexture2D:
	var shade := Gradient.new()
	shade.offsets = PackedFloat32Array([0.0, 0.20, 0.74, 1.0])
	shade.colors = PackedColorArray([Color("#0d090a8a"), Color("#0d090a00"), Color("#0d0b0b00"), Color("#0d0b0bdd")])
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
