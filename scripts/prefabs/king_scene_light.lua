local function fn()
  local inst = CreateEntity()
  inst.entity:AddTransform()
  inst.entity:AddLight()
  inst.entity:AddNetwork()
  inst.Light:SetRadius(5)
  inst.Light:SetIntensity(.85)
  inst.Light:SetFalloff(.6)
  inst.Light:SetColour(1, .85, .55)
  inst.Light:Enable(true)
  inst:AddTag("FX")
  inst:AddTag("NOCLICK")
  inst.entity:SetPristine()
  if not TheWorld.ismastersim then return inst end
  inst.persists = false
  return inst
end
return Prefab("king_scene_light", fn)
