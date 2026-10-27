extends SceneTree
var game
var last_pointer := Vector2.ZERO
var errors := 0

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Use a graphical display for the native drag and render smoke test.")
		quit(2)
		return
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if condition: print("PASS: "+message)
	else:
		errors += 1
		push_error(message)

func snap(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func motion(point: Vector2, held: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = point-last_pointer
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	last_pointer = point
	Input.parse_input_event(event)
	await process_frame
	await process_frame

func drag(index: int, destination: Vector2) -> void:
	var source: Vector2 = game.dice_views[index].global_position+Vector2(34,28)
	await motion(source)
	var press := InputEventMouseButton.new()
	press.position = source
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	await motion(source+Vector2(25,0),true)
	await motion(destination,true)
	var release := InputEventMouseButton.new()
	release.position = destination
	release.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(release)
	await process_frame
	await process_frame
	await create_timer(0.4).timeout

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.35).timeout
	await snap("user://systems-rolling.png")
	await create_timer(1.9).timeout
	check(not game.rolling,"Dice settle and travel from rolling surface to tray")
	var rolled: Array = game.battle.zones.members("rolled")
	var first: int = rolled[0]
	var second: int = rolled[1]
	game.battle.dice[first].symbol = "attack"
	game.refresh()
	await create_timer(0.4).timeout
	var slot = game.card_slots[game.battle.slot_zone(game.battle.cards[0],0)]
	await drag(first,slot.get_global_rect().get_center())
	check(game.battle.dice[first].zone == game.battle.slot_zone(game.battle.cards[0],0),"Native drag into exact ability slot stages the die")
	await snap("user://systems-card-payment.png")
	await drag(first,Vector2(660,795))
	check(game.battle.dice[first].zone == "rolled","Native drag off card returns die to open tray")
	game.battle.dice[first].symbol = "movement"
	game.battle.dice[second].symbol = "movement"
	game.refresh()
	await create_timer(0.4).timeout
	await drag(first,Vector2(1355,747))
	await drag(second,Vector2(1355,747))
	check(game.movement_label.text.ends_with("2"),"Two native movement drops raise visible counter to two")
	await drag(second,Vector2(660,795))
	check(game.movement_label.text.ends_with("1"),"Native drag out reduces movement counter")
	await drag(second,Vector2(1355,747))
	var origin: Vector2i = game.battle.player.position
	var map_point: Vector2 = game.board.global_position+game.board.tile_center(origin+Vector2i(-2,0))
	await motion(map_point)
	await snap("user://systems-movement.png")
	game.on_tile(origin+Vector2i.LEFT)
	await create_timer(0.5).timeout
	check(game.battle.zones.members("used").size() == 1 and game.battle.zones.members("rolled").size() == 1,"Shorter move visibly transfers only one die to Used")
	await snap("user://systems-used.png")
	game.end_turn()
	await create_timer(0.4).timeout
	check(game.battle.zones.members("used").size() == 2,"End turn puts all remaining dice into Used")
	await snap("user://systems-end-turn.png")
	await create_timer(3.0).timeout
	game.queue_free()
	await process_frame
	await process_frame
	print("NATIVE SMOKE RESULT: %d failures" % errors)
	quit(1 if errors else 0)
