extends Node

func init_folders():
	ensure_dir_exists("games")
	ensure_dir_exists("images")
	ensure_dir_exists("levels")
	ensure_dir_exists("worlds")

func ensure_dir_exists(dir) -> void:
	if not DirAccess.dir_exists_absolute("user://" + dir):
		DirAccess.make_dir_absolute("user://" + dir)

func user_file_exists(file_path: String) -> bool:
	return FileAccess.file_exists("user://" + file_path)

func save_json(json_string, directory, file_name) -> void:
	var path = "user://" + directory + "/" + file_name + ".json"
	
	var f: = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(json_string)

func get_default_game() -> String:
	var f = FileAccess.open("user://default_game", FileAccess.READ)
	if f:
		var ret = f.get_as_text().strip_edges()
		return ret
	return ""

func save_default_game(game_name) -> void:
	var f = FileAccess.open("user://default_game", FileAccess.WRITE)
	if f:
		f.store_string(game_name)

func save_game_info(game_info) -> void:
	var serialized = JSON.stringify(game_info)
	save_json(serialized, "games", game_file_name(game_info['game_name']))

func game_file_name(game_name) -> String:
	# TODO make this more sanitary
	var file_name:String = game_name
	file_name.replace(' ', '_')
	return file_name

func game_definition_exists(game_name) -> bool:
	var file_name = game_file_name(game_name) + ".json"
	if not DirAccess.dir_exists_absolute("user://games/"):
		print_debug("Could not open games directory")
		return false
	return FileAccess.file_exists("user://games/" + file_name)

func get_game_definition(game_name) -> Dictionary:
	var file_name = game_file_name(game_name) + ".json"
	var f = FileAccess.open("user://games/" + file_name, FileAccess.READ)
	if not f:
		print_debug("Error loading game: " + game_name)
		return {}
	var result = Utility.parse_json(f.get_as_text())
	return result

func get_games_list() -> Array:
	var directory: = DirAccess.open("user://games/")
	if not directory:
		print_debug("Error loading games list")
		return []
	
	var games_list = []
	directory.list_dir_begin()
	var fn = directory.get_next()
	while fn != "":
		if not directory.current_is_dir():
			var extension = get_extension(fn)
			if extension == "json":
				var f = FileAccess.open("user://games/" + fn, FileAccess.READ)
				if not f:
					print_debug("Game list: Error opening file " + fn)
				else:
					var result = Utility.parse_json(f.get_as_text())
					if result != null:
						if not result['game_name'] in games_list:
							games_list.append(result['game_name'])
					else:
						print_debug("Error parsing game file " + fn)
		fn = directory.get_next()
	
	return games_list

func update_local_image_metadata(local_image_name, data) -> void:
	var existing_data = _get_local_images_metadata()
	existing_data[local_image_name] = Utility.dict_vectors_to_lists(data)
	var f: = FileAccess.open("user://local_image_meta.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(existing_data))

func get_local_image_metadata(local_image_name) -> Dictionary:
	var local_meta = _get_local_images_metadata()
	if local_meta and local_image_name in local_meta:
		return local_meta[local_image_name]
	return {}

func _get_local_images_metadata() -> Dictionary:
	if not FileAccess.file_exists("user://local_image_meta.json"):
		print_debug("No local image meta")
		return {}
	var f = FileAccess.open("user://local_image_meta.json", FileAccess.READ)
	if not f:
		print_debug("Error loading local image meta")
		return {}
	var result = Utility.parse_json(f.get_as_text())
	if result != null:
		return result
	return {}
	

func get_all_image_names() -> Array:
	if not DirAccess.dir_exists_absolute("user://images/"):
		print_debug("Could not open images directory")
		return []
	var directory: = DirAccess.open("user://images/")
	if not directory:
		print_debug("Error loading images list")
		return []
	
	var images_list = []
	directory.list_dir_begin()
	
	var first = true
	var fn = directory.get_next()
	while fn != "":
		if first:
			first = false
		else:
			fn = directory.get_next()
		
		if directory.current_is_dir():
			continue
		
		var extension = get_extension(fn)
		if extension == "png":
			images_list.append(fn)
	
	return images_list

func get_extension(fn: String) -> String:
	return fn.get_extension()

func save_level(game_name, level_data) -> void:
	var level_name = level_data["name"]
	var serialized = JSON.stringify(level_data)
	
	var levels_dir = "levels/" + game_file_name(game_name)
	ensure_dir_exists(levels_dir)
	save_json(serialized, levels_dir, game_file_name(level_name))

func get_level_data(game_name, level_name):
	var file_name = game_file_name(level_name) + ".json"
	var f = FileAccess.open("user://levels/" + game_file_name(game_name) + "/" + file_name, FileAccess.READ)
	if not f:
		print_debug("Error loading level: " + file_name)
		return {}
	var result = Utility.parse_json(f.get_as_text())
	if result != null:
		return result
	return {}

func get_level_list(game_name) -> Array:
	var dir_path = "user://"
	dir_path += "levels/" + game_file_name(game_name) + "/"
	if not DirAccess.dir_exists_absolute(dir_path):
		print_debug("Could not open levels directory")
		return []
	var directory: = DirAccess.open(dir_path)
	if not directory:
		print_debug("Error loading levels list")
		return []
	
	var levels_list = []
	directory.list_dir_begin()
	var fn = " "
	while fn != "":
		fn = directory.get_next()
		if fn == "":
			break
		
		if directory.current_is_dir():
			continue
		var extension = get_extension(fn)
		if extension == "json":
			var f = FileAccess.open(dir_path + fn, FileAccess.READ)
			if not f:
				print_debug("Error opening file " + fn)
			else:
				var result = Utility.parse_json(f.get_as_text())
				if result != null:
					if not result['name'] in levels_list:
						levels_list.append(result['name'])
				else:
					print_debug("Error parsing level file " + fn)
	
	return levels_list
