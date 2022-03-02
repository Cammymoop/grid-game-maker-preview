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

onready var generated_content = find_node("GeneratedContent")
onready var command_slot = find_node("CommandSlot")
onready var title_label = find_node("TitleText")
onready var tab_panel = find_node("TabPanel")

var current_slot: int = Commands.Slot.RED

var ui_data: Dictionary

func _ready():
	generate_ui()

func set_ui_data(command_data: Dictionary) -> void:
	ui_data = command_data

func set_slot(slot_id: int) -> void:
	current_slot = slot_id
	if is_inside_tree():
		find_node("CommandSlot").set_current_slot(slot_id)
		update_panel_background()

func update_panel_background() -> void:
	print_debug("new panel time")
	if current_slot in panels:
		print_debug("new panel is")
		add_stylebox_override("panel", panels[current_slot].main)
		tab_panel.add_stylebox_override("panel", panels[current_slot].tab)
		var box: StyleBoxFlat = get_stylebox("panel") as StyleBoxFlat
		if box:
			title_label.add_color_override("font_color", box.border_color)

func generate_ui() -> void:
	for child in generated_content.get_children():
		child.queue_free()
	
	title_label.text = ""
	
	if not ui_data:
		return
	
	title_label.text = ui_data.display_name
	
	tab_panel.rect_size.x = title_label.get_minimum_size().x + TAB_INTERNAL_MARGIN
	
	for ui_bit in ui_data.ui:
		if ui_bit[0] == "[":
			var input_name = ui_bit.substr(1)
			if not input_name in ui_data.options:
				print_debug("Option not found: " + input_name)
				continue
			
			var input_type = ui_data.options[input_name].input_type
			var input = InputTemplates.templates[input_type].instance()
			generated_content.add_child(input)
		else:
			var text = Label.new()
			text.text = ui_bit
			
			generated_content.add_child(text)
	
	set_slot(current_slot)
	
	yield(get_tree(), "idle_frame")


func _on_TextureRect_gui_input(event):
	var e = event as InputEventMouseButton
	if not e:
		return
	if e.button_mask == BUTTON_MASK_LEFT and e.is_pressed():
		queue_free()


func _on_CommandSlot_slot_changed(new_slot_id):
	current_slot = new_slot_id
	update_panel_background()
