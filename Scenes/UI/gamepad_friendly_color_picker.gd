extends ColorPicker

signal cancelled

@export var base_move_speed: float = 3

@export var move_sensitivity: float = 1.0
@export var low_sensitivity: float = 0.3

@export var angle_sensitivity: float = 1.0
@export var low_angle_sensitivity: float = 0.3

var is_rotating_hue: bool = false
var hue_angle: float = 0.0

var last_hue_value: float = 0.0
var last_saturation_value: float = 0.0

func _input(event: InputEvent) -> void:
    if not visible:
        return
    if Input.is_action_just_pressed_by_event("ui_accept", event):
        color_changed.emit(color)
    elif Input.is_action_just_pressed_by_event("ui_close_dialog", event):
        accept_event()
        cancelled.emit()
    elif event is InputEventJoypadMotion:
        accept_event()
        return

func _process(delta: float) -> void:
    if not visible:
        return
    
    var left_stick_vector: Vector2 = Utility.input_vector_by_prefix("gp_left_stick")
    var right_stick_vector: Vector2 = Utility.input_vector_by_prefix("gp_right_stick")
    
    var left_length: float = left_stick_vector.length()
    var right_length: float = right_stick_vector.length()
    
    if not left_length > 0.01 and not right_length > 0.01:
        return

    if right_length > 0.3:
        if not is_rotating_hue:
            is_rotating_hue = true
            hue_angle = right_stick_vector.angle()
    else:
        is_rotating_hue = false
    
    if picker_shape == PickerShapeType.SHAPE_HSV_RECTANGLE:
        _update_hsv_rect(delta, left_stick_vector, right_stick_vector)
    elif picker_shape == PickerShapeType.SHAPE_OKHSL_CIRCLE:
        _update_okhsl_circle(delta, left_stick_vector, right_stick_vector)
    else:
        picker_shape = PickerShapeType.SHAPE_HSV_RECTANGLE
        return
    
    if is_rotating_hue:
        hue_angle = right_stick_vector.angle()

func _update_hsv_rect(delta: float, left_stick: Vector2, right_stick: Vector2) -> void:
    var sv_coordinate: = Vector2(color.s, 1 - color.v)
    if color.v <= 0:
        sv_coordinate.x = last_saturation_value

    if left_stick.length() > 0.01:
        var factor: float = move_sensitivity
        if Input.is_action_pressed("editor_alt_mode_hold"):
            factor = low_sensitivity
        sv_coordinate += left_stick * base_move_speed * factor * delta
        sv_coordinate = sv_coordinate.clampf(0.0, 1.0)

    var hue: float = color.h
    if color.v <= 0 or color.v >= 1 or color.s <= 0:
        hue = last_hue_value

    var alpha: float = color.a
    if is_rotating_hue:
        var angle_factor: float = angle_sensitivity
        if Input.is_action_pressed("editor_alt_mode_hold"):
            angle_factor = low_angle_sensitivity
        var angle_delta: float = angle_difference(hue_angle, right_stick.angle()) * angle_factor
        
        if Input.is_action_pressed("gp_edit_alpha"):
            if edit_alpha:
                alpha = clampf(alpha + (angle_delta / TAU), 0.0, 1.0)
        else:
            hue = fposmod(hue + (angle_delta / TAU), 1.0)
    
    last_hue_value = hue
    last_saturation_value = sv_coordinate.x
    color = Color.from_hsv(hue, sv_coordinate.x, 1 - sv_coordinate.y, alpha)

func _update_okhsl_circle(delta: float, left_stick: Vector2, right_stick: Vector2) -> void:
    pass