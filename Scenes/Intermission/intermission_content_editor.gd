extends VBoxContainer

signal items_updated()

const IntermissionConfigItem = preload("res://Scenes/Intermission/intermission_config_item.gd")
var intermission_config_item_scn: PackedScene = preload("res://Scenes/Intermission/intermission_config_item.tscn")

@export var height_limit_parent: Control

@export var item_container: Control
@export var add_item_button: Button

@export var scroll_container: ScrollContainer
var scroll_container_content_control: Control

func _ready() -> void:
    if scroll_container and scroll_container.get_child_count() > 0:
        scroll_container_content_control = scroll_container.get_child(0) as Control

    add_item_button.pressed.connect(append_new_item)


func load_contents_info(contents_info: Array) -> void:
    clear_content_items()
    if contents_info.size() == 0:
        append_new_item()
        return

    for item_info in contents_info:
        add_item(item_info)
    adjust_scroll_container_height()
    refresh_order_buttons()

func get_contents_info() -> Array:
    var contents_info: Array = []
    for item in item_container.get_children():
        var item_info: Dictionary = item.get_item_info()
        if item_info.get("type", "text") == "text" and not item_info.get("text", ""):
            continue
        contents_info.append(item_info)
    return contents_info

func append_new_item() -> void:
    var blank_item_info: Dictionary = {
        "type": "text"
    }
    add_item(blank_item_info)
    adjust_scroll_container_height()
    refresh_order_buttons()

func add_item(item_info: Dictionary) -> IntermissionConfigItem:
    var item: = intermission_config_item_scn.instantiate() as IntermissionConfigItem
    item.request_move_relative.connect(move_item_relative.bind(item))
    item.request_move_top_bottom.connect(move_item_top_bottom.bind(item))
    item.request_remove.connect(remove_item.bind(item))
    item.item_updated.connect(on_item_updated)
    item_container.add_child(item)
    item.load_item_info(item_info)
    return item

func clear_content_items() -> void:
    for item in item_container.get_children():
        item_container.remove_child(item)
        item.queue_free()

func refresh_order_buttons() -> void:
    var max_index: int = item_container.get_child_count() - 1
    for item in item_container.get_children():
        item.refresh_order_buttons(max_index)


func move_item_relative(direction: int, item: IntermissionConfigItem) -> void:
    var new_index: int = item.get_index() + direction
    if new_index < 0 or new_index > item_container.get_child_count() - 1:
        return
    item_container.move_child(item, new_index)
    refresh_order_buttons()
    items_updated.emit()

func move_item_top_bottom(direction: int, item: IntermissionConfigItem) -> void:
    var new_index: int = 0 if direction == -1 else item_container.get_child_count() - 1
    item_container.move_child(item, new_index)
    refresh_order_buttons()
    items_updated.emit()

func remove_item(item: IntermissionConfigItem) -> void:
    item_container.remove_child(item)
    item.queue_free()
    if item_container.get_child_count() == 0:
        append_new_item()
    adjust_scroll_container_height()
    items_updated.emit()

func on_item_updated() -> void:
    adjust_scroll_container_height()
    items_updated.emit()

func adjust_scroll_container_height() -> void:
    _adjust_height.call_deferred()

func _adjust_height() -> void:
    if not height_limit_parent or not scroll_container_content_control:
        return
    
    var max_height: float = height_limit_parent.size.y - 50
    scroll_container.custom_minimum_size.y = 0
    var scroll_container_min_height: float = scroll_container.get_minimum_size().y
    var extra_height: float = get_minimum_size().y - scroll_container_min_height
    
    scroll_container_content_control.update_minimum_size()
    
    var scroll_contents_height: float = scroll_container_content_control.get_minimum_size().y
    if scroll_contents_height + extra_height + 10 > max_height:
        scroll_container.custom_minimum_size.y = max_height - 10
    else:
        scroll_container.custom_minimum_size.y = scroll_contents_height + 2