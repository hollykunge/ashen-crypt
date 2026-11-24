extends SceneTree
# 开发用：给主角右手拍特写（侧面、正面、背面），看握拳和手里的兵器。
# 用法 godot --path mobile --script res://tests/_hand_shot.gd -- <输出目录> [动作] [秒] [兵器形制]
const ModelHero = preload("res://scripts/model_hero.gd")
var out := "user://hand"
var action := "Idle_Loop"
var at := 0.0
var form := ""
var hero
var cam := Camera3D.new()
var frame := 0
const VIEWS := {"side": Vector3(-1, 0, 0), "front": Vector3(0, 0, 1), "back": Vector3(0, 0.3, -1), "out": Vector3(-1, 0.2, 0.6)}
var views: Array = VIEWS.keys()

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: action = a[1]
	if a.size() > 2: at = float(a[2])
	if a.size() > 3: form = a[3]
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(500, 500)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color("#c9c3b6")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color("#8a7d72")
	root.add_child(env)
	var key := DirectionalLight3D.new(); root.add_child(key)
	key.transform = Transform3D.IDENTITY.looking_at(Vector3(3, -4, -2.5), Vector3.UP)
	hero = ModelHero.new()
	root.add_child(hero)
	hero.fists = {"r": true, "l": true}
	if not form.is_empty() and hero.has_method("hold"):
		hero.hold(form, {})
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.45 if form.is_empty() else 1.6
	root.add_child(cam)

func _process(_d: float) -> bool:
	frame += 1
	hero.anim.play(hero.anim_name(action), 0.0)
	hero.anim.seek(at, true)
	hero.anim.pause()
	var s: Skeleton3D = hero.skeleton
	var c: Vector3 = s.get_bone_global_pose(s.find_bone("hand_r")).origin
	var v: Vector3 = VIEWS[views[(frame - 1) / 3]]
	cam.look_at_from_position(c + v.normalized() * 3.0, c)
	if frame % 3 != 0:
		return false
	var path := "%s/%s.png" % [out, views[frame / 3 - 1]]
	root.get_texture().get_image().save_png(path)
	print("SHOT ", path)
	return frame / 3 >= views.size()
