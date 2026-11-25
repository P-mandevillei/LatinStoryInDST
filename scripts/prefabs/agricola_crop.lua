local PLANTS = require("prefabs/farm_plant_defs").PLANT_DEFS
local CROPS = {"carrot", "corn", "potato", "tomato", "pumpkin"}
local assets = {}
for _, name in ipairs(CROPS) do
  local def = PLANTS[name]
  table.insert(assets, Asset("ANIM", "anim/" .. def.bank .. ".zip"))
  table.insert(assets, Asset("ANIM", "anim/" .. def.build .. ".zip"))
end

local function SetCrop(inst, name, ripe)
  local def = PLANTS[name]
  inst._crop, inst._ripe = name, ripe
  inst.AnimState:SetBank(def.bank)
  inst.AnimState:SetBuild(def.build)
  inst.AnimState:PlayAnimation(ripe and "crop_full" or "crop_med", true)
end

local function fn()
  local inst = CreateEntity()
  inst.entity:AddTransform()
  inst.entity:AddAnimState()
  inst.entity:AddNetwork()
  inst:AddTag("NOBLOCK")
  inst:AddTag("NOCLICK")
  inst.AnimState:SetBank(PLANTS.carrot.bank)
  inst.AnimState:SetBuild(PLANTS.carrot.build)
  inst.AnimState:PlayAnimation("crop_med", true)
  inst.entity:SetPristine()
  if not TheWorld.ismastersim then return inst end

  -- Decorative plants never create produce, seeds, or inventory records.
  inst.SetCrop = SetCrop
  inst:DoTaskInTime(0, function()
    if inst._crop == nil then SetCrop(inst, CROPS[math.random(#CROPS)], math.random() < .5) end
  end)
  inst.OnSave = function(inst, data) data.crop, data.ripe = inst._crop, inst._ripe end
  inst.OnLoad = function(inst, data)
    if data ~= nil and PLANTS[data.crop] ~= nil then SetCrop(inst, data.crop, data.ripe == true) end
  end
  return inst
end

return Prefab("agricola_crop", fn, assets)
