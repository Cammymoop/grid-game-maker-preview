extends Window

signal hidden

const BetterTextureDialog = preload("res://src/GameEditor/BetterTextureDialog.gd")
const Toaster = preload("res://src/Singletons/global_toaster.gd")

const TilePicker = preload("res://src/GameEditor/TilePicker.gd")

var texture_dialog = preload("res://Scenes/GameEditor/BetterTextureDialog.tscn")

@export var local_tile_picker: TilePicker
@export var loaded_texture: Texture2D
@export var make_tex_with_size: Vector2

@export var title_label: Label

@export var local_toaster: Toaster

@export var tl_paint_btn: ButtonContainer
@export var tr_paint_btn: ButtonContainer
@export var bl_paint_btn: ButtonContainer
@export var br_paint_btn: ButtonContainer
@export var whole_brush_paint_btn: ButtonContainer

@onready var corner_buttons_by_index: Dictionary = {
	0: tl_paint_btn,
	1: tr_paint_btn,
	2: bl_paint_btn,
	3: br_paint_btn,
	-1: whole_brush_paint_btn,
}

@export var rotate_brush_ccw_button: ButtonContainer
@export var rotate_brush_cw_button: ButtonContainer
@export var shift_brush_button: ButtonContainer
@export var flip_brush_button: ButtonContainer

@export var brush_color_picker: ColorPickerButton
@export var brush_secondary_color_picker: ColorPickerButton
@export var swap_colors_button: ButtonContainer

@export var tile_canvas: TextureRect

@export var force_transparent_format: bool = true

var _skip_updating_tile_picker_view_scale: bool = false

var save_as_name: = ""

var edited_is_bundled: bool = false

var edited_image: Image
var edited_texture: Texture2D

var image_meta: Dictionary

var tile_brush_image: Image
var temp_tile_brush_image: Image

var tile_brush_preview_image: Image
var showing_tile_brush_preview: bool = false

@export var picked_brush_tex: AtlasTexture
var picked_brush_image: Image
var picked_colored_preview: ImageTexture
var picked_colored_brush_image: Image


@onready var undoer = $UndoRedoer
const MAX_TILE_BRUSH_UNDOS = 100
const MAX_TEXTURE_UNDOS = 10

var last_tile_brush_change_was_transform: bool = false

@onready var tile_brush_canvas: TextureRect = find_child("BrushView")
const TBC_MAX_WIDTH: = 260
const TBC_MAX_HEIGHT: = 152

const PICKED_BRUSH_MAX: Vector2 = Vector2(70, 70)

const COLOR_PREVIEW_MAX: Vector2 = Vector2(128, 128)

# targeted size for local tile picker
var ltp_target_height: = 240
var ltp_margin: = 120

@export var brush_wrap: = true

var starting_brush_id: int = 0
var picked_texture_sub_index = 0

var picked_brush_offset: Vector2 = Vector2.ZERO

var brush_creator_mode: = "replace"

var brush_color_mode: = "source"
var brush_color: = Color.WHITE

var brush_sliding_h: = 0
var brush_sliding_v: = 0

var transparent_img: Image

var corner_size: Vector2
var tl_corner: Rect2i
var tr_corner: Rect2i
var bl_corner: Rect2i
var br_corner: Rect2i
var whole_brush: Rect2i

var picked_brush_texture_info: Dictionary = {}

@export var hold_corner_button_timer: Timer = Timer.new()
var hold_corner_index: int = -2
var toggled_corner_index: int = -2

func set_texture(tex: Texture2D) -> void:
	loaded_texture = tex
	if is_inside_tree():
		prints("set texture after already inside tree, auto sizing")
		auto_size()

func set_new_texture_size(new_size: Vector2) -> void:
	loaded_texture = null
	make_tex_with_size = new_size

func set_metadata(metadata: Dictionary) -> void:
	image_meta = metadata

func set_filename(file_name: String) -> void:
	save_as_name = file_name
	if save_as_name:
		find_child("SaveFileButton").disabled = false
	else:
		find_child("SaveFileButton").disabled = true
	if save_as_name:
		title_label.text = file_name + ":"
	else:
		title_label.text = "Image:"
		

func _ready():
	size_changed.connect(on_size_changed)

	if not TextureManager.has_texture_id(starting_brush_id):
		starting_brush_id = TextureManager.get_fallback_texture_id()
	
	brush_secondary_color_picker.hide()
	brush_secondary_color_picker.color_changed.connect(secondary_color_changed)
	swap_colors_button.pressed.connect(swap_colors)
	swap_colors_button.hide()

	find_child("BrushWrap").set_pressed_no_signal(brush_wrap)
	close_requested.connect(hide)
	visibility_changed.connect(Callable(self, "_on_vis_changed"))
	if get_parent() is SubViewport:
		# Running scene in standalone mode
		popup_centered()
	if not loaded_texture and not make_tex_with_size:
		print_debug("I need a texture to edit, or a size to create")
		queue_free()
		return
	
	undoer.add_undo_stack("tile_brush", MAX_TILE_BRUSH_UNDOS)
	undoer.set_buttons("tile_brush", find_child("UndoBrushButton"), find_child("RedoBrushButton"))
	undoer.add_undo_stack("texture", MAX_TEXTURE_UNDOS)
	undoer.set_buttons("texture", find_child("UndoTextureButton"), find_child("RedoTextureButton"))
	
	hold_corner_button_timer.one_shot = true
	hold_corner_button_timer.timeout.connect(hold_corner_button_timeout)
	
	tl_paint_btn.button.gui_input.connect(paint_button_gui_input.bind(tl_paint_btn))
	tr_paint_btn.button.gui_input.connect(paint_button_gui_input.bind(tr_paint_btn))
	bl_paint_btn.button.gui_input.connect(paint_button_gui_input.bind(bl_paint_btn))
	br_paint_btn.button.gui_input.connect(paint_button_gui_input.bind(br_paint_btn))
	whole_brush_paint_btn.button.gui_input.connect(paint_button_gui_input.bind(whole_brush_paint_btn))
	
	rotate_brush_ccw_button.pressed.connect(rotate_brush_ccw)
	rotate_brush_cw_button.pressed.connect(rotate_brush_cw)
	shift_brush_button.pressed.connect(shift_brush_right)
	flip_brush_button.pressed.connect(flip_brush_horizontal)
	
	
	var tile_size = image_meta['tile_size']
	
	if loaded_texture:
		edited_image = loaded_texture.get_image()
		var edited_format = edited_image.get_format()
		if force_transparent_format and edited_format != Image.FORMAT_RGBA8:
			edited_image.convert(Image.FORMAT_RGBA8)
	else:
		edited_image = Image.create(make_tex_with_size.x, make_tex_with_size.y, true, Image.FORMAT_RGBA8)

	set_tile_brush_size(tile_size)
	
	edited_texture = ImageTexture.create_from_image(edited_image)
	
	local_tile_picker.set_raw_texture(edited_texture, image_meta)
	
	local_tile_picker.confirmed.connect(on_tile_picker_confirmed)
	
	auto_size()
	
	var brushModes = find_child("BrushCreatorModes")
	if brushModes and brushModes.get_child_count() > 0:
		brushModes.get_child(0).button_group.connect("pressed", Callable(self, "_on_BrushModeChange"))
	
	var brushColorModes = find_child("BrushColorModes")
	if brushColorModes and brushColorModes.get_child_count() > 0:
		brushColorModes.get_child(0).button_group.connect("pressed", Callable(self, "_on_BrushColorModeChange"))
	
	if picked_brush_tex:
		update_picked_brush()
	
	update_tile_brush_preview()
	
	hidden.connect(queue_free)

