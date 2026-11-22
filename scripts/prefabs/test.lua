-- rocks animation files
local assets = { -- type of asset, asset file
  Asset("ANIM", "anim/test.zip"),
  Asset("ATLAS", "images/test.xml"),
  Asset("IMAGE", "images/test.tex")
}

local function foo()
  local inst = CreateEntity()
  inst.entity:AddTransform() -- allow it to move
  inst.entity:AddAnimState() -- add appearance
  inst.entity:AddNetwork() -- networking

  MakeInventoryPhysics(inst)

  inst.AnimState:SetBank("test") -- what set of animations we're using
  inst.AnimState:SetBuild("test") -- texture
  inst.AnimState:PlayAnimation("idle") -- play when entity is created

  inst.entity:SetPristine()
  -- add components only on the server
  -- code below runs only on the server
  if not TheWorld.ismastersim then
    return inst
  end
  inst:AddComponent("inspectable") -- add component

  inst:AddComponent("inventoryitem") -- show in inventory
  inst.components.inventoryitem.imagename = "test"
  inst.components.inventoryitem.atlasname = "images/test.xml"

  inst:AddComponent("stackable")
  inst.components.stackable.maxsize = 10

  inst:AddComponent("huggable")
  inst.components.huggable:SetSanityGain(15)

  inst:AddComponent("equippable")
  inst.components.equippable.equipslot = EQUIPSLOTS.HANDS

  return inst
end

return Prefab("test", foo, assets)