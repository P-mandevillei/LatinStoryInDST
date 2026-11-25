local HELPERS = require("helpers")

local function Populate(inst)
  if inst._populated then return end
  local point = inst:GetPosition()
  local dx, dz = inst._grove_dx or 0, inst._grove_dz or 1
  -- Recheck after deferred spawning before changing any existing resources.
  if not HELPERS.CanPreparePasserSite(point, dx, dz) then inst:Remove(); return end
  local center = HELPERS.GetPasserClearing(point, dx, dz)
  for _, ent in ipairs(HELPERS.GetPasserClearingEntities(center)) do ent:Remove() end
  inst._populated = true
  inst._passer = SpawnPrefab("passer")
  if inst._passer ~= nil then
    inst._passer.Transform:SetPosition(point:Get())
    inst._passer:FacePoint(point.x - dx, 0, point.z - dz)
  end
  -- Nine rows of nine trees fill the 27-unit square with room to walk between.
  for x = -12, 12, 3 do
    for z = -12, 12, 3 do
      local tree = SpawnPrefab("passer_burnt_tree")
      if tree ~= nil then
        tree.Transform:SetPosition(center.x + x, 0, center.z + z)
        table.insert(inst._trees, tree)
      end
    end
  end
end

local function fn()
  local inst = CreateEntity()
  inst.entity:AddTransform()
  inst.entity:AddNetwork()
  inst:AddTag("NOBLOCK")
  inst:AddTag("NOCLICK")
  inst.entity:SetPristine()
  if not TheWorld.ismastersim then return inst end
  inst._trees = {}
  inst.OnSave = function(inst, data)
    data.owneruserid, data.populated = inst._libellus_owneruserid, inst._populated
    data.dx, data.dz = inst._grove_dx, inst._grove_dz
    data.trees = {}
    local refs = {}
    if inst._passer ~= nil and inst._passer:IsValid() then
      data.passer = inst._passer.GUID
      table.insert(refs, data.passer)
    end
    for _, tree in ipairs(inst._trees) do
      if tree:IsValid() then table.insert(data.trees, tree.GUID); table.insert(refs, tree.GUID) end
    end
    return refs
  end
  inst.OnLoad = function(inst, data)
    if data ~= nil then
      inst._libellus_owneruserid, inst._populated = data.owneruserid, data.populated
      inst._grove_dx, inst._grove_dz = data.dx, data.dz
    end
  end
  inst.OnLoadPostPass = function(inst, ents, data)
    if data == nil then return end
    inst._passer = data.passer ~= nil and ents[data.passer] ~= nil and ents[data.passer].entity or nil
    for _, guid in ipairs(data.trees or {}) do
      if ents[guid] ~= nil then table.insert(inst._trees, ents[guid].entity) end
    end
  end
  inst:DoTaskInTime(0, Populate)
  return inst
end

return Prefab("passer_grove", fn, nil, {"passer", "passer_burnt_tree"})
