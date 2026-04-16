extends Node2D

@export var text_label: Label
@export var text_box_panel: PanelContainer
@export var animator: AnimationPlayer
@export var max_width_ratio: float = 0.8

var base_in_out_height: float = 15

var is_on_screen: = false
var showing_text: = ""

func _ready() -> void:
    set_text_and_adjust_anim(text_label.text)

func show_with_text(text: String) -> void:
    set_text_and_adjust_anim(text)
    if not is_on_screen:
        await get_tree().process_frame
        animator.play("show")
        is_on_screen = true

func dismiss() -> void:
    set_text_and_adjust_anim(showing_text)
    await get_tree().process_frame
    if is_on_screen:
        animator.play("hide")
        is_on_screen = false
        

func set_text_and_adjust_anim(text: String) -> void:
    text_label.autowrap_mode = TextServer.AUTOWRAP_OFF
    showing_text = text
    if not is_on_screen:
        position.y = 20000
    text_label.text = showing_text
    
    var vp_width: float = get_viewport().size.x
    var width_ratio: = text_box_panel.size.x / vp_width
    
    var new_textbox_height: float = text_box_panel.size.y
    if width_ratio > max_width_ratio:
        var max_width: = vp_width * max_width_ratio
        text_box_panel.custom_minimum_size.x = max_width
        text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        await get_tree().process_frame
        new_textbox_height = text_box_panel.size.y
    
    var low_point: float = new_textbox_height + base_in_out_height
    _edit_anim_with_low_point(low_point)
    if not is_on_screen:
        position.y = low_point

func _edit_anim_with_low_point(low_point: float) -> void:
    var in_anim: Animation = animator.get_animation("show")
    var in_anim_pos_track: = in_anim.find_track(".:position", Animation.TYPE_VALUE)
    in_anim.track_set_key_value(in_anim_pos_track, 0, Vector2(0, low_point))
    
    var out_anim: Animation = animator.get_animation("hide")
    var out_anim_pos_track: = out_anim.find_track(".:position", Animation.TYPE_VALUE)
    out_anim.track_set_key_value(out_anim_pos_track, 1, Vector2(0, low_point))

    
