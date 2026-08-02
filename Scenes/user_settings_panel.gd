extends PanelContainer

signal request_back()

@export var mute_audio_toggle: CheckButton

@export var erase_game_save_progress_button: ButtonContainer
@export var erase_profile_button: ButtonContainer

@export var auto_save_definition_toggle: CheckButton
@export var skip_non_critical_confirm_toggle: CheckButton
@export var show_version_switcher_toggle: CheckButton

@export var profile_name_label: Label

@export var profile_identifier_input: LineEdit

@export var danger_zone_container: FoldableContainer

@export var back_button: Button

var confirm_dialog_open: bool = false

func _ready() -> void:
    visibility_changed.connect(on_visibility_changed)

    back_button.pressed.connect(request_back.emit)

    mute_audio_toggle.toggled.connect(on_mute_audio_toggle_toggled)
    
    auto_save_definition_toggle.toggled.connect(on_auto_save_definition_toggle_toggled)
    skip_non_critical_confirm_toggle.toggled.connect(on_skip_non_critical_confirm_toggle_toggled)
    show_version_switcher_toggle.toggled.connect(on_show_version_switcher_toggle_toggled)
    
    erase_game_save_progress_button.pressed.connect(on_erase_game_save_progress_button_pressed)
    erase_profile_button.pressed.connect(on_erase_profile_button_pressed)
    
    profile_identifier_input.text_changed.connect(on_profile_identifier_text_changed)

    refresh_ui()

func _shortcut_input(event: InputEvent) -> void:
    if not is_visible_in_tree():
        return
    if Utility.event_is_menu_back_just_pressed(event):
        request_back.emit()
        accept_event()

func on_visibility_changed() -> void:
    if is_visible_in_tree():
        danger_zone_container.fold()

func show_and_refresh() -> void:
    show()
    refresh_ui()

func refresh_ui() -> void:
    var is_muted: bool = GameManager.player_profile.get_profile_setting("mute_all_audio", false)
    mute_audio_toggle.set_pressed_no_signal(is_muted)
    
    var is_auto_saving: bool = GameManager.player_profile.get_profile_setting("auto_save_definition", true)
    auto_save_definition_toggle.set_pressed_no_signal(is_auto_saving)
    
    var is_skip_non_critical: bool = GameManager.player_profile.get_profile_setting("skip_non_critical_save_dialogs", false)
    skip_non_critical_confirm_toggle.set_pressed_no_signal(is_skip_non_critical)
    
    var is_show_version_switcher: bool = GameManager.player_profile.get_profile_setting("main_menu_version_switcher", false)
    show_version_switcher_toggle.set_pressed_no_signal(is_show_version_switcher)
    
    profile_name_label.text = "For Profile: %s" % [GameManager.get_profile_name()]
    
    var profile_count: int = FilesManager.get_player_profile_list().size()
    
    var is_save_empty: bool = GameManager.is_current_game_save_empty()
    erase_game_save_progress_button.disabled = is_save_empty

    erase_profile_button.disabled = profile_count <= 1


func on_mute_audio_toggle_toggled(is_muted: bool) -> void:
    GameManager.player_profile.set_profile_setting("mute_all_audio", is_muted)
    GameManager.update_mute()


func on_erase_game_save_progress_button_pressed() -> void:
    if confirm_dialog_open:
        return

    var game_name: String = GameManager.get_identified_game_name()
    var game_title: String = GameManager.get_game_title()
    var confirm_dialog: = ConfirmationDialog.new()
    confirm_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
    confirm_dialog.title = "Reset Game Save Progress?"
    confirm_dialog.dialog_text = "Are you sure you want to reset all progress for '%s'?" % [game_title]
    
    confirm_dialog.confirmed.connect(erase_progress_confirmed.bind(confirm_dialog, game_name))
    confirm_dialog.canceled.connect(dialog_closing.bind(confirm_dialog))
    
    confirm_dialog.ok_button_text = "Reset Progress"
    
    confirm_dialog_open = true
    confirm_dialog.popup_exclusive_centered(self)

func on_erase_profile_button_pressed() -> void:
    if confirm_dialog_open:
        return

    var profile_name: String = GameManager.get_profile_name()
    var confirm_dialog: = ConfirmationDialog.new()
    confirm_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
    confirm_dialog.title = "Erase Profile?"
    confirm_dialog.dialog_text = "Are you sure you want to erase the profile '%s'?" % [profile_name]
    confirm_dialog.dialog_text += "\nThe progress in this profile for all games will be erased."
    confirm_dialog.confirmed.connect(erase_profile_confirmed.bind(confirm_dialog))
    confirm_dialog.canceled.connect(dialog_closing.bind(confirm_dialog))

    confirm_dialog.ok_button_text = "Erase Profile"

    confirm_dialog_open = true
    confirm_dialog.popup_exclusive_centered(self)

func dialog_closing(dialog: ConfirmationDialog) -> void:
    dialog.queue_free()
    confirm_dialog_open = false

func erase_progress_confirmed(dialog: ConfirmationDialog, game_name: String) -> void:
    dialog_closing(dialog)
    
    GameManager.player_profile.erase_game_save_progress(game_name)
    GameManager.change_scene("Menu")

func erase_profile_confirmed(dialog: ConfirmationDialog) -> void:
    dialog_closing(dialog)
    
    GameManager.delete_current_profile()
    if GameManager.cur_scene == "Play":
        GameManager.change_scene("Menu")
    else:
        request_back.emit()

func on_skip_non_critical_confirm_toggle_toggled(is_skipping: bool) -> void:
    GameManager.player_profile.set_profile_setting("skip_non_critical_save_dialogs", is_skipping)

func on_profile_identifier_text_changed(text: String) -> void:
    var sanitized_identifier: String = GameManager.sanitize_identifier(text)
    GameManager.set_profile_identifier(sanitized_identifier)
    if sanitized_identifier != profile_identifier_input.text:
        profile_identifier_input.text = sanitized_identifier
        profile_identifier_input.caret_column = sanitized_identifier.length()

func on_auto_save_definition_toggle_toggled(is_auto_saving: bool) -> void:
    GameManager.player_profile.set_profile_setting("auto_save_definition", is_auto_saving)

func on_show_version_switcher_toggle_toggled(is_showing: bool) -> void:
    GameManager.player_profile.set_profile_setting("main_menu_version_switcher", is_showing)