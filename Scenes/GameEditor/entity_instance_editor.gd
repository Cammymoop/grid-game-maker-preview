extends Control

const PropertyEditList = preload("res://Scenes/GameEditor/property_edit_list.gd")

@export var auto_pick_entity: bool = true

@export var property_edit_list: PropertyEditList


var edited_entity: BaseEntity = null

func _ready() -> void:
    hide()

func find_auto_pick() -> void:
    if auto_pick_entity:
        var auto_picked_entity = EntityManager.find_entity_with_property("player")
        if auto_picked_entity:
            open_instance_editor(auto_picked_entity)


func open_instance_editor(entity: BaseEntity) -> void:
    if not entity:
        return
    show()
    prints("editing entity: ", entity.get_path())
    edited_entity = entity
    prints(edited_entity, "me", get_path())
    if property_edit_list:
        property_edit_list.load_entity_instance_properties(entity)
