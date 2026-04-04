extends PanelContainer

const ConditionalEditor = preload("res://src/GameEditor/ConditionalEditor/ConditionalEditor.gd")

const TAB_INTERNAL_MARGIN = 10

@onready var generated_content = find_child("GeneratedContent")
@onready var title_label = find_child("TitleText")
@onready var tab_panel = find_child("TabPanel")

var inputs = []

var is_v3 = false

var current_slot: int = Commands.Slot.RED

var parent_list: Control = null

# v2 data:
var command_code: int
var ui_data: Dictionary

# v3 data:
var qualified_command_name: String
var short_command_name: String
var command_info: Dictionary
var no_slot: bool = false
var is_builtin: bool = false

var _ungenerated = true
var _pre_set_arg_values: Array = []

const builtin_descriptions: = {
    "true": "Change the result to true",
    "false": "Change the result to false",
}

const CONTEXT_MENU_MOVE_UP = 10
const CONTEXT_MENU_MOVE_DOWN = 11
const CONTEXT_MENU_MOVE_TOP = 12
const CONTEXT_MENU_MOVE_BOTTOM = 13

const CONTEXT_MENU_DUPLICATE = 20
const CONTEXT_MENU_REPLACE = 21
const CONTEXT_MENU_DELETE = 22

func _ready():
    if _ungenerated:
        generate_ui()

func get_parent_list() -> Control:
    if not parent_list:
        parent_list = get_parent()
    return parent_list

func _get_duplicate_item() -> Control:
    var duplicate_item: Control = duplicate(Node.DUPLICATE_USE_INSTANTIATION)
    duplicate_item.parent_list = parent_list
    duplicate_item.set_v3_data(qualified_command_name, short_command_name, command_info)
    duplicate_item.set_arg_values(get_v3_arg_values())
    return duplicate_item

func set_ui_data(the_command_code: int, command_data: Dictionary) -> void:
    command_code = the_command_code
    ui_data = command_data

func set_v3_data(qualified_name: String, short_name: String, new_command_info: Dictionary) -> void:
    is_v3 = true
    qualified_command_name = qualified_name
    short_command_name = short_name
    command_info = new_command_info
    if qualified_name in builtin_descriptions:
        no_slot = true
        is_builtin = true
        ui_data = {"display_name": qualified_name.capitalize()}
    else:
        ui_data = {"display_name": command_info["display_name"]}

func set_disabled_slots(disabled_slots: Array) -> void:
    var command_slot_selector: Control = find_child("CommandSlot")
    if command_slot_selector:
        command_slot_selector.set_disabled_slots(disabled_slots)

func set_slot(slot_id: int) -> void:
    if slot_id < 0:
        slot_id = find_child("CommandSlot").get_first_valid_slot_id()
    current_slot = slot_id
    if is_inside_tree():
        find_child("CommandSlot").set_current_slot(slot_id)
        update_panel_background()

func update_panel_background() -> void:
    var styleboxes = UiUtil.get_command_item_styleboxes_for_slot(current_slot)
    var font_color = styleboxes["bg"].border_color
    add_theme_stylebox_override("panel", styleboxes["bg"])
    tab_panel.add_theme_stylebox_override("panel", styleboxes["tab"])
    title_label.add_theme_color_override("font_color", font_color)
    var main_font_color = Color.BLACK if styleboxes["bg"].bg_color.ok_hsl_l > 0.7 else Color.WHITE
    $Content.theme.set_color("font_color", "Label", main_font_color)

func add_generated_row() -> HBoxContainer:
    var new_row = HBoxContainer.new()
    new_row.custom_minimum_size.y = 34
    generated_content.add_child(new_row)
    return new_row

func generate_ui() -> void:
    _ungenerated = false
    for child in generated_content.get_children():
        generated_content.remove_child(child)
        child.queue_free()
    if is_v3:
        generate_v3_ui()
        return
    
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
            var input = InputTemplates.get_template(input_type)
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

