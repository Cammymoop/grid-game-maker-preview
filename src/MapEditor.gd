extends Node2D

signal lost_input_priority
signal request_grab_gui_focus

const EntityInstanceEditor = preload("res://Scenes/GameEditor/entity_instance_editor.gd")
const EditorCam = preload("res://src/EditorCam.gd")

const edited_entity_indicator_icon: Texture2D = preload("res://assets/img/button_icons/star.png")

@export var do_autosave: = true

@export var camera_move_speed: = 700

@export var extend_camera_limits_by_tiles: int = 4

@export var ui_layer: CanvasLayer
@export var ui_root_control: Control
@export var entity_instance_editor: EntityInstanceEditor

@export var cursor_star: Node2D

var edit_mode: = false

var cur_ent_i: int = 0
var current_entity_index: int = -1
var current_entity_facing: int = 0

var has_copied_properties: = false
var entity_properties_copied: = {}

var cur_tile_i: int = 0
var current_tile_index: int = -1 
var current_tile_facing: int = 0

var all_tiles: = []
var all_entities: = []

var input_repeat_timers: Array[RepeatDelayTimer] = []

@onready var editor_cam: EditorCam = get_node("EditorCam")

@onready var cursor = get_node("Cursor")
@onready var preview = get_node("Cursor/TileEntityPreview")

@onready var edited_entity_indicators: Node2D = find_child("EditedEntityIndicators")

@onready var cursor_mode_text = find_child("CursorModeText")
@onready var cursor_mode_text_animator = cursor_mode_text.get_node("AnimationPlayer")

@onready var item_name_text = find_child("ItemNameText")
@onready var item_name_text_animator = item_name_text.get_node("AnimationPlayer")

var default_cursor_tex: = preload("res://assets/img/cursor.png")
var entity_cursor_tex: = preload("res://assets/img/cursor_entity.png")
var tile_cursor_tex: = preload("res://assets/img/cursor_tile.png")
var delete_cursor_tex: = preload("res://assets/img/cursor_delete.png")

var cursor_mode: = "none"

var delete_held_on_entity: = false

var cursor_tile_pos: = Vector2i(0, 0)

var camera_scroll_vector: = Vector2(0, 0)

var has_edited_something: = false

var _input_priority: = false
var _last_tile_entity_mode: = "tile"

var _last_picked_entity: BaseEntity = null
var _cursor_moved_from_directional_input: = false

var _edited_entitys_indicators: Dictionary[int, Sprite2D] = {}

func _ready() -> void:

	editor_cam.edge_limit_tile_count = extend_camera_limits_by_tiles
	editor_cam.update_bounds()

	visibility_changed.connect(on_visibility_changed)
	var cursor_move_timer: = Utility.create_auto_repeat_delay_timer(self, 0.45, -1, is_holding_cursor_move, on_cursor_move_activated)
	cursor_move_timer.set_check_changed_callable(get_cursor_hold_vector)
	lost_input_priority.connect(cursor_move_timer.release)
	
	entity_instance_editor.closing.connect(entity_instance_editor_closed)
	entity_instance_editor.entity_props_edited.connect(on_entity_props_edited)
	
	GameManager.level_state_loaded.connect(on_level_state_loaded)

	await get_tree().process_frame
	var pause_menu: Control = Utility.get_pause_menu()
	if pause_menu:
		pause_menu.pause_menu_closed.connect(pause_menu_closed)

func _physics_process(delta: float) -> void:
	if edit_mode and not is_other_paused():
		if not EntityManager.can_process():
			EntityManager.paused_visual_process(delta)

func on_level_state_loaded() -> void:
	if edit_mode:
		_refresh_edited_entity_indicators()

func is_holding_cursor_move() -> bool:
	if not edit_mode or not _input_priority:
		return false
	return Utility.input_vector_by_prefix("editor_cursor").length_squared() > 0.01

func get_cursor_hold_vector() -> Vector2:
	var input_vector: = Utility.input_vector_by_prefix("editor_cursor")
	return input_vector.snapped(Vector2.ONE)

