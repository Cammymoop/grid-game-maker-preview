extends PanelContainer

var panels = {
	Commands.Slot.RED: {
		main= preload("res://assets/ui/PropertyEditor/RedBackground.tres"),
		tab= preload("res://assets/ui/PropertyEditor/RedTabBackground.tres"),
	},
	Commands.Slot.BLUE: {
		main= preload("res://assets/ui/PropertyEditor/BlueBackground.tres"),
		tab= preload("res://assets/ui/PropertyEditor/BlueTabBackground.tres"),
	},
	Commands.Slot.WHITE: {
		main= preload("res://assets/ui/PropertyEditor/WhiteBackground.tres"),
		tab= preload("res://assets/ui/PropertyEditor/WhiteTabBackground.tres"),
	},
	Commands.Slot.PINK: {
		main= preload("res://assets/ui/PropertyEditor/PinkBackground.tres"),
		tab= preload("res://assets/ui/PropertyEditor/PinkTabBackground.tres"),
	},
}

const TAB_INTERNAL_MARGIN = 10

@onready var generated_content = find_child("GeneratedContent")
@onready var title_label = find_child("TitleText")
@onready var tab_panel = find_child("TabPanel")

var inputs = []

var current_slot: int = Commands.Slot.RED

var command_code: int
var ui_data: Dictionary

var ungenerated = true

func _ready():
	if ungenerated:
		generate_ui()

func set_ui_data(the_command_code: int, command_data: Dictionary) -> void:
	command_code = the_command_code
	ui_data = command_data

func set_slot(slot_id: int) -> void:
	current_slot = slot_id
	if is_inside_tree():
		find_child("CommandSlot").set_current_slot(slot_id)
		update_panel_background()

func update_panel_background() -> void:
	if current_slot in panels:
		var panel: = panels[current_slot].main as StyleBoxFlat
		if panel:
			title_label.add_theme_color_override("font_color", panel.border_color)
			add_theme_stylebox_override("panel", panel)
		tab_panel.add_theme_stylebox_override("panel", panels[current_slot].tab)

func add_generated_row() -> HBoxContainer:
	var new_row = HBoxContainer.new()
	new_row.custom_minimum_size.y = 34
	generated_content.add_child(new_row)
	return new_row

func generate_ui() -> void:
	ungenerated = false
	for child in generated_content.get_children():
		generated_content.remove_child(child)
		child.queue_free()
	
	var current_row = add_generated_row()
	
	title_label.text = ""
	
	if not ui_data:
		return
	
	inputs = []
	
	title_label.text = ui_data.display_name
	
	tab_panel.size.x = title_label.get_minimum_size().x + TAB_INTERNAL_MARGIN
	
	for ui_bit in ui_data.ui:
		if ui_bit == "br":
			current_row = add_generated_row()
		elif ui_bit[0] == "[":
			var input_name = ui_bit.substr(1)
			if not input_name in ui_data.options:
				print_debug("Option not found: " + input_name)
				continue
			
			var input_type = ui_data.options[input_name].input_type
			var input = InputTemplates.templates[input_type].instantiate()
			current_row.add_child(input)
			if ui_data.options[input_name].has("template_options"):
				if input.has_method("apply_template_options"):
					input.apply_template_options(ui_data.options[input_name]["template_options"])
			inputs.append(input)
		else:
			var text = Label.new()
			text.text = ui_bit
			
			current_row.add_child(text)
	
	if "slot_types" in ui_data:
		find_child("CommandSlot").set_valid_slot_categories(ui_data.slot_types)
	
	set_slot(current_slot)
	
	await get_tree().process_frame

func get_command_code() -> int:
	return command_code

func get_slot_id() -> int:
	return current_slot

func get_option_values() -> Array:
	var vals = []
	for input_thing in inputs:
		vals.append(input_thing.get_value())
	
	return vals

func set_option_values(new_values: Array) -> void:
	if len(new_values) > len(inputs):
		print_debug("Too many option values")
	
	for i in range(len(new_values)):
		inputs[i].set_value(new_values[i])

func get_command_data() -> Dictionary:
	return {
		code= get_command_code(),
		slot= get_slot_id(),
		options= get_option_values(),
	}

func _on_TextureRect_gui_input(event):
	var e = event as InputEventMouseButton
	if not e:
		return
	if e.button_mask == MOUSE_BUTTON_MASK_LEFT and e.is_pressed():
		queue_free()


func _on_CommandSlot_slot_changed(new_slot_id):
	current_slot = new_slot_id
	update_panel_background()
