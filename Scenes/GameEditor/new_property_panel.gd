extends PanelContainer

@export var prefill_prop_name: String = ""

@export var allow_replacing_existing: bool = true
@export var existing_property_list: Array[String] = []

@export var property_name_input: LineEdit
@export var add_button: Button
@export var replace_button: Button
@export var replace_label: Control


signal name_chosen(property_name: String, alt_mode: bool)
signal cancelled()
signal closed()

func _ready() -> void:
    if prefill_prop_name:
        property_name_input.text = prefill_prop_name
    property_name_input.grab_focus.call_deferred()
    
    property_name_input.text_submitted.connect(accept_name)
    property_name_input.text_changed.connect(on_text_changed)
    
    add_button.pressed.connect(accept_name)
    replace_button.pressed.connect(accept_name)

func set_title_text(title_text: String) -> void:
    find_child("TitleLabel").text = title_text

func _shortcut_input(event: InputEvent) -> void:
    if Utility.fixed_just_pressed_by_event("escape", event):
        close_panel()
        _accept_event()
    elif Utility.fixed_just_pressed_by_event("ui_accept", event):
        accept_name()
        _accept_event()

func _accept_event() -> void:
    get_viewport().set_input_as_handled()

func accept_name() -> void:
    var new_name: String = property_name_input.text
    if new_name in existing_property_list:
        if not allow_replacing_existing:
            GlobalToaster.show_toast_message("That property already exists and cannot be overridden")
        return
    var is_alt_mode: bool = Input.is_key_pressed(KEY_SHIFT)
    _accept_name(is_alt_mode)

func allow_accepting() -> void:
    add_button.disabled = false
    replace_button.hide()
    replace_label.hide()

func disallow_accepting() -> void:
    add_button.disabled = true
    if allow_replacing_existing:
        replace_button.show()
        replace_label.show()

func on_text_changed(new_text: String) -> void:
    if new_text not in existing_property_list:
        allow_accepting()
    else:
        disallow_accepting()


func _accept_name(is_alt_mode: bool) -> void:
    name_chosen.emit(property_name_input.text, is_alt_mode)
    queue_free()
    closed.emit()

func close_panel() -> void:
    cancelled.emit()
    queue_free()
    closed.emit()