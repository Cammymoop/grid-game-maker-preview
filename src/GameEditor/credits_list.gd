extends VBoxContainer

var credits_list_item_scene = preload("res://Scenes/GameEditor/credits_list_item.tscn")

func _ready() -> void:
    load_credits_list()

func get_credits_list() -> Array:
    var credits_list: Array = []
    for child in get_children():
        if not child.has_method("get_entry"):
            continue
        var entry = child.get_entry()
        if empty_credits_item(entry):
            continue
        credits_list.append(entry)
    return credits_list

func empty_credits_item(item: Dictionary) -> bool:
    if not item:
        return true
    if not item.get("type", "") and not item.get("role", "") and not item.get("name", ""):
        return true
    return false

func clear_credits_list() -> void:
    for child in get_children():
        if child.has_method("get_entry"):
            remove_child(child)
            child.queue_free()

func load_credits_list() -> void:
    clear_credits_list()
    var credits_list: Array = GameManager.get_credits_info().get("credits_list", [])
    if credits_list.size() == 0:
        append_new_credit_item({})
    else:
        for entry in credits_list:
            append_new_credit_item(entry)

func _on_new_credit_item_pressed() -> void:
    append_new_credit_item({})
    
func append_new_credit_item(with_entry: Dictionary) -> void:
    var new_credit_item = credits_list_item_scene.instantiate()
    if with_entry:
        new_credit_item.set_entry(with_entry)
    add_child(new_credit_item)
    move_child(new_credit_item, get_child_count() - 2)
    new_credit_item.changed.connect(on_credit_changed)

func num_input_lines() -> int:
    return get_child_count() - 2

func on_credit_changed() -> void:
    update_credits_list()

func update_credits_list() -> void:
    var credits_list: Array = get_credits_list()
    GameManager.set_credits_info({"credits_list": credits_list})

func goto_view_credits() -> void:
    GameManager.show_credits()