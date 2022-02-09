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
		var parsed = JSON.parse(f.get_as_text())
		f.close()
		if parsed.error == OK:
			return parsed.result
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
				var extension = fn.substr(fn.find_last('.') + 1)
				if extension == "json":
					var f = File.new()
					if not f.open(dir_path + fn, File.READ) == OK:
						print_debug("Error opening file " + fn)
					else:
						var parsed = JSON.parse(f.get_as_text())
						if parsed.error == OK:
							if not parsed.result['game_name'] in games_list:
								games_list.append(parsed.result['game_name'])
						else:
							print_debug("Error parsing game file " + fn)
			fn = directory.get_next()
	
	return games_list
