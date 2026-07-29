extends Node


signal level_state_loaded
signal any_state_loaded
signal game_camera_target_changed(entity: BaseEntity)
signal game_settings_changed
signal game_dir_name_changed(new_game_dir_name: String)
signal scene_changed(new_scene: String)
signal bg_style_changed
@warning_ignore("unused_signal")
signal level_edit_mode_changed()
signal profile_switched()

signal flag_counts_changed()

const CreditsUI = preload("res://Scenes/credits_ui.gd")
const BGTileHolder = preload("res://Scenes/bg_tile_holder.gd")

const LevelListSettings = preload("res://Scenes/level_list_settings.gd")
const EditIntermissionAssignments = preload("res://Scenes/Intermission/edit_intermission_assignments.gd")

const IntermissionEvents = EditIntermissionAssignments.Events

const IntermissionUI = preload("res://Scenes/Intermission/intermission_ui.gd")
var intermission_ui_scn: = preload("res://Scenes/Intermission/intermission_ui.tscn")

const IDENTIFIER_MAX_LENGTH: int = 32

var MAX_UNDO_LIMIT: int = 1000

const FULL_TICK_RATE: int = 60
@onready var TICK_RATE: int = ProjectSettings.get_setting_with_override("physics/common/physics_ticks_per_second")

const MAX_LEVEL_TEXT_SIZE: int = 1000000

const DEFAULT_LIST_COMPLETION_MODE: String = "percentage"
const DEFAULT_LIST_COMPLETION_PERCENT: float = 80

var started = false
var cur_scene = null

var is_muted: bool = false


var _cur_profile_id: String = ""
var player_profile: PlayerProfile = null

var cur_game_name: = ""
var cur_game_identifier: String = ""
var current_game_is_release_locked: bool = false

var loaded_from_game_name: = ""

var current_level_list: String = ""

var game_creators: Array[String] = []

var checkpoint_save: = {}
var has_new_undo_since_checkpoint: bool = false
var previous_checkpoint_save: = {}
var editor_save: = {}
var loaded_level: = {}

var dummy_save_data: = {}

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
var _state_load_is_switched_level: = false

var editor_live_edit_mode: = false
var current_level_is_museum: = false

var queued_level_load: bool = false
var queued_level_load_timer: Timer = null
var _queued_lack_of_cam_target_action: bool = false

var file_access_web: RefCounted = null

var default_bg_style: Dictionary = {}

var non_bundled_level_lists: Array[Dictionary] = []

var default_empty_release_info: Dictionary = {
	"edited": true,
	"release_created_utc": "",
	"release_created_local_date": "",
	"release_created_zone_offset": "",
	"base_version": [0, 0],
	"next_version": [0, 1],
	"release_hash": "",
}

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
	"spawn-effect",
	"dying-effect",
	
	"spawn-anim-delay",
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
	"spawn-effect": "Grow In",
	"dying-effect": "Shrink Out",
	
	"spawn-anim-delay": 1.0,
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
	"spawn-effect": "The default effect on this entity's sprite when creating it at the start of a level, or via the \"Select Created Entity With Spawn Effect\" command.\n" +
		"If set, overrides the game's default spawn effect.\n" +
		"Available Effects: None, " + ", ".join(SpriteEffects.SPAWN_EFFECTS.keys()),
	"dying-effect": "The default effect on this entity's sprite when it is destroyed. If set, overrides the game's default dying effect.\n" +
		"Available Effects: None, " + ", ".join(SpriteEffects.DYING_EFFECTS.keys()),
	
	"spawn-anim-delay": "Set this between 0 and 1 to manually adjust when during the staggered level loading animation this entity will show up.\n",
}

enum OneTimeMessages {
	IMPORTED_IMAGE_DISCLAIMER,
	CLONE_ITEMS_WITH_BUNDLED_IMAGES,
}
const ONE_TIME_MESSAGES_KEYS: Dictionary[OneTimeMessages, String] = {
	OneTimeMessages.IMPORTED_IMAGE_DISCLAIMER: "imported_image_disclaimer",
	OneTimeMessages.CLONE_ITEMS_WITH_BUNDLED_IMAGES: "clone_items_with_bundled_images",
}

@export_file("*.json") var builtin_default_game_file: String = ""
var builtin_default_game_definition: Dictionary = {}

var pauses = {}

var game_definition = {}
var _unmodified_game_definition = {}

var game_camera: Camera2D = null

var stateful_camera_settings: = {}

# Only viewing intermissions, no level
var is_intermission_mode: bool = false
var intermission_state: Dictionary = {}

var transitioning = false
var transition_anim_target: Node
var scene_transition_duration = 0.6
var transition_left = true
@export var scene_transition_curve: Curve = Curve.new()

var _requested_tab: String = ""

enum MovementMode {
	MOVEMENT_CONTINUOUS, MOVEMENT_DISCRETE, MOVEMENT_DISCRETE_WAIT
}

const DEFAULT_INTERMISSION_CREDITS: = "Credits"
const DEFAULT_CREDITS: Dictionary = {
	"id": DEFAULT_INTERMISSION_CREDITS,
	"type": "credits",
	"bg_style": {}
}

const INTERM_GAME_STARTED_FLAG = "_GAME_STARTED_"
const INTERM_GAME_COMLETE_FLAG = "_GAME_COMPLETE_"
const INTERM_FULL_COMPLETE_FLAG = "_FULL_COMPLETE_"

const RESERVED_INTERMISSION_IDS: Array[String] = [
	INTERM_GAME_STARTED_FLAG,
	INTERM_GAME_COMLETE_FLAG,
	INTERM_FULL_COMPLETE_FLAG,
]

const RESERVED_INTERMISSIONS: Dictionary[String, Dictionary] = {
	INTERM_GAME_STARTED_FLAG: {
		"id": INTERM_GAME_STARTED_FLAG,
		"type": "flag",
	},
	INTERM_GAME_COMLETE_FLAG: {
		"id": INTERM_GAME_COMLETE_FLAG,
		"type": "flag",
	},
	INTERM_FULL_COMPLETE_FLAG: {
		"id": INTERM_FULL_COMPLETE_FLAG,
		"type": "flag",
	},
}

const COMPLETION__ALL_LISTS = "all_lists_complete"
const COMPLETION__ALL_LEVELS = "all_levels_complete"
const COMPLETION__SPECIFIC_LIST = "specific_list_complete"
const COMPLETION__SPECIFIC_LEVEL_CODE = "specific_level_code_complete"
const COMPLETION__SPECIFIC_LEVEL_NAME = "specific_level_name_complete"

const ALL_COMPLETION_MODES: Array[String] = [
	COMPLETION__ALL_LISTS,
	COMPLETION__ALL_LEVELS,
	COMPLETION__SPECIFIC_LIST,
	COMPLETION__SPECIFIC_LEVEL_CODE,
	COMPLETION__SPECIFIC_LEVEL_NAME,
]

var intermission_advancable_delay: float = 0.75
var intermission_advancable_timer: Timer

var intermission_expire_timer: Timer

func _ready():
	intermission_advancable_timer = Timer.new()
	intermission_advancable_timer.one_shot = true
	add_child(intermission_advancable_timer)
	intermission_expire_timer = Timer.new()
	intermission_expire_timer.one_shot = true
	intermission_expire_timer.process_mode = Timer.PROCESS_MODE_PAUSABLE
	add_child(intermission_expire_timer)
	#PuzzleScriptRNG.test_example()
	load_last_loaded_or_new_player_profile()
	# Automatically use the display scaling from the OS if it's detected, because of how the gameplay display auto scales this mainly affects UI
	var cur_screen_scale: float = DisplayServer.screen_get_scale()
	var min_screen_height: = 700.0
	var screen_size: = DisplayServer.screen_get_size()
	var min_screen_dimension: = minf(screen_size.x, screen_size.y)
	
	var screen_height: = min_screen_dimension / cur_screen_scale

	if screen_height < min_screen_height:
		prints("screen is too small when taking reported scale into account:", screen_size, cur_screen_scale)
		cur_screen_scale = snappedf(min_screen_dimension / min_screen_height, 0.25)
		cur_screen_scale = maxf(cur_screen_scale, 0.5)
		prints("ui scale combined with screen size is not enough space, overriding ui scale to %s" % [cur_screen_scale])

	if cur_screen_scale != get_window().content_scale_factor:
		get_window().content_scale_factor = cur_screen_scale
	
	#if Utility.is_mobile():
		#get_window().content_scale_factor = 1.0

	# run _process even when the game is paused
	process_mode = PROCESS_MODE_ALWAYS
	cur_scene = get_tree().current_scene.name
	FilesManager.init_folders()
	
	if OS.has_feature("web"):
		adjust_web_pssfx_volume()
	
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
			prints("using builtin defintion: %s" % [JSON.stringify(builtin_default_game_definition, "\t", false)])
			if builtin_default_game_definition:
				load_game_definition_data(builtin_default_game_definition, false)
			else:
				new_empty_game_definition()
			start_managers()
		else:
			new_empty_game_definition(FilesManager.get_unique_game_name(Utility.random_animal() + " Game"))
			start_managers()
			save_current_game_definition()
			FilesManager.save_default_game(get_identified_game_name())
	
	MapManager.refresh_definition()
	EntityManager.refresh_definition()
	EntityManager.build_sprite_previews()
	
	SfxPlayer.refresh_game_sfx()

func setup_default_bg_style() -> void:
	var customizable_bg: Node = preload("res://Scenes/bg_effect_6.tscn").instantiate()
	add_child(customizable_bg)
	var fallback_texture_id: = TextureManager.get_fallback_texture_id()
	default_bg_style = {
		"background_color": Utility.color_string_no_alpha(customizable_bg.default_bg_color),
		"bg_gradient_on": true,
		"bg_gradient_color": Utility.color_string(customizable_bg.default_bg_gradient_color, true),
		"bg_gradient_above": "below",
		
		"bg_gradient_rotation": 0.5,
		"bg_gradient_cover_amount": 0.8,
		
		"bg_tile_on": false,
		"bg_tile_color": Utility.color_string(BGTileHolder.DEFAULT_TILE_COLOR, true),
		"bg_tile_camera_scroll_factor": 0.5,
		"bg_tile_angle": 0.0,
		"bg_tile_texture_id": float(fallback_texture_id),
		"bg_tile_texture_index": 0.0,
		"bg_tile_scale": 1.0,
		"bg_tile_smooth_scale": false,
		"bg_tile_above": "below",
		"bg_tile_below_gradient": true,
		"bg_tile_spacing": [0.0, 0.0],
		"bg_tile_base_offset": [0.0, 0.0],
		"bg_tile_scale_with_camera": true,
		
		"bg_tile_auto_scroll_on": false,
		"bg_tile_auto_scroll_speed": 0.5,
		"bg_tile_auto_scroll_angle": 0.0,

		"dusty_particles_on": true,
		"dusty_particles_amount": 1.0,
		"dusty_particles_speed": 1.0,
		"dusty_particles_color": Utility.color_string(customizable_bg.default_particles_color, true),
		"dusty_particles_camera_scroll_factor": 0.5,
		
		"pointy_particles_on": false,
		"pointy_particles_amount": 1.0,
		"pointy_particles_speed": 1.0,
		"pointy_particles_rainbow_on": false,
		"pointy_particles_color": Utility.color_string(customizable_bg.default_pointy_particles_color, true),
		"pointy_particles_dark_mode": customizable_bg.pointy_particles_dark_mode,
		"pointy_particles_camera_scroll_factor": 0.0,
		
		"lines_on": false,
		"lines_solid_on": false,
		"lines_color": Utility.color_string(customizable_bg.lines_color, true),
		"lines_solid_color": Utility.color_string(customizable_bg.lines_solid_color, true),
		"lines_scroll_speed": customizable_bg.lines_scroll_speed,
		"lines_scroll_angle": rad_to_deg(customizable_bg.lines_scroll_angle * TAU),
		"lines_warp_strength": customizable_bg.lines_warp_strength,
		"lines_warp_scroll_speed": customizable_bg.lines_warp_scroll_speed,
		"lines_warp_scroll_angle": rad_to_deg(customizable_bg.lines_warp_scroll_angle * TAU),
		
		"lines_camera_scroll_factor": 0.0,
		"lines_solid_camera_scroll_factor": 0.0,

		"lines_above": "below",
	}
	remove_child(customizable_bg)
	customizable_bg.queue_free()

# only alphabetical characters and -, spaces and _ are converted to -
func sanitize_identifier(raw_identifier: String) -> String:
	raw_identifier = raw_identifier.strip_edges()
	var sanitized_identifier: = ""
	for i in raw_identifier.length():
		var character: = raw_identifier[i]
		if character == "_" or character == " ":
			character = "-"
		if character == "-" or character.is_valid_ascii_identifier():
			sanitized_identifier += character
	if sanitized_identifier.length() > IDENTIFIER_MAX_LENGTH:
		sanitized_identifier = sanitized_identifier.left(IDENTIFIER_MAX_LENGTH)

	return sanitized_identifier

func bake_scene_transition_curve() -> void:
	scene_transition_curve.bake()

func start_managers() -> void:
	TextureManager.setup()
	MapManager.setup()
	EntityManager.setup()

func describe_movement_mode(mode: int) -> String:
	match mode:
		MovementMode.MOVEMENT_CONTINUOUS:
			return "Real-time"
		MovementMode.MOVEMENT_DISCRETE:
			return "Discrete"
		MovementMode.MOVEMENT_DISCRETE_WAIT:
			return "Discrete+ (wait for all movement to settle)"
	return ""

func get_profile_identifier() -> String:
	var raw_identifier: String = player_profile.get_profile_setting("default_identifier", "")
	return sanitize_identifier(raw_identifier)

func set_profile_identifier(new_identifier: String) -> void:
	var sanitized_identifier: = sanitize_identifier(new_identifier)
	player_profile.set_profile_setting("default_identifier", sanitized_identifier)

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
		"game_identifier": get_profile_identifier(),
		"release_info": default_empty_release_info.duplicate_deep(),
		"textures": TextureManager.get_default_texture_spec(),
		"game_settings": {
			"pixel_scale": 2,
			"game_view_size": [22.0, 15.5],
		},
		"entity_definitions": {},
		"tile_definitions": {},
		"level_lists": [
			{"name": "Levels", "level_names": []},
		],
		"intermissions": [
			DEFAULT_CREDITS.duplicate_deep(),
		],
	}
	load_game_definition_data(empty_game, false)

func update_bundled_level_list_order(new_list_names: Array) -> void:
	new_list_names = Utility.list_to_unique_set(new_list_names)
	var old_list_order: = get_list_of_level_lists(true)
	var old_list_datas: Array = game_definition.get("level_lists", [])
	game_definition["level_lists"] = _get_reordered_list_datas(old_list_datas, old_list_order, new_list_names)

func _get_reordered_list_datas(old_list_datas: Array, old_list_order: Array, new_list_names: Array) -> Array:
	# Dont add new names or remove existing
	for new_list_name in new_list_names.duplicate():
		if not new_list_name in old_list_order:
			new_list_names.erase(new_list_name)
	for old_list_name in old_list_order:
		if not old_list_name in new_list_names:
			new_list_names.append(old_list_name)

	var keyed_list_data: Dictionary = {}
	for list_data in old_list_datas:
		if list_data.get("name", "") == "":
			continue
		keyed_list_data[list_data["name"]] = list_data
	var new_list_data: Array = []
	for new_list_name in new_list_names:
		new_list_data.append(keyed_list_data[new_list_name])
	
	return new_list_data

func update_non_bundled_level_lists_order(new_list_names: Array) -> void:
	new_list_names = Utility.list_to_unique_set(new_list_names)
	var old_list_order: = get_list_of_non_bundled_level_lists()
	var old_list_datas: Array = non_bundled_level_lists
	non_bundled_level_lists = _get_reordered_list_datas(old_list_datas, old_list_order, new_list_names)
	non_bundled_lists_updated()

func load_game_definition_from_file(game_name) -> void:
	var definition = FilesManager.get_game_definition(game_name)
	load_game_definition_data(definition, true)
	load_non_bundled_level_lists_from_file()

func load_game_definition_data(definition_data: Dictionary, from_file: bool) -> void:
	game_definition = definition_data.duplicate_deep()
	_unmodified_game_definition = definition_data.duplicate_deep()
	is_in_level_edit_mode = false
	current_level_list = ""
	loaded_level_name = ""
	loaded_level_is_saved = false
	
	_set_game_name(definition_data['game_name'], false)
	_set_game_identifier(definition_data.get("game_identifier", ""))
	
	if from_file:
		loaded_from_game_name = get_identified_game_name()
	else:
		loaded_from_game_name = ""
	
	editor_save = {}
	loaded_level = {}
	clear_checkpoint()
	clear_quicksave()
	clear_undo_stack()
	reset_dummy_save_data()
	
	# compatibility
	if "window_width" in definition_data and "window_height" in definition_data:
		var compatibility_window_size: = Vector2(definition_data['window_width'], definition_data['window_height'])
		set_game_view(compatibility_window_size)
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
	
	current_game_is_release_locked = false
	if not game_definition.has("release_info"):
		game_definition["release_info"] = default_empty_release_info.duplicate_deep()
	elif is_current_game_resavable():
		if not EntityManager.im_ready:
			do_release_info_validation_once_everyone_is_ready()
		else:
			release_info_validation_checks()
	
	#if cur_scene != "Loading" and cur_scene != "Menu":
		#change_scene(cur_scene)

func do_release_info_validation_once_everyone_is_ready() -> void:
	while true:
		await get_tree().process_frame
		if not EntityManager.im_ready or not MapManager.im_ready or not TextureManager.im_ready:
			continue
		release_info_validation_checks()
		break

func release_info_validation_checks() -> void:
	if not game_definition.has("release_info") or typeof(game_definition["release_info"]) != TYPE_DICTIONARY:
		game_definition["release_info"] = default_empty_release_info.duplicate_deep()
		return
	var release_info: Dictionary = game_definition.get("release_info", {})
	var is_edited: bool = release_info.get_or_add("edited", true)

	for timestamp_key in ["release_created_utc", "release_created_local_date", "release_created_zone_offset"]:
		if not release_info.has(timestamp_key):
			release_info[timestamp_key] = ""
	
	for version_key in ["base_version", "next_version"]:
		if not release_info.has(version_key) or not typeof(release_info[version_key]) == TYPE_ARRAY:
			release_info[version_key] = [0, 1 if version_key == "next_version" else 0]
			break
		var version_arr: Array = release_info[version_key]
		if not version_arr.size() == 2:
			version_arr.resize(2)
		for i in 2:
			var val: Variant = release_info[version_key][i]
			if typeof(val) == TYPE_FLOAT:
				val = int(val)
				release_info[version_key][i] = val
			if typeof(val) != TYPE_INT:
				release_info[version_key][i] = 0
		if version_key == "next_version" and release_info[version_key][0] == 0 and release_info[version_key][1] == 0:
			release_info[version_key][1] = 1

	game_definition["release_info"] = release_info
	
	if is_edited:
		return
	
	var release_hash: String = release_info.get("release_hash", "")
	if not release_hash:
		_update_saved_game_as_edited()
		return
	
	var current_hash: String = calculate_game_release_hash()
	if not current_hash or release_hash != current_hash:
		_update_saved_game_as_edited()
		return
	
	# Release is verified against hash, show as a released version until bundled levels or any definition context is edited
	current_game_is_release_locked = true

func increment_game_version(from_version: Vector2i) -> Vector2i:
	return Vector2i(from_version.x, from_version.y + 1)

func _update_saved_game_as_edited() -> void:
	game_definition["release_info"]["edited"] = true
	game_definition["release_info"]["release_hash"] = ""
	save_current_game_definition()

func create_released_version() -> String:
	FilesManager.fix_all_level_data_names(get_identified_game_name())
	if current_game_is_release_locked or not is_current_game_resavable():
		prints("Release Fail: already released or not resavable")
		return ""
	if cur_scene == "Play":
		prints("Release Fail: in play scene")
		return ""
	
	if not game_definition.has("intermissions"):
		game_definition["intermissions"] = []
	
	editor_save = {}
	loaded_level = {}
	clear_checkpoint()
	clear_quicksave()
	clear_undo_stack()
	
	if TextureManager.is_using_any_shared_images():
		if not TextureManager.bundle_all_used_shared_images():
			GlobalToaster.show_toast_message("Failed to bundle shared images", 2.0)
			prints("Release Fail: failed to bundle shared images")
			return ""
	
	var old_release_info: Dictionary = game_definition["release_info"].duplicate_deep()
	
	game_definition["release_info"]["edited"] = false
	game_definition["release_info"]["release_hash"] = ""
	
	game_definition["release_info"]["release_created_utc"] = Time.get_datetime_string_from_system(true, true)
	game_definition["release_info"]["release_created_local_date"] = Time.get_date_string_from_system(false)

	var time_zone_offset: int = Time.get_time_zone_from_system()["bias"]
	game_definition["release_info"]["release_created_zone_offset"] = Time.get_offset_string_from_offset_minutes(time_zone_offset)
	
	var new_version: Vector2i = Utility.get_vector2i_from_arr(game_definition["release_info"]["next_version"])
	var old_version: Vector2i = Utility.get_vector2i_from_arr(game_definition["release_info"]["base_version"])
	if new_version == old_version or new_version == Vector2i.ZERO:
		new_version = increment_game_version(old_version)

	game_definition["release_info"]["base_version"] = Utility.vector_to_list(new_version)
	game_definition["release_info"]["next_version"] = Utility.vector_to_list(increment_game_version(new_version))
	
	save_current_game_definition()
	game_definition["release_info"]["release_hash"] = calculate_game_release_hash()
	if not game_definition["release_info"]["release_hash"]:
		game_definition["release_info"] = old_release_info
		GlobalToaster.show_toast_message("Failed to calculate game release hash", 2.0)
		prints("Release Fail: failed to calculate game release hash")
		return ""
	
	save_current_game_definition()

	current_game_is_release_locked = true
	var zip_path: = export_current_release_mode()
	
	return zip_path

func export_current_release_mode() -> String:
	if not current_game_is_release_locked:
		return ""
	return FilesManager.save_released_version_zip(get_identified_game_name())

func get_release_info() -> Dictionary:
	return game_definition.get("release_info", {}).duplicate_deep()

func unrelease_lock() -> void:
	if not current_game_is_release_locked:
		return
	current_game_is_release_locked = false
	var base_version: Vector2i = Utility.get_vector2i_from_arr(game_definition["release_info"]["base_version"])
	var new_version: Vector2i = increment_game_version(base_version)
	game_definition["release_info"]["next_version"] = Utility.vector_to_list(new_version)
	_update_saved_game_as_edited()
	change_scene("GameEditor")

