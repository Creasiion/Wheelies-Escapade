extends CharacterBody3D
##
## Simple left/right character controller
##

@export var wheel_options: Array[Wheels] #to support multiple wheel types

var wheels: Wheels
var stamina: int
var move_speed: float
var current_wheel_index := 0
var hud: Node = null

func _ready():
	if wheel_options.size() > 0:
		wheels = wheel_options[current_wheel_index]
		
	hud = get_node_or_null("/root/World/Ingame UI")
	if hud:
		hud.show()
		
	apply_wheels()
	$StaminaRegen.start()

func _physics_process(_delta: float) -> void:

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)

	move_and_slide()
	
	check_collisions()
	
	# Switch wheels when Down Arrow or S is pressed
	if Input.is_action_just_pressed("ui_down"):
		switch_wheels()

func check_collisions():
	if not $CollideCooldown.is_stopped():
		return  # Cooldown active

	var collision = get_last_slide_collision()
	if collision:
		var collider = collision.get_collider()
		if collider:
			stamina -= 15
			update_hud()
			$CollideCooldown.start()

			velocity.z = 0 # Don't go backwards after colliding

			if stamina <= 0:
				print("GAME OVER!")
				get_tree().quit()



func switch_wheels():
	current_wheel_index = (current_wheel_index + 1) % wheel_options.size()
	wheels = wheel_options[current_wheel_index]
	apply_wheels()
	
func apply_wheels():
	if stamina == 0:
		stamina = wheels.max_stamina
	else:
		stamina = min(stamina, wheels.max_stamina)
	move_speed = wheels.move_speed
	$Sprite3D.texture = wheels.character_sprite
	update_hud()
		

func update_hud():
	if not hud:
		return
	var stamina_bar = hud.get_node("StaminaBar")
	stamina_bar.max_value = wheels.max_stamina
	stamina_bar.value = stamina
	stamina_bar.get_node("StaminaLabelText").text = "Stamina: " + str(stamina) + " / " + str(wheels.max_stamina)
	
	hud.get_node("WheelsLabel").text = "Wheels: " + wheels.display_name

	#hud.get_node("ScoreLabel").text = "Score: " + str(score)


func _on_stamina_regen_timeout() -> void:
	if stamina < wheels.max_stamina:
		stamina += 1
		update_hud()
