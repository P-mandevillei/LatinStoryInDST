This project turns a Latin playscript into a mod in Don't Starve Together (DST).

## Architecture

- `modmain.lua` registers assets, prefabs, and the custom hug action, then attaches `libellusprogress` to each player on the server. `modinfo.lua` contains mod metadata.
- `scripts/libellus.lua` holds dialogue by chapter, including speakers, facing targets, and scene boundaries. Chapters one and two and chapter-three lines 1–8 have gameplay triggers; later chapter-three lines are dialogue data only.
- `scripts/helpers.lua` centralizes timing, distances, health settings, spawn-location searches, and inspection-string registration.
- `scripts/components/libellusprogress.lua` owns each player's saved story position, dialogue scheduling, speaker selection, and proximity/entry triggers. It finds or spawns the player's Publius and casa. Recruited Publius saves with the player and travels between shards.
- `scripts/prefabs/` constructs entities. `publius.lua` provides the follower using Wilson's appearance; `casa.lua` builds the house, courtyard, Lupa enclosure, and 3 to 5 soldiers, manages territorial aggression, and restores encounter references after loading. `miles.lua` supplies armed soldiers using WX-78's appearance with 1,000 HP; `lupa.lua` supplies the stationary NPC using fire hound animations.
- `agricola_farm.lua` owns a nine-unit-square farm, its tilled plots, decorative crops, and Agricola. Placement searches connected savanna regions from the player's saved spawn origin. `agricola.lua` uses Woodie's appearance and a straw hat; its brain and stategraph move between crops and animate tending/harvesting without generating inventory items. Chapter-two lines 7–13 lead to chapter three and permanently clear the owned casa's Lupa and soldiers after the final speech finishes.
- `navis.lua` owns saved references to a native wooden boat, steering wheel, lamp-upgraded mast, anchor, and Senex. It spawns in nearby clear ocean and starts anchored; native equipment remains operable and retains player changes on loading. `senex.lua` uses Wolfgang's appearance, a spear, 1,000 HP, and 25 damage. His brain stays aboard the moving boat; his stategraph rechecks boarding before damage. Chapter-three line 1 requires sight and proximity, and lines 2–8 require closer proximity.
- `scripts/brains/` controls following, chasing, and returning to guard positions. `scripts/stategraphs/` controls movement and combat animations; `SGmiles.lua` rechecks the casa boundary before applying attack damage.
- `scripts/prefabs/test.lua`, `scripts/components/huggable.lua`, and `items/hugTest.lua` implement the experimental inventory item and sanity-restoring hug action. Custom assets live in `anim/`, `images/`, and `exported/`; story NPCs reuse game assets.

- `scripts/dialogselector.lua` optionally adds the pause-menu dialogue selector and its RPC. `dialogselection.lua` validates choices; `screens/dialogselectorscreen.lua` supplies the UI. Current progress is mirrored to player network fields by `SetProgress`; selection changes only the sending player's chapter and line.

## Working conventions and tests

Keep story progression in the player component, encounter ownership in the casa prefab, and movement decisions in brains. Create replicated visuals and talkers before `SetPristine()`; add server-only gameplay components after the master-simulation check. Register new prefabs in `modmain.lua`.

Run the mocked Lua tests from the mod root:

```sh
lua tests/libellusprogress_test.lua
lua tests/casa_test.lua
lua tests/dialogselection_test.lua
```

These cover dialogue, spawning, persistence, client/server setup, and guard boundaries. They do not replace in-game checks of visuals, physics, and networking.
