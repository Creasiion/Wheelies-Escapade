extends CharacterBody3D
##
## Simple left/right character controller
##

@export var wheel_options: Array[Wheels] #to support multiple wheel types

var wheels: Wheels
var stamina: int
var move_speed: float
var current_wheel_index := 0

func _ready():
	if wheel_options.size() > 0:
		wheels = wheel_options[current_wheel_index]
		apply_wheels()

func _physics_process(_delta: float) -> void:

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)


	move_and_slide()
	
	# Switch wheels when Down Arrow or S is pressed
	if Input.is_action_just_pressed("ui_down"):
		switch_wheels()


func switch_wheels():
	current_wheel_index = (current_wheel_index + 1) % wheel_options.size()
	wheels = wheel_options[current_wheel_index]
	apply_wheels()
	print("Switched to: ", wheels.display_name, " | Speed: ", move_speed)
	
func apply_wheels():
	stamina = wheels.max_stamina
	move_speed = wheels.move_speed
	$Sprite3D.texture = wheels.character_sprite
