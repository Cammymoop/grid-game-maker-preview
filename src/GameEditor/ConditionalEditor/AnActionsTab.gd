extends ScrollContainer

@export var list: NodePath

func get_list() -> Control:
	return get_node(list) as Control
