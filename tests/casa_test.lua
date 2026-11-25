-- Run from the mod directory: lua tests/casa_test.lua
package.path = "./scripts/?.lua;" .. package.path

function Class(base, ctor)
  if ctor == nil then ctor, base = base, nil end
  local class = {_ctor = ctor}
  class.__index = class
  return setmetatable(class, {__index = base, __call = function(_, ...)
    local obj = setmetatable({}, class)
    ctor(obj, ...)
    return obj
  end})
end

local Vector = {}
Vector.__index = Vector
function Vector:Get() return self.x, self.y, self.z end
function Vector.__add(a, b) return Vector3(a.x + b.x, a.y + b.y, a.z + b.z) end
function Vector3(x, y, z) return setmetatable({x = x, y = y, z = z}, Vector) end
function Asset(kind, file) return {type = kind, file = file} end
function Prefab(name, fn, assets, deps) return {name = name, fn = fn, assets = assets, deps = deps} end
TALKINGFONT = "talkingfont"
TUNING = {WILSON_WALK_SPEED = 4, WILSON_RUN_SPEED = 6, SPEAR_DAMAGE = 34}
EQUIPSLOTS = {HANDS = "hands"}
FRAMES = 1/30
WORLD_TILES = {GRASS = 1}

local now, tasks, speeches, serial, cave, blocked, hole, obstacle, random_angles
local factories = {}
local function noop() end
local function reset()
  now, tasks, speeches, serial = 0, {}, {}, 0
  cave, blocked, hole, obstacle = false, false, false, false
  random_angles, Ents, AllPlayers = {}, {}, {}
  TheWorld = {ismastersim = true, Map = {}}
  function TheWorld:HasTag(tag) return tag == "cave" and cave end
  function TheWorld.Map:IsPassableAtPoint(x, y, z)
    return not blocked or x > 80
  end
  function TheWorld.Map:IsPointNearHole() return hole end
  function TheWorld.Map:GetTileAtPoint() return WORLD_TILES.GRASS end
  TheSim = {FindEntities = function()
    return obstacle and {{GetPhysicsRadius = function() return 1 end}} or {}
  end}
end
function GetTime() return now end
function FindWalkableOffset(origin, angle, radius, attempts, los, walls, check)
  table.insert(random_angles, angle)
  local offset = Vector3(radius, 0, 0)
  return check(origin + offset) and offset or nil
end
local function advance(seconds)
  local untiltime, steps = now + seconds, 0
  while true do
    table.sort(tasks, function(a, b) return a.at < b.at end)
    if tasks[1] == nil or tasks[1].at > untiltime + 1e-7 then break end
    local task = table.remove(tasks, 1)
    now = task.at
    if not task.cancelled and task.inst:IsValid() then
      task.fn(task.inst)
      if task.period ~= nil then
        task.at = now + task.period
        table.insert(tasks, task)
      end
    end
    steps = steps + 1
    assert(steps < 20000, "task loop spun")
  end
  now = untiltime
end

