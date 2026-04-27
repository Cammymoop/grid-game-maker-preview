extends MarginContainer

@export var do_interpolate_rotation: bool = true
@export var interp_duration: float = 0.24
@export_exp_easing() var interp_ease_param: float = 0.2

@export var preview_viewport_padding: float = 0.25
@export var preview_vp_container: SubViewportContainer
@export var preview_subviewport: SubViewport
@export var the_sprite: MaskLayerSprite
@export var spin_sprite_toggle: CheckButton

@export var is_spinning: bool = false
@export var spin_speed: float = 1.2

var sprite_rotation: float = 0

var rotation_interp_target: float = 0
var rotation_interp_from: float = 0
var interp_timer: float = 0

var _sprite_is_setup: bool = false
var _has_custom_size: bool = false

func _ready() -> void:
    update_preview_size()
    if spin_sprite_toggle:
        spin_sprite_toggle.toggled.connect(on_spin_sprite_toggled)

func update_preview_size() -> void:
    if _has_custom_size:
        return
    _set_preview_size(GameManager.get_default_pixel_scale(), preview_viewport_padding)

func set_custom_preview_size(preview_scale: float = 1.0, with_padding: float = 0) -> void:
    _has_custom_size = true
    preview_vp_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    _set_preview_size(preview_scale, with_padding)

func _set_preview_size(preview_scale: float = 1.0, with_padding: float = 0) -> void:
    var base_grid_size: = Vector2.ONE * MapManager.tile_width
    var padding_size: = base_grid_size.y * with_padding
    var preview_size: = base_grid_size + (Vector2.ONE * padding_size * 2.0)
    if preview_scale == 1:
        preview_vp_container.custom_minimum_size = preview_size
        preview_subviewport.size_2d_override = Vector2i.ZERO
    else:
        preview_vp_container.custom_minimum_size = preview_size * preview_scale
        preview_subviewport.size_2d_override = preview_size

func get_subviewport() -> SubViewport:
    return preview_subviewport

func hide_bg() -> void:
    preview_subviewport.find_child("PreviewBG").hide()

func show_bg() -> void:
    preview_subviewport.find_child("PreviewBG").show()


func _process(delta: float) -> void:
    if not the_sprite:
        return
    if is_spinning:
        sprite_rotation += spin_speed * delta
    elif interp_timer > 0:
        interp_timer -= delta
        var interp_progress: = minf(1.0, 1.0 - interp_timer / interp_duration)
        sprite_rotation = lerp_angle(rotation_interp_from, rotation_interp_target, interp_progress)
    the_sprite.set_sprite_rotation(sprite_rotation)
    the_sprite.sprite_process(delta)

func on_spin_sprite_toggled(button_pressed: bool) -> void:
    is_spinning = button_pressed

func stop_spinning() -> void:
    if spin_sprite_toggle:
        spin_sprite_toggle.set_pressed_no_signal(false)
    is_spinning = false

func update_sprite_config(entity_def: Dictionary) -> void:
    if not the_sprite:
        return
    
    var sprite_config: = entity_def.get("sprite_config", {}) as Dictionary
    if not _sprite_is_setup:
        the_sprite.set_sprite_rotation(0)
        the_sprite.clear()
        the_sprite.interpolate_facing_enabled = false
        _sprite_is_setup = true
    if not sprite_config:
        update_simple_sprite(entity_def)
    else:
        the_sprite.set_main_layers(sprite_config["layers"])

func update_simple_sprite(entity_def: Dictionary) -> void:
    the_sprite.set_as_single(entity_def['texture'], entity_def['tex_index'])

func set_sprite_facing(facing: int) -> void:
    var rotation_val: = Utility.facing_rotation(facing)
    set_preview_spr_rotation(rotation_val)

func set_preview_spr_rotation(rotation_val: float) -> void:
    if is_spinning:
        stop_spinning()
    if do_interpolate_rotation and absf(angle_difference(rotation_val, sprite_rotation)) > TAU / 12.0:
        rotation_interp_target = rotation_val
        rotation_interp_from = sprite_rotation
        interp_timer = interp_duration
        return

    sprite_rotation = rotation_val
    if not the_sprite:
        return
    the_sprite.set_sprite_rotation(rotation_val)

func set_rotation_immediate(rotation_val: float) -> void:
    the_sprite.set_sprite_rotation(rotation_val)

func reset_sprite(entity_def: Dictionary) -> void:
    stop_spinning()
    sprite_rotation = 0
    _sprite_is_setup = false
    update_sprite_config(entity_def)