extends VBoxContainer

signal list_settings_edited()
signal request_close()

const ScalarValueInput = preload("res://src/GameEditor/ConditionalEditor/scalar_value_input.gd")

@export var back_button: Button

@export var name_input: LineEdit
@export var total_levels_label: Label

@export var do_progressive_unlock_toggle: CheckButton
@export var progressive_unlock_num_container: Control
@export var progressive_unlock_num_input: ScalarValueInput

@export var always_hidden_container: Control
@export var always_hidden_toggle: CheckButton
@export var not_always_hidden_container: Control

@export var is_locked_container: Control
@export var is_locked_toggle: CheckButton
@export var is_hidden_container: Control
@export var is_hidden_toggle: CheckButton

@export var default_is_unlocked_container: Control
@export var default_is_unlocked_toggle: CheckButton

@export var show_locked_levels_toggle: CheckButton
@export var show_locked_titles_container: Control
@export var show_locked_titles_toggle: CheckButton

@export var completion_mode_selector: OptionButton
@export var completion_number_container: Control
@export var completion_number_input: ScalarValueInput

@export var show_completion_container: Control
@export var show_completion_selector: OptionButton

@export var custom_next_list_container: Control
@export var custom_next_list_selector: OptionButton

@export var when_completed_selector: OptionButton

@export var hidden_all_count_for_completion_container: Control
@export var hidden_all_count_for_completion_toggle: CheckButton

@export var show_name_as_hidden_container: Control
@export var show_name_as_hidden_toggle: CheckButton

@export var auto_advance_enabled_toggle: CheckButton

@export var auto_advance_to_next_list_container: Control
@export var auto_advance_to_next_list_toggle: CheckButton

var editing_list_name: String = ""
var total_levels: int = 0

var last_completion_percentage: int = GameManager.DEFAULT_LIST_COMPLETION_PERCENT
var last_completion_count: int = 1

const COMPLETION_MODE_ALL: String = "all"
const COMPLETION_MODE_COUNT: String = "count"
const COMPLETION_MODE_INVERSE_COUNT: String = "inverse_count"
const COMPLETION_MODE_PERCENTAGE: String = "percentage"

const COMPLETION_MODE_UNCOMPLETABLE = "uncompletable"

const CompletionModes: Array[String] = [
    COMPLETION_MODE_ALL,
    COMPLETION_MODE_COUNT,
    COMPLETION_MODE_INVERSE_COUNT,
    COMPLETION_MODE_PERCENTAGE,
]
const CompletionModeDisplayTexts: Dictionary = {
    COMPLETION_MODE_ALL: "All Levels Complete",
    COMPLETION_MODE_COUNT: "(X) Levels Complete",
    COMPLETION_MODE_INVERSE_COUNT: "All But (X) Levels Complete",
    COMPLETION_MODE_PERCENTAGE: "(X)% of Levels Complete",
    COMPLETION_MODE_UNCOMPLETABLE: "Not Completable",
}

const WHEN_COMPLETED_UNLOCK_NEXT = "unlock_next"
const WHEN_COMPLETED_DO_NOTHING = "do_nothing"

const WhenCompletedOptions: Array[String] = [
    WHEN_COMPLETED_UNLOCK_NEXT,
    WHEN_COMPLETED_DO_NOTHING,
]
const WhenCompletedDisplayTexts: Dictionary = {
    WHEN_COMPLETED_UNLOCK_NEXT: "Unlock Next List",
    WHEN_COMPLETED_DO_NOTHING: "Unlock Nothing",
}

const SHOWCOMP_STYLE_HIDE = "hide"
const SHOWCOMP_STYLE_COMP_REQ_TOTAL = "completed_required_total"
const SHOWCOMP_STYLE_COMP_REQ = "completed_required"
const SHOWCOMP_STYLE_COMP_TOTAL = "completed_total"
const SHOWCOMP_STYLE_COMP_REQ_VIS_TOTAL = "completed_required_visible-total"
const SHOWCOMP_STYLE_COMP_VIS_TOTAL = "completed_visible-total"

