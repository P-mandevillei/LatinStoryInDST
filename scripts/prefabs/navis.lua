-- The encounter owns references; the boat and fittings retain native gameplay
-- components and save/load behavior, including any changes made by the player.
local FIELDS = {"_ship", "_wheel", "_mast", "_anchor", "_senex"}

local function OnDeck(ship, name, dx, dz)
  local ent = SpawnPrefab(name)
  if ent ~= nil then
    local x, _, z = ship.Transform:GetWorldPosition()
    ent.Transform:SetPosition(x + dx, 0, z + dz)
    ship.components.walkableplatform:AddEntityToPlatform(ent)
  end
  return ent
end

local function Populate(inst)
  if inst._populated then return end
  local ship = SpawnPrefab("boat")
  if ship == nil then return end
  inst._populated = true
  inst._ship = ship
  local x, _, z = inst.Transform:GetWorldPosition()
  ship.Physics:Teleport(x, 0, z)
  ship.components.hull:OnDeployed()
  inst._wheel = OnDeck(ship, "steeringwheel", 0, -2)
  inst._mast = OnDeck(ship, "mast", 0, 1)
  inst._anchor = OnDeck(ship, "anchor", -2, 0)
  inst._senex = OnDeck(ship, "senex", 2, 0)
  if inst._senex ~= nil then inst._senex._ship = ship end
  if inst._mast ~= nil then
    local lamp = SpawnPrefab("mastupgrade_lamp_item")
    if lamp ~= nil then inst._mast.components.upgradeable:Upgrade(lamp, nil) end
  end
  if inst._anchor ~= nil then
    -- This native load hook establishes the anchor's boat before applying drag.
    local anchor = inst._anchor.components.anchor
    anchor:LoadPostPass()
    anchor.raiseunits = anchor:GetCurrentDepth()
    inst._anchor.sg:GoToState("lowered")
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
  inst.OnSave = function(inst, data)
    data.owneruserid, data.populated = inst._libellus_owneruserid, inst._populated
    local refs = {}
    for _, field in ipairs(FIELDS) do
      local ent = inst[field]
      if ent ~= nil and ent:IsValid() then
        data[field] = ent.GUID
        table.insert(refs, ent.GUID)
      end
    end
    return refs
  end
  inst.OnLoad = function(inst, data)
    if data ~= nil then
      inst._libellus_owneruserid, inst._populated = data.owneruserid, data.populated
    end
  end
  inst.OnLoadPostPass = function(inst, ents, data)
    if data == nil then return end
    for _, field in ipairs(FIELDS) do
      inst[field] = data[field] ~= nil and ents[data[field]] ~= nil and ents[data[field]].entity or nil
    end
    if inst._senex ~= nil then inst._senex._ship = inst._ship end
  end
  inst:DoTaskInTime(0, Populate)
  return inst
end

return Prefab("navis", fn, nil, {"boat", "steeringwheel", "mast", "mastupgrade_lamp_item", "anchor", "senex"})
