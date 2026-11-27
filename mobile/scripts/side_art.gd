extends RefCounted

const Places = preload("res://scripts/rules/places.gd")
const SNOW_PASS = preload("res://art/piying/stage/river-scroll.webp")
# UI portraits share the dyed-leather cutouts.
const PORTRAIT := preload("res://art/ui-icons/portrait.png")
const PORTRAIT_FEMALE := preload("res://art/ui-icons/portrait-female.png")
const CELL := Vector2(96, 96)
const PIVOT := Vector2(47, 89)
const FLOOR := 0.76
const SNOW_FLOOR := 0.79
# 每一个人物像素占背景高度的比例，按山门石阶和雪道前景标定。
# 使用原画比例，导入时降低纹理分辨率也会保持同样的人物大小。
const STREET_ACTOR_SCALE := 1.64 / 887.0
const SNOW_ACTOR_SCALE := 1.52 / 887.0
# 地域共用月夜河卷，镜头位置、景片、天气按层变化。
const PLATES := {
	"drought": {"path": "res://art/piying/stage/river-scroll.webp", "floor": 0.79, "haze": Color("#d6c4a0"),
		"weather": &"dust", "shadow": Color("#3b2a1a9c"), "near": &"grass", "near_ink": Color("#3a2f20")},
	"plague": {"path": "res://art/piying/stage/river-scroll.webp", "floor": 0.79, "haze": Color("#b8b69b"),
		"weather": &"ash", "shadow": Color("#1c1a16b4"), "near": &"grass", "near_ink": Color("#2b2a22")},
	"mine": {"path": "res://art/piying/stage/river-scroll.webp", "floor": 0.79, "haze": Color("#9da3a8"),
		"weather": &"grit", "shadow": Color("#121416bc"), "near": &"rock", "near_ink": Color("#16181a")},
	"war": {"path": "res://art/piying/stage/river-scroll.webp", "floor": 0.79, "haze": Color("#a8b5c6"),
		"weather": &"ash", "shadow": Color("#1a2230ac"), "near": &"grass", "near_ink": Color("#2a2a2c")},
	"flood": {"path": "res://art/piying/stage/river-scroll.webp", "floor": 0.79, "haze": Color("#a7b6bb"),
		"weather": &"rain", "shadow": Color("#1f2a2eac"), "near": &"reed", "near_ink": Color("#18241f")},
	"court": {"path": "res://art/piying/stage/river-scroll.webp", "floor": 0.79, "haze": Color("#dde5ee"),
		"weather": &"mist", "shadow": Color("#3a4a66a0"), "near": &"cloud", "near_ink": Color("#eef3fa")},
}
# 长卷缺失时（还没出图、或日后新增地域）退回月夜河卷，画面照常能跑。
const PLATE_DEPTH := 0.5
# 长卷两头各有一段为拼接留的空地（每幅两侧 18%，折合整卷约 5%），镜头不往那里停。
const PLATE_MARGIN := 0.05
const FALLBACK_PLATE := {"key": "kunlun", "texture": SNOW_PASS, "floor": SNOW_FLOOR, "depth": 1.0, "margin": 0.0,
	"haze": Color(0.80, 0.85, 0.89), "weather": &"snow", "shadow": Color("#23364aa8"), "near": &"grass", "near_ink": Color("#1d2a35")}

static var _plate_cache := {}

# 按层取地域长卷。贴图按需加载，只留当前一张：六条长卷全常驻，手机上要吃掉上百兆显存。
static func plate_for(layer: int) -> Dictionary:
	var key := String(Places.block_of(layer).plate)
	var spec: Dictionary = PLATES.get(key, {})
	if spec.is_empty() or not ResourceLoader.exists(spec.path):
		return FALLBACK_PLATE
	if not _plate_cache.has(key):
		_plate_cache.clear()
		var plate := spec.duplicate()
		plate["key"] = key
		plate["depth"] = PLATE_DEPTH
		plate["margin"] = PLATE_MARGIN
		plate["texture"] = load(spec.path)
		if key == "drought":
			plate["floor"] = 0.78
			plate["haze"] = Color("#d8be95")
			plate["depth"] = 0.12
		_plate_cache[key] = plate
	return _plate_cache[key]

# 这一层落在长卷的哪儿：一个地域十层，从左端走到右端，天劫那层在最右。
static func plate_progress(layer: int) -> float:
	var span := Places.LAYERS_PER_BLOCK - 1
	return float(posmod(maxi(1, layer) - 1, Places.LAYERS_PER_BLOCK)) / float(span)

static func step_trace(distance: float, actor_scale: float, running: bool) -> Dictionary:
	var step_length := (33.0 if running else 22.0) * actor_scale
	var phase := fposmod(distance / step_length, 1.0)
	return {"plant": (0.5 - phase) * step_length, "phase": phase, "step_length": step_length}

static func smooth(texture: Texture2D) -> CanvasTexture:
	var out := CanvasTexture.new()
	out.diffuse_texture = texture
	out.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return out

# 取回贴图像素的副本供检查。
static func pixels(texture: Texture2D) -> Image:
	var source: Texture2D = texture.diffuse_texture if texture is CanvasTexture else texture
	# 无头模式下 get_image 交回的是贴图自己存的那一份，直接改会把底图改掉，所以一定先拷贝。
	var image: Image = source.get_image().duplicate()
	if image.is_compressed():
		image.decompress()
	image.clear_mipmaps()
	image.convert(Image.FORMAT_RGBA8)
	return image


## 按性别取主角头像（角色存档里的 gender，"female" 以外都按男）
static func portrait(gender: String) -> Texture2D:
	return PORTRAIT_FEMALE if gender == "female" else PORTRAIT
