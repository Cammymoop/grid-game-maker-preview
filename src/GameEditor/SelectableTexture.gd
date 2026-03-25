extends PanelContainer

var lowbox = preload("res://src/UI/selectable_list_item_low.tres")
var hibox = preload("res://src/UI/selectable_list_item_high.tres")

signal enabled
signal selected
signal double_clicked

@onready var display_tex_rect: TextureRect = find_child("TextureRect")

var is_selected = false

var texture_name: String
var built_in: bool = false

func set_texture(t_name: String, texture: Texture2D, builtin: bool = false) -> void:
	texture_name = t_name
	$HB/Label.text = t_name
	if not display_tex_rect:
		display_tex_rect = find_child("TextureRect")
	display_tex_rect.texture = texture
	set_filter_mode()
	
	if builtin:
		built_in = true
		$HB/Builtin.visible = true

func get_texture() -> Texture2D:
	return $HB/TextureRect.texture

func set_enabled(new_enabled: bool) -> void:
	$HB/CheckButton.button_pressed = new_enabled

func deselect() -> void:
	is_selected = false
	
	add_theme_stylebox_override("panel", lowbox)


func _on_CheckButton_toggled(on_off):
	emit_signal("enabled", on_off, built_in, texture_name, $HB/CheckButton)


func _on_SelectableTexItem_gui_input(event):
	if not event is InputEventMouseButton:
		return
	
	var button_event = event as InputEventMouseButton
	if button_event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT] and button_event.is_pressed():
		if not is_selected:
			is_selected = true
			emit_signal("selected", self)
			
			add_theme_stylebox_override("panel", hibox)
			
		if button_event.double_click:
			emit_signal("double_clicked")


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
