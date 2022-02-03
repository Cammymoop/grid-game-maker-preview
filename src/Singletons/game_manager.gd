extends Node

var started = false
var cur_scene = null

var one_by_size = Vector2(0, 0)
var two_by_size = Vector2(0, 0)

var scenes: = {
	"Menu": "res://Scenes/Menu.tscn",
	"Loading": "res://Scenes/Loading.tscn",
	"Play": "res://Scenes/Play.tscn",
	"GameEditor": "res://Scenes/GameEditor.tscn",
}

func _ready():
	cur_scene = get_tree().current_scene.name
	update_display_size()
	FilesManager.init_folders()

func update_display_size() -> void:
	var vp = get_viewport()
	one_by_size = vp.size
	two_by_size = one_by_size / 2.0
	if cur_scene == "Play":
		vp.set_size_override(true, two_by_size)

func level_start():
	MapManager.create_empty_layer()
	EntityManager.create_defaults()

func load_random_level():
	MapManager.create_random_layer()
	EntityManager.create_randoms()

func change_scene(new_scene: String):
	if not new_scene in scenes:
		print("I dont know about scene " + new_scene)
	
	if cur_scene == "Play":
		EntityManager.clear_entity_list()
		get_viewport().set_size_override(false)
	elif cur_scene == "GameEditor":
		EntityManager.refresh_definition()
		MapManager.refresh_definition()
	
	if new_scene == "Play":
		get_viewport().set_size_override(true, two_by_size)
	
	cur_scene = new_scene
	get_tree().change_scene(scenes[new_scene])
	
	if new_scene == "Play":
		yield(get_tree(), "idle_frame")
		level_start()

func _process(_delta):
	if not started:
		if TextureManager.im_ready and MapManager.im_ready and EntityManager.im_ready:
			started = true
			if cur_scene == "Loading":
				change_scene("Menu")
		else:
			return
	
	if cur_scene == "Play":
		if Input.is_action_just_pressed("refresh"):
			get_tree().reload_current_scene()
			call_deferred("load_random_level")
		elif Input.is_action_just_pressed("editor_new_map"):
			get_tree().reload_current_scene()
			call_deferred("level_start")
	
	if Input.is_action_just_pressed("escape"):
		if cur_scene == "Play" or cur_scene == "GameEditor":
			change_scene("Menu")
		elif cur_scene == "Menu":
			get_tree().quit()
