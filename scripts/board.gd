extends Control
signal tile_clicked(tile: Vector2i)
var battle
var hovered := Vector2i(-1, -1)
const CELL := 59.0
const ORIGIN := Vector2(36, 36)
const INK := Color("e5ecdf")
var font: Font = ThemeDB.fallback_font

func _ready() -> void:
 custom_minimum_size = Vector2(662, 662)
 mouse_exited.connect(func(): hovered = Vector2i(-1, -1); queue_redraw())

func _gui_input(event: InputEvent) -> void:
 if event is InputEventMouseMotion:
  hovered = Vector2i((event.position - ORIGIN) / CELL)
  queue_redraw()
 if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
  var point: Vector2 = event.position - ORIGIN
  if point.x >= 0 and point.y >= 0 and point.x < CELL * 10 and point.y < CELL * 10:
   tile_clicked.emit(Vector2i(point / CELL))

func word(pos: Vector2, text: String, size: int, color: Color) -> void:
 draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw() -> void:
 if battle == null:
  return
 draw_style_box(_panel(), Rect2(Vector2.ZERO, Vector2(662, 662)))
 var legal: Array = battle.targets()
 for y in range(10):
  for x in range(10):
   var tile := Vector2i(x, y)
   var rect := Rect2(ORIGIN + Vector2(tile) * CELL, Vector2(CELL - 3, CELL - 3))
   var fill := Color("263c39") if (x + y) % 2 == 0 else Color("2c4340")
   if tile in legal:
    fill = Color("487765") if battle.action.get("target", "") == "move" else Color("865d42")
   if tile == hovered:
    fill = fill.lightened(0.12)
   draw_rect(rect, fill)
   if tile in legal:
    draw_rect(rect.grow(-3), Color("e4c777"), false, 2)
   # Subtle city-plan marks, purely decorative.
   draw_line(rect.position + Vector2(8, 8), rect.position + Vector2(15, 8), Color("52655b"), 1)
 for i in range(10):
  word(Vector2(ORIGIN.x + i * CELL + 22, 24), str(i + 1), 12, Color("9aaea2"))
  word(Vector2(15, ORIGIN.y + i * CELL + 33), char(65 + i), 12, Color("9aaea2"))
 _token(battle.player.position, Color("b5d28a"), "K", battle.player.hp, battle.player.max_hp, true)
 for enemy in battle.enemies:
  if enemy.hp > 0:
   _token(enemy.position, Color("edaa77"), "I", enemy.hp, 5, false)
 word(Vector2(37, 648), "SECTOR 07   /   OPEN GROUND", 12, Color("a6b5a7"))

func _panel() -> StyleBoxFlat:
 var box := StyleBoxFlat.new()
 box.bg_color = Color("182d2a")
 box.set_corner_radius_all(12)
 return box

func _token(tile: Vector2i, color: Color, label: String, hp: int, maximum: int, monster: bool) -> void:
 var center := ORIGIN + Vector2(tile) * CELL + Vector2(28, 27)
 draw_circle(center + Vector2(2, 3), 22, Color(0, 0, 0, 0.35))
 if monster:
  draw_colored_polygon(PackedVector2Array([center + Vector2(-22, -15), center + Vector2(-8, -22), center + Vector2(0, -28), center + Vector2(8, -22), center + Vector2(22, -15), center + Vector2(20, 14), center + Vector2(0, 23), center + Vector2(-20, 14)]), color)
 else:
  draw_rect(Rect2(center - Vector2(21, 21), Vector2(42, 42)), color)
 word(center + Vector2(-7, 7), label, 22, Color("152b28"))
 draw_rect(Rect2(center + Vector2(-22, 26), Vector2(44, 4)), Color("10201e"))
 draw_rect(Rect2(center + Vector2(-22, 26), Vector2(44.0 * hp / maximum, 4)), color)
