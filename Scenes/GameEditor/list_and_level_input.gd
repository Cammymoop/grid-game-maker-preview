extends HBoxContainer

signal value_changed

const LevelListNameInput = preload("res://Scenes/GameEditor/ConditionalEditor/level_list_name_input.gd")
const LevelNameInput = preload("res://Scenes/GameEditor/ConditionalEditor/level_name_input.gd")

@export var list_input: LevelListNameInput
@export var level_name_input: LevelNameInput

@export var require_list: bool = true
@export var only_bundled: bool = true


var arg_name: String

func _ready() -> void:
    list_input.either_value_changed.connect(on_sub_value_changed)

func get_arg_name() -> String:
    return arg_name

func set_arg_name(new_arg_name: String) -> void:
    arg_name = new_arg_name


func get_value() -> String:
    var list_name_complex: Dictionary = list_input.get_value()
    var list_name: = ""
    if list_name_complex.get("type") == "plain":
        list_name = list_name_complex.get("value", "")
    
    var level_name_complex: Dictionary = level_name_input.get_value()
    var level_name: = ""
    if level_name_complex.get("type") == "plain":
        level_name = level_name_complex.get("value", "")
    
    if require_list and not list_name:
        if level_name and GameManager.is_level_bundled(level_name):
            list_name = GameManager.get_list_containing_level(level_name)
    if require_list and not list_name:
        return ""
    
    return GameManager.make_level_code(list_name, level_name)

func set_value(new_value: String) -> void:
    var split_code: Array[String] = GameManager.split_level_code(new_value)
    var list_name: String = split_code[0]
    var level_name: String = split_code[1]

    list_input.set_value({"type": "plain", "value": list_name})
    level_name_input.set_value({"type": "plain", "value": level_name})

func on_sub_value_changed() -> void:
    value_changed.emit()