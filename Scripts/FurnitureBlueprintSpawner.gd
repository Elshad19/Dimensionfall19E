class_name FurnitureBlueprintSpawner
extends Node3D

# This script handles the spawning of blueprint furniture for Chunk.gd
# New blueprint furniture will spawn when the player constructs one from the build menu
# Previously saved blueprint furniture will be loaded and spawned onto the map

# Dictionary to map the collider RID to the corresponding FurnitureBlueprintSrv
var collider_to_furniture: Dictionary = {}

# Reference to the World3D and Chunk
var world3d: World3D
var chunk: Chunk

# Array that contains the JSON data for furniture to be spawned
var furniture_json_list: Array = []:
	set(value):
		furniture_json_list = value
		await Helper.task_manager.create_task(_spawn_all_furniture).completed


# Initialize with reference to the chunk
func _init(mychunk: Chunk) -> void:
	chunk = mychunk

func _ready():
	world3d = get_world_3d()
	Helper.signal_broker.player_interacted.connect(_on_player_interacted)
	Helper.signal_broker.body_entered_item_detector.connect(_on_body_entered_item_detector)
	Helper.signal_broker.body_exited_item_detector.connect(_on_body_exited_item_detector)


# Function to spawn a FurnitureBlueprintSrv at a given position with given furniture data
# furniture_data example: {"json": {"id": "kitchen_cupboard", "rotation": 0}, "pos": Vector3(12,2,189)}
func spawn_furniture(furniture_data: Dictionary) -> void:
	# Get the position using the helper function
	var myposition: Vector3
	var new_furniture = FurnitureBlueprintSrv
	# Only new furniture has the json property
	if furniture_data.has("json"):
		myposition = chunk.mypos + get_furniture_position_from_mapdata(furniture_data)
		new_furniture = FurnitureBlueprintSrv.new(myposition, furniture_data.json, world3d)
	else: # Previously saved furniture does not have the json property
		myposition = get_furniture_position_from_mapdata(furniture_data)
		new_furniture = FurnitureBlueprintSrv.new(myposition, furniture_data, world3d)
	new_furniture.about_to_be_destroyed.connect(_on_furniture_about_to_be_destroyed)
	new_furniture.spawner = self
	# Add the collider to the dictionary
	collider_to_furniture[new_furniture.collider] = new_furniture

# Helper function to get the position of the furniture
func get_furniture_position_from_mapdata(furniture_data: Dictionary) -> Vector3:
	# Check if the furniture_data has the "pos" property (for new furniture)
	if furniture_data.has("pos"):
		return furniture_data.pos
	# Otherwise, calculate the position from "global_position_x", "global_position_y", "global_position_z"
	elif furniture_data.has("global_position_x") and furniture_data.has("global_position_y") and furniture_data.has("global_position_z"):
		return Vector3(
			furniture_data.global_position_x,
			furniture_data.global_position_y,
			furniture_data.global_position_z
		)
	# Default to (0,0,0) if no position data is available (fallback)
	return Vector3.ZERO


# Function to remove a furniture instance and clean up the tracking data
func remove_furniture(furniture: FurnitureBlueprintSrv):
	if is_instance_valid(furniture):
		# Remove the furniture from the dictionary
		collider_to_furniture.erase(furniture.collider)
		furniture.free_resources()
		# Queue the furniture for deletion
		furniture.queue_free()


func _on_furniture_about_to_be_destroyed(furniture: FurnitureBlueprintSrv):
	# Remove the furniture from the dictionary
	collider_to_furniture.erase(furniture.collider)
	

# Function to remove all furniture instances
func remove_all_furniture():
	for furniture in collider_to_furniture.values():
		remove_furniture(furniture)

# Function to get a FurnitureBlueprintSrv instance by its collider RID
func get_furniture_by_collider(collider: RID) -> FurnitureBlueprintSrv:
	if collider_to_furniture.has(collider):
		return collider_to_furniture[collider]
	return null


# Function to save the data of all spawned furniture
func get_furniture_data() -> Array:
	var furniture_data: Array = []
	for furniture in collider_to_furniture.values():
		if is_instance_valid(furniture):
			furniture_data.append(furniture.get_data())
	return furniture_data


# Function to load and spawn furniture from saved data
func load_furniture_from_data(furniture_data_array: Array):
	furniture_json_list = furniture_data_array  # This will automatically trigger spawning


# Internal function to spawn all furniture in the list
func _spawn_all_furniture():
	for furniture_data in furniture_json_list:
		spawn_furniture(furniture_data)


# The player has interacted with some furniture. 
# Handle the interaction if the collider is in the dictionary
# Optionally: check if pos is in the boundary of chunk.mypos + 32
func _on_player_interacted(_pos: Vector3, collider: RID) -> void:
	if collider_to_furniture.has(collider):
		var furniturenode = collider_to_furniture[collider]
		if furniturenode.has_method("interact"):
			print_debug("interacting with furniturenode")
			furniturenode.interact()


# Function to handle the event when a body enters the item detector
func _on_body_entered_item_detector(body_rid: RID) -> void:
	if collider_to_furniture.has(body_rid):
		# furniturenode is a FurnitureBlueprintSrv but we need to cast it as a Node3D here
		# because that's what the signal will send
		var furniturenode: Node3D = collider_to_furniture[body_rid]
		Helper.signal_broker.container_entered_proximity.emit(furniturenode)


# Function to handle the event when a body exits the item detector
func _on_body_exited_item_detector(body_rid: RID) -> void:
	if collider_to_furniture.has(body_rid):
		# furniturenode is a FurnitureBlueprintSrv but we need to cast it as a Node3D here
		# because that's what the signal will send
		var furniturenode: Node3D = collider_to_furniture[body_rid]
		Helper.signal_broker.container_exited_proximity.emit(furniturenode)
