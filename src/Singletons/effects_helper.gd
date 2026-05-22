extends Node

# effects helper

const MiniTextMessage = preload("res://Scenes/GameEditor/Effects/mini_text_message.gd")
var mini_text_message_scene: = preload("res://Scenes/GameEditor/Effects/mini_text_message.tscn")

@export var base_effects_z_index: int = 5

var effects_holder: Node2D = null
var effect_id_counter: int = 0

var effect_id_references: Dictionary[int, Node2D] = {}

func _ready() -> void:
    MapManager.map_cleared.connect(clear_all_effects)

func get_next_effect_id() -> int:
    effect_id_counter += 1
    return effect_id_counter

func spawn_mini_text_at(mini_text_message: String, at_pos: Vector2, lifetime: float = -1, z_offset: int = 0, use_id: int = -1) -> int:
    var mini_text_message_instance: = mini_text_message_scene.instantiate() as MiniTextMessage
    mini_text_message_instance.z_index = z_offset
    if lifetime >= 0:
        mini_text_message_instance.lifetime = lifetime
    mini_text_message_instance.mini_message = mini_text_message
    return _spawn_entity_layer_effect(mini_text_message_instance, at_pos, use_id)

func _fetch_effects_holder() -> void:
    if effects_holder:
        return
    var world: = Utility.get_world()
    if not world:
        push_error("Effects Helper: could not find world")
        return
    effects_holder = world.get_node_or_null("Effects")
    if not effects_holder:
        effects_holder = Node2D.new()
        effects_holder.name = "Effects"
        world.add_child(effects_holder, true)
    effects_holder.z_index = base_effects_z_index

func _spawn_entity_layer_effect(effect_node: Node2D, at_pos: Vector2, use_id: int = -1) -> int:
    if not effects_holder:
        _fetch_effects_holder()
        if not effects_holder:
            return -1

    var effect_id: = use_id
    if effect_id < 0:
        effect_id = get_next_effect_id()
    else:
        if effect_id_references.has(effect_id):
            push_warning("Effect id already in use: %s" % [effect_id])
            remove_effect_by_id(effect_id)
        effect_id_counter = maxi(effect_id_counter, use_id + 1)
    effects_holder.add_child(effect_node)
    effect_node.position = at_pos
    effect_id_references[effect_id] = effect_node
    return effect_id

func clear_all_effects() -> void:
    if not effects_holder:
        _fetch_effects_holder()
        if not effects_holder:
            return
    for effect in effects_holder.get_children():
        effect.queue_free()
    effect_id_references.clear()

func clear_effect_id(effect_id: int) -> void:
    effect_id_references.erase(effect_id)

func _cleanup_effect_ids() -> void:
    var new_id_references: Dictionary[int, Node2D] = {}
    for effect_id in effect_id_references.keys():
        if not effect_id_references[effect_id]:
            continue
        var effect_node: = effect_id_references[effect_id]
        if effect_node.is_queued_for_deletion():
            continue
        new_id_references[effect_id] = effect_node

func remove_effect_by_id(effect_id: int) -> void:
    prints("removing effect by id: %s" % [effect_id])
    if not effect_id_references.has(effect_id):
        return
    if is_instance_valid(effect_id_references[effect_id]):
        effect_id_references[effect_id].queue_free()
    clear_effect_id(effect_id)

func get_effect_node_by_id(effect_id: int) -> Node2D:
    if not effect_id_references.has(effect_id) or not is_instance_valid(effect_id_references[effect_id]):
        return null
    return effect_id_references[effect_id]