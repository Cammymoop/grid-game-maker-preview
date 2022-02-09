extends PanelContainer

var fade_time = 1.2
var fade_ratio = 3
var t = 0

func display(message):
	$Text.text = message

func _ready():
	t = fade_time

func _process(delta):
	t -= delta
	var alpha = t/fade_time * 3
	
	modulate = Color(1, 1, 1, alpha)
	if alpha < 0:
		queue_free()
	
