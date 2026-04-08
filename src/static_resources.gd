extends Node
class_name StaticResources

const DirectionIcon: Dictionary[int, Texture2D] = {
    0: preload("res://assets/img/button_icons/direction_icons/up.png"),
    1: preload("res://assets/img/button_icons/direction_icons/right.png"),
    2: preload("res://assets/img/button_icons/direction_icons/down.png"),
    3: preload("res://assets/img/button_icons/direction_icons/left.png"),
}

const RelativeDirIcon: Dictionary[int, Texture2D] = {
    0: preload("res://assets/img/button_icons/direction_icons/rel_up.png"),
    1: preload("res://assets/img/button_icons/direction_icons/rel_right.png"),
    2: preload("res://assets/img/button_icons/direction_icons/rel_down.png"),
    3: preload("res://assets/img/button_icons/direction_icons/rel_left.png"),
}
