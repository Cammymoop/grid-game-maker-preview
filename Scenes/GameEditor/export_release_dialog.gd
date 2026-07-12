extends Window

const Vector2iInput = preload("res://src/GameEditor/ConditionalEditor/vector2i_input.gd")

signal hidden
signal request_edited_export


@export var exisiting_releases_list: ItemList
@export var re_export_release_version_button: Button

@export var show_when_locked_container: Control
@export var show_when_unlocked_container: Control

@export var export_current_locked_button: Button

@export var release_version_input: Vector2iInput
@export var create_release_button: Button

@export var inlcude_non_bundled_levels_toggle: CheckButton
@export var export_as_edited_button: Button

@export var create_release_version_label: Label
@export var locked_version_label: Label


@export var pre_export_container: Control
@export var save_export_container: Control

@export var new_zip_path_label: Label
@export var save_download_zip_button: Button

@export var cancel_button: Button
@export var close_button: Button

var edited_version_number: Vector2i = Vector2i.ZERO
var has_edited_version_number: bool = false

var path_to_current_locked_version_zip: String = ""

var new_zip_path: String = ""

var reload_scene_on_close: bool = false

func _ready() -> void:
    visibility_changed.connect(_on_vis_changed)
    close_requested.connect(close_dialog)
    cancel_button.pressed.connect(close_dialog)
    close_button.pressed.connect(close_dialog)
    
    save_export_container.hide()
    pre_export_container.show()
    
    create_release_button.pressed.connect(on_create_release_button_pressed)
    export_as_edited_button.pressed.connect(on_export_as_edited_button_pressed)
    export_current_locked_button.pressed.connect(on_export_current_locked_button_pressed)
    re_export_release_version_button.pressed.connect(on_re_export_release_version_button_pressed)
    
    release_version_input.value_changed.connect(on_release_version_input_value_changed)
    
    save_download_zip_button.pressed.connect(on_save_download_zip_button_pressed)
    
    load_releases_list()
    
    if GameManager.current_game_is_release_locked:
        show_locked_ui()
    else:
        show_unlocked_ui()

func _unhandled_input(event: InputEvent) -> void:
    if not visible:
        return
    if Utility.event_is_menu_back_just_pressed(event):
        set_input_as_handled()
        close_dialog()

func show_locked_ui() -> void:
    locked_version_label.text = GameManager.get_full_version_string()

    show_when_locked_container.show()
    show_when_unlocked_container.hide()

func show_unlocked_ui() -> void:
    show_when_locked_container.hide()
    show_when_unlocked_container.show()
    
    
    var next_version_vec: = Utility.get_vector2i_from_arr(GameManager.game_definition["release_info"]["next_version"])
    release_version_input.set_value(next_version_vec)
    
    update_create_release_version_label(next_version_vec)

func on_release_version_input_value_changed(value: Vector2i) -> void:
    has_edited_version_number = true
    edited_version_number = value
    update_create_release_version_label(value)
    

func update_create_release_version_label(with_version_number: Vector2i) -> void:
    var game_id: String = GameManager.get_identified_game_name(true)
    create_release_version_label.text = game_id + " " + Utility.version_vec_to_string(with_version_number)


func load_releases_list() -> void:
    path_to_current_locked_version_zip = ""
    var versions_info: = FilesManager.enumerate_and_fetch_data_for_all_versions_of_game(GameManager.get_identified_game_name())
    
    var released_version_count: int = versions_info.get("release_versions", {}).size()
    exisiting_releases_list.clear()
    re_export_release_version_button.disabled = released_version_count < 1
    
    if released_version_count < 1:
        return
    
    var release_versions: Dictionary = versions_info.get("release_versions", {})
    for version_zip_filename in release_versions.keys():
        var version_info: Dictionary = release_versions[version_zip_filename]
        var display_version: String = FilesManager.friendly_version_string_from_version_info(version_info, false)
        display_version += " [Created: " + version_info["release_created_local_date"] + "]"

        var item_index: int = exisiting_releases_list.add_item(display_version)
        exisiting_releases_list.set_item_metadata(item_index, version_info["full_zip_path"])
        exisiting_releases_list.set_item_tooltip(item_index, version_zip_filename)
        
        if GameManager.current_game_is_release_locked:
            var current_hash: String = GameManager.game_definition["release_info"]["release_hash"]
            if current_hash and current_hash == version_info["game_definition"]["release_info"].get("release_hash", ""):
                path_to_current_locked_version_zip = version_info["full_zip_path"]
    

func on_create_release_button_pressed() -> void:
    if has_edited_version_number:
        GameManager.game_definition["release_info"]["next_version"] = Utility.get_arr_from_vector2i(edited_version_number)
    var zip_file_path: String = GameManager.create_released_version()
    if not zip_file_path:
        GlobalToaster.show_toast_message("Unable to create release version :(\nPlease report this tragedy to Cammymoop", 2.0)
        close_dialog()
        return
    else:
        prompt_to_export_existing_zip(zip_file_path, true)


func on_export_as_edited_button_pressed() -> void:
    request_edited_export.emit()
    close_dialog()

func on_export_current_locked_button_pressed() -> void:
    if path_to_current_locked_version_zip:
        prompt_to_export_existing_zip(path_to_current_locked_version_zip, false)
    else:
        var zip_file_path: String = GameManager.export_current_release_mode()
        if not zip_file_path:
            GlobalToaster.show_toast_message("Unable to find or create the zip for the\ncurrent release version, please report!", 2.8)
            close_dialog()
            return
        else:
            prompt_to_export_existing_zip(zip_file_path, true)

func on_re_export_release_version_button_pressed() -> void:
    var selected_items: = exisiting_releases_list.get_selected_items()
    if selected_items.size() < 1:
        return
    var item_index: int = selected_items[0]
    prompt_to_export_existing_zip(exisiting_releases_list.get_item_metadata(item_index), false)


func close_dialog() -> void:
    if visible:
        hide()
    if reload_scene_on_close:
        GameManager.change_scene("GameEditor", true)
    queue_free()

func _on_vis_changed() -> void:
    if not visible:
        hidden.emit()

func on_save_download_zip_button_pressed() -> void:
    prompt_to_export_existing_zip(new_zip_path, false)

func prompt_to_export_existing_zip(zip_file_path: String, is_newly_created: bool) -> void:
    if is_newly_created:
        if GameManager.cur_scene == "GameEditor":
            reload_scene_on_close = true
        pre_export_container.hide()
        save_export_container.show()
        
        new_zip_path_label.text = "<game folder>/other_versions/releases/" + zip_file_path.get_file()
        new_zip_path = zip_file_path
        return
    
    close_dialog()
    GameManager.show_save_game_zip_dialog(zip_file_path)