const ShowCompletionOptions: Array[String] = [
    SHOWCOMP_STYLE_HIDE,
    SHOWCOMP_STYLE_COMP_REQ_TOTAL,
    SHOWCOMP_STYLE_COMP_REQ,
    SHOWCOMP_STYLE_COMP_TOTAL,
    #SHOWCOMP_STYLE_COMP_REQ_VIS_TOTAL,
    #SHOWCOMP_STYLE_COMP_VIS_TOTAL,
]
const ShowCompletionDisplayTexts: Dictionary = {
    SHOWCOMP_STYLE_HIDE: "Hide",
    SHOWCOMP_STYLE_COMP_REQ_TOTAL: "Completed/Required/Total",
    SHOWCOMP_STYLE_COMP_REQ: "Completed/Required",
    SHOWCOMP_STYLE_COMP_TOTAL: "Completed/Total",
    SHOWCOMP_STYLE_COMP_REQ_VIS_TOTAL: "Completed/Required/Visible Total",
    SHOWCOMP_STYLE_COMP_VIS_TOTAL: "Completed/Visible Total",
}

func _ready() -> void:
    completion_mode_selector.clear()
    for completion_mode_id in CompletionModes.size():
        var completion_mode: String = CompletionModes[completion_mode_id]
        completion_mode_selector.add_item(CompletionModeDisplayTexts[completion_mode], completion_mode_id)
    completion_mode_selector.item_selected.connect(on_completion_mode_selected)
    
    always_hidden_toggle.toggled.connect(on_always_hidden_toggled)
    
    custom_next_list_selector.item_selected.connect(on_custom_next_list_selected)
    completion_number_input.value_changed.connect(on_completion_number_input_value_changed)
    when_completed_selector.item_selected.connect(on_when_completed_selected)
    
    default_is_unlocked_toggle.toggled.connect(on_default_is_unlocked_toggled)
    
    is_locked_toggle.toggled.connect(on_is_locked_toggled)
    is_hidden_toggle.toggled.connect(on_is_hidden_toggled)

    back_button.pressed.connect(request_close.emit)
    name_input.text_changed.connect(on_name_input_text_changed)
    do_progressive_unlock_toggle.toggled.connect(on_do_progressive_unlock_toggled)
    progressive_unlock_num_input.value_changed.connect(prop_unlock_num_changed)
    show_locked_levels_toggle.toggled.connect(on_show_locked_levels_toggled)
    show_locked_titles_toggle.toggled.connect(on_show_locked_titles_toggled)
    
    show_completion_selector.item_selected.connect(on_show_completion_selected)
    
    hidden_all_count_for_completion_toggle.toggled.connect(on_hidden_all_count_for_completion_toggled)
    show_name_as_hidden_toggle.toggled.connect(on_show_name_as_hidden_toggled)
    
    auto_advance_enabled_toggle.toggled.connect(on_auto_advance_enabled_toggled)
    auto_advance_to_next_list_toggle.toggled.connect(on_auto_advance_to_next_list_toggled)
    
    when_completed_selector.clear()
    for when_completed_id in WhenCompletedOptions.size():
        var when_completed: String = WhenCompletedOptions[when_completed_id]
        when_completed_selector.add_item(WhenCompletedDisplayTexts[when_completed], when_completed_id)

    show_completion_selector.clear()
    for show_completion_id in ShowCompletionOptions.size():
        var show_completion_str: String = ShowCompletionOptions[show_completion_id]
        show_completion_selector.add_item(ShowCompletionDisplayTexts[show_completion_str], show_completion_id)

    if editing_list_name and visible:
        refresh_ui()

func load_list_info(list_name: String) -> void:
    editing_list_name = list_name
    var list_info: = _get_list_info()
    if not list_info:
        push_error("Editing unknown level list: %s" % list_name)
        return
    total_levels = GameManager.get_levels_in_level_list(editing_list_name).size()
    refresh_ui()

func _get_list_info() -> Dictionary:
    if not editing_list_name:
        return {}
    return GameManager._get_level_list(editing_list_name)

func on_do_progressive_unlock_toggled(toggled_on: bool) -> void:
    progressive_unlock_num_container.visible = toggled_on
    if toggled_on:
        set_prog_unlock_num()
        GameManager.remove_level_list_data(editing_list_name, "default_individual_locked")
    else:
        GameManager.remove_level_list_data(editing_list_name, "progressive_locked_levels")
        var toggle_value: bool = default_is_unlocked_toggle.button_pressed
        GameManager.set_level_list_data(editing_list_name, "default_individual_locked", not toggle_value)
    refresh_ui()
    list_settings_edited.emit()

func on_show_locked_levels_toggled(toggled_on: bool) -> void:
    GameManager.set_level_list_data(editing_list_name, "show_locked_levels", toggled_on)
    refresh_ui()
    list_settings_edited.emit()

