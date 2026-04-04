extends Node

var FORMAT_GAME_JSON: = true
var SORT_JSON_KEYS: = false

var GAME_DEF_FILENAME: = "game_definition.json"

var base_data_directory: = "user://"
var games_subdir: = "games"
var shared_assets_subdir: = "shared_assets"
var local_data_subdir: = "player"

var images_asset_subdir: = "images"
var audio_asset_subdir: = "audio"

var game_dir_default_structure: = {
	"game_data": {
		"assets": {
			"images": {},
			"audio": {},
		},
		"levels": {},
		"worlds": {},
	},
	"other_versions": {},
}

func ___MIGRATION_quick_dir_copy(from_global_path: String, to_global_path: String) -> int:
	if not DirAccess.dir_exists_absolute(to_global_path):
		var error := DirAccess.make_dir_recursive_absolute(to_global_path)
		if error != OK:
			push_error("Failed to create destination directory: %s" % to_global_path)
			return error

	var output: Array = []
	var command_return_code := -1

	match OS.get_name():
		"Windows":
			var robocopy: = OS.get_environment("WINDIR").path_join("System32").path_join("robocopy.exe")

			command_return_code = OS.execute(
				robocopy,
				[from_global_path, to_global_path, "/E", "/R:0", "/W:0"],
				output,
				true
			)

			if command_return_code < 0 or command_return_code > 7:
				push_error("robocopy failed (%s)\n%s" % [command_return_code, "\n".join(output)])
				return FAILED
			return OK
		"Linux", "macOS":
			command_return_code = OS.execute(
				"cp",
				# if you cp -R src/. dst instead of cp -R src dst, it will not copy the whole src directory into the dst if it already exists, instead merging as expected
				["-R", from_global_path.path_join("."), to_global_path],
				output,
				true
			)

			if command_return_code != 0:
				push_error("cp failed (%s)\n%s" % [command_return_code, "\n".join(output)])
				return FAILED
			return OK
		_:
			push_error("Unsupported OS: %s" % [OS.get_name()])
			return FAILED

func init_folders():
	_do_game_data_migration()
	ensure_data_dir_exists(games_subdir)
	ensure_data_dir_exists(shared_assets_subdir)
	ensure_data_dir_exists(shared_assets_subdir, images_asset_subdir)

	ensure_data_dir_exists(local_data_subdir)

func _do_game_data_migration() -> void:
	var old_data_subdir: = "godot/app_userdata/TileGameEngineRedux"
	var old_data_dir: = OS.get_data_dir().path_join(old_data_subdir)
	if DirAccess.dir_exists_absolute(old_data_dir):
		var new_user_data_dir: = ProjectSettings.globalize_path(OS.get_user_data_dir())
		print_debug("Found user data in TileGameEngineRedux, moving to %s" % [new_user_data_dir])
		var error: = ___MIGRATION_quick_dir_copy(old_data_dir, new_user_data_dir)
		if error != OK:
			push_error("Failed to copy user data folder to new location: %s" % [error_string(error)])
			get_tree().quit()
			return
		var remove_old_data_dir_success: = DirAccess.remove_absolute(old_data_dir)
		if remove_old_data_dir_success != OK:
			push_error("Failed to remove old user data folder: %s" % [error_string(remove_old_data_dir_success)])
			get_tree().quit()
			return

	print_debug("Checking for game data migration, looking for %s" % [_data_path(games_subdir, "please_migrate")])
	if not FileAccess.file_exists(_data_path(games_subdir, "please_migrate")):
		return
	print_debug("Starting migration of old game data directory structure...")
	var from_games_dir_path: = _data_path(games_subdir)
	var games_to_migrate: Array[String] = []
	for game_filename in iterate_directory_flat_filelist(from_games_dir_path, "json"):
		games_to_migrate.append(game_filename.get_basename())
	
	print_debug("Attempting to migrate %d games" % [games_to_migrate.size()])
	for game_name in games_to_migrate:
		var migrate_game_success: = _migrate_game(game_name)
		if not migrate_game_success:
			push_error("Error migrating game %s" % [game_name])
			get_tree().quit()
			return
	
	var image_migration_success: = _migrate_shared_images()
	if not image_migration_success:
		push_error("Error migrating shared images")
		get_tree().quit()
		return

	print_debug("Migration of old game data directory structure completed successfully")
	var success: = DirAccess.remove_absolute(_data_path(games_subdir, "please_migrate"))
	if success != OK:
		push_error("Failed to remove migration trigger file: %s" % [error_string(success)])
		get_tree().quit()
		return

