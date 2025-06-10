extends CharacterBody3D

@export var wheel_options: Array[WheelStrategy] #to support multiple wheel types
@export var tire_glow_range := 5.0
@export var tire_stamina_cost := 20

@onready var flash_shader: Shader = preload("res://Shaders/PlayerFlash.gdshader")
var flash_mat: ShaderMaterial = null
@onready var mesh_inst: MeshInstance3D = $MeshInstance3D
var hit_cooldown: float = 1.0
var is_on_flash := false
@onready var hit_sound_player: AudioStreamPlayer3D = $HitSoundPlayer


var save_manager: Node
var wheels: WheelStrategy
var stamina: int
var move_speed: float
var current_wheel_index := 0
var hud: Node = null
var score: int = 0
# track how many tires the player holds
var tire_charges: int = 0

@export var tire_use_range := 5.0
@export var score_rate_per_sec := 1
@onready var glow_mat := preload("res://Shaders/TireGlow.gdshader")

func _ready():
	if not is_in_group("player"):
		add_to_group("player")
	if mesh_inst:
		var mat = mesh_inst.material_override
		if mat and mat is ShaderMaterial:
			flash_mat = mat
		else:
			push_warning("Expected a ShaderMaterial in Material Override on Player mesh")
	
	save_manager = get_node("/root/World/SaveManager")
	var data = save_manager.load_game()
	if data.has("score"):
		score = data.score
		stamina = data.stamina
		current_wheel_index = data.wheel_index
	
	if wheel_options.size() > 0:
		wheels = wheel_options[current_wheel_index]
		wheels.apply_to(self)
	
	hud = get_node_or_null("/root/World/Ingame UI")
	if hud:
		hud.show()
		
	# Stamina and Score timer
	$StaminaRegen.start()
	var score_timer = Timer.new()
	score_timer.wait_time = 1.0
	score_timer.one_shot = false
	score_timer.autostart = true
	add_child(score_timer)
	score_timer.connect("timeout", Callable(self, "_on_score_tick"))

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_M: # press "M" to save
			save_manager.save_game(score, stamina, current_wheel_index)
		elif event.keycode == KEY_L: # press “L” to load
			var data = save_manager.load_game()
			if data.has("score"):
				score = data.score
				stamina = data.stamina
				current_wheel_index = data.wheel_index
				switch_wheels()
				update_hud()

func _physics_process(_delta: float) -> void:

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") #Only allow movement of left and right

	velocity.x = input_dir.x * move_speed
	velocity.z = -move_speed

	move_and_slide()
	
	check_collisions()
	
	# Switch wheels when Down Arrow or S is pressed
	if Input.is_action_just_pressed("ui_down"):
		switch_wheels()
	if Input.is_action_just_pressed("Interact"):
		use_tire()

func _process(delta: float) -> void:
	for tire in get_tree().get_nodes_in_group("tires"):
		if not tire.visible:
			continue
		var dist = global_transform.origin.distance_to(tire.global_transform.origin)
		var mesh = tire.get_node("MeshInstance3D")
		if dist <= tire_glow_range:
			mesh.material_override = glow_mat
		else:
			mesh.material_override = null

func check_collisions():
	var collision = get_last_slide_collision()
	if not collision:
		return
	
	var collider = collision.get_collider()
	if not collider:
		return
		
	if collider.is_in_group("obstacle"):
		collider.visible = false
		if collider.has_method("set_collision_layer"):
			collider.collision_layer = 0
			collider.collision_mask = 0
			
		if $CollideCooldown.is_stopped():
			stamina -= 15
			update_hud()
			velocity.z = 0
			if stamina <= 0:
				print("GAME OVER!")
				save_manager.clear_save()
				get_tree().quit()
			_play_hit_sound()
			_start_hit_flash()
			$CollideCooldown.start()
			
		return
	
	
	  # don’t bounce backwards
	
	if stamina <= 0:
		print("GAME OVER!")
		save_manager.clear_save()
		get_tree().quit()

func _start_hit_flash():
	if not flash_mat:
		return
	if is_on_flash:
		return
	is_on_flash = true
	flash_mat.set_shader_parameter("flash_active", true)
	flash_mat.set_shader_parameter("flash_progress", 1.0)
	
	var tw = create_tween()
	tw.tween_property(flash_mat, "shader_parameter/flash_progress", 0.0, hit_cooldown).set_trans(Tween.TRANS_LINEAR)
	tw.connect("finished", Callable(self, "_on_flash_tween_finished"))

func _on_flash_tween_finished():
	if flash_mat:
		flash_mat.set_shader_parameter("flash_active", false)
		flash_mat.set_shader_parameter("flash_progress", 0.0)
	is_on_flash = false

func _play_hit_sound():
	if hit_sound_player:
		hit_sound_player.stop()
		hit_sound_player.play()


func switch_wheels():
	current_wheel_index = (current_wheel_index + 1) % wheel_options.size()
	wheels = wheel_options[current_wheel_index]
	wheels.apply_to(self)

func use_tire():
	print("use_tire() called, stamina=", stamina)
	if stamina <= tire_stamina_cost:
		print("Not enough stamina!")
		return
	var found_tire = null
	for tire in get_tree().get_nodes_in_group("tires"):
		if tire.visible and global_transform.origin.distance_to(tire.global_transform.origin) <= tire_glow_range:
			found_tire = tire
			break
	if not found_tire:
		return
	found_tire.visible = false
	if found_tire.has_method("set_collision_layer"):
		found_tire.collision_layer = 0
		found_tire.collision_mask = 0
	stamina -= tire_stamina_cost
	update_hud()
	var tc = get_node("/root/World/TerrainController") as TerrainController
	tc.clear_obstacles_next_blocks(3)

func update_hud():
	if not hud:
		return
	var stamina_bar = hud.get_node("StaminaBar")
	stamina_bar.max_value = wheels.max_stamina
	stamina_bar.value = stamina
	stamina_bar.get_node("StaminaLabelText").text = "Stamina: " + str(stamina) + " / " + str(wheels.max_stamina)
	
	hud.get_node("WheelsLabel").text = "Wheels: " + wheels.display_name
	hud.get_node("ScoreLabel").text = "Score: " + str(score)

func _on_stamina_regen_timeout() -> void:
	if stamina < wheels.max_stamina:
		stamina += 1
		update_hud()
		
func _on_score_tick() -> void:
	score += score_rate_per_sec
	update_hud()
