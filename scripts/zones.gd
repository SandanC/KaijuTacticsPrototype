extends RefCounted
## Dice own one location. Zones supply constraints and lifecycle policies, not UI layout.
signal transferred(event: Dictionary)
var definitions: Dictionary = {}
var dice: Array = []
var events: Array = []

func _init(registry: Array) -> void:
	dice = registry

func register_zone(id: String, policy: Dictionary = {}) -> bool:
	if definitions.has(id):
		return false
	definitions[id] = policy.duplicate(true)
	return true

func members(id: String) -> Array:
	var found: Array = []
	for die in dice:
		if die.get("zone", "") == id:
			found.append(die.id)
	return found

func can_transfer(index: int, destination: String) -> bool:
	if index < 0 or index >= dice.size() or not definitions.has(destination):
		return false
	var die: Dictionary = dice[index]
	if die.get("zone", "") == destination:
		return false
	var policy: Dictionary = definitions[destination]
	if policy.get("capacity", -1) >= 0 and members(destination).size() >= policy.capacity:
		return false
	if policy.has("symbol") and die.symbol != policy.symbol:
		return false
	if policy.get("color", "") not in ["", null] and die.color != policy.color:
		return false
	return true

func transfer(index: int, destination: String, reason: String = "assign") -> bool:
	if not can_transfer(index, destination):
		return false
	var source: String = dice[index].get("zone", "")
	dice[index].zone = destination
	dice[index].spent = not definitions[destination].get("available",false)
	var event := {"die": index, "from": source, "to": destination, "reason": reason}
	events.append(event)
	if events.size() > 100:
		events.pop_front()
	transferred.emit(event)
	return true

func apply_event(event_name: String) -> void:
	# Policies can redirect lifecycle transfers for future reserve/exhaust zones.
	for die in dice:
		var destination: String = definitions.get(die.zone, {}).get(event_name, "")
		if not destination.is_empty():
			transfer(die.id, destination, event_name)
