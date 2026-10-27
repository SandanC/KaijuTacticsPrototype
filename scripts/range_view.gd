extends Control
var radius := 1
var all_targets := false
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(0,11),"RANGE",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("b9cad6"))
	for y in range(3):
		for x in range(3):
			var distance := absi(x-1)+absi(y-1)
			var color := Color("26384b")
			if distance > 0 and distance <= radius:
				color = Color("d49f50")
			if distance == 0:
				color = Color("4f9cce")
			var rect := Rect2(x*18,19+y*18,16,16)
			draw_rect(rect,color)
			if distance == 0:
				draw_circle(rect.get_center(),3,Color("f5edce"))
	draw_string(font,Vector2(0,90),"ALL" if all_targets else ("SELF" if radius == 0 else "CHOOSE 1"),HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("b9cad6"))
