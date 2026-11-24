extends Control
## A playable art review using the real game, its equipment rules and combat renderer.
## Each visit uses a disposable profile and never loads a player's character slots.
const Main = preload("res://main.tscn")
const Gear = preload("res://scripts/gear.gd")
const MIXED := {"armor": "chain", "gloves": "leather", "greaves": "cloth", "boots": "leather"}
const PUPPET_TOUR := [
	[1.1,"idle","待机"],[1.2,"ready","备战"],[2.4,"walk","行走"],[2.0,"run","奔跑"],
	[3.67,"attack_slow","出刀、斩击、收刀 · 慢放"],[1.1,"attack","连斩"],
	[0.8,"retreat","后撤"],[0.8,"hurt","受击"],[0.9,"skill","技能"],[1.1,"ready","回到备战"]
]
var game
var outfits := {}
var weapons := {}
var style := "base"
var pieces := {"armor": "cloth", "gloves": "cloth", "greaves": "cloth", "boots": "cloth"}
var piece_buttons := {}
var weapon := ""
var action := "ready"
var elapsed := 0.0
var save_path := "user://ink-preview-" + Crypto.new().generate_random_bytes(6).hex_encode() + ".json"
var toolbar: PanelContainer
var caption: Label
var style_buttons := {}
var weapon_buttons := {}
var action_buttons := {}

func _ready() -> void:
	get_window().title = "余烬地牢 · 手绘试演"
	game = Main.instantiate()
	game.save_base = save_path
	game.profile = Gear.new(save_path)
	add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_setup.call_deferred()

func _setup() -> void:
	game.profile.create_character({"gender": "male", "day_stem": "geng", "month_branch": "mao",
		"hour_branch": "si", "origin": "commoner", "name": "墨行"})
	game.active_slot = 0
	for material in ["geng", "jia", "bing"]:
		game.profile.collect(material, 500)
	for outfit in ["cloth", "leather", "chain"]:
		outfits[outfit] = {}
		for slot in Gear.ARMOR_TYPE_SLOTS:
			var draft := Gear.new_draft()
			draft.slot = slot
			draft.armor_type = outfit
			draft.materials = {"geng": 4, "jia": 2}
			if not game.profile.craft(draft):
				push_error("Preview outfit failed: " + game.profile.craft_error(draft))
				return
			outfits[outfit][slot] = draft.uid
	for form in Gear.WEAPON_FORMS:
		var draft := Gear.new_draft()
		draft.slot = "weapon"
		draft.weapon_form = form
		draft.materials = {"geng": 5, "bing": 1}
		if not game.profile.craft(draft):
			push_error("Preview weapon failed")
			return
		weapons[form] = draft.uid
	_equip()
	_build_toolbar()
	_set_action("ready")

func _build_toolbar() -> void:
	toolbar = PanelContainer.new()
	toolbar.add_theme_stylebox_override("panel", game._box(Color("#f0e0bff5"), game.BORDER, 1, 8))
	game.battle.add_child(toolbar)
	game.battle.move_child(toolbar, 1)
	var stack: VBoxContainer = game._vbox(5)
	toolbar.add_child(stack)
	var header: HBoxContainer = game._hbox(6)
	stack.add_child(header)
	caption = game._label("", 17, game.INK)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(caption)
	var back: Button = game._button("返回题页", false, 30)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://main.tscn"))
	header.add_child(back)
	var clothes: HBoxContainer = game._hbox(5)
	stack.add_child(clothes)
	for pair in [["base", "底身"], ["cuirass", "皮胸甲"], ["cloth", "布衣"], ["leather", "皮甲"], ["chain", "链甲"], ["mixed", "混搭"]]:
		var button: Button = game._button(pair[1], false, 34)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_set_style.bind(pair[0]))
		style_buttons[pair[0]] = button
		clothes.add_child(button)
	var parts: HBoxContainer = game._hbox(5)
	stack.add_child(parts)
	for slot in Gear.ARMOR_TYPE_SLOTS:
		var button: Button = game._button("", false, 30)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_cycle_piece.bind(slot))
		piece_buttons[slot] = button
		parts.add_child(button)
	var forms: HBoxContainer = game._hbox(5)
	stack.add_child(forms)
	for pair in [["jian", "剑"], ["sword", "刀"], ["bow", "弓箭"], ["spear", "长枪"]]:
		var button: Button = game._button(pair[1], false, 30)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_set_weapon.bind(pair[0]))
		weapon_buttons[pair[0]] = button
		forms.add_child(button)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 4)
	actions.add_theme_constant_override("v_separation", 4)
	stack.add_child(actions)
	for pair in [["cycle","刀客连演"],["idle", "站姿"], ["ready", "备战"], ["strike", "斩击定格"], ["walk", "走"], ["run", "跑"], ["attack", "攻击"], ["attack_slow", "慢斩"],
		["cleave","腾身重劈"], ["retreat", "后撤"], ["hurt", "受击"], ["skill", "技能"], ["auto", "实战"], ["bag", "行装"]]:
		var button: Button = game._button(pair[1], false, 28)
		button.pressed.connect(_set_action.bind(pair[0]))
		action_buttons[pair[0]] = button
		actions.add_child(button)
	_refresh_caption()

func _set_style(next: String) -> void:
	style = next
	if next == "base":
		weapon = ""
	else:
		if weapon.is_empty():
			weapon = "sword"
		if next != "cuirass":
			for slot in pieces:
				pieces[slot] = MIXED[slot] if next == "mixed" else next
	_equip()
	_refresh_caption()

