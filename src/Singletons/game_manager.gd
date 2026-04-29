extends Node

signal level_state_loaded
signal game_camera_target_changed(entity: BaseEntity)
signal game_settings_changed
signal game_dir_name_changed(new_game_dir_name: String)
signal scene_changed(new_scene: String)

const CreditsUI = preload("res://Scenes/credits_ui.gd")

const FULL_TICK_RATE: int = 60
@onready var TICK_RATE: int = ProjectSettings.get_setting_with_override("physics/common/physics_ticks_per_second")

var started = false
var cur_scene = null

var cur_game_name: = ""
var loaded_from_game_name: = ""

var current_level_list: String = ""

var game_creators: Array[String] = []

var checkpoint_save: = {}
var editor_save: = {}
var loaded_level: = {}

var quicksave_state: = {}

var loaded_level_name: = ""
var loaded_is_autosave: = false

var is_in_level_edit_mode: = true

var loaded = false

var editor_live_edit_mode: = false
var current_level_is_museum: = false

var queued_level_load: bool = false
var queued_level_load_timer: Timer = null

var file_access_web: RefCounted = null

var scenes: = {
	"Menu": "res://Scenes/Menu.tscn",
	"Loading": "res://Scenes/Loading.tscn",
	"Play": "res://Scenes/Play.tscn",
	"GameEditor": "res://Scenes/GameEditor.tscn",
}

var cameras = {
	"SimpleCamera": preload("res://Scenes/SimpleCamera.tscn"),
}

const SPECIAL_PROPS: Array[String] = [
	"z-index", "move-turns", "inherit-properties",
	"auto-bond", "auto-tail", "auto-scale",
	"die-when-blocked",
	"edit-place-multiple",
	"no-museum", "museum-active",
	"move-animation", "controller-disabled",
	"turn-animation",
	"actions-disabled",
	"no-rotate",
	"teleport-duration", "move-speed",
]

const SPECIAL_PROPS_HINT_TEXT: Dictionary[String, String] = {
	"z-index": "Relative sorting offset, Entities or tiles with a higher sorting offset will be shown over others, can be negative.\nBy default entities are 5 higher than tiles.",
	"move-turns": "If false, the entity will not automatically turn it's facing direction to match it's moving direction when it moves.",
	"inherit-properties": "[Experimental] If true, the entity will inherit properties it does not have from another entity type with this name.",
	"auto-bond": "If true, this entity will automatically join a bond group with other entities of the same type when first created.",
	"auto-tail": "If true, this entity will automatically start tailing an entity in front of it when first created (if there is one)",
	"auto-scale": "[Experimental] if the entity is LARGE, this controls if it's sprite is automatically scaled up to cover the entire area taken up by the entity",
	"die-when-blocked": "If true, when this entity tries to move and is blocked it will automatically be destroyed",
	"edit-place-multiple": "If true, placing this entity using the level editor will not remove other entities of the same type at that location",
	"no-museum": "If true, this entity will not be included in the automatically generated museum",
	"museum-active": "If this property exists, it will determine whether or not the entities of this type will start as active in the automatically generated museum",
	"move-animation": "Set this to define the animation style for when this entity moves (see valid options in the Game tab)\n" +
		'Can be overridden for a single movement by the "Override Move Animation" Conditional command or automatically by the "Get Pushed" command.',
	"turn-animation": "Set this to define the animation style for when this entity turns (see valid options in the Game tab)",
	"controller-disabled": "While this property is true the entity will ignore intended moves from it's controller",
	"actions-disabled": "While this property is true the entity will ignore action events e.g. do_action_1",
	"no-rotate": "If true, the entity's sprite will not rotate regardless of which way the entity is facing (or moving).\n" +
		"The entity will still be able to face different directions. Spinning sprite layers will still spin.",
	"teleport-duration": "The default duration for this entity to finish teleporting (in seconds).\nIf not set, the default is 1/6th of a second." +
		'This can be overridden for a single teleport using by using the "Override Move Speed" Conditional command (duration is = 1/move speed).',
	"move-speed": "The default speed (grid spaces per second) that this entity moves at.\nIf not set, the default from the game settings is used.\n" +
		'This speed can be overridden for a single movement using the "Override Move Speed" Conditional command or automatically by the "Get Pushed" command.',
}

@export_file("*.json") var builtin_default_game_file: String = ""
var builtin_default_game_definition: Dictionary = {}

var pauses = {}

var game_definition = {}
var _unmodified_game_definition = {}

var game_camera: Camera2D = null

var stateful_camera_settings: = {}

var transitioning = false
var transition_anim_target: Node
var scene_transition_duration = 0.6
var transition_left = true
@export var scene_transition_curve: Curve = Curve.new()

