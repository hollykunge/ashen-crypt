extends SceneTree

# 把 pixelfx 导出的逐五行图表拼成游戏用的击打图集。
#
#   godot --headless --path mobile --script res://tests/_pack_fx.gd -- <渲染目录>
#
# <渲染目录> 下按 <五行>/impacts/<效果>/<效果>.png|.json 排布，正是 art/fx/render.json 里那条
# node 命令的输出。每张图集一行一个五行（外加空手），一列一帧，只取前 PLAY 帧；
# 格子裁到所有行所有帧的并集包围盒，锚点随之平移。跑完把打印的常量抄进 scripts/fx_art.gd。

const ROWS := ["jin", "mu", "shui", "huo", "tu", "none"]
const SHEETS := {"hit-spark": 10, "crit-hit": 14}
const OUT_DIR := "res://art/fx"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("用法：godot --headless --path mobile --script res://tests/_pack_fx.gd -- <渲染目录>")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var failed := false
	for id in SHEETS:
		failed = not _pack(args[0], id, SHEETS[id]) or failed
	quit(1 if failed else 0)

func _pack(root: String, id: String, play: int) -> bool:
	var sources := []
	var frame_size := Vector2i.ZERO
	var pivot := Vector2i.ZERO
	var fps := 0
	for element in ROWS:
		var base := "%s/%s/impacts/%s/%s" % [root, element, id, id]
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
		var image := Image.load_from_file(base + ".png")
		if not parsed is Dictionary or image == null:
			printerr("读不到 %s" % base)
			return false
		var meta: Dictionary = parsed.meta.pixelfx
		var size := Vector2i(int(meta.frameSize[0]), int(meta.frameSize[1]))
		var here := Vector2i(int(meta.pivot[0]), int(meta.pivot[1]))
		if frame_size != Vector2i.ZERO and (size != frame_size or here != pivot):
			printerr("%s 各五行的格子或锚点不一致" % id)
			return false
		frame_size = size
		pivot = here
		fps = int(meta.fps)
		image.convert(Image.FORMAT_RGBA8)
		sources.append({"image": image, "columns": int(meta.columns)})

	# 所有行、所有播放帧的并集包围盒，四周留一像素。
	var used := Rect2i()
	for source in sources:
		for frame in range(play):
			var cell := _cell(source, frame, frame_size)
			var rect := (source.image as Image).get_region(cell).get_used_rect()
			if rect.size == Vector2i.ZERO:
				continue
			used = rect if used.size == Vector2i.ZERO else used.merge(rect)
	used = used.grow(1).intersection(Rect2i(Vector2i.ZERO, frame_size))

	var atlas := Image.create_empty(used.size.x * play, used.size.y * ROWS.size(), false, Image.FORMAT_RGBA8)
	for row in range(sources.size()):
		for frame in range(play):
			var cell := _cell(sources[row], frame, frame_size)
			atlas.blit_rect(sources[row].image, Rect2i(cell.position + used.position, used.size),
				Vector2i(frame * used.size.x, row * used.size.y))
	var out := "%s/%s.png" % [OUT_DIR, id]
	if atlas.save_png(out) != OK:
		printerr("写不出 %s" % out)
		return false
	var anchor := pivot - used.position
	print("%s  %dx%d  格 Vector2i(%d, %d)  锚点 Vector2(%d, %d)  %d 帧 × %d 行  %d fps" % [out,
		atlas.get_width(), atlas.get_height(), used.size.x, used.size.y, anchor.x, anchor.y, play, ROWS.size(), fps])
	return true

static func _cell(source: Dictionary, frame: int, size: Vector2i) -> Rect2i:
	var columns: int = source.columns
	return Rect2i(Vector2i(frame % columns, frame / columns) * size, size)
