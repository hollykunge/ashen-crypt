extends Control

const Puppet = preload("res://scripts/male_puppet.gd")
const Edits = preload("res://scripts/motion_edits.gd")
const Combat = preload("res://scripts/combat.gd")
const Gear = preload("res://scripts/gear.gd")
const Handles = preload("res://tools/pose_editor/handles.gd")
var actor := Puppet.new()
var handles := Handles.new()
var cutter := preload("res://tools/pose_editor/cut_canvas.gd").new()
var cut_tools := HBoxContainer.new()
var frame_tools := HBoxContainer.new()
var hint := Label.new()
var mode := OptionButton.new()
var stage := Control.new()
var toolbar := HBoxContainer.new()
var controls := HBoxContainer.new()
var slider := HSlider.new()
var frame_label := Label.new()
var status := Label.new()
var play_button: Button
var picker := OptionButton.new()
var saved := {}
var saved_disk := {}
var undo_stack := []
var redo_stack := []
var clip := "run"
var outfit := "base"
var frame := 0
var playing := false
var elapsed := 0.0
var stature := 1.0
var close_dialog := ConfirmationDialog.new()

func _ready() -> void:
	get_window().title = "刀客动作编辑器"
	get_window().content_scale_size = Vector2i(1060,700)
	get_window().min_size = Vector2i(960,640)
	get_tree().auto_accept_quit = false
	add_child(close_dialog)
	close_dialog.dialog_text = "放弃尚未保存的调整并退出？"
	close_dialog.confirmed.connect(func(): get_tree().quit())
	var bg := ColorRect.new()
	bg.color = Color("#272925")
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,16)
	var stack := VBoxContainer.new()
	margin.add_child(stack)
	stack.add_child(toolbar)
	mode.add_item("动作关节")
	mode.add_item("纸片裁剪")
	toolbar.add_child(mode)
	mode.item_selected.connect(func(i): set_cut_mode(i == 1))
	_options(toolbar,["跑步","挥刀连斩"],func(i): change_clip(["run","combo"][i]))
	_options(toolbar,["底身","布甲","皮甲","链甲"],func(i): dress(["base","cloth","leather","chain"][i]))
	_options(toolbar,["全身","关节放大"],func(i): layout_actor(i == 1))
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	_button(toolbar,"撤销",func(): history(false))
	_button(toolbar,"重做",func(): history(true))
	_button(toolbar,"保存到游戏",save)
	var views := HBoxContainer.new()
	views.size_flags_vertical = SIZE_EXPAND_FILL
	stack.add_child(views)
	cutter.size_flags_horizontal = SIZE_EXPAND_FILL
	views.add_child(cutter)
	cutter.edited.connect(cut_change)
	cutter.notice.connect(func(msg): status.text = msg)
	stage.size_flags_horizontal = SIZE_EXPAND_FILL
	views.add_child(stage)
	stage.clip_contents = true
	stage.size_flags_vertical = SIZE_EXPAND_FILL
	stage.add_child(actor)
	handles.z_index = 1000
	stage.add_child(handles)
	handles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	handles.actor = actor
	handles.cut_canvas = cutter
	handles.begin_drag.connect(snapshot)
	handles.changed.connect(write_key)
	actor.set_process(false)
	stature = actor.stand_height()/actor.scale.y
	stage.resized.connect(func(): layout_actor(stage.get_meta("zoom",false)))
	stack.add_child(controls)
	play_button = _button(controls,"原速播放",toggle_play)
	_button(controls,"上一帧",func(): step_frame(-1))
	_button(controls,"下一帧",func(): step_frame(1))
	controls.add_child(slider)
	slider.size_flags_horizontal = SIZE_EXPAND_FILL
	slider.step = 1
	slider.value_changed.connect(func(v): seek(int(v)))
	controls.add_child(frame_label)
	var footer := HBoxContainer.new()
	stack.add_child(footer)
	for key in handles.LABELS:
		picker.add_item(handles.LABELS[key])
	picker.select(1)
	footer.add_child(frame_tools)
	frame_tools.add_child(picker)
	picker.item_selected.connect(func(i): handles.selected = handles.LABELS.keys()[i]; handles.queue_redraw())
	_button(frame_tools,"清除此帧调整",clear_frame)
	footer.add_child(cut_tools)
	_options(cut_tools,Puppet.Cuts.NAMES.values(),func(i): cutter.inspect(Puppet.Cuts.NAMES.keys()[i],actor.motion_edits.get("cuts",{})))
	_button(cut_tools,"还原此片",reset_piece)
	hint.text = "暂停后拖圆点　·　空格播放　← → 逐帧"
	footer.add_child(hint)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.size_flags_horizontal = SIZE_EXPAND_FILL
	footer.add_child(status)
	saved = Edits.DEFAULTS.data.duplicate(true)
	saved_disk = saved.duplicate(true)
	actor.motion_edits = saved.duplicate(true)
	change_clip("run")
	set_cut_mode("--cuts" in OS.get_cmdline_user_args())

