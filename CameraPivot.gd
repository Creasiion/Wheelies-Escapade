# CameraPivot.gd
extends Node3D
@export var rotation_lerp_speed := 8.0
var target_yaw := 0.0

func _process(delta):
	rotation.y = lerp_angle(rotation.y, target_yaw, rotation_lerp_speed * delta)
