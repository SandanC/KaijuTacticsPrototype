extends Control
signal tile_clicked(tile: Vector2i)
var battle
var hovered := Vector2i(-1,-1)
const HALF := Vector2(30,16)
const ORIGIN := Vector2(331,167)
var clock := 0.0
var player_draw := Vector2.ZERO
var enemy_draw := Vector2.ZERO
var initialized := false
var font: Font = ThemeDB.fallback_font

func _ready() -> void:
 custom_minimum_size = Vector2(662,662)
 mouse_exited.connect(func(): hovered = Vector2i(-1,-1))

func tile_center(tile: Vector2i) -> Vector2:
 return ORIGIN + Vector2((tile.x-tile.y)*HALF.x,(tile.x+tile.y)*HALF.y)

func screen_tile(point: Vector2) -> Vector2i:
 var local := point - ORIGIN
 return Vector2i(floori((local.x/HALF.x + local.y/HALF.y)/2.0+0.5),floori((local.y/HALF.y-local.x/HALF.x)/2.0+0.5))

func _gui_input(event: InputEvent) -> void:
 if event is InputEventMouseMotion:
  hovered = screen_tile(event.position)
 if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
  var tile := screen_tile(event.position)
  if tile.x >= 0 and tile.y >= 0 and tile.x < 10 and tile.y < 10:
   tile_clicked.emit(tile)

func _process(delta: float) -> void:
 clock += delta
 if battle != null:
  var p := tile_center(battle.player.position)
  var e := tile_center(battle.enemies[0].position)
  if not initialized:
   player_draw = p
   enemy_draw = e
   initialized = true
  player_draw = player_draw.lerp(p,1.0-exp(-delta*12))
  enemy_draw = enemy_draw.lerp(e,1.0-exp(-delta*9))
 queue_redraw()

func poly(points: Array, color: Color) -> void:
 draw_colored_polygon(PackedVector2Array(points),color)

func diamond(center: Vector2, color: Color) -> void:
 poly([center+Vector2(-30,0),center+Vector2(0,-16),center+Vector2(30,0),center+Vector2(0,16)],color)

