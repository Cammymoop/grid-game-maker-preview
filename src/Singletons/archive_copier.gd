extends Node

const OUTPUT_SUBDIR := "other_versions"


func copy_and_zip_directory(
	source_dir_path: String,
	dest_name: String
) -> Dictionary:
	if source_dir_path.begins_with("res://"):
		push_error("ArchiveCopier does not support res:// paths: %s" % source_dir_path)
		return {
			"ok": false,
			"error": "res:// paths are not supported.",
		}

	var normalized_source := _normalize_input_dir(source_dir_path)

	if not DirAccess.dir_exists_absolute(normalized_source):
		push_error("Source directory does not exist: %s" % normalized_source)
		return {
			"ok": false,
			"error": "Source directory does not exist: %s" % normalized_source,
		}

	var cleaned_dest_name := _sanitize_name(dest_name)
	if cleaned_dest_name.is_empty():
		push_error("Destination name is empty after sanitization.")
		return {
			"ok": false,
			"error": "Destination name is invalid.",
		}

	var output_root := normalized_source.path_join(OUTPUT_SUBDIR).simplify_path()

	var mk_root_err := _ensure_dir_exists(output_root)
	if mk_root_err != OK:
		push_error("Failed to create output directory: %s" % output_root)
		return {
			"ok": false,
			"error": "Failed to create output directory: %s" % output_root,
			"code": mk_root_err,
		}

	var archive_base_name := _find_available_output_name(
		output_root,
		cleaned_dest_name
	)
	if archive_base_name.is_empty():
		push_error("Failed to determine an available destination name.")
		return {
			"ok": false,
			"error": "Failed to determine an available destination name.",
		}

	var copied_dir := output_root.path_join(archive_base_name).simplify_path()
	var zip_path := output_root.path_join("%s.zip" % archive_base_name).simplify_path()

	var excluded_names := _build_excluded_names()

	var copy_err := _copy_dir_recursive(
		normalized_source,
		copied_dir,
		excluded_names
	)
	if copy_err != OK:
		return {
			"ok": false,
			"error": "Copy failed.",
			"code": copy_err,
			"copied_dir": copied_dir,
		}

	var zip_err := _zip_directory(copied_dir, zip_path)
	if zip_err != OK:
		return {
			"ok": false,
			"error": "Zip creation failed.",
			"code": zip_err,
			"copied_dir": copied_dir,
			"zip_path": zip_path,
		}

	return {
		"ok": true,
		"copied_dir": copied_dir,
		"zip_path": zip_path,
	}


func _normalize_input_dir(path: String) -> String:
	if path.begins_with("user://"):
		return ProjectSettings.globalize_path(path).simplify_path()
	return path.simplify_path()


func _copy_dir_recursive(
	source_dir: String,
	dest_dir: String,
	excluded_names: Array[String]
) -> int:
	var ensure_err := _ensure_dir_exists(dest_dir)
	if ensure_err != OK:
		push_error("Failed to create directory: %s" % dest_dir)
		return ensure_err

	var dir := DirAccess.open(source_dir)
	if dir == null:
		push_error("Failed to open source directory: %s" % source_dir)
		return ERR_CANT_OPEN

	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry == "":
			break

		if entry == "." or entry == "..":
			continue

		if entry in excluded_names:
			continue

		var source_path := source_dir.path_join(entry)
		var dest_path := dest_dir.path_join(entry)

		if dir.current_is_dir():
			var sub_err := _copy_dir_recursive(
				source_path,
				dest_path,
				excluded_names
			)
			if sub_err != OK:
				dir.list_dir_end()
				return sub_err
		else:
			var file_err := _copy_file(source_path, dest_path)
			if file_err != OK:
				dir.list_dir_end()
				return file_err

	dir.list_dir_end()
	return OK


func _copy_file(source_file: String, dest_file: String) -> int:
	var src := FileAccess.open(source_file, FileAccess.READ)
	if src == null:
		push_error("Failed to open source file: %s" % source_file)
		return ERR_CANT_OPEN

	var data := src.get_buffer(src.get_length())
	src.close()

	var dst := FileAccess.open(dest_file, FileAccess.WRITE)
	if dst == null:
		push_error("Failed to open destination file: %s" % dest_file)
		return ERR_CANT_OPEN

	dst.store_buffer(data)
	dst.close()

	return OK


