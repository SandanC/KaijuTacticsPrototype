extends RefCounted
const Rules = preload("res://scripts/rules.gd")
const Content = preload("res://data/content.gd")
const Zones = preload("res://scripts/zones.gd")
enum State { SETUP, PLAYER_ROLL, PLAYER_ACTION, PLAYER_TARGETING, ENEMY_TURN, VICTORY, DEFEAT }
var state := State.SETUP
var rng := RandomNumberGenerator.new()
var seed_value: int
var turn := 0
var rolls := 0
var draw_count: int = Content.DRAW_COUNT
var refills := 0
var scenario: Dictionary
var player: Dictionary
var enemies: Array = []
var cards: Array = []
var dice: Array = []
var zones
var selected: Array = []
var action: Dictionary = {}
var last_path: Array = []
var movement_serial := 0
var history: Array[String] = []
var message := ""
const MOVE = {"id": "move", "name": "Movement", "cost": [], "target": "move"}

func _init(run_seed: int = 0) -> void:
	seed_value = run_seed if run_seed != 0 else int(Time.get_unix_time_from_system() * 1000000)
	rng.seed = seed_value
	zones = Zones.new(dice)
	zones.register_zone("pool")
	zones.register_zone("rolled", {"turn_end": "used", "available": true})
	zones.register_zone("used")
	zones.register_zone("movement", {"symbol": "movement", "turn_end": "used", "available": true})
	scenario = Content.SCENARIO.duplicate(true)
	player = Content.PLAYER.duplicate(true)
	player.max_hp = player.hp
	enemies = [Content.ENEMY.duplicate(true)]
	for card in Content.ABILITIES:
		acquire(card)
	begin_turn()

func acquire(definition: Dictionary) -> void:
	var card := definition.duplicate(true)
	card.key = "%s_%d" % [card.id, cards.size()]
	cards.append(card)
	var die_definition: Dictionary = Content.DICE[card.die]
	dice.append({"id": dice.size(), "definition": card.die, "origin": card.key, "color": die_definition.color, "symbol": "", "spent": true, "zone": "pool"})
	var slots := Rules.requirements(card.cost)
	for i in range(slots.size()):
		var policy: Dictionary = slots[i].duplicate()
		policy.capacity = 1
		policy.available = true
		policy.turn_end = "used"
		zones.register_zone(slot_zone(card, i), policy)

func slot_zone(card: Dictionary, index: int) -> String:
	return "ability/%s/%d" % [card.get("key", card.id), index]

func assigned(card: Dictionary) -> Array:
	if card.target == "move":
		return zones.members("movement")
	var result: Array = []
	for i in range(Rules.requirements(card.cost).size()):
		result.append_array(zones.members(slot_zone(card, i)))
	return result

func note(text: String) -> void:
	message = text
	history.push_front(text)
	if history.size() > 30:
		history.resize(30)

func begin_turn() -> void:
	if state not in [State.SETUP, State.ENEMY_TURN]:
		return
	state = State.PLAYER_ROLL
	turn += 1
	selected.clear()
	action.clear()
	for n in range(draw_count):
		var pool: Array = zones.members("pool")
		if pool.is_empty():
			var used: Array = zones.members("used")
			if used.is_empty():
				break
			for index in used:
				zones.transfer(index, "pool", "refill")
			refills += 1
			pool = zones.members("pool")
		var index: int = pool[rng.randi_range(0, pool.size() - 1)]
		zones.transfer(index, "rolled", "draw")
		var die: Dictionary = dice[index]
		var faces: Array = Content.DICE[die.definition].faces
		die.symbol = faces[rng.randi_range(0, faces.size() - 1)]
		die.spent = false
	rolls += 1
	state = State.PLAYER_ACTION
	note("Turn %d · drew %d dice. Drag into slots; click a map target to confirm." % [turn, zones.members("rolled").size()])

func controllable() -> bool:
	return state in [State.PLAYER_ACTION, State.PLAYER_TARGETING]

func choose_move() -> bool:
	return choose(MOVE)

func choose(ability: Dictionary) -> bool:
	if not controllable():
		return false
	action = ability.duplicate(true)
	selected = assigned(action)
	state = State.PLAYER_TARGETING
	note("%s selected. Drop matching dice into its slots, then confirm a highlighted target." % action.name)
	return true

func draggable(index: int) -> bool:
	if not controllable() or index < 0 or index >= dice.size():
		return false
	var location: String = dice[index].zone
	return location == "rolled" or location == "movement" or location.begins_with("ability/")

