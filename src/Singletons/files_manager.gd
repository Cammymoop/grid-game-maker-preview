extends Node

var FORMAT_GAME_JSON: = true
var SORT_JSON_KEYS: = false

var GAME_DEF_FILENAME: = "game_definition.json"

var TEMPORARY_FILE_PREFIX: = "_tmp_"

var PLAYER_SETTINGS_FILENAME: = "player_settings.json"

var SHARED_IMAGES_METADATA_FILENAME: = "local_image_meta.json"
var BUNDLED_IMAGE_METADATA_FILENAME: = "image_metadata.json"

var base_data_directory: = "user://"
var games_subdir: = "games"
var shared_assets_subdir: = "shared_assets"
var local_data_subdir: = "player"

var game_saves_local_subdir: = "game_saves"

var images_asset_subdir: = "images"
var audio_asset_subdir: = "audio"

var auto_import_all_example_games_if_first_run: = true

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

func init_folders():
	var games_dir_created: = ensure_data_dir_exists(games_subdir)
	ensure_data_dir_exists(shared_assets_subdir)
	ensure_data_dir_exists(shared_assets_subdir, images_asset_subdir)

	ensure_data_dir_exists(local_data_subdir)

	if auto_import_all_example_games_if_first_run and games_dir_created:
		import_all_example_games()
		var games_list: = get_games_list()
		if games_list:
			var new_default_game: String = "Basic" if "Basic" in games_list else games_list[0]
			save_default_game(new_default_game)

func ___clear_local_data() -> void:
	var recursive_delete: = func(dir_path: String, recurse: Callable) -> void:
		for subdirectory in DirAccess.get_directories_at(dir_path):
			recurse.call(dir_path.path_join(subdirectory), recurse)
		for file_name in DirAccess.get_files_at(dir_path):
			DirAccess.remove_absolute(dir_path.path_join(file_name))
	for data_dir in [games_subdir, shared_assets_subdir, local_data_subdir]:
		var data_dir_path: = _data_path(data_dir)
		if not smarter_dir_exists(data_dir_path):
			continue
		recursive_delete.call(data_dir_path, recursive_delete)
	DirAccess.remove_absolute(_data_path("default_game"))
	auto_import_all_example_games_if_first_run = false
	init_folders()


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

func get_game_images_dir(game_name: String) -> String:
	return get_game_assets_dir(game_name).path_join("images")


func get_shared_images_dir() -> String:
	return _data_path(shared_assets_subdir, images_asset_subdir)

func get_games_dir() -> String:
	return _data_path(games_subdir)


func ensure_data_dir_exists(...path_parts: Array) -> bool:
	if not smarter_dir_exists(_data_path_from_arr(path_parts)):
		smarter_make_dir_absolute(_data_path_from_arr(path_parts))
		return true
	return false

func ensure_dir_exists_absolute(abs_path: String) -> bool:
	if not smarter_dir_exists(abs_path):
		smarter_make_dir_absolute(abs_path)
	return true

func _serialize_dict_to_json_string(data: Dictionary, with_formatting: bool = false) -> String:
	var serialized: = JSON.stringify(data, "  " if with_formatting else "", SORT_JSON_KEYS)
	if not serialized:
		push_error("Error serializing data to JSON. Data: %s" % [data])
		return ""
	return serialized

func serialize_and_save_data_to_json(data: Dictionary, directory: String, file_name: String, with_formatting: bool = false) -> bool:
	var serialized_json_string: = _serialize_dict_to_json_string(data, with_formatting)
	if serialized_json_string:
		return _save_json_string_absolute(serialized_json_string, directory, file_name)
	else:
		return false

func _save_json_in_data_dir_path(json_string: String, directory: String, file_name: String) -> void:
	# just in case sanitization
	file_name = Utility.sanitize_for_filename(file_name.trim_suffix(".json"), true, true) + ".json"
	var save_to_path = _data_path(directory, file_name)
	_save_file(json_string, save_to_path)

