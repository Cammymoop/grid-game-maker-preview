extends OptionButton

@export var tooltips: Array[String] = []

var arg_name: String = ""

func _ready() -> void:
    var non_separator_indices: Array[int] = Utility.opbtn_enumerate_non_separator_idx(self)
    for i in non_separator_indices.size():
        if i < tooltips.size():
            set_item_tooltip(non_separator_indices[i], tooltips[i])
    item_selected.connect(on_item_selected)
    if selected >= 0 and get_item_tooltip(selected):
        tooltip_text = get_item_tooltip(selected)

func on_item_selected(index: int) -> void:
    if get_item_tooltip(index):
        tooltip_text = get_item_tooltip(index)
    else:
        tooltip_text = ""

func set_arg_name(new_arg_name: String) -> void:
    arg_name = new_arg_name

func get_arg_name() -> String:
    return arg_name

func get_value() -> String:
    return get_item_text(selected)

func set_value(new_val: String) -> void:
    Utility.opbtn_select_text(self, new_val)