func _zip_directory(directory_to_zip: String, zip_path: String) -> int:
	var writer := ZIPPacker.new()
	var open_err := writer.open(zip_path)
	if open_err != OK:
		push_error("Failed to open zip for writing: %s" % zip_path)
		return open_err

	var zip_root_name := directory_to_zip.get_file()
	var zip_err := _zip_dir_recursive(
		writer,
		directory_to_zip,
		directory_to_zip,
		zip_root_name
	)

	writer.close()
	return zip_err


func _zip_dir_recursive(
	writer: ZIPPacker,
	current_dir: String,
	root_dir: String,
	zip_root_name: String
) -> int:
	var dir := DirAccess.open(current_dir)
	if dir == null:
		push_error("Failed to open directory for zipping: %s" % current_dir)
		return ERR_CANT_OPEN

	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry == "":
			break

		if entry == "." or entry == "..":
			continue

		var abs_path := current_dir.path_join(entry)

		if dir.current_is_dir():
			var sub_err := _zip_dir_recursive(
				writer,
				abs_path,
				root_dir,
				zip_root_name
			)
			if sub_err != OK:
				dir.list_dir_end()
				return sub_err
		else:
			var relative_path := _relative_path(root_dir, abs_path)
			var zip_entry_path := "%s/%s" % [
				zip_root_name,
				relative_path.replace("\\", "/"),
			]

			var file := FileAccess.open(abs_path, FileAccess.READ)
			if file == null:
				dir.list_dir_end()
				push_error("Failed to read file for zipping: %s" % abs_path)
				return ERR_CANT_OPEN

			var start_err := writer.start_file(zip_entry_path)
			if start_err != OK:
				file.close()
				dir.list_dir_end()
				push_error("Failed to start zip entry: %s" % zip_entry_path)
				return start_err

			writer.write_file(file.get_buffer(file.get_length()))
			writer.close_file()
			file.close()

	dir.list_dir_end()
	return OK


func _relative_path(root: String, full_path: String) -> String:
	var normalized_root := root.simplify_path().replace("\\", "/").trim_suffix("/")
	var normalized_full := full_path.simplify_path().replace("\\", "/")

	if normalized_full == normalized_root:
		return ""

	var prefix := normalized_root + "/"
	if normalized_full.begins_with(prefix):
		return normalized_full.substr(prefix.length())

	return normalized_full


func _build_excluded_names() -> Array[String]:
	var excluded: Array[String] = []

	var output_dir_name := OUTPUT_SUBDIR.simplify_path().get_file()
	if not output_dir_name.is_empty():
		excluded.append(output_dir_name)

	return excluded


func _make_date_stamp() -> String:
	var dt := Time.get_datetime_dict_from_system()
	return "%04d%02d%02d" % [
		dt.year,
		dt.month,
		dt.day,
	]


func _find_available_output_name(output_root: String, dest_name: String) -> String:
	var date_stamp := _make_date_stamp()
	var base_name := "%s_%s" % [dest_name, date_stamp]

	var candidate := base_name
	var suffix := 0

	while true:
		var copied_dir := output_root.path_join(candidate).simplify_path()
		var zip_path := output_root.path_join("%s.zip" % candidate).simplify_path()

		var dir_exists := DirAccess.dir_exists_absolute(copied_dir)
		var zip_exists := FileAccess.file_exists(zip_path)

		if not dir_exists and not zip_exists:
			return candidate

		suffix += 1
		candidate = "%s_%d" % [base_name, suffix]

	return ""


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

	while result.contains("__"):
		result = result.replace("__", "_")

	result = result.strip_edges()
	result = result.trim_prefix(".")
	result = result.trim_suffix(".")

	return result


func _ensure_dir_exists(path: String) -> int:
	if DirAccess.dir_exists_absolute(path):
		return OK
	return DirAccess.make_dir_recursive_absolute(path)