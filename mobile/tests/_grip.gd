extends SceneTree

# 开发用：一种兵器、一个性别，十二格动作放大排开。每格左边是空手的人物并标出两手拳心（红=LEAD，蓝=SUPPORT），
# 右边是持械的样子，校握点和兵器角度用。
# 用法 godot --path mobile --resolution 2400x1700 --script res://tests/_grip.gd -- <输出> <sword|spear|bow> <0|1> [格序，逗号分隔]

const HeldWeapon = preload("res://scripts/held_weapon.gd")
const SideArt = preload("res://scripts/side_art.gd")
const Appearance = preload("res://scripts/appearance.gd")
const WornSprites = preload("res://scripts/worn_sprites.gd")

class Board extends Node2D:
	var frames: Array = []
	var look := {}
	var sprite: Texture2D
	var sex := 0

	func _draw() -> void:
		var area := get_viewport_rect().size
		draw_rect(Rect2(Vector2.ZERO, area), Color("#6a6676"))
		var columns := mini(3, frames.size())
		var rows := ceili(frames.size() / float(columns))
		var zoom := minf(area.x / (columns * 2 * SideArt.CELL.x), area.y / (rows * SideArt.CELL.y))
		var font := ThemeDB.fallback_font
		for i in range(frames.size()):
			var frame: int = frames[i]
			var cell := Vector2((i % columns) * 2 * SideArt.CELL.x, (i / columns) * SideArt.CELL.y) * zoom
			var body := HeldWeapon.body_frame(look.form, frame)
			draw_set_transform(cell, 0.0, Vector2.ONE * zoom)
			draw_texture_rect_region(sprite, Rect2(Vector2.ZERO, SideArt.CELL), SideArt.frame_region(body))
			for y in range(0, 96, 8):
				draw_line(Vector2(0, y), Vector2(96, y), Color(1, 1, 1, 0.08), 0.15)
			for x in range(0, 96, 8):
				draw_line(Vector2(x, 0), Vector2(x, 96), Color(1, 1, 1, 0.08), 0.15)
			draw_circle(HeldWeapon.LEAD[sex][body], 1.0, Color(1, 0.2, 0.2, 0.9))
			draw_circle(HeldWeapon.SUPPORT[sex][body], 1.0, Color(0.3, 0.6, 1, 0.9))
			draw_set_transform(cell + Vector2(SideArt.CELL.x, 0) * zoom + SideArt.PIVOT * zoom, 0.0, Vector2.ONE * zoom)
			HeldWeapon.draw_actor(self, sprite, sex, frame, look)
			draw_set_transform(Vector2.ZERO)
			draw_string(font, cell + Vector2(6, 22), "%d" % frame, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://grip.png"
	var form: String = args[1] if args.size() > 1 else "sword"
	var board := Board.new()
	board.sex = int(args[2]) if args.size() > 2 else 0
	for part in (args[3] if args.size() > 3 else "0,1,2,3,4,5,6,7,8,9,10,11").split(",", false):
		board.frames.append(int(part))
	board.look = Appearance.build({}, {}, form)
	board.sprite = WornSprites.texture(board.sex == 1, board.look)
	root.add_child(board)
	for i in range(3):
		await process_frame
	var image := root.get_texture().get_image()
	image.save_png(out)
	print("截图已存：%s" % out)
	quit(0)
