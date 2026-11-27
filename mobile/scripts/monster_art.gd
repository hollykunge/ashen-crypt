extends RefCounted

const Combat = preload("res://scripts/combat.gd")
const SideArt = preload("res://scripts/side_art.gd")
# 精怪图集：4 列 × 3 行，每格的逻辑尺寸是 160×96；贴图是它的 TEXEL 倍，和人物一样用带多级渐远的线性取样。
# 现在用的是皮影精怪（art/piying/monsters，prototype/cutout/pack_puppet_monsters.py 打包）：
# 每只一整块皮子，12 帧按挑签子的动法摆（走时颠、摇，蓄力后仰，出击前扑，被打死往后翻倒）。
const PATHS := [
	"res://art/piying/monsters/shanxiao.png",
	"res://art/piying/monsters/fire-fox.png",
	"res://art/piying/monsters/guardian.png",
	"res://art/piying/monsters/vine-spirit.png",
]
const TEXEL := 3
const CELL := Vector2(160, 96)
const PIVOT := Vector2(80, 76)
const STANDING_HEIGHT := 64.0
const WALK_FRAME_DISTANCE := 9.0
const WINDUP_FRAME := 4
const STRIKE_FRAME := 5
const FOLLOW_THROUGH_FRAME := 6
const IDLE_FRAME := 7
# 一层只出一种精怪（外加甲乙木当令时的藤精），贴图按需加载，只留最近用到的两张。
const CACHE_LIMIT := 2

static var _atlases := {}

static func variant(art: int, stem: String) -> int:
	return 3 if stem in ["jia", "yi"] else art

static func atlas(art: int) -> Texture2D:
	if not _atlases.has(art):
		if _atlases.size() >= CACHE_LIMIT:
			_atlases.erase(_atlases.keys()[0])
		_atlases[art] = SideArt.smooth(load(PATHS[art]))
	return _atlases[art]

# 某一格在贴图上的取样矩形（贴图像素）。
static func frame_region(frame: int) -> Rect2:
	return Rect2(Vector2(frame % 4, floori(frame / 4.0)) * CELL * TEXEL, CELL * TEXEL)

static func live_frame(enemy: Dictionary) -> int:
	if enemy.windup > 0.0 or enemy.attack_windup > 0.0:
		return WINDUP_FRAME
	if enemy.attack_recovery > 0.0:
		return STRIKE_FRAME if enemy.attack_recovery > Combat.ENEMY_ATTACK_RECOVERY * 0.53 else FOLLOW_THROUGH_FRAME
	if enemy.moving:
		return floori(enemy.stride / WALK_FRAME_DISTANCE) % 4
	return IDLE_FRAME

static func death_frame(age: float) -> int:
	return 8 + clampi(floori(age / (Combat.ENEMY_DEATH_DURATION / 4.0)), 0, 3)

static func draw_frame(canvas: CanvasItem, art: int, frame: int, height: float, ink: Color) -> void:
	var pixels := height / STANDING_HEIGHT
	var body := Rect2(-PIVOT * pixels, CELL * pixels)
	var region := frame_region(frame)
	var texture := atlas(art)
	canvas.draw_texture_rect_region(texture, body, region, ink * Color(1.18, 1.12, 1.04))
