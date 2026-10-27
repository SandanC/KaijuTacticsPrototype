extends RefCounted
## Pure matching and geometry helpers. Every requirement consumes a distinct die.
static func requirements(cost: Array) -> Array:
 var result: Array = []
 for item in cost:
  for n in range(item.get("count", 1)):
   result.append({"symbol": item.symbol, "color": item.get("color", "")})
 return result

static func matches(die: Dictionary, requirement: Dictionary) -> bool:
 return not die.spent and die.symbol == requirement.symbol and (requirement.get("color", "") in ["", null] or die.color == requirement.color)

static func allocate(cost: Array, dice: Array) -> Array:
 return _search(requirements(cost), dice, 0, [])

static func _search(reqs: Array, dice: Array, index: int, used: Array) -> Array:
 if index == reqs.size():
  return used.duplicate()
 for i in range(dice.size()):
  if i not in used and matches(dice[i], reqs[index]):
   var next := used.duplicate()
   next.append(i)
   var answer := _search(reqs, dice, index + 1, next)
   if answer.size() == reqs.size():
    return answer
 return []

static func valid_payment(cost: Array, dice: Array, selected: Array) -> bool:
 if selected.size() != requirements(cost).size():
  return false
 var chosen: Array = []
 var seen: Array = []
 for i in selected:
  if i < 0 or i >= dice.size() or i in seen:
   return false
  seen.append(i)
  chosen.append(dice[i])
 return allocate(cost, chosen).size() == chosen.size()

static func distance(a: Vector2i, b: Vector2i) -> int:
 return absi(a.x - b.x) + absi(a.y - b.y)

static func legal_move(origin: Vector2i, target: Vector2i, size: int, blocked: Array, occupied: Array) -> bool:
 return distance(origin, target) == 1 and target.x >= 0 and target.y >= 0 and target.x < size and target.y < size and target not in blocked and target not in occupied

static func cost_text(cost: Array) -> String:
 var parts := PackedStringArray()
 for req in cost:
  var color: String = req.get("color", "")
  parts.append("%d %s%s" % [req.get("count", 1), (color.capitalize() + " ") if not color.is_empty() else "any-color ", str(req.symbol).capitalize()])
 return " + ".join(parts)
