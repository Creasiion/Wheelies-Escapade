extends Node3D

func _ready():
	$LeftZone.body_entered.connect(_on_left_entered)
	$RightZone.body_entered.connect(_on_right_entered)

func _on_left_entered(body):
	if body.name == "Player":
		set_meta("last_direction", "left")

func _on_right_entered(body):
	if body.name == "Player":
		set_meta("last_direction", "right")
