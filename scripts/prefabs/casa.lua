local HELPERS = require("helpers")

local assets = {Asset("ANIM", "anim/pig_house.zip")}
local prefabs = {"miles", "lupa", "wall_stone"}

local function Contains(inst, target)
  if target == nil or not target:IsValid() then return false end
  local x, _, z = inst.Transform:GetWorldPosition()
  local tx, _, tz = target.Transform:GetWorldPosition()
  return math.abs(tx - x) < HELPERS.CASA_HALF_SIZE
    and math.abs(tz - z) < HELPERS.CASA_HALF_SIZE
end

local function CanGuardTarget(inst, target)
  return Contains(inst, target) and target:HasTag("player")
    and not target:HasTag("playerghost") and not target:HasTag("notarget")
    and not target.loadingprotection and target.components.health ~= nil
    and not target.components.health:IsDead()
end

local function GetSoldier(inst)
  for _, soldier in ipairs(inst._soldiers) do
    if soldier:IsValid() and not soldier.components.health:IsDead() then
      return soldier
    end
  end
end

local function UpdateGuards(inst)
  for _, player in ipairs(AllPlayers) do
    if CanGuardTarget(inst, player) then
      local progress = player.components.libellusprogress
      if progress ~= nil then progress:OnCasaEntered(inst) end
    end
  end
  for _, soldier in ipairs(inst._soldiers) do
    if soldier:IsValid() and not soldier.components.health:IsDead() then
      local combat = soldier.components.combat
      if combat.target ~= nil and not CanGuardTarget(inst, combat.target) then
        combat:DropTarget()
        soldier:ClearBufferedAction()
        soldier.components.locomotor:Stop()
        if soldier.sg:HasStateTag("attack") then
          soldier.sg:GoToState("idle")
        end
      end
      if combat.target == nil then
        for _, player in ipairs(AllPlayers) do
          if CanGuardTarget(inst, player) and combat:CanTarget(player) then
            combat:SetTarget(player)
            break
          end
        end
      end
    end
  end
end

local function SpawnAt(inst, prefab, x, z)
  local ent = SpawnPrefab(prefab)
  if ent ~= nil then
    local cx, _, cz = inst.Transform:GetWorldPosition()
    ent.Transform:SetPosition(cx + x, 0, cz + z)
  end
  return ent
end

local function SpawnWall(inst, x, z)
  local wall = SpawnAt(inst, "wall_stone", x, z)
  if wall ~= nil then wall.components.health:SetPercent(1) end
end

local function Populate(inst)
  if inst._populated then return end
  inst._populated = true
  local size = HELPERS.CASA_HALF_SIZE
  for n = -size, size do
    SpawnWall(inst, -size, n)
    SpawnWall(inst, size, n)
    if n > -size and n < size then
      SpawnWall(inst, n, -size)
      -- The three-unit opening faces the soldiers across the courtyard.
      if math.abs(n) > 1 then SpawnWall(inst, n, size) end
    end
  end

  -- A closed pen makes Lupa's captivity visible using ordinary stone walls.
  for x = 2, 6 do
    SpawnWall(inst, x, -5)
    SpawnWall(inst, x, -1)
  end
  for z = -4, -2 do
    SpawnWall(inst, 2, z)
    SpawnWall(inst, 6, z)
  end
  inst._lupa = SpawnAt(inst, "lupa", 4, -3)

  local count = math.random(3, 5)
  for i = 1, count do
    local soldier = SpawnAt(inst, "miles", (i - (count + 1) / 2) * 2, 3)
    if soldier ~= nil then
      soldier._casa = inst
      soldier._guardpoint = soldier:GetPosition()
      table.insert(inst._soldiers, soldier)
    end
  end
end

local function OnSave(inst, data)
  data.owneruserid = inst._libellus_owneruserid
  data.populated = inst._populated
  data.soldiers = {}
  local refs = {}
  for _, soldier in ipairs(inst._soldiers) do
    if soldier:IsValid() and not soldier.components.health:IsDead() then
      table.insert(data.soldiers, soldier.GUID)
      table.insert(refs, soldier.GUID)
    end
  end
  if inst._lupa ~= nil and inst._lupa:IsValid() then
    data.lupa = inst._lupa.GUID
    table.insert(refs, inst._lupa.GUID)
  end
  return refs
end

local function OnLoad(inst, data)
  if data ~= nil then
    inst._libellus_owneruserid = data.owneruserid
    inst._populated = data.populated
  end
end

local function OnLoadPostPass(inst, newents, data)
  if data == nil then return end
  for _, guid in ipairs(data.soldiers or {}) do
    local ent = newents[guid]
    if ent ~= nil then
      ent.entity._casa = inst
      table.insert(inst._soldiers, ent.entity)
    end
  end
  inst._lupa = data.lupa ~= nil and newents[data.lupa] ~= nil
    and newents[data.lupa].entity or nil
end

local function fn()
  local inst = CreateEntity()
  inst.entity:AddTransform()
  inst.entity:AddAnimState()
  inst.entity:AddMiniMapEntity()
  inst.entity:AddNetwork()
  MakeObstaclePhysics(inst, 1)
  inst.AnimState:SetBank("pig_house")
  inst.AnimState:SetBuild("pig_house")
  inst.AnimState:PlayAnimation("idle", true)
  inst.MiniMapEntity:SetIcon("pighouse.png")
  inst:AddTag("structure")
  inst.displaynamefn = function() return "Casa Octaviae" end
  inst.entity:SetPristine()
  if not TheWorld.ismastersim then return inst end

  inst:AddComponent("inspectable")
  inst._soldiers = {}
  inst.Contains = Contains
  inst.CanGuardTarget = CanGuardTarget
  inst.GetSoldier = GetSoldier
  inst.OnSave = OnSave
  inst.OnLoad = OnLoad
  inst.OnLoadPostPass = OnLoadPostPass
  -- Deferred so the spawner (or save loader) can set the position first.
  inst:DoTaskInTime(0, Populate)
  inst:DoPeriodicTask(HELPERS.CASA_CHECK_INTERVAL, UpdateGuards)
  return inst
end

return Prefab("casa", fn, assets, prefabs)
