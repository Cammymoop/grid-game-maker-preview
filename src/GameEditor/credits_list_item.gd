extends HBoxContainer

signal changed

@export var type_picker: OptionButton
@export var input_1: LineEdit
@export var input_2: LineEdit

const TYPE_ROLE_NAME: String = "role_name"
const TYPE_JUST_NAME: String = "just_name"
const TYPE_SECTION: String = "section"

const TYPE_STRINGS: Dictionary[String, String] = {
    TYPE_ROLE_NAME: "Role & Name",
    TYPE_JUST_NAME: "Just Name",
    TYPE_SECTION: "Section",
}

var entry: Dictionary = {}

func _ready() -> void:
    setup_type_picker()
    type_picker.item_selected.connect(on_type_selected)
    var remove_button = find_child("RemoveCreditItemButton")
    remove_button.pressed.connect(remove_this_credit)
    refresh_ui()
    
    input_1.text_changed.connect(on_text_changed)
    input_2.text_changed.connect(on_text_changed)

func on_text_changed(_new_text: String) -> void:
    changed.emit()

func cur_selected_type_str() -> String:
    var type_int_id: int = cur_selected_type_int_id()
    if type_int_id == -1:
        return ""
    return TYPE_STRINGS.keys()[type_int_id]

func cur_selected_type_int_id() -> int:
    return Utility.opbtn_get_selected_id(type_picker)

func get_entry() -> Dictionary:
    var type_str: String = cur_selected_type_str()
    if type_str == "":
        type_str = TYPE_ROLE_NAME

    var ret_entry: Dictionary = { "type": type_str }
    if type_str == TYPE_ROLE_NAME:
        ret_entry["role"] = input_1.text.strip_edges()
        ret_entry["name"] = input_2.text.strip_edges()
    elif type_str == TYPE_JUST_NAME:
        ret_entry["name"] = input_1.text.strip_edges()
    elif type_str == TYPE_SECTION:
        ret_entry["text"] = input_1.text.strip_edges()
    return ret_entry

func set_entry(entry_data: Dictionary) -> void:
    entry = entry_data.duplicate_deep()
    var type_int_id: int = TYPE_STRINGS.keys().find(entry.get("type", TYPE_ROLE_NAME))
    if type_int_id == -1:
        type_int_id = 0
    Utility.opbtn_select_id(type_picker, type_int_id)
    refresh_ui()

func refresh_ui() -> void:
    if not is_inside_tree():
        return
    var type_int_id: int = cur_selected_type_int_id()
    if type_int_id == -1:
        type_int_id = 0
    Utility.opbtn_select_id(type_picker, type_int_id)
    
    var cur_type: String = cur_selected_type_str()
    if cur_type == TYPE_ROLE_NAME:
        input_1.text = entry.get("role", "")
        input_2.text = entry.get("name", "")
        input_2.visible = true
    elif cur_type == TYPE_JUST_NAME:
        input_1.text = entry.get("name", "")
        input_2.visible = false
    elif cur_type == TYPE_SECTION:
        input_1.text = entry.get("text", "")
        input_2.visible = false

func remove_this_credit() -> void:
    if get_parent().num_input_lines() == 1:
        clear()
    else:
        get_parent().remove_child(self)
        queue_free()
    changed.emit()

func clear() -> void:
    input_1.text = ""
    input_2.text = ""

func setup_type_picker() -> void:
    type_picker.clear()
    for index in TYPE_STRINGS.size():
        var type_str: String = TYPE_STRINGS.keys()[index]
        type_picker.add_item(TYPE_STRINGS[type_str], index)
    type_picker.selected = 0

func on_type_selected(index: int) -> void:
    var type_str: String = TYPE_STRINGS.keys()[type_picker.get_item_id(index)]
    entry["type"] = type_str
    refresh_ui()
