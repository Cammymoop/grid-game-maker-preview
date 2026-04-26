extends PanelContainer

var lowbox = preload("res://src/UI/selectable_list_item_low.tres")
var hibox = preload("res://src/UI/selectable_list_item_high.tres")

signal enable_toggled(item: Node, new_is_enabled: bool)
signal selected(item: Node)
signal double_clicked(item: Node)

@onready var display_tex_rect: TextureRect = find_child("TextureRect")

var is_selected = false

var texture_name: String
var built_in: bool = false
var is_shared: bool = true

func set_texture(t_name: String, texture: Texture2D, builtin: bool = false, shared: bool = true) -> void:
	texture_name = t_name
	$HB/Label.text = t_name
	if not display_tex_rect:
		display_tex_rect = find_child("TextureRect")
	display_tex_rect.texture = texture
	set_filter_mode()
	
	is_shared = shared
	if builtin:
		built_in = true
		$HB/Builtin.visible = true

func get_texture_name() -> String:
	return texture_name

func get_is_builtin() -> bool:
	return built_in

func get_is_shared() -> bool:
	return is_shared

func is_enabled() -> bool:
	return $HB/CheckButton.button_pressed

func get_texture() -> Texture2D:
	return $HB/TextureRect.texture

func set_enabled(new_enabled: bool) -> void:
	set_check_button_on(new_enabled)

func set_check_button_on(new_checked: bool) -> void:
	$HB/CheckButton.set_pressed_no_signal(new_checked)

func deselect() -> void:
	is_selected = false
	add_theme_stylebox_override("panel", lowbox)

func select() -> void:
	is_selected = true
	add_theme_stylebox_override("panel", hibox)

func _on_CheckButton_toggled(new_is_enabled: bool) -> void:
	enable_toggled.emit(self, new_is_enabled)


func _on_SelectableTexItem_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	
	var button_event = event as InputEventMouseButton
	if button_event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT] and button_event.is_pressed():
		if not is_selected:
			select()
			selected.emit(self)
		if button_event.double_click and button_event.button_index == MOUSE_BUTTON_LEFT:
			double_clicked.emit(self)


func _on_texture_rect_resized() -> void:
	set_filter_mode()

func set_filter_mode() -> void:
	if not display_tex_rect:
		display_tex_rect = find_child("TextureRect")
	var texture = display_tex_rect.texture
	if texture.get_width() > display_tex_rect.size.x or texture.get_height() > display_tex_rect.size.y:
		display_tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	else:
		display_tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
