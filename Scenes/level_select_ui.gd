extends VBoxContainer

signal close_level_select()

const SingleLevelList = preload("res://Scenes/single_level_list.gd")

var single_level_list_scene: = preload("res://Scenes/single_level_list.tscn")

@export var level_list_container: Control


func _ready() -> void:
    load_unlocked_level_lists()

func load_unlocked_level_lists() -> void:
    clear_level_lists()
    for unlocked_level_list in GameManager.get_all_unlocked_level_lists():
        _add_level_list(unlocked_level_list)

func _add_level_list(level_list_info: Dictionary) -> void:
    var single_level_list: SingleLevelList = single_level_list_scene.instantiate()
    single_level_list.play_level.connect(on_level_list_play_level)
    level_list_container.add_child(single_level_list)
    single_level_list.load_level_list_info(level_list_info)

func clear_level_lists() -> void:
    for child in level_list_container.get_children():
        level_list_container.remove_child(child)
        child.queue_free()

func on_level_list_play_level(level_list_name: String, level_name: String) -> void:
    close()
    if GameManager.is_in_level_edit_mode:
        GameManager.current_level_list = level_list_name
        GameManager.try_load_level(level_name)
    else:
        GameManager.goto_level_in_level_list(level_list_name, level_name)

func close() -> void:
    close_level_select.emit()
    