extends PanelContainer
signal dropped(payload: Dictionary)
var accepts: Callable
func _can_drop_data(_point: Vector2, data: Variant) -> bool:
	return data is Dictionary and accepts.is_valid() and accepts.call(data)
func _drop_data(_point: Vector2, data: Variant) -> void:
	if _can_drop_data(_point, data):
		dropped.emit(data)
