extends Control

signal request_remove(item: Control)
signal request_duplicate(item: Control)
signal request_move_relative(item: Control, amt: int)
signal request_move_to_top(item: Control)
signal request_move_to_bottom(item: Control)
signal request_delete_others(item: Control)
signal changed()

const Vec2IInput: = preload("res://src/GameEditor/ConditionalEditor/vector_2i_input.gd")
const BetterTextureDialog: = preload("res://src/GameEditor/BetterTextureDialog.gd")

static var texture_picker_scene: = preload("res://Scenes/GameEditor/BetterTextureDialog.tscn")

const MODE_NORMAL: = "normal"
const MODE_EMPTY: = "empty"

const LayerModeOptions: Dictionary[String, String] = {
    MODE_NORMAL: "normal",
    MODE_EMPTY: "empty",
}

@export var empty_layer_button_icon: Texture2D

@export var remove_button: ButtonContainer
@export var layer_image_button: ButtonContainer
@export var offset_input: Vec2IInput
@export var mode_selector: OptionButton
@export var reorder_buttons: Control
@export var rotates_toggle: CheckButton

@export var show_reorder_buttons: bool = true
@export var enable_context_menu: bool = true

var layer_info: Dictionary = {}

const CONTEXT_MENU_MOVE_UP = 10
const CONTEXT_MENU_MOVE_DOWN = 11
const CONTEXT_MENU_MOVE_TOP = 12
const CONTEXT_MENU_MOVE_BOTTOM = 13

const CONTEXT_MENU_DUPLICATE = 20
const CONTEXT_MENU_DELETE = 22
const CONTEXT_MENU_DELETE_OTHERS = 23

func _ready() -> void:
    if reorder_buttons:
        reorder_buttons.visible = show_reorder_buttons
        reorder_buttons.get_node("UpButton").pressed.connect(move_up_button_pressed)
        reorder_buttons.get_node("DownButton").pressed.connect(move_down_button_pressed)
    remove_button.pressed.connect(_req_remove)
    
    mode_selector.clear()
    for mode_name in LayerModeOptions:
        mode_selector.add_item(LayerModeOptions[mode_name])
    mode_selector.item_selected.connect(on_mode_selected)
    
    offset_input.value_changed.connect(on_offset_changed)
    
    rotates_toggle.toggled.connect(on_rotates_toggled)
    rotates_toggle.set_pressed_no_signal(layer_info.get("rotates", true))
    if layer_info and layer_info.has("mode"):
        refresh_ui()
    
    layer_image_button.pressed.connect(on_layer_image_button_pressed)

func _req_remove() -> void:
    request_remove.emit(self)

func on_rotates_toggled(button_pressed: bool) -> void:
    layer_info['rotates'] = button_pressed
    changed.emit()

func set_layer_info(new_layer_info: Dictionary) -> void:
    layer_info = new_layer_info.duplicate_deep()
    prints("got layer info:", layer_info)
    if is_inside_tree():
        refresh_ui()

func get_layer_info() -> Dictionary:
    return layer_info.duplicate_deep()

func _set_layer_offset(new_offset: Vector2i) -> void:
    layer_info['offset'] = Utility.get_arr_from_vector2i(new_offset)

func get_layer_offset() -> Vector2i:
    return Utility.get_vector2i_from_arr(layer_info.get("offset", [0,0]))

func get_mode_value() -> String:
    var selected_text: = mode_selector.get_item_text(mode_selector.selected)
    if not selected_text in LayerModeOptions:
        return MODE_NORMAL
    return selected_text

func set_mode_picker_value(new_mode_value: String) -> void:
    if not new_mode_value in LayerModeOptions.keys():
        mode_selector.selected = _layer_mode_index(MODE_NORMAL)
    else:
        mode_selector.selected = _layer_mode_index(new_mode_value)

func on_mode_selected(_index: int) -> void:
    layer_info['mode'] = get_mode_value()
    if layer_info['mode'] != MODE_EMPTY:
        _set_default_texture_and_index()
    changed.emit()
    refresh_ui()

