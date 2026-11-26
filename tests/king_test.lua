-- Run from the mod root: lua tests/king_test.lua
LIBELLUS_TEST_HARNESS = true
local H = dofile("tests/casa_test.lua")
LIBELLUS_TEST_HARNESS = nil
local equal, advance = H.equal, H.advance
local HELPERS, DIALOG = require("helpers"), require("libellus")
local Progress = require("components/libellusprogress")
local Scene = require("kingscene")
package.loaded["brains/kingcourtbrain"] = {name = "court"}
for _, name in ipairs({"dragonfly", "deerclops", "bearger", "beequeen"}) do
  package.loaded["brains/"..name.."brain"] = {name = name}
end
EQUIPSLOTS.HEAD, EQUIPSLOTS.BODY = "head", "body"
WORLD_TILES.COTL_GOLD, WORLD_TILES.CARPET2 = 8, 9
local function noop() end
local function Entity()
  local inst = H.Entity()
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
  function inst:AddComponent(name)
    if name == "kingguard" or name == "libelluscastlesleep" then
      self.components[name] = require("components/"..name)(self)
      return self.components[name]
    end
    local c = add(self, name)
    if name == "combat" then
      function c:SetRetargetFunction(period, fn) self.retarget, self.targetfn = fn, fn end
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
  inst.components.libellusprogress = Progress(inst)
  table.insert(AllPlayers, inst)
  return inst, inst.components.libellusprogress
end
local function Encounter()
  local player, progress = Player()
  -- Keep the rest of the story's encounters outside this focused world.
  progress.EnsureCasa, progress.EnsureFarm, progress.EnsureNavis, progress.EnsurePasser = noop, noop, noop, noop
  player.position = Vector3(1000, 0, 1000)
  local castle = progress:EnsureCastle()
  player.position = Vector3(0, 0, 0)
  local publius = Entity()
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
print(count.." lunar castle tests passed")
