extends Node

@export var obstacle_folder: String = "res://Obstacles"
@export var per_block: int = 2 # Number of blocks to appear on a single path
@export var pool_size_per_scene := 10

const BLOCK_WIDTH = 7.0
const BLOCK_LENGTH = 10.0

var obstacle_pools: Dictionary = {}
var obstacle_scenes: Array[PackedScene] = []

func _ready() -> void:
	# scan the Obstacles folder
	var dir = DirAccess.open(obstacle_folder)
	for file_name in dir.get_files():
		if file_name.ends_with(".tscn"):
			var path = obstacle_folder + "/" + file_name
			var scene = load(path)
			if scene is PackedScene:
				obstacle_scenes.append(scene)
	for scene in obstacle_scenes:
		var pool: Array = []
		for i in range(pool_size_per_scene):
			var inst = scene.instantiate() as Node3D
			inst.visible = false
			inst.collision_layer = 0
			inst.collision_mask  = 0
			add_child(inst)
			pool.append(inst)
		obstacle_pools[scene] = pool

func _get_pooled_obstacle(scene: PackedScene) -> Node3D:
	var pool = obstacle_pools[scene]
	for obs in pool:
		if not obs.visible:
			return obs
	var obs = pool.pop_front()
	pool.append(obs)
	return obs


func spawn_on_block(block: Node3D) -> void:
	var margin_x = 1.0
	var margin_z = 2.0
		
	var hx = (BLOCK_WIDTH  * 0.5) - margin_x
	var hz = (BLOCK_LENGTH * 0.5) - margin_z
	
	for i in range(per_block):
		# Compute a random local offset - Will be location obstacle is placed
		var local_x = randf_range(-hx, hx)
		var local_z = randf_range(-hz, hz)
		var local_pos = Vector3(local_x, 0.0, local_z)
		
		var world_pos = block.global_transform * local_pos
		
		# Randomly pick obstacle
		var scene = obstacle_scenes[randi() % obstacle_scenes.size()]
		var obs = _get_pooled_obstacle(scene)
		var old_parent = obs.get_parent()
		if old_parent:
			old_parent.remove_child(obs)
		block.add_child(obs)
		obs.global_position = world_pos
		obs.collision_layer = 1
		obs.collision_mask  = 1
		obs.visible = true
		
		var anim = obs.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if anim :
			if anim.has_animation("Pop_In Effect"):
				obs.scale = Vector3.ZERO
				anim.play("Pop_In Effect")
