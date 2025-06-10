extends Node

@export var obstacle_folder: String = "res://Obstacles"
@export var item_folder: String = "res://Items"
@export var per_block: int = 2 # Number of blocks to appear on a single path

@export var per_block_obstacles := 2
@export var per_block_rings := 3
@export var tire_chance := 0.3

# Pool sizes
@export var pool_size_per_obstacle := 10
@export var pool_size_per_resource := 10

# Constants
const BLOCK_WIDTH = 7.0
const BLOCK_LENGTH = 10.0

# Internal lists + pools
var obstacle_scenes: Array[PackedScene] = []
var obstacle_pools: Dictionary = {}

var resource_scenes: Array[PackedScene] = []
var resource_pools: Dictionary = {}

func _ready() -> void:
	_load_and_pool(obstacle_folder, obstacle_scenes, obstacle_pools, pool_size_per_obstacle, Node3D)
	_load_and_pool(item_folder, resource_scenes, resource_pools, pool_size_per_resource, Area3D)

# Helper function to load all pools!
func _load_and_pool(folder:String, scenes:Array, pools:Dictionary, size:int, klass):
	var dir = DirAccess.open(folder)
	for file_name in dir.get_files():
		if not file_name.ends_with(".tscn"): 
			continue
		var scene = load(folder + "/" + file_name)
		if scene is PackedScene:
			scenes.append(scene)
			# create a pool array for this scene
			pools[scene] = []
			for i in size:
				var inst = scene.instantiate()
				inst.visible = false
				# disable physics until used
				if inst.has_method("set_collision_layer"):
					inst.set_collision_layer(0)
					inst.set_collision_mask(0)
				add_child(inst)
				pools[scene].append(inst)

func _get_pooled(scene:PackedScene, pools:Dictionary) -> Node:
	for inst in pools[scene]:
		if not inst.visible:
			return inst
	# fallback reuse oldest
	var inst = pools[scene].pop_front()
	pools[scene].append(inst)
	return inst

func spawn_on_block(block: Node3D) -> void:
	var margin_x = 1.0
	var margin_z = 2.0
		
	var hx = (BLOCK_WIDTH  * 0.5) - margin_x
	var hz = (BLOCK_LENGTH * 0.5) - margin_z
	
	var local_x = randf_range(-hx, hx)
	var local_z = randf_range(-hz, hz)

	for i in range(per_block_obstacles):
		var sc = obstacle_scenes[randi()%obstacle_scenes.size()]
		var obs = _get_pooled(sc, obstacle_pools)
		_place(obs, block, hx, hz, true)
		obs.add_to_group("obstacle")
		
	for sc in resource_scenes:
		var name = sc.resource_path.get_file().get_basename()
		if name == "Tire":
			if randf() < tire_chance:
				var tire = _get_pooled(sc, resource_pools)
				_ensure_tire_material_unique(tire)
				_place(tire, block, hx, hz)
				tire.add_to_group("tires")
				#var sig = tire.body_entered
				#var cb  = Callable(self, "_on_tire_picked").bind(tire)
				#if not sig.is_connected(cb):
					#sig.connect(cb)
		elif name == "GoldenRing":
			for i in range(per_block_rings):
				var ring = _get_pooled(sc, resource_pools)
				_place(ring, block, hx, hz)
				ring.add_to_group("rings")
				var sig = ring.body_entered
				var cb  = Callable(self, "_on_ring_picked").bind(ring)
				if not sig.is_connected(cb):
					sig.connect(cb)

func _place(inst:Node, block:Node3D, hx:float, hz:float, is_obstacle=false):
	# reparent
	inst.get_parent().remove_child(inst)
	block.add_child(inst)
	# random local pos
	var lx = randf_range(-hx,hx); var lz = randf_range(-hz,hz)
	inst.position = Vector3(lx, 0, lz)
	# enable collision if needed
	if inst.has_method("set_collision_layer"):
		inst.collision_layer = 1
		inst.collision_mask  = 1
	inst.visible = true

# handlers (same as before)
func _on_tire_picked(body, tire):
	if body.name != "Player": return
	tire.visible = false; 
	tire.get_parent().remove_child(tire); 
	add_child(tire)

func _on_ring_picked(body, ring):
	if body.name != "Player": 
		return
	ring.visible = false; 
	ring.get_parent().call_deferred("remove_child", ring)
	call_deferred("add_child", ring)
	body.score += 10; 
	body.update_hud()

func _ensure_tire_material_unique(tire: Node) -> void:
	if tire.has_meta("mat_dup_done"):
		return

	var mesh_inst = tire.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_inst:
		print(">>> material_override for", tire.name, "is:", mesh_inst.material_override)
		print(">>> surface_override_material(0) for", tire.name, "is:", mesh_inst.get_surface_override_material(0))
		if mesh_inst.mesh:
			print(">>> mesh.surface_get_material(0) for", tire.name, "is:", mesh_inst.mesh.surface_get_material(0))
	else:
		print(">>> No MeshInstance3D found under", tire.name)
	if mesh_inst:
		print("Duplicating material for tire:", tire.name)
		var override_mat = mesh_inst.material_override
		if override_mat and override_mat is ShaderMaterial:
			mesh_inst.material_override = override_mat.duplicate()
			tire.set_meta("mat_dup_done", true)
			return
			
		var m = mesh_inst.mesh
		if m:
			print("Other Duplicating material for tire:", tire.name)
			var surface_count = m.get_surface_count()
			if surface_count > 0:
				var orig = m.surface_get_material(0)
				if orig and orig is ShaderMaterial:
					var dup = orig.duplicate()
					mesh_inst.set_surface_override_material(0, dup)
					tire.set_meta("mat_dup_done", true)
					return
		print("Warning: No ShaderMaterial found on", tire.name)
