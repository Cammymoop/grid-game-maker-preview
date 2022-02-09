extends Node

var started = false
var cur_scene = null

var cur_game_name: = ""

var checkpoint_save = {}
var suspend_save = {}

var loaded = false

var scenes: = {
	"Menu": "res://Scenes/Menu.tscn",
	"Loading": "res://Scenes/Loading.tscn",
	"Play": "res://Scenes/Play.tscn",
	"GameEditor": "res://Scenes/GameEditor.tscn",
}

var pauses = {}

var game_view: = Vector2(12, 12)

func _ready():
	# run _process even when the game is paused
	pause_mode = PAUSE_MODE_PROCESS
	cur_scene = get_tree().current_scene.name
	FilesManager.init_folders()

func load_game_definition_from_file(game_name) -> void:
	var definition = FilesManager.get_game_definition(game_name)
	
	set_game_name(definition['game_name'])
	MapManager.tile_defs = definition['tile_definitions']
	MapManager.refresh_definition()
	EntityManager.entity_defs = definition['entity_definitions']
	EntityManager.refresh_definition()
	
	if "window_width" in definition:
		set_game_view(definition['window_width'], definition['window_height'])
	else:
		set_game_view(12, 12)
	
	if cur_scene != "Loading":
		change_scene(cur_scene)
		
		if cur_scene == "GameEditor":
			loaded = true

func get_game_name() -> String:
	return cur_game_name

func set_game_name(new_name: String) -> void:
	cur_game_name = new_name

func get_serialized_play_state() -> Dictionary:
	if cur_scene != "Play":
		print("Can't serialize play state, not in play scene")
		return {}
	
	var s_map = MapManager.serialize()
	var s_ent = EntityManager.serialize()
	return {"game_name": cur_game_name, "map": s_map, "entities": s_ent}

func load_serialized_play_state(serialized_state: Dictionary) -> void:
	if cur_scene != "Play":
		print("Can't deserialize play state, not in play scene")
		return
	
	get_tree().paused = true
	
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	MapManager.deserialize(serialized_state['map'])
	EntityManager.deserialize(serialized_state['entities'])
	
	get_tree().paused = false

func set_pause(source, paused: bool) -> void:
	pauses[source] = paused
	
	var actually_paused = paused
	if not paused:
		for p in pauses.values():
			if p:
				actually_paused = true
	if actually_paused != get_tree().paused:
		get_tree().paused = actually_paused

func _unpause() -> void:
	pauses = {}
	get_tree().paused = false

func save_checkpoint() -> void:
	checkpoint_save = get_serialized_play_state()

func load_checkpoint() -> void:
	load_serialized_play_state(checkpoint_save)

func level_start():
	update_game_viewport()
	MapManager.create_plain_layer()
	EntityManager.create_defaults()
	
	save_checkpoint()

func load_random_level():
	update_game_viewport()
	MapManager.create_random_layer()
	EntityManager.create_randoms()
	
	save_checkpoint()

func change_scene(new_scene: String):
	if not new_scene in scenes:
		print("I dont know about scene " + new_scene)
		return
	
	if cur_scene == "Play":
		EntityManager.clear_entity_list()
		_unpause()
	elif cur_scene == "GameEditor":
		EntityManager.refresh_definition()
		MapManager.refresh_definition()
	
	cur_scene = new_scene
	get_tree().change_scene(scenes[new_scene])
	
	if new_scene == "Play":
		yield(get_tree(), "idle_frame")
		level_start()

func update_game_viewport() -> void:
	Utility.get_world().get_viewport().set_resolution(game_view * MapManager.tile_width)

func set_game_view(width, height) -> void:
	game_view = Vector2(width, height)

func rescale_window() -> void:
	if OS.window_fullscreen or OS.window_maximized:
		return
	
	OS.window_size = game_view * MapManager.tile_width * 2
	
	# Re-center the window
	var screen = OS.get_screen_size()
	OS.window_position = Vector2(screen.x/2 - OS.window_size.x/2, screen.y/2 - OS.window_size.y/2)

func toggle_pause_menu():
	if cur_scene != "Play":
		return
	
	var pause_menu = get_tree().get_nodes_in_group("PauseMenu")
	for p in pause_menu:
		p.toggle()
	
func start_on_ready() -> bool:
	if TextureManager.im_ready and MapManager.im_ready and EntityManager.im_ready:
		
		var default_game = FilesManager.get_default_game()
		if len(default_game) > 0:
			load_game_definition_from_file(default_game)
		else:
			set_game_name("Basic")

		# Set the window size for the default game
		rescale_window()
		
		started = true
		if cur_scene == "Loading":
			change_scene("Menu")
		
		return true
	return false


func _process(_delta):
	if not started:
		if not start_on_ready():
			return
	
	if cur_scene == "Play":
		if Input.is_action_just_pressed("refresh"):
			get_tree().reload_current_scene()
			call_deferred("load_random_level")
		elif Input.is_action_just_pressed("editor_new_map"):
			get_tree().reload_current_scene()
			call_deferred("level_start")
	
	if Input.is_action_just_pressed("escape"):
		if cur_scene == "GameEditor":
			change_scene("Menu")
		elif cur_scene == "Menu":
			get_tree().quit()
		elif cur_scene == "Play":
			toggle_pause_menu()
