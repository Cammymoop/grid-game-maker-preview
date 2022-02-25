tool
extends Container

# warning-ignore:unused_signal
signal button_down
# warning-ignore:unused_signal
signal button_up
# warning-ignore:unused_signal
signal pressed
signal toggled(button_pressed)

var button

export var toggle_mode = false setget set_toggle_mode, get_toggle_mode
export var pressed = false setget set_pressed, get_pressed

func _init():
	button = Button.new()
	button.name = "BGButton"
	button.show_behind_parent = true
	add_child(button)
	button.anchor_right = 1
	button.anchor_bottom = 1
	button.margin_right = 0
	button.margin_bottom = 0
	
	button.connect("button_down", self, "emit_signal", ["button_down"])
	button.connect("button_up", self, "emit_signal", ["button_up"])
	button.connect("pressed", self, "emit_signal", ["pressed"])
	button.connect("toggled", self, "_toggled_relay")
	
	button.connect("mouse_entered", self, "emit_signal", ["mouse_entered"])
	button.connect("mouse_exited", self, "emit_signal", ["mouse_exited"])

func add_child(child: Node, legible_unique_name=false):
	.add_child(child, legible_unique_name)
	if child == button:
		return
	recursive_set_container_mouse_ignore(child)

func recursive_set_container_mouse_ignore(node: Node) -> void:
	if not node is Control:
		return
	
	if node is Container:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	for child in node.get_children():
		recursive_set_container_mouse_ignore(child)

func _toggled_relay(is_on) -> void:
	emit_signal("toggled", is_on)

func set_pressed(new_pressed) -> void:
	if not toggle_mode:
		return
	pressed = new_pressed
	button.pressed = new_pressed
func get_pressed() -> bool:
	return pressed

func set_toggle_mode(new_toggle_mode) -> void:
	if not new_toggle_mode:
		set_pressed(false)
	toggle_mode = new_toggle_mode
	button.toggle_mode = new_toggle_mode
func get_toggle_mode() -> bool:
	return toggle_mode

func _notification(notification):
	if notification == NOTIFICATION_SORT_CHILDREN:
		for c in get_children():
			if c == button:
				continue
			fit_child_in_rect(c, Rect2(Vector2.ZERO, rect_size))

func _get_minimum_size() -> Vector2:
	var min_so_far: = Vector2(0, 0)
	for c in get_children():
		if not c is Control:
			continue
		if c == button:
			continue
		if c.is_set_as_toplevel():
			continue
		
		var c_min = c.get_minimum_size()
		min_so_far.x = max(min_so_far.x, c_min.x)
		min_so_far.y = max(min_so_far.y, c_min.y)
	return min_so_far