func _migrate_game(game_file_basename: String) -> bool:
	var original_definition_path: = _data_path(games_subdir, game_file_basename + ".json")
	var game_data: Dictionary = _get_dict_from_json_file(original_definition_path)
	var game_internal_name: String = game_data['game_name']
	
	var new_game_dir_name: = get_game_dir_from_name(game_internal_name)
	var game_dir: String = games_subdir.path_join(new_game_dir_name)
	if FileAccess.file_exists(_data_path(game_dir)) or DirAccess.dir_exists_absolute(_data_path(game_dir)):
		push_error("Game directory for %s already exists: " % [game_internal_name])
		return false
	
	create_game_directory_if_not_exists(game_data)
	DirAccess.copy_absolute(original_definition_path, _data_path(game_dir, GAME_DEF_FILENAME))
	
	var old_levels_dir: = _data_path("levels", game_file_basename)
	var new_levels_dir: = get_game_levels_dir(game_internal_name)
	if DirAccess.dir_exists_absolute(old_levels_dir):
		print_debug("Migrating levels from %s to %s" % [old_levels_dir, new_levels_dir])
		for level_file_name in iterate_directory_flat_filelist(old_levels_dir, "json"):
			var abs_from: = ProjectSettings.globalize_path(old_levels_dir.path_join(level_file_name))
			var abs_to: = ProjectSettings.globalize_path(new_levels_dir.path_join(level_file_name))
			var error: = DirAccess.copy_absolute(abs_from, abs_to)
			if error != OK:
				push_error("Error copying level file %s to %s: %s" % [abs_from, abs_to, error_string(error)])
				if not FileAccess.file_exists(abs_from):
					print_debug("Level file copy source %s does not exist" % [abs_from])
				if not FileAccess.file_exists(abs_to):
					print_debug("copied file does not exist: %s" % [abs_to])
				return false
			var remove_lvl_success: = DirAccess.remove_absolute(old_levels_dir.path_join(level_file_name))
			if remove_lvl_success != OK:
				push_error("Failed to remove old level file: %s" % [error_string(remove_lvl_success)])
				return false
		
		var success: = DirAccess.remove_absolute(old_levels_dir)
		if success != OK:
			push_error("Failed to remove old levels directory: %s" % [error_string(success)])
			return false
	var success2: = DirAccess.remove_absolute(original_definition_path)
	if success2 != OK:
		push_error("Failed to remove old game definition file: %s" % [error_string(success2)])
		return false
	
	return true

func _migrate_shared_images() -> bool:
	var old_shared_images_dir: = _data_path("images")
	if not DirAccess.dir_exists_absolute(old_shared_images_dir):
		return true
	var new_shared_images_dir: = get_shared_images_dir()
	var image_file_names: = iterate_directory_flat_filelist(old_shared_images_dir, "png")
	if image_file_names.is_empty():
		return true
	print_debug("Attempting to migrate %d shared images" % [image_file_names.size()])
	for image_file_name in iterate_directory_flat_filelist(old_shared_images_dir, "png"):
		var from: = old_shared_images_dir.path_join(image_file_name)
		var to: = new_shared_images_dir.path_join(image_file_name)
		var error: = DirAccess.copy_absolute(from, to)
		if error != OK:
			push_error("Error copying image file %s to %s: %s" % [from, to, error_string(error)])
			return false
		DirAccess.remove_absolute(from)
	DirAccess.remove_absolute(old_shared_images_dir)
	return true



func _data_path(...path_parts: Array) -> String:
	return _data_path_from_arr(path_parts)

func _data_path_from_arr(path_parts: Array) -> String:
	var final_path: = base_data_directory
	for path_part in path_parts:
		if typeof(path_part) == TYPE_STRING:
			final_path = final_path.path_join(path_part)
	return final_path

