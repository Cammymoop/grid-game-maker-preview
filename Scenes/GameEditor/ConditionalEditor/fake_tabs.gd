extends HBoxContainer

signal request_change_tab(tab_index: int)

const NO_CONTENT_DISABLED_STYLE: StyleBoxFlat = preload("res://src/UI/tab_button_deselected.tres")

@onready var true_tab = find_child("TrueTabButton")
@onready var true_deselected: StyleBoxFlat = true_tab.get_theme_stylebox("normal")
@onready var false_tab = find_child("FalseTabButton")
@onready var false_deselected: StyleBoxFlat = false_tab.get_theme_stylebox("normal")
@onready var always_tab = find_child("AlwaysTabButton")
@onready var always_deselected: StyleBoxFlat = always_tab.get_theme_stylebox("normal")

@onready var tabs: = [true_tab, false_tab, always_tab]
@onready var content_styles: = [true_deselected, false_deselected, always_deselected]

var current_tab_index: int = 0

func _ready() -> void:
    for i in tabs.size():
        var tab_button: Button = tabs[i]
        tab_button.pressed.connect(tab_pressed.bind(i))
    _set_tab_button_pressed(current_tab_index)

func get_current_tab_border_color() -> Color:
    var cur_tab: Button = tabs[current_tab_index]
    var tab_pressed_sb: StyleBoxFlat = cur_tab.get_theme_stylebox("pressed")
    return tab_pressed_sb.bg_color

func update_no_content_styles(content_flags: Array) -> void:
    for i in tabs.size():
        if content_flags[i]:
            tabs[i].add_theme_stylebox_override("normal", content_styles[i])
        else:
            tabs[i].add_theme_stylebox_override("normal", NO_CONTENT_DISABLED_STYLE)

func set_tab_index(tab_index: int) -> void:
    current_tab_index = tab_index
    reset_tab_buttons()
    _set_tab_button_pressed(tab_index)

func reset_tab_buttons() -> void:
    for tab_button in tabs:
        tab_button.button_pressed = false
        tab_button.z_index = 0

func _set_tab_button_pressed(tab_index: int) -> void:
    tabs[tab_index].set_pressed_no_signal(true)
    tabs[tab_index].z_index = 1

func tab_pressed(tab_index: int) -> void:
    request_change_tab.emit(tab_index)