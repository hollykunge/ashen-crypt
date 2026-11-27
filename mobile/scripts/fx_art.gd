extends RefCounted

# 击打特效图集。现在用皮影版（art/piying/fx，prototype/cutout/pack_puppet_fx.py 打包）：
# 镂空团花炸开、暴击叠火焰星芒，几片花瓣、火苗飞散，按五行上色；格子、锚点和原来的一样。
# 原来的像素火花还在 art/fx，由 pixelfx（MIT，见 art/fx/NOTICE.md）按五行配色渲出，配方在 art/fx/render.json。
# 每张图一行一个五行（外加空手），一列一帧。

const ROWS := ["jin", "mu", "shui", "huo", "tu", "none"]
## texel：贴图比格子的逻辑尺寸大几倍（皮影特效是高清原画，层主身上放大好几倍也不糊）。
## 手机显卡贴图最宽 4096，暴击按 2 倍画就只排 7 帧（15 帧/秒，时长和原来 14 帧/30 帧一样）
const SHEETS := {
	&"hit": {"texture": preload("res://art/piying/fx/hit.png"),
		"cell": Vector2i(113, 79), "pivot": Vector2(35, 64), "frames": 10, "fps": 30, "texel": 2},
	&"crit": {"texture": preload("res://art/piying/fx/crit.png"),
		"cell": Vector2i(178, 135), "pivot": Vector2(78, 105), "frames": 7, "fps": 15, "texel": 2}
}
# 特效像素与精怪像素一比一：精怪站立高 64 像素（MonsterArt.STANDING_HEIGHT，测试盯着两边相等）。
# 这里不 preload MonsterArt —— 它经 Combat 绕回来会成环。
const ART_HEIGHT := 64.0

static func duration(kind: StringName) -> float:
	var sheet: Dictionary = SHEETS[kind]
	return float(sheet.frames) / float(sheet.fps)

static func frame_at(kind: StringName, progress: float) -> int:
	var frames: int = SHEETS[kind].frames
	return clampi(floori(progress * frames), 0, frames - 1)

# 认不得的五行（空手、或日后新增）一律落到空手那一行，不会取到图外。
static func row_of(element: String) -> int:
	var row := ROWS.find(element)
	return row if row >= 0 else ROWS.size() - 1

static func region(kind: StringName, element: String, frame: int) -> Rect2:
	var cell := Vector2(SHEETS[kind].cell) * float(SHEETS[kind].get("texel", 1))
	return Rect2(Vector2(frame * cell.x, row_of(element) * cell.y), cell)

# 调用方先把画布变换设到受击者脚下（与 _draw_enemy 同一个 _at_actor），这里只按受击者的像素比例贴一格。
static func draw(canvas: CanvasItem, kind: StringName, element: String, progress: float, height: float) -> void:
	var sheet: Dictionary = SHEETS[kind]
	var pixels := height / ART_HEIGHT
	var pivot: Vector2 = sheet.pivot
	canvas.draw_texture_rect_region(sheet.texture, Rect2(-pivot * pixels, Vector2(sheet.cell) * pixels),
		region(kind, element, frame_at(kind, progress)))
