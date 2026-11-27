extends "res://tests/_armory_shot.gd"

const PAGES := ["title", "farm", "route", "boss", "armory", "forge", "settings"]

# A device-sized render target avoids OS work-area clamping. Mirror Godot's
# canvas_items/expand scale from the active design size for each orientation.
var capture := SubViewport.new()

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0]
	capture.size = Vector2i(int(args[1]), int(args[2]))
	root.size = Vector2i(Vector2(capture.size) * (760.0 / maxi(capture.size.x, capture.size.y)))
	capture.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	capture.size_2d_override_stretch = true
	root.add_child(capture)
	_fit_capture()
	game = Main.instantiate()
	game.save_base = save_path
	capture.add_child(game)
	_start.call_deferred()

func _fit_capture() -> void:
	var design := Vector2(root.content_scale_size)
	var ratio := Vector2(capture.size) / design
	capture.size_2d_override = Vector2i((Vector2(capture.size) / minf(ratio.x, ratio.y)).round())

func _start() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	for slot in 2:
		game._create_in_slot(slot)
		_press(game, "入山")
	game._show_title()

func _process(_delta: float) -> bool:
	_fit_capture()
	frame += 1
	if frame % 45 != 0:
		return false
	var index := frame / 45 - 1
	if not _page_ready(PAGES[index]) or (PAGES[index] in ["farm", "route", "boss"] and not _feet_on_road()):
		push_error("Unexpected page or layout for %s at %s" % [PAGES[index], capture.size])
		_cleanup()
		quit(1)
		return false
	RenderingServer.force_draw(false)
	var file := out.path_join(PAGES[index] + ".png")
	var img := capture.get_texture().get_image()
	if img == null or img.get_size() != capture.size or img.save_png(file) != OK:
		_cleanup()
		quit(1)
		return false
	print(file, " ", img.get_size(), " ", game.state, " window=", root.size, " design=", root.content_scale_size, " canvas=", capture.size_2d_override)
	if index == 0:
		var page: Rect2 = game.title_page.get_global_rect()
		for element in [game.title_page.title, game.title_page.enter, game.title_page.hint]:
			if not page.encloses(element.get_global_rect()):
				push_error("Title element outside safe content: %s" % element.get_global_rect())
				_cleanup()
				quit(1)
				return false
	match PAGES[index]:
		"title":
			game._play_slot(0)
		"farm":
			game.challenge_button.pressed.emit()
			_press(game.place_notice, "接敕")
		"route":
			game._enter_farm()
			game._start_encounter(true)
		"boss":
			game._enter_farm()
			game._open_forge()
		"armory":
			game.forge._forge_for_slot("weapon")
		"forge":
			game._enter_farm()
			game._open_settings()
		"settings":
			_cleanup()
			return true
	return false

func _page_ready(page: String) -> bool:
	var wide := capture.size.x >= capture.size.y * 1.17
	if (root.content_scale_size.x > root.content_scale_size.y) != wide:
		return false
	if not game.get_rect().size.is_equal_approx(Vector2(capture.size_2d_override)):
		return false
	match page:
		"title":
			var controls = game.title_page
			var hint_rect: Rect2 = controls.hint.get_global_rect()
			return controls.is_visible_in_tree() and not controls.hero.get_global_rect().intersects(hint_rect)
		"farm":
			return game.state == &"farm" and game.field.visible
		"route":
			return game.run.continuous and not game.run.boss_wave()
		"boss":
			return game.run.boss_wave()
		"armory", "forge":
			return game.state == &"forge" and game.forge.inventory == (page == "armory")
		"settings":
			return is_instance_valid(game.settings) and game.settings.is_visible_in_tree()
	return false

func _feet_on_road() -> bool:
	var arena = game.field
	var tile: Rect2 = arena._road_tile()
	var surface: Image = arena.BANK.get_image()
	var positions: Array = [game.run.position]
	for enemy in game.run.enemies:
		positions.append(enemy.pos)
	for pos in positions:
		var feet: Vector2 = arena.world_offset + arena.jitter + arena._floor(pos) * arena.scale_to_screen
		var uv := (feet - tile.position) / tile.size
		if uv.y <= 0.0 or uv.y >= arena.ROAD_SURFACE:
			return false
		var pixel_x := floori(fposmod(uv.x, 1.0) * surface.get_width())
		if posmod(floori(uv.x), 2) == 1:
			pixel_x = surface.get_width() - 1 - pixel_x
		if surface.get_pixel(pixel_x, int(uv.y * surface.get_height())).a < 0.95:
			return false
	return true