enum MovementMode {
	MOVEMENT_CONTINUOUS, MOVEMENT_DISCRETE, MOVEMENT_DISCRETE_WAIT
}

func _ready():
	PuzzleScriptRNG.test_example()
	# Automatically use the display scaling from the OS if it's detected, because of how the gameplay display auto scales this mainly affects UI
	var cur_screen_scale: float = DisplayServer.screen_get_scale()
	if cur_screen_scale != get_window().content_scale_factor:
		get_window().content_scale_factor = cur_screen_scale
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
	var loaded_default_game: = false
	if default_game: 
		if FilesManager.game_exists(default_game):
			load_game_definition_from_file(default_game)
			start_managers()
			loaded_default_game = true
		else:
			var games_list: = FilesManager.get_games_list()
			if games_list.size() > 0:
				default_game = games_list[0]
				FilesManager.save_default_game(default_game)
				load_game_definition_from_file(default_game)
				start_managers()
				loaded_default_game = true

	if not loaded_default_game:
		if builtin_default_game_file:
			builtin_default_game_definition = FilesManager._get_dict_from_json_file(builtin_default_game_file)
			load_game_definition_data(builtin_default_game_definition)
			start_managers()
		else:
			new_empty_game_definition(FilesManager.get_unique_game_name("Empty Game"))
			start_managers()
			save_current_game_definition()
			FilesManager.save_default_game(get_game_name())
	
	MapManager.refresh_definition()
	EntityManager.refresh_definition()
	EntityManager.build_sprite_previews()
	
	SfxPlayer.refresh_game_sfx()

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
			return "Discrete+ (wait for all moves to stop)"
	return ""

func new_empty_game_definition(with_name: String = "") -> void:
	if not with_name:
		var safety: int = 10000
		while true:
			with_name = "%s Game" % Utility.random_animal()
			if not FilesManager.game_exists(with_name):
				break
			safety -= 1
			if safety <= 0:
				break
	var empty_game: = {
		"game_name": with_name,
		"textures": TextureManager.get_default_texture_spec(),
		"game_settings": {
			"pixel_scale": 2,
			"window_width": 18,
			"window_height": 14,
		},
		"entity_definitions": {},
		"tile_definitions": {},
		"level_lists": [],
	}
	load_game_definition_data(empty_game)

func load_game_definition_from_file(game_name) -> void:
	var definition = FilesManager.get_game_definition(game_name)
	load_game_definition_data(definition)

func load_game_definition_data(definition_data: Dictionary) -> void:
	game_definition = definition_data.duplicate_deep()
	_unmodified_game_definition = definition_data.duplicate_deep()
	
	_set_game_name(definition_data['game_name'], false)
	loaded_from_game_name = cur_game_name
	
	editor_save = {}
	quicksave_state = {}
	checkpoint_save = {}
	loaded_level = {}
	
	# compatibility
	if "window_width" in definition_data and "window_height" in definition_data:
		var compatibility_window_size: = Vector2(definition_data['window_width'], definition_data['window_height'])
		set_game_view(compatibility_window_size)
		set_game_setting("window_width", definition_data['window_width'])
		definition_data.erase('window_width')
		definition_data.erase('window_height')
	
	# Set the window size when loading a new game definition
	rescale_window()
	
	TextureManager.clear()
	if "textures" in definition_data:
		TextureManager.set_textures(definition_data['textures'])
	else:
		TextureManager.set_default_textures()
	
	MapManager.tile_defs = definition_data['tile_definitions']
	if MapManager.im_ready:
		MapManager.refresh_definition()
	EntityManager.entity_defs = definition_data['entity_definitions']
	if EntityManager.im_ready:
		EntityManager.refresh_definition()
		EntityManager.build_sprite_previews()
	
	if cur_scene != "Loading":
		change_scene(cur_scene)
		
		if cur_scene == "GameEditor":
			loaded = true

func get_serialized_game_definition() -> Dictionary:
	var serialized_def: = game_definition.duplicate_deep()
	serialized_def["game_name"] = get_game_name()
	serialized_def["textures"] = TextureManager.get_texture_spec()
	serialized_def["entity_definitions"] = EntityManager.entity_defs.duplicate_deep()
	serialized_def["tile_definitions"] = MapManager.tile_defs.duplicate_deep()
	return serialized_def

func get_game_setting(setting_name, default):
	if not "game_settings" in game_definition:
		return default
	return game_definition["game_settings"].get(setting_name, default)

func set_game_setting(setting_name: String, value: Variant) -> void:
	if not "game_settings" in game_definition:
		game_definition["game_settings"] = {}
	game_definition["game_settings"][setting_name] = value
	game_settings_changed.emit()

