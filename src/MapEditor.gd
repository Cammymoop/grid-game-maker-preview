extends Node2D

const EntityInstanceEditor = preload("res://Scenes/GameEditor/entity_instance_editor.gd")

@export var do_autosave: = true

@export var camera_move_speed: = 700

@export var ui_layer: CanvasLayer
@export var ui_root_control: Control
@export var entity_instance_editor: EntityInstanceEditor

var edit_mode: = false

var cur_ent_i: int = 0
var current_entity_index: int = 0
var current_entity_facing: int = 0

var cur_tile_i: int = 0
var current_tile_index: int = 0
var current_tile_facing: int = 0

var all_tiles: = []
var all_entities: = []

@onready var cursor = get_node("Cursor")
@onready var preview = get_node("Cursor/TileEntityPreview")

@onready var cursor_mode_text = find_child("CursorModeText")
@onready var cursor_mode_text_animator = cursor_mode_text.get_node("AnimationPlayer")

@onready var item_name_text = find_child("ItemNameText")
@onready var item_name_text_animator = item_name_text.get_node("AnimationPlayer")

var cursor_tex: = preload("res://assets/img/cursor.png")
var entity_cursor_tex: = preload("res://assets/img/cursor_entity.png")
var tile_cursor_tex: = preload("res://assets/img/cursor_tile.png")
var delete_cursor_tex: = preload("res://assets/img/cursor_delete.png")

var placing: = "none"

var delete_held_on_entity: = false

var cursor_tile_pos: = Vector2(0, 0)

var cursor_stick_vector: = Vector2(0, 0)

var has_edited_something: = false

var _last_picked_entity: BaseEntity = null

var _cursor_moved_from_directional_input: = false

func _ready() -> void:
	visibility_changed.connect(on_visibility_changed)
	if not edit_mode:
		switch_edit_mode(false, false)
	
	#var pause_menu = Utility.get_pause_menu()
	#pause_menu.gameplay_paused.connect(save_current_level_state)

func save_current_level_state() -> void:
	if not edit_mode:
		return
	GameManager.save_edited()

func switch_edit_mode(edit_enabled: bool, save_state: bool = true) -> void:
	edit_mode = edit_enabled
	visible = edit_enabled
	process_mode = PROCESS_MODE_ALWAYS if edit_enabled else PROCESS_MODE_PAUSABLE
	GameManager.set_pause("map_editor", edit_enabled)
	if not edit_enabled:
		place_mode("none")
		if save_state:
			GameManager.save_edited()
			if do_autosave and has_edited_something:
				_auto_save(GameManager.editor_save)
		#GameManager.position_gameplay_camera($EditorCam.position)
		GameManager.activate_gameplay_camera()
	else:
		has_edited_something = false
		var vp = get_viewport()
		if vp.has_method("rescale"):
			vp.rescale()
		if not GameManager.editor_live_edit_mode:
			GameManager.load_edited()
			await get_tree().process_frame
			await get_tree().process_frame
		var cam_position = GameManager.get_gameplay_camera_position()
		move_cursor(MapManager.world_to_tile_position(cam_position))
		$EditorCam.set_position_immediate(cam_position)
		$EditorCam.make_current()
		all_entities = EntityManager.get_all_entity_indexes()
		current_entity_index = all_entities[cur_ent_i]
		all_tiles = MapManager.get_all_tile_indexes()
		current_tile_index = all_tiles[cur_tile_i]
		if placing in ["entity", "tile"]:
			show_item_name()
		if entity_instance_editor:
			entity_instance_editor.find_auto_pick()
	
	MapManager.switch_tiles_preview_mode(edit_mode)

func set_entity_to(index: int) -> void:
	var prev_i: = cur_ent_i
	current_entity_index = index
	cur_ent_i = all_entities.find(index)
	preview_entity(index)
	if prev_i != cur_ent_i:
		show_item_name()

func advance_entity(delta: int) -> void:
	var prev_i: = cur_ent_i
	cur_ent_i += delta
	if cur_ent_i < 0:
		cur_ent_i += len(all_entities)
	elif cur_ent_i >= len(all_entities):
		cur_ent_i = 0
	current_entity_index = all_entities[cur_ent_i]
	preview_entity(current_entity_index)
	if prev_i != cur_ent_i:
		show_item_name()

func set_tile_to(index: int) -> void:
	var prev_i: = cur_tile_i
	current_tile_index = index
	cur_tile_i = all_tiles.find(index)
	preview_tile(index)
	if prev_i != cur_tile_i:
		show_item_name()

func advance_tile(delta: int) -> void:
	var prev_i: = cur_tile_i
	cur_tile_i += delta
	if cur_tile_i < 0:
		cur_tile_i += len(all_tiles)
	elif cur_tile_i >= len(all_tiles):
		cur_tile_i = 0
	current_tile_index = all_tiles[cur_tile_i]
	preview_tile(current_tile_index)
	if prev_i != cur_tile_i:
		show_item_name()

