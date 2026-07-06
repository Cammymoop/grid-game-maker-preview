extends Window

const ActionsTabs = preload("res://src/GameEditor/ConditionalEditor/ActionsTabs.gd")

signal cancelled
signal save_conditional(conditional_data: Variant)

@onready var cond_list: = find_child("ConditionsList") as ConditionsCommandList
@onready var cond_list_tab = find_child("Conditions")
@onready var true_actions_list = find_child("TrueActionsList")
@onready var false_actions_list = find_child("FalseActionsList")
@onready var always_actions_list = find_child("AlwaysActionsList")

var when_lists: Dictionary = {}
@export var when_list_container: Control
@export var event_name_label: Label
@export var event_name: String = ""

@export var save_button: Button

@export var editable: bool = true

@onready var add_command_dialog = find_child("AddCommandDialog")

@onready var action_tabs: ActionsTabs = find_child("ActionsTabs")

@onready var steps_ui = find_child("StepsUI")

const CommandListItem = preload("res://src/GameEditor/ConditionalEditor/CommandListItem.gd")
var command_list_item: PackedScene = preload("res://Scenes/GameEditor/ConditionalEditor/CommandListItem.tscn")

var when_list_scn: PackedScene = preload("res://Scenes/GameEditor/ConditionalEditor/when_list.tscn")

var use_conditionalv3 = true

var current_conditional: Array[Dictionary] = []

var step_count: int = 1
var current_step: int = 0

var replace_to_index: int = -1
var is_new_command_replace: bool = false
var replace_from_list: Control = null

var has_me_entity_slot: bool = true
var has_them_entity_slot: bool = true

var adding_command_to_destination: String = "conditions"

static var last_size: Vector2i = Vector2i(0, 0)

var _sized: = false

func _init() -> void:
    if last_size.x > 0 and last_size.y > 0:
        size = last_size
        _sized = true

func _ready():
    if not _sized:
        var window_size: = get_tree().root.size
        size.y = maxf(size.y, window_size.y * 0.8)
        size.x = maxf(size.x, window_size.x * 0.7)
    
    if not editable:
        save_button.text = "Override and Save"

    if not event_name:
        event_name_label.hide()
    else:
        event_name_label.text = event_name
        if event_name in GameManager.SPECIAL_PROPS:
            event_name_label.tooltip_text = GameManager.get_special_prop_hint_text(event_name)
            event_name_label.add_theme_color_override("font_color", Color(0.47, 0.77, 0.99))
        elif event_name in ConditionalsV3.all_events:
            event_name_label.tooltip_text = ConditionalsV3.get_event_hint_text(event_name)
        else:
            event_name_label.tooltip_text = "Custom conditional property or event"
            event_name_label.add_theme_color_override("font_color", Color(0.7, 0.2, 0.2))
    var add_new_command_func = add_new_v3_command if use_conditionalv3 else add_v2_command
    add_command_dialog.connect("command_selected", add_new_command_func)
    add_command_dialog.hidden.connect(on_add_command_hidden)
    #_old_add_action_dialog.connect("command_selected", add_new_command_func.bind("actions"))
    #_old_add_action_dialog.hidden.connect(on_add_action_hidden)
    
    if not use_conditionalv3:
        steps_ui.hide()
    else:
        var when_list_names: = ["when true", "when false", "always"]
        for i in when_list_names.size():
            when_lists[when_list_names[i]] = action_tabs.get_child(i)

        true_actions_list = null
        false_actions_list = null
        always_actions_list = null
        steps_ui.show()
    
    action_tabs.tab_changed.connect(on_actions_tab_changed)
    
    steps_ui.step_changed.connect(on_step_changed)
    steps_ui.add_step_after.connect(on_add_step_after)
    steps_ui.remove_step.connect(on_remove_step)
    steps_ui.request_move_step.connect(on_move_step)
    
    close_requested.connect(cancel)
    
    size_changed.connect(on_size_changed)
    
    popup()

func on_size_changed() -> void:
    last_size = size

func _shortcut_input(event: InputEvent) -> void:
    if Utility.event_is_menu_back_just_pressed(event):
        cancel()

func add_new_command(command_code: int, slot_id: int, destination: String) -> void:
    if use_conditionalv3:
        push_error("adding new v3 command with old method")
        return
    add_v2_command(command_code, slot_id, destination, [])

