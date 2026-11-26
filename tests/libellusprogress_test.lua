-- Run from the mod directory with Lua 5.1+:
-- lua tests/libellusprogress_test.lua [test name filter]
package.path = "./scripts/?.lua;./scripts/?/init.lua;" .. package.path
local test_filter = arg ~= nil and arg[1] or nil

local function equal(actual, expected, message)
  assert(actual == expected, (message or "unexpected value") .. ": expected "
    .. tostring(expected) .. ", got " .. tostring(actual))
end

function Class(base, constructor)
  if constructor == nil then constructor, base = base, nil end
  local class = {_ctor = constructor}
  class.__index = class
  return setmetatable(class, {
    __index = base,
    __call = function(_, ...)
      local object = setmetatable({}, class)
      constructor(object, ...)
      return object
    end
  })
end

local Vector = {}
Vector.__index = Vector
function Vector:Get() return self.x, self.y, self.z end
function Vector.__add(a, b) return Vector3(a.x + b.x, a.y + b.y, a.z + b.z) end
function Vector3(x, y, z) return setmetatable({x = x, y = y, z = z}, Vector) end

local now, tasks, speeches, spawned, grass, blocked, hole
WORLD_TILES = {GRASS = 1}
TheWorld = {ismastersim = true, Map = {}}
function TheWorld.Map:GetTileAtPoint() return grass and WORLD_TILES.GRASS or 2 end
function TheWorld.Map:IsPassableAtPoint() return not blocked end
function TheWorld.Map:IsPointNearHole() return hole end
function GetTime() return now end
function FindWalkableOffset(origin, angle, radius, attempts, los, walls, check)
  local offset = Vector3(radius, 0, 0)
  return check(origin + offset) and offset or nil
end