func on_cursor_move_activated() -> void:
	_cursor_moved_from_directional_input = true
	var move_vec: = Utility.input_vector_by_prefix("editor_cursor")
	move_cursor(cursor_tile_pos + Vector2i(move_vec.snapped(Vector2.ONE)))

func switch_edit_mode(edit_enabled: bool, do_save_state: bool = true) -> void:
	edit_mode = edit_enabled
	visible = edit_enabled
	process_mode = PROCESS_MODE_ALWAYS if edit_enabled else PROCESS_MODE_DISABLED

	GameManager.set_pause("map_editor", edit_enabled)
	if not edit_enabled:
		on_edit_mode_disabled(do_save_state)
	else:
		on_edit_mode_enabled()
	

func after_edit_mode_switched() -> void:
	EntityManager.switch_entities_preview_mode(edit_mode)
	MapManager.switch_tiles_preview_mode(edit_mode)

func on_edit_mode_disabled(do_save_state: bool) -> void:
	drop_input_priority()
	if entity_instance_editor.visible:
		entity_instance_editor.close_instance_editor()
	#set_cursor_mode("none")
	if do_save_state:
		GameManager.save_edited()
		if do_autosave and has_edited_something:
			_auto_save(GameManager.editor_save)
	#GameManager.position_gameplay_camera(editor_cam.position)
	GameManager.activate_gameplay_camera()
	after_edit_mode_switched()

func on_edit_mode_enabled() -> void:
	set_enable_camera_limits(true)
	if GameManager.queued_level_load:
		GameManager.cancel_queued_level_load()
	has_edited_something = false
	var vp = get_viewport()
	if vp.has_method("rescale"):
		vp.rescale()
	if not GameManager.is_live_edit():
		GameManager.load_edited(false)
		await get_tree().process_frame
		await get_tree().process_frame
	refresh_game_definition()

	var cam_position = GameManager.get_gameplay_camera_position()
	_cursor_moved_from_directional_input = true
	move_cursor(MapManager.world_to_tile_position(cam_position))
	editor_cam.set_position_immediate(cam_position)
	editor_cam.make_current()
	_refresh_edited_entity_indicators()
	after_edit_mode_switched()
	request_grab_gui_focus.emit()

func get_new_edited_entity_indicator() -> Sprite2D:
	var indicator: Sprite2D = Sprite2D.new()
	indicator.texture = edited_entity_indicator_icon
	edited_entity_indicators.add_child(indicator)
	return indicator

func _refresh_edited_entity_indicators() -> void:
	var all_level_entities: = EntityManager.entity_list.duplicate()

	var edited_entities: Array[BaseEntity] = []
	var edited_entity_ids: Array[int] = []
	for e in all_level_entities:
		if e.has_local_data():
			edited_entities.append(e)
			edited_entity_ids.append(e.instance_id)
	
	for e in edited_entities:
		var indicator: Sprite2D
		if not e.instance_id in _edited_entitys_indicators:
			indicator = get_new_edited_entity_indicator()
			_edited_entitys_indicators[e.instance_id] = indicator
		else:
			indicator = _edited_entitys_indicators[e.instance_id]
		indicator.global_position = e.global_position + Vector2.ONE * 4
	
	for e_id in _edited_entitys_indicators.keys():
		if not e_id in edited_entity_ids:
			_edited_entitys_indicators[e_id].queue_free()
			_edited_entitys_indicators.erase(e_id)

func _refresh_entity_is_edited(entity: BaseEntity) -> void:
	var e_id: = entity.instance_id
	if entity.has_local_data():
		var indicator: Sprite2D
		if not e_id in _edited_entitys_indicators:
			indicator = get_new_edited_entity_indicator()
			_edited_entitys_indicators[e_id] = indicator
		else:
			indicator = _edited_entitys_indicators[e_id]
		indicator.global_position = entity.global_position + Vector2.ONE * 4
	elif e_id in _edited_entitys_indicators:
		_edited_entitys_indicators[e_id].queue_free()
		_edited_entitys_indicators.erase(e_id)

