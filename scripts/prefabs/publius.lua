local brain = require("brains/publiusbrain")

local assets = {
  Asset("ANIM", "anim/player_basic.zip"),
  Asset("ANIM", "anim/player_boat_jump.zip"),
  Asset("ANIM", "anim/player_knockedout.zip"),
  Asset("ANIM", "anim/wilson.zip")
}

local prefabs = {"globalmapiconnamed"}

local function OnMapIconCreated(inst, icon)
  -- The first icon is created before DST assigns the prefab's default name.
  icon._target_displayname:set(inst:GetDisplayName() or STRINGS.NAMES.PUBLIUS)
end

local function OnSave(inst, data)
  data.owneruserid = inst._libellus_owneruserid
end

local function OnLoad(inst, data)
  if data ~= nil then
    inst._libellus_owneruserid = data.owneruserid
  end
end

local function fn()
  local inst = CreateEntity()
  inst.entity:AddTransform()
  inst.entity:AddAnimState()
  inst.entity:AddSoundEmitter()
  inst.entity:AddDynamicShadow()
  inst.entity:AddMiniMapEntity()
  inst.entity:AddNetwork()

  inst.MiniMapEntity:SetIcon("wilson.png")
  inst.MiniMapEntity:SetPriority(9)
  inst.MiniMapEntity:SetCanUseCache(false)
  inst.MiniMapEntity:SetDrawOverFogOfWar(true)

  MakeCharacterPhysics(inst, 75, .5)
  inst.Transform:SetFourFaced()
  inst.DynamicShadow:SetSize(1.3, .6)
  inst.AnimState:SetBank("wilson")
  inst.AnimState:SetBuild("wilson")
  inst.AnimState:PlayAnimation("idle_loop", true)
  inst.AnimState:Hide("ARM_carry")
  inst.AnimState:Hide("HAT")
  inst.AnimState:Hide("HAIR_HAT")
  inst.AnimState:Hide("HEAD_HAT")
  inst.AnimState:Hide("HEAD_HAT_NOHELM")
  inst.AnimState:Hide("HEAD_HAT_HELM")

  inst:AddTag("character")
  inst:AddTag("companion")
  inst:AddTag("NOBLOCK")

  -- Talker must also exist on clients for replicated speech bubbles.
  inst:AddComponent("talker")
  inst.components.talker.font = TALKINGFONT
  inst.components.talker.fontsize = 35
  inst.components.talker.offset = Vector3(0, -400, 0)

  inst.entity:SetPristine()
  if not TheWorld.ismastersim then
    return inst
  end

  inst:AddComponent("inspectable")
  -- Keep a named, moving marker available even outside the client's view range.
  inst:AddComponent("maprevealable")
  inst.components.maprevealable:SetIconPrefab("globalmapiconnamed")
  inst.components.maprevealable:SetIcon("wilson.png")
  inst.components.maprevealable:SetIconPriority(9)
  inst.components.maprevealable:SetOnIconCreatedFn(OnMapIconCreated)
  inst.components.maprevealable:AddRevealSource("publius")

  inst:AddComponent("locomotor")
  inst.components.locomotor.walkspeed = TUNING.WILSON_WALK_SPEED
  inst.components.locomotor.runspeed = TUNING.WILSON_RUN_SPEED
  inst.components.locomotor:SetAllowPlatformHopping(true)
  inst:AddComponent("embarker")

  inst:AddComponent("follower")
  inst.components.follower.neverexpire = true
  inst.components.follower.keepdeadleader = true
  inst.components.follower.keepleaderduringminigame = true
  inst.components.follower:KeepLeaderOnAttacked()

  inst:SetStateGraph("SGpublius")
  inst:SetBrain(brain)
  inst.OnSave = OnSave
  inst.OnLoad = OnLoad
  return inst
end

return Prefab("publius", fn, assets, prefabs)