func _set_default_texture_and_index() -> void:
    if not 'texture' in layer_info:
        layer_info['texture'] = 0
    if not 'tex_index' in layer_info:
        layer_info['tex_index'] = 0

func on_offset_changed(new_offset: Vector2i) -> void:
    prints("on_offset_changed: %s" % new_offset)
    if new_offset == Vector2i.ZERO:
        layer_info.erase("offset")
    else:
        _set_layer_offset(new_offset)
    changed.emit()


func refresh_ui() -> void:
    set_mode_picker_value(layer_info['mode'])
    if layer_info['mode'] == MODE_EMPTY:
        layer_image_button.disabled = true
    offset_input.set_value(get_layer_offset())
    update_image_button_texture()

func update_image_button_texture() -> void:
    var button_texture: Texture2D = null
    if layer_info['mode'] == MODE_EMPTY and empty_layer_button_icon:
        button_texture = empty_layer_button_icon
    else:
        button_texture = Utility.atlas_texture_from_texture_index(layer_info['texture'], layer_info['tex_index'])
    layer_image_button.find_child("TextureRect").texture = button_texture


func move_up_button_pressed() -> void:
    request_move_relative.emit(self, -1)

func move_down_button_pressed() -> void:
    request_move_relative.emit(self, 1)


func on_layer_image_button_pressed() -> void:
    open_texture_picker()

func open_texture_picker() -> void:
    var tex_picker: = texture_picker_scene.instantiate()
    add_child(tex_picker)
    tex_picker.setup(layer_info['texture'], layer_info['tex_index'])
    tex_picker.confirmed.connect(_on_tex_picker_confirmed.bind(tex_picker))
    tex_picker.popup_centered()

func _on_tex_picker_confirmed(tex_picker: BetterTextureDialog) -> void:
    layer_info['texture'] = tex_picker.get_selected_texture()
    layer_info['tex_index'] = tex_picker.get_selected_sub_index()
    tex_picker.queue_free()
    update_image_button_texture()
    changed.emit()

func _gui_input(event: InputEvent) -> void:
    if enable_context_menu and event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT and not event.is_pressed():
            do_context_menu()

func do_context_menu() -> void:
    var context_menu = Utility.get_empty_context_menu()
    context_menu.add_item("Duplicate", CONTEXT_MENU_DUPLICATE)
    context_menu.add_separator()
    context_menu.add_item("Delete", CONTEXT_MENU_DELETE)
    context_menu.add_item("Delete all other layers", CONTEXT_MENU_DELETE_OTHERS)
    context_menu.add_separator()
    context_menu.add_item("Move to top", CONTEXT_MENU_MOVE_TOP)
    context_menu.add_item("Move to bottom", CONTEXT_MENU_MOVE_BOTTOM)
    context_menu.id_pressed.connect(on_context_menu_id_pressed)
    get_window().add_child(context_menu)
    Utility.popup_context_menu_at_mouse(context_menu)

func on_context_menu_id_pressed(context_menu_id: int) -> void:
    match context_menu_id:
        CONTEXT_MENU_MOVE_UP:
            request_move_relative.emit(self, -1)
        CONTEXT_MENU_MOVE_DOWN:
            request_move_relative.emit(self, 1)
        CONTEXT_MENU_MOVE_TOP:
            request_move_to_top.emit(self)
        CONTEXT_MENU_MOVE_BOTTOM:
            request_move_to_bottom.emit(self)
        CONTEXT_MENU_DUPLICATE:
            request_duplicate.emit(self)
        CONTEXT_MENU_DELETE:
            request_remove.emit(self)
        CONTEXT_MENU_DELETE_OTHERS:
            request_delete_others.emit(self)

func _layer_mode_index(layer_mode: String) -> int:
    var mode_text: = LayerModeOptions[layer_mode]
    for i in mode_selector.get_item_count():
        if mode_selector.get_item_text(i) == mode_text:
            return i
    return -1