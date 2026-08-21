extends Node

var undo_stacks = {}
var button_refernces = {}


func add_undo_stack(undo_name: String, max_undos: int = 0, save_redos: bool = true) -> void:
	undo_stacks[undo_name] = {
		undos = [],
		redos = [],
		max_undos = max_undos,
		save_redos = save_redos
	}
func set_buttons(for_thing: String, undo_button: Node = null, redo_button: Node = null) -> void:
	button_refernces[for_thing] = [undo_button, redo_button]

func _update_undo_redo_buttons(undo_name: String) -> void:
	if undo_name in button_refernces:
		var buttons = button_refernces[undo_name]
		if buttons[0]:
			buttons[0].disabled = len(undo_stacks[undo_name].undos) < 1
		if buttons[1]:
			buttons[1].disabled = len(undo_stacks[undo_name].redos) < 1

func has_undo(undo_name: String) -> bool:
	return len(undo_stacks[undo_name].undos) > 0
func has_redo(undo_name: String) -> bool:
	return len(undo_stacks[undo_name].redos) > 0

func _truncate_undo_stack(undo_name: String) -> void:
	var stack = undo_stacks[undo_name]
	if stack.max_undos == 0:
		return
	if len(stack.undos) >= stack.max_undos:
		var last = len(stack.undos) - 1
		stack.undos = stack.undos.slice(last - stack.max_undos, last)

# Saves a current value (will save objects by reference)
func save_current(undo_name: String, current_value) -> void:
	_truncate_undo_stack(undo_name)
	undo_stacks[undo_name].undos.append(current_value)
	undo_stacks[undo_name].redos = []
	_update_undo_redo_buttons(undo_name)

func save_current_image(undo_name: String, current_image: Image) -> void:
	var copy = Image.new()
	copy.copy_from(current_image)
	save_current(undo_name, copy)

# get the top undo off the stack
# also save the current value to the redo stack
# (assumes the caller will drop the refernce to the current value)
# if the undo stack is empty it will return null, the redo can be fetched in 
# that case if redos are enabled, better to just check has_undo() first
func undo(undo_name, current_value = null):
	var stack = undo_stacks[undo_name]
	if stack.save_redos:
		_push_redo(undo_name, current_value)
	if len(stack.undos) == 0:
		return null
	var popped_undo = stack.undos.pop_back()
	_update_undo_redo_buttons(undo_name)
	return popped_undo

func drop_undo(undo_name: String) -> void:
	if len(undo_stacks[undo_name].undos) == 0:
		return
	undo_stacks[undo_name].undos.pop_back()
	_update_undo_redo_buttons(undo_name)

func _push_redo(undo_name: String, value) -> void:
	undo_stacks[undo_name].redos.append(value)

# get the top redo off the stack
# also save the current value to the undo stack
# (assumes the caller will drop the refernce to the current value)
func redo(undo_name, current_value):
	var stack = undo_stacks[undo_name]
	stack.undos.append(current_value)
	if len(stack.redos) == 0:
		return null
	var popped_redo = stack.redos.pop_back()
	_update_undo_redo_buttons(undo_name)
	return popped_redo
