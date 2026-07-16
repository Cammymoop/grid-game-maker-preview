extends VBoxContainer

const BgEffect = preload("res://Scenes/bg_effect_5.gd")

@export var bg_effect: BgEffect
@export var use_mouse_pos_for_camera: = true

@export var style_editor: Control

var lerpable_mouse_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
    lerpable_mouse_pos = get_rect().size * 0.5
    refresh_simulated_cam()
    visibility_changed.connect(on_visibility_changed)
    set_process(use_mouse_pos_for_camera)

func _process(_delta: float) -> void:
    if is_visible_in_tree():
        refresh_simulated_cam()

func on_visibility_changed() -> void:
    if visible:
        refresh_simulated_cam()

func refresh_simulated_cam() -> void:
    var default_camera_zoom: float = GameManager.get_game_setting("pixel_scale", 2.0)
    var target_mouse: = get_local_mouse_position()
    target_mouse -= get_rect().size * 0.5
    var relative_mouse: = lerpable_mouse_pos.lerp(target_mouse, 0.3)
    if not use_mouse_pos_for_camera:
        relative_mouse = Vector2.ZERO
    else:
        var global_mouse: = get_global_mouse_position()
        var style_editor_global_rect: = style_editor.get_global_rect()
        if style_editor_global_rect.has_point(global_mouse):
            relative_mouse = lerpable_mouse_pos.lerp(Vector2.ZERO, 0.1)
            if relative_mouse.length() < 0.5:
                relative_mouse = Vector2.ZERO

    lerpable_mouse_pos = relative_mouse
    bg_effect.update_cam_scale_and_scroll_manually(default_camera_zoom, relative_mouse)
    RenderingServer.global_shader_parameter_set("camera_displacement", relative_mouse)