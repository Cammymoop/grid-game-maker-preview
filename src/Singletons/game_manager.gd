extends Node

signal level_state_loaded
signal any_state_loaded
signal game_camera_target_changed(entity: BaseEntity)
signal game_settings_changed
signal game_dir_name_changed(new_game_dir_name: String)
signal scene_changed(new_scene: String)
signal bg_style_changed
signal level_edit_mode_changed()

const CreditsUI = preload("res://Scenes/credits_ui.gd")

var MAX_UNDO_LIMIT: int = 1000

const FULL_TICK_RATE: int = 60
@onready var TICK_RATE: int = ProjectSettings.get_setting_with_override("physics/common/physics_ticks_per_second")

const MAX_LEVEL_TEXT_SIZE: int = 1000000

var started = false
var cur_scene = null

var player_profile: PlayerProfile = null

var cur_game_name: = ""
var loaded_from_game_name: = ""

var current_level_list: String = ""

var game_creators: Array[String] = []

var checkpoint_save: = {}
var editor_save: = {}
var loaded_level: = {}

var undo_stack: Array[Dictionary] = []
var undo_checkpoints: Dictionary[int, Dictionary] = {}
var undo_checkpoints_created: Dictionary[int, int] = {}
var next_undo_checkpoint_id: int = 0
var cur_undo_is_current_state: bool = false

var quicksave_state: = {}

var loaded_level_name: = ""
var loaded_level_is_saved: = false
var loaded_is_autosave: = false

var is_in_level_edit_mode: = true
var _state_load_is_start_of_level: = false

var loaded = false

var editor_live_edit_mode: = false
var current_level_is_museum: = false

var queued_level_load: bool = false
var queued_level_load_timer: Timer = null
var _queued_reload_for_lack_of_cam_target: bool = false

var file_access_web: RefCounted = null

var default_bg_style: Dictionary = {}

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
	"auto-bond", "auto-bond-adjacent", "auto-tail", "auto-scale",
	"die-when-blocked",
	"edit-place-multiple",
	"no-museum", "museum-active",
	"move-animation", "controller-disabled",
	"turn-animation",
	"actions-disabled",
	"no-rotate",
	"teleport-duration", "move-speed",
	"dying-effect",
]

const SPECIAL_PROPS_DEFAULTS: Dictionary[String, Variant] = {
	"z-index": 0,
	"move-turns": false,
	
	"auto-bond": true,
	"auto-bond-adjacent": true,
	
	"die-when-blocked": true,

	"move-animation": "smooth",
	"turn-animation": "none",
	
	"museum-active": false,
	"no-rotate": true,
	"teleport-duration": 0.5,
	"move-speed": 6,
	"dying-effect": "Real Explosion",
}

static var SPECIAL_PROPS_HINT_TEXT: Dictionary[String, String] = {
	"z-index": "Relative sorting offset, Entities or tiles with a higher sorting offset will be shown over others, can be negative.\nBy default entities are 5 higher than tiles.",
	"move-turns": "If false, the entity will not automatically turn it's facing direction to match it's moving direction when it moves.",
	"inherit-properties": "[Experimental] If true, the entity will inherit properties it does not have from another entity type with this name.",
	"auto-bond": "If true, this entity will automatically join a bond group with other entities of the same type when first created.\n" +
		"If set to the name of a property, will instead automatically bond with any other entity type with that property set. see also auto-bond-adjacent.",
	"auto-bond-adjacent": "If false, this entity will automatically bond with any entities based on auto-bond instead of only adjacent entities.",
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
	"dying-effect": "The default effect on this entity's sprite when it is destroyed. If set, overrides the game's default dying effect.\n" +
		"Available Effects: " + ", ".join(SpriteEffects.DYING_EFFECTS.keys()),
}

