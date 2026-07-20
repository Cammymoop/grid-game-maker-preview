extends Control

const IntermissionConfigItem = preload("res://Scenes/Intermission/intermission_config_item.gd")

const IntermissionText = preload("res://Scenes/Intermission/intermission_text.gd")
const CreditsImage = preload("res://Scenes/credits_image.gd")

const TYPES = IntermissionConfigItem.TYPES

const TYPE_TEXT: String = IntermissionConfigItem.TYPES[IntermissionConfigItem.TEXT_IDX]
const TYPE_IMAGE: String = IntermissionConfigItem.TYPES[IntermissionConfigItem.IMAGE_IDX]
const TYPE_SPACE: String = IntermissionConfigItem.TYPES[IntermissionConfigItem.SPACE_IDX]

var intermission_text_scn: = preload("res://Scenes/Intermission/intermission_text.tscn")
var credits_image_scn: = preload("res://Scenes/credits_image.tscn")

const SPACE_MULTIPLIER: float = 5

@export var dark_bg: Control
@export var light_bg: Control

@export var inner_container: Control

@export var content_section: Control
@export var continue_section: Control

var is_setup: = false

@export var do_fade_in: = true
var fade_in_duration: = 0.45
var fade_in_timer: = Timer.new()

var fade_in_ease_param: float = 2.5
var scale_from: float = 0.86

func _ready() -> void:
    fade_in_timer = Timer.new()
    fade_in_timer.one_shot = true
    add_child(fade_in_timer)
    if do_fade_in and is_setup:
        fade_in_timer.start(fade_in_duration)
        _fade_in_update()

func setup(intermission_id: String) -> void:
    var intermission_info: Dictionary = GameManager.get_tagged_intermission_info(intermission_id)
    setup_with_info(intermission_info)

func setup_with_info(intermission_info: Dictionary) -> void:
    clear_content()
    reset_fade()
    
    light_bg.visible = intermission_info.get("light_background", true)
    dark_bg.visible = not light_bg.visible and intermission_info.get("dark_background", false)
    
    var content_items: Array = intermission_info.get("content_items", [])
    content_section.visible = content_items.size() > 0
    for item_info in content_items:
        append_item(item_info)
    
    var show_continue: bool = intermission_info.get("show_continue", true)
    continue_section.visible = show_continue
    
    if do_fade_in and fade_in_timer:
        fade_in_timer.start(fade_in_duration)
        _fade_in_update()
    
    is_setup = true

func _process(_delta: float) -> void:
    if fade_in_timer.is_stopped():
        reset_fade()
        return
    _fade_in_update()
    
func _fade_in_update() -> void:
    var time_left: float = fade_in_timer.time_left
    var progress: float = 1.0 - (time_left / fade_in_duration)
    var non_linear_amt: = ease(progress, fade_in_ease_param)

    inner_container.modulate = Color(1, 1, 1, non_linear_amt)
    inner_container.scale = Vector2.ONE * (non_linear_amt * (1 - scale_from) + scale_from)

func reset_fade() -> void:
    fade_in_timer.stop()
    inner_container.scale = Vector2.ONE
    inner_container.modulate = Color.WHITE
    

func append_item(item_info: Dictionary) -> void:
    var item_type: String = item_info.get("type", "")
    if not item_type in TYPES:
        return
    
    if item_type == TYPE_TEXT:
        var text_item: IntermissionText = intermission_text_scn.instantiate()
        content_section.add_child(text_item)
        text_item.setup(item_info)
    elif item_type == TYPE_IMAGE:
        var image_item: CreditsImage = _get_credits_image_item(item_info)
        content_section.add_child(image_item)
    elif item_type == TYPE_SPACE:
        var space_item: Control = Control.new()
        space_item.custom_minimum_size.y = minf(item_info.get("space_amount", 0) * SPACE_MULTIPLIER, 400)
        space_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
        content_section.add_child(space_item)

func _get_credits_image_item(item_info: Dictionary) -> CreditsImage:
    var image_item: CreditsImage = credits_image_scn.instantiate()
    var texture_id: int = item_info.get("texture_id", -1)
    if texture_id == -1 or not TextureManager.has_texture_id(texture_id):
        texture_id = TextureManager.get_fallback_texture_id()
    var texture_sub_index: int = item_info.get("texture_sub_index", 0)
    var atlas_texture: Texture2D = Utility.atlas_texture_from_texture_index(texture_id, texture_sub_index)

    var relative_scale: float = item_info.get("scale", 1.0)
    var with_dark_bg: bool = item_info.get("dark_background", false)
    var sharp_scale: bool = not item_info.get("scale_smooth", false)
    image_item.set_texture(atlas_texture, relative_scale, with_dark_bg, sharp_scale)

    var mod_color: Color = Utility.get_dict_color(item_info, "mod_color", Color.WHITE)
    image_item.set_mod_color(mod_color)
    
    if item_info.get("light_background", false):
        image_item.make_bg_light()

    return image_item

func clear_content() -> void:
    for child in content_section.get_children():
        content_section.remove_child(child)
        child.queue_free()