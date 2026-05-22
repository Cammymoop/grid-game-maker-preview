extends Node2D

@export var label_node: Label
@export var lifetime: float = 1.0
@export var mini_message: String = ""

@export var use_show_anim: bool = true
@export var use_hide_anim: bool = true
@export var animator: AnimationPlayer = null

@export var show_anim_duration: float = 0.1
@export var hide_anim_duration: float = 0.4

var timer: Timer = null

var outline_thickness: int = 4

func _ready() -> void:
    label_node.text = mini_message
    timer = Timer.new()
    timer.timeout.connect(on_timer_timeout)
    add_child(timer)
    if lifetime > 0:
        timer.start(lifetime)
    if animator and use_show_anim:
        animator.speed_scale = 1.0 / show_anim_duration
        animator.play("show")
    adjust_label_positioning()

func adjust_label_positioning() -> void:
    if label_node.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
        adjust_center_alignment()
    else:
        adjust_side_alignment()

func adjust_center_alignment() -> void:
    label_node.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

func adjust_side_alignment() -> void:
    var preset: int = Control.PRESET_CENTER_LEFT
    if label_node.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
        preset = Control.PRESET_CENTER_RIGHT
    label_node.set_anchors_and_offsets_preset(preset)

func set_message_text(new_message: String) -> void:
    mini_message = new_message
    label_node.text = mini_message
    adjust_label_positioning()

func on_timer_timeout() -> void:
    if not animator or not use_hide_anim:
        queue_free()
    else:
        animator.stop(true)
        animator.speed_scale = 1.0 / hide_anim_duration
        animator.animation_finished.connect(queue_free.unbind(1))
        animator.play("hide")

func set_font_size(new_size: int) -> void:
    label_node.add_theme_font_size_override("font_size", new_size)
    adjust_label_positioning()

func set_color(new_color: Color) -> void:
    label_node.add_theme_color_override("font_color", new_color)

func set_outline_color(new_color: Color) -> void:
    label_node.add_theme_color_override("font_outline_color", new_color)

func set_outline_enabled(new_enabled: bool) -> void:
    label_node.add_theme_constant_override("outline_size", outline_thickness if new_enabled else 0)

func set_layout_mode(horiz_align: HorizontalAlignment) -> void:
    label_node.horizontal_alignment = horiz_align
    adjust_label_positioning()

func reset_style() -> void:
    label_node.add_theme_font_size_override("font_size", 9)
    label_node.remove_theme_color_override("font_color")
    label_node.remove_theme_color_override("font_outline_color")
    label_node.add_theme_constant_override("outline_size", 4)
    label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    adjust_label_positioning()