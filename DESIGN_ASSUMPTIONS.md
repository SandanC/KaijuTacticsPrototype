# Milestone 1 design assumptions

The user's request permits Godot or GameMaker. This implementation uses **Godot 4.6**, superseding the attached documents' GameMaker-specific directions. The implementation prompt supplies the milestone scope and acceptance criteria; the GDD supplies mechanics and sample content. This is a new independent game in the previously empty repository.

- One open 10×10 board, one-tile footprints, orthogonal movement and Manhattan adjacency. No obstacles are placed in this first encounter. The movement validator already rejects blocked and occupied tiles.
- Basic Move costs exactly one Movement face for exactly one tile, as provisionally specified. No free movement or action points.
- Tail Slash and Roar use the GDD's exact six-face distributions, colors, costs and damage. Dice belong to the shared pool and keep unique instance IDs.
- Cards stay visible. Each use is paid separately and can repeat if distinct matching dice remain. This is a provisional interpretation of the GDD's open repeat-use decision, not a permanent rule.
- Scenario balance placeholders: Mossback 8 HP at (3,5); infantry 5 HP at (7,5), 1 damage, range 1, movement 1. Coordinates are zero-based in data; the board displays A–J and 1–10. These values favor an easy first battle.
- Infantry attacks if adjacent at the start of its phase; otherwise it advances one tile and does not also attack. Stable neighbor order is left, right, up, down, selecting only closer legal tiles. This is sufficient for the open board; obstacle-routing AI belongs to the terrain milestone.
- Roar is confirmed by clicking any highlighted adjacent enemy and hits all adjacent enemies. It cannot be wasted when there are no legal targets.
- Turns end explicitly with End Turn / Space, even if dice are exhausted. This keeps enemy timing under player control and enables inspection of spent dice.
- Defense and Regeneration faces are visible but have no spend action in Milestone 1, following the prompt's placement of defense/healing in Milestone 2. Passing discards unused rolls. No rerolls, mitigation, shields or passives have been added.
- Seeded RNG is isolated in the battle model. New Battle uses a time-derived seed; tests supply fixed seeds. This prototype has no save system or permanent progression.
- No drafting, second encounter, alternate scenario, advanced attack shapes, terrain art, audio or external assets in this slice. The shared-pool acquisition helper is present for initialization, but reward drafting is deliberately deferred.

Future decisions remain open: repeat-use policy, defense duration, movement magnitude, larger footprints, passive/color affinities, destructible terrain and ultimate-card die counts.
