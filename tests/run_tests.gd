extends SceneTree
const Rules = preload("res://scripts/rules.gd")
const Battle = preload("res://scripts/battle.gd")
var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)

func die(color: String, symbol: String, spent: bool = false) -> Dictionary:
	return {"color": color, "symbol": symbol, "spent": spent}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var attack: Array = [{"symbol": "attack", "count": 1}]
	check(Rules.valid_payment(attack, [die("blue", "attack")], [0]), "Generic accepts any color")
	check(not Rules.valid_payment([{"symbol": "attack", "color": "green"}], [die("blue", "attack")], [0]), "Colored cost rejects wrong color")
	var overlap: Array = [{"symbol": "attack"}, {"symbol": "attack", "color": "green"}]
	var pool: Array = [die("green", "attack"), die("blue", "attack")]
	check(Rules.allocate(overlap, pool) == [1, 0], "Backtracking reserves green for colored requirement")
	var three: Array = [{"symbol": "attack", "color": "green", "count": 2}, {"symbol": "attack"}]
	check(Rules.allocate(three, [die("green", "attack"), die("green", "attack")]).is_empty(), "Two green dice cannot pay three attacks")
	check(Rules.valid_payment(three, [die("green", "attack"), die("green", "attack"), die("blue", "attack")], [0, 1, 2]), "Three distinct dice pay colored plus generic")
	check(not Rules.valid_payment(overlap, pool, [0, 0]), "Duplicate die rejected")
	check(not Rules.valid_payment(attack, [die("green", "attack", true)], [0]), "Spent die cannot be reused")
	var mixed: Array = [{"symbol": "attack"}, {"symbol": "movement"}]
	check(Rules.valid_payment(mixed, [die("red", "attack"), die("blue", "movement")], [0, 1]), "Mixed symbols accepted")
	check(not Rules.valid_payment(attack, pool, [0, 1]), "Extra payment rejected")
	check(not Rules.legal_move(Vector2i(1, 1), Vector2i(2, 1), 10, [Vector2i(2, 1)], []), "Blocked movement rejected")
	check(not Rules.legal_move(Vector2i(1, 1), Vector2i(2, 1), 10, [], [Vector2i(2, 1)]), "Occupied movement rejected")
	check(not Rules.legal_move(Vector2i.ZERO, Vector2i(-1, 0), 10, [], []), "Board bounds enforced")
	check(not Rules.legal_move(Vector2i.ZERO, Vector2i(1, 1), 10, [], []), "Diagonal movement rejected")
	var b = Battle.new(42)
	check(b.cards.size() == 3 and b.dice.size() == 3, "Every visible starter card contributes exactly one die")
	check(b.zones.members("rolled").size() == 2 and b.zones.members("pool").size() == 1, "Turn draws two dice, leaving one in pool")
	check(b.rolls == 1 and b.turn == 1, "Initial draw rolls once")
	b.begin_turn()
	check(b.rolls == 1 and b.turn == 1, "Cannot redraw or reroll during player phase")
	var pool_die: int = b.zones.members("pool")[0]
	check(not b.draggable(pool_die), "Undrawn dice cannot be assigned")
	b.end_turn()
	check(b.zones.members("used").size() == 2 and b.zones.members("pool").size() == 1, "End turn sends all unspent rolled dice to Used, not pool")
	check(not b.end_turn(), "Enemy phase cannot be queued twice")
	b.advance_enemy()
	check(b.rolls == 2 and b.refills == 1 and b.zones.members("rolled").size() == 2, "Partial draw uses remaining pool then refills from Used")
	check(b.zones.members("pool").size() == 1 and b.zones.members("used").is_empty(), "Refill conserves dice and keeps drawn dice out of Used")
	b.advance_enemy()
	check(b.rolls == 2, "Repeated enemy advance outside phase ignored")
	var oversized = Battle.new(7)
	oversized.draw_count = 8
	oversized.end_turn()
	oversized.advance_enemy()
	check(oversized.zones.members("rolled").size() == 3, "Oversized draw never duplicates or redraws already drawn dice")
	var c = Battle.new(42)
	var d = Battle.new(42)
	check(c.dice == d.dice, "Draw selection and face rolls reproduce by seed")
	# Controlled faces and locations isolate payment/movement rules from randomness.
	var m = Battle.new(9)
	for item in m.dice:
		m.zones.transfer(item.id,"rolled","test_fixture")
		item.symbol = "movement"
		item.spent = false
	for i in range(3):
		check(m.assign_die(i,Battle.MOVE), "Movement accepts die %d" % i)
	check(m.zones.members("movement").size() == 3 and m.targets().has(m.player.position+Vector2i(-3,0)), "Three Movement dice enable a three-tile action")
	m.return_die(2)
	check(m.zones.members("movement").size() == 2 and not m.targets().has(m.player.position+Vector2i(-3,0)), "Removing a die immediately reduces movement allowance")
	m.assign_die(2,Battle.MOVE)
	var origin: Vector2i = m.player.position
	check(m.resolve(origin+Vector2i(-2,0)), "Move two tiles in one action")
	check(m.zones.members("used").size() == 2 and m.zones.members("rolled").size() == 1 and m.zones.members("movement").is_empty(), "Only path-length dice spent; excess movement returned unspent")
	check(m.last_path.size() == 3 and m.player.position == origin+Vector2i(-2,0), "Movement records continuous path for animation")
	check(not m.draggable(0) and not m.draggable(1), "Spent Used dice are unavailable")
	m.assign_die(2,Battle.MOVE)
	m.cancel()
	check(m.dice[2].zone == "rolled" and not m.dice[2].spent and m.selected.is_empty(), "Movement cancellation returns allocation without spending")
	var terrain = Battle.new(15)
	for item in terrain.dice:
		terrain.zones.transfer(item.id,"rolled","test_fixture")
		item.symbol = "movement"
		terrain.assign_die(item.id,Battle.MOVE)
	var occupied_tile: Vector2i = terrain.player.position+Vector2i.RIGHT
	terrain.enemies[0].position = occupied_tile
	check(not terrain.targets().has(occupied_tile), "Movement cannot end on enemy")
	var path: Array = terrain.movement_paths(3).get(occupied_tile+Vector2i.RIGHT,[])
	check(path.is_empty(), "Cannot move through enemy to reach a two-tile destination with budget three")
	var blocked: Vector2i = terrain.player.position+Vector2i.LEFT
	terrain.scenario.blocked.append(blocked)
	check(not terrain.targets().has(blocked), "Movement rejects blocked tile")
	terrain.scenario.blocked.clear()
	var a = Battle.new(11)
	for item in a.dice:
		a.zones.transfer(item.id,"rolled","test_fixture")
		item.spent = false
	a.dice[0].symbol = "attack"
	a.dice[1].symbol = "energy"
	a.dice[2].symbol = "regeneration"
	check(not a.assign_die(1,a.cards[0],0), "Wrong symbol cannot enter payment slot")
	check(a.assign_die(0,a.cards[0],0), "Attack die enters Tail Slash slot")
	check(not a.assign_die(0,a.cards[0],0), "Same die cannot fill slot twice")
	check(a.dice[0].zone == a.slot_zone(a.cards[0],0) and not a.dice[0].spent, "Assignment changes zone but does not spend")
	check(not a.resolve(a.enemies[0].position) and not a.dice[0].spent, "No legal adjacent enemy: ability cannot spend")
	a.assign_die(1,a.cards[1],0)
	check(a.assigned(a.cards[0]) == [0] and a.assigned(a.cards[1]) == [1], "Different cards can retain independent staged payments")
	a.cancel()
	check(a.dice[1].zone == "rolled" and a.dice[0].zone == a.slot_zone(a.cards[0],0), "Cancel returns current action payment, preserving other card")
	a.enemies[0].position = a.player.position+Vector2i.RIGHT
	a.choose(a.cards[0])
	check(a.resolve(a.enemies[0].position) and a.enemies[0].hp == 3 and a.dice[0].zone == "used", "Confirmed attack spends exact slotted die and deals damage")
	a.dice[1].symbol = "attack"
	a.assign_die(1,a.cards[0],0)
	check(a.resolve(a.enemies[0].position) and a.enemies[0].hp == 1, "Blue die pays green card from shared pool")
	a.player.hp = 7
	a.assign_die(2,a.cards[2],0)
	check(a.resolve(a.player.position) and a.player.hp == 8 and a.dice[2].zone == "used", "Self-heal spends Regeneration and caps at max HP")
	a.end_turn()
	check(a.zones.members("used").size() == 3, "All assigned/rolled/spent dice finish in Used")
	# Add custom zones without editing turn logic; explicit lifecycle policies control cleanup.
	var z = Battle.new(21)
	var index: int = z.zones.members("rolled")[0]
	check(z.zones.register_zone("reserve",{"capacity":1}), "Additional zone registers modularly")
	check(z.zones.transfer(index,"reserve","ability_effect"), "Dice can move into a custom zone")
	z.end_turn()
	check(z.dice[index].zone == "reserve", "Custom reserve without turn-end policy is preserved")
	check(not z.zones.register_zone("reserve"), "Duplicate zone rejected")
	check(not z.zones.transfer(index,"missing"), "Unknown destination rejected without losing die")
	check(z.zones.events.any(func(e): return e.to == "reserve" and e.reason == "ability_effect"), "Transfers expose events for future ability hooks")
	var colored = Battle.new(23)
	var colored_card: Dictionary = colored.cards[0].duplicate(true)
	colored_card.id = "colored_test"
	colored_card.cost = [{"symbol":"attack","color":"green"}]
	colored.acquire(colored_card)
	colored_card = colored.cards.back()
	colored.zones.transfer(1,"rolled","test_fixture")
	colored.dice[1].symbol = "attack"
	check(not colored.assign_die(1,colored_card,0), "Colored slot rejects matching symbol in wrong color")
	colored.zones.transfer(0,"rolled","test_fixture")
	colored.dice[0].symbol = "attack"
	check(colored.assign_die(0,colored_card,0), "Colored slot accepts correct color and symbol")
	check(colored.dice.size() == 4 and colored.dice[3].zone == "pool", "Acquisition adds exactly one distinct die to pool, not current turn")
	var staged = Battle.new(41)
	var staged_index: int = staged.zones.members("rolled")[0]
	staged.dice[staged_index].symbol = "attack"
	staged.assign_die(staged_index,staged.cards[0],0)
	staged.end_turn()
	check(staged.dice[staged_index].zone == "used", "Turn end also clears unspent inactive ability slots")
	check(staged.zones.transfer(staged_index,"rolled","test_retrieve") and not staged.dice[staged_index].spent, "Zone policy makes retrieved Used dice available without changing UI logic")
	var combination = Battle.new(51)
	var combo: Dictionary = combination.cards[0].duplicate(true)
	combo.id = "combo_test"
	combo.cost = [{"symbol":"attack","color":"green"},{"symbol":"energy"}]
	combination.acquire(combo)
	combo = combination.cards.back()
	for i in [0,1]: combination.zones.transfer(i,"rolled","test_fixture")
	combination.dice[0].symbol = "attack"
	combination.dice[1].symbol = "energy"
	check(combination.assign_die(0,combo,0) and not combination.assign_die(0,combo,1), "Colored and mixed slots keep one die in exactly one location")
	check(combination.assign_die(1,combo,1) and combination.assigned(combo) == [0,1], "Separate mixed-symbol slots collect a complete payment")
	combination.enemies[0].position = combination.player.position+Vector2i.RIGHT
	check(combination.resolve(combination.enemies[0].position) and combination.zones.members("used").size() == 2, "Mixed-slot confirmation spends both distinct dice exactly once")
	var enemy_path = Battle.new(60)
	enemy_path.player.position = Vector2i(2,2)
	enemy_path.enemies[0].position = Vector2i(5,2)
	enemy_path.scenario.blocked = [Vector2i(4,2)]
	enemy_path.end_turn()
	enemy_path.advance_enemy()
	check(enemy_path.enemies[0].position != Vector2i(5,2) and enemy_path.enemies[0].position != Vector2i(4,2), "Enemy routes around blocked buildings instead of getting stuck")
	var victories := 0
	var losses := 0
	for run_seed in range(1,51):
		var game = Battle.new(run_seed)
		for n in range(100):
			for card in game.cards:
				game.choose(card)
				if game.targets().is_empty():
					continue
				for i in game.zones.members("rolled"):
					if game.assign_die(i,card,0): break
				if not game.targets().is_empty(): game.resolve(game.targets()[0])
				if game.state in [Battle.State.VICTORY,Battle.State.DEFEAT]: break
			if game.state in [Battle.State.VICTORY,Battle.State.DEFEAT]: break
			game.end_turn()
			game.advance_enemy()
		if game.state == Battle.State.VICTORY: victories += 1
		if game.state == Battle.State.DEFEAT: losses += 1
	check(victories+losses == 50 and victories > 0, "50 drawn-pool battles terminate (%d wins / %d losses)" % [victories,losses])
	var loser = Battle.new(8)
	for i in range(30):
		loser.end_turn()
		loser.advance_enemy()
	check(loser.state == Battle.State.DEFEAT and loser.player.hp == 0, "Passing reaches defeat")
	var before: int = loser.rolls
	loser.begin_turn()
	check(loser.rolls == before and not loser.end_turn(), "Terminal states block new draws and turns")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.rolling and scene.pass_button.disabled, "UI begins with on-map roll; actions locked")
	await create_timer(2.1).timeout
	check(not scene.rolling and not scene.roll_surface.visible and not scene.pass_button.disabled, "Settled dice transfer to tray before commands unlock")
	check(scene.board.size.x == 1000 and scene.cards_column.size.x == 364, "Map dominates layout with side cards")
	var rolled_index: int = scene.battle.zones.members("rolled")[0]
	scene.battle.dice[rolled_index].symbol = "movement"
	scene.refresh()
	var payload := {"type":"battle_die","index":rolled_index,"battle":scene.battle.get_instance_id(),"turn":scene.battle.turn}
	check(scene.movement_tray._can_drop_data(Vector2.ZERO,payload), "Movement tray accepts native die payload")
	scene.movement_tray._drop_data(Vector2.ZERO,payload)
	check(scene.movement_label.text.ends_with("1"), "Adding movement die updates visible number")
	scene.rolled_tray._drop_data(Vector2.ZERO,payload)
	check(scene.movement_label.text.ends_with("0") and scene.battle.dice[rolled_index].zone == "rolled", "Dragging die back reduces visible movement number")
	scene.battle.dice[rolled_index].symbol = "attack"
	scene.refresh()
	var slot = scene.card_slots[scene.battle.slot_zone(scene.battle.cards[0],0)]
	check(slot._can_drop_data(Vector2.ZERO,payload), "Individual card slot accepts matching die")
	slot._drop_data(Vector2.ZERO,payload)
	check(not scene.battle.dice[rolled_index].spent and scene.battle.dice[rolled_index].zone.begins_with("ability/"), "Drop stages in real slot zone")
	check(not scene.valid_payload({"type":"battle_die","index":rolled_index,"battle":scene.battle.get_instance_id(),"turn":0}), "Stale-turn drags rejected")
	var picking_ok := true
	for x in range(10):
		for y in range(10):
			var tile := Vector2i(x,y)
			picking_ok = picking_ok and scene.board.screen_tile(scene.board.tile_center(tile)) == tile
	check(picking_ok, "All 100 isometric tile centers pick correctly")
	scene.battle.enemies[0].hp = 0
	scene.battle.evaluate()
	scene.refresh()
	check(scene.overlay.visible and scene.result_title.text == "SECTOR CLEARED", "Victory screen renders")
	scene.restart()
	await create_timer(2.1).timeout
	scene.end_turn()
	scene.restart()
	await create_timer(2.1).timeout
	check(scene.battle.turn == 1 and scene.battle.player.hp == 8 and not scene.rolling, "Restart safely ignores enemy and roll callbacks from previous battle")
	scene.queue_free()
	await process_frame
	print("\nRESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