func _save_json_string_absolute(json_string: String, abs_directory: String, file_name: String) -> bool:
	# just in case sanitization
	file_name = Utility.sanitize_for_filename(file_name.trim_suffix(".json"), true, true) + ".json"
	var save_to_path = abs_directory.path_join(file_name)
	return _save_file(json_string, save_to_path)

func _save_file(file_data: String, abs_file_path: String) -> bool:
	var f: = FileAccess.open(abs_file_path, FileAccess.WRITE)
	if not f:
		push_error("Error saving to file. file path: %s" % [abs_file_path])
		return false
	var success: = f.store_string(file_data)
	if not success:
		push_error("Error saving to file. file path: %s" % [abs_file_path])
	return success


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
	if not game_info.get('game_name', ''):
		push_error("Game info does not contain a game name")
		return
	create_game_directory_if_not_exists(game_info['game_name'])
	var game_dir: = get_game_base_dir(game_info['game_name'])
	return serialize_and_save_data_to_json(game_info, game_dir, GAME_DEF_FILENAME, FORMAT_GAME_JSON)

func create_game_directory_if_not_exists(game_name: String) -> void:
	var game_data_path: = get_game_base_dir(game_name)
	if not ensure_dir_exists_absolute(game_data_path):
		return
	_create_directories_recursively(game_data_path, game_dir_default_structure)

func _create_directories_recursively(base_path: String, directory_structure: Dictionary) -> void:
	for key in directory_structure:
		var dir_path = base_path.path_join(key)
		if not smarter_dir_exists(dir_path):
			smarter_make_dir_absolute(dir_path)
		
		if typeof(directory_structure[key]) == TYPE_DICTIONARY and not directory_structure[key].is_empty():
			_create_directories_recursively(dir_path, directory_structure[key])

func get_game_dir_from_name(game_name: String) -> String:
	return Utility.sanitize_for_filename(game_name)

func game_exists(game_name: String) -> bool:
	if not game_name:
		return false
	if not smarter_dir_exists(get_game_base_dir(game_name)):
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

func get_level_file_bytes(game_name: String, level_name: String) -> PackedByteArray:
	if not level_name or not game_exists(game_name):
		push_error("Invalid game or level name: %s, %s" % [game_name, level_name])
		return PackedByteArray()
	var level_filename: = _level_filename(level_name)
	var level_file_path: = get_game_levels_dir(game_name).path_join(level_filename)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(level_file_path)
	if FileAccess.get_open_error() != OK:
		push_error("Error opening level file: " + level_file_path)
		return PackedByteArray()
	return bytes


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

func get_game_list_with_titles() -> Array:
	var games_list: Array[Dictionary] = []
	for game_definition in _get_all_game_definitions():
		games_list.append({
			'game_name': game_definition['game_name'],
			'game_title': game_definition.get('game_settings', {}).get('title', game_definition['game_name']),
		})
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

func update_local_image_metadata(local_image_name: String, data: Dictionary, for_game_name: String = "") -> void:
	var local_images_meta = _get_local_images_metadata(for_game_name)
	local_images_meta[local_image_name] = Utility.dict_vectors_to_lists(data)
	_save_local_images_metadata(local_images_meta, for_game_name)

func _save_local_images_metadata(new_data: Dictionary, for_game_name: String = "") -> void:
	var meta_file_path: String = _data_path(SHARED_IMAGES_METADATA_FILENAME)
	if for_game_name:
		if not game_exists(for_game_name):
			return
		meta_file_path = get_game_images_dir(for_game_name).path_join(BUNDLED_IMAGE_METADATA_FILENAME)
	var f: = FileAccess.open(meta_file_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(new_data))

func get_local_image_metadata(local_image_name: String, for_game_name: String = "") -> Dictionary:
	var local_meta = _get_local_images_metadata(for_game_name)
	if local_meta and local_image_name in local_meta:
		return local_meta[local_image_name]
	return {}

