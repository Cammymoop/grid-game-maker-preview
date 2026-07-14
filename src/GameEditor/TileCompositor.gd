extends Window

signal hidden

const Toaster = preload("res://src/Singletons/global_toaster.gd")

var texture_dialog = preload("res://Scenes/GameEditor/BetterTextureDialog.tscn")

@onready var local_tile_picker = find_child("TilePickerLocal")
@export var loaded_texture: Texture2D
@export var make_tex_with_size: Vector2

@export var title_label: Label

@export var local_toaster: Toaster

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

@onready var tile_brush_canvas: TextureRect = find_child("BrushView")
const TBC_MAX_WIDTH: = 128
const TBC_MAX_HEIGHT: = 128

const PICKED_BRUSH_MAX: Vector2 = Vector2(70, 70)

# targeted size for local tile picker
var ltp_target_height: = 240
var ltp_margin: = 120

@export var brush_wrap: = true

var picked_texture_index = 0
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

func set_texture(tex: Texture2D) -> void:
	loaded_texture = tex

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
	
	
	var tile_size = image_meta['tile_size']
	set_tile_brush_size(tile_size)
	
	if loaded_texture:
		edited_image = loaded_texture.get_image()
	else:
		edited_image = Image.create(make_tex_with_size.x, make_tex_with_size.y, true, Image.FORMAT_RGBA8)
	
	edited_texture = ImageTexture.create_from_image(edited_image)
	
	local_tile_picker.set_raw_texture(edited_texture, image_meta)
	
	rescale_tile_picker()
	
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

func _shortcut_input(event: InputEvent) -> void:
	if Utility.event_is_menu_back_just_pressed(event):
		hide()

func on_scale() -> void:
	rescale_tile_picker()

func rescale_tile_picker() -> void:
	var tp_scale = Utility.max_integer_scale_in(edited_image.get_size(), Vector2(size.x - ltp_margin, ltp_target_height))
	if tp_scale == 0:
		tp_scale = 1
	local_tile_picker.set_view_scale(tp_scale)
#	local_tile_picker.rect_min_size = edited_image.get_size() * tp_scale
#	local_tile_picker.rect_size = local_tile_picker.rect_min_size


func set_tile_brush_size(tile_size: Vector2) -> void:
	whole_brush = Rect2i(Vector2.ZERO, tile_size)
	corner_size = Vector2(ceil(tile_size.x/2), ceil(tile_size.y/2))
	tl_corner = Rect2i(Vector2.ZERO, corner_size)
	var odd_x = int(tile_size.x) % 2
	var odd_y = int(tile_size.y) % 2
	tr_corner = Rect2i(Vector2(corner_size.x - odd_x, 0), corner_size)
	bl_corner = Rect2i(Vector2(0, corner_size.y - odd_y), corner_size)
	br_corner = Rect2i(Vector2(corner_size.x - odd_x, corner_size.y - odd_y), corner_size)
	
	tile_brush_image = Image.create(tile_size.x, tile_size.y, false, Image.FORMAT_RGBA8)
	tile_brush_image.fill(Color.TRANSPARENT)
	transparent_img = Image.create(tile_size.x, tile_size.y, false, Image.FORMAT_RGBA8)
	transparent_img.fill(Color.TRANSPARENT)
	
	var preview_scale = Utility.max_integer_scale_in(tile_size, Vector2(TBC_MAX_WIDTH, TBC_MAX_HEIGHT))
	print(tile_size * preview_scale)
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
	brush_color_mode = new_selected.text.to_lower()
	update_picked_colored_brush()

func update_picked_brush() -> void:
	picked_brush_image = picked_brush_tex.get_image()
	update_picked_colored_brush()

