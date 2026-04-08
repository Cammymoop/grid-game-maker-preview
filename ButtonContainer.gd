@tool
extends Container
class_name ButtonContainer

signal button_down
signal button_up
signal pressed
signal toggled(button_pressed: bool)

var button: Button

@export var disabled_child_modulate: Color = Color(1, 1, 1, 0.7)

var small_font = preload("res://assets/font/img_font_white_reformat.png")

@export var toggle_mode = false:
	get:
		return button.toggle_mode
	set(value):
		button.toggle_mode = value

@export var button_pressed = false:
	get:
		return button.button_pressed
	set(value):
		button.button_pressed = value

@export var disabled: bool = false:
	get:
		return button.disabled
	set(value):
		button.disabled = value
		update_child_modulate()

func _init():
	button = Button.new()
	button.name = "BGButton"
	button.show_behind_parent = true
	button.mouse_filter = mouse_filter
	add_child(button)
	button.anchor_right = 1
	button.anchor_bottom = 1
	button.offset_right = 0
	button.offset_bottom = 0
	
	# slight hack to make the button have a shorter minimum size
	button.add_theme_font_override("font", small_font)
	
	button.button_down.connect(button_down.emit)
	button.button_up.connect(button_up.emit)
	button.pressed.connect(pressed.emit)
	button.toggled.connect(toggled.emit)
	
	button.mouse_entered.connect(mouse_entered.emit)
	button.mouse_exited.connect(mouse_exited.emit)
	
	child_entered_tree.connect(on_child_entered_tree)

func set_disabled(new_disabled: bool) -> void:
	button.disabled = new_disabled

func on_child_entered_tree(child: Node) -> void:
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

func _notification(the_notification: int):
	if the_notification == NOTIFICATION_SORT_CHILDREN:
		for c in get_children():
			if c == button:
				continue
			fit_child_in_rect(c, Rect2(Vector2.ZERO, size))

func _get_minimum_size() -> Vector2:
	var min_so_far: = Vector2(0, 0)
	for c in get_children():
		if not c is Control:
			continue
		if c == button:
			continue
		if c.is_set_as_top_level():
			continue
		
		var c_min = c.get_minimum_size()
		min_so_far.x = max(min_so_far.x, c_min.x)
		min_so_far.y = max(min_so_far.y, c_min.y)
	return min_so_far

func update_child_modulate() -> void:
	if Engine.is_editor_hint():
		return
	for c in get_children():
		if c is CanvasItem:
			c.modulate = disabled_child_modulate if disabled else Color.WHITE