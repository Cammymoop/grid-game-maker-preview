extends Node


func extract_zip_to_games(
	zip_file_path: String,
	dest_game_dir: String
) -> Dictionary:
	var normalized_zip_path := _normalize_input_file_path(zip_file_path)
	if normalized_zip_path.is_empty():
		return {
			"ok": false,
			"error": "Invalid zip file path.",
		}

	if not FileAccess.file_exists(normalized_zip_path):
		push_error("Zip file does not exist: %s" % normalized_zip_path)
		return {
			"ok": false,
			"error": "Zip file does not exist: %s" % normalized_zip_path,
		}

	if not dest_game_dir or dest_game_dir == "OOPS":
		push_error("Game directory name is invalid.")
		return {
			"ok": false,
			"error": "Game directory name is invalid.",
		}

	var import_root_abs := ProjectSettings.globalize_path(FilesManager.get_games_dir()).simplify_path()
	var ensure_root_err := _ensure_dir_exists(import_root_abs)
	if ensure_root_err != OK:
		push_error("Failed to create import root: %s" % import_root_abs)
		return {
			"ok": false,
			"error": "Failed to create import root: %s" % import_root_abs,
			"code": ensure_root_err,
		}

	var dest_dir_abs := import_root_abs.path_join(dest_game_dir).simplify_path()
	var excluded_names := _build_excluded_names()

	var extract_err := _extract_zip_into_dir(
		normalized_zip_path,
		dest_dir_abs,
		import_root_abs,
		excluded_names
	)
	if extract_err != OK:
		return {
			"ok": false,
			"error": "Extraction failed.",
			"code": extract_err,
			"dest_dir": dest_dir_abs,
		}

	return {
		"ok": true,
		"dest_dir": dest_dir_abs,
	}


func import_game_from_zip(
	zip_file: Variant,
	dest_game_name: String,
	make_backup_if_exists: bool = true,
) -> Dictionary:
	if not dest_game_name or dest_game_name == "OOPS":
		push_error("Game directory name is invalid.")
		return {
			"ok": false,
			"error": "Game directory name is invalid.",
		}

	var import_root_abs := ProjectSettings.globalize_path(FilesManager.get_games_dir()).simplify_path()
	var dest_game_dir: = FilesManager.get_game_dir_from_name(dest_game_name)
	var dest_dir_abs := import_root_abs.path_join(dest_game_dir).simplify_path()

	var backup_result: Dictionary = {
		"ok": true,
		"skipped": true,
	}

	if make_backup_if_exists and DirAccess.dir_exists_absolute(dest_dir_abs):
		var marker_file := dest_dir_abs.path_join(FilesManager.GAME_DEF_FILENAME)
		if FileAccess.file_exists(marker_file):
			if not ImporterExporter.make_backup_of_game(dest_game_name):
				backup_result["ok"] = false
				backup_result["error"] = "Failed to make backup of game."
				push_error("Backup failed, extraction aborted.")
				return {
					"ok": false,
					"error": "Backup failed, extraction aborted.",
					"backup_result": backup_result,
				}

			backup_result["skipped"] = false

	var extract_result: Dictionary = {}
	if zip_file is String:
		extract_result = extract_zip_to_games(zip_file, dest_game_dir)
	elif zip_file is PackedByteArray:
		var temp_file_path: = FilesManager.save_temporary_data_as_file(zip_file, ".zip")
		if not temp_file_path:
			return {
				"ok": false,
				"error": "Failed to save temporary zip file.",
			}
		extract_result = extract_zip_to_games(temp_file_path, dest_game_dir)
		FilesManager.delete_temporary_file(temp_file_path)
	extract_result["backup_result"] = backup_result
	return extract_result


