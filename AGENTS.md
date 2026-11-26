This project turns a Latin playscript into a mod in Don't Starve Together (DST).

## Architecture

- `modmain.lua` registers assets, prefabs, and the custom hug action, then attaches `libellusprogress` to each player on the server. `modinfo.lua` contains mod metadata.
- `scripts/libellus.lua` holds dialogue by chapter, including speakers, facing targets, and scene boundaries. Chapters one through four have gameplay triggers; chapter five is an empty continuation point.
- `scripts/helpers.lua` centralizes timing, distances, health settings, spawn-location searches, and inspection-string registration.
- `scripts/components/libellusprogress.lua` owns each player's saved story position, dialogue scheduling, speaker selection, and proximity/entry triggers. It finds or spawns the player's Publius and casa. Recruited Publius saves with the player and travels between shards.
- `scripts/prefabs/` constructs entities. `publius.lua` provides the follower using Wilson's appearance; `casa.lua` builds the house, courtyard, Lupa enclosure, and 3 to 5 soldiers, manages territorial aggression, and restores encounter references after loading. `miles.lua` supplies armed soldiers using WX-78's appearance with 1,000 HP; `lupa.lua` supplies the stationary NPC using fire hound animations.
- `agricola_farm.lua` owns a nine-unit-square farm, its tilled plots, decorative crops, and Agricola. Placement searches connected savanna regions from the player's saved spawn origin. `agricola.lua` uses Woodie's appearance and a straw hat; its brain and stategraph move between crops and animate tending/harvesting without generating inventory items. Chapter-two lines 7–13 lead to chapter three and permanently clear the owned casa's Lupa and soldiers after the final speech finishes.
- `navis.lua` owns saved references to a native wooden boat, steering wheel, lamp-upgraded mast, anchor, and Senex. It spawns in nearby clear ocean and starts anchored; native equipment remains operable and retains player changes on loading. `senex.lua` uses Wolfgang's appearance, a spear, 1,000 HP, and 25 damage. His brain stays aboard the moving boat; his stategraph rechecks boarding before damage. Chapter-three line 1 requires sight and proximity, and lines 2–8 require closer proximity.
- `passer_grove.lua` places Passer's occupied birdcage in nearby forest and owns an isolated 27-unit-square grove of 81 burnt trees behind it, with a 16-unit cleared buffer. Placement protects structures, characters, and other encounters; loading restores references without clearing again. `passer.lua` reuses occupied-cage and robin animations. `passer_burnt_tree.lua` retains native burnt-tree behavior while preventing decay, pinecone drops, and regrowth. Chapter-three lines 9–10 start 15 seconds after line 8 ends (remaining delay saves); ambient line 11 repeats on sight, and nearby lines 12–14 advance to chapter four after the final speech.
- Four hammer hits destroy Passer's cage and replace it with `passer_free.lua`. `passerbrain.lua` flies the bird to the near edge of the grove; `SGpasser.lua` animates takeoff, flight, and landing before chapter-four lines 1–8 can play. Release belongs to the grove's story player even when another player hammers, and the released bird and its flight destination save with the encounter.
- After chapter-four line 8 finishes, Passer flies toward the existing Pig King at the player's effective walking speed. `rexanimalium.lua` extends native Pig Kings without replacing trading, sleep, or minigame behavior; `rex_voice.lua` supplies a replicated child talker. Nearby lines 9–13 lead to chapter five and toss a pan flute and Old Bell to the player; separate saved reward flags prevent duplicate gifts.
- `modinfo.lua` requires Bigfoot Returns (Workshop `2522543318`). Rex gives its `bell` prefab, which supplies Old Bell art, the play action, and an animated Biiigfoot encounter through `TheWorld.components.bigfooter:SummonFoot(position)`. Damage, uses, collateral damage, and warning steps follow the dependency's configuration (its default damage is 2,500). The dependency also adds its normal recipes, Glommer-statue behavior, and Littlefoot pet; enable it on the server and clients.
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
