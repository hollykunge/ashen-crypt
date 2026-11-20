extends SceneTree

# 开发用：每种形制随手打几把兵器，看零件拼出来的样子。每行一种形制，每把画待机、出招两格和一个图标。
# 用法 godot --path mobile --resolution 1800x1800 --script res://tests/_weapons.gd -- <输出> [每行几把] [种子]

const HeldWeapon = preload("res://scripts/held_weapon.gd")
const SideArt = preload("res://scripts/side_art.gd")
const Appearance = preload("res://scripts/appearance.gd")
const WornSprites = preload("res://scripts/worn_sprites.gd")
const Derive = preload("res://scripts/rules/derive.gd")
const Gear = preload("res://scripts/gear.gd")
const STEMS := ["jia", "yi", "bing", "ding", "wu", "ji", "geng", "xin", "ren", "gui"]

class Board extends Node2D:
	var rows: Array = []
	var sprite: Texture2D

	func _draw() -> void:
		var area := get_viewport_rect().size
		draw_rect(Rect2(Vector2.ZERO, area), Color("#5c5868"))
		var font := ThemeDB.fallback_font
		var row_height := area.y / rows.size()
		var per_row: int = rows[0].looks.size()
		var column := (area.x - 50.0) / per_row
		var zoom := minf(column / (SideArt.CELL.x * 2.6), row_height / SideArt.CELL.y)
		for r in range(rows.size()):
			var row: Dictionary = rows[r]
			draw_string(font, Vector2(4, r * row_height + 14), Gear.Rules.NAME_PARTS.weapons[row.form], HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
			for c in range(per_row):
				var look: Dictionary = row.looks[c]
				var left := 50.0 + c * column
				for f in range(2):
					var foot := Vector2(left + (SideArt.PIVOT.x + f * 70.0) * zoom, r * row_height + SideArt.PIVOT.y * zoom + 4.0)
					draw_set_transform(foot, 0.0, Vector2.ONE * zoom)
					HeldWeapon.draw_actor(self, sprite, 0, [0, 5][f], look)
					draw_set_transform(Vector2.ZERO)
				var icon := Rect2(Vector2(left + 190.0 * zoom, r * row_height + 6.0), Vector2.ONE * 46.0)
				draw_rect(icon, Color("#181516"))
				HeldWeapon.draw_icon(self, row.form, look.design, icon.grow(-4.0))
				draw_string(font, Vector2(left, (r + 1) * row_height - 4.0), String(look.design.blade if row.form == "sword" else look.design.head),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://weapons.png"
	var count: int = int(args[1]) if args.size() > 1 else 6
	var rng := RandomNumberGenerator.new()
	rng.seed = int(args[2]) if args.size() > 2 else 7
	var board := Board.new()
	for form in HeldWeapon.FORMS:
		var looks: Array = []
		for i in range(count):
			var materials := {STEMS[rng.randi() % STEMS.size()]: 4 + rng.randi() % 4}
			if rng.randf() < 0.6:
				materials[STEMS[rng.randi() % STEMS.size()]] = 1 + rng.randi() % 3
			var item := {"slot": "weapon", "weapon_form": form, "materials": materials,
				"process": ["forge_fine"], "uid": "%08x" % rng.randi()}
			var entry := Derive.derive(item, 1 + rng.randi() % 5)
			looks.append(Appearance.build({"weapon": entry}, {}, form))
		board.rows.append({"form": form, "looks": looks})
	var tally := {}
	for row: Dictionary in board.rows:
		for look: Dictionary in row.looks:
			var key: String = row.form + ":" + String(look.design.blade if row.form == "sword" else look.design.head)
			tally[key] = tally.get(key, 0) + 1
	print(tally)
	board.sprite = WornSprites.texture(false, board.rows[0].looks[0])
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