func _cycle_piece(slot: String) -> void:
	if style in ["base", "shirt", "cuirass"] and slot == "armor":
		style = "shirt" if style == "base" else "base"
		_equip()
		_refresh_caption()
		return
	var index := Gear.ARMOR_TYPES.find(pieces[slot])
	pieces[slot] = Gear.ARMOR_TYPES[(index + 1) % Gear.ARMOR_TYPES.size()]
	style = pieces.armor if pieces.values().count(pieces.armor) == pieces.size() else "custom"
	_equip()
	_refresh_caption()

func _set_weapon(next: String) -> void:
	weapon = next
	_equip()
	_refresh_caption()

func _equip() -> void:
	for slot in Gear.ARMOR_TYPE_SLOTS:
		if style in ["shirt","cuirass"]:
			var upper: String = outfits.leather.armor if style == "cuirass" else outfits.cloth.armor
			_wear(slot, upper if slot == "armor" else "")
		else:
			_wear(slot, "" if style == "base" else outfits[pieces[slot]][slot])
	_wear("weapon", weapons.get(weapon, ""))
	game._enter_farm()
	game.field.art_review_scale = 1.55
	game.field._fit_stage()
	game.banner.hide()
	game.field.day_clock = 0.0
	game.field.daylight = 0.0
	game.set_physics_process(action == "auto")
	game.run.enemies.clear()
	if action == "auto":
		game._enter_farm()

func _wear(slot: String, uid: String) -> void:
	var current: String = game.profile.equipped(slot)
	if current != uid:
		game.profile.toggle_equip(current if uid.is_empty() else uid)

func _set_action(next: String) -> void:
	elapsed = 0.0
	if next == "bag":
		game.set_physics_process(false)
		game._open_forge()
		return
	action = next
	if next == "cleave":
		if not game.run.leaping_cleave:
			return
		_equip()
		game.field.art_review_scale = 1.12
		game.field._fit_stage()
		game.run.skill()
		return
	if next == "cycle" and weapon != "sword":
		weapon = "sword"
		_equip()
	game.set_physics_process(action == "auto")
	if action == "auto":
		game._enter_farm()
	else:
		game.run.enemies.clear()
		game.banner.hide()
	_refresh_caption()

func _refresh_caption() -> void:
	if caption == null:
		return
	var names := {"base": "底身", "shirt": "单穿布衣上衣", "cuirass": "皮胸甲", "cloth": "布衣", "leather": "皮甲", "chain": "链甲", "mixed": "混搭", "custom": "自选混搭"}
	caption.text = "手绘试演 · " + names[style] + " · " + {"": "空手", "jian": "剑", "sword": "刀", "spear": "长枪", "bow": "弓"}[weapon]
	for slot in piece_buttons:
		var title: String = Gear.SLOT_NAMES[Gear.SLOTS.find(slot)]
		if style in ["base", "shirt", "cuirass"]:
			piece_buttons[slot].disabled = slot != "armor"
			piece_buttons[slot].text = ("穿上布衣上衣" if style == "base" else "脱下布衣上衣") if slot == "armor" else title + " · 空"
			if style == "cuirass" and slot == "armor":
				piece_buttons[slot].text = "脱下皮胸甲"
			piece_buttons[slot].tooltip_text = ""
			continue
		piece_buttons[slot].disabled = false
		var material_name: String = {"cloth": "布", "leather": "皮", "chain": "链"}[pieces[slot]]
		piece_buttons[slot].text = title + " · " + material_name
		piece_buttons[slot].tooltip_text = "切换" + title + "款式"
	for key in style_buttons:
		game._restyle(style_buttons[key], key == style)
	for key in weapon_buttons:
		weapon_buttons[key].disabled = style in ["base", "shirt"] and key != "sword"
		game._restyle(weapon_buttons[key], key == weapon)
	for key in action_buttons:
		if key == "cleave":
			action_buttons[key].disabled = not game.run.leaping_cleave
		game._restyle(action_buttons[key], key == action)

func _process(delta: float) -> void:
	if game == null or not game.profile.has_character() or game.state == &"forge":
		return
	if action == "auto":
		game.set_physics_process(true)
		return
	elapsed += delta
	if action == "cleave":
		game.run.step(delta)
		game.field.queue_redraw()
		if game.run.motion != &"cleave":
			_set_action("ready")
		return
	var clip := action
	var clip_time := elapsed
	if action == "cycle":
		for step in PUPPET_TOUR:
			if clip_time < float(step[0]):
				clip = step[1]
				caption.text = "刀客连演 · " + str(step[2])
				break
			clip_time -= float(step[0])
		if clip == "cycle":
			elapsed = 0.0
			clip_time = 0.0
			clip = "idle"
			caption.text = "刀客连演 · 待机"
	var run = game.run
	run.motion = &"" if clip in ["ready", "walk", "run"] else (&"attack" if clip == "attack_slow" else StringName(clip))
	run.motion_duration = 1.1
	run.motion_time = fposmod(clip_time * (0.30 if clip == "attack_slow" else 1.0), 1.1)
	run.advancing = clip == "run"
	run.step_direction = Vector2.RIGHT
	run.stride = clip_time * (340.0 if clip == "run" else 170.0) if clip in ["walk","run"] else 0.0
	game.field.queue_redraw()

func _exit_tree() -> void:
	for suffix in ["", ".tmp"]:
		var path: String = save_path + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
