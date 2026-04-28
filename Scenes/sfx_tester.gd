extends HBoxContainer

@export var sfx_picker: OptionButton
@export var sfx_input: LineEdit
@export var play_button: Button
@export var stream_player: AudioStreamPlayer

var _cur_seed: int = 0

func _ready() -> void:
    play_button.pressed.connect(on_play_button_pressed)
    sfx_picker.item_selected.connect(on_sfx_picker_item_selected)

func on_sfx_picker_item_selected(index: int) -> void:
    sfx_input.text = sfx_picker.get_item_text(index)

func on_play_button_pressed() -> void:
    var sfx_seed: int = int(sfx_input.text)
    if sfx_seed != _cur_seed:
        _cur_seed = sfx_seed
        var sfx_stream: AudioStreamWAV = PuzzleScriptSFXR.get_sfx_stream(sfx_seed)
        stream_player.stream = sfx_stream
    stream_player.play()
