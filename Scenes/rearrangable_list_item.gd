extends HBoxContainer

const RearrangableListItem = preload("res://Scenes/rearrangable_list_item.gd")

signal request_move_relative(rearrangable_list_item: RearrangableListItem, relative_index: int)
signal request_context_menu(rearrangable_list_item: RearrangableListItem)
signal request_remove(rearrangable_list_item: RearrangableListItem)

@export var up_button: ButtonContainer
@export var down_button: ButtonContainer
@export var remove_button: ButtonContainer

@export var name_label: Label

func _ready() -> void:
    up_button.pressed.connect(request_move_relative.emit.bind(self, -1))
    down_button.pressed.connect(request_move_relative.emit.bind(self, 1))
    remove_button.pressed.connect(request_remove.emit.bind(self))

func set_list_name(new_name: String) -> void:
    name_label.text = new_name

func get_list_name() -> String:
    return name_label.text

func update_buttons_enable() -> void:
    var cur_index: = get_index()
    var total_lists: = get_parent().get_child_count()
    up_button.disabled = cur_index == 0
    down_button.disabled = cur_index == total_lists - 1

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.is_pressed():
        request_context_menu.emit(self)