enum OneTimeMessages {
	IMPORTED_IMAGE_DISCLAIMER,
}
const ONE_TIME_MESSAGES_KEYS: Dictionary[OneTimeMessages, String] = {
	OneTimeMessages.IMPORTED_IMAGE_DISCLAIMER: "imported_image_disclaimer",
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
	#PuzzleScriptRNG.test_example()
	player_profile = ensure_basic_player_profile()
	# Automatically use the display scaling from the OS if it's detected, because of how the gameplay display auto scales this mainly affects UI
	var cur_screen_scale: float = DisplayServer.screen_get_scale()
	if cur_screen_scale != get_window().content_scale_factor:
		get_window().content_scale_factor = cur_screen_scale
	# run _process even when the game is paused
	process_mode = PROCESS_MODE_ALWAYS
	cur_scene = get_tree().current_scene.name
	FilesManager.init_folders()
	
	setup_default_bg_style()
	
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

func setup_default_bg_style() -> void:
	var customizable_bg: Node = preload("res://Scenes/bg_effect_6.tscn").instantiate()
	add_child(customizable_bg)
	default_bg_style = {
		"background_color": Utility.color_string_no_alpha(customizable_bg.default_bg_color),
		"bg_gradient_on": true,
		"bg_gradient_color": Utility.color_string(customizable_bg.default_bg_gradient_color, true),
		"bg_gradient_above": "below",

		"dusty_particles_on": true,
		"dusty_particles_amount": 1.0,
		"dusty_particles_speed": 1.0,
		"dusty_particles_color": Utility.color_string(customizable_bg.default_particles_color, true),
		
		"pointy_particles_on": false,
		"pointy_particles_amount": 1.0,
		"pointy_particles_speed": 1.0,
		"pointy_particles_rainbow_on": false,
		"pointy_particles_color": Utility.color_string(customizable_bg.default_pointy_particles_color, true),
		"pointy_particles_dark_mode": customizable_bg.pointy_particles_dark_mode,
		
		"lines_on": false,
		"lines_solid_on": false,
		"lines_color": Utility.color_string(customizable_bg.lines_color, true),
		"lines_solid_color": Utility.color_string(customizable_bg.lines_solid_color, true),
		"lines_scroll_speed": customizable_bg.lines_scroll_speed,
		"lines_scroll_angle": rad_to_deg(customizable_bg.lines_scroll_angle * TAU),
		"lines_warp_strength": customizable_bg.lines_warp_strength,
		"lines_warp_scroll_speed": customizable_bg.lines_warp_scroll_speed,
		"lines_warp_scroll_angle": rad_to_deg(customizable_bg.lines_warp_scroll_angle * TAU),
		"lines_above": "below",
	}
	remove_child(customizable_bg)
	customizable_bg.queue_free()

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

func put_all_existing_levels_into_single_level_list() -> void:
	var all_levels: = FilesManager.get_level_list(get_game_name())
	all_levels.erase("editor_autosave")
	game_definition["level_lists"] = [{
		"name": "Levels",
		"level_names": all_levels,
	}]

func load_game_definition_from_file(game_name) -> void:
	var definition = FilesManager.get_game_definition(game_name)
	load_game_definition_data(definition)

func load_game_definition_data(definition_data: Dictionary) -> void:
	game_definition = definition_data.duplicate_deep()
	_unmodified_game_definition = definition_data.duplicate_deep()
	is_in_level_edit_mode = false
	current_level_list = ""
	loaded_level_name = ""
	loaded_level_is_saved = false
	
	_set_game_name(definition_data['game_name'], false)
	loaded_from_game_name = cur_game_name
	
	if not definition_data.has("level_lists"):
		put_all_existing_levels_into_single_level_list()
	
	editor_save = {}
	loaded_level = {}
	clear_checkpoint()
	clear_quicksave()
	clear_undo_stack()
	
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
	
	if cur_scene != "Loading" and cur_scene != "Menu":
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
	
	if EntityManager.process_phase != 0:
		await get_tree().physics_frame

	deserialize(serialized_state.get("game_state", {}))
	MapManager.deserialize(serialized_state['map'])
	EntityManager.deserialize(serialized_state['entities'])
	
	if game_camera and (not is_in_level_edit_mode or game_camera.active):
		activate_gameplay_camera()
	
	if as_level_load:
		level_state_loaded.emit()
		clear_undo_stack()
		push_undo_state(true)

	any_state_loaded.emit()

	bg_style_changed.emit()
	_state_load_is_start_of_level = false

func deserialize(serialized_state: Dictionary) -> void:
	stateful_camera_settings = serialized_state.get("stateful_camera_settings", {}).duplicate_deep()
	if "camera_position" in serialized_state:
		if not is_in_level_edit_mode:
			var game_camera_to: Vector2 = Utility.get_vector2_from_arr(serialized_state.get("camera_position", [0, 0]))
			position_gameplay_camera(game_camera_to)

func create_game_camera() -> void:
	var cam = cameras["SimpleCamera"].instantiate()
	Utility.get_world().add_child(cam)
	game_camera = cam
	game_camera.camera_target_changed.connect(on_game_camera_target_changed)
	game_camera.no_more_targets.connect(on_no_more_camera_targets)

func on_no_more_camera_targets() -> void:
	if is_in_level_edit_mode or not editor_save:
		return
	if get_game_setting("auto_reload_checkpoint_for_no_cam_focus", false):
		queue_delayed_other_load(0.5, _reload_for_lack_of_cam_target)
		_queued_reload_for_lack_of_cam_target = true

func on_game_camera_target_changed(entity: BaseEntity) -> void:
	if entity and _queued_reload_for_lack_of_cam_target:
		cancel_queued_level_load()
	game_camera_target_changed.emit(entity)

func _reload_for_lack_of_cam_target() -> void:
	queued_level_load = false
	_queued_reload_for_lack_of_cam_target = false
	load_checkpoint()

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
	if cur_undo_is_current_state and undo_stack.size() > 1:
		undo_stack.pop_back()
	push_undo_state(true, checkpoint_save.duplicate_deep())
func load_checkpoint() -> void:
	if not checkpoint_save:
		if editor_save:
			_state_load_is_start_of_level = true
			load_serialized_play_state(editor_save, false)
			push_undo_state(true)
		else:
			push_error("cannot load level or checkpoint")
		return
	load_serialized_play_state(checkpoint_save, false)
	push_undo_state(true)

func clear_checkpoint() -> void:
	checkpoint_save = {}

func save_edited() -> void:
	editor_save = get_serialized_play_state()
	clear_checkpoint()
func load_edited(as_level_load: bool = true, as_start_of_level: bool = false) -> void:
	if as_level_load:
		as_start_of_level = true
	_state_load_is_start_of_level = as_start_of_level
	load_serialized_play_state(editor_save, as_level_load)
	clear_checkpoint()
	if not as_level_load:
		push_undo_state(true)

func save_quicksave() -> void:
	quicksave_state = {
		"level_state": get_serialized_play_state(),
		"level_name": loaded_level_name,
		"level_list": current_level_list,
		"checkpoint_state": {},
	}
	if checkpoint_save:
		quicksave_state["checkpoint_state"] = checkpoint_save.duplicate_deep()
func load_quicksave() -> void:
	if not quicksave_state:
		return
	var quicksave_level_name: String = quicksave_state.get("level_name", "")
	var quicksave_level_list: String = quicksave_state.get("level_list", "")
	var changing_levels: = false
	if not quicksave_level_name or quicksave_level_name != loaded_level_name:
		changing_levels = true
	elif current_level_list and quicksave_level_list and current_level_list != quicksave_level_list:
		changing_levels = true

	loaded_level_name = quicksave_level_name
	current_level_list = quicksave_level_list
	load_serialized_play_state(quicksave_state["level_state"], changing_levels)
	if changing_levels:
		if FilesManager.level_exists(cur_game_name, quicksave_level_name):
			loaded_level_is_saved = true
			var level_data: = FilesManager.get_level_data(cur_game_name, quicksave_level_name)
			if level_data:
				editor_save = level_data["state"]
			else:
				editor_save = {}
		else:
			editor_save = {}
	else:
		clear_undo_stack()
		push_undo_state(false)
	
	if quicksave_state.get("checkpoint_state", {}):
		checkpoint_save = quicksave_state["checkpoint_state"].duplicate_deep()
	else:
		checkpoint_save = {}
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
	loaded_level_is_saved = false
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
	load_edited(true)
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

func queue_delayed_goto_level(with_delay: float, level_code: String) -> void:
	if with_delay <= 0:
		push_error("Trying to queue a delayed level load with no delay")
	if queued_level_load:
		cancel_queued_level_load()
	
	queued_level_load = true
	queued_level_load_timer = Timer.new()
	queued_level_load_timer.one_shot = true
	queued_level_load_timer.timeout.connect(goto_level_code.bind(level_code, true))
	queued_level_load_timer.timeout.connect(queued_level_load_timer.queue_free)
	add_child(queued_level_load_timer)
	queued_level_load_timer.start(with_delay)

func queue_delayed_other_load(with_delay: float, callback: Callable) -> void:
	if with_delay <= 0:
		push_error("Trying to queue a delayed other load with no delay")
	if queued_level_load:
		cancel_queued_level_load()
	
	queued_level_load = true
	queued_level_load_timer = Timer.new()
	queued_level_load_timer.one_shot = true
	queued_level_load_timer.timeout.connect(callback)
	queued_level_load_timer.timeout.connect(queued_level_load_timer.queue_free)
	add_child(queued_level_load_timer)
	queued_level_load_timer.start(with_delay)

func cancel_queued_level_load() -> void:
	queued_level_load = false
	_queued_reload_for_lack_of_cam_target = false
	if queued_level_load_timer:
		queued_level_load_timer.stop()
		queued_level_load_timer.queue_free()
		queued_level_load_timer = null

func try_load_level(level_name: String, as_queued_load: bool = false):
	if not FilesManager.level_exists(cur_game_name, level_name) or (not as_queued_load and queued_level_load):
		return
	var the_level_data: = FilesManager.get_level_data(cur_game_name, level_name)
	if not the_level_data["name"] == level_name:
		the_level_data["name"] = level_name
	load_level_data(the_level_data, as_queued_load)

func edit_level_named(level_name: String) -> bool:
	if not FilesManager.level_exists(cur_game_name, level_name):
		push_error("Level %s does not exist" % [level_name])
		return false
	var the_level_data: = FilesManager.get_level_data(cur_game_name, level_name)
	if not the_level_data["name"] == level_name:
		the_level_data["name"] = level_name
	current_level_list = get_list_containing_level(level_name)
	load_level_data(the_level_data)
	return true

func edit_level_in_list(level_list_name: String, level_name: String) -> void:
	var level_lists: = get_list_of_level_lists()
	if not level_list_name in level_lists:
		push_error("Level list %s does not exist" % [level_list_name])
		return

	var was_level_list: = current_level_list
	current_level_list = level_list_name
	if not edit_level_named(level_name):
		current_level_list = was_level_list

func cleanup_new_level() -> void:
	clear_checkpoint()
	clear_undo_stack()

func new_empty_level():
	loaded_level_name = ""
	loaded_level_is_saved = false
	current_level_is_museum = false
	EntityManager.clear()
	MapManager.clear()
	MapManager.create_plain_layer()
	EntityManager.create_defaults()
	
	cleanup_new_level()
	new_level_edited_state_and_emit()
	
func new_level_edited_state_and_emit() -> void:
	save_edited()
	level_state_loaded.emit()
	any_state_loaded.emit()

func new_museum_level():
	loaded_level_name = "Museum"
	loaded_level_is_saved = false
	current_level_is_museum = true
	EntityManager.clear()
	MapManager.clear()
	
	cleanup_new_level()
	
	var entity_museum_start_pos: = Vector2i(2, -1)
	var tile_museum_start_pos: = Vector2i(-2, -1)
	var museum_player_pos: = Vector2i(0, 0)
	var museum_spacing: = Vector2i(2, 2)

	var entity_museum_size: = EntityManager.create_museum(Vector2i(0, 0), entity_museum_start_pos, museum_spacing)

	var entity_museum: = Utility.rect2i_pos_inclusive_abs(Rect2i(entity_museum_start_pos, entity_museum_size))

	var tile_museum_spacing: = Vector2i(-museum_spacing.x, museum_spacing.y)
	MapManager.create_museum_layer(museum_player_pos, tile_museum_start_pos, tile_museum_spacing, [entity_museum])
	
	MapManager.set_level_subtitle("Auto-generated showcase")
	
	new_level_edited_state_and_emit()

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
		EffectsHelper._fetch_effects_holder()
		if is_in_level_edit_mode:
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
		else:
			play_current_save_level()
			#play_first_level()
		if not is_in_level_edit_mode:
			activate_gameplay_camera()
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

func open_pause_menu() -> void:
	if get_pause("pause_menu"):
		return
	var pause_menus: = get_tree().get_nodes_in_group("PauseMenu")
	for p in pause_menus:
		if p.active:
			continue
		p.toggle()
		break
	
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
				if queued_level_load:
					cancel_queued_level_load()
				load_quicksave()
				GlobalToaster.show_toast_message("Loaded quicksave")
			else:
				GlobalToaster.show_toast_message("No Quicksave")
		elif Input.is_action_just_pressed(&"reload_checkpoint"):
			if not get_tree().paused:
				if _queued_reload_for_lack_of_cam_target:
					cancel_queued_level_load()
				load_checkpoint()

func _unhandled_input(event: InputEvent) -> void:
	if Utility.event_is_menu_back_just_pressed(event):
		if cur_scene == "Play":
			toggle_pause_menu()
			get_viewport().set_input_as_handled()

func get_all_used_prop_names(include_events: bool = true, include_special_props: bool = true) -> Array[String]:
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
				if not include_events and is_event_name(prop_name):
					continue
				if not include_special_props and is_special_prop_name(prop_name):
					continue
				prop_names.append(prop_name)
	
	if include_special_props:
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

func get_edited_as_level_data() -> Dictionary:
	if not editor_save:
		push_error("No level to get level data of")
		return {}
	var level_name: = loaded_level_name if loaded_level_name else level_data_get_title(editor_save, "");
	if not level_name:
		level_name = Utility.random_animal()
	return get_play_state_as_level_data(editor_save, level_name)

func get_play_state_as_level_data(serialized_play_state: Dictionary, level_name: String = "") -> Dictionary:
	if not serialized_play_state:
		return {}
	if not level_name:
		level_name = loaded_level_name
	if not level_name:
		push_error("No level name provided")
		return {}
	level_name = FilesManager.sanitize_level_filename(level_name)

	var level_data: = {
		"name": level_name,
		"state": serialized_play_state.duplicate_deep(),
	}
	return level_data

func save_edited_level_as(as_level_filename: String) -> void:
	if not editor_save:
		return
	var level_data: = get_play_state_as_level_data(editor_save, as_level_filename)
	if not level_data:
		return
	
	var saved_successfully: = FilesManager.save_level(GameManager.cur_game_name, level_data)
	if saved_successfully:
		GlobalToaster.show_toast_message("Level Saved")
	else:
		GlobalToaster.show_toast_message("Failed to save level")
		return
	
	loaded_level_name = level_data["name"]
	loaded_level_is_saved = true
	loaded_is_autosave = false
	current_level_is_museum = false
	clear_checkpoint()

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
		loaded_from_game_name = get_game_name()
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

func import_and_load_game_zip(zip_file_path: String) -> void:
	var w_images_disabled: bool = is_one_time_message_dismissed(OneTimeMessages.IMPORTED_IMAGE_DISCLAIMER)
	_import_and_load_game_zip(zip_file_path, w_images_disabled, after_import_game_zip_message)

func _import_and_load_game_zip(zip_file_path: String, w_images_confirmed: bool, then_callable: Callable) -> void:
	if not w_images_confirmed:
		if ImportZipExtractor.zip_has_bundled_images(zip_file_path):
			check_and_show_imported_image_disclaimer(_import_and_load_game_zip.bind(zip_file_path, true, then_callable))
	var imported_name: String = ImporterExporter.import_game_zip(zip_file_path, true)
	var success: bool = true
	if not imported_name:
		success = false
	else:
		load_game_definition_from_file(imported_name)

	if then_callable.is_valid():
		then_callable.call(success)

func after_import_game_zip_message(success: bool) -> void:
	if success:
		GlobalToaster.show_toast_message("Imported %s" % [get_game_name()])
	else:
		GlobalToaster.show_toast_message("Failed to import game")

func got_web_import_zip(_file_name: String, _file_type: String, b64_data: String) -> void:
	var zip_byte_array: = Marshalls.base64_to_raw(b64_data)
	var w_images_disabled: bool = is_one_time_message_dismissed(OneTimeMessages.IMPORTED_IMAGE_DISCLAIMER)
	import_and_load_game_zip_buffer(zip_byte_array, w_images_disabled, after_import_game_zip_message)

func import_and_load_game_zip_buffer(zip_buffer: PackedByteArray, w_images_confirmed: bool = false, then_callable: Callable = Callable()) -> void:
	if not w_images_confirmed:
		var zip_has_bundled_images: bool = ImportZipExtractor.zip_or_buffer_has_bundled_images(zip_buffer)
		if zip_has_bundled_images:
			check_and_show_imported_image_disclaimer(import_and_load_game_zip_buffer.bind(zip_buffer, true, then_callable))
	var imported_name: String = ImporterExporter.import_game_zip(zip_buffer, true)
	if not imported_name:
		if then_callable.is_valid():
			then_callable.call(false)
		return
	load_game_definition_from_file(imported_name)
	if then_callable.is_valid():
		then_callable.call(true)

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
	if not cur_scene == "Play" or not game_camera or not game_camera.active:
		return false
	var current_camera_focus: BaseEntity = get_camera_focus_entity()
	if not current_camera_focus:
		return false
	return current_camera_focus.instance_id == entity.instance_id

func get_camera_focus_entity() -> BaseEntity:
	if not game_camera or not game_camera.active:
		return null
	if not game_camera.target_entity or not is_instance_valid(game_camera.target_entity):
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

func remove_level_list(level_list_name: String) -> void:
	if not game_definition.get("level_lists", []):
		return
	var level_list_index: = _get_level_list_index(level_list_name)
	if level_list_index < 0:
		return
	game_definition["level_lists"].remove_at(level_list_index)

func add_level_list(level_list_name: String) -> void:
	if not game_definition.get("level_lists", []):
		game_definition["level_lists"] = []
	game_definition["level_lists"].append({
		"name": level_list_name,
		"level_names": [],
	})

func add_level_list_with_info(level_list_name: String, level_list_info: Dictionary) -> void:
	if not level_list_name:
		return
	if not game_definition.get("level_lists", []):
		game_definition["level_lists"] = []
	if not level_list_info.get("name", "") == level_list_name:
		level_list_info["name"] = level_list_name
	game_definition["level_lists"].append(level_list_info.duplicate_deep())

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
		var list_info: = _get_level_list(level_list_name)
		if list_info.get("default_locked", false):
			return _is_level_list_unlocked_in_save(level_list_name)
		else:
			return true

func unlock_level_in_list(level_list_name: String, level_name: String) -> void:
	if not level_list_name:
		var list_of_level: String = get_list_containing_level(level_name)
		if not list_of_level:
			return
		level_list_name = list_of_level
	var level_list_info: = _get_level_list(level_list_name)
	if not level_list_info:
		return
	if not level_name in level_list_info.get("level_names", []):
		return
	if level_list_info.get("default_locked", false):
		_unlock_level_list(level_list_name)
	_unlock_level_code(_level_code(level_list_name, level_name))

func _unlock_level_list(level_list_name: String) -> void:
	var unlocked_lists: Array = get_game_save_data("unlocked_lists", [])
	if level_list_name in unlocked_lists:
		return
	unlocked_lists.append(level_list_name)
	set_game_save_data("unlocked_lists", unlocked_lists)

func _unlock_level_code(level_code: String) -> void:
	var unlocked_codes: Array = get_game_save_data("unlocked_level_codes", [])
	if level_code in unlocked_codes:
		return
	unlocked_codes.append(level_code)
	set_game_save_data("unlocked_level_codes", unlocked_codes)

func _is_level_list_unlocked_in_save(level_list_name: String) -> bool:
	var unlocked_lists: Array = get_game_save_data("unlocked_lists", [])
	return level_list_name in unlocked_lists

func get_unlocked_levels_in_level_list(level_list_name: String) -> Array:
	if not is_level_list_unlocked(level_list_name):
		return []
	var level_list_info: = _get_level_list(level_list_name)
	var existing_levels: = get_levels_in_level_list(level_list_name)
	var prog_unlock_num: int = level_list_info.get("progressive_locked_levels", 0)
	
	var default_locked: bool = level_list_info.get("default_individual_locked", false)

	var all_completed_levels: Array = get_game_save_data("completed_levels", [])
	var unlocked_levels: Array = []
	var max_completed_idx: int = -1
	for idx in existing_levels.size():
		if not _level_code(level_list_name, existing_levels[idx]) in all_completed_levels:
			continue
		max_completed_idx = idx

	for idx in existing_levels.size():
		if prog_unlock_num > 0 and max_completed_idx + prog_unlock_num >= idx:
			unlocked_levels.append(existing_levels[idx])
		elif not default_locked or _is_level_code_unlocked_in_save(_level_code(level_list_name, existing_levels[idx])):
			unlocked_levels.append(existing_levels[idx])
	return unlocked_levels

func _is_level_code_unlocked_in_save(level_code: String) -> bool:
	var unlocked_codes: Array = get_game_save_data("unlocked_level_codes", [])
	return level_code in unlocked_codes

func get_list_of_unlisted_levels() -> Array:
	var all_level_lists: Array = get_list_of_level_lists()
	var all_listed_levels: Array = []
	for level_list_name in all_level_lists:
		all_listed_levels.append_array(get_levels_in_level_list(level_list_name))
	
	var all_levels: Array = FilesManager.get_level_list(get_game_name())
	var unlisted_levels: Array = []
	for level_name in all_levels:
		if not level_name in all_listed_levels:
			unlisted_levels.append(level_name)
	return unlisted_levels


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

func get_starting_level_and_list() -> Array:
	var first_level_name: String = get_starting_level_name()
	var l_lists: = get_list_of_level_lists()
	if not l_lists:
		return []
	var first_level_list: String = l_lists[0]
	if not first_level_name or not first_level_list:
		return []
	return [first_level_list, first_level_name]


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

func get_list_containing_level(level_name: String) -> String:
	for level_list_info in game_definition.get("level_lists", []):
		if level_name in level_list_info.get("level_names", []):
			return level_list_info["name"]
	return ""


func remove_level_from_list(level_name: String, level_list_name: String) -> void:
	var level_list_info: = _get_level_list(level_list_name)
	if level_list_info:
		level_list_info["level_names"].erase(level_name)


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


func get_auto_load_list_after_list(level_list_name: String, current_level_as_complete: bool = false) -> String:
	var level_list_info: = _get_level_list(level_list_name)
	if not level_list_info:
		return ""

	if level_list_info.get("auto_next_list", ""):
		return level_list_info["auto_next_list"]
	elif level_list_info.get("list_complete_to_lvlselect", false):
		return ""
	var unlocked_lists: Array = get_all_unlocked_level_lists(current_level_as_complete)
	var unlocked_lists_names: Array = []
	for unlocked_list in unlocked_lists:
		unlocked_lists_names.append(unlocked_list["name"])
	if unlocked_lists_names.size() <= 1:
		return ""
	var index_of: = unlocked_lists_names.find(level_list_name)
	if index_of == -1:
		return unlocked_lists_names[0]
	elif index_of == unlocked_lists_names.size() - 1:
		return ""
	return unlocked_lists_names[index_of + 1]

func get_all_unlocked_level_lists(_current_level_as_complete: bool = false) -> Array:
	var lists: Array = []
	for level_list_info in game_definition.get("level_lists", []):
		if not level_list_info.get("name", "") or not level_list_info.get("level_names", []):
			continue
		if is_level_list_unlocked(level_list_info["name"]):
			lists.append(level_list_info)
	return lists

func level_list_has_next(level_list_name: String) -> bool:
	var total_lists: int = game_definition.get("level_lists", []).size()
	var level_list_index: = _get_level_list_index(level_list_name)
	return level_list_index < total_lists - 1

func level_list_has_previous(level_list_name: String) -> bool:
	var level_list_index: = _get_level_list_index(level_list_name)
	return level_list_index > 0

func move_level_to_relative_list(level_name: String, level_list_name: String, delta: int) -> void:
	var list_index: = _get_level_list_index(level_list_name)
	if list_index < 0:
		return
	var total_lists: int = game_definition.get("level_lists", []).size()
	var to_index: = clampi(list_index + delta, 0, total_lists - 1)
	if to_index == list_index:
		return
	remove_level_from_list(level_name, level_list_name)
	add_level_to_level_list(level_name, game_definition.get("level_lists", [])[to_index]["name"])

func add_level_to_list_index(level_name: String, to_index: int) -> void:
	var all_level_lists: Array = get_list_of_level_lists()
	if to_index < 0 or to_index >= all_level_lists.size():
		return
	add_level_to_level_list(level_name, _get_level_list(all_level_lists[to_index])["name"])


func get_next_level_to_auto_load(after_level: String = "", current_level_as_complete: bool = false) -> Array:
	if not after_level:
		after_level = loaded_level_name
	if not current_level_list or not after_level:
		return []
	
	var level_list_info: = _get_level_list(current_level_list)
	if not level_list_info.get("auto_load_next", true):
		return []
	var next_level_in_list: = get_next_level_in_list(current_level_list, after_level)
	if next_level_in_list:
		return [current_level_list, next_level_in_list]

	var next_list_name: = get_auto_load_list_after_list(current_level_list, current_level_as_complete)
	if not next_list_name or not is_level_list_unlocked(next_list_name):
		return []
	return [next_list_name, get_first_existing_level_from_list(next_list_name)]


func _level_code(level_list_name: String, level_name: String) -> String:
	return level_list_name + "??" + level_name

func _level_list_from_code(level_code: String) -> String:
	return level_code.split("??")[0]

func _level_name_from_code(level_code: String) -> String:
	return level_code.split("??")[1]

func goto_level_code(level_code: String, as_queued_load: bool = false) -> void:
	goto_level_in_level_list(_level_list_from_code(level_code), _level_name_from_code(level_code), as_queued_load)

func goto_level_in_level_list(level_list_name: String, level_name: String, as_queued_load: bool = false) -> void:
	if not cur_scene == "Play":
		push_error("goto level not in play scene")
		return
	if is_in_level_edit_mode:
		return
	
	var level_code: String = _level_code(level_list_name, level_name)
	var played_levels: Array = get_game_save_data("played_levels", [])
	if not level_code in played_levels:
		played_levels.append(level_code)
		set_game_save_data("played_levels", played_levels)
	
	set_game_save_data("last_played_level", level_code)
	
	var level_list_info: = _get_level_list(level_list_name)
	if level_list_info:
		if not level_name in level_list_info.get("level_names", []):
			current_level_list = ""
		else:
			current_level_list = level_list_name
	else:
		current_level_list = ""
	
	try_load_level(level_name, as_queued_load)


func _complete_level(level_list_name: String, level_name: String) -> void:
	if is_in_level_edit_mode:
		return
	var level_code: String = _level_code(level_list_name, level_name)
	var completed_levels: Array = get_game_save_data("completed_levels", [])
	if not level_code in completed_levels:
		completed_levels.append(level_code)
		set_game_save_data("completed_levels", completed_levels)

# Complete the current level in the current list and persist any pending dependant save file values
func complete_current_level() -> void:
	if is_in_level_edit_mode or not loaded_level_name:
		return
	
	var complete_in_list: String = current_level_list
	var list_of_loaded_level: String = get_list_containing_level(loaded_level_name)
	if not complete_in_list and list_of_loaded_level:
		complete_in_list = list_of_loaded_level
	_complete_level(complete_in_list, loaded_level_name)
	MapManager.flush_save_persist_on_completion()


func advance_level(with_delay: float = 0, with_complete_current_level: bool = true) -> void:
	if cur_scene != "Play" or is_in_level_edit_mode:
		return
	if with_complete_current_level:
		complete_current_level()
	var adv_to_level_and_list: Array = get_advance_to_level_and_list()
	if not adv_to_level_and_list:
		return
	if adv_to_level_and_list[0] == "end":
		go_to_game_end(with_delay)
	elif adv_to_level_and_list[0] == "select":
		go_to_level_select(with_delay)
	else:
		var level_code: String = _level_code(adv_to_level_and_list[0], adv_to_level_and_list[1])
		_move_to_code_with_delay(level_code, with_delay)

func move_to_level(level_list_name: String, level_name: String, with_delay: float = 0) -> void:
	if cur_scene != "Play" or is_in_level_edit_mode:
		return
	var level_code: String = _level_code(level_list_name, level_name)
	_move_to_code_with_delay(level_code, with_delay)

func move_to_level_list_start(level_list_name: String, with_delay: float = 0) -> void:
	if cur_scene != "Play" or is_in_level_edit_mode:
		return
	var list_info: = _get_level_list(level_list_name)
	if not list_info or list_info.get("level_names", []).size() < 1:
		return
	var level_code: String = _level_code(level_list_name, list_info.get("level_names", [])[0])
	_move_to_code_with_delay(level_code, with_delay)

func _move_to_code_with_delay(level_code: String, with_delay: float) -> void:
	if with_delay <= 0:
		goto_level_code(level_code)
	else:
		set_game_save_data("last_played_level", level_code)
		queue_delayed_goto_level(with_delay, level_code)


func set_last_played_level_as_next_advance_to() -> void:
	var adv_to_level_and_list: Array = get_advance_to_level_and_list()
	if not adv_to_level_and_list or not adv_to_level_and_list[1]:
		return
	var adv_to_code: = _level_code(adv_to_level_and_list[0], adv_to_level_and_list[1])
	set_game_save_data("last_played_level", adv_to_code)

func get_advance_to_level_and_list(with_current_level_as_complete: bool = false) -> Array:
	if not loaded_level_name or not current_level_list or current_level_is_museum:
		return []
	
	var next_auto_load_level: Array = get_next_level_to_auto_load("", with_current_level_as_complete)
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


func go_to_level_select(with_delay: float = 0) -> void:
	if with_delay > 0:
		queue_delayed_other_load(with_delay, go_to_level_select)
		return

	if cur_scene != "Play":
		return
	if get_pause("pause_menu"):
		close_pause_menu()
	var level_select_root = Utility.get_level_select_root()
	level_select_root.open_level_select()

func go_to_game_end(with_delay: float = 0) -> void:
	if with_delay <= 0:
		show_credits()
	else:
		queue_delayed_other_load(with_delay, show_credits)

func start_playing(in_level_edit_mode: bool = false) -> void:
	if cur_scene == "Play":
		return
	is_in_level_edit_mode = in_level_edit_mode
	change_scene("Play")

func play_first_level() -> void:
	if is_in_level_edit_mode:
		push_warning("Trying to call play_first_level in level edit mode")
		return
	var first_level_and_list: Array = get_starting_level_and_list()
	if not first_level_and_list:
		push_warning("no first level and list, creating empty level")
		new_empty_level()
		return
	goto_level_in_level_list(first_level_and_list[0], first_level_and_list[1])

func play_current_save_level() -> void:
	if is_in_level_edit_mode:
		return
	var cur_save_level: String = get_game_save_data("last_played_level", "")
	if not cur_save_level:
		play_first_level()
		return
	goto_level_in_level_list(_level_list_from_code(cur_save_level), _level_name_from_code(cur_save_level))


func get_new_player_profile() -> PlayerProfile:
	return FilesManager.create_player_profile(FilesManager.get_available_player_id())

func load_player_profile(player_id: String) -> PlayerProfile:
	return FilesManager.get_player_profile(player_id)

func ensure_basic_player_profile() -> PlayerProfile:
	var profile_list: Array = FilesManager.get_player_profile_list()
	if profile_list.size() < 1:
		return get_new_player_profile()
	return load_player_profile(profile_list[0])

func get_game_save_data(data_key: String, default_value: Variant = null) -> Variant:
	if not player_profile:
		EngineDebugger.debug()
		push_error("No player profile loaded")
		return default_value
	if not get_game_name():
		push_warning("Trying to get game save data but no current game")
		return default_value
	return player_profile.get_game_save_data(get_game_name(), data_key, default_value)

func set_game_save_data(data_key: String, value: Variant, flush: bool = true) -> void:
	if not player_profile:
		EngineDebugger.debug()
		push_error("No player profile loaded")
		return
	if not get_game_name():
		push_warning("Trying to set game save data but no current game")
		return
	player_profile.set_game_save_data(get_game_name(), data_key, value, flush)


func get_game_bg_info() -> Dictionary:
	var game_bg_info: Dictionary = get_game_setting("bg_style", {})
	return game_bg_info.merged(default_bg_style)

# get current background style, inheriting missing keys if necessary
func get_current_bg_info() -> Dictionary:
	if cur_scene != "Play":
		return get_game_bg_info()

	var game_bg_info: Dictionary = get_game_bg_info().duplicate_deep()
	var level_list_bg_info: Dictionary = {}
	var level_select_root: = Utility.get_level_select_root()
	if is_in_level_edit_mode and level_select_root and level_select_root.visible:
		var level_select_ui = level_select_root.level_select_ui
		if level_select_ui.editing_level_list:
			var list_info: = _get_level_list(level_select_ui.editing_level_list)
			if list_info.get("bg_style", {}):
				level_list_bg_info = list_info["bg_style"].duplicate_deep()
	if not level_list_bg_info and current_level_list:
		var list_info: = _get_level_list(current_level_list)
		if list_info.get("bg_style", {}):
			level_list_bg_info = list_info["bg_style"].duplicate_deep()
	level_list_bg_info.merge(game_bg_info)
	if MapManager.has_metadata_value("bg_style"):
		return MapManager.get_metadata_value("bg_style").merged(level_list_bg_info)
	else:
		return level_list_bg_info

func set_level_bg_info(bg_info: Dictionary) -> void:
	if not editor_save:
		return
	MapManager.set_metadata_value("bg_style", bg_info)
	bg_style_changed.emit()

func _set_game_bg_info_value(key: String, value: Variant) -> void:
	game_definition["game_settings"]["bg_style"][key] = value

func set_game_bg_info_value(key: String, value: Variant) -> void:
	if not "bg_style" in game_definition["game_settings"]:
		set_game_setting("bg_style", {})
	_set_game_bg_info_value(key, value)

func set_level_bg_info_value(key: String, value: Variant) -> void:
	if not MapManager.has_metadata_value("bg_style"):
		copy_current_bg_to_level()
	var level_bg_info: Variant = MapManager.get_metadata_value("bg_style")
	if not level_bg_info:
		level_bg_info = {}
	level_bg_info[key] = value
	MapManager.set_metadata_value("bg_style", level_bg_info)
	bg_style_changed.emit()

func set_level_list_bg_info_value(level_list_name: String, key: String, value: Variant) -> void:
	var level_list_info: = _get_level_list(level_list_name)
	if not level_list_info:
		return
	if not "bg_style" in level_list_info:
		copy_game_bg_to_level_list(level_list_name)
	level_list_info["bg_style"][key] = value
	bg_style_changed.emit()

func remove_current_level_custom_bg_info() -> void:
	if cur_scene != "Play":
		return
	if MapManager.has_metadata_value("bg_style"):
		MapManager.remove_metadata_value("bg_style")
		bg_style_changed.emit()

func remove_level_list_custom_bg_info(level_list_name: String) -> void:
	var level_list_info: = _get_level_list(level_list_name)
	if not level_list_info:
		return
	if "bg_style" in level_list_info:
		level_list_info.erase("bg_style")
		bg_style_changed.emit()

func remove_current_bg_override() -> void:
	if cur_scene != "Play":
		return
	var level_select_root: = Utility.get_level_select_root()
	if level_select_root and level_select_root.visible:
		var level_select_ui = level_select_root.level_select_ui
		if level_select_ui.editing_level_list:
			remove_level_list_custom_bg_info(level_select_ui.editing_level_list)
	else:
		remove_current_level_custom_bg_info()

func current_has_bg_info() -> bool:
	if cur_scene != "Play":
		return false
	var level_select_root: = Utility.get_level_select_root()
	if level_select_root and level_select_root.visible:
		var level_select_ui = level_select_root.level_select_ui
		if level_select_ui.editing_level_list:
			var list_info: = _get_level_list(level_select_ui.editing_level_list)
			return list_info.get("bg_style", {}).size() > 0
	elif MapManager.has_metadata_value("bg_style"):
		return MapManager.get_metadata_value("bg_style").size() > 0
	return false

func set_auto_bg_info_value(key: String, value: Variant) -> void:
	if cur_scene != "Play":
		set_game_bg_info_value(key, value)
		bg_style_changed.emit()
	else:
		var level_select_root: = Utility.get_level_select_root()
		if level_select_root and level_select_root.visible:
			var level_select_ui = level_select_root.level_select_ui
			if level_select_ui.editing_level_list:
				set_level_list_bg_info_value(level_select_ui.editing_level_list, key, value)
		else:
			set_level_bg_info_value(key, value)

func copy_game_bg_to_current() -> void:
	if cur_scene != "Play":
		return
	var level_select_root: = Utility.get_level_select_root()
	if level_select_root and level_select_root.visible:
		var level_select_ui = level_select_root.level_select_ui
		if level_select_ui.editing_level_list:
			copy_game_bg_to_level_list(level_select_ui.editing_level_list)
	else:
		copy_game_bg_to_level()

func copy_game_bg_to_level_list(level_list_name: String) -> void:
	var level_list_info: = _get_level_list(level_list_name)
	if not level_list_info:
		return
	level_list_info["bg_style"] = get_game_bg_info().duplicate_deep()

func copy_game_bg_to_level() -> void:
	set_level_bg_info(get_game_bg_info().duplicate_deep())

func copy_current_bg_to_level() -> void:
	set_level_bg_info(get_current_bg_info().duplicate_deep())


func is_one_time_message_dismissed(message_type: OneTimeMessages) -> bool:
	return player_profile.get_profile_setting_v(["one_time_messages", ONE_TIME_MESSAGES_KEYS[message_type]], false)

func set_one_time_message_dismissed(message_type: OneTimeMessages, as_dismissed: bool = true) -> void:
	player_profile.set_profile_setting_v(["one_time_messages", ONE_TIME_MESSAGES_KEYS[message_type]], as_dismissed)

func check_and_show_imported_image_disclaimer(finish_import_callback: Callable) -> void:
	if is_one_time_message_dismissed(OneTimeMessages.IMPORTED_IMAGE_DISCLAIMER):
		return
	var disclaimer_dialog: = preload("res://Scenes/bundled_image_disclaimer.tscn").instantiate() as ConfirmationDialog
	disclaimer_dialog.confirmed.connect(confirmed_import_with_images.bind(finish_import_callback, disclaimer_dialog))
	add_child(disclaimer_dialog)
	disclaimer_dialog.popup_centered()

func confirmed_import_with_images(finish_import_callback: Callable, disclaimer_dialog: ConfirmationDialog) -> void:
	if disclaimer_dialog:
		var disable_disclaimer_checkbox: = disclaimer_dialog.find_child("DisableDisclaimer") as CheckBox
		if disable_disclaimer_checkbox and disable_disclaimer_checkbox.button_pressed:
			set_one_time_message_dismissed(OneTimeMessages.IMPORTED_IMAGE_DISCLAIMER)
	finish_import_callback.call()


func web_export_level_json(level_name: String) -> void:
	if not OS.has_feature("web") or not get_game_name():
		return
	if not FilesManager.level_exists(get_game_name(), level_name):
		return
	var level_bytes: PackedByteArray = FilesManager.get_level_file_bytes(get_game_name(), level_name)
	var level_filename: = FilesManager.sanitize_level_filename(level_name) + ".json"
	JavaScriptBridge.download_buffer(level_bytes, level_filename, "application/json")


func start_import_levels() -> void:
	if OS.has_feature("web"):
		start_web_import_levels()
	else:
		var file_dialog: FileDialog = FileDialog.new()
		file_dialog.title = "Import Level/Level List json (%s)" % [get_game_title()]
		file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		file_dialog.filters = ["*.json"]
		file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		file_dialog.file_selected.connect(import_levels_local_picked)
		file_dialog.close_requested.connect(file_dialog.queue_free)
		file_dialog.canceled.connect(file_dialog.queue_free)
		
		file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
		add_child(file_dialog)
		file_dialog.popup_file_dialog()

func import_levels_local_picked(file_path: String) -> void:
	var json_string: = FileAccess.get_file_as_string(file_path)
	var data: Variant = JSON.parse_string(json_string)
	if not data or not typeof(data) == TYPE_DICTIONARY:
		push_error("Failed to parse JSON from imported levels")
		GlobalToaster.show_toast_message("Not valid levels")
		return
	import_some_json_data(data)


func start_web_import_levels() -> void:
	if not OS.has_feature("web") or not get_game_name():
		return
	file_access_web = FileAccessWeb.new()
	file_access_web.loaded.connect(GameManager.got_web_import_levels)
	file_access_web.open(".json")

func got_web_import_levels(_file_name: String, _file_type: String, b64_data: String) -> void:
	if file_access_web:
		file_access_web.queue_free()
		file_access_web = null
	var json_text: = Marshalls.base64_to_utf8(b64_data)
	var data: Variant = JSON.parse_string(json_text)
	if not data or not typeof(data) == TYPE_DICTIONARY:
		push_error("Failed to parse JSON from imported levels")
		GlobalToaster.show_toast_message("Not valid levels")
		return
	import_some_json_data(data)


func import_some_json_data(some_data: Dictionary) -> void:
	if is_data_level_list(some_data):
		import_level_list_data(some_data)
		return
	else:
		var imported_as_name: = add_imported_level_data(some_data)
		if not imported_as_name:
			GlobalToaster.show_toast_message("Failed to import level :<")
		else:
			GlobalToaster.show_toast_message("Imported level %s" % [imported_as_name])

func is_data_level_list(some_data: Dictionary) -> bool:
	if some_data.has("list_name") and some_data.has("level_filenames"):
		return true
	return false

func make_level_list_bundle_data(level_list_info: Dictionary) -> Dictionary:
	if not level_list_info.get("name", ""):
		push_error("Invalid level list info: %s" % level_list_info)
		return {}
	if not level_list_info.get("level_names", []):
		return {}
	var bundle_data: Dictionary = {
		"what_is_this": "GGM bundled level list",
		"for_game": get_game_name(),
		"list_name": level_list_info["name"],
		"level_filenames": [],
		"level_titles": {},
		"level_data": {},
	}
	var included_levels: Array = []
	for level_name in level_list_info.get("level_names", []):
		if level_name in included_levels or not FilesManager.level_exists(get_game_name(), level_name):
			continue
		included_levels.append(level_name)
	
	for level_name in level_list_info.get("level_names", []):
		if level_name in included_levels:
			bundle_data["level_filenames"].append(FilesManager.sanitize_level_filename(level_name))
	
	for level_name in included_levels:
		var level_data: = FilesManager.get_level_data(get_game_name(), level_name)
		bundle_data["level_data"][level_name] = level_data
		bundle_data["level_titles"][level_name] = FilesManager.get_level_title(get_game_name(), level_name)
	
	return bundle_data


func export_level_list(list_name: String) -> void:
	var level_list_info: = _get_level_list(list_name)
	if not level_list_info:
		push_error("Level list %s not found" % list_name)
		return
	if level_list_info.get("level_names", []).size() < 1:
		push_warning("Level list %s has no levels" % list_name)
		return

	if OS.has_feature("web"):
		web_export_level_list(list_name)
		return
	
	var list_filename: = Utility.sanitize_for_filename(list_name, true, true) + ".json"
	
	var file_dialog: FileDialog = FileDialog.new()
	file_dialog.title = "Export Level List %s.json" % [list_name]
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.json"]
	file_dialog.file_selected.connect(_export_level_list_destination_picked.bind(list_name, file_dialog))
	file_dialog.close_requested.connect(file_dialog.queue_free)
	file_dialog.canceled.connect(file_dialog.queue_free)
	
	file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	file_dialog.current_file = list_filename
	add_child(file_dialog)
	file_dialog.popup_file_dialog()

func _export_level_list_destination_picked(save_path: String, list_name: String, file_dialog: FileDialog) -> void:
	file_dialog.queue_free()
	var level_list_info: = _get_level_list(list_name)
	var bundle_data: Dictionary = make_level_list_bundle_data(level_list_info)
	if not bundle_data:
		push_error("Failed to make level list bundled data")
		return
	var stringified: = JSON.stringify(bundle_data, "", false)
	if not stringified:
		push_error("Failed to serialize level list bundled data")
		return
	
	var f: = FileAccess.open(save_path, FileAccess.WRITE)
	if not f:
		push_error("Failed to open file for writing: %s" % save_path)
		return
	if not f.store_string(stringified):
		push_error("Failed to write level list bundled data to file: %s" % save_path)
		return
	GlobalToaster.show_toast_message("Exported Level list to %s" % [save_path.get_file()])

func web_export_level_list(list_name: String) -> void:
	if not OS.has_feature("web") or not get_game_name():
		return
	var level_list_info: = _get_level_list(list_name)
	var bundle_data: Dictionary = make_level_list_bundle_data(level_list_info)
	if not bundle_data:
		push_error("Failed to make level list bundled data")
		return
	var serialized: = JSON.stringify(bundle_data, "", false).to_utf8_buffer()
	if not serialized:
		push_error("Failed to serialize level list bundled data")
		return
	var list_filename: = Utility.sanitize_for_filename(list_name, true, true) + ".json"
	JavaScriptBridge.download_buffer(serialized, list_filename, "application/json")

func get_unique_import_level_name(current_levels_list: Array, level_filename: String, level_title: String) -> String:
	if not level_filename in current_levels_list:
		return level_filename
	var title_name: = level_title.to_ascii_buffer().get_string_from_ascii()
	title_name = Utility.sanitize_for_filename(title_name, true, true)
	if title_name and not title_name in current_levels_list:
		return title_name

	var tries: int = 1
	var stamped_title_name: = title_name + (" %s" % Time.get_date_string_from_system())
	if not stamped_title_name in current_levels_list:
		return stamped_title_name
	var current_try: = stamped_title_name
	while current_try in current_levels_list:
		current_try = stamped_title_name + (" (%s)" % tries)
		tries += 1
		if tries > 10000:
			push_error("Failed to find a unique name for the imported level")
			return ""
	return current_try

func import_level_list_data(list_data: Dictionary, game_name_confirmed: bool = false) -> void:
	var for_game_name: String = list_data.get("for_game", "")
	if not game_name_confirmed and for_game_name != get_game_name():
		var confirm_dialog: = ConfirmationDialog.new()
		confirm_dialog.title = "Import Level List"
		confirm_dialog.dialog_text = ("This level list is for a game named '%s'. The current game is '%s'.\n" \
									+ "Do you still want to import the levels?") % [for_game_name, get_game_name()]
		
		confirm_dialog.confirmed.connect(import_level_list_data.bind(list_data, true))
		confirm_dialog.canceled.connect(confirm_dialog.queue_free)
		
		add_child(confirm_dialog)
		confirm_dialog.popup_centered()
		return
	
	var imported_list_name: String = list_data.get("list_name", "")
	if not imported_list_name:
		imported_list_name = Utility.random_animal()
	
	var cur_lists: = get_list_of_level_lists()
	if imported_list_name in cur_lists:
		var stamped_name: = imported_list_name + (" %s" % Time.get_date_string_from_system())
		if not stamped_name in cur_lists:
			var tries: int = 1
			var current_try: = stamped_name
			while current_try in cur_lists:
				current_try = stamped_name + (" (%s)" % tries)
				
				tries += 1
				if tries > 10000:
					push_error("Failed to find a unique name for the imported level list")
					return
			imported_list_name = current_try
		else:
			imported_list_name = stamped_name
	
	var level_list_info: Dictionary = {
		"name": imported_list_name,
	}
	if list_data.has("bg_style"):
		level_list_info["bg_style"] = list_data["bg_style"].duplicate_deep()
	
	var level_datas: Dictionary = list_data.get("level_data", {})
	var level_titles: Dictionary = list_data.get("level_titles", {})
	var existing_levels: = FilesManager.get_level_list(get_game_name())
	
	var remapped_names: Dictionary[String, String] = {}
	for level_filename in level_datas.keys():
		var data: Dictionary = level_datas[level_filename]
		if not data:
			continue
		var new_name: = get_unique_import_level_name(existing_levels, level_filename, level_titles.get(level_filename, ""))
		if not new_name:
			push_warning("failed to make a unique name for level %s, skipping" % [level_filename])
			continue
		remapped_names[level_filename] = new_name
		existing_levels.append(new_name)
	
	for old_level_name in remapped_names.keys():
		var data: Dictionary = level_datas[old_level_name]
		if not FilesManager.save_level_to_name(get_game_name(), data, remapped_names[old_level_name]):
			push_error("Failed to save level %s" % [old_level_name])
			remapped_names.erase(old_level_name)
	
	level_list_info["level_names"] = []
	for old_level_name in list_data.get("level_names", []):
		if old_level_name in remapped_names:
			level_list_info["level_names"].append(remapped_names[old_level_name])
	
	add_level_list_with_info(imported_list_name, level_list_info)
	save_current_game_definition()
	
	GlobalToaster.show_toast_message("Imported level list %s" % [imported_list_name])



func level_data_get_title(level_data: Dictionary, level_name: String) -> String:
	return level_data.get("state", {}).get("map", {}).get("metadata", {}).get("title", level_name)

func level_data_set_title(level_data: Dictionary, title: String) -> void:
	if not level_data.get("state", {}).get("map", {}):
		push_error("Level data is empty or invalid")
		return
	if not level_data["state"]["map"].has("metadata"):
		level_data["state"]["map"]["metadata"] = {}
	level_data["state"]["map"]["metadata"]["title"] = title

func ensure_level_data_title(level_data: Dictionary, level_name: String) -> void:
	if not level_data_get_title(level_data, ""):
		level_data_set_title(level_data, level_name)

func ensure_level_has_name(level_data: Dictionary, fallback_name: String) -> void:
	if level_data.get("name", ""):
		return
	if level_data_get_title(level_data, ""):
		level_data["name"] = FilesManager.sanitize_level_filename(level_data_get_title(level_data, ""))
	elif fallback_name:
		level_data["name"] = FilesManager.sanitize_level_filename(fallback_name)
	else:
		level_data["name"] = Utility.random_animal()


func clipboardify_level_data(level_data: Dictionary) -> String:
	var stringified: = JSON.stringify(level_data, "", false)
	var uncompressed_data: = stringified.to_utf8_buffer()
	var compressed_b64: = Marshalls.raw_to_base64(uncompressed_data.compress(FileAccess.COMPRESSION_ZSTD))
	if not compressed_b64:
		push_error("Failed to compress level data")
		return ""
	return ("%d:" % uncompressed_data.size()) + compressed_b64

func declipboardify_level_data(clipboard_data: String) -> Dictionary:
	if not clipboard_data.substr(0, 20).contains(":"):
		push_error("Invalid clipboard data: %s..." % clipboard_data.substr(0, 20))
		return {}
	var uncompressed_size: = clipboard_data.split(":", true, 1)[0]
	if not uncompressed_size or not uncompressed_size.is_valid_int():
		push_error("Invalid uncompressed size: %s" % uncompressed_size)
	if int(uncompressed_size) > MAX_LEVEL_TEXT_SIZE * 1.5:
		push_error("Level data is too big to paste from clipboard: %s" % uncompressed_size)
		return {}
	var compressed_data: = Marshalls.base64_to_raw(clipboard_data.split(":", true, 1)[1])
	if not compressed_data:
		push_error("Failed to un-base64-ify level data from clipboard")
		return {}
	var decompressed_data: = compressed_data.decompress(int(uncompressed_size), FileAccess.COMPRESSION_ZSTD)
	if not decompressed_data:
		push_error("Failed to decompress level data from clipboard")
		return {}
	var parsed_data: Variant = JSON.parse_string(decompressed_data.get_string_from_utf8())
	if not parsed_data:
		push_error("Failed to parse JSON from decompressed level data from clipboard")
		return {}
	if not parsed_data is Dictionary:
		push_error("Parsed level data from clipboard is not a dictionary: %s" % parsed_data)
		return {}
	return parsed_data

func load_level_from_clipboard_string(clipboard_data: String) -> bool:
	if cur_scene != "Play" or queued_level_load:
		return false
	var parsed: = declipboardify_level_data(clipboard_data)
	if not parsed:
		GlobalToaster.show_toast_message("Unable to paste level")
		return false
	current_level_list = ""
	ensure_level_has_name(parsed, "Pasted Level")
	load_level_data(parsed)
	loaded_level_is_saved = false
	return true

func add_imported_level_data(level_data: Dictionary) -> String:
	var existing_lists: = get_list_of_level_lists()
	if not "Imported Levels" in existing_lists:
		add_level_list("Imported Levels")
	
	var existing_levels: = FilesManager.get_level_list(get_game_name())
	var level_name: String = level_data.get("name", "")
	var unique_level_name: = get_unique_import_level_name(existing_levels, level_name, level_data_get_title(level_data, ""))
	if not unique_level_name:
		push_error("Failed to find a unique name for the imported level")
		return ""
	
	if not FilesManager.save_level_to_name(get_game_name(), level_data, unique_level_name):
		push_error("Failed to save level %s" % [unique_level_name])
		return ""
	
	add_level_to_level_list(unique_level_name, "Imported Levels")
	save_current_game_definition()
	
	return unique_level_name


func is_auto_undo_enabled() -> bool:
	if get_game_setting("movement_mode", MovementMode.MOVEMENT_CONTINUOUS) == GameManager.MovementMode.MOVEMENT_CONTINUOUS:
		return false
	return get_game_setting("auto_undo", true)

func action_1_does_undo() -> bool:
	var is_continuous: bool = get_game_setting("movement_mode", MovementMode.MOVEMENT_CONTINUOUS) == GameManager.MovementMode.MOVEMENT_CONTINUOUS
	return get_game_setting("action_1_does_undo", not is_continuous)

func has_undo_state() -> bool:
	return undo_stack.size() > 0

func clear_undo_stack() -> void:
	undo_stack.clear()
	undo_checkpoints.clear()
	undo_checkpoints_created.clear()
	next_undo_checkpoint_id = 0

# if as_current_state is false, will immediately be able to rewind to this state
# if as_current_state is true, undoing will skip this state if undoing before setting cur_undo_is_current_state to false
func push_undo_state(as_current_state: bool, with_state: Dictionary = {}) -> void:
	var cur_state: Dictionary = with_state
	if not cur_state:
		cur_state = get_serialized_play_state()
	
	if not checkpoint_save:
		cur_state["undo_checkpoint_id"] = -1
	else:
		var c_id: = _get_undo_checkpoint_id()
		cur_state["undo_checkpoint_id"] = c_id
		if c_id not in undo_checkpoints:
			_register_undo_checkpoint(c_id, checkpoint_save)

	undo_stack.append(cur_state)
	if undo_stack.size() > MAX_UNDO_LIMIT:
		remove_oldest_undo_state()
	cur_undo_is_current_state = as_current_state

func _register_undo_checkpoint(checkpoint_id: int, checkpoint_state: Dictionary) -> void:
	undo_checkpoints[checkpoint_id] = checkpoint_state
	undo_checkpoints_created[checkpoint_id] = undo_stack.size()

func remove_oldest_undo_state() -> void:
	if undo_stack.size() < 1:
		return
	undo_stack.pop_front()
	for checkpoint_id in undo_checkpoints_created.keys():
		var created_at: = undo_checkpoints_created[checkpoint_id]
		if created_at < 1:
			undo_checkpoints.erase(checkpoint_id)
			undo_checkpoints_created.erase(checkpoint_id)
		else:
			undo_checkpoints_created[checkpoint_id] = created_at - 1

func pop_and_load_undo_state() -> void:
	if undo_stack.size() < 1:
		return
	
	# only remove an undo from the stack if the top is the current state, otherwise load the top and set cur_undo_is_current_state
	if cur_undo_is_current_state and undo_stack.size() > 1:
		undo_stack.pop_back()
	var popped_state: Dictionary = undo_stack.back()
	cur_undo_is_current_state = true

	if popped_state["undo_checkpoint_id"] == -1 or not popped_state["undo_checkpoint_id"] in undo_checkpoints:
		clear_checkpoint()
	else:
		checkpoint_save = undo_checkpoints[popped_state["undo_checkpoint_id"]]

	if undo_stack.size() < 1:
		undo_checkpoints.clear()
		undo_checkpoints_created.clear()
	else:
		clear_undo_checkpoints_after(undo_stack.size() - 1)
	
	print_debug("popped undo state, %d undos remain" % undo_stack.size())

	load_serialized_play_state(popped_state, false)

func clear_undo_checkpoints_after(index: int) -> void:
	for checkpoint_id in undo_checkpoints_created.keys():
		if undo_checkpoints_created[checkpoint_id] > index:
			undo_checkpoints.erase(checkpoint_id)
			undo_checkpoints_created.erase(checkpoint_id)

func _get_undo_checkpoint_id() -> int:
	for checkpoint_id in undo_checkpoints_created:
		if is_same(undo_checkpoints[checkpoint_id], checkpoint_save):
			return checkpoint_id
	next_undo_checkpoint_id += 1
	return next_undo_checkpoint_id


func get_default_value_for_prop_name(prop_name: String) -> Variant:
	if prop_name in ConditionalsV3.all_events:
		if prop_name == "blocks":
			return true
		else:
			return {}
	elif prop_name in SPECIAL_PROPS and SPECIAL_PROPS_DEFAULTS.has(prop_name):
		return SPECIAL_PROPS_DEFAULTS[prop_name]
	elif prop_name in SPECIAL_PROPS:
		return true
	return true