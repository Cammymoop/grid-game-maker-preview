extends Node2D

const DigitSprite = preload("res://Scenes/digit_sprite.gd")
var digit_sprite_scn: PackedScene = preload("res://Scenes/digit_sprite.tscn")

@export var number: int = 0
@export var max_digits: int = 1
@export var pad_zeros: bool = true
@export var digit_separation: int = 0

var digit_width: int = 0

func _ready() -> void:
    _set_separation(digit_separation)
    update_display()

func set_separation(new_separation: int) -> void:
    _set_separation(new_separation)
    update_display()

func _set_separation(new_separation: int) -> void:
    digit_separation = new_separation
    var temp_digit_sprite: = digit_sprite_scn.instantiate() as DigitSprite
    digit_width = temp_digit_sprite.digit_size.x
    temp_digit_sprite.queue_free()

func set_number(new_number: int) -> void:
    number = new_number
    update_display()

func set_max_digits(new_max_digits: int) -> void:
    max_digits = new_max_digits

func get_digit_string() -> String:
    if pad_zeros:
        return ("%0" + str(max_digits) + "d") % number
    return "%d" % number


func update_display() -> void:
    var num_sprites: int = get_child_count()
    var digit_count: int = mini(len(get_digit_string()), max_digits)
    
    if digit_count != num_sprites:
        remake_sprites(digit_count)
    
    var digit_string: String = get_digit_string().right(digit_count)
    for i in range(digit_count):
        var digit_sprite: = get_child(i) as DigitSprite
        digit_sprite.set_digit(int(digit_string[i]))
    
    arrange_sprites()

func arrange_sprites() -> void:
    var num_sprites: int = get_child_count()
    var total_width: int = (num_sprites * (digit_width + digit_separation)) - digit_separation
    for i in range(num_sprites):
        var digit_sprite: = get_child(i) as DigitSprite
        var x_pos: int = -floori(total_width / 2.0) + i * (digit_width + digit_separation) + floori(digit_width / 2.)
        prints("digit %d x_pos: %d" % [i, x_pos])
        digit_sprite.position = Vector2(x_pos, 0)


func remake_sprites(digit_count: int) -> void:
    for child in get_children():
        child.queue_free()
    for i in range(digit_count):
        var digit_sprite: = digit_sprite_scn.instantiate()
        add_child(digit_sprite)