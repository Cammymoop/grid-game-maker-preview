extends VBoxContainer

const PSSfxDefintionItem = preload("res://Scenes/GameEditor/sfx_defintion_item.gd")
var sfx_definition_item_scn: = preload("res://Scenes/GameEditor/sfx_defintion_item.tscn")

@export var sfx_preview_player: AudioStreamPlayer

@export var item_container: Control

@export var add_item_button: ButtonContainer

var _last_50_seeds: Array[int] = []

func _ready() -> void:
    add_item_button.pressed.connect(add_new_item)
    load_sfx_definitions()

func load_sfx_definitions() -> void:
    clear_children()
    for sfx_definition in GameManager.get_sfx_definitions():
        if not sfx_definition:
            continue
        var new_item: PSSfxDefintionItem = _get_item()
        new_item.set_sfx_definition(sfx_definition)
        item_container.add_child(new_item)

func clear_children() -> void:
    for child in item_container.get_children():
        if child is PSSfxDefintionItem:
            child.queue_free()

func _get_item() -> PSSfxDefintionItem:
    var new_item: = sfx_definition_item_scn.instantiate() as PSSfxDefintionItem
    new_item.changed.connect(on_item_changed)
    new_item.request_remove.connect(on_item_request_remove)
    new_item.play_preview.connect(on_item_play_preview)
    return new_item

func add_new_item() -> void:
    var new_item = _get_item()
    new_item.set_sfx_definition({
        "type": "ps_sfx",
        "name": Utility.random_animal(),
        "ps_seed": PuzzleScriptSFXR.get_random_int_seed(),
    })
    item_container.add_child(new_item)

func on_item_changed() -> void:
    save_updated_definition()

func save_updated_definition() -> void:
    var sfx_definitions: Array = []
    for item in item_container.get_children():
        if not item is PSSfxDefintionItem:
            continue
        sfx_definitions.append(item.get_sfx_definition())
    GameManager.set_sfx_definitions(sfx_definitions)

func on_item_request_remove(item: PSSfxDefintionItem) -> void:
    item.queue_free()
    save_updated_definition()

func force_clean_cache() -> void:
    var all_used_seeds: Array[int] = []
    for sfx_definition in GameManager.get_sfx_definitions():
        if sfx_definition.get('type') == 'ps_sfx':
            var named_seed: int = int(sfx_definition.get('ps_seed', 0))
            if named_seed != 0 and not all_used_seeds.has(named_seed):
                all_used_seeds.append(named_seed)
    SfxPlayer.clean_cache(Utility.arr_set_union(_last_50_seeds, all_used_seeds))

func _get_pssfx_audio_stream(ps_seed: int) -> AudioStreamWAV:
    if not _last_50_seeds.has(ps_seed):
        _last_50_seeds.append(ps_seed)
        if _last_50_seeds.size() > 50:
            _last_50_seeds = _last_50_seeds.slice(10, 50)
            force_clean_cache()
    return PuzzleScriptSFXR.get_sfx_stream(ps_seed)

func on_item_play_preview(item: PSSfxDefintionItem) -> void:
    var item_definition: Dictionary = item.get_sfx_definition()
    if item_definition['type'] == 'ps_sfx':
        sfx_preview_player.stream = _get_pssfx_audio_stream(int(item_definition['ps_seed']))
    else:
        sfx_preview_player.stream = null
    sfx_preview_player.play()
