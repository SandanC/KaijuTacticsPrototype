extends Control
signal tile_clicked(tile: Vector2i)
var battle
var hovered := Vector2i(-1,-1)
const HALF := Vector2(44,22)
const ORIGIN := Vector2(500,106)
var clock := 0.0
var player_draw := Vector2.ZERO
var enemy_draw := Vector2.ZERO
var initialized := false
var route_serial := -1
var route_points: Array = []
var font: Font = ThemeDB.fallback_font

func _ready() -> void:
	custom_minimum_size = Vector2(1000,600)
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
		if route_serial != battle.movement_serial:
			route_serial = battle.movement_serial
			for tile in battle.last_path.slice(1): route_points.append(tile_center(tile))
		var e := tile_center(battle.enemies[0].position)
		if not initialized:
			player_draw = p
			enemy_draw = e
			route_points.clear()
			initialized = true
		if not route_points.is_empty():
			player_draw = player_draw.move_toward(route_points[0],delta*260)
			if player_draw.distance_to(route_points[0]) < 1: route_points.pop_front()
		else:
			player_draw = player_draw.lerp(p,1.0-exp(-delta*12))
		enemy_draw = enemy_draw.lerp(e,1.0-exp(-delta*9))
	queue_redraw()

func poly(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points),color)

func diamond(center: Vector2, color: Color) -> void:
	poly([center+Vector2(-44,0),center+Vector2(0,-22),center+Vector2(44,0),center+Vector2(0,22)],color)

