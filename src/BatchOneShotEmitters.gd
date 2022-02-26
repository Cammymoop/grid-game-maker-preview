extends Node2D

func emit_at(at_pos: Vector2) -> void:
	for c in get_children():
		var emitter = c as Particles2D
		if not emitter:
			continue
		
		
		
		if emitter.emitting:
			continue
		
		emitter.global_position = at_pos
		emitter.emitting = true
		emitter.restart()
		return
