extends Node

# effects helper

const MiniTextMessage = preload("res://Scenes/GameEditor/Effects/mini_text_message.gd")
var mini_text_message_scene: = preload("res://Scenes/GameEditor/Effects/mini_text_message.tscn")




func spawn_mini_text_at(mini_text_message: String, at_pos: Vector2) -> void:
    var mini_text_message_instance: = mini_text_message_scene.instantiate() as MiniTextMessage
    mini_text_message_instance.mini_message = mini_text_message
    _spawn_entity_layer_effect(mini_text_message_instance, at_pos)

func _spawn_entity_layer_effect(effect_node: Node2D, at_pos: Vector2) -> void:
    var world: = Utility.get_world()
    if not world or not world.get_node_or_null("Entities"):
        push_error("Effects Helper: could not find world or entity layer")
        effect_node.queue_free()
        return
    
    world.get_node("Entities").add_child(effect_node)
    effect_node.position = at_pos
