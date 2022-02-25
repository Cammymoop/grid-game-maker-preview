extends Spatial

func _process(delta):
	var sky = $WorldEnvironment.environment.background_sky
	
	sky.sun_latitude += 0.05
	
	$MeshInstance.rotate_z(PI/3 * delta)
