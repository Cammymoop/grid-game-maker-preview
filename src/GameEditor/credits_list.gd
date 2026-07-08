extends VBoxContainer

const CreditsListItem = preload("res://src/GameEditor/credits_list_item.gd")
var credits_list_item_scene = preload("res://Scenes/GameEditor/credits_list_item.tscn")

const AddCreditItemButtonRow = preload("res://Scenes/GameEditor/add_credit_item_button_row.gd")
var add_credit_item_button_row_scene = preload("res://Scenes/GameEditor/add_credit_item_button_row.tscn")

var default_type: String = CreditsListItem.TYPE_ROLE_NAME

func _ready() -> void:
    load_credits_list()

func get_credits_list() -> Array:
    var credits_list: Array = []
    for child in get_children():
        if not child.has_method("get_entry"):
            continue
        var entry = child.get_entry()
        if is_empty_credits_item(entry):
            continue
        credits_list.append(entry)
    return credits_list

func is_empty_credits_item(item: Dictionary) -> bool:
    if not item:
        return true
    if not item.get("type", "") and not item.get("role", "") and not item.get("name", ""):
        return true
    return false

func clear_credits_list() -> void:
    for child in get_children():
        if child.has_method("get_entry"):
            remove_child(child)
            child.queue_free()

func load_credits_list() -> void:
    clear_credits_list()
    var credits_list: Array = GameManager.get_credits_info().get("credits_list", [])
    if credits_list.size() == 0:
        append_new_credit_item({})
    else:
        for entry in credits_list:
            append_new_credit_item(entry)
    refresh_add_new_item_buttons()

func refresh_add_new_item_buttons() -> void:
    for child in get_children():
        if child is AddCreditItemButtonRow:
            remove_child(child)
            child.queue_free()
    var insert_at_indices: Array[int] = []
    for child_idx in range(2, get_child_count() - 1):
        var credit_item: = get_child(child_idx) as CreditsListItem
        if credit_item and credit_item.get_entry().get("type", "") == CreditsListItem.TYPE_SECTION:
            insert_at_indices.append(child_idx)
    insert_at_indices.reverse()
    for idx in insert_at_indices:
        var add_credit_item_button_row: AddCreditItemButtonRow = add_credit_item_button_row_scene.instantiate()
        add_credit_item_button_row.add_pressed.connect(_on_new_credit_item_pressed)
        add_child(add_credit_item_button_row)
        move_child(add_credit_item_button_row, idx)

func _on_new_credit_item_pressed(add_before_node: Node = null) -> void:
    var add_before_idx: int = -1
    if add_before_node and add_before_node.get_parent() == self:
        add_before_idx = add_before_node.get_index()
    append_new_credit_item({}, add_before_idx)
    
func append_new_credit_item(with_entry: Dictionary, add_before_idx: int = -1) -> void:
    var new_credit_item = credits_list_item_scene.instantiate()
    add_child(new_credit_item)
    if with_entry:
        new_credit_item.set_entry(with_entry)
    else:
        new_credit_item.set_entry({"type": default_type})
    if add_before_idx == -1:
        move_child(new_credit_item, get_child_count() - 2)
    else:
        move_child(new_credit_item, maxi(1, add_before_idx))
    new_credit_item.changed.connect(on_credit_changed)
    new_credit_item.type_changed.connect(on_credit_item_type_changed.bind(new_credit_item))
    new_credit_item.request_remove.connect(remove_credit_item.bind(new_credit_item))

func num_credit_items() -> int:
    var count: int = 0
    for child in get_children():
        if child is CreditsListItem:
            count += 1
    return count

func on_credit_changed() -> void:
    update_credits_list()
    refresh_add_new_item_buttons()

func update_credits_list() -> void:
    var credits_list: Array = get_credits_list()
    GameManager.set_credits_info({"credits_list": credits_list})

func goto_view_credits() -> void:
    GameManager.show_credits()

func on_credit_item_type_changed(credit_item: CreditsListItem) -> void:
    var type: String = credit_item.cur_selected_type_str()
    if type in [CreditsListItem.TYPE_ROLE_NAME, CreditsListItem.TYPE_JUST_NAME]:
        default_type = type
    update_credits_list()
    refresh_add_new_item_buttons()

func remove_credit_item(credit_item: CreditsListItem) -> void:
    if not credit_item or not credit_item.is_inside_tree() or not credit_item.get_parent() == self:
        return
    remove_child(credit_item)
    credit_item.queue_free()
    update_credits_list()
    refresh_add_new_item_buttons()