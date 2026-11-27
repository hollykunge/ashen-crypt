extends SceneTree
## Render both production rigs through the same attack base and fixed 60 Hz simulation as gameplay.
const Rig = preload("res://prototype/cutout/cutout_rig.gd")
const OUT := "res://art/piying/ui-shots-v5/"
const CELL := Vector2i(550, 420)
var failed := false
var view := SubViewport.new()

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	view.size = CELL
	view.disable_3d = true
	view.transparent_bg = true
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	for who in ["piying", "nvjiang"]:
		for action in ["stand", "idle", "ready", "walk", "run", "attack", "hurt", "revive"]:
			var rig := Rig.new()
			view.add_child(rig)
			var dir := "res://prototype/cutout/%s/" % who
			rig.setup(dir + "rig.json", dir + "parts")
			rig.attack_from = "ready"
			rig.set_process(false)
			rig.blend_time = 0.0
			rig.scale *= 270.0 / rig.stand_height()
			rig.position = Vector2(217, 369)
			rig.play(action)
			var duration: float = rig.attack_end_time() if action == "attack" else (rig._run.period if action == "run" else (rig._walk.period if action == "walk" else 2.4))
			if action in ["hurt", "revive"]:
				duration = 1.0
			var sheet := Image.create_empty(CELL.x * 4, CELL.y * 2, false, Image.FORMAT_RGBA8)
			var worst_plant := 0.0
			var frame := 0
			for i in 8:
				var sample := roundi(60.0 * duration * i / (7.0 if action == "attack" else 8.0))
				while frame <= sample:
					rig.drive_t = frame / 60.0
					rig._process(1.0 / 60.0)
					if action in ["walk", "run"]:
						worst_plant = maxf(worst_plant, _plant_error(rig))
					frame += 1
				await process_frame
				await RenderingServer.frame_post_draw
				var img := view.get_texture().get_image()
				if action == "stand":
					var measured: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT + "rivets.json"))[who]
					for key: String in measured:
						var disk: Array = measured[key]
						var sprite: Sprite2D = rig._sprites[key.get_slice(":", 0)][0]
						for degree in range(360):
							var p := Vector2(disk[0], disk[1]) + Vector2.RIGHT.rotated(deg_to_rad(degree)) * float(disk[2])
							img.set_pixelv(Vector2i(sprite.to_global(p)), Color.LIME_GREEN)
					for bone in rig._bones.values():
						var pt := Vector2i(bone.global_position)
						for j in range(-3, 4):
							img.set_pixelv(pt + Vector2i(j, 0), Color.RED)
							img.set_pixelv(pt + Vector2i(0, j), Color.RED)
					img.save_png(OUT + "rig-debug-" + who + ".png")
					break
				sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(i % 4, i / 4) * CELL)
			if action != "stand":
				sheet.save_png(OUT + "motion-" + who + "-" + action + ".png")
			if action in ["walk", "run"]:
				while frame <= ceili(duration * 60):
					rig.drive_t = frame / 60.0
					rig._process(1.0 / 60.0)
					worst_plant = maxf(worst_plant, _plant_error(rig))
					frame += 1
				failed = failed or worst_plant > 0.001
				print(who, " ", action, " max plant error (leg lengths): ", worst_plant)
			rig.free()
	quit(1 if failed else 0)

func _plant_error(rig: Rig) -> float:
	var worst := 0.0
	var gait: Dictionary = rig._walk if rig.current_action() == "walk" else rig._run
	for side in ["near", "far"]:
		var phase := fposmod(rig.drive_t / float(gait.period) + (0.5 if side == "far" else 0.0), 1.0)
		if phase >= gait.duty:
			continue
		var foot: Node2D = rig._bones["foot_" + side]
		var sole := rig.to_local(foot.to_global(rig._at("shin", "sole") - rig._at("shin", "ankle")))
		var target := rig._gait_foot(phase, gait) * rig._leg
		if side == "far":
			target.x += rig.FAR_SHIFT.x
		worst = maxf(worst, sole.distance_to(target) / rig._leg)
	return worst
