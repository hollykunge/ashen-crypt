extends RefCounted
## Authored on quarter-size pose sheets. Below the waist only the two boot
## patches may receive equipment paint. All other pixels come from the base.
const POSES := {
	"idle": [62, Vector2(61, 136), Vector2(78, 135)],
	"ready": [69, Vector2(44, 136), Vector2(100, 135)],
	"strike": [72, Vector2(46, 136), Vector2(125, 135)],
	"walk-0": [61, Vector2(54, 134), Vector2(114, 133)],
	"walk-1": [63, Vector2(51, 130), Vector2(102, 136)],
	"walk-2": [62, Vector2(75, 135), Vector2(84, 125)],
	"walk-3": [62, Vector2(61, 134), Vector2(117, 131)],
	"walk-4": [63, Vector2(56, 135), Vector2(119, 133)],
	"walk-5": [62, Vector2(59, 123), Vector2(85, 135)],
	"walk-6": [62, Vector2(72, 136), Vector2(84, 125)],
	"walk-7": [64, Vector2(52, 134), Vector2(116, 132)],
	"run-0": [65, Vector2(35, 121), Vector2(97, 135)],
	"run-1": [69, Vector2(57, 117), Vector2(78, 135)],
	"run-2": [69, Vector2(38, 132), Vector2(83, 117)],
	"run-3": [55, Vector2(33, 117), Vector2(89, 107)],
	"run-4": [63, Vector2(39, 118), Vector2(103, 135)],
	"run-5": [67, Vector2(56, 117), Vector2(76, 135)],
	"run-6": [67, Vector2(38, 132), Vector2(81, 117)],
	"run-7": [54, Vector2(33, 117), Vector2(89, 106)],
	"combat-0": [67, Vector2(45, 136), Vector2(101, 135)],
	"combat-1": [70, Vector2(45, 136), Vector2(92, 135)],
	"combat-2": [69, Vector2(45, 135), Vector2(107, 135)],
	"combat-3": [70, Vector2(45, 135), Vector2(122, 135)],
	"combat-4": [68, Vector2(45, 135), Vector2(117, 135)],
	"combat-5": [68, Vector2(45, 135), Vector2(102, 135)],
	"combat-6": [65, Vector2(45, 134), Vector2(91, 135)],
	"combat-7": [65, Vector2(45, 136), Vector2(102, 135)],
}

static func can_paint(region: Array, pixel: Vector2i) -> bool:
	var point := Vector2(pixel) / 4.0
	if point.y < region[0]:
		return true
	for center: Vector2 in [region[1], region[2]]:
		if ((point - center) / Vector2(10, 5)).length_squared() < 1.0:
			return true
	return false
