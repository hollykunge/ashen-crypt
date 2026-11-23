extends SceneTree
## 量关节用：裁一块放大，每 10 像素一条细线、每 50 像素一条粗线（红），再标上点。
##   godot --headless --path mobile --script res://art/hero-rig/grid.gd -- <图> <输出> x y w h 倍数 [点x,点y ...]
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var img := Image.load_from_file(a[0])
	img.convert(Image.FORMAT_RGBA8)
	var r := Rect2i(int(a[2]), int(a[3]), int(a[4]), int(a[5]))
	var k := int(a[6])
	var crop := img.get_region(r)
	crop.resize(r.size.x * k, r.size.y * k, Image.INTERPOLATE_NEAREST)
	for x in range(r.position.x, r.end.x):
		if x % 10 == 0:
			var c := Color(1, 0, 0, 0.9) if x % 50 == 0 else Color(0, 0.4, 1, 0.35)
			for y in crop.get_height():
				crop.set_pixel((x - r.position.x) * k, y, c)
	for y in range(r.position.y, r.end.y):
		if y % 10 == 0:
			var c := Color(1, 0, 0, 0.9) if y % 50 == 0 else Color(0, 0.4, 1, 0.35)
			for x in crop.get_width():
				crop.set_pixel(x, (y - r.position.y) * k, c)
	for i in range(7, a.size()):
		var p := a[i].split(",")
		var q := (Vector2(float(p[0]), float(p[1])) - Vector2(r.position)) * k
		for dy in range(-4, 5):
			for dx in range(-4, 5):
				var xx := int(q.x) + dx
				var yy := int(q.y) + dy
				if xx >= 0 and yy >= 0 and xx < crop.get_width() and yy < crop.get_height() and (dx == 0 or dy == 0):
					crop.set_pixel(xx, yy, Color(0, 0.9, 0))
	crop.save_png(a[1])
	quit()
