extends Node3D

@export var turn_speed := 5.0

# We only ever modify yaw here
var target_yaw := 0.0

func _process(delta):
	# Interpolate only the Y (yaw) channel
	rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)
