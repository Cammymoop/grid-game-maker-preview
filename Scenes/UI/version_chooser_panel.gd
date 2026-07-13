extends PanelContainer

signal request_back()

@export var current_version_label: Label

@export var save_current_backup_toggle: CheckButton

@export var release_versions_container: Control
@export var other_versions_container: Control

@export var release_versions_list: ItemList
@export var other_versions_list: ItemList

@export var use_release_version_button: Button
@export var use_other_version_button: Button

@export var back_button: Button

func _ready() -> void:
    
    use_release_version_button.pressed.connect(on_use_release_version_button_pressed)
    use_other_version_button.pressed.connect(on_use_other_version_button_pressed)
    
    release_versions_list.item_activated.connect(on_release_versions_list_item_activated)
    other_versions_list.item_activated.connect(on_other_versions_list_item_activated)

    back_button.pressed.connect(request_back.emit)
    
    refresh_ui()

func _shortcut_input(event: InputEvent) -> void:
    if Utility.event_is_menu_back_just_pressed(event):
        request_back.emit()
        accept_event()

func refresh_ui() -> void:
    current_version_label.text = GameManager.get_full_version_string()

    var is_release_locked: bool = GameManager.current_game_is_release_locked
    save_current_backup_toggle.set_pressed_no_signal(false)
    save_current_backup_toggle.visible = not is_release_locked


func on_use_release_version_button_pressed() -> void:
    _chose_index_from_list(release_versions_list)

func on_use_other_version_button_pressed() -> void:
    _chose_index_from_list(release_versions_list)

func on_release_versions_list_item_activated(index: int) -> void:
    load_chosen_version(release_versions_list.get_item_metadata(index))

func on_other_versions_list_item_activated(index: int) -> void:
    load_chosen_version(other_versions_list.get_item_metadata(index))

func _chose_index_from_list(list: ItemList) -> void:
    var selection: = list.get_selected_items()
    if selection.size() == 0:
        return
    var version_zip_path: String = release_versions_list.get_item_metadata(selection[0])
    load_chosen_version(version_zip_path)

func load_chosen_version(version_zip_path: String) -> void:
    GameManager.load_game_version_from_zip_file(version_zip_path)
    request_back.emit()


func show_and_load_version_infos() -> void:
    show()
    refresh_ui()
    
    var version_infos: Dictionary = FilesManager.enumerate_and_fetch_data_for_all_versions_of_game(GameManager.get_identified_game_name())
    
    if version_infos["release_versions"].size() + version_infos["other_versions"].size() == 0:
        request_back.emit()
        GlobalToaster.show_toast_message("No other versions to switch to")
        return

    #breakpoint

    release_versions_list.clear()
    other_versions_list.clear()
    
    if version_infos["release_versions"].size() == 0:
        release_versions_container.hide()
    else:
        release_versions_container.show()
        
        for version_info_zip in version_infos["release_versions"]:
            var version_info: Dictionary = version_infos["release_versions"][version_info_zip]
            if not version_info["name_matches"]:
                continue
            var display_version: String = FilesManager.friendly_version_string_from_version_info(version_info, false)
            var release_date: String = version_info["release_created_local_date"]
            var item_text: String = display_version + " " + release_date
            var item_index: int = release_versions_list.add_item(item_text)
            release_versions_list.set_item_metadata(item_index, version_info["full_zip_path"])

    if version_infos["other_versions"].size() == 0:
        other_versions_container.hide()
    else:
        other_versions_container.show()
        
        for version_info_zip in version_infos["other_versions"]:
            var version_info: Dictionary = version_infos["other_versions"][version_info_zip]
            if not version_info["name_matches"]:
                continue
            var display_version: String = FilesManager.friendly_version_string_from_version_info(version_info, false)
            var item_text: String = version_info_zip.trim_suffix(".zip") + " " + display_version
            var item_index: int = other_versions_list.add_item(item_text)
            other_versions_list.set_item_metadata(item_index, version_info["full_zip_path"])
        