func refresh_game_definition() -> void:
	all_entities = EntityManager.get_all_entity_indexes()
	if current_entity_index not in all_entities:
		_set_entity_index_to(-1 if all_entities.size() < 1 else all_entities[0])
	all_tiles = MapManager.get_all_tile_indexes()
	if current_tile_index not in all_tiles:
		_set_tile_index_to(-1 if all_tiles.size() < 1 else all_tiles[0])

func set_as_placing_mode(tile_entity: String) -> void:
	if not is_in_placing_mode():
		set_current_facing(0)
	set_cursor_mode(tile_entity)

func pick_entity(entity: BaseEntity) -> void:
	pick_index("entity", entity.entity_index, entity.facing)
	has_copied_properties = entity.has_any_local_properties()
	if is_alt_mode_active():
		has_copied_properties = false
	if has_copied_properties:
		entity_properties_copied = entity.get_local_properties_dict()
	else:
		entity_properties_copied = {}
	check_show_star()

func pick_index(tile_entity: String, index: int, facing: int = -1) -> void:
	set_as_placing_mode(tile_entity)
	set_current_index_to(index)
	if facing >= 0:
		set_current_facing(facing)

func _set_entity_index_to(index: int) -> void:
	if index == current_entity_index:
		return
	current_entity_index = index
	if has_copied_properties:
		has_copied_properties = false
		entity_properties_copied = {}
		check_show_star()
	if cursor_mode == "entity" and index > -1:
		preview_entity(index)
		show_item_name()

func _set_tile_index_to(index: int) -> void:
	if index == current_tile_index:
		return
	current_tile_index = index
	if cursor_mode == "tile" and index > -1:
		preview_tile(index)
		show_item_name()

func set_current_index_to(index: int) -> void:
	if cursor_mode == "tile":
		_set_tile_index_to(index)
	elif cursor_mode == "entity":
		_set_entity_index_to(index)

func _advance_entity(delta: int) -> void:
	if all_entities.size() < 2:
		return
	var next_list_index: = posmod(all_entities.find(current_entity_index) + delta, all_entities.size())
	_set_entity_index_to(all_entities[next_list_index])

func _advance_tile(delta: int) -> void:
	if all_tiles.size() < 2:
		return
	var next_list_index: = posmod(all_tiles.find(current_tile_index) + delta, all_tiles.size())
	_set_tile_index_to(all_tiles[next_list_index])

func advance_current(delta: int) -> void:
	if cursor_mode == "tile":
		_advance_tile(delta)
	elif cursor_mode == "entity":
		_advance_entity(delta)

func advance_as_placing_mode(tile_entity: String, delta: int) -> void:
	set_as_placing_mode(tile_entity)
	advance_current(delta)

func preview_entity(entity_index):
	if entity_index == -1:
		return
	preview.texture = EntityManager.get_entity_sprite_snapshot(entity_index, true)
	preview.scale = Vector2.ONE * EntityManager.get_entity_sprite_snapshot_scale(entity_index, true, false)
	preview.region_enabled = false

func preview_tile(tile_index):
	if tile_index == -1:
		return
	preview.scale = Vector2.ONE
	preview.texture = MapManager.get_tile_texture(tile_index, true)
	preview.region_enabled = true
	preview.region_rect = MapManager.get_tile_texture_rect(tile_index, true)

func set_cursor_mode(new_mode: String):
	if new_mode != "none":
		cursor_mode_text.text = new_mode.capitalize()
		cursor_mode_text.reset_size()
		if cursor_mode != new_mode:
			cursor_mode_text_animator.play("show_fade")
	delete_held_on_entity = false
	if cursor_mode == new_mode:
		return

	cursor_mode = new_mode

	if is_in_placing_mode():
		_last_tile_entity_mode = new_mode
		preview.visible = true
		show_item_name()
		check_show_star()
	else:
		preview.visible = false

	# default cursor for "none" or unknown mode
	cursor.texture = default_cursor_tex
	if cursor_mode == "entity":
		cursor.texture = entity_cursor_tex
		if current_entity_index > -1:
			preview_entity(current_entity_index)
	else:
		_last_picked_entity = null

	if cursor_mode == "tile":
		cursor.texture = tile_cursor_tex
		if current_tile_index > -1:
			preview_tile(current_tile_index)
	if cursor_mode == "delete":
		cursor.texture = delete_cursor_tex

