extends Node

var started = false

func level_start():
	MapManager.create_empty_layer()
	EntityManager.create_defaults()

func load_random_level():
	MapManager.create_random_layer()
	EntityManager.create_randoms()

func _process(_delta):
	if not started:
		if TextureManager.im_ready and MapManager.im_ready and EntityManager.im_ready:
			level_start()
			started = true
		else:
			#print_debug(str(TextureManager.im_ready) + str(MapManager.im_ready) + str(EntityManager.im_ready))
			return
	
	if Input.is_action_just_pressed("refresh"):
		get_tree().reload_current_scene()
		call_deferred("load_random_level")
	elif Input.is_action_just_pressed("editor_new_map"):
		get_tree().reload_current_scene()
		call_deferred("level_start")
	
	if Input.is_action_just_pressed("editor_start"):
		Utility.get_world().get_node("MapEditor").enable_edit_mode(true)
