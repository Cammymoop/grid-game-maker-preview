extends Control

@export var level_title_label: Label
@export var level_title_animator: AnimationPlayer

@export var hide_level_title_delay_time: float = 3

var is_show_level_title: = true
var is_keep_level_title_shown: = false

var level_title_is_showing: = false

var hide_delay_timer: = Timer.new()

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(hide_delay_timer)
    hide_delay_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
    var show_level_title_opt: String = GameManager.get_game_setting("show_level_title", "At Level Start").to_lower()
    is_show_level_title = show_level_title_opt != "hide"
    is_keep_level_title_shown = show_level_title_opt == "always"

    GameManager.level_state_loaded.connect(on_level_state_loaded)
    level_title_animator.animation_finished.connect(on_level_title_animation_finished)
    hide_delay_timer.timeout.connect(on_hide_delay_timer_timeout)

func on_level_state_loaded() -> void:
    if not level_title_label:
        return
    switch_level_title()

func switch_level_title() -> void:
    await get_tree().process_frame
    var new_title: = MapManager.get_level_title()
    if not is_show_level_title or not new_title:
        _set_level_title_to(new_title)
        return
    if level_title_is_showing:
        hide_show_level_title(new_title)
    else:
        _set_level_title_to(new_title)
        show_level_title()

func hide_show_level_title(new_title: String) -> void:
    level_title_animator.play("hide")
    if level_title_animator.animation_finished.is_connected(_set_level_title_to):
        level_title_animator.animation_finished.disconnect(_set_level_title_to)
    level_title_animator.animation_finished.connect(_set_level_title_to.bind(new_title).unbind(1))
    level_title_animator.queue("show")
    level_title_is_showing = true

func _set_level_title_to(new_title: String) -> void:
    level_title_label.text = new_title

func show_level_title() -> void:
    if not is_show_level_title:
        return
    if level_title_animator.animation_finished.is_connected(_set_level_title_to):
        level_title_animator.animation_finished.disconnect(_set_level_title_to)
    if level_title_animator.is_playing():
        level_title_animator.stop()
    level_title_animator.play("show")
    level_title_is_showing = true

func hide_level_title() -> void:
    if level_title_is_showing:
        level_title_animator.play("hide")
    level_title_is_showing = false

func on_level_title_animation_finished(anim_name: String) -> void:
    if anim_name == "show":
        if not is_keep_level_title_shown:
            if hide_level_title_delay_time <= 0:
                hide_level_title()
            else:
                hide_delay_timer.start(hide_level_title_delay_time)

func on_hide_delay_timer_timeout() -> void:
    hide_level_title()
