extends Node

func init_folders():
	var directory: = Directory.new()
	if directory.open("user://") != OK:
		print_debug("Could not open user directory")
		return
	
	if not directory.dir_exists("games"):
		directory.make_dir("games")
	if not directory.dir_exists("images"):
		directory.make_dir("images")
	if not directory.dir_exists("levels"):
		directory.make_dir("levels")
	if not directory.dir_exists("worlds"):
		directory.make_dir("worlds")

func ensure_dir_exists(dir) -> void:
	var directory = Directory.new()
	if directory.open("user://") != OK:
		print_debug("Could not open user directory")
		return
	
	if not directory.dir_exists(dir):
		directory.make_dir(dir)

func user_file_exists(file_path: String) -> bool:
	var directory: = Directory.new()
	return directory.file_exists("user://" + file_path)

func save_json(json_string, directory, file_name) -> void:
	var path = "user://" + directory + "/" + file_name + ".json"
	
	var f: = File.new()
	f.open(path, File.WRITE)
	f.store_string(json_string)
	f.close()

func get_default_game() -> String:
	var f = File.new()
	if f.open("user://default_game", File.READ) == OK:
		var ret = f.get_as_text().strip_edges()
		f.close()
		return ret
	return ""

func save_default_game(game_name) -> void:
	var f = File.new()
	if f.open("user://default_game", File.WRITE) == OK:
		f.store_string(game_name)
		f.close()

func save_game_info(game_info) -> void:
	var serialized = JSON.print(game_info)
	save_json(serialized, "games", game_file_name(game_info['game_name']))

func game_file_name(game_name) -> String:
	# TODO make this more sanitary
	var file_name:String = game_name
	file_name.replace(' ', '_')
	return file_name

func game_definition_exists(game_name) -> bool:
	var file_name = game_file_name(game_name) + ".json"
	var dir = Directory.new()
	if dir.open("user://games/") == OK:
		return dir.file_exists(file_name)
	print_debug("Could not open games directory")
	return false

func get_game_definition(game_name) -> Dictionary:
	var file_name = game_file_name(game_name) + ".json"
	var f = File.new()
	if f.open("user://games/" + file_name, File.READ) == OK:
		var result = Utility.parse_json(f.get_as_text())
		f.close()
		if result != null:
			return result
	print_debug("Error loading game: " + game_name)
	return {}

func get_games_list() -> Array:
	var directory: = Directory.new()
	
	var dir_path = "user://games/"
	
	var games_list = []
	if directory.open(dir_path) == OK:
		directory.list_dir_begin(true)
		var fn = directory.get_next()
		while fn != "":
			if not directory.current_is_dir():
				var extension = get_extension(fn)
				if extension == "json":
					var f = File.new()
					if not f.open(dir_path + fn, File.READ) == OK:
						print_debug("Error opening file " + fn)
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
	var f: = File.new()
	f.open("user://local_image_meta.json", File.WRITE)
	f.store_string(JSON.print(existing_data))
	f.close()

func get_local_image_metadata(local_image_name) -> Dictionary:
	var local_meta = _get_local_images_metadata()
	if local_meta and local_image_name in local_meta:
		return local_meta[local_image_name]
	return {}

func _get_local_images_metadata() -> Dictionary:
	var f = File.new()
	if not user_file_exists("local_image_meta.json"):
		print_debug("No local image meta")
		return {}
	if f.open("user://local_image_meta.json", File.READ) == OK:
		var result = Utility.parse_json(f.get_as_text())
		f.close()
		if result != null:
			return result
	print_debug("Error loading local image meta")
	return {}
	

func get_all_image_names() -> Array:
	var directory: = Directory.new()
	
	var dir_path = "user://images/"
	
	var images_list = []
	if directory.open(dir_path) == OK:
		directory.list_dir_begin(true)
		
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
	var ext = ""
	if fn.find_last('.') > -1:
		ext = fn.substr(fn.find_last('.') + 1)
	return ext

func save_level(game_name, level_data) -> void:
	var level_name = level_data["name"]
	var serialized = JSON.print(level_data)
	
	var levels_dir = "levels/" + game_file_name(game_name)
	ensure_dir_exists(levels_dir)
	save_json(serialized, levels_dir, game_file_name(level_name))

func get_level_data(game_name, level_name):
	var file_name = game_file_name(level_name) + ".json"
	var f = File.new()
	if f.open("user://levels/" + game_file_name(game_name) + "/" + file_name, File.READ) == OK:
		var result = Utility.parse_json(f.get_as_text())
		f.close()
		if result != null:
			return result
	print_debug("Error loading level: " + file_name)
	return {}

func get_level_list(game_name) -> Array:
	var directory: = Directory.new()
	
	var dir_path = "user://"
	dir_path += "levels/" + game_file_name(game_name) + "/"
	
	var levels_list = []
	if directory.open(dir_path) == OK:
		directory.list_dir_begin(true)
		var fn = directory.get_next()
		while fn != "":
			if not directory.current_is_dir():
				var extension = get_extension(fn)
				if extension == "json":
					var f = File.new()
					if not f.open(dir_path + fn, File.READ) == OK:
						print_debug("Error opening file " + fn)
					else:
						var result = Utility.parse_json(f.get_as_text())
						if result != null:
							if not result['name'] in levels_list:
								levels_list.append(result['name'])
						else:
							print_debug("Error parsing level file " + fn)
			fn = directory.get_next()
	
	return levels_list