func check_show_star() -> void:
	if not cursor_mode == "entity":
		cursor_star.hide()
		return
	cursor_star.visible = has_copied_properties

func is_in_placing_mode() -> bool:
	return cursor_mode in ["tile", "entity"]

func get_item_name() -> String:
	if not is_in_placing_mode():
		return ""
	return MapManager.get_tile_name(current_tile_index) if cursor_mode == "tile" else EntityManager.get_entity_name(current_entity_index)

func show_item_name() -> void:
	item_name_text.text = get_item_name()
	item_name_text.reset_size()
	if item_name_text_animator.is_playing():
		item_name_text_animator.stop()
	item_name_text_animator.play("show_fade")

func _primary_action_at_cursor(holding: bool = false) -> void:
	has_edited_something = true
	if cursor_mode == "none":
		set_cursor_mode(_last_tile_entity_mode)
	if cursor_mode == "tile":
		MapManager.replace_tiles_at(cursor_tile_pos, current_tile_index, current_tile_facing)
	elif cursor_mode == "entity":
		var entities_here = get_all_entities_at_tile_pos(cursor_tile_pos)
		# remove existing entities of the same index
		for e in entities_here:
			if e.entity_index == current_entity_index:
				if EntityManager.get_entity_prop_with_default(e, "edit-place-multiple", false):
					continue
				EntityManager.remove_entity(e)
		var new_entity: BaseEntity = EntityManager.create_entity(current_entity_index, cursor_tile_pos, current_entity_facing)
		if has_copied_properties:
			new_entity.set_local_properties_dict(entity_properties_copied)
			_refresh_edited_entity_indicators()
	elif cursor_mode == "delete":
		var force_everything: = holding and not delete_held_on_entity
		var force_only_entities: = holding and delete_held_on_entity
		if not holding:
			if get_all_entities_at_tile_pos(cursor_tile_pos).size() > 0:
				delete_held_on_entity = true
			else:
				delete_held_on_entity = false
		_standard_delete_at_cursor(force_everything, force_only_entities)

func _standard_delete_at_cursor(force_everything: bool = false, force_only_entities: bool = false) -> void:
	var entities_here = get_sorted_entities_at(cursor_tile_pos)
	var deleted_something: = false
	if force_everything or (entities_here.size() < 1 and not force_only_entities):
		# No entities, remove the tile
		var here = MapManager.get_tile_index_at(cursor_tile_pos)
		if here > -1:
			MapManager.erase_tiles_and_effects_at(cursor_tile_pos)
			deleted_something = true

	if entities_here.size() > 0:
		if not is_alt_mode_active():
			entities_here = [entities_here[0]]
		for e in entities_here:
			EntityManager.remove_entity(e)
			deleted_something = true	
	if deleted_something:
		_refresh_edited_entity_indicators()
		$DustParticles.emit_at(MapManager.tile_to_world_position_centered(cursor_tile_pos))

func inspect_at_cursor() -> void:
	var entities_here = get_sorted_entities_at(cursor_tile_pos)
	if entities_here.size() > 0:
		var found_last_picked: int = entities_here.find(_last_picked_entity)
		if found_last_picked == -1:
			found_last_picked = 0
		entity_instance_editor.open_instance_editor(entities_here[found_last_picked])
		var ui_vp_size: Vector2 = Vector2(entity_instance_editor.get_viewport().size)
		var instance_editor_width: float = entity_instance_editor.size.x / ui_vp_size.x
		var disp_width: = get_display_world_size().x
		var offset: = (1 - instance_editor_width) * disp_width - (disp_width / 2.0)
		prints("ui_vp_size: ", ui_vp_size, "inst editor width: ", instance_editor_width, "offset: ", offset)
		set_enable_camera_limits(false)
		scroll_editor_camera_to_pos(MapManager.tile_to_world_position_centered(cursor_tile_pos) + Vector2.RIGHT * offset)
	elif entity_instance_editor and entity_instance_editor.visible:
		entity_instance_editor.close_instance_editor()

func set_enable_camera_limits(is_enabled: bool) -> void:
	editor_cam.set_enable_limits(is_enabled)


