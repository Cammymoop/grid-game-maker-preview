extends Node

var started = false
var cur_scene = null

var cur_game_name: = ""

var checkpoint_save = {}
var editor_save = {}
var loaded_level = {}

var loaded_level_name: = ""

var loaded = false

var editor_live_edit_mode: = true

var scenes: = {
	"Menu": "res://Scenes/Menu.tscn",
	"Loading": "res://Scenes/Loading.tscn",
	"Play": "res://Scenes/Play.tscn",
	"GameEditor": "res://Scenes/GameEditor.tscn",
}

var cameras = {
	"SimpleCamera": preload("res://Scenes/SimpleCamera.tscn"),
}

var pauses = {}

var game_view: = Vector2(12, 12)

var game_definition = {}

var game_camera: Camera2D = null

var transitioning = false
var transition_anim_target: Node
var scene_transition_duration = 0.6
var transition_left = true
@export var scene_transition_curve: Curve = Curve.new()

enum MovementMode {
	MOVEMENT_CONTINUOUS, MOVEMENT_DISCRETE, MOVEMENT_DISCRETE_WAIT
}

func _ready():
	# run _process even when the game is paused
	process_mode = PROCESS_MODE_ALWAYS
	cur_scene = get_tree().current_scene.name
	FilesManager.init_folders()
	
	var st_timer = Timer.new()
	st_timer.set_name("SceneTransitionTimer")
	add_child(st_timer)
	
	st_timer.one_shot = true
	st_timer.timeout.connect(scene_transition_clear)
	bake_scene_transition_curve()
	
	var default_game = FilesManager.get_default_game()
	if len(default_game) > 0:
		load_game_definition_from_file(default_game)
		start_managers()
	else:
		set_game_name("Basic")
		game_definition["game_settings"] = {"pixel_scale": 2}
		start_managers()
	
	MapManager.refresh_definition()
	EntityManager.refresh_definition()

func bake_scene_transition_curve() -> void:
	scene_transition_curve.bake()

func start_managers() -> void:
	TextureManager.setup()
	MapManager.setup()
	EntityManager.setup()

func describe_movement_mode(mode: int) -> String:
	match mode:
		MovementMode.MOVEMENT_CONTINUOUS:
			return "Continuous"
		MovementMode.MOVEMENT_DISCRETE:
			return "Discrete"
		MovementMode.MOVEMENT_DISCRETE_WAIT:
			return "Discrete, wait for all moves to finish"
	return ""

func load_game_definition_from_file(game_name) -> void:
	var definition = FilesManager.get_game_definition(game_name)
	
	# required section, but older saves didn't have it, remove this once they all do
	if not "game_settings" in definition:
		definition["game_settings"] = {}
	game_definition = definition
	
	set_game_name(definition['game_name'])
	
	editor_save = {}
	checkpoint_save = {}
	loaded_level = {}
	
	TextureManager.clear()
	if "textures" in definition:
		TextureManager.set_textures(definition['textures'])
	else:
		TextureManager.set_default_textures()
	
	MapManager.tile_defs = definition['tile_definitions']
	if MapManager.im_ready:
		MapManager.refresh_definition()
	EntityManager.entity_defs = definition['entity_definitions']
	if EntityManager.im_ready:
		EntityManager.refresh_definition()
	
	if "window_width" in definition:
		set_game_view(definition['window_width'], definition['window_height'])
	else:
		set_game_view(12, 12)
	
	# Set the window size when loading a new game definition
	rescale_window()
	
	if cur_scene != "Loading":
		change_scene(cur_scene)
		
		if cur_scene == "GameEditor":
			loaded = true

func get_game_setting(setting_name, default):
	if not "game_settings" in game_definition:
		return default
	return game_definition["game_settings"].get(setting_name, default)

func get_default_pixel_scale() -> float:
	return get_game_setting("pixel_scale", 1)

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
	if not serialized_state:
		return
	
	set_pause("gm_loading_state", true)
	
	await get_tree().process_frame
	await get_tree().process_frame
	EntityManager.clear()
	MapManager.clear_layers()
	MapManager.deserialize(serialized_state['map'])
	EntityManager.deserialize(serialized_state['entities'])
	
	set_pause("gm_loading_state", false)

func create_game_camera() -> void:
	var cam = cameras["SimpleCamera"].instantiate()
	Utility.get_world().add_child(cam)
	game_camera = cam

func position_gameplay_camera(pos: Vector2) -> void:
	if game_camera:
		game_camera.position = pos

func get_gameplay_camera_position() -> Vector2:
	if game_camera:
		return game_camera.get_screen_center_position()
	return Vector2.ZERO

func activate_gameplay_camera() -> void:
	if game_camera:
		game_camera.activate()

func set_pause(source, paused: bool) -> void:
	pauses[source] = paused
	
	var actually_paused = paused
	if not paused:
		for p in pauses.values():
			if p:
				actually_paused = true
	if actually_paused != get_tree().paused:
		get_tree().paused = actually_paused
func get_pause(source) -> bool:
	if source in pauses:
		return pauses[source]
	return false

func _unpause() -> void:
	pauses = {}
	get_tree().paused = false

func save_checkpoint() -> void:
	checkpoint_save = get_serialized_play_state()
func load_checkpoint() -> void:
	if not checkpoint_save:
		return
	load_serialized_play_state(checkpoint_save)
func clear_checkpoint() -> void:
	checkpoint_save = {}

