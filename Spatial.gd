extends Node3D

func _process(delta):
	var sky = $WorldEnvironment.environment.background_sky
	
	sky.sun_latitude += 0.05
	
	$MeshInstance3D.rotate_z(PI/3 * delta)
