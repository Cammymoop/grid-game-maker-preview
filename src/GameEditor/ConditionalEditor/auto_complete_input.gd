class_name FuzzyAutocompleteInput
extends LineEdit

const MAX_SUGGESTIONS_VISIBLE := 20

@export var use_autocomplete_menu: bool = true

@export var default_show_clear_button: bool = true

@export var override_default_min_size: Vector2 = Vector2(140, -1)


@export_group("highlight options")
@export var do_highlight_unknown: bool = true
@export var do_highlight_known: bool = false
@export var do_highlight_other: bool = false
@export var other_list: Array[String] = []
@export var include_other_list_in_completions: bool = false

@export_group("highlight colors")
@export var highlight_unknown_color: Color = Color.RED
@export var highlight_known_color: Color = Color(0.83, 0.87, 0.39)
@export var highlight_other_color: Color = Color.BLUE

var arg_name: String = ""

var all_values: Array[String] = []

var fetch_values_func: Callable = Callable()
var _fetched: bool = false

var _ac_list: AutocompleteList
var _filtered: Array[String] = []
var _typed_this_focus: bool = false
var _ignore_menu_sync: bool = false

var _text_change_is_from_completion_accept: bool = false

func _ready() -> void:
	clear_button_enabled = default_show_clear_button
	if override_default_min_size.x >= 0:
		custom_minimum_size.x = override_default_min_size.x
	if override_default_min_size.y >= 0:
		custom_minimum_size.y = override_default_min_size.y

	if fetch_values_func.is_valid():
		fetch_now()
	text_changed.connect(_on_text_changed)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	text_submitted.connect(_on_text_submitted)
	
	if use_autocomplete_menu:
		_create_autocomplete_menu.call_deferred()

	if _fetched:
		update_highlight()

func _create_autocomplete_menu() -> void:
	if not use_autocomplete_menu:
		return
	_ac_list = Autocomplete.acquire_menu(self)
	_ac_list.item_clicked.connect(_on_ac_item_clicked)

func fetch_now() -> void:
	if include_other_list_in_completions:
		all_values.assign(other_list)
	all_values = fetch_values_func.call()
	_fetched = true

func set_fetch_values_func(new_func: Callable) -> void:
	fetch_values_func = new_func
	if not _fetched:
		fetch_now()
	update_highlight()


func _gui_input(event: InputEvent) -> void:
	if not use_autocomplete_menu or _ac_list == null or not _ac_list.visible:
		return
	if Utility.fixed_just_pressed_by_event("ui_text_completion_accept", event):
		_accept_highlighted_autocomplete()
		accept_event()
		return
	if Utility.fixed_just_pressed_by_event("ui_up", event):
		_ac_list.move_current(-1)
		accept_event()
		return
	if Utility.fixed_just_pressed_by_event("ui_down", event):
		_ac_list.move_current(1)
		accept_event()


func set_arg_name(new_arg_name: String) -> void:
	arg_name = new_arg_name


func get_arg_name() -> String:
	return arg_name


func get_value() -> String:
	return text


func set_value(new_val) -> void:
	text = str(new_val)
	update_highlight()


func update_highlight() -> void:
	if do_highlight_other and text in other_list:
		add_theme_color_override("font_color", highlight_other_color)
		return

	var valid_prop_name: = text in all_values
	if not valid_prop_name:
		if do_highlight_unknown:
			add_theme_color_override("font_color", highlight_unknown_color)
		else:
			remove_theme_color_override("font_color")
	else:
		if do_highlight_known:
			add_theme_color_override("font_color", highlight_known_color)
		else:
			remove_theme_color_override("font_color")


func _on_text_changed(_new_text: String) -> void:
	if _text_change_is_from_completion_accept:
		_text_change_is_from_completion_accept = false
		return
	_typed_this_focus = true
	update_highlight()
	if use_autocomplete_menu:
		_sync_autocomplete_menu()


