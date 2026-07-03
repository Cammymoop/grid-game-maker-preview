extends OptionButton

@export var tooltips: Array[String] = []

var select_none_as_default: bool = false

var arg_name: String = ""

var has_default: bool = false
var default_value: String = ""

func _ready() -> void:
    var non_separator_indices: Array[int] = Utility.opbtn_enumerate_non_separator_idx(self)
    for i in non_separator_indices.size():
        if i < tooltips.size():
            set_item_tooltip(non_separator_indices[i], tooltips[i])
    item_selected.connect(on_item_selected)
    
    if select_none_as_default and get_item_count() > 0:
        selected = 0
    elif has_default:
        var def_idx: = Utility.opbtn_get_index_from_text(self, default_value)
        if def_idx >= 0:
            selected = def_idx

    if selected >= 0 and get_item_tooltip(selected):
        tooltip_text = get_item_tooltip(selected)

func set_input_args(new_args: Array) -> void:
    if not new_args:
        return
    var new_items: Array[String] = []
    var new_items_tooltip: String = ""
    var append_items: bool = false
    for arg in new_args:
        if arg.begins_with("default="):
            var default_val_str: String = arg.split("=")[1].strip_edges()
            if default_val_str == "NONE":
                has_default = false
                select_none_as_default = true
            elif default_val_str:
                has_default = true
                default_value = (arg.split("=")[1]).strip_edges()
        elif arg.begins_with("append="):
            var append_value: String = arg.split("=")[1].strip_edges().to_lower()
            if append_value != "false" and append_value != "0":
                append_items = true
        elif arg.begins_with("tt="):
            new_items_tooltip = arg.split("=")[1].strip_edges()
        elif not arg.contains("="):
            var item_str: String = arg.strip_edges()
            if item_str:
                new_items.append(arg.strip_edges())
    
    if new_items.size() > 0:
        if append_items:
            if new_items_tooltip and tooltips.size() < get_item_count():
                for i in range(tooltips.size(), get_item_count()):
                    tooltips.append(new_items_tooltip)
                    set_item_tooltip(i, new_items_tooltip)
        else:
            clear()
        for item in new_items:
            add_item(item)
            if new_items_tooltip:
                tooltips.append(new_items_tooltip)
                set_item_tooltip(get_item_count() - 1, new_items_tooltip)

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