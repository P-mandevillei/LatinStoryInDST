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
TUNING.BOAT = {RADIUS = 4}
TILE_SCALE = 4
EQUIPSLOTS = {HANDS = "hands"}
FRAMES = 1/30
ACTIONS = {HAMMER = "hammer"}
TWOPI = 2 * math.pi
WORLD_TILES = {GRASS = 1, CARPET = 2, SAVANNA = 3, FOREST = 4}
TileGroupManager = {IsLandTile = function() return true end}

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
  function TheWorld.Map:GetSize() return 0, 0 end
  function TheWorld.Map:GetTileCoordsAtPoint(x, y, z) return math.floor(x / 4), math.floor(z / 4) end
  function TheWorld.Map:GetTile() return WORLD_TILES.GRASS end
  function TheWorld.Map:SetTile() end
  function TheWorld.Map:IsLandTileAtPoint() return true end
  function TheWorld.Map:IsDockAtPoint() return false end
  TheSim = {FindEntities = function(_, x, y, z, radius, musttags, excludetags)
    if obstacle and musttags == nil then return {{GetPhysicsRadius = function() return 1 end}} end
    local found = {}
    for _, ent in pairs(Ents) do
      local include = ent:IsValid()
        and (ent.position.x - x)^2 + (ent.position.z - z)^2 <= radius^2
      for _, tag in ipairs(musttags or {}) do include = include and ent:HasTag(tag) end
      for _, tag in ipairs(excludetags or {}) do include = include and not ent:HasTag(tag) end
      if include then table.insert(found, ent) end
    end
    table.sort(found, function(a, b) return a.GUID < b.GUID end)
    return found
  end}
end
function GetTime() return now end
function CanEntitySeeTarget(inst, target) return target.visible ~= false end
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
  function inst:IsInLimbo() return self:HasTag("INLIMBO") end
  function inst:Remove() self.valid = false end
  function inst:GetSaveRecord()
    return {prefab = self.prefab, x = self.position.x, z = self.position.z}
  end
  function inst:HasTag(tag) return self.tags[tag] == true end
  function inst:AddTag(tag) self.tags[tag] = true end
  function inst:RemoveTag(tag) self.tags[tag] = nil end
  function inst:RemoveComponent(name) self.components[name] = nil end
  function inst:SetPrefabName(name) self.prefab = name end
  function inst:SetPrefabNameOverride(name) self.nameoverride = name end
  function inst:GetPosition() return Vector3(self.position:Get()) end
  function inst:GetDistanceSqToPoint(point)
    return (self.position.x-point.x)^2 + (self.position.z-point.z)^2
  end
  function inst:GetCurrentPlatform() return self.platform end
  function inst:GetPhysicsRadius() return self.radius or 0 end
  function inst:IsNear(other, distance)
    return (self.position.x - other.position.x)^2 + (self.position.z - other.position.z)^2 <= distance^2
  end
  function inst:FacePoint(x, y, z) self.facing = Vector3(x, y, z) end
  function inst:ClearBufferedAction() self.cleared = true end
  function inst:ListenForEvent(name, fn) self.events[name] = fn end
  function inst:PushEvent(name, data)
    if self.events[name] ~= nil then self.events[name](self, data) end
  end
  function inst:DoTaskInTime(delay, fn, ...)
    local args, n = {...}, select("#", ...)
    local unpack_args = unpack or table.unpack
    local task = {at = now + delay, fn = function(inst) fn(inst, unpack_args(args, 1, n)) end, inst = self}
    function task:Cancel() self.cancelled = true end
    table.insert(tasks, task)
    return task
  end
  function inst:DoPeriodicTask(period, fn)
    local task = self:DoTaskInTime(period, fn)
    task.period = period
    return task
  end
  inst.entity = setmetatable({_inst = inst, SetParent = function(_, parent) inst.parent = parent._inst end,
    SetPristine = function() inst.pristine = true end,
    GetParent = function() return nil end}, {__index = function() return noop end})
  inst.Transform = {SetFourFaced = noop, SetTwoFaced = noop, SetScale = noop}
  function inst.Transform:GetWorldPosition() return inst.position:Get() end
  function inst.Transform:SetPosition(x, y, z) inst.position = Vector3(x, y, z) end
  inst.Physics = {Teleport = function(_, x, y, z) inst.Transform:SetPosition(x, y, z) end,
    SetVel = function(_, x, y, z) inst.velocity = Vector3(x, y, z) end}
  inst.AnimState = {Hide = noop, Show = noop, OverrideSymbol = noop, PushAnimation = noop,
    AddOverrideBuild = function(self, build) self.overridebuild = build end}
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
    self:AddTag("_" .. name)
    if name == "talker" then
      c.untiltime = 0
      function c:IsTalking() return self.untiltime > now end
      function c:Say(text, duration)
        if self.refuse then return end
        self.untiltime = now + duration
        table.insert(speeches, {speaker = inst, content = text, at = now})
      end
    elseif name == "health" then
      function c:SetMaxHealth(value) self.maxhealth, self.currenthealth = value, value end
      function c:SetPercent(value) self.currenthealth = (self.maxhealth or 100) * value end
      function c:IsDead() return self.currenthealth == 0 end
      function c:IsInvincible() return false end
      function c:DoDelta(amount)
        local before = self.currenthealth
        self.currenthealth = math.max(0, math.min(self.maxhealth, before + amount))
        return self.currenthealth - before
      end
    elseif name == "combat" then
      function c:EnableAreaDamage() end
      function c:SetDefaultDamage(value) self.damage, self.defaultdamage = value, value end
      function c:SetAttackPeriod(value) self.period = value end
      function c:SetRange(value) self.attackrange, self.hitrange = value, value end
      function c:SetKeepTargetFunction(fn) self.keep = fn end
      function c:SetShouldAggroFn(fn) self.shouldaggro = fn end
      function c:CanTarget(target) return target ~= nil and target:IsValid() and not target.untargetable end
      function c:SetTarget(target)
        if target == nil or self.shouldaggro == nil or self.shouldaggro(inst, target) then self.target = target end
      end
      function c:DropTarget() self.target = nil end
      function c:StartAttack() end
      function c:DoAttack(target)
        self.hits = (self.hits or 0) + 1
        local weapon = inst.components.inventory and inst.components.inventory.weapon
        target.components.health:DoDelta(-(weapon and weapon.components.weapon.damage or self.damage))
      end
      function c:CanBeAttacked() return true end
      function c:ShouldRecoil(attacker, weapon, damage) return false, damage end
      function c:GetImpactSound() end
    elseif name == "inventory" then
      function c:GetEquippedItem() return self.weapon end
      function c:Equip(weapon) self.weapon = weapon end
    elseif name == "follower" then
      function c:SetLeader(leader) self.leader = leader end
    elseif name == "locomotor" then
      function c:GetWalkSpeed() return (self.walkspeed or 4) * (self.speedmult or 1) end
      function c:Stop() self.stopped = true end
      function c:GoToPoint(point) self.destination = point end
      function c:SetAllowPlatformHopping(enabled) self.allow_platform_hopping = enabled end
      c.StopMoving = c.Stop
    elseif name == "weapon" then
      function c:SetDamage(value) self.damage = value end
      function c:GetDamage() return self.damage end
      function c:CanRangedAttack() return false end
      function c:OnAttack() end
    elseif name == "workable" then
      function c:SetWorkAction(action) self.action = action end
      function c:SetWorkLeft(amount) self.workleft = amount end
      function c:SetOnFinishCallback(fn) self.onfinish = fn end
      function c:SetOnWorkCallback(fn) self.onwork = fn end
      function c:CanBeWorked() return self.workleft ~= 0 end
      function c:Destroy() inst.destroyed = true; inst:Remove() end
      function c:WorkedBy(worker)
        self.workleft = self.workleft - 1
        if self.workleft > 0 then self.onwork(inst, worker)
        else self.onfinish(inst, worker) end
      end
    elseif name == "inventoryitem" then
      function c:GetGrandOwner() return self.owner end
    end
    return c
  end
  return inst