func add_v2_command(command_code: int, slot_id: int, destination: String, option_values: Array = []) -> void:
    var new_list_item = command_list_item.instantiate()
    new_list_item.set_ui_data(command_code, Commands.Friendly[command_code])
    new_list_item.set_slot(slot_id)

    var to_list = cond_list
    match destination:
        "actions":
            to_list = action_tabs.get_current_list()
        "conditions":
            to_list = cond_list
        "true_actions":
            to_list = true_actions_list
        "false_actions":
            to_list = false_actions_list
        "always_actions":
            to_list = always_actions_list
        _:
            print_debug("unkown command list: %s" % destination)
    
    to_list.add_child(new_list_item)
    
    if option_values:
        new_list_item.generate_ui()
        new_list_item.set_option_values(option_values)

func add_new_v3_command(qualified_cmd: String, slot_id: int) -> void:
    var destination: String = adding_command_to_destination

    var short_name = ConditionalsV3.command_short_name(qualified_cmd)
    if not qualified_cmd:
        push_error("Command not found: %s" % short_name)
        return
    var new_list_item = create_v3_command_item(qualified_cmd)
    if slot_id >= 0:
        new_list_item.set_slot(slot_id)
    else:
        new_list_item.current_slot = -1

    if is_new_command_replace:
        replace_with_new_command(replace_from_list, replace_to_index, new_list_item)
        is_new_command_replace = false
        return

    var list_name: String = destination
    if destination == "actions":
        var cur_list_node: = action_tabs.get_current_list()
        if not cur_list_node in when_lists.values():
            push_error("Current action list is not a when list %s %s" % [cur_list_node, when_lists.values()])
            return
        list_name = when_lists.find_key(cur_list_node)
    append_item_to_command_list(new_list_item, list_name)

func replace_with_new_command(command_list: Control, command_index: int, new_command: CommandListItem) -> void:
    if command_list == cond_list:
        cond_list.replace_command_at(command_index, new_command)
    else:
        var old_command = command_list.get_child(command_index)
        command_list.remove_child(old_command)
        old_command.queue_free()
        command_list.add_child(new_command)
        command_list.move_child(new_command, command_index)

func create_v3_command_item(qualified_name: String, arg_string: String = "") -> CommandListItem:
    var short_name = ConditionalsV3.command_short_name(qualified_name)
    var new_list_item = command_list_item.instantiate()

    var disabled_slots: Array = []
    if not has_me_entity_slot:
        disabled_slots.append(Commands.Slot.RED)
        # I want to disable pink but if the event has neither red nor blue prefilled slots then it wouldn't have at least two entity slots which would not be ideal
        # TODO: Should add at least one more general purpose entity slot
        #disabled_slots.append(Commands.Slot.PINK)
    if not has_them_entity_slot:
        disabled_slots.append(Commands.Slot.BLUE)
    if disabled_slots:
        new_list_item.set_disabled_slots(disabled_slots)

    new_list_item.set_v3_data(qualified_name, short_name, ConditionalsV3.get_command_info(qualified_name))
    new_list_item.set_arg_values(ConditionalsV3.arg_string_to_arg_values(arg_string))
    
    return new_list_item

func load_conditional_data(from_data: Variant) -> void:
    if _is_raw_data_v3(from_data):
        load_v3_conditional_data(from_data)
        return

    for sublist in from_data:
        if not sublist in ["conditions", "true_actions", "false_actions", "always_actions"]:
            continue
        for command in from_data[sublist]:
            var opts = command.options if command.has("options") else []
            add_v2_command(command.code, command.slot, sublist, opts)

func load_v3_conditional_data(from_data: Variant) -> void:
    if typeof(from_data) == TYPE_DICTIONARY:
        from_data = [from_data]
    var arr_data = from_data as Array
    if not arr_data:
        push_error("Invalid v3 conditional data type")
        return

    setup_step_count(len(arr_data))
    set_v3_full_data(arr_data)
    load_v3_conditional_data_step(arr_data[current_step])

func set_v3_full_data(new_data: Array) -> void:
    current_conditional.clear()
    for cond_step in new_data:
        if cond_step is Dictionary:
            current_conditional.append(cond_step)
        else:
            push_warning("Non-dictionary step data: %s" % str(cond_step))

