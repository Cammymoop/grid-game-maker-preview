extends Node

func _game_name_to_zip_name(identified_game_name: String) -> String:
    var zip_name: String = ""
    if identified_game_name.contains("/"):
        zip_name = identified_game_name.split("/", true, 1)[0].strip_edges() + "__"
        identified_game_name = identified_game_name.split("/", true, 1)[1].strip_edges()
    zip_name += Utility.sanitize_for_filename(identified_game_name, true)
    return zip_name

func make_backup_of_game(game_name: String) -> bool:
    var game_dir: = FilesManager.get_game_base_dir(game_name)
    var zip_name: String = _game_name_to_zip_name(game_name)
    var result: Dictionary = ArchiveCopier.copy_and_zip_directory(game_dir, "", zip_name + "_backup")
    if not result.get("ok", false):
        push_error("Failed to make backup of game %s: %s" % [game_name, result.get("error", "Unknown error")])
        return false
    return true

func import_example_game(example_game_name: String, as_new_game: bool) -> bool:
    var example_games_list: = FilesManager.get_example_games_list()
    if not example_game_name in example_games_list:
        return false
    
    if not as_new_game:
        if FilesManager.game_exists(example_game_name):
            if not make_backup_of_game(example_game_name):
                return false
    
    var result: = FilesManager.import_example_game(example_game_name, as_new_game)
    if not result:
        return false
    return true

func reimport_all_example_games() -> Array[String]:
    var failed_games: Array[String] = []
    for example_game_name: String in FilesManager.get_example_games_list():
        if not import_example_game(example_game_name, false):
            failed_games.append(example_game_name)
    return failed_games

func import_game_zip(zip_file: Variant, as_new_game: bool, as_new_game_name: String = "", enable_bundled_images: bool = false) -> String:
    var importing_game_name: = ""
    if not enable_bundled_images:
        if ImportZipExtractor.zip_or_buffer_has_bundled_images(zip_file):
            return ""
    if zip_file is String:
        importing_game_name = ImportZipExtractor.get_game_name_from_zip(zip_file)
    else:
        importing_game_name = ImportZipExtractor.get_game_name_from_zip_buffer(zip_file)

    if not importing_game_name:
        return ""
    
    var make_backup_if_exists: bool = true
    if as_new_game:
        if FilesManager.game_exists(importing_game_name):
            if not as_new_game_name:
                as_new_game_name = FilesManager.get_unique_game_name(importing_game_name)
            if FilesManager.game_exists(as_new_game_name):
                as_new_game_name = FilesManager.get_unique_game_name(as_new_game_name)
            importing_game_name = as_new_game_name
        elif as_new_game_name:
            if FilesManager.game_exists(as_new_game_name):
                as_new_game_name = FilesManager.get_unique_game_name(as_new_game_name)
            importing_game_name = as_new_game_name
    elif FilesManager.game_exists(importing_game_name):
        var game_is_unedited: bool = false
        if importing_game_name == GameManager.get_identified_game_name():
            game_is_unedited = GameManager.current_game_is_release_locked
            if not game_is_unedited:
                GameManager.save_current_game_definition()
        else:
            game_is_unedited = GameManager.validate_game_release(importing_game_name)
        
        if game_is_unedited:
            make_backup_if_exists = false
    
    FilesManager.create_game_directory_if_not_exists(importing_game_name)
    
    var result: = ImportZipExtractor.import_game_from_zip(zip_file, importing_game_name, make_backup_if_exists)
    if not result.get("ok", false):
        return ""
    FilesManager.fix_game_name(importing_game_name)
    
    # Move release zips into the other_versions/releases directory so we have access to them for switching versions
    var imported_was_release_version: bool = GameManager.validate_game_release(importing_game_name)
    if imported_was_release_version:
        var release_zip_dir: = FilesManager.get_game_release_zip_directory(importing_game_name)
        var zip_file_path: String = ""
        var zip_is_temp_file: bool = false
        if typeof(zip_file) == TYPE_STRING:
            zip_file_path = zip_file
        elif typeof(zip_file) == TYPE_PACKED_BYTE_ARRAY:
            zip_file_path = FilesManager.save_temporary_data_as_file(zip_file, ".zip")
            zip_is_temp_file = true
        
        var dest_zip_file: String = release_zip_dir.path_join(zip_file_path.get_file())
        if not FileAccess.file_exists(dest_zip_file):
            DirAccess.copy_absolute(zip_file_path, dest_zip_file)
        if zip_is_temp_file:
            FilesManager.delete_temporary_file(zip_file_path)

    return importing_game_name

func export_game_zip(game_name: String, save_to_directory: String = "", zip_name_suffix: String = "", prefer_skip_date_stamp: bool = false, include_unbundled_levels: bool = false) -> String:
    if not FilesManager.game_exists(game_name):
        return ""
    if save_to_directory:
        if not save_to_directory.is_absolute_path() and not save_to_directory.is_relative_path():
            return ""
        if save_to_directory.is_relative_path() or save_to_directory.begins_with("res://"):
            save_to_directory = OS.get_executable_path().get_base_dir().path_join(save_to_directory)
        if save_to_directory.begins_with("user://"):
            save_to_directory = ProjectSettings.globalize_path(save_to_directory)
        if not DirAccess.dir_exists_absolute(save_to_directory):
            return ""
    
    var all_bundled_level_names: Array[String] = []
    if not include_unbundled_levels:
        all_bundled_level_names.assign(GameManager.get_list_of_all_bundled_levels())
        all_bundled_level_names.append_array(GameManager.get_list_of_unlisted_levels())
    
    var whitelisted_level_filenames: Array[String] = []
    for level_name in all_bundled_level_names:
        var level_filename: = FilesManager._level_filename(level_name)
        if not level_filename in whitelisted_level_filenames:
            whitelisted_level_filenames.append(level_filename)

    var game_dir: = FilesManager.get_game_base_dir(game_name)
    
    var zip_name: String = _game_name_to_zip_name(game_name)
    if zip_name_suffix:
        zip_name += "_" + zip_name_suffix

    var result: = ArchiveCopier.copy_and_zip_directory(
        game_dir,
        save_to_directory,
        zip_name,
        include_unbundled_levels,
        whitelisted_level_filenames,
        prefer_skip_date_stamp
    )
    if not result.get("ok", false):
        return ""
    var zip_path: String = result.get("zip_path", "")
    return zip_path