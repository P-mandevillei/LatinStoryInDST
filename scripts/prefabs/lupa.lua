local HELPERS = require("helpers")
local assets = {
  Asset("ANIM", "anim/hound_basic.zip"),
  Asset("ANIM", "anim/hound_basic_water.zip"),
  Asset("ANIM", "anim/hound_ocean.zip"),
  Asset("ANIM", "anim/hound_red_ocean.zip")
}

local function OnEnterWater(inst)
  local locomotor = inst.components.locomotor
  inst.landspeed, inst.hop_distance = locomotor.runspeed, locomotor.hop_distance
  locomotor.runspeed = TUNING.HOUND_SWIM_SPEED
  locomotor.hop_distance = HELPERS.LUPA_SWIM_HOP_DISTANCE
end

local function OnExitWater(inst)
  local locomotor = inst.components.locomotor
  if inst.landspeed ~= nil then locomotor.runspeed = inst.landspeed end
  if inst.hop_distance ~= nil then locomotor.hop_distance = inst.hop_distance end
end

local function fn(court)
  local inst = CreateEntity()
  inst.entity:AddTransform()
  inst.entity:AddAnimState()
  if court then inst.entity:AddSoundEmitter() end
  inst.entity:AddDynamicShadow()
  inst.entity:AddNetwork()
  MakeCharacterPhysics(inst, 10, .5)
  inst.Transform:SetFourFaced()
  inst.DynamicShadow:SetSize(2.5, 1.5)
  inst.AnimState:SetBank("hound")
  inst.AnimState:SetBuild("hound_red_ocean")
  inst.AnimState:PlayAnimation("idle", true)
  inst:AddTag("companion")
  inst.displaynamefn = function() return "Lupa" end
  if court then
    inst.AnimState:OverrideSymbol("shadow_ripple", "hound_ocean", "shadow_ripple")
    inst.AnimState:OverrideSymbol("water_ripple", "hound_ocean", "water_ripple")
    inst:AddTag("libellus_court")
    inst:AddTag("sleeper")
    inst:AddComponent("talker")
    inst.components.talker.font = TALKINGFONT
    inst.components.talker.fontsize = 35
    inst.components.talker.offset = Vector3(0, -250, 0)
  end
  inst.entity:SetPristine()
  if not TheWorld.ismastersim then return inst end

  inst:AddComponent("inspectable")
  if court then
    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(HELPERS.KING_COURT_HEALTH)
    inst:AddComponent("combat")
    inst.components.combat.hurtsound = "dontstarve/creatures/hound/hurt"
    inst:AddComponent("locomotor")
    inst.components.locomotor.walkspeed = HELPERS.LUPA_WALK_SPEED
    inst.components.locomotor.runspeed = HELPERS.LUPA_FOLLOW_SPEED
    inst.components.locomotor:SetAllowPlatformHopping(true)
    inst:AddComponent("embarker")
    inst.components.embarker.embark_speed = HELPERS.LUPA_FOLLOW_SPEED
    inst.components.embarker.antic = true
    -- SGhound uses amphibious hop states even when jumping from land onto
    -- a boat: done_embark_movement unconditionally calls OnExitOcean().
    inst:AddComponent("amphibiouscreature")
    inst.components.amphibiouscreature:SetBanks("hound", "hound_water")
    inst.components.amphibiouscreature:SetEnterWaterFn(OnEnterWater)
    inst.components.amphibiouscreature:SetExitWaterFn(OnExitWater)
    inst.components.locomotor.pathcaps = {allowocean = true}
    inst:AddComponent("follower")
    inst:AddComponent("lootdropper")
    inst:AddComponent("sleeper")
    inst.components.sleeper:SetSleepTest(function() return false end)
    inst.sounds = {pant = "dontstarve/creatures/hound/pant", bark = "dontstarve/creatures/hound/bark",
      attack = "dontstarve/creatures/hound/attack", growl = "dontstarve/creatures/hound/growl",
      walk = "dontstarve/creatures/hound/move", run = "dontstarve/creatures/hound/move",
      sleep = "dontstarve/creatures/hound/sleep", wake = "dontstarve/creatures/hound/wakeup",
      death = "dontstarve/creatures/hound/death"}
    inst:SetStateGraph("SGhound")
    inst:AddComponent("kingguard")
    inst.OnSave = function(inst, data) data.owneruserid = inst._libellus_owneruserid end
    inst.OnLoad = function(inst, data)
      if data ~= nil then inst._libellus_owneruserid = data.owneruserid end
    end
  end
  -- Captive and stationary: no wild-hound targeting or fire-on-death behavior.
  return inst
end

return Prefab("lupa", function() return fn(false) end, assets),
  Prefab("king_lupa", function() return fn(true) end, assets, {"splash_green"})