func _extract_zip_into_dir(
	zip_file_path: String,
	dest_dir_abs: String,
	allowed_root_abs: String,
	excluded_names: Array[String]
) -> int:
	var ensure_dest_err := _ensure_dir_exists(dest_dir_abs)
	if ensure_dest_err != OK:
		push_error("Failed to create destination directory: %s" % dest_dir_abs)
		return ensure_dest_err

	var reader := ZIPReader.new()
	var open_err := reader.open(zip_file_path)
	if open_err != OK:
		push_error("Failed to open zip file: %s" % zip_file_path)
		return open_err

	var files := reader.get_files()
	var root_prefix := _detect_single_root_prefix(files)

	for zip_entry in files:
		var relative_entry := _strip_root_prefix(zip_entry, root_prefix)
		relative_entry = relative_entry.replace("\\", "/").trim_prefix("./")

		if relative_entry.is_empty():
			continue

		if not _is_safe_relative_zip_path(relative_entry):
			push_error("Skipping unsafe zip entry: %s" % zip_entry)
			continue

		var entry_name := relative_entry.trim_suffix("/").get_file()
		if entry_name in excluded_names:
			continue

		var output_abs := dest_dir_abs.path_join(relative_entry).simplify_path()

		if not _is_path_within_root(output_abs, allowed_root_abs):
			reader.close()
			push_error("Refusing to write outside allowed root: %s" % output_abs)
			return ERR_INVALID_DATA

		if zip_entry.ends_with("/"):
			var dir_err := _ensure_dir_exists(output_abs)
			if dir_err != OK:
				reader.close()
				push_error("Failed to create extracted directory: %s" % output_abs)
				return dir_err
			continue

		var parent_dir := output_abs.get_base_dir()
		var mk_parent_err := _ensure_dir_exists(parent_dir)
		if mk_parent_err != OK:
			reader.close()
			push_error("Failed to create parent directory: %s" % parent_dir)
			return mk_parent_err

		var buffer := reader.read_file(zip_entry)
		var out_file := FileAccess.open(output_abs, FileAccess.WRITE)
		if out_file == null:
			reader.close()
			push_error("Failed to open extracted file for writing: %s" % output_abs)
			return ERR_CANT_OPEN

		out_file.store_buffer(buffer)
		out_file.close()

	reader.close()
	return OK


func _detect_single_root_prefix(files: PackedStringArray) -> String:
	var root_name := ""
	var saw_any := false

	for zip_entry in files:
		var normalized := zip_entry.replace("\\", "/").trim_prefix("./")
		if normalized.is_empty():
			continue

		var trimmed := normalized.trim_suffix("/")
		if trimmed.is_empty():
			continue

		var slash_index := trimmed.find("/")
		var first_component := trimmed
		if slash_index >= 0:
			first_component = trimmed.substr(0, slash_index)

		if first_component.is_empty():
			return ""

		if not saw_any:
			root_name = first_component
			saw_any = true
		elif root_name != first_component:
			return ""

	if not saw_any or root_name.is_empty():
		return ""

	return root_name + "/"


func _strip_root_prefix(path: String, root_prefix: String) -> String:
	var normalized := path.replace("\\", "/").trim_prefix("./")
	if root_prefix.is_empty():
		return normalized
	if normalized.begins_with(root_prefix):
		return normalized.substr(root_prefix.length())
	return normalized


func _is_safe_relative_zip_path(relative_path: String) -> bool:
	var normalized := relative_path.replace("\\", "/").trim_prefix("./")

	if normalized.is_empty():
		return false

	if normalized.begins_with("/"):
		return false

	var parts := normalized.split("/", false)
	for part in parts:
		if part == "." or part == "..":
			return false

	return true


func _is_path_within_root(path: String, root: String) -> bool:
	var normalized_path := path.simplify_path().replace("\\", "/")
	var normalized_root := root.simplify_path().replace("\\", "/").trim_suffix("/")

	if normalized_path == normalized_root:
		return true

	return normalized_path.begins_with(normalized_root + "/")


func _build_excluded_names() -> Array[String]:
	var excluded: Array[String] = []

	var copier_output_dir_name := ArchiveCopier.OUTPUT_SUBDIR.simplify_path().get_file()
	if not copier_output_dir_name.is_empty():
		excluded.append(copier_output_dir_name)

	return excluded


func _normalize_input_file_path(path: String) -> String:
	if path.begins_with("res://"):
		push_error("ImportZipExtractor does not support res:// paths: %s" % path)
		return ""

	if path.begins_with("user://"):
		return ProjectSettings.globalize_path(path).simplify_path()

	return path.simplify_path()


func _sanitize_name(value: String) -> String:
	var result := value.strip_edges()

	var invalid_chars := [
		"/",
		"\\",
		":",
		"*",
		"?",
		"\"",
		"<",
		">",
		"|",
	]

	for ch in invalid_chars:
		result = result.replace(ch, "_")

	result = result.replace(" ", "_")

	result = result.strip_edges()
	result = result.trim_prefix(".")
	result = result.trim_suffix(".")

	return result