func get_window_size_setting() -> Vector2:
	return Utility.get_vector2_from_arr(get_game_setting("game_view_size", [12, 12]))

func get_base_window_size() -> Vector2:
	return get_window_size_setting() * MapManager.tile_width

func set_game_view(new_game_view_size: Vector2) -> void:
	set_game_setting("game_view_size", Utility.vector_to_list(new_game_view_size))

func get_default_pixel_scale() -> float:
	return get_game_setting("pixel_scale", 1)

func get_game_name() -> String:
	return cur_game_name

func get_game_implicit_title() -> String:
	if "[" not in cur_game_name:
		return cur_game_name
	return cur_game_name.split("[")[0]

func get_game_title() -> String:
	if not get_game_setting("title", ""):
		return get_game_implicit_title()
	return get_game_setting("title", "")

func _set_game_name(new_name: String, do_emit: bool = true) -> void:
	cur_game_name = new_name.strip_edges()
	if do_emit:
		game_dir_name_changed.emit(cur_game_name)

func get_credits_info() -> Dictionary:
	return game_definition.get("game_metadata", {}).get("credits", {})

func set_credits_info(credits_info: Dictionary) -> void:
	if not "game_metadata" in game_definition:
		game_definition["game_metadata"] = {}
	game_definition["game_metadata"]["credits"] = credits_info

func get_serialized_play_state() -> Dictionary:
	if cur_scene != "Play":
		print("Can't serialize play state, not in play scene")
		return {}
	
	var s_map = MapManager.serialize()
	var s_ent = EntityManager.serialize()
	return {"game_name": cur_game_name, "map": s_map, "entities": s_ent, "game_state": serialize()}

func serialize() -> Dictionary:
	return {
		"stateful_camera_settings": stateful_camera_settings.duplicate_deep(),
		"camera_position": Utility.vector_to_list(get_gameplay_camera_position()),
	}

func load_serialized_play_state(serialized_state: Dictionary, as_level_load: bool = true) -> void:
	if cur_scene != "Play":
		print("Can't deserialize play state, not in play scene")
		return
	if not serialized_state or queued_level_load:
		return
	
	set_pause("gm_loading_state", true)
	
	await get_tree().process_frame
	deserialize(serialized_state.get("game_state", {}))
	MapManager.deserialize(serialized_state['map'])
	EntityManager.deserialize(serialized_state['entities'])
	
	if as_level_load:
		level_state_loaded.emit()
	set_pause("gm_loading_state", false)

func deserialize(serialized_state: Dictionary) -> void:
	stateful_camera_settings = serialized_state.get("stateful_camera_settings", {}).duplicate_deep()
	if "camera_position" in serialized_state:
		var game_camera_to: Vector2 = Utility.get_vector2_from_arr(serialized_state.get("camera_position", [0, 0]))
		position_gameplay_camera(game_camera_to)

func create_game_camera() -> void:
	var cam = cameras["SimpleCamera"].instantiate()
	Utility.get_world().add_child(cam)
	game_camera = cam
	game_camera.camera_target_changed.connect(game_camera_target_changed.emit)

func position_gameplay_camera(pos: Vector2) -> void:
	if game_camera:
		game_camera.teleport(pos)

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

func is_paused_by_other(other_than_source: String) -> bool:
	if not get_tree().paused:
		return false
	for pause_source in pauses:
		if pause_source != other_than_source and pauses[pause_source]:
			return true
	return false

func _unpause() -> void:
	pauses = {}
	get_tree().paused = false

func save_checkpoint() -> void:
	checkpoint_save = get_serialized_play_state()
func load_checkpoint() -> void:
	if not checkpoint_save:
		if loaded_level_name and editor_save:
			load_serialized_play_state(editor_save, false)
		return
	load_serialized_play_state(checkpoint_save, false)
func clear_checkpoint() -> void:
	checkpoint_save = {}

func save_edited() -> void:
	editor_save = get_serialized_play_state()
	clear_checkpoint()
func load_edited() -> void:
	load_serialized_play_state(editor_save)
	clear_checkpoint()

func save_quicksave() -> void:
	quicksave_state = get_serialized_play_state()
func load_quicksave() -> void:
	if not quicksave_state:
		return
	load_serialized_play_state(quicksave_state, false)
func clear_quicksave() -> void:
	quicksave_state = {}

# hack
func update_edited_level_metadata_value(meta_key: String, meta_value: Variant) -> void:
	if not editor_save:
		return
	
	if typeof(meta_value) in [TYPE_ARRAY, TYPE_DICTIONARY]:
		meta_value = meta_value.duplicate_deep()

	editor_save["map"]["metadata"][meta_key] = meta_value
	if checkpoint_save:
		checkpoint_save["map"]["metadata"][meta_key] = meta_value

