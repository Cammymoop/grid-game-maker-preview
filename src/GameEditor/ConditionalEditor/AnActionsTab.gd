extends ScrollContainer

@export var list: NodePath

func get_list() -> Control:
	return get_node(list) as Control

func clear_contents() -> void:
	var list_node: Node = get_list()
	for list_child in list_node.get_children():
		list_node.remove_child(list_child)
		list_child.queue_free()