func get_game_base_dir(game_name: String) -> String:
	return _data_path(games_subdir, get_game_dir_from_name(game_name))
func get_game_gamedata_dir(game_name: String) -> String:
	return get_game_base_dir(game_name).path_join("game_data")

func get_game_definition_path(game_name: String) -> String:
	return get_game_base_dir(game_name).path_join(GAME_DEF_FILENAME)

func get_game_levels_dir(game_name: String) -> String:
	return get_game_gamedata_dir(game_name).path_join("levels")

func get_game_assets_dir(game_name: String) -> String:
	return get_game_gamedata_dir(game_name).path_join("assets")


func get_shared_images_dir() -> String:
	return _data_path(shared_assets_subdir, images_asset_subdir)

func get_games_dir() -> String:
	return _data_path(games_subdir)


func ensure_data_dir_exists(...path_parts: Array) -> bool:
	if not DirAccess.dir_exists_absolute(_data_path_from_arr(path_parts)):
		DirAccess.make_dir_absolute(_data_path_from_arr(path_parts))
		return true
	return false

func ensure_dir_exists_absolute(abs_path: String) -> bool:
	if not DirAccess.dir_exists_absolute(abs_path):
		DirAccess.make_dir_absolute(abs_path)
	return true

func _serialize_dict_to_json_string(data: Dictionary, with_formatting: bool = false) -> String:
	var serialized: = JSON.stringify(data, "  " if with_formatting else "", SORT_JSON_KEYS)
	if not serialized:
		push_error("Error serializing data to JSON. Data: %s" % [data])
		return ""
	return serialized

func serialize_and_save_data_to_json(data: Dictionary, directory: String, file_name: String, with_formatting: bool = false) -> void:
	var serialized_json_string: = _serialize_dict_to_json_string(data, with_formatting)
	if serialized_json_string:
		_save_json_string_absolute(serialized_json_string, directory, file_name)

func _save_json_in_data_dir_path(json_string: String, directory: String, file_name: String) -> void:
	# just in case sanitization
	file_name = Utility.sanitize_for_filename(file_name.trim_suffix(".json")) + ".json"
	var save_to_path = _data_path(directory, file_name)
	_save_file(json_string, save_to_path)

func _save_json_string_absolute(json_string: String, abs_directory: String, file_name: String) -> void:
	# just in case sanitization
	file_name = Utility.sanitize_for_filename(file_name.trim_suffix(".json")) + ".json"
	var save_to_path = abs_directory.path_join(file_name)
	_save_file(json_string, save_to_path)

func _save_file(file_data: String, abs_file_path: String) -> void:
	var f: = FileAccess.open(abs_file_path, FileAccess.WRITE)
	if not f:
		push_error("Error saving to file. file path: %s" % [abs_file_path])
		return
	f.store_string(file_data)

func get_default_game() -> String:
	var f = FileAccess.open(_data_path("default_game"), FileAccess.READ)
	if f:
		return f.get_as_text().strip_edges()
	return ""

func save_default_game(game_name) -> void:
	var f = FileAccess.open(_data_path("default_game"), FileAccess.WRITE)
	if f:
		f.store_string(game_name)
	else:
		push_error("Error saving default game. file path: %s" % [_data_path("default_game")])

func save_game_info(game_info: Dictionary) -> void:
	create_game_directory_if_not_exists(game_info)
	var game_dir: = get_game_base_dir(game_info['game_name'])
	serialize_and_save_data_to_json(game_info, game_dir, GAME_DEF_FILENAME, FORMAT_GAME_JSON)

func create_game_directory_if_not_exists(game_info: Dictionary) -> void:
	var game_data_path: = get_game_base_dir(game_info['game_name'])
	if not ensure_dir_exists_absolute(game_data_path):
		return
	_create_directories_recursively(game_data_path, game_dir_default_structure)

