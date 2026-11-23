extends Control
const Blade = preload("res://scripts/reference_blade.gd")
const MaterialShader = preload("res://scripts/tailoring.gdshader")
const FontArt = preload("res://art/fonts/game.otf")
const FRAME_ROOT := "res://art/reference-hero/"
const STYLES := ["原布衣", "青碧布衣", "铆钉皮甲", "锁子甲"]
var figures: Array[Sprite2D] = []
var columns := 4

func _ready() -> void:
	get_window().title = "刀客 · 衣片样板"
	for pose in ["ready","strike"]:
		for style in STYLES.size():
			var figure := Sprite2D.new()
			figure.centered = false
			figure.texture = load(FRAME_ROOT + "bodies/cloth/" + pose + ".png")
			figure.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			var cloth := ShaderMaterial.new()
			cloth.shader = MaterialShader
			cloth.set_shader_parameter("style", style)
			cloth.set_shader_parameter("panel_mask", load(FRAME_ROOT + "tailoring/" + pose + ".svg"))
			figure.material = cloth
			add_child(figure)
			var blade := Polygon2D.new()
			figure.add_child(blade)
			Blade.setup(blade)
			Blade.apply(blade, pose)
			figures.append(figure)
	var back := Button.new()
	back.text = "返回试演"
	back.add_theme_font_override("font", FontArt)
	add_child(back)
	back.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	back.offset_left = -95
	back.offset_top = 8
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://ink_preview.tscn"))
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	columns = 4 if size.x > size.y else 2
	var cell := Vector2(size.x / columns, (size.y - 56) / (8 / columns))
	for i in figures.size():
		var origin := Vector2(i % columns, i / columns) * cell + Vector2(0,56)
		var s := minf((cell.x-16)/610.0, (cell.y-40)/470.0)
		figures[i].scale = Vector2.ONE*s
		figures[i].position = origin + Vector2((cell.x-610*s)/2 - 150*s,cell.y-12-560*s)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("#ead8b7"))
	draw_string(FontArt,Vector2(15,36),"刀客衣片样板",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("#35291e"))
	var cell := Vector2(size.x / columns, (size.y-56)/(8/columns))
	for i in 8:
		var origin := Vector2(i%columns,i/columns)*cell + Vector2(0,56)
		draw_rect(Rect2(origin+Vector2(4,2),cell-Vector2(8,4)),Color("#c3ab87"),false)
		draw_string(FontArt,origin+Vector2(13,27),STYLES[i%4]+(" · 备战" if i<4 else " · 斩击"),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("#69422f"))
