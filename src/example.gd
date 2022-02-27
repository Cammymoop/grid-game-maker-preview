extends Node

func angle_difference(rotation_1: float, rotation_2: float) -> float:
	var vec_1 = Vector2.UP.rotated(rotation_1)
	var vec_2 = Vector2.UP.rotated(rotation_2)
	return vec_1.angle_to(vec_2)