func has_local_image_metadata(local_image_name: String, for_game_name: String = "") -> bool:
	var local_meta = _get_local_images_metadata(for_game_name)
	if not local_meta or not local_image_name in local_meta:
		return false
	return true

func _get_local_images_metadata(for_game_name: String = "") -> Dictionary:
	var meta_file_path: String = _data_path(SHARED_IMAGES_METADATA_FILENAME)
	if not for_game_name:
		if not FileAccess.file_exists(_data_path(SHARED_IMAGES_METADATA_FILENAME)):
			return {}
	else:
		if not game_exists(for_game_name):
			return {}
		meta_file_path = get_game_images_dir(for_game_name).path_join(BUNDLED_IMAGE_METADATA_FILENAME)
		if not smarter_file_exists(meta_file_path):
			return {}
	return _get_dict_from_json_file(meta_file_path)


func get_all_shared_image_names() -> Array:
	var images_directory: = get_shared_images_dir()
	return iterate_directory_flat_filelist(images_directory, "png")

func get_all_bundled_image_names(game_name: String) -> Array:
	if not game_exists(game_name):
		push_error("Game %s does not exist" % [game_name])
		return []
	var images_directory: = get_game_images_dir(game_name)
	return iterate_directory_flat_filelist(images_directory, "png")

func _sanitize_image_filename(image_filename: String) -> String:
	return Utility.sanitize_for_filename(image_filename, true, true)

func save_local_image(image_to_save: Image, image_filename: String, to_game_name: String = "") -> bool:
	image_filename = _sanitize_image_filename(image_filename)
	var img_path: = get_shared_images_dir().path_join(image_filename)
	if to_game_name:
		img_path = get_game_images_dir(to_game_name).path_join(image_filename)
	var save_success: = image_to_save.save_png(img_path)
	if save_success != OK:
		push_error("Error saving shared image %s to %s: %s" % [image_filename, img_path, error_string(save_success)])
		return false
	return true

func save_image_to_path(image_to_save: Image, abs_path: String) -> void:
	var base_dir: = abs_path.get_base_dir()
	var filename: = _sanitize_image_filename(abs_path.get_file())
	var save_success: = image_to_save.save_png(base_dir.path_join(filename))
	if save_success != OK:
		push_error("Error saving image to %s: %s" % [base_dir.path_join(filename), error_string(save_success)])
		return

func copy_shared_image_into_game(shared_image_name: String, copy_name: String, game_name: String) -> bool:
	return _copy_from_to_bundled(shared_image_name, copy_name, game_name, true)

func copy_bundled_image_into_shared(bundled_image_name: String, copy_name: String, game_name: String) -> bool:
	return _copy_from_to_bundled(bundled_image_name, copy_name, game_name, false)

func _copy_from_to_bundled(orig_image_name: String, copy_name: String, game_name: String, to_bundled: bool) -> bool:
	orig_image_name = _sanitize_image_filename(orig_image_name)
	if not copy_name:
		copy_name = orig_image_name
	else:
		copy_name = _sanitize_image_filename(copy_name)
	if not game_exists(game_name):
		push_error("Game %s does not exist" % [game_name])
		return false
	if not local_image_file_exists(orig_image_name, "" if to_bundled else game_name) or local_image_file_exists(copy_name, game_name if to_bundled else ""):
		push_error("image %s does not exist or target image with name %s already exists" % [orig_image_name, copy_name])
		return false
	var orig_base_dir: = get_shared_images_dir() if to_bundled else get_game_images_dir(game_name)
	var copy_base_dir: = get_game_images_dir(game_name) if to_bundled else get_shared_images_dir()
	var error: = DirAccess.copy_absolute(orig_base_dir.path_join(orig_image_name), copy_base_dir.path_join(copy_name))
	if error != OK:
		push_error("Error copying image from/to %s: %s -> %s : %s" % [game_name, orig_image_name, copy_name, error_string(error)])
		return false
	return true

