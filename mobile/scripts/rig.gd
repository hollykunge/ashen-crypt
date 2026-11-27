extends RefCounted

# 一具骨架：记下落脚点、朝向、缩放与当前姿态，把角色本地坐标换算成屏幕坐标。
# 本地系以脚底为原点，上为负 y，+x 永远是角色面朝的方向。

const Motion = preload("res://scripts/motion.gd")

var anchor := Vector2.ZERO
var zoom := 1.0
var facing := 1.0
var height := 109.0
var width := 80.0
var pose := {}

func _init(at: Vector2 = Vector2.ZERO, scale_factor: float = 1.0, look_right: float = 1.0,
		tall: float = 109.0, wide: float = 80.0, shape: Dictionary = {}) -> void:
	anchor = at
	zoom = scale_factor
	facing = look_right
	height = tall
	width = wide
	pose = shape if not shape.is_empty() else Motion.REST.duplicate()

# 弯折按高度的 1.6 次方加权，等于胯不动、肩头甩出去。
func at(x: float, y: float) -> Vector2:
	var lift := clampf(-y / maxf(height, 1.0), 0.0, 1.4)
	var point := Vector2(x + float(pose.bend) * pow(lift, 1.6), y)
	point *= Vector2(pose.scale)
	point = point.rotated(float(pose.tilt) * facing)
	point += Vector2(pose.shift) * Vector2(facing, 1.0)
	return anchor + point * Vector2(facing, 1.0) * zoom

func ground() -> Vector2:
	return anchor