func unrelease_as_copy_with_identifier(new_identifier: String) -> void:
	if not current_game_is_release_locked:
		return
	if new_identifier == get_game_identifier():
		unrelease_lock()
		return
	_set_game_identifier(new_identifier)
	save_current_game_definition_as(get_identified_game_name())
	_update_saved_game_as_edited()
	change_scene("GameEditor")


func get_serialized_game_definition() -> Dictionary:
	_clean_no_name_bundled_lists()
	var serialized_def: = game_definition.duplicate_deep()
	serialized_def["game_name"] = get_game_name()
	serialized_def["game_identifier"] = get_game_identifier()
	serialized_def["textures"] = TextureManager.get_texture_spec()
	serialized_def["entity_definitions"] = EntityManager.entity_defs.duplicate_deep()
	serialized_def["tile_definitions"] = MapManager.tile_defs.duplicate_deep()
	if not "intermissions" in serialized_def:
		serialized_def["intermissions"] = []
	return serialized_def

func get_game_setting(setting_name, default):
	if not "game_settings" in game_definition:
		return default
	return game_definition["game_settings"].get(setting_name, default)

func has_game_setting(setting_name: String) -> bool:
	if not "game_settings" in game_definition:
		return false
	return game_definition["game_settings"].has(setting_name)

func set_game_setting(setting_name: String, value: Variant) -> void:
	if not "game_settings" in game_definition:
		game_definition["game_settings"] = {}
	game_definition["game_settings"][setting_name] = value
	game_settings_changed.emit()

func get_movement_mode_id() -> int:
	return get_game_setting("movement_mode", MovementMode.MOVEMENT_CONTINUOUS)

func is_continuous_movement_mode() -> bool:
	return get_movement_mode_id() == MovementMode.MOVEMENT_CONTINUOUS

func is_discrete_movement_mode() -> bool:
	return get_movement_mode_id() != MovementMode.MOVEMENT_CONTINUOUS

func get_window_size_setting() -> Vector2:
	return Utility.get_vector2_from_arr(get_game_setting("game_view_size", [12, 12]))

func get_base_window_size() -> Vector2:
	return get_window_size_setting() * MapManager.tile_width

func get_base_window_size_with_override() -> Vector2:
	if not cur_scene == "Play":
		return get_base_window_size()
	return MapManager.get_view_size_with_override() * MapManager.tile_width

func set_game_view(new_game_view_size: Vector2) -> void:
	set_game_setting("game_view_size", Utility.vector_to_list(new_game_view_size))

func refresh_game_view_size() -> void:
	if not cur_scene == "Play":
		return
	update_game_viewport()

func refresh_view_limit() -> void:
	if not cur_scene == "Play":
		return
	if game_camera:
		game_camera.update_bounds()
	MapManager.level_size_changed.emit()


func is_texture_id_used_in_game_or_levels(texture_id: int, bundled_only: bool = false) -> bool:
	if is_texture_id_used_in_settings(texture_id):
		return true
	if is_texture_id_used_in_levels_and_lists(texture_id, bundled_only):
		return true
	return false

func is_texture_id_used_in_settings(texture_id: int) -> bool:
	if _is_texture_id_used_in_hud(texture_id):
		return true
	if _is_texture_id_used_in_game_background(texture_id):
		return true
	if _is_texture_id_used_in_credits(texture_id):
		return true
	return false

func is_texture_id_used_in_levels_and_lists(texture_id: int, bundled_only: bool = false) -> bool:
	if is_texture_id_used_in_level_lists(texture_id, bundled_only):
		return true
	if is_texture_id_used_in_all_levels(texture_id, bundled_only):
		return true
	return false

func is_texture_id_used_in_level_lists(texture_id: int, bundled_only: bool = false) -> bool:
	for level_list_info in get_all_level_list_infos(bundled_only):
		if not level_list_info.get("bg_style", {}):
			continue
		if _is_texture_id_used_by_bg_style(level_list_info["bg_style"], texture_id):
			return true
	return false

func is_texture_id_used_in_all_levels(texture_id: int, bundled_only: bool = false) -> bool:
	var bundled_levels: = get_list_of_all_bundled_levels()
	if FilesManager.is_texture_id_used_in_levels(get_identified_game_name(), bundled_levels, texture_id):
		return true
	if not bundled_only:
		var all_non_bundled_levels: = get_list_of_all_non_bundled_levels()
		if FilesManager.is_texture_id_used_in_levels(get_identified_game_name(), all_non_bundled_levels, texture_id):
			return true
	return false

func _is_texture_id_used_in_hud(texture_id: int) -> bool:
	var hud_items: Dictionary = get_game_setting("info_panel_items", {})
	for item_id in hud_items:
		if not hud_items[item_id].has("image_icon"):
			continue
		if int(hud_items[item_id]["image_icon"]) == texture_id:
			return true
	return false

func _remap_texture_id_in_hud(from_texture_id: int, to_texture_id: int) -> void:
	var hud_items: Dictionary = get_game_setting("info_panel_items", {})
	for item_id in hud_items:
		if not hud_items[item_id].has("image_icon"):
			continue
		if int(hud_items[item_id]["image_icon"]) == from_texture_id:
			hud_items[item_id]["image_icon"] = to_texture_id
	set_game_setting("info_panel_items", hud_items)

func _is_texture_id_used_in_game_background(texture_id: int) -> bool:
	if not get_game_setting("bg_style", {}):
		return false
	var default_background_info: Dictionary = get_game_setting("bg_style", {})
	return _is_texture_id_used_by_bg_style(default_background_info, texture_id)

func _is_texture_id_used_by_bg_style(bg_style_info: Dictionary, texture_id: int) -> bool:
	if not bg_style_info.get("bg_tile_on", false):
		return false
	if not bg_style_info.has("bg_tile_texture_id"):
		return false
	return int(bg_style_info["bg_tile_texture_id"]) == texture_id

func _is_texture_id_used_in_credits(texture_id: int) -> bool:
	var credits_info: Dictionary = get_credits_info()
	for credit_item in credits_info.get("credits_list", []):
		if not credit_item.get("type", "") == "image" or not credit_item.has("texture_id"):
			continue
		var credit_texture_id: Variant = credit_item.get("texture_id", -1)
		if typeof(credit_texture_id) not in [TYPE_INT, TYPE_FLOAT] or int(credit_texture_id) != texture_id:
			continue
		return true
	return false

func remap_texture_id_in_credits(from_texture_id: int, to_texture_id: int) -> void:
	var credits_info: Dictionary = get_credits_info()
	for credit_item in credits_info.get("credits_list", []):
		if not credit_item.get("type", "") == "image" or not credit_item.has("texture_id"):
			continue
		var credit_texture_id: Variant = credit_item.get("texture_id", -1)
		if typeof(credit_texture_id) not in [TYPE_INT, TYPE_FLOAT] or int(credit_texture_id) != from_texture_id:
			continue
		credit_item["texture_id"] = to_texture_id
	set_credits_info(credits_info)

func remap_texture_id_in_game_and_levels(from_texture_id: int, to_texture_id: int, bundled_only: bool = false) -> void:
	remap_texture_id_in_settings(from_texture_id, to_texture_id)
	remap_texture_id_in_levels_and_lists(from_texture_id, to_texture_id, bundled_only)
	if editor_save:
		var level_fileified: = {"state": editor_save, "name": "nothing_to_see_here"}
		_remap_texture_id_in_level_data(from_texture_id, to_texture_id, level_fileified)
	
	# invalidate all temporary states in case they are invalid now
	clear_quicksave()
	clear_checkpoint()
	clear_undo_stack()

func remap_texture_id_in_settings(from_texture_id: int, to_texture_id: int) -> void:
	_remap_texture_id_in_hud(from_texture_id, to_texture_id)
	_remap_texture_id_game_background(from_texture_id, to_texture_id)
	remap_texture_id_in_credits(from_texture_id, to_texture_id)

func remap_texture_id_in_levels_and_lists(from_texture_id: int, to_texture_id: int, bundled_only: bool = false) -> void:
	remap_texture_id_in_level_lists(from_texture_id, to_texture_id, bundled_only)
	remap_texture_id_in_all_levels(from_texture_id, to_texture_id, bundled_only)

func _remap_texture_id_game_background(from_texture_id: int, to_texture_id: int) -> void:
	set_game_setting("bg_style", remap_texture_id_in_bg_style(from_texture_id, to_texture_id, get_game_setting("bg_style", {})))

func remap_texture_id_in_level_lists(from_texture_id: int, to_texture_id: int, bundled_only: bool = false) -> void:
	for level_list_info in get_all_level_list_infos(bundled_only):
		if not level_list_info.get("bg_style", {}):
			continue
		
		level_list_info["bg_style"] = remap_texture_id_in_bg_style(from_texture_id, to_texture_id, level_list_info["bg_style"])
	
	if not bundled_only:
		non_bundled_lists_updated()

func remap_texture_id_in_all_levels(from_texture_id: int, to_texture_id: int, bundled_only: bool = false) -> void:
	var bundled_levels: = get_list_of_all_bundled_levels()
	FilesManager.remap_texture_id_in_levels(get_identified_game_name(), bundled_levels, from_texture_id, to_texture_id)
	
	if not bundled_only:
		var all_non_bundled_levels: = get_list_of_all_non_bundled_levels()
		FilesManager.remap_texture_id_in_levels(get_identified_game_name(), all_non_bundled_levels, from_texture_id, to_texture_id)

func remap_texture_id_in_bg_style(from_texture_id: int, to_texture_id: int, bg_style_info: Dictionary) -> Dictionary:
	bg_style_info = bg_style_info.duplicate_deep()
	if not bg_style_info.get("bg_tile_on", false) and bg_style_info.has("bg_tile_texture_id"):
		bg_style_info.erase("bg_tile_texture_id")
		return bg_style_info

	if bg_style_info.has("bg_tile_texture_id"):
		if int(bg_style_info["bg_tile_texture_id"]) == from_texture_id:
			bg_style_info["bg_tile_texture_id"] = to_texture_id
	return bg_style_info


func get_default_pixel_scale() -> float:
	return get_game_setting("pixel_scale", 1)

func get_game_name() -> String:
	return cur_game_name

func get_game_identifier() -> String:
	return cur_game_identifier

func get_identified_game_name(visual_version: bool = false) -> String:
	if visual_version:
		return display_format_game_name_and_identifier(cur_game_identifier, cur_game_name)
	elif not cur_game_identifier:
		return cur_game_name
	return cur_game_identifier + "/" + cur_game_name

func display_format_game_name_and_identifier(game_identifier: String, game_name: String) -> String:
	if not game_identifier:
		return "?/" + game_name
	return game_identifier + "/" + game_name

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

func _set_game_identifier(new_identifier: String) -> void:
	cur_game_identifier = new_identifier.strip_edges()

func _game_identifier_part(identified_name: String) -> String:
	return identified_name.split("/", true, 1)[0]

func _game_name_part(identified_name: String) -> String:
	return identified_name.split("/", true, 1)[1]

func _set_identified_game_name(new_identified_name: String) -> void:
	if not new_identified_name.contains("/"):
		_set_game_identifier("")
		_set_game_name(new_identified_name)
	else:
		var new_identifier: = sanitize_identifier(_game_identifier_part(new_identified_name))
		_set_game_identifier(new_identifier)
		_set_game_name(_game_name_part(new_identified_name))

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
	return {"game_name": get_identified_game_name(), "version": get_version_for_data(), "map": s_map, "entities": s_ent, "game_state": serialize()}

func unload_map_and_entities() -> void:
	MapManager.clear()
	EntityManager.clear()

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
	
	clear_intermission_state()
	close_all_intermissions()

	if EntityManager.process_phase != 0:
		await get_tree().physics_frame

	deserialize(serialized_state.get("game_state", {}))
	MapManager.deserialize(serialized_state['map'])
	EntityManager.deserialize(serialized_state['entities'])
	
	update_game_viewport()
	
	if game_camera:
		var map_editor: = Utility.get_map_editor()
		if map_editor and not map_editor.edit_mode:
			activate_gameplay_camera()
	
	if as_level_load:
		level_state_loaded.emit()
		clear_undo_stack()
		push_undo_state(true)
		has_new_undo_since_checkpoint = false

	any_state_loaded.emit()

	bg_style_changed.emit()
	_state_load_is_start_of_level = false
	_state_load_is_switched_level = false

func deserialize(serialized_state: Dictionary) -> void:
	stateful_camera_settings = serialized_state.get("stateful_camera_settings", {}).duplicate_deep()
	if "camera_position" in serialized_state:
		if not is_in_level_edit_mode:
			var game_camera_to: Vector2 = Utility.get_vector2_from_arr(serialized_state.get("camera_position", [0, 0]))
			position_gameplay_camera(game_camera_to)

func create_game_camera() -> void:
	var cam = cameras["SimpleCamera"].instantiate()
	var world = Utility.get_world()
	cam.game_view = world
	world.add_child(cam)
	game_camera = cam
	game_camera.camera_target_changed.connect(on_game_camera_target_changed)
	game_camera.no_more_targets.connect(on_no_more_camera_targets)

func on_no_more_camera_targets() -> void:
	if is_in_level_edit_mode or not editor_save:
		return
	if queued_level_load:
		return

	if get_game_setting("auto_fail_if_no_cam_focus", false):
		queue_delayed_other_load(0.5, _fail_on_lack_of_cam_focus)
		_queued_lack_of_cam_target_action = true
	elif get_game_setting("auto_reload_checkpoint_for_no_cam_focus", false):
		queue_delayed_other_load(0.5, _reload_for_lack_of_cam_target)
		_queued_lack_of_cam_target_action = true

func _fail_on_lack_of_cam_focus() -> void:
	_queued_lack_of_cam_target_action = false
	show_current_fail_state_intermission_as_overlay()

func on_game_camera_target_changed(entity: BaseEntity) -> void:
	if entity and _queued_lack_of_cam_target_action:
		cancel_queued_level_load()
	game_camera_target_changed.emit(entity)

func _reload_for_lack_of_cam_target() -> void:
	_queued_lack_of_cam_target_action = false
	load_checkpoint()

func position_gameplay_camera(pos: Vector2) -> void:
	if game_camera:
		game_camera.teleport(pos)

func get_gameplay_camera_position() -> Vector2:
	if game_camera:
		return game_camera.get_screen_center_position()
	return Vector2.ZERO

func get_gameplay_camera_following_position() -> Vector2:
	if not game_camera:
		return Vector2.ZERO
	return game_camera.get_current_following_position()

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
	push_undo_state(true, checkpoint_save.duplicate_deep(), true)
	has_new_undo_since_checkpoint = false
func load_checkpoint() -> void:
	if checkpoint_save:
		load_serialized_play_state(checkpoint_save, false)
		if has_new_undo_since_checkpoint:
			push_undo_state(true, checkpoint_save.duplicate_deep(), true)
	elif editor_save:
		_state_load_is_start_of_level = true
		load_serialized_play_state(editor_save, false)
		if has_new_undo_since_checkpoint:
			push_undo_state(true, editor_save.duplicate_deep(), true)
	else:
		push_error("cannot load level or checkpoint")

func clear_checkpoint() -> void:
	checkpoint_save = {}

func save_edited() -> void:
	editor_save = get_serialized_play_state()
	clear_checkpoint()
func load_edited(as_level_load: bool = true, as_start_of_level: bool = false) -> void:
	if as_level_load:
		as_start_of_level = true
	_state_load_is_start_of_level = as_start_of_level
	_state_load_is_switched_level = as_level_load
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
		if FilesManager.level_exists(get_identified_game_name(), quicksave_level_name):
			loaded_level_is_saved = true
			var level_data: = FilesManager.get_level_data(get_identified_game_name(), quicksave_level_name)
			editor_save = level_data.get("state", {})
		else:
			loaded_level_is_saved = false
			editor_save = {}
			loaded_level = {}
	else:
		clear_undo_stack()
		push_undo_state(true)
		has_new_undo_since_checkpoint = false
	
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
	return FilesManager.level_exists(get_identified_game_name(), FilesManager.AUTO_SAVE_LEVEL_NAME)

func load_editor_autosave() -> void:
	if queued_level_load:
		return
	var autosave_data: Dictionary = FilesManager.get_level_data(get_identified_game_name(), FilesManager.AUTO_SAVE_LEVEL_NAME)
	load_level_data(autosave_data)
	loaded_level_is_saved = false
	loaded_is_autosave = true
	loaded_level = editor_save
	
	if FilesManager.level_exists(get_identified_game_name(), loaded_level_name):
		current_level_list = get_list_containing_level(loaded_level_name)

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
	queued_level_load_timer.timeout.connect(set.bind("queued_level_load", false))
	queued_level_load_timer.timeout.connect(callback)
	queued_level_load_timer.timeout.connect(queued_level_load_timer.queue_free)
	add_child(queued_level_load_timer)
	queued_level_load_timer.start(with_delay)

func cancel_queued_level_load() -> void:
	queued_level_load = false
	_queued_lack_of_cam_target_action = false
	if queued_level_load_timer:
		queued_level_load_timer.stop()
		queued_level_load_timer.queue_free()
		queued_level_load_timer = null

func try_load_level(level_name: String, as_queued_load: bool = false):
	if not FilesManager.level_exists(get_identified_game_name(), level_name) or (not as_queued_load and queued_level_load):
		return
	if level_name == "editor_autosave":
		load_editor_autosave()
		return

	var the_level_data: = FilesManager.get_level_data(get_identified_game_name(), level_name)
	if not the_level_data["name"] == level_name:
		the_level_data["name"] = level_name
	load_level_data(the_level_data, as_queued_load)
	loaded_level_is_saved = true
	loaded_level = editor_save

func edit_level_named(level_name: String, auto_list: bool = false) -> bool:
	if not FilesManager.level_exists(get_identified_game_name(), level_name):
		push_error("Level %s does not exist" % [level_name])
		return false
	var the_level_data: = FilesManager.get_level_data(get_identified_game_name(), level_name)
	if not the_level_data["name"] == level_name:
		the_level_data["name"] = level_name
	if auto_list:
		current_level_list = get_list_containing_level(level_name)
	load_level_data(the_level_data)
	loaded_level_is_saved = true
	loaded_level = editor_save
	return true

func edit_level_in_list(level_list_name: String, level_name: String) -> void:
	var level_lists: = get_list_of_level_lists()
	if not level_list_name in level_lists:
		push_error("Level list %s does not exist" % [level_list_name])
		return

	var was_level_list: = current_level_list
	current_level_list = level_list_name
	if not edit_level_named(level_name, false):
		current_level_list = was_level_list

func cleanup_new_level() -> void:
	clear_checkpoint()
	clear_undo_stack()
	push_undo_state(true)
	has_new_undo_since_checkpoint = false

func new_empty_level():
	loaded_level_name = ""
	loaded_level_is_saved = false
	current_level_is_museum = false
	EntityManager.clear()
	MapManager.clear()
	MapManager.create_plain_layer()
	EntityManager.create_defaults()
	
	cleanup_new_level()
	save_edited()
	loaded_level = editor_save
	new_level_edited_state_and_emit()
	
func new_level_edited_state_and_emit() -> void:
	save_edited()
	level_state_loaded.emit()
	any_state_loaded.emit()
	bg_style_changed.emit()

func new_museum_level():
	loaded_level_name = "Museum"
	loaded_level_is_saved = false
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
	
	MapManager.set_level_subtitle("Auto-generated showcase")
	
	cleanup_new_level()
	save_edited()
	loaded_level = editor_save
	
	new_level_edited_state_and_emit()

func change_scene(new_scene: String, skip_autosave: bool = false, request_tab: String = ""):
	_requested_tab = request_tab
	if new_scene == "Play" && not loaded_from_game_name and not FilesManager.game_exists(get_identified_game_name()):
		save_current_game_definition()
		
	if cur_scene != "Loading":
		show_scene_transition()
		if new_scene != "Menu" and is_current_game_saved():
			if FilesManager.get_default_game() != get_identified_game_name():
				FilesManager.save_default_game(get_identified_game_name())
	
	if not new_scene in scenes:
		print("I dont know about scene " + new_scene)
		return
	
	if cur_scene == "Play":
		cancel_queued_level_load()
		transition_left = true
		if editor_save and not loaded_level:
			loaded_level = editor_save
		EntityManager.clear()
		MapManager.clear()
		game_camera = null
		_unpause()
	elif cur_scene == "GameEditor":
		if not current_game_is_release_locked:
			if player_profile.get_profile_setting("auto_save_definition", true) and not skip_autosave:
				if is_current_game_resavable():
					save_current_game_definition()
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
		reset_dummy_save_data()
		update_game_viewport()
		create_game_camera()
		EffectsHelper._fetch_effects_holder()
		if is_in_level_edit_mode:
			if loaded_level:
				load_serialized_play_state(loaded_level)
			elif has_editor_autosave():
				var autosave_level_name: String = FilesManager.get_editor_autosave_level_name(get_identified_game_name())
				if current_game_is_release_locked and autosave_level_name in get_list_of_all_bundled_levels():
					new_empty_level()
				else:
					if FilesManager.get_editor_autosave_is_newer(get_identified_game_name()):
						GlobalToaster.show_toast_message("Loaded level autosave", 1.2)
						load_editor_autosave()
					else:
						if autosave_level_name:
							edit_level_named(autosave_level_name, true)
							#load_level_data(FilesManager.get_level_data(get_identified_game_name(), autosave_level_name))
						else:
							GlobalToaster.show_toast_message("Loaded level autosave", 1.2)
							load_editor_autosave()
			else:
				new_empty_level()
			if _requested_tab:
				var requested_tab: = _requested_tab
				_requested_tab = ""
				if requested_tab == "intermission-assignment-editor":
					var level_select_root: = Utility.get_level_select_root()
					if level_select_root:
						level_select_root.show_edit_intermission_assignements()
		else:
			play_current_save_level()
		if not is_in_level_edit_mode:
			activate_gameplay_camera()
	scene_changed.emit(cur_scene)

func update_game_viewport() -> void:
	var vp = Utility.get_world().get_viewport()
	vp.aspect_expand = get_game_setting("auto_aspect", true)
	vp.set_resolution(get_base_window_size_with_override())

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
	
	var pause_menu = get_tree().get_first_node_in_group("PauseMenu")
	if pause_menu:
		pause_menu.toggle()

func close_pause_menu() -> void:
	if cur_scene != "Play":
		return
	var pause_menu: = get_tree().get_first_node_in_group("PauseMenu")
	if pause_menu:
		pause_menu.close_pause_menu()

