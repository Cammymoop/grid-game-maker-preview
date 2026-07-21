extends HBoxContainer

@export var intermission_id_selector: OptionButton

const NO_INTERMISSION_ID: int = 999999

var arg_name: String = ""
var include_from_custom_list: String = ""
var _setup_with_list: String = ""

func _ready() -> void:
    setup_intermission_id_selector()
    Utility.opbtn_select_id(intermission_id_selector, NO_INTERMISSION_ID)
    intermission_id_selector.get_popup().about_to_popup.connect(on_popup_about_to_popup)

func set_arg_name(new_arg_name: String) -> void:
    arg_name = new_arg_name

func get_arg_name() -> String:
    return arg_name

func set_value(value: String) -> void:
    if _setup_with_list != include_from_custom_list:
        setup_intermission_id_selector()
    if not Utility.opbtn_has_text(intermission_id_selector, value):
        Utility.opbtn_select_id(intermission_id_selector, NO_INTERMISSION_ID)
    else:
        Utility.opbtn_select_text(intermission_id_selector, value)
    
func get_value() -> String:
    if Utility.opbtn_get_selected_id(intermission_id_selector) == NO_INTERMISSION_ID:
        return ""
    return Utility.opbtn_get_selected_text(intermission_id_selector)


func setup_intermission_id_selector() -> void:
    _setup_with_list = include_from_custom_list

    intermission_id_selector.clear()
    intermission_id_selector.add_item("[None]", NO_INTERMISSION_ID)
    intermission_id_selector.add_separator()
    
    for intermission_id in GameManager.get_all_intermission_ids():
        intermission_id_selector.add_item(intermission_id)
    
    if include_from_custom_list:
        intermission_id_selector.add_separator(include_from_custom_list)
        
        for intermission_id in GameManager.get_all_intermission_ids_from_custom_list(include_from_custom_list):
            intermission_id_selector.add_item(":" + intermission_id)

func on_popup_about_to_popup() -> void:
    if _setup_with_list != include_from_custom_list:
        setup_intermission_id_selector()