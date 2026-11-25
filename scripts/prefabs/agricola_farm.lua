local HELPERS = require("helpers")
local function SpawnAt(inst, name, x, z)
  local ent = SpawnPrefab(name)
  if ent ~= nil then
    local cx, _, cz = inst.Transform:GetWorldPosition()
    ent.Transform:SetPosition(cx + x, 0, cz + z)
  end
  return ent
end

local function Populate(inst)
  if inst._populated then return end
  inst._populated = true
  local cells = {}
  for x = -3, 3, 3 do
    for z = -3, 3, 3 do
      local soil = SpawnAt(inst, "farm_soil", x, z)
      if soil ~= nil then table.insert(inst._soil, soil) end
      table.insert(cells, {x = x, z = z})
    end
  end
  for n = 1, math.random(5, 8) do
    local i = math.random(#cells)
    local cell = table.remove(cells, i)
    local crop = SpawnAt(inst, "agricola_crop", cell.x, cell.z)
    if crop ~= nil then table.insert(inst._crops, crop) end
  end
  inst._agricola = SpawnAt(inst, "agricola", 0, -HELPERS.FARM_SIZE / 2 + .5)
  if inst._agricola ~= nil then inst._agricola._farm = inst end
end

local function OnSave(inst, data)
  data.owneruserid, data.populated = inst._libellus_owneruserid, inst._populated
  local refs = {}
  for _, field in ipairs({"_soil", "_crops"}) do
    data[field] = {}
    for _, ent in ipairs(inst[field]) do
      if ent:IsValid() then
        table.insert(data[field], ent.GUID)
        table.insert(refs, ent.GUID)
      end
    end
  end
  if inst._agricola ~= nil and inst._agricola:IsValid() then
    data.agricola = inst._agricola.GUID
    table.insert(refs, data.agricola)
  end
  return refs
end

local function fn()
  local inst = CreateEntity()
  inst.entity:AddTransform()
  inst.entity:AddNetwork()
  inst:AddTag("NOBLOCK")
  inst:AddTag("NOCLICK")
  inst.entity:SetPristine()
  if not TheWorld.ismastersim then return inst end
  inst._soil, inst._crops = {}, {}
  inst.OnSave = OnSave
  inst.OnLoad = function(inst, data)
    if data ~= nil then
      inst._libellus_owneruserid, inst._populated = data.owneruserid, data.populated
    end
  end
  inst.OnLoadPostPass = function(inst, ents, data)
    if data == nil then return end
    for _, field in ipairs({"_soil", "_crops"}) do
      for _, guid in ipairs(data[field] or {}) do
        if ents[guid] ~= nil then table.insert(inst[field], ents[guid].entity) end
      end
    end
    inst._agricola = data.agricola ~= nil and ents[data.agricola] ~= nil and ents[data.agricola].entity or nil
    if inst._agricola ~= nil then inst._agricola._farm = inst end
  end
  inst:DoTaskInTime(0, Populate)
  return inst
end

return Prefab("agricola_farm", fn, nil, {"farm_soil", "agricola_crop", "agricola"})