func on_show_locked_titles_toggled(toggled_on: bool) -> void:
    GameManager.set_level_list_data(editing_list_name, "show_locked_titles", toggled_on)
    list_settings_edited.emit()

func prop_unlock_num_changed(_new_value: float) -> void:
    set_prog_unlock_num()
    list_settings_edited.emit()

func set_prog_unlock_num() -> void:
    var num_input_number: = int(progressive_unlock_num_input.get_value())
    GameManager.set_level_list_data(editing_list_name, "progressive_locked_levels", num_input_number)

func on_name_input_text_changed(new_text: String) -> void:
    var exact_input_text: String = new_text
    new_text = new_text.strip_edges()
    while new_text.contains("??"):
        new_text = new_text.replace("??", "?")
    if new_text.ends_with("?"):
        new_text += "%"
    
    if editing_list_name.ends_with("?%") and editing_list_name.trim_suffix("?%") == new_text.trim_suffix("%"):
        new_text = new_text.trim_suffix("%")

    if new_text == editing_list_name:
        name_input.remove_theme_color_override("font_color")
        return
        
    if GameManager.level_list_name_exists(new_text) or not new_text:
        name_input.add_theme_color_override("font_color", Color.RED)
        return

    if GameManager.rename_level_list(editing_list_name, new_text):
        name_input.remove_theme_color_override("font_color")
        editing_list_name = new_text
        if exact_input_text != new_text:
            refresh_ui()
        list_settings_edited.emit()

func refresh_ui() -> void:
    total_levels_label.text = "Total Levels: %d" % total_levels

    var old_caret_column: int = name_input.caret_column
    name_input.text = editing_list_name
    if name_input.is_editing():
        name_input.caret_column = old_caret_column
    name_input.remove_theme_color_override("font_color")
    var list_info: = _get_list_info()
    if not list_info:
        push_warning("Unable to get list info for %s" % editing_list_name)
        request_close.emit()
        return
    
    var is_first_bundled_list: bool = false
    var is_custom_level_list: bool = not GameManager.is_level_list_bundled(editing_list_name)
    if not is_custom_level_list:
        is_first_bundled_list = GameManager.get_list_of_level_lists(true).find(editing_list_name) == 0

    always_hidden_container.visible = not is_custom_level_list
    var is_always_hidden: bool = list_info.get("always_hidden", false) and not is_first_bundled_list
    always_hidden_toggle.set_pressed_no_signal(is_always_hidden)
    #always_hidden_toggle.disabled = is_first_bundled_list

    if is_custom_level_list:
        is_always_hidden = false
    
    hidden_all_count_for_completion_container.visible = is_always_hidden
    show_name_as_hidden_container.visible = is_always_hidden
    if is_always_hidden:
        hidden_all_count_for_completion_toggle.set_pressed_no_signal(list_info.get("always_hidden_levels_completable", false))
        show_name_as_hidden_toggle.set_pressed_no_signal(list_info.get("always_hidden_use_name_when_current", false))
    
    not_always_hidden_container.visible = not is_always_hidden
    custom_next_list_container.visible = not is_always_hidden and not is_custom_level_list
    if custom_next_list_container.visible:
        refresh_custom_next_list_selector()

    if not is_always_hidden:
        var prog_unlock_num: = int(list_info.get("progressive_locked_levels", 0))
        do_progressive_unlock_toggle.button_pressed = prog_unlock_num > 0
        progressive_unlock_num_container.visible = prog_unlock_num > 0
        progressive_unlock_num_input.set_value(maxi(1, prog_unlock_num))
        
        var is_locked: bool = list_info.get("default_locked", false)
        is_locked_toggle.set_pressed_no_signal(is_locked)
        
        is_hidden_toggle.set_pressed_no_signal(list_info.get("hide_when_locked", false))
        is_hidden_container.visible = is_locked
        
        var show_locked_levels: bool = list_info.get("show_locked_levels", true)
        show_locked_levels_toggle.set_pressed_no_signal(show_locked_levels)
        show_locked_titles_toggle.set_pressed_no_signal(list_info.get("show_locked_titles", false))
        show_locked_titles_container.visible = show_locked_levels
        
        default_is_unlocked_container.visible = prog_unlock_num == 0
        var default_level_locked: bool = list_info.get("default_individual_locked", false)
        default_is_unlocked_toggle.set_pressed_no_signal(not default_level_locked)
        
        var is_auto_advance: bool = list_info.get("auto_advance_enabled", true)
        auto_advance_enabled_toggle.set_pressed_no_signal(is_auto_advance)
        
        auto_advance_to_next_list_container.visible = is_auto_advance
        var is_auto_advance_to_next_list: bool = list_info.get("auto_advance_to_next_list", true)
        auto_advance_to_next_list_toggle.set_pressed_no_signal(is_auto_advance_to_next_list)

    
    var completion_mode: String = _get_completion_mode(list_info)
    completion_mode_selector.selected = CompletionModes.find(completion_mode)

    if completion_mode == COMPLETION_MODE_PERCENTAGE:
        completion_mode_selector.tooltip_text = "Rounded down to the nearest level, minimum of 1"
    else:
        completion_mode_selector.tooltip_text = ""
    
    completion_number_container.visible = completion_mode != COMPLETION_MODE_ALL
    if completion_number_container.visible:
        var completion_number: int = _get_completion_number(list_info, completion_mode)
        completion_number_input.set_value(completion_number)
        _update_last_completion_number(completion_mode, completion_number)
    
    var show_completion_style: String = list_info.get("show_completion_style", SHOWCOMP_STYLE_HIDE)
    if not show_completion_style in ShowCompletionOptions:
        show_completion_style = SHOWCOMP_STYLE_HIDE
    var show_completion_id: int = ShowCompletionOptions.find(show_completion_style)
    Utility.opbtn_select_id(show_completion_selector, show_completion_id)
    
    var when_completed_action: String = list_info.get("when_completed_action", WHEN_COMPLETED_UNLOCK_NEXT)
    if not when_completed_action in WhenCompletedOptions:
        when_completed_action = WHEN_COMPLETED_UNLOCK_NEXT
    var when_completed_id: int = WhenCompletedOptions.find(when_completed_action)
    Utility.opbtn_select_id(when_completed_selector, when_completed_id)


