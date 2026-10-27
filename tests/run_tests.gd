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
 check(b.cards.size() == 2 and b.dice.size() == 2 and b.rolls == 1, "Exactly two starter cards and dice, rolled once")
 check(b.dice[0].id != b.dice[1].id, "Unique die instances")
 b.dice[0].symbol = "movement"
 b.choose_move()
 b.toggle_die(0)
 var old_position: Vector2i = b.player.position
 b.cancel()
 check(not b.dice[0].spent and b.player.position == old_position and b.selected.is_empty(), "Cancel consumes nothing")
 b.choose_move()
 check(not b.resolve(old_position + Vector2i.LEFT), "Movement requires payment")
 b.toggle_die(0)
 check(b.resolve(old_position + Vector2i.LEFT) and b.dice[0].spent, "Movement spends one die for one orthogonal tile")
 b.choose_move()
 b.toggle_die(0)
 check(not b.resolve(b.player.position + Vector2i.LEFT), "Cannot spend same die twice")
 b.cancel()
 b.dice[0].symbol = "attack"
 b.dice[0].spent = false
 b.choose(b.cards[0])
 b.toggle_die(0)
 check(b.targets().is_empty() and not b.resolve(b.enemies[0].position) and not b.dice[0].spent, "Out-of-range attack consumes nothing")
 b.enemies[0].position = b.player.position + Vector2i.RIGHT
 b.dice[1].symbol = "attack"
 b.choose(b.cards[0])
 b.toggle_die(1)
 check(b.resolve(b.enemies[0].position) and b.enemies[0].hp == 3 and b.dice[1].spent, "Other card's die pays Tail Slash, damage resolves")
 b.dice[0].symbol = "energy"
 b.choose(b.cards[1])
 b.toggle_die(0)
 check(b.resolve(b.enemies[0].position) and b.enemies[0].hp == 2, "Roar resolves adjacent area damage")
 var before_rolls: int = b.rolls
 var hp: int = b.player.hp
 b.end_turn()
 check(not b.end_turn(), "Enemy phase cannot be queued twice")
 b.advance_enemy()
 check(b.player.hp == hp - 1 and b.rolls == before_rolls + 1 and b.dice.all(func(d): return not d.spent), "Enemy attacks and next turn resets and rolls exactly once")
 b.advance_enemy()
 check(b.rolls == before_rolls + 1, "Repeated enemy advance outside phase ignored")
 var a = Battle.new(100)
 var c = Battle.new(100)
 check(a.dice == c.dice, "Seeded rolls reproduce")
 var start: Vector2i = a.enemies[0].position
 a.end_turn()
 a.advance_enemy()
 check(a.enemies[0].position == start + Vector2i.LEFT and a.player.hp == 8, "Enemy advances horizontally first without attacking")
 # Real seeded battles; no forced faces. Agent only chooses legal actions through public API.
 var victories := 0
 var losses := 0
 for seed_number in range(1, 51):
  var game = Battle.new(seed_number)
  for turn_number in range(100):
   for card in game.cards:
    game.choose(card)
    var targets: Array = game.targets()
    game.selected = Rules.allocate(card.cost, game.dice)
    if not targets.is_empty() and not game.selected.is_empty():
     game.resolve(targets[0])
    else:
     game.cancel()
    if game.state in [Battle.State.VICTORY, Battle.State.DEFEAT]:
     break
   if game.state in [Battle.State.VICTORY, Battle.State.DEFEAT]:
    break
   game.end_turn()
   game.advance_enemy()
  if game.state == Battle.State.VICTORY:
   victories += 1
  elif game.state == Battle.State.DEFEAT:
   losses += 1
 check(victories > 0 and victories + losses == 50, "50 seeded battles all terminate; wins possible (%d wins, %d losses)" % [victories, losses])
 var loser = Battle.new(17)
 for i in range(30):
  loser.end_turn()
  loser.advance_enemy()
 check(loser.state == Battle.State.DEFEAT and loser.player.hp == 0, "Passing to defeat works")
 var loser_rolls: int = loser.rolls
 loser.evaluate()
 loser.begin_turn()
 check(loser.rolls == loser_rolls and not loser.end_turn(), "Terminal defeat cannot restart phases")
 var winner = Battle.new(1)
 winner.enemies[0].hp = 0
 winner.evaluate()
 var history_size: int = winner.history.size()
 winner.evaluate()
 check(winner.state == Battle.State.VICTORY and winner.history.size() == history_size and not winner.end_turn(), "Victory occurs once and locks actions")
 # Instantiated production UI: exercise the same signals that mouse input uses.
 var scene = load("res://main.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 check(scene.rolling and scene.pass_button.disabled, "Turn starts with animated dice and commands locked")
 var initial_rolls: int = scene.battle.rolls
 scene.end_turn()
 check(scene.battle.rolls == initial_rolls and scene.battle.turn == 1, "Cannot advance turn during rolling")
 await create_timer(1.5).timeout
 check(not scene.rolling and not scene.pass_button.disabled, "Commands unlock after dice settle")
 check(scene.board.size.x >= 662 and scene.cards_column.get_child_count() == 2 and scene.dice_row.get_child_count() == 2, "Production UI instantiates with board, two cards, two dice")
 scene.battle.dice[0].symbol = "movement"
 scene.move_button.pressed.emit()
 scene.dice_row.get_child(0).pressed.emit()
 var destination: Vector2i = scene.battle.player.position + Vector2i.LEFT
 scene.board.tile_clicked.emit(destination)
 check(scene.battle.player.position == destination and scene.battle.dice[0].spent, "UI action/die/board signals perform paid move")
 # Real drop handlers, using the exact native drag payload format.
 scene.battle.cancel()
 scene.battle.dice[0].spent = false
 scene.battle.dice[0].symbol = "attack"
 scene.battle.enemies[0].position = scene.battle.player.position + Vector2i.RIGHT
 scene.refresh()
 var payload := {"type": "battle_die", "index": 0, "battle": scene.battle.get_instance_id()}
 var card_view = scene.cards_column.get_child(0)
 check(card_view._can_drop_data(Vector2.ZERO, payload), "Tail Slash accepts dragged Attack die")
 card_view._drop_data(Vector2.ZERO, payload)
 check(scene.battle.selected == [0] and not scene.battle.dice[0].spent, "Drop stages exact die without spending before target confirmation")
 check(not scene.can_drop_die(scene.battle.cards[0], payload), "Same dragged die cannot be assigned twice")
 scene.battle.cancel()
 check(not scene.battle.dice[0].spent and scene.battle.selected.is_empty(), "Cancel returns dragged payment")
 scene.drop_die(scene.battle.cards[0], payload)
 scene.on_tile(scene.battle.enemies[0].position)
 check(scene.battle.dice[0].spent and scene.battle.enemies[0].hp == 3, "Dragged payment spends only on legal target confirmation")
 check(not scene.can_drop_die(scene.battle.cards[0], payload), "Spent dice rejected by drop handler")
 scene.battle.dice[0].spent = false
 scene.battle.dice[0].symbol = "movement"
 check(not scene.can_drop_die(scene.battle.cards[0], payload), "Wrong symbol rejected by card drop handler")
 check(not scene.can_drop_die(scene.battle.cards[0], {"type": "battle_die", "index": 0, "battle": -1}), "Stale battle drag rejected")
 check(not scene.can_drop_die(scene.battle.cards[0], {"type": "battle_die", "index": "0", "battle": scene.battle.get_instance_id()}), "Malformed drag rejected")
 scene.move_button._drop_data(Vector2.ZERO, payload)
 check(scene.battle.action.get("id", "") == "move" and scene.battle.selected == [0], "Movement die can be dropped on Move command")
 scene.battle.cancel()
 scene.battle.dice[0].symbol = "attack"
 scene.battle.dice[1].symbol = "movement"
 var mixed_card := {"id": "test_mixed", "name": "Test", "cost": [{"symbol": "attack"}, {"symbol": "movement"}], "target": "single", "range": 1, "damage": 1}
 scene.drop_die(mixed_card, payload)
 check(scene.battle.selected == [0], "First drop stages partial multi-die cost")
 scene.drop_die(mixed_card, {"type": "battle_die", "index": 1, "battle": scene.battle.get_instance_id()})
 check(scene.battle.selected == [0,1] and Rules.valid_payment(mixed_card.cost, scene.battle.dice, scene.battle.selected), "Second drop completes mixed-symbol payment")
 scene.battle.cancel()
 var picking_ok := true
 for x in range(10):
  for y in range(10):
   var tile := Vector2i(x,y)
   picking_ok = picking_ok and scene.board.screen_tile(scene.board.tile_center(tile)) == tile
 check(picking_ok, "Isometric picking round-trips all 100 tile centers")
 scene.battle.enemies[0].hp = 0
 scene.battle.evaluate()
 scene.refresh()
 check(scene.overlay.visible and scene.result_title.text == "SECTOR CLEARED", "Victory overlay displayed")
 await process_frame
 await process_frame
 check(Rect2(Vector2.ZERO, scene.size).encloses(scene.overlay.get_global_rect()), "Result panel fits entirely within viewport")
 scene.restart()
 scene.battle.player.hp = 0
 scene.battle.evaluate()
 scene.refresh()
 check(scene.overlay.visible and scene.result_title.text == "KAIJU DOWN", "Defeat overlay displayed")
 scene.restart()
 await create_timer(1.5).timeout
 scene.battle.note("A long record entry to exercise the fixed two-line history and ensure that controls and instructions remain visible.")
 scene.battle.note("Another long entry to exercise the record layout while all production controls remain visible.")
 scene.refresh()
 await process_frame
 await process_frame
 var footer = scene.find_child("HelpFooter", true, false)
 check(footer.get_global_rect().end.y <= scene.size.y and scene.pass_button.get_global_rect().end.y <= scene.size.y, "Help and End Turn fit in viewport with populated history")
 scene.end_turn()
 scene.restart()
 await create_timer(0.8).timeout
 check(scene.battle.turn == 1 and scene.battle.player.hp == 8, "Restart safely ignores pending enemy timer")
 scene.queue_free()
 await process_frame
 print("\nRESULT: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
