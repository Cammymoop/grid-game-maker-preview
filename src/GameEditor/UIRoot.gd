# Game Editor UI panel root
extends PanelContainer

var quick_msg = preload("res://Scenes/GameEditor/QuickMessage.tscn")

var save_as_dialog_scn: = preload("res://Scenes/GameEditor/save_game_as_dialog.tscn")

@export var tab_container: TabContainer
@export var beside_tabs_buttons: HBoxContainer

@onready var popup_layer = get_node("PopupLayerLayer/PopupLayer")
@onready var message_layer = get_node("MessageLayer")

@export var release_lock_layer: CanvasLayer

func _ready():
	release_lock_layer.visible = GameManager.current_game_is_release_locked
	
	if GameManager.current_game_is_release_locked:
		tab_container.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED

	var first_beside_tabs_button: Control = beside_tabs_buttons.get_child(0)
	var tab_bar: = tab_container.get_tab_bar()
	tab_bar.focus_neighbor_right = first_beside_tabs_button.get_path()
	tab_bar.focus_next = focus_neighbor_right
	first_beside_tabs_button.focus_neighbor_left = tab_bar.get_path()
	first_beside_tabs_button.focus_previous = first_beside_tabs_button.focus_neighbor_left

func _unhandled_input(event: InputEvent) -> void:
	if Utility.event_is_menu_back_just_pressed(event):
		if tab_container.current_tab != 0 and not release_lock_layer.visible:
			tab_container.current_tab = 0
		else:
			GameManager.change_scene("Menu")
			return
	if release_lock_layer.visible:
		return
	var current_focus_owner: = get_viewport().gui_get_focus_owner()
	if current_focus_owner and is_ancestor_of(current_focus_owner):
		return
	for focus_dir_action in ["ui_up", "ui_down", "ui_left", "ui_right"]:
		if Utility.fixed_just_pressed_by_event(focus_dir_action, event):
			tab_container.get_tab_bar().grab_focus.call_deferred()
			break

#func show_message(message_text) -> void:
#	var qm = quick_msg.instantiate()
#	qm.display(message_text)
#	message_layer.add_child(qm)

func add_popup_layer_node(node: Node) -> void:
	popup_layer.add_something(node)

func _on_BackButton_pressed():
	GameManager.change_scene("Menu")

func _on_test_play_button_pressed() -> void:
	GameManager.start_playing(true)


func _on_OpenGameDir_pressed():
	if false:#GameManager.get_identified_game_name():
		var game_base_dir: = FilesManager.get_game_base_dir(GameManager.get_identified_game_name())
		OS.shell_open(ProjectSettings.globalize_path(game_base_dir))
	else:
		OS.shell_open(ProjectSettings.globalize_path(FilesManager.get_games_dir()))

func _on_OpenImagesFolder_pressed():
	var shared_images_dir: = FilesManager.get_shared_images_dir()
	OS.shell_open(ProjectSettings.globalize_path(shared_images_dir))

func _shortcut_input(event: InputEvent) -> void:
	if release_lock_layer.visible:
		return
	if Utility.fixed_just_pressed_by_event("save_file_shortcut", event):
		if not GameManager.is_save_current_overwriting():
			GameManager.save_current_game_definition()
			GlobalToaster.show_toast_message("Saved %s Game Definition" % [GameManager.get_identified_game_name()])
		else:
			_open_save_as_dialog(FilesManager.get_unique_game_name(GameManager.get_identified_game_name()))
	elif Utility.fixed_just_pressed_by_event("save_file_as_shortcut", event):
		_open_save_as_dialog()
	elif Utility.fixed_just_pressed_by_event("editor_start_no_kb", event):
		GameManager.start_playing(true)

func _open_save_as_dialog(with_name: String = "") -> void:
	var save_as_dialog: = save_as_dialog_scn.instantiate()
	save_as_dialog.use_game_name = with_name
	add_popup_layer_node(save_as_dialog)
	save_as_dialog.move_to_center()