func update_input_priority() -> bool:
	if not get_window().has_focus() or get_viewport().gui_get_focus_owner() or is_other_paused():
		drop_input_priority()
	elif entity_instance_editor and entity_instance_editor.is_visible_in_tree():
		drop_input_priority()
	else:
		if not _input_priority:
			prints("gain input priority")
		gain_input_priority()
	return _input_priority

func gain_input_priority() -> void:
	if _input_priority:
		return
	_input_priority = true
	
func drop_input_priority() -> void:
	if not _input_priority:
		return
	_input_priority = false
	lost_input_priority.emit()

func _process(delta: float) -> void:
	update_input_priority()
	if not edit_mode or is_other_paused():
		return
	
	# camera scroll that doesn't interact with GUI can scroll regardless of input priority
	var dedicated_scroll_input: = Utility.input_vector_by_prefix("editor_camera_dedicated")
	_scroll_editor_camera(dedicated_scroll_input * delta * camera_move_speed)

	if _input_priority:
		var scroll_input: = Utility.input_vector_by_prefix("editor_camera")
		_scroll_editor_camera(scroll_input * delta * camera_move_speed)

func scroll_editor_camera_to_pos(world_pos: Vector2) -> void:
	editor_cam.move_to_pos(world_pos)

func _scroll_editor_camera(camera_delta_pos: Vector2) -> void:
	if camera_delta_pos.length_squared() < 0.01:
		return
	editor_cam.do_scroll(camera_delta_pos)
	if not _cursor_moved_from_directional_input:
		process_new_mouse_position()
func update_camera_vector() -> void:
	camera_scroll_vector = Utility.input_vector_by_prefix("editor_camera")

func process_new_mouse_position() -> void:
	var new_mouse_pos: Vector2 = get_viewport().get_scaled_mouse_position()
	new_mouse_pos += editor_cam.get_tl_position()
	new_mouse_pos = new_mouse_pos.round()
	_cursor_moved_from_directional_input = false
	var tile_pos: = MapManager.world_to_tile_position(new_mouse_pos)
	move_cursor(tile_pos)

func move_cursor(new_position: Vector2i) -> void:
	if new_position == cursor_tile_pos:
		return
	var tile_pos_bounds: = get_valid_tile_pos_bounds()
	if _cursor_moved_from_directional_input and not tile_pos_bounds.has_point(new_position):
		new_position = Utility.clamp_point_in_rect2i(new_position, tile_pos_bounds)

	cursor_tile_pos = new_position
	cursor.position = MapManager.tile_to_world_position(cursor_tile_pos)
	if _cursor_moved_from_directional_input:
		if Input.is_action_pressed("editor_non_pointer_primary"):
			_primary_action_at_cursor(true)
		cursor_drag_camera()
	else:
		if Input.is_action_pressed("editor_pointer_primary"):
			_primary_action_at_cursor(true)

func cursor_drag_camera() -> void:
	var cursor_world_pos: = MapManager.tile_to_world_position(cursor_tile_pos)
	#var keep_cursor_within: = 
	var drag_within_rect: = get_reduced_world_view_rect()
	if not drag_within_rect.has_point(cursor_world_pos):
		var delta_to_clamped: = cursor_world_pos - Utility.clamp_point_in_rect2(cursor_world_pos, drag_within_rect)
		_scroll_editor_camera(delta_to_clamped)

