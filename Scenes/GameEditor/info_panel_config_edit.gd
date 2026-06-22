extends VBoxContainer

const InfoPanelConfigItem = preload("res://Scenes/GameEditor/info_panel_config_item.gd")
const info_panel_config_item_scn: PackedScene = preload("res://Scenes/GameEditor/info_panel_config_item.tscn")

@export var add_item_button: ButtonContainer
@export var item_list_container: Control

@export var enable_toggle: CheckButton

func _ready() -> void:
    enable_toggle.set_pressed_no_signal(GameManager.get_game_setting("info_panel_enabled", false))

    enable_toggle.toggled.connect(_on_enable_toggle_toggled)
    add_item_button.pressed.connect(_on_add_item_button_pressed)
    
    load_info_panel_config()

func config_updated() -> void:
    GameManager.set_game_setting("info_panel_items", get_info_panel_config())

func remove_item(item: InfoPanelConfigItem) -> void:
    item_list_container.remove_child(item)
    item.queue_free()
    order_changed()
    config_updated()

func duplicate_item(item: InfoPanelConfigItem) -> void:
    var new_item: = _new_config_item()
    var item_data: = item.get_config_data()
    item_list_container.add_child(new_item)
    new_item.load_config_data(item_data)
    order_changed()
    config_updated()

func move_item_relative(relative_index: int, item: InfoPanelConfigItem) -> void:
    var current_index: int = item_list_container.get_child_index(item)
    var new_index: int = clampi(current_index + relative_index, 0, item_list_container.get_child_count() - 1)
    if new_index != current_index:
        item_list_container.move_child(item, new_index)
    order_changed()
    config_updated()

func item_to_top(item: InfoPanelConfigItem) -> void:
    item_list_container.move_child(item, 0)
    order_changed()
    config_updated()

func item_to_bottom(item: InfoPanelConfigItem) -> void:
    item_list_container.move_child(item, item_list_container.get_child_count() - 1)
    order_changed()
    config_updated()

func order_changed() -> void:
    var last_item_idx: = item_list_container.get_child_count() - 1
    for i in item_list_container.get_child_count():
        var item: = item_list_container.get_child(i) as InfoPanelConfigItem
        item.order_button_up.disabled = i == 0
        item.order_button_down.disabled = i == last_item_idx


func get_info_panel_config() -> Dictionary:
    var config: Dictionary = {}
    for i in item_list_container.get_child_count():
        var item: = item_list_container.get_child(i) as InfoPanelConfigItem
        if not item:
            continue
        config[i + 1] = item.get_config_data()
    return config

func load_info_panel_config() -> void:
    clear_items()
    var game_info_panel_settings: Dictionary = GameManager.get_game_setting("info_panel_items", {})
    if game_info_panel_settings:
        for info_item_data in game_info_panel_settings.values():
            var new_item: = _new_config_item()
            item_list_container.add_child(new_item)
            new_item.load_config_data(info_item_data)
    order_changed()

func clear_items() -> void:
    for item in item_list_container.get_children():
        item_list_container.remove_child(item)
        item.queue_free()

func _new_config_item() -> InfoPanelConfigItem:
    var new_item: = info_panel_config_item_scn.instantiate() as InfoPanelConfigItem
    new_item.item_updated.connect(config_updated)
    new_item.request_remove.connect(remove_item.bind(new_item))
    new_item.request_duplicate.connect(duplicate_item.bind(new_item))
    new_item.request_move_relative.connect(move_item_relative.bind(new_item))
    new_item.request_move_to_top.connect(item_to_top.bind(new_item))
    new_item.request_move_to_bottom.connect(item_to_bottom.bind(new_item))
    return new_item

func _on_add_item_button_pressed() -> void:
    var new_item: = _new_config_item()
    item_list_container.add_child(new_item)
    new_item.refresh_ui()

func _on_enable_toggle_toggled(toggled: bool) -> void:
    GameManager.set_game_setting("info_panel_enabled", toggled)