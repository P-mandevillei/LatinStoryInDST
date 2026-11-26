-- Run from the mod root: lua tests/king_test.lua
LIBELLUS_TEST_HARNESS = true
local H = dofile("tests/casa_test.lua")
LIBELLUS_TEST_HARNESS = nil
local equal, advance = H.equal, H.advance
local HELPERS, DIALOG = require("helpers"), require("libellus")
-- The Python runner supplies DST's real petleash. Keep the suite runnable
-- with plain Lua when the optional native source loader is unavailable.
if package.preload["components/gamepetleash"] == nil then
  package.preload["components/gamepetleash"] = function()
    local Leash = Class(function(self, inst)
      self.inst, self.pets, self.maxpets, self.limits = inst, {}, 1, {}
    end)
    function Leash:GetPets() return self.pets end
    function Leash:GetMaxPets() return self.maxpets end
    function Leash:SetMaxPetsForPrefab(prefab, limit) self.limits[prefab] = limit end
    function Leash:GetNumPetsForPrefab(prefab)
      local count = 0
      for pet in pairs(self.pets) do if pet.prefab == prefab then count = count+1 end end
      return count
    end
    function Leash:Link(pet)
      self.pets[pet], pet.persists = pet, false
      self.inst.components.leader:AddFollower(pet)
      return pet
    end
    function Leash:SpawnPetAt(x, y, z, prefab)
      if self.limits[prefab] ~= nil and self:GetNumPetsForPrefab(prefab) >= self.limits[prefab] then return end
      local pet = SpawnPrefab(prefab)
      pet.Transform:SetPosition(x, y, z)
      return self:Link(pet)
    end
    function Leash:OnSave()
      local data = {pets = {}}
      for pet in pairs(self.pets) do table.insert(data.pets, pet:GetSaveRecord()) end
      return data
    end
    function Leash:OnLoad(data)
      for _, record in ipairs(data.pets or {}) do
        local pet = self:Link(SpawnSaveRecord(record))
        if self.inst.migrationpets ~= nil then table.insert(self.inst.migrationpets, pet) end
      end
    end
    function Leash:OnRemoveEntity() for pet in pairs(self.pets) do pet:Remove() end end
    return Leash
  end
end
local Progress = require("components/libellusprogress")
local Scene = require("kingscene")
package.loaded["brains/kingcourtbrain"] = {name = "court"}
package.loaded["brains/celebrationpigbrain"] = {name = "celebration"}
package.loaded["brains/pigbrain"] = {name = "pig"}
package.loaded["brains/pigguardbrain"] = {name = "pigguard"}
for _, name in ipairs({"dragonfly", "deerclops", "bearger", "beequeen"}) do
  package.loaded["brains/"..name.."brain"] = {name = name}
end
EQUIPSLOTS.HEAD, EQUIPSLOTS.BODY = "head", "body"
WORLD_TILES.COTL_GOLD, WORLD_TILES.CARPET2 = 8, 9
local function noop() end
local function Entity()
  local inst = H.Entity()
  function inst:IsAsleep() return self.asleep == true end
  inst.PushEventImmediate = inst.PushEvent
  inst.MiniMapEntity.SetPriority, inst.MiniMapEntity.SetDrawOverFogOfWar = noop, noop
  inst.Light = {SetRadius = noop, SetIntensity = noop, SetFalloff = noop, SetColour = noop, Enable = noop}
  inst.AnimState.Pause = function() inst.paused = true end
  inst.AnimState.Resume = function() inst.paused = false end
  inst.sg.sg = {states = {idle = {}}}
  local hastag = inst.sg.HasStateTag
  function inst.sg:HasStateTag(tag)
    return (self.state == "sleep" and tag == "sleeping") or hastag(self, tag)
  end
  local add = inst.AddComponent
  function inst:SetBrain(brain) self.brain, self.brainfn = brain, brain end
  function inst:AddComponent(name)
    if name == "kingguard" or name == "libelluscastlesleep" or name == "libelluscelebration"
      or name == "libelluspigcelebrant" then
      self.components[name] = require("components/"..name)(self)
      return self.components[name]
    elseif name == "petleash" then
      self.components[name] = require("components/gamepetleash")(self)
      return self.components[name]
    elseif name == "amphibiouscreature" and package.preload["components/gameamphibiouscreature"] ~= nil then
      self.components[name] = require("components/gameamphibiouscreature")(self)
      return self.components[name]
    end
    local c = add(self, name)
    if name == "combat" then
      function c:SetRetargetFunction(period, fn) self.retarget, self.targetfn = fn, fn end
    elseif name == "amphibiouscreature" then
      function c:SetBanks(land, water) self.land_bank, self.ocean_bank = land, water end
      function c:SetEnterWaterFn(fn) self.enterwaterfn = fn end
      function c:SetExitWaterFn(fn) self.exitwaterfn = fn end
    elseif name == "follower" then
      function c:GetLeader() return self.leader end
      c.KeepLeaderOnAttacked = noop
    elseif name == "leader" then
      function c:AddFollower(pet) pet.components.follower:SetLeader(inst) end
    elseif name == "maprevealable" then
      c.SetIconPrefab, c.SetIcon, c.SetIconPriority, c.SetOnIconCreatedFn = noop, noop, noop, noop
      function c:AddRevealSource(source) self.source = source end
    elseif name == "trader" then
      function c:SetAcceptTest(fn) self.test = fn end
      function c:SetOnAccept(fn) self.onaccept = fn end
    elseif name == "inventory" then
      c.equipment = {}
      function c:GetEquippedItem(slot) return self.equipment[slot] end
      function c:Equip(item)
        local slot = item.prefab == "ruinshat" and EQUIPSLOTS.HEAD
          or (item.prefab == "armorruins" and EQUIPSLOTS.BODY or EQUIPSLOTS.HANDS)
        self.equipment[slot] = item
      end
    elseif name == "health" then
      local delta = c.DoDelta
      function c:DoDelta(value, ...)
        local result = delta(self, value, ...)
        if self:IsDead() then inst:PushEvent("death") end
        return result
      end
    end
    return c
  end
  return inst
