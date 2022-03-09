extends ScrollContainer

export (NodePath) var list: String

func get_list() -> Control:
	return get_node(list) as Control
