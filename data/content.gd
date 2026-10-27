extends RefCounted
## Theme and balance data; the rules engine never branches on ability names.
const DICE = {
 "tail": {"color": "green", "faces": ["attack", "attack", "attack", "movement", "movement", "regeneration"]},
 "voice": {"color": "blue", "faces": ["energy", "energy", "defense", "movement", "attack", "regeneration"]}
}
const ABILITIES = [
 {"id": "tail_slash", "name": "Tail Slash", "die": "tail", "cost": [{"symbol": "attack", "count": 1}], "range": 1, "target": "single", "damage": 2, "description": "Deal 2 damage to an adjacent enemy."},
 {"id": "roar", "name": "Roar", "die": "voice", "cost": [{"symbol": "energy", "count": 1}], "range": 1, "target": "area", "damage": 1, "description": "Deal 1 damage to every adjacent enemy."}
]
const PLAYER = {"name": "Mossback", "hp": 8, "position": Vector2i(3, 5)}
const ENEMY = {"name": "Infantry", "hp": 5, "position": Vector2i(7, 5), "range": 1, "movement": 1, "damage": 1}
const SCENARIO = {"size": 10, "blocked": [], "objective": "defeat_all"}
