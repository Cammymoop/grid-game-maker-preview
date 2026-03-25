extends HBoxContainer

signal step_changed(step_num: int)
signal add_step_after(step_num: int)
signal remove_step(step_num: int)

@onready var prev_step_button = find_child("PrevStepButton")
@onready var next_step_button = find_child("NextStepButton")
@onready var add_step_button = find_child("AddStepButton")
@onready var remove_step_button = find_child("RemoveStepButton")
@onready var num_label = find_child("StepNumLabel")

var step_count: int = 1
var current_step: int = 0

func _ready():
	update_ui()
	prev_step_button.pressed.connect(prev_step)
	next_step_button.pressed.connect(next_step)
	
	add_step_button.pressed.connect(add_step)
	remove_step_button.pressed.connect(remove_current_step)

func set_step(new_step_count: int, new_current_step: int) -> void:
	step_count = new_step_count
	current_step = new_current_step
	update_ui()

func prev_step():
	current_step -= 1
	notify_step_changed()

func next_step():
	current_step += 1
	notify_step_changed()

func notify_step_changed():
	current_step = clampi(current_step, 0, step_count - 1)
	update_ui()
	step_changed.emit(current_step)

func add_step():
	add_step_after.emit(current_step)

func remove_current_step():
	remove_step.emit(current_step)

func update_ui() -> void:
	update_step_label()
	update_button_states()

func update_step_label() -> void:
	num_label.text = "%d/%d" % [current_step + 1, step_count]

func update_button_states() -> void:
	prev_step_button.disabled = current_step < 1
	next_step_button.disabled = current_step >= step_count - 1
	
	remove_step_button.disabled = step_count <= 1