func get_image_data_as_bytes(image_data: Image) -> PackedByteArray:
	return image_data.save_png_to_buffer()

func get_local_image_path(image_name: String, for_game_name: String = "") -> String:
	if for_game_name:
		if not game_exists(for_game_name):
			push_error("Game %s does not exist" % [for_game_name])
			return ""
		return get_game_images_dir(for_game_name).path_join(image_name)
	return get_shared_images_dir().path_join(image_name)

func copy_local_image_to_local(from_name: String, from_game: String, to_name: String, to_game: String) -> bool:
	from_name = _sanitize_image_filename(from_name)
	to_name = _sanitize_image_filename(to_name)
	if not from_name or not to_name:
		return false
	if from_name == to_name and from_game == to_game:
		return true
	var from_path: = get_local_image_path(from_name, from_game)
	var to_path: = get_local_image_path(to_name, to_game)
	if not smarter_dir_exists(from_path.get_base_dir()) or not smarter_dir_exists(to_path.get_base_dir()):
		push_error("Source or target directory does not exist: %s, %s" % [from_path.get_base_dir(), to_path.get_base_dir()])
		return false
	if not smarter_file_exists(from_path):
		push_error("Source image %s does not exist" % [from_path])
		return false
	if smarter_file_exists(to_path):
		push_error("Target image %s already exists" % [to_path])
		return false
	var error: = DirAccess.copy_absolute(from_path, to_path)
	if error != OK:
		push_error("Error copying image from %s to %s: %s" % [from_path, to_path, error_string(error)])
	return true

func load_local_image_as_texture(image_name: String, for_game_name: String = "") -> Texture:
	image_name = _sanitize_image_filename(image_name)
	if not for_game_name:
		return _load_shared_image_as_texture(image_name)
	else:
		if not game_exists(for_game_name):
			push_error("Game %s does not exist" % [for_game_name])
			return null
		var bundled_image_path: = get_game_images_dir(for_game_name).path_join(image_name)
		return load_file_as_texture(bundled_image_path)

func local_image_file_exists(image_filename: String, for_game_name: String = "") -> bool:
	var file_path: String = get_shared_images_dir().path_join(image_filename)
	if for_game_name:
		file_path = get_game_images_dir(for_game_name).path_join(image_filename)
	return smarter_file_exists(file_path)

func delete_local_image(image_filename: String, for_game_name: String = "") -> void:
	image_filename = _sanitize_image_filename(image_filename)
	if not local_image_file_exists(image_filename, for_game_name):
		return
	var file_path: String = get_shared_images_dir().path_join(image_filename)
	if for_game_name:
		file_path = get_game_images_dir(for_game_name).path_join(image_filename)
	DirAccess.remove_absolute(file_path)

func _load_shared_image_as_texture(image_name: String) -> Texture:
	return load_file_as_texture(get_shared_images_dir().path_join(image_name))

func load_file_as_texture(file_path: String) -> Texture:
	if not FileAccess.file_exists(file_path):
		push_error("File %s does not exist" % [file_path])
		return null
	var loaded_img: = Image.load_from_file(file_path)
	return ImageTexture.create_from_image(loaded_img)

func sanitize_level_filename(level_name: String) -> String:
	return Utility.sanitize_for_filename(level_name, true, true)

func _level_filename(level_name: String) -> String:
	return sanitize_level_filename(level_name) + ".json"

func save_level_to_name(game_name: String, level_data: Dictionary, as_filename: String) -> bool:
	if not game_exists(game_name):
		push_error("Game %s does not exist" % [game_name])
		return false
	serialize_and_save_data_to_json(level_data, get_game_levels_dir(game_name), _level_filename(as_filename))
	return true

func save_level(game_name: String, level_data: Dictionary) -> bool:
	if not level_data.get("name", "").strip_edges():
		push_error("Level data does not contain a name" % [game_name])
		return false
	return save_level_to_name(game_name, level_data, level_data["name"])

