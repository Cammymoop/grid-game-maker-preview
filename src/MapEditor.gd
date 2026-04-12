extends Node2D

@export var do_autosave: = true

@export var camera_move_speed: = 400

@export var ui_layer: CanvasLayer
@export var ui_root_control: Control

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

var last_mouse: = Vector2(0, 0)

var has_edited_something: = false

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

func _process(delta):
	if GameManager.get_pause("pause_menu"):
		return
	if Input.is_action_just_pressed("editor_start"):
		switch_edit_mode(not edit_mode)
	
	if Input.is_action_just_pressed("refresh") and not edit_mode:
		#get_tree().reload_current_scene()
		#call_deferred("load_random_level")
		GameManager.load_checkpoint()
	if Input.is_action_just_pressed("editor_new_map"):
		GameManager.new_empty_level()
	
	if not edit_mode:
		return
	
	var new_mouse = get_viewport().get_scaled_mouse_position()
	new_mouse += $EditorCam.get_tl_position()
	new_mouse = new_mouse.round()
	if edit_mode and last_mouse != new_mouse:
		mouse_moved(new_mouse)
	last_mouse = new_mouse
	
	var iup = Input.is_action_just_pressed("editor_cursor_up")
	var idown = Input.is_action_just_pressed("editor_cursor_down")
	var ileft = Input.is_action_just_pressed("editor_cursor_left")
	var iright = Input.is_action_just_pressed("editor_cursor_right")
	
	var horiz_camera_move = Input.get_axis("editor_camera_left", "editor_camera_right")
	var vert_camera_move = Input.get_axis("editor_camera_up", "editor_camera_down")
	
	var hscroll = horiz_camera_move * delta * camera_move_speed
	var vscroll = vert_camera_move * delta * camera_move_speed
	$EditorCam.do_scroll(hscroll, vscroll)
	
	var input_dir = "none"
	
	if iup and not idown:
		input_dir = "up"
	elif idown and not iup:
		input_dir = "down"
	elif ileft and not iright:
		input_dir = "left"
	elif iright and not ileft:
		input_dir = "right"
	
	if input_dir != "none":
		move_cursor(cursor_tile_pos + Utility.facing_vector(Utility.direction_to_facing(input_dir)))
	
	if not Input.is_action_pressed("editor_place_entity"):
		delete_held_on_entity = false
	
	if Input.is_action_just_pressed("editor_next_tile"):
		if placing != "tile":
			place_mode("tile")
			current_tile_facing = 0
		else:
			advance_tile(1)
	if Input.is_action_just_pressed("editor_prev_tile"):
		if placing != "tile":
			place_mode("tile")
			current_tile_facing = 0
		else:
			advance_tile(-1)
	
	if Input.is_action_just_released("scroll_up") or Input.is_action_just_released("scroll_down"):
		var direction = 1 if Input.is_action_just_released("scroll_up") else -1
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
	
	if Input.is_action_just_pressed("editor_rotate_entity"):
		if placing == "entity" or placing == "tile":
			set_current_facing(posmod(get_current_facing() + 1, 4))
	
	if Input.is_action_just_pressed("editor_place_entity"):
		_place()
	elif Input.is_action_just_pressed("editor_pick"):
		var entities_here = EntityManager.get_entities_at(cursor_tile_pos)
		if len(entities_here) > 0:
			if placing != "entity":
				place_mode("entity")
			var picked_entity = entities_here[-1]
			if len(entities_here) > 1 and entities_here[-1].entity_index == current_entity_index:
				picked_entity = entities_here[-2]
			set_entity_to(picked_entity.entity_index)
			set_current_facing(picked_entity.facing)
		else:
			var tile_here = MapManager.get_tile_index_at(cursor_tile_pos)
			if tile_here > -1:
				var tile_facing = MapManager.get_tile_facing_at(cursor_tile_pos)
				place_mode("tile")
				set_tile_to(tile_here)
				set_current_facing(tile_facing)
			else:
				place_mode("delete")
	
	
	if Input.is_action_just_pressed("editor_next_entity"):
		if placing != "entity":
			place_mode("entity")
			set_current_facing(0)
		else:
			advance_entity(1)
	if Input.is_action_just_pressed("editor_prev_entity"):
		if placing != "entity":
			place_mode("entity")
			set_current_facing(0)
		else:
			advance_entity(-1)
	
	if Input.is_action_just_pressed("editor_clear_entities"):
		var entities_here = EntityManager.get_entities_at(cursor_tile_pos)
		if len(entities_here) < 1:
			# No entities, remove the tile
			MapManager.replace_tiles_at(cursor_tile_pos, -1)
		for e in entities_here:
			EntityManager.remove_entity(e)
	
	if Input.is_action_just_pressed("editor_toggle_delete"):
		if placing != "delete":
			place_mode("delete")

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