func generate_v3_ui() -> void:
    title_label.text = ui_data.display_name
    tab_panel.size.x = title_label.get_minimum_size().x + TAB_INTERNAL_MARGIN
    
    var command_slot_selector = find_child("CommandSlot")
    if no_slot:
        command_slot_selector.hide()

    if is_builtin:
        var row: HBoxContainer = add_generated_row()
        var label: Label = Label.new()
        label.text = builtin_descriptions[qualified_command_name]
        row.add_child(label)
        return
    
    command_slot_selector.set_valid_slot_categories(ConditionalsV3.get_command_slot_type_hint(qualified_command_name))
    set_slot(current_slot)
    
    var ui_template_string: String = command_info.get("template_text", "") as String
    var template_split: = Array(ui_template_string.split("[", true))
    var prefix_str: String = template_split.pop_front()
    
    var current_row: HBoxContainer = null
    # add the text before the first input template value if there is any
    if prefix_str:
        for line in prefix_str.split("\n"):
            current_row = add_generated_row()
            var prefix_text = Label.new()
            prefix_text.text = line
            current_row.add_child(prefix_text)
    else:
        current_row = add_generated_row()

    var arg_names: = command_info.args as Array

    # each part is now a input template value followed by ] and 0 or more chars of plain text/newlines
    for split_part: String in template_split:
        var subsplit: = split_part.split("]", true, 1)
        var input_info: = subsplit[0].split(":", true)
        if input_info.size() >= 2 and input_info[1] in InputTemplates.InputTypes:
            if input_info[0] not in arg_names:
                push_error("arg name %s not found in arg list for command %s" % [input_info[0], qualified_command_name])
            var input_type: InputTemplates.InputTypes = InputTemplates.InputTypes[input_info[1]]
            var input_node: Control = InputTemplates.get_template(input_type)
            if input_info.size() > 2:
                var input_args: = input_info[2].split(",", true)
                if not input_node.has_method("set_input_args"):
                    push_error("%s passed input args but %s does not have a set_input_args method" % [qualified_command_name, input_info[1]])
                else:
                    input_node.set_input_args(input_args)
            input_node.set_arg_name(input_info[0])
            current_row.add_child(input_node)
            inputs.append(input_node)
        else:
            push_error("invalid input template value: %s in command %s" % [input_info, qualified_command_name])
        
        if subsplit.size() > 1 and subsplit[1]:
            var just_text: String = subsplit[1]
            while just_text.contains("\n"):
                var split_on_newline: = just_text.split("\n", true, 1)
                if split_on_newline[0]:
                    var pre_newline_text = Label.new()
                    pre_newline_text.text = split_on_newline[0]
                    current_row.add_child(pre_newline_text)
                current_row = add_generated_row()
                just_text = split_on_newline[1]
            var text_node = Label.new()
            text_node.text = just_text
            current_row.add_child(text_node)
    
    if _pre_set_arg_values:
        set_arg_values(_pre_set_arg_values)
        _pre_set_arg_values = []

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

func get_v3_call_string() -> String:
    var arg_string: = get_arg_string()
    if arg_string:
        return qualified_command_name + "::" + arg_string
    else:
        return qualified_command_name

func get_arg_string() -> String:
    var arg_names: = command_info.args as Array

    var arg_list: Array = [current_slot]
    var ui_values: = get_v3_ui_values()
    for ui_val_key in ui_values:
        if ui_val_key not in arg_names:
            push_error("UI arg key %s not found in arg list for command %s" % [ui_val_key, qualified_command_name])

    for arg_name in arg_names:
        if arg_name in ui_values:
            arg_list.append(ui_values[arg_name])
        else:
            push_error("Arg %s not found in UI values for command %s" % [arg_name, qualified_command_name])
            arg_list.append(0)

    return ConditionalsV3.arg_values_to_arg_string(arg_list)

func get_v3_arg_values() -> Array:
    return ConditionalsV3.arg_string_to_arg_values(get_arg_string())

func set_arg_values(arg_values: Array) -> void:
    if _ungenerated:
        _pre_set_arg_values = arg_values.duplicate()
        return
    if len(arg_values) < 1:
        return
    else:
        set_slot(arg_values.pop_front())

    var arg_names: = command_info.args as Array
    if len(arg_names) != len(inputs):
        push_error("Command UI has the wrong number of inputs for arguments: %d/%d for command %s" % [len(inputs), len(arg_names), qualified_command_name])
        return
    if not arg_names:
        return
    if len(arg_names) != len(arg_values):
        push_error("Wrong number of values for required arguments for command %d/%d: %s" % [len(arg_values), len(arg_names), qualified_command_name])
        return
    
    var input_names: Array[String] = []
    for input_item in inputs:
        input_names.append(input_item.get_arg_name())

    for i in range(len(arg_names)):
        var arg_name = arg_names[i]
        var input_item = inputs[input_names.find(arg_name)]
        input_item.set_value(arg_values[i])

