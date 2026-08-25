extends FoldableContainer

const Vector2fInput = preload("res://src/GameEditor/ConditionalEditor/vector2f_input.gd")

@export var expand_crop_option_picker: OptionButton
@export var window_size_vec_input: Vector2fInput

func _ready():
    expand_crop_option_picker.item_selected.connect(on_expand_crop_option_picked)
    window_size_vec_input.value_changed.connect(on_window_size_vec_input_value_changed)
    refresh_ui()

func refresh_ui() -> void:
    var is_exapand_view: bool = GameManager.get_game_setting("auto_aspect", true)
    expand_crop_option_picker.select(0 if is_exapand_view else 1)
    
    var window_size: = GameManager.get_window_size_setting()
    window_size_vec_input.set_value(window_size)

func on_expand_crop_option_picked(new_index: int):
    var is_expand_view: bool = new_index == 0
    GameManager.set_game_setting("auto_aspect", is_expand_view)

func on_window_size_vec_input_value_changed(new_value: Vector2):
    GameManager.set_game_view(new_value)