func level_exists(game_name: String, level_name: String) -> bool:
	if not level_name or not game_exists(game_name):
		push_error("Invalid game or level name: %s, %s" % [game_name, level_name])
		return false
	var level_filename: = _level_filename(level_name)
	return FileAccess.file_exists(get_game_levels_dir(game_name).path_join(level_filename))

func get_level_title(game_name: String, level_name: String) -> String:
	if not level_name or not game_exists(game_name):
		push_error("Invalid game or level name: %s, %s" % [game_name, level_name])
		return ""
	var level_data: = get_level_data(game_name, level_name)
	if not level_data:
		return ""
	return level_data.get("state", {}).get("map", {}).get("metadata", {}).get("title", level_name)

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

func get_editor_autosave_level_name(game_name: String) -> String:
	var level_list: = get_level_list(game_name)
	if "editor_autosave" not in level_list:
		return ""
	var editor_autosave_level_name: String = get_level_data(game_name, "editor_autosave").get("name", "")
	if not editor_autosave_level_name or editor_autosave_level_name == "editor_autosave" or editor_autosave_level_name not in level_list:
		return ""
	return editor_autosave_level_name

func get_editor_autosave_is_newer(game_name: String) -> bool:
	var level_list: = get_level_list(game_name)
	if "editor_autosave" not in level_list:
		push_error("Editor autosave not found in level list for game %s" % [game_name])
		return false
	var editor_autosave_data: = get_level_data(game_name, "editor_autosave")
	var editor_autosave_level_name: String = editor_autosave_data.get("name", "")
	if not editor_autosave_level_name or editor_autosave_level_name == "editor_autosave" or editor_autosave_level_name not in level_list:
		return true
	
	var editor_autosave_timestamp: = FileAccess.get_modified_time(get_game_levels_dir(game_name).path_join(_level_filename("editor_autosave")))
	var autosaved_level_timestamp: = FileAccess.get_modified_time(get_game_levels_dir(game_name).path_join(_level_filename(editor_autosave_level_name)))
	if editor_autosave_timestamp > autosaved_level_timestamp:
		return true
	return false

func get_example_games_list() -> Array:
	const EXAMPLE_GAMES_DIR: = "res://example_games"
	var example_game_directories: = _iter_directory_flat_filtered(EXAMPLE_GAMES_DIR, [], true, true, true)
	var example_games_list: Array[String] = []
	for ex_dir in example_game_directories:
		if not FileAccess.file_exists(EXAMPLE_GAMES_DIR + "/" + ex_dir + "/" + GAME_DEF_FILENAME):
			continue
		var example_game_definition: = _get_dict_from_json_file(EXAMPLE_GAMES_DIR + "/" + ex_dir + "/" + GAME_DEF_FILENAME)
		if example_game_definition:
			example_games_list.append(example_game_definition['game_name'])
	return example_games_list

func get_unique_game_name(base_name: String) -> String:
	var existing_games: = get_games_list()
	var unique_name: = base_name
	var counter: = 1
	while unique_name in existing_games:
		unique_name = base_name + "[%d]" % [counter]
	return unique_name

func import_all_example_games() -> void:
	for example_game_name: String in get_example_games_list():
		import_example_game(example_game_name)

