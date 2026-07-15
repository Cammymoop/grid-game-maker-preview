extends Control

signal credits_opened
signal credits_closed

const ABOVE_CREDITS: int = 4000

@export var credits_scroll: ScrollContainer
@export var credits_container: VBoxContainer

@export var space_after_title: int = 30
@export var space_before_section: int = 20
@export var space_after_section: int = 10

@export var space_before_link: int = 10
@export var space_after_link: int = 10

@export var space_before_image: int = 20
@export var space_after_image: int = 20

@export var default_autoscroll_speed: float = 200
@export var manual_scroll_speed: float = 400

var link_label_scn: PackedScene = preload("res://Scenes/link_rich_label.tscn")

var image_scn: PackedScene = preload("res://Scenes/credits_image.tscn")

var _autoscrolling: = false

func _ready() -> void:
    hide()
    build_credits_list()
    reset_scroll()

func show_credits() -> void:
    credits_opened.emit()
    show()
    GameManager.set_pause("credits", true)
    scroll_and_start_credits()

func _shortcut_input(event: InputEvent) -> void:
    if not visible:
        return
    if Utility.event_is_menu_back_just_pressed(event):
        close_credits()
        accept_event()

func _process(delta: float) -> void:
    if not visible:
        return
    if _autoscrolling:
        credits_scroll.scroll_vertical += default_autoscroll_speed * delta
    
    var scroll_input: = Utility.input_vector_by_prefix("move")
    scroll_input.x = 0
    if scroll_input.length() > 0.2:
        if _autoscrolling:
            stop_autoscroll()
        credits_scroll.scroll_vertical += scroll_input.y * manual_scroll_speed * delta
    
    var vp_height: = get_viewport_rect().size.y
    if credits_scroll.scroll_vertical + vp_height + 20 < ABOVE_CREDITS:
        credits_scroll.scroll_vertical = ABOVE_CREDITS - vp_height - 20
    if credits_scroll.scroll_vertical - 20 > ABOVE_CREDITS + credits_container.size.y:
        credits_scroll.scroll_vertical = ABOVE_CREDITS + credits_container.size.y + 20
        if _autoscrolling:
            stop_autoscroll()


func build_credits_list() -> void:
    var credits_data: Dictionary = GameManager.get_credits_info()
    var credits_list: Array = credits_data.get("credits_list", [])
    
    clear_credits_container()
    
    var title_label: Label = _get_centered_label(GameManager.get_game_title(), "TitleText")
    credits_container.add_child(title_label)
    var subtitle_label: Label = _get_centered_label("Credits", "SubtitleText")
    credits_container.add_child(subtitle_label)
    _add_space(space_after_title)
    
    var current_role_name_grid: GridContainer = null
    var current_just_names_flow: HFlowContainer = null
    for credit_item in credits_list:
        var item_type: String = credit_item.get("type", "role_name")
        if item_type != "role_name" and current_role_name_grid:
            current_role_name_grid = null
        elif item_type != "just_name" and current_just_names_flow:
            current_just_names_flow = null

        if item_type == "section":
            if space_before_section > 0:
                _add_space(space_before_section)
            var section_label: Label = _get_centered_label(credit_item.get("text", ""), "SectionText")
            credits_container.add_child(section_label)
            if space_after_section > 0:
                _add_space(space_after_section)
        elif item_type == "role_name":
            if not current_role_name_grid:
                current_role_name_grid = _start_role_name_grid()
            _add_role_name_item(current_role_name_grid, credit_item.get("role", ""), credit_item.get("name", ""))
        elif item_type == "just_name":
            if not current_just_names_flow:
                current_just_names_flow = _start_just_names_flow()
            var name_label: Label = _get_centered_label(credit_item.get("name", ""), "NameListName")
            current_just_names_flow.add_child(name_label)
        elif item_type == "link":
            var link_label: RichTextLabel = _get_link_label(credit_item.get("url", ""))
            _add_space(space_before_link)
            credits_container.add_child(link_label)
            _add_space(space_after_link)
        elif item_type == "image":
            var texture_id: int = int(credit_item.get("texture_id", -1))
            if texture_id >= 0 and TextureManager.has_texture_id(texture_id):
                var sub_index: int = int(credit_item.get("texture_sub_index", 0))
                var atlas_tex: Texture2D = Utility.atlas_texture_from_texture_index(texture_id, sub_index)
                var relative_scale: float = credit_item.get("relative_scale", 1.0)
                var dark_bg: bool = credit_item.get("with_dark_bg", false)
                var sharp_scale: bool = credit_item.get("sharp_scale", false)
                var image: Control = _get_image(atlas_tex, relative_scale, dark_bg, sharp_scale)
                _add_space(space_before_image)
                credits_container.add_child(image)
                _add_space(space_after_image)

    #var test_img: Control = _get_image(load("res://assets/img/entityTiles.png"), 2.0, true, true)
    #_add_space(space_before_link)
    #credits_container.add_child(test_img)
    #_add_space(space_after_link)