func _create_directories_recursively(base_path: String, directory_structure: Dictionary) -> void:
	for key in directory_structure:
		var dir_path = base_path.path_join(key)
		if not DirAccess.dir_exists_absolute(dir_path):
			DirAccess.make_dir_absolute(dir_path)
		
		if typeof(directory_structure[key]) == TYPE_DICTIONARY and not directory_structure[key].is_empty():
			_create_directories_recursively(dir_path, directory_structure[key])

func get_game_dir_from_name(game_name: String) -> String:
	return Utility.sanitize_for_filename(game_name)

func game_exists(game_name: String) -> bool:
	if not game_name:
		return false
	if not DirAccess.dir_exists_absolute(get_game_base_dir(game_name)):
		return false
	return FileAccess.file_exists(get_game_definition_path(game_name))

func _get_dict_from_json_file(file_path: String) -> Dictionary:
	var f = FileAccess.open(file_path, FileAccess.READ)
	if not f:
		push_error("Error loading file: " + file_path)
		return {}
	var result = Utility.parse_json(f.get_as_text())
	if result == null:
		push_error("Error parsing game file: " + file_path)
		return {}
	if not typeof(result) == TYPE_DICTIONARY:
		push_error("Error: File is not a dictionary as expected: " + file_path)
		return {}
	return result

func get_game_definition(game_name: String) -> Dictionary:
	if not game_exists(game_name):
		push_error("Game %s does not exist" % [game_name])
		return {}
	var file_name = get_game_definition_path(game_name)
	return _get_dict_from_json_file(file_name)

func iterate_directory_flat_dirlist(directory_path: String) -> Array:
	return _iter_directory_flat_filtered(directory_path, [], false, true)

func iterate_directory_flat_filelist(directory_path: String, extension_filter: String = "", more_filters: Array = []) -> Array:
	var filters: Array[String] = []
	if extension_filter:
		filters.append(extension_filter)
	filters.append_array(more_filters)

	return _iter_directory_flat_filtered(directory_path, filters)

func _iter_directory_flat_filtered(directory_path: String, ext_filters: Array[String], include_files: bool = true, include_dirs: bool = false, dirs_include_slash: bool = false) -> Array:
	var directory: = DirAccess.open(directory_path)
	if not directory:
		push_error("Error opening directory: " + directory_path)
		return []
	
	var filename_list: Array = []
	directory.list_dir_begin()
	var cur_filename: String = "-"
	while cur_filename != "":
		cur_filename = directory.get_next()
		if not cur_filename:
			break
		if directory.current_is_dir():
			if not include_dirs:
				continue
			if dirs_include_slash:
				cur_filename += "/"
		elif not include_files:
			continue
		if ext_filters:
			if not cur_filename.get_extension() or cur_filename.get_extension() not in ext_filters:
				continue

		filename_list.append(cur_filename)
	return filename_list

# NOTE: No caching here, proper game names need to be parsed from game definition files
func get_games_list() -> Array:
	var games_list: Array = []
	for game_definition in _get_all_game_definitions():
		games_list.append(game_definition['game_name'])
	return games_list

func get_game_definitions_by_name() -> Dictionary[String, Dictionary]:
	var game_defs_by_name: Dictionary[String, Dictionary] = {}
	for game_definition in _get_all_game_definitions():
		if game_definition['game_name'] in game_defs_by_name:
			push_warning("Game name %s is duplicated" % [game_definition['game_name']])
			continue
		game_defs_by_name[game_definition['game_name']] = game_definition
	return game_defs_by_name

func _get_all_game_definitions() -> Array[Dictionary]:
	var games_directory: = _data_path(games_subdir)
	var game_definitions: Array[Dictionary] = []
	for game_dir in iterate_directory_flat_dirlist(games_directory):
		var definition_path: = _data_path(games_subdir, game_dir, GAME_DEF_FILENAME)
		if not FileAccess.file_exists(definition_path):
			push_warning("Game definition file not found at game directory: " + definition_path)
			continue
		var game_definition: = _get_dict_from_json_file(definition_path)
		if game_definition:
			game_definitions.append(game_definition)
		else:
			push_error("Error parsing game definition at file: " + definition_path)
	return game_definitions

