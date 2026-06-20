class_name AutocompleteList
extends Panel

signal item_clicked(index: int, text: String)
signal dismissed

var _scroll: ScrollContainer
var _vbox: VBoxContainer
var _rows: Array[Button] = []
var _strings: Array[String] = []
var _current_index: int = -1
var _anchor: WeakRef
var max_visible_rows: int = 8

var _style_selected: StyleBoxFlat
var _style_selected_hover: StyleBoxFlat
var _style_unselected: StyleBoxFlat
var _style_unselected_hover: StyleBoxFlat

var _bus: Node


func _init() -> void:
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_vbox)
	add_child(_scroll)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_selection_styles()


func _ready() -> void:
	_bus = get_tree().root.get_node_or_null(^"Autocomplete")
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	var m := 2.0
	_scroll.offset_left = m
	_scroll.offset_top = m
	_scroll.offset_right = -m
	_scroll.offset_bottom = -m


func _build_selection_styles() -> void:
	_style_selected = StyleBoxFlat.new()
	_style_selected.bg_color = Color(0.25, 0.45, 0.75, 0.35)
	_style_selected.set_content_margin_all(4)
	_style_selected_hover = StyleBoxFlat.new()
	_style_selected_hover.bg_color = Color(0.3, 0.5, 0.85, 0.45)
	_style_selected_hover.set_content_margin_all(4)
	_style_unselected = StyleBoxFlat.new()
	_style_unselected.bg_color = Color.TRANSPARENT
	_style_unselected.set_content_margin_all(4)
	_style_unselected_hover = StyleBoxFlat.new()
	_style_unselected_hover.bg_color = Color(0.1, 0.3, 0.55, 0.45)
	_style_unselected_hover.set_content_margin_all(4)


func _ensure_bus() -> void:
	if _bus == null and is_inside_tree():
		_bus = get_tree().root.get_node_or_null(^"Autocomplete")


func set_anchor_control(anchor: Control) -> void:
	if anchor:
		_anchor = weakref(anchor)
	else:
		_anchor = null

func drop_anchor_control() -> void:
	_anchor = null

func get_anchor_control() -> Control:
	if _anchor == null:
		return null
	return _anchor.get_ref() as Control


func clear_items() -> void:
	for c in _vbox.get_children():
		_vbox.remove_child(c)
		c.queue_free()
	_rows.clear()
	_strings.clear()
	_current_index = -1


func add_item(label_text: String) -> void:
	var idx := _strings.size()
	_strings.append(label_text)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.toggle_mode = false
	b.flat = false
	b.text = label_text
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var captured := idx
	b.pressed.connect(func(): _emit_item_clicked(captured))
	_vbox.add_child(b)
	_rows.append(b)


func get_item_count() -> int:
	return _strings.size()


func get_item_text(index: int) -> String:
	if index < 0 or index >= _strings.size():
		return ""
	return _strings[index]


func get_current_index() -> int:
	return _current_index


func set_current_index(index: int) -> void:
	if _rows.is_empty():
		_current_index = -1
		return
	_current_index = posmod(index, _rows.size())
	_apply_row_styles()
	if _current_index >= 0 and _current_index < _rows.size():
		var row: Control = _rows[_current_index]
		_scroll.ensure_control_visible(row)
		_scroll.scroll_horizontal = 0
		call_deferred("_keep_scroll_left", row)


func move_current(delta: int) -> void:
	if _rows.is_empty():
		return
	var base := _current_index
	if base < 0:
		base = 0
	set_current_index(base + delta)


func _keep_scroll_left(row: Control) -> void:
	if not is_instance_valid(row) or row.get_parent() != _vbox:
		return
	_scroll.ensure_control_visible(row)
	_scroll.scroll_horizontal = 0


func _apply_row_styles() -> void:
	for i in _rows.size():
		var b: Button = _rows[i]
		if i == _current_index:
			b.add_theme_stylebox_override(&"normal", _style_selected)
			b.add_theme_stylebox_override(&"hover", _style_selected_hover)
			b.add_theme_stylebox_override(&"pressed", _style_selected_hover)
		else:
			b.add_theme_stylebox_override(&"normal", _style_unselected)
			b.add_theme_stylebox_override(&"hover", _style_unselected_hover)
			b.add_theme_stylebox_override(&"pressed", _style_unselected_hover)


func _emit_item_clicked(index: int) -> void:
	if index < 0 or index >= _strings.size():
		return
	item_clicked.emit(index, _strings[index])


func _content_text_width() -> float:
	if _strings.is_empty():
		return 0.0
	var font := get_theme_font(&"font", &"Button")
	if font == null:
		font = ThemeDB.fallback_font
	var font_size := get_theme_font_size(&"font_size", &"Button")
	if font_size <= 0:
		font_size = get_theme_default_font_size()
	var max_w := 0.0
	for s in _strings:
		max_w = maxf(max_w, font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x)
	var hpad := float(get_theme_constant(&"h_separation", &"Button"))
	if hpad <= 0.0:
		hpad = 12.0
	return max_w + hpad * 2.0 + 8.0


func position_under_anchor() -> void:
	var a := get_anchor_control()
	if a == null or not is_instance_valid(a):
		return
	var gr := a.get_global_rect()
	var vp := get_viewport().get_visible_rect()
	var space_to_right := vp.end.x - gr.position.x
	var anchor_w := gr.size.x
	var text_w := _content_text_width()
	var target_w := maxf(anchor_w, text_w)
	target_w = minf(target_w, maxf(anchor_w, space_to_right))

	var row_h := float(_estimate_row_height())
	var sep := float(_vbox.get_theme_constant(&"separation", &"VBoxContainer"))
	if sep < 0.0:
		sep = 4.0
	var n := _strings.size()
	var content_h := float(n) * row_h + maxf(0.0, float(n - 1)) * sep + 2.0
	var cap_n := maxi(1, max_visible_rows)
	var cap_h := float(cap_n) * row_h + maxf(0.0, float(cap_n - 1)) * sep + 2.0
	var inner_h := minf(content_h, cap_h)
	var margin_v := 6.0 + absf(_scroll.offset_top) + absf(_scroll.offset_bottom)
	var target_h := inner_h + margin_v

	global_position = gr.position + Vector2(0.0, gr.size.y)
	custom_minimum_size = Vector2(target_w, target_h)
	size = custom_minimum_size


func _estimate_row_height() -> int:
	var fs := get_theme_font_size(&"font_size", &"Button")
	if fs <= 0:
		fs = get_theme_default_font_size()
	return int(round(float(fs) * 1.35)) + 8


func show_list() -> void:
	if _strings.is_empty():
		return
	_ensure_bus()
	visible = true
	position_under_anchor()
	if _bus:
		_bus.begin_outside_click_watch(self)
	set_current_index(0)


func hide_list() -> void:
	if not visible:
		return
	visible = false
	_ensure_bus()
	if _bus:
		_bus.end_outside_click_watch()
	dismissed.emit()


func dismiss_external() -> void:
	hide_list()