func _on_focus_entered() -> void:
	_typed_this_focus = not text.is_empty()
	if use_autocomplete_menu:
		if _ac_list:
			_drop_autocomplete_menu()
		_create_autocomplete_menu()
		_sync_autocomplete_menu.call_deferred()


func _on_focus_exited() -> void:
	_hide_autocomplete()
	_drop_autocomplete_menu()

func _drop_autocomplete_menu() -> void:
	if _ac_list:
		_ac_list.item_clicked.disconnect(_on_ac_item_clicked)
		_ac_list = null

func _on_ac_item_clicked(_index: int, choice: String) -> void:
	if not has_focus():
		return
	_apply_autocomplete_choice(choice)


func _sync_autocomplete_menu() -> void:
	if _ignore_menu_sync or _ac_list == null:
		return
	if not has_focus():
		return
	if text.is_empty() and not _typed_this_focus:
		_hide_autocomplete()
		return
	var raw := _filter_values(text)
	var showable: Array[String] = []
	for n in raw:
		if n != text:
			showable.append(n)
	if showable.is_empty():
		_hide_autocomplete()
		return
	_filtered = showable
	_ac_list.clear_items()
	for n in _filtered:
		_ac_list.add_item(n)
	_set_ac_max_rows_for_viewport()
	_ac_list.show_list()


func _set_ac_max_rows_for_viewport() -> void:
	if _ac_list == null:
		return
	var gr := get_global_rect()
	var row := int(roundf(get_theme_font_size(&"font_size") * 1.35)) + 8
	var sep := 4
	var space_below: int = int(get_viewport().get_visible_rect().size.y - gr.position.y - gr.size.y)
	var max_rows_below: int = floori(float(space_below) / float(row + sep))
	max_rows_below = clampi(max_rows_below, 2, MAX_SUGGESTIONS_VISIBLE)
	_ac_list.max_visible_rows = max_rows_below


func _hide_autocomplete() -> void:
	if _ac_list == null or not _ac_list.visible:
		return
	_ac_list.hide_list()


func _accept_highlighted_autocomplete() -> void:
	if _ac_list == null or _filtered.is_empty():
		return
	var idx: int = _ac_list.get_current_index()
	if idx < 0:
		idx = 0
	_apply_autocomplete_choice(_filtered[idx])


func _apply_autocomplete_choice(choice: String) -> void:
	_ignore_menu_sync = true
	text = choice
	caret_column = text.length()
	update_highlight()
	_ignore_menu_sync = false
	_hide_autocomplete()
	_text_change_is_from_completion_accept = true
	text_changed.emit(text)
	if not has_focus():
		grab_focus.call_deferred()


func _filter_values(query: String) -> Array[String]:
	var pool: Array[String] = []
	if query.is_empty():
		pool.assign(all_values)
		pool.sort_custom(func(a, b): return a.nocasecmp_to(b) < 0)
		return pool
	for n in all_values:
		if _fuzzy_matches(query, n):
			pool.append(n)
	pool.sort_custom(func(a, b):
		var ra := _fuzzy_rank(query, a)
		var rb := _fuzzy_rank(query, b)
		if ra != rb:
			return ra < rb
		return a.nocasecmp_to(b) < 0
	)
	return pool


func _fuzzy_matches(query: String, cand: String) -> bool:
	if query.is_empty():
		return true
	var q := query.to_lower()
	var c := cand.to_lower()
	var j := 0
	for i in c.length():
		if j < q.length() and c[i] == q[j]:
			j += 1
	return j == q.length()


func _fuzzy_rank(query: String, cand: String) -> int:
	var q := query.to_lower()
	var c := cand.to_lower()
	var positions: Array[int] = []
	var j := 0
	for i in c.length():
		if j < q.length() and c[i] == q[j]:
			positions.append(i)
			j += 1
	if j != q.length():
		return 999999
	var score := positions[0] * 10
	for k in range(1, positions.size()):
		score += positions[k] - positions[k - 1] - 1
	return score

func _on_text_submitted(_text: String) -> void:
	if _ac_list and _ac_list.visible:
		_ac_list.hide_list()