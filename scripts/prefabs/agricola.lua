local brain = require("brains/agricolabrain")
local assets = {
  Asset("ANIM", "anim/player_basic.zip"),
  Asset("ANIM", "anim/woodie.zip"),
  Asset("ANIM", "anim/hat_straw.zip")
}

local function fn()
  local inst = CreateEntity()
  inst.entity:AddTransform()
  inst.entity:AddAnimState()
  inst.entity:AddSoundEmitter()
  inst.entity:AddDynamicShadow()
  inst.entity:AddMiniMapEntity()
  inst.entity:AddNetwork()
  MakeCharacterPhysics(inst, 75, .5)
  inst.Transform:SetFourFaced()
  inst.DynamicShadow:SetSize(1.3, .6)
  inst.MiniMapEntity:SetIcon("woodie.png")
  inst.AnimState:SetBank("wilson")
  inst.AnimState:SetBuild("woodie")
  inst.AnimState:PlayAnimation("idle_loop", true)
  inst.AnimState:OverrideSymbol("swap_hat", "hat_straw", "swap_hat")
  inst.AnimState:Show("HAT")
  inst.AnimState:Show("HAIR_HAT")
  inst.AnimState:Hide("HAIR_NOHAT")
  inst.AnimState:Hide("HEAD_HAT")
  inst.AnimState:Hide("ARM_carry")
  inst:AddTag("character")
  inst:AddTag("companion")
  inst:AddTag("NOBLOCK")
  inst:AddComponent("talker")
  inst.components.talker.font = TALKINGFONT
  inst.components.talker.fontsize = 35
  inst.components.talker.offset = Vector3(0, -400, 0)
  inst.entity:SetPristine()
  if not TheWorld.ismastersim then return inst end
  inst:AddComponent("inspectable")
  inst:AddComponent("locomotor")
  inst.components.locomotor.walkspeed = TUNING.WILSON_WALK_SPEED
  inst:SetStateGraph("SGagricola")
  inst:SetBrain(brain)
  return inst
end

return Prefab("agricola", fn, assets)
