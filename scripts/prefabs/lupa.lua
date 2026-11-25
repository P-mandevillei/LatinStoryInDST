local assets = {
  Asset("ANIM", "anim/hound_basic.zip"),
  Asset("ANIM", "anim/hound_red_ocean.zip")
}

local function fn()
  local inst = CreateEntity()
  inst.entity:AddTransform()
  inst.entity:AddAnimState()
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
  inst.entity:SetPristine()
  if not TheWorld.ismastersim then return inst end

  inst:AddComponent("inspectable")
  -- Captive and stationary: no wild-hound targeting or fire-on-death behavior.
  return inst
end

return Prefab("lupa", fn, assets)
