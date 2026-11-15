-- rocks animation files
local assets = {
  Asset("ANIM", "anim/rocks.zip") -- type of asset, asset file
}

local function foo()
  local inst = CreateEntity()
  inst.entity:AddTransform() -- allow it to move
  inst.entity:AddAnimState() -- add appearance
  inst.entity:AddNetwork() -- networking

  MakeInventoryPhysics(inst)

  inst.AnimState:SetBank("rocks") -- what set of animations we're using
  inst.AnimState:SetBuild("rocks") -- texture
  inst.AnimState:PlayAnimation("f1") -- play when entity is created

  inst.entity:SetPristine()
  -- add components only on the server
  -- code below runs only on the server
  if not TheWorld.ismastersim then
    return inst
  end
  inst:AddComponent("inspectable") -- add component

  inst:AddComponent("inventoryitem")
  inst.components.inventoryitem.imagename = "test"
  inst.components.inventoryitem.atlasname = "images/test.xml"

  inst:AddComponent("stackable")
  inst.components.stackable.maxsize = 10

  return inst
end

return Prefab("test", foo, assets)