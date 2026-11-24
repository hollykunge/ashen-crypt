extends CanvasLayer
## 调试版（debug 导出、编辑器里运行）左下角显示帧率和渲染开销，真机测性能用；正式版（release 导出）不出现。
## 每半秒刷新：帧率、最近半秒最差的一帧（毫秒）、每帧绘制调用数、显存占用。

var _label := Label.new()
var _clock := 0.0
var _worst := 0.0


func _ready() -> void:
	layer = 128
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("outline_size", 4)
	_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_label.position += Vector2(6, -58)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func _process(delta: float) -> void:
	_worst = maxf(_worst, delta)
	_clock += delta
	if _clock < 0.5:
		return
	var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var vram := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	_label.text = "%d fps  最差 %.0f ms\n绘制 %d 次/帧  显存 %.0f MB" % [Engine.get_frames_per_second(), _worst * 1000.0, draws, vram]
	_clock = 0.0
	_worst = 0.0