func secondary_color_changed(_color: Color) -> void:
	update_picked_colored_brush()

func _shortcut_input(event: InputEvent) -> void:
	if Utility.fixed_just_pressed_by_event("save_file_as_shortcut", event):
		_on_SaveAsFileButton_pressed()
		set_input_as_handled()
	elif Utility.fixed_just_pressed_by_event("save_file_shortcut", event):
		_on_SaveFileButton_pressed()
		set_input_as_handled()

	if Utility.event_is_menu_back_just_pressed(event):
		hide()
		set_input_as_handled()

func rescale_tile_picker() -> void:
	if not edited_image:
		return
	local_tile_picker.set_view_scale(1)
	var content_minimum_height: int = int(get_child(0).get_minimum_size().y)
	var picker_parent_height: int = int(local_tile_picker.get_parent().get_minimum_size().y)

	var available_height: int = size.y - (content_minimum_height - picker_parent_height)
	
	var outer_window_available_height: int = get_parent().get_viewport().size.y - (content_minimum_height - picker_parent_height)
	
	if edited_image.get_size().y > outer_window_available_height:
		var scale_down: = outer_window_available_height / float(edited_image.get_size().y)
		local_tile_picker.set_target_size((edited_image.get_size() * scale_down).floor())
	else:
		var target_height: int = maxi(ltp_target_height, available_height)
		var tp_scale = Utility.max_integer_scale_in(edited_image.get_size(), Vector2(size.x - ltp_margin, target_height))
		if tp_scale == 0:
			tp_scale = 1
		local_tile_picker.set_view_scale(tp_scale)
		#local_tile_picker.rect_min_size = edited_image.get_size() * tp_scale
		#local_tile_picker.rect_size = local_tile_picker.rect_min_size

func auto_size() -> void:
	if not is_inside_tree() or not local_tile_picker or not edited_image:
		push_warning("Tile Compositor skipping auto size, image or tile picker not setup or tile compositor isn't shown")
		return
	await get_tree().process_frame
	rescale_tile_picker()
	var outer_window_size: Vector2 = Vector2(get_parent().get_viewport().size)

	var content_min_size: = Vector2i(get_child(0).get_combined_minimum_size())
	var tp_min_size: = Vector2i(local_tile_picker.get_combined_minimum_size())
	var tpp: Control = local_tile_picker.get_parent()
	var tpp_min_size: = Vector2i(tpp.get_combined_minimum_size())
	var h_margin: = content_min_size.x - tpp_min_size.x
	var tpp_h_extra: = tpp_min_size.x - tp_min_size.x

	_skip_updating_tile_picker_view_scale = true
	var target_height: = outer_window_size.y * 0.95
	if size.y < outer_window_size.y * 0.95:
		var new_available_height: = target_height - (content_min_size.y - tpp_min_size.y)
		var upsize_factor: = new_available_height / float(tpp_min_size.y)
		var new_tpp_width: = (tpp_min_size.x - tpp_h_extra) * upsize_factor + tpp_h_extra
		size.y = target_height
		size.x = mini(h_margin + new_tpp_width, outer_window_size.x * 0.95)
		
		await get_tree().process_frame
		rescale_tile_picker()

	content_min_size = Vector2i(get_child(0).get_combined_minimum_size())
	size = Vector2(maxi(content_min_size.x, size.x), content_min_size.y)
	_skip_updating_tile_picker_view_scale = false

	move_to_center()


func on_size_changed() -> void:
	if local_tile_picker and not _skip_updating_tile_picker_view_scale:
		rescale_tile_picker()


func set_tile_brush_size(tile_size: Vector2) -> void:
	whole_brush = Rect2i(Vector2.ZERO, tile_size)
	corner_size = Vector2(ceil(tile_size.x/2), ceil(tile_size.y/2))
	tl_corner = Rect2i(Vector2.ZERO, corner_size)
	var odd_x = int(tile_size.x) % 2
	var odd_y = int(tile_size.y) % 2
	tr_corner = Rect2i(Vector2(corner_size.x - odd_x, 0), corner_size)
	bl_corner = Rect2i(Vector2(0, corner_size.y - odd_y), corner_size)
	br_corner = Rect2i(Vector2(corner_size.x - odd_x, corner_size.y - odd_y), corner_size)
	
	tile_brush_image = Image.create_empty(tile_size.x, tile_size.y, false, edited_image.get_format())
	transparent_img = Image.create_empty(tile_size.x, tile_size.y, false, edited_image.get_format())
	
	var max_tile_brush_canvas: = Vector2(TBC_MAX_WIDTH, TBC_MAX_HEIGHT)
	var preview_scale = Utility.max_integer_scale_in(tile_size, max_tile_brush_canvas)
	if preview_scale < 2:
		preview_scale = Utility.max_integer_scale_in(tile_size, max_tile_brush_canvas * 2)

	tile_brush_canvas.custom_minimum_size = tile_size * preview_scale
	tile_brush_canvas.size = tile_size * preview_scale
	
	var h_slide = find_child("BrushSlideH")
	h_slide.max_value = tile_size.x - odd_x
	h_slide.value = floor(tile_size.x/2.0)
	
	var v_slide = find_child("BrushSlideV")
	v_slide.max_value = tile_size.y - odd_y
	v_slide.value = ceil(tile_size.y/2.0)


func _on_BrushModeChange(new_selected):
	brush_creator_mode = new_selected.text.to_lower()
func _on_BrushColorModeChange(new_selected):
	brush_color_mode = new_selected.name
	var is_dual_colorize: = brush_color_mode.begins_with("dual_colorize")
	brush_secondary_color_picker.visible = is_dual_colorize
	swap_colors_button.visible = is_dual_colorize
	update_picked_colored_brush()

func swap_colors() -> void:
	brush_color_picker.color = brush_secondary_color_picker.color
	brush_secondary_color_picker.color = brush_color
	brush_color = brush_color_picker.color
	update_picked_colored_brush()

func update_picked_brush() -> void:
	picked_brush_image = picked_brush_tex.get_image()
	if picked_brush_image.get_format() != edited_image.get_format():
		picked_brush_image.convert(edited_image.get_format())
	update_picked_colored_brush()

func update_picked_colored_brush() -> void:
	if not picked_colored_brush_image:
		picked_colored_brush_image = Image.new()
	picked_colored_brush_image.copy_from(picked_brush_image)
	color_brush()
	picked_colored_preview = ImageTexture.create_from_image(picked_colored_brush_image)
	
	var picked_size: = picked_brush_image.get_size()
	for tex_rect: TextureRect in [find_child("PickBrushButton").find_child("Icon")]:
		tex_rect.texture = picked_colored_preview
		#tex_rect.stretch_mode = TextureRect.STRETCH_KEEP
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		
		var preview_scale: float = float(Utility.max_integer_scale_in(picked_size, PICKED_BRUSH_MAX))
		var clipped_size: = Vector2.ZERO
		if picked_size.x > PICKED_BRUSH_MAX.x * 8 or picked_size.y > PICKED_BRUSH_MAX.y * 8:
			var exact_scale: float = minf(PICKED_BRUSH_MAX.x / picked_size.x, PICKED_BRUSH_MAX.y / picked_size.y)
			clipped_size = (picked_size * exact_scale).floor()
		else:
			if preview_scale == 0:
				preview_scale = Utility.max_integer_scale_in(picked_size, PICKED_BRUSH_MAX * 8) / 8.0
				if preview_scale == 0:
					preview_scale = 0.125
			clipped_size = (picked_size * preview_scale).min(PICKED_BRUSH_MAX)
		tex_rect.custom_minimum_size = clipped_size
		tex_rect.size = clipped_size
	
	var color_preview: = find_child("BrushColorPreview") as TextureRect
	color_preview.texture = picked_colored_preview
	color_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	var color_preview_scale: = Utility.max_integer_scale_in(picked_size, COLOR_PREVIEW_MAX)
	if color_preview_scale == 0:
		color_preview_scale = 0.5
	var new_min_size: = picked_size * color_preview_scale
	color_preview.custom_minimum_size = new_min_size.min(COLOR_PREVIEW_MAX)
	color_preview.size = color_preview.custom_minimum_size
	#color_preview.update_minimum_size()
	
	var crosshair = find_child("PickedCrosshair")
	picked_brush_offset = ((picked_size - tile_brush_image.get_size()) / 2.0).floor()
	crosshair.set_my_size(picked_size)
	crosshair.set_size_offset(tile_brush_image.get_size(), picked_brush_offset)


