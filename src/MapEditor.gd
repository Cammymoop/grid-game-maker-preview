extends Node2D

var edit_mode = false

var entity_place = true
var current_entity_index = 0
var current_entity_facing = 0

var cursor_tile_pos = Vector2(0, 0)

func _ready():
	if not edit_mode:
		enable_edit_mode(false)

func enable_edit_mode(on):
	edit_mode = on
	visible = on
	get_tree().paused = on
	if not on:
		enable_entity_place(false)

func enable_entity_place(on):
	entity_place = on
	$Cursor/EntityPreview.visible = on

func _process(delta):
	if Input.is_action_just_pressed("editor_start"):
		enable_edit_mode(not edit_mode)
	if not edit_mode:
		return
	
	var iup = Input.is_action_just_pressed("move_up")
	var idown = Input.is_action_just_pressed("move_down")
	var ileft = Input.is_action_just_pressed("move_left")
	var iright = Input.is_action_just_pressed("move_right")
	
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
		cursor_tile_pos = cursor_tile_pos + Utility.facing_vector(Utility.direction_to_facing(input_dir))
		$Cursor.position = MapManager.tile_to_world_position(cursor_tile_pos)
	
	if Input.is_action_just_pressed("editor_next_tile"):
		if entity_place:
			enable_entity_place(false)
		else:
			var tiles = MapManager.get_all_tile_indexes()
			var ti = MapManager.get_tile_index_at(cursor_tile_pos)
			var i = tiles.find(ti) + 1
			if i >= len(tiles):
				i = 0
			MapManager.replace_tiles_at(cursor_tile_pos, tiles[i])
	if Input.is_action_just_pressed("editor_prev_tile"):
		if entity_place:
			enable_entity_place(false)
		else:
			var tiles = MapManager.get_all_tile_indexes()
			var ti = MapManager.get_tile_index_at(cursor_tile_pos)
			var i = tiles.find(ti) - 1
			MapManager.replace_tiles_at(cursor_tile_pos, tiles[i])
	
	if Input.is_action_just_pressed("editor_rotate_entity"):
		if entity_place:
			current_entity_facing = Utility.resolve_relative_direction("turn_right", current_entity_facing)
			$Cursor/EntityPreview.rotation = Utility.facing_rotation(current_entity_facing)
	
	if Input.is_action_just_pressed("editor_place_entity"):
		if not entity_place:
			enable_entity_place(true)
		else:
			var entities_here = EntityManager.get_entities_at(cursor_tile_pos)
			for e in entities_here:
				if e.entity_index == current_entity_index:
					EntityManager.remove_entity(e)
			EntityManager.create_entity(current_entity_index, cursor_tile_pos, current_entity_facing)
	
	
	if Input.is_action_just_pressed("editor_next_entity"):
		if not entity_place:
			enable_entity_place(true)
		else:
			var all_entities = EntityManager.get_all_entity_indexes()
			var i = all_entities.find(current_entity_index) + 1
			if i >= len(all_entities):
				i = 0
			current_entity_index = all_entities[i]
			$Cursor/EntityPreview.texture = EntityManager.get_entity_texture(current_entity_index)
			$Cursor/EntityPreview.region_rect = EntityManager.get_entity_texture_rect(current_entity_index)
	if Input.is_action_just_pressed("editor_prev_entity"):
		if not entity_place:
			enable_entity_place(true)
		else:
			var all_entities = EntityManager.get_all_entity_indexes()
			var i = all_entities.find(current_entity_index) - 1
			if i >= len(all_entities):
				i = 0
			current_entity_index = all_entities[i]
			$Cursor/EntityPreview.texture = EntityManager.get_entity_texture(current_entity_index)
			$Cursor/EntityPreview.region_rect = EntityManager.get_entity_texture_rect(current_entity_index)
	
	if Input.is_action_just_pressed("editor_clear_entities"):
		var entities_here = EntityManager.get_entities_at(cursor_tile_pos)
		for e in entities_here:
			EntityManager.remove_entity(e)
