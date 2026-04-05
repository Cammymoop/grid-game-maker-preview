extends Control

const LIST_SCRIPT := preload("res://src/Autocomplete/autocomplete_list.gd")

var _list: LIST_SCRIPT

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func acquire_menu(anchor: Control) -> Panel:
	if _list == null:
		_list = LIST_SCRIPT.new() as Panel
		add_child(_list)
	_list.set_anchor_control(anchor)
	return _list


func get_active_list() -> Panel:
	return _list
