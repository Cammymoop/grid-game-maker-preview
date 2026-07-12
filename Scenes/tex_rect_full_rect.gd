extends TextureRect

@export var vp: Viewport

func _ready() -> void:
    if not vp:
        vp = get_viewport()
    refresh_size()
    vp.size_changed.connect(refresh_size)

func refresh_size() -> void:
    var vp_size = vp.size
    custom_minimum_size = vp_size
