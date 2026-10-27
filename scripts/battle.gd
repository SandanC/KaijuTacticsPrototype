extends RefCounted
const Rules = preload("res://scripts/rules.gd")
const Content = preload("res://data/content.gd")
enum State { SETUP, PLAYER_ROLL, PLAYER_ACTION, PLAYER_TARGETING, ENEMY_TURN, VICTORY, DEFEAT }
var state := State.SETUP
var rng := RandomNumberGenerator.new()
var seed_value: int
var turn := 0
var rolls := 0
var player: Dictionary
var enemies: Array = []
var cards: Array = []
var dice: Array = []
var selected: Array = []
var action: Dictionary = {}
var history: Array[String] = []
var message := ""

func _init(run_seed: int = 0) -> void:
	seed_value = run_seed if run_seed != 0 else int(Time.get_unix_time_from_system() * 1000000)
	rng.seed = seed_value
	player = Content.PLAYER.duplicate(true)
	player.max_hp = player.hp
	enemies = [Content.ENEMY.duplicate(true)]
	for card in Content.ABILITIES:
		acquire(card)
	begin_turn()

func acquire(card: Dictionary) -> void:
	cards.append(card.duplicate(true))
	var definition: Dictionary = Content.DICE[card.die]
	dice.append({"id": dice.size(), "definition": card.die, "origin": card.id, "color": definition.color, "symbol": "", "spent": false})

func note(text: String) -> void:
	message = text
	history.push_front(text)
	if history.size() > 30:
		history.resize(30)

func begin_turn() -> void:
	if state in [State.VICTORY, State.DEFEAT]:
		return
	state = State.PLAYER_ROLL
	turn += 1
	for die in dice:
		var faces: Array = Content.DICE[die.definition].faces
		die.symbol = faces[rng.randi_range(0, faces.size() - 1)]
		die.spent = false
	rolls += 1
	selected.clear()
	action.clear()
	state = State.PLAYER_ACTION
	note("Turn %d · pool rolled. Choose an action, select payment, then a highlighted tile." % turn)

func choose_move() -> bool:
	return choose({"id": "move", "name": "Move", "cost": [{"symbol": "movement", "count": 1}], "target": "move"})

func choose(ability: Dictionary) -> bool:
	if state not in [State.PLAYER_ACTION, State.PLAYER_TARGETING]:
		return false
	action = ability.duplicate(true)
	selected.clear()
	state = State.PLAYER_TARGETING
	if targets().is_empty():
		note("%s has no legal target. Cancel or choose another action; no dice spent." % action.name)
	elif Rules.allocate(action.cost, dice).is_empty():
		note("No payment available for %s this turn. Cancel or pass." % action.name)
	else:
		note("%s: select exactly %d die, then confirm on a highlighted tile." % [action.name, Rules.requirements(action.cost).size()])
	return true

func cancel() -> void:
	if state == State.PLAYER_TARGETING:
		selected.clear()
		action.clear()
		state = State.PLAYER_ACTION
		note("Action canceled · no dice spent.")

func toggle_die(index: int) -> void:
	if state != State.PLAYER_TARGETING or index < 0 or index >= dice.size() or dice[index].spent:
		return
	if index in selected:
		selected.erase(index)
	else:
		selected.append(index)

func targets() -> Array:
	var result: Array = []
	if action.is_empty():
		return result
	if action.target == "move":
		var occupied: Array = []
		for enemy in enemies:
			if enemy.hp > 0:
				occupied.append(enemy.position)
		for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var tile: Vector2i = player.position + dir
			if Rules.legal_move(player.position, tile, Content.SCENARIO.size, Content.SCENARIO.blocked, occupied):
				result.append(tile)
	else:
		for enemy in enemies:
			if enemy.hp > 0 and Rules.distance(player.position, enemy.position) <= action.range:
				result.append(enemy.position)
	return result

func resolve(target: Vector2i) -> bool:
	if state != State.PLAYER_TARGETING or target not in targets():
		return false
	if not Rules.valid_payment(action.cost, dice, selected):
		note("Payment invalid · select the exact unspent symbols shown in the cost. Nothing spent.")
		return false
	for index in selected:
		dice[index].spent = true
	if action.target == "move":
		player.position = target
		note("Moved one tile · spent 1 Movement.")
	else:
		for enemy in enemies:
			if enemy.hp > 0 and (enemy.position == target or (action.target == "area" and Rules.distance(player.position, enemy.position) <= action.range)):
				enemy.hp = maxi(0, enemy.hp - action.damage)
		note("%s resolved · %d damage." % [action.name, action.damage])
	selected.clear()
	action.clear()
	state = State.PLAYER_ACTION
	evaluate()
	return true

func evaluate() -> void:
	if state in [State.VICTORY, State.DEFEAT]:
		return
	if player.hp <= 0:
		state = State.DEFEAT
		note("Defeat · the military stopped your advance.")
	elif Content.SCENARIO.objective == "defeat_all" and enemies.all(func(unit): return unit.hp <= 0):
		state = State.VICTORY
		note("Victory · all military units defeated!")

func intent(enemy: Dictionary) -> String:
	if enemy.hp <= 0:
		return "Defeated"
	if Rules.distance(enemy.position, player.position) <= enemy.range:
		return "ATTACK · %d damage" % enemy.damage
	return "ADVANCE · %d tile toward you" % enemy.movement

func end_turn() -> bool:
	if state not in [State.PLAYER_ACTION, State.PLAYER_TARGETING]:
		return false
	selected.clear()
	action.clear()
	state = State.ENEMY_TURN
	note("Military turn · executing visible intent.")
	return true

func advance_enemy() -> void:
	if state != State.ENEMY_TURN:
		return
	for enemy in enemies:
		if enemy.hp <= 0:
			continue
		if Rules.distance(enemy.position, player.position) <= enemy.range:
			player.hp = maxi(0, player.hp - enemy.damage)
			note("%s attacked for %d damage." % [enemy.name, enemy.damage])
		else:
			# Stable horizontal-first approach. No attack after advancing this phase.
			for step in range(enemy.movement):
				var occupied: Array = [player.position]
				for other in enemies:
					if other != enemy and other.hp > 0:
						occupied.append(other.position)
				var candidates: Array = []
				for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var tile: Vector2i = enemy.position + dir
					if Rules.legal_move(enemy.position, tile, Content.SCENARIO.size, Content.SCENARIO.blocked, occupied) and Rules.distance(tile, player.position) < Rules.distance(enemy.position, player.position):
						candidates.append(tile)
				if not candidates.is_empty():
					enemy.position = candidates[0]
			note("%s advanced. It cannot attack until its next turn." % enemy.name)
	evaluate()
	if state == State.ENEMY_TURN:
		begin_turn()