func update_picked_colored_brush() -> void:
	if not picked_colored_brush_image:
		picked_colored_brush_image = Image.new()
	picked_colored_brush_image.copy_from(picked_brush_image)
	color_brush()
	picked_colored_preview = ImageTexture.create_from_image(picked_colored_brush_image) #,0
	
	var picked_size = picked_brush_image.get_size()
	for tex_rect in [find_child("BrushColorPreview"), find_child("PickBrushButton").find_child("Icon")]:
		tex_rect.texture = picked_colored_preview
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		
		var preview_scale = Utility.max_integer_scale_in(picked_size, PICKED_BRUSH_MAX)
		tex_rect.custom_minimum_size = picked_size * preview_scale
		tex_rect.size = picked_size * preview_scale
	
	var crosshair = find_child("PickedCrosshair")
	picked_brush_offset = ((picked_size - tile_brush_image.get_size()) / 2.0).floor()
	crosshair.set_my_size(picked_size)
	crosshair.set_size_offset(tile_brush_image.get_size(), picked_brush_offset)


func color_brush() -> void:
	if brush_color_mode == "source":
		return
	
	var img = picked_colored_brush_image
	
	var mode_flat: = brush_color_mode == "flat"
	var mode_colorize: = brush_color_mode == "colorize"
	
	for x in range(img.get_width()):
		for y in range(img.get_height()):
			var pixel_color = img.get_pixel(x, y)
			if mode_flat:
				var flat_colored: = brush_color
				flat_colored.a *= pixel_color.a
				img.set_pixel(x, y, flat_colored)
			elif mode_colorize:
				var lightness = pixel_color.ok_hsl_l * brush_color.ok_hsl_l
				var alpha = pixel_color.a * brush_color.a
				img.set_pixel(x, y, Color.from_ok_hsl(brush_color.ok_hsl_h, brush_color.ok_hsl_s, lightness, alpha))
		

func update_tile_brush_preview() -> void:
	var img = tile_brush_image if not showing_tile_brush_preview else tile_brush_preview_image
	find_child("BrushView").texture = ImageTexture.create_from_image(img)

func repaint() -> void:
	edited_texture = ImageTexture.create_from_image(edited_image)
	local_tile_picker.set_raw_texture(edited_texture, image_meta)

func paint_corner_to_tile_brush(corner: Rect2i) -> void:
	undoer.save_current_image("tile_brush", tile_brush_image)
	do_corner_paint(corner, tile_brush_image)
	showing_tile_brush_preview = false
	
	update_tile_brush_preview()

func do_corner_paint(corner: Rect2i, dest_image: Image) -> void:
	var src_rect: = corner
	src_rect.position += Vector2i(picked_brush_offset)
	if brush_creator_mode == "erase":
		dest_image.blit_rect(transparent_img, src_rect, corner.position)
	elif brush_creator_mode == "replace":
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

func alpha_subtract(from_image: Image, to_image, src_rect: Rect2i, dest_offset: Vector2) -> void:
	var w = src_rect.size.x
	var h = src_rect.size.y
	var src_offset = src_rect.position
	
	for x in range(w):
		for y in range(h):
			var alpha: = from_image.get_pixel(src_offset.x + x, src_offset.y + y).a8
			var cur_pixel: Color = to_image.get_pixel(dest_offset.x + x, dest_offset.y + y)
			cur_pixel.a8 = int(max(0, cur_pixel.a8 - alpha))
			to_image.set_pixel(dest_offset.x + x, dest_offset.y + y, cur_pixel)

func alpha_min(from_image: Image, to_image: Image, src_rect: Rect2i, dest_offset: Vector2) -> void:
	var w = src_rect.size.x
	var h = src_rect.size.y
	var src_offset = src_rect.position
	
	for x in range(w):
		for y in range(h):
			var brush_alpha: = from_image.get_pixel(src_offset.x + x, src_offset.y + y).a8
			var cur_pixel: Color = to_image.get_pixel(dest_offset.x + x, dest_offset.y + y)
			cur_pixel.a8 = int(min(cur_pixel.a8, brush_alpha))
			to_image.set_pixel(dest_offset.x + x, dest_offset.y + y, cur_pixel)

