local brain = require("brains/senexbrain")
local HELPERS = require("helpers")

local assets = {
  Asset("ANIM", "anim/player_basic.zip"),
  Asset("ANIM", "anim/player_actions.zip"),
  Asset("ANIM", "anim/player_attacks.zip"),
  Asset("ANIM", "anim/player_knockedout.zip"),
  Asset("ANIM", "anim/wolfgang.zip")
}
local prefabs = {"spear"}

local function CanGuardTarget(inst, target)
  local ship = inst._ship
  return inst._shore_home == nil and not inst.components.sleeper:IsAsleep() and not inst.sg:HasStateTag("waking")
    and ship ~= nil and ship:IsValid() and inst:GetCurrentPlatform() == ship
    and target ~= nil and target:IsValid() and target:HasTag("player")
    and target:GetCurrentPlatform() == ship and not target:HasTag("playerghost")
    and not target.loadingprotection and target.components.health ~= nil
    and not target.components.health:IsDead() and inst.components.combat:CanTarget(target)
end

local function PrepareStorySleep(inst)
  if inst._ch5_sleep_prepared or inst.components.health:IsDead() then return end
  inst._ch5_sleep_prepared = true
  if inst.components.sleeper:IsInDeepSleep() then return end
  inst._story_sleep = true
  inst.components.sleeper:GoToSleep()
  -- Proximity wakes story sleep. A later pan flute play starts the native
  -- wake timer again, using its own sleep duration.
  inst.components.sleeper:StopTesting()
end

local function WakeForStory(inst)
  if inst.components.sleeper:IsInDeepSleep() then return end
  inst.components.sleeper:WakeUp()
end

local function UpdateTarget(inst)
  if inst.components.health:IsDead() then return end
  local combat = inst.components.combat
  if combat.target ~= nil and not CanGuardTarget(inst, combat.target) then
    combat:DropTarget()
    inst:ClearBufferedAction()
    inst.components.locomotor:Stop()
    if inst.sg:HasStateTag("attack") then inst.sg:GoToState("idle") end
  end
  if combat.target == nil then
    for _, player in ipairs(AllPlayers) do
      if CanGuardTarget(inst, player) then combat:SetTarget(player); break end
    end
  end
end

local function Arm(inst)
  if inst.components.health:IsDead() then return end
  local inventory = inst.components.inventory
  local weapon = inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
  if weapon ~= nil then
    -- Update saved equipment too; weapon damage overrides default combat damage.
    weapon.components.weapon:SetDamage(HELPERS.SENEX_DAMAGE)
    return
  end
  local spear = SpawnPrefab("spear")
  if spear ~= nil then
    spear.components.weapon:SetDamage(HELPERS.SENEX_DAMAGE)
    inventory:Equip(spear)
  end
end

local function OnSave(inst, data)
  data.ch5_sleep_prepared = inst._ch5_sleep_prepared
  data.shore_home = inst._shore_home ~= nil and {x = inst._shore_home.x, z = inst._shore_home.z} or nil
  data.story_sleep = inst._story_sleep and not inst.components.sleeper:IsInDeepSleep() or nil
  if inst._ship ~= nil and inst._ship:IsValid() then
    data.ship = inst._ship.GUID
    return {inst._ship.GUID}
  end
end

local function OnLoad(inst, data)
  if data == nil then return end
  inst._ch5_sleep_prepared, inst._story_sleep = data.ch5_sleep_prepared, data.story_sleep
  if data.shore_home ~= nil then inst._shore_home = Vector3(data.shore_home.x, 0, data.shore_home.z) end
  if inst._story_sleep then
    inst:DoTaskInTime(0, function(inst)
      inst.components.sleeper:GoToSleep()
      inst.components.sleeper:StopTesting()
    end)
  end
end

local function OnLoadPostPass(inst, ents, data)
  inst._ship = data ~= nil and data.ship ~= nil and ents[data.ship] ~= nil and ents[data.ship].entity or nil
end

local function fn()
  local inst = CreateEntity()
  inst.entity:AddTransform()
  inst.entity:AddAnimState()
  inst.entity:AddSoundEmitter()
  inst.entity:AddDynamicShadow()
  inst.entity:AddNetwork()
  MakeCharacterPhysics(inst, 75, .5)
  inst.Transform:SetFourFaced()
  inst.DynamicShadow:SetSize(1.3, .6)
  inst.AnimState:SetBank("wilson")
  inst.AnimState:SetBuild("wolfgang")
  inst.AnimState:PlayAnimation("idle_loop", true)
  for _, symbol in ipairs({"ARM_carry", "HAT", "HAIR_HAT", "HEAD_HAT",
    "HEAD_HAT_NOHELM", "HEAD_HAT_HELM"}) do
    inst.AnimState:Hide(symbol)
  end
  inst:AddTag("character")
  inst:AddTag("libellus_senex")
  inst:AddTag("NOBLOCK")
  -- Native pan flutes search for this tag on the replicated entity.
  inst:AddTag("sleeper")
  inst.displaynamefn = function() return "Senex" end
  inst:AddComponent("talker")
  inst.components.talker.font = TALKINGFONT
  inst.components.talker.fontsize = 35
  inst.components.talker.offset = Vector3(0, -400, 0)
  inst.entity:SetPristine()
  if not TheWorld.ismastersim then return inst end

  inst:AddComponent("inspectable")
  inst:AddComponent("locomotor")
  inst.components.locomotor.walkspeed = TUNING.WILSON_WALK_SPEED
  inst.components.locomotor.runspeed = TUNING.WILSON_RUN_SPEED
  inst.components.locomotor:SetAllowPlatformHopping(false)
  inst:AddComponent("health")
  inst.components.health:SetMaxHealth(HELPERS.SENEX_HEALTH)
  inst:AddComponent("combat")
  inst.components.combat:SetDefaultDamage(HELPERS.SENEX_DAMAGE)
  inst.components.combat:SetAttackPeriod(2)
  inst.components.combat:SetRange(2)
  inst.components.combat:SetKeepTargetFunction(CanGuardTarget)
  inst.components.combat:SetShouldAggroFn(CanGuardTarget)
  inst:AddComponent("inventory")
  inst:AddComponent("lootdropper")
  inst:AddComponent("sleeper")
  inst.components.sleeper:SetResistance(1)
  inst.components.sleeper:SetSleepTest(function() return false end)
  inst.components.sleeper:SetWakeTest(function(inst)
    return not inst._story_sleep or inst.components.sleeper:IsInDeepSleep()
  end)
  inst:AddComponent("senexshorepush")
  inst.PrepareStorySleep = PrepareStorySleep
  inst.WakeForStory = WakeForStory
  inst:ListenForEvent("onwakeup", function(inst) inst._story_sleep = nil end)
  inst.CanGuardTarget = CanGuardTarget
  inst:ListenForEvent("attacked", function(inst, data)
    if CanGuardTarget(inst, data.attacker) then
      inst.components.combat:SetTarget(data.attacker)
    end
  end)
  inst:SetStateGraph("SGsenex")
  inst:SetBrain(brain)
  inst.OnSave = OnSave
  inst.OnLoad = OnLoad
  inst.OnLoadPostPass = OnLoadPostPass
  -- Inventory has loaded by this point; a saved spear must not be duplicated.
  inst:DoTaskInTime(0, Arm)
  inst:DoPeriodicTask(HELPERS.SENEX_CHECK_INTERVAL, UpdateTarget)
  return inst
end

return Prefab("senex", fn, assets, prefabs)