func color_brush() -> void:
	if brush_color_mode == "source":
		return
	
	var img = picked_colored_brush_image
	
	var mode_flat: = brush_color_mode == "flat"
	var mode_colorize: = brush_color_mode.begins_with("colorize")
	var alt_colorize_lightness: = brush_color_mode == "colorize_2"
	var mode_dual_colorize: = brush_color_mode.begins_with("dual_colorize")
	var alt_dual_lightness: = brush_color_mode == "dual_colorize_2"
	var colorizing: = mode_colorize or mode_dual_colorize
	
	var secondary_color: = brush_secondary_color_picker.color
	
	if not colorizing and not mode_flat:
		return
	
	# fix hues in case one of the inputs is fully desaturated to avoid rainbow shifts
	var v4_color: = Utility.color_to_ok_hsl_vector4(brush_color)
	var v4_secondary_color: = Utility.color_to_ok_hsl_vector4(secondary_color)
	if mode_dual_colorize:
		if is_zero_approx(v4_color.y):
			v4_color.x = v4_secondary_color.x
		elif is_zero_approx(v4_secondary_color.y):
			v4_secondary_color.x = v4_color.x
	
	var lightness_normalized_scale: = 1.0
	var lightness_max: = 1.0
	var lightness_min: = 0.0
	var lightness_bright_factor: = 1.0
	if mode_dual_colorize or (mode_colorize and not alt_colorize_lightness):
		lightness_max = 0.0
		lightness_min = 1.0
		for y in range(img.get_height()):
			for x in range(img.get_width()):
				var pixel_color: = img.get_pixel(x, y)
				if pixel_color.a < 0.01:
					continue
				var source_lightness: = pixel_color.ok_hsl_l
				lightness_max = maxf(lightness_max, source_lightness)
				lightness_min = minf(lightness_min, source_lightness)
		var lightness_normalized_span: = lightness_max - lightness_min
		lightness_bright_factor = (1 - lightness_min) / lightness_normalized_span
		if not is_zero_approx(lightness_normalized_span):
			lightness_normalized_scale = 1.0 / lightness_normalized_span
		else:
			# if there's only one lightness value then set up params to always get a lerp factor of 1 (primary color)
			if is_zero_approx(lightness_max):
				lightness_min = -1
				lightness_normalized_scale = 1
			else:
				lightness_normalized_scale = 1.0 / lightness_min
				lightness_min = 0.0
			
			if mode_colorize:
				lightness_min = 1.0
				lightness_bright_factor = 0.0
	
	for x in range(img.get_width()):
		for y in range(img.get_height()):
			var pixel_color: = img.get_pixel(x, y)
			if mode_flat:
				img.set_pixel(x, y, Color(brush_color, brush_color.a * pixel_color.a))
			elif colorizing:
				var colorize_to: = brush_color
				var source_lightness: = pixel_color.ok_hsl_l
				var lerp_factor: = (source_lightness - lightness_min) * lightness_normalized_scale
				if mode_dual_colorize:
					var lerp_v4: = v4_secondary_color.lerp(v4_color, lerp_factor)
					lerp_v4.x = lerp_angle(v4_secondary_color.x * TAU, v4_color.x * TAU, lerp_factor) / TAU
					colorize_to = Color.from_ok_hsl(lerp_v4.x, lerp_v4.y, lerp_v4.z, lerp_v4.w)
				var lightness: float = 1
				if mode_dual_colorize and not alt_dual_lightness:
					lightness = colorize_to.ok_hsl_l
				elif mode_colorize and not alt_colorize_lightness:
					lightness = ((source_lightness - lightness_min) * lightness_bright_factor + lightness_min) * colorize_to.ok_hsl_l
				else:
					lightness = source_lightness * colorize_to.ok_hsl_l
				var alpha: = pixel_color.a * colorize_to.a
				img.set_pixel(x, y, Color.from_ok_hsl(colorize_to.ok_hsl_h, colorize_to.ok_hsl_s, lightness, alpha))
		

func update_tile_brush_preview() -> void:
	var img = tile_brush_image if not showing_tile_brush_preview else tile_brush_preview_image
	find_child("BrushView").texture = ImageTexture.create_from_image(img)

func repaint() -> void:
	edited_texture = ImageTexture.create_from_image(edited_image)
	local_tile_picker.set_raw_texture(edited_texture, image_meta)

func paint_corner_to_tile_brush(corner: Rect2i) -> void:
	save_tile_brush_undo_state()
	do_corner_paint(corner, tile_brush_image)
	showing_tile_brush_preview = false
	
	update_tile_brush_preview()

func paint_positioned_corner_at_pos(center_pos: Vector2) -> void:
	if toggled_corner_index == -2:
		return
	save_tile_brush_undo_state()
	_paint_positioned_corner_at_pos(center_pos, tile_brush_image, toggled_corner_index)

	showing_tile_brush_preview = false
	update_tile_brush_preview()

func preview_positioned_corner_at_pos(center_pos: Vector2) -> void:
	if toggled_corner_index == -2:
		return
	tile_brush_preview_image = tile_brush_image.duplicate()
	_paint_positioned_corner_at_pos(center_pos, tile_brush_preview_image, toggled_corner_index)

	showing_tile_brush_preview = true
	update_tile_brush_preview()

func _paint_positioned_corner_at_pos(center_pos: Vector2, to_image: Image, corner_index: int) -> void:
	var corner: = get_corner_rect_for_index(corner_index, to_image.get_size())
	do_positioned_corner_paint(corner, to_image, center_pos, corner_index)

func do_corner_paint(corner: Rect2i, dest_image: Image) -> void:
	var src_rect: = corner
	src_rect.position += Vector2i(picked_brush_offset)
	if brush_creator_mode == "erase":
		dest_image.blit_rect(transparent_img, corner, corner.position)
	elif brush_creator_mode == "replace":
		dest_image.blit_rect(transparent_img, corner, corner.position)
		dest_image.blit_rect(picked_colored_brush_image, src_rect, corner.position)
	elif brush_creator_mode == "over":
		dest_image.blend_rect(picked_colored_brush_image, src_rect, corner.position)
	elif brush_creator_mode == "under":
		var old_brush = Image.new()
		old_brush.copy_from(dest_image)
		dest_image.blit_rect(picked_colored_brush_image, src_rect, corner.position)
		dest_image.blend_rect(old_brush, whole_brush, Vector2.ZERO)
	elif brush_creator_mode == "stamp":
		stamp_blit(picked_colored_brush_image, dest_image, src_rect, corner.position)
	elif brush_creator_mode == "cut":
		alpha_min(picked_colored_brush_image, dest_image, src_rect, corner.position)
	elif brush_creator_mode == "hole cut":
		alpha_subtract(picked_colored_brush_image, dest_image, src_rect, corner.position)

