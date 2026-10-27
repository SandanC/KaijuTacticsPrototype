extends RefCounted
## Prototype tuning, not locked design decisions.
const DRAW_COUNT = 2
const DICE = {
	"tail": {"color": "green", "faces": ["attack", "attack", "attack", "movement", "movement", "regeneration"]},
	"voice": {"color": "blue", "faces": ["energy", "energy", "defense", "movement", "attack", "regeneration"]},
	"hide": {"color": "blue", "faces": ["regeneration", "regeneration", "defense", "defense", "movement", "energy"]}
}
const ABILITIES = [
	{"id": "tail_slash", "name": "Tail Slash", "die": "tail", "cost": [{"symbol": "attack", "count": 1}], "range": 1, "target": "single", "damage": 2, "description": "2 damage / choose 1 adjacent enemy"},
	{"id": "roar", "name": "Roar", "die": "voice", "cost": [{"symbol": "energy", "count": 1}], "range": 1, "target": "area", "damage": 1, "description": "1 damage / all adjacent enemies"},
	{"id": "hide", "name": "Regenerative Hide", "die": "hide", "cost": [{"symbol": "regeneration", "count": 1}], "range": 0, "target": "self", "heal": 2, "description": "Heal 2 HP / target yourself"}
]
const PLAYER = {"name": "Mossback", "hp": 8, "position": Vector2i(3, 5)}
const ENEMY = {"name": "Infantry", "hp": 5, "position": Vector2i(7, 5), "range": 1, "movement": 1, "damage": 1}
const SCENARIO = {"size": 10, "blocked": [Vector2i(1,2), Vector2i(2,7), Vector2i(7,2), Vector2i(8,7)], "objective": "defeat_all"}