func forwarded_gui_input(event: InputEvent) -> void:
	if not edit_mode or GameManager.get_pause("pause_menu"):
		return
	
	#if event is InputEventMouseButton:
		#prints(get_viewport().gui_get_focus_owner())
	
	if event is InputEventMouseMotion:
		process_new_mouse_position()
		return
	
	for next_prev in ["next", "prev"]:
		var direction = 1 if next_prev == "next" else -1
		if Utility.fixed_just_pressed_by_event("editor_" + next_prev + "_either", event, true):
			if not is_in_placing_mode():
				set_cursor_mode(_last_tile_entity_mode)
				set_current_facing(0)
			advance_current(direction)
		for tile_ent in ["tile", "entity"]:
			if Utility.fixed_just_pressed_by_event("editor_" + next_prev + "_" + tile_ent, event, true):
				if cursor_mode != tile_ent:
					set_cursor_mode(tile_ent)
					set_current_facing(0)
				advance_current(direction)
				return
	
	var scroll_up: = Utility.fixed_just_pressed_by_event("scroll_up", event)
	var scroll_down: = Utility.fixed_just_pressed_by_event("scroll_down", event)
	if scroll_up or scroll_down:
		var direction = 1 if scroll_up else -1
		if is_alt_mode_active():
			if cursor_mode == "entity" or cursor_mode == "tile":
				set_current_facing(posmod(get_current_facing() + direction, 4))
		else:
			if not is_in_placing_mode():
				set_cursor_mode(_last_tile_entity_mode)
				set_current_facing(0)
			advance_current(direction)
		return
	
	var rotate_cw: = Utility.fixed_just_pressed_by_event("editor_rotate_cw", event, true)
	var rotate_ccw: = Utility.fixed_just_pressed_by_event("editor_rotate_ccw", event, true)
	if rotate_cw or rotate_ccw:
		if cursor_mode == "entity" or cursor_mode == "tile":
			var direction = 1 if rotate_cw else -1
			set_current_facing(posmod(get_current_facing() + direction, 4))
		return
	
	if Utility.fixed_just_pressed_by_event("editor_non_pointer_primary", event, true):
		_primary_action_at_cursor()
		return
	if Utility.fixed_just_pressed_by_event("editor_pointer_primary", event, true):
		_primary_action_at_cursor()
		return
	
	if Utility.fixed_just_pressed_by_event("editor_pointer_inspect", event, true):
		inspect_at_cursor()
		return
	if Utility.fixed_just_pressed_by_event("editor_non_pointer_secondary", event, true):
		inspect_at_cursor()
		return

	var is_pointer_pick: = Utility.fixed_just_pressed_by_event("editor_pointer_pick", event, true)
	if is_pointer_pick or Utility.fixed_just_pressed_by_event("editor_non_pointer_pick", event, false):
		var entities_here: = get_all_entities_at_tile_pos(cursor_tile_pos)
		if entities_here.size() > 0:
			if cursor_mode != "entity":
				set_cursor_mode("entity")
			entities_here = sort_entities_by_render_order(entities_here)
			var picked_entity: BaseEntity
			if entities_here.size() > 1:
				for i in entities_here.size():
					if entities_here[i] == _last_picked_entity:
						picked_entity = entities_here[posmod(i + 1, entities_here.size())]
						break
			if not picked_entity:
				picked_entity = entities_here[0]

			pick_entity(picked_entity)
			_last_picked_entity = picked_entity
		else:
			var tile_here = MapManager.get_tile_index_at(cursor_tile_pos)
			if tile_here > -1:
				pick_index("tile", tile_here, MapManager.get_tile_facing_at(cursor_tile_pos))
			else:
				set_cursor_mode("delete")
		return
	
	if Utility.fixed_just_pressed_by_event("editor_delete_at_cursor", event):
		_standard_delete_at_cursor()
		return
	
	if Utility.fixed_just_pressed_by_event("editor_toggle_delete", event):
		if cursor_mode != "delete":
			set_cursor_mode("delete")
		return

func forwarded_shortcut_input(event: InputEvent) -> void:
	if GameManager.get_pause("pause_menu") or not GameManager.is_in_level_edit_mode:
		return
	if Utility.fixed_just_pressed_by_event("editor_start", event, true):
		switch_edit_mode(not edit_mode)
	elif Utility.fixed_just_pressed_by_event("editor_save_level", event, true) and edit_mode:
		if edit_mode:
			GameManager.save_edited()
		if GameManager.loaded_level_name:
			GameManager.save_edited_level_as(GameManager.loaded_level_name)
		else:
			var pause_menu: = Utility.get_pause_menu()
			if pause_menu:
				pause_menu.pause_and_open()
				pause_menu.on_save_as_button_pressed()
		GlobalToaster.show_toast_message("Saved")
	elif Utility.fixed_just_pressed_by_event("editor_new_map", event, true):
		GameManager.new_empty_level()