local function Entity()
  serial = serial + 1
  local inst = {GUID = serial, components = {}, tags = {}, valid = true,
    position = Vector3(0, 0, 0), events = {}}
  Ents[serial] = inst
  function inst:IsValid() return self.valid end
  function inst:Remove() self.valid = false end
  function inst:HasTag(tag) return self.tags[tag] == true end
  function inst:AddTag(tag) self.tags[tag] = true end
  function inst:GetPosition() return Vector3(self.position:Get()) end
  function inst:GetPhysicsRadius() return self.radius or 0 end
  function inst:IsNear(other, distance)
    return (self.position.x - other.position.x)^2 + (self.position.z - other.position.z)^2 <= distance^2
  end
  function inst:FacePoint(x, y, z) self.facing = Vector3(x, y, z) end
  function inst:ClearBufferedAction() self.cleared = true end
  function inst:ListenForEvent(name, fn) self.events[name] = fn end
  function inst:DoTaskInTime(delay, fn)
    local task = {at = now + delay, fn = fn, inst = self}
    function task:Cancel() self.cancelled = true end
    table.insert(tasks, task)
    return task
  end
  function inst:DoPeriodicTask(period, fn)
    local task = self:DoTaskInTime(period, fn)
    task.period = period
    return task
  end
  inst.entity = setmetatable({SetPristine = function() inst.pristine = true end}, {__index = function() return noop end})
  inst.Transform = {SetFourFaced = noop}
  function inst.Transform:GetWorldPosition() return inst.position:Get() end
  function inst.Transform:SetPosition(x, y, z) inst.position = Vector3(x, y, z) end
  inst.AnimState = {Hide = noop, Show = noop}
  function inst.AnimState:SetBank(value) self.bank = value end
  function inst.AnimState:SetBuild(value) self.build = value end
  function inst.AnimState:PlayAnimation(value) self.animation = value end
  inst.DynamicShadow = {SetSize = noop}
  inst.MiniMapEntity = {SetIcon = noop}
  inst.SoundEmitter = {PlaySound = noop}
  inst.sg = {statemem = {}, state = "idle"}
  function inst.sg:HasStateTag(tag) return self.state == tag or (tag == "busy" and inst.busy == true) end
  function inst.sg:GoToState(state) self.state = state end
  function inst:SetStateGraph(value) self.graph = value end
  function inst:SetBrain(value) self.brain = value end
  function inst:AddComponent(name)
    local c = {}
    self.components[name] = c
    if name == "talker" then
      c.untiltime = 0
      function c:IsTalking() return self.untiltime > now end
      function c:Say(text, duration)
        if self.refuse then return end
        self.untiltime = now + duration
        table.insert(speeches, {speaker = inst, content = text})
      end
    elseif name == "health" then
      function c:SetMaxHealth(value) self.maxhealth, self.currenthealth = value, value end
      function c:SetPercent(value) self.currenthealth = (self.maxhealth or 100) * value end
      function c:IsDead() return self.currenthealth == 0 end
    elseif name == "combat" then
      function c:SetDefaultDamage(value) self.damage = value end
      function c:SetAttackPeriod(value) self.period = value end
      function c:SetRange(value) self.range = value end
      function c:SetKeepTargetFunction(fn) self.keep = fn end
      function c:SetShouldAggroFn(fn) self.shouldaggro = fn end
      function c:CanTarget(target) return target ~= nil and target:IsValid() and not target.untargetable end
      function c:SetTarget(target)
        if target == nil or self.shouldaggro == nil or self.shouldaggro(inst, target) then self.target = target end
      end
      function c:DropTarget() self.target = nil end
      function c:DoAttack(target) self.hits = (self.hits or 0) + 1 end
    elseif name == "inventory" then
      function c:GetEquippedItem() return self.weapon end
      function c:Equip(weapon) self.weapon = weapon end
    elseif name == "follower" then
      function c:SetLeader(leader) self.leader = leader end
    elseif name == "locomotor" then
      function c:Stop() self.stopped = true end
    end
    return c
  end
  return inst
end
CreateEntity = Entity
function MakeCharacterPhysics(inst, mass, radius) inst.radius = radius end
function MakeObstaclePhysics(inst, radius) inst.radius = radius end
function SpawnPrefab(name)
  local inst
  if factories[name] ~= nil then
    inst = factories[name]()
  else
    inst = Entity()
    if name == "wall_stone" then
      inst:AddComponent("health"):SetMaxHealth(400)
    elseif name == "publius" then
      inst:AddComponent("talker")
      inst:AddComponent("follower")
    end
  end
  inst.prefab = name
  return inst
end

package.loaded["brains/milesbrain"] = {}
local HELPERS = require("helpers")
local DIALOG = require("libellus")
local Progress = require("components/libellusprogress")
for _, name in ipairs({"casa", "lupa", "miles"}) do
  factories[name] = require("prefabs/" .. name).fn
end
local count = 0
local function equal(a, b) assert(a == b, "expected " .. tostring(b) .. ", got " .. tostring(a)) end
local function test(name, fn)
  reset()
  fn()
  count = count + 1
  print("PASS " .. name)
end
local function Player(userid)
  local p = Entity()
  p.userid = userid or "octavia"
  p:AddTag("player")
  p:AddComponent("talker")
  p:AddComponent("health"):SetMaxHealth(150)
  p.components.libellusprogress = Progress(p)
  table.insert(AllPlayers, p)
  return p, p.components.libellusprogress
end
local function Encounter()
  local player, progress = Player()
  local casa = progress:EnsureCasa()
  progress:EnsurePublius()
  advance(0)
  return player, progress, casa
end

test("spawn uses original player origin and retries blocked footprints", function()
  local player, progress = Player()
  blocked = true
  equal(progress:EnsureCasa(), nil)
  blocked = false
  equal(progress:EnsureCasa(), nil)
  now = HELPERS.CASA_SPAWN_RETRY_INTERVAL
  player.position = Vector3(200, 0, 200)
  local casa = progress:EnsureCasa()
  equal(casa.position.x, HELPERS.CASA_SPAWN_MIN_DISTANCE + .5)
  equal(casa.position.z, .5)
  equal(progress:EnsureCasa(), casa)
  assert(random_angles[1] ~= 0, "placement must randomize its angle")
end)

