extends VBoxContainer

const InfoItem = preload("res://Scenes/UI/info_item.gd")
const info_item_scn: PackedScene = preload("res://Scenes/UI/info_item.tscn")

signal info_updated()

func _ready() -> void:
    for info_item in get_children():
        if info_item is InfoItem:
            info_item.info_updated.connect(on_info_item_updated)

func on_info_item_updated() -> void:
    info_updated.emit()

func add_info_item() -> InfoItem:
    var new_info_item: = info_item_scn.instantiate() as InfoItem
    new_info_item.info_updated.connect(on_info_item_updated)
    add_child(new_info_item)
    info_updated.emit()
    return new_info_item


func clear_items() -> void:
    for info_item in get_children():
        remove_child(info_item)
        info_item.queue_free()