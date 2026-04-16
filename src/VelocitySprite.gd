extends Sprite2D

var x_velocity: float
var y_velocity: float
var angular_velocity: float

func set_spr_velocity(new_velocity: Vector2) -> void:
    x_velocity = new_velocity.x
    y_velocity = new_velocity.y

func get_spr_velocity() -> Vector2:
    return Vector2(x_velocity, y_velocity)

func add_spr_velocity(delta: Vector2) -> void:
    x_velocity += delta.x
    y_velocity += delta.y

func velocity_move(delta_time: float) -> void:
    position.x += x_velocity * delta_time
    position.y += y_velocity * delta_time

func angular_velocity_spin(delta_time: float) -> void:
    rotation += angular_velocity * delta_time

func step(delta_time: float) -> void:
    position.x += x_velocity * delta_time
    position.y += y_velocity * delta_time
    rotation += angular_velocity * delta_time