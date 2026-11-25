local brain = require("brains/milesbrain")
local HELPERS = require("helpers")

local assets = {
  Asset("ANIM", "anim/player_basic.zip"),
  Asset("ANIM", "anim/player_actions.zip"),
  Asset("ANIM", "anim/player_attacks.zip"),
  Asset("ANIM", "anim/wx78.zip")
}
local prefabs = {"spear"}

local function CanGuardTarget(inst, target)
  local casa = inst._casa
  return casa ~= nil and casa:IsValid() and casa:CanGuardTarget(target)
    and inst.components.combat:CanTarget(target)
end

local function Arm(inst)
  if inst.components.health:IsDead()
    or inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) ~= nil then
    return
  end
  local spear = SpawnPrefab("spear")
  if spear ~= nil then inst.components.inventory:Equip(spear) end
end

local function OnSave(inst, data)
  local point = inst._guardpoint
  data.guardpoint = point ~= nil and {x = point.x, y = point.y, z = point.z} or nil
end

local function OnLoad(inst, data)
  if data ~= nil and data.guardpoint ~= nil then
    local point = data.guardpoint
    inst._guardpoint = Vector3(point.x, point.y, point.z)
  end
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
  inst.AnimState:SetBuild("wx78")
  inst.AnimState:PlayAnimation("idle_loop", true)
  for _, symbol in ipairs({"ARM_carry", "HAT", "HAIR_HAT", "HEAD_HAT",
    "HEAD_HAT_NOHELM", "HEAD_HAT_HELM"}) do
    inst.AnimState:Hide(symbol)
  end
  inst:AddTag("character")
  inst:AddTag("NOBLOCK")
  inst.displaynamefn = function() return "Miles" end
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
  inst:AddComponent("health")
  inst.components.health:SetMaxHealth(HELPERS.SOLDIER_HEALTH)
  inst:AddComponent("combat")
  inst.components.combat:SetDefaultDamage(TUNING.SPEAR_DAMAGE)
  inst.components.combat:SetAttackPeriod(2)
  inst.components.combat:SetRange(2)
  inst.components.combat:SetKeepTargetFunction(CanGuardTarget)
  inst.components.combat:SetShouldAggroFn(CanGuardTarget)
  inst:AddComponent("inventory")
  inst:AddComponent("lootdropper")
  inst.CanGuardTarget = CanGuardTarget
  inst:ListenForEvent("attacked", function(inst, data)
    if CanGuardTarget(inst, data.attacker) then
      inst.components.combat:SetTarget(data.attacker)
    end
  end)
  inst:SetStateGraph("SGmiles")
  inst:SetBrain(brain)
  inst.OnSave = OnSave
  inst.OnLoad = OnLoad
  -- Inventory has loaded by this point; a saved spear must not be duplicated.
  inst:DoTaskInTime(0, Arm)
  return inst
end

return Prefab("miles", fn, assets, prefabs)