local function Entity(name, userid)
  local inst = {prefab = name, userid = userid, components = {}, tags = {}, valid = true,
    position = Vector3(0, 0, 0)}
  function inst:IsValid() return self.valid end
  function inst:Remove() self.valid = false end
  function inst:GetSaveRecord()
    return {prefab = self.prefab, x = self.position.x, y = self.position.y,
      z = self.position.z, owneruserid = self._libellus_owneruserid}
  end
  function inst:GetPosition() return Vector3(self.position:Get()) end
  function inst:HasTag(tag) return self.tags[tag] == true end
  function inst:AddTag(tag) self.tags[tag] = true end
  function inst:FacePoint() end
  function inst:IsNear(other, distance)
    local a, b = self.position, other.position
    return (a.x - b.x)^2 + (a.z - b.z)^2 <= distance^2
  end
  function inst:DoTaskInTime(delay, fn)
    assert(type(delay) == "number" and delay > 0, "loop must schedule a positive delay")
    tasks[#tasks + 1] = {at = now + delay, fn = fn, inst = self}
  end
  inst.Transform = {}
  function inst.Transform:GetWorldPosition() return inst.position:Get() end
  function inst.Transform:SetPosition(x, y, z) inst.position = Vector3(x, y, z) end
  inst.sg = {HasStateTag = function() return inst.busy == true end}
  local talker = {untiltime = 0}
  function talker:IsTalking() return self.untiltime > now end
  function talker:Say(content, duration)
    if self.refuse then return end
    self.untiltime = now + duration
    speeches[#speeches + 1] = {speaker = inst, content = content, at = now}
    if self.on_say ~= nil then self.on_say() end
  end
  inst.components.talker = talker
  local follower = {}
  function follower:SetLeader(leader) self.leader = leader end
  function follower:KeepLeaderOnAttacked() self.keepleaderonattacked = true end
  inst.components.follower = follower
  return inst
end

function SpawnPrefab(name)
  equal(name, "publius")
  spawned = spawned + 1
  local publius = Entity(name)
  Ents[#Ents + 1] = publius
  return publius
end

function SpawnSaveRecord(data)
  local publius = SpawnPrefab(data.prefab)
  publius.Transform:SetPosition(data.x, data.y, data.z)
  publius._libellus_owneruserid = data.owneruserid
  return publius
end

local function reset()
  now, tasks, speeches, spawned = 0, {}, {}, 0
  grass, blocked, hole = true, false, false
  Ents = {}
end

local function advance(seconds)
  local target = now + seconds
  local count = 0
  while true do
    table.sort(tasks, function(a, b) return a.at < b.at end)
    if tasks[1] == nil or tasks[1].at > target then break end
    local task = table.remove(tasks, 1)
    now = task.at
    if task.inst.valid then task.fn(task.inst) end
    count = count + 1
    assert(count < 1000, "dialogue loop spun without waiting")
  end
  now = target
end

local HELPERS = require("helpers")
local DIALOG = require("libellus")
local Progress = require("components/libellusprogress")
-- Chapter-two encounters have their own suite in casa_test.lua.
function Progress:EnsureCasa() end
function Progress:EnsureFarm() end
function Progress:EnsureNavis() end
function Progress:EnsurePasser() end
function Progress:EnsureCastle() end
local tests = 0
local function test(name, fn)
  if test_filter ~= nil and not name:find(test_filter, 1, true) then return end
  reset()
  fn()
  tests = tests + 1
  print("PASS " .. name)
end

test("spawn uses nearby grass and keeps its original search origin", function()
  local player = Entity("wilson", "octavia")
  local progress = Progress(player)
  local publius = progress:EnsurePublius()
  equal(publius.position.x, HELPERS.PUBLIUS_SPAWN_MIN_DISTANCE)
  equal(publius._libellus_owneruserid, player.userid)
  equal(publius.components.follower.leader, nil)
  player.position = Vector3(100, 0, 0)
  equal(progress:EnsurePublius(), publius)
  equal(spawned, 1)
  equal(progress:OnSave().spawnpoint.x, 0)
end)

test("no off-grass, obstructed, or hole spawns; retry still runs", function()
  for _, flag in ipairs({"grass", "blocked", "hole"}) do
    reset()
    if flag == "grass" then grass = false
    elseif flag == "blocked" then blocked = true
    else hole = true end
    local progress = Progress(Entity("wilson", "octavia"))
    equal(progress:EnsurePublius(), nil)
    equal(spawned, 0)
    grass, blocked, hole = true, false, false
    equal(progress:EnsurePublius(), nil, "retry should be throttled")
    now = HELPERS.PUBLIUS_SPAWN_RETRY_INTERVAL
    assert(progress:EnsurePublius() ~= nil)
  end
end)

test("original intro and distant line five keep running", function()
  local player = Entity("wilson", "octavia")
  local progress = Progress(player)
  progress:DialogLoop(player)
  advance(51)
  equal(progress.dialog, 5)
  for i = 1, 4 do equal(speeches[i].content, DIALOG.ch1[i].content) end
  equal(speeches[5].content, DIALOG.ch1[5].content)
  equal(speeches[6].content, DIALOG.ch1[5].content)
  equal(progress._publius.components.follower.leader, nil)
end)

test("approach interrupts the repeat wait and routes lines six to ten", function()
  local player = Entity("wilson", "octavia")
  local progress = Progress(player)
  progress:SetProgress("ch1", 5)
  progress:DialogLoop(player)
  advance(6)
  player.position = Vector3(7, 0, 0)
  advance(2)
  equal(speeches[2].content, DIALOG.ch1[6].content)
  advance(20)
  equal(progress.dialog, 1)
  equal(progress._publius.components.follower.leader, nil, "last line is still on screen")
  advance(5)
  equal(progress._publius.components.follower.leader, player)
  local actors = {Octavia = player, Publius = progress._publius}
  for i = 6, 10 do
    local speech = speeches[i - 4]
    equal(speech.content, DIALOG.ch1[i].content)
    equal(speech.speaker, actors[DIALOG.ch1[i].name])
    if i > 6 then assert(speech.at >= speeches[i - 5].at + HELPERS.DIALOG_INTERVAL) end
  end
  advance(60)
  equal(#speeches, 6, "finished meeting must not repeat")
  equal(progress.dialog, 1)
  assert(#tasks > 0, "loop must remain active for future dialogue")
end)

test("proximity boundary is three units", function()
  local player = Entity("wilson", "octavia")
  local progress = Progress(player)
  local publius = progress:EnsurePublius()
  player.position = Vector3(publius.position.x - 3.01, 0, 0)
  equal(progress:IsNearPublius(), false)
  player.position.x = publius.position.x - 3
  equal(progress:IsNearPublius(), true)
end)

test("walking away pauses the next line and returning resumes it", function()
  local player = Entity("wilson", "octavia")
  local progress = Progress(player)
  progress:EnsurePublius()
  player.position = Vector3(7, 0, 0)
  progress:SetProgress("ch1", 6)
  progress:DialogLoop(player)
  player.position = Vector3(100, 0, 0)
  advance(12)
  equal(progress.dialog, 7)
  equal(#speeches, 1)
  player.position = Vector3(7, 0, 0)
  advance(2)
  equal(speeches[2].speaker, progress._publius)
  equal(progress.dialog, 8)
end)

test("refused NPC speech is retried without skipping the line", function()
  local player = Entity("wilson", "octavia")
  local progress = Progress(player)
  local publius = progress:EnsurePublius()
  player.position = Vector3(7, 0, 0)
  progress:SetProgress("ch1", 7)
  publius.components.talker.refuse = true
  progress:DialogLoop(player)
  advance(4)
  equal(progress.dialog, 7)
  equal(#speeches, 0)
  publius.components.talker.refuse = false
  advance(2)
  equal(progress.dialog, 8)
  equal(speeches[1].speaker, publius)
end)

test("busy player, busy NPC, and ghosts retain progress", function()
  local player = Entity("wilson", "octavia")
  local progress = Progress(player)
  local publius = progress:EnsurePublius()
  player.position = Vector3(7, 0, 0)
  progress:SetProgress("ch1", 7)
  player.busy = true
  progress:DialogLoop(player)
  advance(4)
  player.busy, publius.busy = false, true
  advance(4)
  publius.busy, player.tags.playerghost = false, true
  advance(4)
  equal(progress.dialog, 7)
  equal(#speeches, 0)
  player.tags.playerghost = nil
  advance(2)
  equal(progress.dialog, 8)
end)

test("saved mid-conversation progress reuses the owned NPC", function()
  local original = Progress(Entity("wilson", "octavia"))
  local publius = original:EnsurePublius()
  original:SetProgress("ch1", 8)
  local player = Entity("wendy", "octavia")
  player.position = Vector3(7, 0, 0)
  local restored = Progress(player)
  restored:OnLoad(original:OnSave())
  restored:DialogLoop(player)
  equal(restored._publius, publius)
  equal(spawned, 1)
  equal(speeches[1].content, DIALOG.ch1[8].content)
  equal(speeches[1].speaker, player)
  equal(restored._spawnpoint.x, 0)
end)

test("completed save resumes following without replaying speech", function()
  local original = Progress(Entity("wilson", "octavia"))
  local publius = original:EnsurePublius()
  original:SetProgress("ch1", 11)
  local player = Entity("wilson", "octavia")
  local restored = Progress(player)
  restored:OnLoad(original:OnSave())
  restored:DialogLoop(player)
  advance(60)
  equal(publius.components.follower.leader, player)
  equal(#speeches, 0)
  equal(spawned, 1)
  assert(#tasks > 0)
end)

test("players cannot claim another player's Publius", function()
  local first = Progress(Entity("wilson", "first")):EnsurePublius()
  local second = Progress(Entity("wilson", "second")):EnsurePublius()
  assert(first ~= second)
  equal(spawned, 2)
end)

test("recruited NPC saves with the player and migrates between shards", function()
  local player = Entity("wilson", "octavia")
  local progress = Progress(player)
  progress:SetProgress("ch1", 11)
  progress:DialogLoop(player)
  local original = progress._publius
  equal(original.persists, false)
  local saved = progress:OnSave()
  equal(saved.publius.prefab, "publius")
  equal(original.temp_save_platform_pos, nil)
  progress:OnRemoveEntity()
  equal(original:IsValid(), false, "old shard must not retain a second copy")
  local arriving = Entity("wilson", "octavia")
  arriving.migrationpets = {}
  local restored = Progress(arriving)
  restored:OnLoad(saved)
  local publius = restored._publius
  equal(arriving.migrationpets[1], publius)
  equal(publius._libellus_owneruserid, arriving.userid)
  restored:DialogLoop(arriving)
  equal(publius.components.follower.leader, arriving)
  equal(#speeches, 0)
end)

test("unrecruited NPC stays in the world when its player disconnects", function()
  local progress = Progress(Entity("wilson", "octavia"))
  local publius = progress:EnsurePublius()
  equal(progress:OnSave().publius, nil)
  progress:OnRemoveEntity()
  equal(publius:IsValid(), true)
end)

test("speech event progress updates take precedence", function()
  local player = Entity("wilson", "octavia")
  local progress = Progress(player)
  local publius = progress:EnsurePublius()
  player.position = Vector3(7, 0, 0)
  progress:SetProgress("ch1", 7)
  publius.components.talker.on_say = function()
    progress:SetProgress("ch1", 9)
    progress:SetProgress("ch1", 7)
  end
  progress:DialogLoop(player)
  equal(progress.dialog, 7, "newer update must win even at the same position")
end)

test("missing player talker does not stop future polling", function()
  local player = Entity("wilson", "octavia")
  player.components.talker = nil
  Progress(player):DialogLoop(player)
  assert(#tasks > 0)
end)

-- Exercise the prefab's client/server split without starting a game server.
local prefabbrain = {}
package.loaded["brains/publiusbrain"] = prefabbrain
TALKINGFONT = "talkingfont"
STRINGS = {NAMES = {PUBLIUS = "Publius"}}
TUNING = {WILSON_WALK_SPEED = 4, WILSON_RUN_SPEED = 6}
function Asset(kind, path) return {kind = kind, path = path} end
function Prefab(name, fn, assets) return {name = name, fn = fn, assets = assets} end
function MakeCharacterPhysics(inst) inst.hasphysics = true end
function CreateEntity()
  local inst = Entity("publius")
  -- DST assigns the prefab and default name after the constructor returns.
  inst.prefab = nil
  inst.components = {}
  inst.entity = {}
  for _, name in ipairs({"AddTransform", "AddAnimState", "AddSoundEmitter",
    "AddDynamicShadow", "AddMiniMapEntity", "AddNetwork"}) do
    inst.entity[name] = function() end
  end
  function inst.entity:SetPristine()
    assert(inst.components.talker ~= nil, "clients need a talker before SetPristine")
  end
  inst.DynamicShadow = {SetSize = function() end}
  inst.MiniMapEntity = {}
  function inst.MiniMapEntity:SetIcon(icon) self.icon = icon end
  function inst.MiniMapEntity:SetPriority(priority) self.priority = priority end
  function inst.MiniMapEntity:SetCanUseCache(enabled) self.canusecache = enabled end
  function inst.MiniMapEntity:SetDrawOverFogOfWar(enabled) self.overfog = enabled end
  function inst:GetDisplayName() return self.name end
  inst.Transform.SetFourFaced = function() end
  inst.AnimState = {hidden = {}}
  function inst.AnimState:SetBank(bank) self.bank = bank end
  function inst.AnimState:SetBuild(build) self.build = build end
  function inst.AnimState:PlayAnimation() end
  function inst.AnimState:Hide(symbol) self.hidden[symbol] = true end
  function inst:AddComponent(name)
    local component = {}
    if name == "follower" then
      function component:KeepLeaderOnAttacked() self.keepleaderonattacked = true end
    elseif name == "locomotor" then
      function component:SetAllowPlatformHopping(enabled) self.allow_platform_hopping = enabled end
    elseif name == "maprevealable" then
      function component:SetIconPrefab(prefab) self.iconprefab = prefab end
      function component:SetIcon(icon) self.iconname = icon end
      function component:SetIconPriority(priority) self.iconpriority = priority end
      function component:SetOnIconCreatedFn(fn) self.oniconcreatedfn = fn end
      function component:AddRevealSource(source)
        self.revealsource = source
        local displayname = {set = function(_, value)
          assert(type(value) == "string", "map label net_string requires a string")
          self.displayname = value
        end}
        self.oniconcreatedfn(inst, {_target_displayname = displayname})
      end
    end
    self.components[name] = component
  end
  function inst:SetStateGraph(graph) self.stategraph = graph end
  function inst:SetBrain(brain) self.brain = brain end
  return inst
end

local prefab = dofile("scripts/prefabs/publius.lua")
test("client prefab has plain Wilson appearance and speech", function()
  TheWorld.ismastersim = false
  local publius = prefab.fn()
  equal(publius.AnimState.bank, "wilson")
  equal(publius.AnimState.build, "wilson")
  assert(publius.AnimState.hidden.HAT and publius.AnimState.hidden.ARM_carry)
  assert(publius.components.talker ~= nil)
  equal(publius.components.follower, nil)
  equal(publius.components.locomotor, nil)
end)

test("server prefab supplies permanent following and saved ownership", function()
  TheWorld.ismastersim = true
  local publius = prefab.fn()
  local follower = publius.components.follower
  assert(follower.neverexpire and follower.keepdeadleader and follower.keepleaderonattacked)
  assert(publius.components.embarker ~= nil and publius.components.locomotor.allow_platform_hopping)
  equal(publius.stategraph, "SGpublius")
  equal(publius.brain, prefabbrain)
  publius._libellus_owneruserid = "octavia"
  local saved = {}
  publius:OnSave(saved)
  local restored = prefab.fn()
  restored:OnLoad(saved)
  equal(restored._libellus_owneruserid, "octavia")
end)

test("server prefab labels the map before its entity name is initialized", function()
  TheWorld.ismastersim = true
  local publius = prefab.fn()
  equal(publius:GetDisplayName(), nil)
  equal(publius.components.maprevealable.displayname, STRINGS.NAMES.PUBLIUS)
end)

test("Publius loads human boat-hop animations and configures every hop phase", function()
  local assets = {}
  for _, asset in ipairs(prefab.assets) do assets[asset.path] = true end
  assert(assets["anim/player_boat_jump.zip"], "boat hopping requires its own animation bank")
  local savedstates, savedhandlers = CommonStates, CommonHandlers
  local savedmodule = package.loaded["stategraphs/commonstates"]
  local hop
  CommonStates = {AddIdle = function() end, AddWalkStates = function() end,
    AddRunStates = function() end,
    AddHopStates = function(states, wait, anims, timelines, sound, falling, data)
      hop = {wait = wait, anims = anims, data = data}
    end}
  CommonHandlers = {OnLocomote = function() return {} end, OnHop = function() return {} end}
  package.loaded["stategraphs/commonstates"] = true
  FRAMES = 1/30
  function State(data) return data end
  function EventHandler(event, fn) return {event = event, fn = fn} end
  function StateGraph(name, states, events) return {states = states, events = events} end
  dofile("scripts/stategraphs/SGpublius.lua")
  equal(hop.wait, true)
  equal(hop.anims.pre, "boat_jump_pre")
  equal(hop.anims.loop, "boat_jump_loop")
  equal(hop.anims.pst, "boat_jump_pst")
  equal(hop.data.start_embarking_pre_frame, 4 * FRAMES)
  CommonStates, CommonHandlers = savedstates, savedhandlers
  package.loaded["stategraphs/commonstates"] = savedmodule
end)

-- An external runner can preload commonstates from the installed scripts.zip.
-- This exercises DST's real transition/cleanup logic rather than a copy of it.
if package.preload["stategraphs/commonstates"] ~= nil then
  test("DST boat hops board, disembark, and cancel without losing Publius", function()
    FRAMES = 1/30
    COLLISION = {GROUND = 1}
    function State(data) return data end
    function EventHandler(event, fn) return {event = event, fn = fn} end
    function TimeEvent(time, fn) return {time = time, fn = fn} end
    function FrameEvent(frame, fn) return TimeEvent(frame * FRAMES, fn) end
    function FunctionOrValue(value, ...) return type(value) == "function" and value(...) or value end
    local graph = dofile("scripts/stategraphs/SGpublius.lua")
    local states = {}
    for _, state in ipairs(graph.states) do states[state.name] = state end
    local inst, boat, leader = Entity("publius"), Entity("boat"), Entity("wilson")
    inst.components.follower:SetLeader(leader)
    inst.ForceFacePoint = function() end
    function inst:RemoveTag(tag) self.tags[tag] = nil end
    inst.SoundEmitter = {PlaySound = function() end}
    inst.Physics = {mask = 123}
    function inst.Physics:GetCollisionMask() return self.mask end
    function inst.Physics:SetCollisionMask(mask) self.mask = mask end
    function inst.Physics:ClearLocalCollisionMask() end
    inst.AnimState = {}
    function inst.AnimState:PlayAnimation(anim) self.anim = anim end
    function inst.AnimState:IsCurrentAnimation(anim) return self.anim == anim end
    function inst.AnimState:GetCurrentAnimationLength() return 1 end
    inst.components.locomotor = {isrunning = false, StopMoving = function() end, Stop = function() end}
    inst.components.embarker = {}
    function inst.components.embarker:GetEmbarkPosition() return 2, 0 end
    function inst.components.embarker:StartMoving() self.moving = true end
    function inst.components.embarker:Cancel() self.moving = false end
    function inst.components.embarker:Embark()
      inst.platform = self.destination
      self.moving = false
    end
    function inst:GetCurrentPlatform() return self.platform end
    function inst:DoTaskInTime(delay, fn) equal(delay, 0); fn(self) end
    inst.sg = {statemem = {}}
    function inst.sg:SetTimeout(timeout) self.timeout = timeout end
    function inst.sg:HasStateTag(tag)
      for _, value in ipairs(self.currentstate.tags or {}) do if value == tag then return true end end
      return false
    end
    function inst.sg:HasAnyStateTag(...)
      for _, tag in ipairs({...}) do if self:HasStateTag(tag) then return true end end
      return false
    end
    function inst.sg:GoToState(name, data)
      local old = self.currentstate
      if old ~= nil and old.onexit ~= nil then old.onexit(inst) end
      self.currentstate, self.statemem = states[name], {}
      if self.currentstate.onenter ~= nil then self.currentstate.onenter(inst, data) end
    end
    function inst:PushEvent(event)
      for _, handler in ipairs(self.sg.currentstate.events or {}) do
        if handler.event == event then handler.fn(self); return end
      end
      for _, handler in ipairs(graph.events) do
        if handler.event == event then handler.fn(self); return end
      end
    end
    inst.sg:GoToState("idle")
    for _, destination in ipairs({boat, false, boat}) do
      inst.components.embarker.destination = destination or nil
      inst:PushEvent("onhop")
      equal(inst.AnimState.anim, "boat_jump_pre")
      states.hop_pre.ontimeout(inst)
      inst:PushEvent("animover")
      equal(inst.AnimState.anim, "boat_jump_loop")
      equal(inst:HasTag("ignorewalkableplatforms"), true)
      inst:PushEvent("done_embark_movement")
      equal(inst.AnimState.anim, "boat_jump_pst")
      equal(inst:HasTag("ignorewalkableplatforms"), false)
      equal(inst:GetCurrentPlatform(), destination or nil)
      inst:PushEvent("animover")
      equal(inst.sg.currentstate.name, "idle")
      equal(inst.Physics.mask, 123)
      equal(inst.components.follower.leader, leader)
      equal(inst:IsValid(), true)
    end
    inst:PushEvent("onhop")
    inst:PushEvent("animover")
    inst:PushEvent("cancelhop")
    inst:PushEvent("animover")
    equal(inst.sg.currentstate.name, "idle")
    equal(inst:HasTag("ignorewalkableplatforms"), false)
    equal(inst.components.embarker.moving, false)
  end)
end

print(string.format("%d dialogue and spawning tests passed", tests))
