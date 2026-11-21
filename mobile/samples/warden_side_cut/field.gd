extends Node3D

const LEATHER_POSES := {
	&"idle": preload("res://samples/warden_side_cut/leather/idle.png"),
	&"load": preload("res://samples/warden_side_cut/leather/load.png"),
	&"gather": preload("res://samples/warden_side_cut/leather/gather.png"),
	&"anticipate": preload("res://samples/warden_side_cut/leather/anticipate.png"),
	&"drive": preload("res://samples/warden_side_cut/leather/drive.png"),
	&"strike": preload("res://samples/warden_side_cut/leather/strike.png"),
	&"reach": preload("res://samples/warden_side_cut/leather/reach.png"),
	&"release": preload("res://samples/warden_side_cut/leather/release.png"),
	&"settle": preload("res://samples/warden_side_cut/leather/settle.png"),
	&"recoil": preload("res://samples/warden_side_cut/leather/recoil.png"),
	&"recover": preload("res://samples/warden_side_cut/leather/recover.png"),
}
# Cells in the cloth-piece atlas, left to right in four columns.
const DYE_POSES := [&"idle", &"load", &"gather", &"anticipate", &"drive", &"strike", &"reach", &"release", &"settle", &"recoil", &"recover"]
const INK_TEAL := Color("#29564c")
var dye_material := ShaderMaterial.new()
var cloth_frames: SpriteFrames
var leather_frames: SpriteFrames

@onready var player: AnimatedSprite3D = $Character
@onready var camera: Camera3D = $Camera
var close_view := false
var inspecting := false
var view_offset := 0.0

func _ready() -> void:
	dye_material.shader = preload("res://samples/warden_side_cut/cloth_dye.gdshader")
	dye_material.set_shader_parameter("pieces", preload("res://samples/warden_side_cut/cloth_pieces.png"))
	for part in [&"body_dye", &"near_sleeve_dye", &"far_sleeve_dye"]:
		dye_material.set_shader_parameter(part, INK_TEAL)
	player.frame_changed.connect(_sync_dye_texture)
	player.animation_changed.connect(_sync_dye_texture)
	cloth_frames = player.sprite_frames
	leather_frames = cloth_frames.duplicate()
	for clip in cloth_frames.get_animation_names():
		for i in cloth_frames.get_frame_count(clip):
			var pose := cloth_frames.get_frame_texture(clip, i).resource_path.get_file().get_basename()
			leather_frames.set_frame(clip, i, LEATHER_POSES[StringName(pose)], cloth_frames.get_frame_duration(clip, i))
	player.animation_finished.connect(_idle)
	_idle()
	refresh_camera()

func _idle() -> void:
	inspecting = false
	player.play(&"idle")

func set_dye(enabled: bool) -> void:
	player.material_override = dye_material if enabled else null
	_sync_dye_texture()

func _sync_dye_texture() -> void:
	if player.material_override != dye_material:
		return
	var texture := player.sprite_frames.get_frame_texture(player.animation, player.frame)
	var cell := DYE_POSES.find(StringName(texture.resource_path.get_file().get_basename()))
	dye_material.set_shader_parameter("pose_texture", texture)
	dye_material.set_shader_parameter("atlas_cell", Vector2(cell % 4, floori(cell / 4.0)))

func set_leather(enabled: bool) -> void:
	var variant := leather_frames if enabled else cloth_frames
	if player.sprite_frames == variant:
		return
	var clip := player.animation
	var index := player.frame
	var progress := player.frame_progress
	var playing := player.is_playing()
	player.sprite_frames = variant
	player.animation = clip
	if playing:
		player.play(clip)
	else:
		player.pause()
	player.set_frame_and_progress(index, progress)

func swing() -> void:
	inspecting = false
	player.stop()
	player.play(&"swing")

func step_drawing(direction: int) -> void:
	var starting := player.animation != &"swing"
	var count := player.sprite_frames.get_frame_count(&"swing")
	player.animation = &"swing"
	player.pause()
	inspecting = true
	var index := posmod(player.frame + direction, count)
	if starting:
		index = 0 if direction > 0 else count - 1
	player.set_frame_and_progress(index, 0)

func refresh_camera() -> void:
	camera.fov = 17.2 if close_view else 40.0
	var focus_height := 0.91 if close_view else 1.72
	camera.position = Vector3(view_offset, focus_height + 1.12, 10.7)
	camera.look_at(Vector3(view_offset * 0.08, focus_height, 0.0))

func pan(pixels: float) -> void:
	view_offset = clampf(view_offset - pixels * 0.008, -1.35, 1.35)
	refresh_camera()
