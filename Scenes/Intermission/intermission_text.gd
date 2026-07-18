extends MarginContainer

@export var label: Label


func setup(item_info: Dictionary) -> void:
    var content_text: String = item_info.get("text", "")
    if not content_text:
        label.hide()
        return
    label.text = content_text
    
    var font_size: int = item_info.get("font_size", 24)
    var text_color: Color = item_info.get("text_color", Color.WHITE)
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", text_color)
    
    var border_enabled: bool = item_info.get("text_outline_enabled", false)
    if border_enabled:
        label.add_theme_color_override("font_outline_color", item_info.get("text_outline_color", Color.BLACK))
    else:
        label.add_theme_constant_override("outline_size", 0)