func import_example_game(example_game_name: String, ensure_unique: bool = true) -> Dictionary:
	var example_game_dir_name: = get_game_dir_from_name(example_game_name)
	const EXAMPLE_GAMES_DIR: = "res://example_games"
	var example_game_dir_path: = EXAMPLE_GAMES_DIR.path_join(example_game_dir_name)
	var target_game_name: = example_game_name
	if ensure_unique:
		target_game_name = get_unique_game_name(example_game_name)
	var target_game_dir: = get_game_base_dir(target_game_name)
	if not smarter_dir_exists(example_game_dir_path):
		push_error("Example game directory %s does not exist" % [example_game_dir_path])
		return {}
	
	var example_game_dir_contents: = _iter_directory_flat_filtered(example_game_dir_path, [], true, true, true)
	if not GAME_DEF_FILENAME in example_game_dir_contents:
		push_error("Example game definition file not found in example game directory: " + example_game_dir_path)
		return {}
	
	var ex_game_info: = _get_dict_from_json_file(example_game_dir_path.path_join(GAME_DEF_FILENAME))
	if not ex_game_info:
		push_error("Error parsing example game definition at file: " + example_game_dir_path.path_join(GAME_DEF_FILENAME))
		return {}
	ex_game_info['game_name'] = target_game_name
	save_game_info(ex_game_info)
	
	var warnings: = import_example_game_levels_and_assets(example_game_dir_path, target_game_dir)
	
	return { "game_name": target_game_name, "warnings": warnings }

func import_example_game_levels_and_assets(example_game_dir_path: String, target_game_dir: String) -> Array[String]:
	var LEVELS: = "game_data/levels"
	var IMAGES: = "game_data/assets/images"
	var AUDIO: = "game_data/assets/audio"
	
	var warnings: Array[String] = []
	
	for subdir: String in [LEVELS, IMAGES, AUDIO]:
		var from_dir: = example_game_dir_path.path_join(subdir)
		if not smarter_dir_exists(from_dir):
			continue
		var to_dir: = target_game_dir.path_join(subdir)
		for a_file: String in _iter_directory_flat_filtered(from_dir, [], true, false):
			if a_file == "editor_autosave.json":
				continue
			var from_absolute_path: = ProjectSettings.globalize_path(from_dir.path_join(a_file))
			if OS.has_feature("web"):
				from_absolute_path = from_dir.path_join(a_file)
			var to_absolute_path: = ProjectSettings.globalize_path(to_dir.path_join(a_file))
			var error: = DirAccess.copy_absolute(from_absolute_path, to_absolute_path)
			if error != OK:
				push_warning("Error copying example game asset/level file %s to %s: %s" % [a_file, to_absolute_path, error_string(error)])
				warnings.append("Failed to copy %s" % [subdir + "/" + a_file])
	return warnings

func copy_assets_and_levels_to(from_game_name: String, to_game_name: String) -> void:
	if not game_exists(from_game_name) or not game_exists(to_game_name):
		push_error("Game %s or %s does not exist" % [from_game_name, to_game_name])
		return
	
	var from_game_gamedata_dir: = get_game_gamedata_dir(from_game_name)
	var to_game_gamedata_dir: = get_game_gamedata_dir(to_game_name)
	
	var game_data_subdirs: = ["levels", "assets/images", "assets/audio"]

	for subdir in game_data_subdirs:
		var abs_from_dir: = ProjectSettings.globalize_path(from_game_gamedata_dir.path_join(subdir))
		if not smarter_dir_exists(abs_from_dir):
			continue
		var abs_to_dir: = ProjectSettings.globalize_path(to_game_gamedata_dir.path_join(subdir))
		for asset_file in iterate_directory_flat_filelist(abs_from_dir):
			var error: = DirAccess.copy_absolute(abs_from_dir.path_join(asset_file), abs_to_dir.path_join(asset_file))
			if error != OK:
				push_warning("Error copying game data file %s from %s to %s: %s" % [asset_file, abs_from_dir, abs_to_dir, error_string(error)])

func is_game_name_equivalent(game_name_1: String, game_name_2: String) -> bool:
	return get_game_dir_from_name(game_name_1) == get_game_dir_from_name(game_name_2)

