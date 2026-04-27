extends ConfirmationDialog

signal hidden

const ConditionalEditor = preload("res://src/GameEditor/ConditionalEditor/ConditionalEditor.gd")
var conditional_editor_scn = preload("res://Scenes/GameEditor/ConditionalEditor/ConditionalEditor.tscn")

var is_entity: bool = false

var conditional_val: Variant = {}
var conditional_mode: = false

var autoshow_conditional_editor: = true

# events that have no triggering entity
const NO_OTHER_EVENTS: = [
	"i_finish_move_onto_tile", "post_move", "idle_update", "dying",
]

func _ready():
	visibility_changed.connect(Callable(self, "_on_vis_changed"))
	
	check_autoshow_conditional_editor()

func check_autoshow_conditional_editor() -> void:
	if autoshow_conditional_editor and is_v3_conditional():
		open_conditional_editor()
	
func is_v3_conditional() -> bool:
	if not conditional_val:
		return false
	var val = [conditional_val] if typeof(conditional_val) == TYPE_DICTIONARY else conditional_val
	return val[0].get("v", "") == "3"

func set_info(prop_name, prop_val) -> void:
	find_child("SetName").text = prop_name
	if typeof(prop_val) in [TYPE_DICTIONARY, TYPE_ARRAY]:
		find_child("CheckButton").set_pressed_no_signal(true)
		_on_toggle(true)
		conditional_val = prop_val
	else:
		find_child("SetValue").set_text_contents(prop_val)


func _on_EditConditional_pressed():
	open_conditional_editor()

func open_conditional_editor() -> void:
	var editor = conditional_editor_scn.instantiate()
	set_conditional_editor_smart_slot_enable(editor, find_child("SetName").text)
	editor.event_name = find_child("SetName").text
	
	var ui_root = find_parent("UIRoot")
	if not ui_root:
		print_debug("Can't get UI Layer")
		return
	
	ui_root.add_popup_layer_node(editor)
	editor.popup_centered()
	if conditional_val:
		editor.load_conditional_data(conditional_val)
	elif editor.use_conditionalv3:
		prints("loading empty v3 conditional")
		editor.load_conditional_data({"v": "3", "conditions": []})
	
	editor.save_conditional.connect(on_save_conditional)
	editor.cancelled.connect(hide)

func set_conditional_editor_smart_slot_enable(condtional_editor: ConditionalEditor, prop_name: String) -> void:
	if prop_name in NO_OTHER_EVENTS:
		condtional_editor.has_them_entity_slot = false
	if not is_entity:
		condtional_editor.has_me_entity_slot = false

func on_save_conditional(new_conditional) -> void:
	conditional_val = new_conditional
	save_prop()

func get_value():
	if conditional_mode:
		return conditional_val
	else:
		return find_child("SetValue").multi_line_contents

func _on_toggle(button_pressed):
	conditional_mode = button_pressed
	if button_pressed:
		find_child("SetValue").visible = false
		find_child("EditConditional").visible = true
	else:
		find_child("SetValue").visible = true
		find_child("EditConditional").visible = false

func _on_Button_pressed():
	if not conditional_val:
		return
	var result = OldConditionalConverter.to_new(conditional_val)
	if result:
		print("converted from old data")
		print(str(result))
		conditional_val = result

func _on_vis_changed():
	if not visible:
		hidden.emit()

func save_prop() -> void:
	confirmed.emit()
	hide()