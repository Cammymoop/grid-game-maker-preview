extends Panel

@export var is_empty: bool = false

func _ready():
    pass

func set_border_and_bg_color(border_color: Color, bg_color: Color):
    if is_empty:
        return
    var main_stylebox = get_theme_stylebox("panel")
    main_stylebox.border_color = border_color
    main_stylebox.bg_color = bg_color
    
    if get_child_count() > 0:
        var panel_child: = get_child(0) as Panel
        if panel_child:
            var child_stylebox = panel_child.get_theme_stylebox("panel")
            child_stylebox.border_color = border_color

