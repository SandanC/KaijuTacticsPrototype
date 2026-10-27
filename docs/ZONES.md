# Dice zones

A die is a stable instance in `battle.dice`. Its `zone` string is its single authoritative location. `zones.members(id)` derives membership; there is no second per-tray inventory that can duplicate a die.

Initial zones:

| ID | Constraints | Turn end |
|---|---|---|
| `pool` | Hidden draw candidates | Remains |
| `rolled` | Available rolled dice | Used |
| `ability/<card instance>/<slot>` | Capacity one, required symbol/optional color | Used |
| `movement` | Any number of Movement dice | Used |
| `used` | Unavailable until refill or a future explicit effect | Remains |

Zone definitions are registered separately from UI panels. Their policies currently support `capacity`, `symbol`, `color`, `available`, and a `turn_end` destination. `zones.transfer(id, destination, reason)` validates the destination before changing anything, updates availability, and emits a `transferred` event with die/source/destination/reason. A bounded event history supports debugging. Raw transfers are an effect/system primitive; player drag authorization stays in `Battle.draggable` and the UI's current-battle/current-turn payload checks.

A future reserve zone can be registered with a capacity and no turn-end destination, keeping its dice across cleanup. A future retrieval effect can transfer a die from Used to Rolled; the destination availability policy makes it usable. Neither operation requires adding tray-specific rules to the turn engine. These are extension examples, not enabled player abilities.

Refill is a battle-level operation, not a zone automatically draining itself: only when the pool runs out while drawing do Used dice move to Pool. Already drawn or reserved dice stay out. Animation observes model locations; it cannot change outcomes or duplicate resources.

## Manual review

1. Watch initial dice roll over the map and move into the bottom open tray.
2. Drag a matching die into a card slot, then back to Rolled. Its exact instance should follow the pointer and remain unspent.
3. Add Movement dice and watch the numeric allowance and reachable tiles expand. Drag one out; both shrink immediately.
4. Allocate two Movement dice and move one tile. Only one should travel to Used; the other returns to Rolled.
5. End the turn with unspent dice in cards/trays. They all enter Used before the enemy phase.
6. Watch the pool count and refill counter on later draws. Used dice remain unavailable until refill.
