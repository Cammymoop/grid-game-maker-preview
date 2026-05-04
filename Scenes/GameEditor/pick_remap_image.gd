extends ConfirmationDialog


@export var builtin_list: ItemList
@export var shared_list: ItemList
@export var bundled_list: ItemList

var picked_name: String = ""
var picked_is_builtin: bool = false
var picked_is_shared: bool = false

func _ready() -> void:
    close_requested.connect(close_dialog)
    setup_lists()
    builtin_list.item_activated.connect(on_image_picked.bind(builtin_list, true, false))
    builtin_list.item_selected.connect(on_list_item_selected.bind(builtin_list))
    shared_list.item_activated.connect(on_image_picked.bind(shared_list, false, true))
    shared_list.item_selected.connect(on_list_item_selected.bind(shared_list))
    bundled_list.item_activated.connect(on_image_picked.bind(bundled_list, false, false))
    bundled_list.item_selected.connect(on_list_item_selected.bind(bundled_list))

func on_image_picked(index: int, from_list: ItemList, is_builtin: bool, is_shared: bool) -> void:
    picked_name = from_list.get_item_text(index)
    picked_is_builtin = is_builtin
    picked_is_shared = is_shared
    get_ok_button().pressed.emit()

func on_list_item_selected(index: int, from_list: ItemList) -> void:
    for list in [builtin_list, shared_list, bundled_list]:
        if list == from_list:
            continue
        list.deselect_all()
    picked_name = from_list.get_item_text(index)
    picked_is_builtin = from_list == builtin_list
    picked_is_shared = from_list == shared_list

func setup_lists() -> void:
    builtin_list.clear()
    shared_list.clear()
    bundled_list.clear()

    var all_builtin_textures: Dictionary = TextureManager.get_all_builtin_textures()
    for texture_name in all_builtin_textures:
        builtin_list.add_item(texture_name)

    var all_shared_textures: Dictionary = TextureManager.get_all_shared_textures()
    for texture_name in all_shared_textures:
        shared_list.add_item(texture_name)

    var all_bundled_textures: Dictionary = TextureManager.get_all_bundled_textures()
    for texture_name in all_bundled_textures:
        bundled_list.add_item(texture_name)

func close_dialog() -> void:
    queue_free()