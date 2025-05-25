# CameraPivot.gd
extends Node3D

# how quickly the pivot eases toward its target angle
@export var rotation_lerp_speed := 8.0

# the “snap” step: PI/4 = 45°
const STEP := PI / 4.0

var target_y := 0.0

func _process(delta):
	# smoothly lerp current y toward target_y
	var cur = rotation.y
	rotation.y = lerp_angle(cur, target_y, rotation_lerp_speed * delta)