func set_cut_mode(active: bool) -> void:
	pause()
	mode.select(int(active))
	get_window().title = "刀客 · 纸片裁剪" if active else "刀客 · 动作关节"
	cutter.visible = active
	handles.visible = true
	cut_tools.visible = active
	frame_tools.visible = not active
	hint.text = "拖黄点改轮廓 · 双击边加点 · 右键删点" if active else "暂停后拖圆点　·　空格播放　← → 逐帧"
	if active:
		cutter.inspect(cutter.key,actor.motion_edits.get("cuts",{}))
	refresh()

func cut_change(part: String, points: Array) -> void:
	snapshot()
	var cuts: Dictionary = actor.motion_edits.get_or_add("cuts",{})
	cuts[part] = points
	actor.apply_piece_cuts()
	refresh()

func reset_piece() -> void:
	var cuts: Dictionary = actor.motion_edits.get("cuts",{})
	if not cuts.has(cutter.key): return
	snapshot()
	cuts.erase(cutter.key)
	if cuts.is_empty(): actor.motion_edits.erase("cuts")
	actor.apply_piece_cuts()
	cutter.inspect(cutter.key,cuts)
	refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if saved != actor.motion_edits:
			close_dialog.popup_centered()
		else:
			get_tree().quit()

func _options(parent: Control, items: Array, callback: Callable) -> void:
	var opt := OptionButton.new()
	for item in items:
		opt.add_item(item)
	parent.add_child(opt)
	opt.item_selected.connect(callback)

