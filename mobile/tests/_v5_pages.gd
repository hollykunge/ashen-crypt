extends "res://tests/_armory_shot.gd"

const PAGES := ["title", "roster", "creation", "farm", "notice", "route", "armory", "forge", "weapons", "settings"]

func _start() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	for slot in 2:
		game._create_in_slot(slot)
		_press(game, "入山")
	game._show_title()

func _process(_delta: float) -> bool:
	frame += 1
	if frame % 20 != 0:
		return false
	var index := frame / 20 - 1
	RenderingServer.force_draw(false)
	var file := out.path_join(PAGES[index] + ".png")
	var img := root.get_texture().get_image()
	if img == null or img.save_png(file) != OK:
		_cleanup()
		quit(1)
		return false
	print(file, " ", img.get_size(), " ", game.state)
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
			_press(game, "进入游戏")
		"roster":
			_press(game, "创建角色")
		"creation":
			_press(game, "入山")
		"farm":
			game.challenge_button.pressed.emit()
		"notice":
			_press(game.place_notice, "接敕")
		"route":
			game._enter_farm()
			game._open_forge()
		"armory":
			game.forge._forge_for_slot("weapon")
		"forge":
			game.forge._open_weapons()
		"weapons":
			game.weapon_gallery._finish(false)
			game._open_settings()
		"settings":
			_cleanup()
			return true
	return false
