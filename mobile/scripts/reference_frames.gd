extends RefCounted
## Whole painted figures. The three approved key poses retain the source RGB pixels.
const ROOT := "res://art/reference-hero/frames/"
const FOOT := Vector2(300, 560)
const HEIGHT := 500.0
const OUTFIT_SHADER = preload("res://scripts/reference_outfit.gdshader")
const WARDROBE := "res://art/reference-hero/keyposes/"
const Blade = preload("res://scripts/reference_blade.gd")
static var _cache := {}

static func texture(frame: String, types := {}) -> Texture2D:
	return _style_texture(frame, types.get("armor", "cloth"))

static func apply(sprite: Sprite2D, frame: String, types: Dictionary) -> void:
	var armor: String = types.get("armor", "cloth")
	var gloves: String = types.get("gloves", "cloth")
	var greaves: String = types.get("greaves", "cloth")
	var boots: String = types.get("boots", "cloth")
	sprite.texture = _style_texture(frame, armor)
	if armor == gloves and armor == boots and armor == greaves:
		sprite.material = null
		return
	if sprite.material == null:
		sprite.material = ShaderMaterial.new()
		sprite.material.shader = OUTFIT_SHADER
	var material: ShaderMaterial = sprite.material
	material.set_shader_parameter("glove_texture", _style_texture(frame, gloves))
	material.set_shader_parameter("greave_texture", _style_texture(frame, greaves))
	material.set_shader_parameter("boot_texture", _style_texture(frame, boots))
	material.set_shader_parameter("pose_slots", cached_texture(WARDROBE + frame + "-slots.png"))

static func _style_texture(frame: String, style: String) -> Texture2D:
	if style != "cloth":
		return cached_texture(WARDROBE + frame + "-" + style + ".png")
	if Blade.POSES.has(frame):
		return cached_texture("res://art/reference-hero/bodies/cloth/" + frame + ".png")
	return cached_texture(ROOT + frame + ".png")

static func cached_texture(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]

static func attack_frame(phase: float, cues: Array) -> String:
	if cues.is_empty(): return "ready"
	var start := 0.0
	for i in cues.size():
		var hit: float = cues[i]
		var finish := 1.0 if i == cues.size() - 1 else hit + (float(cues[i + 1]) - hit) * 0.50
		if phase <= finish:
			if phase < hit:
				var u := (phase - start) / maxf(hit - start, 0.001)
				return "ready" if u < 0.20 else ("combat-1" if u < 0.65 else "combat-2")
			var u := (phase - hit) / maxf(finish - hit, 0.001)
			if u < 0.32: return "strike"
			return "combat-4" if u < 0.65 else ("combat-5" if u < 0.85 else "ready")
		start = finish
	return "ready"

static func frame_for(motion: StringName, phase: float, distance: float, running: bool, cues: Array) -> String:
	if motion.is_empty() and distance > 0.0:
		var stride := 1.15 if running else 0.72
		var frame := floori(distance / stride * 8.0) % 8
		return ("run-" if running else "walk-") + str(frame)
	match motion:
		&"idle": return "idle"
		&"strike": return "strike"
		&"attack": return attack_frame(phase, cues)
		&"hurt", &"retreat": return "combat-6" if phase < 0.72 else "ready"
		&"skill", &"tactic": return "combat-7" if phase < 0.82 else "ready"
		&"revive": return "combat-6" if phase < 0.5 else "idle"
	return "ready"