func load_v3_conditional_data_step(from_data: Dictionary) -> void:
    clear_edited_step()
    #add_when_list("when true")
    #add_when_list("when false")
    #add_when_list("always")
    var show_when_list: String = "when true"
    if "when always" in from_data and from_data["when always"].size() > 0:
        show_when_list = "always"
    elif "when false" in from_data and from_data["when false"].size() > 0:
        show_when_list = "when false"
    action_tabs.set_current_list(show_when_list)

    for key in from_data:
        if key != "conditions" and not key.begins_with("when "):
            continue
        var new_list_items: Array = []
        for call_string in from_data[key]:
            if ConditionalsV3.is_builtin(call_string):
                new_list_items.append(call_string)
            else:
                var qualified_name = ConditionalsV3.callstring_to_qualified_name(call_string)
                var arg_string = ConditionalsV3.callstring_to_arg_string(call_string)
                var new_list_item = create_v3_command_item(qualified_name, arg_string)
                new_list_items.append(new_list_item)
        set_command_list_items(new_list_items, key)
    
    update_actions_list_content_flags()

func set_command_list_items(new_list_items: Array, command_list_name: String) -> void:
    if command_list_name == "conditions":
        cond_list.set_command_list(new_list_items)
    else:
        for new_list_item in new_list_items:
            append_item_to_command_list(new_list_item, command_list_name)

func append_item_to_command_list(new_list_item: CommandListItem, command_list_name: String) -> void:
    if command_list_name == "conditions":
        cond_list.append_command(new_list_item)
    else:
        if command_list_name == "when always":
            command_list_name = "always"
        if command_list_name not in when_lists:
            push_error("when list: %s not found, adding" % command_list_name)
            #prints("when list: %s not found, adding" % command_list_name)
            #add_when_list(command_list_name)
        when_lists[command_list_name].get_list().add_child(new_list_item)

func add_when_list(command_list_name: String) -> void:
    var new_list = when_list_scn.instantiate()
    new_list.name = command_list_name.capitalize()
    when_list_container.add_child(new_list, true)
    when_lists[command_list_name] = new_list

func remove_when_list(command_list_name: String) -> void:
    if command_list_name in when_lists:
        var when_list = when_lists[command_list_name]
        when_list_container.remove_child(when_list)
        when_list.queue_free()
        when_lists.erase(command_list_name)

func _is_raw_data_v3(the_data: Variant) -> bool:
    if typeof(the_data) == TYPE_DICTIONARY:
        return the_data.get("v", "") == "3"
    elif typeof(the_data) == TYPE_ARRAY:
        return the_data.size() > 0 and the_data[0].get("v", "") == "3"
    else:
        return false

func get_full_conditional_data() -> Variant:
    if use_conditionalv3:
        return get_v3_full_conditional_data()

    var data = {
        "conditions": [],
        "true_actions": [],
        "false_actions": [],
        "always_actions": [],
    }
    
    for command_node in cond_list.get_children():
        data.conditions.append(make_command_data(command_node))
    for command_node in true_actions_list.get_children():
        data.true_actions.append(make_command_data(command_node))
    for command_node in false_actions_list.get_children():
        data.false_actions.append(make_command_data(command_node))
    for command_node in always_actions_list.get_children():
        data.always_actions.append(make_command_data(command_node))
    
    return data

func get_v3_full_conditional_data() -> Variant:
    update_current_step()
    if step_count == 1:
        return get_v3_conditional_step_data(0)
    return current_conditional.duplicate(true)

func get_v3_conditional_step_data(step_num: int) -> Dictionary:
    return current_conditional[step_num].duplicate()

func update_current_step() -> void:
    var data = {
        "v": "3",
        "conditions": [],
    }
    
    data.conditions = cond_list.get_v3_command_data()
    for when_list_name in when_lists:
        var data_key: String = when_list_name
        if when_list_name == "always":
            data_key = "when always"
        data[data_key] = []
        for command_node in when_lists[when_list_name].get_list().get_children():
            data[data_key].append(make_v3_command_data(command_node))
    
    current_conditional[current_step] = data

func make_v3_command_data(command_input_node) -> String:
    return command_input_node.get_v3_call_string()