func text_at(point: Vector2, value: String, size: int, color: Color) -> void:
 draw_string(font,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _draw() -> void:
 draw_rect(Rect2(0,0,662,662),Color("172738"))
 # Distant ridgeline and atmospheric silhouettes frame a small tactical diorama.
 poly([Vector2(0,200),Vector2(0,119),Vector2(73,58),Vector2(129,106),Vector2(197,42),Vector2(278,123),Vector2(371,68),Vector2(459,118),Vector2(537,33),Vector2(662,121),Vector2(662,250)],Color("213849"))
 poly([Vector2(0,270),Vector2(0,183),Vector2(107,126),Vector2(219,186),Vector2(340,115),Vector2(433,169),Vector2(552,110),Vector2(662,185),Vector2(662,300)],Color("2b4653"))
 text_at(Vector2(24,32),"ASHEN OUTSKIRTS",22,Color("eee1b6"))
 text_at(Vector2(24,54),"SECTOR 07  /  ROUT THE MILITARY",12,Color("a0b5c5"))
 if battle == null:
  return
 var top := tile_center(Vector2i(0,0))+Vector2(0,-16)
 var left := tile_center(Vector2i(0,9))+Vector2(-30,0)
 var right := tile_center(Vector2i(9,0))+Vector2(30,0)
 var bottom := tile_center(Vector2i(9,9))+Vector2(0,16)
 poly([left,bottom,bottom+Vector2(0,42),left+Vector2(0,42)],Color("4b4e43"))
 poly([bottom,right,right+Vector2(0,42),bottom+Vector2(0,42)],Color("343d3b"))
 draw_line(left+Vector2(0,12),bottom+Vector2(0,12),Color("69705a"),2)
 draw_line(bottom+Vector2(0,12),right+Vector2(0,12),Color("4c5b50"),2)
 var legal: Array = battle.targets()
 for layer in range(19):
  for x in range(10):
   var y := layer-x
   if y < 0 or y >= 10:
    continue
   var tile := Vector2i(x,y)
   var center := tile_center(tile)
   var dirt := y in [4,5] or x == 7
   var base := Color("8b8a66") if dirt else Color("678461")
   base = base.lightened(float((x*13+y*7)%5)*0.018)
   diamond(center,base)
   var edge := PackedVector2Array([center+Vector2(-30,0),center+Vector2(0,-16),center+Vector2(30,0),center+Vector2(0,16),center+Vector2(-30,0)])
   draw_polyline(edge,Color(0.1,0.2,0.15,0.22),1)
   if not dirt:
    for i in range(3):
     var tuft := center+Vector2(-12+i*10, float((x+y+i)%3)*3-2)
     draw_line(tuft,tuft+Vector2(2,-4),Color("8ea878"),1)
   else:
    draw_line(center+Vector2(-9,2),center+Vector2(1,5),Color("a3a07c"),1)
   if tile in legal:
    diamond(center,Color(0.22,0.65,0.95,0.48) if battle.action.get("target", "") == "move" else Color(0.95,0.3,0.2,0.58))
    draw_polyline(edge,Color("9eeaff"),2)
   if tile == hovered:
    draw_polyline(edge,Color("ffdf8c"),3)
   # Cosmetic grass and stones do not introduce hidden terrain rules.
   if (x*7+y*11)%23 == 0 and tile not in [battle.player.position,battle.enemies[0].position]:
    poly([center+Vector2(-7,1),center+Vector2(-4,-6),center+Vector2(3,-8),center+Vector2(10,0),center+Vector2(4,4)],Color("91998a"))
   if tile == battle.player.position:
    monster(player_draw if initialized else center)
   if tile == battle.enemies[0].position and battle.enemies[0].hp > 0:
    soldier(enemy_draw if initialized else center)
 # Tactical cursor at the active unit's feet.
 var p := player_draw if initialized else tile_center(battle.player.position)
 draw_arc(p+Vector2(0,4),24,0,TAU,32,Color("a2def2"),2)
 text_at(Vector2(24,590),"MOSSBACK",15,Color("cce6c1"))
 text_at(Vector2(24,612),"Move with blue tiles  •  Attack with red tiles",13,Color("a9bece"))
 text_at(Vector2(24,635),"Hover to inspect  /  Click a highlighted tile to confirm",12,Color("8ea9bb"))
 if hovered.x >= 0 and hovered.y >= 0 and hovered.x < 10 and hovered.y < 10:
  text_at(Vector2(449,590),"PLAINS  %s%d" % [char(65+hovered.y),hovered.x+1],14,Color("ead69e"))

func shadow(center: Vector2, width: float) -> void:
 draw_set_transform(center,0,Vector2(1,0.36))
 draw_circle(Vector2.ZERO,width,Color(0,0,0,0.3))
 draw_set_transform(Vector2.ZERO)

func monster(center: Vector2) -> void:
 shadow(center,24)
 var p := center+Vector2(0,sin(clock*2)*1.4)
 # Tail, dorsal plates, legs, torso, muzzle: an original small kaiju sprite.
 poly([p+Vector2(-9,-12),p+Vector2(-36,-8),p+Vector2(-46,-22),p+Vector2(-29,-18),p+Vector2(-7,-28)],Color("426e57"))
 for i in range(4):
  var spine := p+Vector2(-15+i*2,-25-i*9)
  poly([spine,spine+Vector2(-12,-8),spine+Vector2(3,-13)],Color("c3c487"))
 draw_rect(Rect2(p+Vector2(-15,-24),Vector2(13,27)),Color("355744"))
 draw_rect(Rect2(p+Vector2(5,-22),Vector2(13,26)),Color("4d805a"))
 poly([p+Vector2(-20,-20),p+Vector2(-21,-50),p+Vector2(-10,-67),p+Vector2(12,-61),p+Vector2(19,-29),p+Vector2(8,-15)],Color("61975f"))
 poly([p+Vector2(-6,-18),p+Vector2(-9,-43),p+Vector2(8,-48),p+Vector2(14,-25)],Color("98b77a"))
 draw_rect(Rect2(p+Vector2(-7,-74),Vector2(27,24)),Color("77a66c"))
 draw_rect(Rect2(p+Vector2(10,-64),Vector2(21,13)),Color("8eb77a"))
 draw_rect(Rect2(p+Vector2(12,-70),Vector2(5,5)),Color("fce0a0"))
 draw_rect(Rect2(p+Vector2(15,-69),Vector2(2,3)),Color("202e32"))
 draw_line(p+Vector2(18,-54),p+Vector2(29,-54),Color("294e43"),2)
 draw_line(p+Vector2(11,-41),p+Vector2(27,-29),Color("568754"),9)
 draw_line(p+Vector2(25,-29),p+Vector2(31,-34),Color("ddd9b1"),3)
 hp_bar(center+Vector2(-25,14),battle.player.hp,battle.player.max_hp,Color("83ccec"))

func soldier(center: Vector2) -> void:
 shadow(center,16)
 var p := center+Vector2(0,sin(clock*2.6)*0.6)
 draw_rect(Rect2(p+Vector2(-10,-17),Vector2(7,20)),Color("343c4b"))
 draw_rect(Rect2(p+Vector2(4,-17),Vector2(7,20)),Color("343c4b"))
 draw_rect(Rect2(p+Vector2(-13,-40),Vector2(27,26)),Color("a18d66"))
 draw_rect(Rect2(p+Vector2(-8,-35),Vector2(16,16)),Color("c5b084"))
 draw_rect(Rect2(p+Vector2(-8,-54),Vector2(19,15)),Color("d5b295"))
 draw_rect(Rect2(p+Vector2(-13,-59),Vector2(27,10)),Color("637987"))
 draw_rect(Rect2(p+Vector2(-10,-63),Vector2(22,7)),Color("7a909b"))
 draw_rect(Rect2(p+Vector2(-22,-35),Vector2(36,6)),Color("293946"))
 draw_line(p+Vector2(-15,-32),p+Vector2(-6,-24),Color("d5b295"),5)
 hp_bar(center+Vector2(-25,14),battle.enemies[0].hp,5,Color("ee9b8c"))

func hp_bar(position: Vector2, hp: int, maximum: int, color: Color) -> void:
 draw_rect(Rect2(position-Vector2.ONE,Vector2(52,7)),Color("172b3c"))
 draw_rect(Rect2(position,Vector2(50.0*hp/maximum,5)),color)
