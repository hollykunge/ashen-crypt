extends SceneTree
## Run at --fixed-fps 24 --resolution 1280x900. Pass the capture directory after --.
const STYLES := ["cloth", "leather", "chain", "mixed"]
const ACTIONS := [["walk", 56], ["run", 48], ["attack", 80], ["ready", 12]]
var failures := 0

func _initialize() -> void:
	_record.call_deferred()

func _record() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		quit(2)
		return
	var preview = load("res://ink_preview.tscn").instantiate()
	root.add_child(preview)
	await process_frame
	await process_frame
	var field = preview.game.field
	for style in STYLES:
		var directory := String(args[0]).path_join(style)
		DirAccess.make_dir_recursive_absolute(directory)
		preview._set_style(style)
		field.art_review_scale = 1.0
		field._fit_stage()
		var index := 0
		var seen := {}
		for step in ACTIONS:
			preview._set_action(step[0])
			for tick in int(step[1]):
				await process_frame
				await RenderingServer.frame_post_draw
				seen[field.cutout.painted_frame] = true
				var screen := root.get_texture().get_image()
				var local_feet: Vector2 = field.world_offset + field._floor(preview.game.run.position) * field.scale_to_screen
				var feet: Vector2 = field.get_global_transform_with_canvas() * local_feet
				var rect := Rect2i(Vector2i(feet.round()) - Vector2i(125, 204), Vector2i(350, 278))
				if screen.get_region(rect).save_jpg(directory.path_join("%04d.jpg" % index), 0.97) != OK:
					quit(1)
					return
				if style == "mixed":
					var full := String(args[0]).path_join("screen")
					DirAccess.make_dir_recursive_absolute(full)
					screen.save_jpg(full.path_join("%04d.jpg" % index), 0.95)
				index += 1
		var required := ["ready", "combat-1", "combat-2", "strike", "combat-4", "combat-5"]
		for step in 8:
			required.append("walk-" + str(step))
			required.append("run-" + str(step))
		for pose in required:
			if not seen.has(pose):
				printerr("Missing recorded pose: ", style, "/", pose)
				failures += 1
		print(style, ": ", index, " frames, ", seen.size(), " poses")
	preview.queue_free()
	await process_frame
	quit(1 if failures else 0)