# paints the specified region onto to_image, while leaving the alpha channel unmodified
func stamp_blit(from_image: Image, to_image: Image, src_rect: Rect2i, dest_offset: Vector2) -> void:
	var w = src_rect.size.x
	var h = src_rect.size.y
	var src_offset = src_rect.position
	
	for x in range(w):
		for y in range(h):
			var color: = from_image.get_pixel(src_offset.x + x, src_offset.y + y)
			if color.a8 < 1:
				# ignore completely transparent_img pixels from source
				continue
			var dest_color: = to_image.get_pixel(dest_offset.x + x, dest_offset.y + y)
			var final_color: = dest_color.lerp(color, color.a)
			final_color.a = dest_color.a
			to_image.set_pixel(dest_offset.x + x, dest_offset.y + y, final_color)

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

func _on_paint_corner_hovered(corner: Rect2i) -> void:
	tile_brush_preview_image = tile_brush_image.duplicate()
	do_corner_paint(corner, tile_brush_preview_image)
	showing_tile_brush_preview = true
	update_tile_brush_preview()

func _on_paint_corner_unhovered() -> void:
	showing_tile_brush_preview = false
	update_tile_brush_preview()

# not assumes square img
func make_transposed_img(from_img: Image) -> Image:
	var copy = Image.new()
	copy.copy_from(from_img)
	
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
	var copy = Image.new()
	copy.copy_from(from_img)
	copy.flip_x()
	return make_transposed_img(copy)
func rotated_cw(from_img: Image) -> Image:
	var copy = Image.new()
	copy.copy_from(from_img)
	copy.flip_y()
	return make_transposed_img(copy)
	

func _on_PaintButton_pressed():
	undoer.save_current_image("texture", edited_image)
	var src_rect: = Rect2i(Vector2.ZERO, tile_brush_image.get_size())
	var dest = local_tile_picker.get_picked_offset()
	edited_image.blend_rect(tile_brush_image, src_rect, dest)
	repaint()
	
func _on_EraseButton_pressed():
	undoer.save_current_image("texture", edited_image)
	var dest = local_tile_picker.get_picked_offset()
	edited_image.blit_rect(transparent_img, whole_brush, dest)
	repaint()

func _on_PickFromEditedButton_pressed():
	picked_brush_tex.atlas = edited_texture
	picked_brush_tex.region = local_tile_picker.get_picked_region()
	update_picked_brush()

func _on_PickTileFromEditedButton_pressed():
	var tex = AtlasTexture.new()
	tex.atlas = edited_texture
	tex.region.size = Vector2(tile_brush_image.get_size())
	tex.region.position = local_tile_picker.get_picked_offset()
	undoer.save_current_image("tile_brush", tile_brush_image)
	tile_brush_image = tex.get_image()
	update_tile_brush_preview()

func _on_TileToBrushButton_pressed():
	picked_brush_tex.atlas = ImageTexture.create_from_image(tile_brush_image)
	picked_brush_tex.region.position = Vector2.ZERO
	update_picked_brush()

func _on_CCWButton_pressed():
	tile_brush_image = rotated_ccw(tile_brush_image)
	update_tile_brush_preview()
func _on_CWButton_pressed():
	tile_brush_image = rotated_cw(tile_brush_image)
	update_tile_brush_preview()
func _on_HFlipButton_pressed():
	tile_brush_image.flip_x()
	tile_brush_image.copy_from(tile_brush_image)
	update_tile_brush_preview()
func _on_VFlipButton_pressed():
	tile_brush_image.flip_y()
	tile_brush_image.copy_from(tile_brush_image)
	update_tile_brush_preview()


func _on_ShiftDownButton_pressed():
	if not brush_wrap:
		undoer.save_current_image("tile_brush", tile_brush_image)
	tile_brush_image = make_half_v_shifted_img(tile_brush_image, brush_wrap)
	update_tile_brush_preview()
