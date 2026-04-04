extends HBoxContainer

signal changed

@onready var role_input = find_child("RoleInput")
@onready var name_input = find_child("NameInput")

var entry: Dictionary = {}

func _ready() -> void:
    var remove_button = find_child("RemoveCreditItemButton")
    remove_button.pressed.connect(remove_this_credit)
    update_text()
    
    role_input.text_changed.connect(on_text_changed)
    name_input.text_changed.connect(on_text_changed)

func on_text_changed(_new_text: String) -> void:
    changed.emit()

func get_entry() -> Dictionary:
    entry = {
        "role": role_input.text.strip_edges(),
        "name": name_input.text.strip_edges(),
    }
    return entry

func set_entry(entry_data: Dictionary) -> void:
    entry = entry_data.duplicate_deep()
    update_text()

func update_text() -> void:
    if not is_inside_tree():
        return
    role_input.text = entry.get("role", "")
    name_input.text = entry.get("name", "")

func remove_this_credit() -> void:
    if get_parent().num_input_lines() == 1:
        clear()
    else:
        get_parent().remove_child(self)
        queue_free()
    changed.emit()

func clear() -> void:
    role_input.text = ""
    name_input.text = ""