end
CreateEntity = Entity
local lp, royal_lupa = dofile("scripts/prefabs/lupa.lua")
H.factories.king_lupa = royal_lupa.fn
H.factories.rex = require("prefabs/rex").fn
H.factories.king_castle = require("prefabs/king_castle").fn
H.factories.king_scene_light = require("prefabs/king_scene_light").fn
H.factories.pigking = function()
  local inst = Entity()
  inst.sg.mem = {}
  function inst:IsMinigameActive() return false end
  require("rexanimalium").Setup(inst)
  return inst
end
Prefabs.critter_puppy = {fn = function()
  local inst = Entity()
  inst.AnimState:SetBank("pupington")
  inst.AnimState:SetBuild("pupington_build")
  inst:AddTag("critter")
  inst:AddTag("companion")
  inst:AddComponent("follower")
  inst:AddComponent("locomotor")
  inst:SetStateGraph("SGcritter_puppy")
  return inst
end}
local puppy, puppyvoice = dofile("scripts/prefabs/publilius.lua")
H.factories.publilius, H.factories.publilius_voice = puppy.fn, puppyvoice.fn
for _, name in ipairs({"dragonfly", "deerclops", "bearger", "beequeen"}) do
  Prefabs[name] = {fn = function()
    local inst = Entity()
    inst.nativeboss = name
    inst:AddComponent("health"):SetMaxHealth(10000)
    inst:AddComponent("combat")
    inst.components.combat.targetfn = function() inst.native_target_updates = (inst.native_target_updates or 0)+1 end
    inst:AddComponent("locomotor")
    inst:AddComponent("sleeper")
    inst:AddComponent("knownlocations").RememberLocation = noop
    inst.OnLoad = noop
    if name == "dragonfly" then
      inst.OnEntitySleep = function(inst) inst.sleeptask = inst:DoTaskInTime(10, inst.Remove) end
    elseif name == "deerclops" then
      inst.worldstatewatching = {stopwinter = {function() inst:Remove() end}}
      inst.StopWatchingWorldState = function(self, var) self.worldstatewatching[var] = nil end
    elseif name == "beequeen" then
      inst.OnEntitySleep = function(inst) inst._sleeptask = inst:DoTaskInTime(10, inst.Remove) end
    end
    inst.entity:SetPristine()
    return inst
  end}
end
local dragon, deer, bear, queen = dofile("scripts/prefabs/king_court.lua")
for _, prefab in ipairs({dragon, deer, bear, queen}) do H.factories[prefab.name] = prefab.fn end

local clockdata, tiles
local function reset()
  H.reset()
  tiles = {}
  clockdata = {phase = "dusk", cycles = 7, mooomphasecycle = 3,
    segs = {day = 10, dusk = 4, night = 2}, totaltimeinphase = 120, remainingtimeinphase = 73}
  TheNet.IsDedicated = function() return true end
  TheWorld.components = {clock = {OnSave = function() return clockdata end, OnUpdate = noop,
    OnLoad = function(_, data) clockdata = data end}}
  TheWorld.net = {components = {clock = TheWorld.components.clock},
    StopUpdatingComponent = function(self) self.clockheld = true end,
    StartUpdatingComponent = function(self) self.clockheld = false end}
  function TheWorld:PushEvent(event, data)
    local copy = {}
    for k, v in pairs(clockdata) do copy[k] = v end
    clockdata = copy
    if event == "ms_setclocksegs" then clockdata.segs = data end
    if event == "ms_setphase" then clockdata.phase = data end
  end
  TheWorld.components.bigfooter = {numWarnings = 3, calls = 0, SummonFoot = function(self, point)
    self.calls, self.targetPos = self.calls+1, point
  end, CheckForWater = function() return "legacy_water_result" end}
  function TheWorld.Map:GetNodeIdAtPoint() return 1 end
  TheWorld.topology = {nodes = {{tags = {"lunacyarea"}}}, ids = {"MoonIsland_Test"}}
  function TheWorld.Map:GetSize() return 1, 1 end
  function TheWorld.Map:GetTileCenterPoint() return 0, 0, 0 end
  function TheWorld.Map:SetTile(x, z, tile) tiles[x..":"..z] = tile end
end
local count = 0
local function test(name, fn)
  reset()
  fn()
  count = count+1
  print("PASS "..name)
end
local function Player(userid)
  local inst = Entity()
  inst.userid = userid or "octavia"
  inst:AddTag("player")
  inst:AddComponent("talker")
  inst:AddComponent("health"):SetMaxHealth(150)
  inst:AddComponent("combat")
  inst:AddComponent("locomotor")
  inst:AddComponent("leader")
  inst:AddComponent("petleash")
  inst:ListenForEvent("emote", function(_, data) inst.last_emote = data end)
  inst.components.libellusprogress = Progress(inst)
  table.insert(AllPlayers, inst)
  return inst, inst.components.libellusprogress
end
local toast = {anim = {"emote_pre_toast", "emote_loop_toast"}, mounted = true, loop = true}
function GetCommonEmotes() return {toast = {data = toast}} end
local function Encounter()
  local player, progress = Player()
  -- Keep the rest of the story's encounters outside this focused world.
  progress.EnsureCasa, progress.EnsureFarm, progress.EnsureNavis, progress.EnsurePasser = noop, noop, noop, noop
  player.position = Vector3(1000, 0, 1000)
  local castle = progress:EnsureCastle()
  player.position = Vector3(0, 0, 0)
  local publius = Entity()
  publius.prefab = "publius"
  publius:AddTag("character")
  publius:AddComponent("talker")
  publius:AddComponent("follower")
  publius:AddComponent("locomotor")
  publius.sg.sg.states.sleep = {}
  progress._publius = publius
  advance(0)
  return player, progress, castle
end
local function GiftBell(player, castle)
  local bell = Entity()
  bell.prefab = "bell"
  bell:AddComponent("instrument"):SetOnPlayedFn(function(_, musician)
    TheWorld.components.bigfooter:SummonFoot(musician:GetPosition())
  end)
  bell:AddComponent("finiteuses").Use = function(self) self.used = (self.used or 0)+1 end
  local trader = castle._king.components.trader
  if trader.test(castle._king, bell, player) then trader.onaccept(castle._king, player, bell); return bell end