func reset_scroll() -> void:
    credits_scroll.scroll_vertical = 0

func scroll_and_start_credits() -> void:
    var vp_height: = get_viewport_rect().size.y
    if vp_height > credits_container.size.y:
        stop_autoscroll()
        scroll_center_credits()
        return
    
    credits_scroll.scroll_vertical = ABOVE_CREDITS - vp_height/2
    start_autoscroll()

func scroll_center_credits() -> void:
    var vp_height: = get_viewport_rect().size.y
    credits_scroll.scroll_vertical = ABOVE_CREDITS - (vp_height - credits_container.size.y)/2

func start_autoscroll() -> void:
    _autoscrolling = true
    if credits_scroll.scroll_vertical > ABOVE_CREDITS + credits_container.size.y - 20:
        credits_scroll.scroll_vertical = ABOVE_CREDITS - get_viewport_rect().size.y

func stop_autoscroll() -> void:
    _autoscrolling = false

func _start_role_name_grid() -> GridContainer:
    var grid: GridContainer = GridContainer.new()
    grid.theme_type_variation = "RoleNameGrid"
    grid.columns = 2
    grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    credits_container.add_child(grid)
    return grid

func _start_just_names_flow() -> HFlowContainer:
    var flow: HFlowContainer = HFlowContainer.new()
    flow.alignment = FlowContainer.ALIGNMENT_CENTER
    flow.theme_type_variation = "NameList"
    flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    credits_container.add_child(flow)
    return flow

func _add_space(spacer_height: int = 30) -> void:
    var spacer: Control = Control.new()
    spacer.name = "Spacer"
    spacer.custom_minimum_size = Vector2(0, spacer_height)
    credits_container.add_child(spacer)

func _add_role_name_item(to_grid: GridContainer, role: String, credit_name: String) -> void:
    var role_label: Label = _get_right_label(role, "RoleText")
    to_grid.add_child(role_label)
    var name_label: Label = _get_left_label(credit_name, "NameCreditText")
    to_grid.add_child(name_label)

func _get_right_label(text: String, type_variation: String = "") -> Label:
    var label: = _get_label(text, type_variation)
    label.size_flags_horizontal = Control.SIZE_EXPAND
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    return label

func _get_left_label(text: String, type_variation: String = "") -> Label:
    var label: = _get_label(text, type_variation)
    label.size_flags_horizontal = Control.SIZE_EXPAND
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    return label

func _get_centered_label(text: String, type_variation: String = "") -> Label:
    var label: = _get_label(text, type_variation)
    label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    return label

func _get_label(text: String, type_variation: String = "") -> Label:
    var label: Label = Label.new()
    label.text = text
    if type_variation:
        label.theme_type_variation = type_variation
    return label

func _get_link_label(url: String) -> RichTextLabel:
    var link_label: RichTextLabel = link_label_scn.instantiate()
    link_label.set_link_url(url)
    return link_label

func _get_image(texture: Texture2D, relative_scale: float, with_dark_bg: bool, sharp_scale: bool) -> Control:
    var image: Control = image_scn.instantiate()
    image.set_texture(texture, relative_scale, with_dark_bg, sharp_scale)
    return image

func clear_credits_container() -> void:
    for child in credits_container.get_children():
        credits_container.remove_child(child)
        child.queue_free()

func close_credits() -> void:
    stop_autoscroll()
    reset_scroll()
    hide()
    GameManager.set_pause("credits", false)
    credits_closed.emit()