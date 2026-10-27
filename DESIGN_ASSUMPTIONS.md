# Current prototype assumptions

The user's later design decisions supersede the initial implementation prompt's all-dice-every-turn loop and the first prototype's layout. Godot remains the explicitly permitted engine. The approved visual starting point is `design/battle-screen-mockup-03.png`.

## Agreed behavior

- Tactical map is the main view; ability cards are on the side. Standard units occupy one tile; larger bosses are future content.
- Dice are drawn from a pool at turn start, roll visibly onto the screen, then transfer to the bottom Rolled tray. Dice are simulated-3D cubes at the smaller approved scale.
- Trays are continuous shared surfaces, not fixed die sockets. Card payments use individual symbol/color slots.
- Ability ranges are shown on top-down square grids, independently of the map's isometric view.
- Movement accepts any number of Movement dice and displays their total. Dragging dice out reduces it. One confirmed action follows the entire selected route; only the dice needed by the route are spent. Excess movement returns to Rolled.
- Spending moves dice into Used. At turn end, all remaining rolled/card/movement dice also enter Used. Used dice return to the pool when it needs refilling, not automatically at every turn start.
- Zones are modular and transfers emit events for future ability interactions. Reserve/retrieval tests demonstrate extensibility; no new reserve/retrieval gameplay ability is added.

## Provisional tuning for this playable pass

- Draw **two dice** from **three starter cards/dice**. This lets players see a partial-pool draw and refill. Draw count and equipped-card limit remain undecided.
- Tail Slash, Roar and Regenerative Hide use their GDD costs, damage/healing and face distributions. Adding Hide supplies the third die through a visible card, not a free unexplained die. Generic starter costs demonstrate shared dice; colored and mixed slots are supported and tested.
- Pool draws select uniformly without replacement using the battle's seeded RNG. If the pool empties mid-draw, refill from Used and complete the draw. If both are empty, draw fewer dice; never reuse an already drawn die in the same turn.
- Allocations can persist across selecting different cards. Cancel affects the current action; dragging a die back removes just that die. Activation consumes its allocated payment only after a legal target is confirmed.
- Each Movement die is worth one orthogonal tile. All movement dice are equivalent, so the first assigned dice pay the selected route and the rest return. No retained movement allowance or free movement is introduced.
- Mossback has 8 HP, infantry 5 HP/1 damage/range 1/movement 1. Infantry attacks if already adjacent; otherwise it advances without also attacking. Path ties use stable left/right/up/down ordering.
- Four building tiles are impassable. Other surface details are cosmetic. The objective is defeat all enemies, with failure at zero player HP.
- Self-healing requires missing HP and caps at maximum. Cards can be used again if new compatible dice remain. Defense faces are unused in this pass.

## Presentation and scope

Runtime art is functional original placeholder drawing, not the finished pixel art in the concept illustration. The dice are animated simulated 3D, not physical mesh dice. Dice roll results come from the model; cosmetic face cycling, rotation and bounce do not consume gameplay RNG.

No drafting, run map, second encounter, passive system, equipment limit, large boss, sound, external art pack or finished exports are included. These remain future decisions. The current sidebar displays three cards; more cards require scrolling/equipment design. Zones can be extended in the model; new gameplay zones still need deliberate UI and effect design.