func open_pause_menu() -> void:
	if cur_scene != "Play":
		return
	var pause_menu: = get_tree().get_first_node_in_group("PauseMenu")
	if pause_menu:
		if pause_menu.active:
			return
		pause_menu.pause_and_open()
	
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
	
	if cur_scene != "Play":
		return

	if Input.is_action_just_pressed(&"press_quicksave"):
		save_quicksave()
		GlobalToaster.show_toast_message("Quicksaved")
		return
	elif Input.is_action_just_pressed(&"press_quickload"):
		if quicksave_state:
			if queued_level_load:
				cancel_queued_level_load()
			load_quicksave()
			GlobalToaster.show_toast_message("Loaded quicksave")
		else:
			GlobalToaster.show_toast_message("No Quicksave")
		return

	var do_intermission_advance: = false
	if is_showing_advancable_intermission():
		for action in ["input_action_1", "input_action_2", "input_action_3"]:
			if Input.is_action_just_pressed(action):
				do_intermission_advance = true
				break
		if not do_intermission_advance and is_intermission_advance_timeout():
			do_intermission_advance = true

	if do_intermission_advance:
		show_next_intermission()
		EntityManager._input_action_ignore_frame = true
	elif not get_tree().paused and Input.is_action_just_pressed(&"reload_checkpoint"):
		if not EntityManager.intermission_overlay_paused or EntityManager.intermission_overlay_undoable:
			if _queued_lack_of_cam_target_action:
				cancel_queued_level_load()
			if not cur_undo_is_current_state:
				push_undo_state(false)
			load_checkpoint()

func _unhandled_input(event: InputEvent) -> void:
	if Utility.fixed_just_pressed_by_event("pause_game", event) or Utility.fixed_just_pressed_by_event("escape", event):
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

func save_edited_level_as(as_level_filename: String, no_toast: bool = false) -> void:
	if not editor_save:
		return
	var level_data: = get_play_state_as_level_data(editor_save, as_level_filename)
	as_level_filename = level_data["name"]
	if not level_data:
		return

	if current_game_is_release_locked:
		if is_level_bundled(as_level_filename):
			if not no_toast:
				GlobalToaster.show_toast_message("Cannot overwrite this level")
			return
	
	var saved_successfully: = FilesManager.save_level(get_identified_game_name(), level_data)
	if saved_successfully:
		if not no_toast:
			GlobalToaster.show_toast_message("Level Saved")
	else:
		if not no_toast:
			GlobalToaster.show_toast_message("Failed to save level")
		return

	loaded_level = editor_save
	
	loaded_level_name = level_data["name"]
	if current_level_list:
		if current_game_is_release_locked and current_level_list in get_list_of_level_lists(true):
			current_level_list = ""
		else:
			add_level_to_level_list(as_level_filename, current_level_list)
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
	if copy_from_loaded_game and loaded_from_game_name and loaded_from_game_name != get_identified_game_name():
		copy_from_game = loaded_from_game_name
	FilesManager.save_game_info(definition_data)
	loaded_from_game_name = get_identified_game_name()

	if copy_from_game:
		FilesManager.copy_assets_and_levels_to(copy_from_game, get_identified_game_name())

func save_current_game_definition_as(as_identified_game_name: String, delete_on_overwrite: bool = false) -> bool:
	if as_identified_game_name == get_identified_game_name() and is_current_game_resavable():
		save_current_game_definition(false)
		return false
	
	var is_renaming: = false
	if not as_identified_game_name.contains("/") or _game_name_part(as_identified_game_name) != get_game_name():
		is_renaming = true

	if is_name_overwriting(as_identified_game_name):
		if not delete_on_overwrite:
			return false
		else:
			if not FilesManager.delete_game(as_identified_game_name):
				GlobalToaster.show_toast_message("Failed to overwrite game directory %s" % [FilesManager.get_game_dir_from_name(as_identified_game_name)])
				return false

	var copy_assets_and_levels_from: = ""
	if loaded_from_game_name and loaded_from_game_name != as_identified_game_name:
		copy_assets_and_levels_from = loaded_from_game_name

	if is_renaming:
		if not get_game_setting("title", ""):
			set_game_setting("title", get_game_implicit_title() + " (copy)")
		elif not get_game_setting("title", "").ends_with(" (copy)"):
			set_game_setting("title", get_game_setting("title", "") + " (copy)")
	_set_identified_game_name(as_identified_game_name)
	save_current_game_definition(false)
	
	if copy_assets_and_levels_from:
		FilesManager.copy_assets_and_levels_to(copy_assets_and_levels_from, as_identified_game_name)
	return true

func rename_and_save_current_game_definition(new_identified_game_name: String, delete_on_overwrite: bool = false) -> bool:
	if not is_current_game_saved():
		_set_identified_game_name(new_identified_game_name)
		return false
	if FilesManager.is_game_name_equivalent(new_identified_game_name, get_identified_game_name()):
		_set_identified_game_name(new_identified_game_name)
		save_current_game_definition()
		return true
	
	if delete_on_overwrite and is_name_overwriting(new_identified_game_name):
		if not FilesManager.delete_game(new_identified_game_name):
			GlobalToaster.show_toast_message("Failed to overwrite game directory %s" % [FilesManager.get_game_dir_from_name(new_identified_game_name)])
			return false

	var old_game_name: = get_identified_game_name()
	if FilesManager.rename_game(old_game_name, new_identified_game_name):
		_set_identified_game_name(new_identified_game_name)
		loaded_from_game_name = get_identified_game_name()
		if FilesManager.get_default_game() == old_game_name:
			FilesManager.save_default_game(new_identified_game_name)
	else:
		GlobalToaster.show_toast_message("Failed to move game directory")
		return false
	return true

func is_current_game_resavable() -> bool:
	if not get_identified_game_name():
		return false
	if not loaded_from_game_name and not FilesManager.game_exists(get_identified_game_name()):
		return true
	return loaded_from_game_name == get_identified_game_name()

func is_save_current_overwriting() -> bool:
	if is_current_game_resavable():
		return false
	return FilesManager.game_exists(get_identified_game_name())

func is_name_overwriting(new_identified_game_name: String) -> bool:
	if new_identified_game_name == loaded_from_game_name:
		return false
	return FilesManager.game_exists(new_identified_game_name)

func is_current_game_saved() -> bool:
	return loaded_from_game_name != ""

func import_and_load_game_zip(zip_file_path: String) -> void:
	var w_images_disabled: bool = is_one_time_message_dismissed(OneTimeMessages.IMPORTED_IMAGE_DISCLAIMER)
	_import_and_load_game_zip(zip_file_path, w_images_disabled, after_import_game_zip_message)

func _import_and_load_game_zip(zip_file_path: String, w_images_confirmed: bool, then_callable: Callable) -> void:
	if not w_images_confirmed:
		if ImportZipExtractor.zip_has_bundled_images(zip_file_path):
			check_and_show_imported_image_disclaimer(_import_and_load_game_zip.bind(zip_file_path, true, then_callable))
	var imported_name: String = ImporterExporter.import_game_zip(zip_file_path, false)
	var success: bool = true
	if not imported_name:
		success = false
	else:
		load_game_definition_from_file(imported_name)

	if then_callable.is_valid():
		then_callable.call(success)

func after_import_game_zip_message(success: bool) -> void:
	if success:
		GlobalToaster.show_toast_message("Imported %s" % [get_identified_game_name()])
	else:
		GlobalToaster.show_toast_message("Failed to import game")


func load_game_version_from_zip_file(version_zip_path: String, force_backup: bool = false) -> void:
	var imported_name: String = ImporterExporter.import_game_zip(version_zip_path, false, "", false, force_backup)
	if not imported_name:
		GlobalToaster.show_toast_message("Failed to load version")
		return
	load_game_definition_from_file(imported_name)


func got_web_import_zip(_file_name: String, _file_type: String, b64_data: String) -> void:
	var zip_byte_array: = Marshalls.base64_to_raw(b64_data)
	var w_images_disabled: bool = is_one_time_message_dismissed(OneTimeMessages.IMPORTED_IMAGE_DISCLAIMER)
	import_and_load_game_zip_buffer(zip_byte_array, w_images_disabled, after_import_game_zip_message)

func import_and_load_game_zip_buffer(zip_buffer: PackedByteArray, w_images_confirmed: bool = false, then_callable: Callable = Callable()) -> void:
	if not w_images_confirmed:
		var zip_has_bundled_images: bool = ImportZipExtractor.zip_or_buffer_has_bundled_images(zip_buffer)
		if zip_has_bundled_images:
			check_and_show_imported_image_disclaimer(import_and_load_game_zip_buffer.bind(zip_buffer, true, then_callable))
	var imported_name: String = ImporterExporter.import_game_zip(zip_buffer, false)
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

func get_empty_non_bundled_level_list_info() -> Dictionary:
	return _wrap_list_info([])

func _wrap_list_info(level_lists: Array) -> Dictionary:
	return {"level_lists": level_lists}

func _unwrap_list_info(wrapped_info: Dictionary) -> Array[Dictionary]:
	var typed_arr: Array[Dictionary] = []
	for list_info in wrapped_info.get("level_lists", []):
		if not typeof(list_info) == TYPE_DICTIONARY:
			continue
		typed_arr.append(list_info)
	return typed_arr

func non_bundled_lists_updated() -> void:
	_clean_no_name_non_bundled_lists()
	var wrapped_info: = _wrap_list_info(non_bundled_level_lists)
	FilesManager.save_non_bundled_level_list_info(get_identified_game_name(), wrapped_info)

func load_non_bundled_level_lists_from_file() -> void:
	var wrapped_info: Dictionary = FilesManager.get_non_bundled_level_info(get_identified_game_name())
	non_bundled_level_lists = _unwrap_list_info(wrapped_info)

func _clean_no_name_non_bundled_lists() -> void:
	var invalid_indices: Array[int] = []
	for i in non_bundled_level_lists.size():
		if not non_bundled_level_lists[i].get("name", ""):
			invalid_indices.append(i)
	if invalid_indices.size() < 1:
		return
	invalid_indices.reverse()
	for index in invalid_indices:
		non_bundled_level_lists.remove_at(index)

func _clean_no_name_bundled_lists() -> void:
	var invalid_indices: Array[int] = []
	for i in game_definition.get("level_lists", []).size():
		if not game_definition.get("level_lists", [])[i].get("name", ""):
			invalid_indices.append(i)
	if invalid_indices.size() < 1:
		return
	invalid_indices.reverse()
	for index in invalid_indices:
		game_definition["level_lists"].remove_at(index)

func _get_level_list(level_list_name: String) -> Dictionary:
	var level_list_info: = _get_bundled_level_list(level_list_name)
	if not level_list_info:
		level_list_info = _get_non_bundled_level_list(level_list_name)
	if not level_list_info:
		return {}
	return level_list_info

func _get_bundled_level_list(level_list_name: String) -> Dictionary:
	for level_list_info in game_definition.get("level_lists", []):
		if level_list_info.get("name", "") == level_list_name:
			return level_list_info
	return {}

func _get_non_bundled_level_list(level_list_name: String) -> Dictionary:
	for level_list_info in non_bundled_level_lists:
		if level_list_info.get("name", "") == level_list_name:
			return level_list_info
	return {}

func remove_level_from_all_editable_lists(level_name: String) -> void:
	if not current_game_is_release_locked:
		_remove_level_from_all_bundled_lists(level_name)

	if _remove_level_from_all_non_bundled_lists(level_name):
		non_bundled_lists_updated()

func _remove_level_from_all_lists(level_name: String, dont_break_release_lock: bool = true) -> bool:
	if not dont_break_release_lock or not current_game_is_release_locked:
		_remove_level_from_all_bundled_lists(level_name)
	return _remove_level_from_all_non_bundled_lists(level_name)

func _remove_level_from_all_bundled_lists(level_name: String) -> void:
	for level_list_info in game_definition.get("level_lists", []):
		level_list_info["level_names"].erase(level_name)

func _remove_level_from_all_non_bundled_lists(level_name: String) -> bool:
	var removed: bool = false
	for non_bundled_info in non_bundled_level_lists:
		non_bundled_info["level_names"].erase(level_name)
		removed = true
	return removed

func _is_list_info_valid_next_list(list_info: Dictionary) -> bool:
	if list_info.get("always_hidden", false):
		return false
	if get_levels_in_list_info(list_info).size() == 0:
		return false
	return true

func _get_next_bundled_level_list_auto(level_list_name: String) -> String:
	var all_bundled_list_infos: = get_all_level_list_infos(true)

	var valid_target_lists: Array[String] = []
	for bundled_list_info in all_bundled_list_infos:
		if bundled_list_info["name"] == level_list_name:
			if bundled_list_info.get("always_hidden", false):
				return ""
			# make sure to include this list so we can check the next index
			valid_target_lists.append(bundled_list_info["name"])
			continue

		if _is_list_info_valid_next_list(bundled_list_info):
			valid_target_lists.append(bundled_list_info["name"])

	var from_list_index: int = valid_target_lists.find(level_list_name)
	if from_list_index == valid_target_lists.size() - 1:
		return ""
	return valid_target_lists[from_list_index + 1]

func _get_level_list_index(level_list_name: String) -> int:
	var all_lists: = get_list_of_level_lists()
	for i in all_lists.size():
		if all_lists[i] == level_list_name:
			return i
	return -1

func is_level_list_bundled(level_list_name: String) -> bool:
	for i in game_definition.get("level_lists", []).size():
		if game_definition.get("level_lists", [])[i].get("name", "") == level_list_name:
			return true
	return false

func level_list_exists(level_list_name: String) -> bool:
	return level_list_name in get_list_of_level_lists()

func change_level_list_is_bundled(level_list_name: String, new_is_bundled: bool) -> void:
	var exists_in_bundled: bool = is_level_list_bundled(level_list_name)
	var exists_in_non_bundled: bool = false
	for non_bundled_info in non_bundled_level_lists:
		if non_bundled_info.get("name", "") == level_list_name:
			exists_in_non_bundled = true
			break
	
	if new_is_bundled and level_list_name == "Imported Levels":
		return
	
	if exists_in_bundled and exists_in_non_bundled:
		return
	
	if new_is_bundled and not exists_in_non_bundled:
		return
	if not new_is_bundled and not exists_in_bundled:
		return
	
	var info: Dictionary = {}
	if new_is_bundled:
		var intermission_id_remaps: Dictionary = {}
		for custom_list_intermission_id in get_all_intermission_ids_from_custom_list(level_list_name):
			var new_id: = import_intermission_from_custom_list(level_list_name, custom_list_intermission_id, true)
			intermission_id_remaps[custom_list_intermission_id] = new_id
		info = _get_non_bundled_level_list(level_list_name)
		info.erase("intermissions")
		_remap_intermission_ids_in_level_list_info(info, intermission_id_remaps)

		_remove_non_bundled_level_list(level_list_name)
	else:
		info = _get_bundled_level_list(level_list_name)
		_remove_bundled_level_list(level_list_name)
	add_level_list_with_info(level_list_name, info, new_is_bundled)
	non_bundled_lists_updated()

func remove_level_list(level_list_name: String) -> void:
	if not current_game_is_release_locked:
		_remove_bundled_level_list(level_list_name)
	_remove_non_bundled_level_list(level_list_name)

func _remove_bundled_level_list(level_list_name: String) -> void:
	var found_at_indices: Array[int] = []
	for i in game_definition.get("level_lists", []).size():
		if game_definition.get("level_lists", [])[i].get("name", "") == level_list_name:
			found_at_indices.append(i)
	found_at_indices.reverse()
	for index in found_at_indices:
		game_definition["level_lists"].remove_at(index)

func _remove_non_bundled_level_list(level_list_name: String) -> void:
	var found_at_indices: Array[int] = []
	for i in non_bundled_level_lists.size():
		if non_bundled_level_lists[i].get("name", "") == level_list_name:
			found_at_indices.append(i)
	found_at_indices.reverse()
	for index in found_at_indices:
		non_bundled_level_lists.remove_at(index)
	if found_at_indices.size() > 0:
		non_bundled_lists_updated()

func _remap_intermission_ids_in_level_list_info(level_list_info: Dictionary, intermission_id_remaps: Dictionary) -> void:
	if not intermission_id_remaps:
		return
	var remapped_tagged_ids: Dictionary = {}
	for base_id in intermission_id_remaps.keys():
		remapped_tagged_ids[":" + base_id] = intermission_id_remaps[base_id]
	var intermission_assignments: Dictionary = level_list_info.get("intermission_assignments", {})
	for event_key in intermission_assignments.keys():
		var assignments: Array = intermission_assignments[event_key]
		for i in assignments.size():
			if assignments[i] in remapped_tagged_ids:
				assignments[i] = remapped_tagged_ids[assignments[i]]
		intermission_assignments[event_key] = assignments
	level_list_info["intermission_assignments"] = intermission_assignments
	
	var intermissions: Array = level_list_info.get("intermissions", [])
	for intermission_info in intermissions:
		var old_id: String = intermission_info.get("id", "")
		if not old_id:
			continue
		if old_id in remapped_tagged_ids:
			intermission_info["id"] = remapped_tagged_ids[old_id]
	level_list_info["intermissions"] = intermissions


func add_empty_level_list(level_list_name: String, is_bundled: bool, dont_break_release_lock: bool = true) -> void:
	level_list_name = make_new_list_name_unique(level_list_name)
	var new_list_info: Dictionary = {
		"name": level_list_name,
		"level_names": [],
		"completion_mode": DEFAULT_LIST_COMPLETION_MODE,
	}
	if is_bundled and level_list_name == "Imported Levels":
		is_bundled = false

	if DEFAULT_LIST_COMPLETION_MODE == "percentage":
		new_list_info["required_percentage"] = DEFAULT_LIST_COMPLETION_PERCENT
	if is_bundled:
		if dont_break_release_lock and current_game_is_release_locked:
			return
		
		if not game_definition.get("level_lists", []):
			game_definition["level_lists"] = []
		game_definition["level_lists"].append(new_list_info)
	else:
		non_bundled_level_lists.append(new_list_info)
		non_bundled_lists_updated()

func is_level_in_list(level_name: String, level_list_name: String) -> bool:
	var level_list_info: = _get_level_list(level_list_name)
	if not level_list_info:
		return false
	return level_name in level_list_info.get("level_names", [])

func set_level_list_data(level_list_name: String, setting_name: String, setting_value: Variant) -> void:
	var list_info: = _get_level_list(level_list_name)
	if not list_info:
		return
	
	if is_level_list_bundled(level_list_name):
		list_info[setting_name] = setting_value
	else:
		list_info[setting_name] = setting_value
		non_bundled_lists_updated()

func remove_level_list_data(level_list_name: String, setting_name: String) -> void:
	var list_info: = _get_level_list(level_list_name)
	if not list_info:
		return

	if is_level_list_bundled(level_list_name):
		list_info.erase(setting_name)
	else:
		list_info.erase(setting_name)
		non_bundled_lists_updated()

func level_list_name_exists(level_list_name: String) -> bool:
	return level_list_name in get_list_of_level_lists()

func make_new_list_name_unique(level_list_name: String) -> String:
	var existing_lists: = get_list_of_level_lists()
	if not level_list_name or not level_list_name in existing_lists:
		return level_list_name
	for i in 100000:
		var new_name: = level_list_name + ("[%d]" % i)
		if not new_name in existing_lists:
			return new_name
	return ""

func rename_level_list(old_name: String, new_name: String) -> bool:
	var old_list_info: = _get_level_list(old_name)
	if not old_list_info or new_name == old_name:
		return false
	if is_level_list_bundled(old_name):
		old_list_info["name"] = new_name
	else:
		old_list_info["name"] = new_name
		non_bundled_lists_updated()
	return true

func add_level_list_with_info(level_list_name: String, level_list_info: Dictionary, is_bundled: bool = true) -> void:
	level_list_name = make_new_list_name_unique(level_list_name)
	if not level_list_name:
		return
	level_list_info["name"] = level_list_name
	if is_bundled:
		if not game_definition.get("level_lists", []):
			game_definition["level_lists"] = []
		game_definition["level_lists"].append(level_list_info.duplicate_deep())
	else:
		non_bundled_level_lists.append(level_list_info.duplicate_deep())
		non_bundled_lists_updated()


func has_any_unlocked_levels() -> bool:
	var total_unlocked_levels: int = 0
	for level_list_name in get_list_of_level_lists():
		total_unlocked_levels += get_unlocked_levels_in_level_list(level_list_name).size()
	return total_unlocked_levels > 0

func list_has_any_unlocked_levels(level_list_name: String) -> bool:
	var level_list_info: = _get_level_list(level_list_name)
	if not level_list_info:
		return false
	return get_unlocked_levels_in_level_list(level_list_name).size() > 0

func get_list_of_level_lists(only_bundled: bool = false) -> Array:
	var ll_names: Array[String] = []
	for level_list_info in game_definition.get("level_lists", []):
		if not level_list_info.get("name", ""):
			continue
		ll_names.append(level_list_info["name"])
	if not only_bundled:
		for non_bundled_info in non_bundled_level_lists:
			if not non_bundled_info.get("name", ""):
				continue
			ll_names.append(non_bundled_info["name"])
	return ll_names

func get_list_of_non_bundled_level_lists() -> Array[String]:
	var ll_names: Array[String] = []
	for non_bundled_info in non_bundled_level_lists:
		if not non_bundled_info.get("name", ""):
			continue
		ll_names.append(non_bundled_info["name"])
	return ll_names

func get_all_level_list_infos(only_bundled: bool = false) -> Array[Dictionary]:
	var level_list_infos: Array[Dictionary] = []
	for level_list_info in game_definition.get("level_lists", []):
		if not level_list_info.get("name", ""):
			continue
		level_list_infos.append(level_list_info)
	if not only_bundled:
		for non_bundled_info in non_bundled_level_lists:
			if not non_bundled_info.get("name", ""):
				continue
			level_list_infos.append(non_bundled_info)
	return level_list_infos

func get_all_non_bundled_level_list_infos() -> Array[Dictionary]:
	var level_list_infos: Array[Dictionary] = []
	for non_bundled_info in non_bundled_level_lists:
		if not non_bundled_info.get("name", ""):
			continue
		level_list_infos.append(non_bundled_info)
	return level_list_infos

func get_levels_in_level_list(level_list_name: String) -> Array[String]:
	var level_list_info: = _get_level_list(level_list_name)
	return get_levels_in_list_info(level_list_info)

func get_levels_in_list_info(level_list_info: Dictionary) -> Array[String]:
	var actual_level_names: Array[String] = []
	for level_name in level_list_info.get("level_names", []):
		if level_name and FilesManager.level_exists(get_identified_game_name(), level_name):
			actual_level_names.append(level_name)
	return actual_level_names