func do_positioned_corner_paint(corner: Rect2i, dest_image: Image, dest_center: Vector2, corner_index: int) -> void:
	var src_rect: = corner
	src_rect.position += Vector2i(picked_brush_offset)
	
	var dest_rect: = corner
	dest_rect.position = Vector2i((dest_center - (Vector2(corner.size) / 2.0)).ceil())
	_rect_mode_paint(src_rect, dest_image, dest_rect, corner_index, dest_center)

func _rect_mode_paint(src_rect: Rect2i, dest_image: Image, dest_rect: Rect2i, corner_index: int, center_pos: Vector2) -> void:
	var exp_dest_rect: = get_expanded_corner(corner_index, dest_image.get_size(), dest_rect)
	exp_dest_rect = exp_dest_rect.intersection(Rect2i(Vector2i.ZERO, dest_image.get_size()))
	var exp_clip_delta_pos: = exp_dest_rect.position - dest_rect.position

	var exp_src_rect: = Rect2i(src_rect.position + exp_clip_delta_pos, exp_dest_rect.size)
	var final_clipped_src_rect: = exp_src_rect.intersection(Rect2i(Vector2i.ZERO, picked_colored_brush_image.get_size()))
	var missing_pixels: bool = final_clipped_src_rect.size != exp_src_rect.size

	if brush_creator_mode == "erase":
		# use center of dest rect in erase mode since brush size doesn't matter
		var erase_rect: = get_positioned_corner(corner_index, dest_image.get_size(), center_pos)
		dest_image.blit_rect(transparent_img, erase_rect, erase_rect.position)
	elif brush_creator_mode == "replace":
		# use expanded rect to erase stuff outside of the reach of src
		if missing_pixels:
			dest_image.blit_rect(transparent_img, exp_dest_rect, exp_dest_rect.position)
		dest_image.blit_rect(picked_colored_brush_image, exp_src_rect, exp_dest_rect.position)
	elif brush_creator_mode == "over":
		dest_image.blend_rect(picked_colored_brush_image, exp_src_rect, exp_dest_rect.position)
	elif brush_creator_mode == "under":
		var old_dest = dest_image.get_region(exp_dest_rect)
		#old_dest.copy_from(dest_image)
		if missing_pixels:
			dest_image.blit_rect(transparent_img, exp_dest_rect, exp_dest_rect.position)
		dest_image.blit_rect(picked_colored_brush_image, exp_src_rect, exp_dest_rect.position)
		dest_image.blend_rect(old_dest, Rect2i(Vector2i.ZERO, old_dest.get_size()), exp_dest_rect.position)
	elif brush_creator_mode == "stamp":
		stamp_blit(picked_colored_brush_image, dest_image, exp_src_rect, exp_dest_rect.position)
	elif brush_creator_mode == "cut":
		alpha_min(picked_colored_brush_image, dest_image, exp_src_rect, exp_dest_rect.position)
	elif brush_creator_mode == "hole cut":
		alpha_subtract(picked_colored_brush_image, dest_image, exp_src_rect, exp_dest_rect.position)

func _single_pixel_paint_mode(dest_image: Image, dest_pos: Vector2i) -> void:
	if brush_creator_mode == "erase":
		dest_image.set_pixelv(dest_pos, Color.TRANSPARENT)
		return
	elif brush_creator_mode == "replace":
		dest_image.set_pixelv(dest_pos, brush_color)
		return

	var paint_color: = Color.WHITE
	var dest_color: = dest_image.get_pixelv(dest_pos)
	if brush_creator_mode == "over":
		paint_color = dest_color.blend(brush_color)
	elif brush_creator_mode == "under":
		paint_color = brush_color.blend(dest_color)
	elif brush_creator_mode == "stamp":
		paint_color = Color(dest_color.blend(brush_color), dest_color.a)
	elif brush_creator_mode == "cut":
		paint_color = Color(dest_color, minf(brush_color.a, dest_color.a))
	elif brush_creator_mode == "hole cut":
		paint_color = Color(dest_color, maxf(0, dest_color.a - brush_color.a))

	dest_image.set_pixelv(dest_pos, paint_color)

func flood_fill_paint_mode(dest_image: Image, start_pos: Vector2i) -> void:
	var image_rect: = Rect2i(Vector2i.ZERO, dest_image.get_size())
	if not image_rect.has_point(start_pos):
		return
	
	var visited_positions: Array[Vector2i] = []
	var outer_edges: Array[Vector2i] = []
	var fill_on_color: = dest_image.get_pixelv(start_pos)
	
	var difference_threshold: = 0.01 * 0.01
	
	outer_edges.append(start_pos)
	visited_positions.append(start_pos)
	
	print("flood filling image, size:", dest_image.get_size(), "clip rect:", image_rect)

	var safety: = 100000
	while outer_edges.size() > 0 and safety > 0:
		safety -= 1
		
		var at_pos: = outer_edges.pop_front() as Vector2i
		_single_pixel_paint_mode(dest_image, at_pos)
		for adjacent_pos in _get_new_positions_around(at_pos, visited_positions, image_rect):
			var color_here: = dest_image.get_pixelv(adjacent_pos)
			var difference: = Utility.color_ok_hsl_difference(color_here, fill_on_color).length_squared()
			if difference < difference_threshold:
				outer_edges.append(adjacent_pos)
				visited_positions.append(adjacent_pos)
	

func _get_new_positions_around(from_pos: Vector2i, cur_pos_list: Array[Vector2i], clip_rect: Rect2i) -> Array[Vector2i]:
	var new_positions: Array[Vector2i] = []
	for pos: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var new_pos: = from_pos + pos
		if not clip_rect.has_point(new_pos) or new_pos in cur_pos_list:
			continue
		new_positions.append(new_pos)
	return new_positions


func get_positioned_corner(corner_index: int, in_size: Vector2i, at_position: Vector2i) -> Rect2i:
	if corner_index == -1:
		return Rect2i(Vector2i.ZERO, in_size)
	var corner_dir: = Vector2i(corner_index % 2, 0 if corner_index < 2 else 1)
	var outer_corner_size: = in_size - at_position
	var actual_size: = (at_position * (Vector2i.ONE - corner_dir)) + (outer_corner_size * corner_dir)
	return Rect2i(at_position * corner_dir, actual_size)

func get_expanded_corner(corner_index: int, in_size: Vector2i, current_rect: Rect2i) -> Rect2i:
	if corner_index == -1:
		return Rect2i(Vector2i.ZERO, in_size)
	var corner_dir: = Vector2i(corner_index % 2, 0 if corner_index < 2 else 1)
	var old_end = current_rect.end
	current_rect.position = current_rect.position * corner_dir
	current_rect.end = old_end * (Vector2i.ONE - corner_dir) + (in_size * corner_dir)
	return current_rect

func get_corner_rect_for_index(corner_index: int, in_size: Vector2i) -> Rect2i:
	if corner_index == -1:
		return Rect2i(Vector2i.ZERO, in_size)
	var corner_dir: = Vector2i(corner_index % 2, 0 if corner_index < 2 else 1)
	var the_corner_size: Vector2i = (Vector2(in_size) / 2.0).ceil()
	var odds: = Vector2i(int(in_size.x) % 2, int(in_size.y) % 2)
	return Rect2i((the_corner_size * corner_dir) - odds, the_corner_size)


func alpha_subtract(from_image: Image, to_image, src_rect: Rect2i, dest_offset: Vector2) -> void:
	var w = src_rect.size.x
	var h = src_rect.size.y
	var src_offset = src_rect.position
	var src_image_rect: = Rect2i(Vector2i.ZERO, from_image.get_size())
	var to_image_rect: = Rect2i(Vector2i.ZERO, to_image.get_size())
	
	for x in range(w):
		for y in range(h):
			var dest_pos: = Vector2i(dest_offset.x + x, dest_offset.y + y)
			var src_pos: = Vector2i(src_offset.x + x, src_offset.y + y)
			if not to_image_rect.has_point(dest_pos) or not src_image_rect.has_point(src_pos):
				continue
			var stencil_alpha: = from_image.get_pixelv(src_pos).a
			var cur_pixel: Color = to_image.get_pixelv(dest_pos)
			to_image.set_pixelv(dest_pos, Color(cur_pixel, maxf(0, cur_pixel.a - stencil_alpha)))