func assign_die(index: int, card: Dictionary, slot: int = -1) -> bool:
	if not draggable(index):
		return false
	var destination := "movement"
	if card.target != "move":
		if slot < 0 or slot >= Rules.requirements(card.cost).size():
			return false
		destination = slot_zone(card, slot)
	if not zones.transfer(index, destination):
		return false
	choose(card)
	note("%s · dice assigned, not spent. Confirm on the map or click a die to return it." % card.name)
	return true

func return_die(index: int) -> bool:
	if not draggable(index) or dice[index].zone == "rolled":
		return false
	zones.transfer(index, "rolled", "unassign")
	selected = assigned(action) if not action.is_empty() else []
	return true

func cancel() -> void:
	if state != State.PLAYER_TARGETING:
		return
	for index in assigned(action):
		zones.transfer(index, "rolled", "cancel")
	selected.clear()
	action.clear()
	state = State.PLAYER_ACTION
	note("Canceled · assigned dice returned to the rolled tray.")

func toggle_die(index: int) -> void:
	if action.is_empty() or not draggable(index):
		return
	if dice[index].zone != "rolled":
		return_die(index)
	elif action.target == "move":
		assign_die(index, action)
	else:
		for slot in range(Rules.requirements(action.cost).size()):
			if assign_die(index, action, slot):
				break

func occupied() -> Array:
	var result: Array = []
	for enemy in enemies:
		if enemy.hp > 0:
			result.append(enemy.position)
	return result

func movement_paths(budget: int) -> Dictionary:
	var paths := {player.position: []}
	var pending: Array = [player.position]
	var taken := occupied()
	while not pending.is_empty():
		var current: Vector2i = pending.pop_front()
		var route: Array = paths[current]
		if route.size() >= budget:
			continue
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var tile: Vector2i = current + direction
			if not paths.has(tile) and Rules.legal_move(current, tile, scenario.size, scenario.blocked, taken):
				var next := route.duplicate()
				next.append(tile)
				paths[tile] = next
				pending.append(tile)
	paths.erase(player.position)
	return paths

func targets() -> Array:
	var result: Array = []
	if action.is_empty():
		return result
	if action.target == "move":
		return movement_paths(zones.members("movement").size()).keys()
	if action.target == "self":
		return [player.position] if player.hp < player.max_hp else []
	for enemy in enemies:
		if enemy.hp > 0 and Rules.distance(player.position, enemy.position) <= action.range:
			result.append(enemy.position)
	return result

func resolve(target: Vector2i) -> bool:
	if state != State.PLAYER_TARGETING or target not in targets():
		return false
	var payment := assigned(action)
	if action.target == "move":
		var route: Array = movement_paths(payment.size()).get(target, [])
		if route.is_empty():
			return false
		for i in range(payment.size()):
			zones.transfer(payment[i], "used" if i < route.size() else "rolled", "spend" if i < route.size() else "unused_movement")
			dice[payment[i]].spent = i < route.size()
		last_path = [player.position] + route
		movement_serial += 1
		player.position = target
		note("Moved %d tiles in one action. Spent %d Movement; extra dice returned." % [route.size(), route.size()])
	else:
		if not Rules.valid_payment(action.cost, dice, payment):
			note("Fill every symbol/color slot before activating. Nothing spent.")
			return false
		for index in payment:
			zones.transfer(index, "used", "spend")
			dice[index].spent = true
		if action.target == "self":
			player.hp = mini(player.max_hp, player.hp + action.heal)
		else:
			for enemy in enemies:
				if enemy.hp > 0 and (enemy.position == target or (action.target == "area" and Rules.distance(player.position, enemy.position) <= action.range)):
					enemy.hp = maxi(0, enemy.hp - action.damage)
		note("%s resolved." % action.name)
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
	elif scenario.objective == "defeat_all" and enemies.all(func(unit): return unit.hp <= 0):
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
	zones.apply_event("turn_end")
	for die in dice:
		if die.zone == "used":
			die.spent = true
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
				var blockers := occupied.duplicate()
				blockers.erase(player.position)
				var route := Rules.path_to(enemy.position, player.position, scenario.size, scenario.blocked, blockers)
				if not route.is_empty() and route[0] != player.position:
					enemy.position = route[0]
			note("%s advanced. It cannot attack until its next turn." % enemy.name)
	evaluate()
	if state == State.ENEMY_TURN:
		begin_turn()