func erase_edited_level_metadata_value(meta_key: String) -> void:
	if not editor_save:
		return
	
	editor_save["map"]["metadata"].erase(meta_key)
	if checkpoint_save:
		checkpoint_save["map"]["metadata"].erase(meta_key)


func has_editor_autosave() -> bool:
	return FilesManager.level_exists(cur_game_name, "editor_autosave")

func load_editor_autosave() -> void:
	if queued_level_load:
		return
	var autosave_data: Dictionary = FilesManager.get_level_data(cur_game_name, "editor_autosave")
	load_level_data(autosave_data)
	loaded_is_autosave = true

func load_level_data(level_data: Dictionary, process_queued_load: bool = false):
	if not process_queued_load and queued_level_load:
		return
	if process_queued_load and not queued_level_load:
		# it was cancelled
		return
	queued_level_load = false
	loaded_is_autosave = false
	current_level_is_museum = false
	loaded_level_name = level_data["name"]
	editor_save = level_data["state"]
	load_edited()
	close_pause_menu()

func try_load_next_level(with_delay: float = 0.5):
	if not MapManager.has_next_level() or queued_level_load:
		return
	
	var next_level_name: String = MapManager.get_metadata_value("next_level")
	var next_level_data: = FilesManager.get_level_data(cur_game_name, next_level_name)
	queued_level_load = true

	queued_level_load_timer = Timer.new()
	queued_level_load_timer.one_shot = true
	queued_level_load_timer.timeout.connect(load_level_data.bind(next_level_data, true))
	queued_level_load_timer.timeout.connect(queued_level_load_timer.queue_free)
	add_child(queued_level_load_timer)
	queued_level_load_timer.start(with_delay)

func cancel_queued_level_load() -> void:
	queued_level_load = false
	if queued_level_load_timer:
		queued_level_load_timer.stop()
		queued_level_load_timer.queue_free()
		queued_level_load_timer = null

func try_load_level(level_name: String):
	if not FilesManager.level_exists(cur_game_name, level_name) or queued_level_load:
		return
	var the_level_data: = FilesManager.get_level_data(cur_game_name, level_name)
	if not the_level_data["name"] == level_name:
		the_level_data["name"] = level_name
	load_level_data(the_level_data)

func new_empty_level():
	loaded_level_name = "LEVEL"
	current_level_is_museum = false
	EntityManager.clear()
	MapManager.clear()
	MapManager.create_plain_layer()
	EntityManager.create_defaults()
	
	save_edited()

func new_museum_level():
	loaded_level_name = "Museum"
	current_level_is_museum = true
	EntityManager.clear()
	MapManager.clear()
	
	var entity_museum_start_pos: = Vector2i(2, -1)
	var tile_museum_start_pos: = Vector2i(-2, -1)
	var museum_player_pos: = Vector2i(0, 0)
	var museum_spacing: = Vector2i(2, 2)

	var entity_museum_size: = EntityManager.create_museum(Vector2i(0, 0), entity_museum_start_pos, museum_spacing)

	var entity_museum: = Utility.rect2i_pos_inclusive_abs(Rect2i(entity_museum_start_pos, entity_museum_size))

	var tile_museum_spacing: = Vector2i(-museum_spacing.x, museum_spacing.y)
	MapManager.create_museum_layer(museum_player_pos, tile_museum_start_pos, tile_museum_spacing, [entity_museum])
	
	save_edited()

func load_random_level():
	EntityManager.clear()
	MapManager.create_random_layer()
	EntityManager.create_randoms()
	
	save_edited()

func change_scene(new_scene: String):
	if cur_scene != "Loading":
		show_scene_transition()
	
	if not new_scene in scenes:
		print("I dont know about scene " + new_scene)
		return
	
	if cur_scene == "Play":
		cancel_queued_level_load()
		transition_left = true
		if editor_save:
			loaded_level = editor_save
		EntityManager.clear()
		MapManager.clear()
		game_camera = null
		_unpause()
	elif cur_scene == "GameEditor":
		transition_left = false
		EntityManager.refresh_definition()
		MapManager.refresh_definition()
	
	if new_scene == "Play":
		transition_left = false
		SfxPlayer.refresh_game_sfx()
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
		EffectsHelper._fetch_effects_holder()
		if loaded_level:
			load_serialized_play_state(loaded_level)
		elif has_editor_autosave():
			if FilesManager.get_editor_autosave_is_newer(cur_game_name):
				GlobalToaster.show_toast_message("Loading autosave")
				load_editor_autosave()
			else:
				var autosave_level_name: String = FilesManager.get_editor_autosave_level_name(cur_game_name)
				if autosave_level_name:
					load_level_data(FilesManager.get_level_data(cur_game_name, autosave_level_name))
				else:
					GlobalToaster.show_toast_message("Loading autosave")
					load_editor_autosave()
		else:
			new_empty_level()
	scene_changed.emit(cur_scene)

