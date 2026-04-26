extends Node

const Slot = Commands.Slot

var command_item_bg_template: StyleBoxFlat = preload("res://assets/ui/PropertyEditor/command_bg_template.tres")
var command_item_tab_template: StyleBoxFlat = preload("res://assets/ui/PropertyEditor/command_tab_template.tres")

@export var slot_colors: Dictionary = {
    Slot.RED: Color.RED,
    Slot.BLUE: Color.BLUE,
    Slot.WHITE: Color.WHITE,
    Slot.PINK: Color.PINK,
    Slot.GREY: Color.GRAY,
    Slot.BLACK: Color.BLACK,
    Slot.A: Color.RED * 0.5,
    Slot.B: Color.RED * 0.5,
    Slot.C: Color.RED * 0.5,
    Slot.X: Color.RED * 0.5,
    Slot.Y: Color.RED * 0.5,
    Slot.Z: Color.RED * 0.5,
    Slot.I: Color.RED * 0.5,
    Slot.II: Color.RED * 0.5,
    Slot.III: Color.RED * 0.5,
    Slot.DARK_RED: Color.RED * 0.6,
    Slot.DARK_BLUE: Color.BLUE * 0.6,
    Slot.DARK_GREEN: Color.GREEN * 0.6,
    Slot.DARK_ORANGE: Color.ORANGE * 0.6,
    
    -1: Color(0.2, 0.9, 0.38),
}

func get_command_item_styleboxes_for_slot(slot_id: int) -> Dictionary:
    var slot_color = slot_colors.get(slot_id, Color.WHITE.darkened(0.2))
    if not slot_colors.has(slot_id):
        prints("no color for slot %s" % slot_id)
    var colored_bg = command_item_bg_template.duplicate()
    recolor_stylebox(colored_bg, slot_color)
    var colored_tab = command_item_tab_template.duplicate()
    recolor_stylebox(colored_tab, slot_color)
    return {
        "bg": colored_bg,
        "tab": colored_tab,
    }

func recolor_stylebox(stylebox: StyleBoxFlat, to_color: Color) -> void:
    var to_bg_color = Color.from_ok_hsl(to_color.ok_hsl_h, to_color.ok_hsl_s * 0.9, to_color.ok_hsl_l)
    
    var border_darken_ratio = stylebox.border_color.ok_hsl_l / stylebox.bg_color.ok_hsl_l
    stylebox.bg_color = to_bg_color
    stylebox.border_color = Color.from_ok_hsl(to_color.ok_hsl_h, to_color.ok_hsl_s, to_color.ok_hsl_l * border_darken_ratio)