end
CreateEntity = Entity
function MakeCharacterPhysics(inst, mass, radius) inst.radius = radius end
function MakeObstaclePhysics(inst, radius) inst.radius = radius end
function MakeInventoryPhysics() end
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
    elseif name == "spear" then
      inst:AddComponent("weapon"):SetDamage(TUNING.SPEAR_DAMAGE)
    elseif name == "boat" then
      inst:AddTag("boat")
      inst.components.walkableplatform = {platform_radius = TUNING.BOAT.RADIUS,
        AddEntityToPlatform = function(_, ent) ent.platform = inst end}
      inst.components.hull = {OnDeployed = function() inst.deployed = true end}
      inst.components.boatphysics = {}
    elseif name == "anchor" then
      inst.components.anchor = {raiseunits = 0,
        LoadPostPass = function(self) self.boat = inst.platform end,
        GetCurrentDepth = function() return 4 end}
      function inst.sg:GoToState(state)
        self.state = state
        if state == "lowered" then
          inst.components.anchor.is_anchor_lowered = true
          inst.platform.components.boatphysics.anchored = true
        end
      end
    elseif name == "mast" then
      inst.components.mast = {is_sail_raised = false}
      inst.components.upgradeable = {Upgrade = function(_, lamp)
        inst.lamp_upgraded = true
        lamp:Remove()
        return true
      end}
    elseif name == "steeringwheel" then
      inst.components.steeringwheel = {}
    elseif name == "collapse_small" then
      function inst:SetMaterial(material) self.material = material end
    elseif name == "pigking" then
      inst.components.trader = {onaccept = function() end}
      inst.sg.mem = {}
      function inst:IsMinigameActive() return self.minigame_active == true end
      require("rexanimalium").Setup(inst)
    elseif name == "evergreen" then
      inst:AddTag("tree")
      inst.components.growable = {}
      inst.components.plantregrowth = {}
      inst.components.simplemagicgrower = {}
      inst.components.burnable = {}
      inst.components.propagator = {}
      inst.components.timer = {StopTimer = function(self, timer) self[timer] = nil end}
      inst.OnLoad = function(inst, data)
        if data.burnt then
          inst:AddTag("burnt")
          inst.components.burnable, inst.components.propagator, inst.components.growable = nil, nil, nil
          inst.components.timer.decay = true
        end
      end
      inst.OnEntityWake = function(inst) inst.components.timer.decay = true end
    end
  end
  inst.prefab = name
  return inst
end

function SpawnSaveRecord(data)
  local inst = SpawnPrefab(data.prefab)
  inst.Transform:SetPosition(data.x, 0, data.z)
  return inst
end

package.loaded["brains/milesbrain"] = {}
package.loaded["brains/agricolabrain"] = {}
package.loaded["brains/senexbrain"] = {}
package.loaded["brains/passerbrain"] = {ForceUpdate = noop}
local plant_defs = {}
for _, crop in ipairs({"carrot", "corn", "potato", "tomato", "pumpkin"}) do
  plant_defs[crop] = {bank = "farm_plant_" .. crop, build = "farm_plant_" .. crop}
end
package.loaded["prefabs/farm_plant_defs"] = {PLANT_DEFS = plant_defs}
local HELPERS = require("helpers")
local DIALOG = require("libellus")
local Progress = require("components/libellusprogress")
Prefabs = {evergreen = {fn = function() return SpawnPrefab("evergreen") end}}
for _, name in ipairs({"casa", "lupa", "miles", "agricola", "agricola_crop", "agricola_farm", "navis", "senex",
  "passer", "passer_grove", "passer_burnt_tree", "passer_free", "rex_voice"}) do
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
  p:AddComponent("combat")
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
    equal(soldier.components.combat.damage, 25)
    equal(soldier.components.inventory.weapon.prefab, "spear")
    equal(soldier.components.inventory.weapon.components.weapon.damage, 25)
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

local function enter(player, casa)
  player.position = casa.position + Vector3(0, 0, 6)
end

local function leave(player, casa)
  player.position = casa.position + Vector3(0, 0, 8)
end