func update_game_viewport() -> void:
	var vp = Utility.get_world().get_viewport()
	vp.aspect_expand = get_game_setting("auto_aspect", true)
	vp.set_resolution(get_base_window_size())

func rescale_window() -> void:
	if Engine.is_embedded_in_editor():
		return
	if OS.has_feature("web") or OS.has_feature("mobile"):
		return
	var window: = get_window()
	if window.mode == Window.MODE_FULLSCREEN or window.mode == Window.MODE_MAXIMIZED:
		prints("current window mode: ", window.mode)
		return
	
	var available_size: Vector2i = DisplayServer.screen_get_usable_rect().size
	var intended_size: = get_base_window_size() * get_default_pixel_scale()
	var decoration_size: = window.get_size_with_decorations() - window.size
	var intended_with_dec: = intended_size + Vector2(decoration_size)
	if intended_with_dec.x > available_size.x or intended_with_dec.y > available_size.y:
		var scale_factor: float = minf(available_size.x / intended_with_dec.x, available_size.y / intended_with_dec.y)
		intended_size = (intended_with_dec * scale_factor).floor() - Vector2(decoration_size)
	window.size = Vector2i(intended_size)

	window.move_to_center()

func toggle_pause_menu():
	if cur_scene != "Play":
		return
	
	var pause_menu = get_tree().get_nodes_in_group("PauseMenu")
	for p in pause_menu:
		p.toggle()

func close_pause_menu() -> void:
	var pause_menus: = get_tree().get_nodes_in_group("PauseMenu")
	for p in pause_menus:
		p.close_pause_menu()
	
func start_on_ready() -> bool:
	if TextureManager.im_ready and MapManager.im_ready and EntityManager.im_ready:
		
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
	
	if cur_scene == "Play":
		if Input.is_action_just_pressed(&"press_quicksave"):
			save_quicksave()
			GlobalToaster.show_toast_message("Quicksaved")
		elif Input.is_action_just_pressed(&"press_quickload"):
			if quicksave_state:
				load_quicksave()
				GlobalToaster.show_toast_message("Loaded quicksave")
			else:
				GlobalToaster.show_toast_message("No Quicksave")

func _unhandled_input(event: InputEvent) -> void:
	if Utility.fixed_just_pressed_by_event("escape", event):
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
	
	for special_prop_name in SPECIAL_PROPS:
		if not special_prop_name in prop_names:
			prop_names.append(special_prop_name)

	return prop_names

func get_tick_rate() -> int:
	return TICK_RATE

func get_full_tick_rate() -> int:
	return FULL_TICK_RATE

func get_is_half_tick_rate() -> bool:
	return TICK_RATE <= FULL_TICK_RATE / 2.0

func is_special_prop_name(prop_name: String) -> bool:
	return prop_name in SPECIAL_PROPS

func is_event_name(prop_name: String) -> bool:
	if prop_name.begins_with("when_signal_"):
		return true
	elif prop_name in ConditionalsV3.all_events:
		return true
	return false

func save_edited_level_as(as_level_filename: String) -> void:
	if not editor_save:
		return
	var level_data: = {}
	level_data["name"] = FilesManager.sanitize_level_filename(as_level_filename)
	level_data["state"] = editor_save
	
	var saved_successfully: = FilesManager.save_level(GameManager.cur_game_name, level_data)
	if saved_successfully:
		GlobalToaster.show_toast_message("Level Saved")
	else:
		GlobalToaster.show_toast_message("Failed to save level")
		return
	
	loaded_level_name = level_data["name"]
	loaded_is_autosave = false
	save_checkpoint()

func _get_textbox() -> Node:
	if not cur_scene == "Play":
		return null
	var textbox: Array[Node] = get_tree().get_nodes_in_group("TextBox")
	if not textbox:
		return null
	return textbox[0]

func show_the_textbox(with_text: String) -> void:
	var textbox: = _get_textbox()
	if textbox:
		textbox.show_with_text(with_text)

func dismiss_the_textbox() -> void:
	var textbox: = _get_textbox()
	if textbox:
		textbox.dismiss()

func set_live_edit_mode_enabled(new_is_enabled: bool) -> void:
	editor_live_edit_mode = new_is_enabled

func is_live_edit() -> bool:
	if current_level_is_museum:
		return true
	return editor_live_edit_mode

func is_entity_followed_by_camera(entity: BaseEntity) -> bool:
	if not game_camera:
		return false
	if game_camera.target_entity == entity:
		return true
	return false