func is_level_list_unlocked(level_list_name: String, current_level_as_complete: bool = false) -> bool:
	var level_list_index: = _get_level_list_index(level_list_name)
	if level_list_index < 0:
		return false

	if _is_unlock_all_levels_and_lists():
		return true
	elif not is_level_list_bundled(level_list_name):
		return true
	elif level_list_index == 0:
		return true
	elif _is_level_list_unlocked_in_save(level_list_name):
		return true
	else:
		var list_info: = _get_level_list(level_list_name)
		if not list_info.get("default_locked", false):
			return true
		if _is_level_list_unlocked_in_save(level_list_name):
			return true
		if current_level_as_complete and _is_current_level_unlocking_level_list(level_list_name):
			return true
	return false

func _is_current_level_unlocking_level_list(level_list_name: String) -> bool:
	if not loaded_level_name:
		return false
	if not is_level_in_any_list(loaded_level_name):
		return false
	
	var completing_in_list: String = current_level_list
	if not completing_in_list:
		completing_in_list = get_list_containing_level(loaded_level_name)
		if not completing_in_list:
			push_error("Unable to determine which list the level %s is in" % loaded_level_name)
			return false
	
	if not will_level_complete_list(loaded_level_name, completing_in_list):
		return false
	if not will_list_unlock_list(completing_in_list, level_list_name):
		return false
	
	return true

func is_level_list_complete(level_list_name: String) -> bool:
	return _check_level_list_completion(level_list_name, "") > 0

func is_level_list_fully_completed(level_list_name: String) -> bool:
	var levels_count: int = get_levels_in_level_list(level_list_name).size()
	if levels_count <= 0:
		return true
	var completed_count: int = get_list_completed_count(level_list_name)
	return completed_count >= levels_count

func will_level_complete_list(level_name: String, level_list_name: String) -> bool:
	return _check_level_list_completion(level_list_name, level_name) == 2

func _level_list_required_level_count(level_list_name: String) -> int:
	var level_list_info: = _get_level_list(level_list_name)
	if not level_list_info:
		return 0
	var comletion_mode: String = level_list_info.get("completion_mode", "all")
	var total_count: int = get_levels_in_level_list(level_list_name).size()
	var required_count: int = total_count
	if comletion_mode == "count" or comletion_mode == "inverse_count":
		required_count = int(level_list_info.get("required_to_complete", 0))
		if comletion_mode == "inverse_count":
			required_count = total_count - required_count
	elif comletion_mode == "percentage":
		var required_ratio: float = clampf(level_list_info.get("required_percentage", 0.), 0, 100) / 100
		required_count = maxi(1, floori(total_count * required_ratio))
	return required_count

func _check_level_list_completion(level_list_name: String, with_level_name_completed: String) -> int:
	var level_list_info: = _get_level_list(level_list_name)
	if not level_list_info:
		return 0
	var required_count: int = _level_list_required_level_count(level_list_name)
	if required_count <= 0:
		return 1

	var all_levels: Array[String] = get_levels_in_level_list(level_list_name)
	var with_another_completed: bool = false
	var completed_count: int = 0
	for level_name in all_levels:
		if is_level_completed_in_list(level_list_name, level_name):
			completed_count += 1
		elif level_name and with_level_name_completed == level_name:
			with_another_completed = true
	
	if completed_count >= required_count:
		return 1
	elif with_another_completed and completed_count + 1 >= required_count:
		return 2
	return 0

func get_list_completed_count(level_list_name: String) -> int:
	if not level_list_exists(level_list_name):
		return 0
	var all_levels: Array[String] = get_levels_in_level_list(level_list_name)
	var completed_count: int = 0
	for level_name in all_levels:
		if is_level_completed_in_list(level_list_name, level_name):
			completed_count += 1
	return completed_count

func is_list_completable(level_list_name: String) -> bool:
	if not level_list_exists(level_list_name):
		return false
	var list_info: = _get_level_list(level_list_name)

	if list_info.get("always_hidden", false):
		if not list_info.get("always_hidden_levels_completable", false):
			return false
	var completion_mode: String = list_info.get("completion_mode", "")
	if completion_mode == LevelListSettings.COMPLETION_MODE_UNCOMPLETABLE:
		return false

	if get_levels_in_level_list(level_list_name).size() <= 0:
		return false
	return true

func is_every_bundled_completable_list_complete() -> bool:
	var completable_lists: Array[String] = []
	var all_bundled_list_infos: = get_all_level_list_infos(true)
	for list_info in all_bundled_list_infos:
		var list_name: String = list_info.get("name", "")
		if not list_name or not get_levels_in_level_list(list_name).size() > 0:
			continue
		if list_info.get("always_hidden", false):
			if not list_info.get("always_hidden_levels_completable", false):
				continue
		var completion_mode: String = list_info.get("completion_mode", "")
		if completion_mode == LevelListSettings.COMPLETION_MODE_UNCOMPLETABLE:
			continue
		completable_lists.append(list_name)

	for list_name in completable_lists:
		if not is_level_list_complete(list_name):
			return false
	return true

func will_list_unlock_list(level_list_name: String, check_unlocking_list_name: String) -> bool:
	var list_will_unlock_list: String = _get_list_unlocked_by_list(level_list_name)
	return list_will_unlock_list == check_unlocking_list_name

func get_next_list_of_bundled_list(level_list_name: String) -> String:
	var level_list_info: = _get_level_list(level_list_name)
	if not level_list_info or not is_level_list_bundled(level_list_name):
		return ""
	if level_list_info.get("always_hidden", false):
		return ""

	var custom_next_list_name: String = get_custom_next_list_of_bundled_list_info(level_list_info)
	if custom_next_list_name:
		return custom_next_list_name
	
	# If no custom next list set, or it's invalid, automatically pick the next list
	return _get_next_bundled_level_list_auto(level_list_name)

func get_custom_next_list_of_bundled_list_info(level_list_info: Dictionary) -> String:
	if level_list_info.get("custom_next_list", "auto") == "auto":
		return ""

	var custom_next_list_name: String = level_list_info.get("custom_next_list_name", "")
	if not custom_next_list_name in get_list_of_level_lists(true):
		return ""
	var custom_next_list_info: = _get_level_list(custom_next_list_name)
	if not _is_list_info_valid_next_list(custom_next_list_info):
		return ""
	return custom_next_list_name

func _get_list_unlocked_by_list(level_list_name: String) -> String:
	if not is_level_list_bundled(level_list_name):
		return ""

	var level_list_info: = _get_level_list(level_list_name)
	if level_list_info.get("always_hidden", false):
		return ""

	var when_completed_action: String = level_list_info.get("when_completed_action", LevelListSettings.WHEN_COMPLETED_UNLOCK_NEXT)
	if when_completed_action != LevelListSettings.WHEN_COMPLETED_UNLOCK_NEXT:
		return ""
	var next_list_name: String = get_next_list_of_bundled_list(level_list_name)
	if not is_level_list_bundled(next_list_name):
		return ""
	return next_list_name

func recheck_level_list_unlocks() -> void:
	var check_all: bool = _is_unlock_all_levels_and_lists()

	for level_list_name in get_list_of_level_lists(true):
		var list_will_unlock_list: String = _get_list_unlocked_by_list(level_list_name)
		if list_will_unlock_list and (check_all or not is_level_list_unlocked(list_will_unlock_list)):
			if is_level_list_complete(level_list_name):
				unlock_list_as_next(list_will_unlock_list)

func unlock_list_as_next(next_level_list_name: String) -> void:
	if not is_level_list_bundled(next_level_list_name):
		return
	_unlock_level_list(next_level_list_name)
	
	# If all levels are locked by default, unlock the first level in the list
	var level_list_info: = _get_level_list(next_level_list_name)
	if level_list_info.get("default_individual_locked", false):
		var levels_in_list: = get_levels_in_level_list(next_level_list_name)
		if levels_in_list.size() > 0:
			unlock_level_in_list(next_level_list_name, levels_in_list[0])

func unlock_level_code(level_code: String) -> void:
	unlock_level_in_list(_level_list_from_code(level_code), _level_name_from_code(level_code))

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
	if not is_level_list_unlocked(level_list_name):
		_unlock_level_list(level_list_name)
	_unlock_level_code(_level_code(level_list_name, level_name))

func _unlock_level_list(level_list_name: String) -> void:
	if not is_level_list_bundled(level_list_name):
		return
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

func _unlock_all_levels_in_list(level_list_name: String) -> void:
	var level_list_info: = _get_level_list(level_list_name)
	if not level_list_info:
		return
	var lists_with_all_unlocked: Array = get_game_save_data("lists_with_all_unlocked", [])
	lists_with_all_unlocked.append(level_list_name)

func _is_level_list_unlocked_in_save(level_list_name: String) -> bool:
	var unlocked_lists: Array = get_game_save_data("unlocked_lists", [])
	return level_list_name in unlocked_lists

func get_unlocked_levels_in_level_list(level_list_name: String, current_lvl_complete: bool = false) -> Array[String]:
	if not is_level_list_unlocked(level_list_name):
		return []
	var level_list_info: = _get_level_list(level_list_name)
	var existing_levels: = get_levels_in_level_list(level_list_name)
	var prog_unlock_num: int = level_list_info.get("progressive_locked_levels", 0)
	
	var default_locked: bool = level_list_info.get("default_individual_locked", false)
	
	var everything_is_unlocked: bool = _is_unlock_all_levels_and_lists()
	var all_in_list_unlocked: bool = _is_all_in_list_unlocked_in_save(level_list_name)

	var all_unlocked: bool = everything_is_unlocked or all_in_list_unlocked or (prog_unlock_num == 0 and not default_locked)

	var unlocked_levels: Array[String] = []
	var max_completed_idx: int = -1
	if not all_unlocked:
		max_completed_idx = _max_completed_idx_in_level_list(level_list_name, current_lvl_complete)

	for idx in existing_levels.size():
		if all_unlocked or (prog_unlock_num > 0 and max_completed_idx + prog_unlock_num >= idx):
			unlocked_levels.append(existing_levels[idx])
		elif _is_level_code_unlocked_in_save(_level_code(level_list_name, existing_levels[idx])):
			unlocked_levels.append(existing_levels[idx])
	return unlocked_levels

func is_level_code_unlocked(level_code: String, current_lvl_complete: bool = false) -> bool:
	return is_level_unlocked_in_list(_level_list_from_code(level_code), _level_name_from_code(level_code), current_lvl_complete)

func is_level_unlocked_in_list(level_list_name: String, level_name: String, current_lvl_complete: bool = false) -> bool:
	return level_name in get_unlocked_levels_in_level_list(level_list_name, current_lvl_complete)

func is_level_unlocked_in_any_list(level_name: String) -> bool:
	for level_list_name in get_list_of_level_lists():
		if is_level_unlocked_in_list(level_list_name, level_name):
			return true
	return false

func get_levels_to_show_in_level_list(level_list_name: String, as_edit_mode: bool = false, is_unlisted_levels: bool = false) -> Array[Dictionary]:
	var levels_with_info: Array[Dictionary] = []
	var level_list_info: = {}
	if not is_unlisted_levels:
		level_list_info = _get_level_list(level_list_name)
		if not level_list_info:
			return []
	else:
		level_list_name = ""
		level_list_info = {
			"show_locked_levels": true,
			"show_locked_titles": true,
		}

	var should_show_locked: bool = as_edit_mode or level_list_info.get("show_locked_levels", true)
	var unlocked_level_names: Array[String] = []
	var all_level_names: Array[String] = []
	if not is_unlisted_levels:
		unlocked_level_names = get_unlocked_levels_in_level_list(level_list_name)
		all_level_names = get_levels_in_level_list(level_list_name)
	else:
		all_level_names = get_list_of_unlisted_levels()
		unlocked_level_names = all_level_names

	var all_played_level_codes: Array = get_game_save_data("played_levels", [])
	var played_levels_in_this_list: Array[String] = []
	for level_code in all_played_level_codes:
		if not _level_list_from_code(level_code) == level_list_name:
			continue
		played_levels_in_this_list.append(_level_name_from_code(level_code))
	
	var show_locked_titles: bool = level_list_info.get("show_locked_titles", false) or as_edit_mode
	
	var is_bundled_list: bool = is_level_list_bundled(level_list_name)
	
	for level_name in all_level_names:
		var is_complete_normal: bool = is_level_completed_in_list(level_list_name, level_name)
		if is_unlisted_levels:
			is_complete_normal = is_level_completed_in_any_list(level_name)
		var level_title: String = FilesManager.get_level_title(get_identified_game_name(), level_name)
		var is_unlocked: bool = level_name in unlocked_level_names
		var display_title: String = "???"
		if is_unlocked or show_locked_titles:
			display_title = level_title
		levels_with_info.append({
			"level_name": level_name,
			"level_title": level_title,
			"display_title": display_title,
			"is_unlocked": is_unlocked,
			"is_played": level_name in played_levels_in_this_list,
			"is_completed": is_complete_normal,
			"is_any_completed": is_complete_normal or is_level_completed_in_any_list(level_name),
			"is_hidden": not (is_unlocked or should_show_locked),
			"is_bundled": is_bundled_list,
			"is_current_level": (loaded_level_name and level_name == loaded_level_name) and current_level_list == level_list_name,
		})
	return levels_with_info

func is_current_level_completed() -> bool:
	if not loaded_level_name:
		return false
	var list_containing_level: String = current_level_list
	if not list_containing_level:
		list_containing_level = get_list_containing_level(loaded_level_name)
	return is_level_completed_in_list(list_containing_level, loaded_level_name)

func is_level_completed_in_list(level_list_name: String, level_name: String) -> bool:
	if not FilesManager.level_exists(get_identified_game_name(), level_name):
		return false
	return _is_level_completed_in_save(level_list_name, level_name)

func is_level_completed_in_any_list(level_name: String) -> bool:
	if not FilesManager.level_exists(get_identified_game_name(), level_name):
		return false
	return _is_level_code_completed_in_save(_level_code("", level_name), true)

func is_every_level_completed() -> bool:
	for level_list_name in get_list_of_level_lists(true):
		if not is_list_completable(level_list_name):
			continue
		if not is_level_list_fully_completed(level_list_name):
			return false
	return true

func _max_completed_idx_in_level_list(level_list_name: String, current_lvl_complete: bool = false) -> int:
	if current_lvl_complete:
		if not current_level_list or current_level_list != level_list_name:
			current_lvl_complete = false
	var existing_levels: = get_levels_in_level_list(level_list_name)
	var max_completed_idx: int = -1
	for idx in existing_levels.size():
		if current_lvl_complete and existing_levels[idx] == loaded_level_name:
			max_completed_idx = idx
			continue
		if not _is_level_completed_in_save(level_list_name, existing_levels[idx]):
			continue
		max_completed_idx = idx
	return max_completed_idx

func _is_unlock_all_levels_and_lists() -> bool:
	return get_game_save_data("unlock_all_levels_and_lists", false)

func _is_all_in_list_unlocked_in_save(level_list_name: String) -> bool:
	var level_list_info: = _get_level_list(level_list_name)
	if not level_list_info:
		return false
	var lists_with_all_unlocked: Array = get_game_save_data("lists_with_all_unlocked", [])
	return level_list_name in lists_with_all_unlocked

func _is_level_code_unlocked_in_save(level_code: String) -> bool:
	var unlocked_codes: Array = get_game_save_data("unlocked_level_codes", [])
	return level_code in unlocked_codes

func _is_level_completed_in_save(level_list_name: String, level_name: String) -> bool:
	return _is_level_code_completed_in_save(_level_code(level_list_name, level_name))

func _is_level_code_completed_in_save(level_code: String, any_list: bool = false) -> bool:
	if not any_list and get_game_setting("levels_complete_in_any_list", true):
		any_list = true
	var completed_levels: Array = get_game_save_data("completed_levels", [])
	var level_name: String = _level_name_from_code(level_code)
	for completed_level_code in completed_levels:
		if completed_level_code == level_code:
			return true
		var completed_level: String = _level_name_from_code(completed_level_code)
		if any_list and completed_level == level_name:
			return true
	return false

# Do not change order of returned names, it is used for hash calculation
func get_list_of_all_bundled_levels() -> Array[String]:
	return _get_list_of_all_bundled_levels_for_game(get_identified_game_name(), game_definition)

func _get_list_of_all_bundled_levels_for_game(for_game_name: String, game_def: Dictionary) -> Array[String]:
	var level_names: Array[String] = []
	for level_list_info in game_def.get("level_lists", []):
		for level_name in level_list_info.get("level_names", []):
			if not level_name in level_names and FilesManager.level_exists(for_game_name, level_name):
				level_names.append(level_name)
	return level_names

func get_list_of_all_non_bundled_levels() -> Array[String]:
	var bundled_level_names: = get_list_of_all_bundled_levels()
	var non_bundled_level_names: Array[String] = []
	for level_name in FilesManager.get_level_list(get_identified_game_name()):
		if not level_name in bundled_level_names and not level_name in non_bundled_level_names:
			non_bundled_level_names.append(level_name)
	return non_bundled_level_names

func get_list_of_non_bundled_levels_in_lists() -> Array[String]:
	var non_bundled_level_names: Array[String] = []
	for level_list_info in non_bundled_level_lists:
		for level_name in level_list_info.get("level_names", []):
			if not level_name in non_bundled_level_names:
				non_bundled_level_names.append(level_name)
	return non_bundled_level_names

func is_level_bundled(level_name: String) -> bool:
	if not FilesManager.level_exists(get_identified_game_name(), level_name):
		return false
	return level_name in get_list_of_all_bundled_levels()

func is_level_code_valid_and_bundled(level_code: String) -> bool:
	if not is_level_code_valid(level_code) or not _level_list_from_code(level_code):
		return false
	if not is_level_list_bundled(_level_list_from_code(level_code)):
		return false
	if not is_level_bundled(_level_name_from_code(level_code)):
		return false
	return true

func get_list_of_all_levels_in_lists() -> Array[String]:
	var all_listed: Array[String] = get_list_of_all_bundled_levels()
	return Utility.arr_set_union(all_listed, get_list_of_non_bundled_levels_in_lists())

# Does not include editor autosave
func get_list_of_unlisted_levels() -> Array[String]:
	var all_listed_levels: = get_list_of_all_levels_in_lists()
	var all_unlisted_levels: Array[String] = []
	for level_name in FilesManager.get_level_list(get_identified_game_name()):
		if level_name == FilesManager.AUTO_SAVE_LEVEL_NAME:
			continue
		if not level_name in all_listed_levels and not level_name in all_unlisted_levels:
			all_unlisted_levels.append(level_name)
	return all_unlisted_levels

func get_first_existing_level_from_list(level_list_name: String) -> String:
	var level_list_info: = _get_level_list(level_list_name)
	for level_name in level_list_info.get("level_names", []):
		if FilesManager.level_exists(get_identified_game_name(), level_name):
			return level_name
	return ""

func get_starting_level_name() -> String:
	for level_list_info in get_all_level_list_infos():
		var first_level_name: = get_first_existing_level_from_list(level_list_info["name"])
		if first_level_name:
			return first_level_name
	return _fallback_starting_level()

func get_starting_level_and_list() -> Array:
	for level_list_info in get_all_level_list_infos():
		var first_level_name: = get_first_existing_level_from_list(level_list_info["name"])
		if first_level_name:
			return [level_list_info["name"], first_level_name]
	return ["", _fallback_starting_level()]

func _fallback_starting_level() -> String:
	# Fallback
	var unlisted_levels: = get_list_of_unlisted_levels()
	if unlisted_levels.size() > 0:
		return unlisted_levels[0]
	if FilesManager.level_exists(get_identified_game_name(), FilesManager.AUTO_SAVE_LEVEL_NAME):
		return FilesManager.AUTO_SAVE_LEVEL_NAME
	return ""


func add_level_to_level_list(level_name: String, level_list_name: String) -> void:
	var level_list_info: = _get_level_list(level_list_name)
	if not level_list_info:
		return
	
	var is_bundled: bool = is_level_list_bundled(level_list_name)
	if not level_name in level_list_info.get("level_names", []):
		if not level_list_info.has("level_names"):
			level_list_info["level_names"] = []
		if level_list_info["level_names"].has(level_name):
			return
		level_list_info["level_names"].append(level_name)
	if not is_bundled:
		non_bundled_lists_updated()

func move_level_to_level_list(level_name: String, level_list_name: String, from_list_name: String = "") -> void:
	var is_locked: bool = current_game_is_release_locked

	if not FilesManager.level_exists(get_identified_game_name(), level_name):
		return
	if not level_list_exists(level_list_name) or from_list_name and not level_list_exists(from_list_name):
		return
	if from_list_name and level_name not in get_levels_in_level_list(from_list_name):
		return
	
	if is_locked and is_level_list_bundled(level_list_name):
		return

	if from_list_name:
		if not is_locked or not is_level_list_bundled(from_list_name):
			_remove_level_from_list(level_name, from_list_name)
	elif not is_locked:
		_remove_level_from_all_lists(level_name, true)

	add_level_to_level_list(level_name, level_list_name)
	non_bundled_lists_updated()

func is_level_in_any_bundled_list(level_name: String) -> bool:
	for level_list_info in game_definition.get("level_lists", []):
		if level_name in level_list_info.get("level_names", []):
			return true
	return false

func is_level_in_any_list(level_name: String) -> bool:
	for level_list_info in get_all_level_list_infos():
		if level_name in level_list_info.get("level_names", []):
			return true
	return false

func get_list_containing_level(level_name: String) -> String:
	for level_list_info in get_all_level_list_infos():
		if level_name in level_list_info.get("level_names", []):
			return level_list_info["name"]
	return ""

func _remove_level_from_list(level_name: String, level_list_name: String) -> void:
	var level_list_info: = _get_level_list(level_list_name)
	if level_list_info:
		level_list_info["level_names"].erase(level_name)

func remove_level_from_list(level_name: String, level_list_name: String) -> void:
	_remove_level_from_list(level_name, level_list_name)
	if not is_level_list_bundled(level_list_name):
		non_bundled_lists_updated()


func get_next_level_in_list(level_list_name: String, after_level: String = "", require_unlocked: bool = false, current_lvl_complete: bool = false) -> String:
	var levels: = get_levels_in_level_list(level_list_name)
	if not levels.size() > 0:
		return ""

	var found: int = -1
	if after_level:
		found = levels.find(after_level)
		if found < 0:
			return ""
	
	for idx in range(found + 1, levels.size()):
		if not require_unlocked or is_level_unlocked_in_list(level_list_name, levels[idx], current_lvl_complete):
			return levels[idx]
	return ""


func get_advance_to_list_after_list(level_list_name: String) -> String:
	if not is_level_list_bundled(level_list_name):
		return ""
	
	return get_next_list_of_bundled_list(level_list_name)

func get_all_unlocked_level_lists(_current_level_as_complete: bool = false, only_bundled: bool = true) -> Array[Dictionary]:
	var lists: Array[Dictionary] = []
	for level_list_info in game_definition.get("level_lists", []):
		if not level_list_info.get("name", "") or not level_list_info.get("level_names", []):
			continue
		if is_level_list_unlocked(level_list_info["name"]):
			lists.append(level_list_info)
	if not only_bundled:
		for level_list_info in non_bundled_level_lists:
			if not level_list_info.get("name", "") or not level_list_info.get("level_names", []):
				continue
			lists.append(level_list_info)
	return lists

