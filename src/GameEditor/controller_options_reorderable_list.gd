extends Control

signal order_changed(new_items: Array)

@export var list_container: Control

func set_items(items: Array) -> void:
    clear_items()
    for item in items:
        add_new_item(item)

func add_new_item(item_text: String) -> void:
    var item_node: Control = get_list_item(0)
    if item_node.visible:
        item_node = item_node.duplicate(Node.DUPLICATE_SIGNALS)
        list_container.add_child(item_node)
    else:
        item_node.visible = true
    item_node.get_node("ItemLabel").text = item_text
    prints("Added new item:", item_text, "cur item count:", list_container.get_child_count(), " -- ", item_node.get_path())

func get_list_item(item_index: int) -> Control:
    return list_container.get_child(item_index)

func get_items() -> Array:
    var items: Array = []
    for child in list_container.get_children():
        var item_label: Label = child.get_node("ItemLabel")
        items.append(item_label.text)
    return items

func clear_items() -> void:
    for child in list_container.get_children():
        if child.get_index() == 0:
            child.get_node("ItemLabel").text = ""
            child.visible = false
        else:
            list_container.remove_child(child)
            child.queue_free()

func move_item_relative(amount: int, item_node: Control) -> void:
    var current_index: int = item_node.get_index()
    if current_index + amount < 0 or current_index + amount >= list_container.get_child_count():
        return
    list_container.move_child(item_node, current_index + amount)
    order_changed.emit(get_items())

func _on_up_button_pressed(btn: BaseButton) -> void:
    var item_node: Control = btn.get_parent()
    move_item_relative(-1, item_node)

func _on_down_button_pressed(btn: BaseButton) -> void:
    var item_node: Control = btn.get_parent()
    move_item_relative(1, item_node)