func preview_entity(entity_index):
	preview.texture = EntityManager.get_entity_texture(entity_index, true)
	preview.region_rect = EntityManager.get_entity_texture_rect(entity_index, true)

func preview_tile(tile_index):
	preview.texture = MapManager.get_tile_texture(tile_index, true)
	preview.region_rect = MapManager.get_tile_texture_rect(tile_index, true)

func place_mode(mode: String):
	if mode != "none":
		cursor_mode_text.text = mode.capitalize()
		cursor_mode_text.reset_size()
		if placing != mode:
			cursor_mode_text_animator.play("show_fade")
	delete_held_on_entity = false
	var item_name_changed: bool = mode != placing and mode in ["entity", "tile"]
	placing = mode
	if placing == "entity":
		cursor.texture = entity_cursor_tex
		preview_entity(current_entity_index)
		preview.visible = true
	elif placing == "tile":
		cursor.texture = tile_cursor_tex
		preview_tile(current_tile_index)
		preview.visible = true
	elif placing == "delete":
		cursor.texture = delete_cursor_tex
		preview.visible = false
	else:
		cursor.texture = cursor_tex
		preview.visible = false

	if placing != "entity":
		_last_picked_entity = null
	
	if item_name_changed:
		show_item_name()

func get_item_name() -> String:
	if placing not in ["entity", "tile"]:
		return ""
	return MapManager.get_tile_name(current_tile_index) if placing == "tile" else EntityManager.get_entity_name(current_entity_index)

func show_item_name() -> void:
	item_name_text.text = get_item_name()
	item_name_text.reset_size()
	if item_name_text_animator.is_playing():
		item_name_text_animator.stop()
	item_name_text_animator.play("show_fade")

func mouse_moved(new_mouse) -> void:
	_cursor_moved_from_directional_input = false
	move_cursor(MapManager.world_to_tile_position(new_mouse))

func move_cursor(new_position) -> void:
	if new_position == cursor_tile_pos:
		return
	cursor_tile_pos = new_position
	cursor.position = MapManager.tile_to_world_position(cursor_tile_pos)
	if Input.is_action_pressed("editor_place_entity"):
		_place(true)

func _place(holding=false):
	has_edited_something = true
	if placing == "tile":
		MapManager.replace_tiles_at(cursor_tile_pos, current_tile_index, current_tile_facing)
	elif placing == "entity":
		var entities_here = EntityManager.get_entities_at(cursor_tile_pos)
		# remove existing entities of the same index
		for e in entities_here:
			if e.entity_index == current_entity_index:
				if EntityManager.get_entity_prop_with_default(e, "edit_place_multiple", false):
					continue
				EntityManager.remove_entity(e)
		EntityManager.create_entity(current_entity_index, cursor_tile_pos, current_entity_facing)
	elif placing == "delete":
		var entities_here = EntityManager.get_entities_at(cursor_tile_pos)
		if not delete_held_on_entity and (len(entities_here) < 1 or holding):
			# No entities, remove the tile
			var here = MapManager.get_tile_index_at(cursor_tile_pos)
			if here > -1:
				MapManager.replace_tiles_at(cursor_tile_pos, -1)
				$DustParticles.emit_at(MapManager.tile_to_world_position_centered(cursor_tile_pos))
		elif not holding:
			delete_held_on_entity = true
		for e in entities_here:
			EntityManager.remove_entity(e)

func _process(delta: float) -> void:
	if GameManager.get_pause("pause_menu"):
		return
	if Input.is_action_just_pressed("editor_start"):
		switch_edit_mode(not edit_mode)
	
	if not edit_mode:
		return
	
	if not Input.is_action_pressed("editor_place_entity"):
		delete_held_on_entity = false
	
	vector_stick_process()
	camera_scroll_process(delta)

func update_cursor_stick_vector() -> void:
	cursor_stick_vector = Input.get_vector("editor_cursor_left", "editor_cursor_right", "editor_cursor_up", "editor_cursor_down")

func vector_stick_process() -> void:
	if cursor_stick_vector.length() < 0.25:
		return
	move_cursor(cursor_tile_pos + cursor_stick_vector.snapped(Vector2.ONE))
	_cursor_moved_from_directional_input = true
	cursor_stick_vector = Vector2.ZERO

func camera_scroll_process(delta: float) -> void:
	var hscroll = Input.get_axis("editor_camera_left", "editor_camera_right") * delta * camera_move_speed
	var vscroll = Input.get_axis("editor_camera_up", "editor_camera_down") * delta * camera_move_speed
	$EditorCam.do_scroll(hscroll, vscroll)
	if Vector2(hscroll, vscroll).length() > 0 and not _cursor_moved_from_directional_input:
		process_new_mouse_position()

