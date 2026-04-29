extends HBoxContainer

const DEFAULT_PS_SEED: int = 1111

signal play_preview(sfx_item: Node)
signal changed()
signal request_remove(sfx_item: Node)

@export var sfx_name_input: LineEdit
@export var sfx_style_picker: OptionButton
@export var sfx_input: LineEdit
@export var play_button: Button

@export var randomize_button: ButtonContainer

func _ready() -> void:
    play_button.pressed.connect(play_me)
    sfx_style_picker.item_selected.connect(on_sfx_style_picker_item_selected)

    sfx_name_input.text_changed.connect(on_sfx_name_changed)
    
    sfx_input.text_changed.connect(on_sfx_input_changed)
    sfx_input.text_submitted.connect(on_sfx_input_submitted)
    
    randomize_button.pressed.connect(on_randomize_button_pressed)
    
    build_style_picker()

func build_style_picker() -> void:
    sfx_style_picker.clear()
    for i in PuzzleScriptSFXR.GeneratorType.size():
        sfx_style_picker.add_item(PuzzleScriptSFXR.GeneratorType.keys()[i], i)

func on_sfx_style_picker_item_selected(index: int) -> void:
    var generator_style_index: = sfx_style_picker.get_item_id(index)
    sfx_input.text = str(1000 + generator_style_index)
    on_randomize_button_pressed()

func on_sfx_name_changed(_new_text: String) -> void:
    changed.emit()

func on_sfx_input_changed(_new_text: String) -> void:
    changed.emit()

func on_randomize_button_pressed() -> void:
    var new_seed: int = randomize_ps_seed_same_generator(get_pssfx_seed())
    sfx_input.text = str(new_seed)
    changed.emit()
    play_me()

func randomize_ps_seed_same_generator(old_seed: int) -> int:
    return PuzzleScriptSFXR.rerandomize_seed(old_seed)

func set_sfx_definition(sfx_definition: Dictionary) -> void:
    var the_name: String = sfx_definition.get("name", "")
    if not the_name:
        push_warning("Invalid sfx definition: %s" % sfx_definition)
        queue_free()
    sfx_name_input.text = the_name
    sfx_input.text = str(int(sfx_definition.get("ps_seed", DEFAULT_PS_SEED)))

func get_sfx_name() -> String:
    return sfx_name_input.text

func get_pssfx_seed() -> int:
    var string_val: String = sfx_input.text.strip_edges().replace(" ", "")
    if string_val.is_valid_int():
        return int(string_val)
    if not string_val.is_valid_float():
        return DEFAULT_PS_SEED
    return int(float(string_val))

func get_sfx_definition() -> Dictionary:
    return {
        "type": "ps_sfx",
        "name": get_sfx_name(),
        "ps_seed": get_pssfx_seed(),
    }

func play_me() -> void:
    play_preview.emit(self)

func remove_me() -> void:
    request_remove.emit(self)

func on_sfx_input_submitted(_new_text: String) -> void:
    play_me()
    