func save_current_game_definition(copy_from_loaded_game: bool = true) -> void:
	var definition_data: = get_serialized_game_definition()
	var copy_from_game: = ""
	if copy_from_loaded_game and loaded_from_game_name and loaded_from_game_name != get_game_name():
		copy_from_game = loaded_from_game_name
	FilesManager.save_game_info(definition_data)
	loaded_from_game_name = get_game_name()

	if copy_from_game:
		FilesManager.copy_assets_and_levels_to(copy_from_game, get_game_name())

func save_current_game_definition_as(as_game_name: String, delete_on_overwrite: bool = false) -> void:
	if as_game_name == get_game_name() and is_current_game_resavable():
		save_current_game_definition(false)
		return

	if delete_on_overwrite and is_name_overwriting(as_game_name):
		if not FilesManager.delete_game(as_game_name):
			GlobalToaster.show_toast_message("Failed to overwrite game directory %s" % [FilesManager.get_game_dir_from_name(as_game_name)])
			return

	var copy_assets_and_levels_from: = ""
	if loaded_from_game_name and loaded_from_game_name != as_game_name:
		copy_assets_and_levels_from = loaded_from_game_name

	if not get_game_setting("title", ""):
		set_game_setting("title", get_game_implicit_title() + " (copy)")
	elif not get_game_setting("title", "").ends_with(" (copy)"):
		set_game_setting("title", get_game_setting("title", "") + " (copy)")
	save_current_game_definition()
	cur_game_name = as_game_name
	
	if copy_assets_and_levels_from:
		FilesManager.copy_assets_and_levels_to(copy_assets_and_levels_from, as_game_name)
	game_dir_name_changed.emit(cur_game_name)

func rename_and_save_current_game_definition(new_game_name: String, delete_on_overwrite: bool = false) -> bool:
	if not is_current_game_saved():
		_set_game_name(new_game_name)
		return false
	if FilesManager.is_game_name_equivalent(new_game_name, get_game_name()):
		_set_game_name(new_game_name)
		save_current_game_definition()
		return true
	
	if delete_on_overwrite and is_name_overwriting(new_game_name):
		if not FilesManager.delete_game(new_game_name):
			GlobalToaster.show_toast_message("Failed to overwrite game directory %s" % [FilesManager.get_game_dir_from_name(new_game_name)])
			return false

	var old_game_name: = get_game_name()
	if FilesManager.rename_game(old_game_name, new_game_name):
		_set_game_name(new_game_name)
		if FilesManager.get_default_game() == old_game_name:
			FilesManager.save_default_game(new_game_name)
	else:
		GlobalToaster.show_toast_message("Failed to move game directory")
		return false
	return true

func is_current_game_resavable() -> bool:
	return loaded_from_game_name == get_game_name()

func is_save_current_overwriting() -> bool:
	if is_current_game_resavable():
		return false
	return FilesManager.game_exists(get_game_name())

func is_name_overwriting(new_game_name: String) -> bool:
	if new_game_name == loaded_from_game_name:
		return false
	return FilesManager.game_exists(new_game_name)

func is_current_game_saved() -> bool:
	return loaded_from_game_name != ""

func import_and_load_game_zip(zip_file_path: String) -> bool:
	var imported_name: String = ImporterExporter.import_game_zip(zip_file_path, true)
	if not imported_name:
		return false
	load_game_definition_from_file(imported_name)
	return true

func got_web_import_zip(_file_name: String, _file_type: String, b64_data: String) -> void:
	var zip_byte_array: = Marshalls.base64_to_raw(b64_data)
	if import_and_load_game_zip_buffer(zip_byte_array):
		GlobalToaster.show_toast_message("Imported %s" % [get_game_name()])
	else:
		GlobalToaster.show_toast_message("Failed to import game")

func import_and_load_game_zip_buffer(zip_buffer: PackedByteArray) -> bool:
	var imported_name: String = ImporterExporter.import_game_zip(zip_buffer, true)
	if not imported_name:
		return false
	load_game_definition_from_file(imported_name)
	return true

func change_camera_follow_to_entity_name(entity_name: String) -> void:
	set_cam_setting("follow_entity", entity_name)
	set_cam_setting("follow_entity_by", "name")
	camera_refollow()

func change_camera_follow_to_entity_property(property_name: String) -> void:
	set_cam_setting("follow_entity", property_name)
	set_cam_setting("follow_entity_by", "property")
	camera_refollow()

func add_camera_follow_instance(instance_id: int) -> void:
	if get_cam_setting("follow_entity_by", "property") != "instance":
		set_camera_follow_instances([instance_id])
	else:
		var cur_instances: Array = get_cam_setting("follow_entity_instances", [])
		set_cam_setting("follow_entity_instances", cur_instances + [instance_id])