test("each guard independently picks a warning while the player speaks line five", function()
  local player, progress, casa = Encounter()
  progress:SetProgress("ch2", 3)
  leave(player, casa)
  progress:DialogLoop(player)
  advance(2)
  equal(#speeches, 0)
  player.busy, progress._publius.busy = true, true
  local random, choices = math.random, 0
  math.random = function(low, high)
    equal(low, 3)
    equal(high, 4)
    choices = choices + 1
    return 3 + choices % 2
  end
  enter(player, casa)
  advance(.11)
  math.random = random
  equal(choices, #casa._soldiers)
  equal(#speeches, #casa._soldiers + 1)
  for i, soldier in ipairs(casa._soldiers) do
    equal(speeches[i].speaker, soldier)
    equal(speeches[i].content, DIALOG.ch2[3 + i % 2].content)
    equal(speeches[i].at, speeches[1].at)
    equal(soldier.facing.z, player.position.z)
  end
  equal(speeches[#speeches].speaker, player)
  equal(speeches[#speeches].content, DIALOG.ch2[5].content)
  equal(speeches[#speeches].at, speeches[1].at)
  equal(progress.dialog, 3)
  leave(player, casa)
  advance(4.8)
  equal(progress.dialog, 3)
  advance(.3)
  equal(progress.dialog, 6)
end)

test("entry ignores story position and does not advance unfinished approach", function()
  for _, position in ipairs({{"ch1", 1}, {"ch2", 1}, {"ch2", 2}, {"ch2", 7}}) do
    reset()
    local player, progress, casa = Encounter()
    progress:SetProgress(position[1], position[2])
    player.busy, progress._publius.busy = true, true
    enter(player, casa)
    progress:DialogLoop(player)
    equal(#speeches, #casa._soldiers + 1)
    advance(6)
    equal(progress.chapter, position[1])
    equal(progress.dialog, position[2])
  end
end)

test("completion checks live progress and preserves newer events", function()
  for _, position in ipairs({{"ch2", 3}, {"ch2", 2}, {"ch2", 7}, {"ch1", 8}}) do
    reset()
    local player, progress, casa = Encounter()
    progress:SetProgress("ch2", 1)
    enter(player, casa)
    progress:DialogLoop(player)
    advance(2)
    progress:SetProgress(position[1], position[2])
    player.busy, progress._publius.busy = true, true
    advance(3.1)
    equal(progress.chapter, position[1])
    equal(progress.dialog, position[2] == 3 and 6 or position[2])
  end
end)

test("entry repeats once per crossing and reentry restarts the completion timer", function()
  local player, progress, casa = Encounter()
  progress:SetProgress("ch2", 3)
  enter(player, casa)
  progress:DialogLoop(player)
  local exchange_count = #casa._soldiers + 1
  advance(2)
  equal(#speeches, exchange_count)
  leave(player, casa)
  advance(.11)
  enter(player, casa)
  advance(.11)
  equal(#speeches, exchange_count * 2)
  advance(3)
  equal(progress.dialog, 3)
  advance(2.1)
  equal(progress.dialog, 6)
  advance(65)
  local warnings = 0
  for _, speech in ipairs(speeches) do
    if speech.speaker == player then warnings = warnings + 1 end
  end
  equal(warnings, 2)
  leave(player, casa)
  advance(.11)
  enter(player, casa)
  advance(.11)
  equal(speeches[#speeches].content, DIALOG.ch2[5].content)
end)

test("entering before approach requires another entry after lines one and two", function()
  local player, progress, casa = Encounter()
  progress:SetProgress("ch2", 1)
  enter(player, casa)
  progress:DialogLoop(player)
  advance(20)
  equal(progress.dialog, 3)
  equal(speeches[#casa._soldiers + 2].content, DIALOG.ch2[1].content)
  equal(speeches[#casa._soldiers + 3].content, DIALOG.ch2[2].content)
  leave(player, casa)
  advance(.11)
  enter(player, casa)
  advance(5.2)
  equal(progress.dialog, 6)
end)

test("Publius repeats line six indefinitely until progress changes", function()
  local player, progress = Encounter()
  progress:SetProgress("ch2", 6)
  progress:DialogLoop(player)
  advance(95)
  assert(#speeches >= 4)
  for i, speech in ipairs(speeches) do
    equal(speech.speaker, progress._publius)
    equal(speech.content, DIALOG.ch2[6].content)
    if i > 1 then
      assert(speech.at >= speeches[i - 1].at + HELPERS.DIALOG_INTERVAL + HELPERS.REPEAT_INTERVAL)
    end
  end
  equal(progress.dialog, 6)
  local before = #speeches
  progress:SetProgress("ch2", 7)
  advance(65)
  equal(#speeches, before)
end)

test("entry interrupts ongoing dialogue without waiting for its next scheduled line", function()
  local player, progress, casa = Encounter()
  progress:SetProgress("ch2", 1)
  leave(player, casa)
  progress:DialogLoop(player)
  equal(speeches[1].content, DIALOG.ch2[1].content)
  equal(progress.dialog, 2)
  enter(player, casa)
  advance(.11)
  equal(#speeches, #casa._soldiers + 2)
  equal(speeches[#speeches].content, DIALOG.ch2[5].content)
  advance(5.1)
  equal(progress.dialog, 2)
  advance(10)
  equal(progress.dialog, 3)
  equal(speeches[#speeches].content, DIALOG.ch2[2].content)
end)

test("saved entry positions wait for a fresh crossing", function()
  for _, dialog in ipairs({3, 4, 5}) do
    reset()
    local _, progress, casa = Encounter()
    progress:SetProgress("ch2", dialog)
    local _, restored = Player()
    restored:OnLoad(progress:OnSave())
    restored:DialogLoop(restored.inst)
    advance(6)
    equal(#speeches, 0)
    equal(restored.dialog, dialog)
    enter(restored.inst, casa)
    advance(5.2)
    equal(restored.dialog, 6)
  end
end)

test("dead and removed soldiers do not speak on entry", function()
  local player, progress, casa = Encounter()
  progress:SetProgress("ch2", 3)
  casa._soldiers[1].components.health:SetPercent(0)
  casa._soldiers[2]:Remove()
  enter(player, casa)
  progress:DialogLoop(player)
  equal(#speeches, #casa._soldiers - 1)
end)

test("ghosts, loading players, untargetable companions, and players outside cannot draw guard hate", function()
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

test("guards attack animals and monsters inside, excluding Lupa, allies, and walls", function()
  local _, _, casa = Encounter()
  local animal = SpawnPrefab("rabbit")
  animal:AddComponent("health"):SetMaxHealth(100)
  animal:AddComponent("combat")
  animal.position = casa.position + Vector3(0, 0, 5)
  advance(.11)
  for _, guard in ipairs(casa._soldiers) do equal(guard.components.combat.target, animal) end
  animal.position = casa.position + Vector3(0, 0, 8)
  local monster = SpawnPrefab("spider")
  monster:AddComponent("health"):SetMaxHealth(100)
  monster:AddComponent("combat")
  monster.position = casa.position + Vector3(1, 0, 5)
  advance(.11)
  for _, guard in ipairs(casa._soldiers) do equal(guard.components.combat.target, monster) end
  -- Exclusion must hold even if Lupa gains combat components later.
  casa._lupa:AddComponent("health"):SetMaxHealth(100)
  casa._lupa:AddComponent("combat")
  local guard = casa:GetSoldier()
  equal(guard:CanGuardTarget(casa._lupa), false)
  for _, ally in ipairs(casa._soldiers) do equal(guard:CanGuardTarget(ally), false) end
  local wall = SpawnPrefab("wall_stone")
  wall:AddTag("wall")
  wall:AddComponent("combat")
  wall.position = casa.position + Vector3(0, 0, 5)
  equal(guard:CanGuardTarget(wall), false)
  monster.components.health:SetPercent(0)
  advance(.11)
  for _, soldier in ipairs(casa._soldiers) do equal(soldier.components.combat.target, nil) end
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
  local saved = progress:OnSave()
  local _, restored = Player()
  restored:OnLoad(saved)
  equal(restored:EnsureCasa(), casa)
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
  equal(weapon.components.weapon.damage, 25)
end)

-- Load the actual game common states when the runner provides them; otherwise
-- the small stand-ins retain the state timeline for the impact-boundary check.
if package.preload["stategraphs/commonstates"] == nil then
  package.preload["stategraphs/commonstates"] = function()
    CommonStates = {AddIdle = noop, AddWalkStates = noop, AddRunStates = noop,
      AddCombatStates = function(states, timelines)
        table.insert(states, {name = "attack", timeline = timelines.attacktimeline,
          onenter = function(inst, target) inst.sg.statemem.target = target end})
      end}
    CommonHandlers = {OnLocomote = function() return {} end,
      OnAttack = function() return {} end, OnDeath = function() return {} end}
  end
end
function State(data) return data end
function EventHandler(event, fn) return {event = event, fn = fn} end
function TimeEvent(time, fn) return {time = time, fn = fn} end
function FrameEvent(frame, fn) return TimeEvent(frame * FRAMES, fn) end
function StateGraph(name, states, events, initial) return {states = states, events = events} end

test("attack event passes the target to the state and deals 25 health damage", function()
  local player, _, casa = Encounter()
  local guard = casa:GetSoldier()
  local graph = dofile("scripts/stategraphs/SGmiles.lua")
  local attack, handler
  for _, state in ipairs(graph.states) do
    if state.name == "attack" then attack = state end
  end
  for _, event in ipairs(graph.events) do
    if event.event == "doattack" then handler = event.fn end
  end
  assert(attack ~= nil and handler ~= nil)
  function guard.sg:GoToState(state, data)
    self.state, self.statemem = state, {}
    if state == "attack" then attack.onenter(guard, data) end
  end
  player.position = guard.position + Vector3(0, 0, 1)
  guard.components.combat:SetTarget(player)
  handler(guard, {target = player})
  equal(guard.sg.statemem.target, player)
  attack.timeline[1].fn(guard)
  equal(guard.components.combat.hits, 1)
  equal(player.components.health.currenthealth, 125)
  player.position = casa.position + Vector3(0, 0, 7.01)
  attack.timeline[1].fn(guard)
  equal(guard.components.combat.hits, 1)
  equal(player.components.health.currenthealth, 125)
  equal(guard.components.combat.target, nil)
end)

-- The external runner can preload these methods from the installed game's
-- scripts.zip to verify weapon calculation and health damage through DST code.
if package.preload["components/gamecombat"] ~= nil then
  test("DST combat applies 25 health damage with a spear and while unarmed", function()
    local player, _, casa = Encounter()
    local guard = casa:GetSoldier()
    local Combat = require("components/gamecombat")
    local combat = guard.components.combat
    combat.inst = guard
    combat.externaldamagemultipliers = {Get = function() return 1 end}
    for _, method in ipairs({"DoAttack", "CalcDamage", "GetWeapon", "CanHitTarget",
      "CalcHitRangeSq", "GetHitRange", "CanExtinguishTarget", "CanLightTarget",
      "CalcReflectedDamage", "ClearAttackTemps"}) do
      combat[method] = Combat[method]
    end
    local defender = player.components.combat
    defender.inst = player
    defender.GetAttacked_Internal = Combat.GetAttacked_Internal
    defender.externaldamagetakenmultipliers = {Get = function() return 1 end}
    function CanApplyPlayerDamageMod(target) return target:HasTag("player") end
    function IsRangedWeapon() return false end

    local graph = dofile("scripts/stategraphs/SGmiles.lua")
    local attack, handler
    for _, state in ipairs(graph.states) do
      if state.name == "attack" then attack = state end
    end
    for _, event in ipairs(graph.events) do
      if event.event == "doattack" then handler = event.fn end
    end
    function guard.sg:GoToState(state, data)
      self.state, self.statemem = state, {}
      if state == "attack" then attack.onenter(guard, data) end
    end
    player.position = guard.position + Vector3(0, 0, 1)
    combat:SetTarget(player)
    handler(guard, {target = player})
    attack.timeline[1].fn(guard)
    equal(player.components.health.currenthealth, 125)
    guard.components.inventory.weapon = nil
    handler(guard, {target = player})
    attack.timeline[1].fn(guard)
    equal(player.components.health.currenthealth, 100)
    player.position = casa.position + Vector3(0, 0, 7.01)
    attack.timeline[1].fn(guard)
    equal(player.components.health.currenthealth, 100)
  end)
end

local function FarmEncounter()
  local player, progress, casa = Encounter()
  local farm = SpawnPrefab("agricola_farm")
  farm.Transform:SetPosition(100, 0, 100)
  farm._libellus_owneruserid = player.userid
  progress._farm = farm
  advance(0)
  return player, progress, casa, farm
end

test("farm has nine tilled plots, random occupied plots, and a Woodie farmer", function()
  local _, _, _, farm = FarmEncounter()
  equal(#farm._soil, 9)
  assert(#farm._crops >= 5 and #farm._crops <= 8)
  local cells = {}
  for _, crop in ipairs(farm._crops) do
    assert(math.abs(crop.position.x - 100) <= 4.5 and math.abs(crop.position.z - 100) <= 4.5)
    local cell = crop.position.x .. ":" .. crop.position.z
    equal(cells[cell], nil)
    cells[cell] = true
    assert(plant_defs[crop._crop] ~= nil)
    equal(crop.components.inventory, nil)
  end
  equal(farm._agricola._farm, farm)
  equal(farm._agricola.AnimState.build, "woodie")
  equal(farm._agricola.graph, "SGagricola")
  equal(farm._agricola.components.inventory, nil)
end)

test("farm placement randomizes within the closest suitable connected savanna", function()
  local map = TheWorld.Map
  function map:GetSize() return 30, 12 end
  function map:GetTile(x, z)
    return ((x >= 2 and x <= 8) or (x >= 20 and x <= 26))
      and z >= 2 and z <= 8 and WORLD_TILES.SAVANNA or WORLD_TILES.GRASS
  end
  function map:GetTileCenterPoint(x, z) return x * 4, 0, z * 4 end
  function map:GetTileAtPoint(x, y, z) return self:GetTile(math.floor(x / 4 + .5), math.floor(z / 4 + .5)) end
  local original = math.random
  local choices = 0
  math.random = function(n) choices = choices + 1; return original(n) end
  local point = HELPERS.FindFarmSpawnPoint(Vector3(0, 0, 0))
  math.random = original
  assert(point ~= nil and point.x < 40)
  assert(choices > 0)
  function map:IsPointNearHole() return true end
  equal(HELPERS.FindFarmSpawnPoint(Vector3(0, 0, 0)), nil)
end)

test("farm retries use the original spawn and reconnects reuse the owned farm", function()
  local player, progress = Player()
  local search, origins = HELPERS.FindFarmSpawnPoint, {}
  HELPERS.FindFarmSpawnPoint = function(origin)
    table.insert(origins, origin)
    return #origins > 1 and Vector3(100, 0, 100) or nil
  end
  equal(progress:EnsureFarm(), nil)
  player.position = Vector3(250, 0, 250)
  equal(progress:EnsureFarm(), nil)
  now = HELPERS.FARM_SPAWN_RETRY_INTERVAL
  local farm = progress:EnsureFarm()
  HELPERS.FindFarmSpawnPoint = search
  equal(origins[2].x, 0)
  equal(farm.position.x, 100)
  local _, restored = Player()
  restored:OnLoad(progress:OnSave())
  equal(restored:EnsureFarm(), farm)
  local _, other = Player("other")
  equal(other:EnsureFarm(), nil)
  cave = true
  local _, underground = Player()
  equal(underground:EnsureFarm(), nil)
end)

test("farmer proximity interrupts line six and plays seven through thirteen before cleanup", function()
  local player, progress, casa, farm = FarmEncounter()
  progress:SetProgress("ch2", 6)
  player.position = farm._agricola.position + Vector3(0, 0, 5.01)
  progress:DialogLoop(player)
  equal(speeches[1].content, DIALOG.ch2[6].content)
  advance(6)
  player.position = farm._agricola.position + Vector3(0, 0, 5)
  advance(2)
  equal(speeches[2].content, DIALOG.ch2[7].content)
  advance(30)
  equal(speeches[8].content, DIALOG.ch2[13].content)
  equal(progress.chapter, "ch2")
  equal(progress.dialog, 13)
  assert(casa._lupa:IsValid())
  local guards, lupa = casa._soldiers, casa._lupa
  local walls = {}
  for _, ent in pairs(Ents) do
    if ent.prefab == "wall_stone" then table.insert(walls, ent) end
  end
  advance(5)
  equal(progress.chapter, "ch3")
  equal(progress.dialog, 1)
  equal(casa._lupa, nil)
  equal(lupa:IsValid(), false)
  for _, guard in ipairs(guards) do equal(guard:IsValid(), false) end
  equal(#casa._soldiers, 0)
  equal(casa:IsValid(), true)
  assert(#walls > 0)
  for _, wall in ipairs(walls) do equal(wall:IsValid(), true) end
  equal(progress:OnSave().casa_cleared, true)
  for i = 7, 13 do
    equal(speeches[i - 5].content, DIALOG.ch2[i].content)
    equal(speeches[i - 5].speaker, DIALOG.ch2[i].name == "Agricola" and farm._agricola or player)
  end
  advance(40)
  equal(#speeches, 8)
end)

test("farmer conversation pauses outside range and resumes from saved progress", function()
  local player, progress, _, farm = FarmEncounter()
  progress:SetProgress("ch2", 9)
  player.position = farm._agricola.position
  farm._agricola.busy = true
  progress:DialogLoop(player)
  equal(#speeches, 0)
  farm._agricola.busy = false
  advance(2)
  equal(progress.dialog, 10)
  player.position = Vector3(200, 0, 200)
  advance(10)
  equal(#speeches, 1)
  local arriving, restored = Player()
  restored:OnLoad(progress:OnSave())
  arriving.position = farm._agricola.position
  restored:DialogLoop(arriving)
  equal(speeches[2].content, DIALOG.ch2[10].content)
end)

test("newer story events cancel farmer completion and casa cleanup", function()
  local player, progress, casa, farm = FarmEncounter()
  progress:SetProgress("ch2", 13)
  player.position = farm._agricola.position
  progress:DialogLoop(player)
  progress:SetProgress("ch2", 1)
  advance(5.1)
  equal(progress.chapter, "ch2")
  equal(progress.dialog, 1)
  equal(casa._encounter_cleared, nil)
  assert(casa._lupa:IsValid())
end)

test("farm references and crop appearances survive loading without repopulation", function()
  local _, _, _, farm = FarmEncounter()
  local data, ents = {}, {}
  local refs = farm:OnSave(data)
  equal(#refs, 10 + #farm._crops)
  for _, ent in pairs(Ents) do ents[ent.GUID] = {entity = ent} end
  local loaded = SpawnPrefab("agricola_farm")
  loaded:OnLoad(data)
  loaded:OnLoadPostPass(ents, data)
  local before = serial
  advance(0)
  equal(serial, before)
  equal(#loaded._crops, #farm._crops)
  equal(#loaded._soil, 9)
  equal(loaded._agricola, farm._agricola)
  equal(loaded._agricola._farm, loaded)
  local crop, cropdata = farm._crops[1], {}
  crop:OnSave(cropdata)
  local newcrop = SpawnPrefab("agricola_crop")
  newcrop:OnLoad(cropdata)
  advance(0)
  equal(newcrop._crop, crop._crop)
  equal(newcrop._ripe, crop._ripe)
end)

test("casa cleanup persists and also prevents deferred occupants from spawning", function()
  local _, progress, casa = Encounter()
  casa:ClearEncounter()
  local data = {}
  casa:OnSave(data)
  local loaded = SpawnPrefab("casa")
  loaded:OnLoad(data)
  loaded:OnLoadPostPass({}, data)
  advance(0)
  equal(loaded._encounter_cleared, true)
  equal(#loaded._soldiers, 0)
  equal(loaded._lupa, nil)
  local fresh = SpawnPrefab("casa")
  fresh:ClearEncounter()
  advance(0)
  equal(#fresh._soldiers, 0)
  equal(fresh._lupa, nil)
  progress._casa_cleared = true
  progress:SetProgress("ch3", 1)
  local player, restored = Player()
  restored:OnLoad(progress:OnSave())
  player.position = casa.position
  restored:DialogLoop(player)
  equal(#speeches, 0)
end)

test("farmer work animations tend and harvest without producing items", function()
  local _, _, _, farm = FarmEncounter()
  local farmer, crop = farm._agricola, farm._crops[1]
  local graph = dofile("scripts/stategraphs/SGagricola.lua")
  function farmer.sg:SetTimeout(seconds) self.timeout = seconds end
  for _, state in ipairs(graph.states) do
    if state.name == "tend" or state.name == "harvest" then
      state.onenter(farmer, crop)
      assert(farmer.sg.timeout > 0)
      state.ontimeout(farmer)
      equal(crop._ripe, state.name == "tend")
      equal(farmer.sg.state, "idle")
      equal(farmer.components.inventory, nil)
    end
  end
end)

test("farmer brain moves to crops and pauses its work for conversations", function()
  BehaviourNode = Class(function() end)
  function BehaviourNode:Sleep() end
  Brain = Class(function(self, inst) self.inst = inst end)
  function BT(inst, node) return {root = node} end
  local FarmerBrain = dofile("scripts/brains/agricolabrain.lua")
  local _, _, _, farm = FarmEncounter()
  local farmer = farm._agricola
  local brain = FarmerBrain(farmer)
  brain:OnStart()
  local work = brain.bt.root
  work:Visit()
  assert(farmer.components.locomotor.destination ~= nil)
  farmer.position = work.target.position
  work:Visit()
  assert(farmer.sg.state == "tend" or farmer.sg.state == "harvest")
  farmer.sg.state = "idle"
  farmer._conversation_until = now + 5
  farmer.components.locomotor.destination = nil
  work:Visit()
  equal(farmer.components.locomotor.destination, nil)
  equal(farmer.components.locomotor.stopped, true)
end)

local function ShipEncounter()
  local player, progress = Player()
  progress:EnsurePublius()
  local navis = SpawnPrefab("navis")
  navis.Transform:SetPosition(100, 0, 100)
  navis._libellus_owneruserid = player.userid
  progress._navis = navis
  advance(0)
  return player, progress, navis, navis._ship, navis._senex
end

test("navis equips a native wooden boat with fittings, light, and a lowered anchor", function()
  local _, _, navis, ship, senex = ShipEncounter()
  equal(ship.prefab, "boat")
  equal(ship.deployed, true)
  equal(navis._wheel.prefab, "steeringwheel")
  equal(navis._mast.prefab, "mast")
  equal(navis._mast.lamp_upgraded, true)
  equal(navis._mast.components.mast.is_sail_raised, false)
  equal(navis._anchor.prefab, "anchor")
  equal(navis._anchor.components.anchor.boat, ship)
  equal(navis._anchor.components.anchor.is_anchor_lowered, true)
  equal(ship.components.boatphysics.anchored, true)
  for _, ent in ipairs({navis._wheel, navis._mast, navis._anchor, senex}) do
    equal(ent:GetCurrentPlatform(), ship)
    assert(ent:IsNear(ship, TUNING.BOAT.RADIUS - .5))
  end
  equal(senex.AnimState.build, "wolfgang")
  equal(senex.components.health.maxhealth, 1000)
  equal(senex.components.inventory.weapon.prefab, "spear")
  equal(senex.components.inventory.weapon.components.weapon.damage, 25)
  equal(senex.components.locomotor.allow_platform_hopping, false)
end)

test("navis search selects nearby ocean and rejects hull overlap with land or boats", function()
  local map = TheWorld.Map
  function map:GetSize() return 80, 80 end
  function map:IsOceanAtPoint(x, y, z) return x > 30 end
  local point = HELPERS.FindNavisSpawnPoint(Vector3(0, 0, 0))
  assert(point ~= nil and point.x > 30 + TUNING.BOAT.RADIUS)
  assert(point.x * point.x + point.z * point.z <= 44^2 + .01)
  function map:IsOceanAtPoint() return false end
  equal(HELPERS.FindNavisSpawnPoint(Vector3(0, 0, 0)), nil)
  function map:IsOceanAtPoint() return true end
  local stack = SpawnPrefab("seastack")
  stack.radius = 5
  local simsearch = TheSim.FindEntities
  TheSim.FindEntities = function() return {stack} end
  equal(HELPERS.FindNavisSpawnPoint(Vector3(0, 0, 0)), nil)
  TheSim.FindEntities = simsearch
end)

test("navis retries from the original spawn, reuses owned encounters, and excludes caves", function()
  local player, progress = Player()
  local search, origins = HELPERS.FindNavisSpawnPoint, {}
  HELPERS.FindNavisSpawnPoint = function(origin)
    table.insert(origins, origin)
    return #origins > 1 and Vector3(100, 0, 100) or nil
  end
  equal(progress:EnsureNavis(), nil)
  player.position = Vector3(500, 0, 500)
  equal(progress:EnsureNavis(), nil)
  now = HELPERS.NAVIS_SPAWN_RETRY_INTERVAL
  local navis = progress:EnsureNavis()
  HELPERS.FindNavisSpawnPoint = search
  equal(origins[2].x, 0)
  local _, restored = Player()
  restored:OnLoad(progress:OnSave())
  equal(restored:EnsureNavis(), navis)
  local _, other = Player("other")
  equal(other:EnsureNavis(), nil)
  cave = true
  local _, underground = Player()
  equal(underground:EnsureNavis(), nil)
end)

test("ship sighting says line one once and waits until near for lines two through eight", function()
  local player, progress, _, ship, senex = ShipEncounter()
  progress:SetProgress("ch3", 1)
  player.position = ship.position + Vector3(0, 0, HELPERS.NAVIS_SEE_DISTANCE + .01)
  progress:DialogLoop(player)
  advance(2)
  equal(#speeches, 0)
  player.position = ship.position + Vector3(0, 0, HELPERS.NAVIS_SEE_DISTANCE)
  ship.visible = false
  advance(2)
  equal(#speeches, 0)
  ship.visible = true
  advance(2)
  equal(speeches[1].content, DIALOG.ch3[1].content)
  equal(speeches[1].speaker, player)
  equal(progress.dialog, 2)
  advance(10)
  equal(#speeches, 1)
  player.position = ship.position + Vector3(0, 0, HELPERS.NAVIS_NEAR_DISTANCE)
  player.busy, senex.busy = true, true
  advance(36)
  equal(progress.chapter, "ch3")
  equal(progress.dialog, 9)
  equal(#speeches, 8)
  for i, speech in ipairs(speeches) do
    equal(speech.content, DIALOG.ch3[i].content)
    equal(speech.speaker, DIALOG.ch3[i].name == "Senex" and senex or player)
    if i > 1 then assert(speech.at >= speeches[i - 1].at + HELPERS.DIALOG_INTERVAL) end
  end
  player.busy, senex.busy = false, false
  advance(25)
  equal(#speeches, 10)
  equal(speeches[9].content, DIALOG.ch3[9].content)
  equal(speeches[10].content, DIALOG.ch3[10].content)
end)

test("ship conversation pauses out of range and retries refused Senex speech", function()
  local player, progress, _, ship, senex = ShipEncounter()
  progress:SetProgress("ch3", 3)
  player.position = ship.position
  senex.components.talker.refuse = true
  progress:DialogLoop(player)
  advance(2)
  equal(progress.dialog, 3)
  equal(#speeches, 0)
  senex.components.talker.refuse = false
  advance(2)
  equal(progress.dialog, 4)
  player.position = Vector3(300, 0, 300)
  advance(8)
  equal(#speeches, 1)
  player.position = ship.position
  advance(2)
  equal(speeches[2].content, DIALOG.ch3[4].content)
end)

test("Senex only targets living players on his own ship and switches when they leave", function()
  local first, _, _, ship, senex = ShipEncounter()
  first.position = ship.position
  advance(.11)
  equal(senex.components.combat.target, nil)
  ship.components.walkableplatform:AddEntityToPlatform(first)
  advance(.11)
  equal(senex.components.combat.target, first)
  local second = Player("second")
  ship.components.walkableplatform:AddEntityToPlatform(second)
  first.platform = nil
  advance(.11)
  equal(senex.components.combat.target, second)
  second.tags.playerghost = true
  advance(.11)
  equal(senex.components.combat.target, nil)
  second.tags.playerghost = nil
  second.loadingprotection = true
  equal(senex:CanGuardTarget(second), false)
  second.loadingprotection = false
  second.components.health:SetPercent(0)
  equal(senex:CanGuardTarget(second), false)
  local companion = SpawnPrefab("publius")
  ship.components.walkableplatform:AddEntityToPlatform(companion)
  equal(senex:CanGuardTarget(companion), false)
end)

test("Senex deals twenty-five per spear hit and rechecks boarding at impact", function()
  local player, _, _, ship, senex = ShipEncounter()
  ship.components.walkableplatform:AddEntityToPlatform(player)
  local graph = dofile("scripts/stategraphs/SGsenex.lua")
  local attack, handler
  for _, state in ipairs(graph.states) do if state.name == "attack" then attack = state end end
  for _, event in ipairs(graph.events) do if event.event == "doattack" then handler = event.fn end end
  function senex.sg:GoToState(state, data)
    self.state, self.statemem = state, {}
    if state == "attack" then attack.onenter(senex, data) end
  end
  senex.components.combat:SetTarget(player)
  handler(senex, {target = player})
  attack.timeline[1].fn(senex)
  equal(player.components.health.currenthealth, 125)
  attack.timeline[1].fn(senex)
  equal(player.components.health.currenthealth, 100)
  player.platform = nil
  attack.timeline[1].fn(senex)
  equal(player.components.health.currenthealth, 100)
  equal(senex.components.combat.target, nil)
end)

test("navis restores the moved ship and fittings without duplicating or lowering an anchor again", function()
  local _, progress, navis, ship, senex = ShipEncounter()
  local data, ents = {}, {}
  navis:OnSave(data)
  ship.Transform:SetPosition(500, 0, 400)
  navis._anchor.sg.state = "raised"
  navis._anchor.components.anchor.is_anchor_lowered = false
  for _, ent in pairs(Ents) do ents[ent.GUID] = {entity = ent} end
  local loaded = SpawnPrefab("navis")
  loaded:OnLoad(data)
  loaded:OnLoadPostPass(ents, data)
  local before = serial
  advance(0)
  equal(serial, before)
  equal(loaded._ship, ship)
  equal(loaded._anchor.sg.state, "raised")
  equal(loaded._anchor.components.anchor.is_anchor_lowered, false)
  equal(loaded._senex._ship, ship)
  progress._navis = loaded
  equal(progress:GetShip().position.x, 500)
  local senexdata = {}
  senex:OnSave(senexdata)
  local restored = SpawnPrefab("senex")
  restored:OnLoadPostPass(ents, senexdata)
  equal(restored._ship, ship)
  restored.components.inventory:Equip(senex.components.inventory.weapon)
  before = serial
  advance(0)
  equal(serial, before)
end)

test("Senex brain follows the moving deck and recovers aboard instead of chasing ashore", function()
  for _, name in ipairs({"chaseandattack", "leash", "standstill"}) do
    package.loaded["behaviours/" .. name] = {}
  end
  Brain = Class(function(self, inst) self.inst = inst end)
  function BT(inst, node) return {root = node} end
  function PriorityNode(nodes) return {children = nodes} end
  function ConditionNode(fn) return {fn = fn} end
  function ChaseAndAttack() return {} end
  function Leash(inst, home) return {home = home} end
  function StandStill() return {} end
  local SenexBrain = dofile("scripts/brains/senexbrain.lua")
  local _, _, _, ship, senex = ShipEncounter()
  local brain = SenexBrain(senex)
  brain:OnStart()
  equal(brain.bt.root.children[1].fn(), false)
  ship.Transform:SetPosition(500, 0, 400)
  equal(brain.bt.root.children[3].home().x, 500)
  senex.platform = nil
  equal(brain.bt.root.children[1].fn(), true)
  equal(senex:GetCurrentPlatform(), ship)
  equal(senex.position.x, 502)
  equal(senex.position.z, 400)
end)

local function PasserEncounter()
  local player, progress = Player()
  progress:EnsurePublius()
  function TheWorld.Map:GetTileAtPoint() return WORLD_TILES.FOREST end
  local grove = SpawnPrefab("passer_grove")
  grove.Transform:SetPosition(100, 0, 100)
  grove._libellus_owneruserid = player.userid
  grove._grove_dx, grove._grove_dz = 0, 1
  progress._passer_grove = grove
  advance(0)
  return player, progress, grove, grove._passer
end

test("Passer uses native occupied-cage and bird visuals with eighty-one stable burnt trees behind", function()
  local _, _, grove, passer = PasserEncounter()
  equal(passer.AnimState.bank, "birdcage")
  equal(passer.AnimState.build, "bird_cage")
  equal(passer.AnimState.overridebuild, "robin_build")
  equal(passer.AnimState.animation, "idle_bird")
  equal(#grove._trees, 81)
  local direct = factories.passer_burnt_tree()
  equal(direct:GetSaveRecord().prefab, "passer_burnt_tree")
  local center = HELPERS.GetPasserClearing(passer.position, 0, 1)
  for _, tree in ipairs(grove._trees) do
    equal(tree:HasTag("burnt"), true)
    equal(tree.components.burnable, nil)
    equal(tree.components.propagator, nil)
    equal(tree.components.plantregrowth, nil)
    equal(tree.components.timer.decay, nil)
    assert(math.abs(tree.position.x-center.x) < 13.5 and math.abs(tree.position.z-center.z) < 13.5)
    assert(tree.position.z > passer.position.z + HELPERS.PASSER_FIREBREAK)
    tree:OnLoad({burnt = true})
    equal(tree.components.timer.decay, nil)
    tree:OnEntityWake()
    equal(tree.components.timer.decay, nil)
    equal(tree.burntcone, true)
    equal(tree.prefab, "passer_burnt_tree")
  end
end)

test("Passer clearing removes resources throughout the grove and firebreak and preserves its outside", function()
  local grove = SpawnPrefab("passer_grove")
  grove.Transform:SetPosition(100, 0, 100)
  grove._grove_dx, grove._grove_dz = 0, 1
  function TheWorld.Map:GetTileAtPoint() return WORLD_TILES.FOREST end
  local center = HELPERS.GetPasserClearing(grove.position, 0, 1)
  local inner, margin, outside = SpawnPrefab("grass"), SpawnPrefab("sapling"), SpawnPrefab("grass")
  inner:AddTag("grass"); margin:AddTag("sapling"); outside:AddTag("grass")
  inner.position = center
  margin.position = center + Vector3(20, 0, 0)
  outside.position = center + Vector3(30, 0, 0)
  advance(0)
  equal(inner:IsValid(), false)
  equal(margin:IsValid(), false)
  equal(outside:IsValid(), true)
  equal(#grove._trees, 81)
  for _, ent in ipairs(HELPERS.GetPasserClearingEntities(center)) do
    equal(ent.prefab, "passer_burnt_tree")
  end
end)

test("Passer placement rejects bases, story encounters, creatures, water, and holes before clearing", function()
  local point = Vector3(100, 0, 100)
  function TheWorld.Map:GetTileAtPoint() return WORLD_TILES.FOREST end
  local center = HELPERS.GetPasserClearing(point, 0, 1)
  local base = SpawnPrefab("treasurechest")
  base:AddTag("structure")
  base.position = center
  equal(HELPERS.CanPreparePasserSite(point, 0, 1), false)
  base:Remove()
  local encounter = SpawnPrefab("agricola_farm")
  encounter._libellus_owneruserid = "other"
  encounter.position = center
  equal(HELPERS.CanPreparePasserSite(point, 0, 1), false)
  encounter:Remove()
  local animal = SpawnPrefab("rabbit")
  animal:AddComponent("health"):SetMaxHealth(20)
  animal.position = center
  equal(HELPERS.CanPreparePasserSite(point, 0, 1), false)
  animal:Remove()
  equal(HELPERS.CanPreparePasserSite(point, 0, 1), true)
  local reserved = SpawnPrefab("passer_burnt_tree")
  reserved.position = center
  equal(HELPERS.CanPreparePasserSite(point, 0, 1), false)
  reserved:Remove()
  hole = true
  equal(HELPERS.CanPreparePasserSite(point, 0, 1), false)
  hole = false
  function TheWorld.Map:IsPassableAtPoint() return false end
  equal(HELPERS.CanPreparePasserSite(point, 0, 1), false)
end)

test("forest placement randomizes close to the original spawn and reuses owned groves", function()
  local map = TheWorld.Map
  function map:GetSize() return 20, 20 end
  function map:GetTile() return WORLD_TILES.FOREST end
  function map:GetTileAtPoint() return WORLD_TILES.FOREST end
  function map:GetTileCenterPoint(x, z) return x * 4, 0, z * 4 end
  local player, progress = Player()
  local grove = progress:EnsurePasser()
  assert(grove ~= nil)
  assert(grove.position.x^2 + grove.position.z^2 <= 16^2)
  equal(grove._libellus_owneruserid, player.userid)
  local _, restored = Player()
  restored:OnLoad(progress:OnSave())
  equal(restored:EnsurePasser(), grove)
  cave = true
  local _, underground = Player()
  equal(underground:EnsurePasser(), nil)
end)

test("reflection starts fifteen seconds after line eight finishes and then speaks nine and ten in order", function()
  local player, progress, _, ship = ShipEncounter()
  progress:SetProgress("ch3", 8)
  player.position = ship.position
  progress:DialogLoop(player)
  equal(speeches[1].content, DIALOG.ch3[8].content)
  advance(19.99)
  equal(#speeches, 1)
  advance(.01)
  equal(speeches[2].content, DIALOG.ch3[9].content)
  equal(speeches[2].at, speeches[1].at + HELPERS.DIALOG_INTERVAL + 15)
  advance(5)
  equal(speeches[3].content, DIALOG.ch3[10].content)
  equal(speeches[3].speaker, progress._publius)
  equal(progress.dialog, 11)
end)

test("the reflection delay survives save and load with its remaining duration", function()
  local player, progress, _, ship = ShipEncounter()
  progress:SetProgress("ch3", 8)
  player.position = ship.position
  progress:DialogLoop(player)
  advance(8)
  local saved = progress:OnSave()
  equal(saved.ch3_reflection_remaining, 12)
  -- Pause the original player's scheduled tasks as on disconnect.
  player.valid = false
  local arriving, restored = Player()
  restored:OnLoad(saved)
  restored:DialogLoop(arriving)
  advance(11.99)
  equal(#speeches, 1)
  advance(.01)
  equal(speeches[2].content, DIALOG.ch3[9].content)
end)

test("Passer repeats line eleven on sight independently of progress and waits when invisible", function()
  local player, progress, _, passer = PasserEncounter()
  progress:SetProgress("ch2", 3)
  player.position = passer.position + Vector3(10, 0, 0)
  passer.visible = false
  progress:DialogLoop(player)
  advance(4)
  equal(#speeches, 0)
  passer.visible = true
  advance(2)
  equal(speeches[1].content, DIALOG.ch3[11].content)
  equal(speeches[1].speaker, passer)
  advance(31)
  equal(#speeches, 2)
  equal(speeches[2].content, DIALOG.ch3[11].content)
  equal(progress.chapter, "ch2")
  equal(progress.dialog, 3)
end)

test("nearby Passer plays twelve through fourteen and advances only after the final speech", function()
  local player, progress, _, passer = PasserEncounter()
  progress:SetProgress("ch3", 11)
  player.position = passer.position + Vector3(5, 0, 0)
  progress:DialogLoop(player)
  advance(6)
  equal(speeches[1].content, DIALOG.ch3[11].content)
  equal(speeches[2].content, DIALOG.ch3[12].content)
  advance(10)
  equal(speeches[3].content, DIALOG.ch3[13].content)
  equal(speeches[4].content, DIALOG.ch3[14].content)
  equal(progress.chapter, "ch3")
  equal(progress.dialog, 14)
  advance(4.99)
  equal(progress.chapter, "ch3")
  advance(.01)
  equal(progress.chapter, "ch4")
  equal(progress.dialog, 1)
end)

test("Passer conversation pauses outside range and a newer event cancels completion", function()
  local player, progress, _, passer = PasserEncounter()
  progress:SetProgress("ch3", 12)
  player.position = passer.position + Vector3(5.01, 0, 0)
  progress:DialogLoop(player)
  advance(6)
  equal(progress.dialog, 12)
  player.position = passer.position
  advance(2)
  equal(progress.dialog, 13)
  advance(10)
  equal(progress.dialog, 14)
  progress:SetProgress("ch3", 1)
  advance(5)
  equal(progress.chapter, "ch3")
  equal(progress.dialog, 1)
end)

test("grove reload restores cage and trees without clearing or duplicating them", function()
  local _, _, grove = PasserEncounter()
  local data, ents = {}, {}
  local refs = grove:OnSave(data)
  equal(#refs, 82)
  for _, ent in pairs(Ents) do ents[ent.GUID] = {entity = ent} end
  local loaded = SpawnPrefab("passer_grove")
  loaded:OnLoad(data)
  loaded:OnLoadPostPass(ents, data)
  local before = serial
  advance(0)
  equal(serial, before)
  equal(loaded._passer, grove._passer)
  equal(#loaded._trees, 81)
  equal(loaded._grove_dx, 0)
  equal(loaded._grove_dz, 1)
end)

local function HammerCage(cage, player)
  equal(cage.components.workable.action, ACTIONS.HAMMER)
  for i = 1, 3 do cage.components.workable:WorkedBy(player); equal(cage:IsValid(), true) end
  cage.components.workable:WorkedBy(player)
end

-- Drive the actual flight brain and stategraph with the mocked task clock.
local function StartPasserFlight(bird)
  BehaviourNode = Class(function() end)
  function BehaviourNode:Sleep() end
  Brain = Class(function(self, inst) self.inst = inst end)
  function BT(inst, node) return {root = node} end
  local graph = dofile("scripts/stategraphs/SGpasser.lua")
  local states = {}
  for _, state in ipairs(graph.states) do states[state.name] = state end
  function bird.sg:SetTimeout(delay)
    local state = self.currentstate
    self.timeout = bird:DoTaskInTime(delay, function()
      if self.currentstate == state and state.ontimeout ~= nil then state.ontimeout(bird) end
    end)
  end
  function bird.sg:GoToState(name)
    if self.timeout ~= nil then self.timeout:Cancel(); self.timeout = nil end
    self.state, self.currentstate = name, states[name]
    if self.currentstate.onenter ~= nil then self.currentstate.onenter(bird) end
  end
  bird.sg:GoToState("idle")
  local BirdBrain = dofile("scripts/brains/passerbrain.lua")
  local brain = BirdBrain(bird)
  brain:OnStart()
  bird:DoPeriodicTask(.05, function() brain.bt.root:Visit() end)
end

test("four hammer hits destroy the cage and release exactly one bird for its story owner", function()
  local owner, progress, grove, cage = PasserEncounter()
  progress:SetProgress("ch3", 13)
  local helper, helperprogress = Player("helper")
  helperprogress:SetProgress("ch2", 2)
  HammerCage(cage, helper)
  equal(cage:IsValid(), false)
  equal(grove._released, true)
  local bird = grove._passer
  equal(bird.prefab, "passer_free")
  equal(bird._grove, grove)
  equal(bird.AnimState.bank, "crow")
  equal(bird.AnimState.build, "robin_build")
  equal(progress.chapter, "ch4")
  equal(progress.dialog, 1)
  equal(helperprogress.chapter, "ch2")
  equal(helperprogress.dialog, 2)
  equal(grove:FreePasser(cage), false)
  equal(grove._passer, bird)
  local center = HELPERS.GetPasserClearing(grove.position, 0, 1)
  equal(bird._flight_target.x, center.x)
  equal(bird._flight_target.z, center.z - HELPERS.PASSER_GROVE_SIZE / 2 - 2)
end)

test("released Passer visibly flies to the burnt grove and lands before chapter four speech", function()
  local player, progress, grove, cage = PasserEncounter()
  player.position = cage.position
  progress:SetProgress("ch4", 1)
  HammerCage(cage, player)
  local bird = grove._passer
  StartPasserFlight(bird)
  progress:DialogLoop(player)
  advance(1)
  equal(#speeches, 0)
  assert(bird.position.y > 0)
  assert(bird.position.z > grove.position.z and bird.position.z < bird._flight_target.z)
  equal(bird.AnimState.animation, "takeoff_diagonal_loop")
  advance(3)
  equal(bird._arrived, true)
  equal(bird.position.y, 0)
  equal(bird.position.z, bird._flight_target.z)
  equal(bird.AnimState.animation, "idle")
  equal(speeches[1].content, DIALOG.ch4[1].content)
  advance(36)
  equal(progress.chapter, "ch4")
  equal(progress.dialog, 9)
  equal(#speeches, 8)
  for i, speech in ipairs(speeches) do
    equal(speech.content, DIALOG.ch4[i].content)
    equal(speech.speaker, DIALOG.ch4[i].name == "Passer" and bird or player)
    if i > 1 then assert(speech.at >= speeches[i - 1].at + HELPERS.DIALOG_INTERVAL) end
  end
  advance(30)
  equal(#speeches, 8)
end)

test("release interrupts pending chapter three completion without rewinding the new conversation", function()
  local player, progress, grove, cage = PasserEncounter()
  progress:SetProgress("ch3", 14)
  player.position = cage.position
  cage._conversation_until = now + 10
  progress:DialogLoop(player)
  equal(speeches[1].content, DIALOG.ch3[14].content)
  HammerCage(cage, player)
  StartPasserFlight(grove._passer)
  advance(6)
  equal(progress.chapter, "ch4")
  assert(progress.dialog >= 2)
end)

test("mid-flight save resumes the released bird without restoring its cage", function()
  local player, _, grove, cage = PasserEncounter()
  HammerCage(cage, player)
  local bird = grove._passer
  StartPasserFlight(bird)
  advance(1)
  local data, birddata, ents = {}, {}, {}
  grove:OnSave(data)
  bird:OnSave(birddata)
  equal(data.released, true)
  equal(birddata.arrived, nil)
  for _, ent in pairs(Ents) do ents[ent.GUID] = {entity = ent} end
  local arriving = SpawnPrefab("passer_free")
  arriving.Transform:SetPosition(bird.position:Get())
  arriving:OnLoad(birddata)
  ents[data.passer] = {entity = arriving}
  local loaded = SpawnPrefab("passer_grove")
  loaded:OnLoad(data)
  loaded:OnLoadPostPass(ents, data)
  bird:Remove()
  local before = serial
  advance(0)
  equal(serial, before)
  equal(loaded._released, true)
  equal(loaded._passer, arriving)
  equal(arriving._grove, loaded)
  StartPasserFlight(arriving)
  advance(4)
  equal(arriving._arrived, true)
  equal(arriving.position.z, birddata.target.z)
  arriving:OnSave(birddata)
  local landed = SpawnPrefab("passer_free")
  landed.Transform:SetPosition(arriving.position:Get())
  landed:OnLoad(birddata)
  StartPasserFlight(landed)
  advance(1)
  equal(landed._arrived, true)
  equal(landed.AnimState.animation, "idle")
  equal(landed.position.y, 0)
end)

test("an already released encounter starts chapter four for an offline owner on return", function()
  local owner, progress, grove, cage = PasserEncounter()
  progress:SetProgress("ch3", 11)
  AllPlayers = {}
  HammerCage(cage, owner)
  equal(progress.chapter, "ch3")
  local arriving, restored = Player()
  restored:OnLoad(progress:OnSave())
  restored:DialogLoop(arriving)
  equal(restored._passer_grove, grove)
  equal(restored.chapter, "ch4")
  equal(restored.dialog, 1)
  restored:SetProgress("ch4", 9)
  restored:OnPasserFreed(grove)
  equal(restored.dialog, 9)
end)

local function RexEncounter()
  local player, progress = Player()
  progress:EnsurePublius()
  local king = SpawnPrefab("pigking")
  king.Transform:SetPosition(200, 0, 200)
  return player, progress, king
end

local function CountPrefab(name)
  local total = 0
  for _, ent in pairs(Ents) do if ent.prefab == name then total = total + 1 end end
  return total
end

test("Rex extends the existing Pig King without replacing his native trade or minigame functions", function()
  local player, progress, king = RexEncounter()
  local trader, onaccept, sg, minigame = king.components.trader, king.components.trader.onaccept, king.sg, king.IsMinigameActive
  local voice = king._libellus_rex_voice
  require("rexanimalium").Setup(king)
  equal(king.prefab, "pigking")
  equal(king.components.trader, trader)
  equal(trader.onaccept, onaccept)
  equal(king.sg, sg)
  equal(king.IsMinigameActive, minigame)
  equal(king._libellus_rex_voice, voice)
  equal(voice.parent, king)
  equal(voice.persists, false)
  assert(voice.pristine and voice.components.talker ~= nil)
  equal(progress:EnsureRex(), king)
  player.position = Vector3(1000, 0, 1000)
  equal(progress:EnsureRex(), king)
  equal(CountPrefab("pigking"), 1)
end)

test("Rex plays nine through thirteen nearby and grants both gifts only after the final line", function()
  local player, progress, king = RexEncounter()
  progress:SetProgress("ch4", 9)
  player.position = king.position + Vector3(HELPERS.REX_MEETING_DISTANCE + .01, 0, 0)
  progress:DialogLoop(player)
  advance(2)
  equal(#speeches, 0)
  player.position = king.position + Vector3(HELPERS.REX_MEETING_DISTANCE, 0, 0)
  advance(22)
  equal(#speeches, 5)
  equal(progress.chapter, "ch4")
  equal(progress.dialog, 13)
  equal(CountPrefab("panflute"), 0)
  equal(CountPrefab("bell"), 0)
  for i = 9, 13 do
    local speech = speeches[i - 8]
    equal(speech.content, DIALOG.ch4[i].content)
    equal(speech.speaker, DIALOG.ch4[i].name == "Rex animalium" and king._libellus_rex_voice or player)
  end
  advance(4.99)
  equal(progress.chapter, "ch4")
  advance(.01)
  equal(progress.chapter, "ch5")
  equal(progress.dialog, 1)
  equal(CountPrefab("panflute"), 1)
  equal(CountPrefab("bell"), 1)
  local saved = progress:OnSave()
  equal(saved.rex_panflute_received, true)
  equal(saved.rex_bell_received, true)
  progress:SetProgress("ch4", 13)
  advance(10)
  equal(CountPrefab("panflute"), 1)
  equal(CountPrefab("bell"), 1)
end)

test("Rex conversation waits for night sleep, active native minigames, and player proximity", function()
  local player, progress, king = RexEncounter()
  player.position = king.position
  progress:SetProgress("ch4", 9)
  king.minigame_active = true
  progress:DialogLoop(player)
  advance(4)
  equal(#speeches, 0)
  king.minigame_active, king.sg.mem.sleeping = false, true
  advance(2)
  equal(#speeches, 0)
  king.sg.mem.sleeping = false
  advance(2)
  equal(speeches[1].content, DIALOG.ch4[9].content)
  player.position = Vector3(500, 0, 500)
  advance(6)
  equal(#speeches, 1)
end)

test("partial gift failures retry only the missing item and newer progress cancels all rewards", function()
  local player, progress, king = RexEncounter()
  player.position = king.position
  progress:SetProgress("ch4", 13)
  local give, attempts = king.GiveLibellusGift, 0
  king.GiveLibellusGift = function(inst, prefab, player)
    if prefab == "bell" then
      attempts = attempts + 1
      if attempts == 1 then return false end
    end
    return give(inst, prefab, player)
  end
  progress:DialogLoop(player)
  advance(5)
  equal(CountPrefab("panflute"), 1)
  equal(CountPrefab("bell"), 0)
  equal(progress:OnSave().rex_panflute_received, true)
  advance(2)
  equal(CountPrefab("panflute"), 1)
  equal(CountPrefab("bell"), 1)
  equal(progress.chapter, "ch5")
  reset()
  player, progress, king = RexEncounter()
  player.position = king.position
  progress:SetProgress("ch4", 13)
  progress:DialogLoop(player)
  progress:SetProgress("ch4", 12)
  player.busy = true
  advance(6)
  equal(CountPrefab("panflute"), 0)
  equal(CountPrefab("bell"), 0)
end)

test("Passer leaves after line eight finishes and tracks the player's effective walking speed", function()
  local player, progress, grove, cage = PasserEncounter()
  HammerCage(cage, player)
  local bird = grove._passer
  bird._arrived = true
  local king = SpawnPrefab("pigking")
  king.position = Vector3(300, 0, 100)
  player:AddComponent("locomotor")
  player.components.locomotor.walkspeed = 4
  StartPasserFlight(bird)
  progress:SetProgress("ch4", 8)
  progress:DialogLoop(player)
  advance(4.99)
  equal(bird._rex_guided, nil)
  advance(.11)
  equal(bird._rex_guided, true)
  equal(bird._guide_userid, player.userid)
  local before = bird:GetPosition()
  advance(1)
  local after = bird:GetPosition()
  assert(math.abs(math.sqrt((after.x-before.x)^2 + (after.z-before.z)^2) - 4) < .01)
  player.components.locomotor.speedmult = 2
  before = bird:GetPosition()
  advance(1)
  after = bird:GetPosition()
  assert(math.abs(math.sqrt((after.x-before.x)^2 + (after.z-before.z)^2) - 8) < .01)
  local data = {}
  bird:OnSave(data)
  equal(data.rex_guided, true)
  equal(data.guideuserid, player.userid)
  local restored = SpawnPrefab("passer_free")
  restored:OnLoad(data)
  equal(restored._rex_guided, true)
  equal(restored._flight_target.x, bird._flight_target.x)
end)

test("client encounter prefabs have visuals and no server-only components", function()
  TheWorld.ismastersim = false
  for _, name in ipairs({"casa", "lupa", "miles", "agricola", "agricola_crop", "agricola_farm", "navis", "senex",
    "passer", "passer_grove", "passer_free", "rex_voice"}) do
    local inst = SpawnPrefab(name)
    assert(inst.pristine)
    equal(inst.components.combat, nil)
    equal(inst.components.health, nil)
    equal(inst.components.inventory, nil)
    if name == "miles" or name == "agricola" or name == "senex" or name == "passer" or name == "passer_free"
      or name == "rex_voice" then
      assert(inst.components.talker ~= nil)
    end
  end
end)

print(count .. " casa encounter tests passed")