func process_new_mouse_position() -> void:
	var new_mouse_pos: Vector2 = get_viewport().get_scaled_mouse_position()
	new_mouse_pos += $EditorCam.get_tl_position()
	new_mouse_pos = new_mouse_pos.round()
	mouse_moved(new_mouse_pos)

func forwarded_gui_input(event: InputEvent) -> void:
	if not edit_mode or GameManager.get_pause("pause_menu"):
		return
	
	if event is InputEventMouseMotion:
		process_new_mouse_position()
		return
	
	for cursor_stick_action in ["editor_cursor_up", "editor_cursor_down", "editor_cursor_left", "editor_cursor_right"]:
		if event.is_action(cursor_stick_action):
			update_cursor_stick_vector()
			break
	
	for tile_ent in ["tile", "entity"]:
		for next_prev in ["next", "prev"]:
			var direction = 1 if next_prev == "next" else -1
			if Utility.fixed_just_pressed_by_event("editor_" + next_prev + "_" + tile_ent, event, true):
				if placing != tile_ent:
					place_mode(tile_ent)
					set_current_facing(0)
				advance_tile(direction)
				return
	
	var scroll_up: = Utility.fixed_just_pressed_by_event("scroll_up", event)
	var scroll_down: = Utility.fixed_just_pressed_by_event("scroll_down", event)
	if scroll_up or scroll_down:
		var direction = 1 if scroll_up else -1
		if Input.is_key_pressed(KEY_SHIFT):
			if placing == "entity" or placing == "tile":
				set_current_facing(posmod(get_current_facing() + direction, 4))
		else:
			if placing == "delete":
				place_mode("tile")
			
			if placing == "tile":
				advance_tile(direction)
			elif placing == "entity":
				advance_entity(direction)
		return
	
	if Utility.fixed_just_pressed_by_event("editor_rotate_entity", event, true):
		if placing == "entity" or placing == "tile":
			set_current_facing(posmod(get_current_facing() + 1, 4))
		return
	
	if Utility.fixed_just_pressed_by_event("editor_place_entity", event, true):
		_place()
		return

	if Utility.fixed_just_pressed_by_event("editor_pick", event, true):
		prints("editor_pick")
		var entities_here: = EntityManager.get_entities_at(cursor_tile_pos, null, [], true)
		if entities_here.size() > 0:
			if placing != "entity":
				place_mode("entity")
			entities_here = sort_entities_by_render_order(entities_here)
			var picked_entity: BaseEntity
			if entities_here.size() > 1:
				for i in entities_here.size():
					if entities_here[i] == _last_picked_entity:
						picked_entity = entities_here[posmod(i + 1, entities_here.size())]
						break
			if not picked_entity:
				picked_entity = entities_here[0]

			set_entity_to(picked_entity.entity_index)
			set_current_facing(picked_entity.facing)
			_last_picked_entity = picked_entity
		else:
			var tile_here = MapManager.get_tile_index_at(cursor_tile_pos)
			if tile_here > -1:
				place_mode("tile")
				set_tile_to(tile_here)
				set_current_facing(MapManager.get_tile_facing_at(cursor_tile_pos))
			else:
				place_mode("delete")
		return
	
	if Utility.fixed_just_pressed_by_event("editor_clear_entities", event):
		var entities_here: = EntityManager.get_entities_at(cursor_tile_pos, null, [], true)
		if Input.is_key_pressed(KEY_SHIFT) or len(entities_here) < 1:
			# No entities or holding shift, remove the tile
			MapManager.replace_tiles_at(cursor_tile_pos, -1)
		for e in entities_here:
			EntityManager.remove_entity(e)
		return
	
	if Utility.fixed_just_pressed_by_event("editor_toggle_delete", event):
		if placing != "delete":
			place_mode("delete")
		return

func forwarded_shortcut_input(event: InputEvent) -> void:
	if Utility.fixed_just_pressed_by_event("refresh", event) and not edit_mode:
		GameManager.load_checkpoint()
		return
	if Utility.fixed_just_pressed_by_event("editor_new_map", event):
		GameManager.new_empty_level()
		return

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
	if placing == "entity":
		return current_entity_facing
	elif placing == "tile":
		return current_tile_facing
	return 0

func set_current_facing(facing: int) -> void:
	if placing == "entity":
		current_entity_facing = facing
	elif placing == "tile":
		current_tile_facing = facing
	preview.rotation = Utility.facing_rotation(facing)

func on_visibility_changed() -> void:
	prints("visibility changed: ", visible)
	if ui_layer:
		prints("setting ui layer visible: ", visible)
		ui_layer.visible = visible

func _entity_render_order(entity_a: BaseEntity, entity_b: BaseEntity) -> bool:
	if entity_a.z_index != entity_b.z_index:
		return entity_a.z_index > entity_b.z_index
	return entity_a.get_index() > entity_b.get_index()

func sort_entities_by_render_order(entity_list: Array) -> Array:
	entity_list = entity_list.duplicate()
	entity_list.sort_custom(_entity_render_order)
	return entity_list