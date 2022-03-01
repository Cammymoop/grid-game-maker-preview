extends Control

onready var vbox = find_node("VBox")
onready var vbox2 = find_node("VBox2")

onready var add_condition_dialog = find_node("AddConditionDialog")
onready var add_action_dialog = find_node("AddActionDialog")

var command_list_item: PackedScene = preload("res://Scenes/GameEditor/CommandListItem.tscn")

func _ready():
	for test_command in [Commands.CC.A_DIE, Commands.CC.C_HAS_PROPERTY, Commands.CC.C_CAN_MOVE, Commands.CC.A_FIND_SWAP_TILES]:
		pass
#		var new_list_item = command_list_item.instance()
#		var new_list_item2 = command_list_item.instance()
#		new_list_item.set_ui_data(Commands.Friendly[test_command])
#		new_list_item2.set_ui_data(Commands.Friendly[test_command])
#
#		vbox.add_child(new_list_item)
#		vbox2.add_child(new_list_item2)
	
	add_condition_dialog.connect("command_selected", self, "add_command")
	add_action_dialog.connect("command_selected", self, "add_action")

func add_command(command_id: int, slot_id: int) -> void:
		var new_list_item = command_list_item.instance()
		new_list_item.set_slot(slot_id)
		new_list_item.set_ui_data(Commands.Friendly[command_id])
		
		vbox.add_child(new_list_item)

func add_action(command_id: int, slot_id: int) -> void:
		var new_list_item = command_list_item.instance()
		new_list_item.set_slot(slot_id)
		new_list_item.set_ui_data(Commands.Friendly[command_id])
		
		vbox2.add_child(new_list_item)


func _on_NewConditionButton_pressed():
	add_condition_dialog.popup_centered()


func _on_NewActionButton_pressed():
	add_action_dialog.popup_centered()