func switch_to_non_level_edit_mode() -> void:
	if edit_mode:
		switch_edit_mode(false)
	GameManager.is_in_level_edit_mode = false
	GameManager.set_live_edit_mode_enabled(false)
	var list_of_current_level: String = ""
	for level_list_name in GameManager.get_list_of_level_lists():
		for level_name in GameManager.get_levels_in_level_list(level_list_name):
			if level_name == GameManager.loaded_level_name:
				list_of_current_level = level_list_name
				break
		if list_of_current_level:
			break
	if list_of_current_level:
		GameManager.goto_level_in_level_list(list_of_current_level, GameManager.loaded_level_name)
	else:
		GameManager.play_first_level()

func _auto_save(level_state: Dictionary) -> void:
	var autosave_filename: = "editor_autosave"
	var level_name: = GameManager.loaded_level_name
	if not level_name.strip_edges():
		level_name = "LEVEL"
	prints("autosaving level: ", level_name)

	var level_data: = {
		"name": level_name,
		"state": level_state,
	}
	FilesManager.save_level_to_name(GameManager.cur_game_name, level_data, autosave_filename)

func get_current_facing() -> int:
	if cursor_mode == "entity":
		return current_entity_facing
	elif cursor_mode == "tile":
		return current_tile_facing
	return 0

func set_current_facing(facing: int) -> void:
	if cursor_mode == "entity":
		current_entity_facing = facing
	elif cursor_mode == "tile":
		current_tile_facing = facing
	preview.rotation = Utility.facing_rotation(facing)

func is_alt_mode_active() -> bool:
	if Input.is_key_pressed(KEY_SHIFT):
		return true
	if Input.is_action_pressed("editor_alt_mode_hold"):
		return true
	return false

func on_visibility_changed() -> void:
	if ui_layer:
		ui_layer.visible = visible

func is_other_paused() -> bool:
	return GameManager.is_paused_by_other("map_editor")

func get_valid_tile_pos_bounds() -> Rect2i:
	var map_bounds: = MapManager.get_map_size()
	return map_bounds.grow(extend_camera_limits_by_tiles)

func _entity_render_order(entity_a: BaseEntity, entity_b: BaseEntity) -> bool:
	if entity_a.z_index != entity_b.z_index:
		return entity_a.z_index > entity_b.z_index
	return entity_a.get_index() > entity_b.get_index()

func sort_entities_by_render_order(entity_list: Array) -> Array:
	entity_list = entity_list.duplicate()
	entity_list.sort_custom(_entity_render_order)
	return entity_list

func get_sorted_entities_at(tile_pos: Vector2i) -> Array:
	return sort_entities_by_render_order(get_all_entities_at_tile_pos(tile_pos))

func cleanup() -> void:
	GameManager.set_pause("map_editor", false)
	EntityManager.switch_entities_preview_mode(false)
	MapManager.switch_tiles_preview_mode(false)

func get_reduced_world_view_rect() -> Rect2:
	var world_view_rect: = Rect2(editor_cam.get_tl_position(), get_display_world_size())
	var reduce_ratio: = 0.6
	return Utility.grow_rect2_by_ratio(world_view_rect, reduce_ratio)

func get_display_world_size() -> Vector2:
	var vp: = get_viewport()
	if not vp.has_method("get_resolution"):
		return Vector2(vp.size)
	return Vector2(vp.get_resolution())

func entity_instance_editor_closed() -> void:
	set_enable_camera_limits(true)
	if entity_instance_editor.edited_entity:
		_refresh_entity_is_edited(entity_instance_editor.edited_entity)
	request_grab_gui_focus.emit()

func on_entity_props_edited(entity: BaseEntity) -> void:
	_refresh_entity_is_edited(entity)

func get_all_entities_at_tile_pos(tile_pos: Vector2i) -> Array:
	return EntityManager.get_entities_at(tile_pos, null, [], true, true)

func pause_menu_closed() -> void:
	if entity_instance_editor and entity_instance_editor.visible:
		entity_instance_editor.get_gui_focus()
	request_grab_gui_focus.emit()