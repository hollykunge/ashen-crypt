extends "res://tests/_v6_pages.gd"

const VIEWS := ["roster", "farm", "route", "boss"]

func _start() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	for slot in 2:
		game._create_in_slot(slot)
		game.selection._choose("gender", "female" if slot == 1 else "male")
		_press(game.selection, "入山")
	game._show_roster()

func _process(_delta: float) -> bool:
	_fit_capture()
	frame += 1
	if frame % 45 != 0:
		return false
	var view: String = VIEWS[frame / 45 - 1]
	var ready := false
	if view == "roster":
		var page = game.roster_page
		ready = game.state == &"roster" and page.count() == 2 and page.list.get_child_count() == 3
		for card in page.list.get_children():
			ready = ready and page.get_global_rect().encloses(card.get_global_rect())
	else:
		ready = _page_ready(view) and _feet_on_road() and game.field._road_tile().size.y < game.field.size.y * 0.13
	if not ready:
		push_error("Invalid layout or state: %s %s" % [view, capture.size])
		_cleanup()
		quit(1)
		return false
	RenderingServer.force_draw(false)
	var img := capture.get_texture().get_image()
	if img == null or img.get_size() != capture.size or img.save_png(out.path_join(view + ".png")) != OK:
		_cleanup()
		quit(1)
		return false
	print("V7 ", view, " ", capture.size, " canvas=", capture.size_2d_override)
	match view:
		"roster":
			_press(game.roster_page, "入山")
		"farm":
			game.challenge_button.pressed.emit()
			_press(game.place_notice, "接敕")
		"route":
			game._enter_farm()
			game._start_encounter(true)
		"boss":
			game._show_roster()
			_press(game.roster_page, "删除")
			if game.roster_page.count() != 2 or not _press(game.roster_page, "确认删除") or game.roster_page.count() != 1:
				push_error("Two-step roster deletion failed")
				_cleanup()
				quit(1)
				return false
			if not _press(game.roster_page, "创建角色") or game.state != &"selection":
				push_error("Empty slot did not open the creator")
				_cleanup()
				quit(1)
				return false
			_cleanup()
			return true
	return false