func get_all_visible_bundled_level_lists(current_level_as_complete: bool = false, exclude_current_hidden: bool = false) -> Array[Dictionary]:
	var lists: Array[Dictionary] = []
	var all_list_infos: = get_all_level_list_infos(true)
	var first_list: bool = true
	var hidden_current_list_info: Dictionary = {}
	for list_info in all_list_infos:
		if list_info.get("always_hidden", false) and not first_list:
			if current_level_list and list_info.get("name", "") == current_level_list:
				hidden_current_list_info = list_info
			continue
		first_list = false
		var hide_when_locked: bool = list_info.get("hide_when_locked", false)
		if hide_when_locked and not is_level_list_unlocked(list_info["name"], current_level_as_complete):
			continue
		var included_levels: = get_levels_in_level_list(list_info["name"])
		if not get_game_setting("show_empty_level_lists", false) and included_levels.size() == 0:
			continue
		lists.append(list_info)
	
	if not is_intermission_mode and not exclude_current_hidden and hidden_current_list_info:
		if loaded_level_name and loaded_level_name in get_levels_in_level_list(current_level_list):
			lists.push_front(hidden_current_list_info)
	
	return lists

func move_level_to_relative_list(level_name: String, from_list_name: String, delta: int) -> String:
	var list_info: = _get_level_list(from_list_name)
	if not list_info or not level_name in list_info.get("level_names", []):
		return ""
	var all_level_lists: = get_list_of_level_lists()
	var from_index: = all_level_lists.find(from_list_name)
	var to_index: = clampi(from_index + delta, 0, all_level_lists.size() - 1)
	if to_index == from_index:
		return ""
	move_level_to_level_list(level_name, all_level_lists[to_index], from_list_name)
	return all_level_lists[to_index]


func move_level_list_to_top_bottom(level_list_name: String, to_top: bool) -> void:
	var move_sign: int = -1 if to_top else 1
	move_level_list_relative(level_list_name, 1000000 * move_sign)

func move_level_list_relative(level_list_name: String, delta: int) -> void:
	var all_level_lists: = get_list_of_level_lists()
	if not level_list_name in all_level_lists:
		return
	var is_bundled: bool = is_level_list_bundled(level_list_name)
	var all_relevant_lists: Array[String] = []
	if is_bundled:
		all_relevant_lists = get_list_of_level_lists(true)
	else:
		all_relevant_lists = get_list_of_non_bundled_level_lists()
	var cur_index: = all_relevant_lists.find(level_list_name)
	if cur_index == -1:
		return
	var to_index: = clampi(cur_index + delta, 0, all_relevant_lists.size() - 1)
	all_relevant_lists.erase(level_list_name)
	all_relevant_lists.insert(to_index, level_list_name)
	if is_bundled:
		update_bundled_level_list_order(all_relevant_lists)
	else:
		update_non_bundled_level_lists_order(all_relevant_lists)


func add_level_to_list_index(level_name: String, is_bundled_lists: bool, to_index: int) -> String:
	var all_level_infos: Array
	if is_bundled_lists:
		all_level_infos = get_all_level_list_infos(true)
	else:
		all_level_infos = get_all_non_bundled_level_list_infos()

	if to_index < 0:
		to_index = all_level_infos.size() + to_index
	to_index = clampi(to_index, 0, all_level_infos.size() - 1)
	var list_name: String = all_level_infos[to_index]["name"]
	add_level_to_level_list(level_name, list_name)
	return list_name


func get_next_level_to_auto_load_code(after_level: String, current_level_as_complete: bool) -> String:
	if not after_level:
		after_level = loaded_level_name
	if not current_level_list or not after_level:
		return ""
	
	var level_list_info: = _get_level_list(current_level_list)
	if not level_list_info.get("auto_advance_enabled", true):
		return ""
	var next_level_in_list: = get_next_level_in_list(current_level_list, after_level, true, current_level_as_complete)
	if next_level_in_list:
		return _level_code(current_level_list, next_level_in_list)

	if not level_list_info.get("auto_advance_to_next_list", true):
		return ""

	var next_list_name: = get_advance_to_list_after_list(current_level_list)
	if not next_list_name:
		return ""
	#if not is_level_list_unlocked(next_list_name, current_level_as_complete):
		#return []
	return _level_code(next_list_name, get_first_existing_level_from_list(next_list_name))

func make_level_code(level_list_name: String, level_name: String) -> String:
	if not level_name or not FilesManager.level_exists(get_identified_game_name(), level_name):
		return ""
	if level_list_name:
		if not level_list_exists(level_list_name):
			level_list_name = ""
	return _level_code(level_list_name, level_name)

func _level_code(level_list_name: String, level_name: String) -> String:
	if not level_name:
		return ""
	return level_list_name + "??" + level_name

func is_a_level_code(level_code: String) -> bool:
	if not level_code or not level_code.contains("??"):
		return false
	return true

func is_level_code_valid(level_code: String) -> bool:
	if not level_code or not level_code.contains("??"):
		return false
	var level_name: = _level_name_from_code(level_code)
	if not level_name or not FilesManager.level_exists(get_identified_game_name(), level_name):
		return false
	var level_list_name: = _level_list_from_code(level_code)
	if level_list_name: 
		if not level_list_exists(level_list_name):
			return false
		if not level_name in get_levels_in_level_list(level_list_name):
			return false
	return true

func _level_list_from_code(level_code: String) -> String:
	if not level_code:
		return ""
	return level_code.split("??")[0]

func _level_name_from_code(level_code: String) -> String:
	if not level_code:
		return ""
	return level_code.split("??")[1]

func split_level_code(level_code: String, validate_code: bool = false) -> Array[String]:
	if not is_a_level_code(level_code):
		return ["", ""]
	if validate_code and not is_level_code_valid(level_code):
		return ["", ""]
	return [_level_list_from_code(level_code), _level_name_from_code(level_code)]

func goto_level_code(level_code: String, as_queued_load: bool = false) -> void:
	goto_level_in_level_list(_level_list_from_code(level_code), _level_name_from_code(level_code), as_queued_load)

func goto_level_in_level_list(level_list_name: String, level_name: String, as_queued_load: bool = false) -> void:
	if not cur_scene == "Play":
		push_error("goto level not in play scene")
		return
	if is_in_level_edit_mode:
		return
	
	var level_code: String = _level_code(level_list_name, level_name)
	save_level_code_as_current_visited(level_code)
	
	var level_list_info: = _get_level_list(level_list_name)
	if level_list_info:
		if not level_name in level_list_info.get("level_names", []):
			current_level_list = ""
		else:
			current_level_list = level_list_name
	else:
		current_level_list = ""
	
	try_load_level(level_name, as_queued_load)

func save_level_code_as_current_visited(to_level_code: String) -> void:
	if not is_level_code_valid(to_level_code):
		return
	_save_level_code_as_played(to_level_code)
	set_game_save_data("last_played_level", to_level_code)
	
	var level_list_name: String = _level_list_from_code(to_level_code)
	if level_list_exists(level_list_name):
		current_level_list = level_list_name
	else:
		current_level_list = ""

func save_level_code_as_played(to_level_code: String) -> void:
	if not is_level_code_valid(to_level_code):
		return
	_save_level_code_as_played(to_level_code)

func _save_level_code_as_played(to_level_code: String) -> void:
	if not to_level_code in get_game_save_data("played_levels", []):
		var played_levels: Array = get_game_save_data("played_levels", [])
		played_levels.append(to_level_code)
		set_game_save_data("played_levels", played_levels)



func _complete_level(level_list_name: String, level_name: String) -> Dictionary:
	if is_in_level_edit_mode:
		return {}

	var ret: Dictionary = {
		"is_complete": true,
		"completed": false,
		"game_was_completed": false,
		"intermissions": Array([], TYPE_STRING, "", null),
	}
	var level_code: String = _level_code(level_list_name, level_name)
	var completed_levels: Array = get_game_save_data("completed_levels", [])
	var intermissions: Array[String] = []
	
	
	var was_every_level_complete: bool = has_intermission_flag(INTERM_FULL_COMPLETE_FLAG)

	var level_list_was_complete: bool = true
	var list_was_all_complete: bool = true
	if level_list_name:
		level_list_was_complete = is_level_list_complete(level_list_name)
		list_was_all_complete = is_level_list_fully_completed(level_list_name)

	var was_game_complete: bool = is_game_completed()

	if not level_code in completed_levels:
		ret["completed"] = true
		completed_levels.append(level_code)
		set_game_save_data("completed_levels", completed_levels)
		intermissions.append_array(get_intermissions_for_level_code_event(level_code, IntermissionEvents.LEVEL_COMPLETE))

	recheck_level_list_unlocks()
	if not level_list_was_complete and is_level_list_complete(level_list_name):
		intermissions.append_array(get_intermissions_for_list_event(level_list_name, IntermissionEvents.LEVEL_LIST_COMPLETE))
	
	if not list_was_all_complete and is_level_list_fully_completed(level_list_name):
		intermissions.append_array(get_intermissions_for_list_event(level_list_name, IntermissionEvents.LEVEL_LIST_ALL_COMPLETE))
	
	if not was_game_complete:
		var game_is_now_complete: bool = check_for_game_completion()
		if game_is_now_complete:
			ret["game_was_completed"] = true
			intermissions.append_array(get_intermissions_for_game_event(IntermissionEvents.GAME_COMPLETE))
			
	if not was_every_level_complete and is_every_level_completed():
		# dont require viewing the intermissions for this flag, just set it
		set_intermission_flag(INTERM_FULL_COMPLETE_FLAG)
		intermissions.append_array(get_intermissions_for_game_event(IntermissionEvents.GAME_ALL_COMPLETE))

	ret["intermissions"] = intermissions
	return ret

# Complete the current level in the current list and persist any pending dependant save file updates
func complete_current_level_for_transition() -> Dictionary:
	return _complete_current_level()

# Make sure to show the intermissions for completing the level and list, since we're not leaving the level, they show as overlay
func complete_current_level_without_transition(extra_intermissions: Array = []) -> void:
	var result: Dictionary = _complete_current_level()
	var intermissions: Array[String] = []
	intermissions.append_array(extra_intermissions)
	intermissions.append_array(result.get("intermissions", []))
	if intermissions.size() > 0:
		show_overlay_intermissions(intermissions)

func _complete_current_level() -> Dictionary:
	if is_in_level_edit_mode or not loaded_level_name:
		return {}
	
	var complete_in_list: String = current_level_list
	var list_of_loaded_level: String = get_list_containing_level(loaded_level_name)
	if not complete_in_list and list_of_loaded_level:
		complete_in_list = list_of_loaded_level
	var result: Dictionary = _complete_level(complete_in_list, loaded_level_name)
	if result.get("is_complete", false):
		MapManager.flush_save_persist_on_completion()
	else:
		# don't know if this is needed or makes sense
		# note that if a state is loaded it will load the new save persist stuff,
		#   so loading a fresh level state or another level wont carry over the save persist stuff
		pass#MapManager.clear_save_persist_on_completion()

	var intermissions: Array[String] = []
	intermissions.assign(result.get("intermissions", []))
	return {
		"is_complete": result.get("is_complete", false),
		"completed": result.get("completed", false),
		"game_was_completed": result.get("game_was_completed", false),
		"intermissions": intermissions,
	}

func move_to_next_level(with_delay: float = 0, extra_intermissions: Array = []) -> void:
	if cur_scene != "Play" or is_in_level_edit_mode:
		return
	if not current_level_list and get_list_containing_level(loaded_level_name):
		current_level_list = get_list_containing_level(loaded_level_name)
	var next_level_in_list: String = get_next_level_in_list(current_level_list, loaded_level_name, true, true)
	if not next_level_in_list:
		return
	
	var intermissions: Array[String] = []
	intermissions.append_array(extra_intermissions)

	var adv_to_info: Array = get_advance_to_code_or_special(false)
	var advance_to_special: String = adv_to_info[0]
	var advance_to_code: String = adv_to_info[1]
	
	if advance_to_code and not advance_to_special:
		if not is_level_code_unlocked(advance_to_code):
			advance_to_code = ""
			advance_to_special = "select"

	if not advance_to_special and not advance_to_code:
		show_overlay_intermissions(intermissions)
		return
	_advance_to_special_or_code_with_intermissions(with_delay, advance_to_special, advance_to_code, intermissions)

func advance_level(with_delay: float = 0, advance_to_code: String = "", extra_intermissions: Array = []) -> void:
	if cur_scene != "Play" or is_in_level_edit_mode:
		return
	if not current_level_list and get_list_containing_level(loaded_level_name):
		current_level_list = get_list_containing_level(loaded_level_name)
	var result: Dictionary = complete_current_level_for_transition()
	
	var transition_intermissions: Array[String] = []
	transition_intermissions.append_array(extra_intermissions)
	transition_intermissions.append_array(result.get("intermissions", []))

	var advance_to_special: String = ""
	
	if not advance_to_code:
		var adv_to_info: Array = get_advance_to_code_or_special()
		advance_to_special = adv_to_info[0]
		advance_to_code = adv_to_info[1]

	if result.get("game_was_completed", false):
		if get_game_setting("game_end_replace_transition", false):
			advance_to_special = "end"

	if not advance_to_special and not advance_to_code:
		show_overlay_intermissions(transition_intermissions)
		return
	_advance_to_special_or_code_with_intermissions(with_delay, advance_to_special, advance_to_code, transition_intermissions)

func _advance_to_special_or_code_with_intermissions(with_delay: float = 0, to_special: String = "", to_code: String = "", interm_q: Array[String] = []) -> void:
	if to_special == "end":
		_go_to_game_end(with_delay, interm_q)
	elif to_special == "select":
		_go_to_level_select(with_delay, interm_q)
	elif to_special:
		push_error("Unknown advance 'special': %s" % [to_special])
		show_overlay_intermissions(interm_q)
	elif not to_code or not _level_name_from_code(to_code):
		push_error("unknown advance to level code: %s" % [to_code])
		show_overlay_intermissions(interm_q)
	else:
		_move_to_code_with_delay(to_code, with_delay, true, interm_q)

# External API for gameplay level transition with completing current level
func move_to_level_code(level_code: String, with_delay: float = 0) -> void:
	if cur_scene != "Play" or is_in_level_edit_mode:
		return
	var list_name: = _level_list_from_code(level_code)
	var level_name: = _level_name_from_code(level_code)
	move_to_level(list_name, level_name, with_delay)


func complete_and_move_to_level(level_list_name: String, level_name: String, with_delay: float = 0, extra_intermissions: Array = []) -> void:
	var to_level_code: String = _level_code(level_list_name, level_name)
	advance_level(with_delay, to_level_code, extra_intermissions)

func complete_and_move_to_level_select(with_delay: float = 0, extra_intermissions: Array = []) -> void:
	var result: Dictionary = complete_current_level_for_transition()
	var intermissions: Array[String] = []
	intermissions.append_array(extra_intermissions)
	intermissions.append_array(result.get("intermissions", []))
	_go_to_level_select(with_delay, intermissions)

func move_to_level_select(with_delay: float = 0, with_intermissions: Array = []) -> void:
	_go_to_level_select(with_delay, Array(with_intermissions, TYPE_STRING, "", null))


# External API for gameplay/level select level transition without completing current level
func move_to_level(level_list_name: String, level_name: String, with_delay: float = 0, extra_intermissions: Array = []) -> void:
	if cur_scene != "Play" or is_in_level_edit_mode:
		return
	var level_code: String = _level_code(level_list_name, level_name)
	_move_to_code_with_delay(level_code, with_delay, true, extra_intermissions)

func move_to_level_list_start(level_list_name: String, with_delay: float = 0, complete_current: bool = false, extra_intermissions: Array = []) -> void:
	if cur_scene != "Play" or is_in_level_edit_mode:
		return
	var existing_levels: = get_levels_in_level_list(level_list_name)
	if not existing_levels.size() > 0:
		return
	var to_level_code: String = _level_code(level_list_name, existing_levels[0])
	if complete_current:
		advance_level(with_delay, to_level_code, extra_intermissions)
	else:
		_move_to_code_with_delay(to_level_code, with_delay, true, extra_intermissions)


# Check for list transitions to add intermissions
func _move_to_code_with_delay(level_code: String, with_delay: float, also_unlock: bool, interm_q: Array) -> void:
	if GameManager.cur_scene != "Play" or GameManager.is_in_level_edit_mode:
		return
	
	var to_level_list: = _level_list_from_code(level_code)
	if current_level_list and to_level_list and current_level_list != to_level_list:
		interm_q.append_array(get_intermissions_for_list_event(to_level_list, IntermissionEvents.LEVEL_LIST_START))

	_move_to_level_by_code_with_delay(level_code, with_delay, also_unlock, interm_q)

# Skip checking list transition
func _move_to_level_by_code_with_delay(level_code: String, with_delay: float, also_unlock: bool, interm_q: Array) -> void:
	if also_unlock and not is_level_code_unlocked(level_code):
		unlock_level_code(level_code)
	
	var intermissions: Array[String] = []
	intermissions.append_array(interm_q)
	intermissions.append_array(get_intermissions_for_level_code_event(level_code, IntermissionEvents.LEVEL_START))
	_queue_goto_level_with_intermissions(level_code, intermissions, with_delay)
	#if with_delay <= 0:
		#goto_level_code(level_code)
	#else:
		#set_game_save_data("last_played_level", level_code)
		#queue_delayed_goto_level(with_delay, level_code)

func get_advance_to_code_or_special(with_current_level_as_complete: bool = true) -> Array:
	if not loaded_level_name or not current_level_list or current_level_is_museum:
		return ["", ""]
	
	var auto_load_code: String = get_next_level_to_auto_load_code(loaded_level_name, with_current_level_as_complete)
	if auto_load_code:
		return ["", auto_load_code]
	
	if not has_any_unlocked_levels():
		push_warning("No unlocked levels")
		return ["select", ""]
	else:
		return ["select", ""]
	
func has_level_advance() -> bool:
	if cur_scene != "Play":
		return false
	var auto_load_code: String = get_next_level_to_auto_load_code(loaded_level_name, true)
	if auto_load_code:
		return true
	return false


func _go_to_level_select(with_delay: float = 0, interm_q: Array[String] = []) -> void:
	if with_delay > 0:
		queue_delayed_other_load(with_delay, _go_to_level_select.bind(0, interm_q))
		return

	if cur_scene != "Play":
		return
	if get_pause("pause_menu"):
		close_pause_menu()
	
	if interm_q.size() > 0:
		_now_goto_level_select_with_intermissions(interm_q)
	else:
		_go_to_level_select_for_real()

func _go_to_level_select_for_real() -> void:
	var level_select_root = Utility.get_level_select_root()
	if level_select_root:
		level_select_root.open_level_select()
	else:
		push_warning("Level select root not found")

func get_after_game_level_code() -> String:
	var post_end_level_code: String = get_game_setting("game_end_transition_level_code", "")
	if not is_level_code_valid_and_bundled(post_end_level_code):
		return ""
	return post_end_level_code

func _go_to_game_end(with_delay: float = 0, interm_q: Array[String] = []) -> void:
	var post_end_level_code: String = get_after_game_level_code()
	prints("go to game end, code: %s" % [post_end_level_code])
	if not post_end_level_code:
		_go_to_level_select(with_delay, interm_q)
		return
	else:
		_move_to_code_with_delay(post_end_level_code, with_delay, true, interm_q)

func start_playing(in_level_edit_mode: bool = false) -> void:
	if cur_scene == "Play":
		return
	is_in_level_edit_mode = in_level_edit_mode
	change_scene("Play")

func play_first_level(extra_intermissions: Array[String] = []) -> void:
	if is_in_level_edit_mode:
		push_warning("Trying to call play_first_level in level edit mode")
		return
	var first_level_and_list: Array = get_starting_level_and_list()
	if first_level_and_list.size() < 2 or not first_level_and_list[1]:
		new_empty_level()
		GlobalToaster.show_toast("No levels")
		return
	var level_code: String = _level_code(first_level_and_list[0], first_level_and_list[1])
	current_level_list = ""
	goto_level_with_starting_intermissions(level_code, extra_intermissions)
	#goto_level_in_level_list(first_level_and_list[0], first_level_and_list[1])


func get_game_save_current_level_if_exists() -> String:
	var cur_save_level_code: String = get_game_save_data("last_played_level", "")
	if not cur_save_level_code:
		return ""
	var level_name: = _level_name_from_code(cur_save_level_code)
	if not FilesManager.level_exists(get_identified_game_name(), level_name):
		return ""
	return level_name

func get_game_save_current_level_code() -> String:
	var cur_save_level_code: String = get_game_save_data("last_played_level", "")
	if not cur_save_level_code:
		return ""
	return cur_save_level_code

func get_game_save_current_level_list() -> String:
	var cur_save_level_code: String = get_game_save_data("last_played_level", "")
	var level_list_name: = _level_list_from_code(cur_save_level_code)
	if not level_list_name and _level_name_from_code(cur_save_level_code):
		level_list_name = get_list_containing_level(_level_name_from_code(cur_save_level_code))
	return level_list_name

func play_current_save_level() -> void:
	if is_in_level_edit_mode:
		return
	
	var intermissions: Array[String] = []
	# If the game was already completed but the ending sequence hasn't been viewed, show it when starting from the menu
	if is_game_completed() and not has_viewed_game_completion():
		intermissions.append_array(get_intermissions_for_game_event(IntermissionEvents.GAME_COMPLETE))

	var cur_save_level: String = get_game_save_current_level_if_exists()
	if not cur_save_level:
		play_first_level(intermissions)
		return

	var level_list_name: = get_game_save_current_level_list()
	move_to_level(level_list_name, cur_save_level, 0, intermissions)


func get_new_player_profile(with_id: String = "") -> PlayerProfile:
	var new_profile_name: = Utility.random_animal()

	if not with_id:
		with_id = FilesManager.get_available_player_id()
	new_profile_name += " %s" % [with_id]
	var new_profile: = FilesManager.create_player_profile(with_id)
	new_profile.set_profile_setting("profile_name", new_profile_name)
	return new_profile

func switch_to_new_player_profile() -> void:
	var new_profile_id: String = FilesManager.get_available_player_id()
	var _new_profile: = get_new_player_profile(new_profile_id)
	load_player_profile(new_profile_id)

func load_player_profile(player_id: String) -> void:
	var first_load: bool = player_profile == null
	if not FilesManager.player_profile_exists(player_id):
		push_error("Player profile %s does not exist" % [player_id])
		return
	_cur_profile_id = player_id
	FilesManager.set_last_profile_id(player_id)
	player_profile = FilesManager.get_player_profile(player_id)
	after_profile_changed()
	if not first_load:
		profile_switched.emit()

