class_name DMobgroup
extends RefCounted


# There's a D in front of the class name to indicate this class only handles mob data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the data for one mobgroup. You can access it through Gamedata.mobgroups


# Represents a mob group and its properties.
# This script is used for handling mob group data within the GameData autoload singleton.
# Example mob group JSON:
# {
# 	"id": "basic_zombies",
# 	"name": "Basic zombies",
# 	"description": "The default, basic zombies posing a low threat to the player",
# 	"spriteid": "scrapwalker64.png",
# 	"references": {
# 		"core": {
# 			"maps": [
# 				"Generichouse",
# 				"store_electronic_clothing"
# 			]
# 		}
# 	},
# 	"mobs": {
# 		"basic_zombie_1": 100,
# 		"basic_zombie_2": 100,
# 		"limping_zombie": 25,
# 		"fast_zombie": 10,
# 		"heavy_zombie": 25
# 	}
# }

# Properties defined in the JSON structure
var id: String
var name: String
var description: String
var spriteid: String
var sprite: Texture
var references: Dictionary = {}
var mobs: Dictionary = {}  # Holds the list of mobs and their weights

# Constructor to initialize mob group properties from a dictionary
func _init(data: Dictionary):
	id = data.get("id", "")
	name = data.get("name", "")
	description = data.get("description", "")
	spriteid = data.get("spriteid", "")
	references = data.get("references", {})
	mobs = data.get("mobs", {})


# Returns all properties of the mob group as a dictionary
func get_data() -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"name": name,
		"description": description,
		"spriteid": spriteid,
		"mobs": mobs
	}
	if not references.is_empty():
		data["references"] = references
	return data


# Method to save any changes to the stat back to disk
func save_to_disk():
	Gamedata.stats.save_stats_to_disk()


# Removes the specified reference from the mob group's references
func remove_reference(module: String, type: String, refid: String):
	var changes_made = Gamedata.dremove_reference(references, module, type, refid)
	if changes_made:
		Gamedata.mobgroups.save_mobgroups_to_disk()

# Adds a new reference to the mob group's references
func add_reference(module: String, type: String, refid: String):
	var changes_made = Gamedata.dadd_reference(references, module, type, refid)
	if changes_made:
		Gamedata.mobgroups.save_mobgroups_to_disk()

# Handles changes to the mob group, such as updating references
func changed(olddata: DMobgroup):
	update_mob_references(olddata)
	Gamedata.mobgroups.save_mobgroups_to_disk()

# Updates references to mobs within the mob group
func update_mob_references(olddata: DMobgroup):
	var old_mobs = olddata.mobs.keys()
	var new_mobs = mobs.keys()

	# Remove old references not present in the new data
	for old_mob in old_mobs:
		if not new_mobs.has(old_mob):
			Gamedata.mobs.remove_reference(old_mob, "core", "mobgroups", id)

	# Add new references
	for new_mob in new_mobs:
		Gamedata.mobs.add_reference(new_mob, "core", "mobgroups", id)

# Deletes the mob group, removing all its references
func delete():
	# Remove references to maps
	var mapsdata: Array = Helper.json_helper.get_nested_data(references, "core.maps")
	if mapsdata:
		Gamedata.maps.remove_entity_from_selected_maps("mobgroup", id, mapsdata)

	# Remove references to mobs
	for mob in mobs.keys():
		Gamedata.mobs.remove_reference(mob, "core", "mobgroups", id)

# Retrieves all maps associated with the mob group, including maps from its mobs.
func get_maps() -> Array:
	var unique_maps: Array = []

	# Collect maps from each mob in the group
	for mob_id in mobs.keys():
		var mob = Gamedata.mobs.by_id(mob_id)
		if mob:
			unique_maps = Helper.json_helper.merge_unique(unique_maps, mob.get_maps())
	return unique_maps


# Function to return an array of all mob IDs in the "mobs" property
func get_mob_ids() -> Array[String]:
	var mob_ids: Array[String] = []
	for mob_id in mobs.keys():
		mob_ids.append(mob_id)
	return mob_ids


# Function to check if a specific mob ID exists in the "mobs" property
func has_mob(mob_id: String) -> bool:
	return mobs.has(mob_id)