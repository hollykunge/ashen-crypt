extends SceneTree

# 开发用：把生成出来的立绘裁成游戏要的规格。
#
# 游戏按「画幅高度」决定角色在场上的大小，并且把画幅下边缘当落脚点，
# 所以每张图都得：去掉四周透明边 → 按相对身高缩放 → 脚底压在下边缘。
# 手工对这个很容易错一两像素，角色就会浮在半空或忽大忽小。
#
# 用法 godot --headless --path mobile --script res://tests/_fit_art.gd -- <输入图> <输出名> [相对身高] [画幅高]
#   输入图   ChatGPT 出的透明背景 png/webp，多大都行，绝对路径
#   输出名   不带扩展名，直接写成 art/immortals/<输出名>.webp，例如 ready-0、bow-strike-2
#   相对身高 站姿填 1.0；下蹲、前扑的姿势按它比站姿矮多少填，例如 0.92。默认 1.0
#   画幅高   默认 288，与现有立绘一致
#
# 例 godot --headless --path mobile --script res://tests/_fit_art.gd -- D:/out/ready-0.png ready-0 1.0

const TARGET := 288

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("用法：<输入图> <输出名> [相对身高] [画幅高]")
		quit(1)
		return
	var source: String = args[0]
	var stem: String = args[1]
	var relative: float = clampf(float(args[2]) if args.size() > 2 else 1.0, 0.2, 1.0)
	var canvas: int = int(args[3]) if args.size() > 3 else TARGET

	var image := Image.load_from_file(source)
	if image == null:
		printerr("读不出这张图：" + source)
		quit(1)
		return
	image.convert(Image.FORMAT_RGBA8)
	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		printerr("整张图都是透明的：" + source)
		quit(1)
		return
	var figure := image.get_region(used)
	var tall := maxi(1, roundi(float(canvas) * relative))
	var wide := maxi(1, roundi(float(figure.get_width()) * float(tall) / float(figure.get_height())))
	figure.resize(wide, tall, Image.INTERPOLATE_LANCZOS)

	var sheet := Image.create(wide, canvas, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	# 脚底贴下边缘：引擎就是以这条线为落脚点画影子和特效的。
	sheet.blit_rect(figure, Rect2i(Vector2i.ZERO, figure.get_size()), Vector2i(0, canvas - tall))

	var out := "res://art/immortals/%s.webp" % stem
	var error := sheet.save_webp(out, false)
	if error != OK:
		printerr("写不出 %s [%d]" % [out, error])
		quit(1)
		return
	print("已写出 %s  %d×%d（原图 %d×%d，取用 %s）" % [out, wide, canvas,
		image.get_width(), image.get_height(), used])
	print("提示：新图落地后记得跑一次 godot --headless --path mobile --import，再用 _dress.gd 截图核对。")
	quit(0)
