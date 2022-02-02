extends Node

var started = false

func level_start():
	MapManager.create_default_layer()
	MapManager.auto_setup_layers()
	EntityManager.create_default_player()
	EntityManager.create_default_box()
	EntityManager.create_default_bouncer()

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
		call_deferred("level_start")
