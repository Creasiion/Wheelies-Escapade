extends Resource
class_name WheelStrategy

@export var display_name: String
@export var move_speed: float
@export var max_stamina: int
@export var character_sprite: Texture

func apply_to(player: CharacterBody3D) -> void:
	player.move_speed = move_speed
	if player.stamina == 0:
		player.stamina = max_stamina
	else:
		player.stamina = min(player.stamina, max_stamina)
