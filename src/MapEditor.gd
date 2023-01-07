extends Node2D

var edit_mode = false

var cur_ent_i = 0
var current_entity_index = 0
var current_entity_facing = 0

const CAMERA_MOVE_SPEED: = 400

var cur_tile_i = 0
var current_tile_index = 0

var all_tiles = []
var all_entities = []

var live_edit_mode: = true

onready var cursor = get_node("Cursor")
onready var preview = get_node("Cursor/TileEntityPreview")

var cursor_tex = preload("res://assets/img/cursor.png")
var entity_cursor_tex = preload("res://assets/img/cursor_entity.png")
var tile_cursor_tex = preload("res://assets/img/cursor_tile.png")
var delete_cursor_tex = preload("res://assets/img/cursor_delete.png")

var placing = "none"

var delete_held_on_entity = false

var cursor_tile_pos = Vector2(0, 0)

var last_mouse = Vector2(0, 0)

func _ready() -> void:
	if not edit_mode:
		enable_edit_mode(false, false)
	
	var pause_menu = Utility.get_pause_menu()
	pause_menu.connect("gameplay_paused", self, "save_current_level_state")

func save_current_level_state() -> void:
	if not edit_mode:
		return
	GameManager.save_edited()

func enable_edit_mode(on, save_state=true):
	edit_mode = on
	visible = on
	pause_mode = PAUSE_MODE_PROCESS if on else PAUSE_MODE_STOP
	GameManager.set_pause("map_editor", on)
	if not on:
		place_mode("none")
		if save_state:
			GameManager.save_edited()
			GameManager.checkpoint_save = GameManager.editor_save
		#GameManager.position_gameplay_camera($EditorCam.position)
		GameManager.activate_gameplay_camera()
	else:
		if not live_edit_mode:
			GameManager.load_edited()
		var cam_position = GameManager.get_gameplay_camera_position()
		move_cursor(MapManager.world_to_tile_position(cam_position))
		$EditorCam.set_position_immediate(cam_position)
		$EditorCam.current = true
		all_entities = EntityManager.get_all_entity_indexes()
		current_entity_index = all_entities[cur_ent_i]
		all_tiles = MapManager.get_all_tile_indexes()
		current_tile_index = all_tiles[cur_tile_i]

func set_entity_to(index) -> void:
	current_entity_index = index
	cur_ent_i = all_entities.find(index)
	preview_entity(index)

func advance_entity(delta) -> void:
	cur_ent_i += delta
	if cur_ent_i < 0:
		cur_ent_i += len(all_entities)
	elif cur_ent_i >= len(all_entities):
		cur_ent_i = 0
	current_entity_index = all_entities[cur_ent_i]
	preview_entity(current_entity_index)

func set_tile_to(index) -> void:
	current_tile_index = index
	cur_tile_i = all_tiles.find(index)
	preview_tile(index)

func advance_tile(delta) -> void:
	cur_tile_i += delta
	if cur_tile_i < 0:
		cur_tile_i += len(all_tiles)
	elif cur_tile_i >= len(all_tiles):
		cur_tile_i = 0
	current_tile_index = all_tiles[cur_tile_i]
	preview_tile(current_tile_index)

func preview_entity(entity_index):
	preview.texture = EntityManager.get_entity_texture(entity_index)
	preview.region_rect = EntityManager.get_entity_texture_rect(entity_index)

func preview_tile(tile_index):
	preview.texture = MapManager.get_tile_texture(tile_index)
	preview.region_rect = MapManager.get_tile_texture_rect(tile_index)

func place_mode(mode):
	delete_held_on_entity = false
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
	if placing == "tile":
		MapManager.replace_tiles_at(cursor_tile_pos, current_tile_index)
	elif placing == "entity":
		var entities_here = EntityManager.get_entities_at(cursor_tile_pos)
		# remove existing entities of the same index
		for e in entities_here:
			if e.entity_index == current_entity_index:
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
		enable_edit_mode(not edit_mode)
	
	if Input.is_action_just_pressed("refresh") and not edit_mode:
		#get_tree().reload_current_scene()
		#call_deferred("load_random_level")
		GameManager.load_checkpoint()
	if Input.is_action_just_pressed("editor_new_map"):
		#get_tree().reload_current_scene()
		EntityManager.clear_entity_list()
		MapManager.clear_layers()
		MapManager.create_plain_layer()
		EntityManager.create_defaults()
	
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
	
	var hscroll = horiz_camera_move * delta * CAMERA_MOVE_SPEED
	var vscroll = vert_camera_move * delta * CAMERA_MOVE_SPEED
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
		else:
			advance_tile(1)
	if Input.is_action_just_pressed("editor_prev_tile"):
		if placing != "tile":
			place_mode("tile")
		else:
			advance_tile(-1)
	
	if Input.is_action_just_released("scroll_up") or Input.is_action_just_released("scroll_down"):
		var direction = 1 if Input.is_action_just_released("scroll_up") else -1
		if placing == "delete":
			place_mode("tile")
		
		if placing == "tile":
			advance_tile(direction)
		elif placing == "entity":
			advance_entity(direction)
	
	if Input.is_action_just_pressed("editor_rotate_entity"):
		if placing == "entity":
			current_entity_facing = Utility.resolve_relative_direction("turn_right", current_entity_facing)
			preview.rotation = Utility.facing_rotation(current_entity_facing)
	
	if Input.is_action_just_pressed("editor_place_entity"):
		_place()
	elif Input.is_action_just_pressed("editor_pick"):
		var entities_here = EntityManager.get_entities_at(cursor_tile_pos)
		if len(entities_here) > 0:
			if placing != "entity":
				place_mode("entity")
			var new_index = entities_here[-1].entity_index
			if len(entities_here) > 1 and new_index == current_entity_index:
				set_entity_to(entities_here[-2].entity_index)
			else:
				set_entity_to(new_index)
		else:
			var tile_here = MapManager.get_tile_index_at(cursor_tile_pos)
			if tile_here > -1:
				place_mode("tile")
				set_tile_to(tile_here)
			else:
				place_mode("delete")
	
	
	if Input.is_action_just_pressed("editor_next_entity"):
		if placing != "entity":
			place_mode("entity")
		else:
			advance_entity(1)
	if Input.is_action_just_pressed("editor_prev_entity"):
		if placing != "entity":
			place_mode("entity")
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
