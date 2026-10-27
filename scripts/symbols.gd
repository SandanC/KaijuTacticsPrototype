extends RefCounted
## Shared, color-independent resource pictograms for dice and payment slots.
static func draw_on(canvas: CanvasItem, symbol: String, center: Vector2, color: Color) -> void:
	match symbol:
		"attack":
			canvas.draw_colored_polygon(PackedVector2Array([center+Vector2(-5,10),center+Vector2(-9,6),center+Vector2(9,-16),center+Vector2(17,-20),center+Vector2(15,-10)]),color)
			canvas.draw_line(center+Vector2(-12,4),center+Vector2(1,15),color,4)
			canvas.draw_line(center+Vector2(-7,9),center+Vector2(-15,19),color,5)
		"movement":
			for offset in [Vector2(-9,6),Vector2(9,-7)]:
				canvas.draw_circle(center+offset,6,color)
				canvas.draw_circle(center+offset+Vector2(1,-9),4,color)
				canvas.draw_line(center+offset,center+offset+Vector2(-3,7),color,8)
		"energy":
			canvas.draw_colored_polygon(PackedVector2Array([center+Vector2(2,-22),center+Vector2(-14,3),center+Vector2(-1,3),center+Vector2(-5,22),center+Vector2(16,-5),center+Vector2(3,-5)]),color)
		"defense":
			canvas.draw_colored_polygon(PackedVector2Array([center+Vector2(-17,-15),center+Vector2(0,-21),center+Vector2(17,-15),center+Vector2(14,5),center+Vector2(0,21),center+Vector2(-14,5)]),color)
			canvas.draw_line(center+Vector2(0,-12),center+Vector2(0,10),Color("6585a0"),3)
		"regeneration":
			canvas.draw_rect(Rect2(center+Vector2(-5,-20),Vector2(10,40)),color)
			canvas.draw_rect(Rect2(center+Vector2(-20,-5),Vector2(40,10)),color)

