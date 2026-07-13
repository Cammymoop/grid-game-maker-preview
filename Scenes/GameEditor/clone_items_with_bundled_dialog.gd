extends ConfirmationDialog

var image_item_scn: = preload("res://Scenes/UI/just_name_and_image.tscn")

@export var list_container: Control

@export var dont_show_again_toggle: CheckButton


func _ready() -> void:
    close_requested.connect(close_dialog)
    confirmed.connect(on_confirmed)
    
    visibility_changed.connect(on_visibility_changed)

func on_visibility_changed() -> void:
    if visible:
        dont_show_again_toggle.set_pressed_no_signal(false)

func _unhandled_input(event: InputEvent) -> void:
    if Utility.event_is_menu_back_just_pressed(event):
        close_dialog()

func set_textures(image_names: Array[String], image_textures: Array[Texture2D]) -> void:
    clear_list()
    
    for i in image_names.size():
        var image_item: = image_item_scn.instantiate()
        list_container.add_child(image_item)
        image_item.set_name_and_image(image_names[i], image_textures[i])

func clear_list() -> void:
    for child in list_container.get_children():
        list_container.remove_child(child)
        child.queue_free()

func close_dialog() -> void:
    hide()

func on_confirmed() -> void:
    if dont_show_again_toggle.button_pressed:
        GameManager.set_one_time_message_dismissed(GameManager.OneTimeMessages.CLONE_ITEMS_WITH_BUNDLED_IMAGES)
    close_dialog()