func get_v3_ui_values() -> Dictionary:
    var ui_values: = {}
    for input_item in inputs:
        ui_values[input_item.get_arg_name()] = input_item.get_value()
    return ui_values

func _on_TextureRect_gui_input(event):
    var e = event as InputEventMouseButton
    if not e:
        return
    if e.button_mask == MOUSE_BUTTON_MASK_LEFT and e.is_pressed():
        delete_self()

func delete_self() -> void:
    if get_parent_list() is ConditionsCommandList:
        get_parent_list().remove_command(self)
        queue_free()
    else:
        queue_free()

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT and not event.is_pressed():
            do_context_menu()

func do_context_menu() -> void:
    var context_menu = Utility.get_empty_context_menu()
    context_menu.add_item("Move up", CONTEXT_MENU_MOVE_UP)
    context_menu.add_item("Move down", CONTEXT_MENU_MOVE_DOWN)
    context_menu.add_item("Move to top", CONTEXT_MENU_MOVE_TOP)
    context_menu.add_item("Move to bottom", CONTEXT_MENU_MOVE_BOTTOM)
    context_menu.add_separator()
    context_menu.add_item("Duplicate", CONTEXT_MENU_DUPLICATE)
    context_menu.add_item("Replace", CONTEXT_MENU_REPLACE)
    context_menu.add_item("Delete", CONTEXT_MENU_DELETE)
    context_menu.id_pressed.connect(on_context_menu_id_pressed)
    get_window().add_child(context_menu)
    Utility.popup_context_menu_at_mouse(context_menu)

func on_context_menu_id_pressed(context_menu_id: int) -> void:
    match context_menu_id:
        CONTEXT_MENU_MOVE_UP:
            move_relative(-1)
        CONTEXT_MENU_MOVE_DOWN:
            move_relative(1)
        CONTEXT_MENU_MOVE_TOP:
            move_to_top()
        CONTEXT_MENU_MOVE_BOTTOM:
            move_to_bottom()
        CONTEXT_MENU_DUPLICATE:
            duplicate_self()
        CONTEXT_MENU_REPLACE:
            replace_with_new_command()
        CONTEXT_MENU_DELETE:
            delete_self()

func move_relative(relative_index: int) -> void:
    var my_index: int = get_my_index()
    _move_to_index(my_index + relative_index)

func move_to_top() -> void:
    _move_to_index(0)

func move_to_bottom() -> void:
    var total_items: int = get_parent_list().get_child_count()
    if get_parent_list() is ConditionsCommandList:
        total_items = get_parent_list().get_command_count()
    _move_to_index(total_items)

func get_my_index() -> int:
    if get_parent_list() is ConditionsCommandList:
        return get_parent_list().get_command_index(self)
    else:
        return get_index()

func _move_to_index(new_index: int) -> void:
    new_index = maxi(0, new_index)
    if get_parent_list() is ConditionsCommandList:
        if new_index > get_my_index():
            new_index += 1
        new_index = mini(new_index, get_parent_list().get_command_count())
        get_parent_list().move_command_to_before_index(self, new_index)
    else:
        new_index = mini(new_index, get_parent_list().get_child_count())
        get_parent_list().move_child(self, new_index)

func duplicate_self() -> void:
    var duplicate_item: Control = _get_duplicate_item()
    var my_index: int = get_my_index()
    if get_parent_list() is ConditionsCommandList:
        get_parent_list().insert_command_at(duplicate_item, my_index + 1)
    else:
        get_parent_list().add_child(duplicate_item)
        get_parent_list().move_child(duplicate_item, my_index + 1)

func _on_CommandSlot_slot_changed(new_slot_id):
    current_slot = new_slot_id
    update_panel_background()

func replace_with_new_command() -> void:
    var conditional_editor: ConditionalEditor = get_window() as ConditionalEditor
    if not conditional_editor:
        push_error("CommandListItem is not in a ConditionalEditor window")
    conditional_editor.open_new_command_for_replace(get_parent_list(), get_my_index())