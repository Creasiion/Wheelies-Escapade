# SaveManager.gd
extends Node

const SAVE_PATH := "user://save_game.cfg"


func save_game(score: int, stamina: int, wheel_index: int) -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("player", "score", score)
	cfg.set_value("player", "stamina", stamina)
	cfg.set_value("player", "wheel_index", wheel_index)
	var err = cfg.save(SAVE_PATH)
	if err != OK:
		push_error("Failed to save: %s" % err)

func load_game() -> Dictionary:
	var cfg = ConfigFile.new()
	var err = cfg.load(SAVE_PATH)
	if err != OK:
		push_warning("No save found or failed to load: %s" % err)
		return {}
	return {
		"score": cfg.get_value("player", "score", 0),
		"stamina": cfg.get_value("player", "stamina", 0),
		"wheel_index": cfg.get_value("player", "wheel_index", 0),
	}
	
func clear_save() -> void:
	# Only delete if it exists
	if FileAccess.file_exists(SAVE_PATH):
		# Open the user:// folder
		var dir = DirAccess.open("user://")
		if dir:
			dir.remove("save_game.cfg")
		else:
			push_error("Could not open user:// to clear save.")