func _button(parent: Control, title: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = title
	parent.add_child(b)
	b.pressed.connect(callback)
	return b

func layout_actor(zoom: bool) -> void:
	stage.set_meta("zoom",zoom)
	var h := stage.size.y*(1.36 if zoom else 0.72)
	actor.scale = Vector2.ONE*h/stature
	actor.position = Vector2(stage.size.x*0.45,stage.size.y*(1.20 if zoom else 0.96))
	handles.queue_redraw()

func dress(style: String) -> void:
	outfit = style
	var slots := {}
	if style != "base":
		for slot in Gear.ARMOR_TYPE_SLOTS:
			slots[slot] = style
	actor.equip(clip == "combo",style != "base",style in ["leather","chain"],slots)
	handles.queue_redraw()

func change_clip(next: String) -> void:
	clip = next
	slider.max_value = Edits.FRAMES[clip]-1
	dress(outfit)
	seek(0)

func duration() -> float:
	return actor._run.period if clip == "run" else Gear.WEAPON_FORMS.sword.interval

func sample_frame(n: int) -> void:
	var phase := float(n)/float(Edits.FRAMES[clip])
	if clip == "run":
		actor.play("run")
		actor.drive_t = phase * duration()
	else:
		actor.drive_combo(phase,Combat.BLADE_CUES.sword)
	actor._process(duration()/float(Edits.FRAMES[clip]))

func seek(n: int) -> void:
	pause()
	frame = clampi(n,0,Edits.FRAMES[clip]-1)
	# Rebuild the same spring history when scrubbing either forward or backward.
	actor._spring.clear()
	actor._from.clear()
	actor._time = 0
	actor.edit_clip = ""
	actor._bones.arm_far_hand.rotation = 0
	actor.pose_override.clear()
	if clip == "run":
		for warmup in 2:
			for i in Edits.FRAMES.run:
				sample_frame(i)
	else:
		actor.play("ready")
		actor.drive_t = -1.0
		for i in 24:
			actor._process(1.0/60)
	for i in frame+1:
		sample_frame(i)
	refresh()

func refresh() -> void:
	slider.set_value_no_signal(frame)
	var keyed := false
	for track in actor.motion_edits.get(clip,{}).values():
		keyed = keyed or track.has(str(frame))
	frame_label.text = "%02d / %02d 帧%s" % [frame+1,Edits.FRAMES[clip]," ◆" if keyed else ""]
	status.text = "有未保存的调整" if saved != actor.motion_edits else "已同步"
	handles.queue_redraw()

func pause() -> void:
	playing = false
	elapsed = 0
	handles.show_handles = true
	play_button.text = "原速播放"

func toggle_play() -> void:
	if playing:
		pause()
	else:
		playing = true
		handles.drag = ""
		handles.show_handles = false
		play_button.text = "暂停"
	handles.queue_redraw()

func step_frame(direction: int) -> void:
	seek(posmod(frame+direction,Edits.FRAMES[clip]))

func _process(delta: float) -> void:
	if not playing:
		return
	elapsed += delta
	var dt := duration()/float(Edits.FRAMES[clip])
	while elapsed >= dt:
		elapsed -= dt
		frame = (frame+1)%int(Edits.FRAMES[clip])
		if frame == 0 and clip == "combo":
			var remainder := elapsed
			seek(0)
			toggle_play()
			elapsed = remainder
		else:
			sample_frame(frame)
	refresh()

func snapshot() -> void:
	undo_stack.append(actor.motion_edits.duplicate(true))
	if undo_stack.size() > 80:
		undo_stack.pop_front()
	redo_stack.clear()

func write_key(channel: String, value: Vector2) -> void:
	var tracks: Dictionary = actor.motion_edits.get_or_add(clip,{})
	var keys: Dictionary = tracks.get_or_add(channel,{})
	keys[str(frame)] = [value.x,value.y]
	actor.apply_motion_edits()
	picker.select(handles.LABELS.keys().find(handles.selected))
	refresh()

func clear_frame() -> void:
	pause()
	var tracks: Dictionary = actor.motion_edits.get(clip,{})
	for track in tracks.values():
		if track.has(str(frame)):
			snapshot()
			break
	for channel in tracks.keys():
		tracks[channel].erase(str(frame))
		if tracks[channel].is_empty():
			tracks.erase(channel)
	if tracks.is_empty():
		actor.motion_edits.erase(clip)
	seek(frame)

func history(redo: bool) -> void:
	var src := redo_stack if redo else undo_stack
	var dest := undo_stack if redo else redo_stack
	if src.is_empty():
		return
	dest.append(actor.motion_edits.duplicate(true))
	actor.motion_edits = src.pop_back()
	actor.apply_piece_cuts()
	if cutter.visible:
		cutter.inspect(cutter.key,actor.motion_edits.get("cuts",{}))
	seek(frame)

func save() -> void:
	var disk = JSON.parse_string(FileAccess.get_file_as_string(Edits.FILE))
	if disk != saved_disk:
		status.text = "文件已被修改，请重新打开编辑器"
		return
	var err := Edits.save(actor.motion_edits)
	if err == OK:
		saved = actor.motion_edits.duplicate(true)
		status.text = "已保存到游戏"
	else:
		status.text = "保存失败：" + error_string(err)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or close_dialog.visible:
		return
	match event.keycode:
		KEY_SPACE: toggle_play()
		KEY_LEFT: step_frame(-1)
		KEY_RIGHT: step_frame(1)
		KEY_S:
			if not event.ctrl_pressed: return
			save()
		KEY_Z:
			if not event.ctrl_pressed: return
			history(event.shift_pressed)
		_: return
	get_viewport().set_input_as_handled()
