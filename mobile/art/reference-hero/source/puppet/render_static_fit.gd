extends SceneTree
## Render the equipped game skeleton on the registered standing-view canvas.
## Pass an output directory after -- to export the four transparent fitting layers.
const Puppet = preload("res://scripts/male_puppet.gd")
const TEMPLATE := "res://art/reference-hero/source/standing-views/anchors.json"

func _initialize() -> void:
	render_layers.call_deferred()

func render_layers() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or DirAccess.make_dir_recursive_absolute(args[0]) != OK:
		push_error("Pass a writable output directory after --.")
		quit(1)
		return
	var template: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEMPLATE))
	var view := SubViewport.new()
	view.size = Vector2i(template.canvas[0], template.canvas[1])
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var actor := Puppet.new()
	view.add_child(actor)
	# Same camera for all layers. Registration compensates for the ankle origin,
	# which is behind the template's ground landmark and above the visible sole.
	actor.position = Vector2(template.ground[0], template.ground[1]) + Vector2(-17, 4)
	actor.scale = Vector2.ONE * 0.686
	actor.set_process(false)
	actor.play("stand")
	actor.pose_override = actor.rig.idle.duplicate()
	for frame in 90:
		actor._process(1.0 / 60.0)
	for style in ["base", "cloth", "leather", "chain"]:
		var pieces := {}
		if style != "base":
			for slot in ["armor", "gloves", "greaves", "boots"]:
				pieces[slot] = style
		actor.equip(false, style != "base", style in ["leather", "chain"], pieces)
		var bones := {"shoulder": "arm_near_up", "waist": "torso", "wrist": "arm_near_hand",
			"knee": "leg_near_lo", "ankle": "foot_near"}
		for mark in bones:
			var anchor: Array = template.side[mark]
			var joint: Node2D = actor._bones[bones[mark]]
			if joint.global_position.distance_to(Vector2(anchor[0], anchor[1])) > 0.01:
				push_error("%s: %s is outside the registered fitting point" % [style, mark])
				quit(1)
				return
		await RenderingServer.frame_post_draw
		if view.get_texture().get_image().save_png(args[0].path_join(style + ".png")) != OK:
			quit(1)
			return
	quit()