func set_camera_follow_instances(instances: Array) -> void:
	set_cam_setting("follow_entity_by", "instances")
	set_cam_setting("follow_entity_instances", instances)

func reset_camera_follow() -> void:
	reset_cam_setting("follow_entity")
	reset_cam_setting("follow_entity_by")
	camera_refollow()

func camera_refollow() -> void:
	game_camera.find_entity_to_follow()

func get_base_camera_setting(setting_name: String, default_value: Variant = null) -> Variant:
	return get_game_setting("camera_settings", {}).get(setting_name, default_value)

func get_cam_setting(setting_name: String, default_value: Variant = null) -> Variant:
	if not stateful_camera_settings.has(setting_name):
		return get_base_camera_setting(setting_name, default_value)
	return stateful_camera_settings[setting_name]

func set_cam_setting(setting_name: String, value: Variant) -> void:
	stateful_camera_settings[setting_name] = value

func reset_cam_setting(setting_name: String) -> void:
	stateful_camera_settings.erase(setting_name)

func reset_stateful_camera_settings() -> void:
	stateful_camera_settings = {}

func is_entity_current_camera_focus(entity: BaseEntity) -> bool:
	var current_camera_focus: BaseEntity = game_camera.target_entity
	if not current_camera_focus:
		return false
	return current_camera_focus.instance_id == entity.instance_id

func get_camera_focus_entity() -> BaseEntity:
	if not game_camera or not game_camera.active:
		return null
	return game_camera.target_entity

func get_next_prev_camera_focus(dir: int = 1) -> BaseEntity:
	var cur_focus: BaseEntity = get_camera_focus_entity()
	if not cur_focus:
		return null
	return game_camera.get_next_prev_follow_target(dir)

func show_credits() -> void:
	if not cur_scene == "Play":
		change_scene("Play")
		await scene_changed

	var creditses: Array[Node] = get_tree().get_nodes_in_group("Credits")
	for credits in creditses:
		if not credits is CreditsUI:
			push_warning("Node in Credits group is not a CreditsUI: %s" % credits.get_path())
			continue
		credits.show_credits()
		break

func get_special_prop_hint_text(prop_name: String) -> String:
	return SPECIAL_PROPS_HINT_TEXT.get(prop_name, "")

func get_sfx_definitions() -> Array:
	return game_definition.get("sfx_definitions", []).duplicate_deep()

func set_sfx_definitions(new_sfx_definitions: Array) -> void:
	game_definition["sfx_definitions"] = new_sfx_definitions.duplicate_deep()

func get_used_sfx_names() -> Array[String]:
	var used_sfx_names: Array[String] = []
	for sfx_definition in get_sfx_definitions():
		if not sfx_definition.get("name", ""):
			continue
		used_sfx_names.append(sfx_definition["name"])
	return used_sfx_names


func _get_level_list(level_list_name: String) -> Dictionary:
	for level_list_info in game_definition.get("level_lists", []):
		if level_list_info.get("name", "") == level_list_name:
			return level_list_info
	return {}

func _remove_level_from_all_lists(level_name: String) -> void:
	for level_list_info in game_definition.get("level_lists", []):
		level_list_info["level_names"].erase(level_name)

func _get_level_list_index(level_list_name: String) -> int:
	for i in game_definition.get("level_lists", []).size():
		if game_definition.get("level_lists", [])[i].get("name", "") == level_list_name:
			return i
	return -1

func has_any_unlocked_levels() -> bool:
	var total_unlocked_levels: int = 0
	for level_list_name in get_list_of_level_lists():
		total_unlocked_levels += get_unlocked_levels_in_level_list(level_list_name).size()
	return total_unlocked_levels > 0

func get_list_of_level_lists() -> Array:
	var ll_names: Array[String] = []
	for level_list_info in game_definition.get("level_lists", []):
		if not level_list_info.get("name", ""):
			continue
		ll_names.append(level_list_info["name"])
	return ll_names

func get_levels_in_level_list(level_list_name: String) -> Array:
	var level_list_info: = _get_level_list(level_list_name)
	var actual_level_names: = []
	for level_name in level_list_info.get("level_names", []):
		if FilesManager.level_exists(get_game_name(), level_name):
			actual_level_names.append(level_name)
	return actual_level_names

func is_level_list_unlocked(level_list_name: String) -> bool:
	var level_list_index: = _get_level_list_index(level_list_name)
	if level_list_index < 0:
		return false
	if level_list_index == 0:
		return true
	else:
		# Check if level list should be unlocked here
		return true

