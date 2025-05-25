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

# Pools and State
var TerrainBlocks: Array[PackedScene] = []
var terrain_pools: Dictionary = {}
var terrain_belt: Array[Node3D] = []
var current_exit_transform: Transform3D
var player: Node3D
var last_entry_block: Node3D = null
var last_snapped_yaw: float = 0.0

func _ready() -> void:
	player = get_node_or_null("/root/World/Player")
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
			scene = TerrainBlocks.pick_random()

		var block = _get_pooled_block(scene)
		var entry = block.get_node("Entry") as Area3D
		
		if i == 0:
			block.global_transform = entry.transform.affine_inverse()
		else:
			block.global_transform = current_exit_transform * entry.transform.affine_inverse()
			
		block.visible = true
		block.global_position.y = 0
		terrain_belt.append(block)
		
		if block.name == "ForkPath":
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

	# Only add blocks if needed
	if not _needs_more_blocks_ahead(player_z):
		return
		
	var last_block = terrain_belt.back()
	var scene = _pick_next_scene()

	if last_block.name == "ForkPath" and last_block.has_meta("last_direction"):
		var dir = last_block.get_meta("last_direction")  # "left" or "right"
		var exit_node = last_block.get_node_or_null(dir.capitalize() + "Exit")
		if exit_node:
			current_exit_transform = exit_node.global_transform
		last_block.remove_meta("last_direction")

	# Placing block on path
	var new_block = _get_pooled_block(scene)
	var entry = new_block.get_node_or_null("Entry") as Area3D

	new_block.global_transform = current_exit_transform * entry.transform.affine_inverse()
	new_block.global_position.y = 0
	new_block.visible = true
	terrain_belt.append(new_block)
	
	if new_block.name == "ForkPath":
		_wire_fork_branches(new_block)
	else:
		_wire_entry_pivot(new_block)

	# Updating exit
	var exit_marker = _get_exit_marker(new_block)
	if exit_marker:
		current_exit_transform = exit_marker.global_transform

func _pick_next_scene() -> PackedScene:
	var last = terrain_belt.back()
	var candidates: Array[PackedScene] = []
	
	# Only allow forks AFTER a straight path
	for scene in TerrainBlocks:
		var name = scene.resource_path.get_file().get_basename()
		if last.name != "StraightPath" and name == "ForkPath":
			continue
		candidates.append(scene)
	
	return candidates.pick_random()


func _needs_more_blocks_ahead(player_z: float) -> bool:
	if terrain_belt.is_empty():
		return true
		
	var exit_z = current_exit_transform.origin.z
	var prev_block = terrain_belt.back()
	if prev_block.name == "ForkPath":
		return prev_block.has_meta("last_direction")
	
	return exit_z > player_z - (lookahead_blocks * BLOCK_LENGTH)

func _wire_entry_pivot(block):
	var entry = block.get_node_or_null("Entry") as Area3D
	if entry:
		var cb = Callable(self,"_on_entry_zone_entered").bind(block)
		if not entry.is_connected("body_entered", cb):
			entry.connect("body_entered", cb)

func _wire_fork_branches(block):
	for dir in ["Left","Right"]:
		var zone = block.get_node_or_null(dir+"ExitZone") as Area3D
		if zone:
			var cb = Callable(self,"_on_branch_zone_entered").bind(block, dir)
			if not zone.is_connected("body_entered", cb):
				zone.connect("body_entered", cb)

func _on_entry_zone_entered(body: Node, block_ref: Node3D) -> void:
	if body != player or block_ref == last_entry_block:
		return
	last_entry_block = block_ref

	# compute snapped yaw…
	var raw_yaw = current_exit_transform.basis.get_euler().y
	var snapped = round(raw_yaw / STEP) * STEP
	
	if is_equal_approx(snapped, last_snapped_yaw):
		return
	last_snapped_yaw = snapped
	
	player.rotation.y = snapped
	var pivot = player.get_node("CameraPivot") as Node3D
	pivot.target_yaw = snapped



func _on_branch_zone_entered(body, block_ref, dir):
	if body != player or block_ref == last_entry_block:
		return
	last_entry_block = block_ref

	var m = block_ref.get_node(dir + "Exit") as Marker3D
	current_exit_transform = m.global_transform

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
