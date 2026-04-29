extends Node

func make_backup_of_game(game_name: String) -> bool:
    var game_dir: = FilesManager.get_game_base_dir(game_name)
    var result: Dictionary = ArchiveCopier.copy_and_zip_directory(game_dir, game_name + "_backup")
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

func import_game_zip(zip_file: Variant, as_new_game: bool, new_game_name: String = "") -> String:
    var importing_game_name: = ""
    if zip_file is String:
        importing_game_name = ImportZipExtractor.get_game_name_from_zip(zip_file)
    else:
        importing_game_name = ImportZipExtractor.get_game_name_from_zip_buffer(zip_file)

    if not importing_game_name:
        return ""
    
    if FilesManager.game_exists(importing_game_name):
        if as_new_game:
            if not new_game_name:
                new_game_name = FilesManager.get_unique_game_name(importing_game_name)
            if FilesManager.game_exists(new_game_name):
                new_game_name = FilesManager.get_unique_game_name(new_game_name)
            importing_game_name = new_game_name
    elif as_new_game and new_game_name:
        if FilesManager.game_exists(new_game_name):
            new_game_name = FilesManager.get_unique_game_name(new_game_name)
        importing_game_name = new_game_name
    
    FilesManager.create_game_directory_if_not_exists(importing_game_name)
    
    var result: = ImportZipExtractor.import_game_zip_with_backup(zip_file, importing_game_name)
    if not result.get("ok", false):
        return ""
    FilesManager.fix_game_name(importing_game_name)

    return importing_game_name

func export_game_zip(game_name: String, save_to_directory: String = "") -> String:
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

    var game_dir: = FilesManager.get_game_base_dir(game_name)
    var result: = ArchiveCopier.copy_and_zip_directory(game_dir, game_name)
    if not result.get("ok", false):
        return ""
    var zip_path: String = result.get("zip_path", "")
    if save_to_directory:
        var error: = DirAccess.rename_absolute(zip_path, save_to_directory.path_join(zip_path.get_file()))
        if error != OK:
            push_error("Failed to rename zip file to %s: %s" % [save_to_directory, error_string(error)])
            return zip_path
        return save_to_directory.path_join(zip_path.get_file()).simplify_path()
    else:
        return zip_path