extends SceneTree
## 劈砍时膝盖抖不抖（godot --path mobile --headless --fixed-fps 30 --script res://prototype/cutout/attack_jitter.gd -- idle 或 run）：每帧膝盖角度的变化，统计最大跳变和「来回反向」的次数（抖一下就是一弯一直一弯）
var r
var n := 0
var start := 0
var prev := {}
var dprev := {}
var maxd := {"near": 0.0, "far": 0.0}
var flips := {"near": 0, "far": 0}
func _initialize():
	r = load("res://prototype/cutout/cutout_rig.gd").new()
	root.add_child(r)
	r.setup("res://prototype/cutout/hero/rig.json", "res://prototype/cutout/hero/parts")
	r.play(OS.get_cmdline_user_args()[0])
func _process(d):
	n += 1
	if n == 40:
		r.play("attack"); start = n
	if start > 0 and n > start:
		for s in ["near", "far"]:
			var k: float = r._bones["leg_%s_lo" % s].rotation_degrees
			if prev.has(s):
				var dk: float = k - prev[s]
				maxd[s] = maxf(maxd[s], absf(dk))
				if dprev.has(s) and absf(dk) > 1.5 and absf(dprev[s]) > 1.5 and signf(dk) != signf(dprev[s]):
					flips[s] += 1
				dprev[s] = dk
			prev[s] = k
	if start > 0 and n > start + 40:
		print("膝盖每帧最大变化：近 %.1f° 远 %.1f°；来回反向：近 %d 次 远 %d 次" % [maxd.near, maxd.far, flips.near, flips.far])
		return true
	return false