end
local function CountPrefab(name)
  local count = 0
  for _, ent in pairs(Ents) do if ent:IsValid() and ent.prefab == name then count = count+1 end end
  return count
end

test("random lunar placement rejects mainland, ocean, bases, and creatures", function()
  local point = Vector3(0, 0, 0)
  assert(HELPERS.CanPrepareCastleSite(point))
  TheWorld.topology = {nodes = {{tags = {}}}, ids = {"MainlandMeteor"}}
  equal(HELPERS.FindCastleSpawnPoint(), nil)
  TheWorld.topology.nodes[1].tags = {"lunacyarea"}
  local passable = TheWorld.Map.IsPassableAtPoint
  TheWorld.Map.IsPassableAtPoint = function(_, x) return x < 8 end
  equal(HELPERS.CanPrepareCastleSite(point), false)
  TheWorld.Map.IsPassableAtPoint = passable
  local base = Entity(); base:AddTag("structure")
  equal(HELPERS.CanPrepareCastleSite(point), false)
  base:Remove()
  local animal = Entity(); animal:AddComponent("health"):SetMaxHealth(50)
  equal(HELPERS.CanPrepareCastleSite(point), false)
  animal:Remove()
  assert(HELPERS.FindCastleSpawnPoint() ~= nil)
end)

test("castle is shared, has the requested court health, equipment, turf, and map marker", function()
  local _, _, castle = Encounter()
  local _, other = Player("other")
  equal(other:EnsureCastle(), castle)
  equal(CountPrefab("king_castle"), 1)
  equal(#castle._guards, 4)
  equal(castle._king.components.health.maxhealth, 1000)
  equal(castle._king.AnimState.build, "waxwell")
  equal(castle._king.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD).prefab, "ruinshat")
  equal(castle._lupa.components.health.maxhealth, 2000)
  for _, guard in ipairs(castle._guards) do
    equal(guard.components.health.maxhealth, 2000)
    equal(guard.displaynamefn(), "Animus Magnus")
    assert(guard.nativeboss ~= nil)
    assert(guard.components.kingguard:GetDestination() ~= nil)
  end
  equal(tiles["0:0"], WORLD_TILES.COTL_GOLD)
  equal(tiles["2:2"], WORLD_TILES.CARPET2)
  equal(castle.components.maprevealable.source, "king_castle")
  for _, wall in ipairs(castle._walls) do
    assert(math.abs(wall.position.x)+.5 <= 9 and math.abs(wall.position.z)+.5 <= 9)
  end
end)

