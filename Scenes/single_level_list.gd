extends VBoxContainer

signal play_level(level_list_name: String, level_name: String)

var level_item_scene: = preload("res://Scenes/level_list_item.tscn")

@export var level_item_container: Container

var level_list_name: String = ""

func load_level_list_info(level_list_info: Dictionary) -> void:
    set_level_list_name(level_list_info.get("name", ""))
    var existing_levels: Array = []
    for level_name in level_list_info.get("level_names", []):
        if FilesManager.level_exists(GameManager.cur_game_name, level_name):
            existing_levels.append(level_name)
    set_levels(existing_levels)

func set_level_list_name(new_level_list_name: String) -> void:
    level_list_name = new_level_list_name

func set_levels(level_name_list: Array) -> void:
    clear_level_items()
    for level_name in level_name_list:
        var level_title: = FilesManager.get_level_title(GameManager.cur_game_name, level_name)
        _add_level_item(level_name, level_title)

func _add_level_item(with_level_name: String, with_level_title: String) -> void:
    var level_item: Control = level_item_scene.instantiate()
    level_item.set_level_name_and_title(with_level_name, with_level_title)
    level_item.play_level.connect(on_level_item_play_level)
    level_item_container.add_child(level_item)

func on_level_item_play_level(level_name: String) -> void:
    if not level_list_name:
        push_warning("Level list name is not set for level list %s" % [get_path()])
        return
    play_level.emit(level_list_name, level_name)

func clear_level_items() -> void:
    for child in level_item_container.get_children():
        level_item_container.remove_child(child)
        child.queue_free()