extends HBoxContainer

const DEFAULT_PS_SEED: int = 1111

signal play_preview(sfx_item: Node)
signal changed()
signal request_remove(sfx_item: Node)

const SFX_TYPE_PS_SFX: String = "ps_sfx"
const SFX_TYPE_SAMPLE: String = "sample"

const SFX_TYPE_STRINGS: Dictionary[String, String] = {
    SFX_TYPE_PS_SFX: "PuzzleScript Sfx Number",
    SFX_TYPE_SAMPLE: "Sample",
}

var pitch_factor_size: float = 3

@export var sfx_name_input: LineEdit
@export var sfx_type_picker: OptionButton

@export var sample_only_container: Control
@export var sample_picker: OptionButton

@export var volume_slider: Slider
@export var pitch_slider: Slider

@export var ps_only_container: Control
@export var sfx_style_picker: OptionButton
@export var sfx_input: LineEdit
@export var play_button: Button

@export var randomize_button: ButtonContainer

func _ready() -> void:
    play_button.pressed.connect(play_me)
    sfx_type_picker.item_selected.connect(on_sfx_type_picker_item_selected)

    sfx_style_picker.item_selected.connect(on_sfx_style_picker_item_selected)

    sfx_name_input.text_changed.connect(on_sfx_name_changed)
    
    sfx_input.text_changed.connect(on_sfx_input_changed)
    sfx_input.text_submitted.connect(on_sfx_input_submitted)
    
    randomize_button.pressed.connect(on_randomize_button_pressed)
    
    volume_slider.drag_ended.connect(on_volume_slider_drag_ended)
    volume_slider.gui_input.connect(on_slider_gui_input.bind(volume_slider))
    
    pitch_slider.drag_ended.connect(on_pitch_slider_drag_ended)
    pitch_slider.gui_input.connect(on_slider_gui_input.bind(pitch_slider))

    sample_picker.item_selected.connect(on_sample_picker_item_selected)
    
    build_style_picker()
    build_sample_picker()

func _slider_default(for_slider: Slider) -> float:
    if for_slider == pitch_slider:
        return 0.5
    return 1.0

func build_style_picker() -> void:
    sfx_style_picker.clear()
    for i in PuzzleScriptSFXR.GeneratorType.size():
        sfx_style_picker.add_item(PuzzleScriptSFXR.GeneratorType.keys()[i], i)

func build_sample_picker() -> void:
    sample_picker.clear()
    for sample_name in SfxPlayer.get_sample_name_list():
        sample_picker.add_item(sample_name)

func on_sfx_type_picker_item_selected(_index: int) -> void:
    refresh_ui()

func on_sfx_style_picker_item_selected(index: int) -> void:
    var generator_style_index: = sfx_style_picker.get_item_id(index)
    sfx_input.text = str(1000 + generator_style_index)
    on_randomize_button_pressed()

func on_sfx_name_changed(new_text: String) -> void:
    if new_text.strip_edges().length() > 0:
        changed.emit()

func on_sfx_input_changed(new_text: String) -> void:
    if new_text.is_valid_int():
        var new_seed: int = int(new_text)
        Utility.opbtn_select_id(sfx_style_picker, PuzzleScriptSFXR.get_generator_index_from_seed(new_seed))
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
        return
    sfx_name_input.text = the_name

    volume_slider.set_value_no_signal(sfx_definition.get("volume", 1.0))
    
    var sfx_type: String = sfx_definition.get("type", SFX_TYPE_PS_SFX)
    if sfx_type not in SFX_TYPE_STRINGS.keys():
        sfx_type = SFX_TYPE_PS_SFX
    sfx_type_picker.selected = SFX_TYPE_STRINGS.keys().find(sfx_type)

    if sfx_type == SFX_TYPE_PS_SFX:
        var ps_seed: int = int(sfx_definition.get("ps_seed", DEFAULT_PS_SEED))
        sfx_input.text = str(ps_seed)
        var generator_index: int = PuzzleScriptSFXR.get_generator_index_from_seed(ps_seed)
        Utility.opbtn_select_id(sfx_style_picker, generator_index)
        prints(Utility.opbtn_get_selected_text(sfx_style_picker))
    else:
        var sample_name: String = sfx_definition.get("sample_name", "")
        prints("sample_name: %s" % sample_name)
        var sample_name_list: Array[String] = SfxPlayer.get_sample_name_list()
        if not sample_name or not sample_name_list.has(sample_name):
            sample_name = sample_name_list[0]
        prints("sample_name: %s" % sample_name, "index: %s" % sample_name_list.find(sample_name))
        sample_picker.selected = sample_name_list.find(sample_name)
    
    _set_pitch_factor(sfx_definition.get("pitch", 1.0))
    
    refresh_ui()

func refresh_ui() -> void:
    var sfx_type: String = SFX_TYPE_STRINGS.keys()[sfx_type_picker.selected]
    
    ps_only_container.visible = sfx_type == SFX_TYPE_PS_SFX
    randomize_button.visible = sfx_type == SFX_TYPE_PS_SFX
    sample_only_container.visible = sfx_type == SFX_TYPE_SAMPLE


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
    var sfx_type: String = SFX_TYPE_STRINGS.keys()[sfx_type_picker.selected]
    var sfx_definition: Dictionary = {
        "type": sfx_type,
        "name": get_sfx_name(),
        "volume": volume_slider.value,
        "pitch": 1.0,
    }
    if pitch_slider.visible:
        sfx_definition["pitch"] = _get_pitch_factor()

    if sfx_type == SFX_TYPE_PS_SFX:
        sfx_definition["ps_seed"] = get_pssfx_seed()
    elif sfx_type == SFX_TYPE_SAMPLE:
        sfx_definition["sample_name"] = Utility.opbtn_get_selected_text(sample_picker)
    return sfx_definition

func play_me() -> void:
    play_preview.emit(self)

func remove_me() -> void:
    request_remove.emit(self)

func on_sfx_input_submitted(_new_text: String) -> void:
    play_me()

func _get_pitch_factor() -> float:
    var raw_pitch_slider: = pitch_slider.value
    return pow(pitch_factor_size, (2 * raw_pitch_slider) - 1.0)

func _set_pitch_factor(pitch_factor: float) -> void:
    pitch_slider.set_value_no_signal((1 + log(pitch_factor) / log(pitch_factor_size)) / 2.0)

func on_volume_slider_drag_ended(_new_value: float) -> void:
    changed.emit()
    play_me()

func on_pitch_slider_drag_ended(_new_value: float) -> void:
    changed.emit()
    play_me()

func on_sample_picker_item_selected(_index: int) -> void:
    changed.emit()
    play_me()

func on_slider_gui_input(event: InputEvent, slider: Slider) -> void:
    if event is InputEventMouseButton and not event.is_pressed():
        if event.button_index == MOUSE_BUTTON_RIGHT:
            slider.value = _slider_default(slider)
            changed.emit()
            play_me()