extends OptionButton

@export var text_is_value: bool = true
@export var use_id: bool = true
var arg_name: String = ""

func set_arg_name(new_arg_name: String) -> void:
    arg_name = new_arg_name

func get_arg_name() -> String:
    return arg_name

func get_value() -> Variant:
    if text_is_value:
        return get_item_text(selected)
    elif use_id:
        return get_item_id(selected)
    else:
        return selected

func set_value(new_val: Variant) -> void:
    if text_is_value:
        _set_item_as_text(str(new_val))
    elif use_id:
        _set_id(int(new_val))
    else:
        select(int(new_val))

func _set_item_as_text(as_text: String) -> void:
    for i in get_item_count():
        if get_item_text(i) == as_text:
            select(i)
            return
    selected = -1

func _set_id(id: int) -> void:
    for i in get_item_count():
        if get_item_id(i) == id:
            select(i)
            return
    selected = -1
