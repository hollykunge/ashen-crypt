extends SceneTree
## 拆件人物的接缝检查：每套衣装摆遍所有动作帧，画在纯品红底上，从画面四边往里灌底色，
## 灌不到的品红像素就是被人物围住的空隙。细碎的空隙（小于 SEAM_AREA）就是关节没盖住的缝。
## 大块的（比如手叉腰围出来的空当）是正常姿势，不算。
##
##   godot --path mobile --script res://tests/hero_rig_check.gd [-- 截图目录]
const Puppet = preload("res://scripts/hero_puppet.gd")
const KEY := Color(1, 0, 1)
const SEAM_AREA := 300
const SEAM_WIDTH := 4.0
const OUTFITS := {
	"base": {},
	"cloth": {"armor": "cloth", "gloves": "cloth", "greaves": "cloth", "boots": "cloth"},
	"leather": {"armor": "leather", "gloves": "leather", "greaves": "leather", "boots": "leather"},
	"chain": {"armor": "chain", "gloves": "chain", "greaves": "chain", "boots": "chain"},
	"mixed": {"armor": "chain", "gloves": "leather", "greaves": "cloth", "boots": "leather"},
}
const FRAMES := ["idle", "ready", "walk-0", "walk-1", "walk-2", "walk-3", "walk-4", "walk-5", "walk-6", "walk-7",
	"run-0", "run-1", "run-2", "run-3", "run-4", "run-5", "run-6", "run-7",
	"strike", "combat-1", "combat-2", "combat-3", "combat-4", "combat-5"]
const PER_ROW := 6
const CELL := Vector2i(330, 600)

var puppets := []
var outfit_names: Array = OUTFITS.keys()
var outfit_i := 0
var frame_i := 0
var wait := 0
var shots := ""
var failures := 0

func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var a := OS.get_cmdline_user_args()
	shots = a[0] if a.size() > 0 else ""
	var size := Vector2i(CELL.x * PER_ROW, CELL.y)
	DisplayServer.window_set_size(size)
	root.size = size
	var bg := ColorRect.new()
	bg.color = KEY
	bg.size = Vector2(size)
	root.add_child(bg)
	for i in PER_ROW:
		var p = Puppet.new()
		root.add_child(p)
		p.show_trail = false
		p.position = Vector2(CELL.x * (i + 0.42), CELL.y - 40)
		puppets.append(p)
	_pose_batch()

func _pose_batch() -> void:
	var name: String = outfit_names[outfit_i]
	var pieces: Dictionary = OUTFITS[name]
	for i in PER_ROW:
		var p = puppets[i]
		var k := frame_i + i
		p.visible = k < FRAMES.size()
		if not p.visible:
			continue
		p.equip(true, pieces.has("armor"), pieces.get("armor", "") in ["leather", "chain"], pieces)
		p.sample_frame(FRAMES[k])
		# 刀不查（环首本来就是空心的）
		p.sword.visible = false
	wait = 0

func _process(_d: float) -> bool:
	wait += 1
	# 弹簧要几帧才追到位
	if wait < 40:
		return false
	var img := root.get_texture().get_image()
	var name: String = outfit_names[outfit_i]
	for i in PER_ROW:
		var k := frame_i + i
		if k >= FRAMES.size():
			break
		var rect := Rect2i(CELL.x * i, 0, CELL.x, CELL.y)
		var seams := _holes(img, rect)
		if not seams.is_empty():
			failures += 1
			print("缝  %s %s  %s" % [name, FRAMES[k], seams])
	if not shots.is_empty():
		img.save_png("%s/%s-%02d.png" % [shots, name, frame_i / PER_ROW])
	frame_i += PER_ROW
	if frame_i >= FRAMES.size():
		frame_i = 0
		outfit_i += 1
		if outfit_i >= outfit_names.size():
			print("接缝检查：%d 帧有缝" % failures if failures else "接缝检查通过")
			quit(1 if failures else 0)
			return true
	_pose_batch()
	return false

## 返回 [[像素数, 中心], ...]：被人物围住的细缝。面积小于 SEAM_AREA 且又细又长（最窄处不超过 SEAM_WIDTH）
## 才算缝；两腿交叉围出来的三角空当是正常的负形，不算
func _holes(img: Image, r: Rect2i) -> Array:
	var w := r.size.x
	var h := r.size.y
	var seen := PackedByteArray()
	seen.resize(w * h)
	var key := PackedByteArray()
	key.resize(w * h)
	for y in h:
		for x in w:
			var c := img.get_pixel(r.position.x + x, r.position.y + y)
			# 品红：红蓝高、绿低（人物边缘半透明混出来的不算）
			if c.r > 0.9 and c.b > 0.9 and c.g < 0.1:
				key[y * w + x] = 1
	var out := []
	for start in w * h:
		if key[start] == 0 or seen[start] == 1:
			continue
		var stack := PackedInt32Array([start])
		seen[start] = 1
		var count := 0
		var border := false
		var sum := Vector2.ZERO
		var lo := Vector2i(w, h)
		var hi := Vector2i(-1, -1)
		while not stack.is_empty():
			var i: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			count += 1
			var x := i % w
			var y := i / w
			sum += Vector2(x, y)
			lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
			hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
			if x == 0 or y == 0 or x == w - 1 or y == h - 1:
				border = true
			for n in [i - 1, i + 1, i - w, i + w]:
				if n >= 0 and n < w * h and key[n] == 1 and seen[n] == 0 and absi(n % w - x) <= 1:
					seen[n] = 1
					stack.append(n)
		var span := hi - lo + Vector2i.ONE
		var thin := float(count) / maxf(span.x, span.y) <= SEAM_WIDTH
		if not border and count < SEAM_AREA and thin:
			out.append([count, Vector2i(sum / count)])
	return out