test("holes, physical obstacles, and cave shards reject casa placement", function()
  for _, flag in ipairs({"hole", "obstacle", "cave"}) do
    reset()
    if flag == "hole" then hole = true elseif flag == "obstacle" then obstacle = true else cave = true end
    local _, progress = Player()
    equal(progress:EnsureCasa(), nil)
  end
end)

test("layout has three to five armed WX-78 guards and a closed Lupa pen", function()
  local _, _, casa = Encounter()
  assert(#casa._soldiers >= 3 and #casa._soldiers <= 5)
  for _, soldier in ipairs(casa._soldiers) do
    equal(soldier.AnimState.build, "wx78")
    equal(soldier.components.health.maxhealth, 1000)
    equal(soldier.components.inventory.weapon.prefab, "spear")
    equal(soldier.graph, "SGmiles")
    equal(soldier._casa, casa)
  end
  equal(casa._lupa.AnimState.build, "hound_red_ocean")
  equal(casa._lupa.AnimState.bank, "hound")
  equal(casa._lupa.components.combat, nil)
  local walls = {}
  for _, ent in pairs(Ents) do
    if ent.prefab == "wall_stone" then
      local x, z = ent.position.x - casa.position.x, ent.position.z - casa.position.z
      walls[x .. ":" .. z] = ent
      equal(ent.components.health.currenthealth, 400)
    end
  end
  for x = 2, 6 do assert(walls[x .. ":-5"] and walls[x .. ":-1"]) end
  for z = -4, -2 do assert(walls["2:" .. z] and walls["6:" .. z]) end
  for x = -1, 1 do equal(walls[x .. ":7"], nil) end
end)

test("approach plays exactly two lines with Publius then Octavia", function()
  local player, progress, casa = Encounter()
  progress:SetProgress("ch2", 1)
  progress:DialogLoop(player)
  advance(2)
  equal(#speeches, 0)
  player.position = casa.position + Vector3(0, 0, 12)
  advance(2)
  equal(speeches[1].speaker, progress._publius)
  equal(speeches[1].content, DIALOG.ch2[1].content)
  advance(5)
  equal(speeches[2].speaker, player)
  equal(speeches[2].content, DIALOG.ch2[2].content)
  advance(15)
  equal(#speeches, 2)
  equal(progress.dialog, 3)
end)

test("brief entry attacks, then fleeing clears hate and preserves lines three to five", function()
  local player, progress, casa = Encounter()
  progress:SetProgress("ch2", 3)
  player.position = casa.position + Vector3(0, 0, 6)
  advance(.11)
  for _, soldier in ipairs(casa._soldiers) do equal(soldier.components.combat.target, player) end
  equal(progress._casa_entered, true)
  local soldier = casa:GetSoldier()
  soldier.sg.state = "attack"
  player.position = casa.position + Vector3(0, 0, 7.01)
  advance(.11)
  for _, guard in ipairs(casa._soldiers) do equal(guard.components.combat.target, nil) end
  equal(soldier.sg.state, "idle")
  progress:DialogLoop(player)
  equal(speeches[1].speaker, soldier)
  equal(speeches[1].content, DIALOG.ch2[3].content)
  equal(soldier.facing.z, player.position.z)
  advance(10)
  equal(speeches[2].speaker, player)
  equal(speeches[3].speaker, progress._publius)
  equal(speeches[3].content, DIALOG.ch2[5].content)
  equal(progress.dialog, 6)
  advance(30)
  equal(#speeches, 3)
  player.position = casa.position + Vector3(0, 0, 6)
  advance(.11)
  for _, guard in ipairs(casa._soldiers) do equal(guard.components.combat.target, player) end
end)

test("rushing inside preserves approach speech before entry speech", function()
  local player, progress, casa = Encounter()
  progress:SetProgress("ch2", 1)
  player.position = casa.position + Vector3(0, 0, 6)
  progress:DialogLoop(player)
  advance(20)
  equal(#speeches, 5)
  for i = 1, 5 do equal(speeches[i].content, DIALOG.ch2[i].content) end
end)

test("busy soldier can deliver warning and refused speech is retried", function()
  local player, progress, casa = Encounter()
  progress:SetProgress("ch2", 3)
  progress._casa_entered = true
  local guard = casa:GetSoldier()
  guard.busy = true
  guard.components.talker.refuse = true
  progress:DialogLoop(player)
  equal(progress.dialog, 3)
  guard.components.talker.refuse = false
  advance(2)
  equal(progress.dialog, 4)
  equal(speeches[1].speaker, guard)
end)

test("ghosts, loading players, companions, and players outside cannot draw guard hate", function()
  local player, progress, casa = Encounter()
  local guard = casa:GetSoldier()
  player.position = casa.position + Vector3(0, 0, 6)
  player:AddTag("playerghost")
  equal(guard:CanGuardTarget(player), false)
  player.tags.playerghost = nil
  player.loadingprotection = true
  equal(guard:CanGuardTarget(player), false)
  player.loadingprotection = false
  equal(guard:CanGuardTarget(player), true)
  player.position = casa.position + Vector3(0, 0, 7)
  equal(guard:CanGuardTarget(player), false)
  guard.events.attacked(guard, {attacker = player})
  equal(guard.components.combat.target, nil)
  progress._publius.position = casa.position
  equal(guard:CanGuardTarget(progress._publius), false)
end)

test("multiple players keep separate hate when one leaves", function()
  local first, _, casa = Encounter()
  local second = Player("second")
  first.position = casa.position + Vector3(0, 0, 6)
  second.position = casa.position + Vector3(1, 0, 6)
  advance(.11)
  first.position = casa.position + Vector3(0, 0, 8)
  advance(.11)
  for _, guard in ipairs(casa._soldiers) do equal(guard.components.combat.target, second) end
end)

test("reload reuses owned casa and saves guard homes without repopulation", function()
  local player, progress, casa = Encounter()
  progress:SetProgress("ch2", 3)
  progress._casa_entered = true
  local saved = progress:OnSave()
  local _, restored = Player()
  restored:OnLoad(saved)
  equal(restored:EnsureCasa(), casa)
  equal(restored._casa_entered, true)
  local data, newents = {}, {}
  local refs = casa:OnSave(data)
  equal(#refs, #casa._soldiers + 1)
  for _, ent in pairs(Ents) do newents[ent.GUID] = {entity = ent} end
  local loaded = SpawnPrefab("casa")
  loaded:OnLoad(data)
  loaded:OnLoadPostPass(newents, data)
  local before = serial
  advance(0)
  equal(serial, before)
  equal(#loaded._soldiers, #casa._soldiers)
  equal(loaded._lupa, casa._lupa)
  for _, guard in ipairs(loaded._soldiers) do equal(guard._casa, loaded) end
  local guard, guarddata = loaded:GetSoldier(), {}
  guard:OnSave(guarddata)
  local second = SpawnPrefab("miles")
  second:OnLoad(guarddata)
  equal(second._guardpoint.x, guard._guardpoint.x)
  -- A loaded equipped spear survives the deferred equip task.
  local weapon = SpawnPrefab("spear")
  second.components.inventory:Equip(weapon)
  before = serial
  advance(0)
  equal(serial, before)
  equal(second.components.inventory.weapon, weapon)
end)

-- Load the actual game common states when the runner provides them; otherwise
-- the small stand-ins retain the state timeline for the impact-boundary check.
if package.preload["stategraphs/commonstates"] == nil then
  package.preload["stategraphs/commonstates"] = function()
    CommonStates = {AddIdle = noop, AddWalkStates = noop, AddRunStates = noop,
      AddCombatStates = function(states, timelines)
        table.insert(states, {name = "attack", timeline = timelines.attacktimeline})
      end}
    CommonHandlers = {OnLocomote = noop, OnAttack = noop, OnDeath = noop}
  end
end
function State(data) return data end
function EventHandler(event, fn) return {event = event, fn = fn} end
function TimeEvent(time, fn) return {time = time, fn = fn} end
function FrameEvent(frame, fn) return TimeEvent(frame * FRAMES, fn) end
function StateGraph(name, states, events, initial) return {states = states, events = events} end

test("attack impact cannot damage a player after crossing the boundary", function()
  local player, _, casa = Encounter()
  local guard = casa:GetSoldier()
  local graph = dofile("scripts/stategraphs/SGmiles.lua")
  local impact
  for _, state in ipairs(graph.states) do
    if state.name == "attack" then impact = state.timeline[1].fn end
  end
  assert(impact ~= nil)
  guard.sg.statemem.target = player
  player.position = casa.position + Vector3(0, 0, 6)
  guard.components.combat:SetTarget(player)
  impact(guard)
  equal(guard.components.combat.hits, 1)
  player.position = casa.position + Vector3(0, 0, 7.01)
  impact(guard)
  equal(guard.components.combat.hits, 1)
  equal(guard.components.combat.target, nil)
end)

test("client encounter prefabs have visuals and no server-only components", function()
  TheWorld.ismastersim = false
  for _, name in ipairs({"casa", "lupa", "miles"}) do
    local inst = SpawnPrefab(name)
    assert(inst.pristine)
    equal(inst.components.combat, nil)
    equal(inst.components.health, nil)
    equal(inst.components.inventory, nil)
    if name == "miles" then assert(inst.components.talker ~= nil) end
  end
end)

print(count .. " casa encounter tests passed")
