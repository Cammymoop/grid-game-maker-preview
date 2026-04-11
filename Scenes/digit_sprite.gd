extends Sprite2D

@export var digit_size: Vector2i = Vector2i(8, 8)
@export var digits_per_row: int = 5

var digit: int = 0

func _ready() -> void:
    update_rect()

func update_rect() -> void:
    var digit_x: int = digit % digits_per_row
    var digit_y: int = floori(digit / float(digits_per_row))
    region_rect = Rect2i(digit_x * digit_size.x, digit_y * digit_size.y, digit_size.x, digit_size.y)
    region_enabled = true

func set_digit(new_digit: int) -> void:
    digit = new_digit
    update_rect()
