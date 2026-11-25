This project turns a Latin playscript into a mod in Don't Starve Together (DST).

## Architecture

- `modmain.lua` registers assets, prefabs, and the custom hug action, then attaches `libellusprogress` to each player on the server. `modinfo.lua` contains mod metadata.
- `scripts/libellus.lua` holds dialogue by chapter, including speakers, facing targets, and scene boundaries. Chapter one and chapter two's first five lines currently have gameplay triggers; the remaining chapter-two lines are dialogue data only.
- `scripts/helpers.lua` centralizes timing, distances, health settings, spawn-location searches, and inspection-string registration.
- `scripts/components/libellusprogress.lua` owns each player's saved story position, dialogue scheduling, speaker selection, and proximity/entry triggers. It finds or spawns the player's Publius and casa. Recruited Publius saves with the player and travels between shards.
- `scripts/prefabs/` constructs entities. `publius.lua` provides the follower using Wilson's appearance; `casa.lua` builds the house, courtyard, Lupa enclosure, and 3 to 5 soldiers, manages territorial aggression, and restores encounter references after loading. `miles.lua` supplies armed soldiers using WX-78's appearance with 1,000 HP; `lupa.lua` supplies the stationary NPC using fire hound animations.
- `scripts/brains/` controls following, chasing, and returning to guard positions. `scripts/stategraphs/` controls movement and combat animations; `SGmiles.lua` rechecks the casa boundary before applying attack damage.
- `scripts/prefabs/test.lua`, `scripts/components/huggable.lua`, and `items/hugTest.lua` implement the experimental inventory item and sanity-restoring hug action. Custom assets live in `anim/`, `images/`, and `exported/`; story NPCs reuse game assets.

## Working conventions and tests

Keep story progression in the player component, encounter ownership in the casa prefab, and movement decisions in brains. Create replicated visuals and talkers before `SetPristine()`; add server-only gameplay components after the master-simulation check. Register new prefabs in `modmain.lua`.

Run the mocked Lua tests from the mod root:

```sh
lua tests/libellusprogress_test.lua
lua tests/casa_test.lua
```

These cover dialogue, spawning, persistence, client/server setup, and guard boundaries. They do not replace in-game checks of visuals, physics, and networking.