func alpha_multiply(from_image: Image, to_image, src_rect: Rect2i, dest_offset: Vector2) -> void:
	var w = src_rect.size.x
	var h = src_rect.size.y
	var src_offset = src_rect.position
	var src_image_rect: = Rect2i(Vector2i.ZERO, from_image.get_size())
	var to_image_rect: = Rect2i(Vector2i.ZERO, to_image.get_size())
	
	for x in range(w):
		for y in range(h):
			var dest_pos: = Vector2i(dest_offset.x + x, dest_offset.y + y)
			var src_pos: = Vector2i(src_offset.x + x, src_offset.y + y)
			if not to_image_rect.has_point(dest_pos) or not src_image_rect.has_point(src_pos):
				continue
			var stencil_alpha: = from_image.get_pixelv(src_pos).a
			var cur_pixel: Color = to_image.get_pixelv(dest_pos)
			to_image.set_pixelv(dest_pos, Color(cur_pixel, cur_pixel.a * stencil_alpha))

func alpha_inverse_multiply(from_image: Image, to_image, src_rect: Rect2i, dest_offset: Vector2) -> void:
	var w = src_rect.size.x
	var h = src_rect.size.y
	var src_offset = src_rect.position
	var src_image_rect: = Rect2i(Vector2i.ZERO, from_image.get_size())
	var to_image_rect: = Rect2i(Vector2i.ZERO, to_image.get_size())
	
	for x in range(w):
		for y in range(h):
			var dest_pos: = Vector2i(dest_offset.x + x, dest_offset.y + y)
			var src_pos: = Vector2i(src_offset.x + x, src_offset.y + y)
			if not to_image_rect.has_point(dest_pos) or not src_image_rect.has_point(src_pos):
				continue
			var stencil_alpha: = 1 - from_image.get_pixelv(src_pos).a
			var cur_pixel: Color = to_image.get_pixelv(dest_pos)
			to_image.set_pixelv(dest_pos, Color(cur_pixel, cur_pixel.a * stencil_alpha))

