extends Node3D
class_name TerrainController

# Constants
const STEP := PI/4.0  # 45°
const BLOCK_LENGTH := 10.0
const POOL_SIZE_PER_TYPE := 5

# Spawning config
@export var num_terrain_blocks: int = 4
@export var lookahead_blocks: int = 2
@export var recycle_distance: float = 20.0
@export_dir var path_blocks_folder: String = "res://Paths"

# Pools, State, and Obstacles
var TerrainBlocks: Array[PackedScene] = []
var terrain_pools: Dictionary = {}
var terrain_belt: Array[Node3D] = []
var current_exit_transform: Transform3D
var player: Node3D
var last_entry_block: Node3D = null
var last_snapped_yaw: float = 0.0
var obstacle_spawner: Node

func _ready() -> void:
	randomize()
	player = get_node_or_null("/root/World/Player")
	obstacle_spawner = get_node("ObstacleSpawner")
	_load_path_blocks(path_blocks_folder)
	_initialize_pools()
	_init_blocks(num_terrain_blocks)

func _physics_process(_delta: float) -> void:
	if player:
		_manage_terrain(player.position.z)

func _load_path_blocks(folder_path: String) -> void:
	var dir = DirAccess.open(folder_path)
	for file_name in dir.get_files():
		if file_name.ends_with(".tscn"):
			var scene = load(folder_path + "/" + file_name)
			if scene is PackedScene:
				TerrainBlocks.append(scene)

func _initialize_pools() -> void:
	for scene in TerrainBlocks:
		var pool: Array = []
		for i in range(POOL_SIZE_PER_TYPE):
			var instance = scene.instantiate()
			instance.visible = false
			add_child(instance)
			pool.append(instance)
		terrain_pools[scene] = pool
		
func _get_pooled_block(scene: PackedScene) -> Node3D:
	var pool = terrain_pools.get(scene)
	for block in pool:
		if not block.visible:
			return block
	var instance = scene.instantiate()
	add_child(instance)
	pool.append(instance)
	return instance

func _init_blocks(count: int) -> void:
	for i in range(count):
		var scene: PackedScene
		if i < 4: # Make the first 4 blocks is just the straight path
			scene = _get_scene_by_name("StraightPath")
		else:
			scene = _pick_next_scene()

		var block = _get_pooled_block(scene)
		block.set_meta("type", scene.resource_path.get_file().get_basename())
		var entry = block.get_node("Entry") as Area3D
		
		if i == 0:
			block.global_transform = entry.transform.affine_inverse()
		else:
			block.global_transform = current_exit_transform * entry.transform.affine_inverse()
			
		block.visible = true
		block.global_position.y = 0
		terrain_belt.append(block)
		if i > 1:
			obstacle_spawner.spawn_on_block(block)
		
		if block.get_meta("type") == "ForkPath":
			_wire_fork_branches(block)
		else:
			_wire_entry_pivot(block)
			var exit_marker = _get_exit_marker(block)
			if exit_marker:
				current_exit_transform = exit_marker.global_transform
		
		if i==0 and player: # Positioning player's start point
			var spawn_pos = entry.global_transform.origin
			spawn_pos.y += 1.0
			player.global_position = spawn_pos
			var target = current_exit_transform.origin
			player.look_at(target, Vector3.UP)

func _manage_terrain(player_z: float) -> void:
	# Recycle blocks behind player
	while terrain_belt.size() > 0 and terrain_belt[0].global_position.z < player_z - recycle_distance:
		var old_block = terrain_belt.pop_front()
		old_block.visible = false
		
		for child in old_block.get_children(): # Getting rid of obstacles
			if child.name.begins_with("Obstacle_"):
				child.visible = false

	# Only add blocks if needed
	if not _needs_more_blocks_ahead(player_z):
		return
		
	var last_block = terrain_belt.back()
	var scene = _pick_next_scene()

	if last_block.get_meta("type") == "ForkPath" and last_block.has_meta("last_direction"):
		var dir = last_block.get_meta("last_direction")  # "left" or "right"
		var exit_node = last_block.get_node_or_null(dir.capitalize() + "Exit")
		if exit_node:
			current_exit_transform = exit_node.global_transform
		last_block.remove_meta("last_direction")

	# Placing block on path
	var new_block = _get_pooled_block(scene)
	new_block.set_meta("type", scene.resource_path.get_file().get_basename())
	var entry = new_block.get_node_or_null("Entry") as Area3D

	new_block.global_transform = current_exit_transform * entry.transform.affine_inverse()
	new_block.global_position.y = 0
	new_block.visible = true
	terrain_belt.append(new_block)
	obstacle_spawner.spawn_on_block(new_block)
	
	if new_block.get_meta("type") == "ForkPath":
		_wire_fork_branches(new_block)
	else:
		_wire_entry_pivot(new_block)
		# Updating exit
		var exit_marker = _get_exit_marker(new_block)
		if exit_marker:
			current_exit_transform = exit_marker.global_transform
	
		

func clear_obstacles_next_blocks(count: int) -> void:
	for i in range(min(count, terrain_belt.size())):
		var block = terrain_belt[i]
		for obs in block.get_children():
			if obs.is_in_group("obstacle"):
				obs.visible = false
				# disable collision if you pooled
				if obs.has_method("set_collision_layer"):
					obs.set_collision_layer(0)
					obs.set_collision_mask(0)


