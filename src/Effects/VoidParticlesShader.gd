extends Particles2D

func _ready():
	update_size()
	get_viewport().connect("size_changed", self, "update_size")

func update_size():
	var vp = get_viewport()
	position.x = vp.size.x / 2
	position.y = vp.size.x / 2
	
	process_material.set_shader_param("emission_box_extents", Vector3((vp.size.x/2) * 1.2, vp.size.y * 1.5, 1))