func after_profile_changed() -> void:
	update_mute()

func get_last_loaded_or_new_player_profile_id() -> String:
	var last_profile_id: String = FilesManager.get_last_profile_id()

	if not last_profile_id or not FilesManager.player_profile_exists(last_profile_id):
		var profile_list: Array = FilesManager.get_player_profile_list()
		if profile_list.size() < 1:
			var new_profile_id: = FilesManager.get_available_player_id()
			var _new_profile: = get_new_player_profile(new_profile_id)
			return new_profile_id
		else:
			return profile_list[0]
	else:
		return last_profile_id

func load_last_loaded_or_new_player_profile() -> void:
	var profile_id: String = get_last_loaded_or_new_player_profile_id()
	load_player_profile(profile_id)

func get_profile_names() -> Dictionary:
	return FilesManager.get_player_profile_name_dict()

func get_game_save_data(data_key: String, default_value: Variant = null) -> Variant:
	if not player_profile:
		push_error("No player profile loaded")
		return default_value
	if not get_identified_game_name():
		push_warning("Trying to get game save data but no current game")
		return default_value
	return player_profile.get_game_save_data(get_identified_game_name(), data_key, default_value)

func set_game_save_data(data_key: String, value: Variant, flush: bool = true) -> void:
	if not player_profile:
		push_error("No player profile loaded")
		return
	if not get_identified_game_name():
		push_warning("Trying to set game save data but no current game")
		return
	player_profile.set_game_save_data(get_identified_game_name(), data_key, value, flush)
	flag_counts_changed.emit()

func clear_game_save_data(data_key: String) -> void:
	if not player_profile:
		push_error("No player profile loaded")
		return
	if not get_identified_game_name():
		push_warning("Trying to clear game save data but no current game")
		return
	player_profile.clear_game_save_data(get_identified_game_name(), data_key)
	flag_counts_changed.emit()

func has_game_save_data(data_key: String) -> bool:
	if not player_profile:
		push_error("No player profile loaded")
		return false
	if not get_identified_game_name():
		push_warning("Trying to check if game save data exists but no current game")
		return false
	return player_profile.has_game_save_data(get_identified_game_name(), data_key)


func get_dummy_save_data(data_key: String, default_value: Variant = null) -> Variant:
	return dummy_save_data.get(data_key, default_value)

func set_dummy_save_data(data_key: String, value: Variant) -> void:
	dummy_save_data[data_key] = value
	flag_counts_changed.emit()

func clear_dummy_save_data(data_key: String) -> void:
	dummy_save_data.erase(data_key)
	flag_counts_changed.emit()

func has_dummy_save_data(data_key: String) -> bool:
	return dummy_save_data.has(data_key)

func get_game_save_data_or_dummy(data_key: String, default_value: Variant = null) -> Variant:
	if is_in_level_edit_mode:
		return get_dummy_save_data(data_key, default_value)
	else:
		return get_game_save_data(data_key, default_value)

func set_game_save_data_or_dummy(data_key: String, value: Variant, flush: bool = true) -> void:
	if is_in_level_edit_mode:
		set_dummy_save_data(data_key, value)
	else:
		set_game_save_data(data_key, value, flush)

func clear_game_save_data_or_dummy(data_key: String) -> void:
	if is_in_level_edit_mode:
		clear_dummy_save_data(data_key)
	else:
		clear_game_save_data(data_key)

func has_game_save_data_or_dummy(data_key: String) -> bool:
	if is_in_level_edit_mode:
		return has_dummy_save_data(data_key)
	else:
		return has_game_save_data(data_key)


func get_profile_name() -> String:
	if not player_profile:
		push_error("No player profile loaded")
		return ""
	return player_profile.get_profile_setting("profile_name", "UNNAMED")

func set_profile_name(new_profile_name: String) -> void:
	if not new_profile_name:
		return
	if not player_profile:
		push_error("No player profile loaded")
		return
	player_profile.set_profile_setting("profile_name", new_profile_name)


func get_game_bg_info() -> Dictionary:
	var game_bg_info: Dictionary = get_game_setting("bg_style", {})
	return game_bg_info.merged(default_bg_style)

# get current background style, inheriting missing keys if necessary
func get_current_bg_info() -> Dictionary:
	if cur_scene != "Play":
		return get_game_bg_info()
	
	if is_intermission_mode:
		var showing_intermission_id: String = intermission_state.get("showing_id", "")
		if has_tagged_intermission_id(showing_intermission_id):
			var intermission_bg_info: Dictionary = get_tagged_intermission_info(showing_intermission_id).get("bg_style", {})
			if not intermission_bg_info:
				return get_game_bg_info()
			else:
				return intermission_bg_info.merged(get_game_bg_info())

	var game_bg_info: Dictionary = get_game_bg_info().duplicate_deep()
	var level_list_bg_info: Dictionary = {}
	var level_select_root: = Utility.get_level_select_root()
	if is_in_level_edit_mode and level_select_root and level_select_root.visible:
		var level_select_ui = level_select_root.level_select_ui
		if level_select_ui.editing_settings_of_list:
			var list_info: = _get_level_list(level_select_ui.editing_settings_of_list)
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

func get_level_bg_info_from_level_data(level_data: Dictionary) -> Dictionary:
	var map_metadata: Dictionary = level_data.get("state", {}).get("map", {}).get("metadata", {})
	if not map_metadata:
		return {}
	if not map_metadata.has("bg_style"):
		return {}
	return map_metadata["bg_style"]

func set_level_bg_info_into_level_data(level_data: Dictionary, bg_info: Dictionary) -> bool:
	var map: Dictionary = level_data.get("state", {}).get("map", {})
	if not map:
		push_warning("Level data has no map")
		return false
	if not map.has("metadata"):
		map["metadata"] = {}
	map["metadata"]["bg_style"] = bg_info
	return true

func _remap_texture_id_in_level_data(from_texture_id: int, to_texture_id: int, level_data: Dictionary) -> bool:
	var level_bg_info: Dictionary = get_level_bg_info_from_level_data(level_data)
	if not level_bg_info:
		return false
	var new_level_bg_info: Dictionary = remap_texture_id_in_bg_style(from_texture_id, to_texture_id, level_bg_info)
	if new_level_bg_info == level_bg_info:
		return false
	return set_level_bg_info_into_level_data(level_data, new_level_bg_info)

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
		MapManager.erase_metadata_value("bg_style")
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
		if level_select_ui.editing_settings_of_list:
			remove_level_list_custom_bg_info(level_select_ui.editing_settings_of_list)
	else:
		remove_current_level_custom_bg_info()

func current_has_bg_info() -> bool:
	if cur_scene != "Play":
		return false
	var level_select_root: = Utility.get_level_select_root()
	if level_select_root and level_select_root.visible:
		var level_select_ui = level_select_root.level_select_ui
		if level_select_ui.editing_settings_of_list:
			var list_info: = _get_level_list(level_select_ui.editing_settings_of_list)
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
			if level_select_ui.editing_settings_of_list:
				set_level_list_bg_info_value(level_select_ui.editing_settings_of_list, key, value)
		else:
			set_level_bg_info_value(key, value)

func copy_game_bg_to_current() -> void:
	if cur_scene != "Play":
		return
	var level_select_root: = Utility.get_level_select_root()
	if level_select_root and level_select_root.visible:
		var level_select_ui = level_select_root.level_select_ui
		if level_select_ui.editing_settings_of_list:
			copy_game_bg_to_level_list(level_select_ui.editing_settings_of_list)
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


func get_current_game_profile_setting_v(keys: Array, default_value: Variant) -> Variant:
	return player_profile.get_profile_setting_v([get_identified_game_name()] + keys, default_value)

func set_current_game_profile_setting_v(keys: Array, value: Variant) -> void:
	player_profile.set_profile_setting_v([get_identified_game_name()] + keys, value)


func get_current_game_profile_setting_1(key: String, default_value: Variant) -> Variant:
	return player_profile.get_profile_setting_v([get_identified_game_name(), key], default_value)

func set_current_game_profile_setting_1(key: String, value: Variant) -> void:
	player_profile.set_profile_setting_v([get_identified_game_name(), key], value)


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
	if not OS.has_feature("web") or not get_identified_game_name():
		return
	if not FilesManager.level_exists(get_identified_game_name(), level_name):
		return
	var level_bytes: PackedByteArray = FilesManager.get_level_file_bytes(get_identified_game_name(), level_name)
	var level_filename: = FilesManager.sanitize_level_filename(level_name) + ".json"
	JavaScriptBridge.download_buffer(level_bytes, level_filename, "application/json")

func web_export_current_edited_level_json(with_filename: String = "") -> void:
	if not editor_save:
		return
	if not with_filename or with_filename == "LEVEL" or with_filename == "OOPS":
		with_filename = "Unsaved_" + Utility.random_animal()
	var level_data: = get_play_state_as_level_data(editor_save, with_filename)
	if not level_data:
		return
	var level_bytes: PackedByteArray = JSON.stringify(level_data, "", false).to_utf8_buffer()
	var level_filename: = FilesManager.sanitize_level_filename(level_data["name"]) + ".json"
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
		
		if Utility.is_mobile():
			file_dialog.use_native_dialog = true
			file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)

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
	if not OS.has_feature("web") or not get_identified_game_name():
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
		"for_game": get_identified_game_name(),
		"for_version": get_version_for_data(),
		"list_name": level_list_info["name"],
		"level_filenames": [],
		"level_titles": {},
		"level_data": {},
	}
	var included_levels: Array = []
	for level_name in level_list_info.get("level_names", []):
		if level_name in included_levels or not FilesManager.level_exists(get_identified_game_name(), level_name):
			continue
		included_levels.append(level_name)
	
	for level_name in level_list_info.get("level_names", []):
		if level_name in included_levels:
			bundle_data["level_filenames"].append(FilesManager.sanitize_level_filename(level_name))
	
	for level_name in included_levels:
		var level_data: = FilesManager.get_level_data(get_identified_game_name(), level_name)
		bundle_data["level_data"][level_name] = level_data
		bundle_data["level_titles"][level_name] = FilesManager.get_level_title(get_identified_game_name(), level_name)
	
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
	
	if Utility.is_mobile():
		file_dialog.use_native_dialog = true
		file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)

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
	if not OS.has_feature("web") or not get_identified_game_name():
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
	if not game_name_confirmed and for_game_name != get_identified_game_name():
		var confirm_dialog: = ConfirmationDialog.new()
		confirm_dialog.title = "Import Level List"
		confirm_dialog.dialog_text = ("This level list is for a game named '%s'. The current game is '%s'.\n" \
									+ "Do you still want to import the levels?") % [for_game_name, get_identified_game_name()]
		
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
	var existing_levels: = FilesManager.get_level_list(get_identified_game_name())
	
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
		if not FilesManager.save_level_to_name(get_identified_game_name(), data, remapped_names[old_level_name]):
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

func level_data_get_map_metadata(level_data: Dictionary) -> Dictionary:
	return level_data.get("state", {}).get("map", {}).get("metadata", {})

func level_data_set_map_metadata(level_data: Dictionary, map_metadata: Dictionary) -> void:
	if not level_data.get("state", {}).get("map", {}):
		level_data["state"]["map"] = {}
	level_data["state"]["map"]["metadata"] = map_metadata

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

func _level_data_has_any_entities(level_data: Dictionary) -> bool:
	if not level_data.has("state"):
		return false
	if not level_data["state"].has("entities"):
		return false
	if not level_data["state"]["entities"].get("entity_list", []).size() > 0:
		return false
	return true

func _make_entity_data_short(level_data: Dictionary) -> Dictionary:
	level_data = level_data.duplicate_deep()
	if not _level_data_has_any_entities(level_data):
		return level_data
	
	var template_entity: BaseEntity = BaseEntity.new()
	var default_template_data: Dictionary = template_entity.serialize(true)
	
	var old_entity_list: Array = level_data["state"]["entities"]["entity_list"]
	level_data["state"]["entities"]["entity_list"] = []
	for entity_data in old_entity_list:
		if not typeof(entity_data) == TYPE_DICTIONARY:
			continue
		var minified_entity: Dictionary = {}
		for key in entity_data.keys():
			if key not in default_template_data:
				minified_entity[key] = entity_data[key]
			elif default_template_data[key] != entity_data[key]:
				minified_entity[key] = entity_data[key]
		if minified_entity["next_tile_pos"] == minified_entity["tile_position"]:
			minified_entity.erase("next_tile_pos")
		level_data["state"]["entities"]["entity_list"].append(minified_entity)
	return level_data

func _expand_entity_data(level_data: Dictionary) -> Dictionary:
	level_data = level_data.duplicate_deep()
	if not _level_data_has_any_entities(level_data):
		return level_data
	
	var template_entity: BaseEntity = BaseEntity.new()
	var default_template_data: Dictionary = template_entity.serialize(true)
	
	var old_entity_list: Array = level_data["state"]["entities"]["entity_list"]
	level_data["state"]["entities"]["entity_list"] = []
	for compressed_entity in old_entity_list:
		if not typeof(compressed_entity) == TYPE_DICTIONARY:
			continue
		if not compressed_entity.has("next_tile_pos"):
			compressed_entity["next_tile_pos"] = compressed_entity["tile_position"].duplicate()

		var expanded_entity: Dictionary = default_template_data.duplicate_deep()
		expanded_entity.merge(compressed_entity, true)
		level_data["state"]["entities"]["entity_list"].append(expanded_entity)
	return level_data
	
	


func clipboardify_level_data(level_data: Dictionary) -> String:
	var with_short_entities: = _make_entity_data_short(level_data)

	var stringified: = JSON.stringify(with_short_entities, "", false)
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
	return _expand_entity_data(parsed_data)
	#return parsed_data

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
	save_edited()
	loaded_level = editor_save
	return true

func add_imported_level_data(level_data: Dictionary) -> String:
	var existing_lists: = get_list_of_level_lists()
	if not "Imported Levels" in existing_lists:
		add_empty_level_list("Imported Levels", false)
	
	var existing_levels: = FilesManager.get_level_list(get_identified_game_name())
	var level_name: String = level_data.get("name", "")
	var unique_level_name: = get_unique_import_level_name(existing_levels, level_name, level_data_get_title(level_data, ""))
	if not unique_level_name:
		push_error("Failed to find a unique name for the imported level")
		return ""
	
	if not FilesManager.save_level_to_name(get_identified_game_name(), level_data, unique_level_name):
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
	if undo_stack.size() == 1:
		return not cur_undo_is_current_state
	return undo_stack.size() > 1

func clear_undo_stack() -> void:
	undo_stack.clear()
	undo_checkpoints.clear()
	undo_checkpoints_created.clear()
	next_undo_checkpoint_id = 0
	has_new_undo_since_checkpoint = false

# if as_current_state is false, will immediately be able to rewind to this state
# if as_current_state is true, undoing will skip this state if undoing before setting cur_undo_is_current_state to false
func push_undo_state(as_current_state: bool, with_state: Dictionary = {}, is_exact_checkpoint: bool = false) -> void:
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
	
	if is_exact_checkpoint:
		cur_state["is_reset_point"] = true

	undo_stack.append(cur_state)
	if undo_stack.size() > MAX_UNDO_LIMIT:
		remove_oldest_undo_state()
	cur_undo_is_current_state = as_current_state
	has_new_undo_since_checkpoint = not is_exact_checkpoint

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
	if queued_level_load:
		return
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
	if popped_state.get("is_reset_point", false):
		has_new_undo_since_checkpoint = false

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

func adjust_web_pssfx_volume() -> void:
	var pssfx_bus_idx: int = AudioServer.get_bus_index("LowPassSfx")
	AudioServer.set_bus_volume_linear(pssfx_bus_idx, 0.3)

func update_mute() -> void:
	is_muted = player_profile.get_profile_setting("mute_all_audio", false)
	
	var bus_idx: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus_idx, is_muted)

func get_all_levels_included_in_list_data(list_infos: Array) -> Array[String]:
	var all_level_names: = []
	for list_info in list_infos:
		if not typeof(list_info) == TYPE_DICTIONARY:
			continue
		for level_name in list_info.get("level_names", []):
			if not level_name in all_level_names:
				all_level_names.append(level_name)
	return all_level_names



func calculate_game_release_hash() -> String:
	return _calculate_game_release_hash(true)

func _get_all_bundled_texture_ids_for_game(game_def: Dictionary) -> Array[int]:
	return TextureManager.get_all_used_bundled_texture_ids_from_spec(game_def.get("textures", []))

func _calculate_game_release_hash(for_loaded_game: bool, for_game_name: String = "") -> String:
	var hash_context: = HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	
	if for_loaded_game:
		for_game_name = get_identified_game_name()
	
	var game_def_without_hash: Dictionary = {}
	if for_loaded_game:
		# normalize to format on being read from json file (some float values instead of ints)
		# so that hash compares correctly with unloaded games
		game_def_without_hash = get_serialized_game_definition()
		game_def_without_hash = JSON.parse_string(FilesManager.get_save_formatted_game_info(game_def_without_hash))
	else:
		game_def_without_hash = FilesManager.get_game_definition(for_game_name)
	
	var base_version: Vector2i = Utility.get_vector2i_from_arr(game_def_without_hash["release_info"]["base_version"])
	var base_version_bytes: PackedByteArray = []
	base_version_bytes.resize(8)
	base_version_bytes.encode_s32(0, base_version.x)
	base_version_bytes.encode_s32(4, base_version.y)
	hash_context.update(base_version_bytes)
	game_def_without_hash["release_info"]["release_hash"] = ""
	game_def_without_hash["release_info"]["base_version"] = []
	game_def_without_hash["release_info"]["next_version"] = []
	hash_context.update(JSON.stringify(game_def_without_hash, "", false).to_utf8_buffer())
	
	var bundled_levels: Array[String] = []
	if for_loaded_game:
		bundled_levels = get_list_of_all_bundled_levels()
	else:
		bundled_levels = _get_list_of_all_bundled_levels_for_game(for_game_name, game_def_without_hash)

	for level_name in bundled_levels:
		hash_context.update(level_name.to_utf8_buffer())
		var level_data: Dictionary = FilesManager.get_level_data(for_game_name, level_name)
		hash_context.update(JSON.stringify(level_data, "", false).to_utf8_buffer())
	
	var bundled_texture_ids: Array[int] = []
	var texture_spec: Array = []
	if for_loaded_game:
		texture_spec = TextureManager.texture_spec
	else:
		texture_spec = game_def_without_hash.get("textures", [])
	bundled_texture_ids = TextureManager.get_all_used_bundled_texture_ids_from_spec(texture_spec)

	for texture_id in bundled_texture_ids:
		var image_name: String = TextureManager.get_bundled_texture_image_name_from_spec(texture_spec, texture_id)
		if not image_name:
			prints("Calculate Release Hash Fail: failed to get bundled texture image name from spec id: %d" % texture_id)
			return ""
		
		var image_bytes: PackedByteArray = []
		image_bytes.resize(4)
		image_bytes.encode_s32(0, texture_id)
		image_bytes.append_array(FilesManager.get_local_image_as_bytes(image_name, for_game_name))
		if not image_bytes.size() > 4:
			return ""
		hash_context.update(image_bytes)
	
	var result: = hash_context.finish().hex_encode()
	return result

func get_current_game_base_version() -> Vector2i:
	return Utility.get_vector2i_from_arr(game_definition["release_info"]["base_version"])

func get_current_game_current_version() -> Vector2i:
	if current_game_is_release_locked:
		return get_current_game_base_version()
	return Utility.get_vector2i_from_arr(game_definition["release_info"]["next_version"])


func get_full_version_string() -> String:
	var ver_str: = get_identified_game_name(true) + " "

	var base_version: Vector2i = get_current_game_base_version()

	if current_game_is_release_locked:
		ver_str += str(base_version.x) + "." + str(base_version.y)
	else:
		var current_version: Vector2i = get_current_game_current_version()
		ver_str += str(current_version.x) + "." + str(current_version.y)
		if base_version == Vector2i.ZERO:
			ver_str += "(edited)"
		else:
			ver_str += "(edited from " + str(base_version.x) + "." + str(base_version.y) + ")"
	return ver_str

func get_version_for_data() -> String:
	var base_version: Vector2i = get_current_game_base_version()
	if current_game_is_release_locked:
		return str(base_version.x) + "." + str(base_version.y)
	else:
		var current_version: Vector2i = get_current_game_current_version()
		var ver_str: = str(current_version.x) + "." + str(current_version.y)
		ver_str += "-edited-from-" + str(base_version.x) + "." + str(base_version.y)
		return ver_str

func validate_game_release(for_game_name: String) -> bool:
	if not FilesManager.game_has_release_hash(for_game_name):
		return false
	
	var game_info: Dictionary = FilesManager.get_game_definition(for_game_name)
	var hash_from_info: String = game_info.get("release_info", {}).get("release_hash", "")
	
	var calculated_hash: String = _calculate_game_release_hash(false, for_game_name)
	if not calculated_hash:
		return false
	
	return hash_from_info == calculated_hash


func is_current_game_save_empty() -> bool:
	return player_profile.is_empty_game_save(get_identified_game_name())


func delete_current_profile() -> void:
	var all_profile_ids: = FilesManager.get_player_profile_list()
	var next_profile_id: = ""
	for profile_id in all_profile_ids:
		if profile_id and profile_id != GameManager._cur_profile_id:
			next_profile_id = profile_id
			break
	if not next_profile_id:
		return
	
	FilesManager.delete_player_profile(GameManager._cur_profile_id)
	load_player_profile(next_profile_id)

func create_and_edit_new_empty_game() -> void:
	if cur_scene == "GameEditor":
		if player_profile.get_profile_setting("auto_save_definition", true) and is_current_game_resavable():
			save_current_game_definition()

	new_empty_game_definition()
	save_current_game_definition()
	var default_game: = FilesManager.get_default_game()
	if not default_game or not FilesManager.game_exists(default_game):
		FilesManager.save_default_game(GameManager.get_identified_game_name())
	
	await get_tree().process_frame
	change_scene("GameEditor", true)


func show_save_game_zip_dialog(zip_file_path: String) -> void:
	if OS.has_feature("web"):
		_show_save_game_zip_web(zip_file_path)
		return
	
	var file_dialog: FileDialog = FileDialog.new()
	file_dialog.title = "Save Exported Game .zip to..."
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.zip"]
	file_dialog.file_selected.connect(_save_game_zip_destination_picked.bind(zip_file_path, file_dialog))
	file_dialog.close_requested.connect(file_dialog.queue_free)
	file_dialog.canceled.connect(file_dialog.queue_free)
	
	file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	file_dialog.current_file = zip_file_path.get_file()

	if Utility.is_mobile():
		file_dialog.use_native_dialog = true
		file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)

	add_child(file_dialog)
	file_dialog.popup_file_dialog()

