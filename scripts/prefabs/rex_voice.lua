local function fn()
  local inst = CreateEntity()
  inst.entity:AddTransform()
  inst.entity:AddNetwork()
  inst:AddTag("NOBLOCK")
  inst:AddTag("NOCLICK")
  inst:AddComponent("talker")
  inst.components.talker.font = TALKINGFONT
  inst.components.talker.fontsize = 35
  inst.components.talker.offset = Vector3(0, -600, 0)
  inst.entity:SetPristine()
  if not TheWorld.ismastersim then return inst end
  inst.persists = false
  return inst
end
return Prefab("rex_voice", fn)
