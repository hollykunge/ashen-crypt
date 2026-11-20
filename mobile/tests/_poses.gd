extends SceneTree

# 开发用：把八种兵器、男女两套人物在指定几格动作上的持械姿态排成一张表，截图存盘。
# 用法 godot --path mobile --resolution 1600x1800 --script res://tests/_poses.gd -- <输出> [格序，逗号分隔] [五行]
# 例 ... -- poses.png 0,3,5 huo

const HeldWeapon = preload("res://scripts/held_weapon.gd")
const SideArt = preload("res://scripts/side_art.gd")
const Appearance = preload("res://scripts/appearance.gd")
const WornSprites = preload("res://scripts/worn_sprites.gd")
const Gear = preload("res://scripts/gear.gd")
const Derive = preload("res://scripts/rules/derive.gd")
const PURE := {"jin": "geng", "mu": "jia", "shui": "ren", "huo": "bing", "tu": "wu"}

class Board extends Node2D:
	var frames: Array = []
	var looks := {}
	var sprites := []
	var zoom := 2.0

	func _draw() -> void:
		# 工程按 canvas_items 拉伸，这里的坐标是设计分辨率，不是窗口像素。
		var area := get_viewport_rect().size
		draw_rect(Rect2(Vector2.ZERO, area), Color("#5c5868"))
		var forms: Array = HeldWeapon.FORMS.keys()
		zoom = minf((area.x - 40.0) / (frames.size() * 2 * SideArt.CELL.x), area.y / (forms.size() * SideArt.CELL.y))
		var column := SideArt.CELL.x * zoom
		var row := SideArt.CELL.y * zoom
		var font := ThemeDB.fallback_font
		for r in range(forms.size()):
			var form: String = forms[r]
			draw_string(font, Vector2(4, r * row + 12), Gear.Rules.NAME_PARTS.weapons[form], HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
			for c in range(frames.size() * 2):
				var sex := c % 2
				var frame: int = frames[c / 2]
				var foot := Vector2(30 + c * column + SideArt.PIVOT.x * zoom, r * row + SideArt.PIVOT.y * zoom)
				draw_line(foot + Vector2(-20, 0), foot + Vector2(20, 0), Color(0, 0, 0, 0.35), 1.0)
				draw_set_transform(foot, 0.0, Vector2.ONE * zoom)
				var look: Dictionary = looks[form]
				HeldWeapon.draw_actor(self, sprites[sex], sex, frame, look)
				draw_set_transform(Vector2.ZERO)
		for c in range(frames.size()):
			draw_string(font, Vector2(30 + c * 2 * column + 40, 10), "第 %d 格" % frames[c], HORIZONTAL_ALIGNMENT_LEFT, -1, 9)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://poses.png"
	var frames: Array = []
	for part in (args[1] if args.size() > 1 else "0").split(",", false):
		frames.append(int(part))
	var element: String = args[2] if args.size() > 2 else ""
	var board := Board.new()
	board.frames = frames
	var entries := {}
	if not element.is_empty():
		for slot in Gear.SLOTS:
			entries[slot] = Derive.derive({"slot": slot, "materials": {PURE[element]: 6}, "process": ["forge_fine"]}, 3)
	for form in HeldWeapon.FORMS:
		board.looks[form] = Appearance.build(entries, {}, form)
	var any_look: Dictionary = board.looks.values()[0]
	board.sprites = [WornSprites.texture(false, any_look), WornSprites.texture(true, any_look)]
	root.add_child(board)
	for i in range(3):
		await process_frame
	var image := root.get_texture().get_image()
	if image.save_png(out) != OK:
		printerr("截图写入失败：" + out)
		quit(1)
		return
	print("截图已存：%s" % out)
	quit(0)
