extends SceneTree

# 把每个地域的四幅底图拼成一条长卷。
#
#   godot --headless --path mobile --script res://tests/_stitch_plates.gd -- <幅目录> [地域,地域,...] [输出目录]
#
# <幅目录>/<地域>/<地域>-1.png … -4.png 由 art/side/plates/prompts.json 的流程出图。
# 相邻两幅在两侧留白处重叠：先在缩小图上搜重叠宽度与上下错位，取亮度差最小的一组，
# 再在重叠带里用 smoothstep 渐变交叉淡化。输出 res://art/side/plates/<地域>.webp。
# 手机上常见的贴图上限是 8192，拼出来超了就报错，不写文件。

const REGIONS := ["drought", "plague", "mine", "war", "flood", "court"]
const PANELS := 4
const OUT_DIR := "res://art/side/plates"
const MAX_WIDTH := 8192
const OVERLAP_RANGE := [0.12, 0.22]   # 占幅宽的比例；出图时两侧各留了 18% 的空地
# 上下错位不搜：每幅都按脚底 79% 出图，真实错位约为零；放开搜索只会去拟合纹理噪声，
# 三道接缝累起来能把地面线挪掉 5%，人物就悬空或陷地了。保留参数，需要时再开。
const SHIFT_RANGE := 0
const PROBE := 6                      # 搜索时缩小的倍数

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("用法：godot --headless --path mobile --script res://tests/_stitch_plates.gd -- <幅目录> [地域,...]")
		quit(1)
		return
	var regions: Array = REGIONS if args.size() < 2 or args[1].is_empty() else Array(args[1].split(","))
	var out_dir: String = args[2] if args.size() > 2 else OUT_DIR
	var failed := false
	for region in regions:
		failed = not _stitch(args[0], region, out_dir) or failed
	quit(1 if failed else 0)

func _stitch(root: String, region: String, out_dir: String) -> bool:
	var panels: Array[Image] = []
	for n in range(1, PANELS + 1):
		var path := "%s/%s/%s-%d.png" % [root, region, region, n]
		var image := Image.load_from_file(path)
		if image == null:
			printerr("缺 %s" % path)
			return false
		image.convert(Image.FORMAT_RGBA8)
		# 出图工具偶尔给出不同尺寸，统一到第一幅，接缝才对得上。
		if not panels.is_empty() and image.get_size() != panels[0].get_size():
			image.resize(panels[0].get_width(), panels[0].get_height(), Image.INTERPOLATE_LANCZOS)
		panels.append(image)
	var size := panels[0].get_size()

	# 每道接缝找最贴合的重叠宽度与上下错位。
	var seams := []
	for k in range(1, panels.size()):
		seams.append(_align(panels[k - 1], panels[k]))
	var total := size.x
	for seam in seams:
		total += size.x - int(seam.overlap)
	if total > MAX_WIDTH:
		printerr("%s 拼出来 %d 宽，超过 %d" % [region, total, MAX_WIDTH])
		return false

	var scroll := Image.create_empty(total, size.y, false, Image.FORMAT_RGBA8)
	scroll.blit_rect(panels[0], Rect2i(Vector2i.ZERO, size), Vector2i.ZERO)
	var x := 0
	var shift := 0
	for k in range(1, panels.size()):
		var seam: Dictionary = seams[k - 1]
		x += size.x - int(seam.overlap)
		shift += int(seam.shift)
		var piece := _shifted(panels[k], shift)
		_feather(piece, int(seam.overlap))
		scroll.blend_rect(piece, Rect2i(Vector2i.ZERO, size), Vector2i(x, 0))
		print("  %s 第 %d 道接缝：重叠 %d 像素，错位 %+d，亮度差 %.4f" % [region, k, seam.overlap, seam.shift, seam.cost])

	scroll.convert(Image.FORMAT_RGB8)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var out := "%s/%s.webp" % [out_dir, region]
	if scroll.save_webp(out, true, 0.88) != OK:
		printerr("写不出 %s" % out)
		return false
	print("%s  %dx%d" % [out, scroll.get_width(), scroll.get_height()])
	return true

# 在缩小的亮度图上比较：左幅的右边带 vs 右幅的左边带，地面线以下的前景权重加倍（错位最显眼的地方）。
func _align(left: Image, right: Image) -> Dictionary:
	var a := _luma(left)
	var b := _luma(right)
	var w := left.get_width() / PROBE
	var h := left.get_height() / PROBE
	var best := {"overlap": int(left.get_width() * 0.18), "shift": 0, "cost": INF}
	for percent in range(int(OVERLAP_RANGE[0] * 100), int(OVERLAP_RANGE[1] * 100) + 1):
		var span := maxi(2, w * percent / 100)
		for shift in range(-SHIFT_RANGE, SHIFT_RANGE + 1, 2):
			var dy := shift / PROBE
			var sum := 0.0
			var weight := 0.0
			for y in range(int(h * 0.05), int(h * 0.95)):
				var y2 := y - dy
				if y2 < 0 or y2 >= h:
					continue
				var bias := 2.0 if y > h * 0.55 else 1.0
				for i in range(0, span, 2):
					sum += absf(a[y * w + (w - span + i)] - b[y2 * w + i]) * bias
					weight += bias
			var cost := sum / maxf(1.0, weight)
			if cost < best.cost:
				best = {"overlap": span * PROBE, "shift": shift, "cost": cost}
	return best

func _luma(image: Image) -> PackedFloat32Array:
	var small := image.duplicate() as Image
	small.resize(image.get_width() / PROBE, image.get_height() / PROBE, Image.INTERPOLATE_BILINEAR)
	var values := PackedFloat32Array()
	values.resize(small.get_width() * small.get_height())
	for y in range(small.get_height()):
		for x in range(small.get_width()):
			var c := small.get_pixel(x, y)
			values[y * small.get_width() + x] = c.r * 0.299 + c.g * 0.587 + c.b * 0.114
	return values

# 上下挪 shift 像素，空出来的一两行用边缘行补，不留透明缝。
func _shifted(image: Image, shift: int) -> Image:
	if shift == 0:
		return image.duplicate() as Image
	var w := image.get_width()
	var h := image.get_height()
	var out := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	out.blit_rect(image, Rect2i(0, maxi(0, -shift), w, h - absi(shift)), Vector2i(0, maxi(0, shift)))
	var edge := 0 if shift > 0 else h - 1
	for row in range(absi(shift)):
		var target := row if shift > 0 else h - 1 - row
		out.blit_rect(image, Rect2i(0, edge, w, 1), Vector2i(0, target))
	return out

# 重叠带内透明度从 0 渐到 1（smoothstep），其余不透明，blend_rect 按透明度叠到长卷上。
func _feather(image: Image, overlap: int) -> void:
	for x in range(overlap):
		var t := float(x) / float(overlap)
		var alpha := t * t * (3.0 - 2.0 * t)
		for y in range(image.get_height()):
			var c := image.get_pixel(x, y)
			c.a = alpha
			image.set_pixel(x, y, c)