test("sight gates each conversation, night sleeps everyone else, then restores exact time", function()
  local player, progress, castle = Encounter()
  local other = Player("other")
  other:AddComponent("sleeper")
  local animal = Entity()
  animal:AddComponent("health"):SetMaxHealth(100)
  animal:AddComponent("combat")
  animal:AddComponent("locomotor")
  animal:AddComponent("sleeper")
  castle.visible = false
  progress:SetProgress("ch5", DIALOG.CH5_SEP[3])
  progress:DialogLoop(player)
  advance(3)
  equal(#H.speeches(), 0)
  equal(progress.chapter, "ch5")
  equal(progress.dialog, DIALOG.CH5_SEP[3])
  castle.visible = true
  castle._lupa.visible = false
  advance(12)
  equal(progress.dialog, 3)
  equal(clockdata.phase, "night")
  equal(TheWorld.net.clockheld, true)
  assert(other.components.sleeper:IsAsleep())
  assert(animal.components.sleeper:IsAsleep())
  assert(castle._king.components.sleeper:IsAsleep())
  equal(progress._publius.sg.state, "sleep")
  equal(castle._lupa.components.sleeper:IsAsleep(), false)
  equal(player.components.libelluscastlesleep, nil)
  equal(#castle._lights, 2)
  equal(castle._lights[1].parent, player)
  equal(castle._lights[2].parent, castle._lupa)
  castle._lupa.visible = true
  castle._king.visible = false
  advance(23)
  equal(progress.dialog, 7)
  equal(clockdata.phase, "dusk")
  equal(TheWorld.net.clockheld, false)
  equal(clockdata.remainingtimeinphase, 73)
  equal(clockdata.cycles, 7)
  equal(other.components.sleeper:IsAsleep(), false)
  equal(animal.components.sleeper:IsAsleep(), false)
  equal(progress._publius.sg.state, "idle")
  equal(#castle._lights, 0)
  equal(#H.speeches(), 6)
  castle._king.visible = true
  advance(30)
  equal(progress.dialog, 12)
  assert(progress:IsKingTradeReady(castle))
  for i = 1, 11 do equal(H.speeches()[i].content, DIALOG.ch6[i].content) end
end)

test("no trading before the final royal speech finishes; ordinary gifts do not betray", function()
  local player, progress, castle = Encounter()
  local item = Entity(); item.prefab = "goldnugget"
  local trader = castle._king.components.trader
  progress:SetProgress("ch6", 11)
  equal(trader.test(castle._king, item, player), false)
  progress:DialogLoop(player)
  advance(4)
  equal(progress.dialog, 12)
  equal(trader.test(castle._king, item, player), false)
  advance(3)
  assert(trader.test(castle._king, item, player))
  trader.onaccept(castle._king, player, item)
  equal(castle._betrayed, nil)
  equal(progress.dialog, 12)
end)

test("bell says twelve immediately, frees Lupa, gathers the court, then enables native boss combat", function()
  local player, progress, castle = Encounter()
  progress:SetProgress("ch6", 12)
  progress:DialogLoop(player)
  local bell = assert(GiftBell(player, castle))
  equal(H.speeches()[1].content, DIALOG.ch6[12].content)
  equal(castle._king.sg.state, "ring")
  equal(TheWorld.components.bigfooter.calls, 1)
  equal(TheWorld.components.bigfooter:CheckForWater(castle._king:GetPosition()), nil)
  equal(TheWorld.components.bigfooter:CheckForWater(Vector3(50, 0, 50)), "legacy_water_result")
  equal(bell.components.finiteuses.used, 1)
  assert(castle._lupa.components.kingguard.escaping)
  assert(castle._lupa:HasTag("groundpound_immune"))
  local escape = castle._lupa.components.kingguard:GetDestination()
  assert((escape.x-castle._king.position.x)^2+(escape.z-castle._king.position.z)^2 > 20^2)
  for _, guard in ipairs(castle._guards) do
    equal(guard.brain, package.loaded["brains/kingcourtbrain"])
    equal(guard.components.combat.target, nil)
    local destination = guard.components.kingguard:GetDestination()
    assert(guard:GetDistanceSqToPoint(destination) > HELPERS.KING_COURT_ARRIVAL_DISTANCE^2)
    assert(castle._king:GetDistanceSqToPoint(destination) <= HELPERS.KING_COURT_GATHER_RADIUS^2+.001)
    guard.position = destination
    equal(guard.components.combat:CanTarget(castle._king), false)
    equal(guard.components.combat:CanTarget(castle._lupa), false)
  end
  advance(.1)
  advance(HELPERS.KING_COURT_HOLD_TIME-.2)
  for _, guard in ipairs(castle._guards) do equal(guard.components.combat.target, nil) end
  advance(.3)
  for _, guard in ipairs(castle._guards) do
    equal(guard.brain, package.loaded["brains/"..guard.nativeboss.."brain"])
    equal(guard.components.combat.target, player)
    guard.components.combat.targetfn(guard)
    equal(guard.native_target_updates, 1)
  end
  equal(GiftBell(player, castle), nil)
  advance(10)
  equal(progress.dialog, 13)
  equal(#H.speeches(), 1)
  local foot = Entity()
  foot.Stomp = function() foot.stomped = true end
  Scene.SetupFoot(foot)
  foot.Transform:SetPosition(castle._king.position:Get())
  foot:Stomp()
  assert(foot.stomped and castle._king_dead)
  equal(TheWorld.components.bigfooter:CheckForWater(castle._king:GetPosition()), "legacy_water_result")
  advance(3)
  equal(H.speeches()[2].speaker, castle._lupa)
  equal(H.speeches()[2].content, DIALOG.ch6[13].content)
  equal(progress.dialog, 13)
  advance(6)
  equal(progress.chapter, "ch6")
  equal(progress.dialog, 14)
end)

test("save/load restores encounter references without rebuilding, and resumes a pending stomp once", function()
  local player, progress, castle = Encounter()
  progress:SetProgress("ch6", 12)
  assert(GiftBell(player, castle))
  local data, refs = {}, {}
  castle.OnSave(castle, data)
  for guid, ent in pairs(Ents) do refs[guid] = {entity = ent} end
  local before = CountPrefab("wall_stone")
  local loaded = SpawnPrefab("king_castle")
  loaded.OnLoad(loaded, data)
  loaded.OnLoadPostPass(loaded, refs, data)
  advance(1)
  equal(loaded._king, castle._king)
  equal(loaded._lupa, castle._lupa)
  equal(#loaded._guards, 4)
  equal(CountPrefab("wall_stone"), before)
  equal(TheWorld.components.bigfooter.calls, 2)
  equal(castle._king._castle, loaded)
  local guard = loaded._guards[1].components.kingguard
  local saved = guard:OnSave()
  local restored = SpawnPrefab("animus_dragonfly")
  restored.components.kingguard:OnLoad(saved)
  advance(1)
  equal(restored.components.combat.target, nil)
  equal(restored.components.kingguard.gathering, true)
  equal(restored.components.kingguard:GetDestination().x, guard:GetDestination().x)
  equal(restored.components.kingguard:GetDestination().z, guard:GetDestination().z)
end)

test("castle sighting waits for chapter five's final line and requires sight and range", function()
  local player, progress, castle = Encounter()
  progress:SetProgress("ch5", DIALOG.CH5_SEP[2])
  progress:DialogLoop(player)
  advance(3)
  equal(progress.chapter, "ch5")
  equal(progress.dialog, DIALOG.CH5_SEP[2])
  progress:SetProgress("ch5", DIALOG.CH5_SEP[3])
  player.position = Vector3(HELPERS.CASTLE_SEE_DISTANCE+1, 0, 0)
  progress:DialogLoop(player)
  advance(3)
  equal(progress.chapter, "ch5")
  equal(#H.speeches(), 0)
  player.position = castle:GetPosition()
  advance(2)
  equal(progress.chapter, "ch6")
  equal(H.speeches()[1].content, DIALOG.ch6[1].content)
end)

test("court waits for every survivor, resets its pause if displaced, and skips dead guards", function()
  local player, progress, castle = Encounter()
  progress:SetProgress("ch6", DIALOG.CH6_SEP[4])
  assert(GiftBell(player, castle))
  for i = 1, #castle._guards-1 do
    local guard = castle._guards[i]
    guard.position = guard.components.kingguard:GetDestination()
  end
  advance(HELPERS.KING_COURT_HOLD_TIME+1)
  equal(castle._court_hold_until, nil)
  for _, guard in ipairs(castle._guards) do equal(guard.components.combat.target, nil) end
  local last = castle._guards[#castle._guards]
  last.components.health:DoDelta(-last.components.health.maxhealth)
  advance(2)
  assert(castle._court_hold_until ~= nil)
  local displaced = castle._guards[1]
  displaced.position = Vector3(8, 0, 8)
  advance(.2)
  equal(castle._court_hold_until, nil)
  displaced.position = displaced.components.kingguard:GetDestination()
  advance(HELPERS.KING_COURT_HOLD_TIME-.1)
  equal(displaced.components.combat.target, nil)
  advance(.3)
  equal(displaced.components.combat.target, player)
  equal(last.components.kingguard.hostile, false)
end)

test("a saved court pause resumes its remaining duration before attacking", function()
  local player, progress, castle = Encounter()
  progress:SetProgress("ch6", DIALOG.CH6_SEP[4])
  assert(GiftBell(player, castle))
  for _, guard in ipairs(castle._guards) do guard.position = guard.components.kingguard:GetDestination() end
  advance(2.1)
  local data, refs = {}, {}
  castle:OnSave(data)
  assert(math.abs(data.court_hold_remaining-2) < .001)
  for guid, ent in pairs(Ents) do refs[guid] = {entity = ent} end
  castle:Remove()
  advance(100)
  local loaded = SpawnPrefab("king_castle")
  loaded:OnLoad(data)
  loaded:OnLoadPostPass(refs, data)
  advance(1.8)
  for _, guard in ipairs(loaded._guards) do equal(guard.components.combat.target, nil) end
  advance(.4)
  for _, guard in ipairs(loaded._guards) do equal(guard.components.combat.target, player) end
end)

test("Animi gathered beside Rex can die in the stomp before their attack pause ends", function()
  local player, progress, castle = Encounter()
  progress:SetProgress("ch6", DIALOG.CH6_SEP[4])
  progress:DialogLoop(player)
  assert(GiftBell(player, castle))
  for _, guard in ipairs(castle._guards) do guard.position = guard.components.kingguard:GetDestination() end
  advance(.2)
  local foot = Entity()
  foot.position = castle._king:GetPosition()
  foot.Stomp = function(inst)
    for _, guard in ipairs(castle._guards) do
      if inst:IsNear(guard, HELPERS.KING_COURT_GATHER_RADIUS+HELPERS.KING_COURT_ARRIVAL_DISTANCE) then
        guard.components.health:DoDelta(-guard.components.health.maxhealth)
      end
    end
  end
  Scene.SetupFoot(foot)
  foot:Stomp()
  assert(castle._king_dead)
  advance(12)
  for _, guard in ipairs(castle._guards) do
    assert(guard.components.health:IsDead())
    equal(guard.components.combat.target, nil)
    equal(guard.components.kingguard.hostile, false)
  end
  equal(progress.dialog, DIALOG.CH6_SEP[5]+1)
end)

test("night interruption, disconnect, and saved pending speech restore time and sleeping state", function()
  local player, progress, castle = Encounter()
  local animal = Entity()
  animal:AddComponent("health"):SetMaxHealth(100)
  animal:AddComponent("combat")
  animal:AddComponent("locomotor")
  animal:AddComponent("sleeper")
  animal.components.sleeper:GoToSleep(50)
  progress:SetProgress("ch6", 3)
  progress:DialogLoop(player)
  equal(clockdata.phase, "night")
  progress:SetProgress("ch5", 12)
  equal(clockdata.phase, "dusk")
  assert(animal.components.sleeper:IsAsleep())
  progress:SetProgress("ch6", 6)
  progress:DialogLoop(player)
  advance(2)
  local saved = progress:OnSave()
  equal(saved.ch6_pending.line, 6)
  equal(saved.ch6_pending.remaining, 3)
  progress:OnRemoveEntity()
  equal(clockdata.phase, "dusk")
  local resumed = Progress(player)
  resumed._castle = castle
  resumed:OnLoad(saved)
  equal(resumed._ch6_pending.line, 6)
  advance(3)
  resumed:UpdateChapterSixScene()
  equal(clockdata.phase, "dusk")
  equal(resumed._ch6_pending, nil)
end)

test("clients construct speech and lights before pristine and receive no gameplay components", function()
  TheWorld.ismastersim = false
  local king = H.factories.rex()
  assert(king.pristine)
  assert(king.components.talker ~= nil)
  equal(king.components.health, nil)
  local lupa = H.factories.king_lupa()
  assert(lupa.components.talker ~= nil)
  equal(lupa.components.kingguard, nil)
  local castle = H.factories.king_castle()
  equal(castle.components.maprevealable, nil)
  equal(castle.ReceiveBell, nil)
end)
test("other players stay knocked out until the conversation ends and regain their prior grogginess", function()
  local player, progress, castle = Encounter()
  local other = Player("other")
  other.components.grogginess = {grog_amount = .3, cometotestfn = function() return true end,
    IsKnockedOut = function(self) return self.out == true end,
    KnockOut = function(self) self.out = true end,
    ComeTo = function(self) self.out = false; self.grog_amount = 1 end}
  local original_test = other.components.grogginess.cometotestfn
  progress:SetProgress("ch6", 3)
  progress:DialogLoop(player)
  assert(other.components.grogginess:IsKnockedOut())
  equal(other.components.grogginess.cometotestfn(other), false)
  progress:SetProgress("ch6", 8)
  equal(other.components.grogginess:IsKnockedOut(), false)
  equal(other.components.grogginess.grog_amount, .3)
  equal(other.components.grogginess.cometotestfn, original_test)
  equal(clockdata.phase, "dusk")
end)
test("a global night lease excludes simultaneous conversations and releases when its owner dies", function()
  local player, progress, castle = Encounter()
  local other = Player("other")
  progress:SetProgress("ch6", 3)
  progress:DialogLoop(player)
  equal(castle:BeginNight(other), false)
  player:AddTag("playerghost")
  advance(1)
  equal(clockdata.phase, "dusk")
  equal(TheWorld.net.clockheld, false)
  equal(#castle._lights, 0)
end)
test("castle giants remain after native offscreen and winter cleanup", function()
  local _, _, castle = Encounter()
  local dragon, deer, queen = castle._guards[1], castle._guards[2], castle._guards[4]
  equal(deer:WantsToLeave(), false)
  equal(deer.worldstatewatching.stopwinter, nil)
  queen.OnEntitySleep(queen)
  dragon.OnEntitySleep(dragon)
  advance(15)
  assert(queen:IsValid())
  equal(queen._sleeptask, nil)
  assert(dragon:IsValid())
  equal(dragon.sleeptask, nil)
end)
local function Pig(name, x, z)
  local pig = Entity()
  pig.prefab = name or "pigman"
  pig.position = Vector3(x or 0, 0, z or 0)
  pig:AddComponent("talker")
  pig:AddComponent("health"):SetMaxHealth(100)
  pig:AddComponent("combat")
  pig:AddComponent("locomotor")
  pig:SetBrain(package.loaded["brains/pigbrain"])
  return pig
end
local function Closing()
  local player, progress, castle = Encounter()
  local king = SpawnPrefab("pigking")
  king.position = Vector3(100, 0, 100)
  progress._rex = king
  progress:SetProgress("ch6", DIALOG.CH6_SEP[6])
  return player, progress, castle, king
end
local function CountSpeech(speaker, line)
  local count, time = 0, nil
  for _, speech in ipairs(H.speeches()) do
    if speech.speaker == speaker and speech.content == DIALOG.ch6[line].content then
      count, time = count+1, speech.at
    end
  end
  return count, time
end

test("Lupa follows after the king dies, but line thirteen waits for her to reach the player", function()
  local player, progress, castle = Encounter()
  progress:SetProgress("ch6", DIALOG.CH6_SEP[4])
  progress:DialogLoop(player)
  assert(GiftBell(player, castle))
  local lupa = castle._lupa
  lupa.position = Vector3(HELPERS.LUPA_MEETING_DISTANCE+10, 0, 0)
  castle._king.components.health:DoDelta(-castle._king.components.health.maxhealth)
  equal(lupa.components.follower:GetLeader(), player)
  equal(lupa.components.kingguard.followuserid, player.userid)
  equal(lupa.components.kingguard.escaping, nil)
  equal(lupa.persists, false)
  advance(HELPERS.DIALOG_INTERVAL+3)
  equal(CountSpeech(lupa, DIALOG.CH6_SEP[5]), 0)
  equal(progress.dialog, DIALOG.CH6_SEP[5])
  lupa.position = player:GetPosition()
  advance(HELPERS.CHECK_PROGRESS_INTERVAL)
  equal(CountSpeech(lupa, DIALOG.CH6_SEP[5]), 1)
  advance(HELPERS.DIALOG_INTERVAL+1)
  equal(progress.dialog, DIALOG.CH6_SEP[6])
end)

test("rescued Lupa saves with the player, migrates, and is not duplicated by the castle", function()
  local player, progress, castle = Encounter()
  castle._betrayeruserid = player.userid
  castle._king.components.health:DoDelta(-castle._king.components.health.maxhealth)
  local lupa = castle._lupa
  local saved = progress:OnSave()
  assert(saved.king_defeated and saved.lupa ~= nil)
  local castledata = {}
  castle:OnSave(castledata)
  equal(castledata._lupa, nil)
  progress:OnRemoveEntity()
  local arriving, restored = Player(player.userid)
  arriving.migrationpets = {}
  restored:OnLoad(saved)
  local adopted = restored:GetLupa()
  assert(adopted ~= nil and adopted ~= lupa)
  equal(adopted.components.follower:GetLeader(), arriving)
  equal(adopted.persists, false)
  equal(arriving.migrationpets[1], adopted)
  equal(CountPrefab("king_lupa"), 1)
end)

test("reunion creates no puppy before line fourteen ends, then cheers and puppy speech start together", function()
  local player, progress, _, king = Closing()
  local pig, distant = Pig("pigman", 30, 20), Pig("pigguard", -300, -300)
  progress:DialogLoop(player)
  advance(2)
  equal(#H.speeches(), 0)
  equal(CountPrefab("publilius"), 0)
  player.position = king:GetPosition()
  advance(HELPERS.CHECK_PROGRESS_INTERVAL)
  equal(CountSpeech(king._libellus_rex_voice, DIALOG.CH6_SEP[6]), 1)
  equal(CountPrefab("publilius"), 0)
  equal(king.components.libelluscelebration.untiltime, nil)
  advance(HELPERS.DIALOG_INTERVAL-.1)
  equal(CountPrefab("publilius"), 0)
  advance(.2)
  equal(CountPrefab("publilius"), 1)
  local pet = progress:EnsurePublilius()
  equal(pet.AnimState.bank, "pupington")
  equal(pet.graph, "SGcritter_puppy")
  equal(pet.components.follower:GetLeader(), player)
  equal(pet.persists, false)
  equal(pet.displaynamefn(), "Publilius")
  equal(player.components.petleash:GetNumPetsForPrefab("publilius"), 1)
  local count, time = CountSpeech(pet._libellus_voice, DIALOG.CH6_SEP[8])
  equal(count, 1)
  local pigcount, pigtime = CountSpeech(pig, DIALOG.CH6_SEP[7])
  equal(pigcount, 1)
  equal(time, pigtime)
  equal(select(2, CountSpeech(distant, DIALOG.CH6_SEP[7])), time)
  equal(pig.sg.state, "run_start")
  equal(pig.brain, package.loaded["brains/celebrationpigbrain"])
  equal(CountSpeech(player, DIALOG.CH6_SEP[9]), 0)
  advance(HELPERS.DIALOG_INTERVAL+1)
  equal(CountSpeech(player, DIALOG.CH6_SEP[9]), 1)
  equal(player.last_emote, toast)
  advance(HELPERS.DIALOG_INTERVAL+1)
  equal(progress.dialog, DIALOG.CH6_SEP[9]+1)
  equal(CountSpeech(pet._libellus_voice, DIALOG.CH6_SEP[8]), 1)
  advance(time+HELPERS.CLOSING_DURATION-GetTime()+1)
  assert(CountSpeech(pig, DIALOG.CH6_SEP[7]) > 1)
  equal(king.components.libelluscelebration.untiltime, nil)
  equal(pig.position.x, 30)
  equal(pig.position.z, 20)
  equal(distant.position.x, -300)
  equal(distant.position.z, -300)
  equal(pig.brain, package.loaded["brains/pigbrain"])
  equal(pig.components.libelluspigcelebrant, nil)
  local finished = #H.speeches()
  advance(HELPERS.CLOSING_CHEER_INTERVAL)
  equal(#H.speeches(), finished)
end)

test("a refused or interrupted line fourteen cannot grant Publilius", function()
  local player, progress, _, king = Closing()
  player.position = king:GetPosition()
  king._libellus_rex_voice.components.talker.refuse = true
  progress:DialogLoop(player)
  advance(HELPERS.DIALOG_INTERVAL+1)
  equal(progress.dialog, DIALOG.CH6_SEP[6])
  equal(progress._closing_ready, nil)
  equal(CountPrefab("publilius"), 0)
  king._libellus_rex_voice.components.talker.refuse = false
  advance(HELPERS.BUSY_INTERVAL)
  equal(progress.dialog, DIALOG.CH6_SEP[7])
  progress:SetProgress("ch5", DIALOG.CH5_SEP[3])
  player.position = king:GetPosition()
  advance(HELPERS.DIALOG_INTERVAL+1)
  equal(CountPrefab("publilius"), 0)
  equal(king.components.libelluscelebration.untiltime, nil)
end)

test("native pet leash retains an existing pet and never grants a second Publilius", function()
  local player, progress, _, king = Closing()
  H.factories.critter_puppy = Prefabs.critter_puppy.fn
  local original = player.components.petleash:SpawnPetAt(0, 0, 0, "critter_puppy")
  assert(original ~= nil)
  player.position = king:GetPosition()
  progress:DialogLoop(player)
  advance(HELPERS.DIALOG_INTERVAL+1)
  local pet = assert(progress:EnsurePublilius())
  equal(player.components.petleash:GetMaxPets(), 1)
  equal(original.components.follower:GetLeader(), player)
  equal(progress:EnsurePublilius(), pet)
  equal(CountPrefab("publilius"), 1)
  local records = player.components.petleash:OnSave()
  local saved = progress:OnSave()
  progress:OnRemoveEntity()
  player.components.petleash:OnRemoveEntity()
  player:Remove()
  local arriving, restored = Player(player.userid)
  arriving.migrationpets = {}
  restored:OnLoad(saved)
  arriving.components.petleash:OnLoad(records)
  local adopted = assert(restored:EnsurePublilius())
  equal(CountPrefab("publilius"), 1)
  equal(adopted.components.follower:GetLeader(), arriving)
  equal(arriving.components.petleash:GetNumPetsForPrefab("publilius"), 1)
  equal(restored._publilius_spoken, true)
  equal(#arriving.migrationpets, 3) -- Publius and the two native pets.
end)

test("a saved one-minute celebration resumes its remaining time and restores each pig's home", function()
  local king = SpawnPrefab("pigking")
  king.position = Vector3(100, 0, 100)
  local pig = Pig("pigman", 20, 30)
  king.components.libelluscelebration:Start()
  advance(HELPERS.CLOSING_DURATION/2)
  local saved = king.components.libelluscelebration:OnSave()
  local pigsave = pig.components.libelluspigcelebrant:OnSave()
  equal(saved.remaining, HELPERS.CLOSING_DURATION/2)
  king:Remove()
  pig:Remove()
  local loadedking, loadedpig = SpawnPrefab("pigking"), Pig("pigman")
  loadedking.position = Vector3(100, 0, 100)
  loadedpig.position = pig:GetPosition()
  loadedpig:AddComponent("libelluspigcelebrant"):OnLoad(pigsave)
  loadedking.components.libelluscelebration:OnLoad(saved)
  loadedking.components.libelluscelebration:LoadPostPass({[pig.GUID] = {entity = loadedpig}}, saved)
  advance(saved.remaining-.1)
  assert(loadedking.components.libelluscelebration.untiltime ~= nil)
  equal(loadedpig.brain, package.loaded["brains/celebrationpigbrain"])
  advance(.4)
  equal(loadedking.components.libelluscelebration.untiltime, nil)
  equal(loadedpig.brain, package.loaded["brains/pigbrain"])
  equal(loadedpig.position.x, 20)
  equal(loadedpig.position.z, 30)
end)

test("pig movement alternates around Rex and rescued Lupa's brain runs toward her leader", function()
  local savedbrain, savednode, savedbt, savedrunning = Brain, BehaviourNode, BT, RUNNING
  Brain = {_ctor = function(self, inst) self.inst = inst end}
  BehaviourNode = {_ctor = noop, Sleep = noop}
  BT = function(_, node) return {root = node} end
  RUNNING = "RUNNING"
  local oldoffset = FindWalkableOffset
  function FindWalkableOffset(_, angle, radius) return Vector3(math.cos(angle)*radius, 0, math.sin(angle)*radius) end
  local king = SpawnPrefab("pigking")
  king.position = Vector3(100, 0, 100)
  local pig = Pig()
  pig:AddComponent("libelluspigcelebrant"):Join(king)
  function pig.components.locomotor:GoToPoint(point, _, run) self.destination, self.run = point, run end
  local brain = dofile("scripts/brains/celebrationpigbrain.lua")(pig)
  brain:OnStart()
  brain.bt.root:Visit()
  local first = pig.components.locomotor.destination
  equal(pig.components.locomotor.run, true)
  advance(HELPERS.CLOSING_PIG_TURN_INTERVAL)
  brain.bt.root:Visit()
  local second = pig.components.locomotor.destination
  assert((first.x-king.position.x)*(second.x-king.position.x)
    +(first.z-king.position.z)*(second.z-king.position.z) < 0)
  local player, progress, castle = Encounter()
  castle._betrayeruserid = player.userid
  castle._king.components.health:DoDelta(-castle._king.components.health.maxhealth)
  local lupa = castle._lupa
  lupa.position = Vector3(HELPERS.LUPA_FOLLOW_DISTANCE+10, 0, 0)
  function lupa.components.locomotor:GoToPoint(point, _, run) self.destination, self.run = point, run end
  local follow = dofile("scripts/brains/kingcourtbrain.lua")(lupa)
  follow:OnStart()
  follow.bt.root:Visit()
  equal(lupa.components.locomotor.destination.x, player.position.x)
  equal(lupa.components.locomotor.run, true)
  lupa.position = player:GetPosition()
  follow.bt.root:Visit()
  equal(lupa.components.locomotor.stopped, true)
  FindWalkableOffset = oldoffset
  Brain, BehaviourNode, BT, RUNNING = savedbrain, savednode, savedbt, savedrunning
end)
if package.preload.gamehoundgraph ~= nil then
  -- Reproduce the reported crash with the installed game's actual SGhound,
  -- shared amphibious hop states, and amphibiouscreature component.
  function State(data) return data end
  function EventHandler(event, fn) return {event = event, fn = fn} end
  function ActionHandler(action, state) return {action = action, state = state} end
  function TimeEvent(time, fn) return {time = time, fn = fn} end
  function FrameEvent(frame, fn) return TimeEvent(frame*FRAMES, fn) end
  function SoundFrameEvent(frame, sound) return FrameEvent(frame, function(inst) inst.SoundEmitter:PlaySound(sound) end) end
  function StateGraph(name, states, events) return {name = name, states = states, events = events} end
  function JoinArrays(a, b)
    local result = {}
    for _, value in ipairs(a) do table.insert(result, value) end
    for _, value in ipairs(b) do table.insert(result, value) end
    return result
  end
  function IsEntityDead(inst) return inst.components.health ~= nil and inst.components.health:IsDead() end
  COLLISION = {LIMITS = 1}
  TUNING.HOUND_SWIM_SPEED = 7
  require("gamecommonstates")
  package.loaded["stategraphs/commonstates"] = true
  local graph = require("gamehoundgraph")
  local states = {}
  for _, state in ipairs(graph.states) do states[state.name] = state end
  local function BoatLupa()
    TheWorld.has_ocean = true
    local lupa = SpawnPrefab("king_lupa")
    local player = Player()
    lupa.components.kingguard:FollowPlayer(player)
    lupa.Physics.ClearCollidesWith, lupa.Physics.CollidesWith = noop, noop
    function lupa.AnimState:IsCurrentAnimation(name) return self.animation == name end
    function lupa.AnimState:AnimDone() return true end
    function lupa.components.locomotor:RunForward() self.running = true end
    lupa.components.locomotor.hop_distance = 6
    local embarker = lupa.components.embarker
    function embarker:HasDestination() return self.destination ~= nil end
    function embarker:StartMoving() self.moving = true end
    function embarker:Embark()
      lupa.platform = self.destination ~= "land" and self.destination or nil
      self.destination, self.moving = nil, false
    end
    function embarker:Cancel() self.destination, self.moving = nil, false end
    lupa._test_stategraph = graph
    lupa.sg = {statemem = {}, mem = {}}
    function lupa.sg:HasStateTag(tag)
      for _, value in ipairs(self.currentstate.tags or {}) do if value == tag then return true end end
      return false
    end
    function lupa.sg:HasAnyStateTag(...)
      for _, tag in ipairs({...}) do if self:HasStateTag(tag) then return true end end
      return false
    end
    function lupa.sg:SetTimeout(value) self.timeout = value end
    function lupa.sg:GoToState(name, data)
      if self.currentstate ~= nil and self.currentstate.onexit ~= nil then self.currentstate.onexit(lupa) end
      self.currentstate, self.statemem = assert(states[name]), {}
      if self.currentstate.onenter ~= nil then self.currentstate.onenter(lupa, data) end
    end
    lupa.sg:GoToState("idle")
    return lupa, player
  end
  local function FinishHop(lupa)
    -- The first event is the exact commonstates.lua:1087 failure in the screenshot.
    lupa:PushEvent("done_embark_movement")
    lupa.sg.currentstate.onupdate(lupa, 0)
    equal(lupa.sg.currentstate.name, "hop_pst")
    lupa:PushEvent("animover")
    equal(lupa.sg.currentstate.name, "idle")
  end
  test("native hound boarding and disembarking events keep Lupa on deck or on land without crashing", function()
    local lupa, player = BoatLupa()
    local boat = SpawnPrefab("boat")
    local embarker = lupa.components.embarker
    assert(lupa.components.amphibiouscreature ~= nil)
    equal(embarker.antic, true)
    equal(embarker.embark_speed, HELPERS.LUPA_FOLLOW_SPEED)
    embarker.destination = boat
    lupa:PushEvent("onhop")
    equal(lupa.sg.currentstate.name, "hop_pre")
    FinishHop(lupa)
    equal(lupa:GetCurrentPlatform(), boat)
    equal(lupa:HasTag("swimming"), false)
    equal(lupa.AnimState.bank, "hound")
    embarker.destination = "land"
    lupa:PushEvent("onhop")
    FinishHop(lupa)
    equal(lupa:GetCurrentPlatform(), nil)
    equal(lupa.components.follower:GetLeader(), player)
    equal(lupa.components.locomotor.runspeed, HELPERS.LUPA_FOLLOW_SPEED)
  end)
  test("native water-to-boat hop restores Lupa's land bank, speed, and hop distance", function()
    local lupa = BoatLupa()
    local amphibious = lupa.components.amphibiouscreature
    amphibious:OnEnterOcean()
    equal(lupa.AnimState.bank, "hound_water")
    equal(lupa:HasTag("swimming"), true)
    equal(lupa.components.locomotor.runspeed, TUNING.HOUND_SWIM_SPEED)
    equal(lupa.components.locomotor.hop_distance, HELPERS.LUPA_SWIM_HOP_DISTANCE)
    local boat = SpawnPrefab("boat")
    lupa.components.embarker.destination = boat
    lupa:PushEvent("onhop")
    equal(lupa.sg.currentstate.name, "hop_antic")
    lupa.sg.currentstate.ontimeout(lupa)
    FinishHop(lupa)
    equal(lupa:GetCurrentPlatform(), boat)
    equal(amphibious.in_water, false)
    equal(lupa.AnimState.bank, "hound")
    equal(lupa.components.locomotor.runspeed, HELPERS.LUPA_FOLLOW_SPEED)
    equal(lupa.components.locomotor.hop_distance, 6)
  end)
  test("native hop animation and water-landing events also have their required amphibious component", function()
    local lupa = BoatLupa()
    local boat = SpawnPrefab("boat")
    lupa.components.embarker.destination = boat
    lupa:PushEvent("onhop")
    lupa:PushEvent("animover")
    equal(lupa.AnimState.animation, "jump_loop")
    FinishHop(lupa)
    lupa.sg:GoToState("hop_pst", true)
    equal(lupa.components.amphibiouscreature.in_water, true)
    equal(lupa.AnimState.bank, "hound_water")
    lupa:PushEvent("animover")
    lupa.sg:GoToState("hop_pst", false)
    equal(lupa.components.amphibiouscreature.in_water, false)
    equal(lupa.AnimState.bank, "hound")
  end)
end
print(count.." lunar castle and closing-scene tests passed")