# NOTE leaving local images metadata file in place for now, should be moved probably, more likely refactored
func update_local_image_metadata(local_image_name: String, data: Dictionary, for_game_name: String = "") -> void:
	if for_game_name:
		push_error("Images specific to games not supported yet")
		return
	var existing_data = _get_local_images_metadata()
	existing_data[local_image_name] = Utility.dict_vectors_to_lists(data)
	var f: = FileAccess.open(_data_path("local_image_meta.json"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(existing_data))

func get_local_image_metadata(local_image_name: String, for_game_name: String = "") -> Dictionary:
	if for_game_name:
		push_error("Images specific to games not supported yet")
		return {}
	var local_meta = _get_local_images_metadata()
	if local_meta and local_image_name in local_meta:
		return local_meta[local_image_name]
	return {}

func _get_local_images_metadata() -> Dictionary:
	if not FileAccess.file_exists(_data_path("local_image_meta.json")):
		print_debug("No local image meta")
		return {}
	return _get_dict_from_json_file(_data_path("local_image_meta.json"))

func get_all_image_names() -> Array:
	var images_directory: = get_shared_images_dir()
	return iterate_directory_flat_filelist(images_directory, "png")

func _sanitize_image_filename(image_filename: String) -> String:
	var extension: = "." + image_filename.get_extension()
	var just_filename: = image_filename.trim_suffix(extension)
	return Utility.sanitize_for_filename(just_filename, true) + extension

func save_shared_image(image_to_save: Image, as_name: String) -> void:
	var img_filename: = _sanitize_image_filename(as_name)
	var img_path: = get_shared_images_dir().path_join(img_filename)
	var save_success: = image_to_save.save_png(img_path)
	if save_success != OK:
		push_error("Error saving shared image %s to %s: %s" % [as_name, img_path, error_string(save_success)])
		return

func save_image_to_path(image_to_save: Image, abs_path: String) -> void:
	var base_dir: = abs_path.get_base_dir()
	var filename: = _sanitize_image_filename(abs_path.get_file())
	var save_success: = image_to_save.save_png(base_dir.path_join(filename))
	if save_success != OK:
		push_error("Error saving image to %s: %s" % [base_dir.path_join(filename), error_string(save_success)])
		return

func load_shared_image_as_texture(image_name: String) -> Texture:
	return load_file_as_texture(get_shared_images_dir().path_join(image_name))

func load_file_as_texture(file_path: String) -> Texture:
	if not FileAccess.file_exists(file_path):
		push_error("File %s does not exist" % [file_path])
		return null
	var loaded_img: = Image.load_from_file(file_path)
	return ImageTexture.create_from_image(loaded_img)

func _level_filename(level_name: String) -> String:
	return Utility.sanitize_for_filename(level_name) + ".json"

func save_level(game_name: String, level_data: Dictionary) -> void:
	if not game_exists(game_name):
		push_error("Game %s does not exist" % [game_name])
		return
	if not level_data.get("name", ""):
		push_error("Level data does not contain a name" % [game_name])
		return
	var level_filename: = _level_filename(level_data["name"])
	serialize_and_save_data_to_json(level_data, get_game_levels_dir(game_name), level_filename)

func level_exists(game_name: String, level_name: String) -> bool:
	if not level_name or not game_exists(game_name):
		push_error("Invalid game or level name: %s, %s" % [game_name, level_name])
		return false
	var level_filename: = _level_filename(level_name)
	return FileAccess.file_exists(get_game_levels_dir(game_name).path_join(level_filename))

func get_level_data(game_name: String, level_name: String) -> Dictionary:
	if not level_name or not game_exists(game_name):
		push_error("Invalid game or level name: %s, %s" % [game_name, level_name])
		return {}
	var level_filename: = _level_filename(level_name)
	return _get_dict_from_json_file(get_game_levels_dir(game_name).path_join(level_filename))

func get_level_list(game_name: String) -> Array:
	if not game_exists(game_name):
		push_error("Game %s does not exist" % [game_name])
		return []
	var level_names: Array = []
	for level_filename in iterate_directory_flat_filelist(get_game_levels_dir(game_name), "json"):
		level_names.append(level_filename.get_basename())
	return level_names