func refresh_custom_next_list_selector() -> void:
    custom_next_list_selector.clear()
    custom_next_list_selector.add_item("Auto", -1)
    
    var selected_custom_next: String = GameManager.get_custom_next_list_of_bundled_list_info(_get_list_info())
    if not selected_custom_next:
        custom_next_list_selector.selected = 0

    # Any list which isn't always hidden and has at least one level
    for bundled_list_info in GameManager.get_all_level_list_infos(true):
        if bundled_list_info.get("name") == editing_list_name:
            custom_next_list_selector.add_item(editing_list_name, -2)
            custom_next_list_selector.set_item_disabled(custom_next_list_selector.item_count - 1, true)
            continue
        if not GameManager._is_list_info_valid_next_list(bundled_list_info):
            continue
        custom_next_list_selector.add_item(bundled_list_info["name"])
        if bundled_list_info["name"] == selected_custom_next:
            custom_next_list_selector.selected = custom_next_list_selector.item_count - 1


func _get_completion_mode(list_info: Dictionary) -> String:
    var completion_mode: String = list_info.get("completion_mode", "")
    if not completion_mode in CompletionModes:
        completion_mode = GameManager.DEFAULT_LIST_COMPLETION_MODE
    return completion_mode

func _get_completion_number(list_info: Dictionary, completion_mode: String) -> int:
    if completion_mode == COMPLETION_MODE_PERCENTAGE:
        return int(list_info.get("required_percentage", 0))
    elif completion_mode == COMPLETION_MODE_COUNT or completion_mode == COMPLETION_MODE_INVERSE_COUNT:
        return int(list_info.get("required_to_complete", 0))
    return 0

func _update_last_completion_number(completion_mode: String, completion_number: int) -> void:
    if completion_mode == COMPLETION_MODE_PERCENTAGE:
        last_completion_percentage = completion_number
    elif completion_mode == COMPLETION_MODE_COUNT or completion_mode == COMPLETION_MODE_INVERSE_COUNT:
        last_completion_count = completion_number

