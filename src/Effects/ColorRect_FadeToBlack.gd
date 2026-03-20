extends ColorRect

@onready var normal_color = color

@export var fade_length: float = 1
var fading: bool = true
var fade_timer: float = 0
var fade: float = 1

func _ready():
	set_process(false)
	get_viewport().connect("size_changed", Callable(self, "updated"))

func updated() -> void:
	fade_timer = fade_length
	fading = true
	set_process(true)

func _process(delta):
	if fading:
		fade -= delta / fade_length
		fade = max(0, fade)
		if fade <= 0:
			fading = false
	else:
		fade += delta / fade_length
		fade = min(1, fade)
		if fade >= 1:
			set_process(false)
	
	color = lerp(Color.BLACK, normal_color, fade)
	
	if fading:
		fade_timer -= delta
		if fade_timer <= 0:
			fading = false
