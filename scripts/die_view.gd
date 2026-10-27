extends Button
## Cosmetic tumbling uses time only; it never rerolls the battle model.
var die: Dictionary = {}
var chosen := false
var elapsed := 2.0
var delay := 0.0
const DURATION := 1.15
const SYMBOLS = ["attack", "movement", "energy", "defense", "regeneration"]
var rolling := false

func _ready() -> void:
 custom_minimum_size = Vector2(164, 150)
 mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 for state in ["normal", "hover", "pressed", "disabled", "focus"]:
  add_theme_stylebox_override(state, StyleBoxEmpty.new())

func show_die(value: Dictionary, selected: bool, can_select: bool) -> void:
 die = value
 chosen = selected
 disabled = not can_select or rolling
 tooltip_text = "%s die #%d · %s\nClick to select this exact die for payment." % [die.color.capitalize(), die.id + 1, die.symbol.capitalize()]
 queue_redraw()

func roll(index: int) -> void:
 elapsed = 0.0
 delay = index * 0.16
 rolling = true
 disabled = true
 set_process(true)

func _process(delta: float) -> void:
 elapsed += delta
 if elapsed >= DURATION + delay:
  rolling = false
  set_process(false)
 queue_redraw()

func _draw() -> void:
 if die.is_empty():
  return
 var t := clampf((elapsed - delay) / DURATION, 0, 1)
 var progress := 1.0 - t
 var center := Vector2(size.x * 0.5, 62)
 var bounce := absf(sin(t * PI * 3.0)) * progress * 32 if rolling else 0.0
 draw_ellipse_shadow(center + Vector2(0, 44), 40 - bounce * 0.25)
 var angle := sin(t * PI * 6.0) * progress * 0.8 if rolling else 0.0
 draw_set_transform(center - Vector2(0, bounce), angle, Vector2.ONE * (0.88 + 0.12 * t if rolling else 1.0))
 var base := Color("70af66") if die.color == "green" else Color("598bc7")
 if die.spent:
  base = base.darkened(0.65)
 draw_colored_polygon(PackedVector2Array([Vector2(-39,-30),Vector2(25,-30),Vector2(39,-43),Vector2(-25,-43)]), base.lightened(0.27))
 draw_colored_polygon(PackedVector2Array([Vector2(25,-30),Vector2(39,-43),Vector2(39,17),Vector2(25,30)]), base.darkened(0.35))
 var face := Rect2(-39, -30, 64, 60)
 var box := StyleBoxFlat.new()
 box.bg_color = base
 box.border_color = Color("fff0b6") if chosen else base.lightened(0.45)
 box.set_border_width_all(3 if chosen else 1)
 box.set_corner_radius_all(7)
 draw_style_box(box, face)
 var symbol: String = SYMBOLS[int(elapsed * 22 + die.id * 3) % SYMBOLS.size()] if rolling and t < 0.96 else die.symbol
 draw_symbol(symbol, Vector2(-7, 0), Color("f8f4dc") if not die.spent else Color("73818c"))
 if die.spent:
  draw_line(Vector2(-28, -20),Vector2(16, 20),Color("84939c"),3)
 draw_set_transform(Vector2.ZERO)
 var font := ThemeDB.fallback_font
 var text: String = "ROLLING…" if rolling else ("SPENT" if die.spent else str(die.symbol).to_upper())
 draw_string(font,Vector2(0,126),text,HORIZONTAL_ALIGNMENT_CENTER,size.x,15,Color("f2dfac"))
 draw_string(font,Vector2(0,146),"%s • %s" % [str(die.color).capitalize(), "Selected" if chosen else "#%d" % (die.id + 1)],HORIZONTAL_ALIGNMENT_CENTER,size.x,12,Color("a6bbcf"))

func draw_ellipse_shadow(center: Vector2, radius: float) -> void:
 draw_set_transform(center,0,Vector2(1,0.3))
 draw_circle(Vector2.ZERO,radius,Color(0,0,0,0.4))
 draw_set_transform(Vector2.ZERO)

func draw_symbol(symbol: String, center: Vector2, color: Color) -> void:
 match symbol:
  "attack":
   draw_colored_polygon(PackedVector2Array([center+Vector2(-5,10),center+Vector2(-9,6),center+Vector2(9,-16),center+Vector2(17,-20),center+Vector2(15,-10)]),color)
   draw_line(center+Vector2(-12,4),center+Vector2(1,15),color,4)
   draw_line(center+Vector2(-7,9),center+Vector2(-15,19),color,5)
  "movement":
   for offset in [Vector2(-9,6),Vector2(9,-7)]:
    draw_circle(center+offset,6,color)
    draw_circle(center+offset+Vector2(1,-9),4,color)
    draw_line(center+offset,center+offset+Vector2(-3,7),color,8)
  "energy":
   draw_colored_polygon(PackedVector2Array([center+Vector2(2,-22),center+Vector2(-14,3),center+Vector2(-1,3),center+Vector2(-5,22),center+Vector2(16,-5),center+Vector2(3,-5)]),color)
  "defense":
   draw_colored_polygon(PackedVector2Array([center+Vector2(-17,-15),center+Vector2(0,-21),center+Vector2(17,-15),center+Vector2(14,5),center+Vector2(0,21),center+Vector2(-14,5)]),color)
   draw_line(center+Vector2(0,-12),center+Vector2(0,10),Color("6585a0"),3)
  "regeneration":
   draw_rect(Rect2(center+Vector2(-5,-20),Vector2(10,40)),color)
   draw_rect(Rect2(center+Vector2(-20,-5),Vector2(40,10)),color)

var battle_token: int
func _get_drag_data(_position: Vector2) -> Variant:
 if rolling or die.is_empty() or die.spent or disabled:
  return null
 var preview = get_script().new()
 preview.die = die.duplicate()
 preview.custom_minimum_size = Vector2(164,150)
 preview.size = Vector2(164,150)
 preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
 set_drag_preview(preview)
 return {"type": "battle_die", "index": die.id, "battle": battle_token}