func text_at(point: Vector2, value: String, size: int, color: Color) -> void:
	draw_string(font,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _draw() -> void:
	draw_rect(Rect2(0,0,1000,600),Color("122e43"))
	for y in range(20):
		for x in range(30):
			var point := Vector2(x*36+(y%2)*15,y*32)
			draw_rect(Rect2(point,Vector2(15+(x*y)%14,2)),Color("1b3b50") if (x+y)%3 else Color("234659"))
	text_at(Vector2(20,24),"ASHEN OUTSKIRTS",19,Color("e0d1a5"))
	if battle == null:
		return
	var top := tile_center(Vector2i(0,0))+Vector2(0,-22)
	var left := tile_center(Vector2i(0,9))+Vector2(-44,0)
	var right := tile_center(Vector2i(9,0))+Vector2(44,0)
	var bottom := tile_center(Vector2i(9,9))+Vector2(0,22)
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
			var edge := PackedVector2Array([center+Vector2(-44,0),center+Vector2(0,-22),center+Vector2(44,0),center+Vector2(0,22),center+Vector2(-44,0)])
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
			if tile in [Vector2i(1,1),Vector2i(1,8),Vector2i(8,8)]:
				# Tile surface markings only, no impassable objects.
				draw_rect(Rect2(center+Vector2(-9,-4),Vector2(18,8)),Color("83917a"))
			# Cosmetic grass and stones do not introduce hidden terrain rules.
			if (x*7+y*11)%23 == 0 and tile not in [battle.player.position,battle.enemies[0].position]:
				poly([center+Vector2(-7,1),center+Vector2(-4,-6),center+Vector2(3,-8),center+Vector2(10,0),center+Vector2(4,4)],Color("91998a"))
			if tile in battle.scenario.blocked:
				building(center)
			if tile == battle.player.position:
				monster(player_draw if initialized else center)
			if tile == battle.enemies[0].position and battle.enemies[0].hp > 0:
				soldier(enemy_draw if initialized else center)
	# Tactical cursor at the active unit's feet.
	if battle.enemies[0].hp > 0 and battle.Rules.distance(battle.enemies[0].position,battle.player.position) <= battle.enemies[0].range:
		var enemy_point := tile_center(battle.enemies[0].position)
		var player_point := tile_center(battle.player.position)
		var direction := (player_point-enemy_point).normalized()
		draw_dashed_line(enemy_point+direction*24,player_point-direction*25,Color("ed917d"),3,5)
		text_at((enemy_point+player_point)*0.5+Vector2(0,-12),"1 DMG",11,Color("ffb49e"))
	var p := player_draw if initialized else tile_center(battle.player.position)
	draw_arc(p+Vector2(0,4),24,0,TAU,32,Color("a2def2"),2)
	if not battle.action.is_empty() and battle.action.target == "move":
		var route: Array = battle.movement_paths(battle.zones.members("movement").size()).get(hovered,[])
		var previous := tile_center(battle.player.position)
		for tile in route:
			var next := tile_center(tile)
			draw_dashed_line(previous,next,Color("a7edee"),3,5)
			previous = next
		if not route.is_empty():
			text_at(previous+Vector2(12,-12),"%d" % route.size(),16,Color("fff0b6"))
	if hovered.x >= 0 and hovered.y >= 0 and hovered.x < 10 and hovered.y < 10:
		text_at(Vector2(750,570),"PLAINS  %s%d" % [char(65+hovered.y),hovered.x+1],14,Color("ead69e"))

func shadow(center: Vector2, width: float) -> void:
	draw_set_transform(center,0,Vector2(1,0.36))
	draw_circle(Vector2.ZERO,width,Color(0,0,0,0.3))
	draw_set_transform(Vector2.ZERO)

func monster(center: Vector2) -> void:
	shadow(center,19)
	draw_set_transform(center,0,Vector2.ONE*0.65)
	var p := Vector2(0,sin(clock*2)*1.4)
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
	draw_set_transform(Vector2.ZERO)
	hp_bar(center+Vector2(-25,14),battle.player.hp,battle.player.max_hp,Color("83ccec"))

func soldier(center: Vector2) -> void:
	shadow(center,15)
	draw_set_transform(center,0,Vector2.ONE*0.8)
	var p := Vector2(0,sin(clock*2.6)*0.6)
	draw_rect(Rect2(p+Vector2(-10,-17),Vector2(7,20)),Color("343c4b"))
	draw_rect(Rect2(p+Vector2(4,-17),Vector2(7,20)),Color("343c4b"))
	draw_rect(Rect2(p+Vector2(-13,-40),Vector2(27,26)),Color("a18d66"))
	draw_rect(Rect2(p+Vector2(-8,-35),Vector2(16,16)),Color("c5b084"))
	draw_rect(Rect2(p+Vector2(-8,-54),Vector2(19,15)),Color("d5b295"))
	draw_rect(Rect2(p+Vector2(-13,-59),Vector2(27,10)),Color("637987"))
	draw_rect(Rect2(p+Vector2(-10,-63),Vector2(22,7)),Color("7a909b"))
	draw_rect(Rect2(p+Vector2(-22,-35),Vector2(36,6)),Color("293946"))
	draw_line(p+Vector2(-15,-32),p+Vector2(-6,-24),Color("d5b295"),5)
	draw_set_transform(Vector2.ZERO)
	hp_bar(center+Vector2(-25,14),battle.enemies[0].hp,5,Color("ee9b8c"))

func hp_bar(position: Vector2, hp: int, maximum: int, color: Color) -> void:
	draw_rect(Rect2(position-Vector2.ONE,Vector2(52,7)),Color("172b3c"))
	draw_rect(Rect2(position,Vector2(50.0*hp/maximum,5)),color)

func building(center: Vector2) -> void:
	# Original compact isometric city block; its tile is genuinely impassable.
	var a := center+Vector2(-20,-1)
	var b := center+Vector2(0,-12)
	var c := center+Vector2(20,-1)
	var d := center+Vector2(0,10)
	var height := Vector2(0,48)
	poly([a,d,d-height,a-height],Color("9c9e90"))
	poly([d,c,c-height,d-height],Color("696e6d"))
	poly([a-height,b-height,c-height,d-height],Color("c5c4b2"))
	for floor_index in range(4):
		for column in range(2):
			var p := a+Vector2(5+column*8,-9-floor_index*10+column*4)
			draw_rect(Rect2(p,Vector2(4,5)),Color("3b5260"))
			p = d+Vector2(4+column*8,-8-floor_index*10-column*4)
			draw_rect(Rect2(p,Vector2(4,5)),Color("2b3e48"))
	draw_rect(Rect2(center+Vector2(-5,-53),Vector2(9,6)),Color("8a9189"))
