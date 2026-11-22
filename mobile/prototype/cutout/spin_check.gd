extends SceneTree
## 整段演示（待机→走→跑→劈砍→待机→劈砍）逐帧查骨骼角度：每帧变化超过 60° 的都打印出来（正常动作不会一帧转这么多，
## 多半是角度跨 ±180° 时弹簧绕了一大圈）。
##   godot --path mobile --headless --fixed-fps 30 --script res://prototype/cutout/spin_check.gd -- swordsman
var demo
var n := 0
var prev := {}
var worst := {}
func _initialize():
	demo = load("res://prototype/cutout/demo.tscn").instantiate()
	root.add_child(demo)
func _process(d):
	n += 1
	if n > 3:
		var r = demo.rigs[0]
		for b in r._bones:
			var a: float = r._bones[b].rotation_degrees
			if prev.has(b):
				var dd := absf(a - prev[b])
				worst[b] = maxf(worst.get(b, 0.0), dd)
				if dd > 60.0:
					print("第 %d 帧（%s，%.2f 秒）%s 一帧转了 %.0f°：%.0f → %.0f" % [n, r._action, r._action_t, b, dd, prev[b], a])
			prev[b] = a
	if n > 240:
		var top := []
		for b in worst:
			top.append([worst[b], b])
		top.sort()
		top.reverse()
		print("每帧最大变化前几名：", top.slice(0, 6))
		return true
	return false