func _save_game_zip_destination_picked(save_path: String, zip_file_path: String, file_dialog: FileDialog) -> void:
	file_dialog.queue_free()
	var error: = DirAccess.copy_absolute(zip_file_path, save_path)
	if error != OK:
		push_error("Failed to copy zip file to %s: %s" % [save_path, error_string(error)])
		GlobalToaster.show_toast_message("Failed to copy .zip to the selected destination", 2.0)
		return
	else:
		GlobalToaster.show_toast_message("Saved .zip")

func _show_save_game_zip_web(zip_file_path: String) -> void:
	var zip_file_bytes: = FileAccess.get_file_as_bytes(zip_file_path)
	if not zip_file_bytes:
		push_error("Failed to get bytes from zip file %s" % [zip_file_path])
		GlobalToaster.show_toast_message("Unable to download exported .zip, please report to Cammymoop", 2.0)
		return
	var save_filename: = zip_file_path.get_file()
	JavaScriptBridge.download_buffer(zip_file_bytes, save_filename, "application/zip")


func is_current_level_custom() -> bool:
	var default_in_level_edit: = not is_in_level_edit_mode
	if current_level_is_museum:
		return false

	if not loaded_level_name:
		return default_in_level_edit
	if not current_level_list:
		if not is_level_in_any_list(loaded_level_name):
			return default_in_level_edit
		var list_of_cur_level: = get_list_containing_level(loaded_level_name)
		return not is_level_list_bundled(list_of_cur_level)
	return not is_level_list_bundled(current_level_list)

func get_all_existing_levels_sorted_by_chronology() -> Array[String]:
	var all_levels: Array[String] = []
	all_levels.append_array(get_list_of_all_levels_in_lists())
	
	for unlisted_level in get_list_of_unlisted_levels():
		if not unlisted_level in all_levels:
			all_levels.append(unlisted_level)
	return all_levels

func get_list_show_completion_style(list_name: String) -> String:
	var list_info: = _get_level_list(list_name)
	if not list_info:
		return LevelListSettings.SHOWCOMP_STYLE_HIDE
	var show_completion_style: String = list_info.get("show_completion_style", "")
	if not show_completion_style in LevelListSettings.ShowCompletionOptions:
		show_completion_style = LevelListSettings.SHOWCOMP_STYLE_HIDE
	return show_completion_style

func should_show_list_completion(list_name: String) -> bool:
	if not is_list_completable(list_name):
		return false
	var show_completion_style: = get_list_show_completion_style(list_name)
	return show_completion_style != LevelListSettings.SHOWCOMP_STYLE_HIDE

func get_list_completion_text(list_name: String) -> String:
	var show_completion_style: = get_list_show_completion_style(list_name)
	if show_completion_style == LevelListSettings.SHOWCOMP_STYLE_HIDE:
		return ""

	var completed_count: int = get_list_completed_count(list_name)
	var required_count: int = _level_list_required_level_count(list_name)
	var total_count: int = get_levels_in_level_list(list_name).size()
	
	if show_completion_style == LevelListSettings.SHOWCOMP_STYLE_COMP_REQ_TOTAL:
		return "%d/%d/%d" % [completed_count, required_count, total_count]
	elif show_completion_style == LevelListSettings.SHOWCOMP_STYLE_COMP_REQ:
		return "%d/%d" % [completed_count, required_count]
	elif show_completion_style == LevelListSettings.SHOWCOMP_STYLE_COMP_TOTAL:
		return "%d/%d" % [completed_count, total_count]
	return ""

func get_list_completion_tooltip(list_name: String) -> String:
	var show_completion_style: = get_list_show_completion_style(list_name)
	if show_completion_style == LevelListSettings.SHOWCOMP_STYLE_HIDE:
		return ""
	elif show_completion_style == LevelListSettings.SHOWCOMP_STYLE_COMP_REQ_TOTAL:
		return "Completed / Required / Total"
	elif show_completion_style == LevelListSettings.SHOWCOMP_STYLE_COMP_REQ:
		return "Completed / Required"
	elif show_completion_style == LevelListSettings.SHOWCOMP_STYLE_COMP_TOTAL:
		return "Completed / Total"
	return ""

func _clean_intermission_info() -> void:
	var idx_to_remove: Array[int] = []
	var intermissions: Array = game_definition.get("intermissions", [])
	if not intermissions:
		return
	var existing_ids: Array[String] = []
	for i in intermissions.size():
		var this_id: String = intermissions[i].get("id", "")
		if not this_id or this_id in existing_ids:
			idx_to_remove.append(i)
		existing_ids.append(this_id)
	if idx_to_remove.size() > 0:
		print_debug("cleaning intermissions: %s " % idx_to_remove, "existing_ids: %s" % existing_ids)
	idx_to_remove.reverse()
	for idx in idx_to_remove:
		intermissions.remove_at(idx)

func get_all_intermission_ids() -> Array[String]:
	var all_intermission_ids: Array[String] = _get_all_intermission_ids_from(game_definition.get("intermissions", []))
	if all_intermission_ids.size() == 0:
		return [DEFAULT_INTERMISSION_CREDITS]
	return all_intermission_ids

func get_all_intermission_ids_from_custom_list(from_custom_list: String) -> Array[String]:
	if not from_custom_list in get_list_of_non_bundled_level_lists():
		return []
	var custom_list_info: = _get_level_list(from_custom_list)
	if not custom_list_info:
		return []
	return _get_all_intermission_ids_from(custom_list_info.get("intermissions", []))

func get_lists_of_intermission_ids_by_storage_location() -> Dictionary:
	var lists_of_intermission_ids: Dictionary = {
		"bundled": get_all_intermission_ids(),
		"custom_lists": {},
	}

	for custom_list_name in get_list_of_non_bundled_level_lists():
		var intermission_ids: Array[String] = get_all_intermission_ids_from_custom_list(custom_list_name)
		if intermission_ids.size() > 0:
			lists_of_intermission_ids["custom_lists"][custom_list_name] = get_all_intermission_ids_from_custom_list(custom_list_name)
	return lists_of_intermission_ids

func _get_all_intermission_ids_from(intermissions: Array) -> Array[String]:
	var all_intermission_ids: Array[String] = []
	for intermission_info in intermissions:
		if not intermission_info.get("id", ""):
			continue
		all_intermission_ids.append(intermission_info["id"])
	return all_intermission_ids

func has_tagged_intermission_id(intermission_id: String, for_custom_list: String = "") -> bool:
	if is_intermission_id_reserved(intermission_id):
		return true
	if not intermission_id:
		return false
	if not for_custom_list:
		for_custom_list = current_level_list

	if intermission_id.begins_with(":"):
		if not for_custom_list:
			return false
		return has_intermission_id(intermission_id.trim_prefix(":"), for_custom_list)
	return has_intermission_id(intermission_id)

func has_intermission_id(intermission_id: String, from_custom_list: String = "") -> bool:
	if is_intermission_id_reserved(intermission_id):
		return true

	if not intermission_id:
		return false
	if not from_custom_list:
		return _has_bundled_intermission_id(intermission_id)
	return _has_custom_intermission_id(intermission_id, from_custom_list)

func _has_bundled_intermission_id(intermission_id: String) -> bool:
	if is_intermission_id_reserved(intermission_id):
		return true
	return intermission_id in get_all_intermission_ids()

func _has_custom_intermission_id(intermission_id: String, from_custom_list: String) -> bool:
	return intermission_id in get_all_intermission_ids_from_custom_list(from_custom_list)

func update_intermission_info(update_intermission_id: String, intermission_info: Dictionary, in_custom_list: String = "") -> void:
	if not update_intermission_id or is_intermission_id_reserved(update_intermission_id):
		return
	if current_game_is_release_locked and not in_custom_list:
		push_warning("Trying to edit bundled intermission data in release locked game")
		return
	if not in_custom_list:
		_update_bundled_intermission_info(update_intermission_id, intermission_info)
		return
	
	if not in_custom_list in get_list_of_non_bundled_level_lists():
		return
	var list_info: = _get_level_list(in_custom_list)
	var intermissions: Array = list_info.get("intermissions", [])
	var updated_in_place: bool = false
	for i in intermissions.size():
		if intermissions[i]["id"] == update_intermission_id:
			intermissions[i] = intermission_info.duplicate_deep()
			updated_in_place = true
			break
	if not updated_in_place:
		intermissions.append(intermission_info.duplicate_deep())
	set_level_list_data(in_custom_list, "intermissions", intermissions)
	non_bundled_lists_updated()

func _update_bundled_intermission_info(update_intermission_id: String, intermission_info: Dictionary) -> void:
	_clean_intermission_info()
	if not has_intermission_id(update_intermission_id) or game_definition.get("intermissions", []).size() == 0:
		game_definition["intermissions"].append(intermission_info.duplicate_deep())
		return
	
	var intermissions: Array = game_definition.get("intermissions", [])
	var saved: bool = false
	for i in intermissions.size():
		if intermissions[i]["id"] == update_intermission_id:
			game_definition["intermissions"][i] = intermission_info.duplicate_deep()
			saved = true
			break
	if not saved:
		push_error("Failed to save intermission info for id: %s" % update_intermission_id)

func get_intermission_info(intermission_id: String, from_custom_list: String = "") -> Dictionary:
	if not from_custom_list and is_intermission_id_reserved(intermission_id):
		if not RESERVED_INTERMISSIONS.has(intermission_id):
			push_warning("Reserved intermission id %s not found in RESERVED_INTERMISSIONS" % intermission_id)
			var default_info: = {
				"id": intermission_id,
				"type": "flag",
			}
			return default_info
		return RESERVED_INTERMISSIONS[intermission_id]
	if not from_custom_list:
		return _get_bundled_intermission_info(intermission_id)
	if not from_custom_list in get_list_of_non_bundled_level_lists():
		return {}
	
	var list_info: = _get_level_list(from_custom_list)
	var intermissions: Array = list_info.get("intermissions", [])
	for intermission_info in intermissions:
		if intermission_info.get("id", "") == intermission_id:
			return intermission_info.duplicate_deep()
	return {}

func get_tagged_intermission_info(intermission_id: String, context_list_name: String = "") -> Dictionary:
	if not context_list_name:
		context_list_name = current_level_list
	if intermission_id.begins_with(":"):
		if not context_list_name:
			return {}
		var inner_id: String = intermission_id.trim_prefix(":")
		return get_intermission_info(inner_id, context_list_name)
	return get_intermission_info(intermission_id)

func _get_bundled_intermission_info(intermission_id: String) -> Dictionary:
	# this method shouldn't be called except from get_intermission_info but just in case
	if is_intermission_id_reserved(intermission_id):
		return get_intermission_info(intermission_id)

	if intermission_id == DEFAULT_INTERMISSION_CREDITS:
		if not game_definition.get("intermissions", []).size() > 0:
			return DEFAULT_CREDITS.duplicate_deep()
	var intermissions: Array = game_definition.get("intermissions", [])
	for intermission_info in intermissions:
		if intermission_info.get("id", "") == intermission_id:
			return intermission_info.duplicate_deep()
	return {}

func remove_intermission_info(intermission_id: String) -> void:
	if not intermission_id or not has_intermission_id(intermission_id):
		return
	
	remove_intermission_id_from_defualt_assignments(intermission_id)
	var new_intermissions: Array = []
	for intermission_info in game_definition.get("intermissions", []):
		if intermission_info.get("type", "") == "sequence":
			var filtered_sequence_ids: Array[String] = []
			for sequence_id in intermission_info.get("sequence_ids", []):
				if sequence_id != intermission_id:
					filtered_sequence_ids.append(sequence_id)
			intermission_info["sequence_ids"] = filtered_sequence_ids
		if not intermission_info.get("id", ""):
			continue
		if intermission_info["id"] != intermission_id:
			new_intermissions.append(intermission_info.duplicate_deep())
	game_definition["intermissions"] = new_intermissions

func remove_intermission_id_from_defualt_assignments(intermission_id: String) -> void:
	var game_intermission_assignments: Dictionary = get_game_setting("default_intermissions", {}).duplicate_deep()
	var has_filtered_any: bool = false
	for event_key in game_intermission_assignments:
		if not game_intermission_assignments[event_key].size() > 0:
			continue
		var filtered_intermission_ids: Array[String] = []
		for id in game_intermission_assignments[event_key]:
			if id != intermission_id:
				filtered_intermission_ids.append(id)
			else:
				has_filtered_any = true
		game_intermission_assignments[event_key] = filtered_intermission_ids
	if has_filtered_any:
		set_game_setting("default_intermissions", game_intermission_assignments)


func get_available_numeric_intermission_id(in_custom_list: String = "") -> String:
	var next_id: int = 1
	var exisiting_ids: Array[String] = []
	if not in_custom_list:
		exisiting_ids.append_array(get_all_intermission_ids())
	else:
		exisiting_ids.append_array(get_all_intermission_ids_from_custom_list(in_custom_list))
	while str(next_id) in exisiting_ids:
		next_id += 1
	return str(next_id)

func get_default_credits_info() -> Dictionary:
	if not DEFAULT_INTERMISSION_CREDITS in get_all_intermission_ids():
		return DEFAULT_CREDITS.duplicate_deep()
	return get_intermission_info(DEFAULT_INTERMISSION_CREDITS)

func create_default_credits_if_not_exists() -> void:
	if game_definition.get("intermissions", []).size() == 0:
		game_definition["intermissions"].append(DEFAULT_CREDITS.duplicate_deep())
	elif not DEFAULT_INTERMISSION_CREDITS in get_all_intermission_ids():
		game_definition["intermissions"].append(DEFAULT_CREDITS.duplicate_deep())


func remove_custom_list_intermission(custom_list_name: String, intermission_id: String) -> void:
	if not intermission_id or not custom_list_name in get_list_of_non_bundled_level_lists():
		return
	var custom_list_info: = _get_level_list(custom_list_name)
	if not custom_list_info:
		return
	var new_intermissions: Array = []
	for old_intermission_info in custom_list_info.get("intermissions", []):
		if not old_intermission_info.get("id", ""):
			continue
		if old_intermission_info["id"] != intermission_id:
			new_intermissions.append(old_intermission_info.duplicate_deep())
	custom_list_info["intermissions"] = new_intermissions
	non_bundled_lists_updated()


func import_intermission_from_custom_list(from_custom_list: String, intermission_id: String, skip_remove: bool = false) -> String:
	if current_game_is_release_locked:
		push_warning("Trying to import intermission from custom list in release locked game")
		return ""
	if not intermission_id or not from_custom_list in get_list_of_non_bundled_level_lists():
		return ""
	var intermission_info: = get_intermission_info(intermission_id, from_custom_list)
	if not intermission_info:
		return ""
	if not skip_remove:
		remove_custom_list_intermission(from_custom_list, intermission_id)

	if intermission_id in get_all_intermission_ids():
		intermission_id = get_available_numeric_intermission_id()
	intermission_info["id"] = intermission_id
	update_intermission_info(intermission_id, intermission_info, "")
	return intermission_id

func move_intermission_between_custom_lists(from_custom_list: String, to_custom_list: String, intermission_id: String) -> String:
	if not intermission_id:
		return ""
	var all_custom_lists: = get_list_of_non_bundled_level_lists()
	if not from_custom_list in all_custom_lists or not to_custom_list in all_custom_lists:
		return ""
	
	var to_custom_list_info: = _get_level_list(to_custom_list)
	var from_intermission_info: = get_intermission_info(intermission_id, from_custom_list).duplicate_deep()
	if not from_intermission_info or not to_custom_list_info:
		return ""
	
	var intermissions_at_destination: = get_all_intermission_ids_from_custom_list(to_custom_list)
	if intermission_id in intermissions_at_destination:
		intermission_id = get_available_numeric_intermission_id(to_custom_list)
	from_intermission_info["id"] = intermission_id
	
	update_intermission_info(intermission_id, from_intermission_info, to_custom_list)
	remove_custom_list_intermission(from_custom_list, intermission_id)

	return intermission_id

func move_intermission_to_custom_list(to_custom_list: String, intermission_id: String) -> String:
	if not intermission_id or not to_custom_list in get_list_of_non_bundled_level_lists():
		return ""
	if is_intermission_id_reserved(intermission_id):
		return ""
	if not has_intermission_id(intermission_id):
		return ""

	var new_intermission_id: = _copy_intermission_to_custom_list(to_custom_list, get_intermission_info(intermission_id))
	if not GameManager.current_game_is_release_locked:
		remove_intermission_info(intermission_id)
	return new_intermission_id

func duplicate_bundled_intermission_into_custom_list(to_custom_list: String, intermission_id: String, try_suffix: String = "-custom") -> String:
	if not intermission_id or not to_custom_list in get_list_of_non_bundled_level_lists():
		return ""
	if not has_intermission_id(intermission_id):
		return ""
	
	return _copy_intermission_to_custom_list(to_custom_list, get_intermission_info(intermission_id), try_suffix)

func append_numbered_intermission_id_suffix(intermission_id: String, suffix: String) -> String:
	if not intermission_id or not suffix:
		return intermission_id
	if intermission_id.ends_with(suffix) or intermission_id.left(-1).ends_with(suffix):
		var old_number: int = 1
		if not intermission_id.ends_with(suffix):
			old_number = int(intermission_id.right(-1))
		intermission_id += suffix + str(old_number + 1)
	else:
		intermission_id += suffix
	return intermission_id

func _copy_intermission_to_custom_list(to_custom_list: String, intermission_info: Dictionary, try_suffix: String = "-custom") -> String:
	intermission_info = intermission_info.duplicate_deep()
	var intermission_id: String = intermission_info["id"]
	if try_suffix:
		intermission_id = append_numbered_intermission_id_suffix(intermission_id, try_suffix)
	var intermissions_at_destination: = get_all_intermission_ids_from_custom_list(to_custom_list)
	if not intermission_id or intermission_id in intermissions_at_destination:
		intermission_id = get_available_numeric_intermission_id(to_custom_list)
	intermission_info["id"] = intermission_id
	update_intermission_info(intermission_id, intermission_info, to_custom_list)
	return intermission_id


func save_current_definition_if_auto_enabled() -> void:
	if current_game_is_release_locked:
		return
	if player_profile.get_profile_setting("auto_save_definition", true):
		if is_current_game_resavable():
			save_current_game_definition()


func set_map_metadata_into_level_file(level_name: String, map_metadata: Dictionary) -> void:
	if not FilesManager.level_exists(get_identified_game_name(), level_name):
		return

	var level_data: = FilesManager.get_level_data(get_identified_game_name(), level_name)
	level_data_set_map_metadata(level_data, map_metadata)
	FilesManager.save_level_to_name(get_identified_game_name(), level_data, level_name)

func get_map_metadata_from_level_file(level_name: String) -> Dictionary:
	if not FilesManager.level_exists(get_identified_game_name(), level_name):
		return {}
	var level_data: = FilesManager.get_level_data(get_identified_game_name(), level_name)
	return level_data_get_map_metadata(level_data)



func get_current_fail_state_intermission_info() -> Dictionary:
	if not cur_scene == "Play" or not loaded_level_name:
		return get_default_fail_state_intermission_info()
	var fail_intermission_id_from_map: String = MapManager.get_custom_fail_state_intermission_id()
	if not fail_intermission_id_from_map:
		return get_current_list_fail_state_intermission_info()
	return get_tagged_intermission_info(fail_intermission_id_from_map)

func get_current_list_fail_state_intermission_info() -> Dictionary:
	if not cur_scene == "Play" or not loaded_level_name:
		return get_default_fail_state_intermission_info()
	var def_info: = get_default_fail_state_intermission_info()
	if not current_level_list:
		return def_info

	var fail_state_intermission_ids: Array[String] = get_intermissions_for_list_event(current_level_list, IntermissionEvents.CUSTOM_FAIL_STATE)
	var first_viewable: String = get_first_viewable_intermission_from_list(fail_state_intermission_ids)
	if not first_viewable:
		return def_info
	return get_tagged_intermission_info(first_viewable)

func get_default_fail_state_intermission_info() -> Dictionary:
	var fail_state_intermission_ids: Array[String] = get_intermissions_for_game_event(IntermissionEvents.DEFAULT_FAIL_STATE)
	var first_viewable_id: String = get_first_viewable_intermission_from_list(fail_state_intermission_ids)
	if not first_viewable_id:
		return {}
	return get_tagged_intermission_info(first_viewable_id)

func _get_intermission_info_if_not_sequence(tagged_intermission_id: String, context_list_name: String = "") -> Dictionary:
	var info: Dictionary = get_tagged_intermission_info(tagged_intermission_id, context_list_name)
	if info.get("type", "") == "sequence":
		return {}
	return info



func show_credits_as_overlay(manually_triggered: bool) -> void:
	var credits_intermission_info: = get_credtis_intermission_info().duplicate_deep()
	clear_intermission_state()
	set_overlay_intermission_state()
	
	if manually_triggered:
		credits_intermission_info["show_only_once"] = false
	if not credits_intermission_info.has("id"):
		credits_intermission_info["id"] = DEFAULT_INTERMISSION_CREDITS
	show_single_overlay_intermission(credits_intermission_info, true)

func get_credtis_intermission_info() -> Dictionary:
	var first_id: String = get_credits_intermission_first_id()
	if not first_id:
		return DEFAULT_CREDITS.duplicate_deep()

	return get_intermission_info(first_id)

func get_credits_intermission_first_id() -> String:
	if not has_intermission_id(DEFAULT_INTERMISSION_CREDITS):
		return DEFAULT_INTERMISSION_CREDITS
	return _get_first_viewable_intermission_id(DEFAULT_INTERMISSION_CREDITS)


func get_first_viewable_intermission_from_list(intermission_ids: Array, context_list_name: String = "") -> String:
	for intermission_id in intermission_ids:
		if typeof(intermission_ids[0]) != TYPE_STRING:
			push_error("Non-string intermission id: %s" % [intermission_id])
		if not is_intermission_id_viewable(intermission_id, context_list_name):
			continue
		var first_viewable_id: String = _get_first_viewable_intermission_id(intermission_id, context_list_name)
		if first_viewable_id:
			return first_viewable_id
	return ""

func _get_first_viewable_intermission_id(from_id: String, context_list_name: String = "", search_depth: int = 0) -> String:
	if search_depth > 50:
		return ""
	if not has_tagged_intermission_id(from_id, context_list_name):
		return ""

	var intermission_info: = get_tagged_intermission_info(from_id, context_list_name)
	if not intermission_info or intermission_info.get("type", "") == "flag":
		return ""
	var intermission_type: String = intermission_info.get("type", "")
	if intermission_type != "sequence":
		return from_id
	else:
		var sequence_ids: Array[String] = intermission_info.get("sequence_ids", [])
		for index in sequence_ids.size():
			if not is_intermission_id_viewable(sequence_ids[index], context_list_name):
				continue
			else:
				return _get_first_viewable_intermission_id(sequence_ids[index], context_list_name, search_depth + 1)
		return ""