func get_unlocked_levels_in_level_list(level_list_name: String) -> Array:
	if not is_level_list_unlocked(level_list_name):
		return []
	var level_list_info: = _get_level_list(level_list_name)
	var existing_levels: = get_levels_in_level_list(level_list_name)
	if level_list_info.get("progressive_locked_levels", 0) > 0:
		return existing_levels.slice(0, level_list_info.get("progressive_locked_levels", 0))
	else:
		return existing_levels

func get_first_existing_level_from_list(level_list_name: String) -> String:
	var level_list_info: = _get_level_list(level_list_name)
	for level_name in level_list_info.get("level_names", []):
		if FilesManager.level_exists(get_game_name(), level_name):
			return level_name
	return ""

func get_starting_level_name() -> String:
	var lists: Array = get_list_of_level_lists()
	if lists.size() < 1:
		return ""
	return get_first_existing_level_from_list(lists[0])


func add_level_to_level_list(level_name: String, level_list_name: String) -> void:
	var level_list_info: = _get_level_list(level_list_name)
	if not level_list_info:
		return
	
	if not level_name in level_list_info.get("level_names", []):
		if not level_list_info.has("level_names"):
			level_list_info["level_names"] = []
		level_list_info["level_names"].append(level_name)

func move_level_to_level_list(level_name: String, level_list_name: String) -> void:
	_remove_level_from_all_lists(level_name)
	add_level_to_level_list(level_name, level_list_name)

func is_level_in_any_list(level_name: String) -> bool:
	for level_list_info in game_definition.get("level_lists", []):
		if level_name in level_list_info.get("level_names", []):
			return true
	return false


func get_next_level_in_list(level_list_name: String, after_level: String = "") -> String:
	var level_list_info: = _get_level_list(level_list_name)
	if not level_list_info or level_list_info.get("level_names", []).size() < 1:
		return ""

	var found: int = level_list_info["level_names"].find(after_level)
	if not after_level or found < 0:
		found = 0
	if found + 1 >= level_list_info["level_names"].size():
		return ""
	return level_list_info["level_names"][found + 1]


func get_auto_load_list_after_list(level_list_name: String) -> String:
	var level_list_info: = _get_level_list(level_list_name)
	if not level_list_info:
		return ""

	if not level_list_info.get("auto_next_list", ""):
		return level_list_info["auto_next_list"]
	elif level_list_info.get("list_complete_to_lvlselect", false):
		return ""
	var index_of: = _get_level_list_index(level_list_name)
	if index_of == game_definition.get("level_lists", []).size() - 1:
		return ""
	return game_definition.get("level_lists", [])[index_of + 1].get("name", "")


func get_next_level_to_auto_load() -> Array:
	if not current_level_list or not loaded_level_name:
		return []
	
	var level_list_info: = _get_level_list(current_level_list)
	if not level_list_info.get("auto_load_next", true):
		return []
	var next_level_in_list: = get_next_level_in_list(current_level_list, loaded_level_name)
	if next_level_in_list:
		return [current_level_list, next_level_in_list]

	var next_list_name: = get_auto_load_list_after_list(current_level_list)
	if not next_list_name or not is_level_list_unlocked(next_list_name):
		return []
	return [next_list_name, get_first_existing_level_from_list(next_list_name)]


func goto_level_in_level_list(level_list_name: String, level_name: String) -> void:
	if not cur_scene == "Play":
		return
	if is_in_level_edit_mode:
		return
	
	var level_list_info: = _get_level_list(level_list_name)
	if level_list_info:
		if not level_name in level_list_info.get("level_names", []):
			current_level_list = ""
		else:
			current_level_list = level_list_name
	else:
		current_level_list = ""
	
	try_load_level(level_name)


func advance_level() -> void:
	if cur_scene != "Play":
		return
	var adv_to_level_and_list: Array = get_advance_to_level_and_list()
	if not adv_to_level_and_list:
		return
	if adv_to_level_and_list[0] == "end":
		go_to_game_end()
	elif adv_to_level_and_list[0] == "select":
		go_to_level_select()
	else:
		goto_level_in_level_list(adv_to_level_and_list[0], adv_to_level_and_list[1])

func get_advance_to_level_and_list() -> Array:
	if not loaded_level_name or not current_level_list or current_level_is_museum:
		return []
	
	var next_auto_load_level: Array = get_next_level_to_auto_load()
	if next_auto_load_level:
		return next_auto_load_level
	
	if not has_any_unlocked_levels():
		return ["end", ""]
	else:
		return ["select", ""]
	
func has_level_advance() -> bool:
	if cur_scene != "Play":
		return false
	var adv_to_level_and_list: Array = get_advance_to_level_and_list()
	if adv_to_level_and_list.size() > 0:
		return true
	return false


func go_to_level_select() -> void:
	pass

func go_to_game_end() -> void:
	show_credits()