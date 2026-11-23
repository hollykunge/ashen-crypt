extends SceneTree
## Export the two standing views on the same 800 x 640 canvas as the swordsman.
const MaleBase = preload("res://scripts/male_base.gd")
const StraightAlpha = preload("res://scripts/unpremultiply.gdshader")
const OUT := "res://art/reference-hero/source/standing-views/"
const CANVAS := Vector2i(800, 640)
# Coordinates are in the source sheets. Floor is the exclusive lower edge at 50% alpha.
const SIDE_TOP := 80.0
const FRONT_TOP := 28.0
const FRONT_FLOOR := Vector2(512, 1479)
# Manually picked points: near shoulder, waistband top, wrist, kneecap and ankle.
# Use the screen-left limbs in both views. These are clothing landmarks, not bone pivots.
const SIDE_MARKS := {"shoulder": Vector2(169,212), "waist": Vector2(223,383),
	"wrist": Vector2(146,452), "knee": Vector2(183,579), "ankle": Vector2(143,752)}
const FRONT_MARKS := {"shoulder": Vector2(367,307), "waist": Vector2(512,624),
	"wrist": Vector2(289,736), "knee": Vector2(423,1011), "ankle": Vector2(390,1382)}

func _initialize() -> void:
	export_views.call_deferred()

func export_views() -> void:
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if error != OK:
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = CANVAS
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var side := MaleBase.new()
	viewport.add_child(side)
	side.set_pose("idle", false)
	var pin: Vector3i = MaleBase.REGISTRATION["keys"][0]
	var ground: Vector2 = side.transform * Vector2(pin.x, pin.y)
	var height := (pin.y - SIDE_TOP) * side.scale.y
	var front := Sprite2D.new()
	front.centered = false
	var pixels := Image.load_from_file(MaleBase.ROOT + "front.png")
	if pixels == null or pixels.is_empty():
		quit(1)
		return
	pixels.fix_alpha_edges()
	pixels.generate_mipmaps()
	front.texture = ImageTexture.create_from_image(pixels)
	front.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	front.scale = Vector2.ONE * (height / (FRONT_FLOOR.y - FRONT_TOP))
	front.position = ground - FRONT_FLOOR * front.scale
	viewport.add_child(front)
	var fix := ColorRect.new()
	fix.size = CANVAS
	var material := ShaderMaterial.new()
	material.shader = StraightAlpha
	fix.material = material
	fix.z_index = 1
	viewport.add_child(fix)
	var anchors := {"canvas": [CANVAS.x, CANVAS.y], "ground": [ground.x, ground.y]}
	for view: String in ["side", "front"]:
		side.visible = view == "side"
		front.visible = view == "front"
		var actor: Sprite2D = side if side.visible else front
		var marks := SIDE_MARKS if side.visible else FRONT_MARKS
		var registered := {}
		for point in marks:
			var dest: Vector2 = actor.transform * marks[point]
			registered[point] = [snappedf(dest.x, 0.01), snappedf(dest.y, 0.01)]
		anchors[view] = registered
		await process_frame
		await RenderingServer.frame_post_draw
		if viewport.get_texture().get_image().save_png(OUT + view + ".png") != OK:
			quit(1)
			return
	var file := FileAccess.open(OUT + "anchors.json", FileAccess.WRITE)
	if file == null or not file.store_string(JSON.stringify(anchors, "\t") + "\n"):
		quit(1)
		return
	file.close()
	quit(0)