func is_intermission_info_viewable(intermission_info: Dictionary) -> bool:
	return intermission_info.get("type", "") != "flag"

func is_intermission_id_viewable(intermission_id: String, context_list_name: String = "") -> bool:
	var intermission_info: = get_tagged_intermission_info(intermission_id, context_list_name)
	if not intermission_info:
		return false
	return is_intermission_info_viewable(intermission_info)


# external API for showing overlay intermission, if mupltiple needed make a sequence intermission
func show_custom_intermission_overlay(tagged_intermission_id: String) -> void:
	var intermission_info: = {}
	if not has_tagged_intermission_id(tagged_intermission_id):
		intermission_info = _get_not_found_intermission_info()
	else:
		intermission_info = get_tagged_intermission_info(tagged_intermission_id)
	if not intermission_info:
		push_error("Trying to show empty intermission info as custom intermission overlay")
		return

	show_single_overlay_intermission(intermission_info, true)

# external API for showing a single intermission 
func show_custom_fail_state_overlay(tagged_intermission_id: String) -> void:
	if not has_tagged_intermission_id(tagged_intermission_id):
		show_current_fail_state_intermission_as_overlay()
		return
	
	var info: = get_tagged_intermission_info(tagged_intermission_id)
	_show_fail_state_overlay_info(info)

func _get_not_found_intermission_info() -> Dictionary:
	return {
		"type": "intermission",
		"id": "NOT_FOUND",
		"show_only_once": false,
		"show_continue": true,
		"content_items": [
			{
				"type": "text",
				"text": "Missing\nIntermission",
				"font_size": 50,
			}
		]
	}

func show_current_fail_state_intermission_as_overlay() -> void:
	var fail_state_intermission_info: = get_current_fail_state_intermission_info()
	_show_fail_state_overlay_info(fail_state_intermission_info)

func _show_fail_state_overlay_info(intermission_info: Dictionary) -> void:
	if not intermission_info:
		push_error("Trying to show empty intermission info as fail state overlay")
		return
	intermission_info = intermission_info.duplicate_deep()
	intermission_info["show_only_once"] = false
	if not intermission_info.has("id"):
		intermission_info["id"] = "FAIL"
	
	intermission_info["show_undo"] = undo_stack.size() > 1 and action_1_does_undo()
	intermission_info["show_reload_checkpoint"] = true
	
	show_single_overlay_intermission(intermission_info)


func show_overlay_intermissions(intermission_id_list: Array[String]) -> void:
	if not intermission_id_list:
		return
	clear_intermission_state()
	intermission_state["intermission_queue"] = intermission_id_list.duplicate_deep()
	intermission_state["to_level_code"] = ""
	intermission_state["is_overlaying"] = true
	set_overlay_intermission_state()
	show_next_intermission()
	start_intermission_expire_timer(2000)

func _queue_goto_level_with_intermissions(to_level_code: String, intermission_id_list: Array[String], with_delay: float = 0.0) -> void:
	if with_delay <= 0:
		if queued_level_load:
			cancel_queued_level_load()
		_now_goto_level_with_intermissions(to_level_code, intermission_id_list)
	else:
		queue_delayed_other_load(with_delay, _now_goto_level_with_intermissions.bind(to_level_code, intermission_id_list))

func _filter_existing_intermission_ids(intermission_id_list: Array[String], for_list_name: String) -> Array[String]:
	var filtered: Array[String] = []
	for id in intermission_id_list:
		if id.begins_with(":"):
			var inner_id: String = id.trim_prefix(":")
			if has_intermission_id(inner_id, for_list_name):
				filtered.append(id)
		elif has_intermission_id(id):
			filtered.append(id)
	return filtered


func _clear_level_for_intermission_mode() -> void:
	loaded_level_name = ""
	
	editor_save = {}
	loaded_level = {}
	clear_checkpoint()
	clear_undo_stack()
	unload_map_and_entities()

func _now_goto_level_with_intermissions(to_level_code: String, intermission_id_list: Array[String]) -> void:
	var for_list_name: String = _level_list_from_code(to_level_code)
	var filtered_intermission_id_list: Array[String] = _filter_existing_intermission_ids(intermission_id_list, for_list_name)
	if filtered_intermission_id_list.size() == 0:
		clear_intermission_state()
		goto_level_code(to_level_code)
		return
	
	save_level_code_as_current_visited(to_level_code)
	_clear_level_for_intermission_mode()
	
	clear_intermission_state()
	is_intermission_mode = true
	intermission_state["intermission_queue"] = filtered_intermission_id_list
	intermission_state["to_special"] = ""
	intermission_state["to_level_code"] = to_level_code
	intermission_state["is_overlaying"] = false
	
	show_next_intermission()

func _now_goto_level_select_with_intermissions(intermission_id_list: Array[String]) -> void:
	_clear_level_for_intermission_mode()
	clear_intermission_state()
	is_intermission_mode = true
	intermission_state["intermission_queue"] = intermission_id_list
	intermission_state["to_special"] = "select"
	intermission_state["to_level_code"] = ""
	intermission_state["is_overlaying"] = false
	
	show_next_intermission()

func goto_level_with_starting_intermissions(level_code: String, with_intermissions: Array[String] = []) -> void:
	with_intermissions.append_array(get_intermissions_for_game_start(level_code))
	_now_goto_level_with_intermissions(level_code, with_intermissions)


func get_intermissions_for_game_start(to_level_code: String) -> Array[String]:
	var intermissions: Array[String] = []

	if not has_intermission_flag(INTERM_GAME_STARTED_FLAG):
		intermissions.append_array(get_intermissions_for_game_event(IntermissionEvents.NEW_GAME))

	var level_list_name: String = _level_list_from_code(to_level_code)
	if level_list_name and level_list_exists(level_list_name):
		intermissions.append_array(get_intermissions_for_list_event(level_list_name, IntermissionEvents.LEVEL_LIST_START))

	intermissions.append_array(get_intermissions_for_level_code_event(to_level_code, IntermissionEvents.LEVEL_START))
	return intermissions

func get_intermissions_for_level_code_event(level_code: String, event: IntermissionEvents) -> Array[String]:
	var event_key: String = EditIntermissionAssignments.get_event_key(event)
	if not event_key:
		return []

	var intermissions: Array[String] = []
	var level_map_metadata: = get_map_metadata_from_level_file(_level_name_from_code(level_code))
	var intermission_assignments: Dictionary = level_map_metadata.get("intermission_assignments", {})
	intermissions.append_array(intermission_assignments.get(event_key, []))

	return intermissions

func get_intermissions_for_list_event(level_list_name: String, event: IntermissionEvents) -> Array[String]:
	var event_key: String = EditIntermissionAssignments.get_event_key(event)
	if not event_key:
		return []
	
	var intermissions: Array[String] = []
	var list_info: = _get_level_list(level_list_name)
	var intermission_assignments: Dictionary = list_info.get("intermission_assignments", {})
	intermissions.append_array(intermission_assignments.get(event_key, []))
	return intermissions

func get_intermissions_for_game_event(event: IntermissionEvents) -> Array[String]:
	var event_key: String = EditIntermissionAssignments.get_event_key(event)
	if not event_key:
		return []
	
	var intermissions: Array[String] = []
	var game_intermission_assignments: Dictionary = get_game_setting("default_intermissions", {})
	intermissions.append_array(game_intermission_assignments.get(event_key, []))

	# Add builtin flags for certain events
	if event == IntermissionEvents.GAME_COMPLETE:
		intermissions.append(INTERM_GAME_COMLETE_FLAG)
	elif event == IntermissionEvents.NEW_GAME:
		intermissions.append(INTERM_GAME_STARTED_FLAG)

	return intermissions


func _get_intermission_root() -> Node:
	if not cur_scene == "Play":
		return null
	return get_tree().current_scene.intermission_root


func show_single_overlay_intermission(intermission_info: Dictionary, advancable: bool = false) -> bool:
	if is_intermission_mode:
		return false
	var intermission_id: String = intermission_info.get("id", "")
	if not intermission_id:
		return false
	var only_once: bool = intermission_info.get("show_only_once", false)
	if only_once and has_saved_intermission_id_viewed(intermission_id):
		return false

	clear_intermission_state()
	set_overlay_intermission_state()
	intermission_state["advancable"] = advancable

	if not show_intermission(intermission_info, intermission_id):
		clear_intermission_state()
		return false
	return true

# Also saves viewed intermission ids
func show_intermission(intermission_info: Dictionary, tagged_intermission_id: String = "") -> bool:
	intermission_info = intermission_info.duplicate_deep()
	if not is_in_level_edit_mode:
		var only_once: bool = intermission_info.get("show_only_once", false)
		if only_once and has_saved_intermission_id_viewed(tagged_intermission_id):
			return false

	intermission_state["showing_id"] = tagged_intermission_id
	bg_style_changed.emit()
	
	save_intermission_id_viewed(tagged_intermission_id)
	var intermission_type: String = intermission_info.get("type", "")
	if intermission_type == "flag":
		return false

	var intermission_root: Node = _get_intermission_root()
	if not intermission_root:
		push_error("No intermission root found")
		return false

	hide_intermissions()
	
	intermission_advancable_timer.start(intermission_advancable_delay)
	
	if intermission_type == "credits":
		if cur_scene == "Play":
			show_credits()
		return true
	elif intermission_type == "sequence":
		push_error("sequence info passed to show_intermission, should have been queued and called with show_next_intermission")
		return false

	var intermission_ui: = intermission_ui_scn.instantiate() as IntermissionUI
	intermission_ui.advancable = intermission_state.get("advancable", true)
	intermission_root.add_child(intermission_ui)
	intermission_ui.setup_with_info(intermission_info)
	return true

func save_intermission_id_viewed(intermission_id: String) -> void:
	if is_in_level_edit_mode or not intermission_id:
		return
	var viewed_intermissions: Array = get_game_save_data("viewed_intermissions", [])
	var id_or_combined_id: String = intermission_id
	if intermission_id.begins_with(":"):
		id_or_combined_id = _make_combined_intermission_id(intermission_id.trim_prefix(":"), current_level_list)
	if not id_or_combined_id in viewed_intermissions:
		viewed_intermissions.append(id_or_combined_id)
		set_game_save_data("viewed_intermissions", viewed_intermissions)

func has_saved_intermission_id_viewed(intermission_id: String) -> bool:
	if not intermission_id.strip_edges() or intermission_id.strip_edges() == ":":
		return false
	var check_id: String = intermission_id
	if intermission_id.begins_with(":"):
		var inner_id: String = intermission_id.trim_prefix(":")
		if not has_intermission_id(inner_id, current_level_list):
			return false
		else:
			check_id = _make_combined_intermission_id(inner_id, current_level_list)
	var viewed_intermissions: Array = get_game_save_data("viewed_intermissions", [])
	return check_id in viewed_intermissions

func has_intermission_flag(flag_id: String) -> bool:
	return has_saved_intermission_id_viewed(flag_id)

func set_intermission_flag(flag_id: String) -> void:
	save_intermission_id_viewed(flag_id)

func _make_combined_intermission_id(intermission_id: String, custom_list_name: String) -> String:
	return ":" + custom_list_name + ":" + intermission_id

func _extract_combined_intermission_id(combined_id: String) -> Array[String]:
	if not combined_id.strip_edges() or not combined_id.begins_with(":"):
		return ["", ""]
	var parts: Array[String] = []
	parts.append_array(combined_id.rsplit(":", true, 1))
	if not parts.size() == 2:
		return ["", ""]
	parts[0] = parts[0].trim_prefix(":")
	return parts

func _hide_credits_ui() -> void:
	if not cur_scene == "Play":
		return
	var credits_ui: = get_tree().get_first_node_in_group("Credits") as CreditsUI
	if credits_ui and credits_ui.visible:
		credits_ui.close_credits()

func hide_intermissions() -> void:
	_hide_credits_ui()
	_clear_intermission_root()

func close_all_intermissions() -> void:
	EntityManager.stop_pause_for_intermission_overlay()
	_hide_credits_ui()
	_clear_intermission_root()

func _clear_intermission_root() -> void:
	var intermission_root: Node = _get_intermission_root()
	if not intermission_root:
		return
	for child in intermission_root.get_children():
		intermission_root.remove_child(child)
		child.queue_free()

func clear_intermission_state() -> void:
	EntityManager.stop_pause_for_intermission_overlay()
	is_intermission_mode = false
	intermission_state = {}

func set_overlay_intermission_state() -> void:
	intermission_state["is_overlaying"] = true
	EntityManager.start_pause_for_intermission_overlay(false)

func is_showing_advancable_intermission() -> bool:
	if not is_intermission_mode and not is_showing_intermission_overlay():
		return false
	if not is_intermission_advancable():
		return false
	return true

func is_showing_intermission_overlay() -> bool:
	return intermission_state.get("is_overlaying", false)

func show_next_intermission(depth: int = 0) -> void:
	if depth > 400:
		push_error("Intermission sequence depth too deep, probably infinite sequence loop")
		skip_all_queued_intermissions()
		return

	if not cur_scene == "Play":
		prints("next intermission not in play scene")
		return
	
	_hide_credits_ui()

	var queue: Array[String] = intermission_state.get("intermission_queue", [])
	if queue.size() == 0:
		var to_special: String = intermission_state.get("to_special", "")
		var to_level_code: String = intermission_state.get("to_level_code", "")
		var was_intermission_mode: bool = is_intermission_mode
		clear_intermission_state()
		close_all_intermissions()
		if not to_level_code and not to_special:
			if was_intermission_mode:
				push_warning("Intermission queue empty in intermission mode but no destination")
				open_pause_menu()
			return

		if to_special:
			if to_special == "select":
				_go_to_level_select_for_real()
		elif to_level_code:
			goto_level_code(to_level_code)
		EntityManager._input_action_ignore_frame = true
		return
	
	var next: String = queue.pop_front()
	
	var intermission_info: Dictionary = get_tagged_intermission_info(next)
	var intermission_type: String = intermission_info.get("type", "")
		
	if intermission_type == "sequence":
		var new_queue: Array[String] = []
		var checked_sequence_ids: Array[String] = []
		for id in intermission_info.get("sequence_ids", []):
			if has_tagged_intermission_id(id):
				checked_sequence_ids.append(id)
		new_queue.assign(checked_sequence_ids + queue)
		intermission_state["intermission_queue"] = new_queue
		if new_queue.size() > 400:
			push_error("Too many intermissions in queue, aborting")
			skip_all_queued_intermissions()
			return
		# use depth for cheap infinite loop detection
		show_next_intermission(depth + 1)
		return

	if not intermission_info:
		print_debug("no intermission info found for: ", next)
		show_next_intermission()
	elif not show_intermission(intermission_info, next):
		# intermission not shown, could have been a show once that was already viewed, or a flag
		show_next_intermission()

func skip_all_queued_intermissions() -> void:
	intermission_state["intermission_queue"] = []
	show_next_intermission()


func is_intermission_advancable() -> bool:
	if not is_intermission_mode and not is_showing_intermission_overlay():
		return false
	if not intermission_state.get("advancable", true):
		return false
	return intermission_advancable_timer.is_stopped()

func start_intermission_expire_timer(for_seconds: float) -> void:
	intermission_state["expire_time"] = for_seconds
	intermission_expire_timer.start(for_seconds)

func is_intermission_advance_timeout() -> bool:
	if not is_intermission_mode or not is_showing_intermission_overlay():
		return false
	if not intermission_state.get("expire_time", 0.0) > 0:
		return false
	return intermission_expire_timer.is_stopped()

func is_pause_no_current_level() -> bool:
	if cur_scene != "Play":
		return false
	if is_in_level_edit_mode:
		return false
	if is_intermission_mode:
		return true
	if not loaded_level_name:
		return true
	return false



func is_level_select_current_level(item_list: String, item_level_name: String) -> bool:
	var current_level_code: String = ""
	if not loaded_level_name:
		current_level_code = get_game_save_current_level_code()
		if not current_level_code or not is_level_code_valid(current_level_code):
			return false
	else:
		current_level_code = _level_code(current_level_list, loaded_level_name)
	
	return current_level_code == _level_code(item_list, item_level_name)


func is_game_completed() -> bool:
	var save_completed_val: bool = get_game_save_data("game_completed", false)
	return save_completed_val

func _save_game_completion() -> void:
	if is_in_level_edit_mode:
		return
	set_game_save_data("game_completed", true)

func has_viewed_game_completion() -> bool:
	return not has_intermission_flag(INTERM_GAME_COMLETE_FLAG)

func get_game_completion_mode_and_key() -> Array:
	var game_completion_mode: String = get_game_setting("game_completion_mode", "")
	if not game_completion_mode or game_completion_mode not in ALL_COMPLETION_MODES:
		game_completion_mode = COMPLETION__ALL_LISTS
	var specific_key: String = get_game_setting("specific_completion_key", "")

	if game_completion_mode == COMPLETION__SPECIFIC_LIST:
		if not specific_key:
			var all_bundled_lists: = get_list_of_level_lists(true)
			if "Levels" in all_bundled_lists:
				return [
					COMPLETION__SPECIFIC_LIST,
					"Levels"
				]
			elif all_bundled_lists.size() > 0:
				return [
					COMPLETION__SPECIFIC_LIST,
					all_bundled_lists[-1]
				]
	elif game_completion_mode == COMPLETION__SPECIFIC_LEVEL_CODE or game_completion_mode == COMPLETION__SPECIFIC_LEVEL_NAME:
		if not specific_key:
			var all_levels: Array[String] = get_list_of_all_bundled_levels()
			if all_levels.size() > 0:
				var last_level: String = all_levels[-1]
				if game_completion_mode == COMPLETION__SPECIFIC_LEVEL_CODE:
					last_level = _level_code(get_list_containing_level(last_level), last_level)
				return [
					game_completion_mode,
					last_level
				]

	return [
		game_completion_mode,
		specific_key
	]

func get_game_completion_mode() -> String:
	var game_completion_mode_and_key: Array = get_game_completion_mode_and_key()
	return game_completion_mode_and_key[0]

func check_for_game_completion() -> bool:
	if is_game_completed():
		return true
	
	var game_completion_mode_and_key: Array = get_game_completion_mode_and_key()
	var game_completion_mode: String = game_completion_mode_and_key[0]
	var specific_key: String = game_completion_mode_and_key[1]
	if not game_completion_mode in ALL_COMPLETION_MODES:
		push_warning("Invalid game completion mode: ", game_completion_mode)
		game_completion_mode = COMPLETION__ALL_LISTS
	
	var is_completed: bool = false
	if game_completion_mode == COMPLETION__ALL_LISTS:
		if is_every_bundled_completable_list_complete():
			is_completed = true
	elif game_completion_mode == COMPLETION__ALL_LEVELS:
		if is_every_level_completed():
			is_completed = true
	elif game_completion_mode == COMPLETION__SPECIFIC_LIST:
		if not is_level_list_bundled(specific_key):
			# invalid list, default to completed
			is_completed = is_every_level_completed()
		elif is_level_list_complete(specific_key):
			is_completed = true
	elif game_completion_mode == COMPLETION__SPECIFIC_LEVEL_CODE or game_completion_mode == COMPLETION__SPECIFIC_LEVEL_NAME:
		if game_completion_mode == COMPLETION__SPECIFIC_LEVEL_NAME or get_game_setting("levels_complete_in_any_list", true):
			var level_name: String = specific_key
			if game_completion_mode == COMPLETION__SPECIFIC_LEVEL_CODE:
				level_name = ""
				if is_level_code_valid(specific_key):
					level_name = _level_name_from_code(specific_key)
			if not is_level_bundled(level_name):
				# invalid level, default to all levels complete
				is_completed = is_every_level_completed()
			elif is_level_completed_in_any_list(level_name):
				is_completed = true
		else:
			if not is_level_code_valid_and_bundled(specific_key):
				# invalid level, default to all levels complete
				is_completed = is_every_level_completed()
			elif is_level_completed_in_list(_level_list_from_code(specific_key), _level_name_from_code(specific_key)):
				is_completed = true

	if is_completed:
		_save_game_completion()
		return true
	else:
		return false

func is_intermission_id_reserved(intermission_id: String) -> bool:
	return intermission_id in RESERVED_INTERMISSION_IDS

func get_all_reserved_intermission_flags() -> Array[String]:
	return RESERVED_INTERMISSION_IDS.duplicate()


func has_save_data_for_current_game() -> bool:
	return true

func ____clear_all_local_data() -> void:
	FilesManager.___clear_local_data()
	GlobalToaster.show_toast_message("All local data has been cleared\ncurrent game will not function properly if not saved again")



func get_feature_category_filter() -> Array:
	var filter: Variant = get_current_game_profile_setting_1("feature_category_filter", [])
	if typeof(filter) != TYPE_ARRAY:
		return []
	return filter.duplicate()

func update_feature_category_filter(excluded_feature_categories: Array) -> void:
	set_current_game_profile_setting_1("feature_category_filter", excluded_feature_categories)

func reset_dummy_save_data() -> void:
	dummy_save_data = {}


func get_current_level_code() -> String:
	if not loaded_level_name:
		return _level_code(current_level_list, "_UNKNOWN_")
	return _level_code(current_level_list, loaded_level_name)

func count_dummy_entity_flags_by_entity_id(entity_id: int, _include_pending: bool) -> int:
	var count: int = 0
	var key_prefix: String = "::cmd-flag::entity-flag-%s::" % str(entity_id)
	for key_name in dummy_save_data.keys():
		if key_name.begins_with(key_prefix):
			count += 1
	return count

func count_entity_flags_by_entity_id(entity_id: int, include_pending: bool, skip_dummy: bool = false) -> int:
	if is_in_level_edit_mode and not skip_dummy:
		return count_dummy_entity_flags_by_entity_id(entity_id, include_pending)

	var key_prefix: String = "::cmd-flag::entity-flag-%s::" % str(entity_id)
	var game_save_root_dict: = player_profile.get_game_save_data_root(GameManager.get_identified_game_name())
	var flags: Array[String] = []
	for key_name in game_save_root_dict.keys():
		if key_name.begins_with(key_prefix):
			if include_pending:
				if not (cur_scene == "Play" and MapManager.is_flag_cleared_on_completion(key_name)):
					flags.append(key_name)
			else:
				flags.append(key_name)
	if include_pending:
		for new_flag_key in MapManager.get_new_flags_on_completion():
			if new_flag_key.begins_with(key_prefix) and new_flag_key not in flags:
				flags.append(new_flag_key)

	return flags.size()