func _on_ShiftRightButton_pressed():
	if not brush_wrap:
		undoer.save_current_image("tile_brush", tile_brush_image)
	tile_brush_image = make_half_h_shifted_img(tile_brush_image, brush_wrap)
	update_tile_brush_preview()

func brush_picked(dialog) -> void:
	picked_texture_index = dialog.get_selected_texture()
	picked_texture_sub_index = dialog.get_selected_sub_index()
	
	picked_brush_tex.atlas = TextureManager.get_texture(picked_texture_index)
	picked_brush_tex.region = TextureManager.get_index_rect(picked_texture_index, picked_texture_sub_index)
	#picked_brush_tex.region.position = TextureManager.get_index_offset(picked_texture_index, picked_texture_sub_index)
	update_picked_brush()
	

func _on_PickBrushButton_pressed():
	var dialog = texture_dialog.instantiate()
	if not TextureManager.has_texture_id(picked_texture_index):
		picked_texture_index = TextureManager.get_fallback_texture_id()
	dialog.setup(picked_texture_index, picked_texture_sub_index)
	
	dialog.connect("confirmed", Callable(self, "brush_picked").bind(dialog))
	add_child(dialog)
	dialog.popup_centered()

func _on_BrushSlideH_mouse_pressed():
	show_tile_brush_crosshair(true)
	if not brush_wrap:
		undoer.save_current_image("tile_brush", tile_brush_image)
		temp_tile_brush_image = Image.new()
		temp_tile_brush_image.copy_from(tile_brush_image)
func _on_BrushSlideH_mouse_released():
	show_tile_brush_crosshair(false)
	brush_sliding_h = floor(tile_brush_image.get_width()/2.0)
	find_child("BrushSlideH").value = brush_sliding_h
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
	if not brush_wrap:
		undoer.save_current_image("tile_brush", tile_brush_image)
		temp_tile_brush_image = Image.new()
		temp_tile_brush_image.copy_from(tile_brush_image)
func _on_BrushSlideV_mouse_released():
	show_tile_brush_crosshair(false)
	brush_sliding_v = ceil(tile_brush_image.get_height()/2.0)
	var alt = floor(tile_brush_image.get_height()/2.0)
	find_child("BrushSlideV").value = alt
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

func _on_margin_container_resized() -> void:
	var min_content_size = get_child(0).get_minimum_size()
	if size.x < min_content_size.x:
		size.x = min_content_size.x
	if size.y < min_content_size.y:
		size.y = min_content_size.y


var click_paint_holding_click: bool = false
var click_paint_last_pos: Vector2 = Vector2.ZERO
var click_paint_last_was_in_bounds: bool = false
func start_click_paint() -> void:
	undoer.save_current_image("tile_brush", tile_brush_image)
	click_paint_holding_click = true
	click_paint_last_was_in_bounds = false

func _on_brush_view_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MASK_LEFT:
		if click_paint_holding_click and not event.is_pressed():
			click_paint_holding_click = false
		if event.is_pressed():
			start_click_paint()
	
	if click_paint_holding_click and event is InputEventMouseMotion:
		var cur_pos: Vector2 = (event.position / tile_brush_canvas.size) * Vector2(tile_brush_image.get_size())
		var prev_pos: = click_paint_last_pos
		click_paint_last_pos = cur_pos

		if not Rect2(Vector2.ZERO, tile_brush_image.get_size()).has_point(cur_pos):
			click_paint_last_was_in_bounds = false
			return

		if click_paint_last_was_in_bounds:
			for pixel_pos in bresenham_line(prev_pos, cur_pos):
				tile_brush_image.set_pixelv(pixel_pos, brush_color)
		else:
			tile_brush_image.set_pixelv(cur_pos.floor(), brush_color)
		update_tile_brush_preview()
		
		click_paint_last_was_in_bounds = true

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