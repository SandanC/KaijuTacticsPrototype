extends "res://scripts/drop_zone.gd"
var symbol := "attack"
func _draw() -> void:
	draw_set_transform(Vector2(25,25),0,Vector2.ONE*0.55)
	preload("res://scripts/symbols.gd").draw_on(self,symbol,Vector2.ZERO,Color("e8e4cf"))
	draw_set_transform(Vector2.ZERO)
