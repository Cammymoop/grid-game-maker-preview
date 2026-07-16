extends Control

const IntermissionText = preload("res://Scenes/Intermission/intermission_text.gd")
const CreditsImage = preload("res://Scenes/credits_image.gd")

var intermission_text_scn: = preload("res://Scenes/Intermission/intermission_text.tscn")
var credits_image_scn: = preload("res://Scenes/credits_image.tscn")

@export var dark_bg: Control
@export var light_bg: Control

@export var content_section: Control
@export var continue_section: Control

func setup(intermission_id: String) -> void:
    var intermission_info: Dictionary = GameManager.get_intermission_info(intermission_id)
    setup_with_info(intermission_info)

func setup_with_info(intermission_info: Dictionary) -> void:
    clear_content()
    
    var content_items: Array = intermission_info.get("content_items", [])
    content_section.visible = content_items.size() > 0
    for item_info in content_items:
        append_item(item_info)
    
    var show_continue: bool = intermission_info.get("show_continue", true)
    continue_section.visible = show_continue

func append_item(item_info: Dictionary) -> void:
    pass

func clear_content() -> void:
    for child in content_section.get_children():
        content_section.remove_child(child)
        child.queue_free()