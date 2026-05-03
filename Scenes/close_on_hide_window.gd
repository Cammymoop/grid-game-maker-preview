extends Window

func _ready():
    visibility_changed.connect(_on_vis_changed)
    close_requested.connect(hide)

func _on_vis_changed():
    if not visible:
        await get_tree().process_frame
        queue_free()
