extends PanelContainer

var lowbox = preload("res://src/UI/selectable_list_item_low.tres")
var hibox = preload("res://src/UI/selectable_list_item_high.tres")

signal enabled
signal selected
signal double_clicked

var is_selected = false

var texture_name: String
var built_in: bool = false

func set_texture(t_name: String, texture: Texture, builtin: bool = false) -> void:
	texture_name = t_name
	$HB/Label.text = t_name
	$HB/TextureRect.texture = texture
	
	if builtin:
		built_in = true
		$HB/Builtin.visible = true

func get_texture() -> Texture:
	return $HB/TextureRect.texture

func set_enabled(selected: bool) -> void:
	$HB/CheckButton.pressed = selected

func deselect() -> void:
	is_selected = false
	
	add_stylebox_override("panel", lowbox)


func _on_CheckButton_toggled(on_off):
	emit_signal("enabled", on_off, built_in, texture_name, $HB/CheckButton)


func _on_SelectableTexItem_gui_input(event):
	if not event is InputEventMouseButton:
		return
	
	var button_event = event as InputEventMouseButton
	if button_event.button_index in [BUTTON_LEFT, BUTTON_RIGHT] and button_event.is_pressed():
		if not is_selected:
			is_selected = true
			emit_signal("selected", self)
			
			add_stylebox_override("panel", hibox)
			
		if button_event.doubleclick:
			emit_signal("double_clicked")