func save_edited() -> void:
	print_debug("setting editor_save")
	editor_save = get_serialized_play_state()
func load_edited() -> void:
	load_serialized_play_state(editor_save)

func load_level_data(level_data):
	loaded_level_name = level_data["name"]
	editor_save = level_data["state"]
	load_edited()
	toggle_pause_menu()
	
	checkpoint_save = editor_save

func level_start():
	EntityManager.clear_entity_list()
	MapManager.create_plain_layer()
	EntityManager.create_defaults()
	
	save_checkpoint()

func load_random_level():
	EntityManager.clear_entity_list()
	MapManager.create_random_layer()
	EntityManager.create_randoms()
	
	save_checkpoint()

func change_scene(new_scene: String):
	if cur_scene != "Loading":
		show_scene_transition()
	
	if not new_scene in scenes:
		print("I dont know about scene " + new_scene)
		return
	
	if cur_scene == "Play":
		transition_left = true
		if editor_save:
			loaded_level = editor_save
		EntityManager.clear_entity_list()
		MapManager.clear_layers()
		game_camera = null
		_unpause()
	elif cur_scene == "GameEditor":
		transition_left = false
		EntityManager.refresh_definition()
		MapManager.refresh_definition()
	
	if new_scene == "Play":
		transition_left = false
	elif new_scene == "GameEditor":
		transition_left = true
	
	cur_scene = new_scene
	get_tree().change_scene_to_file(scenes[new_scene])
	
	await get_tree().process_frame
	post_scene_change()

func show_scene_transition() -> void:
	var main_viewport_copy: = get_viewport().get_texture().get_image()
	main_viewport_copy.flip_y()
	var copy_tex = ImageTexture.create_from_image(main_viewport_copy)
	var overlay = TextureRect.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.texture = copy_tex
	
	var overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 128
	get_viewport().add_child(overlay_layer)
	overlay_layer.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_VCENTER_WIDE)
	overlay_layer.add_to_group("TransitionOverlay")
	
	transitioning = true
	$SceneTransitionTimer.start(scene_transition_duration)
	transition_anim_target = overlay

func scene_transisiton_update() -> void:
	var progress = (scene_transition_duration - $SceneTransitionTimer.time_left)/scene_transition_duration
	var curve_val = scene_transition_curve.sample_baked(progress)
	var transition_sign = -1 if transition_left else 1
	transition_anim_target.position.x = curve_val * get_viewport().size.x * transition_sign

func scene_transition_clear() -> void:
	for overlay_layer in get_tree().get_nodes_in_group("TransitionOverlay"):
		overlay_layer.queue_free()
	
	transition_anim_target = null
	transitioning = false

func post_scene_change() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if cur_scene == "Play":
		update_game_viewport()
		create_game_camera()
		activate_gameplay_camera()
		if loaded_level:
			load_serialized_play_state(loaded_level)
		else:
			level_start()

func update_game_viewport() -> void:
	var vp = Utility.get_world().get_viewport()
	vp.update_aspect = get_game_setting("auto_aspect", true)
	vp.set_resolution(game_view * MapManager.tile_width)

func set_game_view(width, height) -> void:
	game_view = Vector2(width, height)

func rescale_window() -> void:
	var window: = get_window()
	if window.mode == Window.MODE_FULLSCREEN or window.mode == Window.MODE_MAXIMIZED:
		return
	
	window.size = game_view * MapManager.tile_width * get_default_pixel_scale()
	
	# Re-center the window
	var screen_size = DisplayServer.screen_get_size()
	@warning_ignore("integer_division")
	window.position = screen_size/2 - window.size/2 + DisplayServer.screen_get_position()

func toggle_pause_menu():
	if cur_scene != "Play":
		return
	
	var pause_menu = get_tree().get_nodes_in_group("PauseMenu")
	for p in pause_menu:
		p.toggle()
	
func start_on_ready() -> bool:
	if TextureManager.im_ready and MapManager.im_ready and EntityManager.im_ready:
		
#		var default_game = FilesManager.get_default_game()
#		if len(default_game) > 0:
#			load_game_definition_from_file(default_game)
#		else:
#			set_game_name("Basic")
#			game_definition["game_settings"] = {"pixel_scale": 2}

		# Set the window size for the default game
#		rescale_window()
		
		started = true
		if cur_scene == "Loading":
			change_scene("Menu")
		
		return true
	return false


func _process(_delta):
	if not started:
		if not start_on_ready():
			return
	
	if transitioning:
		scene_transisiton_update()
	
	if Input.is_action_just_pressed("escape"):
		if cur_scene == "GameEditor":
			change_scene("Menu")
		elif cur_scene == "Menu":
			get_tree().quit()
		elif cur_scene == "Play":
			toggle_pause_menu()

func get_all_used_prop_names() -> Array[String]:
	var prop_names: Array[String] = []
	
	var tile_entity_defs: Array[Dictionary] = []
	tile_entity_defs.append_array(EntityManager.entity_defs.values())
	tile_entity_defs.append_array(MapManager.tile_defs.values())
	for tile_or_entity_def in tile_entity_defs:
		for prop_name in tile_or_entity_def["properties"].keys():
			if not typeof(prop_name) == TYPE_STRING:
				push_error("Property name is not a string: " + str(prop_name))
				continue
			if not prop_name in prop_names:
				prop_names.append(prop_name)

	return prop_names