func _pick_next_scene() -> PackedScene:
	var last = terrain_belt.back()
	var last_type = last.get_meta("type")
	var can_fork = last_type == "StraightPath"
	var roll = randf()
	
	if can_fork and randf() < 0.0001:
		print("    ↪ spawning FORK")
		return _get_scene_by_name("ForkPath")

	# otherwise pick among left, right, straight
	var pool: Array[PackedScene] = []
	for scene in TerrainBlocks:
		var name = scene.resource_path.get_file().get_basename()
		if not can_fork and name == "ForkPath":
			continue
		pool.append(scene)
	return pool.pick_random()



func _needs_more_blocks_ahead(player_z: float) -> bool:
	if terrain_belt.is_empty():
		return true
		
	var exit_z = current_exit_transform.origin.z
	var prev_block = terrain_belt.back()
	if prev_block.get_meta("type") == "ForkPath":
		return prev_block.has_meta("last_direction")

	return exit_z > player_z - (lookahead_blocks * BLOCK_LENGTH)

func _wire_entry_pivot(block):
	var entry = block.get_node_or_null("Entry") as Area3D
	if entry:
		var cb = Callable(self,"_on_entry_zone_entered").bind(block)
		if not entry.is_connected("body_entered", cb):
			entry.connect("body_entered", cb)

func _wire_fork_branches(block):
	if block.has_meta("fork_wired"):
		return
	block.set_meta("fork_wired", true)
	var entry = block.get_node("Entry")
	var left_zone = block.get_node("LeftZone")
	print("Entry at: ", entry.global_transform.origin)
	print("LeftZone at: ", left_zone.global_transform.origin)
	call_deferred("_deferred_wire_fork_branches", block)
	
func _deferred_wire_fork_branches(block: Node3D) -> void:
	print("👉 wiring fork branches for ", block.name)
	for dir in ["Left","Right"]:
		var zone = block.get_node_or_null(dir + "Zone") as Area3D
		if zone:
			var zone_pos = zone.global_transform.origin
			block.set_meta(dir + "_zone_z", zone_pos.z)
			
			var forward = -zone.global_transform.basis.z.normalized()
			block.set_meta(dir + "_zone_forward", forward)
			
			block.set_meta(dir + "_armed", false)
			var cb_exited  = Callable(self, "_on_zone_exited").bind(block, dir)
			var cb_entered = Callable(self, "_on_branch_zone_entered").bind(block, dir)

			zone.connect("body_exited",  cb_exited)
			zone.connect("body_entered", cb_entered)

func _on_entry_zone_entered(body: Node, block_ref: Node3D) -> void:
	if body != player or block_ref == last_entry_block:
		return
	last_entry_block = block_ref
	
	if block_ref.get_meta("type") == "ForkPath":
		return

	# compute snapped yaw…
	var raw_yaw = current_exit_transform.basis.get_euler().y
	var snapped = round(raw_yaw / STEP) * STEP
	
	if is_equal_approx(snapped, last_snapped_yaw):
		return
	last_snapped_yaw = snapped
	
	player.rotation.y = snapped
	var pivot = player.get_node("CameraPivot") as Node3D
	pivot.target_yaw = snapped

func _on_zone_exited(body: Node, block_ref: Node3D, dir: String) -> void:
	if body == player:
		block_ref.set_meta(dir + "_armed", true)

func _on_branch_zone_entered(body, block_ref, dir):
	print("_on_branch_zone_entered fired for ", dir)
	if body != player or block_ref == last_entry_block:
		return
	if not block_ref.get_meta(dir + "_armed"):
		return
	block_ref.remove_meta(dir + "_armed")
	
	var zone_pos = block_ref.get_meta(dir + "_zone_pos") as Vector3
	var forward_vec = block_ref.get_meta(dir + "_zone_forward") as Vector3
	var to_player = player.global_transform.origin - zone_pos
	var dist_along   = forward_vec.dot(to_player)
	if dist_along < 0.1:
		return
	
	block_ref.set_meta("last_direction", dir)
	
	print("Branch entered on block ", block_ref.name, " – direction: ", dir)

	var exit_marker = block_ref.get_node(dir + "Exit") as Marker3D
	current_exit_transform = exit_marker.global_transform

	var raw = current_exit_transform.basis.get_euler().y
	var snapped = round(raw / STEP) * STEP
	
	if is_equal_approx(snapped, last_snapped_yaw):
		return
	last_snapped_yaw = snapped

	player.rotation.y = snapped
	player.get_node("CameraPivot").target_yaw = snapped
	

func _get_exit_marker(block: Node3D) -> Marker3D:
	for name in ["Exit", "LeftExit", "RightExit"]:
		var marker = block.get_node_or_null(name)
		if marker:
			return marker
	return null

func _get_scene_by_name(name: String) -> PackedScene:
	for scene in TerrainBlocks:
		if scene.resource_path.get_file().get_basename().contains(name):
			return scene
	push_error("Scene with name '" + name + "' not found.")
	return TerrainBlocks[0]