func _extended_get_pixel_alpha8(image: Image, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return 0
	return image.get_pixel(x, y).a8

func alpha_min(from_image: Image, to_image: Image, src_rect: Rect2i, dest_offset: Vector2) -> void:
	var w = src_rect.size.x
	var h = src_rect.size.y
	var src_offset = src_rect.position
	var to_image_rect: = Rect2i(Vector2i.ZERO, to_image.get_size())
	
	for x in range(w):
		for y in range(h):
			var dest_pos: = Vector2i(dest_offset.x + x, dest_offset.y + y)
			if not to_image_rect.has_point(dest_pos):
				continue
			var brush_alpha: = _extended_get_pixel_alpha8(from_image, src_offset.x + x, src_offset.y + y)
			var cur_pixel: Color = to_image.get_pixelv(dest_pos)
			cur_pixel.a8 = int(min(cur_pixel.a8, brush_alpha))
			to_image.set_pixelv(dest_pos, cur_pixel)

# paints the specified region onto to_image, while leaving the alpha channel unmodified
func stamp_blit(from_image: Image, to_image: Image, src_rect: Rect2i, dest_offset: Vector2) -> void:
	var w = src_rect.size.x
	var h = src_rect.size.y
	var src_offset = src_rect.position
	var src_image_rect: = Rect2i(Vector2.ZERO, from_image.get_size())
	var dest_image_rect: = Rect2i(Vector2.ZERO, to_image.get_size())
	
	for x in range(w):
		for y in range(h):
			var from_pos: = Vector2i(src_offset.x + x, src_offset.y + y)
			var dest_pos: = Vector2i(dest_offset.x + x, dest_offset.y + y)
			if not src_image_rect.has_point(from_pos) or not dest_image_rect.has_point(dest_pos):
				continue
			var color: = from_image.get_pixelv(from_pos)
			if is_zero_approx(color.a):
				# ignore completely transparent pixels
				continue
			var dest_color: = to_image.get_pixelv(dest_pos)
			if is_zero_approx(dest_color.a):
				continue

			# Style A: do a normal blend over, then keep the original dest alpha, slightly artificial
			#var blended: = dest_color.blend(color)
			# Style B: dest alpha is treated as if it is a mask that will be applied once dest is blended onto something else, 
			#     and stamp color is blended over dest color before this mask has been applied
			var blended: = Color(dest_color, 1).blend(color)
			to_image.set_pixelv(dest_pos, Color(blended.r, blended.g, blended.b, dest_color.a))

func paint_button_to_corner_index(button: ButtonContainer) -> int:
	if button == tl_paint_btn:
		return 0
	elif button == tr_paint_btn:
		return 1
	elif button == bl_paint_btn:
		return 2
	elif button == br_paint_btn:
		return 3
	elif button == whole_brush_paint_btn:
		return -1
	else:
		return -2

func paint_button_gui_input(event: InputEvent, corner_button: ButtonContainer) -> void:
	if event is InputEventMouseButton:
		var corner_index: = paint_button_to_corner_index(corner_button)
		if event.button_index == MOUSE_BUTTON_MASK_RIGHT and not event.is_pressed():
			change_toggled_corner_index(corner_index)
		if not event.button_index == MOUSE_BUTTON_MASK_LEFT:
			return
		
		if toggled_corner_index != -2 and event.is_pressed() and Utility.is_holding_alt_mode():
			paint_corner_button_psuedo_pressed(corner_button)
			hold_corner_index = -2
			return

		if event.is_pressed():
			hold_corner_index = corner_index
			hold_corner_button_timer.start()

			showing_tile_brush_preview = false
			update_tile_brush_preview()
		else:
			if corner_index == hold_corner_index:
				if not corner_index == toggled_corner_index:
					if toggled_corner_index != -2:
						change_toggled_corner_index(-2)
						_on_paint_corner_hovered(get_corner_rect_for_index(corner_index, tile_brush_image.get_size()))
					else:
						hold_corner_button_timer.stop()
						paint_corner_button_psuedo_pressed(corner_button)
				else:
					change_toggled_corner_index(-2)
					_on_paint_corner_hovered(get_corner_rect_for_index(corner_index, tile_brush_image.get_size()))
			hold_corner_index = -2

func change_toggled_corner_index(toggled_index: int) -> void:
	toggled_corner_index = toggled_index
	var variant: = "HeldButton" if toggled_index != -2 else ""
	for btn_idx in corner_buttons_by_index.keys():
		var is_pressed: = int(btn_idx) == toggled_index
		corner_buttons_by_index[btn_idx].toggle_mode = is_pressed
		corner_buttons_by_index[btn_idx].button_pressed = is_pressed
		corner_buttons_by_index[btn_idx].disabled = is_pressed
		corner_buttons_by_index[btn_idx].set_button_theme_variant(variant)

func hold_corner_button_timeout() -> void:
	change_toggled_corner_index(hold_corner_index)
	hold_corner_index = -2

func _on_TLButton_pressed() -> void:
	paint_corner_to_tile_brush(tl_corner)
func _on_TRButton_pressed() -> void:
	paint_corner_to_tile_brush(tr_corner)
func _on_BLButton_pressed() -> void:
	paint_corner_to_tile_brush(bl_corner)
func _on_BRButton_pressed() -> void:
	paint_corner_to_tile_brush(br_corner)
func _on_AllButton_pressed() -> void:
	paint_corner_to_tile_brush(whole_brush)

func paint_corner_button_psuedo_pressed(corner_button: ButtonContainer) -> void:
	var corner_index: = paint_button_to_corner_index(corner_button)
	var corner: = get_corner_rect_for_index(corner_index, tile_brush_image.get_size())
	paint_corner_to_tile_brush(corner)

func paint_tl() -> void:
	paint_corner_to_tile_brush(tl_corner)
func paint_tr() -> void:
	paint_corner_to_tile_brush(tr_corner)
func paint_bl() -> void:
	paint_corner_to_tile_brush(bl_corner)
func paint_br() -> void:
	paint_corner_to_tile_brush(br_corner)
func paint_whole_brush() -> void:
	paint_corner_to_tile_brush(whole_brush)

func _on_paint_corner_hovered(corner: Rect2i) -> void:
	if toggled_corner_index != -2:
		return
	tile_brush_preview_image = tile_brush_image.duplicate()
	do_corner_paint(corner, tile_brush_preview_image)
	showing_tile_brush_preview = true
	update_tile_brush_preview()

func _on_paint_corner_unhovered() -> void:
	if toggled_corner_index != -2:
		return
	showing_tile_brush_preview = false
	update_tile_brush_preview()

# not assumes square img
func make_transposed_img(from_img: Image) -> Image:
	var copy = Image.create(from_img.get_height(), from_img.get_width(), false, from_img.get_format())
	
	for x in range(from_img.get_width()):
		for y in range(from_img.get_height()):
			copy.set_pixel(y, x, from_img.get_pixel(x, y))
	
	return copy

var alternate_half_shift_v: = false
func make_half_v_shifted_img_odd(from_img: Image, do_wrap: bool) -> Image:
	var half = from_img.get_height()/2.0
	half = floor(half) if alternate_half_shift_v else ceil(half)
	alternate_half_shift_v = not alternate_half_shift_v
	
	return make_v_shifted_img_by(from_img, half, do_wrap)
	
func make_v_shifted_img_by(from_img: Image, amount: int, do_wrap: bool) -> Image:
	var copy = Image.new()
	copy.copy_from(from_img)
	
	var negative = amount < 0
	if negative:
		amount += from_img.get_height()
	
	var size_a = Vector2(from_img.get_width(), from_img.get_height() - amount)
	var size_b = Vector2(from_img.get_width(), amount)
	var offset_a = Vector2(0, size_a.y)
	var offset_b = Vector2(0, size_b.y)
	
	var img_a: Image = from_img
	var img_b: Image = from_img
	if not do_wrap:
		if negative:
			img_a = transparent_img
		else:
			img_b = transparent_img
	copy.blit_rect(img_a, Rect2i(Vector2.ZERO, size_a), offset_b)
	copy.blit_rect(img_b, Rect2i(offset_a, size_b), Vector2.ZERO)
	return copy

var alternate_half_shift_h: = false
func make_half_h_shifted_img_odd(from_img: Image, do_wrap: bool) -> Image:
	var half = from_img.get_width()/2.0
	half = floor(half) if alternate_half_shift_h else ceil(half)
	alternate_half_shift_h = not alternate_half_shift_h
	
	return make_h_shifted_img_by(from_img, half, do_wrap)

func make_h_shifted_img_by(from_img: Image, amount: int, do_wrap: bool) -> Image:
	var copy = Image.new()
	copy.copy_from(from_img)
	
	var negative = amount < 0
	if negative:
		amount += from_img.get_width()
	
	var size_a = Vector2(from_img.get_width() - amount, from_img.get_height())
	var size_b = Vector2(amount, from_img.get_height())
	var offset_a = Vector2(size_a.x, 0)
	var offset_b = Vector2(size_b.x, 0)
	
	var img_a: Image = from_img
	var img_b: Image = from_img
	if not do_wrap:
		if negative:
			img_a = transparent_img
		else:
			img_b = transparent_img
	copy.blit_rect(img_a, Rect2i(Vector2.ZERO, size_a), offset_b)
	copy.blit_rect(img_b, Rect2i(offset_a, size_b), Vector2.ZERO)
	return copy


func make_half_v_shifted_img(from_img: Image, do_wrap: bool) -> Image:
	if from_img.get_height() % 2 == 1:
		return make_half_v_shifted_img_odd(from_img, do_wrap)
	var copy = Image.new()
	copy.copy_from(from_img)
	
	var half_size = Vector2(from_img.get_width(), floor(from_img.get_height()/2.0))
	var half_offset = Vector2(0, half_size.y)
	
	copy.blit_rect(from_img, Rect2i(Vector2.ZERO, half_size), half_offset)
	copy.blit_rect(from_img if do_wrap else transparent_img, Rect2i(half_offset, half_size), Vector2.ZERO)
	
	return copy
func make_half_h_shifted_img(from_img: Image, do_wrap: bool) -> Image:
	if from_img.get_width() % 2 == 1:
		return make_half_h_shifted_img_odd(from_img, do_wrap)
	var copy = Image.new()
	copy.copy_from(from_img)
	
	var half_size = Vector2(floor(from_img.get_width()/2.0), from_img.get_height())
	var half_offset = Vector2(half_size.x, 0)
	
	copy.blit_rect(from_img, Rect2i(Vector2.ZERO, half_size), half_offset)
	copy.blit_rect(from_img if do_wrap else transparent_img, Rect2i(half_offset, half_size), Vector2.ZERO)
	
	return copy

func rotated_ccw(from_img: Image) -> Image:
	var flipped_copy = Image.new()
	flipped_copy.copy_from(from_img)
	flipped_copy.flip_x()
	return make_transposed_img(flipped_copy)
func rotated_cw(from_img: Image) -> Image:
	var flipped_copy = Image.new()
	flipped_copy.copy_from(from_img)
	flipped_copy.flip_y()
	return make_transposed_img(flipped_copy)
	

func _on_PaintButton_pressed():
	undoer.save_current_image("texture", edited_image)
	var src_rect: = Rect2i(Vector2.ZERO, tile_brush_image.get_size())
	var dest = local_tile_picker.get_picked_offset()
	if not Utility.is_holding_alt_mode():
		edited_image.blit_rect(transparent_img, whole_brush, dest)
	edited_image.blend_rect(tile_brush_image, src_rect, dest)
	repaint()
	
func _on_EraseButton_pressed():
	undoer.save_current_image("texture", edited_image)
	var dest = local_tile_picker.get_picked_offset()
	edited_image.blit_rect(transparent_img, whole_brush, dest)
	repaint()

func _on_PickFromEditedButton_pressed():
	set_picked_brush_from_tile_picker()

func set_picked_brush_from_tile_picker() -> void:
	picked_brush_tex.atlas = edited_texture
	picked_brush_tex.region = local_tile_picker.get_picked_region()
	update_picked_brush()

func _on_PickTileFromEditedButton_pressed():
	set_tile_brush_from_tile_picker()

func on_tile_picker_confirmed() -> void:
	if Utility.is_holding_alt_mode():
		set_picked_brush_from_tile_picker()
	else:
		set_tile_brush_from_tile_picker()

func set_tile_brush_from_tile_picker() -> void:
	var tex = AtlasTexture.new()
	tex.atlas = edited_texture
	tex.region.size = Vector2(tile_brush_image.get_size())
	tex.region.position = local_tile_picker.get_picked_offset()
	save_tile_brush_undo_state()
	tile_brush_image = tex.get_image()
	update_tile_brush_preview()

func _on_TileToBrushButton_pressed():
	picked_brush_tex.atlas = ImageTexture.create_from_image(tile_brush_image)
	picked_brush_tex.region.position = Vector2.ZERO
	picked_brush_tex.region.size = Vector2(tile_brush_image.get_size())
	update_picked_brush()

func _on_CCWButton_pressed():
	save_tile_brush_undo_state(true)
	tile_brush_image = rotated_ccw(tile_brush_image)
	update_tile_brush_preview()
func _on_CWButton_pressed():
	save_tile_brush_undo_state(true)
	tile_brush_image = rotated_cw(tile_brush_image)
	update_tile_brush_preview()
func _on_HFlipButton_pressed():
	save_tile_brush_undo_state(true)
	tile_brush_image.flip_x()
	tile_brush_image.copy_from(tile_brush_image)
	update_tile_brush_preview()
func _on_VFlipButton_pressed():
	save_tile_brush_undo_state(true)
	tile_brush_image.flip_y()
	tile_brush_image.copy_from(tile_brush_image)
	update_tile_brush_preview()


func _on_ShiftDownButton_pressed():
	save_tile_brush_undo_state()
	tile_brush_image = make_half_v_shifted_img(tile_brush_image, brush_wrap)
	update_tile_brush_preview()
func _on_ShiftRightButton_pressed():
	save_tile_brush_undo_state()
	tile_brush_image = make_half_h_shifted_img(tile_brush_image, brush_wrap)
	update_tile_brush_preview()

func rotate_brush_ccw() -> void:
	picked_brush_image = rotated_ccw(picked_brush_image)
	update_picked_colored_brush()
func rotate_brush_cw() -> void:
	picked_brush_image = rotated_cw(picked_brush_image)
	update_picked_colored_brush()
func shift_brush_right() -> void:
	picked_brush_image = make_half_h_shifted_img(picked_brush_image, true)
	update_picked_colored_brush()
func flip_brush_horizontal() -> void:
	picked_brush_image.flip_x()
	update_picked_colored_brush()

func save_tile_brush_undo_state(is_transform: bool = false) -> void:
	if not is_transform or not last_tile_brush_change_was_transform:
		undoer.save_current_image("tile_brush", tile_brush_image)
	last_tile_brush_change_was_transform = is_transform

func _update_picked_brush_tex_from_image() -> void:
	var image_tex = ImageTexture.create_from_image(picked_brush_image)
	picked_brush_tex.atlas = image_tex
	picked_brush_tex.region.position = Vector2.ZERO
	picked_brush_tex.region.size = Vector2(picked_brush_image.get_size())

#func brush_picked(dialog) -> void:
	#picked_texture_id = dialog.get_selected_texture()
	#picked_texture_sub_index = dialog.get_selected_sub_index()
	
	#picked_brush_tex.atlas = TextureManager.get_texture(picked_texture_id)
	#picked_brush_tex.region = TextureManager.get_index_rect(picked_texture_id, picked_texture_sub_index)
	#picked_brush_tex.region.position = TextureManager.get_index_offset(picked_texture_id, picked_texture_sub_index)
	#update_picked_brush()

func brush_picked_raw(texture: Texture2D, texture_rect: Rect2, picked_index: int, texture_info: Dictionary) -> void:
	picked_brush_tex.atlas = texture
	picked_brush_tex.region = texture_rect
	picked_texture_sub_index = picked_index
	picked_brush_texture_info = texture_info
	update_picked_brush()
	

func _on_PickBrushButton_pressed():
	if not picked_brush_texture_info:
		var starting_texture_info: = TextureManager.get_loaded_texture_info(starting_brush_id)
		picked_brush_texture_info = {
			"texture_name": starting_texture_info["name"],
			"is_builtin": starting_texture_info["is_builtin"],
			"is_shared": starting_texture_info["is_shared"],
		}
	var dialog: = texture_dialog.instantiate() as BetterTextureDialog

	#dialog.setup(picked_texture_id, picked_texture_sub_index)
	dialog.setup_raw(
		picked_brush_texture_info["texture_name"],
		picked_brush_texture_info["is_builtin"],
		picked_brush_texture_info["is_shared"],
		picked_texture_sub_index
	)
	
	#dialog.confirmed.connect(brush_picked.bind(dialog))
	dialog.picked_raw_texture.connect(brush_picked_raw)
	add_child(dialog)
	dialog.popup_centered()

func _on_BrushSlideH_mouse_pressed():
	show_tile_brush_crosshair(true)
	save_tile_brush_undo_state()
	if not brush_wrap:
		temp_tile_brush_image = Image.new()
		temp_tile_brush_image.copy_from(tile_brush_image)
func _on_BrushSlideH_mouse_released():
	show_tile_brush_crosshair(false)
	brush_sliding_h = floor(tile_brush_image.get_width()/2.0)
	var slider: = find_child("BrushSlideH") as HSlider
	if slider.value == brush_sliding_h:
		# no change was made
		undoer.drop_undo("tile_brush")
	slider.value = brush_sliding_h
func _on_BrushSlideH_value_changed(value):
	var diff = value - brush_sliding_h
	if diff == 0:
		return
	brush_sliding_h = value
	
	var from_img = tile_brush_image
	if not brush_wrap:
		# copying from saved copy so the diff is relative to the center not the last value
		diff = value - floor(tile_brush_image.get_width()/2.0)
		from_img = temp_tile_brush_image
	
	tile_brush_image = make_h_shifted_img_by(from_img, diff, brush_wrap)
	update_tile_brush_preview()

func _on_BrushSlideV_mouse_pressed():
	show_tile_brush_crosshair(true)
	save_tile_brush_undo_state()
	if not brush_wrap:
		temp_tile_brush_image = Image.new()
		temp_tile_brush_image.copy_from(tile_brush_image)
func _on_BrushSlideV_mouse_released():
	show_tile_brush_crosshair(false)
	brush_sliding_v = ceil(tile_brush_image.get_height()/2.0)
	var alt = floor(tile_brush_image.get_height()/2.0)
	var slider: = find_child("BrushSlideV") as VSlider
	if slider.value == alt:
		# no change was made
		undoer.drop_undo("tile_brush")
	slider.value = alt
func _on_BrushSlideV_value_changed(value):
	# vertical slider has 0 at the bottom
	value = tile_brush_image.get_height() - value
	var diff = value - brush_sliding_v
	if diff == 0:
		return
	brush_sliding_v = value
	
	var from_img = tile_brush_image
	if not brush_wrap:
		# copying from saved copy so the diff is relative to the center not the last value
		diff = value - floor(tile_brush_image.get_height()/2.0)
		from_img = temp_tile_brush_image
	
	tile_brush_image = make_v_shifted_img_by(from_img, diff, brush_wrap)
	update_tile_brush_preview()
	

func _on_BrushWrap_toggled(button_pressed):
	brush_wrap = button_pressed


func _on_UndoBrushButton_pressed():
	if undoer.has_undo("tile_brush"):
		tile_brush_image = undoer.undo("tile_brush", tile_brush_image)
		update_tile_brush_preview()
func _on_RedoBrushButton2_pressed():
	if undoer.has_redo("tile_brush"):
		tile_brush_image = undoer.redo("tile_brush", tile_brush_image)
		update_tile_brush_preview()

func _on_UndoTextureButton_pressed():
	if undoer.has_undo("texture"):
		edited_image = undoer.undo("texture", edited_image)
		repaint()
func _on_RedoTextureButton_pressed():
	if undoer.has_redo("texture"):
		edited_image = undoer.redo("texture", edited_image)
		repaint()



func _on_DiscardButton_pressed():
	hide()


func _on_SaveAsFileButton_pressed():
	if OS.has_feature("web"):
		return
	if not save_as_name:
		set_filename(Utility.random_animal() + ".png")
	var default_dest_dir: = FilesManager.get_shared_images_dir()
	if edited_is_bundled:
		default_dest_dir = FilesManager.get_game_images_dir(GameManager.get_identified_game_name())
	FileDialog.set_favorite_list(PackedStringArray([
		FilesManager.get_shared_images_dir(),
		FilesManager.get_game_images_dir(GameManager.get_identified_game_name()),
	]))
	$SaveAsDialog.current_path = default_dest_dir.path_join(save_as_name)
	$SaveAsDialog.popup_file_dialog()
	$SaveAsDialog.deselect_all()


func _on_SaveAsDialog_file_selected(path: String):
	var base_path: = path.get_base_dir()
	var saved_to_shared: = false
	var saved_to_bundled: = false
	if base_path == FilesManager.get_shared_images_dir():
		saved_to_shared = true
		FilesManager.save_local_image(edited_image, path.get_file(), "")
	elif base_path == FilesManager.get_game_images_dir(GameManager.get_identified_game_name()):
		saved_to_bundled = true
		FilesManager.save_local_image(edited_image, path.get_file(), GameManager.get_identified_game_name())
	else:
		local_toaster.show_toast_message("Please save to shared or bundled images directory")
		return
	local_toaster.show_toast_message("Saved Image")
	set_filename(path.get_file())
	if saved_to_shared:
		FilesManager.update_local_image_metadata(save_as_name, image_meta, "")
		edited_is_bundled = false
	elif saved_to_bundled:
		var to_game_name: = GameManager.get_identified_game_name()
		FilesManager.update_local_image_metadata(save_as_name, image_meta, to_game_name)
		edited_is_bundled = true


func _on_BrushColorPicker_color_changed(color):
	brush_color = color
	update_picked_colored_brush()


func _on_SaveFileButton_pressed():
	if save_as_name == "":
		return
	var to_game_name: = GameManager.get_identified_game_name() if edited_is_bundled else ""
	FilesManager.save_local_image(edited_image, save_as_name, to_game_name)
	FilesManager.update_local_image_metadata(save_as_name, image_meta, to_game_name)
	local_toaster.show_toast_message("Saved Image")
	

func get_corner_from_button(corner_button: ButtonContainer) -> Rect2i:
	if corner_button.name.to_lower().begins_with("All"):
		return whole_brush
	var corner_val: = corner_button.name.to_lower().substr(0, 2)
	if not corner_val in ["tl", "tr", "bl", "br"]:
		return whole_brush
	return get(corner_val + "_corner") as Rect2i

func _on_CornerButtonHover(corner_button: ButtonContainer):
	show_tile_brush_crosshair(true)
	var corner: = get_corner_from_button(corner_button)
	_on_paint_corner_hovered(corner)
func _on_CornerButtonUnHover():
	show_tile_brush_crosshair(false)
	_on_paint_corner_unhovered()

func show_tile_brush_crosshair(show_crosshair: bool) -> void:
	tile_brush_canvas.get_node("Crosshair").visible = show_crosshair
	



func _on_vis_changed():
	if not visible:
		hidden.emit()


var click_paint_holding_click: bool = false
var click_paint_last_pos: Vector2 = Vector2.ZERO
var click_paint_last_was_in_bounds: bool = false
func start_click_paint(at_pos: Vector2) -> void:
	save_tile_brush_undo_state()
	click_paint_holding_click = true
	click_paint_last_pos = at_pos
	click_paint_last_was_in_bounds = true

func set_primary_color(color: Color) -> void:
	brush_color = color
	brush_color_picker.color = color
	update_picked_colored_brush()

func _on_brush_view_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MASK_LEFT:
		if click_paint_holding_click and not event.is_pressed():
			click_paint_holding_click = false
		if event.is_pressed():
			var at_pixel_pos: Vector2 = event.position / tile_brush_canvas.size * Vector2(tile_brush_image.get_size())
			var clip_rect: = Rect2i(Vector2i.ZERO, tile_brush_image.get_size())
			if clip_rect.has_point(at_pixel_pos.floor()):
				if Utility.is_holding_alt_mode():
					var picked_color: = tile_brush_image.get_pixelv(at_pixel_pos.floor())
					set_primary_color(picked_color)
				else:
					if toggled_corner_index == -2:
						start_click_paint(at_pixel_pos)
						_single_pixel_paint_mode(tile_brush_image, at_pixel_pos.floor())
						update_tile_brush_preview()
					else:
						paint_positioned_corner_at_pos(at_pixel_pos)
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MASK_RIGHT:
		if event.is_pressed() and toggled_corner_index == -2 and not click_paint_holding_click:
			var at_pixel_pos: Vector2 = event.position / tile_brush_canvas.size * Vector2(tile_brush_image.get_size())
			save_tile_brush_undo_state()
			flood_fill_paint_mode(tile_brush_image, at_pixel_pos.floor())
			update_tile_brush_preview()
	
	if event is InputEventMouseMotion:
		var cur_pos: Vector2 = event.position / tile_brush_canvas.size * Vector2(tile_brush_image.get_size())
		var set_cross_cursor: = false
		if click_paint_holding_click:
			var prev_pos: = click_paint_last_pos
			click_paint_last_pos = cur_pos

			if not Rect2(Vector2.ZERO, tile_brush_image.get_size()).has_point(cur_pos):
				click_paint_last_was_in_bounds = false
				return

			if click_paint_last_was_in_bounds:
				for pixel_pos in bresenham_line(prev_pos, cur_pos):
					_single_pixel_paint_mode(tile_brush_image, pixel_pos)
			else:
				_single_pixel_paint_mode(tile_brush_image, cur_pos.floor())
			update_tile_brush_preview()
			
			click_paint_last_was_in_bounds = true
		elif Utility.is_holding_alt_mode():
			set_cross_cursor = true
			update_tile_brush_preview()
		elif toggled_corner_index != -2:
			preview_positioned_corner_at_pos(cur_pos)

		if set_cross_cursor:
			tile_canvas.mouse_default_cursor_shape = Control.CURSOR_CROSS
		else:
			tile_canvas.mouse_default_cursor_shape = Control.CURSOR_ARROW

func _on_brush_view_mouse_exited() -> void:
	if showing_tile_brush_preview:
		showing_tile_brush_preview = false
		update_tile_brush_preview()
	
	tile_canvas.mouse_default_cursor_shape = Control.CURSOR_ARROW

func bresenham_line(start_pos: Vector2, end_pos: Vector2) -> Array[Vector2i]:
	var start_pixel_pos: Vector2i = Vector2i(start_pos.floor())
	var end_pixel_pos: Vector2i = Vector2i(end_pos.floor())
	if start_pixel_pos == end_pixel_pos or (start_pixel_pos - end_pixel_pos).length() < 1.5:
		return [end_pixel_pos]
	var rounding_delta: Vector2 = Vector2(start_pixel_pos) + Vector2.ONE * 0.5 - start_pos

	var delta: Vector2 = end_pos - start_pos
	var long_basis: = Vector2i(Utility.long_basis(delta))
	var short_basis: = Vector2i(Utility.short_basis(delta))
	var long_axis: int = delta.abs().max_axis_index()

	var step_delta: float = delta[1 - long_axis] / delta[long_axis]
	var start_offs: float = clampf(rounding_delta[long_axis] * step_delta + rounding_delta[1 - long_axis], -.5, .5)
	
	var line: Array[Vector2i] = []
	for i in (end_pixel_pos - start_pixel_pos).abs()[long_axis] + 1:
		var short_length: int = floori(start_offs + i * absf(step_delta))
		line.append(start_pixel_pos + long_basis * i + short_basis * short_length)
	return line
