extends SceneTree
## godot --path mobile --resolution 1280x900 --fixed-fps 30 --script res://tests/ink_preview_movie.gd -- <frames-directory>
const TOUR := [
	[0.0, "cloth", "sword", "idle"], [1.5, "cloth", "sword", "ready"],
	[3.0, "cloth", "sword", "strike"], [4.5, "cloth", "sword", "walk"],
	[7.0, "cloth", "sword", "run"], [9.5, "cloth", "sword", "attack"],
	[12.0, "leather", "sword", "attack"], [14.0, "chain", "sword", "attack"],
	[16.0, "mixed", "sword", "skill"], [17.0, "cloth", "sword", "auto"]
]
const WEAPON_TOUR := [
	[0.0,"cloth","sword","ready"],[1.0,"cloth","sword","attack_slow"],
	[5.0,"leather","sword","ready"],[6.0,"leather","sword","attack_slow"],
	[10.0,"chain","sword","ready"],[11.0,"chain","sword","attack_slow"],
	[15.0,"mixed","sword","ready"],[16.0,"mixed","sword","attack_slow"],
	[20.0,"cloth","sword","attack"],[22.0,"cloth","sword","auto"]
]
var preview
var elapsed := -0.2
var index := -1
var frames_dir := ""
var frame := 0
var tour := TOUR
var end_time := 20.0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		frames_dir = args[0]
		DirAccess.make_dir_recursive_absolute(frames_dir)
	if args.size()>1 and args[1]=="weapon":
		tour=WEAPON_TOUR
		end_time=25.0
	preview = load("res://ink_preview.tscn").instantiate()
	root.add_child(preview)

func _process(delta: float) -> bool:
	if preview.outfits.size() < 3 or preview.weapons.size() < 3:
		return false
	elapsed += delta
	if index + 1 < tour.size() and elapsed >= float(tour[index + 1][0]):
		index += 1
		preview._set_style(tour[index][1])
		preview._set_weapon(tour[index][2])
		preview._set_action(tour[index][3])
	_clear_tooltips(root)
	if not frames_dir.is_empty() and index >= 0:
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_jpg("%s/%05d.jpg" % [frames_dir, frame], 0.93)
		frame += 1
	return elapsed > end_time

func _clear_tooltips(node: Node) -> void:
	if node is Control:
		node.tooltip_text = ""
	for child in node.get_children():
		_clear_tooltips(child)