func _ensure_dir_exists(path: String) -> int:
	if DirAccess.dir_exists_absolute(path):
		return OK
	return DirAccess.make_dir_recursive_absolute(path)

func get_game_name_from_zip(zip_file_path: String) -> String:
	var game_info: = get_game_info_from_zip(zip_file_path)
	var game_identifier: String = game_info.get("identifier", "")
	var game_name: String = game_info.get("game_name", "")
	if game_identifier:
		game_name = game_identifier + "/" + game_name
	return game_name

func get_game_name_from_zip_buffer(zip_buffer: PackedByteArray) -> String:
	var temp_file_path: = FilesManager.save_temporary_data_as_file(zip_buffer, ".zip")
	if not temp_file_path:
		return ""
	var game_name: = get_game_name_from_zip(temp_file_path)
	FilesManager.delete_temporary_file(temp_file_path)
	return game_name

func get_game_info_from_zip(zip_file_path: String) -> Dictionary:
	var result: = _read_game_definition_from_zip(zip_file_path)
	if not result.get("ok", false):
		return {}
	var parsed_data: Variant = result.get("data", {})
	if typeof(parsed_data) != TYPE_DICTIONARY or not parsed_data:
		return {}
	return parsed_data

func zip_or_buffer_has_bundled_images(zip_file: Variant) -> bool:
	if zip_file is String:
		return zip_has_bundled_images(zip_file)
	elif zip_file is PackedByteArray:
		var temp_file_path: = FilesManager.save_temporary_data_as_file(zip_file, ".zip")
		if not temp_file_path:
			return false
		var result: = zip_has_bundled_images(temp_file_path)
		FilesManager.delete_temporary_file(temp_file_path)
		return result
	return false

func zip_has_bundled_images(zip_file_path: String) -> bool:
	var game_config: Dictionary = get_game_info_from_zip(zip_file_path).get("data", {})
	var texture_spec: Array = game_config.get("textures", [])
	for texture_info in texture_spec:
		if not typeof(texture_info) == TYPE_DICTIONARY:
			continue
		if texture_info.get("type", "") == "local_file" and not texture_info.get("is_shared", true):
			return true
	return false

func _read_game_definition_from_zip(zip_file_path: String) -> Dictionary:
	var normalized_zip_path := _normalize_input_file_path(zip_file_path)
	if normalized_zip_path.is_empty():
		return {
			"ok": false,
			"error": "Invalid zip file path.",
		}

	if not FileAccess.file_exists(normalized_zip_path):
		push_error("Zip file does not exist: %s" % normalized_zip_path)
		return {
			"ok": false,
			"error": "Zip file does not exist: %s" % normalized_zip_path,
		}

	var reader := ZIPReader.new()
	var open_err := reader.open(normalized_zip_path)
	if open_err != OK:
		push_error("Failed to open zip file: %s" % normalized_zip_path)
		return {
			"ok": false,
			"error": "Failed to open zip file.",
			"code": open_err,
		}

	var files := reader.get_files()
	var root_prefix := _detect_single_root_prefix(files)

	var candidate_paths: Array[String] = [
		FilesManager.GAME_DEF_FILENAME,
	]
	if not root_prefix.is_empty():
		candidate_paths.append(root_prefix + FilesManager.GAME_DEF_FILENAME)

	var matched_path := ""
	for candidate in candidate_paths:
		if candidate in files:
			matched_path = candidate
			break

	if matched_path.is_empty():
		reader.close()
		return {
			"ok": false,
			"error": "No %s found at zip top level or under common root." % FilesManager.GAME_DEF_FILENAME,
		}

	var buffer := reader.read_file(matched_path)
	reader.close()

	if buffer.is_empty():
		return {
			"ok": false,
			"error": "Found %s but it was empty or unreadable." % matched_path,
			"zip_path": matched_path,
		}

	var json_text := buffer.get_string_from_utf8()
	if json_text.is_empty():
		return {
			"ok": false,
			"error": "Found %s but it was not valid UTF-8 text." % matched_path,
			"zip_path": matched_path,
		}

	var parsed_data: Variant = Utility.parse_json(json_text)
	return {
		"ok": true,
		"data": parsed_data,
	}