func rename_game(old_game_name: String, new_game_name: String) -> bool:
	if not game_exists(old_game_name):
		push_error("Game %s does not exist" % [old_game_name])
		return false
	if game_exists(new_game_name):
		push_error("Game directory %s already exists, cannot rename %s to it" % [new_game_name, old_game_name])
		return false
	var rename_dir: = not is_game_name_equivalent(old_game_name, new_game_name)
	
	var def_path: = get_game_definition_path(old_game_name)
	var game_definition_data: = _get_dict_from_json_file(def_path)
	if not game_definition_data:
		push_error("Error parsing game definition at file: " + def_path)
		return false
	game_definition_data['game_name'] = new_game_name.strip_edges()
	if not serialize_and_save_data_to_json(game_definition_data, def_path.get_base_dir(), GAME_DEF_FILENAME, FORMAT_GAME_JSON):
		push_error("Error saving renamed game definition at file: " + def_path)
		return false

	if rename_dir:
		var old_game_dir_abs: = ProjectSettings.globalize_path(get_game_base_dir(old_game_name))
		var new_game_dir_abs: = ProjectSettings.globalize_path(get_game_base_dir(new_game_name))
		var error: = DirAccess.rename_absolute(old_game_dir_abs, new_game_dir_abs)
		if error != OK:
			push_error("Error renaming game directory from %s to %s: %s" % [old_game_dir_abs, new_game_dir_abs, error_string(error)])
			return false
	return true

func fix_game_name(game_name: String) -> void:
	if not game_exists(game_name):
		push_error("Game %s does not exist" % [game_name])
		return
	var game_def_path: = get_game_definition_path(game_name)
	var game_definition: = _get_dict_from_json_file(game_def_path)
	if not game_definition:
		push_error("Error parsing game definition at file: " + game_def_path)
		return
	game_definition['game_name'] = game_name.strip_edges()
	if not serialize_and_save_data_to_json(game_definition, game_def_path.get_base_dir(), GAME_DEF_FILENAME, FORMAT_GAME_JSON):
		push_error("Error saving fixed game definition at file: " + game_def_path)
		return

func smarter_dir_exists(dir_path: String) -> bool:
	if OS.has_feature("web"):
		return web_dir_exists(dir_path)
	var path_abs: = ProjectSettings.globalize_path(dir_path)
	return DirAccess.dir_exists_absolute(path_abs)

func web_dir_exists(dir_path: String) -> bool:
	var path_localized: = ProjectSettings.localize_path(dir_path)
	if path_localized.begins_with("user://"):
		return DirAccess.dir_exists_absolute(path_localized)

	if not path_localized:
		return false
	if path_localized == "res://":
		return true
	var base_path: = path_localized.get_base_dir()
	var dir_name: = path_localized.get_file().trim_suffix("/") + "/"
	var listed_contents: = ResourceLoader.list_directory(base_path)
	if not listed_contents or not dir_name in listed_contents:
		prints("dir %s not found in %s" % [dir_name, listed_contents])
		return false
	return true

func smarter_make_dir_absolute(dir_path: String) -> void:
	var path_abs: = ProjectSettings.globalize_path(dir_path)
	DirAccess.make_dir_absolute(path_abs)

func smarter_file_exists(file_path: String) -> bool:
	var path_abs: = ProjectSettings.globalize_path(file_path)
	return FileAccess.file_exists(path_abs)

func delete_game(game_name: String) -> bool:
	var game_dir: = get_game_base_dir(game_name)
	if not smarter_dir_exists(game_dir):
		push_error("Game directory %s does not exist" % [game_dir])
		return false
	var error: = DirAccess.remove_absolute(ProjectSettings.globalize_path(game_dir))
	if error != OK:
		push_error("Error deleting game directory %s: %s" % [game_dir, error_string(error)])
		return false
	return true

func _get_temp_file_path(with_extension: String = "") -> String:
	var random_name: = String.num_int64(randi_range(1, 200000), 16)
	return _data_path(TEMPORARY_FILE_PREFIX + random_name + with_extension)

