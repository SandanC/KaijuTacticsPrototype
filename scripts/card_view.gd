extends Button
signal die_dropped(payload: Dictionary)
var accepts_die: Callable

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
 return not disabled and data is Dictionary and accepts_die.is_valid() and accepts_die.call(data)

func _drop_data(_position: Vector2, data: Variant) -> void:
 die_dropped.emit(data)