func on_completion_mode_selected(idx: int) -> void:
    var completion_mode: String = CompletionModes[completion_mode_selector.get_item_id(idx)]
    GameManager.set_level_list_data(editing_list_name, "completion_mode", completion_mode)

    if completion_mode == COMPLETION_MODE_PERCENTAGE:
        GameManager.remove_level_list_data(editing_list_name, "required_to_complete")
        GameManager.set_level_list_data(editing_list_name, "required_percentage", last_completion_percentage)
    if completion_mode == COMPLETION_MODE_COUNT or completion_mode == COMPLETION_MODE_INVERSE_COUNT:
        GameManager.remove_level_list_data(editing_list_name, "required_percentage")
        GameManager.set_level_list_data(editing_list_name, "required_to_complete", maxi(last_completion_count, total_levels))
    else:
        GameManager.remove_level_list_data(editing_list_name, "required_percentage")
        GameManager.remove_level_list_data(editing_list_name, "required_to_complete")

    refresh_ui()
    list_settings_edited.emit()
    
func on_completion_number_input_value_changed(new_value: float) -> void:
    var completion_mode: String = _get_completion_mode(_get_list_info())
    var write_key: String = ""
    var max_value: int = 100
    if completion_mode == COMPLETION_MODE_PERCENTAGE:
        write_key = "required_percentage"
    elif completion_mode == COMPLETION_MODE_COUNT or completion_mode == COMPLETION_MODE_INVERSE_COUNT:
        write_key = "required_to_complete"
        max_value = total_levels

    var new_value_int: int = clampi(int(new_value), 1, max_value)
    GameManager.set_level_list_data(editing_list_name, write_key, new_value_int)
    _update_last_completion_number(completion_mode, new_value_int)
    list_settings_edited.emit()

func on_default_is_unlocked_toggled(toggled_on: bool) -> void:
    var defualt_levels_locked: bool = not toggled_on
    GameManager.set_level_list_data(editing_list_name, "default_individual_locked", defualt_levels_locked)
    list_settings_edited.emit()


func on_always_hidden_toggled(toggled_on: bool) -> void:
    GameManager.set_level_list_data(editing_list_name, "always_hidden", toggled_on)
    if not toggled_on:
        GameManager.remove_level_list_data(editing_list_name, "always_hidden_levels_completable")
        GameManager.remove_level_list_data(editing_list_name, "always_hidden_use_name_when_current")
    else:
        GameManager.set_level_list_data(editing_list_name, "always_hidden_levels_completable", false)
        GameManager.set_level_list_data(editing_list_name, "always_hidden_use_name_when_current", false)
    refresh_ui()
    list_settings_edited.emit()

func on_is_locked_toggled(toggled_on: bool) -> void:
    GameManager.set_level_list_data(editing_list_name, "default_locked", toggled_on)
    refresh_ui()
    list_settings_edited.emit()

func on_is_hidden_toggled(toggled_on: bool) -> void:
    GameManager.set_level_list_data(editing_list_name, "hide_when_locked", toggled_on)
    refresh_ui()
    list_settings_edited.emit()

func on_when_completed_selected(idx: int) -> void:
    GameManager.set_level_list_data(editing_list_name, "when_completed_action", WhenCompletedOptions[idx])
    list_settings_edited.emit()

func on_custom_next_list_selected(idx: int) -> void:
    if idx == 0:
        GameManager.set_level_list_data(editing_list_name, "custom_next_list", "auto")
        GameManager.remove_level_list_data(editing_list_name, "custom_next_list_name")
    else:
        GameManager.set_level_list_data(editing_list_name, "custom_next_list", "manual")
        GameManager.set_level_list_data(editing_list_name, "custom_next_list_name", custom_next_list_selector.get_item_text(idx))
    list_settings_edited.emit()

func on_show_completion_selected(idx: int) -> void:
    GameManager.set_level_list_data(editing_list_name, "show_completion_style", ShowCompletionOptions[idx])
    list_settings_edited.emit()

func on_hidden_all_count_for_completion_toggled(toggled_on: bool) -> void:
    GameManager.set_level_list_data(editing_list_name, "always_hidden_levels_completable", toggled_on)
    list_settings_edited.emit()

func on_show_name_as_hidden_toggled(toggled_on: bool) -> void:
    GameManager.set_level_list_data(editing_list_name, "always_hidden_use_name_when_current", toggled_on)
    list_settings_edited.emit()

func on_auto_advance_enabled_toggled(toggled_on: bool) -> void:
    GameManager.set_level_list_data(editing_list_name, "auto_advance_enabled", toggled_on)
    list_settings_edited.emit()

func on_auto_advance_to_next_list_toggled(toggled_on: bool) -> void:
    GameManager.set_level_list_data(editing_list_name, "auto_advance_to_next_list", toggled_on)
    list_settings_edited.emit()