func save_temporary_data_as_file(data: PackedByteArray, with_extension: String = "") -> String:
	var temp_file_path: = _get_temp_file_path(with_extension)
	var wr_file: = FileAccess.open(temp_file_path, FileAccess.WRITE)
	if not wr_file:
		push_error("Error creating temp file to write data to %s" % [temp_file_path])
		return ""
	if not wr_file.store_buffer(data):
		push_error("Error writing data to temp file %s" % [temp_file_path])
		return ""
	return temp_file_path

func delete_temporary_file(temp_file_path: String) -> void:
	if not temp_file_path.begins_with(_data_path(TEMPORARY_FILE_PREFIX)):
		push_error("Temp file path %s is not a temporary file path" % [temp_file_path])
		return
	if not FileAccess.file_exists(temp_file_path):
		return
	var error: = DirAccess.remove_absolute(temp_file_path)
	if error != OK:
		push_error("Error deleting temporary file %s: %s" % [temp_file_path, error_string(error)])
		return



func get_available_player_id() -> String:
	var id_num: = 1
	var profile_list: = get_player_profile_list()
	for i in 100000:
		if not str(id_num) in profile_list:
			return str(id_num)
		id_num += 1
	push_error("Maximum iterations reached when trying to get a new player id")
	return ""

func get_player_profile_list() -> Array:
	if not smarter_dir_exists(_data_path(local_data_subdir)):
		return []
	var player_profile_list: Array = []
	for player_id in DirAccess.get_directories_at(_data_path(local_data_subdir)):
		if player_profile_exists(player_id):
			player_profile_list.append(player_id)
	return player_profile_list

func create_player_profile(player_id: String) -> PlayerProfile:
	if player_profile_exists(player_id):
		push_error("Player profile %s already exists" % [player_id])
		return
	ensure_data_dir_exists(local_data_subdir, player_id)
	ensure_data_dir_exists(local_data_subdir, player_id, game_saves_local_subdir)
	var profile: PlayerProfile = PlayerProfile.new()
	profile.player_id = player_id
	profile.write_settings()
	return profile

func save_profile_settings(player_id: String, settings_data: Dictionary) -> bool:
	return _save_json_string_absolute(JSON.stringify(settings_data), _data_path(local_data_subdir, player_id), PLAYER_SETTINGS_FILENAME)

func player_profile_exists(player_id: String) -> bool:
	if not smarter_dir_exists(_data_path(local_data_subdir, player_id)):
		return false
	return smarter_file_exists(_data_path(local_data_subdir, player_id, PLAYER_SETTINGS_FILENAME))

func get_player_profile(player_id: String) -> PlayerProfile:
	if not player_profile_exists(player_id):
		return null
	var settings_data: = _get_dict_from_json_file(_data_path(local_data_subdir, player_id, PLAYER_SETTINGS_FILENAME))
	if not settings_data:
		push_error("Error parsing player settings at file: " + _data_path(local_data_subdir, player_id, PLAYER_SETTINGS_FILENAME))
		return null
	var profile: PlayerProfile = PlayerProfile.get_profile_for_serialized_settings(player_id, settings_data)
	if smarter_dir_exists(_data_path(local_data_subdir, player_id, game_saves_local_subdir)):
		for game_save_file in iterate_directory_flat_filelist(_data_path(local_data_subdir, player_id, game_saves_local_subdir), "json"):
			var game_save_data: = _get_dict_from_json_file(_data_path(local_data_subdir, player_id, game_saves_local_subdir, game_save_file))
			if not game_save_data:
				continue
			profile.add_game_save(game_save_data)
	return profile

func save_game_save_for_player(player_id: String, game_name: String, game_save_data: Dictionary) -> void:
	if not player_profile_exists(player_id):
		push_error("Player profile %s does not exist" % [player_id])
		return
	var game_name_sanitized: = get_game_dir_from_name(game_name)
	var profile_game_saves_dir: = _data_path(local_data_subdir, player_id, game_saves_local_subdir)
	return serialize_and_save_data_to_json(game_save_data, profile_game_saves_dir, game_name_sanitized + ".json", FORMAT_GAME_JSON)