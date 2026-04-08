extends Control

signal order_changed(new_items: Array)

var list_item_scn: PackedScene = preload("res://Scenes/GameEditor/ControllerOptions/reorderable_item.tscn")

@export var list_container: Control

func set_items(items: Array) -> void:
    clear_items()
    if not is_inside_tree():
        await ready
    for item in items:
        add_new_item(item)
    update_items_up_down_enabled()

func add_new_item(item_text: String) -> void:
    var item_node: = list_item_scn.instantiate() as Control
    set_signals_on_item(item_node)
    list_container.add_child(item_node)
    item_node.get_node("ItemLabel").text = item_text

func set_signals_on_item(item_node: Control) -> void:
    item_node.find_child("UpButton").pressed.connect(_on_up_button_pressed.bind(item_node))
    item_node.find_child("DownButton").pressed.connect(_on_down_button_pressed.bind(item_node))

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
        list_container.remove_child(child)
        child.queue_free()

func move_item_relative(amount: int, item_node: Control) -> void:
    var current_index: int = item_node.get_index()
    if current_index + amount < 0 or current_index + amount >= list_container.get_child_count():
        return
    list_container.move_child(item_node, current_index + amount)
    update_items_up_down_enabled()
    order_changed.emit(get_items())

func update_items_up_down_enabled() -> void:
    for i in range(list_container.get_child_count()):
        var up_disabled: bool = i == 0
        var down_disabled: bool = i == list_container.get_child_count() - 1
        var item_node: Control = get_list_item(i)
        item_node.find_child("UpButton").disabled = up_disabled
        item_node.find_child("DownButton").disabled = down_disabled

func _on_up_button_pressed(list_item: Control) -> void:
    move_item_relative(-1, list_item)

func _on_down_button_pressed(list_item: Control) -> void:
    move_item_relative(1, list_item)
