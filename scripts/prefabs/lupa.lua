local assets = {
  Asset("ANIM", "anim/hound_basic.zip"),
  Asset("ANIM", "anim/hound_red_ocean.zip")
}

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
    inst.components.health:SetMaxHealth(require("helpers").KING_COURT_HEALTH)
    inst:AddComponent("combat")
    inst.components.combat.hurtsound = "dontstarve/creatures/hound/hurt"
    inst:AddComponent("locomotor")
    inst.components.locomotor.walkspeed = 5
    inst.components.locomotor.runspeed = 12
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
  end
  -- Captive and stationary: no wild-hound targeting or fire-on-death behavior.
  return inst
end

return Prefab("lupa", function() return fn(false) end, assets),
  Prefab("king_lupa", function() return fn(true) end, assets)