func make_command_data(command_input_node) -> Dictionary:
    return command_input_node.get_command_data()

func _on_NewConditionButton_pressed():
    adding_command_to_destination = "conditions"
    add_command_dialog.set_list_and_mode("Conditions", true)
    add_command_dialog.popup_centered()
    
func _on_NewActionButton_pressed():
    var action_list_title: = get_current_action_list_tab_title()
    adding_command_to_destination = "actions"
    add_command_dialog.set_list_and_mode(action_list_title, false)
    add_command_dialog.popup_centered()
    #_old_add_action_dialog.popup_centered()

func open_new_command_for_replace(command_list: Control, command_index: int) -> void:
    is_new_command_replace = true
    replace_to_index = command_index
    replace_from_list = command_list
    if command_list == cond_list:
        adding_command_to_destination = "conditions"
        add_command_dialog.set_list_and_mode("Conditions", true)
    else:
        adding_command_to_destination = "actions"
        add_command_dialog.set_list_and_mode(get_current_action_list_tab_title(), false)
    add_command_dialog.popup_centered()

func _on_SaveButton_pressed():
    save_conditional.emit(get_full_conditional_data())
    queue_free()

func _on_CancelButton_pressed():
    cancel()

func setup_step_count(new_step_count: int) -> void:
    step_count = new_step_count
    current_step = 0
    steps_ui.set_step(step_count, current_step)
    current_conditional.resize(step_count)

func on_step_changed(new_step_num: int) -> void:
    update_current_step()
    current_step = new_step_num
    load_current_step()

func on_add_step_after(after_step_num: int) -> void:
    update_current_step()
    current_conditional.insert(after_step_num + 1, {"v": "3"})
    step_count = current_conditional.size()
    current_step = after_step_num + 1
    steps_ui.set_step(step_count, current_step)
    load_current_step()

func on_remove_step(step_num: int) -> void:
    if step_count < 2:
        return
    current_conditional.remove_at(step_num)
    step_count = current_conditional.size()
    current_step = clampi(current_step, 0, step_count - 1)
    steps_ui.set_step(step_count, current_step)
    load_current_step()

func load_current_step() -> void:
    clear_edited_step()
    load_v3_conditional_data_step(current_conditional[current_step])

func clear_edited_step() -> void:
    cond_list.clear_commands()
    clear_when_lists()

func _clear_list(list_node: Node) -> void:
    for child in list_node.get_children():
        list_node.remove_child(child)
        child.queue_free()

func clear_when_lists() -> void:
    action_tabs.clear_list_contents()
    #for when_list_name in when_lists.keys():
        #remove_when_list(when_list_name)

func cancel() -> void:
    emit_signal("cancelled")
    queue_free()

func on_add_command_hidden() -> void:
    await get_tree().process_frame
    if is_new_command_replace:
        is_new_command_replace = false

func get_current_action_list_tab_title() -> String:
    return action_tabs.get_tab_title(action_tabs.current_tab)

func on_move_step(direction: int) -> void:
    var new_step_index: = current_step + direction
    if new_step_index < 0 or new_step_index >= step_count:
        return
    if current_conditional.size() != step_count:
        push_error("Step count mismatch: %d != %d" % [current_conditional.size(), step_count])
        return
    update_current_step()
    
    var step_data = current_conditional[current_step]
    current_conditional.remove_at(current_step)
    current_conditional.insert(new_step_index, step_data)
    current_step = new_step_index
    steps_ui.set_step(step_count, current_step)
    
func update_actions_list_content_flags() -> void:
    var content_flags: Array = []

    var true_list_count = 0
    if "when true" in when_lists:
        true_list_count = when_lists["when true"].get_list().get_child_count()
    content_flags.append(true_list_count > 0)

    var false_list_count = 0
    if "when true" in when_lists:
        false_list_count = when_lists["when false"].get_list().get_child_count()
    content_flags.append(false_list_count > 0)

    var always_list_count = 0
    if "always" in when_lists:
        always_list_count = when_lists["always"].get_list().get_child_count()
    content_flags.append(always_list_count > 0)

    action_tabs.update_list_content_flags(content_flags)

func on_actions_tab_changed(_tab_index: int) -> void:
    update_actions_list_content_flags()